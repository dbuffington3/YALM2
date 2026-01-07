#!/usr/bin/env python3
import sqlite3

conn = sqlite3.connect(r'C:\MQ2\lua\yalm2\MQ2LinkDB.db')
cur = conn.cursor()

# List all tables
tables = cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print('Tables in MQ2LinkDB.db:')
for t in tables:
    print(f'  {t[0]}')

print('\nChecking raw_item_data table for item 121564:')
row = cur.execute('SELECT id, name, slots, classes FROM raw_item_data WHERE id = 121564').fetchone()
if row:
    print(f'  raw_item_data: ID={row[0]}, Name={row[1]}, Slots={row[2]}, Classes={row[3]}')

print('\nChecking raw_item_data_315 table for item 121564:')
try:
    row = cur.execute('SELECT id, name, slots, classes FROM raw_item_data_315 WHERE id = 121564').fetchone()
    if row:
        print(f'  raw_item_data_315: ID={row[0]}, Name={row[1]}, Slots={row[2]}, Classes={row[3]}')
    else:
        print('  Item not found in raw_item_data_315')
except Exception as e:
    print(f'  Error: {e}')

conn.close()
