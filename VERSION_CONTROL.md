# YALM2 Version Management Guide

## Quick Commands

### Create a backup before making changes:
```bash
git add .
git commit -m "WIP: Description of what you're working on"
git tag -a v1.1-testing -m "Testing new feature - $(date)"
```

### List all available versions:
```bash
git tag -l
git log --oneline --decorate
```

### Revert to stable version (SAFE - doesn't lose work):
```bash
# Create a backup of current work first
git add .
git commit -m "Backup before revert - $(date)"

# Go back to stable
git checkout v1.0-stable
```

### Revert to any specific version:
```bash
git checkout v1.1-testing
git checkout cb180bc  # Using commit hash
```

### Return to latest development:
```bash
git checkout master
```

### Compare versions:
```bash
git diff v1.0-stable v1.1-testing
git diff HEAD~1 HEAD  # Compare with previous commit
```

## Emergency Recovery Commands

### If YALM2 won't load at all:
```bash
cd "c:\MQ2\lua\yalm2"
git checkout v1.0-stable --force
# Reload in game: /lua reload yalm2
```

### Create emergency backup of entire folder:
```powershell
Copy-Item "c:\MQ2\lua\yalm2" "c:\MQ2\lua\yalm2_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Recurse
```

## Version History
- **v1.0-stable**: Working NO TRADE safety + class priority system (Dec 7, 2025)
  - NO TRADE items blocked from incompatible classes
  - Class-restricted items prioritize usable classes
  - Quest timing fixes
  - Crash prevention fixes

## Development Workflow

1. **Before making changes**: `git commit -m "Checkpoint before changes"`
2. **Test changes**: Make your modifications
3. **If working**: `git add . && git commit -m "Working: Feature description"`
4. **If broken**: `git checkout HEAD~1` (go back one commit)
5. **Create stable milestone**: `git tag -a v1.X-stable -m "Description"`

## File-Specific Backups (Alternative)

If you don't want to use git, you can backup individual files:
```bash
copy core\looting.lua core\looting.lua.backup
copy core\evaluate.lua core\evaluate.lua.backup
copy core\tasks.lua core\tasks.lua.backup
```

Restore with:
```bash
copy core\looting.lua.backup core\looting.lua
```