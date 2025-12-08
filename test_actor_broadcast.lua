-- Simple test to verify actor broadcast messaging works
-- Run this on multiple characters to test communication

local mq = require('mq')
local actors = require('actors')

-- Test actor for broadcasting
local test_actor = nil
local received_messages = {}

-- Initialize test actor
local function init_test_actor()
    if test_actor then
        test_actor = nil
    end
    
    test_actor = actors.register('test_broadcast', function(message)
        local char_name = mq.TLO.Me.Name()
        local sender = message.sender and message.sender.character or "unknown"
        local msg_id = message.content and message.content.id or "NO_ID"
        
        print(string.format("[%s] Received message: %s from %s", char_name, msg_id, sender))
        
        if msg_id == 'TEST_PING' then
            print(string.format("[%s] Responding to TEST_PING", char_name))
            test_actor:send({
                id = 'TEST_PONG',
                responder = char_name,
                timestamp = os.time()
            })
        elseif msg_id == 'TEST_PONG' then
            table.insert(received_messages, {
                from = sender,
                at = os.time()
            })
        end
    end)
    
    print(string.format("[%s] Test actor initialized", mq.TLO.Me.Name()))
end

-- Send test broadcast
local function send_test_broadcast()
    if not test_actor then
        print("Test actor not initialized!")
        return
    end
    
    local char_name = mq.TLO.Me.Name()
    print(string.format("[%s] Broadcasting TEST_PING to all characters", char_name))
    
    test_actor:send({
        id = 'TEST_PING',
        sender_char = char_name,
        timestamp = os.time()
    })
end

-- Show received responses
local function show_responses()
    local char_name = mq.TLO.Me.Name()
    print(string.format("[%s] Received %d responses:", char_name, #received_messages))
    for i, resp in ipairs(received_messages) do
        print(string.format("  %d. %s (at %d)", i, resp.from, resp.at))
    end
end

-- Commands
local function handle_command(...)
    local args = {...}
    local cmd = args[1] and args[1]:lower() or ""
    
    if cmd == "init" then
        init_test_actor()
    elseif cmd == "ping" then
        send_test_broadcast()
    elseif cmd == "show" then
        show_responses()
    elseif cmd == "help" then
        print("Commands:")
        print("  /lua run yalm2/test_actor_broadcast init  - Initialize test actor")
        print("  /lua run yalm2/test_actor_broadcast ping  - Send test broadcast")
        print("  /lua run yalm2/test_actor_broadcast show  - Show responses")
        print("")
        print("Usage:")
        print("1. Run 'init' on all characters")
        print("2. Run 'ping' on one character") 
        print("3. Run 'show' on the ping character to see responses")
    else
        print("Test Actor Broadcast - use 'help' for commands")
        print("Current character: " .. mq.TLO.Me.Name())
        if test_actor then
            print("Actor initialized: YES")
        else
            print("Actor initialized: NO - run 'init' first")
        end
    end
end

-- Main execution
local args = {...}
if #args > 0 then
    handle_command(...)
else
    handle_command("help")
end