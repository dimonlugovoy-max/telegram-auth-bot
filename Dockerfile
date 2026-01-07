FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

RUN mkdir -p /app/logs /app/data && touch /app/bot.db

RUN chown -R node:node /app && chmod 600 .env* 2>/dev/null || true

USER node

VOLUME ["/app/data", "/app/logs"]

EXPOSE 3010

CMD ["node", "index.js"]
