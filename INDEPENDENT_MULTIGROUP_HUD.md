# Multi-Group Independent HUD Implementation

## Problem Solved

**Previous Issue:**
When two separate groups tried to run the quest HUD:
- Group 1 Master (Vexxuss) starts HUD with `/yalm2quest`
- Group 2 Master (Bristle) starts HUD with `/yalm2quest`
- Group 1's HUD disappears because `/dge` command stopped it

**Root Cause:**
The original code used `/dge` (all except self) globally, which affected ALL connected DanNet peers, not just the intended group.

## Solution: Group-Isolated HUD Architecture

### Key Change: Use `/dquery` Instead of `/dge`

**Before (Global, Conflict-Prone):**
```lua
mq.cmd('/dge /lua stop yalm2/yalm2_native_quest')    -- Stops ALL except self
mq.cmd('/dge /lua run yalm2/yalm2_native_quest nohud')  -- Starts on ALL except self
```

**After (Group-Isolated, Multi-Safe):**
```lua
if raid_count > 0 then
    for i = 1, raid_count do
        local member = mq.TLO.Raid.Member(i)
        if member and member.DisplayName():lower() ~= my_name:lower() then
            -- Start ONLY on actual raid members
            mq.cmd(string.format('/dquery %s /lua run yalm2/yalm2_native_quest nohud', member.DisplayName()))
        end
    end
elseif group_count > 0 then
    for i = 1, group_count do
        local member = mq.TLO.Group.Member(i)
        if member and member.DisplayName():lower() ~= my_name:lower() then
            -- Start ONLY on actual group members
            mq.cmd(string.format('/dquery %s /lua run yalm2/yalm2_native_quest nohud', member.DisplayName()))
        end
    end
end
```

### How It Works

```
GROUP 1: Vexxuss (Master) + Lumarra + Thornwick
GROUP 2: Bristle (Master) + Twiggle + Sparkles

Scenario: Both groups run /yalm2quest simultaneously

Step 1: Vexxuss runs "/yalm2quest"
  ├─ Vexxuss: drawGUI = true (creates HUD window)
  ├─ Uses /dquery to target ONLY Lumarra and Thornwick
  ├─ Lumarra: drawGUI = false (runs as collector)
  └─ Thornwick: drawGUI = false (runs as collector)

Step 2: Bristle runs "/yalm2quest"
  ├─ Bristle: drawGUI = true (creates HUD window)
  ├─ Uses /dquery to target ONLY Twiggle and Sparkles
  ├─ Twiggle: drawGUI = false (runs as collector)
  └─ Sparkles: drawGUI = false (runs as collector)

Result:
✅ Vexxusz's HUD shows Group 1 quests only (quest data filtered by group membership)
✅ Bristle's HUD shows Group 2 quests only (quest data filtered by group membership)
✅ No conflicts between the two groups
✅ Both groups operate independently
```

## Implementation Details

### File Modified
- `yalm2_native_quest.lua` - Lines 1656-1696

### Function: `check_args()`

**Purpose:**
Initializes the script as either:
- **Master** (with HUD): Runs on the character who executes `/yalm2quest`
- **Collector** (no HUD): Runs on group/raid members to feed quest data to master

**Key Logic:**

1. **Detect Group/Raid Membership**
   ```lua
   local raid_count = mq.TLO.Raid.Members() or 0
   local group_count = mq.TLO.Group.Members() or 0
   ```

2. **Start Collectors on Group Members Only**
   - If in raid: Loop through raid members, use `/dquery` on each
   - If in group: Loop through group members, use `/dquery` on each
   - Skip self (master is already running)
   - Skip out-of-group DanNet peers (they'll have their own group's master)

3. **Stagger the Starts**
   ```lua
   mq.delay(500)  -- Space out the /dquery commands
   ```

4. **Set drawGUI Flag**
   - Master: `drawGUI = true` → Creates ImGui window
   - Collector: `drawGUI = false` → No window, just feeds data

### Data Flow

