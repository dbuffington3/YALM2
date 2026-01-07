# Multi-Group Quest Filtering - Visual Summary

## The Problem (Before)

```
Group 1 Setup:
├─ Vexxuss (Master, runs HUD)
├─ Lumarra
└─ Thornwick

Group 2 Setup (separate):
├─ Bristle
├─ Twiggle
└─ Sparkles

All connected via DanNet

Result on Vexxuss's HUD:
├─ Vexxuss's quests
├─ Lumarra's quests
├─ Thornwick's quests
├─ Bristle's quests ❌ WRONG - shouldn't see
├─ Twiggle's quests ❌ WRONG - shouldn't see
└─ Sparkles's quests ❌ WRONG - shouldn't see
```

## The Solution (After)

```
Same Setup, but with filtering:

Vexxuss sends REQUEST_TASKS to all DanNet peers
↓
All peers respond with INCOMING_TASKS messages
↓
New Filter Check: is_character_in_our_group(sender)
├─ Vexxuss? YES (self) → STORE ✓
├─ Lumarra? YES (in group) → STORE ✓
├─ Thornwick? YES (in group) → STORE ✓
├─ Bristle? NO (not in group) → IGNORE ✗
├─ Twiggle? NO (not in group) → IGNORE ✗
└─ Sparkles? NO (not in group) → IGNORE ✗

Result on Vexxusz's HUD:
├─ Vexxus's quests ✓
├─ Lumarra's quests ✓
└─ Thornwick's quests ✓

Group 2 never appears!
```

## Group/Raid Priority Logic

```
is_character_in_our_group(name)?

┌─ Is it me?
│  YES → Return TRUE
│  NO ↓
├─ mq.TLO.Raid.Members() > 0?
│  YES → Check raid member list
│    ├─ Found in raid? → Return TRUE
│    └─ Not found in raid? → Return FALSE
│  NO ↓
├─ mq.TLO.Group.Members() > 0?
│  YES → Check group member list
│    ├─ Found in group? → Return TRUE
│    └─ Not found in group? → Return FALSE
│  NO ↓
└─ Solo?
   → Return FALSE (only self included, already checked above)
```

## Data Flow

### Message Collection (yalm2_native_quest.lua)

```
DanNet Message: INCOMING_TASKS from "Bristle"
↓
Actor handler receives message
↓
Check: if is_character_in_our_group("Bristle") then
├─ NO → Execute: Write.Debug("ACTOR: Ignored quest data from Bristle...")
└─ DONE - message dropped, storage skipped
```

### Loot Distribution (core/quest_interface.lua)

```
Item dropped: "Rune of Sorcery"
↓
Looting system calls: quest_interface.get_characters_needing_item("Rune of Sorcery")
↓
Native tasks returns: ["Vexxuss", "Lumarra", "Thornwick", "Bristle", "Sparkles"]
↓
FOR EACH character in list:
├─ Vexxuss: is_character_in_our_group("Vexxuss")? YES → INCLUDE
├─ Lumarra: is_character_in_our_group("Lumarra")? YES → INCLUDE
├─ Thornwick: is_character_in_our_group("Thornwick")? YES → INCLUDE
├─ Bristle: is_character_in_our_group("Bristle")? NO → EXCLUDE
└─ Sparkles: is_character_in_our_group("Sparkles")? NO → EXCLUDE
↓
Return: ["Vexxuss", "Lumarra", "Thornwick"]
↓
Looting system only considers these 3 for distribution
```

## Implementation Locations

### Location 1: Quest Data Collection
**File:** `yalm2_native_quest.lua`
**Lines:** 320-354 (new function), 371-378 (modified handler)
**Type:** Actor message filtering

```lua
local function is_character_in_our_group(character_name)
    -- [Logic shown above]
end

elseif message.content.id == 'INCOMING_TASKS' then
    if drawGUI == true then
        if is_character_in_our_group(message.sender.character) then
            -- Store task data
            task_data.tasks[message.sender.character] = message.content.tasks
        else
            -- Ignore out-of-group data
            Write.Debug("ACTOR: Ignored quest data from %s (not in our group/raid)", ...)
        end
    end
end
```

### Location 2: Loot Distribution
**File:** `core/quest_interface.lua`
**Lines:** 163-199 (new function), 201-225 (modified function)
**Type:** Quest item distribution filter

