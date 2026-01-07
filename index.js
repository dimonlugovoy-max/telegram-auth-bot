// index.js — Telegram Auth Bot v3.0
// Безопасно, надёжно, с HTTPS и уведомлениями
// Работает с pm2, nginx, Let's Encrypt

require('dotenv').config();
const TelegramBot = require('node-telegram-bot-api');
const express = require('express');
const axios = require('axios');
const cron = require('node-cron');

// Утилиты
const Database = require('./utils/database');
const Validator = require('./utils/validator');
const logger = require('./utils/logger');
const LinkSigner = require('./utils/linkSigner');

// Конфиг
const BOT_TOKEN = process.env.BOT_TOKEN;
const BOT_USERNAME = process.env.BOT_USERNAME;
const API_BASE_URL = 'https://api.yclients.com/api/v1';
const BEARER_TOKEN = process.env.BEARER_TOKEN;
const PARTNER_TOKEN = process.env.PARTNER_TOKEN;
const PORT = process.env.PORT || 3010;
const LINK_EXPIRY_HOURS = parseInt(process.env.LINK_EXPIRY_HOURS || '24');
const RETRY_INTERVAL_MINUTES = parseInt(process.env.RETRY_INTERVAL_MINUTES || '5');
const API_TIMEOUT_MS = parseInt(process.env.API_TIMEOUT_MS || '15000');

// Сообщения
const MESSAGES = {
  WELCOME_NEW: '👋 Добро пожаловать!\n\nДля завершения регистрации введите ваши ФИО в формате:\nФамилия Имя Отчество',
  CONSENT_TEXT: '📋 *Соглашение на обработку персональных данных*\n\nЯ даю согласие на обработку моих персональных данных.\n\nДля продолжения необходимо принять соглашение:',
  CONSENT_ACCEPTED: '✅ Согласие принято!\n\nТеперь подтвердите ваш номер телефона:',
  CONSENT_DECLINED: '❌ Без согласия невозможно продолжить.',
  AUTH_SUCCESS: '✅ Аутентификация успешна!',
  AUTH_PENDING: '⏳ Данные приняты. Синхронизация с системой...',
  PHONE_MISMATCH: '❌ Номер телефона не совпадает с данными в системе.',
  INVALID_NAME: '❌ Введите ФИО корректно (минимум Фамилия и Имя)',
  LINK_EXPIRED: '❌ Ссылка устарела. Запросите новую.',
  INVALID_LINK: '❌ Неверная ссылка. Запросите новую.',
  SESSION_EXPIRED: 'Сессия истекла. Начните заново.'
};

// Бот и сервер
const bot = new TelegramBot(BOT_TOKEN, { polling: true });
const app = express();
app.use(express.json());

// База данных
const db = new Database();

// Сессии
const userSessions = new Map();

// ============================================
// Генерация и проверка подписанных ссылок
// ============================================

function generateBotLink(data) {
  const signed = LinkSigner.sign(data);
  return `https://t.me/${BOT_USERNAME}?start=${encodeURIComponent(signed)}`;
}

function parseStartParam(signedData) {
  return LinkSigner.verify(decodeURIComponent(signedData));
}

// ============================================
// YClients API: обновление клиента
// ============================================

async function updateClient(companyId, clientId, fullName, phone, tgId) {
  try {
    const phoneDigits = phone.toString().replace(/\D/g, '');
    const body = {
      phone: phoneDigits,
      custom_fields: { tg_id: tgId.toString() }
    };
    if (fullName) body.name = fullName;

    const response = await axios.put(
      `${API_BASE_URL}/client/${companyId}/${clientId}`,
      body,
      {
        headers: {
          'Authorization': `Bearer ${BEARER_TOKEN}, User ${PARTNER_TOKEN}`,
          'Content-Type': 'application/json'
        },
        timeout: API_TIMEOUT_MS
      }
    );

    return response.data.success === true;
  } catch (error) {
    logger.error('Ошибка обновления клиента в YClients', {
      companyId,
      clientId,
      error: error.response?.data || error.message
    });
    return false;
  }
}

// ============================================
// Очередь повторных попыток
// ============================================

