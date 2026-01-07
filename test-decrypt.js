const crypto = require('crypto');
require('dotenv').config();

const ENCRYPTION_KEY = process.env.ENCRYPTION_KEY;

function decrypt(text) {
  try {
    const parts = text.split(':');
    const iv = Buffer.from(parts.shift(), 'hex');
    const encryptedText = Buffer.from(parts.join(':'), 'hex');
    const decipher = crypto.createDecipheriv('aes-256-cbc', Buffer.from(ENCRYPTION_KEY, 'hex'), iv);
    let decrypted = decipher.update(encryptedText);
    decrypted = Buffer.concat([decrypted, decipher.final()]);
    return JSON.parse(decrypted.toString());
  } catch (e) {
    console.error('❌ Ошибка:', e.message);
    return null;
  }
}

// Ваш start-параметр (без `start=`)
const param = 'MGFjMWMxNDIyN2Y1ZmZjMjJiZDZjZTBkOTY0ODRhYTg6M2Q4Nzg0ZjljYjczNjFlNGRkMmUxMzU2ZTU0YjcyOGFkY2NmZmRlOTRlYTE4NGQxZjUzYjExOTIwYWQ1MzA4NzU3NWYxNzMyZWZlYTUxOTk3MmFlNDUyOGZkZWFiYjgzN2JhMTg2YWQxNjZiYWRhNzdlN2VjNGM0ODFlMTQ3NWI2MzY2MDJlNWQ2ODUwN2EyNzJiNjI4MjI0ZWIzMTk2N2YwMjE0YzE2ZWM1NmY2NGE0ZGFhMzIxOTM5MThmOWMyODZkZmRkMjUyYjQyY2M1MDk1NGEyOTQ3MGYzYzQ2YjIwYTMxNmRhZTdkYWRjZTNjYzlkNDI5YzA3NjBkYzU1Ng';

// Декодируем base64url → base64 → hex
const base64 = param.replace(/-/g, '+').replace(/_/g, '/');
const raw = Buffer.from(base64, 'base64').toString('hex');
console.log('🔍 Hex:', raw);

// Теперь расшифровываем
const decoded = Buffer.from(base64, 'base64').toString();
console.log('🔍 Раскодировано:', decoded);

const data = decrypt(decoded);
console.log('🔓 Результат:', data);