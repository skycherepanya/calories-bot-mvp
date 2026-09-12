# Project Master Context: Lifecore (Quantified Self Health Data Warehouse)

> **File Purpose:** This file serves as the Single Source of Truth for AI agents and developers. It contains the full project description, vision, domain mathematics, architecture, current code status, and step-by-step development roadmap to avoid repetitive file searches and excessive token usage.

---

## 1. High-Level Vision

* **Project Name:** Lifecore (Quantified Self Health & Nutrition Data Warehouse)
* **Current Repository (MVP):** `calories-bot-mvp`
* **Main Goal:** Build a modular, scalable ecosystem for collecting, aggregating, analyzing, and finding hidden correlations between nutrition, body composition, activity, sleep, and overall well-being.
* **Problem with Existing Solutions:**
  - Commercial apps lock functionality behind subscriptions (vendor lock-in) and don't provide full access to raw historical data.
  - High barrier to entry (requires manual typing or weighing every gram).
  - Data isolation: fitness trackers don't know about food quality, and calorie counters don't account for water retention or muscle recovery phases.
* **Core Principles:**
  1. **Frictionless Input:** Photo-tracking or short voice/text descriptions instead of manual weighing and database search.
  2. **Data Ownership:** All data is stored in a private relational database (PostgreSQL / Supabase) in an open format.
  3. **Modularity:** Strict separation of layers (Ingestion, Storage, Processing/Math, AI Insights, Presentation).
  4. **High AI Precision:** Strict prompt engineering, structured JSON, cooked food weight calculation, correcting coefficients.

---

## 2. Domain Core & Physiological Math

The system is built not on naive "today's weight vs yesterday's weight" comparison, but on understanding human biological processes:

### 2.1. Daily Weight "Water Noise" vs Real Trend
Raw daily weight metrics don't reflect actual fat or muscle mass changes due to water balance fluctuations:
1. **Carbohydrate Swelling:** 1g of glycogen binds about **3–4g of water**. Increasing carbs causes an immediate weight spike the next day without fat gain.
2. **Muscle Micro-inflammation:** Intense training (running, cycling, lifting) causes micro-tears in fibers. The body accumulates fluid in muscles for recovery for 24–72 hours.
3. **Cortisol & Stress:** Extreme calorie deficit and sleep deprivation raise cortisol levels, which blocks water excretion by kidneys.
4. **Bioimpedance Scale Limitations:** Smart scales measure tissue resistance to electrical current. In reality, they measure lower body hydration and approximate the upper body algorithmically.

> **Mathematical Solution:** Use a **Rolling Average over 7–14 days** to filter out water noise and estimate the true long-term trend.

---

### 2.2. Macronutrient Quality & Absorption Kinetics
A calorie is not just a calorie, and the macronutrient source determines the metabolic response:
1. **Thermic Effect of Food (TEF):**
   - Protein: 20–30% of energy expended on digestion.
   - Carbs: 5–10%.
   - Fats: 0–3%.
   - Whole meat/fish have a higher TEF than ultra-processed nuggets or sausages.
2. **Absorption Kinetics:**
   - Liquid and ultra-processed foods (protein shakes, smoothies, white bread) cause a rapid glucose/amino acid spike and quick return of hunger.
   - Solid whole foods (steak, buckwheat, boiled eggs) absorb slowly, providing a prolonged satiety plateau.
3. **Food Matrix & Sodium:**
   - Ultra-processed food (shawarma, chips, snacks) contains hidden excess sodium and trans fats, guaranteeing water retention for 24–48 hours.

#### Mandatory Food Tagging Taxonomy
Every meal in the system must be tagged with categories:
* `whole_food` — whole unprocessed foods (potatoes, eggs, fillet, veggies).
* `solid` — solid food form.
* `liquid` — liquid or semi-liquid form (soup, smoothie, shake).
* `fast_absorbing` — fast carbs / isolates with high glycemic/insulin index.
* `ultra_processed` — heavily processed industrial food.
* `high_sodium` — high salt/sodium content (pickles, fast food, snacks).

