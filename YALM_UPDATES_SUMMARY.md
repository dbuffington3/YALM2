# YALM Recent Updates - Complete Summary

## Overview

Your YALM loot distribution system has been updated with three major improvements:

1. ✅ **Database Compatibility Fix** - Queries now work with both old and new item database schemas
2. ✅ **Class-Based Item Filtering** - Warriors get warrior items, rogues don't get warrior items (sent to tribute instead)
3. ✅ **Quest Item Awareness** - Quest items are intelligently distributed based on master looter's active tasks

---

## What Changed

### 1. Database Compatibility (Already Fixed)

**Problem:** Nothing was being looted because class usability checks were failing

**Root Cause:** MQ2LinkDB created database with table named `raw_item_data_315`, but `items.txt` populated the older `raw_item_data` table instead

**Solution Implemented:** Updated `lib/database.lua` to query both tables with fallback logic
- Tries `raw_item_data_315` first (for future compatibility)
- Falls back to `raw_item_data` if item not found (current data location)
- Both `QueryDatabaseForItemId()` and `QueryDatabaseForItemName()` functions updated

**Files Modified:**
- `lib/database.lua` - Added fallback query logic

**Status:** ✅ COMPLETE - Restart YALM to activate

---

### 2. Class-Based Item Filtering (Already Implemented)

**Feature:** Items are now checked for class usability before looting

**How It Works:**
1. When evaluating an item with "Keep" preference
2. System queries database for item's class restrictions
3. Checks if member's class can use the item
4. If not usable → marked for tribute instead
5. If usable → kept as normal

**Example Scenarios:**
- **Warrior drops:** Warrior items go to warriors, rogue items go to tribute
- **Rogue items:** Rogues keep them, warriors can't use so they go to tribute
- **Universal items:** Everyone can equip/use, no filtering needed

**Files Modified:**
- `core/inventory.lua` - Added `check_class_usability()` function
- `core/evaluate.lua` - Modified `check_can_loot()` to call class check for "Keep" items

**Status:** ✅ COMPLETE - Automatically active with database fix

---

### 3. Quest Item Awareness (New Feature)

**Feature:** Quest items are automatically kept if master looter needs them for active tasks

**How It Works:**
1. Item drops (must have `Quest()` flag in database)
2. System checks if it's a quest item
3. Reads master looter's task window to find active quests
4. Searches quest objectives for the item name
5. If found → Kept for master looter
6. If not found → Sent to tribute (or configured preference)

**Supported Scenarios:**
- Quest items only kept when needed by active tasks
- Master looter's tasks automatically detected
- Non-quest items unaffected
- Class-based filtering still applies first

**Files Created:**
- `config/conditions/QuestActive.lua` - Condition that reads task window
- `config/helpers/QuestItemCheck.lua` - Reusable helper function
- `config/defaults/QUEST_ITEM_INTEGRATION.md` - Detailed integration guide
- `config/defaults/QUEST_CONFIG_SETUP.md` - Configuration step-by-step
- `config/defaults/QUEST_VERIFICATION_CHECKLIST.md` - Verification and troubleshooting

**Status:** ⏳ READY FOR CONFIGURATION - User needs to add rules to settings

---

## Implementation Checklist

### Verify Database Fix
- [ ] Restart YALM: `/yalm reload`
- [ ] Test loot drops - should see items looting again
- [ ] Run `/yalm check` on a known item - should see loot preference evaluated

### Verify Class Filtering
- [ ] Have warrior and non-warrior in group
- [ ] Kill mob with warrior-only items
- [ ] Verify: Warrior keeps item, non-warrior gets tribute

### Configure Quest Items (Optional)

Follow the **3-step setup** in `QUEST_CONFIG_SETUP.md`:

1. **Add rules to global settings** - Copy QuestItems and QuestItemsNotNeeded rules
2. **Add helper to global settings** - Add QuestItemCheck helper
3. **Add rules to character settings** - Enable rules for your character

Then follow **QUEST_VERIFICATION_CHECKLIST.md** to test:

- [ ] Quest item with active task → Kept
- [ ] Quest item without active task → Tribute
- [ ] Non-quest items → Handled normally

---

## File Structure Reference

### Core System Files (Modified)

```
core/
  inventory.lua         ← Added check_class_usability()
  evaluate.lua          ← Modified check_can_loot() for class checking
  looting.lua           ← (No changes needed)
  
lib/
  database.lua          ← Added fallback query logic
```

### New Quest Item Files

