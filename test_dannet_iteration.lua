--[[
Test DAN net client iteration to see how many characters are available
]]

local mq = require('mq')

mq.cmdf('/echo [TEST] Starting DAN net client iteration...')

-- Test getting group members first
local group_count = 0
local ok_group, group = pcall(function() return mq.TLO.Group end)
if ok_group and group then
    local ok_members, members = pcall(function() return group.Members() end)
    if ok_members and members then
        group_count = tonumber(members) or 0
        mq.cmdf('/echo [TEST] Found %d group members', group_count)
        
        for i = 1, group_count do
            local ok_member, member = pcall(function() return group.Member(i) end)
            if ok_member and member then
                local ok_name, name = pcall(function() return member.Name() end)
                if ok_name and name then
                    mq.cmdf('/echo [TEST]   Group member %d: %s', i, name)
                end
            end
        end
    end
end

-- Test DAN net client iteration
mq.cmdf('/echo [TEST] Testing DAN net client iteration...')
local dannet_count = 0
local ok, dannet = pcall(function() return mq.TLO.DanNet end)
if ok and dannet then
    for i = 1, 100 do
        local ok_client, client = pcall(function() return dannet.Client(i) end)
        if ok_client and client then
            local ok_name, name = pcall(function() return client.Name() end)
            if ok_name and name and name ~= "" then
                dannet_count = dannet_count + 1
                local ok_class, class = pcall(function() return client.Class() end)
                local ok_level, level = pcall(function() return client.Level() end)
                mq.cmdf('/echo [TEST]   Client %d: %s (Class: %s, Level: %s)', i, name, (ok_class and class) or "?", (ok_level and level) or "?")
            end
        else
            mq.cmdf('/echo [TEST]   Client %d: Not available', i)
        end
    end
else
    mq.cmdf('/echo [TEST] Failed to access DAN net TLO')
end

mq.cmdf('/echo [TEST] Summary: Found %d DAN net clients', dannet_count)
