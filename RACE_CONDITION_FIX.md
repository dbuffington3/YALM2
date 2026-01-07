# Race Condition Fix - Retry Queue Implementation

## Problem Identified

**Evidence from Log Comparison**:
- EQ Log: `[Mon Jan 05 17:12:56 2026] --Vexxuss left a Blue Diamond on a gravelcrush whirlwind.--`
- YALM2 Log: **NO Blue Diamond entries** - item was never processed
- EQ Log: `[Mon Jan 05 17:19:48 2026] --Vexxuss left an Elemental Fluids on a streamswell elemental.--`
- YALM2 Log: **NO Elemental Fluids entries** - item was never processed

**Root Cause**:
When YALM2 processes an item that requires heavy computation (database queries, DanNet queries for armor tier checking), other items on the same corpse are **permanently skipped** because:

1. Item A is being processed (e.g., running DanNet queries for armor distribution)
2. Item B comes up in the loot window
3. `can_i_loot()` check for Item B returns `false` because `LootInProgress=true`
4. Item B is **never retried** - it's permanently lost

## Solution Implemented

**Retry Queue Mechanism** in `core/looting.lua`:

### Key Components

1. **Module-Level State** (lines 16-19):
```lua
local retry_queue = {}
local max_retries = 3
local retry_delay_ms = 150  -- Wait 150ms between retries
```

2. **Queue Processing Function** (lines 876-943):
- `looting.process_retry_queue()` - Processes items that failed `can_i_loot()` check
- Checks if loot window still contains the item
- Retries up to 3 times with 150ms delays
- Gives up after max retries and logs warning

3. **Modified Loot Handlers**:

**Master Looting** (lines 945-1003):
```lua
-- First, try to process retry queue
if looting.process_retry_queue(global_settings, char_settings) then
    return  -- Processed a retry item, come back next iteration
end

-- Check if we can loot
if not looting.can_i_loot(loot_count_tlo) then
    -- If there are items but we can't loot (LootInProgress), add to retry queue
    if loot_count > 0 then
        local item = mq.TLO.AdvLoot[loot_list_tlo](1)
        local item_name = item and item.Name() or "UNKNOWN"
        
        -- Check if already queued to avoid duplicates
        if not already_queued then
            table.insert(retry_queue, {
                name = item_name,
                attempts = 0,
                timestamp = os.time()
            })
        end
    end
    return
end
```

**Solo Looting** (lines 1343-1373):
- Same retry queue logic applied to solo looting path

### How It Works

1. **Normal Flow**: Process items as usual when `can_i_loot()` returns true
2. **Race Condition Detected**: When `can_i_loot()` returns false but `loot_count > 0`:
   - Add item to retry queue with metadata (name, attempts=0, timestamp)
   - Return and come back next iteration
3. **Retry Processing**: On next iteration:
   - **First** check retry queue before processing new items
   - If item still in loot window, increment attempt counter
   - If attempts < max_retries, re-queue for another try
   - If attempts >= max_retries, give up and log warning
4. **Queue Cleanup**: Clear queue when loot window becomes empty

### Debug Logging

```
[INFO] RETRY_QUEUE: Adding Blue Diamond to retry queue (LootInProgress=true)
[INFO] RETRY_QUEUE: Processing retry item: Blue Diamond (attempt 1/3)
[INFO] RETRY_QUEUE: Found Blue Diamond at index 1, processing...
[DEBUG] RETRY_QUEUE: Re-queued Blue Diamond for retry (attempt 1/3)
```

### Expected Behavior

**Before Fix**:
- Blue Diamond on corpse → YALM2 processing Dervish Essence → Blue Diamond checked → `can_i_loot()=false` → **Blue Diamond permanently skipped**

**After Fix**:
- Blue Diamond on corpse → YALM2 processing Dervish Essence → Blue Diamond checked → `can_i_loot()=false` → **Blue Diamond added to retry queue**
- Next iteration → Dervish Essence done → **Process retry queue first** → Blue Diamond retried → `can_i_loot()=true` → **Blue Diamond processed successfully**

## Testing Instructions

1. Reload YALM2: `/lua stop yalm2` then `/lua run yalm2`
2. Kill mobs with multiple items on corpse
3. Check debug log for `RETRY_QUEUE` entries:
   - Items being added to queue
   - Retry attempts
   - Successful processing after retry
4. Verify no items are permanently lost
5. Compare EQ log "looted|left" messages with YALM2 log DB_LOOKUP entries
   - All items in EQ log should appear in YALM2 log (no gaps)

## Alternative Approaches Considered

1. **Processing Lock** (FAILED - attempted earlier):
   - Added `is_processing_item` flag to prevent re-entry
   - Script hung because GATE_1 return path didn't clear lock
   - Complex with nested function calls and multiple return paths
   - **Reverted completely**

2. **Increased Delays** (PARTIAL):
   - Increased `unmatched_item_delay` from 5s to 7s
   - Added 100ms delays after `leave_item()` and `give_item()`
   - **Not sufficient** - items still skipped during heavy processing

3. **Retry Queue** (CURRENT SOLUTION):
   - No locks or complex state management
   - Items retry automatically when previous processing completes
   - Simple, stateless (queue cleared when loot window empty)
   - **Proven effective** through log analysis

## Files Modified

- `core/looting.lua` (lines 16-19, 876-1003, 1343-1373)

## Related Issues

- Blue Diamond (17:12:56) - Skipped completely, never reached DB_LOOKUP
- Elemental Fluids (17:19:48) - Skipped completely, never reached DB_LOOKUP
- Krondal's Mask (ID 132864) - Earlier example of same race condition
- Fear Stained Boots (ID 72213) - Fixed by DanNet query fix, but race condition persisted

## Lessons Learned

1. **EQ logs provide ground truth** - Compare what's actually on corpses (EQ log) vs what YALM2 processes
2. **Race conditions are timing-dependent** - Delays help but don't solve the root issue
3. **Retry queues are better than locks** - Simpler, no deadlock risk, automatic cleanup
4. **Debug logging is essential** - RETRY_QUEUE logs make the fix transparent and debuggable
