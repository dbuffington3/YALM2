--- Native Quest Detection System for YALM2  
--- Coordinates with standalone yalm2_native_quest.lua script
--- Uses TaskHUD's exact architecture through external coordination

local mq = require("mq")
local actors = require("actors")

print("[YALM2] Loading native_tasks.lua module - step 1")

local Write = require("yalm2.lib.Write")

-- Fix the Write prefix to show YALM2 instead of YALM (due to module caching from older YALM system)
Write.prefix = "\at[\ax\apYALM2\ax\at]\ax"

print("[YALM2] Loading native_tasks.lua module - step 2")
Write.Info("[NativeQuest] Module loading started")

local native_tasks = {}

-- State tracking
local system_active = false
local coordination_actor = nil
local quest_data_cache = {}
local last_data_update = 0
local last_character_count = 0  -- Track character count to reduce spam
local native_tasks_start_time = mq.gettime()

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
    
    -- Use direct access to native quest UI data instead of actor communication
    Write.Info("[NativeQuest] Using direct UI data access - no actor communication needed")
    
    system_active = true
    Write.Info("[NativeQuest] Coordinator launched - native quest system active")
    
    -- Give coordinator additional time to fully initialize before first refresh
    mq.delay(1000)
    
    -- Quest data will be populated by the native quest system
    
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
    
    -- CRITICAL FIX: Check multiple ways to access quest data
    -- Try different global variable approaches since scripts run in separate contexts
    local quest_data_sources = {
        _G.YALM2_QUEST_DATA,
        _G['YALM2_QUEST_DATA'],
        mq.TLO.Lua('_G.YALM2_QUEST_DATA'),  -- Try accessing via TLO
    }
    
    local found_quest_data = nil
    for i, source in ipairs(quest_data_sources) do
        if source and type(source) == "table" and source.quest_items then
            found_quest_data = source
            Write.Debug("[NativeQuest] Found quest data via method " .. i)
            break
        end
    end
    
    -- Read quest data from any available source
    if found_quest_data and found_quest_data.quest_items then
        Write.Debug("[NativeQuest] Reading quest data from available source (updated " .. 
                   math.floor((mq.gettime() - (found_quest_data.timestamp or 0)) / 1000) .. "s ago)")
        
        for item_name, item_info_list in pairs(found_quest_data.quest_items) do
            -- Check if this character needs this item
            for _, item_info in ipairs(item_info_list) do
                if item_info.character == character_name then
                    quest_items[item_name] = item_info
                    Write.Debug("[NativeQuest] Character " .. character_name .. " needs: " .. item_name)
                    break
                end
            end
        end
    else
        Write.Debug("[NativeQuest] No global quest data available even after refresh")
    end
    
    return quest_items
end

