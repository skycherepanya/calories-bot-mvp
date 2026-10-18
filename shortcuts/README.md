# iOS Shortcuts: Lifecore Integration

Цей каталог містить документацію для iOS Shortcuts, які автоматично передають дані з Apple Health та Apple Watch у базу даних Lifecore.

---

## Shortcuts у цьому каталозі

| Файл | Призначення |
|---|---|
| [ingest_health_shortcut.md](./ingest_health_shortcut.md) | Головний синк: сон + тренування → Supabase `ingest-health` |

---

## Архітектура інтеграції

```
Apple Watch (HRV, RHR, Workout, Sleep)
        ↓
   HealthKit API
        ↓
  iOS Shortcut (Lifecore Morning Sync)
        ↓
  POST /functions/v1/ingest-health
        ↓
  Supabase Edge Function (Deno)
        ↓
  sleep_logs + workouts tables
        ↓
  /coach command in Telegram
```

---

## Як додати секрет у Supabase

```bash
supabase secrets set INGEST_SECRET="your_random_secret_here"
supabase functions deploy ingest-health --no-verify-jwt
```
