const crypto = require('crypto');

const API_KEYS = process.env.API_KEYS ? process.env.API_KEYS.split(',').map(k => k.trim()) : [];

function safeCompare(a, b) {
  const buffA = Buffer.from(a);
  const buffB = Buffer.from(b);
  if (buffA.length !== buffB.length) return false;
  return crypto.timingSafeEqual(buffA, buffB);
}

function validateApiKey(req, res, next) {
  if (API_KEYS.length === 0) return next();

  const apiKey = req.headers['x-api-key'];
  if (!apiKey || !API_KEYS.some(key => safeCompare(key, apiKey))) {
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

module.exports = { validateApiKey, generateApiKey };