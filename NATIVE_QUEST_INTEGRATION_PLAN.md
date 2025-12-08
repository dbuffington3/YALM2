# Native Quest System Integration Plan

## Current State
- ✅ Created `core/native_tasks.lua` with TaskHUD's proven quest detection logic
- ✅ Native character discovery via DanNet
- ✅ Self-contained quest system (no external script dependencies)

## Integration Steps

### Phase 1: Basic Integration
1. **Modify `init.lua`** - Load native_tasks module instead of external TaskHUD communication
2. **Update `core/tasks.lua`** - Replace TaskHUD calls with native_tasks calls  
3. **Test Master Looter Only** - Verify quest detection works for single character
4. **Add quest item extraction** - Apply existing patterns to native task data

### Phase 2: Multi-Character Support  
1. **Deploy quest logic to all clients** - Each character can run native quest detection locally
2. **DanNet orchestration** - Master looter triggers quest updates on all connected characters
3. **Completeness validation** - Ensure we get responses from all expected characters
4. **Retry mechanism** - Re-query characters that don't respond

### Phase 3: Command Interface
1. **Add `/yalm2 taskrefresh`** - Force refresh of all character quest data
2. **Add `/yalm2 taskstatus`** - Show current quest item needs across all characters  
3. **Add `/yalm2 taskinfo`** - Display quest completion status for debugging

### Phase 4: Reliability Enhancements
1. **Character presence detection** - Alert when characters are missing expected quests
2. **Quest sync verification** - Detect when characters have different quest states
3. **Automatic retry** - Re-attempt failed character queries
4. **Fallback modes** - Graceful degradation when some characters are unavailable

## Benefits Over External TaskHUD
- ✅ **Full Control** - No inter-script communication timing issues
- ✅ **Reliability** - Know exactly which characters we queried and got responses from  
- ✅ **Completeness** - Can verify we have data from all expected characters
- ✅ **Retry Logic** - Can re-query specific characters that failed
- ✅ **Unified System** - Quest detection and loot distribution in single system
- ✅ **Real-time Updates** - Can trigger quest refreshes exactly when needed

## Implementation Priority
1. **Phase 1** - Get basic native quest detection working (single character)
2. **Test extensively** - Ensure quest item extraction works correctly
3. **Phase 2** - Add multi-character support gradually  
4. **Validate reliability** - Confirm it's more reliable than external TaskHUD
5. **Phase 3 & 4** - Add convenience features and robustness

## Migration Strategy
- Keep existing TaskHUD code as fallback during transition
- Add configuration option to choose native vs external TaskHUD
- Extensive testing before full switchover
- Ability to revert if issues arise