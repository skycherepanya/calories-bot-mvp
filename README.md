# Lifecore: AI Health Coach & Nutrition Data Warehouse

**Lifecore** is a personal, modular health tracking platform built on *Quantified Self* principles. The system gathers nutrition data (meal photos via Telegram), workouts, and recovery metrics (Apple Health / Strava) into a unified relational database, leveraging Gemini AI to uncover causal relationships between daily habits and physical performance.

---

## ⚡ Key Features (Current State)

### ✅ Implemented
* **📸 Food Photo Tracking:** Send a meal photo — Gemini estimates portion size, calculates Kcal/P/F/C + quality tags.
* **🛡️ Deficit Buffer (+12.5% Kcal):** Automatically multiplies calories by ×1.125 to guarantee a calorie deficit.
* **🌙 4-Hour Day Shift:** The dietary day resets at 04:00 AM; late-night meals count toward the previous day.
* **📅 Log for Yesterday (`/y`):** Retrospective meal logging for late entries.
* **⚖️ Weight Tracking (`/w <weight>`):** Morning weight logging with trend change deltas.
* **🌾 Micronutrients & Amino Acids:** Tracks fiber, sodium, potassium, BCAA, and leucine.
* **📊 Daily Analysis (`/stats`):** Whole vs. ultra-processed food ratio, sodium warnings, and actionable tips.
* **🏷️ Quality Taxonomy:** `whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`.
* **🔄 Inline Date Navigation:** ⬅️/➡️ buttons for browsing `/stats` history.
* **🏃 AI Coach Engine (`/coach` & `🏃 Аналіз тренування` button):** Contextual 3-day recovery analysis (workouts + sleep + nutrition + NEAT) via Gemini with strict causal reasoning and 🟢/🟡/🔴 state assessment.
* **🍏 Native iOS App & AppIntents (`ios/`):** Native SwiftUI app on iPhone 16 Pro + Apple Watch Ultra for <5ms HealthKit sync (steps, calories, sleep phases, HRV, RHR, workouts) via `LifecoreSyncIntent`.
* **⚡ Ingestion Webhook (`ingest-health`):** Supabase Edge Function ingesting telemetry from iOS with secret token authentication.
* **🧠 Double-Counting Prevention:** Mathematical isolation of pure NEAT (`daily_active_kcal - workout_kcal`) preventing duplicate calorie counting.

### 🔜 In Progress (Phase 3)
* **📈 Rolling Averages for Body Weight:** 7-day and 14-day trend lines filtering water weight noise.
* **⏱️ Time-Lagged Correlations:** Multi-day lag impact (T+1/T+2) of sodium, carb load, deficit, and running on HRV and weight.
* **🌅 Automated Morning Digest:** Daily 08:00 AM readiness briefing in Telegram.

---

## 🏗️ Architecture

The project maintains a **dual implementation**:

| | Node.js (Dev) | Supabase Edge (Prod) |
|---|---|---|
| Files | `index.js`, `handlers/`, `utils/` | `supabase/functions/telegram-bot/index.ts` |
| Mode | Long Polling | Webhook (Deno) |
| Purpose | Rapid local development & debugging | Production serverless deployment |

---

## 📁 Repository Structure

