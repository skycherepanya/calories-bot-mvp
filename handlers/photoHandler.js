const { SYSTEM_PROMPT } = require('../utils/prompt');
const { getDietaryDate } = require('../utils/dateUtils');
const { generateMealJSON } = require('../utils/gemini');
const { MAIN_KEYBOARD } = require('../utils/keyboard');

async function getPhotoBase64(bot, fileId) {
    const fileLink = await bot.getFileLink(fileId);
    const response = await fetch(fileLink);
    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer).toString('base64');
}

module.exports = async (msg, bot, supabase, genAI, allowedUserId) => {
    const chatId = msg.chat.id;
    if (chatId !== allowedUserId) return;

    let offsetDays = 0;
    let isYesterday = false;
    let rawCaption = msg.caption ? msg.caption.trim() : "";

    if (rawCaption.toLowerCase().startsWith('/y')) {
        offsetDays = -1;
        isYesterday = true;
        rawCaption = rawCaption.replace(/^\/y\s*/i, '').trim();
    } else if (msg.reply_to_message && msg.reply_to_message.text && msg.reply_to_message.text.includes("з'їли вчора")) {
        offsetDays = -1;
        isYesterday = true;
    }

    const targetDate = getDietaryDate(new Date(), offsetDays);
    const progressPrefix = isYesterday ? "⏳ Рахую калорії за прийом (за вчора)..." : "📸 Рахую калорії за прийом...";
    bot.sendMessage(chatId, progressPrefix);

    try {
        const photo = msg.photo[msg.photo.length - 1];
        const fileId = photo.file_id;
        const base64Image = await getPhotoBase64(bot, fileId);

        const captionContext = rawCaption ? `\nAdditional user description: ${rawCaption}` : "";

        const mealData = await generateMealJSON(genAI, [
            SYSTEM_PROMPT + captionContext,
            { inlineData: { data: base64Image, mimeType: "image/jpeg" } }
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
            dietary_date: targetDate,
            telegram_file_id: fileId
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
        console.error('Photo pipeline error:', error);
        bot.sendMessage(chatId, "❌ Упс. Щось зламалося (перевір консоль).");
    }
};