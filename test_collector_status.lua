-- Simple test: Check if task collectors are running
-- Run this to see if collectors started and are responding

local mq = require('mq')

print("=== Collector Status Check ===")
print("Current character: " .. mq.TLO.Me.Name())

-- Check running Lua scripts  
local scripts = {}
local script_count = mq.TLO.Lua.Script.Count()
if script_count then
    for i = 1, script_count do
        local script_name = mq.TLO.Lua.Script.Name(i)()
        if script_name then
            table.insert(scripts, script_name)
        end
    end
else
    print("Cannot access Lua.Script.Count - using alternative method")
    -- Try alternative: check if specific collector is running
    if mq.TLO.Lua.Script("task_collector").Status() == "RUNNING" then
        table.insert(scripts, "task_collector")
    end
end

print("Running Lua scripts: " .. #scripts)
for _, script in ipairs(scripts) do
    print("  - " .. script)
end

-- Check if task_collector is running
local collector_running = false
for _, script in ipairs(scripts) do
    if string.find(script, "task_collector") then
        collector_running = true
        break
    end
end

if collector_running then
    print("✅ Task collector is running on this character")
else
    print("❌ Task collector is NOT running on this character")
end

-- Check DanNet peers
local peers = {}
local peer_count = mq.TLO.DanNet.PeerCount() or 0
print("DanNet peers: " .. peer_count)
for i = 1, peer_count do
    local peer = mq.TLO.DanNet.Peers(i)()
    if peer then
        table.insert(peers, peer)
        print("  - " .. peer)
    end
end

print("=== End Status Check ===")