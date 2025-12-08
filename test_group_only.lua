--[[
Group/Raid Quest Monitoring Test
Tests the corrected logic that ONLY monitors group/raid members for quests
Usage: /lua run yalm2\test_group_only
]]

local mq = require("mq")

print("=== Group/Raid Quest Monitoring Test ===")

-- Check current group/raid status
local group_count = mq.TLO.Group.Members() or 0
local raid_count = mq.TLO.Raid.Members() or 0
local total_dannet_peers = mq.TLO.DanNet.PeerCount() or 0

print(string.format("Current Status:"))
print(string.format("  Group Members: %d", group_count))
print(string.format("  Raid Members: %d", raid_count)) 
print(string.format("  Total DanNet Peers: %d", total_dannet_peers))
print("")

-- Determine what we should be monitoring
local monitoring_type = "Solo"
local expected_monitor_count = 1

if raid_count > 0 then
    monitoring_type = "Raid"
    expected_monitor_count = raid_count + 1 -- +1 for self if not in member list
elseif group_count > 0 then
    monitoring_type = "Group"  
    expected_monitor_count = group_count + 1 -- +1 includes self (index 0)
end

print(string.format("Expected Monitoring:"))
print(string.format("  Type: %s", monitoring_type))
print(string.format("  Should monitor: %d characters", expected_monitor_count))
print(string.format("  Should ignore: %d other DanNet peers", total_dannet_peers - expected_monitor_count))
print("")

-- Show who we should be monitoring
print(string.format("Characters that should be monitored for quests:"))

if monitoring_type == "Raid" then
    print(string.format("  0. %s (Self)", mq.TLO.Me.DisplayName()))
    for i = 1, raid_count do
        local member_name = mq.TLO.Raid.Member(i).DisplayName()
        if member_name and member_name ~= "" then
            print(string.format("  %d. %s", i, member_name))
        end
    end
elseif monitoring_type == "Group" then
    for i = 0, group_count do
        local member_name = nil
        if i == 0 then
            member_name = mq.TLO.Me.DisplayName() .. " (Self)"
        else
            member_name = mq.TLO.Group.Member(i).DisplayName()
        end
        if member_name and member_name ~= "" then
            print(string.format("  %d. %s", i, member_name))
        end
    end
else
    print(string.format("  0. %s (Self - Solo play)", mq.TLO.Me.DisplayName()))
end

print("")
print("=== Key Points ===")
print("✅ YALM2 should ONLY monitor group/raid members for quests")
print("✅ Other DanNet peers should be ignored for loot distribution")  
print("✅ This allows multiple separate groups to operate independently")
print("✅ Loot will only be distributed among your current group/raid")
print("")
print("Run the native quest system to verify it follows this logic!")
print("Command: /yalm2 nativequest (if not already enabled)")
print("Then check: /yalm2 dannetdiag")