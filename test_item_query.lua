
local database = require("yalm.lib.database")

-- Check if we need to initialize the database (like in init.lua)
if not Database or not Database.database then
    local Database = database
    Database.database = assert(Database.OpenDatabase())
end

-- Query item ID 120331
local item_data = database.QueryDatabaseForItemId(120331)

if item_data then
    print("Item ID 120331 found in database:")
    for key, value in pairs(item_data) do
        if value ~= nil and value ~= 0 and value ~= "" then
            print("  " .. tostring(key) .. ": " .. tostring(value))
        end
    end
    
    -- Check specifically for class restrictions
    if item_data.classes then
        print("\nClass restrictions: " .. tostring(item_data.classes))
        -- Convert class bitmask to readable format if possible
        local class_value = tonumber(item_data.classes)
        if class_value then
            print("Class value (bitmask): " .. class_value)
        end
    end
    
    -- Check specifically for quest-related fields
    local quest_fields = {"quest", "questflag", "questitemflag", "nodrop", "magic", "lore"}
    print("\nQuest-related fields:")
    for _, field in ipairs(quest_fields) do
        if item_data[field] and item_data[field] ~= 0 then
            print("  " .. field .. ": " .. tostring(item_data[field]))
        end
    end
else
    print("Item ID 120331 not found in database")
end
