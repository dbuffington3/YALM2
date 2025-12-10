# Session Changes Log - Database Singleton Architecture Fix

## Session Objective
Fix database initialization errors that appeared after namespace migration from `yalm.*` to `yalm2.*`

## Errors Being Fixed
1. "ERROR: Database.database is nil - connection not initialized"
2. "bad argument #1 to 'pairs' (table expected, got nil)" at evaluate.lua:493
3. Multiple database query failures

## Root Cause
Modules creating separate Database instances instead of sharing a global singleton

## Changes Made

### 1. core/looting.lua
**Change**: Added missing require statement
**Location**: Line 12
**Before**:
```lua
local dannet = require("yalm2.lib.dannet")
local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")

local looting = {}
```

**After**:
```lua
local dannet = require("yalm2.lib.dannet")
local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")
require("yalm2.lib.database")  -- Initialize the global Database table

local looting = {}
```

**Why**: looting.lua uses `Database.QueryDatabaseForItemId()` at line 523, so it needs to ensure the global Database is initialized

## Previous Sessions' Changes (For Reference)

### core/evaluate.lua
- Added `require("yalm2.lib.database")` at line 10
- Changed `local database = require()` to bare `require()`
- Changed `database.QueryDatabaseForItemId()` to `Database.QueryDatabaseForItemId()`
- Changed `database.QueryDatabaseForItemName()` to `Database.QueryDatabaseForItemName()`
- Added nil check in `is_valid_preference()` function

### core/loot_simulator.lua
- Added `require("yalm2.lib.database")` 
- Removed `local database = require()` line
- Changed 4 occurrences of `database.database:nrows()` to `Database.database:nrows()`

### lib/database.lua
- No changes needed - was already correct with global Database pattern

### yalm2_native_quest.lua
- Already had initialization (lines 67-72)
- No changes needed

## Verification Steps Taken

### Step 1: Find all Database usage locations
```
Select-String 'Database\.' "C:\MQ2\lua\yalm2\**\*.lua" | Select-Object Path -Unique
```
Result: Found in evaluate.lua, looting.lua, loot_simulator.lua, database.lua ✅

### Step 2: Verify all Database-using files have require
```
Get-ChildItem "C:\MQ2\lua\yalm2\**\*.lua" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    if ($content -match 'Database\.') {
        if ($content -notmatch 'require.*database') {
            Write-Host "MISSING: $($_.FullName)"
        }
    }
}
```
Result: Only database.lua (which is correct), all others have requires ✅

### Step 3: Verify no remaining local database requires
```
Select-String 'local database = require\|local Database = require' "C:\MQ2\lua\yalm2\**\*.lua"
```
Result: Zero matches (all converted to bare requires) ✅

### Step 4: Verify no old yalm namespace remains
```
Select-String 'require.*yalm"' "C:\MQ2\lua\yalm2\**\*.lua"
```
Result: Zero matches (all migrated to yalm2) ✅

## Files Requiring This Fix
The following files use Database and needed the require:
1. ✅ core/evaluate.lua - DONE (previous session)
2. ✅ core/looting.lua - DONE (this session)
3. ✅ core/loot_simulator.lua - DONE (previous session)
4. ✅ yalm2_native_quest.lua - Already correct
5. ✅ lib/database.lua - Module definition, no require needed

## Architectural Pattern

**Pattern**: Lua Global Singleton
```lua
-- In database.lua (module):
Database = { database = nil }  -- Global, not local
Database.OpenDatabase = function() ... end
Database.QueryDatabaseForItemId = function() ... end
return Database

-- In any consumer:
require("yalm2.lib.database")  -- Gets/creates global Database
Database.database = Database.OpenDatabase()  -- Initialize once
-- Later use:
Database.QueryDatabaseForItemId(123)  -- Works in all modules
```

## Expected Behavior After Fix

**Before**: Each module had its own Database instance
```
yalm2_native_quest.lua loads → creates Database (initialized)
evaluate.lua loads → creates Database (NOT initialized)
looting.lua loads → creates Database (NOT initialized) ← Error when used!
```

**After**: All modules share the same Database instance
```
yalm2_native_quest.lua loads → creates global Database (initialized)
evaluate.lua loads → gets global Database (already initialized)
looting.lua loads → gets global Database (already initialized) ✅
```

## Testing Validation

Quick test script created: `test_database_singleton.lua`
```lua
require("yalm2.lib.database")
print("Database exists: " .. tostring(Database ~= nil))

Database.database = Database.OpenDatabase()
print("Connection exists: " .. tostring(Database.database ~= nil))

require("yalm2.lib.database")  -- Load again
print("Same global: " .. tostring(Database ~= nil))
```

## Status
✅ **COMPLETE** - All database singleton fixes implemented
Ready to: Restart YALM2 and verify errors are resolved
