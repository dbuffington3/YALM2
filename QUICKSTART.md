# Quick Start Guide - Equipment Upgrade Detection

## Installation (5 minutes)

### Step 1: Ensure Database Exists
Your MQ2 installation should have:
```
<MQ2_ROOT>/
├── lua/
│   └── yalm2/           ← You already have this
└── resources/
    └── MQ2LinkDB.db     ← Database goes here
```

**The database will be auto-detected. Just place it in the resources folder.**

### Step 2: Run the Script
In EverQuest with MQ2 running:
```
/lua run check_upgrades.lua
```

### Step 3: Review Results
The script will:
1. Scan your entire inventory
2. Analyze all equipped items
3. Find and display upgrade suggestions
4. Show stat improvements for each upgrade

## Example Output

```
[CHECK UPGRADES] for Vexxuss (Level 97 Shadow Knight)
=================================================

✓ Slot 11:
  Current: Bow of the Warder
  Upgrade: Candied Brain
  Mana: +223
  Endurance: +194
  Magic Resist: +2
  Fire Resist: +1
  Clairvoyance: +7
  Cold Resist: +5
  Heal Amt: +9
  Poison Resist: +9
  Mana Regen: +3
  Disease Resist: -3
  Attack: -6
  HP Regen: +5
  AC: +12
  HP: +153
  Score Improvement: +758.0

✓ Found 4 upgrade(s)
```

## How It Works

### Automatic Path Detection
The script automatically finds your database:
1. Looks in `<MQ2_ROOT>/resources/MQ2LinkDB.db`
2. Falls back to `<MQ2_ROOT>/config/MQ2LinkDB.db`
3. Uses MQ2's default resources path as last resort

**No configuration needed!**

### Equipment Analysis
- Scans all inventory items (typically 200+)
- Compares against your 13 equipped slots
- Respects your character class restrictions
- Checks level requirements
- Validates slot compatibility
- Calculates stat improvements

### Character Support
Works with all EQ classes:
- Shadowknight, Warrior, Paladin (tanks)
- Ranger, Rogue, Monk, Berserker (DPS)
- Bard (hybrid)
- Cleric, Druid, Shaman (healer/casters)
- Wizard, Enchanter, Necromancer, Magician (pure casters)

## Troubleshooting

### "Database file does not exist"
**Solution:** Place `MQ2LinkDB.db` in your `<MQ2_ROOT>/resources/` directory

### Database is empty/not found
**Create it:**
```bash
python import_lucy.py
```

### Wrong path detected
**Manual override** (edit check_upgrades.lua line 16):
```lua
-- Uncomment and set your path:
-- db.database = db.OpenDatabase("D:\\YourPath\\MQ2LinkDB.db")
```

### No upgrades found
- Ensure database is populated (150+ MB)
- Check inventory has items matching your class
- Verify equipped items have valid slots in database

## Files

- **check_upgrades.lua** - Main script (run this!)
- **lib/database.lua** - Database connection
- **import_lucy.py** - Create database from Lucy data
- **DATABASE_SETUP.md** - Detailed setup guide
- **SMART_PATH_DETECTION.md** - Technical details

## What Gets Compared

### Stat Weights by Class

**Shadowknight (Tank):**
- AC: 3x weight
- HP: 2x weight
- Endurance: 1.5x weight
- Resists: 1x weight

**Wizard (Caster):**
- Mana: 3x weight
- AC: 1x weight
- Resists: 1.5x weight
- Mana Regen: 2x weight

(Each class has optimized weights)

### All Stats Compared
- AC (Armor Class)
- HP (Hit Points)
- Mana
- Endurance
- Attack
- Healing Amount
- Mana/HP Regen
- All 5 resists (Magic, Fire, Cold, Poison, Disease)
- Clairvoyance

## Next Steps

1. **Place database** in `<MQ2_ROOT>/resources/`
2. **Run the script**: `/lua run check_upgrades.lua`
3. **Review suggestions** in your log
4. **Equip upgrades** and repeat periodically

## Still Need Help?

See detailed documentation:
- `DATABASE_SETUP.md` - Comprehensive setup guide
- `SMART_PATH_DETECTION.md` - How path detection works
- `IMPLEMENTATION_COMPLETE.md` - Full technical details

All files are in your `<MQ2_ROOT>/lua/yalm2/` directory.
