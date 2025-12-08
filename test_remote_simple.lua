--[[
Simple test of the remote task collection method
Usage: /lua run yalm2\test_remote_simple
]]

local mq = require("mq")

print("=== Simple Remote Task Collection Test ===")

-- Test if we can execute the remote collector on another character
local group_size = mq.TLO.Group.Members() or 0
if group_size == 0 then
    print("❌ Need group members for testing")
    return
end

local test_character = mq.TLO.Group.Member(1).Name()
if not test_character or test_character == "NULL" then
    print("❌ Cannot get group member name")
    return
end

print(string.format("Testing with character: %s", test_character))
print("")

-- Step 1: Send the remote collection command
print("Step 1: Sending remote task collection command...")
mq.cmdf('/dex %s /lua run yalm2\\remote_task_collector', test_character)
print("Command sent, waiting 3 seconds...")
mq.delay(3000)

-- Step 2: Try to retrieve the results
print("Step 2: Checking for results...")
local dannet = require("yalm2.lib.dannet")

-- Check timestamp first
local timestamp_query = string.format("_G.YALM2_NATIVE_TIMESTAMP_%s", test_character)
local timestamp_result = dannet.query(test_character, timestamp_query, 500)
print(string.format("Timestamp result: %s", tostring(timestamp_result)))

if timestamp_result and timestamp_result ~= "NULL" and timestamp_result ~= "" then
    -- Get task count
    local count_query = string.format("_G.YALM2_NATIVE_TASKS_%s and #_G.YALM2_NATIVE_TASKS_%s or 0", test_character, test_character)
    local count_result = dannet.query(test_character, count_query, 500)
    print(string.format("Task count: %s", tostring(count_result)))
    
    if count_result and count_result ~= "NULL" then
        local task_count = tonumber(count_result) or 0
        print(string.format("✅ SUCCESS: Found %d tasks from %s", task_count, test_character))
        
        -- Get first task name as example
        if task_count > 0 then
            local task_name_query = string.format("_G.YALM2_NATIVE_TASKS_%s[1].task_name", test_character)
            local task_name = dannet.query(test_character, task_name_query, 500)
            print(string.format("First task: %s", tostring(task_name)))
        end
        
        -- Clean up
        mq.cmdf('/dex %s /lua parse "_G.YALM2_NATIVE_TASKS_%s = nil; _G.YALM2_NATIVE_TIMESTAMP_%s = nil"', test_character, test_character, test_character)
    else
        print("❌ Could not retrieve task count")
    end
else
    print("❌ No timestamp found - remote script may have failed")
    print("Try manually on that character:")
    print(string.format("  /dex %s /lua run yalm2\\remote_task_collector", test_character))
    print("  Or check if the character has any tasks: /dquery " .. test_character .. " Task.Count")
end

print("")
print("=== Test Complete ===")