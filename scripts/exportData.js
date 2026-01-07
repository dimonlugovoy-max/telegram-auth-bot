// scripts/exportData.js (экспорт данных в CSV)

require('dotenv').config();
const sqlite3 = require('sqlite3').verbose();
const fs = require('fs');

const db = new sqlite3.Database('./bot.db');

function escapeCSV(value) {
  if (value === null || value === undefined) return '';
  const stringValue = String(value);
  if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
    return `"${stringValue.replace(/"/g, '""')}"`;
  }
  return stringValue;
}

console.log('📤 Экспорт данных в CSV...\n');

// Экспорт клиентов
db.all('SELECT * FROM clients ORDER BY created_at DESC', (err, rows) => {
  if (err) {
    console.error('❌ Ошибка экспорта клиентов:', err);
    return;
  }

  if (rows.length === 0) {
    console.log('⚠️  Нет данных для экспорта');
    db.close();
    return;
  }

  // Заголовки CSV
  const headers = Object.keys(rows[0]);
  let csv = headers.join(',') + '\n';

  // Данные
  rows.forEach(row => {
    const values = headers.map(header => escapeCSV(row[header]));
    csv += values.join(',') + '\n';
  });

  // Сохранение файла
  const filename = `export_clients_${new Date().toISOString().split('T')[0]}.csv`;
  fs.writeFileSync(filename, csv, 'utf8');
  
  console.log(`✅ Экспортировано ${rows.length} записей клиентов в ${filename}`);

  // Экспорт очереди
  db.all('SELECT * FROM retry_queue ORDER BY created_at DESC', (err, queueRows) => {
    if (!err && queueRows.length > 0) {
      const queueHeaders = Object.keys(queueRows[0]);
      let queueCsv = queueHeaders.join(',') + '\n';

      queueRows.forEach(row => {
        const values = queueHeaders.map(header => escapeCSV(row[header]));
        queueCsv += values.join(',') + '\n';
      });

      const queueFilename = `export_queue_${new Date().toISOString().split('T')[0]}.csv`;
      fs.writeFileSync(queueFilename, queueCsv, 'utf8');
      
      console.log(`✅ Экспортировано ${queueRows.length} записей очереди в ${queueFilename}`);
    }

    db.close();
    console.log('\n✅ Экспорт завершен!');
  });
});