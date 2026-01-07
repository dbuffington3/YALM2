--[[
Multi-Group Quest Filtering Test
Tests that quest data is only collected from characters in the current group/raid
Usage: /lua run yalm2\test_multigroup_filtering
]]

local mq = require("mq")

print("=== Multi-Group Quest Filtering Test ===\n")

-- Check current group/raid status
local my_name = mq.TLO.Me.DisplayName()
local raid_count = mq.TLO.Raid.Members() or 0
local group_count = mq.TLO.Group.Members() or 0
local dannet_peers = mq.TLO.DanNet.PeerCount() or 0

print(string.format("Current Character: %s", my_name))
print(string.format("Raid Members: %d", raid_count))
print(string.format("Group Members: %d", group_count))
print(string.format("Total DanNet Peers: %d", dannet_peers))
print("")

-- Determine what should be monitored
local monitoring_type = "Solo"
local expected_chars = {my_name}

if raid_count > 0 then
    monitoring_type = "Raid"
    for i = 1, raid_count do
        local member = mq.TLO.Raid.Member(i)
        if member and member.DisplayName() and member.DisplayName() ~= "" then
            table.insert(expected_chars, member.DisplayName())
        end
    end
elseif group_count > 0 then
    monitoring_type = "Group"
    for i = 1, group_count do
        local member = mq.TLO.Group.Member(i)
        if member and member.DisplayName() and member.DisplayName() ~= "" then
            table.insert(expected_chars, member.DisplayName())
        end
    end
end

print(string.format("Monitoring Type: %s", monitoring_type))
print(string.format("Expected Characters to Monitor: %d", #expected_chars))
print("")

print("Expected to INCLUDE in quest data:")
for i, char in ipairs(expected_chars) do
    print(string.format("  ✓ %s", char))
end
print("")

print("Expected to IGNORE (out of group):")
local ignored_count = 0
for i = 1, dannet_peers do
    local peer = mq.TLO.DanNet.Peer(i)
    if peer and peer.Name() and peer.Name() ~= "" then
        local peer_name = peer.Name()
        local found = false
        for _, expected_char in ipairs(expected_chars) do
            if peer_name:lower() == expected_char:lower() then
                found = true
                break
            end
        end
        if not found then
            print(string.format("  ✗ %s", peer_name))
            ignored_count = ignored_count + 1
        end
    end
end

if ignored_count == 0 then
    print("  (None - all DanNet peers are in your group/raid)")
end
print("")

print("=== What to Look For ===")
print("")
print("1. Check YALM2 debug logs for filtering messages:")
print("   Command: /yalm2 loglevel debug")
print("   Look for patterns like:")
print("   - '[YALM2] ACTOR: Accepted quest data from [CharName] (in our group/raid)'")
print("   - '[YALM2] ACTOR: Ignored quest data from [CharName] (not in our group/raid)'")
print("")

print("2. Verify HUD display matches expected characters only")
print("   - Run: /yalm2 nativequest")
print("   - Check the UI - should only show characters from list above")
print("")

print("3. Test Multi-Group Isolation:")
print("   - Setup: Two separate groups connected via DanNet")
print("   - Run: /lua run yalm2\\test_multigroup_filtering on each master")
print("   - Expected: Each group's HUD shows only its own members")
print("   - Each group's loot respects only its own quests")
print("")

print("=== Quick Diagnostic ===")
if dannet_peers > (#expected_chars) then
    print(string.format("⚠️  WARNING: DanNet has %d peers but only %d are in your %s", 
        dannet_peers, #expected_chars, monitoring_type:lower()))
    print("   These extra peers should be IGNORED by the quest filtering:")
    
    local shown = 0
    for i = 1, dannet_peers do
        if shown >= 5 then
            print("   ... and more")
            break
        end
        local peer = mq.TLO.DanNet.Peer(i)
        if peer and peer.Name() and peer.Name() ~= "" then
            local peer_name = peer.Name()
            local found = false
            for _, expected_char in ipairs(expected_chars) do
                if peer_name:lower() == expected_char:lower() then
                    found = true
                    break
                end
            end
            if not found then
                print(string.format("   - %s", peer_name))
                shown = shown + 1
            end
        end
    end
    print("")
    print("   ✓ This is expected behavior for multi-group setups")
else
    print("✅ All DanNet peers are in your group/raid")
    print("   No outside characters to filter")
end

print("\n=== Test Complete ===")
print("Use commands above to verify the filtering is working correctly")
