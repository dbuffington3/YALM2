--[[
DanNet Task Query Diagnostic - Test task queries for all group members
Usage: /lua run yalm2\test_dannet_tasks
]]

local mq = require("mq")
local dannet = require("yalm2.lib.dannet")

print("=== DanNet Task Query Diagnostic ===")

-- Get group composition
local group_size = mq.TLO.Group.Members() or 0
local characters = {}

-- Add current character
table.insert(characters, mq.TLO.Me.Name())

-- Add group members
if group_size > 0 then
    for i = 1, group_size do
        local member_name = mq.TLO.Group.Member(i).Name()
        if member_name and member_name ~= "NULL" and member_name ~= mq.TLO.Me.Name() then
            table.insert(characters, member_name)
        end
    end
end

print(string.format("Testing task queries for %d characters:", #characters))
print("")

for _, char_name in ipairs(characters) do
    print(string.format("=== Testing %s ===", char_name))
    
    if char_name == mq.TLO.Me.Name() then
        -- Test local character using TLO
        local local_count = mq.TLO.Task.Count() or 0
        print(string.format("  Local TLO Task.Count: %d", local_count))
        
        if local_count > 0 then
            for i = 1, math.min(local_count, 3) do
                local task_title = mq.TLO.Task(i).Title() or "NULL"
                print(string.format("  Local TLO Task[%d].Title: '%s'", i, task_title))
            end
        end
        print("")
    else
        -- Test remote character using DanNet
        print("  Testing DanNet connectivity...")
        local ping_result = dannet.query(char_name, "Me.Name", 250)
        print(string.format("  DanNet ping result: '%s'", tostring(ping_result)))
        
        if ping_result and ping_result ~= "NULL" then
            print("  ✅ DanNet connection confirmed")
            
            -- Test task count query
            local remote_count = dannet.query(char_name, "Task.Count", 500)
            print(string.format("  DanNet Task.Count: '%s'", tostring(remote_count)))
            
            if remote_count and remote_count ~= "NULL" then
                local num_tasks = tonumber(remote_count) or 0
                print(string.format("  Parsed task count: %d", num_tasks))
                
                if num_tasks > 0 then
                    -- Test individual task queries
                    for i = 1, math.min(num_tasks, 3) do
                        local task_title = dannet.query(char_name, string.format("Task[%d].Title", i), 300)
                        print(string.format("  DanNet Task[%d].Title: '%s'", i, tostring(task_title)))
                    end
                end
            else
                print("  ❌ Task.Count returned NULL")
            end
        else
            print("  ❌ DanNet connection failed")
        end
        print("")
    end
end

print("=== Manual Test Commands ===")
print("Try these commands manually in game:")
for _, char_name in ipairs(characters) do
    if char_name ~= mq.TLO.Me.Name() then
        print(string.format("/dquery %s Task.Count", char_name))
        print(string.format("/dquery %s Task[1].Title", char_name))
    end
end
print("")
print("If manual /dquery commands return NULL, the issue is:")
print("1. Characters don't have active tasks, or")
print("2. DanNet TLO access issue on remote characters")