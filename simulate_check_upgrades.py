#!/usr/bin/env python3
"""Simulate what check_upgrades.lua should do for a Rogue"""

import sqlite3

DB_PATH = r'C:\MQ2\lua\yalm2\MQ2LinkDB.db'

def get_item_stats(cur, item_id):
    """Query database for item stats"""
    if not item_id:
        return None
    
    cur.execute('SELECT * FROM raw_item_data WHERE id = ?', (item_id,))
    row = cur.fetchone()
    if not row:
        return None
    
    # Convert to dict with column names
    columns = [desc[0] for desc in cur.description]
    data = dict(zip(columns, row))
    
    # Convert to numbers
    stats = {
        'ac': int(data.get('ac', 0) or 0) if data.get('ac') else 0,
        'hp': int(data.get('hp', 0) or 0) if data.get('hp') else 0,
        'mana': int(data.get('mana', 0) or 0) if data.get('mana') else 0,
        'endurance': int(data.get('endur', 0) or 0) if data.get('endur') else 0,
        'itemtype': int(data.get('itemtype', 0) or 0) if data.get('itemtype') else 0,
        'slots': int(data.get('slots', 0) or 0) if data.get('slots') else 0,
        'classes': int(data.get('classes', 0) or 0) if data.get('classes') else 0,
        'reqlevel': int(data.get('reqlevel', 0) or 0) if data.get('reqlevel') else 0,
    }
    return stats

def can_equip_item(cur, item_id, char_level, char_class):
    """Check if character can equip item"""
    stats = get_item_stats(cur, item_id)
    if not stats:
        return False
    
    # Check level
    if stats['reqlevel'] > char_level:
        print(f"  ❌ Too high level (req {stats['reqlevel']}, char level {char_level})")
        return False
    
    # Check classes
    if stats['classes'] and stats['classes'] > 0:
        # Map class to bit
        class_map = {
            'Warrior': 1, 'Cleric': 2, 'Paladin': 3, 'Ranger': 4,
            'Shadowknight': 5, 'Druid': 6, 'Monk': 7, 'Bard': 8,
            'Rogue': 9, 'Shaman': 10, 'Necromancer': 11, 'Wizard': 12,
            'Magician': 13, 'Enchanter': 14, 'Beastlord': 15, 'Berserker': 16,
        }
        
        class_index = class_map.get(char_class)
        if not class_index:
            print(f"  ❌ Unknown class '{char_class}'")
            return False
        
        # Check if class bit is set
        class_bit = 1 << (class_index - 1)
        if (stats['classes'] & class_bit) == 0:
            print(f"  ❌ Rogue bit not set in classes bitmask {stats['classes']}")
            return False
    
    return True

def are_items_comparable(stats1, stats2):
    """Check if items are comparable"""
    if not stats1 or not stats2:
        return False
    
    # Check slots overlap
    slot_overlap = stats1['slots'] & stats2['slots']
    if slot_overlap == 0:
        print(f"    ❌ No slot overlap ({stats1['slots']} & {stats2['slots']} = 0)")
        return False
    
    # Check itemtype match
    if stats1['itemtype'] != stats2['itemtype']:
        print(f"    ❌ ItemType mismatch ({stats1['itemtype']} vs {stats2['itemtype']})")
        return False
    
    return True

def simulate_rogue_check():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    
    print("=== Simulating Check Upgrades for Rogue ===\n")
    
    # Test case: Currently wearing 121171, check if 121564 is an upgrade
    print("Current scenario: Rogue wearing item 121171")
    equipped_id = 121171
    inventory_id = 121564
    char_class = 'Rogue'
    char_level = 90
    
    equipped_stats = get_item_stats(cur, equipped_id)
    if not equipped_stats:
        print(f"❌ Item {equipped_id} not found\n")
        return
    
    print(f"  Item {equipped_id}: AC={equipped_stats['ac']}\n")
    
    print(f"Checking inventory item {inventory_id}...")
    
    # Step 1: Can equip?
    print("  Step 1: Can equip?")
    if not can_equip_item(cur, inventory_id, char_level, char_class):
        print(f"  ❌ Cannot equip item {inventory_id}")
        return
    print("  ✓ Can equip")
    
    # Step 2: Get stats
    inv_stats = get_item_stats(cur, inventory_id)
    if not inv_stats:
        print(f"  ❌ Item {inventory_id} not found")
        return
    print(f"  ✓ Got stats: AC={inv_stats['ac']}")
    
    # Step 3: Are they comparable?
    print("  Step 3: Are items comparable?")
    if not are_items_comparable(equipped_stats, inv_stats):
        print(f"  ❌ Items not comparable")
        return
    print("  ✓ Items are comparable")
    
    # Step 4: Compare AC
    ac_delta = inv_stats['ac'] - equipped_stats['ac']
    print(f"\n  Step 4: Score calculation")
    print(f"    AC delta: {ac_delta} ({inv_stats['ac']} - {equipped_stats['ac']})")
    
    if ac_delta > 0:
        print(f"    ✓ Item {inventory_id} has BETTER AC (upgrade!)")
    elif ac_delta < 0:
        print(f"    ❌ Item {inventory_id} has WORSE AC (downgrade)")
    else:
        print(f"    = Same AC")
    
    print()

if __name__ == '__main__':
    simulate_rogue_check()
