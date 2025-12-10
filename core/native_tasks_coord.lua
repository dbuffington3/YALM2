--- Native Quest Detection System for YALM2  
--- Coordinates with standalone yalm2_native_quest.lua script
--- Uses TaskHUD's exact architecture through external coordination

local mq = require("mq")
local actors = require("actors")
require("yalm2.lib.Write")

local native_tasks = {}

-- State tracking
local system_active = false
local coordination_actor = nil
local quest_data_cache = {}
local last_data_update = 0

--- Initialize the native quest system by launching the coordinator
function native_tasks.initialize()
    Write.Info("[NativeQuest] Starting YALM2 Native Quest Coordinator...")
    
    -- Stop any existing instances
    mq.cmd('/lua stop yalm2_native_quest')
    mq.delay(500)
    
    -- Start the coordinator script (TaskHUD style)
    mq.cmd('/lua run yalm2\\yalm2_native_quest')
    
    -- Set up communication with the coordinator
    coordination_actor = actors.register(function(message)
        if message.content.id == 'YALM2_QUEST_DATA' then
            quest_data_cache = message.content.data or {}
            last_data_update = mq.gettime()
            Write.Debug("[NativeQuest] Received quest data update")
        end
    end)
    
    system_active = true
    Write.Info("[NativeQuest] Coordinator launched - native quest system active")
    return true
end

--- Stop the native quest system
function native_tasks.shutdown()
    Write.Info("[NativeQuest] Shutting down native quest system...")
    system_active = false
    
    -- Stop the coordinator script
    mq.cmd('/lua stop yalm2_native_quest')
    
    quest_data_cache = {}
end

--- Refresh all character quest data
function native_tasks.refresh_all_characters()
    if not system_active then
        Write.Warn("[NativeQuest] Native quest system not active")
        return
    end
    
    Write.Info("[NativeQuest] Requesting quest data refresh...")
    -- Send refresh command to coordinator
    mq.cmd('/yalm2quest refresh')
end

--- Get quest items needed by a specific character
function native_tasks.get_quest_items_for_character(character_name)
    local quest_items = {}
    
    if not quest_data_cache.tasks or not quest_data_cache.tasks[character_name] then
        return quest_items
    end
    
    for _, task in ipairs(quest_data_cache.tasks[character_name]) do
        for _, objective in ipairs(task.objectives) do
            -- Parse item names from objectives
            -- Look for common quest item patterns
            local patterns = {
                "([%w%s]+) %d+/%d+",  -- "Item Name 5/10"
                "([%w%s]+) %(Done%)",  -- "Item Name (Done)" 
                "([%w%s]+)$"           -- Just the item name
            }
            
            for _, pattern in ipairs(patterns) do
                local item_name = objective.objective:match(pattern)
                if item_name and item_name:len() > 3 and not item_name:match("^%s*$") then
                    quest_items[item_name:gsub("^%s*(.-)%s*$", "%1")] = {  -- Trim whitespace
                        task_name = task.task_name,
                        objective = objective.objective,
                        status = objective.status,
                        character = character_name
                    }
                    break  -- Found a match, move to next objective
                end
            end
        end
    end
    
    return quest_items
end

--- Get all quest items across all tracked characters
function native_tasks.get_all_quest_items()
    local all_quest_items = {}
    
    if not quest_data_cache.tasks then
        return all_quest_items
    end
    
    for character_name, _ in pairs(quest_data_cache.tasks) do
        local character_items = native_tasks.get_quest_items_for_character(character_name)
        for item_name, item_info in pairs(character_items) do
            all_quest_items[item_name] = all_quest_items[item_name] or {}
            table.insert(all_quest_items[item_name], item_info)
        end
    end
    
    return all_quest_items
end

--- Check if an item is needed for any character's quests
function native_tasks.is_item_needed_for_quest(item_name)
    local all_items = native_tasks.get_all_quest_items()
    
    -- Check exact match first
    if all_items[item_name] then
        return true
    end
    
    -- Check partial matches (quest objectives might not match item names exactly)
    for quest_item_name, _ in pairs(all_items) do
        if quest_item_name:lower():find(item_name:lower()) or 
           item_name:lower():find(quest_item_name:lower()) then
            return true
        end
    end
    
    return false
end

--- Get list of tracked characters
function native_tasks.get_tracked_characters()
    if not quest_data_cache.peer_list then
        return {}
    end
    return quest_data_cache.peer_list
end

--- Check if system is active and has recent data
function native_tasks.is_active()
    local has_recent_data = (mq.gettime() - last_data_update) < 30000  -- 30 seconds
    return system_active and has_recent_data and #native_tasks.get_tracked_characters() > 0
end

--- Get status for debugging
function native_tasks.get_status()
    local characters = native_tasks.get_tracked_characters()
    local data_age = mq.gettime() - last_data_update
    
    return {
        active = system_active,
        characters_tracked = #characters,
        data_age_ms = data_age,
        has_recent_data = data_age < 30000,
        peer_list = characters,
        total_quest_items = 0  -- Could calculate this if needed
    }
end

--- Process background tasks (called from main YALM2 loop)
function native_tasks.process()
    -- Request data update if we haven't had one recently
    if system_active and (mq.gettime() - last_data_update) > 10000 then  -- 10 seconds
        -- Silently refresh to keep data current
        mq.cmd('/yalm2quest refresh silent')  -- 'silent' argument suppresses auto-refresh quest messages
        last_data_update = mq.gettime()  -- Prevent spam
    end
end

--- Force immediate task collection
function native_tasks.collect_my_tasks()
    if system_active then
        mq.cmd('/yalm2quest refresh')
    end
end

--- Legacy compatibility functions
function native_tasks.shutdown_collectors()
    native_tasks.shutdown()
end

return native_tasks