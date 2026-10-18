"""
sync_to_supabase.py — Lifecore Historical Data Sync

Loads archived Apple Health and Strava data into Supabase PostgreSQL.
Run ONCE after applying DB migrations 002 and 003,
or again after exporting a fresh Apple Health archive.

Usage:
    cd Lifecore/
    python scripts/sync_to_supabase.py

Requirements:
    pip install supabase pandas python-dotenv

Environment variables (reads from ../.env in the project root):
    SUPABASE_URL
    SUPABASE_KEY  (service_role key recommended for bulk inserts)
    ALLOWED_USER_ID
"""

import json
import csv
import os
import sys
from pathlib import Path
from datetime import datetime, timedelta

from dotenv import load_dotenv

# ── Paths ──────────────────────────────────────────────────────────────────
BASE_DIR = Path(__file__).resolve().parent.parent
SCRIPT_DIR = Path(__file__).resolve().parent

# Load .env from project root
env_path = BASE_DIR.parent / '.env' if (BASE_DIR.parent / '.env').exists() else BASE_DIR / '.env'
if not env_path.exists():
    print(f"[ERROR] .env file not found at {env_path}")
    sys.exit(1)
load_dotenv(env_path)

SUPABASE_URL = os.getenv('SUPABASE_URL')
SUPABASE_KEY = os.getenv('SUPABASE_KEY')
USER_ID = int(os.getenv('ALLOWED_USER_ID', '0'))

if not SUPABASE_URL or not SUPABASE_KEY or not USER_ID:
    print("[ERROR] Missing SUPABASE_URL, SUPABASE_KEY, or ALLOWED_USER_ID in .env")
    sys.exit(1)

try:
    from supabase import create_client
except ImportError:
    print("[ERROR] supabase not installed. Run: pip install supabase")
    sys.exit(1)

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

HEALTH_SUMMARY = SCRIPT_DIR.parent / 'reports' / 'daily_health_summary.json'
STRAVA_CSV = SCRIPT_DIR.parent / 'data' / 'strava' / 'activities.csv'

SHIFT_HOURS = 4  # Same dietary day shift as the Telegram bot


def dietary_date_from_dt(dt: datetime) -> str:
    """Apply the same 4-hour shift rule used by the Telegram bot."""
    shifted = dt - timedelta(hours=SHIFT_HOURS)
    return shifted.strftime('%Y-%m-%d')


# ── 1. Sync Sleep Logs from daily_health_summary.json ──────────────────────
def sync_sleep_logs():
    if not HEALTH_SUMMARY.exists():
        print(f"[SKIP] daily_health_summary.json not found at {HEALTH_SUMMARY}")
        print("       Run scripts/deep_health_analysis.py first to generate it.")
        return

    with open(HEALTH_SUMMARY, 'r', encoding='utf-8') as f:
        data = json.load(f)

    daily = data.get('daily', [])
    records = []
    for day in daily:
        hrv = day.get('hrv_avg')
        rhr = day.get('rhr_avg')
        # Only insert days where we have at least HRV or RHR data
        if hrv is None and rhr is None:
            continue
        records.append({
            'user_id': USER_ID,
            'source': 'apple_health',
            'sleep_date': day['date'],
            'total_hours': None,
            'hrv_avg_ms': round(hrv, 2) if hrv else None,
            'rhr_bpm': round(rhr, 1) if rhr else None,
        })

    if not records:
        print("[SKIP] No HRV/RHR data found in daily_health_summary.json")
        return

    print(f"[SYNC] Uploading {len(records)} sleep_logs records...")
    chunk_size = 100
    for i in range(0, len(records), chunk_size):
        chunk = records[i:i + chunk_size]
        supabase.table('sleep_logs').upsert(chunk, on_conflict='user_id,sleep_date').execute()
        print(f"  → Sleep logs chunk {i // chunk_size + 1}/{(len(records) + chunk_size - 1) // chunk_size} uploaded.")
    print(f"[OK]   sleep_logs: {len(records)} records processed.")


