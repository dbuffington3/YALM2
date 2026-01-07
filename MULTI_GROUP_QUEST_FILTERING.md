# Multi-Group Quest Filtering Implementation

## Problem Statement

When running two separate groups via DanNet (e.g., Group 1: Vexxuss/Lumarra/Thornwick and Group 2: Bristle/Twiggle/Sparkles), the HUD on the master character was displaying quests from ALL connected DanNet peers, not just members of its own group/raid.

**Example:**
- HUD Running on: Vexxuss (Group 1 master)
- Expected UI Display: Vexxuss, Lumarra, Thornwick quests only
- Actual UI Display: Vexxuss, Lumarra, Thornwick, **Bristle, Twiggle, Sparkles** quests (WRONG)

## Root Cause

The actor message handler in `yalm2_native_quest.lua` was unconditionally accepting and storing task data from ANY character connected via DanNet:

```lua
-- OLD (BROKEN)
elseif message.content.id == 'INCOMING_TASKS' then
    if drawGUI == true then
        task_data.tasks[message.sender.character] = message.content.tasks  -- ← No filtering!
        table.insert(peer_list, message.sender.character)
```

This meant that when `REQUEST_TASKS` broadcast was sent, all connected characters responded, and all their quest data was collected regardless of group membership.

## Solution Architecture

### 1. Group/Raid Membership Detection

**Files Modified:**
- `yalm2_native_quest.lua` - Added `is_character_in_our_group()` helper
- `core/quest_interface.lua` - Added same helper function locally

**Logic:**
```lua
local function is_character_in_our_group(character_name)
    -- Self is always included
    if character_name:lower() == my_name:lower() then
        return true
    end
    
    -- Raid takes priority
    if mq.TLO.Raid.Members() > 0 then
        -- Check if character is in raid
        -- Return false if not found (even if we're in a raid)
        return false if not found
    end
    
    -- Fall back to group
    if mq.TLO.Group.Members() > 0 then
        -- Check if character is in group
        -- Return false if not found (even if we're in a group)
        return false if not found
    end
    
    -- Solo play - only accept self
    return false
end
```

### 2. Quest Data Collection Filtering (yalm2_native_quest.lua)

**Location:** Actor message handler, `INCOMING_TASKS` section (lines ~355-365)

**Change:**
```lua
elseif message.content.id == 'INCOMING_TASKS' then
    if drawGUI == true then
        -- NEW: Only accept task data from characters in our group/raid
        if is_character_in_our_group(message.sender.character) then
            task_data.tasks[message.sender.character] = message.content.tasks
            table.insert(peer_list, message.sender.character)
            table.sort(peer_list)
            Write.Debug("ACTOR: Accepted quest data from %s (in our group/raid)", message.sender.character)
        else
            Write.Debug("ACTOR: Ignored quest data from %s (not in our group/raid)", message.sender.character)
        end
    end
```

**Impact:**
- Task data from out-of-group characters is silently dropped
- UI only processes quest items from actual group/raid members
- Debug logs show what was filtered for troubleshooting

### 3. Loot Distribution Filtering (core/quest_interface.lua)

**Location:** `get_characters_needing_item()` function (lines ~163-225)

**Change:**
```lua
quest_interface.get_characters_needing_item = function(item_name)
    if native_tasks and native_tasks.get_characters_needing_item then
        local chars, task_name, objective = native_tasks.get_characters_needing_item(item_name)
        
        -- CRITICAL FIX: Filter to only characters in our group/raid
        local filtered_chars = {}
        if chars then
            for _, char_name in ipairs(chars) do
                if is_character_in_our_group(char_name) then
                    table.insert(filtered_chars, char_name)
                    debug_logger.debug("QUEST_INTERFACE: Including %s (in our group/raid)", char_name)
                else
                    debug_logger.debug("QUEST_INTERFACE: Excluding %s (not in our group/raid)", char_name)
                end
            end
        end
        
        return filtered_chars, task_name, objective
    end
```

**Impact:**
- Looting system will NEVER give quest items to characters outside current group/raid
- Even if out-of-group characters appear in the database, they'll be filtered during loot decisions
- Provides redundant safety check for the looting pipeline

## Hierarchy of Group/Raid Membership

The filtering follows this priority:

1. **Self:** Always included (you can always loot for yourself)
2. **Raid:** If you're in a raid, ONLY raid members are processed
3. **Group:** If you're in a group (but not raid), ONLY group members are processed
4. **Solo:** If solo, ONLY self is processed

**Important:** A raid group doesn't automatically include group members. If you're in a raid, the system looks ONLY at raid members, not at your group.

## Data Flow with Filtering

### Before (Multi-Group Shows All)
```
Group 1 Master (Vexxuss)
  └─ REQUEST_TASKS broadcast
       ├─ Vexxuss responds ✓
       ├─ Lumarra responds ✓
       ├─ Thornwick responds ✓
       ├─ Bristle responds ✓ (WRONG - accepted unconditionally)
       ├─ Twiggle responds ✓ (WRONG - accepted unconditionally)
       └─ Sparkles responds ✓ (WRONG - accepted unconditionally)
  
  Result: UI shows quests from both groups
```

