import xml.etree.ElementTree as ET
from datetime import datetime
from collections import defaultdict

import os
import sys
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
HEALTH_DIR = BASE_DIR / 'data' / 'health'

def find_export_file():
    if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
        return Path(sys.argv[1])
    candidates = list(HEALTH_DIR.glob('**/export.xml'))
    if candidates:
        return candidates[0]
    return HEALTH_DIR / 'export.xml'

file_path = find_export_file()
if not file_path.exists():
    print(f"File not found: {file_path}")
    print(f"Please place your Apple Health export into {HEALTH_DIR}")
    sys.exit(1)


target_types = {
    'HKQuantityTypeIdentifierHeartRateVariabilitySDNN': 'HRV',
    'HKQuantityTypeIdentifierRestingHeartRate': 'RestingHR',
    'HKQuantityTypeIdentifierStepCount': 'Steps'
}

data_by_month = defaultdict(lambda: defaultdict(list))
min_date = None
max_date = None
workouts_by_month = defaultdict(int)

print("Starting to parse all data...")
for event, elem in ET.iterparse(file_path, events=('start',)):
    if elem.tag == 'Record':
        rtype = elem.get('type')
        if rtype in target_types:
            date_str = elem.get('startDate')
            if date_str:
                try:
                    dt = datetime.strptime(date_str[:19], '%Y-%m-%d %H:%M:%S')
                    if min_date is None or dt < min_date: min_date = dt
                    if max_date is None or dt > max_date: max_date = dt
                    
                    month_key = dt.strftime('%Y-%m')
                    val = float(elem.get('value'))
                    data_by_month[month_key][target_types[rtype]].append((dt, val))
                except:
                    pass
        elem.clear()
    elif elem.tag == 'Workout':
        date_str = elem.get('startDate')
        if date_str:
            try:
                dt = datetime.strptime(date_str[:19], '%Y-%m-%d %H:%M:%S')
                if min_date is None or dt < min_date: min_date = dt
                if max_date is None or dt > max_date: max_date = dt
                month_key = dt.strftime('%Y-%m')
                workouts_by_month[month_key] += 1
            except:
                pass
        elem.clear()

print(f"\nData range: {min_date} to {max_date}")

# Process and print
for month in sorted(data_by_month.keys()):
    month_data = data_by_month[month]
    
    print(f"\n--- {month} ---")
    
    # Steps
    if 'Steps' in month_data:
        steps_by_day = defaultdict(float)
        for d, v in month_data['Steps']:
            steps_by_day[d.date()] += v
        daily_steps = list(steps_by_day.values())
        if daily_steps:
            print(f"Steps: {sum(daily_steps)/len(daily_steps):.0f} avg/day (days with data: {len(daily_steps)})")
            
    # HRV
    if 'HRV' in month_data:
        hrv_vals = [v for d, v in month_data['HRV']]
        print(f"HRV: {sum(hrv_vals)/len(hrv_vals):.2f} avg (count: {len(hrv_vals)})")
        
    # Resting HR
    if 'RestingHR' in month_data:
        rhr_vals = [v for d, v in month_data['RestingHR']]
        print(f"Resting HR: {sum(rhr_vals)/len(rhr_vals):.2f} avg (count: {len(rhr_vals)})")
        
    print(f"Workouts: {workouts_by_month.get(month, 0)}")
