# Quest Cache Refresh - Quick Reference

## The Issue
Quest objectives are cached in the `quest_objectives` database table to avoid re-matching them repeatedly. However, when a quest advances to the next stage (previous stage marked "Done"), the objectives change but the cache wasn't being cleared on manual refresh.

**Current Cache State**: 1 cached entry (Treant Bark from "It Only Gets Worse" Stage 1)

## The Fix
Added one line to `manual_refresh_with_messages()`:
```lua
quest_db.clear_objective_cache()
```

This line is now called FIRST in the function, before any task data processing.

## User Experience Impact

### Before (Broken)
1. User advances quest stage (marks stage as "Done")
2. New objectives become visible in task window
3. User clicks "Refresh Quest Data" button
4. System still shows old cached objective
5. New objectives not discovered ❌

### After (Fixed)  
1. User advances quest stage (marks stage as "Done")
2. New objectives become visible in task window
3. User clicks "Refresh Quest Data" button
4. **Cache is cleared**
5. System re-scans ALL objectives from scratch
6. New objectives are discovered and cached ✓

## Performance Notes

- **Automatic refresh** (every 3 seconds): Still uses cached data, no slowdown
- **Manual refresh** (user button click): Slightly slower now because cache is cleared, but this is acceptable and expected

## Where to Test
1. Advance quest to next stage (mark current stage "Done")
2. Click "Refresh Quest Data" in YALM2 UI
3. Check logs for: "Cleared quest objectives cache for fresh matching"
4. New objectives should appear in quest data

## Technical Details
- **Function Modified**: `manual_refresh_with_messages()` in `yalm2_native_quest.lua`
- **Cache Function Used**: `quest_db.clear_objective_cache()` from `lib/quest_database.lua`
- **Cache Table**: `quest_objectives` in `quest_tasks.db`
- **Automatic Calls**: User-initiated only (NOT on automatic loops)

## Related Files
- `yalm2_native_quest.lua` - Main quest coordinator (where fix is applied)
- `lib/quest_database.lua` - Database functions (includes clear_objective_cache)
- `quest_tasks.db` - SQLite database (contains quest_objectives table)
