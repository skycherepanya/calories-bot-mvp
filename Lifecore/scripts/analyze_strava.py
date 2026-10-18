import pandas as pd
import numpy as np

from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
csv_path = BASE_DIR / 'data' / 'strava' / 'activities.csv'

df = pd.read_csv(csv_path)
df['Activity Date'] = pd.to_datetime(df['Activity Date'])
df = df.sort_values('Activity Date')

# Basic stats
runs = df[df['Activity Type'] == 'Run']
print("=== Basic Stats ===")
print(f"Total Activities: {len(df)}")
print(f"Total Runs: {len(runs)}")
print(f"Total Distance (km): {runs['Distance'].sum():.2f}")
print(f"Total Moving Time (hrs): {runs['Moving Time'].sum() / 3600:.2f}")

# Group by month
runs['Month'] = runs['Activity Date'].dt.to_period('M')
monthly_stats = runs.groupby('Month').agg({
    'Distance': ['sum', 'mean', 'max'],
    'Average Speed': 'mean',
    'Average Heart Rate': 'mean',
    'Elevation Gain': 'sum',
}).reset_index()
print("\n=== Monthly Stats ===")
print(monthly_stats)

# Correlations
print("\n=== Correlations ===")
corr = runs[['Distance', 'Moving Time', 'Elevation Gain', 'Average Speed', 'Average Heart Rate', 'Relative Effort']].corr()
print(corr)

# Insights
print("\n=== Insights ===")
# Is pace improving? Pace is 1000 / Average Speed if Speed is in m/s. 
# Let's check Average Speed (Strava exports speed in m/s)
runs['Pace (min/km)'] = 1000 / runs['Average Speed'] / 60
monthly_pace = runs.groupby('Month')['Pace (min/km)'].mean()
print("Monthly Average Pace (min/km):")
print(monthly_pace)

print("\nLongest Runs:")
print(runs.nlargest(5, 'Distance')[['Activity Date', 'Activity Name', 'Distance', 'Pace (min/km)', 'Average Heart Rate']])
