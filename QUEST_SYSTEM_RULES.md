# YALM2 Native Quest System - Critical Rules and Documentation

## DO NOT IGNORE THESE RULES - THEY PREVENT RECURRING BUGS!

### 1. DATA STRUCTURE FIELD NAMES (MOST IMPORTANT!)

**ALWAYS USE:**
- `task.task_name` (NOT `task.name`)
- `objective.objective` (NOT `objective.text`)

**WHY:** These are the exact field names created by `get_tasks()` function. All code must match.

**WHERE TO CHECK:**
- UI display code (lines ~430-450)
- Manual refresh function (lines ~500-600) 
- Automatic processing (lines ~730-800)

### 2. DATA SOURCE CONSISTENCY

**RULE:** All processing functions must use `task_data.tasks[character_name]`

**WHY:** This is the same data source the UI uses. It's populated by DanNet actor messages from all characters.

**NEVER:** Create separate data sources or use different variables.

### 3. MESSAGE SYSTEM SEPARATION  

**Manual Refresh:**
- User-facing messages with taskheader formatting
- Called when user types `/lua run yalm2/yalm2_native_quest refresh`
- Shows results with print() statements

**Automatic Processing:**
- Silent operation every 3 seconds
- Only Write.Debug() for troubleshooting
- NO user-facing messages or print() statements

### 4. LUA PATTERN SAFETY

**PROBLEM:** Lua patterns like `%w`, `%s` conflict with `string.format()`

**SOLUTION:** Use `print(string.format(...))` directly, NOT `Write.Info()` when patterns are involved

**EXAMPLE:**
```lua
-- WRONG - causes format errors
Write.Info("Found pattern: " .. pattern)

-- RIGHT - safe for patterns  
print(string.format("[YALM2] Found pattern match: %s", item_name))
```

### 5. DEBUGGING CHECKLIST

**If quest items aren't found:**
1. Check field names first (`objective.objective` vs `objective.text`)
2. Verify data source (`task_data.tasks` consistency)
3. Check pattern matching (lua patterns vs string.format)
4. Verify message systems aren't mixed

**If format errors occur:**
1. Look for lua patterns in Write.Info/Write.Debug calls
2. Use print() + string.format() for pattern-containing strings
3. Check for `%w`, `%s`, `%d` in message strings

### 6. MODIFICATION WORKFLOW

**BEFORE CHANGING ANYTHING:**
1. Read the architecture documentation at top of file
2. Identify which system you're modifying (UI, manual, automatic)
3. Check field name consistency across all systems
4. Verify message system separation

**AFTER MAKING CHANGES:**
1. Test manual refresh with `/lua run yalm2/yalm2_native_quest refresh`
2. Check logs for format errors
3. Verify quest items are detected properly
4. Ensure no message spam in automatic processing

### 7. COMMON ERROR PATTERNS

**"invalid option '%w' to 'format'"**
- Cause: Lua pattern passed to Write.Info()
- Fix: Use print() + string.format() directly

**"Quest items not found"**
- Cause: Wrong field names (objective.text vs objective.objective)
- Fix: Use objective.objective everywhere

**"Log spam every 3 seconds"**
- Cause: User messages in automatic processing
- Fix: Remove Write.Info/print from automatic section

**"UI shows data but manual refresh doesn't"**
- Cause: Different data sources or field names
- Fix: Use same task_data.tasks and field names

### 8. TESTING COMMANDS

```
/lua run yalm2/yalm2_native_quest refresh    # Test manual refresh
/lua run yalm2/yalm2_native_quest show       # Show UI
/lua run yalm2/yalm2_native_quest hide       # Hide UI  
/lua run yalm2/yalm2_native_quest stop       # Stop script
```

### 9. LOG MONITORING

**Check for errors:**
```powershell
Get-Content "C:\MQ2\logs\bristle_vexxuss.log" -Tail 30
```

**Look for:**
- Format errors with lua patterns
- Field name mismatches  
- Message spam from automatic processing
- Quest item detection success/failure

---

## REMEMBER: Follow these rules to prevent the same bugs from recurring!

The most common issues are:
1. Wrong field names (objective.text vs objective.objective)
2. Format errors with lua patterns
3. Mixed message systems
4. Inconsistent data sources

Check these FIRST when debugging quest system issues.