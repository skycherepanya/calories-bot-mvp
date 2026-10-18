# Lifecore Project Changelog

All changes to the code, data structure, AI prompts, and documentation must be recorded in this log in reverse chronological order.

---

## [2026-10-18] - Phase 2 Complete: AI Coach Engine & Ingest-Health Webhook Deployed

### 🏃 AI Coach & Biometric Analysis:
- **Created `utils/coachPrompt.js`:** Implemented 4-part data aggregation (`buildCoachContext`) across last 3 days for meals, sleep logs, workouts, and daily NEAT activity. Designed strict clinical reasoning prompt (`buildCoachPrompt`) returning `СТАН СИСТЕМИ: 🟢/🟡/🔴` with exactly 4 causal insights citing exact metrics.
- **Created `handlers/coachHandler.js`:** Implemented Node.js handler featuring a 25-second timeout promise race across the Gemini cascade to ensure zero hanging or latency spikes.
- **Edge Function Webhook Synchronization (`telegram-bot`):** Mirrored `handleCoachAnalysis` and the updated `MAIN_KEYBOARD` directly into `supabase/functions/telegram-bot/index.ts` and deployed to Supabase production.
- **Added `🏃 Аналіз тренування` Button:** Integrated into `MAIN_KEYBOARD` across both Node.js (`utils/keyboard.js`) and Edge Function environments.
- **Verified Live Coach Generation:** Tested full pipeline against actual user biometric data with immediate, highly personalized recommendations based on HRV, RHR, running telemetry, and NEAT step counts.

### ⚡ Apple Health Ingestion Webhook:
- **Created `supabase/functions/ingest-health/index.ts`:** Implemented dedicated ingestion webhook accepting `daily_activity`, `sleep`, and `workout` payloads from iOS Shortcuts.
- **Secured with `INGEST_SECRET`:** Added secret token validation and user ID authorization.
- **Deployed to Supabase:** Deployed `ingest-health` to production and verified end-to-end with curl and Supabase PostgreSQL queries.

### Affected Files
`supabase/functions/ingest-health/index.ts`, `utils/coachPrompt.js`, `handlers/coachHandler.js`, `handlers/textHandler.js`, `utils/keyboard.js`, `supabase/functions/telegram-bot/index.ts`, `PROJECT_KNOWLEDGE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `CHANGELOG.md`

---

## [2026-10-18] - NEAT Activity Tracking, Apple Health Canonical Source & Gemini 3.8 Flash Upgrade

### 🏃 Lifestyle Activity & Ingestion Architecture:
- **Canonical Primary Source Established:** Declared Apple Health / Apple Fitness (Apple Watch) as the single primary source of truth for workouts, steps, sleep, and recovery metrics. Strava designated as secondary/export-only.
- **NEAT & Daily Activity Tracking:** Created and applied migration `005_daily_metrics_enhancements.sql` enhancing `daily_metrics` with `steps`, `active_kcal`, and device prioritization (`apple_watch` preferred over `iphone` to eliminate double counting).
- **Imported 1,279 Days of Daily Activity:** Extended `Lifecore/scripts/sync_to_supabase.py` with `sync_daily_metrics()` uploading 1,279 days of step counts and active energy expenditure to remote Supabase.
- **iOS Shortcut Spec Enhanced:** Updated `shortcuts/ingest_health_shortcut.md` and docs to include daily activity payload (`daily_activity: { date, steps, active_kcal, distance_km }`).

### 🤖 AI Models & Infrastructure:
- **AI Model Upgrade to Gemini 3.8 Flash:** Benchmarked models live against the Gemini API. Upgraded production AI cascade across Node.js (`utils/gemini.js`) and Edge Function (`supabase/functions/telegram-bot/index.ts`) to:
  1. `gemini-3.8-flash` (Primary — superior reasoning for Coach & fast multimodal vision)
  2. `gemini-2.5-flash` (First fallback — ultra-fast latency)
  3. `gemini-3.6-flash` (Secondary fallback)
- **Deployed Edge Function:** Redeployed `telegram-bot` Edge Function to Supabase production with new model cascade.

### Affected Files
`supabase/migrations/005_daily_metrics_enhancements.sql`, `Lifecore/scripts/sync_to_supabase.py`, `utils/gemini.js`, `supabase/functions/telegram-bot/index.ts`, `PROJECT_KNOWLEDGE.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `shortcuts/ingest_health_shortcut.md`, `README.md`, `CHANGELOG.md`

