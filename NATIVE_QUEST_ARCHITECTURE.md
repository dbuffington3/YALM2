# YALM2 Native Quest System - Multi-Script Architecture

## Overview

The YALM2 Native Quest System now uses a multi-script architecture similar to TaskHUD, with a master script on the main character and lightweight companion scripts on all other characters.

## Architecture

### Master Script: `yalm2` (Main Character)
**File**: `init.lua`
**Purpose**: Full YALM2 functionality with native quest system
**Responsibilities**:
- Complete loot management system
- Native quest detection and item tracking
- Coordinates with task collectors on other characters
- Makes all loot distribution decisions

### Companion Scripts: `task_collector` (Other Characters)
**File**: `task_collector.lua`  
**Purpose**: Lightweight task collection only
**Responsibilities**:
- Monitors local character's tasks using TaskHUD's UI method
- Responds to task data requests from master
- Automatic task update detection via events
- Minimal resource usage

## Setup Instructions

### 1. Master Character Setup (Only Required Step!)
```
/lua run yalm2
```
This runs the full YALM2 system and **automatically starts collectors on all group/raid members**.

### 2. Verification Commands
**Master Character**:
```
/yalm2 taskinfo status    # Check task data collection
/yalm2 nativequest        # Toggle native quest system
```

**Collector Characters**:
```
/yalmcollector status     # Check collector status
/yalmcollector refresh    # Force task refresh
/yalmcollector shutdown   # Stop collector
```

## Communication Flow

1. **Startup**: Master validates DanNet connectivity to all group/raid members
2. **Auto-Deploy**: Master automatically starts task collectors on all remote characters via `/dgga`
3. **Initialization**: Collectors register with master via actor messages
4. **Task Request**: Master sends `YALM2_REQUEST_TASKS` via actors to all collectors
5. **Task Collection**: Each collector uses TaskHUD's proven UI method to extract tasks
6. **Response**: Collectors send `YALM2_TASK_RESPONSE` with task data back to master
7. **Processing**: Master combines all task data and extracts quest items
8. **Updates**: Collectors automatically detect task updates and refresh data
9. **Cleanup**: Master automatically shuts down collectors when YALM2 exits

## Advantages over Single Script + /dex

### ✅ Reliability
- Persistent collectors eliminate script execution failures
- Built-in retry logic and error handling
- Automatic task update detection

### ✅ Performance  
- No repeated script loading/execution overhead
- Cached task data with intelligent refresh intervals
- Parallel communication via actors

### ✅ Maintainability
- Clear separation of concerns
- Consistent with TaskHUD's proven architecture
- Easier debugging and monitoring

### ✅ Scalability
- Works with any group/raid size
- Minimal resource usage on companion characters
- Graceful handling of character disconnections

## Troubleshooting

### Master Not Getting Task Data
1. Check if collectors are running: `/dex [character] /yalmcollector status`
2. Verify actor communication: Check for `YALM2_TASK_RESPONSE` messages
3. Test DanNet connectivity: `/yalm2 dannetdiag`

### Collector Not Responding
1. Restart collector: `/dex [character] /lua run yalm2\task_collector`
2. Check for task window issues: Manual `/tasks` command
3. Verify character has active tasks: `/dquery [character] Task.Count`

### Quest Items Not Detected
1. Force task refresh: `/yalmcollector refresh` on all collectors
2. Check task extraction: `/yalm2 taskinfo items`
3. Verify quest item patterns in code

## Migration from External TaskHUD

The native quest system completely replaces external TaskHUD dependencies:

- **Before**: YALM2 → TaskHUD (separate script) → Actor messages
- **After**: YALM2 Master → Task Collectors (integrated) → Actor messages

This eliminates the external script dependency while maintaining the proven TaskHUD task collection method and communication patterns.