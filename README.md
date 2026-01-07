telegram-auth-bot/
│
├── index.js                          # Основной файл приложения (3 части объединены)
│
├── package.json                      # Зависимости проекта
├── package-lock.json                 # Lockfile для npm
│
├── .env                              # Переменные окружения (НЕ коммитить!)
├── .env.example                      # Пример конфигурации
├── .gitignore                        # Игнорируемые файлы для Git
│
├── ecosystem.config.js               # Конфигурация PM2
│
├── bot.db                            # SQLite база данных (создается автоматически)
│
├── README.md                         # Документация проекта
├── CHANGELOG.md                      # История изменений
│
├── Dockerfile                        # Docker образ
├── docker-compose.yml                # Docker Compose для development
├── docker-compose.prod.yml           # Docker Compose для production
│
├── nginx.conf                        # Конфигурация Nginx
│
├── Makefile                          # Команды для управления проектом
│
├── postman_collection.json           # Postman коллекция для тестирования API
│
├── logs/                             # Директория для логов
│   ├── app.log                       # Общие логи
│   ├── error.log                     # Логи ошибок
│   ├── out.log                       # PM2 stdout
│   └── combined.log                  # PM2 combined logs
│
├── backups/                          # Резервные копии БД
│   └── bot_YYYYMMDD_HHMMSS.db.tar.gz
│
├── scripts/                          # Вспомогательные скрипты
│   ├── migrate.js                    # Миграции БД
│   ├── cleanup.js                    # Очистка старых данных
│   ├── stats.js                      # Детальная статистика
│   ├── exportData.js                 # Экспорт данных в CSV
│   ├── clearQueue.js                 # Очистка очереди
│   ├── checkHealth.js                # Проверка здоровья системы
│   └── generateApiKey.js             # Генерация API ключей
│
├── utils/                            # Утилиты (опционально)
│   ├── logger.js                     # Модуль логирования
│   ├── validator.js                  # Валидация данных
│   └── database.js                   # Обертка для работы с БД
│
├── middleware/                       # Express middleware (опционально)
│   ├── auth.js                       # Аутентификация для API
│   └── rateLimit.js                  # Rate limiting
│
├── config/                           # Конфигурационные файлы (опционально)
│   └── constants.js                  # Константы приложения
│
├── migrations/                       # Миграции базы данных
│   └── migrate.js                    # Скрипт миграций
│
├── .github/                          # GitHub Actions
│   └── workflows/
│       └── ci.yml                    # CI/CD pipeline
│
└── deployment/                       # Скрипты развертывания
    ├── ssh_setup.sh                  # Настройка SSH
    ├── install_node.sh               # Установка Node.js
    ├── install_nginx.sh              # Установка Nginx
    ├── install_ssl.sh                # Установка SSL
    ├── full_deploy_timeweb.sh        # Полное развертывание
    ├── setup.sh                      # Начальная настройка
    ├── start.sh                      # Запуск бота
    ├── deploy.sh                     # Развертывание с PM2
    ├── backup.sh                     # Резервное копирование
    ├── restore.sh                    # Восстановление из бэкапа
    ├── monitor.sh                    # Мониторинг
    ├── update.sh                     # Обновление бота
    └── install-service.sh            # Установка systemd сервиса



API Endpoints
Генерация ссылки для клиента
POST /api/generate-link
Content-Type: application/json

{
  "company_id": 123456,
  "client_id": 123456,
  "phone": "79261234567",
  "client_status": "new"
}
Ответ:

{
  "success": true,
  "link": "https://t.me/your_bot?start=U2FsdGVkX1...",
  "expires_in": "24 hours"
}
Получение статуса аутентификации
GET /api/auth-status/:company_id/:client_id
Ответ:

{
  "company_id": 123456,
  "client_id": 123456,
  "auth_status": "success",
  "tg_id": 987654321,
  "webhook_sent": true
}
Статистика
GET /api/stats
Ответ:

{
  "total_clients": 150,
  "successful_auth": 145,
  "pending_auth": 5,
  "webhooks_sent": 145,
  "retry_queue_size": 3
}
Очередь повторных попыток
GET /api/retry-queue
Повторная отправка webhook
POST /api/resend-webhook/:company_id/:client_id
Health Check
GET /health
Webhook форм

