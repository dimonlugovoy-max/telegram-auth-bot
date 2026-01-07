const sqlite3 = require('sqlite3').verbose();
const logger = require('./logger');

class Database {
  constructor(dbPath = './bot.db') {
    this.db = new sqlite3.Database(dbPath, (err) => {
      if (err) {
        logger.error('Ошибка подключения к БД', { error: err.message });
      } else {
        logger.success('✅ Подключение к БД установлено', { path: dbPath });
      }
    });
  }

  run(sql, params = []) {
    return new Promise((resolve, reject) => {
      this.db.run(sql, params, function (err) {
        if (err) {
          logger.error('Ошибка SQL run', { sql, params, error: err.message });
          reject(err);
        } else {
          resolve({ lastID: this.lastID, changes: this.changes });
        }
      });
    });
  }

  get(sql, params = []) {
    return new Promise((resolve, reject) => {
      this.db.get(sql, params, (err, row) => {
        if (err) {
          logger.error('Ошибка SQL get', { sql, params, error: err.message });
          reject(err);
        } else {
          resolve(row);
        }
      });
    });
  }

  all(sql, params = []) {
    return new Promise((resolve, reject) => {
      this.db.all(sql, params, (err, rows) => {
        if (err) {
          logger.error('Ошибка SQL all', { sql, params, error: err.message });
          reject(err);
        } else {
          resolve(rows);
        }
      });
    });
  }

  close() {
    return new Promise((resolve, reject) => {
      this.db.close((err) => {
        if (err) {
          logger.error('Ошибка закрытия БД', { error: err.message });
          reject(err);
        } else {
          logger.info('БД закрыта');
          resolve();
        }
      });
    });
  }

  async getClient(companyId, clientId) {
    return this.get(
      'SELECT * FROM clients WHERE company_id = ? AND client_id = ? ORDER BY created_at DESC LIMIT 1',
      [companyId, clientId]
    );
  }

  async getClientByTgId(tgId) {
    return this.get(
      'SELECT * FROM clients WHERE tg_id = ? ORDER BY created_at DESC LIMIT 1',
      [tgId]
    );
  }

  async updateClientStatus(tgId, status) {
    return this.run('UPDATE clients SET auth_status = ? WHERE tg_id = ?', [status, tgId]);
  }

  async getRetryQueue() {
    const now = new Date().toISOString();
    return this.all(
      'SELECT * FROM retry_queue WHERE next_retry <= ? ORDER BY next_retry ASC',
      [now]
    );
  }

  async removeFromQueue(id) {
    return this.run('DELETE FROM retry_queue WHERE id = ?', [id]);
  }
}

module.exports = Database;