---

## [2026-10-18] - Database Migrations Applied & Historical Data Ingested

### 🗄 Database & Migrations:
- **Applied Database Migrations:** Successfully applied migrations to remote Supabase database:
  - `001_initial.sql` — base schema (`meals`, `body_measurements`).
  - `002_workouts.sql` — new `workouts` table with indexes.
  - `003_sleep_logs.sql` — new `sleep_logs` table with recovery biomarkers.
  - `004_fix_sleep_logs_nullable.sql` — relaxed `total_hours` constraint to allow importing HRV/RHR biomarkers when sleep stage duration is absent.

### 🐍 Scripts & Data Ingestion:
- **Fixed Strava Parsing Bug:** Resolved date parsing failures in `Lifecore/scripts/sync_to_supabase.py` caused by premature string slicing on AM/PM datetime formats.
- **Added Workout Deduplication:** Implemented cross-source deduplication in `sync_to_supabase.py` (filtered out 131 duplicate Apple Health activities already captured with rich telemetry by Strava).
- **Populated Data Warehouse:** Bulk-uploaded **1,044 sleep log records** and **410 unique workout records** into remote Supabase PostgreSQL.
- **Documentation Parity:** Updated `PROJECT_KNOWLEDGE.md`, `docs/DATABASE.md`, and `docs/ROADMAP.md` reflecting live database state.

### Affected Files
`supabase/migrations/003_sleep_logs.sql`, `supabase/migrations/004_fix_sleep_logs_nullable.sql`, `Lifecore/scripts/sync_to_supabase.py`, `PROJECT_KNOWLEDGE.md`, `docs/DATABASE.md`, `docs/ROADMAP.md`, `CHANGELOG.md`

---

## [2026-10-18] - Documentation Translation to English & Project Standardization

### 🌍 Changed:
- **Project Documentation Translation:** Fully translated all newly created and updated documents to English to comply with the project's language rule (`AGENTS.md`) and optimize LLM token usage:
  - `README.md` — full English rewrite with updated project structure and feature matrix.
  - `docs/ARCHITECTURE.md` — full English translation including 5-layer mermaid diagram.
  - `docs/ROADMAP.md` — translated all phases, tasks, and immediate priorities.
  - `docs/IMPLEMENTATION_PLAN_PHASE2.md` — translated plan steps, task descriptions, and DoD to English.
  - `shortcuts/README.md` & `shortcuts/ingest_health_shortcut.md` — translated iOS Shortcut specifications.
  - `Lifecore/README.md` — translated submodule overview and execution guide.
  - `docs/DATABASE.md` — cleaned up remaining non-English notes.
- **Code Consistency:** Removed unused imports in Phase 2 handler examples.

