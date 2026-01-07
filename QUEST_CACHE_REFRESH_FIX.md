# Quest Objectives Cache Refresh Fix

## Problem Identified

TWO issues were found:

### Issue 1: Cache Not Cleared on Manual Refresh
When a quest stage is marked "Done", the objectives from that stage become inactive and new objectives from the next stage become visible. However, the `quest_objectives` cache was not being cleared during manual refresh, causing the system to:
- Keep using old cached objective matches from completed stages
- Fail to discover and cache new objectives that are now visible
- Require a complete database reset to see new objectives (unacceptable)

### Issue 2: Completed Objectives Not Filtered Out
Even after clearing the cache, the system was still processing objectives with `status == "Done"`, which means they're already completed and not active. These completed objectives should be completely skipped.

**Example Scenario**
- Stage 1: "Loot 3 pieces of bark from the treants" → status = "Done"
- User marks Stage 1 as "Done"  
- System should SKIP this objective completely
- **BUG**: System was still including it in quest item detection ❌

## Solution Implemented

**File**: `yalm2_native_quest.lua`  
**Functions Modified**: 
1. `manual_refresh_with_messages()` (Lines 1157-1280)
2. `refresh_character_after_loot()` (Lines 1030-1107)

### Changes Made

#### 1. Clear Cache on Manual Refresh (Line 1163)
Added explicit cache clearing at the START of the manual refresh function:

```lua
local function manual_refresh_with_messages(show_messages)
    -- ...
    -- CRITICAL: Clear the quest objectives cache on manual refresh
    quest_db.clear_objective_cache()
    -- ...
end
```

#### 2. Filter Out Completed Objectives (Both Functions)
Added status check to skip any objectives marked "Done":

```lua
-- In manual_refresh_with_messages (Line 1203-1204)
if objective and objective.status == "Done" then
    Write.Debug("MANUAL_REFRESH: Skipping completed objective: '%s'", objective.objective)
elseif objective and objective.objective then
    -- Process this objective
end

-- In refresh_character_after_loot (Line 1037-1038)
if objective and objective.status == "Done" then
    Write.Debug("[CHAR_REFRESH] Skipping completed objective: '%s'", objective.objective)
elseif objective and objective.objective then
    -- Process this objective
end
```

### Why This Works

1. **Cache cleared first**: Each user-initiated refresh starts with an empty cache
2. **Completed objectives skipped**: Only processes objectives still in progress
3. **New objectives discovered**: Forces fuzzy matching to re-run for active objectives
4. **Manual refresh only**: Cache is cleared ONLY when user clicks the "Refresh Quest Data" button
5. **Not on automatic loops**: Automatic 3-second refreshes still use cached data for speed

## Automatic vs Manual Refresh

### Automatic Refresh (Every 3 seconds - SILENT)
- Uses `efficient_refresh_from_cache()`
- Checks cache, returns immediately if cached
- No database modifications or cache clearing
- Skips completed objectives (already in code)
- No user messages
- Purpose: Responsive looting during combat

### Manual Refresh (User-initiated - WITH MESSAGES)
- Calls `manual_refresh_with_messages()`
- **NOW CLEARS CACHE** (FIX #1)
- **NOW FILTERS COMPLETED OBJECTIVES** (FIX #2)
- Re-scans ONLY active objectives via fuzzy matching
- Shows quest item discoveries to user
- Purpose: Update after quest stage changes

## Testing the Fix

### Before Fix
```
Quest stage marked "Done"
Click "Refresh Quest Data"
// Still shows old completed objective from that stage ❌
```

### After Fix  
```
Quest stage marked "Done"
Click "Refresh Quest Data"
// quest_objectives cache CLEARED
// System skips all objectives with status == "Done"
// Scans only ACTIVE objectives (not "Done")
// New objectives from next stage discovered ✓
```

### Manual Test Steps
1. Have an active quest with multiple stages
2. Mark a stage as "Done" (status changes from active to "Done")
3. Click "Refresh Quest Data" in YALM2 UI
4. Check logs for debug messages like: "Skipping completed objective: 'Loot 3 pieces...'"
5. New objectives should now be visible in quest data (not old completed ones)

## Impact

- **User Workflow**: Much smoother - no need to restart to see new objectives
- **Accuracy**: System only processes active objectives, not completed ones
- **Performance**: Manual refresh slightly slower (cache clear + rescan) but acceptable
- **Automatic Loops**: Unaffected - still use cache for speed
- **Safety**: Completed objectives no longer interfere with active quest processing

## Related Code

- `quest_db.clear_objective_cache()` - Clears the `quest_objectives` table
- `quest_db.store_objective()` - Stores newly matched objectives
- `quest_db.get_objective()` - Retrieves cached objective data
- `objective.status` - Field indicating if objective is "Done" or active
- `quest_interface.find_matching_quest_item()` - Performs fuzzy matching on objective text
- `efficient_refresh_from_cache()` - Automatic refresh (unchanged)

## Commit Information

- **Files Modified**: `yalm2_native_quest.lua`
- **Lines Changed**: Multiple sections (cache clear + status filters)
- **Change Type**: Added cache clearing and status filtering
- **Breaking Changes**: None
- **Backward Compatibility**: Full - only affects manual refresh behavior
