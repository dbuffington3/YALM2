# Startup Task Data Fix

## Problem Identified
YALM2 was not refreshing task data on startup, causing:
1. Script starts with empty quest item cache
2. Processes loot without quest awareness 
3. Continues giving quest items to characters even after they complete objectives
4. Only works properly after manual `/yalm taskinfo` refresh

## Solution: Enhanced Startup Initialization

### Before Fix:
```lua
tasks.init = function()
    -- Register actor
    -- Request task data (fire and forget)
    -- Return immediately (no waiting)
end
```
**Result**: Script starts looting before quest data arrives

### After Fix:
```lua  
tasks.init = function()
    -- Register actor
    -- Request task data
    -- WAIT for task data to arrive (up to 10 seconds)
    -- Process quest items 
    -- Only then allow looting to begin
end
```
**Result**: Script has quest data ready before first loot evaluation

## Implementation Details

### 1. Startup Wait Logic
```lua
-- Wait for initial task data to arrive (with timeout)
local wait_start = os.time()
local max_wait = 10 -- 10 seconds timeout
local received_data = false

while (os.time() - wait_start) < max_wait and not received_data do
    -- Check if we have any character data
    local char_count = 0
    for _ in pairs(task_data.characters) do
        char_count = char_count + 1
    end
    
    if char_count > 0 then
        received_data = true
        break
    end
    
    mq.delay(500) -- Check every 500ms
end
```

### 2. Quest Cache Pre-Population
```lua
if received_data then
    -- Process the initial quest items
    tasks.update_quest_items()
    local quest_count = 0
    for _ in pairs(task_data.quest_items) do quest_count = quest_count + 1 end
    Write.Info("Task initialization complete - tracking %d quest items", quest_count)
end
```

### 3. Enhanced Debug Logging
- `STARTUP: Initializing task awareness system`
- `STARTUP: Task actor registered successfully`  
- `STARTUP: Requesting initial task data from TaskHUD`
- `STARTUP: Waiting for initial task data response...`
- `STARTUP: Initial task data received for X characters`
- `STARTUP: Task initialization complete with X quest items`

## Expected Behavior Change

### Before Fix:
1. **0s**: YALM2 starts
2. **0s**: Requests task data (no wait)
3. **0s**: Begins loot processing with empty quest cache
4. **1-5s**: TaskHUD data arrives (too late)
5. **Result**: Quest items distributed incorrectly until manual refresh

### After Fix:  
1. **0s**: YALM2 starts
2. **0s**: Requests task data  
3. **0-10s**: **WAITS** for TaskHUD response
4. **1-3s**: TaskHUD data arrives and is processed
5. **3s**: Quest cache populated with current objectives
6. **3s**: Begins loot processing with accurate quest data
7. **Result**: Quest items distributed correctly from first loot

## Validation Steps
1. **Restart YALM2** and watch startup messages
2. **Look for**: "Task initialization complete - tracking X quest items" 
3. **Check debug log**: Should show startup sequence completion
4. **Test quest loot**: First Bloodbone Sample should go to correct character

## Timeout Handling
- **10-second timeout** prevents infinite hang if TaskHUD unavailable
- **Graceful fallback**: Continues with warning if no data received
- **Manual recovery**: Users can still run `/yalm taskinfo` to populate cache later

This ensures quest-aware looting works correctly from the moment YALM2 starts, rather than requiring manual intervention.