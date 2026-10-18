// utils/coachPrompt.js
const { getDietaryDate } = require('./dateUtils');

/**
 * Fetches last 3 days of context from Supabase for coach recovery and workout analysis.
 */
async function buildCoachContext(supabase, userId) {
  const threeDaysAgo = getDietaryDate(new Date(), -3);

  const [mealsRes, sleepRes, workoutsRes, activityRes] = await Promise.all([
    supabase
      .from('meals')
      .select('dietary_date, kcal, protein, carbs, fat, tags')
      .eq('user_id', userId)
      .gte('dietary_date', threeDaysAgo)
      .order('dietary_date'),

    supabase
      .from('sleep_logs')
      .select('sleep_date, total_hours, deep_hours, rem_hours, core_hours, awake_hours, hrv_avg_ms, rhr_bpm, vo2max')
      .eq('user_id', userId)
      .gte('sleep_date', threeDaysAgo)
      .order('sleep_date'),

    supabase
      .from('workouts')
      .select('dietary_date, workout_type, duration_min, avg_heart_rate, max_heart_rate, active_kcal, distance_km, avg_pace_min_km, notes')
      .eq('user_id', userId)
      .gte('dietary_date', threeDaysAgo)
      .order('started_at'),

    supabase
      .from('daily_metrics')
      .select('metric_date, steps, active_kcal, distance_km')
      .eq('user_id', userId)
      .gte('metric_date', threeDaysAgo)
      .order('metric_date'),
  ]);

  // Aggregate daily nutrition macros
  const mealsByDay = {};
  for (const meal of (mealsRes.data || [])) {
    const d = meal.dietary_date;
    if (!mealsByDay[d]) {
      mealsByDay[d] = { kcal: 0, protein: 0, carbs: 0, fat: 0, tags: new Set() };
    }
    mealsByDay[d].kcal += Number(meal.kcal) || 0;
    mealsByDay[d].protein += Number(meal.protein) || 0;
    mealsByDay[d].carbs += Number(meal.carbs) || 0;
    mealsByDay[d].fat += Number(meal.fat) || 0;
    (meal.tags || []).forEach(t => mealsByDay[d].tags.add(t));
  }

  return {
    nutrition: Object.entries(mealsByDay).map(([date, v]) => ({
      date,
      total_kcal: Math.round(v.kcal),
      protein_g: Math.round(v.protein),
      carbs_g: Math.round(v.carbs),
      fat_g: Math.round(v.fat),
      tags: [...v.tags],
    })),
    sleep: sleepRes.data || [],
    workouts: workoutsRes.data || [],
    daily_activity: activityRes.data || [],
  };
}

/**
 * Builds the Gemini prompt embedding 3-day recovery, activity, and nutrition context.
 */
function buildCoachPrompt(context) {
  const hasData = (context.nutrition && context.nutrition.length > 0) ||
    (context.sleep && context.sleep.length > 0) ||
    (context.workouts && context.workouts.length > 0) ||
    (context.daily_activity && context.daily_activity.length > 0);

  if (!hasData) {
    return null;
  }

  return `Ти — персональний спортивний аналітик, фізіолог та нутріціолог. Твоя мета — оцінити готовність організму до навантажень, баланс енергії, якість відновлення та дати чіткі рекомендації.
Аналізуй ВИКЛЮЧНО на основі наданих нижче даних. НЕ давай банальних або абстрактних порад — тільки прямі причинно-наслідкові висновки на основі цих цифр.

КОНТЕКСТ (останні 3 дні):

1. ХАРЧУВАННЯ (калорії та БЖВ з урахуванням +12.5% дефіцитного буфера):
${JSON.stringify(context.nutrition, null, 2)}

2. СОН ТА ВІДНОВЛЕННЯ (фази сну, HRV та пульс спокою RHR):
${JSON.stringify(context.sleep, null, 2)}

3. ТРЕНУВАННЯ (біг, силове навантаження, пульсові зони, спалені ккал):
${JSON.stringify(context.workouts, null, 2)}

4. ПОБУТОВА АКТИВНІСТЬ ТА НЕ-ТРЕНУВАЛЬНІ ЕНЕРГОВИТРАТИ (NEAT - кроки, щоденні активні ккал):
${JSON.stringify(context.daily_activity, null, 2)}

ПРАВИЛА ТА СТРУКТУРА ВІДПОВІДІ:
1. ПЕРШИЙ РЯДОК ОБОВ'ЯЗКОВО:
   "СТАН СИСТЕМИ: 🟢" або "СТАН СИСТЕМИ: 🟡" або "СТАН СИСТЕМИ: 🔴"
   - 🟢 = HRV у межах норми (>60-70 мс або стабільний), RHR спокійний (<52 bpm), сон > 7 годин, відновлення повне.
   - 🟡 = помірне навантаження / недосип (сон 6-7 годин, або висока побутова активність >12k кроків, або легке зниження HRV).
   - 🔴 = перевтома / симпатичний стрес (HRV впав >15% від попередніх днів, або RHR зріс на >3 bpm, або сон <5.5 годин, або високе навантаження при сильному дефіциті калорій).

2. Дай РІВНО 4 чіткі інсайти у форматі:
   • **[Короткий заголовок]** → [Фізіологічна причина зі згадкою точних цифр з контексту] → [Конкретна дія на сьогодні/завтра]

3. Обов'язково враховуй побутову активність (NEAT): якщо тренувань не було, але кроків багато (наприклад, 8k-15k), це суттєво впливає на загальний дефіцит калорій та глікоген ніг!

4. Якщо статус 🔴 — перший інсайт ЗАВЖДИ має починатися з: "• **⛔ СТОП / ВІДНОВЛЕННЯ:** ..." з поясненням, чому сьогодні не можна робити інтенсивне тренування.

5. Відповідай українською мовою. Тон — спортивний лікар/аналітик: лаконічно, строго, без "води" та мотиваційних гасел.`;
}

module.exports = { buildCoachContext, buildCoachPrompt };
