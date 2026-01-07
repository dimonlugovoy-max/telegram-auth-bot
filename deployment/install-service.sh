#!/bin/bash
# install-service.sh (установка как systemd сервис)

echo "⚙️  Установка Telegram Auth Bot как systemd сервис"
echo "===================================================="

# Проверка прав root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Запустите с sudo"
  exit 1
fi

# Получение текущего пути и пользователя
CURRENT_DIR=$(pwd)
CURRENT_USER=$(logname)

# Создание systemd unit файла
cat > /etc/systemd/system/telegram-auth-bot.service << EOF
[Unit]
Description=Telegram Auth Bot
After=network.target

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$CURRENT_DIR
ExecStart=/usr/bin/node $CURRENT_DIR/index.js
Restart=always
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=telegram-auth-bot
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd
systemctl daemon-reload

# Включение автозапуска
systemctl enable telegram-auth-bot.service

echo ""
echo "✅ Сервис установлен!"
echo ""
echo "Управление сервисом:"
echo "  sudo systemctl start telegram-auth-bot    - Запуск"
echo "  sudo systemctl stop telegram-auth-bot     - Остановка"
echo "  sudo systemctl restart telegram-auth-bot  - Перезапуск"
echo "  sudo systemctl status telegram-auth-bot   - Статус"
echo "  sudo journalctl -u telegram-auth-bot -f   - Логи"