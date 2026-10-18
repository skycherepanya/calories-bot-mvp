# iOS Shortcut: Lifecore Morning Sync

Цей документ описує логіку та налаштування iOS Shortcut, який автоматично передає дані з Apple Health та Apple Watch у Lifecore кожного ранку.

---

## Призначення

Щоразу після пробіджки або о 09:00 ранку Shortcut зчитує біометричні дані за вчорашній день і надсилає їх POST-запитом на Supabase Edge Function `ingest-health`. Ці дані потрапляють у таблиці `sleep_logs` та `workouts`, і стають доступні для `/coach` аналізу в Telegram.

---

## Налаштування в Shortcuts

**Назва:** `Lifecore Morning Sync`  
**Automation trigger:** Щодня о 09:00 АБО «Після завершення тренування» (Workout ends)

---

## JSON-структура запиту

```json
{
  "secret": "YOUR_INGEST_SECRET",
  "user_id": 123456789,
  "sleep": {
    "sleep_date": "2026-10-16",
    "total_hours": 6.8,
    "deep_hours": 1.2,
    "rem_hours": 1.5,
    "core_hours": 4.1,
    "awake_hours": 0.3,
    "hrv_avg_ms": 102.4,
    "rhr_bpm": 49.0
  },
  "workout": {
    "type": "running",
    "duration_min": 35,
    "avg_heart_rate": 158,
    "max_heart_rate": 174,
    "active_calories": 420,
    "distance_km": 5.1,
    "elevation_m": 42,
    "started_at": "2026-10-17T07:00:00+02:00"
  }
}
```

Поля `sleep` та `workout` є **опціональними** — можна відправляти одне або обидва.

---

## Покрокова логіка Shortcut

### Блок 1: Змінні середовища
```
Set variable SUPABASE_URL = "https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health"
Set variable SECRET = "ВАШ_СЕКРЕТНИЙ_КЛЮЧ"
Set variable USER_ID = "ВАШ_TELEGRAM_ID"
```

### Блок 2: Зчитування сну (за вчора)
```
Get health samples:
  - Type: Sleep Analysis
  - Period: Yesterday (00:00 → 23:59)
Aggregate:
  - total_hours = sum of all sleep phases / 3600
  - deep_hours  = AsleepDeep / 3600
  - rem_hours   = AsleepREM / 3600
  - core_hours  = AsleepCore / 3600
```

### Блок 3: Зчитування HRV та RHR (за сьогодні вранці)
```
Get health samples:
  - Type: Heart Rate Variability (SDNN) → last value
  - Type: Resting Heart Rate → last value
```

### Блок 4: Зчитування тренування (якщо є за сьогодні)
```
Get workouts:
  - Period: Today (since 00:00)
  - Type: Running / Cycling / Other
If workouts found:
  - workout_type = Activity Type
  - duration_min = Duration / 60
  - avg_heart_rate = Average Heart Rate
  - max_heart_rate = Max Heart Rate  
  - active_calories = Active Energy Burned
  - distance_km = Distance / 1000
  - elevation_m = Elevation Gain
  - started_at = Start Date (ISO8601)
```

### Блок 5: Збірка та відправка запиту
```
Construct JSON Dictionary:
  secret → SECRET
  user_id → USER_ID (as number)
  sleep → {sleep_date, total_hours, deep_hours, rem_hours, core_hours, hrv_avg_ms, rhr_bpm}
  workout → {type, duration_min, avg_heart_rate, ...} (if workout found)

Get contents of URL:
  URL: SUPABASE_URL
  Method: POST
  Headers: Content-Type: application/json
  Body: JSON Dictionary
```

### Блок 6: Push-сповіщення
```
If result contains "ok":
  Show notification: "✅ Lifecore synced: Sleep 6.8h | HRV 102 ms"
Else:
  Show notification: "⚠️ Lifecore sync failed"
```

---

## Endpoint: `ingest-health` Edge Function

**URL:** `POST https://[SUPABASE_PROJECT].supabase.co/functions/v1/ingest-health`

**Авторизація:** через поле `secret` у тілі запиту (не через JWT), щоб iOS Shortcuts міг робити запити без авторизаційних заголовків.

**Секрет:** зберігається у Supabase Secrets як `INGEST_SECRET` (додати через `supabase secrets set INGEST_SECRET=...`).

---

## Додаткові нотатки

- Apple Watch оновлює HRV та RHR зазвичай між 06:00 та 09:00, тому Shortcut краще запускати не раніше 09:00.
- Якщо тренування проводяться зранку до 09:00, краще тригерити Shortcut «Після завершення тренування» (Workout Ends), а не по таймеру.
- `sleep_date` = дата вечора, коли ти ліг спати (тобто якщо ліг о 23:30 15-го і встав о 07:00 16-го → `sleep_date = "2026-10-15"`).
