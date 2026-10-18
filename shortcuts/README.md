# iOS Shortcuts: Lifecore Integration

This directory contains specifications and setup guides for iOS Shortcuts that automatically synchronize Apple Health and Apple Watch telemetry to the Lifecore database warehouse.

---

## Shortcuts in this Directory

| File | Purpose |
|---|---|
| [ingest_health_shortcut.md](./ingest_health_shortcut.md) | Primary sync: sleep stages + workouts → Supabase `ingest-health` |

---

## Integration Architecture

```
Apple Watch (HRV, RHR, Workout, Sleep Phases)
        ↓
   HealthKit API
        ↓
   iOS Shortcut (Lifecore Morning Sync)
        ↓
   POST /functions/v1/ingest-health
        ↓
   Supabase Edge Function (Deno)
        ↓
   sleep_logs + workouts PostgreSQL tables
        ↓
   /coach command in Telegram
```

---

## Configuring the Supabase Ingestion Secret

```bash
supabase secrets set INGEST_SECRET="your_random_secret_here"
supabase functions deploy ingest-health --no-verify-jwt --use-api
```
