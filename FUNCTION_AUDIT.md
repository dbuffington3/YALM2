# YALM2 Function Usage Audit

## DEPRECATED: core/tasks.lua Functions

**Status**: ❌ **NOT USED - DEPRECATED MODULE**

This module contains external task system functions that are no longer called. Imported in:
- `init.lua` line 25
- `core/looting.lua` line 6

**Actual Usage in looting.lua**: ZERO - imported but never called
- Search pattern `tasks.` in looting.lua yields NO matches
- This is a dead import

**Functions in module** (all unused):
- `tasks.initialize()`
- `tasks.send_task_to_actor()`
- `tasks.handle_task_event()`
- `tasks.get_task_status()`
- And dozens more - ALL UNUSED

**Action**: Safe to remove. This entire module can be deleted.

---

## QUESTIONABLE: quest_db and quest_data_store Usage

These modules are imported widely but usage is inconsistent. Need deeper audit.

### quest_db.lua Usage
**Locations**:
- `core/looting.lua` line 12
- `core/native_tasks.lua` line 12
- `yalm2_native_quest.lua` line 68

**Actual Function Calls Found**:
- `quest_db.increment_quantity_received()` - called in looting.lua line 120
- Need to check for other calls

### quest_data_store.lua Usage
**Locations**:
- `core/quest_interface.lua` line 7
- `core/native_tasks.lua` line 11
- `yalm2_native_quest.lua` line 67

**Status**: Imported but unclear if functions are called

---

## Module Dependency Analysis

### Modules Imported But Potentially Unused

```
core/looting.lua:
  ✓ evaluate - USED (evaluate.determine_final_preference)
  ✓ inventory - USED (inventory functions for tracking)
  ✗ tasks - NOT USED (dead import)
  ✓ quest_interface - USED (quest detection)
  ✓ dannet - USED (DanNet communication)
  ✓ utils - USED (utility functions)
  ✓ debug_logger - USED (logging)
  ✓ quest_db - USED (quest_db.increment_quantity_received)

core/evaluate.lua:
  ✓ configuration - USED
  ✓ settings - USED
  ✓ inventory - USED
  ✓ Item - USED
  ✓ database - USED
  ✓ dannet - USED
  ✓ utils - USED
  ✓ Write - USED
  ✓ debug_logger - USED
  ✓ quest_interface - USED (quest detection)

init.lua:
  ✗ tasks - NOT USED (dead import - init.lua loads tasks but tasks isn't used in init.lua itself)
  ✓ native_tasks - USED
  ✓ quest_interface - USED
  ✓ looting - USED
  ✓ loader - USED
```

---

## Clean Imports vs Bloated Imports

### init.lua - Bloated
```lua
line 25: local tasks = require("yalm2.core.tasks")  -- ❌ NEVER USED
```
**Action**: Remove this line

### core/looting.lua - Has one dead import
```lua
line 6: local tasks = require("yalm2.core.tasks")  -- ❌ NEVER USED (no tasks. calls)
```
**Action**: Remove this line

### core/native_tasks.lua - Need to verify
Imports quest_db and quest_data_store - need to check actual usage

### yalm2_native_quest.lua - Need to verify
Imports quest_db and quest_data_store - need to check actual usage

---

## Confirmed Safe for Removal

| Module | Location | Status | Reason |
|--------|----------|--------|--------|
| `core/tasks.lua` | `/core/` | ❌ Unused | Entire external task system deprecated |
| `tasks` import in init.lua | line 25 | ❌ Dead | Never referenced |
| `tasks` import in looting.lua | line 6 | ❌ Dead | Never referenced |

---

## Files Needing Deeper Audit

1. **core/native_tasks.lua** - Check which functions are actually called
2. **yalm2_native_quest.lua** - Check which functions are actually called
3. **core/quest_interface.lua** - Check which functions are actually called
4. **lib/quest_database.lua** - Check which functions are called
5. **lib/quest_data_store.lua** - Check which functions are called

---

## Next Steps

### Immediate (SAFE):
1. Delete `core/tasks.lua` - confirmed not imported anywhere that uses it
2. Remove `local tasks = require(...)` from init.lua line 25
3. Remove `local tasks = require(...)` from core/looting.lua line 6

### Requires Verification:
1. Scan for all calls to quest_db functions
2. Scan for all calls to quest_data_store functions
3. Identify unused functions in each module
4. Document which functions in each module are ACTUALLY called vs defined

### Requires Function Analysis:
For each of these modules, list:
- Total functions defined
- Functions that are actually called
- Functions that are never called (dead code)
- Candidates for removal

Modules to analyze:
- core/native_tasks.lua
- core/quest_interface.lua
- lib/quest_database.lua
- lib/quest_data_store.lua
