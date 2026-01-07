# install_node.sh

#!/bin/bash

echo "📦 Установка Node.js 20.x LTS"
echo "=============================="

# Установка NodeSource репозитория
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

# Установка Node.js
apt install -y nodejs

# Проверка установки
node --version
npm --version

# Установка глобальных пакетов
npm install -g pm2

# Настройка PM2 startup
pm2 startup systemd -u botuser --hp /home/botuser

echo "✅ Node.js установлен успешно!"