echo “📊 Мониторинг Telegram Auth Bot” echo “=================================”

Проверка запущен ли бот
if pm2 list | grep -q “telegram-auth-bot.*online”; then echo “✅ Бот работает” else echo “❌ Бот не запущен!” exit 1 fi

Статистика PM2
echo “” echo “📈 PM2 статистика:” pm2 show telegram-auth-bot

# API статистика
echo ""
echo "📊 API статистика:"
curl -s http://localhost:${PORT:-3000}/api/stats | jq '.' || echo "❌ API недоступен"

# Очередь повторных попыток
echo ""
echo "⏳ Очередь повторных попыток:"
QUEUE_SIZE=$(curl -s http://localhost:${PORT:-3000}/api/retry-queue | jq '.count')
echo "Задач в очереди: $QUEUE_SIZE"

if [ "$QUEUE_SIZE" -gt 10 ]; then
    echo "⚠️  ВНИМАНИЕ: Большая очередь повторных попыток!"
fi

# Размер БД
echo ""
echo "💾 Размер базы данных:"
if [ -f bot.db ]; then
    du -h bot.db
else
    echo "❌ БД не найдена"
fi

# Использование памяти
echo ""
echo "🧠 Использование памяти:"
pm2 show telegram-auth-bot | grep "memory"

# Последние логи
echo ""
echo "📝 Последние 10 строк логов:"
pm2 logs telegram-auth-bot --lines 10 --nostream

# ПроверкаHealth
echo ""
echo "🏥 Health Check:"
HEALTH=$(curl -s http://localhost:${PORT:-3000}/health)
echo $HEALTH | jq '.'

if echo $HEALTH | jq -e '.status == "ok"' > /dev/null; then
    echo "✅ Сервис здоров"
else
    echo "❌ Проблемы со здоровьем сервиса"
fi

echo ""
echo "================================="
echo "Мониторинг завершен: $(date)"