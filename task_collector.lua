--[[
YALM2 Task Collector - Using TaskHUD's Exact Trigger Pattern
Lightweight companion script for remote characters
Runs continuously to provide task data to YALM2 master

Usage: /lua run yalm2\task_collector
]]

local mq = require('mq')
local actors = require('actors')

local collector = {
    running = true,
    my_name = mq.TLO.Me.DisplayName(),
    my_tasks = {},
    last_update = 0,
    update_interval = 5000, -- Check for task updates every 5 seconds
    actor = nil
}

-- Trigger system (exactly like TaskHUD)
local triggers = {
    need_task_update = false,
    timestamp = mq.gettime()
}

-- TaskHUD's proven task collection method
local function get_tasks()
    local tasks = {}
    
    -- Don't spam task window opens
    if (os.clock() * 1000 - collector.last_update) < collector.update_interval then
        return collector.my_tasks
    end
    
    mq.TLO.Window('TaskWnd').DoOpen()
    
    -- Wait for window to open (TaskHUD's exact method - no delay)
    while mq.TLO.Window('TaskWnd').Open() == false do
    end
    
    local count1 = 1
    for i = 1, mq.TLO.Window('TaskWnd/TASK_TaskList').Items() do
        mq.TLO.Window('TaskWnd/TASK_TaskList').Select(i)
        while mq.TLO.Window('TaskWnd/TASK_TaskList').GetCurSel() ~= i do
        end
        
        -- Check that the task name is not nil (skip separator lines) - TaskHUD's exact check
        if mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)() then
            tasks[count1] = {
                task_name = mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)(),
                objectives = {}
            }
            
            local count2 = 1
            -- Loop through objectives of current task
            for j = 1, mq.TLO.Window('TaskWnd/TASK_TaskElementList').Items() do
                -- Check that the name of the objective is not nil (skip separator lines) 
                if mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)() then
                    local tmp_objective = {
                        objective = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 1)(),
                        status = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)()
                    }
                    table.insert(tasks[count1]['objectives'], count2, tmp_objective)
                    count2 = count2 + 1
                end
            end
            count1 = count1 + 1
        end
    end
    
    mq.TLO.Window('TaskWnd').DoClose()
    
    collector.my_tasks = tasks
    collector.last_update = os.clock() * 1000
    return tasks
end

