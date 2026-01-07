#!/bin/bash
# quick_setup.sh

echo "🚀 Быстрая настройка Telegram Auth Bot"
echo "========================================"

ENV_FILE=".env"

# Функция генерации ключа
generate_key() {
    node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
}

# Проверка существования .env
if [ -f "$ENV_FILE" ]; then
    read -p "⚠️  Файл .env существует. Перезаписать? (yes/no): " OVERWRITE
    if [ "$OVERWRITE" != "yes" ]; then
        echo "Отменено"
        exit 0
    fi
    # Бэкап
    cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%s)"
    echo "💾 Создан бэкап .env"
fi

# Ввод данных
echo ""
echo "📋 Введите параметры:"
echo ""

read -p "BOT_TOKEN: " BOT_TOKEN
read -p "BOT_USERNAME (без @): " BOT_USERNAME
read -p "BEARER_TOKEN: " BEARER_TOKEN
read -p "PARTNER_TOKEN: " PARTNER_TOKEN
read -p "WEBHOOK_URL (опционально): " WEBHOOK_URL
read -p "PORT (по умолчанию 3000): " PORT
PORT=${PORT:-3000}

# Генерация ключа
echo ""
echo "🔐 Генерация ENCRYPTION_KEY..."
ENCRYPTION_KEY=$(generate_key)
echo "✅ Ключ сгенерирован: $ENCRYPTION_KEY"

# Создание .env
cat > "$ENV_FILE" << EOF
# ========================================
# Telegram Bot Configuration
# ========================================
BOT_TOKEN=$BOT_TOKEN
BOT_USERNAME=$BOT_USERNAME

# ========================================
# Security
# ========================================
# Ключ шифрования (сгенерирован $(date))
ENCRYPTION_KEY=$ENCRYPTION_KEY

# ========================================
# YClients API
# ========================================
BEARER_TOKEN=$BEARER_TOKEN
PARTNER_TOKEN=$PARTNER_TOKEN

# ========================================
# Webhook
# ========================================
WEBHOOK_URL=$WEBHOOK_URL

# ========================================
# Server
# ========================================
PORT=$PORT
NODE_ENV=production

# ========================================
# Advanced Settings
# ========================================
LINK_EXPIRY_HOURS=24
RETRY_INTERVAL_MINUTES=5
API_TIMEOUT_MS=15000
DATA_RETENTION_DAYS=90
EOF

echo ""
echo "✅ Файл .env создан успешно!"
echo ""
echo "========================================"
echo "Следующие шаги:"
echo "1. Установите зависимости: npm install"
echo "2. Запустите бота: npm start"
echo "========================================"