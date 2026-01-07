# Collector Tracking Fix - Multi-Group Quest Communication

## Problem
When multiple groups each ran their own quest HUD, collectors' task data was being rejected by the filter `is_character_in_our_group()`. This happened because:
- Group 1 (Vexxusz + collectors) and Group 2 (Malrik + collectors) are separate groups
- When Vexxusz receives INCOMING_TASKS from his collectors, the filter checked if they were in HIS group
- But the same filter was also checking OTHER groups' collectors, rejecting them
- This broke legitimate group-internal communication

## Solution
Instead of filtering by group/raid membership, we now track which collectors each master instance STARTED:

1. When a master starts collectors via `/dquery`, we add them to `known_collectors` table
2. When master receives INCOMING_TASKS, we only accept data from collectors in the `known_collectors` table
3. This prevents cross-group pollution while allowing each group's internal communication

## Code Changes

### Change 1: Added known_collectors table (Line ~110)
```lua
local known_collectors = {}  -- Track which collectors this master started
```

### Change 2: Track collectors when starting them (Lines ~1677-1700)
When looping through raid/group members to start collectors:
```lua
local collector_name = member.DisplayName()
table.insert(known_collectors, collector_name)
mq.cmd(string.format('/dquery %s /lua run yalm2/yalm2_native_quest nohud', collector_name))
```

### Change 3: Check known_collectors instead of is_character_in_our_group() (Lines ~365-383)
```lua
elseif message.content.id == 'INCOMING_TASKS' then
    if drawGUI == true then
        local is_known_collector = false
        for _, collector in pairs(known_collectors) do
            if collector:lower() == message.sender.character:lower() then
                is_known_collector = true
                break
            end
        end
        
        if is_known_collector then
            task_data.tasks[message.sender.character] = message.content.tasks
            table.insert(peer_list, message.sender.character)
            table.sort(peer_list)
        else
            -- Silently ignore data from unknown senders
        end
    end
end
```

## How It Works Now

**Scenario: Two groups running independent HUDs**

Group 1: Vexxusz (master) + Lumarra, Thornwick (collectors)
Group 2: Malrik (master) + Sparkles, Twiggle (collectors)

When Vexxusz runs `/yalm2quest`:
1. Known_collectors = ["Lumarra", "Thornwick"]
2. Vexxusz sends REQUEST_TASKS
3. Lumarra and Thornwick respond with INCOMING_TASKS
4. Vexxusz receives:
   - INCOMING_TASKS from Lumarra → CHECK: Is "Lumarra" in known_collectors? YES → ACCEPT
   - INCOMING_TASKS from Thornwick → CHECK: Is "Thornwick" in known_collectors? YES → ACCEPT
   - INCOMING_TASKS from Sparkles → CHECK: Is "Sparkles" in known_collectors? NO → REJECT

Simultaneously, Malrik's HUD works independently:
1. Known_collectors = ["Sparkles", "Twiggle"]
2. Accepts data from his collectors only
3. Never sees Group 1's data

## Result
- Each group's HUD only shows that group's members' quests
- Actors communicate freely within each group
- No cross-group pollution
- Works with raid or group
- Works with solo characters (no collectors to track)

## Note
The `is_character_in_our_group()` function still exists but is no longer used in the actor handler. It may be referenced elsewhere in the codebase for other purposes.
