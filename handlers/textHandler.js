const { SYSTEM_PROMPT } = require('../utils/prompt');
const { getDietaryDate, getStatsMessage } = require('../utils/dateUtils');
const { generateMealJSON } = require('../utils/gemini');
const { MAIN_KEYBOARD } = require('../utils/keyboard');
const weightHandler = require('./weightHandler');

module.exports = async (msg, bot, supabase, genAI, allowedUserId) => {
    const chatId = msg.chat.id;
    const text = msg.text ? msg.text.trim() : "";

    if (chatId !== allowedUserId) return;

    // 0. /start command
    if (text === '/start') {
        const welcome = "👋 **Вітаю у Lifecore!**\n\n" +
            "📸 **Їжа:** надішліть фото або опис страви текстом.\n" +
            "⚖️ **Вага:** кнопка «Записати вагу» або просто введіть число (наприклад `76.2`).\n" +
            "📅 **Вчора:** кнопка «Запис за вчора» для внесення страв за минулий день.\n" +
            "📊 **Статистика:** перегляд денного звіту та порад нутриціолога.";
        return bot.sendMessage(chatId, welcome, { parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD });
    }

    // 1. /stats command or "📊 Статистика" button
    if (text === '/stats' || text === '📊 Статистика') {
        const todayDate = getDietaryDate();
        const { text: statsText, replyMarkup } = await getStatsMessage(supabase, chatId, todayDate);
        return bot.sendMessage(chatId, statsText, { parse_mode: 'Markdown', reply_markup: replyMarkup });
    }

    // 2. "⚖️ Записати вагу" button
    if (text === '⚖️ Записати вагу') {
        return bot.sendMessage(chatId, "⚖️ Введіть ваше значення ваги у кг (наприклад: `76.2`):", {
            parse_mode: 'Markdown',
            reply_markup: {
                force_reply: true,
                input_field_placeholder: "76.2"
            }
        });
    }

    // 3. "📅 Запис за вчора" button
    if (text === '📅 Запис за вчора') {
        return bot.sendMessage(chatId, "📅 Надішліть фото або опис страви, яку ви з'їли вчора:", {
            reply_markup: {
                force_reply: true,
                input_field_placeholder: "Опис страви за вчора..."
            }
        });
    }

    // 4. Check for weight input:
    // Either via /w, or reply to weight prompt, or just a weight number (30-350 kg)
    let detectedWeight = null;
    if (text.toLowerCase().startsWith('/w')) {
        return weightHandler(msg, bot, supabase, allowedUserId);
    }
    if (msg.reply_to_message && msg.reply_to_message.text && msg.reply_to_message.text.includes("ваги у кг")) {
        const numMatch = text.match(/^([\d]+(?:[.,][\d]+)?)/);
        if (numMatch) detectedWeight = parseFloat(numMatch[1].replace(',', '.'));
    } else {
        const pureNumMatch = text.match(/^([\d]{2,3}(?:[.,][\d]+)?)(?:\s*(?:кг|kg))?$/i);
        if (pureNumMatch) {
            const val = parseFloat(pureNumMatch[1].replace(',', '.'));
            if (val >= 30 && val <= 350) detectedWeight = val;
        }
    }
    if (detectedWeight !== null) {
        return weightHandler(msg, bot, supabase, allowedUserId, detectedWeight);
    }

    // 5. Support for yesterday's log (/y or reply to "з'їли вчора" prompt)
    let offsetDays = 0;
    let isYesterday = false;
    let textToAnalyze = text;

    if (text.toLowerCase().startsWith('/y')) {
        offsetDays = -1;
        isYesterday = true;
        textToAnalyze = text.replace(/^\/y\s*/i, '').trim();
        if (!textToAnalyze) {
            return bot.sendMessage(chatId, "ℹ️ Напишіть опис їжі після `/y`, наприклад: `/y 2 варених яйця і тост`", { parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD });
        }
    } else if (msg.reply_to_message && msg.reply_to_message.text && msg.reply_to_message.text.includes("з'їли вчора")) {
        offsetDays = -1;
        isYesterday = true;
    } else if (text.startsWith('/')) {
        return;
    }

    const targetDate = getDietaryDate(new Date(), offsetDays);
    const progressPrefix = isYesterday ? "⏳ Рахую калорії за прийом (за вчора)..." : "✍️ Рахую калорії за прийом...";
    bot.sendMessage(chatId, progressPrefix);

    try {
        const mealData = await generateMealJSON(genAI, [
            SYSTEM_PROMPT,
            `Here is the meal description: ${textToAnalyze}`
        ]);

        const { error } = await supabase.from('meals').insert([{
            user_id: chatId,
            meal_name: mealData.meal_name,
            kcal: mealData.kcal,
            protein: mealData.protein,
            fat: mealData.fat,
            carbs: mealData.carbs,
            weight_g: mealData.weight_g,
            confidence: mealData.confidence,
            tags: mealData.tags || [],
            micronutrients: mealData.micronutrients || {},
            amino_acids: mealData.amino_acids || {},
            dietary_date: targetDate
        }]);

        if (error) throw new Error("Supabase error: " + error.message);

        const yesterdayMarker = isYesterday ? "📅 **[Записано за вчора]**\n" : "";
        const replyText = `${yesterdayMarker}🍽 **${mealData.meal_name}**\n\n` +
            `🔥 Калорії: **${mealData.kcal} ккал**\n` +
            `🥩 Білки: **${mealData.protein}г** | 🥑 Жири: **${mealData.fat}г** | 🍞 Вуглеводи: **${mealData.carbs}г**\n` +
            `⚖️ Вага: ~**${mealData.weight_g}г**\n` +
            `🤖 Впевненість AI: ${mealData.confidence}%`;

        bot.sendMessage(chatId, replyText, {
            parse_mode: 'Markdown',
            reply_markup: MAIN_KEYBOARD
        });

    } catch (error) {
        console.error('Text pipeline error:', error);
        bot.sendMessage(chatId, "❌ Упс. Не зміг розібрати текст. Спробуй описати інакше.");
    }
};