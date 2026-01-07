#!/bin/bash
# deploy.sh

echo "🚀 Развертывание Telegram Auth Bot"
echo "===================================="

# Проверка окружения
if [ "$1" == "production" ]; then
    ENV="production"
    echo "📍 Режим: PRODUCTION"
else
    ENV="development"
    echo "📍 Режим: DEVELOPMENT"
fi

# Остановка существующего процесса
echo ""
echo "🛑 Остановка существующих процессов..."
pm2 stop telegram-auth-bot 2>/dev/null || true
pm2 delete telegram-auth-bot 2>/dev/null || true

# Установка/обновление зависимостей
echo ""
echo "📦 Установка зависимостей..."
if [ "$ENV" == "production" ]; then
    npm ci --only=production
else
    npm install
fi

# Проверка .env
if [ ! -f .env ]; then
    echo "❌ Файл .env не найден!"
    exit 1
fi

# Резервное копирование БД
if [ -f bot.db ]; then
    echo ""
    echo "💾 Создание резервной копии БД..."
    cp bot.db "bot.db.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Запуск через PM2
echo ""
echo "▶️  Запуск через PM2..."
if [ "$ENV" == "production" ]; then
    pm2 start index.js --name telegram-auth-bot \
        --time \
        --max-memory-restart 500M \
        --restart-delay 5000
else
    pm2 start index.js --name telegram-auth-bot --watch
fi

# Сохранение конфигурации PM2
pm2 save

# Настройка автозапуска
if [ "$ENV" == "production" ]; then
    echo ""
    echo "⚙️  Настройка автозапуска..."
    pm2 startup
fi

echo ""
echo "✅ Развертывание завершено!"
echo ""
echo "Полезные команды:"
echo "  pm2 logs telegram-auth-bot  - просмотр логов"
echo "  pm2 status                   - статус процессов"
echo "  pm2 restart telegram-auth-bot - перезапуск"
echo "  pm2 stop telegram-auth-bot   - остановка"
# Dockerfile

FROM node:18-alpine

# Метаданные
LABEL maintainer="your-email@example.com"
LABEL description="Telegram Auth Bot with YClients integration"

# Создание рабочей директории
WORKDIR /app

# Копирование package файлов
COPY package*.json ./

# Установка зависимостей
RUN npm ci --only=production && \
    npm cache clean --force

# Копирование исходного кода
COPY . .

# Создание непривилегированного пользователя
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

# Переключение на непривилегированного пользователя
USER nodejs

# Открытие порта
EXPOSE 3000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Запуск приложения
CMD ["node", "index.js"]