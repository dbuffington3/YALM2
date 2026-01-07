#!/usr/bin/env python3

import sqlite3
import os

db_path = r'C:\MQ2\lua\yalm2\MQ2LinkDB.db'

if not os.path.exists(db_path):
    print(f"Database not found at {db_path}")
    exit(1)

conn = sqlite3.connect(db_path)
conn.row_factory = sqlite3.Row
cur = conn.cursor()

# Query both items
query = '''
SELECT id, name, ac, hp, mana, endur, attack, mr, fr, cr, pr, dr, itemtype, slots, classes 
FROM raw_item_data 
WHERE id IN (121564, 4654)
ORDER BY id
'''

cur.execute(query)
rows = cur.fetchall()

if len(rows) < 2:
    print("One or both items not found in database")
    exit(1)

item2 = dict(rows[0])  # 4654
item1 = dict(rows[1])  # 121564

print(f"Item 121564: {item1['name']}")
print(f"Item 4654: {item2['name']}")
print()

# Check if comparable
print("COMPARABILITY CHECK:")
print(f"  Itemtype: {item1['itemtype']} vs {item2['itemtype']}")
if item1['itemtype'] != item2['itemtype']:
    print("  ✗ NOT COMPARABLE - Different itemtypes!")
    exit(0)

slots_overlap = item1['slots'] & item2['slots']
print(f"  Slots: {item1['slots']} vs {item2['slots']} (overlap: {slots_overlap})")
if slots_overlap == 0:
    print("  ✗ NOT COMPARABLE - No slot overlap!")
    exit(0)

print("  ✓ Items ARE comparable")
print()

# Rogue weights
rogue_weights = {'ac': 1.5, 'hp': 1.5, 'mana': 0, 'endurance': 2, 'resists': 0.5, 'attack': 2}

print("STAT COMPARISON (121564 → 4654):")
print("=" * 60)

ac_delta = item1['ac'] - item2['ac']
hp_delta = item1['hp'] - item2['hp']
mana_delta = item1['mana'] - item2['mana']
endur_delta = item1['endur'] - item2['endur']
attack_delta = item1['attack'] - item2['attack']
resist_avg_delta = ((item1['mr'] - item2['mr']) + (item1['fr'] - item2['fr']) + (item1['cr'] - item2['cr']) + (item1['pr'] - item2['pr']) + (item1['dr'] - item2['dr'])) / 5

print(f"AC:        {item2['ac']:4d} → {item1['ac']:4d}   (delta: {ac_delta:+3d})")
print(f"HP:        {item2['hp']:4d} → {item1['hp']:4d}   (delta: {hp_delta:+3d})")
print(f"Mana:      {item2['mana']:4d} → {item1['mana']:4d}   (delta: {mana_delta:+3d}, weight=0 → ignored)")
print(f"Endurance: {item2['endur']:4d} → {item1['endur']:4d}   (delta: {endur_delta:+3d})")
print(f"Attack:    {item2['attack']:4d} → {item1['attack']:4d}   (delta: {attack_delta:+3d})")
print(f"Avg Resist:{(item2['mr'] + item2['fr'] + item2['cr'] + item2['pr'] + item2['dr'])/5:+4.1f} → {(item1['mr'] + item1['fr'] + item1['cr'] + item1['pr'] + item1['dr'])/5:+4.1f} (delta: {resist_avg_delta:+.1f})")
print()

print("WEIGHTED SCORE CALCULATION (Rogue weights):")
print("=" * 60)

ac_score = ac_delta * rogue_weights['ac']
hp_score = hp_delta * rogue_weights['hp']
mana_score = mana_delta * rogue_weights['mana']
endur_score = endur_delta * rogue_weights['endurance']
attack_score = attack_delta * rogue_weights['attack']
resist_score = resist_avg_delta * rogue_weights['resists']

print(f"AC:        {ac_delta:+3d} × 1.5 = {ac_score:+7.1f}")
print(f"HP:        {hp_delta:+3d} × 1.5 = {hp_score:+7.1f}")
print(f"Mana:      {mana_delta:+3d} × 0.0 = {mana_score:+7.1f}  (Rogue doesn't value mana)")
print(f"Endurance: {endur_delta:+3d} × 2.0 = {endur_score:+7.1f}")
print(f"Attack:    {attack_delta:+3d} × 2.0 = {attack_score:+7.1f}")
print(f"Resists:   {resist_avg_delta:+.1f} × 0.5 = {resist_score:+7.1f}")
print("-" * 60)

total_score = ac_score + hp_score + mana_score + endur_score + attack_score + resist_score
print(f"TOTAL SCORE DELTA: {total_score:+.1f}")
print()

if total_score > 0:
    print("✓ Item 121564 IS an upgrade over 4654")
elif total_score < 0:
    print("✗ Item 121564 is NOT an upgrade over 4654")
else:
    print("= Items are equivalent")

conn.close()