# ── 1b. Sync Daily Activity Metrics (Steps, Active Kcal, NEAT) ─────────────
def sync_daily_metrics():
    if not HEALTH_SUMMARY.exists():
        print(f"[SKIP] daily_health_summary.json not found.")
        return

    with open(HEALTH_SUMMARY, 'r', encoding='utf-8') as f:
        data = json.load(f)

    daily = data.get('daily', [])
    records = []
    for day in daily:
        steps_src = day.get('steps_by_source', {})
        active_src = day.get('active_by_source', {})
        if not steps_src and not active_src:
            continue

        # Prioritize Apple Watch over iPhone to avoid double counting
        watch_steps = next((v for k, v in steps_src.items() if 'watch' in k.lower()), None)
        iphone_steps = next((v for k, v in steps_src.items() if 'iphone' in k.lower()), None)
        steps = int(round(watch_steps if watch_steps else (iphone_steps if iphone_steps else sum(steps_src.values()))))

        watch_active = next((v for k, v in active_src.items() if 'watch' in k.lower()), None)
        active_kcal = round(watch_active if watch_active else sum(active_src.values()), 1)

        records.append({
            'user_id': USER_ID,
            'metric_date': day['date'],
            'steps': steps if steps > 0 else None,
            'active_kcal': active_kcal if active_kcal > 0 else None,
            'source': 'apple_health',
        })

    if not records:
        print("[SKIP] No daily steps/active energy data found.")
        return

    print(f"[SYNC] Uploading {len(records)} daily_metrics records...")
    chunk_size = 100
    for i in range(0, len(records), chunk_size):
        chunk = records[i:i + chunk_size]
        supabase.table('daily_metrics').upsert(chunk, on_conflict='user_id,metric_date').execute()
        print(f"  → Daily metrics chunk {i // chunk_size + 1}/{(len(records) + chunk_size - 1) // chunk_size} uploaded.")
    print(f"[OK]   daily_metrics: {len(records)} records processed.")