```
lifecore/
├── AGENTS.md              # AI agent guidelines & operational rules
├── PROJECT_KNOWLEDGE.md   # Single Source of Truth (master context)
├── CHANGELOG.md           # Project changelog & release history
│
├── ios/                   🍏 Native iOS App (SwiftUI & HealthKit)
│   ├── README.md          Setup instructions & capabilities guide
│   └── Lifecore/
│       ├── Lifecore.xcodeproj
│       └── Lifecore/
│           ├── LifecoreApp.swift         Main SwiftUI entry point
│           ├── ContentView.swift         Dark-mode Quantified Self dashboard
│           ├── HealthKitManager.swift    Async HealthKit queries (sleep, NEAT, HRV)
│           ├── HealthPayload.swift       Codable models matching Supabase schema
│           ├── LifecoreAPIService.swift  URLSession client for ingest-health
│           └── LifecoreSyncIntent.swift  AppIntent for Shortcuts, Action Button, Siri
│
├── handlers/              # Telegram handlers (Node.js)
│   ├── photoHandler.js    ✅ Food photo recognition via Gemini
│   ├── textHandler.js     ✅ Commands and text meal descriptions
│   ├── weightHandler.js   ✅ Weight tracking command (/w)
│   ├── callbackHandler.js ✅ Inline date pagination for /stats
│   └── coachHandler.js    ✅ /coach — AI recovery & workout analysis
│
├── utils/
│   ├── gemini.js          ✅ Cascade: 3.8-flash → 2.5-flash → 3.6-flash
│   ├── keyboard.js        ✅ MAIN_KEYBOARD (including 🏃 Coach button)
│   ├── dateUtils.js       ✅ 4-hour day shift, stats aggregation
│   ├── prompt.js          ✅ System prompt for food recognition
│   └── coachPrompt.js     ✅ Contextual prompt builder for /coach
│
├── supabase/
│   ├── functions/
│   │   ├── telegram-bot/  ✅ Production webhook (Deno)
│   │   └── ingest-health/ ✅ HealthKit telemetry ingestion webhook
│   └── migrations/
│       ├── 001_initial.sql                   ✅ meals + body_measurements
│       ├── 002_workouts.sql                  ✅ workouts table
│       ├── 003_sleep_logs.sql                ✅ sleep_logs table
│       ├── 004_fix_sleep_logs_nullable.sql   ✅ nullable metrics fix
│       └── 005_daily_metrics_enhancements.sql ✅ steps, active kcal, NEAT
│
├── shortcuts/             # iOS Shortcuts documentation & fallback
│   ├── README.md
│   └── ingest_health_shortcut.md
│
├── Lifecore/              📊 Offline analytics & data warehouse (Python)
│   ├── data/
│   │   ├── health/        Apple Health XML export (1.97 GB)
│   │   └── strava/        Strava activities.csv
│   ├── scripts/
│   │   ├── deep_health_analysis.py  ✅ XML → daily_health_summary.json
│   │   ├── analyze_health.py        ✅ HRV/RHR/Steps trends
│   │   ├── analyze_steps.py         ✅ Step double-counting check
│   │   ├── analyze_strava.py        ✅ Pace/distance/HR correlations
│   │   └── sync_to_supabase.py      ✅ Historical data sync to DB
│   └── reports/           Archival analytics reports
│
└── docs/
    ├── ARCHITECTURE.md    System architecture & 5-layer model
    ├── DATABASE.md        Database schema, ERD, and SQL DDL
    ├── IMPLEMENTATION_PLAN_PHASE2.md  Phase 2 step-by-step plan
    └── ROADMAP.md         Project development roadmap
```


---

## 📚 Project Documentation

| File | Description |
|---|---|
| [PROJECT_KNOWLEDGE.md](./PROJECT_KNOWLEDGE.md) | Master context: physiological formulas, prompts, architectural rules |
| [AGENTS.md](./AGENTS.md) | Operational guidelines and constraints for AI agents |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | 5-layer system architecture & data flows |
| [docs/DATABASE.md](./docs/DATABASE.md) | Database schema, ERD, and SQL DDL for all tables |
| [docs/ROADMAP.md](./docs/ROADMAP.md) | Milestone roadmap and task statuses |
| [docs/IMPLEMENTATION_PLAN_PHASE2.md](./docs/IMPLEMENTATION_PLAN_PHASE2.md) | Detailed Phase 2 implementation plan |
| [CHANGELOG.md](./CHANGELOG.md) | Chronological release and change log |
| [shortcuts/ingest_health_shortcut.md](./shortcuts/ingest_health_shortcut.md) | iOS Shortcut configuration guide |

---

## 🚀 Quick Start (Local Development)

### 1. Install Dependencies
```bash
npm install
```

### 2. Configure Environment Variables
Create a `.env` file in the project root:
```env
TELEGRAM_BOT_TOKEN="your_botfather_token"
ALLOWED_USER_ID="your_numeric_telegram_id"
GEMINI_API_KEY="your_google_ai_studio_api_key"
SUPABASE_URL="https://xxxxxxxxxxxx.supabase.co"
SUPABASE_KEY="your_supabase_anon_or_service_role_key"
```

### 3. Run Local Bot (Node.js)
```bash
node index.js
```

### 4. Deploy Edge Function (Supabase)
```bash
supabase functions deploy telegram-bot --no-verify-jwt --use-api
```

### 5. Set Webhook
```bash
curl -F "url=https://<PROJECT-REF>.supabase.co/functions/v1/telegram-bot" \
     https://api.telegram.org/bot<TOKEN>/setWebhook
```

---

## 🐍 Offline Analytics (Python)

```bash
cd Lifecore/
# 1. Parse Apple Health XML (requires export.xml in data/health/apple_health_export/)
python scripts/deep_health_analysis.py
# → Generates reports/daily_health_summary.json

# 2. Upload archive to Supabase (after applying migrations 002 and 003)
python scripts/sync_to_supabase.py

# 3. Analyze running performance from Strava
python scripts/analyze_strava.py
```

---

## 🌍 Key Constants

| Parameter | Value |
|---|---|
| Deficit Buffer | ×1.125 (+12.5% to Kcal) |
| Dietary Day Shift | 04:00 AM |
| Primary AI Model | `gemini-3.8-flash` |
| Fallback AI Models | `gemini-2.5-flash`, `gemini-3.6-flash` |
| Database | PostgreSQL via Supabase |
| Backend (Prod) | Deno Edge Functions |
| Backend (Dev) | Node.js Long Polling |

