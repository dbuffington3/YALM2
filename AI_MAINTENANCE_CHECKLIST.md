# 📌 AI MAINTENANCE CHECKLIST

This file provides critical reminders for maintaining YALM2 codebase consistently.

## 🔒 LOCKED CODE SECTIONS - DO NOT MODIFY

### 1. Default Loot Distribution Log Message
**Reason**: User explicitly requested this message be protected from automatic changes  
**Files**: `core/looting.lua` (2 locations)  
**Related Doc**: `LOOT_MESSAGE_LOCKED.md`

**Current Format** (as of 2025/12/14):
```
[timestamp] [YALM2]:: <item> KEPT → <character> <reason>
```

**Before making ANY changes**:
- [ ] Read `LOOT_MESSAGE_LOCKED.md`
- [ ] Verify user explicitly requested the change
- [ ] Show proposed format to user FIRST
- [ ] Only modify if user confirms
- [ ] Update the safeguard document

---

## ✅ Implementation Checklist

When implementing features or fixes:

- [ ] Check if there are any LOCKED sections affecting this code
- [ ] Read all safeguard documents before editing
- [ ] Verify changes don't accidentally modify locked sections
- [ ] If locked section must change: confirm with user first
- [ ] Document any new locked sections immediately

---

## 📚 Safeguard Documents

These documents should ALWAYS be checked before code modifications:

1. **`LOOT_MESSAGE_LOCKED.md`** - Log message format protection
2. **`LOG_MESSAGE_SAFEGUARD.md`** - Additional safeguard details (deprecated, use LOOT_MESSAGE_LOCKED.md)

---

## 📝 Update Frequency

Update this file whenever:
- New safeguard sections are needed
- Locked code sections change
- User provides maintenance reminders
- Major refactoring affects critical paths

---

Last Updated: 2025/12/14
