# Lifecore: Implementation Plan (Phase 2)
*AI Coach — Workouts, Sleep & Recovery Analysis*

> This document is the step-by-step implementation plan for Phase 2. Each task is self-contained and can be executed in an isolated session. Begin every session by reading [`PROJECT_KNOWLEDGE.md`](./PROJECT_KNOWLEDGE.md) and this file.

---

## Pre-Implementation State

### ✅ Completed & Stable (Do Not Modify)
- Telegram bot: photo and text food logging, `/stats`, `/w`, `/y`, EXIF date extraction
- Supabase Edge Function `telegram-bot` (Deno) — production webhook
- Database tables in Supabase: `meals`, `body_measurements`
- Migration files drafted: `supabase/migrations/002_workouts.sql`, `003_sleep_logs.sql`
- `Lifecore/scripts/sync_to_supabase.py` — ready for execution
- `shortcuts/ingest_health_shortcut.md` — iOS Shortcut specification

### ⚠️ Prerequisites Before Starting
1. **Restore Supabase Project:** Visit the [Supabase Dashboard](https://supabase.com/dashboard/project/khmviccwbuktnvdxhnwg) and click "Restore".
2. Wait for full database reactivation (1–2 minutes).
3. Verify connection: run `node scratch/ping-check.js` — Supabase must report healthy (`status: 200/204`).

---

## Task 1: Database Migrations (Estimated time: 30 min)

**Files:** [`supabase/migrations/002_workouts.sql`](../supabase/migrations/002_workouts.sql), [`supabase/migrations/003_sleep_logs.sql`](../supabase/migrations/003_sleep_logs.sql)

### Steps
1. Navigate to the [Supabase SQL Editor](https://supabase.com/dashboard/project/khmviccwbuktnvdxhnwg/sql/new).
2. Paste and run the contents of `002_workouts.sql`.
3. Paste and run the contents of `003_sleep_logs.sql`.
4. Confirm tables exist in the Supabase Table Editor: `workouts` and `sleep_logs`.

### Success Criteria
```sql
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_name IN ('workouts', 'sleep_logs');
-- Must return 2 rows
```

---

## Task 2: Bulk Historical Archive Ingestion (Estimated time: 1–2 hours)

**Files:** [`Lifecore/scripts/deep_health_analysis.py`](../Lifecore/scripts/deep_health_analysis.py), [`Lifecore/scripts/sync_to_supabase.py`](../Lifecore/scripts/sync_to_supabase.py)

### Steps
```bash
# 1. Install dependencies (if not already installed)
pip install supabase pandas python-dotenv

# 2. Run Apple Health XML streaming parser (takes 2-5 min for 1.97 GB file)
cd Lifecore/
python scripts/deep_health_analysis.py
# → Generates reports/daily_health_summary.json

# 3. Ingest archive into Supabase PostgreSQL
python scripts/sync_to_supabase.py
```

### Expected Output
```
[OK]   sleep_logs: ~XXX records processed.
[OK]   workouts (Apple Health): ~XXX records processed.
[OK]   workouts (Strava): ~XXX records processed.
✅ Sync complete.
```

### Success Criteria
Inspect Supabase Table Editor: verify `workouts` and `sleep_logs` contain historical rows.

---

## Task 3: Edge Function `ingest-health` (Estimated time: 1–2 hours)

**New File to Create:**
- `supabase/functions/ingest-health/index.ts`

### Function Overview
```typescript
// POST /functions/v1/ingest-health
// Auth: "secret" field in JSON body (bypasses JWT headers for iOS Shortcuts)

// 1. Validate incoming secret against INGEST_SECRET
// 2. Parse request body: { user_id, sleep?, workout? }
// 3. If sleep: UPSERT into sleep_logs (onConflict: 'user_id,sleep_date')
// 4. If workout: INSERT into workouts
// 5. Return JSON: { ok: true, inserted: { sleep: boolean, workout: boolean } }
```

### Complete Implementation (`supabase/functions/ingest-health/index.ts`)

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

  // Authentication via body secret
  if (body.secret !== INGEST_SECRET) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 });
  }

  const userId = body.user_id;
  if (!userId) {
    return new Response(JSON.stringify({ error: 'Missing user_id' }), { status: 400 });
  }

  const inserted = { sleep: false, workout: false };

  // Insert or update sleep log
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

  // Insert workout record
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

### Deployment and Verification
```bash
# 1. Set secret in Supabase
supabase secrets set INGEST_SECRET="your_random_secret_32chars"

# 2. Deploy edge function
supabase functions deploy ingest-health --no-verify-jwt --use-api

# 3. Test endpoint with curl
curl -X POST https://<PROJECT-REF>.supabase.co/functions/v1/ingest-health \
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
# Expected response: {"ok":true,"inserted":{"sleep":true,"workout":false}}
```

