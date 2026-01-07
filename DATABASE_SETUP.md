# MQ2LinkDB Database Setup Guide

## Overview
YALM2's equipment upgrade detection system uses the **MQ2LinkDB.db** SQLite database containing item data from Lucy's database exports.

## Automatic Detection
The database path is **automatically detected** based on your YALM2 installation location. No manual configuration required!

### How It Works
1. YALM2 is installed at: `<MQ2_ROOT>/lua/yalm2/`
2. The system navigates up to find `<MQ2_ROOT>`
3. Looks for database at: `<MQ2_ROOT>/resources/MQ2LinkDB.db`
4. Falls back to MQ2's configured resources path if needed

## Installation

### Standard Installation (Most Users)
```
C:\MQ2\
├── lua\
│   └── yalm2\              ← YALM2 installed here
├── resources\
│   └── MQ2LinkDB.db        ← Database goes here (auto-detected)
├── config\
└── eqclient.ini
```

**Just place `MQ2LinkDB.db` in your `<MQ2_ROOT>/resources/` directory and it will be found automatically.**

### Non-Standard Installation
```
D:\EverQuest\               ← Your MQ2 root (any path)
├── lua\
│   └── yalm2\              ← YALM2 installed here
├── resources\
│   └── MQ2LinkDB.db        ← Database auto-detected here
└── config\
```

**The auto-detection works regardless of your MQ2 installation path.**

## Database File Format

The database should contain a table named `raw_item_data` with columns including:
- `id` (INTEGER PRIMARY KEY) - Item ID
- `name` (TEXT) - Item name
- `slots` (TEXT) - Slot bitmask value
- `itemtype` (TEXT) - Equipment type
- `ac` (TEXT) - Armor class
- `hp` (TEXT) - Hit points
- `mana` (TEXT) - Mana bonus
- `endur` (TEXT) - Endurance bonus
- And many other stat columns...

## Creating the Database

If you don't have MQ2LinkDB.db, you can create it using the included Python importer:

```bash
python import_lucy.py
```

This will:
1. Read Lucy item JSON files from the configured directory
2. Create or populate the SQLite database
3. Insert all item data with proper schema

## Troubleshooting

### Database Not Found
If you get "Database file does not exist" error:

1. **Check the detected path:**
   - Look at the error message for the exact path being searched
   - Verify that path exists

2. **Verify file location:**
   ```powershell
   # Windows PowerShell - check if database exists
   Test-Path "C:\MQ2\resources\MQ2LinkDB.db"
   Test-Path "D:\YourMQPath\resources\MQ2LinkDB.db"
   ```

3. **Verify directory structure:**
   - Ensure your MQ2 installation has a `lua` directory
   - Ensure YALM2 is installed as `<MQ2_ROOT>/lua/yalm2/`
   - Ensure your MQ2 installation has a `resources` directory

4. **Manual override:**
   - If auto-detection fails, edit the script directly
   - In `check_upgrades.lua`, uncomment and set explicit path:
   ```lua
   -- Override auto-detection if needed
   local explicit_db_path = "C:\\MQ2\\resources\\MQ2LinkDB.db"
   db.database = db.OpenDatabase(explicit_db_path)
   ```

### Database is Empty
If the database exists but contains no data:

1. Run the import script to populate it:
   ```bash
   python import_lucy.py
   ```

2. Verify the import completed successfully by checking file size:
   ```powershell
   (Get-Item "C:\MQ2\resources\MQ2LinkDB.db").Length
   ```
   - Empty database: ~0-50 KB
   - Populated database: ~150+ MB (contains 134,079 items)

## Technical Details

### Path Resolution Logic
Located in: `lib/database.lua`

```
1. Get lua directory from MQ2
2. Remove "/lua" or "\lua" from path to find MQ2 root
3. Try: <root>/resources/MQ2LinkDB.db
4. Try: <root>/config/MQ2LinkDB.db  
5. Fall back to MQ2's configured resources path
```

### Supported Path Formats
- Windows: `C:\MQ2\resources\MQ2LinkDB.db`
- Mixed: `C:/MQ2/resources/MQ2LinkDB.db`
- Network: `\\server\share\MQ2\resources\MQ2LinkDB.db`

## For Multiple MQ2 Installations

If you have multiple MQ2 installations:
- Each should have its own YALM2 installation
- Each can have its own database location
- The auto-detection works independently for each installation

No special setup needed - just install YALM2 in each location's lua directory.

## Need Help?

Check the following files for detailed information:
- `lib/database.lua` - Database connection and path detection logic
- `check_upgrades.lua` - Equipment upgrade detection script
- `import_lucy.py` - Database creation/population script
