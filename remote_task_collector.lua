--[[
Remote Task Collection Script for YALM2 Native Quest System
This script is executed on remote characters via DanNet /dex command
Usage: Character runs this to collect their tasks and store in global variables
]]

local mq = require('mq')
local character_name = mq.TLO.Me.DisplayName()

-- Use TaskHUD's proven method to collect tasks
local tasks = {}
mq.TLO.Window('TaskWnd').DoOpen()

-- Wait for window to open
local wait_count = 0
while not mq.TLO.Window('TaskWnd').Open() and wait_count < 50 do
    mq.delay(100)
    wait_count = wait_count + 1
end

if mq.TLO.Window('TaskWnd').Open() then
    local count1 = 1
    for i = 1, mq.TLO.Window('TaskWnd/TASK_TaskList').Items() do
        mq.TLO.Window('TaskWnd/TASK_TaskList').Select(i)
        
        -- Wait for selection
        local select_wait = 0
        while mq.TLO.Window('TaskWnd/TASK_TaskList').GetCurSel() ~= i and select_wait < 10 do
            mq.delay(50)
            select_wait = select_wait + 1
        end
        
        -- Check that the task name is not nil (skip separator lines)
        local task_name = mq.TLO.Window('TaskWnd/TASK_TaskList').List(i, 3)()
        if task_name and task_name ~= "" then
            tasks[count1] = {
                task_name = task_name,
                objectives = {}
            }
            
            local count2 = 1
            -- Loop through objectives of current task
            for j = 1, mq.TLO.Window('TaskWnd/TASK_TaskElementList').Items() do
                local obj_status = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 2)()
                if obj_status and obj_status ~= "" then
                    local objective = {
                        objective = mq.TLO.Window('TaskWnd/TASK_TaskElementList').List(j, 1)() or "",
                        status = obj_status
                    }
                    table.insert(tasks[count1].objectives, count2, objective)
                    count2 = count2 + 1
                end
            end
            count1 = count1 + 1
        end
    end
    
    mq.TLO.Window('TaskWnd').DoClose()
end

-- Store results in global variables for YALM2 to retrieve
_G['YALM2_NATIVE_TASKS_' .. character_name] = tasks
_G['YALM2_NATIVE_TIMESTAMP_' .. character_name] = os.time()

print(string.format("[YALM2 Remote] Collected %d tasks for %s", #tasks, character_name))