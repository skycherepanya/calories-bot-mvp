// handlers/coachHandler.js
const { buildCoachContext, buildCoachPrompt } = require('../utils/coachPrompt');
const { MAIN_KEYBOARD } = require('../utils/keyboard');

async function coachHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID) {
  const chatId = msg.chat.id;
  if (chatId !== ALLOWED_USER_ID) return;

  try {
    await bot.sendChatAction(chatId, 'typing');
  } catch (_) {}

  try {
    const context = await buildCoachContext(supabase, ALLOWED_USER_ID);
    const prompt = buildCoachPrompt(context);

    if (!prompt) {
      return bot.sendMessage(
        chatId,
        '📊 **Недостатньо даних для аналізу тренера.**\n\n' +
        'Логуй їжу, вагу та синхронізуй сон/тренування з Apple Health, щоб Coach міг проаналізувати відновлення та готовність до навантажень.',
        { parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD }
      );
    }

    const models = ['gemini-2.5-flash', 'gemini-3.8-flash', 'gemini-3.6-flash'];
    let textResponse = null;

    for (const modelName of models) {
      try {
        const model = genAI.getGenerativeModel({ model: modelName });
        const generatePromise = model.generateContent(prompt);
        const timeoutPromise = new Promise((_, reject) => setTimeout(() => reject(new Error('Timeout')), 25000));
        const result = await Promise.race([generatePromise, timeoutPromise]);
        textResponse = result.response.text().trim();
        if (textResponse) break;
      } catch (err) {
        console.warn(`[Coach] Model ${modelName} failed or timed out:`, err.message);
      }
    }

    if (!textResponse) {
      throw new Error('All Gemini models failed for Coach prompt');
    }

    try {
      await bot.sendMessage(chatId, textResponse, { parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD });
    } catch (parseErr) {
      // Fallback if Markdown syntax was malformed by LLM
      console.warn('[Coach] Markdown send failed, sending as plain text:', parseErr.message);
      await bot.sendMessage(chatId, textResponse, { reply_markup: MAIN_KEYBOARD });
    }

  } catch (err) {
    console.error('[coachHandler] Error:', err.message);
    await bot.sendMessage(chatId, '⚠️ Помилка аналізу тренера. Спробуйте трохи пізніше.', { reply_markup: MAIN_KEYBOARD });
  }
}

module.exports = coachHandler;
