SQLITE3 SETUP FOR POWERSHELL DATABASE QUERIES
==============================================

To query the YALM2 database directly from PowerShell, you need sqlite3 command-line tool.

DOWNLOAD:
---------
Download from: https://www.sqlite.org/download.html
Look for: "Precompiled Binaries for Windows"
Specifically: sqlite-tools-win32-x86-*.zip or sqlite-tools-win-x64-*.zip

INSTALLATION:
--------------
1. Download the zip file
2. Extract sqlite3.exe to a location in your PATH, or to C:\MQ2\lua\yalm2\
3. Test with: sqlite3 --version

USAGE EXAMPLE:
--------------
# Query database directly
sqlite3 yalm2_ItemDB.db "SELECT id, name FROM raw_item_data WHERE id = 17596 LIMIT 1;"

# Find items by name
sqlite3 yalm2_ItemDB.db "SELECT id, name FROM raw_item_data WHERE name LIKE '%Orbweaver%' LIMIT 10;"

# Find items in 315 table
sqlite3 yalm2_ItemDB.db "SELECT id, name FROM raw_item_data_315 WHERE name LIKE '%Orbweaver%' LIMIT 10;"

# Export to CSV
sqlite3 yalm2_ItemDB.db ".mode csv" "SELECT id, name FROM raw_item_data WHERE name LIKE '%Orbweaver%';" > items.csv

POWERSHELL ALTERNATIVE:
------------------------
If you don't want to install sqlite3, can use PowerShell with reflection:
[Reflection.Assembly]::LoadFile('path\to\lsqlite3.dll')
But sqlite3 command-line is simpler for quick queries.
