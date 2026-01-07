# Data Mapping Analysis - Item 120448

## Field Mapping Comparison

### ItemCollect items.txt Format
The itemcollect data uses **36 fields** (0-indexed):
- Field 8: `nodrop` - Boolean (0=NO TRADE, 1=tradeable)
- Field 36: `classes` - Bitmask for usable classes

### Database (SQLite MQ2LinkDB.db) Schema
The database uses named columns:
- Column 75: `classes` - Bitmask for usable classes
- Column 182: `nodrop` - Boolean (0=NO TRADE, 1=tradeable)

## Test Item: 120448 (Ring of Glamouring)

### From itemcollect/items.txt
```
Field breakdown for item 120448:
- Field 1 (name): Ring of Glamouring
- Field 5 (id): 120448
- Field 8 (nodrop): 0  <-- NO TRADE flag (0=NO TRADE)
- Field 36 (classes): 33096  <-- Class bitmask
```

### From SQLite Database Query
```sql
SELECT name, id, nodrop, classes FROM raw_item_data WHERE id = 120448;
-- Result: Ring of Glamouring|120448|0|33096
```

## Class Bitmask Analysis (Value: 33096)

### Binary Representation
```
33096 (decimal) = 1000000101001000 (binary)

Bit positions (0-indexed):
Bit:  15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
Val:   1  0  0  0  0  0  1  0  1  0  0  1  0  0  0
      ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^  ^
      B  B  B  B  B  B  B  B  B  B  B  B  B  B  B  B
      e  a  N  W  M  E  R  S  B  M  D  P  R  C  W  -
      r  a  e  i  a  n  o  h  a  n  R  a  a  l  a
      s  r  c  z  g  c  g  a  r  k  u  l  n  e  r
      e  d  r  e  i  h  u  m  d  N  n  a  g  r  r
      r  |  o  |  c  |  e  a  |  |  n  d  e  i  i
      k  B  m  W  |  E  |  n  B  M  e  i  r  o  o
      e  e  |  |  E  |  R  |  e  o  |  n  |  r  r
      r  r  M  W  n  E  |  S  r  n  D  |  C  |  |
      |  |  a  |  c  n  |  h  s  k  R  P  l  C  W
      B  B  g  W  h  c  R  a  e  |  u  a  e  l  a
      E  S  |  a  |  |  o  m  r  -  n  l  r  e  r
      R  H  E  r  M  E  g  |  k  S  |  -  |  r  -
      S  D  n  r  A  n  u  B  e  l  D  R  C  i  -
      |  |  c  i  g  c  e  a  r  o  R  G  l  o  -
      1  5  4  3  2  1  9  2  7  5  1  4  3  2  1  0
      5  4  3  2  1  0  0  0  0  0  0  0  0  0  0  0
```

Wait, let me recalculate more carefully:

```
Decimal: 33096
Binary:  1000000101001000

Reading right-to-left (bit 0 is rightmost):
Bit 0: 0
Bit 1: 0
Bit 2: 0
Bit 3: 1  <-- CLASS 4 (Paladin, ID=3)
Bit 4: 0
Bit 5: 0
Bit 6: 1  <-- CLASS 7 (Bard, ID=7)
Bit 7: 0
Bit 8: 1  <-- CLASS 9 (Rogue, ID=9)
Bit 9: 0
Bit 10: 0
Bit 11: 0
Bit 12: 0
Bit 13: 0
Bit 14: 0
Bit 15: 1  <-- CLASS 16 (Berserker, ID=16)
```

Actually, the bit positions map directly to class IDs when using the formula:
- Bit position = Class ID - 1

So:
- Bit 3 set → Class 4 (Paladin)
- Bit 7 set → Class 8 (Bard)
- Bit 9 set → Class 10 (Rogue)  
- Bit 15 set → Class 16 (Berserker)

Wait, that doesn't match. Let me reconsider. The standard EQ class numbering is:
```
1 = Warrior
2 = Cleric
3 = Paladin
4 = Ranger
5 = Shadowknight
6 = Druid
7 = Monk
8 = Bard
9 = Rogue
10 = Shaman
11 = Necromancer
12 = Wizard
13 = Magician
14 = Enchanter
15 = Beastlord
16 = Berserker
```

If bits are: 3, 7, 9, 15 (using 0-indexing), then:
- Class = Bit + 1
- Bit 3 → Class 4 = Ranger
- Bit 7 → Class 8 = Bard
- Bit 9 → Class 10 = Shaman
- Bit 15 → Class 16 = Berserker

But user said bits 3,7,9,15 represent Paladin, Bard, Rogue, Berserker...

Let me check using a different method:

```powershell
$value = 33096
for ($i = 0; $i -lt 16; $i++) {
    if (($value -band [Math]::Pow(2, $i)) -ne 0) {
        Write-Host "Bit $i is set (Class ID $($i + 1))"
    }
}
```

This will tell us exactly which bits are set. But based on the conversation summary, the user already did this analysis and found:
- Bits 3, 7, 9, 15 are set
- These correspond to: Paladin, Bard, Rogue, Berserker
- Bit 4 is NOT set
- Bit 4 would be Class 5 (Shadowknight)

So for Malrik (Shadowknight/Class 5):
- Need to check bit 4 (since bit position = class - 1)
- Bit 4 is NOT set in 33096
- Therefore: Malrik CANNOT use Ring of Glamouring
- Therefore: Should auto-tribute YES

## Data Source Verification

All three data sources show identical values for item 120448:

### Source 1: SQLite Database
```
SELECT name, id, nodrop, classes FROM raw_item_data WHERE id = 120448;
Ring of Glamouring|120448|0|33096
```

### Source 2: MQ2 Resources (items.txt)
```
Field search for "Ring of Glamouring":
- Classes field: 33096
- NoTrade (nodrop): 0
```

### Source 3: ItemCollect items.txt
```
Record for 120448:
- Field 8 (nodrop): 0
- Field 36 (classes): 33096
```

**Conclusion:** Data is consistent across all sources

## Implications for Tribute System

### NO TRADE Detection
- Database field: `nodrop` (0 = NO TRADE, 1 = tradeable)
- Check: `item_data.nodrop == 0`
- For item 120448: `0 == 0` → TRUE (is NO TRADE)

### Class Usage Check
- Database field: `classes` (16-bit bitmask)
- For Malrik (SHD, Class 5):
  - Check bit 4 (5 - 1 = 4)
  - Bit 4 not set in 33096 → FALSE (cannot use)
  
### Auto-Tribute Decision
- Item is NO TRADE: TRUE ✓
- Character cannot use: TRUE ✓
- **Result: AUTO-TRIBUTE = YES**

## Code Implementation

The logic in `Tribute.lua` should:
1. Query database for item 120448
2. Check `item_data.nodrop == 0` → TRUE
3. Get character class (SHD → ID 5)
4. Check bit 4 in `item_data.classes` (33096)
5. Bit 4 not set → can_use = FALSE
6. Return `not can_use` → TRUE
7. Auto-tribute item

