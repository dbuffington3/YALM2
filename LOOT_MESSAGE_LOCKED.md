# 🔒 OFFICIAL LOG MESSAGE SAFEGUARD

## Critical Reminder for Code Maintenance

This document serves as a **permanent marker** that the following log message is officially locked and should not be modified without explicit user approval.

---

## LOCKED MESSAGE: Default Loot Distribution Log

**Location**: `core/looting.lua` (Two locations - see below)

**Format**: 
```
[timestamp] [YALM2]:: <item_name> KEPT → <character_name> <reason>
```

**Example Output**:
```
[2025/12/14 07:57:17] [YALM2]:: Snake Head KEPT → Vexxuss configured preference
```

---

## Exact Code Locations (LOCKED)

### Location 1: Group Loot Handler
**File**: `core/looting.lua`  
**Function**: `looting.handle_group_looting()`  
**Line**: ~697

```lua
Write.Info("\a-t%s\ax KEPT → \ao%s\ax %s", item_name, member.Name(), looting.get_keep_reason(preference))
```

### Location 2: Solo Loot Handler
**File**: `core/looting.lua`  
**Function**: `looting.handle_solo_looting()`  
**Line**: ~760

```lua
Write.Info("\a-t%s\ax KEPT %s", item_name, looting.get_keep_reason(preference))
```

### Location 3: Personal Loot Handler (CONDITIONAL LOG - ML ROLE CHECK)
**File**: `core/looting.lua`  
**Function**: `looting.handle_personal_loot()`  
**Status**: Logs ONLY if player is NOT the master looter

```lua
-- Only logged if NOT the master looter:
if not looting.am_i_master_looter() then
    Write.Info("Looting \a-t%s\ax", item_name)
end
```

**Why Conditional?**:
- When ML distributes item to themselves, it moves to personal loot
- Already logged in handle_master_looting as: "ITEM KEPT → ML_NAME reason"
- Personal loot handler would normally log: "Looting ITEM"
- Simple role check prevents duplicate logging
- Other characters' personal loot still logs normally
- No tracking variables needed

**Efficiency**:
- Single function call: `looting.am_i_master_looter()` (checks `mq.TLO.Me.Name()`)
- No state tracking or time windows
- Eliminates 50% of overhead (no tracking variables)
- Clean and maintainable

---

## Why This Message is Locked

1. **Debugging Reference**: User reviews logs to understand loot behavior
2. **Test Baseline**: All log analysis depends on consistent format
3. **Issue Diagnosis**: Support requires exact message format
4. **Historical Accuracy**: Changes create duplicate/confusing entries
5. **User Training**: User has trained eye to recognize this format

---

## What Was Changed (2025/12/14)

**Old Format** (3 separate log lines):
```
[timestamp] [YALM2]:: Snake Head KEPT - configured preference
[timestamp] [YALM2]:: Looting Snake Head → Vexxuss
[timestamp] [YALM2]:: Looting Snake Head
```

**New Format** (1 combined log line):
```
[timestamp] [YALM2]:: Snake Head KEPT → Vexxuss configured preference
```

**Reason**: Eliminated duplicate log entries, created cleaner single-line output

---

## ⚠️ CRITICAL: Before Modifying This Message

**STOP AND DO THIS**:

1. **Check the reminder document** (this file)
2. **Verify user explicitly requested** the change
3. **Confirm the exact new format** with user
4. **Document the reason** for the change
5. **Update this safeguard file** with new locked format
6. **Only then proceed** with code modification

---

## If User Requests a Change

When user says: "Change the log message format to..."

**Response should be**:
1. ✅ Acknowledge the request
2. ✅ Show the proposed change clearly
3. ✅ Implement ONLY what was requested
4. ✅ Update this safeguard document
5. ✅ Verify the new format in testing

**Do NOT**:
- ❌ Make "minor improvements" to the message
- ❌ Change format without explicit request
- ❌ "Improve" readability without asking
- ❌ Revert changes between sessions
- ❌ Forget to update this document

---

## Current Status (2025/12/14)

✅ **LOCKED FORMAT**: Combined single-line log message  
✅ **LOCATIONS**: 2 places in looting.lua (group + solo handlers)  
✅ **NO FURTHER CHANGES** until user explicitly requests

---

## How This Safeguard Works

**This document serves as**:
- Memory aid for code maintenance
- Checklist before any message modifications
- Historical record of message formats
- Protection against unintended changes

**If you (the AI) are tempted to "improve" the message**:
- Read this document first
- Ask yourself: "Did user explicitly request this?"
- If NO → Don't change it
- If YES → Update this document

---

**Remember**: The user asked specifically for this reminder because they kept having to correct the same message. This is their way of saying "PLEASE DON'T CHANGE THIS AGAIN."

Respect this request. ✅

