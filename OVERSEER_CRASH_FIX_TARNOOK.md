# Overseer Crash Fix - Tarnook (January 1, 2026)

**Issue:** Overseer crashed with nil value error in `SelectNextDuplicateAgent` function  
**Affected Character:** Tarnook (bristle)  
**Crash Time:** 2026/01/01 01:02:54  
**Status:** ✅ FIXED

---

## Problem Analysis

### Crash Details
```
[2026/01/01 01:02:54] [Overseer.lua] SelectNextDuplicateAgent: count label is nil

C:\MQ2\lua\overseer\overseer.lua:1825: attempt to call field 'Siblings' (a nil value)
stack traceback:
  C:\MQ2\lua\overseer\overseer.lua:1825: in function 'SelectNextDuplicateAgent'
  C:\MQ2\lua\overseer\overseer.lua:1733: in function 'ProcessConversionQuest'
  C:\MQ2\lua\overseer\overseer.lua:1843: in function 'ProcessConversion'
  C:\MQ2\lua\overseer\overseer.lua:1090: in function 'RunConversions'
  C:\MQ2\lua\overseer\overseer.lua:326: in function 'RunCompleteCycle'
  C:\MQ2\lua\overseer\overseer.lua:67: in function 'Main'
```

### Root Cause

The issue occurred in the `SelectNextDuplicateAgent()` function at **line 1825**:

**BEFORE (Buggy Code):**
```lua
::nextAgentOrReturn::
if (NODE ~= nil and NODE.Siblings()) then
    NODE = NODE.Next
    goto nextAgent
end
```

**The Problem:**
1. When the `countLabel` check failed at line 1799, the code jumped to `nextAgentOrReturn`
2. At that point, `NODE` could be in a state where it had no `Siblings` method
3. The condition `NODE ~= nil and NODE.Siblings()` fails when:
   - `NODE.Siblings` is nil (the method doesn't exist)
   - Lua tries to call nil, causing the crash

**Why it wasn't caught before:**
- The code checked `NODE ~= nil` but didn't check if `NODE.Siblings` itself existed
- When `NODE.Siblings` is nil (doesn't exist), Lua still tries to call it as a function
- This is different from `NODE` being nil

---

## Solution Applied

**AFTER (Fixed Code):**
```lua
::nextAgentOrReturn::
if (NODE ~= nil) then
    if (NODE.Siblings ~= nil and NODE.Siblings()) then
        NODE = NODE.Next
        goto nextAgent
    end
end

return false
end
```

**Changes Made:**
1. ✅ Added explicit nil check for `NODE` first
2. ✅ Added explicit nil check for `NODE.Siblings` method before calling it
3. ✅ Safely returns false if either NODE or its Siblings method is nil
4. ✅ Prevents nil value errors in edge cases

---

## Why This Fix Works

### Before (Vulnerable to Crash)
- Single combined condition: `NODE ~= nil and NODE.Siblings()`
- If NODE exists but Siblings method doesn't, it crashes
- No protection against nil methods

### After (Safe Against Nil)
- First checks: Is NODE itself nil? If so, skip the whole block
- Second checks: Does NODE.Siblings method exist? If not, skip calling it
- Safely handles all edge cases

---

## Technical Explanation

### The Issue
In Lua, when you use `and` (short-circuit evaluation):
```lua
if (NODE ~= nil and NODE.Siblings()) then
```

- If `NODE ~= nil` is **false**, Lua stops and doesn't evaluate the second part ✅
- If `NODE ~= nil` is **true**, Lua evaluates `NODE.Siblings()`
- **BUT**: If `NODE.Siblings` is nil (doesn't exist as a method), Lua crashes ❌

### The Fix
By checking the method exists FIRST:
```lua
if (NODE ~= nil) then
    if (NODE.Siblings ~= nil and NODE.Siblings()) then
        -- Only executed if both NODE and Siblings method exist
    end
end
```

- First condition: Is NODE actually an object? ✅
- Second condition: Does NODE have a Siblings method? ✅
- Call: Now it's safe to call NODE.Siblings() ✅

---

## What Was Happening in Context

When Tarnook's overseer was running the conversion quest cycle:

1. **At 01:02:45:** Successfully processed several quests
2. **At 01:02:54:** Attempted to find duplicate agents for conversion
3. **Issue:** The UI element for agent count label was nil or empty
4. **Action:** Code logged error and jumped to cleanup
5. **Crash:** While cleaning up, tried to iterate to next agent but NODE.Siblings was nil
6. **Result:** Lua crash - Script ended with status -1

---

## Files Changed

**File:** `C:\MQ2\lua\overseer\overseer.lua`  
**Lines:** 1824-1831  
**Change Type:** Bug fix - Nil value protection

---

## Testing Recommendations

After this fix, Tarnook should:
1. ✅ No longer crash on conversion quests with missing agents
2. ✅ Gracefully skip conversion if no valid agents found
3. ✅ Continue running overseer cycles without interruption
4. ✅ Log appropriate error messages without crashing

---

## Summary

**Status:** ✅ FIXED  
**Type:** Nil value protection  
**Severity:** Critical (causes script crash)  
**Impact:** Overseer can now handle edge cases safely  
**Testing:** Recommend running overseer cycle test

The fix adds proper nil checking to prevent the crash when NODE or its Siblings method is nil. This is a defensive programming fix that makes the code more robust against edge cases.
