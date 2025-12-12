# YALM2 Setup Guide

## Prerequisites

### Required MQ2 Plugin: MQ2LinkDB

**YALM2 requires MQ2LinkDB to be loaded.** This plugin provides access to the item database for quest item validation.

#### Checking if MQ2LinkDB is loaded:
```
/listplugins
```
Look for `mq2linkdb` in the output.

#### Loading MQ2LinkDB:
```
/plugin mq2linkdb load
```

#### Making it persist:
Add this line to your login macro or macro sequence:
```lua
/plugin mq2linkdb load
```

If you don't see `mq2linkdb` available, ensure you're using the latest MacroQuest from [RedGuides](https://redguides.com). It's included in the standard distribution.

---

## Quick Start (Recommended)

The repository includes a pre-populated `MQ2LinkDB.db` with all 134,000+ items from Lucy Allakhazam. This is the easiest way to get started.

### Step 1: Ensure MQ2LinkDB Plugin is Loaded
```
/plugin mq2linkdb load
```

### Step 2: Copy Database Files to MQ2
Copy these files from the repository to your MQ2 resources directory:

```
Repository Files              →  MQ2 Resources Directory
─────────────────────────────     ──────────────────────
MQ2LinkDB.db                  →  C:\MQ2\resources\MQ2LinkDB.db
MQ2LinkDB.db-wal              →  C:\MQ2\resources\MQ2LinkDB.db-wal
```

**Windows (copy command):**
```powershell
Copy-Item "MQ2LinkDB.db" "C:\MQ2\resources\"
Copy-Item "MQ2LinkDB.db-wal" "C:\MQ2\resources\"
```

### Step 3: Verify the Database
When YALM2 loads, it will automatically verify that MQ2LinkDB.db has the YALM2 initialization marker:
- The system checks for a `yalm2_metadata` table with a `yalm2_db_version` timestamp
- If verification passes, you'll see a debug message confirming the database
- If it fails, you'll get an error message indicating the issue

### Step 4: Start Using YALM2
- Quest items will be detected and distributed automatically
- The system will check item metadata from the included database
- Everything should work immediately

---

## Advanced Setup (Updating with Fresh Data)

If you want to refresh the database with the latest Lucy item data, follow these steps.

### Prerequisites:
- Node.js installed (v16 or later) - [Download](https://nodejs.org/)
- PowerShell
- Internet connection

### Step 1: Install Node.js Dependencies
```powershell
cd C:\MQ2\lua\yalm2
npm install
```

This installs:
- **Puppeteer**: Browser automation for scraping
- **Puppeteer-cluster**: Manages 30 parallel browser instances
- **Node-fetch**: HTTP requests

### Step 2: Run the Lucy Scraper
```powershell
.\run_scraper.ps1
```

**What this does:**
- Scrapes all 134,000+ items from Lucy Allakhazam
- Creates JSON files in `D:\lucy\` directory
- Takes several hours to complete (parallel processing)
- Auto-restarts on failure (up to 1000 attempts)
- Logs progress and debug info

**Note:** This is a one-time operation. You only need to do this if you want the absolute latest item data.

### Step 3: Update MQ2LinkDB with Lucy Data
Two options:

**Option A: Single Item Update**
```lua
-- In MQ2 console:
/lua run yalm2.update_linkdb
UpdateLinkDB.update_single_item(item_id)
```

**Option B: Bulk Update (Recommended)**
```lua
-- In MQ2 console or batch script:
/lua run yalm2.batch_update_linkdb
```

### Step 4: Replace Database in Repository
After updating, copy the new database back for distribution:

```powershell
Copy-Item "C:\MQ2\resources\MQ2LinkDB.db" "C:\MQ2\lua\yalm2\MQ2LinkDB.db"
Copy-Item "C:\MQ2\resources\MQ2LinkDB.db-wal" "C:\MQ2\lua\yalm2\MQ2LinkDB.db-wal"
git add MQ2LinkDB.db MQ2LinkDB.db-wal
git commit -m "Update database with latest Lucy scraping results"
git push
```

---

## Database Verification

The system uses a metadata marker in MQ2LinkDB to ensure database validity:

### Marker Details:
- **Location:** `yalm2_metadata` table
- **Key:** `yalm2_db_version`
- **Value:** Unix timestamp (date of last database update)
- **Purpose:** Prevents using outdated or incorrect database files

### If Verification Fails:
```
ERROR: MQ2LinkDB.db is missing YALM2 initialization marker.
Please use the database file provided with this repository.
```

**Solution:** 
1. Delete your current `C:\MQ2\resources\MQ2LinkDB.db`
2. Replace it with the one from this repository
3. Ensure `MQ2LinkDB.db-wal` is also present

### Manual Marker Addition:
If you're using a custom database and want to add the marker:

```sql
CREATE TABLE IF NOT EXISTS yalm2_metadata (
  key TEXT PRIMARY KEY,
  last_update INTEGER
);

INSERT INTO yalm2_metadata (key, last_update) 
VALUES ('yalm2_db_version', strftime('%s', 'now'));
```

---

## Database Contents

The included MQ2LinkDB.db contains:
- **134,079 items** from Everquest
- **Complete Lucy metadata** including:
  - Item names and IDs
  - Item types (weapons, armor, tradeskill, etc.)
  - Class and race restrictions
  - Stats and effects
  - Tradeskill information
  - Quest flags and indicators

---

## Configuration Files

Located in the repository root:

- **lucy_scraper.js** - Node.js web scraper using Puppeteer
- **run_scraper.ps1** - PowerShell orchestrator with auto-restart
- **itemlist.txt** - CSV file with 134,083 item IDs and Lucy URLs
- **update_linkdb.lua** - Single/batch update tool for MQ2LinkDB
- **batch_update_linkdb.lua** - Bulk update utility
- **package.json** - Node.js dependencies
- **package-lock.json** - Locked dependency versions

---

## Troubleshooting

### "MQ2LinkDB plugin not found"
```
ERROR: Could not load mq2linkdb plugin
```
**Solution:** 
1. Check you have the latest MacroQuest from [RedGuides](https://redguides.com)
2. Run `/plugin mq2linkdb load`
3. Add to your macro startup sequence

### "MQ2LinkDB.db not found"
```
ERROR: Could not open MQ2LinkDB.db for verification
```
**Solution:**
1. Verify files are at: `C:\MQ2\resources\MQ2LinkDB.db`
2. Check that the file is not read-only (Properties → Uncheck "Read-only")
3. Ensure `MQ2LinkDB.db-wal` is also present

### "Missing YALM2 initialization marker"
```
ERROR: MQ2LinkDB.db is missing YALM2 initialization marker.
```
**Solution:**
1. You're using an old or wrong MQ2LinkDB.db
2. Delete the current one: `C:\MQ2\resources\MQ2LinkDB.db`
3. Replace with fresh copy from the repository
4. Optionally add the marker manually (see "Manual Marker Addition" above)

### Scraper takes too long
The scraper is a one-time operation:
- Scrapes 134,000+ items over several hours
- Parallel processing (30 concurrent browsers)
- You only need to run this if updating with fresh Lucy data
- For daily use, just use the included database file

### Out of date database
The included database is current as of its commit date. To update:
1. Follow the "Advanced Setup" section above
2. Re-scraping the entire database takes several hours
3. Consider if you really need the absolute latest data

---

## File Structure

```
C:\MQ2\
├── resources/
│   ├── MQ2LinkDB.db          ← Copy here from repository
│   └── MQ2LinkDB.db-wal      ← Copy here from repository
└── lua/
    └── yalm2/
        ├── MQ2LinkDB.db      ← Source (from repository)
        ├── MQ2LinkDB.db-wal  ← Source (from repository)
        ├── lucy_scraper.js   ← For refreshing data
        ├── run_scraper.ps1   ← For refreshing data
        ├── itemlist.txt      ← Item ID list
        ├── update_linkdb.lua ← Database update tool
        └── ...
```

---

## Support

For issues or questions:
1. Check this guide first
2. Review [README.md](README.md) for feature overview
3. Check existing issues on GitHub
4. Ensure all prerequisites are met (MQ2LinkDB plugin loaded, files copied)
