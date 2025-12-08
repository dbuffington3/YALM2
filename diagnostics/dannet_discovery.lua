--- Enhanced DanNet Character Discovery for YALM2
--- Tests multiple methods to find all connected DanNet characters
--- Provides detailed diagnostics and comparison with group/raid membership

local mq = require("mq")
local dannet = require("yalm.lib.dannet")
require("yalm2.lib.Write")

local dannet_diagnostics = {}

--- Method 1: Get all DanNet connected peers using DanNet TLO
dannet_diagnostics.get_all_dannet_peers = function()
    Write.Info("=== DanNet Peer Discovery Method 1: All Connected Peers ===")
    
    local all_peers = {}
    
    -- Try to get DanNet peer count and iterate
    local peer_count = mq.TLO.DanNet.PeerCount() or 0
    Write.Info("DanNet reports %d total peers", peer_count)
    
    if peer_count > 0 then
        -- Try different methods to get peer names
        
        -- Method 1a: Try DanNet.Peers TLO (if it exists)
        if mq.TLO.DanNet.Peers then
            Write.Info("Trying DanNet.Peers TLO...")
            local peers_string = mq.TLO.DanNet.Peers() or ""
            Write.Info("DanNet.Peers returned: '%s'", peers_string)
            
            if peers_string and peers_string ~= "" then
                -- Parse peer list (DanNet uses pipe separators)
                for peer in string.gmatch(peers_string, "([^|]+)") do
                    local clean_peer = peer:match("^%s*(.-)%s*$") -- trim whitespace
                    if clean_peer and clean_peer ~= "" then
                        table.insert(all_peers, clean_peer)
                        Write.Info("Found peer from Peers TLO: %s", clean_peer)
                    end
                end
            end
        else
            Write.Warn("DanNet.Peers TLO not available")
        end
        
        -- Method 1b: DanNet.Peer(index) doesn't exist, skip this method
        if #all_peers == 0 then
            Write.Warn("DanNet.Peer(index) TLO not available - this is normal")
        end
        
        -- Method 1c: Try DanNet.Peer[name] validation with known names
        if #all_peers == 0 then
            Write.Warn("Could not iterate DanNet peers directly, will use fallback methods")
        end
    end
    
    return all_peers
end

