---
applyTo: '**'
---

# PowerShell Syntax Rules

## CRITICAL: Select-String with Context Lines

**NEVER use `-A` flag with piping to Select-Object. ALWAYS use `-Context` instead.**

### ❌ WRONG (produces unbound pipeline errors):
```powershell
Get-Content file.log | Select-String "pattern" -A 50 | Select-Object -First 60
```

### ✅ CORRECT (use -Context instead):
```powershell
Get-Content "C:\path\to\file.log" | Select-String "pattern" -Context 0,50
```

### Explanation:
- `-A` (After) parameter outputs array elements that don't bind properly to `Select-Object`
- `-Context 0,50` outputs proper objects that can be piped
- Format: `-Context <lines_before>,<lines_after>`
- Use `0,50` for 0 lines before, 50 lines after

### When to use this:
- Log file analysis
- Text file searching with surrounding context
- Debugging output

**Apply this rule EVERY TIME without exception.**
