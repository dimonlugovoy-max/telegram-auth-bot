#!/bin/bash
# update.sh (обновление бота)

echo "🔄 Обновление Telegram Auth Bot"
echo "================================"

# Проверка git репозитория
if [ ! -d ".git" ]; then
    echo "❌ Не git репозиторий"
    exit 1
fi

# Создание бэкапа перед обновлением
echo "💾 Создание резервной копии..."
./backup.sh

# Получение изменений
echo ""
echo "📥 Получение обновлений..."
git fetch origin

# Показ изменений
echo ""
echo "📋 Доступные обновления:"
git log HEAD..origin/main --oneline

read -p "Продолжить обновление? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Отменено"
    exit 0
fi

# Остановка бота
echo ""
echo "🛑 Остановка бота..."
pm2 stop telegram-auth-bot

# Применение обновлений
echo "⬇️  Применение обновлений..."
git pull origin main

# Обновление зависимостей
echo "📦 Обновление зависимостей..."
npm install

# Миграция БД (если есть)
if [ -f "migrations/migrate.js" ]; then
    echo "🔄 Выполнение миграций..."
    node migrations/migrate.js
fi

# Запуск бота
echo ""
echo "▶️  Запуск бота..."
pm2 restart telegram-auth-bot

# Проверка статуса
sleep 3
pm2 status telegram-auth-bot

echo ""
echo "✅ Обновление завершено!"
echo "Версия: $(git describe --tags --always)"