---

### 2.3. Correlation Algorithms and Time Lags
Nutrition and exercise events affect body metrics with a delay:
* **Lag $T+1$ / $T+2$:** The impact of carb and sodium intake on day $T$ on morning weight on day $T+1$ and $T+2$.
* **Calculating Lags in the Analytics System:**
  - Data cleanup from outliers (Outlier Detection via IQR / Z-score).
  - Pearson / Spearman correlation calculation with lags $\Delta t \in \{1, 2, 3\}$.
  - Statistical significance estimation ($p$-value $< 0.05$).
* **Role of LLM (AI Insights):** The model **does not calculate raw numbers itself**. It receives ready statistical conclusions from the math engine and generates human-readable hypotheses, e.g.:
  > *"The correlation between a `high_sodium` dinner and a morning weight spike is $r = 0.74$ ($p < 0.01$). The 800g weight increase is temporary water retention, not fat."*

---

## 3. Current Implementation

The project is implemented as a Dual Architecture with full logic synchronization:

### 3.1. Variant 1: Node.js Process (Long Polling)
* **Entry Point:** [index.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/index.js)
* **Stack:** `node-telegram-bot-api` (polling: true), `@google/generative-ai`, `@supabase/supabase-js`, `dotenv`.
* **Handlers (`handlers/`):**
  - [handlers/photoHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/photoHandler.js): receives photo or uncompressed document (extracts EXIF date via `exifr` or falls back to message date, supports `/y` in caption), calls AI via `generateMealJSON`, saves result along with `tags`, `micronutrients`, and `amino_acids` to `meals` table (overriding `created_at` with exact meal time), returns macro card with fiber, sodium, BCAA, and quality tags.
  - [handlers/textHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/textHandler.js): routes commands `/stats`, `/w` (to `weightHandler`), `/y` (record for yesterday), or analyzes food description via `generateMealJSON`.
  - [handlers/weightHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/weightHandler.js): handles `/w <weight>` command, calculates delta from the last measurement, and saves to `body_measurements`.
  - [handlers/callbackHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/callbackHandler.js): handles inline pagination buttons for stats (`stats_YYYY-MM-DD`).
* **Utils (`utils/`):**
  - [utils/keyboard.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/keyboard.js): persistent bottom menu `MAIN_KEYBOARD` (`📊 Статистика`, `⚖️ Записати вагу`, `📅 Запис за вчора`).
  - [utils/gemini.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/gemini.js): `generateMealJSON(genAI, promptData)` — fault-tolerant call with cascade fallback (`gemini-2.5-flash` -> `gemini-3.6-flash`) to protect against 503 Overloaded errors.
  - [utils/dateUtils.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/dateUtils.js):
    - `getDietaryDate(date, offsetDays)`: calculates date with a **4-hour shift** (`shiftHours = 4`) and day offsets.
    - `getStatsMessage()`: aggregates macros, fiber, sodium, reads day weight from `body_measurements`, and forms a clinical nutritionist recommendation block.
  - [utils/prompt.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/prompt.js): system prompt for Gemini with tag taxonomy, micronutrient/amino acid estimation, and +12.5% Kcal deficit buffer (1.125 multiplier).

### 3.2. Variant 2: Serverless Deno Edge Function (Webhook)
* **Path:** [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts)
* **Stack:** Deno runtime, `std/http/server.ts`, `std/encoding/base64.ts`, `@supabase/supabase-js`, `@google/generative-ai`.
* **Features:**
  - Full parity with Node.js logic: photo/document recognition (with EXIF date extraction), commands `/w`, `/y`, `/stats`, `/start`.
  - Persistent keyboard `MAIN_KEYBOARD`.
  - Automatic weight recognizer on prompt reply or entering a number between 30 and 350.
  - "Record for yesterday" mode via `force_reply` button.
  - Built-in Gemini model fallback (`generateMealJSON`: `gemini-2.5-flash` -> `gemini-3.6-flash`).
  - Fault-tolerant `sendTg` with automatic fallback to plain text on Markdown parsing errors.
  - Reliable execution completion: `await handleUpdate(update)` before returning HTTP 200 OK (prevents premature Deno isolate freezing).
  - Fast image encoding via `base64Encode` from `std/encoding/base64.ts`.
  - Deployed via CLI with `--use-api` flag: `supabase functions deploy telegram-bot --no-verify-jwt --use-api`.

