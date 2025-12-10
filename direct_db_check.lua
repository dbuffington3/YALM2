-- Direct database check script
local sql = require("lsqlite3")

-- Open the database directly
local db_path = "C:\\MQ2\\Resources\\MQ2LinkDB.db"
print("Opening database:", db_path)

local db, ec, em = sql.open(db_path)
if not db then
    print("Error opening database:", ec, em)
    return
end

-- Check what tables exist
print("\n=== Available Tables ===")
for row in db:nrows("SELECT name FROM sqlite_master WHERE type='table';") do
    print("Table:", row.name)
end

-- Get column info for raw_item_data table
print("\n=== Columns in raw_item_data ===")
for row in db:nrows("PRAGMA table_info(raw_item_data);") do
    print(string.format("Column: %s, Type: %s", row.name, row.type))
end

-- Check if questitem column exists
print("\n=== Checking for questitem column ===")
local has_questitem = false
for row in db:nrows("PRAGMA table_info(raw_item_data);") do
    if row.name == "questitem" then
        has_questitem = true
        print("questitem column found!")
        break
    end
end

if not has_questitem then
    print("questitem column NOT found")
end

-- Query item 50814 directly
print("\n=== Item 50814 Data ===")
local query = "SELECT id, name, norent, questitem FROM raw_item_data WHERE id = 50814;"
print("Query:", query)

local found = false
for row in db:nrows(query) do
    found = true
    print("ID:", row.id)
    print("Name:", row.name)
    print("norent:", row.norent)
    print("questitem:", row.questitem)
end

if not found then
    print("Item 50814 not found in raw_item_data")
    
    -- Try raw_item_data_315 table
    print("\n=== Trying raw_item_data_315 ===")
    local query315 = "SELECT id, name, norent, questitem FROM raw_item_data_315 WHERE id = 50814;"
    for row in db:nrows(query315) do
        print("ID:", row.id)
        print("Name:", row.name) 
        print("norent:", row.norent)
        print("questitem:", row.questitem)
        found = true
    end
end

if not found then
    print("Item 50814 not found in either table")
end

db:close()
print("\nDatabase check complete.")