---

## Task 4: Coach Prompt (`utils/coachPrompt.js`) (Estimated time: 1 hour)

**New File to Create:** [`utils/coachPrompt.js`](./utils/coachPrompt.js)

```javascript
// utils/coachPrompt.js
const { getDietaryDate } = require('./dateUtils');

/**
 * Fetches last 3 days of context from Supabase for coach recovery analysis.
 */
async function buildCoachContext(supabase, userId) {
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

  // Aggregate daily nutrition macros
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
 * Builds the Gemini prompt embedding 3-day recovery and nutrition context.
 */
function buildCoachPrompt(context) {
  const hasData = context.nutrition.length > 0 || context.sleep.length > 0 || context.workouts.length > 0;
  if (!hasData) {
    return null; // Insufficient data
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

## Task 5: Coach Handler (`handlers/coachHandler.js`) (Estimated time: 1–2 hours)

**New File to Create:** [`handlers/coachHandler.js`](./handlers/coachHandler.js)

```javascript
// handlers/coachHandler.js
const { buildCoachContext, buildCoachPrompt } = require('../utils/coachPrompt');

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

    // Call Gemini with cascade fallback (text mode)
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

### Integration in `index.js`
```javascript
// Import coach handler
const coachHandler = require('./handlers/coachHandler');

// Register /coach command
bot.onText(/\/coach/, (msg) => coachHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID));
```

### Parallel Edge Function Implementation
In `supabase/functions/telegram-bot/index.ts`, add the `/coach` command and `🏃 Workout Analysis` button handler mirroring the Node.js implementation.

---

## Task 6: New Buttons in MAIN_KEYBOARD (Estimated time: 30 min)

**Files:** [`utils/keyboard.js`](./utils/keyboard.js) & `supabase/functions/telegram-bot/index.ts`

```javascript
// utils/keyboard.js — updated layout
const MAIN_KEYBOARD = {
  keyboard: [
    [{ text: '📊 Статистика' }, { text: '⚖️ Записати вагу' }],
    [{ text: '📅 Запис за вчора' }, { text: '🏃 Аналіз тренування' }],
  ],
  resize_keyboard: true,
  is_persistent: true,
};
```

In `handlers/textHandler.js`, route the button press:
```javascript
if (text === '🏃 Аналіз тренування') {
  return coachHandler(msg, bot, supabase, genAI, ALLOWED_USER_ID);
}
```

---

## Task 7: iOS Shortcut Integration (Estimated time: 30 min)

Reference specification: [`shortcuts/ingest_health_shortcut.md`](./shortcuts/ingest_health_shortcut.md)

### Quick Setup Steps
1. Launch the Apple Shortcuts application on iOS.
2. Create a new shortcut titled `Lifecore Morning Sync`.
3. Replicate the action blocks detailed in `ingest_health_shortcut.md`.
4. Configure an iOS Automation trigger: "Daily at 09:00 AM" OR "When workout ends".

---

## Recommended Execution Order

```
Task 1 → Task 2 → Task 3 → Task 4 → Task 5 → Task 6 → Task 7
 30m     1-2h     1-2h      1h      1-2h     30m      30m
```

**Total Estimated Duration:** ~6–8 hours of focused development (conveniently partitioned across 3–4 sessions).

---

## Phase 2 Definition of Done (DoD)

- [ ] Tables `workouts` and `sleep_logs` exist in Supabase and contain valid rows.
- [ ] `ingest-health` Edge Function is deployed and passes validation via `curl`.
- [ ] iOS Shortcut sends biometric data and verifies row creation in PostgreSQL.
- [ ] The `/coach` command or `🏃 Workout Analysis` keyboard button returns a diagnosis starting with `SYSTEM STATE: 🟢/🟡/🔴`.
- [ ] All codebase updates committed, pushed to Git, and deployed via `supabase functions deploy telegram-bot --no-verify-jwt --use-api`.
- [ ] `CHANGELOG.md` updated with the Phase 2 release details.

---

## Useful Operational Commands

```bash
# Verify system connectivity and credentials
node scratch/ping-check.js

# Run local Node.js bot for testing
node index.js

# Deploy Supabase Edge Functions
supabase functions deploy telegram-bot --no-verify-jwt --use-api
supabase functions deploy ingest-health --no-verify-jwt --use-api

# Set secrets in Supabase
supabase secrets set INGEST_SECRET="..."

# Commit and push
git add -A && git commit -m "feat: Phase 2 — AI Coach, workouts, sleep_logs" && git push
```