```
┌─────────────────────────────────────────────────────────┐
│ MASTER HUD WINDOW (Vexxusz)                             │
│  ┌──────────────────────────────────────────────────┐   │
│  │ YALM2 Native Quest##Vexxusz                      │   │
│  │ ┌─ Tasks ─ Database ─ Failed ──────────────────┐ │   │
│  │ │ Vexxusz's quests (from my_tasks)             │ │   │
│  │ │ Lumarra's quests (from collectors)           │ │   │
│  │ │ Thornwick's quests (from collectors)         │ │   │
│  │ └────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         ↑                          ↑                  ↑
    drawGUI = true         Filtered by group    Shown to user
                          membership (see
                          multi-group filtering)

┌─────────────────────────────────────────────────────────┐
│ COLLECTORS (Lumarra, Thornwick)                         │
│  └─ drawGUI = false                                     │
│  └─ Send task data via actor messages                  │
│  └─ Only visible to master's actor handler             │
│  └─ Filtered by is_character_in_our_group()            │
└─────────────────────────────────────────────────────────┘
         ↓
    task_data.tasks (populated only with group members)
         ↓
    YALM2 variables (quest item names/characters)
         ↓
    Looting system (distributes quest items)
```

## Multi-Group Operation Example

### Setup
```
Zone A:
  Group 1 Master: Vexxuzz
  Group 1 Members: Lumarra, Thornwick
  
Zone B (different zone, separate group):
  Group 2 Master: Bristle
  Group 2 Members: Twiggle, Sparkles

All characters: Connected via DanNet
```

### Starting Both Groups

**On Vexxuzz:**
```
/yalm2quest
```
Output:
```
[YALM2 Native Quest] Starting as master HUD for Vexxuzz
[YALM2 Native Quest] Managing group with 2 members
[YALM2 Native Quest] starting for Vexxuzz. Use /yalm2quest help for commands.
```

Script Actions:
1. `drawGUI = true` → Creates HUD window for Vexxuzz
2. `/dquery Lumarra /lua run yalm2/yalm2_native_quest nohud`
3. `/dquery Thornwick /lua run yalm2/yalm2_native_quest nohud`
4. Vexxuzz's HUD is ready

**On Bristle:**
```
/yalm2quest
```
Output:
```
[YALM2 Native Quest] Starting as master HUD for Bristle
[YALM2 Native Quest] Managing group with 2 members
[YALM2 Native Quest] starting for Bristle. Use /yalm2quest help for commands.
```

Script Actions:
1. `drawGUI = true` → Creates HUD window for Bristle
2. `/dquery Twiggle /lua run yalm2/yalm2_native_quest nohud`
3. `/dquery Sparkles /lua run yalm2/yalm2_native_quest nohud`
4. Bristle's HUD is ready

### Result

Both HUD windows are visible and independent:
- **Vexxuzz's HUD**: Shows quests for Vexxuzz, Lumarra, Thornwick only
- **Bristle's HUD**: Shows quests for Bristle, Twiggle, Sparkles only

Each HUD window is named uniquely:
- `YALM2 Native Quest##Vexxusz`
- `YALM2 Native Quest##Bristle`

These appear as separate ImGui windows that don't interfere.

## Detailed Changes

### Old Code (Lines 1656-1677)
```lua
local function check_args()
    if #args == 0 then
        mq.cmd('/dge /lua stop yalm2/yalm2_native_quest')       -- ❌ Stops all except self
        mq.delay(2000)
        mq.cmd('/dge /lua run yalm2/yalm2_native_quest nohud')  -- ❌ Starts all except self
        drawGUI = true
        triggers.do_refresh = true
    else
        for _, arg in pairs(args) do
            if arg == 'nohud' then
                drawGUI = false
            elseif arg == 'debug' then
                debug_mode = true
                mq.cmd('/dgga /lua run yalm2\\yalm2_native_quest nohud')
                drawGUI = true
                triggers.do_refresh = true
            end
        end
    end
end
```