-- TaskHUD's exact update_tasks function
local function update_tasks()
    print(string.format("[YALM2 Collector] %s starting task scan...", collector.my_name))
    collector.my_tasks = {}
    
    -- Force update by resetting last_update timestamp
    collector.last_update = 0 -- Force fresh scan
    
    collector.my_tasks = get_tasks()
    print(string.format("[YALM2 Collector] %s completed task scan, found %d tasks", collector.my_name, #collector.my_tasks))
    mq.delay(3000, function() return not mq.TLO.Window('TaskWnd').Open() end)
    
    -- Send response to master using global broadcast (master will filter)
    collector.actor:send({ 
        id = 'INCOMING_TASKS', 
        tasks = collector.my_tasks,
        character = collector.my_name,
        timestamp = os.time()
    })
    print(string.format("[YALM2 Collector] Sent %d tasks to YALM2 master", #collector.my_tasks))
end

-- Actor message handler (TaskHUD's pattern)
local function handle_actor_message(message)
    local success, error_msg = pcall(function()
        -- Debug: Log all messages received
        print(string.format("[YALM2 Collector] Received message: %s from %s", 
            message.content and message.content.id or "NO_ID",
            message.sender and message.sender.character or "UNKNOWN"))
        
        return true
    end)
    
    if not success then
        print(string.format("[YALM2 Collector] ERROR in message handler: %s", error_msg))
        return
    end
    
    if not message.content or not message.content.id then
        print("[YALM2 Collector] Message has no content or ID")
        return
    end
    
    if message.content.id == 'REQUEST_TASKS' then
        -- TaskHUD's exact pattern: set trigger, don't respond immediately
        print(string.format("[YALM2 Collector] ✅ REQUEST_TASKS received from %s, setting trigger", message.sender and message.sender.character or "unknown"))
        triggers.need_task_update = true
        print(string.format("[YALM2 Collector] %s trigger set to: %s", collector.my_name, tostring(triggers.need_task_update)))
        
    elseif message.content.id == 'YALM2_SHUTDOWN_COLLECTORS' then
        -- Master is shutting down, we should too
        print("[YALM2 Collector] Shutdown requested by master")
        collector.running = false
        
    elseif message.content.id == 'YALM2_PING_COLLECTORS' then
        -- Health check from master
        collector.actor:send({
            id = 'YALM2_PONG',
            character = collector.my_name,
            status = 'active'
        })
    end
end

-- Task update events (borrowed from TaskHUD)
local function create_events()
    mq.event('task_update', '#*#Your task #*# has been updated#*#', function()
        print("[YALM2 Collector] Task updated, refreshing data...")
        triggers.need_task_update = true -- Use trigger like TaskHUD
    end)
    
    mq.event('new_task', '#*#You have been assigned the task#*#', function()
        print("[YALM2 Collector] New task assigned, refreshing data...")
        triggers.need_task_update = true -- Use trigger like TaskHUD
    end)
    
    mq.event('shared_task_end', '#*#Your shared task#*# has ended.', function()
        print("[YALM2 Collector] Shared task ended, refreshing data...")
        triggers.need_task_update = true -- Use trigger like TaskHUD
    end)
end

-- Initialize the collector
local function initialize()
    -- Removed startup message to reduce log spam
    
    -- Register anonymous actor (TaskHUD style - no name)
    collector.actor = actors.register(handle_actor_message)
    if not collector.actor then
        print("[YALM2 Collector] ERROR: Could not register anonymous actor")
        return false
    else
        print(string.format("[YALM2 Collector] %s registered anonymous actor (TaskHUD style)", collector.my_name))
    end
    
    -- Set up task update events
    create_events()
    
    -- Announce availability to any YALM2 masters (simple message)
    collector.actor:send({
        id = 'COLLECTOR_READY'
    })
    
    -- Test message to master
    collector.actor:send({
        id = 'COLLECTOR_TEST',
        character = collector.my_name,
        message = 'Testing communication to master'
    })
    print(string.format("[YALM2 Collector] %s sent test message to master", collector.my_name))
    
    print("[YALM2 Collector] Task collector initialized and ready")
    return true
end

-- TaskHUD's exact main loop pattern
local function main()
    print("[YALM2 Collector] Attempting to initialize...")
    
    local success, error_msg = pcall(function()
        return initialize()
    end)
    
    if not success then
        print(string.format("[YALM2 Collector] ERROR during initialization: %s", error_msg))
        return
    end
    
    if not error_msg then
        print("[YALM2 Collector] Initialization failed, exiting")
        return
    end
    
    print("[YALM2 Collector] Initialization successful, starting main loop...")
    mq.delay(500) -- TaskHUD's initial delay
    while collector.running do
        mq.doevents()
        mq.delay(200) -- TaskHUD's exact delay
        
        -- TaskHUD's exact trigger processing
        if triggers.need_task_update then
            print(string.format("[YALM2 Collector] %s processing task update trigger", collector.my_name))
            triggers.need_task_update = false
            update_tasks()
            triggers.timestamp = mq.gettime() -- Update timestamp like TaskHUD
        end
    end
    
    print(string.format("[YALM2 Collector] Task collector for %s shutting down", collector.my_name))
end

-- Handle script shutdown
local function shutdown()
    collector.running = false
    if collector.actor then
        collector.actor:send({
            id = 'YALM2_COLLECTOR_SHUTDOWN',
            character = collector.my_name,
            timestamp = os.time()
        })
    end
end

-- Bind control commands
print("[YALM2 Collector] Registering /yalmcollector command...")
mq.bind('/yalmcollector', function(...)
    local args = {...}
    if args[1] == 'status' then
        print(string.format("[YALM2 Collector] Status for %s:", collector.my_name))
        print(string.format("  Running: %s", tostring(collector.running)))
        print(string.format("  Last update: %d ms ago", (os.clock() * 1000) - collector.last_update))
        print(string.format("  Cached tasks: %d", #collector.my_tasks))
        print(string.format("  Actor registered: %s", tostring(collector.actor ~= nil)))
        print(string.format("  Needs update: %s", tostring(triggers.need_task_update)))
    elseif args[1] == 'refresh' then
        print("[YALM2 Collector] Forcing task refresh...")
        triggers.need_task_update = true -- Use trigger pattern
    elseif args[1] == 'respawn' then
        print("[YALM2 Collector] Respawning actor with unique name...")
        -- Destroy old actor
        if collector.actor then
            collector.actor = nil
        end
        -- Create new actor with unique name to avoid conflicts
        local unique_name = 'yalm2_collector_' .. collector.my_name:lower()
        collector.actor = actors.register(unique_name, handle_actor_message)
        print(string.format("[YALM2 Collector] Attempting to register: %s", unique_name))
        if collector.actor then
            print("[YALM2 Collector] ✅ Actor respawned successfully")
            -- Send test message
            collector.actor:send({
                id = 'COLLECTOR_READY'
            })
            print("[YALM2 Collector] Sent COLLECTOR_READY after respawn")
        else
            print("[YALM2 Collector] ❌ Actor respawn failed")
        end
    elseif args[1] == 'shutdown' then
        print("[YALM2 Collector] Manual shutdown requested")
        shutdown()
    else
        print("[YALM2 Collector] Commands: status, refresh, respawn, shutdown")
    end
end)

print(string.format("[YALM2 Collector] Task collector loaded for %s", collector.my_name))
print("Use /yalmcollector status|refresh|shutdown for control")

-- Start the main loop (TaskHUD's pattern)
main()
