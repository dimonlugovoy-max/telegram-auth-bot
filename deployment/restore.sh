#!/bin/bash
# restore.sh (восстановление из резервной копии)

echo "♻️  Восстановление БД из резервной копии"
echo "========================================="

BACKUP_DIR="./backups"

# Список доступных бэкапов
echo "Доступные резервные копии:"
ls -lh $BACKUP_DIR/*.tar.gz 2>/dev/null || {
    echo "❌ Резервные копии не найдены"
    exit 1
}

echo ""
read -p "Введите имя файла для восстановления (например: bot_20250115_120000.db.tar.gz): " BACKUP_NAME

BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

if [ ! -f "$BACKUP_PATH" ]; then
    echo "❌ Файл не найден: $BACKUP_PATH"
    exit 1
fi

# Подтверждение
echo ""
echo "⚠️  ВНИМАНИЕ: Текущая БД будет перезаписана!"
read -p "Продолжить? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Отменено"
    exit 0
fi

# Остановка бота
echo ""
echo "🛑 Остановка бота..."
pm2 stop telegram-auth-bot

# Создание бэкапа текущей БД
if [ -f bot.db ]; then
    echo "💾 Создание резервной копии текущей БД..."
    cp bot.db "bot.db.before_restore.$(date +%Y%m%d_%H%M%S)"
fi

# Распаковка
echo "📦 Распаковка резервной копии..."
tar -xzf "$BACKUP_PATH" -C $BACKUP_DIR

# Восстановление
EXTRACTED_FILE=$(basename "$BACKUP_NAME" .tar.gz)
cp "$BACKUP_DIR/$EXTRACTED_FILE" bot.db
rm "$BACKUP_DIR/$EXTRACTED_FILE"

echo "✅ БД восстановлена"

# Запуск бота
echo ""
echo "▶️  Запуск бота..."
pm2 start telegram-auth-bot

echo ""
echo "✅ Восстановление завершено!"