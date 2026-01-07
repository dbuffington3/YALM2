# Complete Class Bitmask Mapping Fix - Full Scrub

## Issue Found
The class bitmask mappings throughout the yalm2 codebase were INCORRECT. The database uses 0-indexed bit positions, but the code was either:
1. Using 1-indexed bit positions (Warrior=1, Cleric=2, ... Rogue=9, Shaman=10, etc.)
2. Using incorrect mappings after the Bard class

## Correct Mapping (0-indexed bit positions)
```
Bit 0  = 2^0  = 1      = Warrior
Bit 1  = 2^1  = 2      = Cleric
Bit 2  = 2^2  = 4      = Paladin
Bit 3  = 2^3  = 8      = Ranger
Bit 4  = 2^4  = 16     = Shadowknight
Bit 5  = 2^5  = 32     = Druid
Bit 6  = 2^6  = 64     = Monk
Bit 7  = 2^7  = 128    = Bard
Bit 8  = 2^8  = 256    = Rogue
Bit 9  = 2^9  = 512    = Shaman
Bit 10 = 2^10 = 1024   = Necromancer
Bit 11 = 2^11 = 2048   = Wizard
Bit 12 = 2^12 = 4096   = Magician
Bit 13 = 2^13 = 8192   = Enchanter
Bit 14 = 2^14 = 16384  = Beastlord
Bit 15 = 2^15 = 32768  = Berserker
```

## Verification Examples
- Item 256 = classes value for Rogue-only items ✓ (2^8)
- Item 512 = classes value for Shaman-only items ✓ (2^9)
- Item 133911 (Reinforced Bear Hide Bracer) = classes 16480 = 64+32+16384 = Monk+Druid+Beastlord ✓
- Item 133919 (Ellithia's Hot Handwraps) = classes 15360 = 1024+2048+4096+8192 = Necromancer+Wizard+Magician+Enchanter ✓

## Files Fixed

### 1. `check_cross_character_upgrades.lua`
**Problem:** Two functions had bad mappings
- `can_equip_item_for_class()` - lines 231-248
- `can_remote_character_equip()` - lines 327-344

**Old Mapping:**
```
['Rogue'] = 6,  -- WRONG (was using Monk slot)
['Shaman'] = 8,  -- WRONG (should be 9)
['Necromancer'] = 9,  -- WRONG (should be 10)
['Wizard'] = 10,  -- WRONG (should be 11)
['Magician'] = 11,  -- WRONG (should be 12)
['Enchanter'] = 12,  -- WRONG (should be 13)
['Beastlord'] = 14,  -- WRONG (should be 14 - but docstring said bit 13)
['Berserker'] = 15,  -- WRONG (should be 15 - but docstring said bit 14)
```

**New Mapping:**
```
['Rogue'] = 8,
['Shaman'] = 9,
['Necromancer'] = 10,
['Wizard'] = 11,
['Magician'] = 12,
['Enchanter'] = 13,
['Beastlord'] = 14,
['Berserker'] = 15,
```

### 2. `check_upgrades.lua`
**Problem:** `can_equip_item()` function (lines 502-577) was using 1-indexed class indices with formula `bit.lshift(1, class_index - 1)`

**Old Code:**
```lua
local class_map = {
    ['Warrior'] = 1,
    ['Cleric'] = 2,
    ...
    ['Rogue'] = 9,
    ['Shaman'] = 10,
    ['Necromancer'] = 11,
    ['Wizard'] = 12,
    ['Magician'] = 13,
    ['Enchanter'] = 14,
    ['Beastlord'] = 15,
    ['Berserker'] = 16,
}
local class_bit = bit.lshift(1, class_index - 1)
```

**New Code:**
```lua
local class_bit_positions = {
    ['Warrior'] = 0,
    ['Cleric'] = 1,
    ...
    ['Rogue'] = 8,
    ['Shaman'] = 9,
    ['Necromancer'] = 10,
    ['Wizard'] = 11,
    ['Magician'] = 12,
    ['Enchanter'] = 13,
    ['Beastlord'] = 14,
    ['Berserker'] = 15,
}
local can_equip = bit.band(item_data.classes, bit.lshift(1, class_bit))
```

### 3. `CLASS_BITMASK_MAPPING_FIX.md`
**Problem:** Documentation had outdated code example with bad mapping

**Fixed:** Updated the example code to use correct 0-indexed mapping

### 4. `YALM_COMPLETE_SETUP_GUIDE.md`
**Problem:** Documentation listed incorrect bit positions
- Said Enchanter = 4096 (bit 12) but should note Magician exists first
- Said Beastlord = 8192 (bit 13) but should be 16384 (bit 14)
- Said Berserker = 16384 (bit 14) but should be 32768 (bit 15)
- Missing Magician in the list

**Fixed:** Updated to show correct mapping with Magician included

## Impact
These fixes ensure that:
1. ✓ Item 133919 (Enchanter/Wizard/Magician/Necromancer only) is NO LONGER recommended for Beastlord
2. ✓ Items usable by Beastlord/Berserker are correctly validated
3. ✓ All 16 classes now have proper bitmask validation
4. ✓ Cross-character upgrade checking uses correct class validation
5. ✓ Local upgrade checking uses correct class validation

## Testing Verification
Verified with database queries:
- Item 256 (Rogue classes) confirmed as Bit 8 class
- Item 512 (Shaman classes) confirmed as Bit 9 class
- Item 133911 (16480) correctly decoded as Monk(6) + Druid(5) + Beastlord(14)
- Item 133919 (15360) correctly decoded as Nec(10) + Wiz(11) + Mag(12) + Enc(13)
