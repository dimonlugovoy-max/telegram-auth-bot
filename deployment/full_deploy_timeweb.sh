#!/bin/bash
# full_deploy_timeweb.sh - ЧАСТЬ 1 из 2
# Полное развертывание Telegram Auth Bot на Timeweb VDS

set -e  # Остановка при ошибке

echo "════════════════════════════════════════════════════════════"
echo "🚀 Полное развертывание Telegram Auth Bot на Timeweb VDS"
echo "════════════════════════════════════════════════════════════"
echo ""

# ============================================
# Цвета для вывода
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Функции для красивого вывода
# ============================================

error() {
    echo -e "${RED}❌ $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

step() {
    echo ""
    echo -e "${BLUE}═══ $1 ═══${NC}"
    echo ""
}

# ============================================
# Проверка прав root
# ============================================

if [ "$EUID" -ne 0 ]; then 
    error "Запустите скрипт с sudo или от пользователя root"
    echo "Использование: sudo bash $0"
    exit 1
fi

# ============================================
# Определение ОС
# ============================================

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    error "Не удалось определить операционную систему"
    exit 1
fi

info "Операционная система: $OS $VER"

if [[ "$OS" != *"Ubuntu"* ]]; then
    warning "Скрипт оптимизирован для Ubuntu. Продолжить? (yes/no)"
    read -p "> " CONTINUE
    if [ "$CONTINUE" != "yes" ]; then
        exit 0
    fi
fi

# ============================================
# Сбор информации от пользователя
# ============================================

step "Сбор информации для развертывания"

# Домен
while true; do
    read -p "Введите ваш домен (например: bot.example.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        error "Домен не может быть пустым!"
    elif [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        error "Некорректный формат домена!"
    else
        break
    fi
done

# Email для SSL
while true; do
    read -p "Введите email для SSL сертификата: " EMAIL
    if [ -z "$EMAIL" ]; then
        error "Email не может быть пустым!"
    elif [[ ! "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        error "Некорректный формат email!"
    else
        break
    fi
done

# Telegram Bot Token
while true; do
    read -p "Введите Telegram Bot Token: " BOT_TOKEN
    if [ -z "$BOT_TOKEN" ]; then
        error "Bot Token не может быть пустым!"
    elif [[ ! "$BOT_TOKEN" =~ ^[0-9]+:[a-zA-Z0-9_-]{35}$ ]]; then
        warning "Возможно некорректный формат токена. Продолжить? (yes/no)"
        read -p "> " CONTINUE
        if [ "$CONTINUE" == "yes" ]; then
            break
        fi
    else
        break
    fi
done

# Bot Username
while true; do
    read -p "Введите Bot Username (без @): " BOT_USERNAME
    if [ -z "$BOT_USERNAME" ]; then
        error "Bot Username не может быть пустым!"
    else
        # Удаление @ если пользователь его ввел
        BOT_USERNAME="${BOT_USERNAME#@}"
        break
    fi
done

# YClients токены
echo ""
info "YClients API токены (можно оставить пустыми и заполнить позже в .env)"
read -p "BEARER_TOKEN (YClients): " BEARER_TOKEN
read -p "PARTNER_TOKEN (YClients): " PARTNER_TOKEN

# Webhook URL (опционально)
echo ""
read -p "WEBHOOK_URL для уведомлений (Enter для пропуска): " CUSTOM_WEBHOOK_URL

# Подтверждение
echo ""
echo "════════════════════════════════════════════════════════════"
echo "📋 Проверьте введенные данные:"
echo "════════════════════════════════════════════════════════════"
echo "Домен: $DOMAIN"
echo "Email: $EMAIL"
echo "Bot: @$BOT_USERNAME"
echo "Bot Token: ${BOT_TOKEN:0:10}...${BOT_TOKEN: -5}"
echo "BEARER_TOKEN: ${BEARER_TOKEN:+установлен}"
echo "PARTNER_TOKEN: ${PARTNER_TOKEN:+установлен}"
echo "Webhook URL: ${CUSTOM_WEBHOOK_URL:-https://$DOMAIN/api/webhook (по умолчанию)}"
echo "════════════════════════════════════════════════════════════"
echo ""

read -p "Продолжить установку? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    warning "Установка отменена"
    exit 0
fi

# Установка webhook URL по умолчанию если не указан
WEBHOOK_URL="${CUSTOM_WEBHOOK_URL:-https://$DOMAIN/api/webhook}"

# ============================================
# Логирование установки
# ============================================

LOG_FILE="/var/log/telegram-bot-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

info "Лог установки сохраняется в: $LOG_FILE"

# ============================================
# 1. Обновление системы
# ============================================

step "1/16: Обновление системы"

info "Обновление списка пакетов..."
apt update

info "Обновление установленных пакетов..."
apt upgrade -y

success "Система обновлена"

# ============================================
# 2. Установка базовых пакетов
# ============================================

step "2/16: Установка базовых пакетов"

info "Установка необходимых утилит..."
DEBIAN_FRONTEND=noninteractive apt install -y \
    curl \
    wget \
    git \
    build-essential \
    ufw \
    nano \
    vim \
    htop \
    unzip \
    zip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    net-tools

success "Базовые пакеты установлены"

# ============================================
# 3. Настройка firewall (UFW)
# ============================================

step "3/16: Настройка firewall"

info "Сброс правил UFW..."
ufw --force reset

info "Настройка правил firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'

info "Включение UFW..."
ufw --force enable

success "Firewall настроен"
ufw status verbose

# ============================================
# 4. Установка Node.js 20.x LTS
# ============================================

step "4/16: Установка Node.js 20.x LTS"

info "Добавление NodeSource репозитория..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -

info "Установка Node.js..."
apt install -y nodejs

# Проверка установки
NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

success "Node.js $NODE_VERSION установлен"
success "npm $NPM_VERSION установлен"

# Установка глобальных пакетов
info "Установка PM2..."
npm install -g pm2

PM2_VERSION=$(pm2 --version)
success "PM2 $PM2_VERSION установлен"

# ============================================
# 5. Создание пользователя для бота
# ============================================

step "5/16: Создание пользователя botuser"

if id "botuser" &>/dev/null; then
    warning "Пользователь botuser уже существует"
else
    info "Создание пользователя botuser..."
    adduser --disabled-password --gecos "" botuser
    
    # Добавление в группу sudo (опционально)
    # usermod -aG sudo botuser
    
    success "Пользователь botuser создан"
fi

BOT_DIR="/home/botuser/telegram-auth-bot"

# ============================================
# 6. Настройка swap (для серверов с малой RAM)
# ============================================

step "6/16: Настройка swap файла"

if [ -f /swapfile ]; then
    warning "Swap файл уже существует"
    FREE_MEM=$(free -m | awk '/^Swap:/ {print $2}')
    info "Текущий swap: ${FREE_MEM}MB"
else
    # Определение размера swap (2GB для серверов с 1GB RAM)
    TOTAL_MEM=$(free -m | awk '/^Mem:/ {print $2}')
    
    if [ "$TOTAL_MEM" -lt 2048 ]; then
        SWAP_SIZE="2G"
    elif [ "$TOTAL_MEM" -lt 4096 ]; then
        SWAP_SIZE="4G"
    else
        SWAP_SIZE="4G"
    fi
    
    info "Создание swap файла размером $SWAP_SIZE..."
    
    fallocate -l $SWAP_SIZE /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    
    # Добавление в fstab для автомонтирования
    if ! grep -q '/swapfile' /etc/fstab; then
        echo '/swapfile none swap sw 0 0' >> /etc/fstab
    fi
    
    # Настройка swappiness
    sysctl vm.swappiness=10
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    
    success "Swap $SWAP_SIZE настроен"
fi

# ============================================
# 7. Настройка timezone
# ============================================

step "7/16: Настройка timezone"

info "Установка timezone Europe/Moscow..."
timedatectl set-timezone Europe/Moscow

CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
success "Timezone установлен: $CURRENT_TZ"

# ============================================
# 8. Установка и настройка Nginx
# ============================================

step "8/16: Установка Nginx"

info "Установка Nginx..."
apt install -y nginx

info "Запуск и автозапуск Nginx..."
systemctl start nginx
systemctl enable nginx

NGINX_VERSION=$(nginx -v 2>&1 | awk '{print $3}')
success "Nginx $NGINX_VERSION установлен и запущен"

# full_deploy_timeweb.sh - ЧАСТЬ 2A из 3
# Продолжение скрипта развертывания

# НАЧАЛО ЧАСТИ 2A (продолжение)

# ============================================
# 9. Создание структуры директорий бота
# ============================================

step "9/16: Создание структуры проекта"

info "Создание директории $BOT_DIR..."
mkdir -p $BOT_DIR

# Создание поддиректорий
su - botuser -c "mkdir -p $BOT_DIR/{logs,backups,scripts,deployment}"

chown -R botuser:botuser $BOT_DIR
chmod 755 $BOT_DIR

success "Структура директорий создана"

# ============================================
# 10. Генерация ENCRYPTION_KEY
# ============================================

step "10/16: Генерация ключа шифрования"

info "Генерация ENCRYPTION_KEY..."
ENCRYPTION_KEY=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")

success "ENCRYPTION_KEY сгенерирован"
info "Ключ: ${ENCRYPTION_KEY:0:16}...${ENCRYPTION_KEY: -16}"

# ============================================
# 11. Создание .env файла
# ============================================

step "11/16: Создание конфигурации (.env)"

info "Создание .env файла..."

cat > $BOT_DIR/.env << ENVEOF
# ========================================
# Telegram Bot Configuration
# ========================================
BOT_TOKEN=$BOT_TOKEN
BOT_USERNAME=$BOT_USERNAME

# ========================================
# Security
# ========================================
# Ключ шифрования (сгенерирован автоматически $(date))
ENCRYPTION_KEY=$ENCRYPTION_KEY

# ========================================
# YClients API
# ========================================
BEARER_TOKEN=$BEARER_TOKEN
PARTNER_TOKEN=$PARTNER_TOKEN

# ========================================
# Webhook
# ========================================
WEBHOOK_URL=$WEBHOOK_URL

# ========================================
# Server
# ========================================
PORT=3000
NODE_ENV=production

# ========================================
# Advanced Settings
# ========================================
LINK_EXPIRY_HOURS=24
RETRY_INTERVAL_MINUTES=5
API_TIMEOUT_MS=15000
DATA_RETENTION_DAYS=90
ENVEOF

chmod 600 $BOT_DIR/.env
chown botuser:botuser $BOT_DIR/.env

success ".env файл создан и защищен (права 600)"

# ============================================
# 12. Создание package.json
# ============================================

step "12/16: Создание package.json"

cat > $BOT_DIR/package.json << 'PKGEOF'
{
  "name": "telegram-auth-bot",
  "version": "2.0.0",
  "description": "Telegram bot for client authentication with YClients",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js",
    "pm2:start": "pm2 start index.js --name telegram-auth-bot",
    "pm2:restart": "pm2 restart telegram-auth-bot",
    "pm2:stop": "pm2 stop telegram-auth-bot",
    "pm2:logs": "pm2 logs telegram-auth-bot"
  },
  "dependencies": {
    "node-telegram-bot-api": "^0.64.0",
    "express": "^4.18.2",
    "axios": "^1.6.7",
    "sqlite3": "^5.1.7",
    "dotenv": "^16.4.1",
    "node-cron": "^3.0.3"
  },
  "devDependencies": {
    "nodemon": "^3.0.3"
  },
  "engines": {
    "node": ">=16.0.0"
  }
}
PKGEOF

chown botuser:botuser $BOT_DIR/package.json

success "package.json создан"

# ============================================
# 13. Создание placeholder index.js
# ============================================

step "13/16: Создание временного index.js"

warning "Создается временный index.js для проверки установки"
warning "ОБЯЗАТЕЛЬНО замените его на полную версию после установки!"

cat > $BOT_DIR/index.js << 'INDEXEOF'
// index.js - ВРЕМЕННЫЙ ФАЙЛ
// ⚠️ ЗАМЕНИТЕ НА ПОЛНУЮ ВЕРСИЮ!

require('dotenv').config();
const express = require('express');

const app = express();
app.use(express.json());

console.log('═══════════════════════════════════════════════');
console.log('✅ Telegram Auth Bot - Тестовый режим');
console.log('═══════════════════════════════════════════════');
console.log('📋 Конфигурация:');
console.log('   Bot: @' + process.env.BOT_USERNAME);
console.log('   Port: ' + process.env.PORT);
console.log('   Webhook: ' + process.env.WEBHOOK_URL);
console.log('═══════════════════════════════════════════════');
console.log('');
console.log('⚠️  ЭТО ВРЕМЕННАЯ ВЕРСИЯ!');
console.log('');
console.log('Следующие шаги:');
console.log('1. Скопируйте полный код index.js в /home/botuser/telegram-auth-bot/');
console.log('2. Перезапустите: pm2 restart telegram-auth-bot');
console.log('');

app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Установка завершена. Загрузите полный код бота.',
    timestamp: new Date().toISOString()
  });
});

