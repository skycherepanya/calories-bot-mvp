# ARCHITECTURAL PIVOT: Lifecore 2.0 — Native iOS-First & Athletic Performance Platform

> **Статус документа:** Master Architectural Directive (Single Source of Truth для оновлення документації та кодової бази).
> **Призначення для AI-агентів:** Цей документ скасовує попередню Dual-архітектуру (Node.js Long Polling + Deno Edge Telegram Bot + iOS Webhook Ingestion)[cite: 1, 2, 3] і переводить проєкт **Lifecore** на єдину нативну **iOS-First архітектуру (SwiftUI + HealthKit + SwiftData/Supabase + Gemini API)**.

---

## 0. Прямі інструкції для AI-агентів (Action Plan з оновлення документації)

При обробці цього документа агент **зобов'язаний** виконати наступні кроки:

1. **Переписати `PROJECT_KNOWLEDGE.md`:**
   - Замінити розділ *Current Implementation (Dual Architecture: Node.js + Supabase Edge Telegram Bot)* на архітектуру нативного iOS-додатка (`ios/Lifecore/`)[cite: 2].
   - Оновити розділ *AI Prompts Rules*[cite: 1]: повністю видалити тривожні медичні правила (`СТОП / ВІДНОВЛЕННЯ` при падінні HRV >15% або зростанні RHR >3 bpm)[cite: 1, 3] і замінити їх на правила **Athletic Performance Analyst (70/15/15)**[cite: 3] та детермінований математичний рушій у Swift.
2. **Переписати `AGENTS.md`:**
   - Видалити директиву *Dual Sync* (більше не потрібно синхронізувати логіку між Node.js `handlers/` та Deno `index.ts`)[cite: 1, 2].
   - Зафіксувати нові стандарти розробки: **Swift 6 / SwiftUI / Swift Charts / HealthKit / SwiftData**, модульна структура в `ios/Lifecore/`, суворе розділення детермінованої математики у Swift та генерації інсайтів у Gemini.
3. **Оновити `README.md` та `docs/ARCHITECTURE.md`:**
   - Описати нову 4-шарову On-Device архітектуру (HealthKit Source of Truth → Swift Math & Telemetry Engine → SwiftData + Supabase Cloud Backup → SwiftUI Bevel-style Dashboard & AI Coach).
   - Перевести папки `handlers/`, `utils/`, `index.js` та `supabase/functions/telegram-bot/` у статус `Legacy / Deprecated`[cite: 1, 2].
4. **Оновити `docs/DATABASE.md` та `docs/ROADMAP.md`:**
   - Спростити схему хмарної БД (відмова від окремої реляційної таблиці `workout_splits` на користь локального парсингу з HealthKit та `JSONB` кешування розібраних тренувань)[cite: 3].
   - Сформувати новий Roadmap для iOS-додатка (Екран Today / Readiness, Екран Workouts & Splits Analyst, Екран Оптимістичного логування їжі, Екран Trends & Rolling Weight).

---

## 1. Чому ми змінюємо архітектуру (Контекст трансформації)

### Що було не так у версії 1.0 (Telegram + Dual Backend):
1. **Дублювання коду та інфраструктурне тертя:** Підтримка двох ідентичних бекендів (Node.js для локальної розробки та Deno Edge Function для продакшену)[cite: 1, 2, 3] плюс окремий пайплайн перекачування даних з Apple Health через `ingest-health` у Supabase[cite: 1, 2] створювали зайву складність, розсинхронізацію та затримки.
2. **Відсутність візуального дашборду (Bevel-style UX):** У Telegram неможливо за 2 секунди оцінити стан організму[cite: 3]. Користувачу потрібен нативний дашборд із кільцями *Recovery / Strain / Nutrition*, графіками тренду ваги та інтерактивними таблицями сплітів забігів.
3. **Проблема «Сміттєвих тренувань» та Strava API:** Намагання склеїти в базі даних тренування з Apple Health та Strava API для отримання сплітів вело до ризику дублювання калорій та складних евристик дедуплікації[cite: 3]. У нативному iOS-додатку всі посекундні дані пульсу, висоти, темпу та інтервалів вже доступні напряму з `HealthKit` без сторонніх API.
4. **Токсичний тон «Тривожного терапевта» в `/coach`:** Жорсткі пороги в промпті змушували LLM ігнорувати сам забіг і видавати банальні медичні повчання («прийміть теплу ванну», «дихальні практики», «критичний стрес») через нормальні фізіологічні коливання пульсу спокою[cite: 1, 3].

---

## 2. Цільова Архітектура Lifecore 2.0 (Native iOS-First)