### Affected Files
`README.md`, `docs/ARCHITECTURE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `shortcuts/README.md`, `shortcuts/ingest_health_shortcut.md`, `Lifecore/README.md`, `docs/DATABASE.md`, `CHANGELOG.md`

---

## [2026-10-18] - Lifecore Analytics Module Merge & Repository Restructure

### 🏗 Structural Changes
- **Merged `Lifecore/` analytics module** into the main repository as a first-class submodule alongside the Telegram bot.
- **Removed duplicate files:**
  - `Lifecore/docs/quantified_self_concepts.md` → content consolidated into `PROJECT_KNOWLEDGE.md`
  - `Lifecore/docs/architecture_vision.md` → merged into `docs/ARCHITECTURE.md`
  - `Lifecore/docs/Персональний AI-тренер у Telegram.md` → merged into `docs/ARCHITECTURE.md`
- **Renamed** `Lifecore/scripts/analyze_strava_tmp.py` → `analyze_strava.py`

### 🗄 Database
- **Added DB migration files** (pending application in Supabase):
  - `supabase/migrations/001_initial.sql` — documents existing schema (meals, body_measurements)
  - `supabase/migrations/002_workouts.sql` — new `workouts` table (type, HR, pace, kcal, source)
  - `supabase/migrations/003_sleep_logs.sql` — new `sleep_logs` table (phases, HRV, RHR, VO2Max)
- **Coach Context SQL Query** documented in `docs/DATABASE.md`

### 🐍 New Scripts
- `Lifecore/scripts/sync_to_supabase.py` — bulk upload Apple Health JSON + Strava CSV to Supabase `workouts` and `sleep_logs` tables

### 📱 iOS Shortcuts
- `shortcuts/README.md` + `shortcuts/ingest_health_shortcut.md` — full specification for `Lifecore Morning Sync` iOS Shortcut (HealthKit → `ingest-health` Edge Function)

### 📚 Documentation Updated
- `README.md` — full rewrite: unified structure, new feature list, Python analytics quickstart
- `docs/ARCHITECTURE.md` — merged with Lifecore docs, added 5-layer diagram with workouts/sleep data flows
- `docs/DATABASE.md` — added `workouts`, `sleep_logs` table specs, ERD, Coach Context SQL query
- `docs/ROADMAP.md` — Phase 1 completed, detailed Phase 2 (Coach) tasks, Phases 3–5 outlined
- `docs/IMPLEMENTATION_PLAN_PHASE2.md` — detailed Phase 2 step-by-step plan
- `PROJECT_KNOWLEDGE.md` — expanded: recovery biomarkers (HRV/RHR/VO2Max), Sasha's baseline, Coach prompt rules, `ingest-health` Edge Function spec, new env variable `INGEST_SECRET`
- `Lifecore/README.md` — rewritten as module-level guide within the unified repo

### 🔜 Planned (Phase 2 — not yet implemented)
- `supabase/functions/ingest-health/index.ts`
- `handlers/coachHandler.js` + `utils/coachPrompt.js`
- New keyboard buttons: `🏃 Workout Analysis`, `📋 Weekly Report`

### Affected Files
`README.md`, `PROJECT_KNOWLEDGE.md`, `CHANGELOG.md`, `docs/ARCHITECTURE.md`, `docs/DATABASE.md`, `docs/ROADMAP.md`, `docs/IMPLEMENTATION_PLAN_PHASE2.md`, `Lifecore/README.md`, `supabase/migrations/001_initial.sql`, `supabase/migrations/002_workouts.sql`, `supabase/migrations/003_sleep_logs.sql`, `Lifecore/scripts/sync_to_supabase.py`, `shortcuts/README.md`, `shortcuts/ingest_health_shortcut.md`

---

## [2026-09-12] - Photo EXIF Metadata Date Extraction

### 🚀 Added:
- **Automatic EXIF Date Extraction:**
  - Added the ability to automatically extract the exact date and time a photo was taken directly from its EXIF metadata.
  - Implemented using the `exifr` library in both the Node.js implementation (`handlers/photoHandler.js`) and the Supabase Edge Function (`supabase/functions/telegram-bot/index.ts`).
  - Added support for processing uncompressed files (`bot.on('document')`) to preserve EXIF metadata (since Telegram strips EXIF from regular photos).
  - Automatically calculates the correct `dietary_date` and overrides `created_at` in the database to reflect the true time the meal was consumed.
  - As a fallback for photos without EXIF or sent as regular photos, uses the message sent time (`msg.date`) or original forwarded time (`msg.forward_date`).

---

## [2026-09-12] - Codebase Language Optimization (Translation to English)

### 🌍 Changed:
- **Project Documentation:** Translated `README.md`, `PROJECT_KNOWLEDGE.md`, `CHANGELOG.md`, `AGENTS.md`, and all files in `docs/` to English to optimize AI token consumption and context window efficiency.
- **Codebase Internal Strings:** Translated all internal code comments, logging messages (`console.log`, `console.error`), and internal LLM prompt prefixes in both the Node.js implementation (`index.js`, `handlers/`, `utils/`) and the Supabase Edge Function (`supabase/functions/telegram-bot/index.ts`) to English.
- **UI Language Preservation:** Kept all Telegram Bot user-facing messages, responses, and interactive keyboard buttons strictly in Ukrainian.
- **Added Deployment Rule:** Updated `AGENTS.md` to strictly require testing, git committing/pushing, and deploying changes immediately after modifications.

---

## [2026-09-04] - Persistent Reply Keyboard and Removal of Redundant Buttons

### 🚀 Added:
- **Persistent Reply Keyboard in Telegram:**
  - Created a pinned keyboard with three buttons: `📊 Статистика` (Statistics), `⚖️ Записати вагу` (Record weight), `📅 Запис за вчора` (Record for yesterday).
  - Keyboard module [utils/keyboard.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/keyboard.js) for Node.js and `MAIN_KEYBOARD` constant in Supabase Edge Function.
  - Menu is automatically attached on `/start` and in all bot replies.
- **Interactive Scenarios Without Typing Commands:**
  - `📊 Статистика`: instantly returns daily analytics with date scrolling buttons.
  - `⚖️ Записати вагу`: sends a focused `force_reply` message with placeholder `76.2`. User can enter a number in reply, or just type a number (from 30 to 350) in chat.
  - `📅 Запис за вчора`: sends `force_reply` waiting mode. Next text or photo message is automatically logged for yesterday without needing the `/y` command.

### 🧹 UI Cleanup:
- **Removed Non-Functional Inline Buttons:**
  - Completely removed inline buttons `[✅ Записано]` (meal is saved automatically) and `[✏️ Редагувати]` from meal cards.
  - The meal card is now completely clean, and bot controls are moved to the bottom system menu in Telegram.

---

## [2026-09-04] - Adjusted Deficit Buffer (12.5%) and Optimized Status Texts

### ⚙️ Changed:
- **Lowered Calorie Deficit Buffer:**
  - Adjusted buffer from 15% to a moderate **12.5%** (`kcal * 1.125`).
  - Updated prompts in [utils/prompt.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/prompt.js) and [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts). Protein, fats, and carbs remain exact.
- **Hidden Technical Buffer Text:**
  - Completely removed the `*(+15% buffer)*` string from the meal card — it now shows clean calories: `🔥 Calories: **XX kcal**`.
- **Updated Processing Status Text:**
  - Replaced calculation text with specifics: `⏳ Рахую калорії за прийом...` and `⏳ Рахую калорії за прийом (за вчора)...`.
  - Synced changes in [handlers/photoHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/photoHandler.js), [handlers/textHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/textHandler.js), and Edge Function.

---

## [2026-09-04] - Simplified Message UI and Historical Weight Generation

### 🎨 UI/UX Improvements for Messages:
- **Minimalist Meal Card:**
  - Removed display of raw fiber, sodium, BCAA numbers, and quality tags from the Telegram message (both Node.js and Supabase).
  - Micronutrient and quality data continues to be saved in DB for daily analysis and advice.
  - Card contains only key macros: calories (buffered), proteins, fats, carbs, meal weight, and AI confidence percentage.
- **Cleaned Up `/stats` Report:**
  - Removed technical rows with grams of fiber and milligrams of sodium.
  - Nutritionist recommendations converted into a natural, human-centric format: concise tips on protein, fiber, hydration, and quality without overwhelming with numbers.

### 📊 Data and History:
- **Historical Weight Generation (2026-08-20 — 2026-09-04):**
  - Added 16 daily weight logs to `body_measurements` covering the entire bot usage period, simulating natural fluctuations between 76.2 – 76.6 kg.
  - As of today (2026-09-04), accurate weight logged at **76.0 kg**.
- **Cleaned DB from Test Entries:**
  - Removed all test entries from `meals` and `body_measurements`; no real user meals (87 records) were touched.

---

## [2026-09-04] - Fixed Edge Function Freezing & Fault-Tolerant Gemini Fallback

### 🐛 Fixed (Root Cause Analysis):
- **Deno Isolate Freezing in Supabase Edge Function:**
  - In [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts), `handleUpdate(update)` wasn't awaited. Returning `Response("OK")` caused immediate suspension/termination of the Deno worker isolate, cutting off async requests to Gemini, DB, and Telegram halfway. Added `await handleUpdate(update)`.
- **Gemini 503 Service Unavailable ("High Demand") Failures:**
  - Model `gemini-3.6-flash` occasionally returns HTTP 503 due to Google server overload.
  - Implemented a single fault-tolerant helper with fallback queue (`gemini-2.5-flash` -> `gemini-3.6-flash`):
    - Node.js: module [utils/gemini.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/gemini.js).
    - Supabase: function `generateMealJSON` in [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts).
- **Telegram API Resilience (`sendTg`):**
  - Added response status check `res.ok`. If Telegram fails to parse Markdown entities (HTTP 400 Bad Request), it automatically retries as `plain text`, preventing silent failures.
- **Optimized Base64 Photo Processing in Deno:**
  - Replaced slow byte concatenation loop with native `base64Encode(new Uint8Array(imageBuffer))` from `std/encoding/base64.ts`.
- **Edge Function Deployment Without Local Docker:**
  - Found reason for CLI freezing during `supabase functions deploy`: local CLI was trying to connect to Docker daemon. Fixed by adding `--use-api` flag (`supabase functions deploy telegram-bot --no-verify-jwt --use-api`), ensuring build and deploy happens server-side in 1-2 seconds.

---

## [2026-09-04] - Micronutrients, Amino Acids, Weight Tracking (/w) and Diet Analysis

### 🚀 Added:
- **Weight Tracking via Telegram (`/w`):**
  - Created handler [handlers/weightHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/weightHandler.js) for `/w <weight>` command (supports comma and dot: `/w 78.5`, `/w 78,5`).
  - Calculates delta compared to previous measurement (`+0.4 kg`, `-0.2 kg`).
  - Reminds user about water fluctuations (1g glycogen : 3-4g water).
  - Synced `/w` command in Supabase Edge Function.
- **Body Measurements & Bioimpedance Table:**
  - Created migration [supabase/migrations/20260904160000_lifecore_schema.sql](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/migrations/20260904160000_lifecore_schema.sql) with `body_measurements` table.
  - Added placeholders for future smart scales: `impedance_ohms`, `impedance_frequency_khz`, `body_fat_pct`, `water_pct`, `muscle_mass_kg`, `bone_mass_kg`, `visceral_fat`.
- **Diet Analysis & Recommendations in `/stats`:**
  - Updated [utils/dateUtils.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/dateUtils.js) and `getStatsPayload` in Edge Function.
  - Displays logged day's weight in stats header.
  - Aggregates fiber (`fiber_g`) and sodium (`sodium_mg`).
  - Calculates ratio of whole foods (`whole_food`) to ultra-processed (`ultra_processed`).
  - Nutritionist recommendation block: protein deficit (<100g), fiber deficit (<20g), sodium edema warnings (>2300mg), and calorie saving tips (>2200 kcal).
- **Support for `/y` (Yesterday) Command in Node.js:**
  - Added support for `/y` in text and photo handlers.
- **Deploy to Supabase (Production):**
  - Successfully applied migration `20260904160000_lifecore_schema.sql` via `supabase db push`.
  - Deployed updated Edge Function `telegram-bot` via `supabase functions deploy`.

### ⚙️ Changed:
- **AI Prompt [utils/prompt.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/prompt.js):**
  - Added quality taxonomy (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
  - Added micronutrient calculations (`fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`).
  - Added amino acid profile (`bcaa_g`, `leucine_g`) for protein meals.
  - Preserved `Deficit Buffer` (+15% Kcal) rule.
- **Meal Saving:** in [handlers/textHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/textHandler.js) and [handlers/photoHandler.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/photoHandler.js), added writing `tags`, `micronutrients`, `amino_acids` fields to Supabase.

---

## [2026-09-04] - Documentation Initialization, Superpowers Integration, and Project Start

### 🚀 Added:
- **Integrated Engineering Skills Library (*Superpowers*):**
  - Copied 14 skills from `hotel-amenities-2` project into [.agents/skills/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/.agents/skills).
  - Added version manifest [skills-lock.json](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/skills-lock.json) and compatibility symlinks [.claude/skills/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/.claude/skills).
- **Created Single Knowledge Base and Operational Rules:**
  - [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md) — consolidated domain knowledge base.
  - [AGENTS.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/AGENTS.md) — system instructions for agents with mandatory documentation rule.
  - [README.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/README.md) — updated project description and deploy instructions.
- **Architectural Spec and DB Design:**
  - [docs/ARCHITECTURE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ARCHITECTURE.md) — 5 architecture layers.
  - [docs/DATABASE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/DATABASE.md) — ER diagram, specs for tables.
  - [docs/ROADMAP.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ROADMAP.md) — step-by-step roadmap (Phases 1–5).
  - [supabase/migrations/20260904160000_lifecore_schema.sql](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/migrations/20260904160000_lifecore_schema.sql) — base SQL script for creating tables.

### ⚙️ Changed:
- [package.json](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/package.json): filled `description` field.
