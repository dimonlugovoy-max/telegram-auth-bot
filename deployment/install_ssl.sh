# install_ssl.sh

#!/bin/bash

echo "🔒 Установка SSL сертификата с автопродлением"
echo "=============================================="

# Ваш домен (замените на свой)
DOMAIN="your-domain.com"
EMAIL="your-email@example.com"

# Установка Certbot
apt install -y certbot python3-certbot-nginx

# Получение SSL сертификата
certbot --nginx -d $DOMAIN -d www.$DOMAIN \
  --non-interactive \
  --agree-tos \
  --email $EMAIL \
  --redirect

# Проверка автопродления
certbot renew --dry-run

# Добавление задачи cron для автопродления
echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'" | crontab -

echo ""
echo "✅ SSL сертификат установлен!"
echo "🔄 Автопродление настроено (каждый день в 3:00)"
echo "📅 Проверка продления: certbot renew --dry-run"