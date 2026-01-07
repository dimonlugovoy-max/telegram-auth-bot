// test-api.js
const axios = require('axios');

const API_URL = 'http://localhost:3010';

// Тест 1: Health Check
async function testHealthCheck() {
    console.log('🏥 Тест Health Check...');
    try {
        const response = await axios.get(`${API_URL}/health`);
        console.log('✅ Успех:', response.data);
    } catch (error) {
        console.error('❌ Ошибка:', error.message);
    }
    console.log('');
}

// Тест 2: Генерация ссылки для нового клиента
async function testGenerateLinkNew() {
    console.log('🔗 Тест генерации ссылки (новый клиент)...');
    try {
        const response = await axios.post(`${API_URL}/api/generate-link`, {
            company_id: 123456,
            client_id: 789012,
            phone: '79261234567',
            client_status: 'new'
        });
        console.log('✅ Успех:');
        console.log('Ссылка:', response.data.link);
        console.log('Срок:', response.data.expires_in);
    } catch (error) {
        console.error('❌ Ошибка:', error.response?.data || error.message);
    }
    console.log('');
}

// Тест 3: Генерация ссылки для существующего клиента
async function testGenerateLinkOld() {
    console.log('🔗 Тест генерации ссылки (существующий клиент)...');
    try {
        const response = await axios.post(`${API_URL}/api/generate-link`, {
            company_id: 123456,
            client_id: 789013,
            phone: '79267654321',
            client_status: 'old'
        });
        console.log('✅ Успех:');
        console.log('Ссылка:', response.data.link);
    } catch (error) {
        console.error('❌ Ошибка:', error.response?.data || error.message);
    }
    console.log('');
}

// Тест 4: Проверка статуса
async function testAuthStatus() {
    console.log('📊 Тест проверки статуса аутентификации...');
    try {
        const response = await axios.get(`${API_URL}/api/auth-status/123456/789012`);
        console.log('✅ Успех:', response.data);
    } catch (error) {
        if (error.response?.status === 404) {
            console.log('ℹ️  Клиент не найден (это нормально для первого теста)');
        } else {
            console.error('❌ Ошибка:', error.response?.data || error.message);
        }
    }
    console.log('');
}

// Тест 5: Статистика
async function testStats() {
    console.log('📈 Тест получения статистики...');
    try {
        const response = await axios.get(`${API_URL}/api/stats`);
        console.log('✅ Успех:', response.data);
    } catch (error) {
        console.error('❌ Ошибка:', error.message);
    }
    console.log('');
}

// Запуск всех тестов
async function runAllTests() {
    console.log('═══════════════════════════════════════════');
    console.log('🧪 Запуск тестов API');
    console.log('═══════════════════════════════════════════');
    console.log('');
    
    await testHealthCheck();
    await testGenerateLinkNew();
    await testGenerateLinkOld();
    await testAuthStatus();
    await testStats();
    
    console.log('═══════════════════════════════════════════');
    console.log('✅ Все тесты завершены');
    console.log('═══════════════════════════════════════════');
}

runAllTests();