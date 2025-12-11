--- Unified Quest Interface for YALM2
--- Provides a single interface for both external TaskHUD and native quest systems
--- Automatically routes to the appropriate implementation based on configuration

local mq = require("mq")
local debug_logger = require("yalm2.lib.debug_logger")
local quest_data_store = require("yalm2.lib.quest_data_store")

local quest_interface = {}

-- Global references to the quest systems
local external_tasks = nil
local native_tasks = nil
local use_native_system = false

--- Initialize the quest interface with the appropriate system
quest_interface.initialize = function(global_settings, external_tasks_module, native_tasks_module)
    external_tasks = external_tasks_module
    native_tasks = native_tasks_module
    use_native_system = global_settings.settings.use_native_quest_system
    
    debug_logger.debug("QUEST_INTERFACE: Using %s quest system", use_native_system and "native" or "external")
    Write.Info("Quest interface initialized for %s quest system", use_native_system and "native" or "external")
end

--- Check if an item is needed for quests
quest_interface.is_quest_item = function(item_name)
    if use_native_system then
        if native_tasks and native_tasks.is_quest_item then
            return native_tasks.is_quest_item(item_name)
        else
            debug_logger.warn("QUEST_INTERFACE: native_tasks or is_quest_item function not available")
        end
        return false
    else
        if external_tasks and external_tasks.is_quest_item then
            return external_tasks.is_quest_item(item_name)
        end
        return false
    end
end

