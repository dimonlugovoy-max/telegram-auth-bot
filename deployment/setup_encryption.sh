#!/bin/bash
# setup_encryption.sh

echo "🔐 Генерация ключа шифрования..."

# Генерация ключа
KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

echo ""
echo "✅ Ключ сгенерирован:"
echo "$KEY"
echo ""

# Проверка существования .env
if [ -f .env ]; then
    # Обновление существующего ключа
    if grep -q "ENCRYPTION_KEY=" .env; then
        # Замена старого ключа
        sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$KEY/" .env
        echo "✅ ENCRYPTION_KEY обновлен в .env"
    else
        # Добавление нового ключа
        echo "ENCRYPTION_KEY=$KEY" >> .env
        echo "✅ ENCRYPTION_KEY добавлен в .env"
    fi
else
    echo "❌ Файл .env не найден!"
    echo "Создайте файл .env и добавьте:"
    echo "ENCRYPTION_KEY=$KEY"
fi