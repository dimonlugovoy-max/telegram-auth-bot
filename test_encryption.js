// test_encryption.js
require('dotenv').config();
const crypto = require('crypto');

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;

// Проверка наличия ключа
if (!ENCRYPTION_KEY) {
  console.error('❌ ENCRYPTION_KEY не установлен в .env');
  process.exit(1);
}

// Проверка длины
if (ENCRYPTION_KEY.length !== 64) {
  console.error(`❌ Неверная длина ключа: ${ENCRYPTION_KEY.length} (должно быть 64)`);
  process.exit(1);
}

console.log('✅ ENCRYPTION_KEY установлен корректно');
console.log(`Длина: ${ENCRYPTION_KEY.length} символов`);

// Тест шифрования
function encrypt(text) {
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
  let encrypted = cipher.update(JSON.stringify(text));
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return iv.toString('hex') + ':' + encrypted.toString('hex');
}

function decrypt(text) {
  const parts = text.split(':');
  const iv = Buffer.from(parts.shift(), 'hex');
  const encryptedText = Buffer.from(parts.join(':'), 'hex');
  const decipher = crypto.createDecipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
  let decrypted = decipher.update(encryptedText);
  decrypted = Buffer.concat([decrypted, decipher.final()]);
  return JSON.parse(decrypted.toString());
}

// Тестовые данные
const testData = {
  company_id: 123456,
  client_id: 789012,
  phone: '79261234567',
  client_status: 'new',
  date: new Date().toISOString()
};

console.log('\n📋 Тестовые данные:', testData);

// Шифрование
const encrypted = encrypt(testData);
console.log('\n🔐 Зашифровано:', encrypted.substring(0, 50) + '...');

// Расшифровка
const decrypted = decrypt(encrypted);
console.log('\n🔓 Расшифровано:', decrypted);

// Проверка совпадения
if (JSON.stringify(testData) === JSON.stringify(decrypted)) {
  console.log('\n✅ Тест шифрования пройден успешно!');
} else {
  console.error('\n❌ Ошибка: данные не совпадают после расшифровки');
}