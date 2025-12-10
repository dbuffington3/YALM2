-- Direct database verification script for MQ2
local mq = require("mq")
local sql = require("lsqlite3")

-- Open database directly
local db_path = mq.TLO.MacroQuest.Path("resources") .. "/MQ2LinkDB.db"
print("=== Direct Database Check ===")
print("Database path:", db_path)

local db, ec, em = sql.open(db_path)
if not db then
    print("ERROR: Could not open database:", ec, em)
    return
end

-- Check if questitem column exists in raw_item_data
print("\n=== Checking raw_item_data schema ===")
local questitem_exists = false
local column_count = 0
for row in db:nrows("PRAGMA table_info(raw_item_data);") do
    column_count = column_count + 1
    if row.name == "questitem" then
        questitem_exists = true
        print("✓ questitem column found at position", row.cid)
    end
end

print("Total columns in raw_item_data:", column_count)
print("questitem column exists:", questitem_exists)

-- Get data for item 50814
print("\n=== Item 50814 Direct Query ===")
local query = "SELECT id, name, norent, " .. (questitem_exists and "questitem" or "0 as questitem") .. " FROM raw_item_data WHERE id = 50814 LIMIT 1;"
print("SQL:", query)

local found = false
for row in db:nrows(query) do
    found = true
    print("Found in raw_item_data:")
    print("  ID:", row.id)
    print("  Name:", row.name or "NULL")
    print("  norent:", row.norent or "NULL") 
    print("  questitem:", row.questitem or "NULL")
end

if not found then
    print("Item 50814 NOT found in raw_item_data")
    
    -- Check raw_item_data_315
    print("\n=== Checking raw_item_data_315 ===")
    local query315 = "SELECT id, name, norent FROM raw_item_data_315 WHERE id = 50814 LIMIT 1;"
    for row in db:nrows(query315) do
        print("Found in raw_item_data_315:")
        print("  ID:", row.id)
        print("  Name:", row.name or "NULL")
        print("  norent:", row.norent or "NULL")
        found = true
    end
end

-- Count total records
print("\n=== Table Statistics ===")
for row in db:nrows("SELECT COUNT(*) as count FROM raw_item_data;") do
    print("raw_item_data total records:", row.count)
end

for row in db:nrows("SELECT COUNT(*) as count FROM raw_item_data_315;") do
    print("raw_item_data_315 total records:", row.count)
end

db:close()
print("\n=== Database Check Complete ===")

-- Also test the YALM2 database interface
print("\n=== Testing YALM2 Database Interface ===")
local Database = require("yalm.lib.database")
if Database.database then
    print("YALM2 database connection exists")
    local item_data = Database.QueryDatabaseForItemId(50814)
    if item_data then
        print("YALM2 interface found item 50814:")
        print("  ID:", item_data.id)
        print("  Name:", item_data.name)
        print("  norent:", item_data.norent)
        print("  questitem:", item_data.questitem)
    else
        print("YALM2 interface did NOT find item 50814")
    end
else
    print("YALM2 database connection not initialized")
end