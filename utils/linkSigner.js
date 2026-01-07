const crypto = require('crypto');
const logger = require('./logger');

const SECRET_KEY = process.env.ENCRYPTION_KEY;

if (!SECRET_KEY || SECRET_KEY.length !== 64) {
  logger.error('❌ ENCRYPTION_KEY не настроен или неверной длины. Используйте: node scripts/generateApiKey.js');
  throw new Error('ENCRYPTION_KEY required (64 hex chars)');
}

class LinkSigner {
  /**
   * Подписывает данные и возвращает base64-url-safe строку
   */
  static sign(data) {
    const payload = JSON.stringify(data);
    const buffer = Buffer.from(payload);
    const base64 = buffer.toString('base64url');

    const signature = crypto
      .createHmac('sha256', SECRET_KEY)
      .update(base64)
      .digest('hex')
      .substring(0, 16); // Укорачиваем для краткости

    return `${base64}.${signature}`;
  }

  /**
   * Проверяет и расшифровывает подпись
   */
  static verify(signedData) {
    try {
      const [base64, signature] = signedData.split('.');
      if (!base64 || !signature) return null;

      const expected = crypto
        .createHmac('sha256', SECRET_KEY)
        .update(base64)
        .digest('hex')
        .substring(0, 16);

      if (signature !== expected) {
        logger.warn('❌ Подпись ссылки невалидна', { provided: signature, expected });
        return null;
      }

      const payload = Buffer.from(base64, 'base64url').toString();
      return JSON.parse(payload);
    } catch (err) {
      logger.error('❌ Ошибка проверки ссылки', { error: err.message });
      return null;
    }
  }
}

module.exports = LinkSigner;