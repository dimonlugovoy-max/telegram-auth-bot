// scripts/setup-env.js
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const envPath = path.join(__dirname, '..', '.env');
const envExamplePath = path.join(__dirname, '..', '.env.example');

console.log('🔧 Проверка конфигурации окружения...');

// Создание .env из .env.example если не существует
if (!fs.existsSync(envPath)) {
  console.log('📝 Создание .env файла...');
  
  if (fs.existsSync(envExamplePath)) {
    fs.copyFileSync(envExamplePath, envPath);
    console.log('✅ Создан .env из .env.example');
  } else {
    // Создание минимального .env
    const minimalEnv = `# Telegram Auth Bot Configuration
# Сгенерировано автоматически: ${new Date().toISOString()}

# ========================================
# Telegram Bot Configuration
# ========================================
BOT_TOKEN=
BOT_USERNAME=

# ========================================
# Security
# ========================================
ENCRYPTION_KEY=

# ========================================
# YClients API
# ========================================
BEARER_TOKEN=
PARTNER_TOKEN=

# ========================================
# Webhook
# ========================================
WEBHOOK_URL=

# ========================================
# Server
# ========================================
PORT=3000
NODE_ENV=production

# ========================================
# Advanced Settings
# ========================================
LINK_EXPIRY_HOURS=24
RETRY_INTERVAL_MINUTES=5
API_TIMEOUT_MS=15000
DATA_RETENTION_DAYS=90
`;
    fs.writeFileSync(envPath, minimalEnv);
    console.log('✅ Создан новый .env файл');
  }
}

// Чтение .env
let envContent = fs.readFileSync(envPath, 'utf8');

// Проверка и генерация ENCRYPTION_KEY
const keyRegex = /ENCRYPTION_KEY=([a-f0-9]{64})/;
const match = envContent.match(keyRegex);

if (!match || match[1].length !== 64) {
  console.log('🔐 Генерация ENCRYPTION_KEY...');
  
  const newKey = crypto.randomBytes(32).toString('hex');
  
  if (envContent.includes('ENCRYPTION_KEY=')) {
    // Замена существующего ключа
    envContent = envContent.replace(/ENCRYPTION_KEY=.*/, `ENCRYPTION_KEY=${newKey}`);
  } else {
    // Добавление нового ключа
    envContent += `\n# Ключ шифрования (сгенерирован автоматически ${new Date().toISOString()})\nENCRYPTION_KEY=${newKey}\n`;
  }
  
  fs.writeFileSync(envPath, envContent);
  console.log('✅ ENCRYPTION_KEY сгенерирован и сохранен');
  console.log(`🔑 Ключ: ${newKey}`);
} else {
  console.log('✅ ENCRYPTION_KEY найден и валиден');
}

console.log('');
console.log('📋 Следующие шаги:');
console.log('1. Откройте .env и заполните обязательные поля:');
console.log('   - BOT_TOKEN');
console.log('   - BOT_USERNAME');
console.log('   - BEARER_TOKEN');
console.log('   - PARTNER_TOKEN');
console.log('2. Запустите бота: npm start');
console.log('');