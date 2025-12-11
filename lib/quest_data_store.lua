--- Shared Quest Data Store Module
--- Provides a single shared location for quest data that both yalm2_native_quest.lua
--- and YALM2 init.lua can access, regardless of script context isolation.
--- 
--- This works around the Lua script isolation issue where each script has its own _G table.

local mq = require("mq")

local quest_data_store = {
    quest_items_with_qty = "",
    quest_items = "",
    timestamp = 0,
    is_valid = false
}

--- Set the quest data with quantities
--- @param data string - The quest data string in format "ItemName:char1:qty1,char2:qty2|ItemName2:..."
function quest_data_store.set_quest_data_with_qty(data)
    if data and data:len() > 0 then
        quest_data_store.quest_items_with_qty = data
        quest_data_store.timestamp = mq.gettime()
        quest_data_store.is_valid = true
    else
        quest_data_store.quest_items_with_qty = ""
        quest_data_store.is_valid = false
    end
end

--- Set the quest data without quantities
--- @param data string - The quest data string in format "ItemName:char1,char2|ItemName2:..."
function quest_data_store.set_quest_data(data)
    if data and data:len() > 0 then
        quest_data_store.quest_items = data
        quest_data_store.timestamp = mq.gettime()
    else
        quest_data_store.quest_items = ""
    end
end

--- Get the quest data with quantities
--- @return string - The current quest data with quantities, or empty string if none available
function quest_data_store.get_quest_data_with_qty()
    return quest_data_store.quest_items_with_qty or ""
end

--- Get the quest data without quantities
--- @return string - The current quest data without quantities, or empty string if none available
function quest_data_store.get_quest_data()
    return quest_data_store.quest_items or ""
end

--- Check if the stored data is currently valid (recently updated)
--- @param max_age_ms number - Maximum age in milliseconds (default: 10000ms = 10 seconds)
--- @return boolean - true if data is valid and within max_age, false otherwise
function quest_data_store.is_data_valid(max_age_ms)
    max_age_ms = max_age_ms or 10000
    
    if not quest_data_store.is_valid then
        return false
    end
    
    local current_time = mq.gettime()
    local age = current_time - quest_data_store.timestamp
    
    return age < max_age_ms
end

--- Clear all stored data
function quest_data_store.clear()
    quest_data_store.quest_items_with_qty = ""
    quest_data_store.quest_items = ""
    quest_data_store.timestamp = 0
    quest_data_store.is_valid = false
end

--- Get debug info about the stored data
--- @return table - Debug information
function quest_data_store.get_debug_info()
    return {
        has_qty_data = quest_data_store.quest_items_with_qty:len() > 0,
        qty_data_len = quest_data_store.quest_items_with_qty:len(),
        has_simple_data = quest_data_store.quest_items:len() > 0,
        simple_data_len = quest_data_store.quest_items:len(),
        timestamp = quest_data_store.timestamp,
        is_valid = quest_data_store.is_valid,
        age_ms = (mq.gettime() or 0) - quest_data_store.timestamp
    }
end

return quest_data_store
