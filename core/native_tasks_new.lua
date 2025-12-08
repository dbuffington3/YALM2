--- Native Quest Detection System for YALM2
--- Uses TaskHUD's exact architecture - same script runs everywhere with UI flag
--- Eliminates separate master/collector scripts - one unified approach

local mq = require("mq")
local actors = require("actors")
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
local task_actor = nil
local system_active = false
local running = false

--- Get tasks using TaskHUD's exact method
local function get_tasks()
    local tasks = {}
    mq.TLO.Window('TaskWnd').DoOpen()
    while mq.TLO.Window('TaskWnd').Open() == false do
        -- Wait for window to open
    end
    
    local count1, count2 = 1, 1
    for i = 1, mq.TLO.Window('TaskWnd/TASK_TaskList').Items() do
        mq.TLO.Window('TaskWnd/TASK_TaskList').Select(i)
        while mq.TLO.Window('TaskWnd/TASK_TaskList').GetCurSel() ~= i do
            -- Wait for selection
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
    mq.TLO.Window('TaskWnd').DoClose()
    return tasks
end

-- Message handler - TaskHUD's exact pattern
local function create_message_handler()
    return actors.register(function(message)
        if not system_active then return end
        
        Write.Debug("[NativeQuest] Received message: " .. (message.content.id or "unknown"))
        
        if message.content.id == 'REQUEST_TASKS' then
            Write.Debug("[NativeQuest] Handling REQUEST_TASKS message")
            triggers.need_task_update = true
            peer_list = {}
            task_data.tasks = {}
            
        elseif message.content.id == 'INCOMING_TASKS' then
            Write.Debug("[NativeQuest] Handling INCOMING_TASKS from " .. message.sender.character)
            task_data.tasks[message.sender.character] = message.content.tasks
            table.insert(peer_list, message.sender.character)
            table.sort(peer_list)
            triggers.timestamp = mq.gettime()
            
        elseif message.content.id == 'TASKS_UPDATED' then
            Write.Debug("[NativeQuest] Handling TASKS_UPDATED message")
            if mq.gettime() > triggers.timestamp + 1500 then
                triggers.do_refresh = true
            end
            
        elseif message.content.id == 'END_SCRIPT' then
            Write.Debug("[NativeQuest] Handling END_SCRIPT message")
            running = false
        end
    end)
end

local function request_task_update()
    Write.Debug("[NativeQuest] Requesting task update from all characters")
    if task_actor then
        task_actor:send({ id = 'REQUEST_TASKS' })
    end
end

local function update_tasks()
    Write.Debug("[NativeQuest] Updating tasks for " .. my_name)
    task_data.my_tasks = get_tasks()
    mq.delay(3000, function() return not mq.TLO.Window('TaskWnd').Open() end)
    Write.Debug("[NativeQuest] Sending INCOMING_TASKS with " .. #task_data.my_tasks .. " tasks")
    if task_actor then
        task_actor:send({ id = 'INCOMING_TASKS', tasks = task_data.my_tasks })
    end
end

-- Task update events (TaskHUD's exact events)
local function update_event()
    Write.Debug("[NativeQuest] Task update event triggered")  
    if task_actor then
        task_actor:send({ id = 'TASKS_UPDATED' })
    end
end

local function create_events()
    mq.event('update_event', '#*#Your task #*# has been updated#*#', update_event)
    mq.event('new_task_event', '#*#You have been assigned the task#*#', update_event)
    mq.event('shared_task_event', '#*#Your shared task#*# has ended.', update_event)
end

-- Background processing loop (TaskHUD style)
local function process_triggers()
    if not system_active or not running then return end
    
    mq.doevents()
    
    if triggers.do_refresh then
        request_task_update()
        triggers.do_refresh = false
    end
    
    if triggers.need_task_update then
        triggers.need_task_update = false
        update_tasks()
    end
end

--- Initialize the native quest system
function native_tasks.initialize()
    Write.Info("[NativeQuest] Starting native quest system for " .. my_name)
    
    -- Start the system on all group members (TaskHUD style)
    -- Master runs with UI, others run as collectors
    mq.cmd('/dgga /lua stop yalm2\\core\\native_tasks')
    mq.delay(1000)
    mq.cmd('/dgga /lua run yalm2\\core\\native_tasks nohud')
    
    task_actor = create_message_handler()
    create_events()
    system_active = true
    running = true
    triggers.do_refresh = true
    
    Write.Info("[NativeQuest] Native quest system initialized - requesting initial data...")
    return true
end

--- Stop the native quest system
function native_tasks.shutdown()
    Write.Info("[NativeQuest] Shutting down native quest system...")
    system_active = false
    running = false
    
    if task_actor then
        task_actor:send({ id = 'END_SCRIPT' })
    end
    
    -- Clear all data
    task_data.tasks = {}
    task_data.my_tasks = {}
    peer_list = {}
end

--- Refresh all character quest data (TaskHUD style)
function native_tasks.refresh_all_characters()
    if not system_active then
        Write.Warn("[NativeQuest] Native quest system not active")
        return
    end
    
    Write.Info("[NativeQuest] Refreshing quest data from all characters...")
    triggers.do_refresh = true
end

--- Get quest items needed by a specific character
function native_tasks.get_quest_items_for_character(character_name)
    local quest_items = {}
    
    if not task_data.tasks[character_name] then
        return quest_items
    end
    
    for _, task in ipairs(task_data.tasks[character_name]) do
        for _, objective in ipairs(task.objectives) do
            -- Parse item names from objectives
            -- This is a simple parser - could be enhanced based on actual objective text patterns
            local item_name = objective.objective:match("([%w%s]+)")
            if item_name and item_name:len() > 3 then  -- Basic filtering
                quest_items[item_name] = {
                    task_name = task.task_name,
                    objective = objective.objective,
                    status = objective.status,
                    character = character_name
                }
            end
        end
    end
    
    return quest_items
end

--- Get all quest items across all tracked characters  
function native_tasks.get_all_quest_items()
    local all_quest_items = {}
    
    for character_name, _ in pairs(task_data.tasks) do
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
    return all_items[item_name] ~= nil
end

--- Get list of tracked characters
function native_tasks.get_tracked_characters()
    return peer_list
end

--- Check if system is active and has data
function native_tasks.is_active()
    return system_active and #peer_list > 0
end

--- Get status for debugging
function native_tasks.get_status()
    return {
        active = system_active,
        running = running,
        characters_tracked = #peer_list,
        my_tasks_count = #task_data.my_tasks,
        total_characters = #peer_list,
        peer_list = peer_list
    }
end

--- Process background tasks (call this from main loop)
function native_tasks.process()
    process_triggers()
end

--- Force immediate task collection from current character  
function native_tasks.collect_my_tasks()
    if system_active then
        triggers.need_task_update = true
    end
end

--- Legacy compatibility functions
function native_tasks.shutdown_collectors()
    native_tasks.shutdown()
end

return native_tasks