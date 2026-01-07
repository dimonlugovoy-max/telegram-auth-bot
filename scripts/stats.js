// scripts/stats.js (детальная статистика)

require('dotenv').config();
const sqlite3 = require('sqlite3').verbose();

const db = new sqlite3.Database('./bot.db');

console.log('📊 Детальная статистика бота');
console.log('='.repeat(50));

// Общая статистика
db.get(`
  SELECT 
    COUNT(*) as total,
    SUM(CASE WHEN auth_status = 'success' THEN 1 ELSE 0 END) as success,
    SUM(CASE WHEN auth_status = 'pending' THEN 1 ELSE 0 END) as pending
  FROM clients
`, (err, row) => {
  if (err) {
    console.error('Ошибка:', err);
    return;
  }

  console.log('\n📈 Общая статистика:');
  console.log(`  Всего клиентов: ${row.total}`);
  console.log(`  Успешных: ${row.success}`);
  console.log(`  В ожидании: ${row.pending}`);
  console.log(`  Процент успеха: ${row.total > 0 ? ((row.success / row.total) * 100).toFixed(2) : 0}%`);
});

// Статистика по датам
db.all(`
  SELECT 
    DATE(created_at) as date,
    COUNT(*) as count,
    SUM(CASE WHEN auth_status = 'success' THEN 1 ELSE 0 END) as success_count
  FROM clients
  WHERE created_at >= datetime('now', '-7 days')
  GROUP BY DATE(created_at)
  ORDER BY date DESC
`, (err, rows) => {
  if (err) {
    console.error('Ошибка:', err);
    return;
  }

  console.log('\n📅 Активность за последние 7 дней:');
  rows.forEach(row => {
    console.log(`  ${row.date}: ${row.count} клиентов (${row.success_count} успешных)`);
  });
});

// Статистика очереди
db.all(`
  SELECT 
    retry_count,
    COUNT(*) as count
  FROM retry_queue
  GROUP BY retry_count
  ORDER BY retry_count
`, (err, rows) => {
  if (err) {
    console.error('Ошибка:', err);
    db.close();
    return;
  }

  console.log('\n⏳ Очередь повторных попыток:');
  if (rows.length === 0) {
    console.log('  Очередь пуста');
  } else {
    rows.forEach(row => {
      console.log(`  Попытка ${row.retry_count}: ${row.count} задач`);
    });
  }

  // Средний возраст задач в очереди
  db.get(`
    SELECT 
      AVG((julianday('now') - julianday(created_at)) * 24) as avg_hours
    FROM retry_queue
  `, (err, row) => {
    if (!err && row.avg_hours) {
      console.log(`  Средний возраст задач: ${row.avg_hours.toFixed(2)} часов`);
    }

    console.log('\n' + '='.repeat(50));
    db.close();
  });
});