// scripts/cleanup.js (очистка старых данных)

require('dotenv').config();
const sqlite3 = require('sqlite3').verbose();

const db = new sqlite3.Database('./bot.db');

const DAYS_TO_KEEP = parseInt(process.env.DATA_RETENTION_DAYS || '90');

console.log(`🧹 Очистка данных старше ${DAYS_TO_KEEP} дней...`);

const cutoffDate = new Date();
cutoffDate.setDate(cutoffDate.getDate() - DAYS_TO_KEEP);
const cutoffISO = cutoffDate.toISOString();

// Удаление старых успешных записей клиентов
db.run(
  `DELETE FROM clients WHERE auth_status = 'success' AND created_at < ?`,
  [cutoffISO],
  function(err) {
    if (err) {
      console.error('❌ Ошибка удаления клиентов:', err);
    } else {
      console.log(`✅ Удалено ${this.changes} старых записей клиентов`);
    }
  }
);

// Удаление зависших задач из очереди (старше 7 дней)
const queueCutoff = new Date();
queueCutoff.setDate(queueCutoff.getDate() - 7);

db.run(
  `DELETE FROM retry_queue WHERE created_at < ?`,
  [queueCutoff.toISOString()],
  function(err) {
    if (err) {
      console.error('❌ Ошибка очистки очереди:', err);
    } else {
      console.log(`✅ Удалено ${this.changes} зависших задач из очереди`);
    }
    
    db.close();
    console.log('✅ Очистка завершена');
  }
);