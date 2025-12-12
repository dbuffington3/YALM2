# Bug Fix: Quest Interface Database Reference

## Issue Found
After removing the external TaskHUD system, the quest system was broken with repeated errors:
```
[YALM2]:: ITEM_MATCH: Database not available for fuzzy matching (quest_database: false, _G.YALM2_Database: false)
```

This prevented quest item detection and fuzzy matching from working.

## Root Cause
When I changed the `quest_interface.initialize()` function signature from:
```lua
initialize(global_settings, external_tasks_module, native_tasks_module, database_ref)  -- 4 params
```

To:
```lua
initialize(global_settings, native_tasks_module, database_ref)  -- 3 params
```

I updated the call in `init.lua` correctly, BUT I forgot to update the call in `yalm2_native_quest.lua` which still had:
```lua
quest_interface.initialize(nil, nil, nil, YALM2_Database)  -- OLD 4-param call
```

This caused the 3rd parameter (native_tasks) to be set to `YALM2_Database` and the database_ref to be `nil`, breaking fuzzy matching.

## Solution
Updated `yalm2_native_quest.lua` line 84 from:
```lua
quest_interface.initialize(nil, nil, nil, YALM2_Database)  -- WRONG: 4 params
```

To:
```lua
quest_interface.initialize(nil, nil, YALM2_Database)  -- CORRECT: 3 params
```

## Verification
After fix:
- ✅ Debug log shows "QUEST_INTERFACE: Database reference stored"
- ✅ No more "Database not available for fuzzy matching" errors
- ✅ Quest items being detected: "Stored 6 quest item records from refresh"
- ✅ System initializes correctly

## Lessons Learned
When changing function signatures across multiple call sites:
1. Search for ALL calls to the function, not just the obvious ones
2. Remember that standalone scripts may have their own initialization
3. Update function signature, all call sites, and their documentation
4. Test all code paths that use the function

## Commit
Fixed in: `12071ab Fix quest_interface.initialize() call in yalm2_native_quest.lua`
