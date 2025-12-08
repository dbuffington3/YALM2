-- Actor Registration Diagnostic
-- Run this on each character to check actor system conflicts

local mq = require('mq')
local actors = require('actors')

local char_name = mq.TLO.Me.Name()
print(string.format("=== Actor Diagnostic for %s ===", char_name))

-- Test 1: Try to register with the same name all collectors use
local test_actor1 = actors.register('yalm2_task_collector', function(message)
    print(string.format("[%s] Received test message: %s", char_name, message.content and message.content.test or "no content"))
end)

if test_actor1 then
    print(string.format("✅ [%s] Successfully registered 'yalm2_task_collector'", char_name))
    
    -- Send a test message to see who receives it
    test_actor1:send({
        test = string.format("Test from %s at %d", char_name, os.time())
    })
    
    mq.delay(1000) -- Wait for message processing
    
else
    print(string.format("❌ [%s] FAILED to register 'yalm2_task_collector' - likely already taken!", char_name))
end

-- Test 2: Try with unique name per character
local unique_name = string.format('test_collector_%s', char_name:lower())
local test_actor2 = actors.register(unique_name, function(message)
    print(string.format("[%s] Received message on unique actor: %s", char_name, message.content and message.content.test or "no content"))
end)

if test_actor2 then
    print(string.format("✅ [%s] Successfully registered unique actor '%s'", char_name, unique_name))
else
    print(string.format("❌ [%s] FAILED to register unique actor '%s'", char_name, unique_name))
end

print(string.format("=== End Diagnostic for %s ===", char_name))