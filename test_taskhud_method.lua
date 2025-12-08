--[[
Test Native Quest System with TaskHUD Method
Usage: /lua run yalm2\test_taskhud_method
]]

local mq = require("mq")

print("=== Testing TaskHUD Method for Remote Task Collection ===")

-- Test with one remote character first
local group_size = mq.TLO.Group.Members() or 0
if group_size == 0 then
    print("❌ No group members found. Need at least one other character to test remote collection.")
    return
end

local remote_character = mq.TLO.Group.Member(1).Name()
if not remote_character or remote_character == "NULL" then
    print("❌ Could not get first group member name")
    return
end

print(string.format("Testing remote task collection with: %s", remote_character))
print("")

-- Load the native tasks module
local native_tasks = require("yalm2.core.native_tasks")

-- Test the new TaskHUD-style method
print("=== Step 1: Request Task Collection ===")
local success = native_tasks.request_character_tasks_via_dannet(remote_character)
print(string.format("Request sent to %s: %s", remote_character, success and "SUCCESS" or "FAILED"))

if not success then
    print("❌ Failed to send task collection request")
    return
end

print("")
print("=== Step 2: Retrieve Task Results ===")
print("Waiting for task collection to complete...")

local tasks = native_tasks.get_character_task_results(remote_character, 5000)
print(string.format("Tasks retrieved from %s: %d", remote_character, #tasks))

if #tasks > 0 then
    print("")
    print("=== Task Details ===")
    for i, task in ipairs(tasks) do
        print(string.format("Task %d: %s", i, task.task_name or "NO NAME"))
        print(string.format("  Objectives: %d", #task.objectives))
    end
    print("")
    print("✅ SUCCESS: TaskHUD method working!")
else
    print("⚠️ No tasks retrieved. This could mean:")
    print("  1. Character has no active tasks")
    print("  2. Task window couldn't be opened")
    print("  3. Communication issue")
    print("")
    print("Try manually on that character:")
    print("  /lua parse \"print('Task count:', mq.TLO.Task.Count())\"")
    print("  /dquery " .. remote_character .. " Task.Count")
end

print("")
print("=== Test Complete ===")