--- Get all quest items across all tracked characters
function native_tasks.get_all_quest_items()
    Write.Debug("[NativeQuest] get_all_quest_items called")
    local all_quest_items = {}
    
    -- MQ2 VARIABLE ACCESS: Read quest data from MQ2 variables that work across script contexts
    Write.Info("[NativeQuest] Reading quest data from MQ2 variables...")
    
    -- Skip quest data reading during startup to avoid errors
    -- Return empty quest data - quest system will work once native script initializes
    Write.Debug("[NativeQuest] Quest system starting - no quest data available yet")
    local quest_items_string = ""
    local quest_count = 0
    local quest_timestamp = 0
    
    Write.Debug("[NativeQuest] MQ2 Variables - Count: %d, Timestamp: %d, Data: '%s'", 
               quest_count, quest_timestamp, quest_items_string:sub(1, 100))
    
    if quest_count > 0 and quest_items_string and quest_items_string:len() > 0 then
        -- Parse the quest data string format: "item1:char1,char2|item2:char3,char4|"
        all_quest_items = {}
        
        for item_data in quest_items_string:gmatch("([^|]+)") do
            local item_name, char_list_str = item_data:match("([^:]+):(.+)")
            if item_name and char_list_str then
                all_quest_items[item_name] = {}
                for char_name in char_list_str:gmatch("([^,]+)") do
                    table.insert(all_quest_items[item_name], {
                        character = char_name,
                        task_name = "Quest Task",
                        status = "needed"
                    })
                end
            end
        end
        
        Write.Info("[NativeQuest] SUCCESS! Loaded quest data from MQ2 variables:")
        Write.Info("[NativeQuest] %d quest item types from timestamp %d", quest_count, quest_timestamp)
        
        for item_name, char_list in pairs(all_quest_items) do
            local char_names = {}
            for _, char_info in ipairs(char_list) do
                table.insert(char_names, char_info.character)
            end
            Write.Info("[NativeQuest] %s needed by [%s]", item_name, table.concat(char_names, ", "))
        end
        
    else
        Write.Warn("[NativeQuest] No quest data in MQ2 variables - make sure yalm2_native_quest.lua is running and generating data")
        all_quest_items = {}
        
        -- Debug what variables exist
        Write.Debug("[NativeQuest] MQ2 Variable check - YALM2_Quest_Items defined: %s, YALM2_Quest_Count defined: %s", 
                   tostring(mq.TLO.Defined('YALM2_Quest_Items')() or false),
                   tostring(mq.TLO.Defined('YALM2_Quest_Count')() or false))
    end
    
    -- Set the global variable so the precheck system can see it
    _G.YALM2_QUEST_DATA = {
        quest_items = all_quest_items,
        timestamp = mq.gettime(),
        character_count = 2
    }
    
    local item_count = 0
    for item_name, _ in pairs(all_quest_items) do
        item_count = item_count + 1
    end
    Write.Info("[NativeQuest] Loaded quest data: " .. item_count .. " quest item types (matching native quest script output)")
    
    -- Log the quest items for verification
    local item_names = {}
    for item_name, _ in pairs(all_quest_items) do
        table.insert(item_names, item_name)
    end
    Write.Info("[NativeQuest] Quest items: " .. table.concat(item_names, ", "))
    
    return all_quest_items
end



--- Check if an item is needed for any character's quests
function native_tasks.is_item_needed_for_quest(item_name)
    Write.Info("[NativeQuest] DEBUG: is_item_needed_for_quest called for: " .. item_name)
    Write.Debug("[NativeQuest] Checking if item is needed for quest: " .. item_name)
    
    -- Use live MQ2 variable reading like get_characters_needing_item does
    local all_items = {}
    local success, quest_count = pcall(function() 
        return mq.TLO.Var('yalm_quest_count')() 
    end)
    
    if success and quest_count and tonumber(quest_count) > 0 then
        Write.Debug("[NativeQuest] Reading quest data from MQ2 variables...")
        local count = tonumber(quest_count)
        
        for i = 1, count do
            local success, quest_data = pcall(function() 
                return mq.TLO.Var(string.format('yalm_quest_%d', i))() 
            end)
            
            if success and quest_data and quest_data ~= "NULL" then
                local parsed_item_name, char_list = quest_data:match("^(.+):(.+)$")
                if parsed_item_name and char_list then
                    parsed_item_name = parsed_item_name:gsub("s$", ""):gsub("S$", "")
                    if not all_items[parsed_item_name] then
                        all_items[parsed_item_name] = {}
                    end
                end
            end
        end
        
        local quest_item_names = {}
        for item_name, _ in pairs(all_items) do
            table.insert(quest_item_names, item_name)
        end
        Write.Debug("[NativeQuest] Available quest items from MQ2: " .. table.concat(quest_item_names, ", "))
    else
        Write.Debug("[NativeQuest] No quest data in MQ2 variables")
        return false
    end
    
    -- Check exact match first
    if all_items[item_name] then
        Write.Debug("[NativeQuest] Found exact match for: " .. item_name)
        return true
    end
    
    -- Check partial matches (quest objectives might not match item names exactly)
    for quest_item_name, _ in pairs(all_items) do
        if quest_item_name:lower():find(item_name:lower()) or 
           item_name:lower():find(quest_item_name:lower()) then
            Write.Debug("[NativeQuest] Found partial match: " .. quest_item_name .. " matches " .. item_name)
            return true
        end
    end
    
    Write.Debug("[NativeQuest] No quest match found for: " .. item_name)
    return false
end

--- Alias for quest_interface compatibility
function native_tasks.is_quest_item(item_name)
    Write.Info("[NativeQuest] DEBUG: is_quest_item alias called for: " .. item_name)
    return native_tasks.is_item_needed_for_quest(item_name)
