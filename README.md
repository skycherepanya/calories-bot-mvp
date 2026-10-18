# Lifecore: AI Health Coach & Nutrition Data Warehouse

**Lifecore** — особистий модульний трекер здоров'я, побудований на принципі *Quantified Self*. Система збирає дані про харчування (фото через Telegram), тренування та відновлення (Apple Health / Strava) в єдину реляційну базу даних і використовує Gemini AI для пошуку причинно-наслідкових зв'язків між твоїми звичками та фізичним станом.

---

## ⚡ Ключові функції (поточний стан)

### ✅ Реалізовано
* **📸 Фото-трекінг їжі:** Надіслав фото — Gemini розпізнає порцію, розраховує Ккал/Б/Ж/В + якісні теги
* **🛡️ Deficit Buffer (+12.5% Ккал):** Автоматично множить калорії ×1.125 для гарантованого дефіциту
* **🌙 4-годинний зсув:** День змінюється о 04:00, нічна їжа зараховується до попереднього дня
* **📅 Запис за вчора (`/y`):** Ретроспективне логування прийому їжі
* **⚖️ Вага (`/w <вага>`):** Запис ранкової ваги з динамікою змін
* **🌾 Мікронутрієнти & амінокислоти:** Клітковина, натрій, калій, BCAA, лейцин
* **📊 Аналіз дня (`/stats`):** Співвідношення цільних/ультраоброблених продуктів, натрій, рекомендації
* **🏷️ Таксономія якості:** `whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`
* **🔄 Inline-навігація по датах:** Кнопки ⬅️/➡️ у `/stats`

### 🔜 В розробці (Фаза 2)
* **🏃 AI-тренер (`/coach`):** Аналіз тренування + сну + харчування за 3 дні через Gemini
* **💤 Трекінг сну:** Автоматична синхронізація з Apple Health (фази сну, HRV, ЧСС)
* **🏃 Трекінг тренувань:** Синхронізація Strava + Apple Health + ручне логування

---

## 🏗️ Архітектура

Проект використовує **дуальну реалізацію**:

| | Node.js (Dev) | Supabase Edge (Prod) |
|---|---|---|
| Файли | `index.js`, `handlers/`, `utils/` | `supabase/functions/telegram-bot/index.ts` |
| Режим | Long Polling | Webhook (Deno) |
| Призначення | Локальна розробка | Production |

---

## 📁 Структура проєкту

```
lifecore/
├── AGENTS.md              # Правила для AI-агентів
├── PROJECT_KNOWLEDGE.md   # Єдине джерело правди (master context)
├── CHANGELOG.md           # Лог змін
│
├── handlers/              # Telegram handlers (Node.js)
│   ├── photoHandler.js    ✅ Розпізнавання фото через Gemini
│   ├── textHandler.js     ✅ Команди та текстові описи їжі
│   ├── weightHandler.js   ✅ Команда /w
│   ├── callbackHandler.js ✅ Inline-кнопки пагінації stats
│   └── coachHandler.js    🔜 /coach — AI-аналіз відновлення
│
├── utils/
│   ├── gemini.js          ✅ Fallback chain: 2.5-flash → 3.6-flash
│   ├── keyboard.js        ✅ MAIN_KEYBOARD (постійне меню)
│   ├── dateUtils.js       ✅ 4-годинний зсув, агрегація stats
│   ├── prompt.js          ✅ Системний промпт розпізнавання їжі
│   └── coachPrompt.js     🔜 Контекстний промпт для /coach
│
├── supabase/
│   ├── functions/
│   │   ├── telegram-bot/  ✅ Production webhook (Deno)
│   │   └── ingest-health/ 🔜 iOS Shortcut endpoint
│   └── migrations/
│       ├── 001_initial.sql    ✅ meals + body_measurements (є в БД)
│       ├── 002_workouts.sql   🔜 PENDING — застосувати
│       └── 003_sleep_logs.sql 🔜 PENDING — застосувати
│
├── shortcuts/             🔜 iOS Shortcuts документація
│   ├── README.md
│   └── ingest_health_shortcut.md
│
├── Lifecore/              📊 Офлайн-аналітика (Python)
│   ├── data/
│   │   ├── health/        Apple Health XML export (1.97 GB)
│   │   └── strava/        Strava activities.csv
│   ├── scripts/
│   │   ├── deep_health_analysis.py  ✅ XML → daily_health_summary.json
│   │   ├── analyze_health.py        ✅ HRV/RHR/Steps trends
│   │   ├── analyze_steps.py         ✅ Steps double-counting check
│   │   ├── analyze_strava.py        ✅ Pace/distance/HR correlations
│   │   └── sync_to_supabase.py      🔜 Завантаження архіву в БД
│   ├── prompts/           Системні промпти (reference)
│   │   ├── antigravity_health_assistant_prompt_sasha.md
│   │   └── antigravity_health_assistant_prompt_vika.md
│   └── reports/           Архівні аналітичні звіти
│
└── docs/
    ├── ARCHITECTURE.md    Системна архітектура
    ├── DATABASE.md        Схема БД + ERD + SQL DDL
    └── ROADMAP.md         Дорожня карта розробки
```

