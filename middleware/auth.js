// middleware/auth.js (опциональная аутентификация для API)

const crypto = require('crypto');

const API_KEYS = process.env.API_KEYS ? process.env.API_KEYS.split(',') : [];

function validateApiKey(req, res, next) {
  // Если API ключи не настроены, пропускаем проверку
  if (API_KEYS.length === 0) {
    return next();
  }

  const apiKey = req.headers['x-api-key'];

  if (!apiKey || !API_KEYS.includes(apiKey)) {
    return res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid or missing API key'
    });
  }

  next();
}

function generateApiKey() {
  return crypto.randomBytes(32).toString('hex');
}

module.exports = {
  validateApiKey,
  generateApiKey
};