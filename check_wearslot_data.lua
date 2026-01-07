#!/usr/bin/env lua
-- Check what wearslot data exists in the database
local sql = require("lsqlite3")

local db_path = "C:\\MQ2\\Resources\\MQ2LinkDB.db"
print("Opening database:", db_path)

local db, ec, em = sql.open(db_path)
if not db then
    print("Error opening database:", ec, em)
    return
end

-- Check columns in raw_item_data
print("\n=== Columns in raw_item_data ===")
local columns = {}
for row in db:nrows("PRAGMA table_info(raw_item_data);") do
    table.insert(columns, row.name)
    if row.name:match("wear") or row.name:match("slot") or row.name:match("item") then
        print("Column: " .. row.name .. " (Type: " .. row.type .. ")")
    end
end

-- Look for wearslot or similar columns
print("\n=== Checking specific columns ===")
print("All columns with 'wear', 'slot', or 'item' in name:")
for _, col in ipairs(columns) do
    if col:lower():match("wear") or col:lower():match("slot") or col:lower():match("item") then
        print("  - " .. col)
    end
end

-- Check items 50814 and 120331 (the problematic ones)
print("\n=== Item 50814 (Runic Partisan - THE PROBLEM) ===")
local query = "SELECT id, name, itemtype, wearslot FROM raw_item_data WHERE id = 50814 LIMIT 1;"
local found = false
for row in db:nrows(query) do
    found = true
    print("ID: " .. (row.id or "nil"))
    print("Name: " .. (row.name or "nil"))
    print("ItemType: " .. (row.itemtype or "nil"))
    print("Wearslot: " .. (row.wearslot or "nil"))
end
if not found then
    print("Item 50814 not found")
end

print("\n=== Item 120331 (What character is wearing) ===")
query = "SELECT id, name, itemtype, wearslot FROM raw_item_data WHERE id = 120331 LIMIT 1;"
found = false
for row in db:nrows(query) do
    found = true
    print("ID: " .. (row.id or "nil"))
    print("Name: " .. (row.name or "nil"))
    print("ItemType: " .. (row.itemtype or "nil"))
    print("Wearslot: " .. (row.wearslot or "nil"))
end
if not found then
    print("Item 120331 not found")
end

-- Check ALL wearslot values that exist
print("\n=== Summary of wearslot values in database ===")
query = "SELECT DISTINCT wearslot FROM raw_item_data WHERE wearslot IS NOT NULL AND wearslot != '' ORDER BY wearslot LIMIT 20;"
local count = 0
for row in db:nrows(query) do
    print("  - " .. (row.wearslot or "NULL"))
    count = count + 1
end
print("Found " .. count .. " distinct wearslot values")

-- Check how many items have NO wearslot
query = "SELECT COUNT(*) as cnt FROM raw_item_data WHERE wearslot IS NULL OR wearslot = '';"
for row in db:nrows(query) do
    print("\nItems with NO wearslot: " .. (row.cnt or 0))
end

-- Check how many items HAVE wearslot
query = "SELECT COUNT(*) as cnt FROM raw_item_data WHERE wearslot IS NOT NULL AND wearslot != '';"
for row in db:nrows(query) do
    print("Items WITH wearslot: " .. (row.cnt or 0))
end

-- Check for all columns to understand the schema better
print("\n=== All columns in raw_item_data (first 30) ===")
for i = 1, math.min(30, #columns) do
    print("  " .. i .. ". " .. columns[i])
end

db:close()
print("\nDone.")
