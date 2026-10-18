import xml.etree.ElementTree as ET
from datetime import datetime
from collections import defaultdict
import sys

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


print("Analyzing steps specifically to check for double counting...")
steps_by_day_and_source = defaultdict(lambda: defaultdict(float))

count = 0
for event, elem in ET.iterparse(file_path, events=('start',)):
    if elem.tag == 'Record' and elem.get('type') == 'HKQuantityTypeIdentifierStepCount':
        date_str = elem.get('startDate')
        source = elem.get('sourceName', 'Unknown')
        
        if date_str:
            try:
                dt = datetime.strptime(date_str[:19], '%Y-%m-%d %H:%M:%S')
                val = float(elem.get('value'))
                steps_by_day_and_source[dt.date()][source] += val
            except Exception as e:
                pass
        elem.clear()
        count += 1

# Process last 30 days of data for a quick check
recent_days = sorted(steps_by_day_and_source.keys())[-14:]

print("\n--- Daily Steps Breakdown (Last 14 Days) ---")
for day in recent_days:
    sources = steps_by_day_and_source[day]
    total_naive = sum(sources.values())
    print(f"{day}:")
    for src, val in sources.items():
        print(f"  - {src}: {val:.0f}")
    print(f"  >> Naive Sum: {total_naive:.0f}")