---

## 📚 Документація

| Файл | Зміст |
|---|---|
| [PROJECT_KNOWLEDGE.md](./PROJECT_KNOWLEDGE.md) | Master context: фізіологічна математика, промпти, правила |
| [AGENTS.md](./AGENTS.md) | Правила для AI-агентів |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | 5-рівнева архітектура системи |
| [docs/DATABASE.md](./docs/DATABASE.md) | Схема БД, ERD, SQL DDL для всіх таблиць |
| [docs/ROADMAP.md](./docs/ROADMAP.md) | Дорожня карта та статус завдань |
| [CHANGELOG.md](./CHANGELOG.md) | Хронологія всіх змін |
| [shortcuts/ingest_health_shortcut.md](./shortcuts/ingest_health_shortcut.md) | Специфікація iOS Shortcut |

---

## 🚀 Швидкий старт (локальна розробка)

### 1. Встановити залежності
```bash
npm install
```

### 2. Налаштувати `.env`
```env
TELEGRAM_BOT_TOKEN="токен від BotFather"
ALLOWED_USER_ID="числовий Telegram ID"
GEMINI_API_KEY="ключ Google AI Studio"
SUPABASE_URL="https://xxxxxxxxxxxx.supabase.co"
SUPABASE_KEY="anon або service_role ключ Supabase"
```

### 3. Запустити бота локально
```bash
node index.js
```

### 4. Deploy Edge Function (Supabase)
```bash
supabase functions deploy telegram-bot --no-verify-jwt --use-api
```

### 5. Встановити Webhook
```bash
curl -F "url=https://<PROJECT-REF>.supabase.co/functions/v1/telegram-bot" \
     https://api.telegram.org/bot<TOKEN>/setWebhook
```

---

## 🐍 Офлайн-аналітика (Python)

```bash
cd Lifecore/
# 1. Спершу запарси Apple Health XML (потрібен export.xml в data/health/)
python scripts/deep_health_analysis.py
# → генерує reports/daily_health_summary.json

# 2. Завантаж архів у Supabase (після застосування міграцій 002 та 003)
python scripts/sync_to_supabase.py

# 3. Аналіз бігових показників Strava
python scripts/analyze_strava.py
```

---

## 🌍 Ключові константи

| Параметр | Значення |
|---|---|
| Deficit Buffer | ×1.125 (+12.5% до Ккал) |
| Dietary day shift | 04:00 AM |
| Primary AI model | `gemini-2.5-flash` |
| Fallback AI model | `gemini-3.6-flash` |
| DB | PostgreSQL via Supabase |
| Backend (prod) | Deno Edge Functions |
| Backend (dev) | Node.js Long Polling |