function addToRetryQueue(companyId, clientId, tgId, fullName, phone) {
  const nextRetry = new Date(Date.now() + RETRY_INTERVAL_MINUTES * 60 * 1000).toISOString();
  db.run(
    `INSERT INTO retry_queue (company_id, client_id, tg_id, full_name, phone, next_retry)
     VALUES (?, ?, ?, ?, ?, ?)`,
    [companyId, clientId, tgId, fullName, phone, nextRetry]
  ).catch(err => logger.error('Ошибка добавления в очередь', { err }));
}

// ============================================
// Обработка /start
// ============================================

async function handleStart(chatId, tgId, startParam) {
  if (!startParam) {
    bot.sendMessage(chatId, MESSAGES.INVALID_LINK);
    return;
  }

  try {
    const data = parseStartParam(startParam);
    if (!data) {
      bot.sendMessage(chatId, MESSAGES.INVALID_LINK);
      return;
    }

    if (!Validator.validateLinkExpiry(data.date, LINK_EXPIRY_HOURS)) {
      bot.sendMessage(chatId, MESSAGES.LINK_EXPIRED);
      return;
    }

    const existing = await db.getClient(data.company_id, data.client_id);
    if (existing && existing.tg_id && existing.tg_id === tgId) {
      bot.sendMessage(chatId, '👋 С возвращением! Подтвердите личность:', {
        reply_markup: {
          inline_keyboard: [[{ text: '✅ Подтвердить личность', callback_data: 'confirm_identity' }]]
        }
      });
      return;
    }

    userSessions.set(tgId, {
      company_id: data.company_id,
      client_id: data.client_id,
      phone: data.phone,
      client_status: data.client_status,
      step: 'waiting_name'
    });

    bot.sendMessage(chatId, MESSAGES.WELCOME_NEW, {
      reply_markup: {
        keyboard: [['❌ Отмена']],
        resize_keyboard: true
      }
    });

    logger.info('Создана сессия', { tgId, company_id: data.company_id, client_id: data.client_id });
  } catch (error) {
    logger.error('Ошибка handleStart', { error, tgId, startParam });
    bot.sendMessage(chatId, MESSAGES.INVALID_LINK);
  }
}

// ============================================
// Обработка сообщений
// ============================================

bot.on('message', async (msg) => {
  logger.info('📩 ВХОДЯЩЕЕ СООБЩЕНИЕ', {
    from: msg.from.id,
    chat: msg.chat.id,
    text: msg.text,
    contact: msg.contact ? 'есть' : null
  });

  const chatId = msg.chat.id;
  const tgId = msg.from.id;
  const text = msg.text?.trim();

  // 1. /start с параметром
  if (text?.startsWith('/start ')) {
    const startParam = text.slice(7).trim();
    await handleStart(chatId, tgId, startParam);
    return;
  }

  // 2. Просто /start
  if (text === '/start') {
    const client = await db.getClientByTgId(tgId);
    if (client) {
      bot.sendMessage(chatId, '👋 С возвращением! Подтвердите личность:', {
        reply_markup: {
          inline_keyboard: [[{ text: '✅ Подтвердить личность', callback_data: 'confirm_identity' }]]
        }
      });
    } else {
      bot.sendMessage(chatId, 'Добро пожаловать! Используйте специальную ссылку для аутентификации.');
    }
    return;
  }

  // 3. Прямой параметр (Telegram может прислать без "/start")
  if (text && text.includes('.') && text.length > 30 && /^[a-zA-Z0-9+/=._-]+$/.test(text)) {
    await handleStart(chatId, tgId, text);
    return;
  }

  // 4. Ввод ФИО
  const session = userSessions.get(tgId);
  if (session && session.step === 'waiting_name') {
    if (text === '❌ Отмена') {
      bot.sendMessage(chatId, '❌ Регистрация отменена.', {
        reply_markup: { remove_keyboard: true }
      });
      userSessions.delete(tgId);
      return;
    }

    if (!Validator.validateFullName(text)) {
      bot.sendMessage(chatId, MESSAGES.INVALID_NAME);
      return;
    }

    session.full_name = text;
    session.step = 'waiting_consent';

    bot.sendMessage(chatId, MESSAGES.CONSENT_TEXT, {
      parse_mode: 'Markdown',
      reply_markup: {
        inline_keyboard: [
          [{ text: '✅ Принимаю', callback_data: 'accept_consent' }],
          [{ text: '❌ Отклонить', callback_data: 'decline_consent' }]
        ]
      }
    });
  }
});

// ============================================
// Callback (подтверждение)
// ============================================

