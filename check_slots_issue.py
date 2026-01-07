#!/usr/bin/env python3
import sqlite3

conn = sqlite3.connect(r'C:\MQ2\lua\yalm2\MQ2LinkDB.db')
cur = conn.cursor()

# Count items with AC but no slots
print("Checking raw_item_data table for items with AC but missing/zero slots:")
print()

# Items with AC > 0 but slots = 0
count_zero = cur.execute(
    "SELECT COUNT(*) FROM raw_item_data WHERE ac > 0 AND (slots IS NULL OR slots = 0)"
).fetchone()[0]

print(f"Items with AC > 0 but slots = 0 or NULL: {count_zero}")

# Total items with AC > 0
total_ac = cur.execute(
    "SELECT COUNT(*) FROM raw_item_data WHERE ac > 0"
).fetchone()[0]

print(f"Total items with AC > 0: {total_ac}")

if total_ac > 0:
    percent = (count_zero / total_ac) * 100
    print(f"Percentage affected: {percent:.1f}%")

print()

# Show some examples
print("Sample items with AC but slots=0:")
rows = cur.execute(
    "SELECT id, name, ac, slots FROM raw_item_data WHERE ac > 0 AND slots = 0 ORDER BY ac DESC LIMIT 20"
).fetchall()

for row in rows:
    print(f"  ID {row[0]:6d}: {row[1]:40s} AC={row[2]:3d} Slots={row[3]}")

conn.close()
