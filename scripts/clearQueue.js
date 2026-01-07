// scripts/clearQueue.js (очистка очереди)

require('dotenv').config();
const sqlite3 = require('sqlite3').verbose();
const readline = require('readline');

const db = new sqlite3.Database('./bot.db');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

db.get('SELECT COUNT(*) as count FROM retry_queue', (err, row) => {
  if (err) {
    console.error('❌ Ошибка:', err);
    db.close();
    process.exit(1);
  }

  const queueSize = row.count;

  if (queueSize === 0) {
    console.log('✅ Очередь уже пуста');
    db.close();
    process.exit(0);
  }

  console.log(`⚠️  В очереди ${queueSize} задач`);
  
  rl.question('Очистить всю очередь? (yes/no): ', (answer) => {
    if (answer.toLowerCase() === 'yes') {
      db.run('DELETE FROM retry_queue', (err) => {
        if (err) {
          console.error('❌ Ошибка очистки:', err);
        } else {
          console.log('✅ Очередь очищена');
        }
        db.close();
        rl.close();
      });
    } else {
      console.log('Отменено');
      db.close();
      rl.close();
    }
  });
});