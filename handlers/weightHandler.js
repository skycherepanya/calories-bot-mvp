// handlers/weightHandler.js
const { getDietaryDate } = require('../utils/dateUtils');
const { MAIN_KEYBOARD } = require('../utils/keyboard');

module.exports = async (msg, bot, supabase, allowedUserId, weightOverride = null) => {
    const chatId = msg.chat.id;
    if (chatId !== allowedUserId) return;

    let weight = weightOverride;
    if (weight === null) {
        const text = msg.text ? msg.text.trim() : "";
        const match = text.match(/^\/w(?:\s+([\d]+(?:[.,][\d]+)?))?(?:\s*kg)?$/i);

        if (!match || !match[1]) {
            return bot.sendMessage(
                chatId,
                "⚖️ Введіть ваше значення ваги у кг (наприклад: `76.2`):",
                {
                    parse_mode: 'Markdown',
                    reply_markup: {
                        force_reply: true,
                        input_field_placeholder: "76.2"
                    }
                }
            );
        }

        const rawWeight = match[1].replace(',', '.');
        weight = parseFloat(rawWeight);
    }

    if (isNaN(weight) || weight < 30 || weight > 350) {
        return bot.sendMessage(chatId, "⚠️ Будь ласка, введіть реальну вагу від 30 до 350 кг.", { reply_markup: MAIN_KEYBOARD });
    }

    const dietaryDate = getDietaryDate();

    try {
        // 1. Get the previous record to calculate dynamics (delta)
        const { data: prevData } = await supabase
            .from('body_measurements')
            .select('weight_kg, measured_at, dietary_date')
            .eq('user_id', chatId)
            .order('measured_at', { ascending: false })
            .limit(1);

        let deltaText = "";
        if (prevData && prevData.length > 0) {
            const prevWeight = prevData[0].weight_kg;
            const diff = (weight - prevWeight).toFixed(1);
            if (diff > 0) {
                deltaText = `📈 Динаміка: **+${diff} кг** (з минулого заміру ${prevWeight} кг)`;
            } else if (diff < 0) {
                deltaText = `📉 Динаміка: **${diff} кг** (з минулого заміру ${prevWeight} кг)`;
            } else {
                deltaText = `⏸ Динаміка: **без змін** (${prevWeight} кг)`;
            }
        }

        // 2. Save the new measurement to the body_measurements table
        const { error: insertError } = await supabase
            .from('body_measurements')
            .insert([{
                user_id: chatId,
                weight_kg: weight,
                dietary_date: dietaryDate,
                source: 'telegram_w'
            }]);

        if (insertError) throw insertError;

        // 3. Optionally sync with daily_metrics (if the table is set up)
        try {
            await supabase
                .from('daily_metrics')
                .upsert([{
                    user_id: chatId,
                    metric_date: dietaryDate,
                    morning_weight_kg: weight
                }], { onConflict: 'user_id,metric_date' });
        } catch (_) {
            // Ignore if daily_metrics is not yet used
        }

        let reply = `⚖️ **Вагу успішно записано: ${weight} кг**\n📅 Дієтична дата: \`${dietaryDate}\`\n`;
        if (deltaText) {
            reply += `\n${deltaText}\n`;
        }
        reply += `\n💡 *Пам'ятайте: 1 г глікогену затримує 3-4 г води. Щоденні коливання 1-2 кг є нормою водного балансу!*`;

        await bot.sendMessage(chatId, reply, { parse_mode: 'Markdown', reply_markup: MAIN_KEYBOARD });

    } catch (error) {
        console.error("Weight save error:", error);
        bot.sendMessage(chatId, "❌ Не вдалося зберегти вагу в базу. Перевірте консоль / Supabase.", { reply_markup: MAIN_KEYBOARD });
    }
};
