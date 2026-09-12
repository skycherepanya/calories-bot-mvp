# Lifecore Development Plan and Roadmap

This document outlines the practical steps for transitioning from the current prototype (`calories-bot-mvp`) to the fully functional **Lifecore (Quantified Self Health Data Warehouse)** system.

---

## Phase 1: Telegram Bot Modernization, Food Quality, and Weight Tracking

- [x] **1.1. Adding quality tags, micronutrients, and amino acids to the AI prompt:**
  - Updated the system prompt in [utils/prompt.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/prompt.js) and Edge Function [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts).
  - Returns tags (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`), micronutrients (`fiber_g`, `sodium_mg`, etc.), and amino acids (`bcaa_g`, `leucine_g`).
- [x] **1.2. Database Model Update:**
  - Added `tags TEXT[]`, `micronutrients JSONB`, `amino_acids JSONB` columns to the `meals` table.
  - Created `body_measurements` table with placeholders for smart scales (impedance, fat, water, muscle).
- [x] **1.3. Weight logging functionality via `/w` command:**
  - Implemented in [handlers/weightHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/weightHandler.js) and Edge Function: weight logging, delta calculation, and output in `/stats`.
- [x] **1.4. Diet Analysis and Recommendations in `/stats`:**
  - Implemented calculation of whole/processed food ratio, fiber, sodium, edema warnings, and calorie saving tips.
- [x] **1.5. Functionality Synchronization:**
  - Support for the `/y` command (yesterday) now works in both Node.js and Supabase Edge Function.
- [x] **1.6. Persistent Reply Keyboard and Quick Scenarios:**
  - Implemented persistent buttons `📊 Статистика`, `⚖️ Записати вагу`, `📅 Запис за вчора`.
  - Cleaned up the message interface: removed non-functional inline buttons from meal cards.
  - Added automatic recognition of numbers as weight and yesterday input mode via Reply.
- [ ] **1.7. Edit and Delete Function:**
  - Ability to delete the last entry or adjust the portion (+/- 20%).

---

## Phase 2: Relational Structure and Supabase Migration

- [ ] **2.1. Creation of `daily_metrics` Table:**
  - Apply SQL migration for the daily biometric metrics table (weight, sleep, activity, steps).
- [ ] **2.2. Setup Rolling Averages Calculation:**
  - Create a trigger or function in PostgreSQL (or Edge Function) to automatically update `rolling_avg_weight_7d` and `rolling_avg_weight_14d` when a new weight measurement is added.
- [ ] **2.3. `meal_ingredients` Table (Optional):**
  - Detail complex meals into individual components.

---

## Phase 3: Biometric Data Collection Automation (Apple Shortcuts & HealthKit)

- [ ] **3.1. Webhook Ingestion Endpoint Creation:**
  - Create a new Supabase Edge Function `ingest-health-metrics` to receive JSON payloads from Apple Health.
- [ ] **3.2. Apple Shortcut Setup:**
  - Create an iOS Shortcuts script that:
    1. Reads from Apple Health: morning weight, sleep (duration, deep, REM), steps, and active energy for the previous day.
    2. Constructs a JSON payload.
    3. Sends a POST request to the Supabase webhook with a secret authorization token.
- [ ] **3.3. Daily Automatic Update Testing:**
  - Auto-run the shortcut every morning at 09:00.

---

## Phase 4: Analytics Engine and Correlation Analysis

- [ ] **4.1. Data Cleanup and Outlier Filtering Script:**
  - Algorithmic removal of "water noise" and weight trend smoothing.
- [ ] **4.2. Time-Lagged Correlation Calculation:**
  - Python / TypeScript service for testing hypotheses:
    - *Impact of sodium and ultra-processed food on water retention at day T+1.*
    - *Impact of carbohydrate amount on deep sleep quality.*
    - *Impact of calorie deficit on HRV metrics and recovery.*
- [ ] **4.3. Statistical Significance Calculation ($p$-value):**
  - Filtering out random coincidences.

---

## Phase 5: AI Interpretation and Daily Reports (AI Insights)

- [ ] **5.1. Morning Digest in Telegram:**
  - Every morning, the bot sends a summary:
    - Current weight vs 7-day trend (no panic over water).
    - Yesterday's calorie summary and `whole_food` vs `ultra_processed` ratio.
    - Sleep quality and recommendations for today's activity.
- [ ] **5.2. Smart Assistant (Gemini Insights):**
  - The user can ask the bot: *"Why did I gain 1 kg today?"* or *"How did my diet affect my recovery this week?"*.
  - The model answers based exclusively on statistical facts from the database.
