// scripts/checkHealth.js (проверка здоровья системы)

require('dotenv').config();
const axios = require('axios');
const sqlite3 = require('sqlite3').verbose();

const BASE_URL = `http://localhost:${process.env.PORT || 3000}`;
const db = new sqlite3.Database('./bot.db');

async function checkHealth() {
  console.log('🏥 Проверка здоровья системы');
  console.log('='.repeat(50));

  const checks = {
    api: false,
    database: false,
    queue: false,
    disk: false
  };

  // 1. Проверка API
  try {
    const response = await axios.get(`${BASE_URL}/health`, { timeout: 5000 });
    checks.api = response.data.status === 'ok';
    console.log(`✅ API доступен: ${response.data.bot_active ? 'Бот активен' : 'Бот неактивен'}`);
  } catch (error) {
    console.error('❌ API недоступен:', error.message);
  }

  // 2. Проверка базы данных
  await new Promise((resolve) => {
    db.get('SELECT COUNT(*) as count FROM clients', (err, row) => {
      if (err) {
        console.error('❌ Ошибка БД:', err.message);
      } else {
        checks.database = true;
        console.log(`✅ База данных: ${row.count} клиентов`);
      }
      resolve();
    });
  });

  // 3. Проверка очереди
  await new Promise((resolve) => {
    db.get('SELECT COUNT(*) as count FROM retry_queue', (err, row) => {
      if (err) {
        console.error('❌ Ошибка очереди:', err.message);
      } else {
        const queueSize = row.count;
        if (queueSize > 50) {
          console.log(`⚠️  Очередь: ${queueSize} задач (переполнение!)`);
        } else if (queueSize > 0) {
          console.log(`✅ Очередь: ${queueSize} задач`);
        } else {
          console.log(`✅ Очередь пуста`);
        }
        checks.queue = queueSize < 100; // Критичный порог
      }
      resolve();
    });
  });

  // 4. Проверка дискового пространства
  const fs = require('fs');
  const stats = fs.statSync('./bot.db');
  const fileSizeMB = (stats.size / (1024 * 1024)).toFixed(2);
  
  if (fileSizeMB > 100) {
    console.log(`⚠️  Размер БД: ${fileSizeMB} MB (требуется очистка)`);
    checks.disk = false;
  } else {
    console.log(`✅ Размер БД: ${fileSizeMB} MB`);
    checks.disk = true;
  }

  // 5. Проверка webhook
  if (process.env.WEBHOOK_URL) {
    try {
      await axios.get(process.env.WEBHOOK_URL, { 
        timeout: 5000,
        validateStatus: () => true // Принимаем любой статус
      });
      console.log(`✅ Webhook URL доступен`);
    } catch (error) {
      console.log(`⚠️  Webhook URL недоступен: ${error.message}`);
    }
  } else {
    console.log(`⚠️  Webhook URL не настроен`);
  }

  console.log('\n' + '='.repeat(50));
  
  const allHealthy = Object.values(checks).every(v => v);
  
  if (allHealthy) {
    console.log('✅ Все системы работают нормально');
    process.exit(0);
  } else {
    console.log('❌ Обнаружены проблемы!');
    console.log('Статус проверок:', checks);
    process.exit(1);
  }
}

checkHealth().catch(error => {
  console.error('Критическая ошибка:', error);
  process.exit(1);
});