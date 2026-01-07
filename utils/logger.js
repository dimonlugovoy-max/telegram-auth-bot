const fs = require('fs');
const path = require('path');

const LOG_DIR = path.join(__dirname, '../logs');
if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

class Logger {
  constructor() {
    this.logFile = path.join(LOG_DIR, 'app.log');
    this.errorFile = path.join(LOG_DIR, 'error.log');
  }

  formatMessage(level, message, data = null) {
    const timestamp = new Date().toISOString();
    const logData = data ? JSON.stringify(data) : '';
    return `[${timestamp}] [${level}] ${message} ${logData}\n`;
  }

  writeToFile(filename, content) {
    try {
      fs.appendFileSync(filename, content, 'utf8');
    } catch (err) {
      console.error('❌ Ошибка записи лога', err);
    }
  }

  info(message, data) {
    const formatted = this.formatMessage('INFO', message, data);
    console.log(formatted.trim());
    this.writeToFile(this.logFile, formatted);
  }

  error(message, data) {
    const formatted = this.formatMessage('ERROR', message, data);
    console.error(formatted.trim());
    this.writeToFile(this.errorFile, formatted);
  }

  warn(message, data) {
    const formatted = this.formatMessage('WARN', message, data);
    console.warn(formatted.trim());
    this.writeToFile(this.logFile, formatted);
  }

  success(message, data) {
    const formatted = this.formatMessage('SUCCESS', message, data);
    console.log(formatted.trim());
    this.writeToFile(this.logFile, formatted);
  }
}

module.exports = new Logger();