app.get('/', (req, res) => {
  res.json({
    service: 'Telegram Auth Bot',
    version: '2.0.0 (placeholder)',
    status: 'waiting for full deployment'
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Сервер запущен на порту ${PORT}`);
  console.log(`🌐 Health check: http://localhost:${PORT}/health`);
});
INDEXEOF

chown botuser:botuser $BOT_DIR/index.js

success "Временный index.js создан"

# ============================================
# 14. Установка npm зависимостей
# ============================================

step "14/16: Установка npm зависимостей"

info "Установка пакетов (может занять несколько минут)..."
cd $BOT_DIR
su - botuser -c "cd $BOT_DIR && npm install --production"

success "Зависимости установлены"

# ============================================
# 15. Настройка Nginx
# ============================================

step "15/16: Настройка Nginx"

info "Создание конфигурации Nginx для $DOMAIN..."

cat > /etc/nginx/sites-available/telegram-bot << NGINXEOF
# Rate limiting
limit_req_zone \$binary_remote_addr zone=api_limit:10m rate=10r/s;

server {
    listen 80;
    server_name $DOMAIN;

    access_log /var/log/nginx/telegram-bot-access.log;
    error_log /var/log/nginx/telegram-bot-error.log;

    # Основное проксирование
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # API с rate limiting
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        limit_req_status 429;
        
        proxy_pass http://localhost:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health check без логирования
    location /health {
        proxy_pass http://localhost:3000/health;
        access_log off;
    }
}
NGINXEOF

# Активация конфигурации
ln -sf /etc/nginx/sites-available/telegram-bot /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Проверка конфигурации
info "Проверка конфигурации Nginx..."
nginx -t

# Перезагрузка Nginx
systemctl reload nginx

success "Nginx настроен для $DOMAIN"

# ============================================
# 16. Установка SSL с Certbot
# ============================================

step "16/16: Установка SSL сертификата"

info "Установка Certbot..."
apt install -y certbot python3-certbot-nginx

info "Получение SSL сертификата для $DOMAIN..."
info "Это может занять минуту..."

certbot --nginx \
    -d $DOMAIN \
    --non-interactive \
    --agree-tos \
    --email $EMAIL \
    --redirect

# Проверка автопродления
info "Проверка автопродления сертификата..."
certbot renew --dry-run

# Настройка cron для автопродления
CRON_CMD="0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'"
(crontab -l 2>/dev/null | grep -v "certbot renew"; echo "$CRON_CMD") | crontab -

success "SSL сертификат установлен"
success "Автопродление настроено (каждый день в 3:00)"

# full_deploy_timeweb.sh - ЧАСТЬ 2B1 из 4
# Завершение скрипта развертывания - часть 1

# НАЧАЛО ЧАСТИ 2B1 (продолжение)

# ============================================
# 17. Настройка PM2 и запуск бота
# ============================================

step "Настройка PM2 и запуск бота"

info "Запуск бота через PM2..."
su - botuser -c "cd $BOT_DIR && pm2 start index.js --name telegram-auth-bot"

# PM2 startup
info "Настройка автозапуска PM2..."
PM2_STARTUP=$(su - botuser -c "pm2 startup systemd -u botuser --hp /home/botuser" | grep "sudo")
eval $PM2_STARTUP

# Сохранение конфигурации PM2
su - botuser -c "pm2 save"

success "PM2 настроен и бот запущен"

# Проверка статуса
info "Статус PM2:"
sleep 2
su - botuser -c "pm2 status"

# ============================================
# 18. Создание вспомогательных скриптов
# ============================================

step "Создание вспомогательных скриптов"

# Скрипт обновления бота
info "Создание скрипта обновления..."
cat > $BOT_DIR/deployment/update.sh << 'UPDATEEOF'
#!/bin/bash
echo "🔄 Обновление бота..."
cd /home/botuser/telegram-auth-bot

# Бэкап перед обновлением
./deployment/backup.sh

# Остановка бота
pm2 stop telegram-auth-bot

# Обновление из Git (если настроен)
if [ -d .git ]; then
    git pull
else
    echo "⚠️  Git репозиторий не настроен"
fi

# Обновление зависимостей
npm install --production

# Перезапуск
pm2 restart telegram-auth-bot

echo "✅ Обновление завершено"
pm2 logs telegram-auth-bot --lines 50
UPDATEEOF

# Скрипт бэкапа
info "Создание скрипта бэкапа..."
cat > $BOT_DIR/deployment/backup.sh << 'BACKUPEOF'
#!/bin/bash
BACKUP_DIR="/home/botuser/telegram-auth-bot/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "💾 Создание резервной копии..."

# Бэкап БД и .env
tar -czf "$BACKUP_DIR/backup_$TIMESTAMP.tar.gz" \
    -C /home/botuser/telegram-auth-bot \
    bot.db \
    .env \
    2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Бэкап создан: backup_$TIMESTAMP.tar.gz"
    ls -lh "$BACKUP_DIR/backup_$TIMESTAMP.tar.gz"
else
    echo "⚠️  Некоторые файлы могут отсутствовать"
fi

# Удаление бэкапов старше 30 дней
DELETED=$(find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +30 -delete -print | wc -l)
if [ $DELETED -gt 0 ]; then
    echo "🗑️  Удалено старых бэкапов: $DELETED"
fi

echo "📊 Всего бэкапов: $(ls $BACKUP_DIR/backup_*.tar.gz 2>/dev/null | wc -l)"
BACKUPEOF

# Скрипт просмотра логов
info "Создание скрипта логов..."
cat > $BOT_DIR/deployment/logs.sh << 'LOGSEOF'
#!/bin/bash
echo "📝 Логи Telegram Auth Bot"
echo "=========================="
pm2 logs telegram-auth-bot --lines 100
LOGSEOF

# Скрипт мониторинга
info "Создание скрипта мониторинга..."
cat > $BOT_DIR/deployment/monitor.sh << 'MONITOREOF'
#!/bin/bash
echo "📊 Мониторинг Telegram Auth Bot"
echo "================================"
echo ""

# PM2 статус
echo "--- PM2 Статус ---"
pm2 status telegram-auth-bot

echo ""
echo "--- Использование памяти ---"
pm2 show telegram-auth-bot | grep -A 5 "memory"

echo ""
echo "--- Процессор ---"
pm2 show telegram-auth-bot | grep -A 3 "cpu"

echo ""
echo "--- Аптайм ---"
pm2 show telegram-auth-bot | grep "uptime"

echo ""
echo "--- Размер БД ---"
if [ -f /home/botuser/telegram-auth-bot/bot.db ]; then
    du -h /home/botuser/telegram-auth-bot/bot.db
else
    echo "БД еще не создана"
fi

echo ""
echo "--- Доступность API ---"
curl -s http://localhost:3000/health | jq '.' || echo "API недоступен"

echo ""
echo "--- Последние 10 строк логов ---"
pm2 logs telegram-auth-bot --lines 10 --nostream
MONITOREOF

# Скрипт перезапуска
info "Создание скрипта перезапуска..."
cat > $BOT_DIR/deployment/restart.sh << 'RESTARTEOF'
#!/bin/bash
echo "🔄 Перезапуск бота..."
pm2 restart telegram-auth-bot
sleep 2
pm2 status telegram-auth-bot
pm2 logs telegram-auth-bot --lines 20
RESTARTEOF

# Скрипт остановки
info "Создание скрипта остановки..."
cat > $BOT_DIR/deployment/stop.sh << 'STOPEOF'
#!/bin/bash
echo "🛑 Остановка бота..."
pm2 stop telegram-auth-bot
pm2 status telegram-auth-bot
STOPEOF

# Скрипт запуска
info "Создание скрипта запуска..."
cat > $BOT_DIR/deployment/start.sh << 'STARTEOF'
#!/bin/bash
echo "▶️  Запуск бота..."
pm2 start telegram-auth-bot
sleep 2
pm2 status telegram-auth-bot
pm2 logs telegram-auth-bot --lines 20
STARTEOF

# Установка прав на выполнение
chmod +x $BOT_DIR/deployment/*.sh
chown -R botuser:botuser $BOT_DIR/deployment/

success "Вспомогательные скрипты созданы:"
ls -lh $BOT_DIR/deployment/*.sh

# ============================================
# 19. Создание README для администратора
# ============================================

step "Создание документации"

info "Создание README.admin.md..."
cat > $BOT_DIR/README.admin.md << 'READMEEOF'
# Telegram Auth Bot - Руководство администратора

## Управление ботом

### Основные команды

```bash
# Просмотр статуса
pm2 status telegram-auth-bot

# Просмотр логов
pm2 logs telegram-auth-bot

# Перезапуск
pm2 restart telegram-auth-bot

# Остановка
pm2 stop telegram-auth-bot

# Запуск
pm2 start telegram-auth-bot

# Вспомогательные скрипты
# Все скрипты находятся в /home/botuser/telegram-auth-bot/deployment/

# Обновление бота
./deployment/update.sh

# Создание бэкапа
./deployment/backup.sh

# Просмотр логов
./deployment/logs.sh

# Мониторинг
./deployment/monitor.sh

# Перезапуск
./deployment/restart.sh

# Остановка
./deployment/stop.sh

# Запуск
./deployment/start.sh
Конфигурация
Редактирование .env
nano /home/botuser/telegram-auth-bot/.env
После изменений перезапустите бота:

pm2 restart telegram-auth-bot
Важные переменные
BOT_TOKEN - токен Telegram бота
BOT_USERNAME - username бота
ENCRYPTION_KEY - ключ шифрования (НЕ МЕНЯТЬ!)
BEARER_TOKEN - токен YClients API
PARTNER_TOKEN - партнерский токен YClients
WEBHOOK_URL - URL для webhook уведомлений
Мониторинг
Проверка работоспособности
# Health check
curl https://ваш-домен.com/health

# Локально
curl http://localhost:3000/health
Просмотр метрик
# Статистика PM2
pm2 monit

# Детальная информация
pm2 show telegram-auth-bot
Резервное копирование
Создание бэкапа
cd /home/botuser/telegram-auth-bot
./deployment/backup.sh
Бэкапы сохраняются в /home/botuser/telegram-auth-bot/backups/

Восстановление из бэкапа
# Остановка бота
pm2 stop telegram-auth-bot

# Распаковка бэкапа
cd /home/botuser/telegram-auth-bot
tar -xzf backups/backup_YYYYMMDD_HHMMSS.tar.gz

# Запуск бота
pm2 start telegram-auth-bot
Логи
Расположение логов
PM2 логи: ~/.pm2/logs/
Nginx логи: /var/log/nginx/
Системные логи: /var/log/syslog
Просмотр логов
# PM2 логи (live)
pm2 logs telegram-auth-bot

# PM2 логи (последние 100 строк)
pm2 logs telegram-auth-bot --lines 100

# Nginx access log
tail -f /var/log/nginx/telegram-bot-access.log

# Nginx error log
tail -f /var/log/nginx/telegram-bot-error.log
Обновление
Обновление кода бота
Загрузите новый index.js
Запустите скрипт обновления:
./deployment/update.sh
Обновление зависимостей
cd /home/botuser/telegram-auth-bot
npm install --production
pm2 restart telegram-auth-bot
SSL сертификат
Проверка срока действия
certbot certificates
Ручное продление
certbot renew
systemctl reload nginx
Автопродление настроено и работает каждый день в 3:00.

Troubleshooting
Бот не отвечает
# Проверка статуса
pm2 status telegram-auth-bot

# Перезапуск
pm2 restart telegram-auth-bot

# Проверка логов на ошибки
pm2 logs telegram-auth-bot --err
Ошибки Nginx
# Проверка конфигурации
nginx -t

# Перезапуск Nginx
systemctl restart nginx

# Логи ошибок
tail -f /var/log/nginx/telegram-bot-error.log
Проблемы с БД
# Проверка наличия БД
ls -lh /home/botuser/telegram-auth-bot/bot.db

# Права доступа
chown botuser:botuser /home/botuser/telegram-auth-bot/bot.db
Контакты
Логи установки: /var/log/telegram-bot-install.log
Директория проекта: /home/botuser/telegram-auth-bot
Конфигурация Nginx: /etc/nginx/sites-available/telegram-bot READMEEOF
chown botuser:botuser $BOT_DIR/README.admin.md

success “Документация создана: README.admin.md”

КОНЕЦ ЧАСТИ 2B1
Продолжение в части 2B2…
”`

full_deploy_timeweb.sh - ЧАСТЬ 2B2 из 4 (ФИНАЛЬНАЯ)
”`bash

full_deploy_timeweb.sh - ЧАСТЬ 2B2 из 4 (ФИНАЛЬНАЯ ЧАСТЬ)
Финализация установки
НАЧАЛО ЧАСТИ 2B2 (продолжение)
============================================
20. Финальная проверка установки
============================================
step “Финальная проверка установки”

Пауза для запуска сервисов
sleep 3

Проверка HTTP
info “Проверка HTTP доступности…” HTTP_STATUS=$(curl -s -o /dev/null -w “%{http_code}” http://localhost:3000/health)

if [ “\(HTTP_STATUS" == "200" ]; then success "HTTP сервер работает (статус: \)HTTP_STATUS)” else warning “HTTP сервер вернул статус: $HTTP_STATUS” fi

Проверка HTTPS
info “Проверка HTTPS доступности…” HTTPS_STATUS=\((curl -s -o /dev/null -w "%{http_code}" https://\)DOMAIN/health 2>/dev/null)

if [ “\(HTTPS_STATUS" == "200" ]; then success "HTTPS работает (статус: \)HTTPS_STATUS)” else warning “HTTPS вернул статус: $HTTPS_STATUS (может потребоваться время для DNS)” fi

Проверка PM2
info “Проверка PM2…” PM2_STATUS=$(su - botuser -c “pm2 jlist” | jq -r ‘.[0].pm2_env.status’)

if [ “\(PM2_STATUS" == "online" ]; then success "PM2: бот запущен и работает" else error "PM2: статус бота - \)PM2_STATUS” fi

Проверка Nginx
info “Проверка Nginx…” if systemctl is-active –quiet nginx; then success “Nginx активен” else error “Nginx не активен” fi

Проверка SSL
info “Проверка SSL сертификата…” if [ -d “/etc/letsencrypt/live/\(DOMAIN" ]; then CERT_EXPIRY=\)(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$DOMAIN/cert.pem | cut -d= -f2) success “SSL сертификат установлен (истекает




подготовь часть 2B2
full_deploy_timeweb.sh - ЧАСТЬ 2B2 из 4 (ФИНАЛЬНАЯ)
”`bash

full_deploy_timeweb.sh - ЧАСТЬ 2B2 из 4 (ФИНАЛЬНАЯ ЧАСТЬ)
Финализация установки
НАЧАЛО ЧАСТИ 2B2 (продолжение)
============================================
20. Финальная проверка установки
============================================
step “Финальная проверка установки”

Пауза для запуска сервисов
sleep 3

Проверка HTTP
info “Проверка HTTP доступности…” HTTP_STATUS=$(curl -s -o /dev/null -w “%{http_code}” http://localhost:3000/health)

if [ “\(HTTP_STATUS" == "200" ]; then success "HTTP сервер работает (статус: \)HTTP_STATUS)” HTTP_RESPONSE=\((curl -s http://localhost:3000/health) info "Ответ сервера: \)HTTP_RESPONSE” else warning “HTTP сервер вернул статус: $HTTP_STATUS” fi

Проверка HTTPS
info “Проверка HTTPS доступности…” HTTPS_STATUS=\((curl -s -o /dev/null -w "%{http_code}" https://\)DOMAIN/health 2>/dev/null)

if [ “\(HTTPS_STATUS" == "200" ]; then success "HTTPS работает (статус: \)HTTPS_STATUS)” else warning “HTTPS вернул статус: $HTTPS_STATUS” warning “Если DNS еще не обновился, это нормально” fi

Проверка PM2
info “Проверка PM2…” PM2_STATUS=$(su - botuser -c “pm2 jlist” | jq -r ‘.[0].pm2_env.status’ 2>/dev/null || echo “unknown”)

if [ “\(PM2_STATUS" == "online" ]; then success "PM2: бот запущен и работает" PM2_UPTIME=\)(su - botuser -c “pm2 jlist” | jq -r ‘.[0].pm2_env.pm_uptime’ 2>/dev/null) info “Uptime: \(((\)(date +%s) - PM2_UPTIME/1000)) секунд” else error “PM2: статус бота - $PM2_STATUS” fi

Проверка Nginx
info “Проверка Nginx…” if systemctl is-active –quiet nginx; then success “Nginx активен” else error “Nginx не активен” fi

Проверка SSL
info “Проверка SSL сертификата…” if [ -d “/etc/letsencrypt/live/\(DOMAIN" ]; then CERT_EXPIRY=\)(openssl x509 -enddate -noout -in /etc/letsencrypt/live/\(DOMAIN/cert.pem 2>/dev/null | cut -d= -f2) success "SSL сертификат установлен (истекает: \)CERT_EXPIRY)” else warning “SSL сертификат не найден” fi

Проверка базы данных
info “Проверка базы данных…” if [ -f “\(BOT_DIR/bot.db" ]; then DB_SIZE=\)(du -h “\(BOT_DIR/bot.db" | cut -f1) success "База данных создана (размер: \)DB_SIZE)” else info “База данных будет создана при первом запуске” fi

Проверка дискового пространства
info “Проверка дискового пространства…” DISK_USAGE=\((df -h / | awk 'NR==2 {print \)5}’ | sed ’s/%//‘) if [ \(DISK_USAGE -lt 80 ]; then success "Свободное место: \)((100 - DISK_USAGE))%” else warning “Использовано диска: ${DISK_USAGE}%” fi

Проверка памяти
info “Проверка памяти…” FREE_MEM=\((free -m | awk 'NR==2 {printf "%.0f", \)7/\(2 * 100}') if [ \)FREE_MEM -gt 20 ]; then success “Свободная память: \({FREE_MEM}%" else warning "Свободная память: \){FREE_MEM}%” fi

============================================
21. Создание информационного файла
============================================
step “Сохранение информации об установке”

cat > $BOT_DIR/INSTALLATION_INFO.txt << INFOEOF ════════════════════════════════════════════════════════════ TELEGRAM AUTH BOT - Информация об установке ════════════════════════════════════════════════════════════

Дата установки: \((date) Сервер: \)(hostname) IP адрес: $(curl -s ifconfig.me)

════════════════════════════════════════════════════════════ КОНФИГУРАЦИЯ ════════════════════════════════════════════════════════════

Домен: https://\(DOMAIN Бот: @\)BOT_USERNAME Директория: $BOT_DIR Пользователь: botuser

════════════════════════════════════════════════════════════ БЕЗОПАСНОСТЬ ════════════════════════════════════════════════════════════

ENCRYPTION_KEY: $ENCRYPTION_KEY SSL сертификат: Let’s Encrypt (автопродление включено) Firewall: UFW (порты 22, 80, 443)

════════════════════════════════════════════════════════════ СИСТЕМНЫЕ КОМПОНЕНТЫ ════════════════════════════════════════════════════════════

ОС: \(OS \)VER Node.js: \(NODE_VERSION npm: \)NPM_VERSION PM2: \((pm2 --version) Nginx: \)(nginx -v 2>&1 | awk ‘{print $3}’)

════════════════════════════════════════════════════════════ ВАЖНЫЕ ФАЙЛЫ ════════════════════════════════════════════════════════════

Конфигурация: \(BOT_DIR/.env Код бота: \)BOT_DIR/index.js База данных: \(BOT_DIR/bot.db Логи PM2: ~/.pm2/logs/ Логи Nginx: /var/log/nginx/ Бэкапы: \)BOT_DIR/backups/ Скрипты: $BOT_DIR/deployment/

════════════════════════════════════════════════════════════ ОСНОВНЫЕ КОМАНДЫ ════════════════════════════════════════════════════════════

Статус: pm2 status telegram-auth-bot Логи: pm2 logs telegram-auth-bot Перезапуск: pm2 restart telegram-auth-bot Мониторинг: cd \(BOT_DIR && ./deployment/monitor.sh Бэкап: cd \)BOT_DIR && ./deployment/backup.sh

════════════════════════════════════════════════════════════ ENDPOINTS ════════════════════════════════════════════════════════════

Health Check: https://\(DOMAIN/health Generate Link: POST https://\)DOMAIN/api/generate-link Auth Status: GET https://\(DOMAIN/api/auth-status/:company_id/:client_id Statistics: GET https://\)DOMAIN/api/stats

════════════════════════════════════════════════════════════ ДОКУМЕНТАЦИЯ ════════════════════════════════════════════════════════════

Руководство администратора: $BOT_DIR/README.admin.md Лог установки: /var/log/telegram-bot-install.log

════════════════════════════════════════════════════════════ СЛЕДУЮЩИЕ ШАГИ ════════════════════════════════════════════════════════════

Загрузите полный код index.js в $BOT_DIR/
Заполните BEARER_TOKEN и PARTNER_TOKEN в .env (если не заполнены)
Перезапустите бота: pm2 restart telegram-auth-bot
Проверьте работу: curl https://$DOMAIN/health
════════════════════════════════════════════════════════════ INFOEOF

chown botuser:botuser \(BOT_DIR/INSTALLATION_INFO.txt chmod 600 \)BOT_DIR/INSTALLATION_INFO.txt

success “Информация об установке сохранена”

============================================
22. Создание cron задач для обслуживания
============================================
step “Настройка cron задач”

info “Создание задач для автоматического обслуживания…”

Ежедневный бэкап в 2:00
BACKUP_CRON=“0 2 * * * cd \(BOT_DIR && ./deployment/backup.sh >> \)BOT_DIR/logs/backup.log 2>&1”

Еженедельная очистка старых логов в воскресенье в 4:00
CLEANUP_CRON=“0 4 * * 0 pm2 flush”

Добавление в crontab пользователя botuser
su - botuser -c “(crontab -l 2>/dev/null | grep -v ‘backup.sh’; echo ‘\(BACKUP_CRON') | crontab -" su - botuser -c "(crontab -l 2>/dev/null | grep -v 'pm2 flush'; echo '\)CLEANUP_CRON’) | crontab -”

success “Cron задачи настроены:” info “ - Ежедневный бэкап в 2:00” info “ - Очистка логов PM2 каждое воскресенье в 4:00”

============================================
23. Создание quick reference файла
============================================
step “Создание справочника команд”

cat > /root/bot-commands.txt << ‘QUICKREF’ ╔════════════════════════════════════════════════════════════╗ ║ TELEGRAM AUTH BOT - Быстрый справочник ║ ╚════════════════════════════════════════════════════════════╝

📋 УПРАВЛЕНИЕ БОТОМ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

pm2 status telegram-auth-bot Статус pm2 logs telegram-auth-bot Логи (live) pm2 restart telegram-auth-bot Перезапуск pm2 stop telegram-auth-bot Остановка pm2 start telegram-auth-bot Запуск pm2 monit Мониторинг

🛠️ СКРИПТЫ (/home/botuser/telegram-auth-bot/deployment/) ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

./deployment/monitor.sh Мониторинг системы ./deployment/backup.sh Создать бэкап ./deployment/update.sh Обновить бота ./deployment/logs.sh Просмотр логов ./deployment/restart.sh Перезапуск

📁 ВАЖНЫЕ ФАЙЛЫ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/home/botuser/telegram-auth-bot/.env Конфигурация /home/botuser/telegram-auth-bot/index.js Код бота /home/botuser/telegram-auth-bot/bot.db База данных /var/log/nginx/telegram-bot-*.log Логи Nginx /var/log/telegram-bot-install.log Лог установки

🔧 NGINX ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

nginx -t Проверка конфигурации systemctl restart nginx Перезапуск systemctl status nginx Статус

🔒 SSL ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

certbot certificates Список сертификатов certbot renew Обновить вручную certbot renew –dry-run Проверить автообновление

💾 БЭКАП ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

cd /home/botuser/telegram-auth-bot && ./deployment/backup.sh

Восстановление: 1. pm2 stop telegram-auth-bot 2. tar -xzf backups/backup_*.tar.gz 3. pm2 start telegram-auth-bot

📊 МОНИТОРИНГ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

curl http://localhost:3000/health Health check htop Ресурсы системы df -h Место на диске free -h Память

╚════════════════════════════════════════════════════════════╝ QUICKREF

success “Справочник создан: /root/bot-commands.txt”

============================================
24. Финальные сообщения и инструкции
============================================
echo “” echo “════════════════════════════════════════════════════════════” echo “✅ УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!” echo “════════════════════════════════════════════════════════════” echo “” echo “📋 Информация о системе:” echo “ 🌐 Домен: https://\(DOMAIN" echo " 🤖 Бот: @\)BOT_USERNAME” echo “ 📁 Директория: \(BOT_DIR" echo " 👤 Пользователь: botuser" echo "" echo "🔐 Безопасность:" echo " 🔑 ENCRYPTION_KEY: \){ENCRYPTION_KEY:0:20}…\({ENCRYPTION_KEY: -10}" echo " 🔒 SSL: Установлен (Let's Encrypt)" echo " 🛡️ Firewall: UFW активен" echo "" echo "📊 Статус сервисов:" echo " HTTP: \){HTTP_STATUS




продолжай
# full_deploy_timeweb.sh - ЧАСТЬ 2B2 (продолжение)

echo "📊 Статус сервисов:"
echo "   HTTP:  $HTTP_STATUS"
echo "   HTTPS: $HTTPS_STATUS"
echo "   PM2:   $PM2_STATUS"
echo "   Nginx: $(systemctl is-active nginx)"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "⚠️  ВАЖНО - ОБЯЗАТЕЛЬНЫЕ СЛЕДУЮЩИЕ ШАГИ!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "1️⃣  ЗАМЕНИТЕ ВРЕМЕННЫЙ index.js НА ПОЛНУЮ ВЕРСИЮ:"
echo ""
echo "    Способ 1: Копирование файла"
echo "    ─────────────────────────────"
echo "    # На локальной машине:"
echo "    scp index.js root@$(curl -s ifconfig.me):$BOT_DIR/"
echo ""
echo "    # Затем на сервере:"
echo "    chown botuser:botuser $BOT_DIR/index.js"
echo "    pm2 restart telegram-auth-bot"
echo ""
echo "    Способ 2: Nano редактор"
echo "    ─────────────────────────────"
echo "    nano $BOT_DIR/index.js"
echo "    # Вставьте полный код бота (все 3 части)"
echo "    # Ctrl+X, Y, Enter для сохранения"
echo "    pm2 restart telegram-auth-bot"
echo ""
echo "2️⃣  ПРОВЕРЬТЕ И ЗАПОЛНИТЕ YClients ТОКЕНЫ (если не заполнены):"
echo ""
echo "    nano $BOT_DIR/.env"
echo ""
echo "    Заполните:"
echo "    BEARER_TOKEN=ваш_bearer_token"
echo "    PARTNER_TOKEN=ваш_partner_token"
echo ""
echo "    Перезапустите:"
echo "    pm2 restart telegram-auth-bot"
echo ""
echo "3️⃣  ПРОВЕРЬТЕ РАБОТУ БОТА:"
echo ""
echo "    # Health check"
echo "    curl https://$DOMAIN/health"
echo ""
echo "    # Мониторинг"
echo "    cd $BOT_DIR && ./deployment/monitor.sh"
echo ""
echo "    # Логи"
echo "    pm2 logs telegram-auth-bot"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "📚 ПОЛЕЗНАЯ ИНФОРМАЦИЯ"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "📁 Важные файлы:"
echo "   • Конфигурация:    $BOT_DIR/.env"
echo "   • Код бота:        $BOT_DIR/index.js"
echo "   • База данных:     $BOT_DIR/bot.db (создастся автоматически)"
echo "   • Документация:    $BOT_DIR/README.admin.md"
echo "   • Инфо установки:  $BOT_DIR/INSTALLATION_INFO.txt"
echo "   • Справочник:      /root/bot-commands.txt"
echo ""
echo "📋 Основные команды:"
echo "   • Статус:          pm2 status telegram-auth-bot"
echo "   • Логи:            pm2 logs telegram-auth-bot"
echo "   • Перезапуск:      pm2 restart telegram-auth-bot"
echo "   • Мониторинг:      cd $BOT_DIR && ./deployment/monitor.sh"
echo "   • Бэкап:           cd $BOT_DIR && ./deployment/backup.sh"
echo ""
echo "🔧 Вспомогательные скрипты:"
echo "   cd $BOT_DIR/deployment/"
echo "   • ./monitor.sh     - Мониторинг системы"
echo "   • ./backup.sh      - Создать резервную копию"
echo "   • ./update.sh      - Обновить бота"
echo "   • ./logs.sh        - Просмотр логов"
echo "   • ./restart.sh     - Перезапуск"
echo "   • ./stop.sh        - Остановка"
echo "   • ./start.sh       - Запуск"
echo ""
echo "🌐 API Endpoints:"
echo "   • Health:          https://$DOMAIN/health"
echo "   • Generate Link:   POST https://$DOMAIN/api/generate-link"
echo "   • Auth Status:     GET https://$DOMAIN/api/auth-status/:company_id/:client_id"
echo "   • Statistics:      GET https://$DOMAIN/api/stats"
echo ""
echo "🔒 Безопасность:"
echo "   • SSL сертификат автоматически обновляется каждый день в 3:00"
echo "   • Бэкапы создаются автоматически каждый день в 2:00"
echo "   • Старые бэкапы (>30 дней) удаляются автоматически"
echo "   • .env файл защищен (права 600)"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "🆘 ПОМОЩЬ И TROUBLESHOOTING"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "❓ Бот не работает:"
echo "   pm2 logs telegram-auth-bot --err"
echo "   pm2 restart telegram-auth-bot"
echo ""
echo "❓ Nginx ошибки:"
echo "   nginx -t"
echo "   tail -f /var/log/nginx/telegram-bot-error.log"
echo ""
echo "❓ SSL проблемы:"
echo "   certbot certificates"
echo "   certbot renew --dry-run"
echo ""
echo "❓ Проверка всех сервисов:"
echo "   systemctl status nginx"
echo "   pm2 status"
echo "   ufw status"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "📝 ЛОГИ УСТАНОВКИ"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Полный лог установки сохранен в:"
echo "$LOG_FILE"
echo ""
echo "Просмотр лога:"
echo "less $LOG_FILE"
echo ""
echo "════════════════════════════════════════════════════════════"
echo "🎉 УСТАНОВКА ЗАВЕРШЕНА!"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Спасибо за использование Telegram Auth Bot!"
echo ""
echo "Для начала работы:"
echo "1. Замените index.js на полную версию"
echo "2. Заполните .env токенами YClients"
echo "3. Перезапустите: pm2 restart telegram-auth-bot"
echo "4. Проверьте: curl https://$DOMAIN/health"
echo ""
echo "Справочник команд: cat /root/bot-commands.txt"
echo ""
echo "════════════════════════════════════════════════════════════"

# ============================================
# 25. Сохранение важной информации для администратора
# ============================================

# Создание файла с учетными данными (только для root)
cat > /root/bot-credentials.txt << CREDEOF
════════════════════════════════════════════════════════════
TELEGRAM AUTH BOT - Конфиденциальная информация
════════════════════════════════════════════════════════════

⚠️  ХРАНИТЕ ЭТОТ ФАЙЛ В БЕЗОПАСНОСТИ!

Дата: $(date)

════════════════════════════════════════════════════════════
ДОСТУПЫ
════════════════════════════════════════════════════════════

Сервер IP: $(curl -s ifconfig.me)
SSH порт: 22
Домен: https://$DOMAIN

Пользователь бота: botuser
Директория: $BOT_DIR

════════════════════════════════════════════════════════════
ТОКЕНЫ И КЛЮЧИ
════════════════════════════════════════════════════════════

BOT_TOKEN: $BOT_TOKEN
BOT_USERNAME: @$BOT_USERNAME

ENCRYPTION_KEY: $ENCRYPTION_KEY

BEARER_TOKEN: ${BEARER_TOKEN:-не заполнен}
PARTNER_TOKEN: ${PARTNER_TOKEN:-не заполнен}

WEBHOOK_URL: $WEBHOOK_URL

════════════════════════════════════════════════════════════
SSL СЕРТИФИКАТ
════════════════════════════════════════════════════════════

Email: $EMAIL
Домен: $DOMAIN
Автопродление: Включено (каждый день в 3:00)

════════════════════════════════════════════════════════════
РЕЗЕРВНЫЕ КОПИИ
════════════════════════════════════════════════════════════

Расположение: $BOT_DIR/backups/
Расписание: Каждый день в 2:00
Хранение: 30 дней

════════════════════════════════════════════════════════════
ВАЖНО
════════════════════════════════════════════════════════════

1. НЕ ДЕЛИТЕСЬ этим файлом
2. НЕ КОММИТЬТЕ в Git
3. СОЗДАВАЙТЕ БЭКАПЫ регулярно
4. МЕНЯЙТЕ пароли периодически

════════════════════════════════════════════════════════════
CREDEOF

chmod 600 /root/bot-credentials.txt

info "Конфиденциальная информация сохранена в /root/bot-credentials.txt"
warning "ХРАНИТЕ ЭТОТ ФАЙЛ В БЕЗОПАСНОСТИ!"

# ============================================
# 26. Создание быстрых алиасов для root
# ============================================

info "Добавление удобных алиасов в .bashrc..."

cat >> /root/.bashrc << 'ALIASEOF'

# Telegram Auth Bot aliases
alias bot-status='pm2 status telegram-auth-bot'
alias bot-logs='pm2 logs telegram-auth-bot'
alias bot-restart='pm2 restart telegram-auth-bot'
alias bot-stop='pm2 stop telegram-auth-bot'
alias bot-start='pm2 start telegram-auth-bot'
alias bot-monitor='cd /home/botuser/telegram-auth-bot && ./deployment/monitor.sh'
alias bot-backup='cd /home/botuser/telegram-auth-bot && ./deployment/backup.sh'
alias bot-update='cd /home/botuser/telegram-auth-bot && ./deployment/update.sh'
alias bot-health='curl http://localhost:3000/health | jq'
alias bot-dir='cd /home/botuser/telegram-auth-bot'
alias bot-help='cat /root/bot-commands.txt'
ALIASEOF

success "Алиасы добавлены. Используйте после перезагрузки shell или выполните: source /root/.bashrc"

# ============================================
# 27. Финальная очистка
# ============================================

info "Очистка временных файлов..."
apt autoremove -y
apt autoclean -y

# ============================================
# 28. Итоговая статистика
# ============================================

echo ""
echo "════════════════════════════════════════════════════════════"
echo "📊 СТАТИСТИКА УСТАНОВКИ"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "⏱️  Время установки: примерно $(($SECONDS / 60)) минут"
echo "💾 Использовано диска: $(df -h / | awk 'NR==2 {print $3}')"
echo "💿 Свободно на диске: $(df -h / | awk 'NR==2 {print $4}')"
echo "🧠 Использовано RAM: $(free -h | awk 'NR==2 {print $3}')"
echo "🆓 Свободно RAM: $(free -h | awk 'NR==2 {print $7}')"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

# Финальная пауза
sleep 2

# ============================================
# КОНЕЦ СКРИПТА
# ============================================

success "Скрипт развертывания завершен успешно!"
echo ""
info "Рекомендуется перезагрузить сервер после первоначальной настройки:"
echo "reboot"
echo ""
info "Или просто перезапустить бота после замены index.js:"
echo "pm2 restart telegram-auth-bot"
echo ""

exit 0

# КОНЕЦ ФАЙЛА full_deploy_timeweb.sh