# ── 2. Sync Strava Activities ───────────────────────────────────────────────
def sync_strava_activities():
    """Returns list of indexed (datetime, elapsed_min, moving_min) for deduplication with Health."""
    if not STRAVA_CSV.exists():
        print(f"[SKIP] activities.csv not found at {STRAVA_CSV}")
        return []

    records = []
    strava_index = []

    with open(STRAVA_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            activity_type = row.get('Activity Type', '').lower()
            if activity_type not in ['run', 'ride', 'walk', 'hike']:
                continue
            date_str = row.get('Activity Date', '').strip()
            if not date_str:
                continue

            try:
                dt = datetime.strptime(date_str, '%b %d, %Y, %I:%M:%S %p')
            except Exception:
                try:
                    dt = datetime.strptime(date_str[:19], '%Y-%m-%d %H:%M:%S')
                except Exception:
                    print(f"[WARN] Cannot parse Strava date: {date_str}")
                    continue

            distance_m = float(row.get('Distance', 0) or 0)
            moving_time_s = float(row.get('Moving Time', 0) or 0)
            elapsed_time_s = float(row.get('Elapsed Time', 0) or 0)
            avg_speed_ms = float(row.get('Average Speed', 0) or 0)
            avg_pace = round(1000 / avg_speed_ms / 60, 2) if avg_speed_ms > 0 else None

            type_map = {'run': 'running', 'ride': 'cycling', 'walk': 'walking', 'hike': 'walking'}
            records.append({
                'user_id': USER_ID,
                'workout_type': type_map.get(activity_type, 'other'),
                'source': 'strava',
                'started_at': dt.isoformat(),
                'duration_min': round(moving_time_s / 60, 1) if moving_time_s else round(elapsed_time_s / 60, 1),
                'distance_km': round(distance_m / 1000, 2) if distance_m else None,
                'avg_heart_rate': float(row.get('Average Heart Rate', 0) or 0) or None,
                'max_heart_rate': float(row.get('Max Heart Rate', 0) or 0) or None,
                'active_kcal': float(row.get('Calories', 0) or 0) or None,
                'avg_pace_min_km': avg_pace,
                'elevation_m': float(row.get('Elevation Gain', 0) or 0) or None,
                'dietary_date': dietary_date_from_dt(dt),
                'notes': row.get('Activity Name', ''),
                'raw_data': dict(row),
            })
            strava_index.append((dt, elapsed_time_s / 60.0, moving_time_s / 60.0))

    if not records:
        print("[SKIP] No Strava activities to sync.")
        return []

    print(f"[SYNC] Uploading {len(records)} Strava activity records...")
    chunk_size = 100
    for i in range(0, len(records), chunk_size):
        chunk = records[i:i + chunk_size]
        supabase.table('workouts').insert(chunk).execute()
        print(f"  → Strava chunk {i // chunk_size + 1}/{(len(records) + chunk_size - 1) // chunk_size} uploaded.")
    print(f"[OK]   workouts (Strava): {len(records)} records processed.")
    return strava_index


# ── 3. Sync Workouts from daily_health_summary.json (Deduplicated) ──────────
def sync_health_workouts(strava_index):
    if not HEALTH_SUMMARY.exists():
        print(f"[SKIP] daily_health_summary.json not found.")
        return

    with open(HEALTH_SUMMARY, 'r', encoding='utf-8') as f:
        data = json.load(f)

    raw_workouts = data.get('workouts', [])
    records = []
    skipped_dups = 0

    for w in raw_workouts:
        if not w.get('date') or not w.get('type'):
            continue
        try:
            dt = datetime.strptime(w['date'][:19], '%Y-%m-%d %H:%M:%S')
            dur = float(w.get('duration_min', 0) or 0)

            # Check if this workout is already covered by Strava (deduplication)
            is_dup = False
            for s_dt, s_elapsed, s_moving in strava_index:
                if abs(dur - s_elapsed) < 2.0 or abs(dur - s_moving) < 2.0:
                    diff_hours = (dt - s_dt).total_seconds() / 3600.0
                    # Account for UTC vs Kyiv local timezone offsets (0h to 3h)
                    if any(abs(diff_hours - offset) < 0.35 for offset in [0, 1, 2, 3]):
                        is_dup = True
                        break

            if is_dup:
                skipped_dups += 1
                continue

            # Map workout type
            wtype_raw = w.get('type', '').lower()
            if 'running' in wtype_raw:
                wtype = 'running'
            elif 'cycling' in wtype_raw:
                wtype = 'cycling'
            elif 'walking' in wtype_raw:
                wtype = 'walking'
            elif 'functional' in wtype_raw or 'traditionalstrength' in wtype_raw:
                wtype = 'strength'
            else:
                wtype = 'other'

            records.append({
                'user_id': USER_ID,
                'workout_type': wtype,
                'source': 'apple_health',
                'started_at': dt.isoformat(),
                'duration_min': round(dur, 1),
                'active_kcal': round(w.get('energy_kcal', 0), 1) or None,
                'dietary_date': dietary_date_from_dt(dt),
                'notes': f"Apple Health ({w.get('source', '')})",
                'raw_data': w,
            })
        except Exception as e:
            print(f"[WARN] Skipping workout entry: {e}")
            continue

    if skipped_dups > 0:
        print(f"[INFO] Filtered out {skipped_dups} duplicate Apple Health workouts that already exist in Strava.")

    if not records:
        print("[SKIP] No unique workout data found in daily_health_summary.json")
        return

    print(f"[SYNC] Uploading {len(records)} unique workout records from Apple Health...")
    chunk_size = 100
    for i in range(0, len(records), chunk_size):
        chunk = records[i:i + chunk_size]
        supabase.table('workouts').insert(chunk).execute()
        print(f"  → Health chunk {i // chunk_size + 1}/{(len(records) + chunk_size - 1) // chunk_size} uploaded.")
    print(f"[OK]   workouts (Apple Health): {len(records)} unique records processed.")


# ── Main ────────────────────────────────────────────────────────────────────
if __name__ == '__main__':
    print("=" * 60)
    print("Lifecore: Historical Data Sync to Supabase")
    print(f"Target user_id: {USER_ID}")
    print(f"Supabase URL: {SUPABASE_URL}")
    print("=" * 60)

    sync_sleep_logs()
    sync_daily_metrics()
    strava_index = sync_strava_activities()
    sync_health_workouts(strava_index)

    print("\n✅ Sync complete.")
