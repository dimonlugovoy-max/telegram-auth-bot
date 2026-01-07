// init.js
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

const envPath = path.join(__dirname, '.env');
const envExamplePath = path.join(__dirname, '.env.example');

console.log('🚀 Инициализация Telegram Auth Bot');
console.log('='.repeat(50));

// Функция для вопросов
function ask(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

async function init() {
  let envContent = '';

  // Проверка существующего .env
  if (fs.existsSync(envPath)) {
    const overwrite = await ask('\n⚠️  Файл .env уже существует. Перезаписать? (yes/no): ');
    if (overwrite.toLowerCase() !== 'yes') {
      console.log('Отменено');
      rl.close();
      return;
    }
    // Создаем бэкап
    fs.copyFileSync(envPath, `${envPath}.backup.${Date.now()}`);
    console.log('💾 Создана резервная копия .env');
  }

  console.log('\n📋 Введите параметры конфигурации:');
  console.log('(Нажмите Enter для пропуска необязательных полей)\n');

  // Сбор данных
  const botToken = await ask('BOT_TOKEN (обязательно): ');
  const botUsername = await ask('BOT_USERNAME (без @): ');
  const bearerToken = await ask('BEARER_TOKEN (YClients): ');
  const partnerToken = await ask('PARTNER_TOKEN (YClients): ');
  const webhookUrl = await ask('WEBHOOK_URL (опционально): ');
  const port = await ask('PORT (по умолчанию 3000): ') || '3000';

  // Автогенерация ключа
  console.log('\n🔐 Генерация ENCRYPTION_KEY...');
  const encryptionKey = crypto.randomBytes(32).toString('hex');
  console.log('✅ Ключ сгенерирован:', encryptionKey);

  // Формирование .env
  envContent = `# ========================================
# Telegram Bot Configuration
# ========================================
BOT_TOKEN=${botToken}
BOT_USERNAME=${botUsername}

# ========================================
# Security
# ========================================
# Ключ шифрования (сгенерирован автоматически ${new Date().toISOString()})
ENCRYPTION_KEY=${encryptionKey}

# ========================================
# YClients API
# ========================================
BEARER_TOKEN=${bearerToken}
PARTNER_TOKEN=${partnerToken}

# ========================================
# Webhook
# ========================================
WEBHOOK_URL=${webhookUrl}

# ========================================
# Server
# ========================================
PORT=${port}
NODE_ENV=production

# ========================================
# Advanced Settings
# ========================================
LINK_EXPIRY_HOURS=24
RETRY_INTERVAL_MINUTES=5
API_TIMEOUT_MS=15000
DATA_RETENTION_DAYS=90
`;

  // Сохранение .env
  fs.writeFileSync(envPath, envContent);
  console.log('\n✅ Файл .env создан успешно!');

  // Создание .env.example
  const exampleContent = envContent.replace(/=.*/g, '=');
  fs.writeFileSync(envExamplePath, exampleContent);
  console.log('✅ Файл .env.example создан');

  console.log('\n' + '='.repeat(50));
  console.log('✅ Инициализация завершена!');
  console.log('');
  console.log('Следующие шаги:');
  console.log('1. Проверьте .env файл: nano .env');
  console.log('2. Установите зависимости: npm install');
  console.log('3. Запустите бота: npm start');
  console.log('='.repeat(50));

  rl.close();
}

init().catch(error => {
  console.error('❌ Ошибка инициализации:', error);
  rl.close();
  process.exit(1);
});