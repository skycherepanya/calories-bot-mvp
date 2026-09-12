# 🍏 Lifecore: Calories Bot & Health Data Warehouse

**Lifecore** is a personal, modular ecosystem for collecting, aggregating, and analyzing health metrics (Quantified Self). The project combines fast food input via a Telegram bot with AI vision support (Google Gemini), data storage in a relational Supabase (PostgreSQL) database, and future correlation analysis between nutrition, sleep, and body composition.

---

## ⚡ Key Features

* **📸 Frictionless Photo Tracking:** Send a photo of your meal — the `gemini-3.6-flash` model recognizes the portion, calculates the ready-to-eat macros (Kcal, Protein, Fats, Carbs), and extracts quality tags.
* **✍️ Text or Voice Input:** Ability to send a text description of the food or add a text caption to a photo.
* **🛡️ Deficit Buffer (+15% Kcal):** The calculated calories are automatically multiplied by 1.15 as a safety margin against underestimating restaurant portions and to guarantee a caloric deficit.
* **🌙 Dietary Day (4-Hour Shift):** A new day starts at 04:00 AM. Nighttime meals eaten before 04:00 AM are credited to the previous day.
* **📅 Record for Yesterday (`/y`):** Ability to retroactively log a meal for the previous day.
* **⚖️ Weight Logging (`/w <weight>`):** Record your morning weight (e.g., `/w 78.5` or `/w 78,5`) with automatic calculation of dynamics (+/- kg since the last weigh-in).
* **🌾 Micronutrients & Amino Acids:** Estimation of fiber, sodium, potassium, and BCAA/leucine for protein-rich meals.
* **🧠 Diet Analysis & Recommendations:** With the `/stats` command, the bot analyzes the ratio of whole foods, sodium, and fiber, providing tips on saving calories or addressing protein deficiency.
* **📊 Interactive Statistics:** The `/stats` command displays the day's weight and provides inline buttons (⬅️ / ➡️) to quickly navigate between dates.
* **🏷️ Food Quality Taxonomy:** Automatic tagging of meals (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).

---

## 🏗️ Architecture (Dual Implementation)

The project has two parallel backend implementations:

1. **Node.js Process (Long Polling):**
   - Files: [index.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/index.js), [handlers/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/), [utils/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/)
   - Ideal for rapid local development and debugging.
2. **Supabase Edge Function (Webhook):**
   - File: [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts)
   - Serverless architecture on Deno for production deployment with Telegram webhooks.

---

## 📚 Project Documentation

* **[PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md)** — Single source of project knowledge, physiological formulas (glycogen, water noise, TEF), and prompt rules.
* **[AGENTS.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/AGENTS.md)** — Operational instructions for AI agents.
* **[docs/ARCHITECTURE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ARCHITECTURE.md)** — Detailed description of system layers (Ingestion, Storage, Processing, Analytics).
* **[docs/DATABASE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/DATABASE.md)** — PostgreSQL table specifications and ER diagram.
* **[docs/ROADMAP.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ROADMAP.md)** — Action plan and development stages.
* **[CHANGELOG.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/CHANGELOG.md)** — Change log and release history.

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
supabase functions deploy telegram-bot --no-verify-jwt
```
Set webhook in Telegram:
```bash
curl -F "url=https://<PROJECT-REF>.supabase.co/functions/v1/telegram-bot" https://api.telegram.org/bot<TELEGRAM_BOT_TOKEN>/setWebhook
```
