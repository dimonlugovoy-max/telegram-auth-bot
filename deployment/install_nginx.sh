# install_nginx.sh

#!/bin/bash

echo "🌐 Установка Nginx"
echo "=================="

# Установка Nginx
apt install -y nginx

# Запуск и автозапуск
systemctl start nginx
systemctl enable nginx

# Проверка статуса
systemctl status nginx

echo "✅ Nginx установлен и запущен!"