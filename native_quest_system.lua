--- Native Quest System for YALM2 (TaskHUD Architecture)
--- Single script that runs on ALL characters, with UI only on master
--- Exact replication of TaskHUD's proven communication pattern

local mq = require("mq")
local actors = require("actors")
local Write = require("yalm2.lib.Write")

-- Arguments passed when starting the script
local args = { ... }
local show_ui = true  -- Will be set to false with 'nohud' argument
local debug_mode = false
local running = true
local my_name = mq.TLO.Me.DisplayName()

-- Task data storage
local task_data = {
    tasks = {},      -- character_name -> task_array 
    my_tasks = {},   -- This character's tasks
}

local peer_list = {}
local triggers = {
    do_refresh = false,
    timestamp = mq.gettime(),
    need_task_update = false
}

-- Get tasks using TaskHUD's exact method
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
local actor = actors.register(function(message)
    if message.content.id == 'REQUEST_TASKS' then
        triggers.need_task_update = true
        peer_list = {}
        task_data.tasks = {}
        
    elseif message.content.id == 'INCOMING_TASKS' then
        if show_ui then  -- Only process if we're the UI instance
            task_data.tasks[message.sender.character] = message.content.tasks
            table.insert(peer_list, message.sender.character)
            table.sort(peer_list)
        end
        triggers.timestamp = mq.gettime()
        
    elseif message.content.id == 'TASKS_UPDATED' then
        if mq.gettime() > triggers.timestamp + 1500 then
            triggers.do_refresh = true
        end
        
    elseif message.content.id == 'END_SCRIPT' then
        running = false
    end
end)

local function request_task_update()
    actor:send({ id = 'REQUEST_TASKS' })
end

local function update_tasks()
    task_data.my_tasks = get_tasks()
    mq.delay(3000, function() return not mq.TLO.Window('TaskWnd').Open() end)
    actor:send({ id = 'INCOMING_TASKS', tasks = task_data.my_tasks })
end

-- Task update events (TaskHUD's exact events)
local function update_event()
    actors:send({ id = 'TASKS_UPDATED' })
end

local function create_events()
    mq.event('update_event', '#*#Your task #*# has been updated#*#', update_event)
    mq.event('new_task_event', '#*#You have been assigned the task#*#', update_event)  
    mq.event('shared_task_event', '#*#Your shared task#*# has ended.', update_event)
end

-- Command handler
local function cmd_native_quest(cmd)
    cmd = cmd or ""
    
    if cmd == 'refresh' then
        Write.Info("Refreshing quest data...")
        triggers.do_refresh = true
    elseif cmd == 'status' then
        Write.Info("Quest System Status:")
        Write.Info("  Characters tracked: " .. #peer_list)
        Write.Info("  My tasks: " .. #task_data.my_tasks)
        Write.Info("  Show UI: " .. tostring(show_ui))
    elseif cmd == 'stop' then
        Write.Info("Stopping native quest system...")
        running = false
    else
        Write.Info("Native Quest System Commands:")
        Write.Info("  /nativequest refresh - Refresh quest data")
        Write.Info("  /nativequest status - Show system status") 
        Write.Info("  /nativequest stop - Stop the system")
    end
end

-- Argument processing (TaskHUD's exact pattern)
local function check_args()
    if #args == 0 then
        -- Master instance - start collectors on other characters
        Write.Info("Starting native quest system as master (with UI)")
        mq.cmd('/dgga /lua stop yalm2\\native_quest_system')
        mq.delay(1000)
        mq.cmd('/dgga /lua run yalm2\\native_quest_system nohud')
        show_ui = true
        triggers.do_refresh = true
    else
        for _, arg in pairs(args) do
            if arg == 'nohud' then
                show_ui = false
                Write.Info("Starting native quest system as collector (no UI)")
            elseif arg == 'debug' then
                debug_mode = true
                Write.Info("Debug mode enabled")
            end
        end
    end
end

-- Main loop (TaskHUD's exact pattern)
local function main()
    mq.delay(500)
    while running do
        mq.doevents()
        mq.delay(200)
        
        if triggers.do_refresh then
            request_task_update()
            triggers.do_refresh = false
        end
        
        if triggers.need_task_update then
            triggers.need_task_update = false
            update_tasks()
        end
    end
    
    Write.Info("Native quest system shutting down...")
    actor:send({ id = 'END_SCRIPT' })
    mq.exit()
end

-- Initialize
local function init()
    create_events()
    mq.bind('/nativequest', cmd_native_quest)
    Write.Info("Native Quest System started for " .. my_name)
    Write.Info("Use /nativequest help for commands")
    mq.delay(500)
end

-- Export function to get quest items for YALM2 loot logic
local function get_quest_items_for_character(character_name)
    local quest_items = {}
    
    if task_data.tasks[character_name] then
        for _, task in ipairs(task_data.tasks[character_name]) do
            for _, objective in ipairs(task.objectives) do
                -- Look for item names in objectives
                local item_name = objective.objective:match("([%w%s]+)")
                if item_name and item_name ~= "" then
                    quest_items[item_name] = {
                        task_name = task.task_name,
                        objective = objective.objective,
                        status = objective.status
                    }
                end
            end
        end
    end
    
    return quest_items
end

-- Export function to check if system is active
local function is_active()
    return running and #peer_list > 0
end

-- Export function to get all tracked characters
local function get_tracked_characters()
    return peer_list
end

-- Start the system
check_args()
init()

-- Export functions for YALM2 integration
return {
    get_quest_items_for_character = get_quest_items_for_character,
    is_active = is_active,
    get_tracked_characters = get_tracked_characters,
    main = main  -- Call this from outside to start the main loop
}