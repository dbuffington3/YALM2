# Write Module Prefix Fix - [YALM]:: Mystery Solved

## Problem Identified

After renaming the old YALM folder to yalm_original, the mysterious `[YALM]::` messages in logs were still appearing even though:
- No YALM system was running (verified in Lua process manager)
- No references to old yalm.* namespace existed in code
- No errors occurred when old folder was renamed

## Root Cause

**Module Caching in Lua**: When a module is required multiple times, Lua caches it. The Write module was being cached with its original prefix value of `[YALM]::` from an earlier initialization.

Flow:
1. Old YALM system (or old initialization) loads Write module with prefix `[YALM]::`
2. Lua caches the module globally
3. YALM2 loads Write module, gets the cached version with `[YALM]::` prefix
4. init.lua fixes it: `Write.prefix = "[YALM2]::"`
5. BUT: yalm2_native_quest.lua (separate script) loads Write, gets cached version with old prefix
6. native_tasks.lua doesn't set the prefix either
7. Result: `[YALM]::` messages in all quest-related logs

## Solution

Add Write.prefix fix to both standalone scripts:

### yalm2_native_quest.lua (Line 67)
```lua
local Write = require("yalm2.lib.Write")

-- Fix the Write prefix to show YALM2 instead of YALM (due to module caching from older YALM system)
Write.prefix = "\at[\ax\apYALM2\ax\at]\ax"
```

### core/native_tasks.lua (Line 13)
```lua
local Write = require("yalm2.lib.Write")

-- Fix the Write prefix to show YALM2 instead of YALM (due to module caching from older YALM system)
Write.prefix = "\at[\ax\apYALM2\ax\at]\ax"
```

## Files Changed
- yalm2_native_quest.lua - Added Write.prefix fix after require
- core/native_tasks.lua - Added Write.prefix fix after require

## Why This Works

- Direct assignment of Write.prefix overrides the cached default value
- Happens immediately after module load, before any logging
- Both standalone and embedded scripts now set correct prefix
- No actual code references old YALM system needed

## Verification

After these changes, all `[YALM]::` messages should become `[YALM2]::` in logs.

## Lesson Learned

When using globals/module-level variables:
1. Be aware of Lua module caching
2. If inheriting from old code, override cached values explicitly
3. Standalone scripts that load modules should set their own defaults
4. Comment why defaults are being overridden (for future maintenance)

