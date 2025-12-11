--- Native Quest Detection System for YALM2  
--- Coordinates with standalone yalm2_native_quest.lua script
--- Uses TaskHUD's exact architecture through external coordination

local mq = require("mq")
local actors = require("actors")

print("[YALM2] Loading native_tasks.lua module - step 1")

local Write = require("yalm2.lib.Write")
local quest_data_store = require("yalm2.lib.quest_data_store")
local quest_db = require("yalm2.lib.quest_database")

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
    
    -- DATABASE ACCESS: Read quest data from the quest_tasks database
    Write.Info("[NativeQuest] Reading quest data from database...")
    
    -- Initialize database if needed
    if not quest_db.init() then
        Write.Error("[NativeQuest] Failed to initialize quest database")
        return all_quest_items
    end
    
    -- Get all quest items from the database
    local quest_items_by_item = quest_db.get_all_quest_items()
    
    if quest_items_by_item and next(quest_items_by_item) then
        -- Convert database format {item_name -> [{character, status}, ...]} 
        -- to our internal format for compatibility
        all_quest_items = quest_items_by_item
        
        local total_items = 0
        local total_entries = 0
        for item_name, chars in pairs(all_quest_items) do
            total_items = total_items + 1
            total_entries = total_entries + #chars
        end
        
        Write.Info("[NativeQuest] Loaded %d quest items for %d character needs from database", 
                   total_items, total_entries)
        Write.Debug("[NativeQuest] Quest items: %s", 
                   require("yalm2.lib.inspect")(all_quest_items))
    else
        Write.Debug("[NativeQuest] No quest items found in database")
    end
    
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
    Write.Debug("[NativeQuest] Getting characters needing: %s", item_name)
    
    local characters_needing = {}
    local task_name = nil
    local objective = nil
    
    -- PRIMARY: Read from database (populated by manual refresh)
    local quest_db = require("yalm2.lib.quest_database")
    if quest_db.init() then
        local all_items = quest_db.get_all_quest_items()
        
        if all_items and next(all_items) then
            -- Check exact match first
            if all_items[item_name] then
                Write.Debug("[NativeQuest] Found exact match for '%s' in database", item_name)
                for _, char_info in ipairs(all_items[item_name]) do
                    table.insert(characters_needing, char_info.character)
                    -- Note: database doesn't store task_name/objective, only status
                end
                Write.Debug("[NativeQuest] Found %d characters needing %s (exact match)", #characters_needing, item_name)
                return characters_needing, task_name, objective
            end
            
            -- Check plural/singular variations (e.g., "Tanglefang Pelt" vs "Tanglefang Pelts")
            for quest_item_name, char_list in pairs(all_items) do
                local is_plural_match = false
                
                -- Try removing trailing 's' from each name and comparing
                local item_singular = item_name:gsub("s$", "")
                local quest_singular = quest_item_name:gsub("s$", "")
                
                -- Match if either removing 's' makes them equal (case-insensitive)
                if (item_singular ~= item_name or quest_singular ~= quest_item_name) then
                    if item_singular:lower() == quest_singular:lower() then
                        is_plural_match = true
                    end
                end
                
                if is_plural_match then
                    Write.Debug("[NativeQuest] Found plural/singular match: '%s' vs '%s'", quest_item_name, item_name)
                    for _, char_info in ipairs(char_list) do
                        table.insert(characters_needing, char_info.character)
                    end
                    Write.Debug("[NativeQuest] Found %d characters needing %s (plural/singular match)", #characters_needing, item_name)
                    return characters_needing, task_name, objective
                end
            end
            
            -- Check partial matches
            for quest_item_name, char_list in pairs(all_items) do
                if quest_item_name:lower():find(item_name:lower()) or 
                   item_name:lower():find(quest_item_name:lower()) then
                    Write.Debug("[NativeQuest] Found partial match: '%s' contains '%s'", quest_item_name, item_name)
                    for _, char_info in ipairs(char_list) do
                        table.insert(characters_needing, char_info.character)
                    end
                end
            end
        else
            Write.Debug("[NativeQuest] Database has no quest items - database may be empty")
        end
    else
        Write.Error("[NativeQuest] Failed to initialize database")
    end
    
    -- Fallback to in-memory data if database is empty
    if #characters_needing == 0 then
        Write.Debug("[NativeQuest] No results from database, trying in-memory fallback")
        
        if not _G.YALM2_QUEST_DATA or not _G.YALM2_QUEST_DATA.quest_items then
            Write.Debug("[NativeQuest] YALM2_QUEST_DATA not populated yet, calling get_all_quest_items()")
            native_tasks.get_all_quest_items()
        end
        
        local quest_data = _G.YALM2_QUEST_DATA
        local wait_count = 0
        while (not quest_data or not quest_data.quest_items) and wait_count < 50 do
            mq.delay(100)
            quest_data = _G.YALM2_QUEST_DATA
            wait_count = wait_count + 1
        end
        
        if quest_data and quest_data.quest_items then
            Write.Debug("[NativeQuest] Using in-memory YALM2_QUEST_DATA with %d characters", quest_data.character_count or 0)
            
            -- Same matching logic as database
            if quest_data.quest_items[item_name] then
                for _, char_info in ipairs(quest_data.quest_items[item_name]) do
                    table.insert(characters_needing, char_info.character)
                    task_name = task_name or char_info.task_name
                    objective = objective or char_info.objective
                end
            else
                -- Check plural/singular and partial matches in in-memory data
                for quest_item_name, char_list in pairs(quest_data.quest_items) do
                    local item_singular = item_name:gsub("s$", "")
                    local quest_singular = quest_item_name:gsub("s$", "")
                    
                    if (item_singular ~= item_name or quest_singular ~= quest_item_name) and
                       item_singular:lower() == quest_singular:lower() then
                        for _, char_info in ipairs(char_list) do
                            table.insert(characters_needing, char_info.character)
                            task_name = task_name or char_info.task_name
                            objective = objective or char_info.objective
                        end
                        break
                    end
                end
            end
        end
    end
    
    Write.Debug("[NativeQuest] Final result for '%s': found %d characters", item_name, #characters_needing)
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

--- TEST FUNCTION: Set a test MQ2 variable to verify communication is working
--- Call this from YALM2 to set a test variable, then check if yalm2_native_quest can read it
function native_tasks.test_set_mq2_variable()
    Write.Info("[TEST] Setting test MQ2 variable from native_tasks...")
    local test_data = "TEST_DATA_FROM_NATIVE_TASKS_" .. os.time()
    
    -- Set the test variable
    mq.cmd(string.format('/declare YALM2_Test_Var string outer "%s"', test_data))
    mq.delay(100)
    mq.cmd(string.format('/varset YALM2_Test_Var "%s"', test_data))
    
    Write.Info("[TEST] Set YALM2_Test_Var = %s", test_data)
    return test_data
end

--- TEST FUNCTION: Try to read a test MQ2 variable to verify communication is working
--- Call this to see if you can read variables that were set by other scripts
function native_tasks.test_read_mq2_variable()
    Write.Info("[TEST] Attempting to read test MQ2 variable from native_tasks...")
    
    local success, result = pcall(function()
        local var_defined = mq.TLO.Defined('YALM2_Test_Var')
        if var_defined and var_defined() then
            return tostring(mq.TLO.YALM2_Test_Var() or "NULL")
        end
        return "NOT_DEFINED"
    end)
    
    if success then
        Write.Info("[TEST] Successfully read YALM2_Test_Var = %s", result)
        return result
    else
        Write.Info("[TEST] FAILED to read YALM2_Test_Var: %s", result)
        return nil
    end
end

--- TEST FUNCTION: Continuously monitor an MQ2 variable for changes
--- Use this to verify variables are being updated in real-time
function native_tasks.test_monitor_variable(var_name, duration_seconds)
    var_name = var_name or "YALM2_Test_Var"
    duration_seconds = duration_seconds or 30
    
    Write.Info("[TEST] Monitoring %s for %d seconds...", var_name, duration_seconds)
    
    local start_time = mq.gettime()
    local last_value = nil
    local change_count = 0
    
    while (mq.gettime() - start_time) < (duration_seconds * 1000) do
        local success, result = pcall(function()
            local var_defined = mq.TLO.Defined(var_name)
            if var_defined and var_defined() then
                return tostring(mq.TLO[var_name]() or "NULL")
            end
            return "NOT_DEFINED"
        end)
        
        if success then
            if result ~= last_value then
                Write.Info("[TEST] %s changed to: %s (change #%d)", var_name, result, change_count + 1)
                last_value = result
                change_count = change_count + 1
            end
        else
            Write.Info("[TEST] Error reading %s: %s", var_name, result)
        end
        
        mq.delay(1000)  -- Check every second
    end
    
    Write.Info("[TEST] Monitor complete. Variable changed %d times in %d seconds", change_count, duration_seconds)
end

return native_tasks