bot.on('callback_query', async (query) => {
  const chatId = query.message.chat.id;
  const tgId = query.from.id;
  const data = query.data;
  const session = userSessions.get(tgId);

  bot.answerCallbackQuery(query.id);

  if (data === 'confirm_identity') {
    const client = await db.getClientByTgId(tgId);
    if (!client) {
      bot.sendMessage(chatId, '❌ Вы не зарегистрированы.');
      return;
    }

    const contact = await bot.getChat(tgId);
    const phoneNumber = contact.phone_number;

    if (!phoneNumber || !phoneNumber.endsWith(client.phone.slice(-10))) {
      bot.sendMessage(chatId, MESSAGES.PHONE_MISMATCH);
      return;
    }

    bot.editMessageText('✅ Личность подтверждена!', {
      chat_id: chatId,
      message_id: query.message.message_id
    });
    return;
  }

  if (data === 'accept_consent') {
    session.step = 'waiting_phone';
    session.consent_date = new Date().toISOString();

    bot.editMessageText(MESSAGES.CONSENT_ACCEPTED, {
      chat_id: chatId,
      message_id: query.message.message_id
    });

    bot.sendMessage(chatId, 'Подтвердите номер телефона:', {
      reply_markup: {
        keyboard: [[{ text: '📱 Отправить телефон', request_contact: true }]],
        resize_keyboard: true,
        one_time_keyboard: true
      }
    });
  }

  if (data === 'decline_consent') {
    bot.editMessageText(MESSAGES.CONSENT_DECLINED, {
      chat_id: chatId,
      message_id: query.message.message_id
    });
    userSessions.delete(tgId);
  }
});

// ============================================
// Подтверждение телефона
// ============================================

