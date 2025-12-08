--- Native Quest Detection System for YALM2
--- Integrates TaskHUD's proven quest detection logic directly into YALM2
--- Eliminates external script dependencies and communication reliability issues

local mq = require("mq")
local dannet = require("yalm.lib.dannet")
local debug_logger = require("yalm2.lib.debug_logger")

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