--- Method 2: Enhanced Group/Raid + DanNet connectivity testing
dannet_diagnostics.get_group_raid_with_dannet = function()
    Write.Info("=== DanNet Peer Discovery Method 2: Group/Raid + DanNet Test ===")
    
    local connected = {}
    local all_members = {}
    
    -- Collect all group/raid members
    if mq.TLO.Group.Members() > 0 then
        Write.Info("Checking %d group members for DanNet connectivity", mq.TLO.Group.Members())
        for i = 0, mq.TLO.Group.Members() do
            local member_name = nil
            if i == 0 then
                member_name = mq.TLO.Me.DisplayName()
            else
                member_name = mq.TLO.Group.Member(i).DisplayName()
            end
            
            if member_name and member_name ~= "" then
                table.insert(all_members, {name = member_name, source = "Group", index = i})
            end
        end
    end
    
    if mq.TLO.Raid.Members() > 0 then
        Write.Info("Checking %d raid members for DanNet connectivity", mq.TLO.Raid.Members())
        for i = 1, mq.TLO.Raid.Members() do
            local member_name = mq.TLO.Raid.Member(i).DisplayName()
            if member_name and member_name ~= "" then
                -- Check if not already in list (from group)
                local already_added = false
                for _, existing in ipairs(all_members) do
                    if existing.name == member_name then
                        already_added = true
                        break
                    end
                end
                
                if not already_added then
                    table.insert(all_members, {name = member_name, source = "Raid", index = i})
                end
            end
        end
    end
    
    Write.Info("Found %d total group/raid members to test", #all_members)
    
    -- Test DanNet connectivity for each member
    for _, member in ipairs(all_members) do
        Write.Info("Testing DanNet connectivity to %s (%s %d)...", member.name, member.source, member.index)
        
        -- Test basic connectivity
        local response = dannet.query(member.name, "Me.Name", 2000)
        Write.Info("DanNet query result for %s: '%s'", member.name, tostring(response))
        
        if response and response ~= "NULL" and response ~= "" then
            table.insert(connected, member.name)
            Write.Info("✅ %s is DanNet connected (%s)", member.name, member.source)
            
            -- Get additional info about this character
            local zone = dannet.query(member.name, "Zone.ShortName", 1000)
            local level = dannet.query(member.name, "Me.Level", 1000) 
            Write.Info("   Zone: %s, Level: %s", zone or "unknown", level or "unknown")
        else
            Write.Warn("❌ %s is NOT DanNet connected (%s)", member.name, member.source)
        end
    end
    
    return connected, all_members
end

--- Method 3: Try to discover DanNet peers by known character patterns
dannet_diagnostics.discover_unknown_peers = function(known_connected)
    Write.Info("=== DanNet Peer Discovery Method 3: Pattern Discovery ===")
    
    local additional_peers = {}
    
    -- If we know some characters are connected but not in group/raid,
    -- we could try common naming patterns or server-specific discovery
    
    Write.Info("Known connected from group/raid: %d", #known_connected)
    Write.Info("Need to find: %d additional DanNet peers", 13 - #known_connected)
    
    -- This would require more advanced discovery methods:
    -- 1. Query guild members if in same guild
    -- 2. Try common character name patterns (same account)
    -- 3. Use DanNet broadcast/discovery if available
    
    Write.Warn("Advanced peer discovery not yet implemented")
    Write.Info("Consider implementing guild member checking or character pattern matching")
    
    return additional_peers
end

--- Main diagnostic function
dannet_diagnostics.run_full_diagnostics = function()
    Write.Info("=== YALM2 DanNet Character Discovery Diagnostics ===")
    Write.Info("Expected: 13 DanNet connected characters")
    Write.Info("Currently found: 5 characters")
    Write.Info("")
    
    -- Method 1: Try to get all DanNet peers directly
    local all_peers = dannet_diagnostics.get_all_dannet_peers()
    
    -- Method 2: Check group/raid members with DanNet testing
    local group_raid_connected, all_members = dannet_diagnostics.get_group_raid_with_dannet()
    
    -- Method 3: Try to discover additional peers
    local additional_peers = dannet_diagnostics.discover_unknown_peers(group_raid_connected)
    
    -- Summary
    Write.Info("")
    Write.Info("=== DISCOVERY SUMMARY ===")
    Write.Info("Method 1 (All Peers): %d characters", #all_peers)
    Write.Info("Method 2 (Group/Raid): %d characters", #group_raid_connected)
    Write.Info("Method 3 (Additional): %d characters", #additional_peers)
    
    local total_unique = {}
    local add_unique = function(list, source)
        for _, name in ipairs(list) do
            if not total_unique[name] then
                total_unique[name] = source
                Write.Info("✅ %s (from %s)", name, source)
            end
        end
    end
    
    Write.Info("")
    Write.Info("=== UNIQUE CHARACTERS FOUND ===")
    add_unique(all_peers, "All Peers")
    add_unique(group_raid_connected, "Group/Raid")
    add_unique(additional_peers, "Additional")
    
    local total_count = 0
    for name, source in pairs(total_unique) do
        total_count = total_count + 1
    end
    
    Write.Info("")
    Write.Info("=== FINAL RESULTS ===")
    Write.Info("Total unique DanNet characters found: %d", total_count)
    Write.Info("Expected: 13")
    Write.Info("Missing: %d", 13 - total_count)
    
    if total_count < 13 then
        Write.Warn("⚠️  Missing %d DanNet characters!", 13 - total_count)
        Write.Info("Recommendations:")
        Write.Info("1. Check if all 13 characters are actually in same group/raid")
        Write.Info("2. Verify DanNet connectivity with /dquery command manually")
        Write.Info("3. Consider characters on different accounts or in different zones")
        Write.Info("4. Check guild members if characters are in same guild")
    else
        Write.Info("✅ All expected DanNet characters found!")
    end
    
    return total_unique
end

return dannet_diagnostics