### After (Multi-Group Isolated)
```
Group 1 Master (Vexxuss)
  └─ REQUEST_TASKS broadcast
       ├─ Vexxuss responds → is_character_in_our_group("Vexxuss") = true ✓ STORED
       ├─ Lumarra responds → is_character_in_our_group("Lumarra") = true ✓ STORED
       ├─ Thornwick responds → is_character_in_our_group("Thornwick") = true ✓ STORED
       ├─ Bristle responds → is_character_in_our_group("Bristle") = false ✗ IGNORED
       ├─ Twiggle responds → is_character_in_our_group("Twiggle") = false ✗ IGNORED
       └─ Sparkles responds → is_character_in_our_group("Sparkles") = false ✗ IGNORED
  
  Result: UI shows only Group 1 quests
```

## Implementation Details

### Data Persistence

- **Quest data from out-of-group characters:** NOT stored in `task_data.tasks`
- **MQ2 Variables:** The `YALM2_Quest_Items_WithQty` variable still contains all quest data (this is fine - it's a shared store)
- **Database:** The quest_tasks table may contain entries from all characters (historical data is fine)
- **UI Display:** Only displays characters that made it past the filtering check

The key is that the **HUD UI and looting logic only USE the filtered data**, not the raw database.

### Collector Behavior (No Changes Needed)

- Collector scripts on Group 2 characters continue to run normally
- They send their task data via DanNet `INCOMING_TASKS` messages
- Group 1's HUD just ignores those messages
- No modifications to collector behavior - they don't know about group filtering
- This allows independent operation without cross-group interference

## Testing the Fix

### Setup
```
Raid/Group 1: Vexxuss (Master with HUD), Lumarra, Thornwick
Raid/Group 2: Bristle (separate, no HUD), Twiggle, Sparkles
All connected via DanNet
```

### Test Procedure
1. On **Vexxuss**: Run YALM2 with native quest system enabled
2. Accept/share some quests on Group 1 characters
3. Accept/share different quests on Group 2 characters
4. Check Vexxuss's quest HUD display
5. Verify: **Only Group 1 quests are shown**
6. Check debug logs: Should see "Ignored quest data from [Bristle/Twiggle/Sparkles]" messages

### Expected Results
- ✅ Group 1 quests appear in HUD
- ✅ Group 1 quest items are looted correctly
- ❌ Group 2 quests do NOT appear in HUD (should see ignore debug messages)
- ❌ Group 2 quest items are NOT considered for loot distribution
- ✅ Both groups operate independently without interference

## Debug Output Examples

### Normal Multi-Group Operation
```
[YALM2] ACTOR: Accepted quest data from Vexxuss (in our group/raid)
[YALM2] ACTOR: Accepted quest data from Lumarra (in our group/raid)
[YALM2] ACTOR: Accepted quest data from Thornwick (in our group/raid)
[YALM2] ACTOR: Ignored quest data from Bristle (not in our group/raid)
[YALM2] ACTOR: Ignored quest data from Twiggle (not in our group/raid)
[YALM2] ACTOR: Ignored quest data from Sparkles (not in our group/raid)
```

### Loot Distribution Example
```
[YALM2] QUEST_INTERFACE: Including Vexxuss (in our group/raid)
[YALM2] QUEST_INTERFACE: Including Lumarra (in our group/raid)
[YALM2] QUEST_INTERFACE: Excluding Bristle (not in our group/raid)
[YALM2] QUEST_DISTRIBUTION: Giving [Item] to Lumarra (needs quest item)
```

## Files Modified

1. **yalm2_native_quest.lua** (Lines 320-354)
   - Added `is_character_in_our_group()` function
   - Modified actor message handler INCOMING_TASKS section
   - Added debug logging for filtering decisions

2. **core/quest_interface.lua** (Lines 163-225)
   - Added `is_character_in_our_group()` function
   - Modified `get_characters_needing_item()` to filter results
   - Added debug logging for quest interface filtering

## Backward Compatibility

- ✅ Single group/raid scenarios: No change (everyone is in the group)
- ✅ Solo play: Works as before (only self is included)
- ✅ Raid transitions: Auto-adapts to raid/group changes
- ✅ Quest data storage: Database unchanged, filtering happens at read time
- ✅ Collector scripts: No modifications needed, continue operating normally

## Future Enhancements (Not Implemented)

1. **Raid Sub-Groups:** Could extend to support raid sub-groups (Group A vs Group B within a raid)
2. **Cross-Group Distribution:** Could add optional "broadcast to all DanNet" mode for specific items
3. **Alliance Support:** Could add filtering by alliance/confederate relationships
4. **Manual Override:** Could add commands to manually include/exclude specific characters

These are not implemented because the current multi-group isolation is the desired behavior.
