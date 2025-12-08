--- Unified Quest Interface for YALM2
--- Provides a single interface for both external TaskHUD and native quest systems
--- Automatically routes to the appropriate implementation based on configuration

local mq = require("mq")
local debug_logger = require("yalm2.lib.debug_logger")

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
    
    debug_logger.info("QUEST_INTERFACE: Using %s quest system", use_native_system and "native" or "external")
    Write.Info("Quest interface initialized for %s quest system", use_native_system and "native" or "external")
end

--- Check if an item is needed for quests
quest_interface.is_quest_item = function(item_name)
    if use_native_system then
        if native_tasks and native_tasks.is_quest_item then
            return native_tasks.is_quest_item(item_name)
        end
        return false
    else
        if external_tasks and external_tasks.is_quest_item then
            return external_tasks.is_quest_item(item_name)
        end
        return false
    end
end

--- Get characters who need a specific quest item
quest_interface.get_characters_needing_item = function(item_name)
    if use_native_system then
        if native_tasks and native_tasks.get_characters_needing_item then
            local chars, task_name, objective = native_tasks.get_characters_needing_item(item_name)
            return chars or {}
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
        debug_logger.info("QUEST_INTERFACE: Native system - no per-character refresh needed for %s", character_name)
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
    debug_logger.info("QUEST_INTERFACE: System toggled to %s", new_system)
    
    return new_system
end

return quest_interface