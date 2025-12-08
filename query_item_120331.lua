-- Query item 120331 from database
local mq = require("mq")

-- Load the database module
local database = require("yalm.lib.database")

print("Opening database...")
database.database = database.OpenDatabase()

if not database.database then
    print("ERROR: Could not open database")
    return
end

print("Querying item ID 120331...")
local item_data = database.QueryDatabaseForItemId(120331)

if item_data then
    print("=== ITEM ID 120331 FOUND ===")
    print("ID: " .. tostring(item_data.id or "unknown"))
    print("Name: " .. tostring(item_data.name or "unknown"))
    print("Classes: " .. tostring(item_data.classes or "unknown"))
    
    -- Show all important fields
    print("\n=== ALL FIELDS ===")
    local sorted_keys = {}
    for key in pairs(item_data) do
        table.insert(sorted_keys, key)
    end
    table.sort(sorted_keys)
    
    for _, key in ipairs(sorted_keys) do
        local value = item_data[key]
        if value ~= nil and value ~= 0 and value ~= "" then
            print(key .. ": " .. tostring(value))
        end
    end
else
    print("ERROR: Item ID 120331 not found in database")
end

if database.database then
    database.database:close()
end