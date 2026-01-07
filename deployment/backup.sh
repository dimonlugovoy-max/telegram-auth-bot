#!/bin/bash
# backup.sh (скрипт резервного копирования)

echo "💾 Резервное копирование БД..."

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_FILE="bot.db"
BACKUP_FILE="$BACKUP_DIR/bot_${TIMESTAMP}.db"

# Создание директории для бэкапов
mkdir -p $BACKUP_DIR

# Копирование БД
if [ -f $DB_FILE ]; then
    cp $DB_FILE $BACKUP_FILE
    echo "✅ Создан бэкап: $BACKUP_FILE"
    
    # Удаление старых бэкапов (старше 30 дней)
    find $BACKUP_DIR -name "bot_*.db" -mtime +30 -delete
    echo "🗑️  Удалены бэкапы старше 30 дней"
else
    echo "❌ Файл БД не найден: $DB_FILE"
    exit 1
fi

# Архивация
tar -czf "$BACKUP_FILE.tar.gz" -C $BACKUP_DIR "bot_${TIMESTAMP}.db"
rm $BACKUP_FILE
echo "📦 Создан архив: $BACKUP_FILE.tar.gz"

echo "✅ Резервное копирование завершено!"