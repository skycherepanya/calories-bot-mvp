# Lifecore: Implementation Plan (Phase 2)
*AI Coach — Workouts, Sleep & Recovery Analysis*

> Цей документ є покроковим планом реалізації Фази 2. Кожна задача незалежна і може виконуватись у окремій сесії. Починай кожну сесію з читання [`PROJECT_KNOWLEDGE.md`](./PROJECT_KNOWLEDGE.md) та цього файлу.

---

## Стан перед початком

### ✅ Вже зроблено (не чіпати)
- Telegram bot: photo/text food logging, `/stats`, `/w`, `/y`, EXIF extraction
- Supabase Edge Function `telegram-bot` (Deno) — prod webhook
- DB tables in Supabase: `meals`, `body_measurements`
- Migration files written: `supabase/migrations/002_workouts.sql`, `003_sleep_logs.sql`
- `Lifecore/scripts/sync_to_supabase.py` — готовий до запуску
- `shortcuts/ingest_health_shortcut.md` — специфікація iOS Shortcut

### ⚠️ Передумови перед стартом
1. **Відновити Supabase проект** → [Dashboard](https://supabase.com/dashboard/project/khmviccwbuktnvdxhnwg) → кнопка «Restore»
2. Дочекатись повного відновлення (1–2 хвилини)
3. Перевірити: `node scratch/ping-check.js` — Supabase має відповідати ✅

---

## Задача 1: DB Міграції (30 хв)

**Файли:** [`supabase/migrations/002_workouts.sql`](./supabase/migrations/002_workouts.sql), [`supabase/migrations/003_sleep_logs.sql`](./supabase/migrations/003_sleep_logs.sql)

### Кроки
1. Відкрити [Supabase SQL Editor](https://supabase.com/dashboard/project/khmviccwbuktnvdxhnwg/sql/new)
2. Скопіювати та виконати вміст `002_workouts.sql`
3. Скопіювати та виконати вміст `003_sleep_logs.sql`
4. Перевірити в Table Editor: таблиці `workouts` та `sleep_logs` з'явились

### Критерій успіху
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN ('workouts', 'sleep_logs');
-- Має повернути 2 рядки
```

---

## Задача 2: Завантаження Архіву в БД (1–2 год)

**Файли:** [`Lifecore/scripts/deep_health_analysis.py`](./Lifecore/scripts/deep_health_analysis.py), [`Lifecore/scripts/sync_to_supabase.py`](./Lifecore/scripts/sync_to_supabase.py)

### Кроки
```bash
# 1. Встановити залежності (якщо ще не встановлено)
pip install supabase pandas python-dotenv

# 2. Запустити парсер Apple Health (займає 2-5 хв, файл 1.97 GB)
cd Lifecore/
python scripts/deep_health_analysis.py
# → Генерує reports/daily_health_summary.json

# 3. Завантажити архів в Supabase
python scripts/sync_to_supabase.py
```

### Очікуваний вивід
```
[OK]   sleep_logs: ~XXX records processed.
[OK]   workouts (Apple Health): ~XXX records processed.
[OK]   workouts (Strava): ~XXX records processed.
✅ Sync complete.
```

### Критерій успіху
Перевірити в Supabase Table Editor: `workouts` та `sleep_logs` мають записи

---

## Задача 3: Edge Function `ingest-health` (1–2 год)

**Нові файли:**
- `supabase/functions/ingest-health/index.ts` — **створити**

### Логіка функції
```typescript
// POST /functions/v1/ingest-health
// Auth: "secret" field in body (not JWT)

// 1. Validate secret
// 2. Parse body: { user_id, sleep?, workout? }
// 3. If sleep: INSERT INTO sleep_logs (upsert on user_id + sleep_date)
// 4. If workout: INSERT INTO workouts
// 5. Return { ok: true, inserted: { sleep: bool, workout: bool } }
```

### Повна реалізація `index.ts`

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const INGEST_SECRET = Deno.env.get('INGEST_SECRET')!;
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_ANON_KEY')!
);

const SHIFT_HOURS = 4;

function dietaryDate(isoString: string): string {
  const dt = new Date(isoString);
  dt.setHours(dt.getHours() - SHIFT_HOURS);
  return dt.toISOString().split('T')[0];
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid JSON' }), { status: 400 });
  }

  // Auth
  if (body.secret !== INGEST_SECRET) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
  }

  const userId = body.user_id;
  if (!userId) {
    return new Response(JSON.stringify({ error: 'Missing user_id' }), { status: 400 });
  }

  const inserted = { sleep: false, workout: false };

  // Insert sleep
  if (body.sleep) {
    const s = body.sleep;
    const { error } = await supabase.from('sleep_logs').upsert({
      user_id: userId,
      source: 'apple_health',
      sleep_date: s.sleep_date,
      total_hours: s.total_hours ?? null,
      deep_hours: s.deep_hours ?? null,
      rem_hours: s.rem_hours ?? null,
      core_hours: s.core_hours ?? null,
      awake_hours: s.awake_hours ?? null,
      hrv_avg_ms: s.hrv_avg_ms ?? null,
      rhr_bpm: s.rhr_bpm ?? null,
      vo2max: s.vo2max ?? null,
    }, { onConflict: 'user_id,sleep_date' });
    if (error) console.error('[ingest-health] sleep insert error:', error);
    else inserted.sleep = true;
  }

  // Insert workout
  if (body.workout) {
    const w = body.workout;
    const startedAt = w.started_at || new Date().toISOString();
    const { error } = await supabase.from('workouts').insert({
      user_id: userId,
      workout_type: w.type || 'other',
      source: 'apple_health',
      started_at: startedAt,
      duration_min: w.duration_min ?? 0,
      distance_km: w.distance_km ?? null,
      avg_heart_rate: w.avg_heart_rate ?? null,
      max_heart_rate: w.max_heart_rate ?? null,
      active_kcal: w.active_calories ?? null,
      avg_pace_min_km: w.distance_km && w.duration_min
        ? +(w.duration_min / w.distance_km).toFixed(2) : null,
      elevation_m: w.elevation_m ?? null,
      dietary_date: dietaryDate(startedAt),
      raw_data: w,
    });
    if (error) console.error('[ingest-health] workout insert error:', error);
    else inserted.workout = true;
  }

  return new Response(JSON.stringify({ ok: true, inserted }), {
    headers: { 'Content-Type': 'application/json' }
  });
});
```

### Deploy
```bash
# Встановити секрет
supabase secrets set INGEST_SECRET="your_random_secret_32chars"

# Задеплоїти
supabase functions deploy ingest-health --no-verify-jwt --use-api

# Тест (замінити значення)
curl -X POST https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health \
  -H "Content-Type: application/json" \
  -d '{
    "secret": "your_random_secret_32chars",
    "user_id": YOUR_TELEGRAM_ID,
    "sleep": {
      "sleep_date": "2026-10-17",
      "total_hours": 7.2,
      "hrv_avg_ms": 98.5,
      "rhr_bpm": 50.0
    }
  }'
# Очікувана відповідь: {"ok":true,"inserted":{"sleep":true,"workout":false}}
```

---

## Задача 4: Coach Prompt (`utils/coachPrompt.js`) (1 год)

**Новий файл:** [`utils/coachPrompt.js`](./utils/coachPrompt.js)

```javascript
// utils/coachPrompt.js
const { getDietaryDate } = require('./dateUtils');

/**
 * Fetches last 3 days of context from Supabase for the coach analysis.
 */
async function buildCoachContext(supabase, userId) {
  const today = getDietaryDate(new Date(), 0);
  const threeDaysAgo = getDietaryDate(new Date(), -3);

  const [mealsRes, sleepRes, workoutsRes] = await Promise.all([
    supabase
      .from('meals')
      .select('dietary_date, kcal, protein, carbs, fat, tags')
      .eq('user_id', userId)
      .gte('dietary_date', threeDaysAgo)
      .order('dietary_date'),

    supabase
      .from('sleep_logs')
      .select('sleep_date, total_hours, deep_hours, rem_hours, hrv_avg_ms, rhr_bpm')
      .eq('user_id', userId)
      .gte('sleep_date', threeDaysAgo)
      .order('sleep_date'),

    supabase
      .from('workouts')
      .select('dietary_date, workout_type, duration_min, avg_heart_rate, active_kcal, distance_km, avg_pace_min_km')
      .eq('user_id', userId)
      .gte('dietary_date', threeDaysAgo)
      .order('started_at'),
  ]);

  // Aggregate meals by day
  const mealsByDay = {};
  for (const meal of (mealsRes.data || [])) {
    const d = meal.dietary_date;
    if (!mealsByDay[d]) mealsByDay[d] = { kcal: 0, protein: 0, carbs: 0, fat: 0, tags: new Set() };
    mealsByDay[d].kcal += meal.kcal;
    mealsByDay[d].protein += meal.protein;
    mealsByDay[d].carbs += meal.carbs;
    mealsByDay[d].fat += meal.fat;
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
  };
}

/**
 * Builds the Gemini system prompt with context data embedded.
 */
function buildCoachPrompt(context) {
  const hasData = context.nutrition.length > 0 || context.sleep.length > 0 || context.workouts.length > 0;
  if (!hasData) {
    return null; // No data to analyze
  }

  return `Ти — персональний спортивний аналітик і нутріціолог. Аналізуй ВИКЛЮЧНО на основі наданих даних.
НЕ давай загальних порад з інтернету — тільки причинно-наслідкові висновки на основі цих конкретних цифр.

КОНТЕКСТ (останні 3 дні):

ХАРЧУВАННЯ:
${JSON.stringify(context.nutrition, null, 2)}

СОН ТА ВІДНОВЛЕННЯ:
${JSON.stringify(context.sleep, null, 2)}

ТРЕНУВАННЯ:
${JSON.stringify(context.workouts, null, 2)}

ПРАВИЛА ВІДПОВІДІ:
1. ПЕРШИЙ РЯДОК обов'язково: "СТАН СИСТЕМИ: 🟢" або "🟡" або "🔴" — на основі HRV + RHR + сон.
   - 🟢 = HRV в нормі, RHR стабільний, сон >7h
   - 🟡 = незначні відхилення (HRV -10%, або сон 6-7h, або RHR +2 bpm)
   - 🔴 = HRV впав >15% від попередніх днів, або RHR >+3 bpm, або сон <5.5h
2. Дай РІВНО 4 інсайти у форматі: **[Спостереження]** → [фізіологічна причина] → [конкретна рекомендація]
3. Якщо стан 🔴 — перший інсайт ЗАВЖДИ: "⛔ СТОП / ВІДНОВЛЕННЯ: ..." з поясненням чому
4. Кожен інсайт спирається на конкретні цифри з контексту
5. Відповідай українською. Без мотиваційного тону — тільки факти та дії.
6. Не вигадуй дані яких немає — якщо якогось показника бракує, прямо скажи`;
}

module.exports = { buildCoachContext, buildCoachPrompt };
```

---

## Задача 5: Coach Handler (`handlers/coachHandler.js`) (1–2 год)

**Новий файл:** [`handlers/coachHandler.js`](./handlers/coachHandler.js)

```javascript
// handlers/coachHandler.js
const { buildCoachContext, buildCoachPrompt } = require('../utils/coachPrompt');
const { generateMealJSON } = require('../utils/gemini');

async function coachHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID) {
  const chatId = msg.chat.id;
  if (chatId !== ALLOWED_USER_ID) return;

  await bot.sendChatAction(chatId, 'typing');

  try {
    const context = await buildCoachContext(supabase, ALLOWED_USER_ID);
    const prompt = buildCoachPrompt(context);

    if (!prompt) {
      await bot.sendMessage(chatId,
        '📊 Недостатньо даних для аналізу.\n\nЛогуй їжу, вагу та тренування кілька днів, щоб Coach міг знайти закономірності.',
        { parse_mode: 'Markdown' }
      );
      return;
    }

    // Use Gemini with text prompt (not JSON mode — we want natural language)
    const models = ['gemini-2.5-flash', 'gemini-3.6-flash'];
    let response = null;

    for (const modelName of models) {
      try {
        const model = genAI.getGenerativeModel({ model: modelName });
        const result = await model.generateContent(prompt);
        response = result.response.text().trim();
        break;
      } catch (err) {
        console.warn(`[Coach] ${modelName} failed:`, err.message);
      }
    }

    if (!response) throw new Error('All Gemini models failed');

    await bot.sendMessage(chatId, response, { parse_mode: 'Markdown' });

  } catch (err) {
    console.error('[coachHandler] Error:', err.message);
    await bot.sendMessage(chatId, '⚠️ Помилка аналізу. Спробуй пізніше.');
  }
}

module.exports = coachHandler;
```

### Підключення в `index.js`
```javascript
// Додати в index.js:
const coachHandler = require('./handlers/coachHandler');

// Додати до обробників:
bot.onText(/\/coach/, (msg) => coachHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID));
```

### Паралельна реалізація в Edge Function
У `supabase/functions/telegram-bot/index.ts` додати обробку команди `/coach` та кнопки `🏃 Аналіз тренування` аналогічно Node.js логіці.

---

## Задача 6: Нові Кнопки в MAIN_KEYBOARD (30 хв)

**Файл:** [`utils/keyboard.js`](./utils/keyboard.js) + `supabase/functions/telegram-bot/index.ts`

```javascript
// utils/keyboard.js — нова версія
const MAIN_KEYBOARD = {
  keyboard: [
    [{ text: '📊 Статистика' }, { text: '⚖️ Записати вагу' }],
    [{ text: '📅 Запис за вчора' }, { text: '🏃 Аналіз тренування' }],
  ],
  resize_keyboard: true,
  is_persistent: true,
};
```

У `textHandler.js` додати:
```javascript
if (text === '🏃 Аналіз тренування') {
  return coachHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID);
}
```

---

## Задача 7: iOS Shortcut (30 хв — після Задачі 3)

Дивись детальну специфікацію: [`shortcuts/ingest_health_shortcut.md`](./shortcuts/ingest_health_shortcut.md)

### Швидкий старт
1. Відкрити Apple Shortcuts на iPhone
2. Створити новий Shortcut з назвою `Lifecore Morning Sync`
3. Реалізувати логіку з `ingest_health_shortcut.md`
4. Налаштувати Automation: «Щодня о 09:00» АБО «Після завершення тренування»

---

## Порядок виконання (рекомендований)

```
Задача 1 → Задача 2 → Задача 3 → Задача 4 → Задача 5 → Задача 6 → Задача 7
   30хв      1-2год      1-2год     1год        1-2год      30хв       30хв
```

**Загальний час:** ~6–8 годин розробки (можна розбити на 3–4 сесії)

---

## Критерій завершення Фази 2

- [ ] Taблиці `workouts` та `sleep_logs` є в Supabase і мають реальні дані
- [ ] `ingest-health` Edge Function задеплоєна і відповідає на тестовий curl
- [ ] iOS Shortcut відправляє дані і вони з'являються в БД
- [ ] Команда `/coach` або кнопка `🏃 Аналіз тренування` в Telegram повертає аналіз з `СТАН СИСТЕМИ: 🟢/🟡/🔴`
- [ ] Весь код задеплоєний: `git commit + push`, `supabase functions deploy telegram-bot --no-verify-jwt --use-api`
- [ ] `CHANGELOG.md` оновлено з описом Фази 2

---

## Корисні команди

```bash
# Перевірка стану системи
node scratch/ping-check.js

# Локальний запуск бота (тестування)
node index.js

# Deploy Edge Functions
supabase functions deploy telegram-bot --no-verify-jwt --use-api
supabase functions deploy ingest-health --no-verify-jwt --use-api

# Встановити секрет
supabase secrets set INGEST_SECRET="..."

# Git
git add -A && git commit -m "feat: Phase 2 — AI Coach, workouts, sleep_logs" && git push
```
