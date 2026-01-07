#!/usr/bin/env python3
import sqlite3

conn = sqlite3.connect(r'C:\MQ2\lua\yalm2\MQ2LinkDB.db')
cur = conn.cursor()

# Search for IDs near 4654
print("Searching for IDs near 4654:")
rows = cur.execute("SELECT id, name FROM raw_item_data WHERE id BETWEEN 4640 AND 4670").fetchall()
for r in rows:
    print(f"  {r[0]}: {r[1]}")

print("\nSearching for IDs starting with 465:")
rows = cur.execute("SELECT id, name FROM raw_item_data WHERE id BETWEEN 4650 AND 4660").fetchall()
for r in rows:
    print(f"  {r[0]}: {r[1]}")

# Look for common Rogue equipment around this level
print("\nLet me check item 121564 (Chief Maeder's Leather Belt):")
row = cur.execute("SELECT id, name, ac, hp, mana, endur, attack, mr, fr, cr, pr, dr, itemtype, slots, classes FROM raw_item_data WHERE id = 121564").fetchone()
if row:
    print(f"  ID: {row[0]}")
    print(f"  Name: {row[1]}")
    print(f"  AC: {row[2]}, HP: {row[3]}, Mana: {row[4]}, Endur: {row[5]}, Attack: {row[6]}")
    print(f"  Resists - MR: {row[7]}, FR: {row[8]}, CR: {row[9]}, PR: {row[10]}, DR: {row[11]}")
    print(f"  Itemtype: {row[12]}, Slots: {row[13]}, Classes: {row[14]}")

conn.close()
