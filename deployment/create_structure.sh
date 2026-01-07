#!/bin/bash
# create_structure.sh - Создание структуры проекта

echo "📁 Создание структуры проекта..."

# Основные директории
mkdir -p telegram-auth-bot/{logs,backups,scripts,utils,middleware,config,migrations,deployment,.github/workflows}

cd telegram-auth-bot

# Создание пустых файлов
touch index.js package.json .env.example .gitignore README.md CHANGELOG.md
touch ecosystem.config.js Dockerfile docker-compose.yml nginx.conf Makefile
touch postman_collection.json

# Scripts
touch scripts/{migrate.js,cleanup.js,stats.js,exportData.js,clearQueue.js,checkHealth.js,generateApiKey.js}

# Utils (опционально)
touch utils/{logger.js,validator.js,database.js}

# Middleware (опционально)
touch middleware/{auth.js,rateLimit.js}

# Config
touch config/constants.js

# Deployment
touch deployment/{ssh_setup.sh,install_node.sh,install_nginx.sh,install_ssl.sh,full_deploy_timeweb.sh,setup.sh,start.sh,deploy.sh,backup.sh,restore.sh,monitor.sh,update.sh,install-service.sh}

# Сделать скрипты исполняемыми
chmod +x deployment/*.sh

echo "✅ Структура проекта создана!"
echo "📍 Директория: $(pwd)"