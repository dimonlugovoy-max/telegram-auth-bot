const rateLimitMap = new Map();

function rateLimit(options = {}) {
  const {
    windowMs = 60000,
    max = 100,
    message = 'Too many requests'
  } = options;

  return (req, res, next) => {
    const key = req.ip || req.socket.remoteAddress;
    const now = Date.now();

    if (!rateLimitMap.has(key)) {
      rateLimitMap.set(key, { count: 1, resetTime: now + windowMs });
      return next();
    }

    const data = rateLimitMap.get(key);

    if (now > data.resetTime) {
      data.count = 1;
      data.resetTime = now + windowMs;
      return next();
    }

    if (data.count >= max) {
      return res.status(429).json({
        error: 'Too Many Requests',
        message,
        retryAfter: Math.ceil((data.resetTime - now) / 1000)
      });
    }

    data.count++;
    next();
  };
}

// Очистка каждые 5 минут
setInterval(() => {
  const now = Date.now();
  for (const [key, data] of rateLimitMap) {
    if (now > data.resetTime) {
      rateLimitMap.delete(key);
    }
  }
}, 300000);

module.exports = rateLimit;