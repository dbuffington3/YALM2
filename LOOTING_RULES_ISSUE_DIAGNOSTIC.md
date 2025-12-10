# Looting Rules Issue - Diagnostic Summary

## Current State
✅ **Fixed**: Database namespace collision (Database → YALM2_Database)
❌ **Problem**: Items being left on corpse (looting rules not working)

## Evidence from Log

### What's Happening:
1. YALM2_Database is initialized and working (queries show valid results)
2. Items are being detected and queried (Orbweaver Silk ID 17596 found correctly)
3. BUT: `[YALM]:: No loot preference found for Orbweaver Silk`

### Key Observation:
The error message has `[YALM]::` prefix, not `[YALM2]::`. This means:
- The OLD YALM system is interfering with loot decisions
- Old YALM is looking for rules and not finding them (because they're in YALM2 namespace)
- This is blocking the looting process

## Root Causes to Investigate

### 1. Old YALM Interference
- Old YALM native quest system may still be running
- It's trying to process loot before YALM2
- May need to completely disable old YALM quest system

### 2. Looting Rules Not Matching Items
- Rules may not exist for items being looted
- Rule names may not match item names exactly
- Database vs. actual item names may differ

### 3. Preference System Broken
- `get_loot_preference()` may not be finding matching rules
- Loader may not be loading rules correctly
- Rules may be in wrong location or format

### 4. Configuration Settings
- `use_native_quest_system` setting may be wrong
- Quest interface routing may be broken
- Settings may not be persisting

## Next Steps to Diagnose

1. **Check Rules Exist**
   ```
   /yalm2 check Orbweaver Silk
   /yalm2 edit Orbweaver Silk
   ```

2. **Verify Settings**
   - Check if use_native_quest_system is enabled
   - Check if global_settings is loading correctly
   - Verify character-specific settings

3. **Check Old YALM Status**
   - Verify old YALM isn't still processing loot
   - Check if native quest system is disabled
   - May need to unload old YALM completely

4. **Test Preferences**
   - Add temporary debug logging to preference system
   - Check if rules are being found
   - Verify preference matching logic

5. **Review Logs**
   - Search for all "No loot preference" messages
   - See which rules are missing
   - Check error patterns

## Items Left on Corpse (From User Statement)

The user mentioned items with value were left:
- Need to check which specific items
- Check if those items have rules configured
- Verify if rules are enabled/active
- Check if preference system is evaluating them

## Architecture Check

The issue may be:
1. **Old YALM running and blocking**: Need to stop old YALM completely
2. **Rules not loaded**: Need to verify loader.lua is working with YALM2_Database rename
3. **Preference evaluation**: Need to check evaluate.lua calling correct rules
4. **Config not persisted**: Need to verify settings are loading

## Testing Strategy

Once we diagnose:
1. Fix root cause
2. Create test rules for common quest items
3. Test with /yalm2 simulate
4. Verify actual loot distribution
5. Check no items left on corpse

## Commit Status
✅ Namespace collision fix committed to git
📝 Ready to debug looting rules

## Questions for User

1. Are there any rules configured for quest items?
2. Is the old YALM system still active (`/yalm` status)?
3. Should we completely disable old YALM?
4. Which specific items were left on corpse?