### New Code (Lines 1656-1696)
```lua
local function check_args()
    if #args == 0 then
        -- Master instance - start collectors on GROUP/RAID MEMBERS ONLY
        mq.cmd(string.format('/echo %s \\aoStarting as master HUD for %s', taskheader, my_name))
        
        -- Detect group/raid
        local raid_count = mq.TLO.Raid.Members() or 0
        local group_count = mq.TLO.Group.Members() or 0
        
        if raid_count > 0 then
            mq.cmd(string.format('/echo %s \\aoManaging raid with %d members', taskheader, raid_count))
            for i = 1, raid_count do
                local member = mq.TLO.Raid.Member(i)
                if member and member.DisplayName() and member.DisplayName():lower() ~= my_name:lower() then
                    mq.cmd(string.format('/dquery %s /lua run yalm2/yalm2_native_quest nohud', member.DisplayName()))
                    mq.delay(500)
                end
            end
        elseif group_count > 0 then
            mq.cmd(string.format('/echo %s \\aoManaging group with %d members', taskheader, group_count))
            for i = 1, group_count do
                local member = mq.TLO.Group.Member(i)
                if member and member.DisplayName() and member.DisplayName():lower() ~= my_name:lower() then
                    mq.cmd(string.format('/dquery %s /lua run yalm2/yalm2_native_quest nohud', member.DisplayName()))
                    mq.delay(500)
                end
            end
        else
            mq.cmd(string.format('/echo %s \\aoSolo mode', taskheader))
        end
        
        drawGUI = true
        triggers.do_refresh = true
    else
        -- Collector instance
        for _, arg in pairs(args) do
            if arg == 'nohud' then
                drawGUI = false
            elseif arg == 'debug' then
                debug_mode = true
                drawGUI = true
                triggers.do_refresh = true
            end
        end
    end
end
```

**Key Differences:**
1. ❌ Removed `/dge` and `/dgga` commands
2. ✅ Added explicit loop through group/raid members
3. ✅ Used `/dquery` to target specific members only
4. ✅ Added informational messages showing who's being managed
5. ✅ Graceful handling of solo mode

## Compatibility

### With Group Filtering (Previous Update)
- ✅ Works together perfectly
- `check_args()` ensures only group members get started
- `is_character_in_our_group()` filters the collected data
- Double protection against cross-group data pollution

### Raid vs Group
- If in a raid: Only raid members get collectors
- If in a group: Only group members get collectors
- Raid takes priority (matches earlier filter logic)

### Solo Play
- No collectors started
- Master runs with HUD alone
- Works as expected

## Testing Multi-Group

### Prerequisite
Make sure both groups have the group/raid filtering from the previous update!

### Test Scenario

1. **Setup:**
   - Group 1: Vexxuzz (A), Lumarra (A), Thornwick (A)
   - Group 2: Bristle (B), Twiggle (B), Sparkles (B)
   - All connected via DanNet

2. **On Vexxuzz:**
   ```
   /yalm2quest
   ```
   Verify: HUD window appears with "YALM2 Native Quest##Vexxuzz" title

3. **On Bristle:**
   ```
   /yalm2quest
   ```
   Verify: New HUD window appears with "YALM2 Native Quest##Bristle" title
   Both windows are visible!

4. **Accept quests on both groups**

5. **Verify HUDs:**
   - Vexxusz's HUD: Shows only Group 1 quests ✅
   - Bristle's HUD: Shows only Group 2 quests ✅
   - No overlap between groups ✅

6. **Drop quest items and verify loot:**
   - Quest items only go to group members ✅
   - Never attempt to give to other group ✅

## Troubleshooting

### "HUD only appears for last group"
- This should now be fixed
- Each master gets its own ImGui window
- Check that both scripts are running: `/echo $${Defined(yalm2_native_quest_loaded)}`

### "Collectors not starting"
- Verify group/raid membership: `/grouproster` or `/raididroster`
- Check debug logs for collector start messages
- Verify DanNet connectivity: `/dquery [member] Me.Name`

### "Still seeing cross-group quests"
- Ensure you have the group membership filtering from the previous update
- Check debug logs for filtering messages
- Verify `/yalm2 loglevel debug` shows exclusion messages

## Performance Impact

- Minimal: Just loops through group/raid members (3-24 people max)
- No database queries
- No additional processing

## Backwards Compatibility

- ✅ Single group: Works as before (just targets actual group members)
- ✅ Raid: Works as before (just targets actual raid members)
- ✅ Solo: Works as expected (no collectors)

## Future Enhancements

1. **Raid Sub-Groups:** Could split raid display by sub-group
2. **Manual Collector:** Allow specific characters to run as collectors without being in group
3. **Multi-Master Sync:** Could sync HUD between multiple masters (complex)
