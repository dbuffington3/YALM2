# Namespace Collision Fix - YALM2_Database Rename

## Problem
Both old YALM and YALM2 systems create a global `Database` variable. When the old YALM system loads after YALM2, it overwrites the global Database with its own instance, which has no connection initialized. This causes crashes with:

```
C:\MQ2\lua\yalm\lib\database.lua:35: attempt to index field 'database' (a nil value)
```

## Solution
Rename YALM2's global Database to YALM2_Database to avoid collision with old YALM system's Database.

## Files Changed

### 1. lib/database.lua
- Line 9: `Database = {` → `YALM2_Database = {`
- Line 14: `Database.OpenDatabase` → `YALM2_Database.OpenDatabase`
- Line 16: `Database.path` → `YALM2_Database.path`
- Line 37: `Database.database` → `YALM2_Database.database`
- Line 52: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 85: `Database.database` → `YALM2_Database.database`
- Line 110: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 126: `Database.QueryDatabaseForItemName` → `YALM2_Database.QueryDatabaseForItemName`
- Line 129: `Database.RefreshConnection` → `YALM2_Database.RefreshConnection`
- Line 130: `Database.database` → `YALM2_Database.database`
- Line 131: `Database.database:close()` → `YALM2_Database.database:close()`
- Line 133: `Database.database = Database.OpenDatabase()` → `YALM2_Database.database = YALM2_Database.OpenDatabase()`
- Line 134: `return Database.database` → `return YALM2_Database.database`
- Line 137: `return Database` → `return YALM2_Database`

### 2. core/evaluate.lua
- Line 10: Comment updated to mention YALM2_Database
- Line 272: `Database.QueryDatabaseForItemId()` → `YALM2_Database.QueryDatabaseForItemId()`
- Line 276: `Database.QueryDatabaseForItemName()` → `YALM2_Database.QueryDatabaseForItemName()`

### 3. core/looting.lua
- Line 12: Comment updated to mention YALM2_Database
- Line 523: `Database.QueryDatabaseForItemId()` → `YALM2_Database.QueryDatabaseForItemId()`

### 4. core/loot_simulator.lua
- Line 35: Comment updated to mention YALM2_Database
- Line 84: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 94: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 105: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 139: `Database.database:nrows()` → `YALM2_Database.database:nrows()`

### 5. yalm2_native_quest.lua
- Line 67: Comment mentions YALM2_Database
- Line 70: `Database.database = Database.OpenDatabase()` → `YALM2_Database.database = YALM2_Database.OpenDatabase()`
- Line 71: `if not Database.database` → `if not YALM2_Database.database`
- Line 459: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 807: `if not Database.database` → `if not YALM2_Database.database`
- Line 831: `Database.database:nrows()` → `YALM2_Database.database:nrows()`
- Line 1063: `if not Database.database` → `if not YALM2_Database.database`
- Line 1083: `Database.database:nrows()` → `YALM2_Database.database:nrows()`

### 6. init.lua
- Line 151: `Database.database = assert(Database.OpenDatabase())` → `YALM2_Database.database = assert(YALM2_Database.OpenDatabase())`

## Impact
- YALM2 now uses YALM2_Database exclusively
- Old YALM system uses Database without conflicts
- No namespace collision when both systems are loaded
- YALM2 will work independently even if old YALM reloads or initializes

## Testing
Run YALM2 with old YALM system active:
1. Start both `/yalm2` and old `/yalm` scripts
2. Verify no "attempt to index field 'database'" errors
3. Confirm quest item detection works
4. Test loot distribution

## Verification
All Database references in yalm2 changed to YALM2_Database:
```
✅ lib/database.lua - Creates YALM2_Database global
✅ core/evaluate.lua - Uses YALM2_Database
✅ core/looting.lua - Uses YALM2_Database
✅ core/loot_simulator.lua - Uses YALM2_Database
✅ yalm2_native_quest.lua - Initializes and uses YALM2_Database
✅ init.lua - Initializes YALM2_Database
```

No remaining bare `Database` references in code (only in comments).
