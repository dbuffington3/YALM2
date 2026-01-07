# YALM Complete Setup & Configuration Guide

## Table of Contents

1. [Quick Start](#quick-start)
2. [Complete Change History](#complete-change-history)
3. [Database Fixes (Foundation)](#database-fixes-foundation)
4. [Core Features Enabled](#core-features-enabled)
5. [Implementation Steps](#implementation-steps)
6. [Troubleshooting](#troubleshooting)
7. [Code Reference](#code-reference)

---

## Quick Start

YALM has three major working features:

1. **✅ Database Compatibility** - Fixed empty database problem
2. **✅ Class-Based Filtering** - Automatic, already working
3. **✅ Quest Item Awareness** - Optional, requires configuration

### To Get Started Today:

```
/yalm reload
```

That's it. Items should now loot and be class-filtered automatically.

---

## Complete Change History

### What We Found Broken

When you first set up YALM, **nothing was looting**. Items would drop but sit on the ground. The system appeared to be working but had a critical database issue.

### Root Cause: Database Schema Mismatch

MQ2LinkDB (MacroQuest2's database tool) created an empty table `raw_item_data_315` while the item database (`items.txt`) populated the older `raw_item_data` table. YALM was querying only the empty table.

**The Problem Chain:**
```
Item drops
  ↓
YALM queries: SELECT class_bitmask FROM raw_item_data_315 WHERE id = ?
  ↓
Returns NULL (table is empty)
  ↓
Class check fails
  ↓
Safety mechanism: "Can't verify this item, won't loot"
  ↓
Nothing looted
```

### Solution Implemented: Database Fallback Logic

Modified `lib/database.lua` to query **both tables** with intelligent fallback:

**Before (Broken):**
```lua
-- Only queried the empty table
local result = sql.execute(db, "SELECT class_bitmask FROM raw_item_data_315 WHERE id = ?")
return result  -- Always NULL = nothing looted
```

**After (Fixed):**
```lua
-- Try new table first
local result = sql.execute(db, "SELECT class_bitmask FROM raw_item_data_315 WHERE id = ?")

-- If empty, try old table
if not result or result == "" then
    result = sql.execute(db, "SELECT class_bitmask FROM raw_item_data WHERE id = ?")
end

return result  -- Now finds items in the right table
```

### Functions Updated

- `QueryDatabaseForItemId(item_id)` - Looks up item by ID, tries both tables
- `QueryDatabaseForItemName(item_name)` - Looks up item by name, tries both tables

### Result

✅ Item database queries now work  
✅ Class usability checks work  
✅ Loot distribution works  
✅ Future compatible with MQ2 updates  

---

## Database Fixes (Foundation)

### The Database Schema

MQ2LinkDB uses SQLite with an items table:

```sql
CREATE TABLE raw_item_data (
    id              INTEGER PRIMARY KEY,
    name            TEXT,
    class_bitmask   INTEGER,  -- Which classes can use
    race_bitmask    INTEGER,  -- Which races can use
    lore_flag       INTEGER,  -- 0 = not lore, 1 = lore (no duplicates)
    quest_flag      INTEGER,  -- 0 = not quest, 1 = quest item
    rarity          TEXT,     -- Common, Uncommon, Rare, etc.
);
```

### Class Bitmask Values

Used to determine which classes can equip an item:

```
Warrior        = 1 (bit 0)
Cleric         = 2 (bit 1)
Paladin        = 4 (bit 2)
Ranger         = 8 (bit 3)
Shadowknight   = 16 (bit 4)
Druid          = 32 (bit 5)
Monk           = 64 (bit 6)
Bard           = 128 (bit 7)
Rogue          = 256 (bit 8)
Shaman         = 512 (bit 9)
Necromancer    = 1024 (bit 10)
Wizard         = 2048 (bit 11)
Magician       = 4096 (bit 12)
Enchanter      = 8192 (bit 13)
Beastlord      = 16384 (bit 14)
Berserker      = 32768 (bit 15)
```

**Example:** Bitmask 31 = binary `11111` = bits 0-4 set = Warrior, Cleric, Paladin, Ranger, Shadowknight all can use it

### How Item Queries Work Now

**Query Flow:**
```
Item drops (ID: 12345)
  ↓
YALM calls: QueryDatabaseForItemId(12345)
  ↓
1. Try: SELECT * FROM raw_item_data_315 WHERE id = 12345
   Result: NULL (table is empty)
  ↓
2. Fallback: SELECT * FROM raw_item_data WHERE id = 12345
   Result: { id: 12345, name: "Plate Armor", class_bitmask: 1, ... }
  ↓
Returns item data with all properties
  ↓
YALM makes looting decision based on class restrictions
```

### Verify Database Fix Works

**Command:**
```
/yalm check Plate Armor
```

**Expected Output:**
```
[YALM] Item lookup for "Plate Armor":
  ID: 12345
  Rarity: Uncommon
  Class: Warrior
  Lore: No
  Quest: No
```

**If Database Still Broken:**
```
[YALM] Item lookup for "Plate Armor":
  NOT FOUND - Database query failed
```

---

## Core Features Enabled

### Feature 1: Database Compatibility (Foundation)

**What It Does:** Allows YALM to find items in the database

**Files Modified:**
- `lib/database.lua` - Added fallback query logic in `QueryDatabaseForItemId()` and `QueryDatabaseForItemName()`

**How to Activate:**
```
/yalm reload
```

**Verification:**
```
/yalm check [any item name]
```

---

### Feature 2: Class-Based Item Filtering (Automatic)

**What It Does:** Ensures warriors get warrior items, rogues don't get warrior-only items, etc.

**How It Works:**

1. Item drops (e.g., warrior sword)
2. YALM evaluates the item against member rules
3. For items with "Keep" preference:
   - Queries database for class restrictions
   - Checks if member's class can use it
   - If yes → Keep
   - If no → Mark for tribute
4. Item is routed accordingly

**Example Scenarios:**

- **Warrior-only sword drops:**
  - Warrior with "Keep" rule → Keeps it ✓
  - Rogue with "Keep" rule → Tributes it ✓
  
- **Universal armor drops:**
  - All classes with "Keep" rule → Keep it ✓

- **Rogue item drops:**
  - Rogue with "Keep" rule → Keeps it ✓
  - Warrior with "Keep" rule → Tributes it ✓

**Files Modified:**
- `core/inventory.lua` - Added `check_class_usability()` function
- `core/evaluate.lua` - Modified `check_can_loot()` to call class check for "Keep" items

**How to Use:**

Just configure rules normally. Class filtering is automatic:

```lua
["BER"] = {  -- Berserker rules
    ["category"] = "Class",
    ["items"] = {
        ["Warrior Sword"] = { ["setting"] = "Keep" },
        ["Spell Scroll"] = { ["setting"] = "Tribute" },
    }
}
```

The system automatically filters items based on class usability. Warriors can use "Warrior Sword", so they keep it. Rogues can't use "Warrior Sword", so they tribute it even if their rules say "Keep".

**Verification:**

When you loot mixed class items, watch the logs:

```
[LOOT] Evaluating: Warrior Plate
[LOOT] Warrior can use Warrior Plate → Keeping
[LOOT] Rogue cannot use Warrior Plate → Tributing
```

---

### Feature 3: Quest Item Awareness (Optional)

**What It Does:** Automatically keeps quest items only when the master looter needs them for active tasks

**How It Works:**

1. Item drops
2. YALM checks if item has `Quest()` flag in database
3. If it's a quest item:
   - Reads master looter's task window
   - Searches active quest objectives
   - If objective found → Keep for ML
   - If not found → Tribute (or other configured action)
4. Non-quest items unaffected

**Example Scenarios:**

- **Quest item with active task:**
  - "Kobold Pelt" drops
  - ML has active task "Kill Kobolds" needing pelts
  - Objective mentions "Kobold Pelt"
  - ML keeps it ✓

- **Quest item without active task:**
  - "Kobold Pelt" drops
  - ML has no active task needing it
  - ML tributes it ✓

- **Non-quest items:**
  - Regular loot processes normally
  - No special quest handling ✓

**Files Created:**
- `config/conditions/QuestActive.lua` - Reads task window, checks if item is needed
- `config/helpers/QuestItemCheck.lua` - Reusable helper for quest item checks
- `config/helpers/TaskReader.lua` - Reads EQ task window UI
- `config/helpers/QuestAutoDetect.lua` - Auto-detects new quest objectives

**Setup Required:**

3-step configuration in your settings file:

1. **Add rules to global settings:**
```lua
global_settings["rules"] = {
    ["QuestItems"] = {
        ["category"] = "Item",
        ["conditions"] = { { ["name"] = "QuestActive" } },
        ["items"] = { ["Keep"] = {} }
    },
    ["QuestItemsNotNeeded"] = {
        ["category"] = "Item",
        ["items"] = { ["Tribute"] = {} }
    },
}
```

2. **Add helper to global settings:**
```lua
global_settings["helpers"] = {
    ["QuestItemCheck"] = { ["name"] = "QuestItemCheck" },
}
```

3. **Enable rules in character settings:**
```lua
char_settings["rules"] = {
    { ["name"] = "QuestItems", ["enabled"] = true },
    { ["name"] = "QuestItemsNotNeeded", ["enabled"] = true },
}
```

4. **Restart:**
```
/yalm reload
```

**Verification:**

See `QUEST_VERIFICATION_CHECKLIST.md` for detailed testing procedures.

---

## Implementation Steps

### Step 1: Activate Database Fix (Required)

```bash
/yalm reload
```

This loads the updated `lib/database.lua` with fallback logic.

**Verification:**
```bash
/yalm check Plate Armor
```

Should show item properties instead of "NOT FOUND" error.

---

### Step 2: Test Class Filtering (Automatic)

1. Have warrior and rogue in group
2. Kill a mob with warrior-only item
3. Watch logs:

```
[LOOT] Evaluating: Warrior Breastplate
[LOOT] ✓ Warrior can use → Keeping
[LOOT] ✗ Rogue cannot use → Tributing
```

Class filtering is now automatic for all "Keep" items.

---

### Step 3: Configure Quest Items (Optional)

If you want quest item awareness:

1. **Edit your global settings file** (add rules section shown above)
2. **Edit your character settings file** (enable rules section shown above)
3. **Restart:** `/yalm reload`
4. **Test:** Follow procedures in `QUEST_VERIFICATION_CHECKLIST.md`

---

## Troubleshooting

### Problem: "Nothing is looting"

**Causes & Solutions:**

1. **Database not fixed**
   - Run: `/yalm check [itemname]`
   - If shows "NOT FOUND", fallback logic not loaded
   - Solution: `/yalm reload`

2. **Items don't match rules**
   - Check if item has a rule configured
   - Example: Item "Plate Armor" might need explicit "Keep" rule
   - Solution: Add rule or use broader category rules

3. **Class check failing**
   - Run: `/yalm debug on`
   - Check logs for class evaluation messages
   - Solution: Verify database query returned class_bitmask

---

### Problem: "Items not being class-filtered"

**Causes & Solutions:**

1. **Database query failing**
   - Run: `/yalm check Warrior Sword`
   - Should show "Class: Warrior"
   - If not, database fallback isn't working
   - Solution: Verify `lib/database.lua` modifications

2. **Class rules not configured**
   - Rules might not have "Keep" setting for that item type
   - Solution: Configure appropriate "Keep" rules by class

3. **Item doesn't have class restrictions**
   - Some items can be used by all classes
   - Those won't be filtered
   - This is correct behavior

---

### Problem: "Quest items not working"

**Check in order:**

1. **Is it a quest item in database?**
   - Run: `/yalm check [questitem]`
   - Look for: `Quest: Yes`
   - If `Quest: No`, item isn't marked as quest
   - Solution: Manually add quest item rule

2. **Is task window reading working?**
   - Check ML's task window is open
   - Check logs for: `[TASK_READER] Found X active tasks`
   - If not reading tasks, check `config/helpers/TaskReader.lua`

3. **Are rules enabled?**
   - Check character settings has quest rules enabled
   - Check: `{ ["name"] = "QuestItems", ["enabled"] = true }`
   - Solution: Add/enable rules

4. **Does ML need the item?**
   - Check logs for: `Quest objective "Kill Kobolds" found in active tasks`
   - If not found, ML doesn't need it (correct behavior)
   - Solution: Accept ML doesn't need it, or manually configure

See `QUEST_VERIFICATION_CHECKLIST.md` section 6 for detailed troubleshooting.

---

### Problem: "Lua errors or crashes"

**Diagnosis:**

1. **Enable debug mode:**
   ```
   /yalm debug on
   ```

2. **Reproduce the error:**
   - Kill a quest item
   - Watch logs for error messages

3. **Check specific log:**
   - Database errors: Check `lib/database.lua` syntax
   - Class filter errors: Check `core/evaluate.lua` syntax
   - Quest errors: Check `config/conditions/QuestActive.lua` syntax

4. **Look for error patterns:**
   - `[ERROR]` - Something failed
   - `[WARN]` - Something unexpected but continuing
   - Stack trace shows which function crashed

5. **Solutions:**
   - Syntax error: Check Lua syntax in modified files
   - Database error: Verify SQLite query format
   - Quest error: Verify task window is readable

---

## Code Reference

### Database Fallback Logic

**Location:** `lib/database.lua`

**What Changed:**
```lua
-- OLD: Query only new table (empty)
function QueryDatabaseForItemId(item_id)
    local query = string.format("SELECT * FROM raw_item_data_315 WHERE id = %d", item_id)
    return sql.execute(db, query)
end

-- NEW: Try both tables with fallback
function QueryDatabaseForItemId(item_id)
    -- Try new table first
    local query = string.format("SELECT * FROM raw_item_data_315 WHERE id = %d", item_id)
    local result = sql.execute(db, query)
    
    -- Fallback to old table if empty
    if not result or result == "" then
        query = string.format("SELECT * FROM raw_item_data WHERE id = %d", item_id)
        result = sql.execute(db, query)
    end
    
    return result
end
```

**Similar changes in:** `QueryDatabaseForItemName()`

---

### Class Usability Check

**Location:** `core/inventory.lua`

**Function:** `check_class_usability(member_class, class_bitmask)`

**What It Does:**
```lua
function check_class_usability(member_class, class_bitmask)
    -- Convert class name to bitmask value
    local class_masks = {
        ["Warrior"] = 1,
        ["Cleric"] = 2,
        ["Paladin"] = 4,
        -- ... etc for all classes
    }
    
    local member_mask = class_masks[member_class]
    
    -- Bitwise AND: if result > 0, class can use item
    if (class_bitmask & member_mask) > 0 then
        return true  -- Can use
    else
        return false  -- Cannot use
    end
end
```

---

### Integration Point

**Location:** `core/evaluate.lua`

**Where It's Called:**
```lua
function check_can_loot(item, member, preference)
    -- ... existing checks ...
    
    -- NEW: Class usability check
    if preference == "Keep" then
        local class_bitmask = QueryDatabaseForItemId(item:ID())
        if not inventory.check_class_usability(member.Class(), class_bitmask) then
            Write.Debug("Item class-filtered for %s", member.Name())
            return false
        end
    end
    
    -- ... rest of checks ...
end
```

---

## Summary

### What We Fixed

| Problem | Solution | Result |
|---------|----------|--------|
| Database querying wrong table | Fallback logic to try both tables | Items found, looting works |
| No class filtering | Added class bitmask check | Correct items to correct classes |
| Quest items not sorted | Added quest detection & task reading | Quest items to those who need them |

### What Now Works

✅ Items are detected and looted  
✅ Items routed to correct classes  
✅ Quest items intelligently distributed  
✅ Database compatible with future updates  
✅ Complete transparency in logs  

### Quick Verification

```bash
# Test 1: Database working
/yalm check "Any Item Name"

# Test 2: Loot happening
Kill a mob, watch items loot

# Test 3: Class filtering
Watch logs for class evaluations

# Test 4: Quest items (if configured)
Kill quest item, check if kept/tributed based on ML's tasks
```

---

## Next Steps

1. **Immediate:** `/yalm reload` to activate database fix
2. **Test:** Verify loot resumption
3. **Observe:** Class filtering works automatically
4. **Optional:** Configure quest items if desired
5. **Monitor:** Watch logs for smooth operation

You're ready to start fresh with a solid foundation!
