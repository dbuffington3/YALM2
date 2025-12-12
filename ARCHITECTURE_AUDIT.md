# YALM2 Architecture Audit - Module Usage Analysis

## Executive Summary
This document identifies all Lua modules in the codebase and their actual usage status. The system has evolved from external task coordination to native quest detection only. Many modules contain legacy code that may no longer be used.

---

## CORE ACTIVE MODULES (MUST KEEP)

### 1. `yalm2_native_quest.lua` - Main Coordinator Script
**Status**: ✅ **ACTIVE - PRIMARY ENTRY POINT**
- Location: `/root/yalm2_native_quest.lua`
- Purpose: Standalone quest coordinator (replaces TaskHUD)
- Key Functions:
  - `extract_quest_item_from_objective()` - Pattern matching for quest items
  - `parse_progress_status()` - Parse task progress strings
  - `manual_refresh_with_messages()` - Process quest data with logging
  - `cmd_yalm2quest()` - Command handler
- Dependencies: quest_interface, native_tasks, database
- Usage: Runs continuously as standalone script

### 2. `core/quest_interface.lua` - Quest Detection Interface
**Status**: ✅ **ACTIVE - CRITICAL**
- Purpose: Unified interface for quest item detection
- Key Functions:
  - `find_matching_quest_item()` - Fuzzy matching of extracted item names to database
  - `is_quest_item()` - Check if item is a quest item
- Dependencies: native_tasks, database
- Recent Changes: Now receives database reference explicitly via initialize()
- Active Usage: Called for EVERY looted item to validate quest status

### 3. `core/native_tasks.lua` - Native Quest System Module
**Status**: ✅ **ACTIVE - CRITICAL**
- Purpose: Native quest data extraction from game UI
- Key Functions:
  - `initialize()` - Setup module
  - `is_quest_item()` - Database validation
  - `get_tasks()` - Extract tasks from TaskWnd UI
  - `get_characters_needing_item()` - Get character list needing quest items
- Dependencies: database
- Usage: Core quest item detection and character determination

### 4. `lib/database.lua` - SQLite Database Interface
**Status**: ✅ **ACTIVE - CRITICAL**
- Purpose: MQ2LinkDB database access
- Key Functions:
  - `OpenDatabase()` - Initialize SQLite connection
  - Database queries for item validation
- Dependencies: None (native SQLite binding)
- Usage: EVERY item lookup uses this for questitem flag validation

---

## LEGACY/DEPRECATED MODULES (LIKELY UNUSED)

### 1. `core/tasks.lua` - External Task System
**Status**: ❌ **DEPRECATED - REMOVE**
- Purpose: External task coordination (OLD system)
- Contains: Old matching functions, external actor logic
- Why Deprecated: Replaced by native_tasks.lua
- Current Status: NOT imported or used anywhere
- Action: **CANDIDATE FOR REMOVAL**

### 2. `lib/quest_database.lua` - Quest Item Storage
**Status**: ❓ **UNCLEAR USAGE**
- Purpose: Local quest item caching
- Contains: Store/retrieve quest items
- Usage Status: Imported in yalm2_native_quest.lua but unclear if actively used
- Action: **AUDIT NEEDED** - Check if actually called

### 3. `lib/quest_data_store.lua` - Data Persistence
**Status**: ❓ **UNCLEAR USAGE**
- Purpose: Store quest data
- Imported in: quest_interface.lua
- Usage Status: Imported but no active calls visible
- Action: **AUDIT NEEDED** - Remove if unused

---

## CONFIG/SETUP MODULES (SUPPORT)

### 1. `config/configuration.lua`
**Status**: ✅ **ACTIVE - SETTINGS**
- Purpose: Configuration defaults and setup

### 2. `config/settings.lua`
**Status**: ✅ **ACTIVE - USER SETTINGS**
- Purpose: Load/save user preferences

### 3. `config/state.lua`
**Status**: ✅ **ACTIVE - STATE TRACKING**
- Purpose: Track system state

### 4. `config/defaults/` - Default Configuration
**Status**: ✅ **ACTIVE - DEFAULTS**
- Various default settings files

### 5. `config/commands/` - Command Definitions
**Status**: ✅ **ACTIVE - COMMANDS**
- Command registration and handlers

---

## UTILITY MODULES (SUPPORT)

### 1. `lib/Write.lua` - Logging System
**Status**: ✅ **ACTIVE - ESSENTIAL**
- Purpose: Formatted logging output
- Usage: Used throughout codebase for Write.Info, Write.Error, Write.Debug

