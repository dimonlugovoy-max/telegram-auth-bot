
# Установка приложения
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Копируем исходники
COPY . .

# Создаём директории
RUN mkdir -p logs && mkdir -p data && touch bot.db

# Устанавливаем права
RUN chmod 600 .env* 2>/dev/null || true
RUN chown -R node:node /app
USER node

# Объём для БД и логов