--- Native Quest Detection System for YALM2
--- Uses TaskHUD's exact architecture - same script runs everywhere with UI flag
--- Eliminates separate master/collector scripts - one unified approach

local mq = require("mq")
local dannet = require("yalm2.lib.dannet")
local actors = require("actors")
local debug_logger = require("yalm2.lib.debug_logger")
require("yalm2.lib.Write")

local native_tasks = {}

-- TaskHUD-style internal state
local task_data = {
    tasks = {},      -- character_name -> task_array (TaskHUD format)
    my_tasks = {},   -- This character's tasks 
}

local peer_list = {}
local triggers = {
    do_refresh = false,
    timestamp = mq.gettime(),
    need_task_update = false
}

local my_name = mq.TLO.Me.DisplayName()
local task_actor = nil  -- Will be initialized when system starts
local system_active = false
local show_ui = false  -- Only master character shows UI

--- Get tasks for the current character using TaskHUD's proven method
--- This is TaskHUD's core logic adapted for YALM2
native_tasks.get_current_character_tasks = function()
    Write.Info("Getting tasks for current character using native quest detection...")
    local tasks = {}
    
    -- Open the task window (TaskHUD's approach)
    mq.TLO.Window('TaskWnd').DoOpen()
    while mq.TLO.Window('TaskWnd').Open() == false do
        mq.delay(100)  -- Wait for window to open
    end
    
    local count1, count2 = 1, 1
    for i = 1, mq.TLO.Window('TaskWnd/TASK_TaskList').Items() do
        mq.TLO.Window('TaskWnd/TASK_TaskList').Select(i)
        while mq.TLO.Window('TaskWnd/TASK_TaskList').GetCurSel() ~= i do
            mq.delay(50)  -- Wait for selection
        end
        
        -- Check that the name of the task is not nil (skip separator lines)
        if mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)() ~= nil then
            tasks[count1] = {
                task_name = mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)(),
                objectives = {},
            }

            -- Loop through the objectives of the current task
            for j = 1, mq.TLO.Window('TaskWnd/TASK_TaskElementList').Items() do
                -- Check that the name of the objective is not nil (skip separator lines)
                if mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)() ~= nil then
                    local tmp_objective = {
                        objective = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 1)(),
                        status = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)(),
                    }
                    table.insert(tasks[count1]['objectives'], count2, tmp_objective)
                    count2 = count2 + 1
                end
            end
            count2 = 1
            count1 = count1 + 1
        end
    end
    
    -- Close the task window
    mq.TLO.Window('TaskWnd').DoClose()
    
    Write.Info("Native quest detection found %d tasks for current character", #tasks)
    debug_logger.info("NATIVE_TASKS: Found %d tasks for %s", #tasks, mq.TLO.Me.DisplayName())
    
    return tasks
end

--- Get validated connected characters (uses cached results from initialization)
native_tasks.get_connected_characters = function()
    -- Return the already-validated connected members from initialization
    if native_task_data.connected_members then
        Write.Debug("Returning %d pre-validated connected members: [%s]", 
            #native_task_data.connected_members, table.concat(native_task_data.connected_members, ", "))
        return native_task_data.connected_members
    end
    
    -- Fallback: re-validate if data not available (shouldn't happen after proper initialization)
    Write.Warn("Connected members not cached - re-validating (this shouldn't happen)")
    local composition = native_tasks.get_expected_group_composition()
    local connectivity = native_tasks.validate_dannet_connectivity(composition)
    -- Legacy compatibility - to be removed in TaskHUD architecture
    return connectivity.connected
end

--- Request tasks from YALM2 task collectors via actor messaging
native_tasks.request_tasks_from_collectors = function(character_names)
    Write.Info("Broadcasting REQUEST_TASKS to %d collectors...", #character_names)
    
    if not native_task_data.task_actor then
        Write.Error("Task actor not initialized - cannot request collector data")
        return false
    end
    
    Write.Info("Master actor status: %s", tostring(native_task_data.task_actor ~= nil))
    
    -- Send task request via broadcast (all collectors will receive)
    local success, error_msg = pcall(function()
        native_task_data.task_actor:send({
            id = 'REQUEST_TASKS',
            timestamp = os.time(),
            expected_collectors = character_names  -- Help collectors identify if they should respond
        })
    end)
    
    local requests_sent = 0
    if success then
        Write.Info("✅ Successfully broadcast REQUEST_TASKS to all collectors")
        requests_sent = #character_names
    else
        Write.Error("❌ Failed to broadcast REQUEST_TASKS: %s", error_msg or "unknown error")
    end
    
    Write.Info("Task request broadcast completed: %d/%d expected to respond", requests_sent, #character_names)
    return requests_sent > 0
end

--- Wait for and collect task responses from collectors
native_tasks.collect_responses_from_collectors = function(expected_characters, timeout_ms)
    timeout_ms = timeout_ms or 5000
    local start_time = os.clock() * 1000
    local responses = {}
    
    Write.Debug("Waiting for task responses from %d collectors (timeout: %dms)...", #expected_characters, timeout_ms)
    
    -- Initialize responses table if needed (but don't clear existing responses)
    native_task_data.collector_responses = native_task_data.collector_responses or {}
    
    -- Count responses properly (responses is a table with string keys)
    local function count_responses()
        local count = 0
        for _ in pairs(responses) do count = count + 1 end
        return count
    end
    
    while (os.clock() * 1000 - start_time) < timeout_ms and count_responses() < #expected_characters do
        mq.doevents() -- Process actor messages
        mq.delay(100)
        
        -- Check for new responses
        for character_name, response in pairs(native_task_data.collector_responses or {}) do
            if not responses[character_name] then
                responses[character_name] = response
                Write.Debug("  %s: Received %d tasks", character_name, #response.tasks)
            end
        end
    end
    
    local response_count = count_responses()
    
    Write.Debug("Collected %d/%d responses within timeout", response_count, #expected_characters)
    return responses
end

--- Extract quest items from native task data
native_tasks.extract_quest_items = function()
    Write.Info("Extracting quest items from native task data...")
    native_task_data.quest_items = {}
    
    -- Import quest item patterns from tasks module
    local quest_item_patterns = {
        "Sample$", "Essence$", "Fragment$", "Shard$", "Component$", "Part$", "Piece$", 
        "Token$", "Medallion$", "Emblem$", "Seal$", "Crystal$", "Gem$", "Stone$", 
        "Ore$", "Metal$", "Wood$", "Bone$", "Scale$", "Claw$", "Fang$", "Hide$", 
        "Pelt$", "Feather$", "Wing$", "Heart$", "Brain$", "Eye$", "Blood$", "Bile$", 
        "Dust$", "Powder$"
    }
    
    local quest_items_found = 0
    
    -- Process each character's tasks
    for character_name, char_data in pairs(native_task_data.characters) do
        if char_data.tasks and #char_data.tasks > 0 then
            Write.Debug("Processing tasks for %s (%d tasks)", character_name, #char_data.tasks)
            
            for _, task in ipairs(char_data.tasks) do
                if task.objectives then
                    for _, objective in ipairs(task.objectives) do
                        if objective.objective and objective.objective ~= "? ? ?" and objective.objective ~= "" then
                            -- Only process LOOT/COLLECT objectives
                            local is_loot_objective = objective.objective:match("^Loot ") or objective.objective:match("^Collect ")
                            
                            if is_loot_objective then
                                local needs_item = (objective.status ~= "Done" and objective.status ~= "")
                                
                                if needs_item then
                                    local extracted_item = native_tasks.extract_quest_item_name(objective.objective, quest_item_patterns)
                                    
                                    if extracted_item then
                                        Write.Info("Found quest item need: %s for %s (task: %s)", 
                                            extracted_item, character_name, task.task_name)
                                        
                                        if not native_task_data.quest_items[extracted_item] then
                                            native_task_data.quest_items[extracted_item] = {
                                                needed_by = {},
                                                task_name = task.task_name,
                                                objective = objective.objective
                                            }
                                            quest_items_found = quest_items_found + 1
                                        end
                                        
                                        -- Add character to needed_by list if not already there
                                        local already_added = false
                                        for _, char in ipairs(native_task_data.quest_items[extracted_item].needed_by) do
                                            if char == character_name then
                                                already_added = true
                                                break
                                            end
                                        end
                                        
                                        if not already_added then
                                            table.insert(native_task_data.quest_items[extracted_item].needed_by, character_name)
                                        end
                                        
                                        debug_logger.quest("NATIVE_QUEST_ITEM: %s -> [%s] task:'%s'", 
                                            extracted_item, character_name, task.task_name)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    Write.Info("Native quest extraction found %d quest items that need collecting", quest_items_found)
    debug_logger.info("NATIVE_EXTRACTION: Found %d quest items", quest_items_found)
end

--- Extract quest item name from objective text (borrowed from tasks.lua)
native_tasks.extract_quest_item_name = function(objective_text, quest_item_patterns)
    if not objective_text then return nil end
    
    local item_name = nil
    
    -- Try various loot patterns
    item_name = objective_text:match("Loot %d+ (.+) from") or
                objective_text:match("Loot a (.+) from") or
                objective_text:match("Loot some (.+) from") or
                objective_text:match("Collect %d+ (.+) from") or
                objective_text:match("Collect a few (.+) from") or
                objective_text:match("Collect some (.+) from") or
                objective_text:match("Collect %d+ (.+)") or
                objective_text:match("Collect (.+)") or
                objective_text:match("Loot %d+ (.+)") or
                objective_text:match("Loot (.+)")
    
    -- Convert plural to singular and apply title case
    if item_name then
        local lowercase_item = item_name:lower()
        if lowercase_item:match("(.+) samples?$") then
            local base = item_name:match("(.+) [Ss]amples?$")
            if base then
                item_name = base .. " Sample"
            end
        elseif item_name:lower():match("(.+)s$") and not item_name:lower():match("ss$") then
            item_name = item_name:gsub("s$", "")
        end
        
        -- Title case
        item_name = item_name:gsub("(%w)([%w']*)", function(first, rest)
            return string.upper(first) .. string.lower(rest)
        end)
        
        -- Check against quest item patterns
        for _, pattern in ipairs(quest_item_patterns) do
            if item_name:match(pattern) then
                return item_name
            end
        end
    end
    
    return nil
end

--- Get expected group/raid composition before testing connectivity
native_tasks.get_expected_group_composition = function()
    local composition = {
        type = "Solo",
        members = {},
        names = {}
    }
    
    -- Check raid first (takes precedence over group)
    if mq.TLO.Raid.Members() > 0 then
        composition.type = "Raid"
        
        -- Add self
        table.insert(composition.members, {name = mq.TLO.Me.DisplayName(), index = 0})
        table.insert(composition.names, mq.TLO.Me.DisplayName())
        
        -- Add raid members
        for i = 1, mq.TLO.Raid.Members() do
            local member_name = mq.TLO.Raid.Member(i).DisplayName()
            if member_name and member_name ~= "" then
                -- Avoid duplicates
                local already_added = false
                for _, existing in ipairs(composition.members) do
                    if existing.name == member_name then
                        already_added = true
                        break
                    end
                end
                
                if not already_added then
                    table.insert(composition.members, {name = member_name, index = i})
                    table.insert(composition.names, member_name)
                end
            end
        end
    elseif mq.TLO.Group.Members() > 0 then
        composition.type = "Group"
        
        -- Add all group members including self
        for i = 0, mq.TLO.Group.Members() do
            local member_name = nil
            if i == 0 then
                member_name = mq.TLO.Me.DisplayName()
            else
                member_name = mq.TLO.Group.Member(i).DisplayName()
            end
            
            if member_name and member_name ~= "" then
                table.insert(composition.members, {name = member_name, index = i})
                table.insert(composition.names, member_name)
            end
        end
    else
        -- Solo mode
        table.insert(composition.members, {name = mq.TLO.Me.DisplayName(), index = 0})
        table.insert(composition.names, mq.TLO.Me.DisplayName())
    end
    
    return composition
end

--- Test DanNet connectivity for all expected members
native_tasks.validate_dannet_connectivity = function(expected_members, fast_mode)
    local results = {
        connected = {},
        missing = {},
        connected_count = 0,
        details = {}
    }
    
    if fast_mode then
        Write.Info("Fast DanNet connectivity test for %d expected %s members...", 
            #expected_members.members, expected_members.type)
    else
        Write.Info("Testing DanNet connectivity for %d expected %s members...", 
            #expected_members.members, expected_members.type)
    end
    
    for _, member in ipairs(expected_members.members) do
        Write.Debug("Testing DanNet connectivity to %s...", member.name)
        
        local response = dannet.query(member.name, "Me.Name", fast_mode and 250 or 500)
        if response and response ~= "NULL" and response ~= "" then
            table.insert(results.connected, member.name)
            results.connected_count = results.connected_count + 1
            
            if fast_mode then
                -- Fast mode: skip extra details
                results.details[member.name] = {
                    connected = true,
                    mode = "fast"
                }
                Write.Info("✅ %s - Connected", member.name)
            else
                -- Full mode: get detailed info
                local zone = dannet.query(member.name, "Zone.ShortName", 250) or "unknown"
                local class = dannet.query(member.name, "Me.Class.ShortName", 250) or "unknown"
                local level = dannet.query(member.name, "Me.Level", 250) or "unknown"
                
                results.details[member.name] = {
                    zone = zone,
                    class = class,
                    level = level,
                    connected = true
                }
                Write.Info("✅ %s - %s %s in %s", member.name, level, class, zone)
            end
        else
            table.insert(results.missing, member.name)
            results.details[member.name] = {
                connected = false,
                error = "No DanNet response"
            }
            Write.Warn("❌ %s - No DanNet response", member.name)
        end
    end
    
    return results
end

--- Actor message handler for collector communication
local function handle_collector_message(message)
    if not message.content or not message.content.id then
        return
    end
    
    if message.content.id == 'REQUEST_TASKS' then
        -- Master also responds to REQUEST_TASKS (like TaskHUD does)
        Write.Info("✅ Master received REQUEST_TASKS, collecting own tasks...")
        
        -- Get master's tasks and add to responses
        local my_tasks = native_tasks.get_current_character_tasks()
        local master_name = mq.TLO.Me.Name()
        
        native_task_data.collector_responses = native_task_data.collector_responses or {}
        native_task_data.collector_responses[master_name] = {
            tasks = my_tasks,
            timestamp = os.time()
        }
        
        Write.Info("✅ Master added %d own tasks to collection", #my_tasks)
        
    elseif message.content.id == 'INCOMING_TASKS' then
        -- Received task data from a collector (TaskHUD's exact message ID)
        local character = message.sender.character
        local tasks = message.content.tasks or {}
        
        if character and tasks then
            native_task_data.collector_responses = native_task_data.collector_responses or {}
            native_task_data.collector_responses[character] = {
                tasks = tasks,
                timestamp = os.time()
            }
            Write.Info("✅ Received %d tasks from collector %s", #tasks, character)
        end
        
    elseif message.content.id == 'COLLECTOR_READY' then
        -- A collector has come online
        local character = message.sender.character
        Write.Debug("Task collector %s is ready", character or "unknown")
        
    elseif message.content.id == 'COLLECTOR_TEST' then
        -- Test message from collector
        local character = message.content.character
        Write.Info("✅ Received test message from collector: %s", character or "unknown")
        
    elseif message.content.id == 'YALM2_COLLECTOR_SHUTDOWN' then
        -- A collector is shutting down
        local character = message.content.character
        Write.Debug("Task collector %s shutting down", character or "unknown")
    end
end

--- Auto-start task collectors on all group/raid members
native_tasks.start_collectors_on_group_members = function(connected_characters)
    Write.Info("Auto-starting task collectors on group members...")
    
    local current_character = mq.TLO.Me.DisplayName()
    local remote_characters = {}
    
    -- Collect list of remote characters first
    for _, character_name in ipairs(connected_characters) do
        if character_name ~= current_character then
            table.insert(remote_characters, character_name)
        end
    end
    
    if #remote_characters == 0 then
        Write.Info("No remote characters found - running in solo mode")
        return
    end
    
    -- Step 1: Stop any existing collectors to ensure clean state and code updates
    Write.Info("Stopping any existing task collectors to ensure clean state...")
    mq.cmdf('/dgga /lua stop yalm2/task_collector')
    mq.delay(1000) -- Give time for scripts to stop
    
    -- Step 2: Start fresh collectors on each character
    Write.Info("Starting fresh task collectors on %d characters...", #remote_characters)
    local collectors_started = 0
    
    for _, character_name in ipairs(remote_characters) do
        Write.Info("  Starting task collector on %s...", character_name)
        
        -- Start the task collector
        mq.cmdf('/dex %s /lua run yalm2\\task_collector', character_name)
        collectors_started = collectors_started + 1
        
        -- Small delay between starts to prevent overwhelming
        mq.delay(300)
    end
    
    Write.Info("Started task collectors on %d characters", collectors_started)
    
    if collectors_started > 0 then
        Write.Info("Waiting 5 seconds for collectors to initialize...")
        mq.delay(5000) -- Give collectors time to start up and register actors
        Write.Info("Collectors should now be ready for communication")
    end
end

--- Initialize actor system for collector communication
native_tasks.initialize_actor_system = function()
    Write.Debug("Initializing actor system for collector communication...")
    
    -- Use TaskHUD's approach: anonymous actor registration (no name)
    native_task_data.task_actor = actors.register(handle_collector_message)
    if not native_task_data.task_actor then
        Write.Error("Failed to register anonymous actor")
        return false
    else
        Write.Debug("Registered anonymous actor (TaskHUD style)")
    end
    
    Write.Debug("Task actor registered successfully")
    return true
end

--- Initialize solo mode (fallback when no group/raid)
native_tasks.initialize_solo_mode = function()
    Write.Info("Initializing native quest system in solo mode...")
    
    -- Initialize actor system even for solo mode (for consistency)
    if not native_tasks.initialize_actor_system() then
        Write.Warn("Actor system initialization failed in solo mode")
    end
    
    -- Initialize for solo character only
    native_task_data.characters = {}
    native_task_data.quest_items = {}
    native_task_data.master_looter = mq.TLO.Me.DisplayName()
    native_task_data.expected_members = {mq.TLO.Me.DisplayName()}
    native_task_data.connected_members = {mq.TLO.Me.DisplayName()}
    
    -- Get current character's tasks
    local my_tasks = native_tasks.get_current_character_tasks()
    native_task_data.characters[native_task_data.master_looter] = {
        tasks = my_tasks,
        last_updated = os.time()
    }
    
    -- Extract quest items
    native_tasks.extract_quest_items()
    
    Write.Info("Solo mode initialized with %d quest tasks", #my_tasks)
    return true
end

--- Initialize native quest system with comprehensive validation
native_tasks.initialize = function()
    Write.Info("=== Native Quest System Startup Validation ===")
    
    -- Step 1: Determine expected group/raid composition
    local expected_members = native_tasks.get_expected_group_composition()
    Write.Info("Group composition: %s with %d members", expected_members.type, #expected_members.members)
    Write.Info("Expected members: [%s]", table.concat(expected_members.names, ", "))
    
    if #expected_members.members == 1 and expected_members.type == "Solo" then
        return native_tasks.initialize_solo_mode()
    end
    
    -- Step 2: Test DanNet connectivity for ALL expected members (fast mode for startup)
    Write.Info("Validating DanNet connectivity...")
    local connectivity_results = native_tasks.validate_dannet_connectivity(expected_members, true)
    
    -- Step 3: Report connectivity results
    Write.Info("DanNet Connectivity Results:")
    Write.Info("  Expected %s members: %d", expected_members.type, #expected_members.members)  
    Write.Info("  Successfully connected: %d", connectivity_results.connected_count)
    
    if connectivity_results.connected_count < #expected_members.members then
        Write.Warn("  Missing DanNet connectivity: [%s]", table.concat(connectivity_results.missing, ", "))
        Write.Warn("  ⚠️ Quest monitoring will be limited to connected members only")
    else
        Write.Info("  ✅ ALL %s members have DanNet connectivity", expected_members.type)
    end
    
    -- Step 4: Auto-start task collectors on all group members
    Write.Info("Starting task collectors on group members...")
    native_tasks.start_collectors_on_group_members(connectivity_results.connected)
    
    -- Step 5: Initialize actor system for collector communication
    Write.Info("Initializing actor communication system...")
    if not native_tasks.initialize_actor_system() then
        Write.Error("Failed to initialize actor system - native quest system cannot function")
        return false
    end
    
    -- Step 6: Initialize with validated data
    native_task_data.characters = {}
    native_task_data.quest_items = {}
    native_task_data.master_looter = mq.TLO.Me.DisplayName()
    native_task_data.expected_members = expected_members.names
    native_task_data.connected_members = connectivity_results.connected
    native_task_data.connectivity_details = connectivity_results.details
    
    -- Step 7: Collect quest data from ALL connected members
    Write.Info("Collecting quest data from all %d connected members...", connectivity_results.connected_count)
    local total_tasks_collected = 0
    local characters_with_tasks = 0
    
    -- Note: Master will collect its own tasks via REQUEST_TASKS response (TaskHUD style)
    -- This ensures consistent behavior across all characters
    
    -- Request tasks from remote collectors (excluding current character)
    local remote_characters = {}
    for _, character_name in ipairs(connectivity_results.connected) do
        if character_name ~= native_task_data.master_looter then
            table.insert(remote_characters, character_name)
        end
    end
    
    if #remote_characters > 0 then
        Write.Info("Requesting task data from %d remote collectors...", #remote_characters)
        
        -- Send request to collectors
        if native_tasks.request_tasks_from_collectors(remote_characters) then
            Write.Info("Waiting 2 seconds for collectors to scan tasks...")
            mq.delay(2000) -- Give collectors time to scan TaskWnd
            
            -- Wait for and collect responses
            local responses = native_tasks.collect_responses_from_collectors(remote_characters, 5000)
            
            -- Process responses
            for character_name, response in pairs(responses) do
                local character_tasks = response.tasks or {}
                Write.Info("  %s: %d tasks received from collector", character_name, #character_tasks)
                
                if #character_tasks > 0 then
                    native_task_data.characters[character_name] = {
                        tasks = character_tasks,
                        last_updated = response.timestamp or os.time()
                    }
                    total_tasks_collected = total_tasks_collected + #character_tasks
                    characters_with_tasks = characters_with_tasks + 1
                    Write.Info("  %s: Stored %d tasks", character_name, #character_tasks)
                end
            end
        else
            Write.Warn("Failed to send task requests to collectors")
        end
    else
        Write.Info("No remote characters to collect tasks from")
    end
    
    Write.Info("Task collection summary: %d tasks from %d/%d characters", 
        total_tasks_collected, characters_with_tasks, connectivity_results.connected_count)
    
    -- Step 8: Extract quest items from all collected task data
    native_tasks.extract_quest_items()
    
    -- Step 9: Final validation report
    local quest_item_count = 0
    if native_task_data.quest_items then
        for _ in pairs(native_task_data.quest_items) do
            quest_item_count = quest_item_count + 1
        end
    end
    
    Write.Info("=== Native Quest System Startup Complete ===")
    Write.Info("  Configuration: %s mode", expected_members.type)
    Write.Info("  Members expected: %d", #expected_members.members)
    Write.Info("  Members DanNet connected: %d", connectivity_results.connected_count)
    Write.Info("  Total quest tasks collected: %d", total_tasks_collected)
    Write.Info("  Characters with tasks: %d", characters_with_tasks)
    Write.Info("  Quest items being tracked: %d", quest_item_count)
    
    -- Ensure we always have consistent member tracking
    if connectivity_results.connected_count == 0 then
        Write.Error("❌ No DanNet connectivity to any group/raid members!")
        Write.Error("❌ Quest item distribution will not work properly!")
        return false
    end
    
    Write.Info("✅ Native quest system operational with %d/%d members connected", 
        connectivity_results.connected_count, #expected_members.members)
    
    return true
end

--- Get quest items from native task data (replaces TaskHUD communication)
native_tasks.get_quest_items = function()
    return native_task_data.quest_items
end

--- Check if item is needed for quests (native implementation)
native_tasks.is_quest_item = function(item_name)
    return native_task_data.quest_items[item_name] ~= nil
end

--- Get characters needing specific quest item (native implementation)
native_tasks.get_characters_needing_item = function(item_name)
    local quest_info = native_task_data.quest_items[item_name]
    if quest_info then
        return quest_info.needed_by, quest_info.task_name, quest_info.objective
    end
    return {}, nil, nil
end

--- Force refresh of group/raid member task data
native_tasks.refresh_all_characters = function()
    Write.Info("Refreshing quest data for group/raid members...")
    
    -- Refresh group/raid member list with DanNet connectivity
    local connected = native_tasks.get_connected_characters()
    
    -- Get fresh task data for master looter (current character)
    local my_tasks = native_tasks.get_current_character_tasks()
    native_task_data.characters[native_task_data.master_looter] = {
        tasks = my_tasks,
        last_updated = os.time()
    }
    
    -- Extract quest items from current task data
    native_tasks.extract_quest_items()
    
    Write.Info("Quest refresh complete for %d connected group/raid members", #connected)
    return true
end

--- Shutdown task collectors on group members when YALM2 exits
native_tasks.shutdown_collectors = function()
    Write.Info("Shutting down task collectors on group members...")
    
    if native_task_data.task_actor and native_task_data.connected_members then
        -- Send shutdown message to each collector's unique actor
        local shutdowns_sent = 0
        local current_character = mq.TLO.Me.DisplayName()
        
        for _, character_name in ipairs(native_task_data.connected_members) do
            if character_name ~= current_character then
                local collector_actor_name = 'yalm2_collector_' .. character_name:lower()
                
                local success, error_msg = pcall(function()
                    actors.send({
                        id = 'YALM2_SHUTDOWN_COLLECTORS',
                        timestamp = os.time()
                    }, collector_actor_name)
                end)
                
                if success then
                    Write.Debug("Sent shutdown to %s (%s)", character_name, collector_actor_name)
                    shutdowns_sent = shutdowns_sent + 1
                end
            end
        end
        
        if shutdowns_sent > 0 then
            Write.Info("Shutdown message sent to %d collectors", shutdowns_sent)
            mq.delay(1000) -- Give collectors time to receive shutdown message
        end
    end
    
    -- Alternative: Direct shutdown commands for reliability
    if native_task_data.connected_members then
        local current_character = mq.TLO.Me.DisplayName()
        local collectors_shutdown = 0
        
        for _, character_name in ipairs(native_task_data.connected_members) do
            if character_name ~= current_character then
                mq.cmdf('/dex %s /yalmcollector shutdown', character_name)
                collectors_shutdown = collectors_shutdown + 1
                mq.delay(100)
            end
        end
        
        if collectors_shutdown > 0 then
            Write.Info("Sent shutdown commands to %d collectors", collectors_shutdown)
        end
    end
end

return native_tasks