--- Get characters who need a specific quest item directly from MQ2 variable
--- Get characters who need a specific quest item 
--- Reads from shared quest data store populated by yalm2_native_quest.lua
quest_interface.get_quest_characters_local = function(item_name)
    local needed_by = {}
    
    -- PRIMARY: Use shared quest data store which is populated by automatic update loop
    -- The automatic loop in yalm2_native_quest.lua updates this every 3 seconds
    local quest_data = quest_data_store.get_quest_data_with_qty()
    
    -- If shared store is empty, try MQ2 variable as fallback
    if not quest_data or quest_data == "" then
        local success, var_value = pcall(function()
            -- Try the variable with quantities first
            if mq.TLO.Defined('YALM2_Quest_Items_WithQty')() then
                local raw_val = mq.TLO.YALM2_Quest_Items_WithQty
                if raw_val then
                    local str_val = tostring(raw_val)
                    if str_val and str_val ~= "nil" and str_val ~= "" then
                        debug_logger.info("QUEST_INTERFACE: MQ2 Variable YALM2_Quest_Items_WithQty accessed (len=%d)", str_val:len())
                        return str_val
                    end
                end
            end
            -- Fallback to the one without quantities
            if mq.TLO.Defined('YALM2_Quest_Items')() then
                local raw_val = mq.TLO.YALM2_Quest_Items
                if raw_val then
                    local str_val = tostring(raw_val)
                    if str_val and str_val ~= "nil" and str_val ~= "" then
                        debug_logger.info("QUEST_INTERFACE: MQ2 Variable YALM2_Quest_Items accessed (fallback, len=%d)", str_val:len())
                        return str_val
                    end
                end
            end
            return ""
        end)
        
        if success and var_value and var_value ~= "" and var_value ~= "nil" then
            quest_data = var_value
        end
    end
    
    debug_logger.debug("QUEST_INTERFACE: Looking for '%s' in quest_data (len=%d)", item_name, quest_data and quest_data:len() or 0)
    
    if quest_data and quest_data:len() > 0 then
        for item_data in quest_data:gmatch("([^|]+)") do
            -- Parse: "ItemName:char1:qty1,char2:qty2"
            local quest_item_name, char_list_str = item_data:match("^([^:]+):(.+)$")
            
            if quest_item_name and char_list_str then
                -- Check for exact match
                local exact_match = (quest_item_name == item_name or quest_item_name:lower() == item_name:lower())
                
                -- Check for plural/singular variations
                local singular_match = false
                if not exact_match then
                    -- Try removing trailing 's' from quest item name
                    local quest_singular = quest_item_name:gsub("s$", "")
                    if quest_singular ~= quest_item_name then
                        singular_match = (quest_singular == item_name or quest_singular:lower() == item_name:lower())
                        if singular_match then
                            debug_logger.debug("QUEST_INTERFACE: Matched via quest singular: '%s' -> '%s'", quest_item_name, quest_singular)
                        end
                    end
                    
                    -- Try removing trailing 's' from db item name if no match yet
                    if not singular_match then
                        local db_singular = item_name:gsub("s$", "")
                        if db_singular ~= item_name then
                            singular_match = (quest_item_name == db_singular or quest_item_name:lower() == db_singular:lower())
                            if singular_match then
                                debug_logger.debug("QUEST_INTERFACE: Matched via db singular: '%s' -> '%s'", item_name, db_singular)
                            end
                        end
                    end
                end
                
                if exact_match or singular_match then
                    -- Found matching quest item
                    -- Parse character:qty pairs from char_list_str
                    for char_qty_pair in char_list_str:gmatch("([^,]+)") do
                        local char_name, qty_str = char_qty_pair:match("^([^:]+):(.+)$")
                        if char_name and qty_str then
                            -- Only include characters who still need this item (qty > 0)
                            local qty = tonumber(qty_str) or 0
                            if qty > 0 then
                                table.insert(needed_by, char_name)
                            end
                        end
                    end
                    break
                end
            end
        end
    else
        debug_logger.warn("QUEST_INTERFACE: Quest data is empty or nil")
    end
    
    if #needed_by > 0 then
        debug_logger.debug("QUEST_INTERFACE: Found %d characters needing '%s'", #needed_by, item_name)
    else
        debug_logger.debug("QUEST_INTERFACE: No characters need '%s'", item_name)
    end
    
    return needed_by
end

--- Get characters who need a specific quest item
quest_interface.get_characters_needing_item = function(item_name)
    if use_native_system then
        if native_tasks and native_tasks.get_characters_needing_item then
            local chars, task_name, objective = native_tasks.get_characters_needing_item(item_name)
            return chars or {}
        else
            debug_logger.warn("QUEST_INTERFACE: native_tasks or get_characters_needing_item function not available")
        end
        return {}
    else
        if external_tasks and external_tasks.get_characters_needing_item then
            return external_tasks.get_characters_needing_item(item_name)
        end
        return {}
    end
end

--- Get all quest items currently being tracked
quest_interface.get_all_quest_items = function()
    if use_native_system then
        if native_tasks and native_tasks.get_quest_items then
            local quest_items = native_tasks.get_quest_items()
            -- Convert the native format (table with keys) to array format
            local items_array = {}
            if quest_items then
                for item_name, _ in pairs(quest_items) do
                    table.insert(items_array, item_name)
                end
            end
            return items_array
        end
        return {}
    else
        if external_tasks and external_tasks.get_all_quest_items then
            return external_tasks.get_all_quest_items()
        end
        return {}
    end
end

--- Refresh quest data for a specific character after they receive loot
quest_interface.refresh_character_after_loot = function(character_name, item_name)
    if use_native_system then
        -- Native system handles this internally
    else
        if external_tasks and external_tasks.refresh_character_after_loot then
            external_tasks.refresh_character_after_loot(character_name, item_name)
        end
    end
end

--- Force refresh of all quest data
quest_interface.refresh_all_characters = function()
    if use_native_system then
        if native_tasks and native_tasks.refresh_all_characters then
            return native_tasks.refresh_all_characters()
        end
        return false
    else
        if external_tasks and external_tasks.request_task_update then
            external_tasks.request_task_update()
            return true
        else
            Write.Warn("External TaskHUD refresh not available")
            return false
        end
    end
end

--- Get current quest system status
quest_interface.get_status = function()
    return {
        system_type = use_native_system and "native" or "external",
        native_available = native_tasks ~= nil,
        external_available = external_tasks ~= nil,
    }
end

--- Switch quest system (requires restart to take effect)
quest_interface.toggle_system = function(global_settings)
    global_settings.settings.use_native_quest_system = not global_settings.settings.use_native_quest_system
    local new_system = global_settings.settings.use_native_quest_system and "native" or "external"
    
    Write.Info("Quest system switched to %s (restart required)", new_system)
    
    return new_system
end

--- Get per-character quest item needs (quantity required per character per item)
quest_interface.get_per_character_needs = function()
    if use_native_system then
        if native_tasks and native_tasks.get_per_character_needs then
            return native_tasks.get_per_character_needs()
        end
        return {}
    else
        -- External system would implement this similarly
        if external_tasks and external_tasks.get_per_character_needs then
            return external_tasks.get_per_character_needs()
        end
        return {}
    end
end

return quest_interface