---

## 4. Database Layer

### 4.1. `meals` Table
```sql
CREATE TABLE IF NOT EXISTS public.meals (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    meal_name TEXT NOT NULL,
    kcal NUMERIC NOT NULL,
    protein NUMERIC NOT NULL,
    fat NUMERIC NOT NULL,
    carbs NUMERIC NOT NULL,
    weight_g NUMERIC NOT NULL,
    confidence NUMERIC,
    tags TEXT[] DEFAULT '{}'::TEXT[],
    micronutrients JSONB DEFAULT '{}'::JSONB,
    amino_acids JSONB DEFAULT '{}'::JSONB,
    dietary_date DATE NOT NULL,
    telegram_file_id TEXT,
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
```

### 4.2. `body_measurements` Table
```sql
CREATE TABLE IF NOT EXISTS public.body_measurements (
    id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    weight_kg NUMERIC NOT NULL,
    dietary_date DATE NOT NULL,
    measured_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL,
    impedance_ohms NUMERIC,
    impedance_frequency_khz NUMERIC DEFAULT 50,
    body_fat_pct NUMERIC,
    water_pct NUMERIC,
    muscle_mass_kg NUMERIC,
    bone_mass_kg NUMERIC,
    visceral_fat NUMERIC,
    source TEXT DEFAULT 'telegram_w',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()) NOT NULL
);
```

---

## 5. Ingestion Pipeline

1. **Telegram Bot:**
   - Fast photo/text input (MVP active).
   - Upgrades planned: auto-tagging (`whole_food`, `liquid`, `high_sodium`), manual adjustment, "delete/edit" button.
2. **Apple Shortcuts (Fast Ingestion):**
   - Daily iOS shortcut running on a schedule (e.g., at 09:00 after weighing in).
   - Reads from Apple HealthKit: morning weight, sleep duration, active calories yesterday, steps.
   - Sends a POST JSON request to Supabase Edge Function Webhook.
3. **Bluetooth Scale & iOS App (Future Phase):**
   - Native SwiftUI / CoreBluetooth app for seamless interception of scale measurements without opening the manufacturer's app.

---

## 6. Environment Variables

Required for local or Supabase execution:
```env
TELEGRAM_BOT_TOKEN="BotFather token"
ALLOWED_USER_ID="numeric Telegram ID of authorized user"
GEMINI_API_KEY="Google AI Studio key for Gemini API"
SUPABASE_URL="https://xxxxxxxxxxxx.supabase.co"
SUPABASE_KEY="anon or service_role Supabase key"
```

---

## 7. Operational Directives (AI Guidelines)

1. **Context and Token Economy:** All information is documented in this file and in the `docs/` directory. Do not read external files unnecessarily.
2. **Do Not Break the Working Pipeline:** Photo recognition and Supabase saving code works stably. Any prompt modifications must strictly maintain the JSON format.
3. **Logic Synchronization:** If functionality is updated in Node.js ([handlers/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/)), identical changes must be reflected in the Edge Function ([supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts)) or vice versa.
4. **Deficit Discipline:** Keep the 12.5% calorie buffer rule (`Deficit Buffer` x1.125) unless the user specifically asks to change the strategy.
5. **Product Tagging:** Whenever updating the AI prompt, you must always retrieve the `tags` array for each meal.
6. **Self-Updating Docs:** No code or architecture change is considered complete without synchronously updating [CHANGELOG.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/CHANGELOG.md), [docs/ROADMAP.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ROADMAP.md), and relevant documents (`PROJECT_KNOWLEDGE.md`, `DATABASE.md`, `ARCHITECTURE.md`, `README.md`).
