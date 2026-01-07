#!/usr/bin/env python3
import sqlite3
import json
import os
from pathlib import Path

db_path = r'C:\MQ2\lua\yalm2\MQ2LinkDB.db'
lucy_dir = r'D:\lucy'

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find all items in raw_item_data with AC but no slots
print("Finding items with AC but missing slots in database...")
rows = cur.execute(
    "SELECT id FROM raw_item_data WHERE ac > 0 AND (slots IS NULL OR slots = 0) ORDER BY id"
).fetchall()

missing_slots_ids = [row[0] for row in rows]
print(f"Found {len(missing_slots_ids)} items needing slots data")

# Check how many Lucy files exist for these items
print(f"\nChecking for Lucy JSON files...")
found_count = 0
missing_count = 0

for item_id in missing_slots_ids[:100]:  # Check first 100
    lucy_file = os.path.join(lucy_dir, f'lucy_item_{item_id}.json')
    if os.path.exists(lucy_file):
        found_count += 1
    else:
        missing_count += 1
        if missing_count <= 5:
            print(f"  Missing: lucy_item_{item_id}.json")

print(f"\nFrom first 100 checked:")
print(f"  Found in Lucy: {found_count}")
print(f"  Missing from Lucy: {missing_count}")

# Show which items we CAN update
if found_count > 0:
    print(f"\nWe can update approximately {found_count/100 * len(missing_slots_ids):.0f} items from Lucy data")
else:
    print(f"\nNo Lucy files found for these items")

conn.close()
