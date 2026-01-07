#!/usr/bin/env python3
"""
Update MQ2LinkDB.db raw_item_data table with complete item data from Lucy JSON files
This will fill in missing slots, ac, hp, mana, endur, attack, and other stats
"""

import sqlite3
import json
import os
from pathlib import Path
from datetime import datetime

db_path = r'C:\MQ2\lua\yalm2\MQ2LinkDB.db'
lucy_dir = r'D:\lucy'

# Fields to update from Lucy JSON
LUCY_FIELDS = [
    'slots', 'ac', 'hp', 'mana', 'endur', 'attack', 'mr', 'fr', 'cr', 'pr', 'dr',
    'regen', 'manaregen', 'healamt', 'clairvoyance', 'spelleffect', 'worneffect',
    'reqlevel', 'classes', 'itemtype', 'wearslot', 'lore', 'nodrop'
]

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Find items that need updating (have AC but slots=0 or NULL)
print("=" * 70)
print("MQ2LinkDB Update from Lucy JSON Files")
print("=" * 70)
print()

print("Finding items with AC but missing slots...")
rows = cur.execute(
    "SELECT id FROM raw_item_data WHERE ac > 0 AND (slots IS NULL OR slots = 0) ORDER BY id"
).fetchall()

items_to_update = [row[0] for row in rows]
print(f"Found {len(items_to_update)} items that need slots data from Lucy")
print()

# Check how many Lucy files we can actually find
print("Checking Lucy JSON file availability...")
found_lucy = []
missing_lucy = []

for item_id in items_to_update:
    lucy_file = os.path.join(lucy_dir, f'lucy_item_{item_id}.json')
    if os.path.exists(lucy_file):
        found_lucy.append(item_id)
    else:
        missing_lucy.append(item_id)

print(f"  Found in Lucy directory: {len(found_lucy)}")
print(f"  Missing from Lucy directory: {len(missing_lucy)}")
print()

if len(found_lucy) == 0:
    print("ERROR: No Lucy files found for items needing update!")
    exit(1)

# Show coverage
coverage = (len(found_lucy) / len(items_to_update)) * 100
print(f"Coverage: {coverage:.1f}% of items can be updated from Lucy")
print()

# Now do the actual update
print("Starting database update...")
print()

updated_count = 0
error_count = 0
skipped_count = 0

for idx, item_id in enumerate(found_lucy):
    lucy_file = os.path.join(lucy_dir, f'lucy_item_{item_id}.json')
    
    try:
        # Read Lucy JSON
        with open(lucy_file, 'r') as f:
            lucy_data = json.load(f)
        
        # Build update SQL - only update fields that exist in Lucy
        update_fields = []
        update_values = []
        
        for field in LUCY_FIELDS:
            if field in lucy_data:
                value = lucy_data[field]
                # Skip empty strings and null-like values
                if value != '' and value is not None:
                    update_fields.append(f'{field} = ?')
                    update_values.append(value)
        
        if update_fields:
            sql = f"UPDATE raw_item_data SET {', '.join(update_fields)} WHERE id = ?"
            update_values.append(item_id)
            
            cur.execute(sql, update_values)
            updated_count += 1
        else:
            skipped_count += 1
    
    except Exception as e:
        print(f"Error processing item {item_id}: {e}")
        error_count += 1
    
    # Progress update
    if (idx + 1) % 1000 == 0:
        percent = ((idx + 1) / len(found_lucy)) * 100
        print(f"  Progress: {idx + 1}/{len(found_lucy)} ({percent:.1f}%) - Updated: {updated_count}, Errors: {error_count}, Skipped: {skipped_count}")

print()
print("=" * 70)
print("Update Statistics:")
print("=" * 70)
print(f"Items processed: {len(found_lucy)}")
print(f"Successfully updated: {updated_count}")
print(f"Errors: {error_count}")
print(f"Skipped: {skipped_count}")
print()

# Commit changes
print("Committing changes to database...")
conn.commit()

# Verify results
print()
print("Verification:")
print("-" * 70)

# Check how many items now have slots
still_missing = cur.execute(
    "SELECT COUNT(*) FROM raw_item_data WHERE ac > 0 AND (slots IS NULL OR slots = 0)"
).fetchone()[0]

fixed = len(items_to_update) - still_missing
print(f"Items with AC and slots=0 before: {len(items_to_update)}")
print(f"Items with AC and slots=0 after: {still_missing}")
print(f"Items fixed: {fixed}")
print()

if still_missing > 0:
    print(f"Remaining items missing slots data:")
    remaining = cur.execute(
        "SELECT id, name, ac FROM raw_item_data WHERE ac > 0 AND (slots IS NULL OR slots = 0) LIMIT 10"
    ).fetchall()
    for item_id, name, ac in remaining:
        lucy_exists = os.path.exists(os.path.join(lucy_dir, f'lucy_item_{item_id}.json'))
        print(f"  Item {item_id}: {name} AC={ac} (Lucy file: {'exists' if lucy_exists else 'MISSING'})")

conn.close()
print()
print("Update complete!")
