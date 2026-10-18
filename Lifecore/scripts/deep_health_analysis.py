import xml.etree.ElementTree as ET
from datetime import datetime, date
from collections import defaultdict
import json
from pathlib import Path

xml_path = Path('data/health/apple_health_export/export.xml')

target_record_types = {
    'HKQuantityTypeIdentifierBodyMass': 'weight',
    'HKQuantityTypeIdentifierStepCount': 'steps',
    'HKQuantityTypeIdentifierActiveEnergyBurned': 'active_energy',
    'HKQuantityTypeIdentifierBasalEnergyBurned': 'basal_energy',
    'HKQuantityTypeIdentifierHeartRateVariabilitySDNN': 'hrv',
    'HKQuantityTypeIdentifierRestingHeartRate': 'resting_hr',
    'HKQuantityTypeIdentifierVO2Max': 'vo2max',
    'HKQuantityTypeIdentifierAppleExerciseTime': 'exercise_time'
}

weight_records = []
steps_by_day_source = defaultdict(lambda: defaultdict(float))
active_by_day_source = defaultdict(lambda: defaultdict(float))
basal_by_day_source = defaultdict(lambda: defaultdict(float))
hrv_by_day = defaultdict(list)
rhr_by_day = defaultdict(list)
vo2max_records = []
workouts = []

print("Starting streaming parse of export.xml...")
t0 = datetime.now()

for event, elem in ET.iterparse(xml_path, events=('end',)):
    tag = elem.tag
    if tag == 'Record':
        rtype = elem.get('type')
        if rtype in target_record_types:
            key = target_record_types[rtype]
            dt_str = elem.get('startDate', '')
            val_str = elem.get('value')
            source = elem.get('sourceName', 'Unknown')
            if dt_str and val_str:
                try:
                    dt = datetime.strptime(dt_str[:19], '%Y-%m-%d %H:%M:%S')
                    d = dt.date()
                    val = float(val_str)
                    
                    if key == 'weight':
                        weight_records.append((dt, val))
                    elif key == 'steps':
                        steps_by_day_source[d][source] += val
                    elif key == 'active_energy':
                        active_by_day_source[d][source] += val
                    elif key == 'basal_energy':
                        basal_by_day_source[d][source] += val
                    elif key == 'hrv':
                        hrv_by_day[d].append(val)
                    elif key == 'resting_hr':
                        rhr_by_day[d].append(val)
                    elif key == 'vo2max':
                        vo2max_records.append((dt, val))
                except Exception:
                    pass
        elem.clear()
    elif tag == 'Workout':
        wtype = elem.get('workoutActivityType')
        dur = elem.get('duration')
        energy = elem.get('totalEnergyBurned')
        sdate = elem.get('startDate')
        source = elem.get('sourceName', 'Unknown')
        if sdate:
            try:
                dt = datetime.strptime(sdate[:19], '%Y-%m-%d %H:%M:%S')
                workouts.append({
                    'type': wtype,
                    'duration_min': float(dur) if dur else 0.0,
                    'energy_kcal': float(energy) if energy else 0.0,
                    'date': str(dt),
                    'source': source
                })
            except Exception:
                pass
        elem.clear()

t1 = datetime.now()
print(f"Parsing complete in {(t1 - t0).total_seconds():.1f}s.")

# Save intermediate summary or print findings
print(f"\nTotal weight records: {len(weight_records)}")
recent_weights = sorted(weight_records, key=lambda x: x[0])[-25:]
print("\nRecent weight records:")
for dt, w in recent_weights:
    print(f"  {dt.strftime('%Y-%m-%d %H:%M')}: {w:.2f} kg")

# Check sources for active energy and steps
all_sources_active = set()
for d, sdict in active_by_day_source.items():
    all_sources_active.update(sdict.keys())
print("\nActive Energy Sources:", all_sources_active)

all_sources_steps = set()
for d, sdict in steps_by_day_source.items():
    all_sources_steps.update(sdict.keys())
print("Steps Sources:", all_sources_steps)

# Save processed daily summary into json for deep analysis
days = sorted(set(list(steps_by_day_source.keys()) + list(active_by_day_source.keys()) + list(basal_by_day_source.keys())))
daily_data = []
for d in days:
    daily_data.append({
        'date': str(d),
        'steps_by_source': steps_by_day_source[d],
        'active_by_source': active_by_day_source[d],
        'basal_by_source': basal_by_day_source[d],
        'hrv_avg': sum(hrv_by_day[d])/len(hrv_by_day[d]) if hrv_by_day[d] else None,
        'rhr_avg': sum(rhr_by_day[d])/len(rhr_by_day[d]) if rhr_by_day[d] else None,
    })

import json
with open('reports/daily_health_summary.json', 'w') as f:
    json.dump({
        'daily': daily_data,
        'weights': [(dt.strftime('%Y-%m-%d %H:%M:%S'), w) for dt, w in weight_records],
        'vo2max': [(dt.strftime('%Y-%m-%d %H:%M:%S'), v) for dt, v in vo2max_records],
        'workouts': workouts
    }, f, indent=2)

print("\nSummary written to reports/daily_health_summary.json")