```lua
quest_interface.get_characters_needing_item = function(item_name)
    local chars = native_tasks.get_characters_needing_item(item_name)
    
    local filtered_chars = {}
    for _, char_name in ipairs(chars) do
        if is_character_in_our_group(char_name) then
            table.insert(filtered_chars, char_name)
        end
    end
    
    return filtered_chars
end
```

## Raid vs Group Distinction

```
Scenario 1: In a RAID
┌─ Check: mq.TLO.Raid.Members() > 0
│  YES (we're in a raid)
│  └─ Look ONLY at raid members
│     ├─ Raid member "Lumarra"? → Include
│     ├─ Group member "Bristle"? → Exclude (not in raid)
│     └─ This is correct - raid takes full priority
└─ Never check group members if in raid

Scenario 2: In a GROUP (not in raid)
┌─ Check: mq.TLO.Raid.Members() > 0
│  NO (not in raid)
│  Check: mq.TLO.Group.Members() > 0
│  YES (we're in a group)
│  └─ Look ONLY at group members
│     ├─ Group member "Lumarra"? → Include
│     ├─ DanNet peer "Bristle"? → Exclude (not in group)
│     └─ This is correct - group limits visibility
└─ Never check raid if we're not in one

Scenario 3: SOLO
┌─ Check: mq.TLO.Raid.Members() > 0
│  NO
│  Check: mq.TLO.Group.Members() > 0
│  NO
│  └─ Only include yourself
│     └─ This is correct - only self needs items
```

## Debug Output Examples

### Accepting Group Members
```
[YALM2] ACTOR: Accepted quest data from Vexxuss (in our group/raid)
[YALM2] ACTOR: Accepted quest data from Lumarra (in our group/raid)
[YALM2] ACTOR: Accepted quest data from Thornwick (in our group/raid)
```

### Rejecting Out-of-Group Members
```
[YALM2] ACTOR: Ignored quest data from Bristle (not in our group/raid)
[YALM2] ACTOR: Ignored quest data from Twiggle (not in our group/raid)
[YALM2] ACTOR: Ignored quest data from Sparkles (not in our group/raid)
```

### Loot Distribution Filtering
```
[YALM2] QUEST_INTERFACE: Including Vexxuss (in our group/raid)
[YALM2] QUEST_INTERFACE: Including Lumarra (in our group/raid)
[YALM2] QUEST_INTERFACE: Excluding Bristle (not in our group/raid)
```

## File Modifications Summary

| File | Lines | Change | Impact |
|------|-------|--------|--------|
| yalm2_native_quest.lua | 320-354 | Add `is_character_in_our_group()` | Quest data collection |
| yalm2_native_quest.lua | 371-378 | Filter INCOMING_TASKS | Primary filter point |
| core/quest_interface.lua | 163-199 | Add `is_character_in_our_group()` | Loot distribution |
| core/quest_interface.lua | 201-225 | Filter `get_characters_needing_item()` | Secondary safety check |

## New Files Created

| File | Purpose |
|------|---------|
| test_multigroup_filtering.lua | Test script to verify filtering behavior |
| MULTI_GROUP_QUEST_FILTERING.md | Complete technical documentation |
| MULTI_GROUP_IMPLEMENTATION_COMPLETE.md | Implementation details and testing guide |

## Testing Quick Reference

### View Debug Logs
```
/yalm2 loglevel debug
/yalm2 nativequest
```

### Test Script
```
/lua run yalm2\test_multigroup_filtering
```

### Search Logs for Filtering
```
Get-Content "C:\MQ2\logs\[character]_[server].log" | Select-String "ACTOR.*group" -Context 1,1
```

## Key Takeaways

✅ **Two Filters:**
1. Quest data collection filters out-of-group messages
2. Loot distribution filters out-of-group recipients

✅ **Raid Priority:**
- Raid members are always checked first
- Group only checked if not in raid

✅ **No Data Loss:**
- Database still has all history
- Filtering at display/distribution time
- Can easily revert if needed

✅ **Backward Compatible:**
- Single group: no change
- Solo: no change
- Multi-group: now works correctly

✅ **Debug Visibility:**
- All filtering decisions logged
- Easy to troubleshoot
- Can see exactly what's being accepted/rejected