```
config/
  conditions/
    QuestActive.lua                    ← NEW: Reads task window
    
  helpers/
    QuestItemCheck.lua                 ← NEW: Reusable helper
    
  defaults/
    QUEST_ITEM_INTEGRATION.md          ← NEW: Integration guide
    QUEST_CONFIG_SETUP.md              ← NEW: Step-by-step setup
    QUEST_VERIFICATION_CHECKLIST.md    ← NEW: Testing guide
```

---

## How to Use Each Feature

### Feature 1: Database Fix (Automatic)

**No configuration needed.** Just restart YALM:
```
/yalm reload
```

Loot should resume. Items with configured "Keep" preferences will be kept if class-usable.

### Feature 2: Class Filtering (Automatic)

**Already active** after database fix.

Configure class rules normally:
```
["BER"] = {
    ["category"] = "Class",
    ["items"] = {
        ["Warrior Sword"] = { ["setting"] = "Keep" },
        -- ... etc
    }
}
```

The system automatically filters items based on class usability.

### Feature 3: Quest Items (Requires Setup)

**3-step configuration:**

1. **Global Settings** - Add to `global_settings["rules"]`:
```lua
["QuestItems"] = {
    ["category"] = "Item",
    ["conditions"] = { { ["name"] = "QuestActive" } },
    ["items"] = { ["Keep"] = {} }
},
["QuestItemsNotNeeded"] = {
    ["category"] = "Item",
    ["items"] = { ["Tribute"] = {} }
},
```

2. **Global Helpers** - Add to `global_settings["helpers"]`:
```lua
["QuestItemCheck"] = { ["name"] = "QuestItemCheck" },
```

3. **Character Settings** - Add to `["rules"]` list:
```lua
{ ["name"] = "QuestItems", ["enabled"] = true },
{ ["name"] = "QuestItemsNotNeeded", ["enabled"] = true },
```

4. **Restart:** `/yalm reload`

5. **Test:** Use checklist in `QUEST_VERIFICATION_CHECKLIST.md`

---

## Troubleshooting Quick Links

### "Nothing is looting"
→ See **Database Fix** section, Step 1: Verify Database Fix

### "Items not being class-filtered"
→ Check database is working: `/yalm check [itemname]`
→ Verify class rules are configured

### "Quest items not working"
→ See **QUEST_VERIFICATION_CHECKLIST.md** → Troubleshooting section

### "Lua errors or crashes"
→ Check `/yalm debug` output
→ See specific error in troubleshooting guides

---

## Key Improvements Summary

| Aspect | Before | After |
|--------|--------|-------|
| **Looting** | Nothing looting due to DB errors | Full loot evaluation works |
| **Class Filtering** | Attempted but failed | Warriors get warrior items, others tribute |
| **Database** | Only used new table (empty) | Uses both old & new tables with fallback |
| **Quest Items** | No distinction | Intelligently kept/tributed based on tasks |
| **Configuration** | Unchanged | New optional quest item rules |

---

## FAQ

**Q: Do I need to update anything right now?**
A: No. Restart YALM to activate the database fix. Quest items are optional.

**Q: Will this break my existing configuration?**
A: No. Existing rules work the same. Quest item feature is additive.

**Q: Do all quest items need the feature?**
A: No. You can still use manual rules for specific quest items.

**Q: How do I know if the database fix is working?**
A: Use `/yalm check [itemname]` - should show loot preference instead of errors.

**Q: Can non-master-looters benefit from quest items?**
A: The condition reads the master looter's tasks. Others get automatic rule-based preferences.

---

## Next Steps

1. **Immediate:** Restart YALM to activate database fix
2. **Test:** Verify loot resumption with `/yalm check` on known items
3. **Observe:** Class filtering should automatically work
4. **Optional:** Configure quest items following `QUEST_CONFIG_SETUP.md`
5. **Verify:** Use `QUEST_VERIFICATION_CHECKLIST.md` to test quest feature

---

## Support & Documentation

**Detailed Guides Located In:**
- `config/defaults/QUEST_ITEM_INTEGRATION.md` - Integration details
- `config/defaults/QUEST_CONFIG_SETUP.md` - Configuration examples
- `config/defaults/QUEST_VERIFICATION_CHECKLIST.md` - Testing & troubleshooting
- `config/defaults/quest_item_example.lua` - Configuration code snippets

**Getting Help:**
1. Check relevant troubleshooting section above
2. Review appropriate documentation file
3. Enable debug mode: `/yalm debug on`
4. Check debug output for specific error messages
5. Cross-reference error with troubleshooting guide

---

**Last Updated:** This Session
**Status:** Ready for deployment
**Testing:** Proceed with verification checklist
