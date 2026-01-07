# Tribute NO TRADE Enhancement

## Overview
Enhanced the tribute system to automatically tribute items that are:
1. **NO TRADE** - Cannot be traded to other players
2. **Character cannot use** - Class/race restricted for current character

This happens automatically during tribute runs without needing to set preferences in global/character config files.

## How It Works

### New Functions

#### `can_character_use_item(item)`
- Checks if the current character can use an item based on class restrictions
- Uses the database class bitmask for the item
- Maps EQ class IDs (1-16) to bit positions
- Compares against current character's class
- Returns `true` if character CAN use it, `false` if cannot

**Supports all 16 classes:**
- Warriors, Clerics, Paladins, Rangers, Shadowknights, Druids, Monks, Bards
- Rogues, Shamans, Necromancers, Wizards, Magicians, Enchanters, Beastlords, Berserkers

#### `should_tribute_item(item, global_settings, char_settings)`
- Determines if an item should be auto-tributed
- Checks:
  1. Is item NO TRADE? (if tradeable, skip)
  2. Is item in saved slot? (if saved, skip)
  3. Can character use it? (if yes, skip)
- Returns `true` if item should be tributed (NO TRADE + cannot use)

### Updated Function

#### `donate_item(item, global_settings, char_settings)`
- Now checks BOTH:
  1. Traditional Tribute preference (from settings)
  2. New NO TRADE + class restriction check
- If either condition is true, item gets tributed
- Logs when auto-tributing NO TRADE restricted items

## Data Sources

### From MQ2 TLO (Real-time)
- `item.NoTrade()` - Checks NO TRADE flag directly from item
- `item.Name()` - Item name for logging
- `item.ItemSlot()`, `item.ItemSlot2()` - Inventory location
- `mq.TLO.Me.Class()` - Current character's class

### From Database (YALM2_Database)
- `item.classes` - Class bitmask (used to determine restrictions)
- Only queried if item is NO TRADE and not in saved slot

## Benefits

1. **No Configuration Needed** - Works out of the box
2. **Per-Run Basis** - Only affects this tribute run, no permanent settings changes
3. **Respects Saved Items** - Won't tribute items you've marked as saved
4. **Class-Aware** - Uses actual item class restrictions, not just database flags
5. **Database-Light** - Only queries database for NO TRADE items

## Example Scenarios

| Item | NO TRADE | Class OK? | Result |
|------|----------|-----------|--------|
| Silk Gloves | No | Yes | Don't tribute |
| Leather Armor | Yes | Yes | Don't tribute (can use) |
| Wizard Robe | Yes | No | **Tribute it** ✓ |
| Plate Armor | Yes | No | **Tribute it** ✓ |
| Quest Item (saved) | Yes | No | Don't tribute (saved) |

## Usage

Use the normal tribute command:
```
/yalm2 tribute guild
/yalm2 tribute me
```

Items will be tributed if they match either:
1. The Tribute preference setting (if configured)
2. NO TRADE + character cannot use

## Technical Details

### Class Bitmask Format
Items in the database have a `classes` field with a bitmask:
- Bit 0 = Warrior (class ID 1)
- Bit 1 = Cleric (class ID 2)
- Bit 2 = Paladin (class ID 3)
- ... and so on through Berserker (class ID 16)

The check uses bitwise AND to determine if current class bit is set.

### Fallback Logic
If database lookup fails for an item:
- If item not in database → assume usable (don't tribute)
- If class bitmask is 0 → assume no restrictions (don't tribute)
- If current class unknown → assume usable (don't tribute)

This safe-fallback approach prevents accidental loss of items.

## Future Enhancements

Possible additions:
- [ ] Race restriction checking (if added to database)
- [ ] Configuration option to disable auto-tribute of NO TRADE items
- [ ] Logging which items were auto-tributed for review
- [ ] Database update checks for outdated class restrictions
