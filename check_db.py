#!/usr/bin/env python3
import sqlite3

conn = sqlite3.connect(r'C:\MQ2\lua\yalm2\MQ2LinkDB.db')
cur = conn.cursor()

# List tables
tables = cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print("Tables in MQ2LinkDB.db:")
for t in tables:
    print(f"  {t[0]}")

# Check if raw_item_data exists and has rows
if tables:
    print("\nChecking raw_item_data table:")
    try:
        count = cur.execute("SELECT COUNT(*) FROM raw_item_data").fetchone()[0]
        print(f"  Total rows: {count}")
        
        # Try to find items
        print(f"\nSearching for item 121564:")
        row = cur.execute("SELECT id, name FROM raw_item_data WHERE id = 121564").fetchone()
        if row:
            print(f"  Found: {row}")
        else:
            print(f"  Not found")
            
        print(f"\nSearching for item 4654:")
        row = cur.execute("SELECT id, name FROM raw_item_data WHERE id = 4654").fetchone()
        if row:
            print(f"  Found: {row}")
        else:
            print(f"  Not found")
            
        # Show some sample IDs
        print(f"\nSample item IDs in database (first 10):")
        samples = cur.execute("SELECT id, name FROM raw_item_data LIMIT 10").fetchall()
        for s in samples:
            print(f"  {s[0]}: {s[1]}")
    except Exception as e:
        print(f"  Error: {e}")

conn.close()
