const { SYSTEM_PROMPT } = require('../utils/prompt');
const { getDietaryDate } = require('../utils/dateUtils');
const { generateMealJSON } = require('../utils/gemini');
const { MAIN_KEYBOARD } = require('../utils/keyboard');
const ExifReader = require('exifreader');

async function getPhotoBuffer(bot, fileId) {
    const fileLink = await bot.getFileLink(fileId);
    const response = await fetch(fileLink);
    const arrayBuffer = await response.arrayBuffer();
    return Buffer.from(arrayBuffer);
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

    const progressPrefix = isYesterday ? "⏳ Рахую калорії за прийом (за вчора)..." : "📸 Рахую калорії за прийом...";
    bot.sendMessage(chatId, progressPrefix);

    try {
        let fileId;
        if (msg.photo && msg.photo.length > 0) {
            fileId = msg.photo[msg.photo.length - 1].file_id;
        } else if (msg.document) {
            fileId = msg.document.file_id;
            const mime = msg.document.mime_type;
            if (!mime || !mime.startsWith('image/')) {
                bot.sendMessage(chatId, "⚠️ Будь ласка, надішліть файл зображення.");
                return;
            }
        } else {
            return;
        }

        const imageBuffer = await getPhotoBuffer(bot, fileId);
        const base64Image = imageBuffer.toString('base64');

        let photoDate = new Date(msg.forward_date ? msg.forward_date * 1000 : msg.date * 1000);
        try {
            const tags = ExifReader.load(imageBuffer);
            const dateStr = tags['DateTimeOriginal']?.description || tags['Creation Date']?.description || tags['CreateDate']?.description;
            if (dateStr) {
                const isoStr = dateStr.replace(/^(\d{4}):(\d{2}):(\d{2})/, '$1-$2-$3');
                const parsed = new Date(isoStr);
                if (!isNaN(parsed.getTime())) {
                    photoDate = parsed;
                }
            }
        } catch (e) {
            console.log("ExifReader parsing error:", e.message);
        }

        const targetDate = getDietaryDate(photoDate, offsetDays);

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
            created_at: photoDate.toISOString(),
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