bot.on('contact', async (msg) => {
  const chatId = msg.chat.id;
  const tgId = msg.from.id;
  const contact = msg.contact;
  const session = userSessions.get(tgId);

  if (!session || session.step !== 'waiting_phone') return;

  const phoneDigits = contact.phone_number.replace(/\D/g, '');
  const expectedPhone = session.phone.toString().replace(/\D/g, '');

  if (!phoneDigits.endsWith(expectedPhone.slice(-10))) {
    bot.sendMessage(chatId, MESSAGES.PHONE_MISMATCH);
    return;
  }

  try {
    await db.run(
      `INSERT INTO clients (tg_id, company_id, client_id, phone, full_name, consent_date, auth_status)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [tgId, session.company_id, session.client_id, session.phone, session.full_name, session.consent_date, 'pending']
    );

    const success = await updateClient(session.company_id, session.client_id, session.full_name, session.phone, tgId);

    if (success) {
      await db.run(`UPDATE clients SET auth_status = 'success' WHERE tg_id = ?`, [tgId]);
      bot.sendMessage(chatId, MESSAGES.AUTH_SUCCESS, { reply_markup: { remove_keyboard: true } });
      logger.success('✅ Аутентификация успешна', { tgId, client_id: session.client_id });
    } else {
      addToRetryQueue(session.company_id, session.client_id, tgId, session.full_name, session.phone);
      bot.sendMessage(chatId, MESSAGES.AUTH_PENDING, { reply_markup: { remove_keyboard: true } });
      logger.warn('⚠️ Требуется повторная синхронизация', { client_id: session.client_id });
    }

    userSessions.delete(tgId);
  } catch (err) {
    logger.error('❌ Ошибка при сохранении клиента', { error: err.message, tgId });
    bot.sendMessage(chatId, '❌ Ошибка. Обратитесь к администратору.');
  }
});

// ============================================
// Cron: повторные попытки
// ============================================

cron.schedule('* * * * *', async () => {
  try {
    const queue = await db.getRetryQueue();
    for (const row of queue) {
      const success = await updateClient(row.company_id, row.client_id, row.full_name, row.phone, row.tg_id);
      if (success) {
        await db.run(`UPDATE clients SET auth_status = 'success' WHERE tg_id = ?`, [row.tg_id]);
        await db.removeFromQueue(row.id);
        logger.success('🔁 Успешная повторная синхронизация', { client_id: row.client_id });
      } else {
        const nextRetry = new Date(Date.now() + RETRY_INTERVAL_MINUTES * 60000).toISOString();
        await db.run(
          `UPDATE retry_queue SET retry_count = retry_count + 1, next_retry = ? WHERE id = ?`,
          [nextRetry, row.id]
        );
      }
    }
  } catch (err) {
    logger.error('❌ Ошибка в cron-задаче', { error: err.message });
  }
});

// ============================================
// API маршруты
// ============================================

app.post('/api/generate-link', express.json(), (req, res) => {
  const { company_id, client_id, phone, client_status } = req.body;
  if (!company_id || !client_id || !phone || !client_status) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  if (!Validator.validateIds(company_id, client_id)) {
    return res.status(400).json({ error: 'Invalid IDs' });
  }
  if (!Validator.validatePhone(phone)) {
    return res.status(400).json({ error: 'Invalid phone' });
  }
  if (!Validator.validateClientStatus(client_status)) {
    return res.status(400).json({ error: 'Invalid client_status' });
  }

  const data = {
    company_id: +company_id,
    client_id: +client_id,
    phone: phone.toString(),
    client_status,
    date: new Date().toISOString()
  };

  const link = generateBotLink(data);
  res.json({ success: true, link });
});

app.get('/api/client-progress/:company_id/:client_id', async (req, res) => {
  const { company_id, client_id } = req.params;
  try {
    const row = await db.getClient(company_id, client_id);
    if (row) return res.json({ status: row.auth_status, ...row });

    let progress = null;
    for (const [id, sess] of userSessions) {
      if (sess.company_id == company_id && sess.client_id == client_id) {
        progress = { step: sess.step };
      }
    }
    res.json({ status: progress ? 'in_progress' : 'not_started', progress });
  } catch (err) {
    logger.error('Ошибка API /client-progress', { err });
    res.status(500).json({ error: 'DB error' });
  }
});

app.get('/api/auth-status/:company_id/:client_id', async (req, res) => {
  const { company_id, client_id } = req.params;
  try {
    const row = await db.get(
      `SELECT auth_status, tg_id FROM clients WHERE company_id = ? AND client_id = ?`,
      [company_id, client_id]
    );
    res.json({ auth_status: row?.auth_status || 'not_found', tg_id: row?.tg_id });
  } catch (err) {
    logger.error('Ошибка API /auth-status', { err });
    res.status(500).json({ error: 'DB error' });
  }
});

app.get('/api/stats', async (req, res) => {
  try {
    const row = await db.get(`
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN auth_status='success' THEN 1 ELSE 0 END) as success
      FROM clients
    `);
    res.json({ total: row?.total || 0, success: row?.success || 0 });
  } catch (err) {
    logger.error('Ошибка API /stats', { err });
    res.status(500).json({ error: 'DB error' });
  }
});

// ============================================
// /visit — красивый редирект
// ============================================

app.get('/visit', (req, res) => {
  const { company_id, client_id, phone, client_status } = req.query;

  if (!company_id || !client_id || !phone || !client_status) {
    return res.status(400).send('❌ Не хватает данных');
  }
  if (!Validator.validateIds(+company_id, +client_id)) {
    return res.status(400).send('❌ Неверные ID');
  }
  if (!Validator.validatePhone(phone)) {
    return res.status(400).send('❌ Неверный телефон');
  }
  if (!Validator.validateClientStatus(client_status)) {
    return res.status(400).send('❌ client_status должен быть "new" или "old"');
  }

  const data = {
    company_id: +company_id,
    client_id: +client_id,
    phone: phone.toString(),
    client_status,
    date: new Date().toISOString()
  };

  const link = generateBotLink(data);
  res.redirect(link);
});

// ============================================
// Health и дефолт
// ============================================

app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.get('/', (req, res) => res.json({ service: 'Telegram Auth Bot', status: 'running' }));
app.use((req, res) => res.status(404).json({ error: 'Not Found' }));

// ============================================
// Запуск сервера
// ============================================

const server = app.listen(PORT, '127.0.0.1', () => {
  logger.success('✅ Сервер запущен', {
    port: PORT,
    bot: `@${BOT_USERNAME}`,
    bind: 'localhost only (safe behind nginx)'
  });
});

// Обработка завершения
process.on('SIGINT', async () => {
  logger.info('Остановка сервера...');
  server.close(() => logger.info('HTTP сервер остановлен'));
  await db.close();
  bot.stopPolling();
  logger.info('Бот остановлен');
});

// Глобальные ошибки
process.on('uncaughtException', err => logger.error('uncaughtException', { err }));
process.on('unhandledRejection', err => logger.error('unhandledRejection', { err }));
bot.on('polling_error', err => logger.error('polling_error', { err }));