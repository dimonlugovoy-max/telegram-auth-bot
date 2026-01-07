require('dotenv').config();
const sqlite3 = require('sqlite3').verbose();
const logger = require('../utils/logger');

const db = new sqlite3.Database('./bot.db');

db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    executed_at TEXT DEFAULT CURRENT_TIMESTAMP
  )`);
});

const migrations = [
  {
    name: '001_add_webhook_sent_column',
    up: `ALTER TABLE clients ADD COLUMN webhook_sent INTEGER DEFAULT 0`,
    down: `ALTER TABLE clients DROP COLUMN webhook_sent`
  },
  {
    name: '002_add_indexes',
    up: `
      CREATE INDEX IF NOT EXISTS idx_clients_company_client ON clients(company_id, client_id);
      CREATE INDEX IF NOT EXISTS idx_clients_auth_status ON clients(auth_status);
      CREATE INDEX IF NOT EXISTS idx_retry_queue_next_retry ON retry_queue(next_retry);
    `,
    down: `
      DROP INDEX IF EXISTS idx_clients_company_client;
      DROP INDEX IF EXISTS idx_clients_auth_status;
      DROP INDEX IF EXISTS idx_retry_queue_next_retry;
    `
  }
];

async function runMigration(migration) {
  return new Promise((resolve, reject) => {
    db.get('SELECT * FROM migrations WHERE name = ?', [migration.name], (err, row) => {
      if (err) return reject(err);
      if (row) {
        logger.warn(`Миграция пропущена`, { name: migration.name });
        return resolve();
      }

      db.exec(migration.up, (err) => {
        if (err) {
          logger.error(`Ошибка миграции`, { name: migration.name, error: err.message });
          return reject(err);
        }

        db.run('INSERT INTO migrations (name) VALUES (?)', [migration.name], (err) => {
          if (err) return reject(err);
          logger.success(`Миграция выполнена`, { name: migration.name });
          resolve();
        });
      });
    });
  });
}

async function migrate() {
  logger.info('Запуск миграций...');
  for (const migration of migrations) {
    try {
      await runMigration(migration);
    } catch (error) {
      logger.error('Критическая ошибка миграции', { error });
      process.exit(1);
    }
  }
  logger.success('Все миграции выполнены');
  db.close();
}

if (require.main === module) migrate();

module.exports = { migrate };