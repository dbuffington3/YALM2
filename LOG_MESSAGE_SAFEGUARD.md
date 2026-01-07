# ⚠️ CRITICAL: DEFAULT LOG MESSAGE - DO NOT MODIFY

## Location: `core/looting.lua` - Lines 689-701

### The Official Default Log Message

```lua
Write.Info("\a-t%s\ax KEPT → \ao%s\ax %s", item_name, member.Name(), looting.get_keep_reason(preference))
```

### This EXACT message format MUST NOT be changed

**DO NOT** modify without explicit user request.

This message is the **standard default logging output** for the loot system and is used as the baseline for debugging and testing. 

### Why This Matters

1. **Debugging**: User references logs to understand loot behavior
2. **Testing**: Automated tests and log parsing depend on this format
3. **Support**: User support and issue diagnosis relies on consistent format
4. **History**: Changes to this message create duplicates and confusion in logs

### If Changes Are Needed

**The user MUST explicitly request changes** with:
- Specific reason for change
- Exact new format desired
- Confirmation that this is intentional

### Current Format (as of 2025/12/14)

```
[timestamp] [YALM2]:: <item_name> KEPT → <character_name> <reason>
```

**Example**:
```
[2025/12/14 07:57:17] [YALM2]:: Snake Head KEPT → Vexxuss configured preference
```

### Previous Format (DEPRECATED - DO NOT USE)

```
[timestamp] [YALM2]:: <item_name> KEPT - <reason>
[timestamp] [YALM2]:: Looting <item_name> → <character_name>
[timestamp] [YALM2]:: Looting <item_name>
```

This created 3 separate lines and was confusing.

---

**Status**: Official default log format  
**Last Modified**: 2025/12/14  
**Do Not Change Without User Approval**
