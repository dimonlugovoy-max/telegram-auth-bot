// scripts/generateApiKey.js (генерация API ключа)

const crypto = require('crypto');

const apiKey = crypto.randomBytes(32).toString('hex');

console.log('🔑 Сгенерирован новый API ключ:');
console.log(apiKey);
console.log('');
console.log('Добавьте его в .env файл:');
console.log(`API_KEYS=${apiKey}`);
console.log('');
console.log('Для нескольких ключей разделяйте запятыми:');
console.log(`API_KEYS=${apiKey},another_key`);