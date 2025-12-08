--[[
Quick DanNet Connectivity Test
Run this to check how many DanNet characters are actually connected
Usage: /lua run yalm2\test_dannet_quick
]]

local mq = require("mq")

print("=== Quick DanNet Connectivity Test ===")

-- Method 1: Check DanNet peer count
local peer_count = mq.TLO.DanNet.PeerCount() or 0
print(string.format("DanNet.PeerCount(): %d", peer_count))

-- Method 2: Try to get peer list
if mq.TLO.DanNet.Peers then
    local peers_string = mq.TLO.DanNet.Peers() or ""
    print(string.format("DanNet.Peers(): '%s'", peers_string))
    
    if peers_string and peers_string ~= "" then
        local count = 0
        -- DanNet uses pipe separators, not commas
        for peer in string.gmatch(peers_string, "([^|]+)") do
            local clean_peer = peer:match("^%s*(.-)%s*$")
            if clean_peer and clean_peer ~= "" then
                count = count + 1
                print(string.format("  Peer %d: %s", count, clean_peer))
            end
        end
        print(string.format("Total peers parsed: %d", count))
    end
else
    print("DanNet.Peers() TLO not available")
end

-- Method 3: Try individual peer access (DanNet.Peer(index) doesn't exist)
print("\nNote: DanNet.Peer(index) TLO doesn't exist - using peer list instead")

-- Method 4: Check group/raid membership
print("\nGroup/Raid Information:")
local group_count = mq.TLO.Group.Members() or 0
local raid_count = mq.TLO.Raid.Members() or 0
print(string.format("Group.Members(): %d", group_count))
print(string.format("Raid.Members(): %d", raid_count))

if group_count > 0 then
    print("Group members:")
    for i = 0, group_count do
        local member_name = nil
        if i == 0 then
            member_name = mq.TLO.Me.DisplayName()
        else  
            member_name = mq.TLO.Group.Member(i).DisplayName()
        end
        if member_name and member_name ~= "" then
            print(string.format("  Group[%d]: %s", i, member_name))
        end
    end
end

if raid_count > 0 then
    print("Raid members (first 10):")
    for i = 1, math.min(raid_count, 10) do
        local member_name = mq.TLO.Raid.Member(i).DisplayName()
        if member_name and member_name ~= "" then
            print(string.format("  Raid[%d]: %s", i, member_name))
        end
    end
    if raid_count > 10 then
        print(string.format("  ... and %d more raid members", raid_count - 10))
    end
end

print("\n=== Summary ===")
print(string.format("Expected DanNet peers: 13"))
print(string.format("Reported DanNet peers: %d", peer_count))
print(string.format("Group members: %d", group_count))
print(string.format("Raid members: %d", raid_count))
print(string.format("Total group+raid (unique): %d", group_count + raid_count))

if peer_count > (group_count + raid_count) then
    print(string.format("⚠️  DanNet has %d more peers than group+raid members", 
        peer_count - (group_count + raid_count)))
    print("This suggests characters outside your group/raid are connected via DanNet")
end

print("\nRun '/yalm2 dannetdiag' for full diagnostics with connectivity testing")