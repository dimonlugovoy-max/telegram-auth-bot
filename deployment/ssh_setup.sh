# ssh_setup.sh

#!/bin/bash

echo "🔧 Первоначальная настройка Ubuntu 22.04"
echo "========================================"

# Обновление системы
echo "📦 Обновление системы..."
apt update && apt upgrade -y

# Установка необходимых пакетов
echo "📦 Установка базовых пакетов..."
apt install -y curl wget git build-essential ufw nano htop

# Настройка файрвола
echo "🔥 Настройка firewall..."
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # Node.js (временно для тестирования)
ufw --force enable

# Создание пользователя для бота
echo "👤 Создание пользователя botuser..."
adduser --disabled-password --gecos "" botuser
usermod -aG sudo botuser

# Настройка swap (для серверов с 1GB RAM)
echo "💾 Настройка swap..."
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Настройка timezone
echo "🕐 Настройка timezone (Moscow)..."
timedatectl set-timezone Europe/Moscow

echo ""
echo "✅ Базовая настройка завершена!"
echo "Перезагрузите сервер: reboot"