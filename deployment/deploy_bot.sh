# deploy_bot.sh

#!/bin/bash

echo "🚀 Развертывание Telegram Auth Bot"
echo "===================================="

BOT_USER="botuser"
BOT_DIR="/home/$BOT_USER/telegram-auth-bot"

# Переключение на пользователя botuser
su - $BOT_USER << 'EOF'

# Клонирование репозитория (или создание директории)
cd ~
mkdir -p telegram-auth-bot
cd telegram-auth-bot

# Если используете Git:
# git clone https://github.com/yourusername/telegram-auth-bot.git .

# Установка зависимостей
npm install

# Создание .env файла
cat > .env << 'ENVEOF'
BOT_TOKEN=your_bot_token
BOT_USERNAME=your_bot_username
ENCRYPTION_KEY=generate_with_command_below
BEARER_TOKEN=your_yclients_bearer_token
PARTNER_TOKEN=your_yclients_partner_token
WEBHOOK_URL=https://your-domain.com/api/webhook
PORT=3000
NODE_ENV=production
DATA_RETENTION_DAYS=90
ENVEOF

# Генерация ключа шифрования
echo "ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")" >> .env.tmp
echo "Скопируйте ключ из .env.tmp в .env файл"

# Создание директорий
mkdir -p logs backups

# Запуск через PM2
pm2 start index.js --name telegram-auth-bot
pm2 save

EOF

echo ""
echo "✅ Развертывание завершено!"
echo ""
echo "Следующие шаги:"
echo "1. Отредактируйте /home/$BOT_USER/telegram-auth-bot/.env"
echo "2. Перезапустите бота: pm2 restart telegram-auth-bot"