### 2. `lib/debug_logger.lua` - Debug Logging
**Status**: ✅ **ACTIVE - DIAGNOSTICS**
- Purpose: Detailed debug logging
- Usage: Used for detailed diagnostic output

### 3. `lib/inspect.lua` - Table Inspection
**Status**: ✅ **ACTIVE - DEBUGGING**
- Purpose: Pretty-print Lua tables
- Usage: Debugging and table visualization

### 4. `core/evaluate.lua` - Condition Evaluation
**Status**: ✅ **ACTIVE**
- Purpose: Evaluate loot conditions
- Usage: Used in loot rule processing

### 5. `core/helpers.lua` - Helper Functions
**Status**: ✅ **ACTIVE**
- Purpose: Utility functions
- Usage: Core functionality helpers

### 6. `core/inventory.lua` - Inventory Management
**Status**: ✅ **ACTIVE**
- Purpose: Inventory tracking
- Usage: Item distribution tracking

### 7. `core/looting.lua` - Loot Processing
**Status**: ✅ **ACTIVE - CRITICAL**
- Purpose: Main loot processing and distribution
- Usage: Called on every loot event

### 8. `core/loot_simulator.lua` - Loot Testing
**Status**: ✅ **ACTIVE - TEST SUPPORT**
- Purpose: Simulate loot for testing
- Usage: Optional testing/debugging

---

## DEFINITIONS/DATA FILES

### 1. `definitions/Classes.lua`
**Status**: ✅ **ACTIVE**
- Purpose: Class definitions and constants

### 2. `definitions/InventorySlots.lua`
**Status**: ✅ **ACTIVE**
- Purpose: Inventory slot constants

### 3. `definitions/Item.lua`
**Status**: ✅ **ACTIVE**
- Purpose: Item data structure definitions

### 4. `definitions/ItemTypes.lua`
**Status**: ✅ **ACTIVE**
- Purpose: Item type constants and mappings

---

## DIAGNOSTIC MODULES (TESTING ONLY)

### 1. `diagnostics/dannet_discovery.lua`
**Status**: ❌ **NOT USED IN PRODUCTION**
- Purpose: DanNet discovery testing
- Used Only For: Debugging actor communication
- Action: Can keep for future use, no impact

### 2. All `test_*.lua` files
**Status**: ❌ **TEST FILES ONLY**
- Purpose: Various testing scripts
- Action: Can archive/remove after audit complete

---

## CRITICAL DEPENDENCY CHAIN

```
yalm2_native_quest.lua (MAIN)
├── core/quest_interface.lua ✅
│   ├── core/native_tasks.lua ✅
│   │   └── lib/database.lua ✅
│   └── lib/database.lua ✅
├── core/looting.lua ✅
│   ├── core/native_tasks.lua ✅
│   └── core/evaluate.lua ✅
├── lib/Write.lua ✅
├── config/settings.lua ✅
└── config/configuration.lua ✅
```

---

## UNUSED/QUESTIONABLE MODULES

| Module | Status | Reason | Action |
|--------|--------|--------|--------|
| `core/tasks.lua` | ❌ Deprecated | Replaced by native_tasks | REMOVE |
| `lib/quest_database.lua` | ❓ Unclear | Imported but unused calls? | AUDIT |
| `lib/quest_data_store.lua` | ❓ Unclear | Imported but unused? | AUDIT |
| Various test_*.lua files | ❌ Test only | For debugging | ARCHIVE |
| `diagnostics/dannet_discovery.lua` | ❌ Test only | For debugging | ARCHIVE |

---

## NEXT STEPS FOR CLEANUP

### Phase 1: Audit
1. Grep all imports to find unused modules
2. Check if quest_database.lua is actually called
3. Check if quest_data_store.lua is actually called
4. List all test files that can be archived

### Phase 2: Remove Deprecated
1. Delete `core/tasks.lua` (confirmed unused)
2. Archive all test_*.lua files
3. Archive `diagnostics/dannet_discovery.lua`

### Phase 3: Remove Unused Found in Audit
1. Delete any modules that import but never call
2. Clean up stale function definitions

### Phase 4: Documentation
1. Update README with actual module list
2. Document critical dependency chain
3. Create architecture diagram

---

## Active Imports Summary

**Files that MUST stay:**
- yalm2_native_quest.lua
- core/quest_interface.lua
- core/native_tasks.lua
- lib/database.lua
- core/looting.lua
- lib/Write.lua
- config/*.lua

**Files that CAN be removed:**
- core/tasks.lua (deprecated)
- test_*.lua (test files)
- diagnostics/dannet_discovery.lua (test file)

**Files needing audit:**
- lib/quest_database.lua
- lib/quest_data_store.lua
