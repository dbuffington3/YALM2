# Manual Override Cache Preservation Fix

## Problem

After the user successfully entered a manual override (e.g., "Faernoc's Fang" for the objective "Retrieve one of Faernoc's fangs"):

1. The manual override was successfully stored in the database
2. The system worked correctly for that objective (no more fuzzy matching)
3. BUT: The next time the user clicked "Refresh Quest Data", the cache was **completely cleared**
4. This wiped out the manual override
5. The system went back to trying to fuzzy match the objective
6. Log spam from ITEM_MATCH continued indefinitely

## Root Cause

The `manual_refresh_with_messages()` function was calling `quest_db.clear_objective_cache()` unconditionally at startup, which deleted ALL cached objectives including manually verified ones.

This was too aggressive - we only need to clear objectives that are NO LONGER ACTIVE (marked "Done"), not all cached objectives.

## Solution

Changed the cache clearing strategy:

**Before**: Clear entire cache
```lua
quest_db.clear_objective_cache()  -- Deletes EVERYTHING
```

**After**: Clear only completed objectives, keep active ones

```lua
-- Build list of objectives that are currently active (not "Done")
local active_objectives = {}
-- Iterate through all task data and collect active objectives

-- Get cached objectives and remove the ones no longer active
local cached_objs = quest_db.get_all_cached_objectives()
for cached_obj_text, _ in pairs(cached_objs) do
    if not active_objectives[cached_obj_text] then
        -- This objective is completed - remove from cache
        quest_db.delete_objective_cache_entry(cached_obj_text)
    end
end
```

## Changes Made

### File 1: `yalm2_native_quest.lua` (manual_refresh_with_messages function)

**Changed**:
- Replaced `quest_db.clear_objective_cache()` with selective clearing
- Now only removes cache entries for objectives that are no longer active
- Preserves all active objective caches, including manual overrides

**Effect**:
- Manual overrides survive across refreshes
- User doesn't have to re-enter them
- Only stale completed objectives are cleared

### File 2: `lib/quest_database.lua` (new function)

**Added**: `quest_db.delete_objective_cache_entry(objective_text)`

```lua
function quest_db.delete_objective_cache_entry(objective_text)
    if not objective_text then
        return false
    end
    
    local db = get_db()
    if not db then
        return false
    end
    
    local delete_sql = "DELETE FROM quest_objectives WHERE objective = ?"
    local stmt = db:prepare(delete_sql)
    if stmt then
        stmt:bind_values(objective_text)
        local result = stmt:step()
        stmt:finalize()
        return result == sql.DONE
    end
    
    return false
end
```

This function deletes a SINGLE cache entry instead of all entries.

## Impact

### Before
- User enters manual override
- Manual override works for a moment
- Next refresh clears everything
- Log spam resumes
- User has to re-enter override repeatedly

### After
- User enters manual override
- Manual override persists across refreshes
- Only completed objectives are cleared from cache
- No log spam
- User only needs to do it once per session

## Testing

1. Have an objective that fails to fuzzy match
2. See it in the "Failed" tab
3. Enter a manual override and click "Retry"
4. Verify it succeeds and appears in quest data
5. Click "Refresh Quest Data" multiple times
6. Manual override should **persist** across refreshes
7. No more ITEM_MATCH spam for that objective

## Code Quality

- ✓ Selective clearing preserves manual work
- ✓ New function is reusable for other scenarios
- ✓ Logging shows which objectives were removed
- ✓ No performance impact
- ✓ Backward compatible

## Related Functions

- `get_all_cached_objectives()` - Returns all cached objectives
- `delete_objective_cache_entry()` - NEW: Deletes single entry
- `clear_objective_cache()` - Still exists for startup cleanup
- `store_objective()` - Stores manual overrides in cache
