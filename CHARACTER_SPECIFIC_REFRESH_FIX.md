# Character-Specific Task Refresh Fix

## Problem Identified
- Vexxuss receives Bloodbone Skeleton Blood Sample (needs 3 total)
- After receiving 3rd sample, his quest status should show "Done" 
- But system continues using stale data that shows he still needs more
- Result: Vexxuss gets 6 samples instead of stopping at 3

## Root Cause
**Over-broad refreshing**: System was doing expensive full-group task refreshes instead of targeted character refreshes after loot distribution.

## Solution Implemented

### 1. Character-Specific Refresh Function (`core/tasks.lua`)
```lua
-- Request task data for a specific character only
tasks.request_character_task_update = function(character_name)
    -- Sends targeted request for just one character's data
    actors.send({ 
        id = 'YALM_REQUEST_CHARACTER_TASKS',
        character = character_name
    })
end

-- Refresh task data for a specific character after they receive loot
tasks.refresh_character_after_loot = function(character_name, item_name)
    -- 1. Request update for just this character
    -- 2. Wait for their data to refresh  
    -- 3. Rebuild quest items cache with updated data
end
```

### 2. Enhanced Loot Distribution (`core/looting.lua`)
```lua
looting.give_item = function(member, item_name)
    mq.cmdf("/advloot shared 1 giveto %s 1", character_name)
    
    -- If this was a quest item, refresh the recipient's task data
    if item_name and tasks.is_quest_item(item_name) then
        tasks.refresh_character_after_loot(character_name, item_name)
    end
end
```

## Expected Behavior Change

### Before Fix:
1. Vexxuss gets Bloodbone Sample #1 → No refresh
2. Vexxuss gets Bloodbone Sample #2 → No refresh  
3. Vexxuss gets Bloodbone Sample #3 → No refresh → **Quest should be complete but system doesn't know**
4. Vexxuss gets Bloodbone Sample #4, #5, #6... → **Continues indefinitely**

### After Fix:
1. Vexxuss gets Bloodbone Sample #1 → **Character-specific refresh** → Status: "1/3"
2. Vexxuss gets Bloodbone Sample #2 → **Character-specific refresh** → Status: "2/3"
3. Vexxuss gets Bloodbone Sample #3 → **Character-specific refresh** → Status: "Done"
4. **System sees "Done" status** → **Stops flagging Vexxuss as needing more samples**

## Performance Benefits
- **Faster**: Refresh 1 character instead of entire group (6 characters)
- **More accurate**: Immediate status updates after loot distribution
- **Less network traffic**: Targeted TaskHUD requests instead of full group scans

## Debug Logging Added
- `LOOT_DISTRIBUTE`: Tracks when items are given to characters
- `QUEST_LOOT`: Specifically tracks quest item distribution
- `CHAR_REFRESH`: Monitors character-specific refresh operations
- `LOOT_REFRESH`: Shows task data update process after loot

## Files Modified
- `core/tasks.lua`: Added character-specific refresh functions
- `core/looting.lua`: Enhanced give_item() with targeted refreshes
- Added debug logging throughout the process

This should resolve the issue where characters receive more quest items than needed by ensuring their task status is immediately updated after each loot distribution.