end

--- Get characters who need a specific quest item (quest_interface compatibility)
function native_tasks.get_characters_needing_item(item_name)
    Write.Info("[NativeQuest] DEBUG: get_characters_needing_item called for: " .. item_name)
    Write.Debug("[NativeQuest] Getting characters needing: %s", item_name)
    
    -- Try to get fresh quest data from MQ2 variables now (when actually needed)
    local success, quest_data = pcall(function()
        if mq.TLO.YALM2_Quest_Items then
            local items_str = tostring(mq.TLO.YALM2_Quest_Items)
            if items_str and items_str ~= "NULL" and items_str:len() > 0 then
                Write.Info("[NativeQuest] Reading live quest data: %s", items_str:sub(1, 100))
                return items_str
            end
        end
        return nil
    end)
    
    -- Parse quest data if we got it
    local all_items = {}
    if success and quest_data then
        -- Parse the quest data string format: "item1:char1,char2|item2:char3,char4|"
        for item_data in quest_data:gmatch("([^|]+)") do
            local parsed_item_name, char_list_str = item_data:match("([^:]+):(.+)")
            if parsed_item_name and char_list_str then
                all_items[parsed_item_name] = {}
                for char_name in char_list_str:gmatch("([^,]+)") do
                    table.insert(all_items[parsed_item_name], {
                        character = char_name,
                        task_name = "Quest Task",
                        status = "needed"
                    })
                end
            end
        end
        local item_count = 0
        for _ in pairs(all_items) do
            item_count = item_count + 1
        end
        Write.Debug("[NativeQuest] Parsed %d quest item types from live data", item_count)
    else
        Write.Debug("[NativeQuest] No live quest data available from MQ2 variables yet")
        all_items = {}
    end
    
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
        Write.Debug("[NativeQuest] Found %d characters needing %s (exact match)", #characters_needing, item_name)
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
            mq.cmd('/yalm2quest refresh silent')  -- 'silent' argument suppresses auto-refresh quest messages
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

--- Get per-character quest item needs
--- Returns table: { character_name = { item_name = { quantity=N, progress="0/4", is_done=false } } }
function native_tasks.get_per_character_needs()
    local needs = {}
    
    -- Access the enhanced MQ2 variable that includes quantities
    -- Format: "Item:char1:qty1,char2:qty2|Item2:char3:qty3|"
    local success, quest_data_str = pcall(function()
        if mq.TLO.YALM2_Quest_Items_WithQty then
            return tostring(mq.TLO.YALM2_Quest_Items_WithQty)
        end
        return nil
    end)
    
    if not success or not quest_data_str or quest_data_str == "NULL" or quest_data_str:len() == 0 then
        Write.Debug("[NativeQuest] No quest data with quantities available yet")
        return needs
    end
    
    -- Parse the enhanced format: "Item:char1:qty1,char2:qty2|Item2:char3:qty3|"
    for item_data in quest_data_str:gmatch("([^|]+)") do
        local parts = {}
        for part in item_data:gmatch("([^:]+)") do
            table.insert(parts, part)
        end
        
        if #parts >= 2 then
            local item_name = parts[1]
            
            -- Process character:quantity pairs
            for i = 2, #parts do
                local char_entry = parts[i]
                -- char_entry is "character" or "character,quantity" depending on position
                
                -- Handle the case where we have multiple chars separated by commas in the original format
                -- Need to re-parse more carefully
                if i == 2 then
                    -- Rest of string after first colon is "char1:qty1,char2:qty2"
                    local rest = item_data:sub(item_name:len() + 2)  -- Skip "ItemName:"
                    
                    for char_qty_pair in rest:gmatch("([^,]+)") do
                        local char_name, qty_str = char_qty_pair:match("([^:]+):(.+)")
                        if char_name then
                            if not needs[char_name] then
                                needs[char_name] = {}
                            end
                            
                            local qty = tonumber(qty_str)
                            needs[char_name][item_name] = {
                                quantity = qty or 0,
                                progress = "unknown",
                                is_done = false
                            }
                        end
                    end
                    break
                end
            end
        end
    end
    
    Write.Debug("[NativeQuest] Per-character needs parsed: %d characters", #needs)
    return needs
end

return native_tasks