## Webhook формат

Ваша внешняя система получит POST запрос со следующей структурой:

```json
{
  "company_id": 123456,
  "client_id": 123456,
  "auth_status": "success",
  "tg_id": 987654321,
  "timestamp": "2025-01-15T10:30:00.000Z"
}
Возможные значения auth_status:
success - аутентификация успешна
pending - ожидание синхронизации
Пример обработки webhook на вашей стороне (Node.js):
app.post('/api/webhook', (req, res) => {
  const { company_id, client_id, auth_status, tg_id } = req.body;
  
  console.log(`Получен статус ${auth_status} для клиента ${client_id}`);
  
  // Ваша бизнес-логика
  
  res.json({ received: true });
});
Процесс работы
Для новых клиентов (client_status: “new”)
Клиент переходит по ссылке
Бот запрашивает ФИО
Клиент вводит: “Иванов Иван Иванович”
Бот показывает согласие на обработку данных
Клиент принимает согласие
Бот запрашивает подтверждение номера телефона
Клиент подтверждает через кнопку Telegram
Бот отправляет PUT запрос в YClients API
При успехе:
Обновляет статус в БД
Отправляет webhook на ваш сервер
Удаляет задачу из очереди
При ошибке API:
Добавляет в очередь повторных попыток
Повторяет каждые 5 минут до успеха
Для существующих клиентов (client_status: “old”)
Клиент переходит по ссылке
Бот показывает кнопку “Подтвердить”
Клиент нажимает подтверждение
Далее аналогично п.8-10 выше
Структура базы данных
Таблица clients
Поле	Тип	Описание
id	INTEGER	Первичный ключ
tg_id	INTEGER	Telegram ID (уникальный)
company_id	INTEGER	ID компании в YClients
client_id	INTEGER	ID клиента в YClients
phone	TEXT	Номер телефона
full_name	TEXT	ФИО клиента
consent_date	TEXT	Дата принятия согласия
auth_status	TEXT	Статус: pending/success
webhook_sent	INTEGER	Флаг отправки webhook (0/1)
created_at	TEXT	Дата создания
Таблица retry_queue
Поле	Тип	Описание
id	INTEGER	Первичный ключ
company_id	INTEGER	ID компании
client_id	INTEGER	ID клиента
tg_id	INTEGER	Telegram ID
full_name	TEXT	ФИО клиента
phone	TEXT	Номер телефона
retry_count	INTEGER	Количество попыток
next_retry	TEXT	Время следующей попытки
created_at	TEXT	Дата создания
Безопасность
Все данные в ссылках шифруются AES-256
Ссылки действительны 24 часа
Проверка соответствия номера телефона
Обязательное согласие на обработку данных
Мониторинг и отладка
Логи
Бот выводит детальные логи всех операций:

✅ API успех для client_id: 123456
📤 Webhook отправлен для client_id: 123456
🗑️ Задача удалена из очереди для client_id: 123456
⏳ Повторная попытка #2 для client_id: 123456
Просмотр очереди
curl http://localhost:3000/api/retry-queue
Просмотр статистики
curl http://localhost:3000/api/stats
Тестирование
Локальное тестирование webhook
Если WEBHOOK_URL не задан, можно использовать встроенный тестовый эндпоинт:

# В .env установите:
WEBHOOK_URL=http://localhost:3000/api/test-webhook
Генерация тестовой ссылки
curl -X POST http://localhost:3000/api/generate-link \
  -H "Content-Type: application/json" \
  -d '{
    "company_id": 123456,
    "client_id": 123456,
    "phone": "79261234567",
    "client_status": "new"
  }'
Развертывание
Docker (опционально)
Создайте Dockerfile:

FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

CMD ["node", "index.js"]
Сборка и запуск:

docker build -t telegram-auth-bot .
docker run -d --env-file .env -p 3000:3000 telegram-auth-bot
PM2 (рекомендуется)
npm install -g pm2
pm2 start index.js --name telegram-auth-bot
pm2 save
pm2 startup
