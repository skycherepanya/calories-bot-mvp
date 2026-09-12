// utils/dateUtils.js

function getDietaryDate(date = new Date(), offsetDays = 0) {
    const shiftHours = 4; // Baseline - 04:00 AM
    const adjustedDate = new Date(date);

    // 4-hour shift (until 03:59 counts as the previous day)
    adjustedDate.setHours(adjustedDate.getHours() - shiftHours);

    if (offsetDays !== 0) {
        adjustedDate.setDate(adjustedDate.getDate() + offsetDays);
    }

    return adjustedDate.toISOString().split('T')[0];
}

async function getStatsMessage(supabase, userId, targetDate) {
    // 1. Fetch meals for the date
    const { data: meals, error } = await supabase
        .from('meals')
        .select('*')
        .eq('user_id', userId)
        .eq('dietary_date', targetDate);

    if (error) throw error;

    // 2. Fetch logged weight for the day
    let dayWeight = null;
    try {
        const { data: weightLogs } = await supabase
            .from('body_measurements')
            .select('weight_kg, measured_at')
            .eq('user_id', userId)
            .eq('dietary_date', targetDate)
            .order('measured_at', { ascending: false })
            .limit(1);

        if (weightLogs && weightLogs.length > 0) {
            dayWeight = weightLogs[0].weight_kg;
        }
    } catch (_) {
        // If table doesn't exist yet or error, continue
    }

    let totalKcal = 0, totalProtein = 0, totalFat = 0, totalCarbs = 0;
    let totalFiber = 0, totalSodium = 0, totalBcaa = 0;
    let wholeFoodCount = 0, ultraProcessedCount = 0, hasHighSodium = false;
    let mealNames = [];

    (meals || []).forEach(meal => {
        totalKcal += Number(meal.kcal) || 0;
        totalProtein += Number(meal.protein) || 0;
        totalFat += Number(meal.fat) || 0;
        totalCarbs += Number(meal.carbs) || 0;
        mealNames.push(meal.meal_name);

        const micro = meal.micronutrients || {};
        totalFiber += Number(micro.fiber_g) || 0;
        totalSodium += Number(micro.sodium_mg) || 0;

        const amino = meal.amino_acids || {};
        totalBcaa += Number(amino.bcaa_g) || 0;

        const tags = Array.isArray(meal.tags) ? meal.tags : [];
        if (tags.includes('whole_food')) wholeFoodCount++;
        if (tags.includes('ultra_processed')) ultraProcessedCount++;
        if (tags.includes('high_sodium')) hasHighSodium = true;
    });

    const mealsList = mealNames.length > 0 ? mealNames.join(', ') : 'Нічого не знайдено 텅';

    // 3. Generate recommendations and diet analysis
    let recommendations = [];

    if (meals && meals.length > 0) {
        // Protein analysis
        if (totalProtein < 100) {
            recommendations.push(`• 🥩 **Білок:** Бажано додати більше м'яса, риби, яєць або сиру для захисту м'язів.`);
        } else {
            recommendations.push(`• 🥩 **Білок:** Норму виконано (${Math.round(totalProtein)}г) — м'язи під надійним захистом.`);
        }

        // Fiber analysis
        if (totalFiber < 20) {
            recommendations.push(`• 🌾 **Клітковина:** Малувато — додайте свіжих овочів, зелені або ягід для травлення.`);
        }

        // Sodium and water retention
        if (totalSodium > 2300 || hasHighSodium) {
            recommendations.push(`• 🧂 **Водний баланс:** Були солоні або перероблені страви — завтра очікується тимчасова затримка води. Це не жир!`);
        }

        // Quality balance and calorie saving tips
        if (ultraProcessedCount > 0) {
            recommendations.push(`• 🥗 **Якість продуктів:** Було ${ultraProcessedCount} ультраперероблених страв. Більше цільної їжі прискорить спалювання калорій.`);
        }

        if (totalKcal > 2200) {
            recommendations.push(`• 💡 **Де зекономити:** Зменшіть кількість доданої олії, соусів або рідких калорій.`);
        }
    } else {
        recommendations.push("• ℹ️ Записів їжі за цей день поки що немає.");
    }

    const weightLine = dayWeight !== null 
        ? `⚖️ Вага за день: **${dayWeight} кг**\n` 
        : `⚖️ Вага за день: *не записана (додайте через /w <вага>)*\n`;

    const text = `📊 **Статистика за ${targetDate}**\n\n` +
        weightLine +
        `🔥 Калорії: **${Math.round(totalKcal)} ккал**\n` +
        `🥩 Білки: **${Math.round(totalProtein)}г** | 🥑 Жири: **${Math.round(totalFat)}г** | 🍞 Вуглеводи: **${Math.round(totalCarbs)}г**\n\n` +
        `🍽 **З'їдено:** ${mealsList}\n\n` +
        `🧠 **Аналіз раціону та поради:**\n` +
        recommendations.join('\n');

    // Navigation buttons "Yesterday" and "Tomorrow"
    const curr = new Date(targetDate);

    const prev = new Date(curr);
    prev.setDate(prev.getDate() - 1);
    const prevStr = prev.toISOString().split('T')[0];

    const next = new Date(curr);
    next.setDate(next.getDate() + 1);
    const nextStr = next.toISOString().split('T')[0];

    const replyMarkup = {
        inline_keyboard: [[
            { text: "⬅️", callback_data: `stats_${prevStr}` },
            { text: "➡️", callback_data: `stats_${nextStr}` }
        ]]
    };

    return { text, replyMarkup };
}

module.exports = { getDietaryDate, getStatsMessage };