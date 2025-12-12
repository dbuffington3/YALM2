# YALM2 Cleanup Roadmap - Future Phases

Now that external TaskHUD system is removed, here are the next cleanup opportunities.

## Phase 2: Unused Functions (Estimated)

After removing the entire tasks.lua module and external system, there may be orphaned functions in other modules that were only called by the external system.

### High Priority

#### 1. quest_data_store.lua Functions
**Potentially unused:**
- `get_quest_data()` (line 48) - Returns `quest_items` (not `quest_items_with_qty`)
- `is_data_valid(max_age_ms)` (line 55) - Data validation function
- `clear()` (line 69) - Clear cached data

**Why**: May have been used only by external TaskHUD system

**Verification needed**: Search codebase for these function calls

#### 2. Native Tasks "backwards compat" functions
Check `core/native_tasks.lua` for functions that were added for external system compatibility:
- Look for functions that "bridge" to external system
- Check function signatures for unused parameters

**Recommendation**: Audit and remove compatibility layers

### Medium Priority

#### 3. Configuration Commands Related to Task System
Check `config/commands/` for commands that were TaskHUD-specific:
- Commands that toggled between systems (already removed nativequest)
- Commands that pushed tasks to external system
- Commands that refreshed external task data

**Files to check:**
- push_tasks.lua
- refresh.lua

#### 4. Unused Condition/Helper Modules
Check `config/conditions/` and `config/helpers/`:
- Conditions that check TaskHUD states
- Helpers that format for external system
- Conditions based on `use_native_quest_system` setting

### Low Priority

#### 5. Test Files
Archive test files that were only for TaskHUD:
- test_*.lua files that test external system
- Diagnostic scripts for TaskHUD debugging

**Candidates for archiving:**
- test_dannet_*.lua (if TaskHUD-only)
- test_actor_*.lua (if only for TaskHUD actors)
- diagnostics/dannet_discovery.lua (might be test-only)

---

## Phase 3: Dead Code Removal

After identifying unused functions, remove:

1. **Unused functions within modules** - Functions defined but never called
2. **Unused parameters** - Function parameters that aren't used
3. **Dead code paths** - Conditional branches that are never taken
4. **Orphaned comments** - Comments referring to removed systems

---

## Phase 4: Code Consolidation

Once dead code is removed:

1. **Consolidate similar functions** - If multiple functions do nearly the same thing
2. **Simplify quest_interface.lua** - Remove helper functions that were for compatibility
3. **Optimize native_tasks.lua** - Remove workarounds that were for fallback support
4. **Clean up looting.lua** - Remove special cases that were for external system

---

## Phase 5: Documentation & Architecture

1. **Update architecture diagrams** - Remove TaskHUD references
2. **Update module documentation** - Document actual usage patterns
3. **Create data flow diagrams** - Show quest detection flow (now simplified)
4. **Update README** - Reflect native-only system
5. **Document remaining modules** - What they do and why

---

## Cleanup Checklist Template

For each cleanup phase, use this checklist:

```
[ ] Identify target modules/functions
[ ] Document current usage in codebase
[ ] Create backup/branch for changes
[ ] Remove/refactor identified code
[ ] Verify no broken imports
[ ] Test functionality
[ ] Update documentation
[ ] Commit with clear message
[ ] Deploy and monitor logs
```

---

## Estimated Impact by Phase

| Phase | Scope | Effort | Risk | Value |
|-------|-------|--------|------|-------|
| 2 | Remove unused functions | Medium | Low | High |
| 3 | Remove dead code | Small | Low | Medium |
| 4 | Consolidate functions | Medium | Medium | Medium |
| 5 | Documentation | Small | None | Medium |

---

## Priority Ranking

**MUST DO (before production use):**
1. ✅ Remove external TaskHUD system (DONE)
2. Verify quest system works with new code

**SHOULD DO (cleanup):**
3. Audit quest_data_store.lua for unused functions
4. Check native_tasks.lua for compat code
5. Archive TaskHUD-only test files

**NICE TO HAVE (optimization):**
6. Consolidate similar functions
7. Remove dead code paths
8. Update documentation

---

## Monitoring After Each Phase

After each cleanup phase:

1. **Check logs** for any unexpected behavior
2. **Test core functionality** - quest detection and distribution
3. **Monitor for errors** - 24+ hours of normal operation
4. **Check performance** - any improvement or regression?

---

## Success Criteria

Codebase will be cleaner when:

- ✅ No dead code or unused functions
- ✅ No import cycles or broken references
- ✅ Clear module dependencies
- ✅ Documented function usage
- ✅ No legacy workarounds
- ✅ Single, clear code path for each feature

---

## Related Documents

- ARCHITECTURE_AUDIT.md - Full module usage audit
- FUNCTION_AUDIT.md - Function-level analysis
- CLEANUP_PHASE_1.md - Phase 1 completion status
- TASKHUD_REMOVAL_COMPLETE.md - TaskHUD removal details

---

**Status**: PLANNING PHASE - Ready for Phase 2 when needed
**Last Updated**: 2025-12-11
**Maintainer**: Agent (Assistant)
