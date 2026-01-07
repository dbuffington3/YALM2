# Smart Database Path Auto-Detection Implementation

## Summary
Implemented intelligent, self-contained database path resolution that works across different MQ2 installations without requiring manual user configuration.

## Changes Made

### 1. `lib/database.lua`
**Added comprehensive documentation and smart path detection:**

- **New function: `get_database_path()`**
  - Automatically detects the MQ2 root directory
  - Searches for database in standard locations:
    1. `<MQ2_ROOT>/resources/MQ2LinkDB.db` (primary)
    2. MQ2's configured resources path (fallback)
  - No configuration needed from users

- **New table property: `YALM2_Database.mq2_root`**
  - Stores the detected MQ2 root directory
  - Can be used by other modules if needed

- **Documentation added to explain:**
  - How path detection works
  - Standard vs custom installation formats
  - Troubleshooting steps
  - Multiple installation support

### 2. `check_upgrades.lua`
**Updated database initialization:**

- Removed hard-coded path: `'C:\\MQ2\\resources\\MQ2LinkDB.db'`
- Now uses: `db.OpenDatabase()` (auto-detection)
- Added comment explaining how auto-detection works
- Better error message if database can't be found

### 3. New Documentation: `DATABASE_SETUP.md`
**Comprehensive guide for users:**

- Installation instructions for standard and custom paths
- Examples of directory structures
- Database file format specification
- Database creation instructions
- Troubleshooting section with:
  - How to verify database exists
  - How to check if database is populated
  - Manual override instructions for edge cases
- Technical details on path resolution
- Support for multiple MQ2 installations

## How It Works

### Auto-Detection Algorithm
```
1. Get lua path from MQ2 API
   (e.g., C:\MQ2\lua or D:\EverQuest\lua)

2. Extract MQ2 root by removing /lua
   (e.g., C:\MQ2 or D:\EverQuest)

3. Try <root>/resources/MQ2LinkDB.db
4. Fall back to MQ2's configured resources path
```

### Supported Scenarios

✅ **Standard Installation**
```
C:\MQ2\
├── lua/yalm2/          ← YALM2 here
└── resources/
    └── MQ2LinkDB.db    ← Auto-detected
```

✅ **Custom Location**
```
D:\EverQuest\
├── lua/yalm2/          ← YALM2 here
└── resources/
    └── MQ2LinkDB.db    ← Auto-detected
```

✅ **Non-Standard Structure**
```
E:\Games\EQ\
├── lua/yalm2/          ← YALM2 here
└── config/
    └── MQ2LinkDB.db    ← Falls back here
```

✅ **Multiple Installations**
- Each YALM2 installation auto-detects independently
- No shared configuration needed

## User Experience

### Before
- Users had to hard-code database paths
- Script failed if installed in non-standard location
- Confusing error messages about database location

### After
- Automatic detection - works out of the box
- Works with any MQ2 installation path
- Clear error messages if database still can't be found
- Fallback mechanisms for edge cases

## Benefits

1. **Zero Configuration** - Just place database in resources directory
2. **Portable** - Works with any MQ2 installation path
3. **Reliable** - Multiple fallback locations tested in order
4. **Documented** - Clear documentation for troubleshooting
5. **Maintainable** - Path detection centralized in one location
6. **Scalable** - Supports multiple installations on same system

## Testing

The implementation has been tested with:
- Standard C:\MQ2\ installation ✓
- Auto-detection from YALM2's location ✓
- Database query and item lookup ✓
- Equipment upgrade detection ✓

## Migration Notes

If you have an existing installation with hard-coded paths:
1. No changes needed - auto-detection is backward compatible
2. Database can stay in current location
3. System will find it automatically
4. Remove any manual path overrides (optional but cleaner)

## Edge Cases Handled

- Windows vs forward slashes in paths
- Missing database with helpful error message
- Database in non-standard locations (fallback search)
- Multiple MQ2 installations (independent detection)
- Case sensitivity in path navigation

## Files Modified
- `lib/database.lua` - Auto-detection logic and documentation
- `check_upgrades.lua` - Removed hard-coded path

## Files Added
- `DATABASE_SETUP.md` - User guide for database setup and troubleshooting
