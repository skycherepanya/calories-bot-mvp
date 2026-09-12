const { getStatsMessage } = require('../utils/dateUtils');

module.exports = async (query, bot, supabase) => {
    const chatId = query.message.chat.id;
    const messageId = query.message.message_id;
    const data = query.data;

    try {
        if (data.startsWith('stats_')) {
            const targetDate = data.split('_')[1];
            const { text, replyMarkup } = await getStatsMessage(supabase, chatId, targetDate);

            // Replace the current message with new data
            await bot.editMessageText(text, {
                chat_id: chatId,
                message_id: messageId,
                parse_mode: 'Markdown',
                reply_markup: replyMarkup
            });
        }
        else if (data === 'confirm') {
            await bot.sendMessage(chatId, "✅ Дані вже надійно лежать у Supabase!");
        }
        else if (data === 'edit') {
            await bot.sendMessage(chatId, "✏️ Функція редагування в розробці.");
        }
    } catch (error) {
        // If the button for the same day is pressed, Telegram will throw an error because the text hasn't changed. Just ignore it.
        console.error("Callback error:", error.message);
    }

    bot.answerCallbackQuery(query.id);
};