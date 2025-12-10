# YALM2 Database Singleton Fix - Testing Checklist

## Fixes Applied

### 1. Database Module Architecture (lib/database.lua)
- ✅ Database table created as GLOBAL (not local)
- ✅ Returns Database at end of module
- ✅ All functions (OpenDatabase, QueryDatabaseForItemId, QueryDatabaseForItemName) are methods on Database table
- ✅ Nil checks in place for Database.database

### 2. Initialization (yalm2_native_quest.lua)
- ✅ Line 67: `require("yalm2.lib.database")` - initializes Database global
- ✅ Line 70: `Database.database = Database.OpenDatabase()` - opens connection
- ✅ Lines 71-74: Error handling if Database.database is nil

### 3. Core Module Requires
- ✅ core/evaluate.lua - Line 10: `require("yalm2.lib.database")`
- ✅ core/looting.lua - Line 12: `require("yalm2.lib.database")` [NEWLY ADDED]
- ✅ core/loot_simulator.lua - Line 35: `require("yalm2.lib.database")`

### 4. Database Usage Pattern
All files use:
- ✅ Global `Database` object (not local instance)
- ✅ `Database.QueryDatabaseForItemId(item_id)` - proper method call
- ✅ `Database.QueryDatabaseForItemName(item_name)` - proper method call
- ✅ `Database.database:nrows(query)` - proper connection access
- ❌ NO `local database = require(...)` patterns (removed all)

### 5. Nil Protection
- ✅ evaluate.lua - Checks `if not loot_item.item_db then` after query
- ✅ looting.lua - Uses pcall() wrapper around Database calls
- ✅ loot_simulator.lua - Direct calls but only in test code
- ✅ yalm2_native_quest.lua - Checks `if not Database.database then` before use

## Test Sequence

### Test 1: Script Load
1. Start YALM2: `/yalm2quest`
2. Watch for errors in MQ2 console
3. **Expected**: No "ERROR: Database.database is nil" messages
4. **Expected**: Database initialization successful message

### Test 2: Item Database Query
1. Run: `/yalm2 queryitem 120331`
2. **Expected**: Returns item "Orbweaver Silk" details
3. **Expected**: No database connection errors

### Test 3: Loot Detection
1. Accept a quest with items to track
2. Get a quest item from a mob
3. Watch item appear in YALM2 Quest window
4. **Expected**: Item correctly identified as quest item
5. **Expected**: No database query errors in debug log

### Test 4: Quest Item Distribution
1. Get multiple quest items
2. Check that items are distributed to correct quest holders
3. **Expected**: Distribution logic works without database errors
4. **Expected**: No "bad argument #1 to 'pairs'" errors

### Test 5: Manual Refresh
1. In YALM2 Quest window, click "Refresh Quest Data"
2. **Expected**: Quest data updates without errors
3. **Expected**: All items properly validated in database

### Test 6: Loot Simulator (if needed)
1. Run: `/yalm2 simulate id 120331`
2. **Expected**: Simulates quest item distribution
3. **Expected**: No database connection errors

## Key Error Indicators to Watch For

### MUST NOT OCCUR:
- "ERROR: Database.database is nil"
- "bad argument #1 to 'pairs' (table expected, got nil)"
- "Database connection failed"
- "ERROR: Cannot query database" (unless intentional for non-existent items)

### Should see:
- "Database connection established successfully" (or similar)
- Successful quest item detection and distribution
- Normal debug logging output

## Debugging Steps If Errors Occur

If "Database.database is nil" appears:
1. Check yalm2_native_quest.lua line 70 executes: `Database.database = Database.OpenDatabase()`
2. Verify Database.OpenDatabase() returns a valid connection
3. Check MQ2LinkDB.db exists at `C:\MQ2\resources\MQ2LinkDB.db`
4. Verify raw_item_data table exists in database

If functions can't find Database:
1. Verify all three require statements are in place:
   - yalm2_native_quest.lua line 67
   - core/evaluate.lua line 10
   - core/looting.lua line 12
   - core/loot_simulator.lua line 35
2. Check that Database is NOT defined as `local Database` anywhere
3. Search for `local database = require` - should find ZERO results

If pairs() error occurs:
1. Check that loot_preferences parameter is validated before use
2. Look for any table iteration on potentially nil values
3. Add defensive nil checks in calling functions

## Notes

- The Database object becomes a true singleton because it's created in database.lua as a global
- When any module does `require("yalm2.lib.database")`, it gets the SAME global Database table
- Initialization in yalm2_native_quest.lua happens BEFORE any other modules use it
- All module loading is synchronous, so initialization order is predictable

## Files Modified in This Session

1. **core/looting.lua** - Added require for database module at line 12
2. **Previous sessions**:
   - core/evaluate.lua - Added require and fixed Database usage
   - core/loot_simulator.lua - Fixed Database usage pattern
   - lib/database.lua - Unchanged (already correct)
   - yalm2_native_quest.lua - Already has initialization

## Verification Command

To verify no local database requires remain:
```
Select-String 'local database = require\|local Database = require' "C:\MQ2\lua\yalm2\**\*.lua"
```

Expected result: NO matches (all have been removed or changed to bare require)
