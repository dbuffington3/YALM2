# Quest Cache Cleanup - Clear Both Tables at Startup

## Problem
The system tracks quest items in two tables, both of which accumulate data across sessions:
- **quest_tasks**: Stores character task progress (which items they need, status)
- **quest_objectives**: Caches the objective text for each item (populated by fuzzy matching)

### Why Both Need Clearing

**quest_objectives** (the fuzzy-match cache):
- Becomes stale if matching logic changes
- Needs fresh matching on each session for accuracy
- Clear it at startup: ✓

**quest_tasks** (the progress data):
- Accumulates entries for completed quests that never get deleted
- Queries filter for `status NOT LIKE 'Done'` so old entries are ignored anyway
- Characters repush their current task status on every refresh (which replaces all their entries)
- Database bloat issue: Without clearing, completed entries accumulate indefinitely
- Clear it at startup: ✓ (will be immediately repopulated on next refresh)

**The Realization**: Both tables should be treated as session caches, not persistent storage, because:
1. All data will be regenerated immediately on next refresh
2. Persisting old completed entries just wastes space and provides no value
3. Keeping it clean prevents database bloat

## The Two Tables

### quest_objectives Table (FUZZY-MATCH CACHE)
- **Stores**: Cached objective text from fuzzy matching
- **Data**: item_name → objective_text mappings
- **Lifecycle**: Populated by fuzzy matcher during "refresh", cleared at startup
- **Purpose**: Performance optimization - cache the objective text matching
- **Clearing**: YES - at startup to ensure fresh matching

### quest_tasks Table (PROGRESS DATA)
- **Stores**: Character task progress - who needs which items, their completion status
- **Data**: character, item_name, status, objective (text field)
- **Lifecycle**: Built up during each refresh when characters push their tasks
- **Purpose**: Aggregate "what items do we need right now" across all characters
- **Clearing**: YES - at startup to prevent database bloat
- **Why cleared**: All queries filter for `status NOT LIKE 'Done'` anyway, so old completed entries are never used but accumulate indefinitely

## How The UI Works

The Database tab displays items currently in quest_tasks. With both tables cleared at startup:

**Startup sequence**:
```
Startup:
  ├─ DELETE FROM quest_objectives ✓ (clear fuzzy-match cache)
  └─ DELETE FROM quest_tasks ✓ (clear old task data)

Later, during "refresh":
  ├─ Characters push their current task status
  │  └─ Populates quest_tasks with active items
  ├─ Fuzzy matcher matches objective text
  │  └─ Populates quest_objectives
  └─ UI joins tables and displays matched objectives

UI Display**:
  ├─ Before refresh: "Database is empty"
  └─ After refresh: Shows all items with objective text
```

## Solution Implemented

Both tables are now cleared at startup:

```lua
function quest_db.clear_objective_cache()
    -- Clear fuzzy-match cache for fresh matching
    db:exec("DELETE FROM quest_objectives")
    Write.Info("[QuestDB] Cleared quest_objectives cache for fresh matching")
    
    -- Clear task data to prevent database bloat
    -- Will be immediately repopulated during next refresh
    db:exec("DELETE FROM quest_tasks")
    Write.Info("[QuestDB] Cleared quest_tasks - will be repopulated on refresh")
    
    return true
end
```

**Called at**: System startup (yalm2_native_quest.lua line 88-89)

**Why this works**:
1. Clears all stale/completed data
2. Prevents database bloat from accumulating unused entries
3. All data regenerated immediately on next refresh anyway
4. Fresh start each session = predictable, clean state

## Database Lifecycle

### Before Fix
```
Session 1:
  Startup → No clear
  Refresh → quest_tasks has 30 items
  Shutdown → All data persists

Session 2:
  Startup → No clear
  quest_tasks still has 30 old items
  └─ 20 completed, 10 active (only active ones used)
  
Session 3, 4, 5...
  quest_tasks grows to 100s of entries
  Database bloat - most never used
```

### After Fix
```
Session 1:
  Startup → DELETE both tables
  Refresh → Characters push current tasks
  └─ quest_tasks has only active items
  Shutdown → Data persists (ok, it's fresh)

Session 2:
  Startup → DELETE both tables (clean slate)
  quest_tasks is empty
  Refresh → Characters push current tasks again
  └─ Only active items in database
  
Session 3, 4, 5...
  Always starts clean
  No database bloat
  Predictable state
```

## When This Runs

**Trigger**: At system startup in `yalm2_native_quest.lua` (lines 88-89)

```lua
-- At initialization, before any UI or quest processing
quest_db.clear_objective_cache()  -- Clears BOTH tables
quest_db.verify_cache_clear()
```

**Frequency**: Once per session startup

**Impact**: Minimal - quick DELETE queries, negligible performance impact

## Log Messages

**Startup logs will show**:
```
[QuestDB] Cleared quest_objectives cache for fresh matching
[QuestDB] Cleared quest_tasks - will be repopulated on refresh
```

## What Gets Cleared

**CLEARED at startup**:
- quest_objectives: All entries (fuzzy-match cache)
- quest_tasks: All entries (task progress data)

**PRESERVED**: Nothing - both tables start fresh each session

**Why both**:
1. quest_objectives needs to be fresh (may have stale fuzzy matches from previous session)
2. quest_tasks can be safely cleared because:
   - Characters will repush their current task status immediately on refresh anyway
   - Queries filter for active items only (`status NOT LIKE 'Done'`)
   - Completed entries just waste space and accumulate indefinitely
   - Starting fresh prevents database bloat

## Testing Checklist

- [ ] Start system → Both tables empty at startup
- [ ] Check Database tab → Shows "Database is empty"
- [ ] Run "refresh" → Characters push tasks
- [ ] Check Database tab → Shows active items with objective text
- [ ] Restart system → Tables cleared again (clean start)
- [ ] Run refresh again → Same items reappear (data regenerates)

---

**Status**: CORRECTED - Both tables should be cleared at startup  
**Reason**: Prevents database bloat, ensures fresh data each session, all data regenerates anyway  
**User Benefit**: Clean database, no accumulation of completed entries, predictable state each session
