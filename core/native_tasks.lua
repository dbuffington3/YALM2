--- Native Quest Detection System for YALM2
--- Integrates TaskHUD's proven quest detection logic directly into YALM2
--- Eliminates external script dependencies and communication reliability issues

local mq = require("mq")
local dannet = require("yalm.lib.dannet")
local debug_logger = require("yalm2.lib.debug_logger")
require("yalm2.lib.Write")

local native_tasks = {}

-- Internal task storage (replaces external TaskHUD communication)
local native_task_data = {
    characters = {},  -- character_name -> { tasks = {...}, last_updated = timestamp }
    quest_items = {}, -- item_name -> { needed_by = {character_names...}, task_name = "..." }
    master_looter = nil,
    connected_characters = {},
}

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
    native_task_data.connected_members = connectivity.connected
    return connectivity.connected
end

--- Query tasks from a specific character via DanNet
native_tasks.get_character_tasks_via_dannet = function(character_name)
    Write.Debug("Querying basic task data from %s via DanNet...", character_name)
    
    local tasks = {}
    
    -- Query basic task count first
    local task_count = dannet.query(character_name, "Task.Count", 2000)
    if not task_count or task_count == "NULL" or tonumber(task_count) == 0 then
        Write.Debug("  %s: No tasks reported", character_name)
        return tasks
    end
    
    local num_tasks = tonumber(task_count) or 0
    Write.Debug("  %s: Reports %d active tasks", character_name, num_tasks)
    
    -- Query each task's basic info
    for i = 1, math.min(num_tasks, 10) do -- Limit to first 10 tasks to avoid spam
        local task_name = dannet.query(character_name, string.format("Task[%d].Title", i), 1000)
        if task_name and task_name ~= "NULL" and task_name ~= "" then
            local task_info = {
                task_name = task_name,
                objectives = {} -- TODO: Query objectives in Phase 2
            }
            table.insert(tasks, task_info)
            Write.Debug("    Task %d: %s", i, task_name)
        end
    end
    
    Write.Debug("  %s: Collected %d task names via DanNet", character_name, #tasks)
    return tasks
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
native_tasks.validate_dannet_connectivity = function(expected_members)
    local results = {
        connected = {},
        missing = {},
        connected_count = 0,
        details = {}
    }
    
    Write.Info("Testing DanNet connectivity for %d expected %s members...", 
        #expected_members.members, expected_members.type)
    
    for _, member in ipairs(expected_members.members) do
        Write.Debug("Testing DanNet connectivity to %s...", member.name)
        
        local response = dannet.query(member.name, "Me.Name", 3000) -- Longer timeout for reliability
        if response and response ~= "NULL" and response ~= "" then
            table.insert(results.connected, member.name)
            results.connected_count = results.connected_count + 1
            
            -- Get additional details for validation
            local zone = dannet.query(member.name, "Zone.ShortName", 1000) or "unknown"
            local class = dannet.query(member.name, "Me.Class.ShortName", 1000) or "unknown"
            local level = dannet.query(member.name, "Me.Level", 1000) or "unknown"
            
            results.details[member.name] = {
                zone = zone,
                class = class,
                level = level,
                connected = true
            }
            
            Write.Info("✅ %s - %s %s in %s (DanNet OK)", member.name, level, class, zone)
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

--- Initialize solo mode (fallback when no group/raid)
native_tasks.initialize_solo_mode = function()
    Write.Info("Initializing native quest system in solo mode...")
    
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
    
    -- Step 2: Test DanNet connectivity for ALL expected members with retries
    Write.Info("Validating DanNet connectivity (this may take a moment)...")
    local connectivity_results = native_tasks.validate_dannet_connectivity(expected_members)
    
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
    
    -- Step 4: Initialize with validated data
    native_task_data.characters = {}
    native_task_data.quest_items = {}
    native_task_data.master_looter = mq.TLO.Me.DisplayName()
    native_task_data.expected_members = expected_members.names
    native_task_data.connected_members = connectivity_results.connected
    native_task_data.connectivity_details = connectivity_results.details
    
    -- Step 5: Collect quest data from ALL connected members
    Write.Info("Collecting quest data from all %d connected members...", connectivity_results.connected_count)
    local total_tasks_collected = 0
    local characters_with_tasks = 0
    
    for _, character_name in ipairs(connectivity_results.connected) do
        Write.Info("Collecting tasks from %s...", character_name)
        
        local character_tasks = {}
        if character_name == native_task_data.master_looter then
            -- Current character - use direct access
            character_tasks = native_tasks.get_current_character_tasks()
            Write.Info("  %s (current character): %d tasks collected directly", character_name, #character_tasks)
        else
            -- Other characters - use DanNet queries for basic task info
            character_tasks = native_tasks.get_character_tasks_via_dannet(character_name)
            Write.Info("  %s: %d task names collected via DanNet", character_name, #character_tasks)
        end
        
        if #character_tasks > 0 then
            native_task_data.characters[character_name] = {
                tasks = character_tasks,
                last_updated = os.time()
            }
            total_tasks_collected = total_tasks_collected + #character_tasks
            characters_with_tasks = characters_with_tasks + 1
            Write.Info("  %s: Stored %d tasks", character_name, #character_tasks)
        end
    end
    
    Write.Info("Task collection summary: %d tasks from %d/%d characters", 
        total_tasks_collected, characters_with_tasks, connectivity_results.connected_count)
    
    -- Step 6: Extract quest items from all collected task data
    native_tasks.extract_quest_items()
    
    -- Step 7: Final validation report
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

return native_tasks