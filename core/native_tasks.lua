--- Native Quest Detection System for YALM2  
--- Coordinates with standalone yalm2_native_quest.lua script
--- Uses TaskHUD's exact architecture through external coordination

local mq = require("mq")
local actors = require("actors")

print("[YALM2] Loading native_tasks.lua module - step 1")

local Write = require("yalm2.lib.Write")

print("[YALM2] Loading native_tasks.lua module - step 2")
Write.Info("[NativeQuest] Module loading started")

local native_tasks = {}

-- State tracking
local system_active = false
local coordination_actor = nil
local quest_data_cache = {}
local last_data_update = 0

--- Initialize the native quest system by launching the coordinator
function native_tasks.initialize()
    print("[YALM2] native_tasks.initialize() called")
    Write.Info("[NativeQuest] Starting YALM2 Native Quest Coordinator...")
    
    -- Stop any existing instances on ALL characters first (global cleanup)
    Write.Info("[NativeQuest] Cleaning up any existing native quest instances...")
    mq.cmd('/dgga /lua stop yalm2/yalm2_native_quest')
    mq.delay(1000)  -- Give time for all characters to stop
    mq.cmd('/lua stop yalm2/yalm2_native_quest')  -- Stop local instance too
    mq.delay(500)
    
    -- Start the coordinator script (TaskHUD style)
    Write.Info("[NativeQuest] Starting fresh coordinator instance...")
    mq.cmd('/lua run yalm2/yalm2_native_quest')
    
    -- Wait for coordinator to initialize before setting up communication
    mq.delay(2000)  -- Give coordinator time to start and initialize
    
    -- Set up communication with the coordinator
    Write.Info("[NativeQuest] Registering actor for quest data communication...")
    coordination_actor = actors.register(function(message)
        Write.Info("[NativeQuest] *** ACTOR CALLBACK TRIGGERED *** Message from: " .. tostring(message.sender and message.sender.character or "unknown"))
        Write.Info("[NativeQuest] Message ID: " .. tostring(message.content and message.content.id or "nil"))
        if message.content and message.content.id == 'YALM2_QUEST_DATA' then
            quest_data_cache = message.content.data or {}
            last_data_update = mq.gettime()
            Write.Info("[NativeQuest] Received quest data update with " .. (quest_data_cache.peer_list and #quest_data_cache.peer_list or 0) .. " characters")
            
            -- DEBUG: Show what characters we have data for
            if quest_data_cache.tasks then
                for char_name, tasks in pairs(quest_data_cache.tasks) do
                    Write.Info("[NativeQuest] Data for " .. char_name .. ": " .. #tasks .. " tasks")
                end
            end
        end
    end)
    Write.Info("[NativeQuest] Actor registered successfully")
    
    system_active = true
    Write.Info("[NativeQuest] Coordinator launched - native quest system active")
    
    -- Give coordinator additional time to fully initialize before first refresh
    mq.delay(1000)
    
    return true
end

--- Stop the native quest system
function native_tasks.shutdown()
    Write.Info("[NativeQuest] Shutting down native quest system...")
    system_active = false
    
    -- Stop coordinator scripts on all characters
    Write.Info("[NativeQuest] Stopping coordinator on all characters...")
    mq.cmd('/dgga /lua stop yalm2/yalm2_native_quest')
    mq.cmd('/lua stop yalm2/yalm2_native_quest')
    
    quest_data_cache = {}
    last_data_update = 0
end

--- Refresh all character quest data
function native_tasks.refresh_all_characters()
    if not system_active then
        Write.Warn("[NativeQuest] Native quest system not active")
        return
    end
    
    Write.Debug("[NativeQuest] Refreshing quest data from all characters...")
    -- Send refresh command to coordinator (with error handling)
    local success = pcall(function()
        mq.cmd('/yalm2quest refresh')
    end)
    if not success then
        Write.Warn("[NativeQuest] Coordinator not ready yet - command failed")
    end
end

--- Get quest items needed by a specific character
function native_tasks.get_quest_items_for_character(character_name)
    Write.Debug("[NativeQuest] get_quest_items_for_character called for: " .. character_name)
    local quest_items = {}
    
    -- For now, return empty since the standalone script has the real data
    -- We need to figure out how to access the data from yalm2_native_quest.lua
    Write.Info("[NativeQuest] Quest item detection not yet implemented - need to access standalone script data")
    
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

--- Alias for quest_interface compatibility
function native_tasks.is_quest_item(item_name)
    return native_tasks.is_item_needed_for_quest(item_name)
end

--- Get characters who need a specific quest item (quest_interface compatibility)
function native_tasks.get_characters_needing_item(item_name)
    local all_items = native_tasks.get_all_quest_items()
    local characters_needing = {}
    local task_name = nil
    local objective = nil
    
    -- Check exact match first
    if all_items[item_name] then
        for _, item_info in ipairs(all_items[item_name]) do
            table.insert(characters_needing, item_info.character)
            task_name = task_name or item_info.task_name
            objective = objective or item_info.objective
        end
        return characters_needing, task_name, objective
    end
    
    -- Check partial matches
    for quest_item_name, item_infos in pairs(all_items) do
        if quest_item_name:lower():find(item_name:lower()) or 
           item_name:lower():find(quest_item_name:lower()) then
            for _, item_info in ipairs(item_infos) do
                table.insert(characters_needing, item_info.character)
                task_name = task_name or item_info.task_name
                objective = objective or item_info.objective
            end
        end
    end
    
    return characters_needing, task_name, objective
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
    if system_active and (mq.gettime() - last_data_update) > 30000 then  -- 30 seconds instead of 10
        -- Silently refresh to keep data current (with error handling)
        local success = pcall(function()
            mq.cmd('/yalm2quest refresh')
        end)
        if success then
            last_data_update = mq.gettime()  -- Only update timestamp if command succeeded
        end
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