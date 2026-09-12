// index.js
require('dotenv').config();
const TelegramBot = require('node-telegram-bot-api').default || require('node-telegram-bot-api');
const { createClient } = require('@supabase/supabase-js');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Import handlers
const photoHandler = require('./handlers/photoHandler');
const textHandler = require('./handlers/textHandler');
const callbackHandler = require('./handlers/callbackHandler');

// 1. Initialize clients
const bot = new TelegramBot(process.env.TELEGRAM_BOT_TOKEN, { polling: true });
const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_KEY);
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
const ALLOWED_USER_ID = parseInt(process.env.ALLOWED_USER_ID, 10);

console.log('🤖 Bot is running. Waiting for food (photo or text)...');

// 2. Connect handlers and pass instances
bot.on('photo', (msg) => photoHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID));
bot.on('text', (msg) => textHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID));
bot.on('callback_query', (query) => callbackHandler(query, bot, supabase));