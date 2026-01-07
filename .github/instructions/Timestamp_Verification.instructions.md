---
applyTo: '**'
---

# CRITICAL: ALWAYS VERIFY TIMESTAMPS - NEVER ASSUME RELOAD STATUS

## MANDATORY RULE - NO EXCEPTIONS:

**BEFORE suggesting "the script wasn't reloaded" or any variation:**

1. **CHECK FILE MODIFICATION TIME:**
   ```powershell
   Get-Item "path\to\file.lua" | Select-Object Name, LastWriteTime
   ```

2. **CHECK LOG TIMESTAMPS:**
   ```powershell
   Get-Content "C:\MQ2\logs\yalm2_debug.log" | Select-Object -Last 5
   ```

3. **COMPARE TIMES** - If log entries are AFTER file modification time, the script WAS reloaded.

4. **NEVER SAY:**
   - "The script wasn't reloaded"
   - "YALM2 needs to be reloaded" 
   - "Make sure to reload"
   - Any assumption about reload status

5. **INSTEAD:**
   - Verify timestamps first
   - If timestamps confirm reload, investigate the ACTUAL bug
   - Trust that the user reloaded when they say they did

## THIS RULE OVERRIDES ALL OTHER DEBUGGING ASSUMPTIONS

The user ALWAYS reloads the script. If debug output is missing, it's because:
- The code has a bug
- The function isn't being called
- There's an early return preventing the log
- The logic is wrong

**NEVER** blame reload status without checking timestamps.
