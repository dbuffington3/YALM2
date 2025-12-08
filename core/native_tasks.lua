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

--- Get connected DanNet characters
native_tasks.get_connected_characters = function()
    Write.Info("Getting connected DanNet characters...")
    
    -- Query DanNet for connected peers
    local connected = {}
    
    -- Method 1: Try to get DanNet observer list (if available)
    -- This would need to be implemented based on DanNet's API
    
    -- Method 2: Try group members first
    if mq.TLO.Group.Members() > 0 then
        for i = 0, mq.TLO.Group.Members() do
            local member_name = nil
            if i == 0 then
                member_name = mq.TLO.Me.DisplayName()
            else
                member_name = mq.TLO.Group.Member(i).DisplayName()
            end
            
            if member_name and member_name ~= "" then
                -- Test DanNet connectivity
                local response = dannet.query(member_name, "Me.Name", 1000)
                if response and response ~= "NULL" then
                    table.insert(connected, member_name)
                    Write.Debug("Found connected character: %s", member_name)
                end
            end
        end
    end
    
    -- Method 3: Try raid members if in raid
    if mq.TLO.Raid.Members() > 0 then
        for i = 0, mq.TLO.Raid.Members() do
            local member_name = nil
            if i == 0 then
                member_name = mq.TLO.Me.DisplayName()
            else
                member_name = mq.TLO.Raid.Member(i).DisplayName()
            end
            
            if member_name and member_name ~= "" then
                -- Check if not already in connected list
                local already_added = false
                for _, existing in ipairs(connected) do
                    if existing == member_name then
                        already_added = true
                        break
                    end
                end
                
                if not already_added then
                    -- Test DanNet connectivity
                    local response = dannet.query(member_name, "Me.Name", 1000)
                    if response and response ~= "NULL" then
                        table.insert(connected, member_name)
                        Write.Debug("Found connected raid character: %s", member_name)
                    end
                end
            end
        end
    end
    
    Write.Info("Found %d connected DanNet characters: [%s]", #connected, table.concat(connected, ", "))
    native_task_data.connected_characters = connected
    return connected
end

--- Query tasks from a specific character via DanNet
native_tasks.get_character_tasks_via_dannet = function(character_name)
    Write.Debug("Querying tasks from %s via DanNet...", character_name)
    
    -- Use DanNet to execute the task detection on the remote character
    -- This requires the native quest detection function to be available on all clients
    
    -- For now, return empty - this would need TaskHUD-style logic deployed to each character
    -- Or we could query individual task elements directly via DanNet TLO queries
    
    Write.Debug("DanNet task querying not yet implemented for %s", character_name)
    return {}
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

--- Initialize native quest system
native_tasks.initialize = function()
    Write.Info("Initializing native quest detection system...")
    
    -- Set master looter
    native_task_data.master_looter = mq.TLO.Me.DisplayName()
    
    -- Get connected characters
    local connected = native_tasks.get_connected_characters()
    
    if #connected == 0 then
        Write.Warn("No connected DanNet characters found - quest detection will be limited")
        return false
    end
    
    -- Get master looter's tasks (authoritative source)
    local my_tasks = native_tasks.get_current_character_tasks()
    native_task_data.characters[native_task_data.master_looter] = {
        tasks = my_tasks,
        last_updated = os.time()
    }
    
    -- Extract quest items from task data
    native_tasks.extract_quest_items()
    
    Write.Info("Native quest system initialized with %d characters, %d tasks for master looter", 
        #connected, #my_tasks)
    
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

--- Force refresh of all character task data
native_tasks.refresh_all_characters = function()
    Write.Info("Forcing refresh of all character task data...")
    
    -- Refresh connected character list
    local connected = native_tasks.get_connected_characters()
    
    -- Get fresh task data for master looter
    local my_tasks = native_tasks.get_current_character_tasks()
    native_task_data.characters[native_task_data.master_looter] = {
        tasks = my_tasks,
        last_updated = os.time()
    }
    
    -- TODO: Query other characters via DanNet
    -- This would require deploying task query logic to each client
    
    Write.Info("Native task refresh complete")
    return true
end

return native_tasks