# Lifecore Development Roadmap

Дорожня карта переходу від MVP (`calories-bot-mvp`) до повноцінної платформи **Lifecore (Quantified Self Health & Nutrition Data Warehouse)**.

---

## ✅ Фаза 1 — Telegram Bot: Харчування та Вага (Завершена)

- [x] **1.1.** AI-розпізнавання їжі за фото через Gemini (`gemini-2.5-flash` → `gemini-3.6-flash` fallback)
- [x] **1.2.** Система якісних тегів (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`)
- [x] **1.3.** Мікронутрієнти (`fiber_g`, `sodium_mg`, `potassium_mg`, `vitamin_c_mg`, `iron_mg`, `calcium_mg`)
- [x] **1.4.** Амінокислоти (`bcaa_g`, `leucine_g`) для білкових страв
- [x] **1.5.** Deficit Buffer ×1.125 (+12.5% до Ккал, макроси — точні)
- [x] **1.6.** 4-годинний зсув дня (день змінюється о 04:00, не опівночі)
- [x] **1.7.** Команда `/y` — запис за вчора (обидві реалізації: Node.js + Edge)
- [x] **1.8.** Команда `/w <вага>` — логування ваги з динамікою
- [x] **1.9.** Команда `/stats` — щоденна статистика з аналізом якості раціону + inline-навігація по датах
- [x] **1.10.** Persistent keyboard (`📊 Статистика`, `⚖️ Записати вагу`, `📅 Запис за вчора`)
- [x] **1.11.** EXIF-екстракція дати з фото (справжній час їжі, не час відправки)
- [x] **1.12.** Таблиці БД: `meals`, `body_measurements`
- [x] **1.13.** Supabase Edge Function (Deno) — Production webhook з повним паритетом
- [x] **1.14.** Злиття аналітичного модуля `Lifecore/` в єдиний репозиторій

---

## 🔜 Фаза 2 — AI-тренер: Тренування, Сон та Coach-аналіз (Наступна)

### 2.1. База даних
- [ ] Застосувати міграцію `002_workouts.sql` у Supabase
- [ ] Застосувати міграцію `003_sleep_logs.sql` у Supabase

### 2.2. Завантаження архівних даних
- [ ] Запустити `Lifecore/scripts/deep_health_analysis.py` → згенерувати `daily_health_summary.json`
- [ ] Запустити `Lifecore/scripts/sync_to_supabase.py` → завантажити Apple Health + Strava в БД

### 2.3. Edge Function `ingest-health`
- [ ] Створити `supabase/functions/ingest-health/index.ts`
- [ ] Прийом JSON: `{ secret, user_id, sleep, workout }`
- [ ] Перевірка `INGEST_SECRET` з Supabase Secrets
- [ ] Запис у `sleep_logs` та/або `workouts`
- [ ] Деплой: `supabase functions deploy ingest-health --no-verify-jwt --use-api`
- [ ] Встановити секрет: `supabase secrets set INGEST_SECRET=...`

### 2.4. iOS Shortcut `Lifecore Morning Sync`
- [ ] Зчитування з HealthKit: HRV (SDNN), RHR, фази сну
- [ ] Зчитування останнього тренування: тип, тривалість, avg HR, kcal, дистанція
- [ ] POST-запит на `ingest-health` Edge Function
- [ ] Push-повідомлення з підтвердженням синку
- [ ] Automation: запуск о 09:00 або після завершення тренування
- [ ] Специфікація: [`shortcuts/ingest_health_shortcut.md`](../shortcuts/ingest_health_shortcut.md)

### 2.5. Coach Prompt (`utils/coachPrompt.js`)
- [ ] Функція `buildCoachContext(userId)` — SQL-запит: 3 дні тренувань + сон + харчування
- [ ] Функція `buildCoachPrompt(context)` — формування системного промпту для Gemini
- [ ] Формат відповіді: `СТАН СИСТЕМИ: 🟢/🟡/🔴` + 4 причинно-наслідкові інсайти
- [ ] Правила: якщо HRV < базовий або RHR > базовий → обов'язково `СТОП / ВІДНОВЛЕННЯ`

### 2.6. Coach Handler (`handlers/coachHandler.js`)
- [ ] Команда `/coach` → виклик `buildCoachContext` + Gemini + відповідь у Telegram
- [ ] Команда `/workout <тип> <хвилини> [опціонально: km, avg_hr]` — ручне логування
- [ ] Команда `/sleep <годин>` — ручне логування сну (якщо без Apple Watch)
- [ ] Паралельна реалізація в Edge Function `telegram-bot/index.ts`

### 2.7. Оновлення MAIN_KEYBOARD
- [ ] Додати кнопку `🏃 Аналіз тренування` → `/coach`
- [ ] Додати кнопку `📋 Звіт за тиждень` → weekly digest
- [ ] Оновити в обох реалізаціях: `utils/keyboard.js` + Edge Function

---

## 📅 Фаза 3 — Analytics Engine (Після Фази 2)

### 3.1. Rolling Averages для ваги
- [ ] PostgreSQL функція або Edge Function: обчислення `rolling_avg_weight_7d` та `rolling_avg_weight_14d`
- [ ] Заповнення таблиці `daily_metrics` при кожному новому записі ваги
- [ ] Відображення тренду в `/stats` (реальна тенденція замість щоденного "шуму")

### 3.2. Time-Lagged Correlation (Python)
- [ ] Скрипт для аналізу впливу натрію (день T) на вагу (день T+1, T+2)
- [ ] Вплив вуглеводів на якість глибокого сну
- [ ] Вплив дефіциту калорій на HRV наступного ранку
- [ ] Вплив бігового об'єму на RHR (тижневий тренд)
- [ ] Pearson/Spearman кореляція + p-value ($p < 0.05$)

### 3.3. Автоматичний ранковий дайджест
- [ ] Supabase cron (Edge Function Scheduler) о 08:00 щодня
- [ ] Вміст: вага vs 7-денний тренд + причина відхилення (натрій? глікоген?); вчорашній раціон; рекомендація на сьогодні (тренувати чи відновлюватись — на базі HRV)

---

## 📅 Фаза 4 — Multi-user та Профілі (Після Фази 3)

### 4.1. Таблиця `users`
- [ ] Базовий профіль: вік, зріст, поточна вага, цілі (дефіцит/профіцит/рекомпозиція)
- [ ] Цільові макроси: `target_kcal`, `target_protein`, `target_carbs`, `target_fat`
- [ ] Базовий HRV та RHR (для порівняння у Coach)

### 4.2. Профіль Віка
- [ ] Промпт готовий: `Lifecore/prompts/antigravity_health_assistant_prompt_vika.md`
- [ ] Додати другий `ALLOWED_USER_ID` або перейти на систему `users` table

### 4.3. Персоналізований Coach Prompt
- [ ] Читати цільові макроси та базові біомаркери з `users` таблиці
- [ ] Адаптувати поради під індивідуальні цілі (схуднення vs рекомпозиція vs витривалість)

---

## 📅 Фаза 5 — AI Insights та Візуалізація (Довгострокова)

### 5.1. Smart Assistant (запити вільною мовою)
- [ ] "Чому я набрав 1 кг сьогодні?" → AI знаходить відповідь у даних (натрій, глікоген, сон)
- [ ] "Як мій раціон впливає на темп бігу?" → time-lag correlation з поясненням
- [ ] "Порівняй цей тиждень з минулим" → структурований порівняльний звіт

### 5.2. BI Dashboard
- [ ] Підключення Metabase або Superset до Supabase PostgreSQL
- [ ] Дашборд: вага (rolling avg) + тренування + HRV + калорії на одному графіку

### 5.3. Native iOS App (Дуже довгостроково)
- [ ] SwiftUI + CoreBluetooth: перехоплення даних з Bluetooth-ваги без нативного додатку
- [ ] Підключення до HealthKit для читання та запису

---

## Поточний пріоритет

```
⭐ ЗАРАЗ: Відновити Supabase → Застосувати міграції 002 + 003 → sync_to_supabase.py
⭐ ДАЛІ:  ingest-health Edge Function + iOS Shortcut
⭐ ПОТІМ: coachHandler + coachPrompt → кнопка 🏃 в боті
```
