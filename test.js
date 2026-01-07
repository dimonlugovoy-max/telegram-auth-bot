// test.js
require('dotenv').config();
const axios = require('axios');

const BASE_URL = `http://localhost:${process.env.PORT || 3000}`;

async function runTests() {
  console.log('🧪 Запуск тестов...\n');

  // 1. Health Check
  try {
    const health = await axios.get(`${BASE_URL}/health`);
    console.log('✅ Health Check:', health.data);
  } catch (error) {
    console.error('❌ Health Check failed:', error.message);
    return;
  }

  // 2. Генерация ссылки для нового клиента
  try {
    const newClientLink = await axios.post(`${BASE_URL}/api/generate-link`, {
      company_id: 123456,
      client_id: 789012,
      phone: '79261234567',
      client_status: 'new'
    });
    console.log('\n✅ Ссылка для нового клиента:');
    console.log(newClientLink.data.link);
  } catch (error) {
    console.error('❌ Генерация ссылки (new) failed:', error.response?.data || error.message);
  }

  // 3. Генерация ссылки для существующего клиента
  try {
    const oldClientLink = await axios.post(`${BASE_URL}/api/generate-link`, {
      company_id: 123456,
      client_id: 789013,
      phone: '79267654321',
      client_status: 'old'
    });
    console.log('\n✅ Ссылка для существующего клиента:');
    console.log(oldClientLink.data.link);
  } catch (error) {
    console.error('❌ Генерация ссылки (old) failed:', error.response?.data || error.message);
  }

  // 4. Проверка статистики
  try {
    const stats = await axios.get(`${BASE_URL}/api/stats`);
    console.log('\n✅ Статистика:');
    console.log(stats.data);
  } catch (error) {
    console.error('❌ Статистика failed:', error.message);
  }

  // 5. Проверка очереди
  try {
    const queue = await axios.get(`${BASE_URL}/api/retry-queue`);
    console.log('\n✅ Очередь повторных попыток:');
    console.log(`Задач в очереди: ${queue.data.count}`);
  } catch (error) {
    console.error('❌ Очередь failed:', error.message);
  }

  // 6. Проверка несуществующего клиента
  try {
    const status = await axios.get(`${BASE_URL}/api/auth-status/999999/999999`);
    console.log('\n✅ Статус несуществующего клиента:');
    console.log(status.data);
  } catch (error) {
    if (error.response?.status === 404) {
      console.log('\n✅ Корректная обработка несуществующего клиента:', error.response.data);
    } else {
      console.error('❌ Проверка статуса failed:', error.message);
    }
  }

  console.log('\n🎉 Тесты завершены!');
}

// Запуск тестов
if (require.main === module) {
  runTests().catch(console.error);
}

module.exports = { runTests };