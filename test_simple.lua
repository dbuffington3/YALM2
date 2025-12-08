-- Simple collector test - just check if we can communicate
local mq = require('mq')

print("=== Simple Collector Test ===")
print("Character: " .. mq.TLO.Me.Name())
print("Zone: " .. (mq.TLO.Zone.ShortName() or "Unknown"))

-- Try to check if task collector is running by looking for its bind
-- The task_collector should register /yalmcollector command
local has_collector = false
if mq.TLO.Bind("yalmcollector") then
    print("✅ Task collector bind found - collector likely running")
    has_collector = true
else
    print("❌ Task collector bind not found - collector NOT running")
end

-- Check DanNet status
local dannet_connected = mq.TLO.DanNet.Connected()
if dannet_connected then
    print("✅ DanNet is connected")
    
    -- Try to get peer count safely
    local peer_count = 0
    if mq.TLO.DanNet.PeerCount then
        peer_count = mq.TLO.DanNet.PeerCount() or 0
    end
    print("DanNet peers: " .. peer_count)
else
    print("❌ DanNet is NOT connected")
end

-- Test task window access
local task_window = mq.TLO.Window('TaskWnd')
if task_window and task_window.Open ~= nil then
    print("✅ TaskWnd window accessible")
    print("TaskWnd currently open: " .. tostring(task_window.Open()))
else
    print("❌ TaskWnd window not accessible")
end

print("=== End Test ===")