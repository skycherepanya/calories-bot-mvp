# iOS Shortcut: Lifecore Morning Sync

This document details the configuration and architecture of the iOS Shortcut responsible for automatically synchronizing Apple Health and Apple Watch biometric telemetry with the Lifecore warehouse.

---

## Purpose

Every morning (or directly upon completing an exercise session), the Shortcut queries HealthKit for the previous night's sleep phases and the morning's autonomic recovery biomarkers (HRV and Resting Heart Rate), then dispatches them via an HTTP POST request to the Supabase `ingest-health` Edge Function. The data populates the `sleep_logs` and `workouts` tables, immediately empowering the `/coach` command in Telegram.

---

## Shortcut Configuration

* **Name:** `Lifecore Morning Sync`
* **Automation Trigger:** Daily at 09:00 AM OR "When workout ends"

---

## Request Payload Structure

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

The `sleep` and `workout` objects are **optional** — the payload can transmit either one or both simultaneously.

---

## Step-by-Step Shortcut Logic

### Block 1: Environment Variables
```
Set variable SUPABASE_URL = "https://<PROJECT-REF>.supabase.co/functions/v1/ingest-health"
Set variable SECRET = "YOUR_INGEST_SECRET"
Set variable USER_ID = "YOUR_TELEGRAM_ID"
```

### Block 2: Sleep Sampling (Previous Night)
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

### Block 3: Autonomic Biomarkers (Morning HRV & RHR)
```
Get health samples:
  - Type: Heart Rate Variability (SDNN) → latest value
  - Type: Resting Heart Rate → latest value
```

### Block 4: Workout Sampling (Today's Activities)
```
Get workouts:
  - Period: Today (since 00:00)
  - Type: Running / Cycling / Strength / Other
If workouts found:
  - workout_type = Activity Type
  - duration_min = Duration / 60
  - avg_heart_rate = Average Heart Rate
  - max_heart_rate = Max Heart Rate
  - active_calories = Active Energy Burned
  - distance_km = Distance / 1000
  - elevation_m = Elevation Gain
  - started_at = Start Date (ISO 8601)
```

### Block 5: Payload Construction & Transmission
```
Construct JSON Dictionary:
  secret → SECRET
  user_id → USER_ID (as number)
  sleep → {sleep_date, total_hours, deep_hours, rem_hours, core_hours, hrv_avg_ms, rhr_bpm}
  workout → {type, duration_min, avg_heart_rate, ...} (if workout detected)

Get contents of URL:
  URL: SUPABASE_URL
  Method: POST
  Headers: Content-Type: application/json
  Body: JSON Dictionary
```

### Block 6: User Feedback & Notification
```
If response contains "ok":
  Show notification: "✅ Lifecore synced: Sleep recorded | HRV updated"
Else:
  Show notification: "⚠️ Lifecore sync failed"
```

---

## Endpoint: `ingest-health` Edge Function

* **URL:** `POST https://[SUPABASE_PROJECT].supabase.co/functions/v1/ingest-health`
* **Authentication:** Validated via the `secret` field inside the JSON body (bypassing JWT header restrictions within iOS Shortcuts).
* **Secret Storage:** Managed securely via Supabase Secrets (`INGEST_SECRET`).

---

## Operational Notes

* Apple Watch updates HRV and Resting Heart Rate algorithms between 06:00 and 09:00 AM; running the sync at 09:00 AM ensures accurate recovery readings.
* For morning workouts taking place prior to 09:00 AM, triggering the Shortcut via the iOS "When Workout Ends" automation provides instantaneous logging.
* `sleep_date` denotes the date the user went to sleep (e.g. falling asleep at 23:30 on Oct 15 and waking at 07:00 on Oct 16 yields `sleep_date = "2026-10-15"`).
