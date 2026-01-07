FROM node:18-alpine

WORKDIR /app

# Копируем package.json и устанавливаем зависимости
COPY package*.json ./
RUN npm ci --only=production

# Копируем остальные файлы
COPY . .

# Создаём папки для данных и логов
RUN mkdir -p /app/logs /app/data && touch /app/bot.db

# Устанавливаем права (безопасность)
RUN chown -R node:node /app && chmod 600 .env* 2>/dev/null || true

# Переключаемся на пользователя node
USER node

# Объявляем тома
VOLUME ["/app/data", "/app/logs"]

# Открываем порт
EXPOSE 3010

# Запускаем бота
CMD ["node", "index.js"]
