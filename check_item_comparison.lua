
local database = require("yalm2.lib.database")
local mq = require("mq")

-- Initialize database
if not database.database then
    database.database = database.OpenDatabase()
    if not database.database then
        print("ERROR: Could not open database")
        return
    end
end

local items_to_check = {
    {id = 50814, name = "Runic Partisan (PROBLEM)"},
    {id = 120331, name = "Item 120331 (equipped)"}
}

for _, item_info in ipairs(items_to_check) do
    print("\n=== Checking Item " .. item_info.id .. " (" .. item_info.name .. ") ===")
    
    local item_data = database.QueryDatabaseForItemId(item_info.id)
    
    if item_data then
        print("Item found! Checking key fields:")
        
        -- Print the most relevant fields
        local fields_to_check = {
            "id", "name", "itemtype", "wearslot", "wear_slot", "itemslot", "item_slot",
            "ac", "hp", "mana", "attack", "delay", "damage", "type"
        }
        
        for _, field in ipairs(fields_to_check) do
            local val = item_data[field]
            if val ~= nil then
                print(string.format("  %s: %s", field, tostring(val)))
            end
        end
        
        -- Also print itemtype with explanation
        if item_data.itemtype then
            print(string.format("\nItemType value: %s (numeric: %s)", 
                tostring(item_data.itemtype), 
                tostring(tonumber(item_data.itemtype) or "not numeric")))
        else
            print("\nItemType: NOT PRESENT")
        end
        
        if item_data.wearslot then
            print(string.format("Wearslot value: '%s'", tostring(item_data.wearslot)))
        else
            print("Wearslot: NOT PRESENT or empty")
        end
        
    else
        print("Item NOT found in database")
    end
end

database.database:close()
print("\nDone.")
