--[[
    Find equipped item slot mappings
]]

local mq = require('mq')

mq.cmdf('/echo === Finding Equipment Slot Numbers ===')

local me = mq.TLO.Me
if not me then
    mq.cmdf('/echo Cannot access character')
    return
end

-- In EQ, equipment slots are numbered 0-22 typically
-- Slot 0 = Head, 1 = Neck, 2 = Shoulders, etc.
-- Then inventory starts around slot 23

mq.cmdf('/echo Scanning slots 0-40 to find equipped items:')

for i = 0, 40 do
    local ok, item = pcall(function() return me.Inventory(i) end)
    if ok and item then
        local ok2, exists = pcall(function() return item() end)
        if ok2 and exists then
            local ok3, name = pcall(function() return item.Name() end)
            local ok4, id = pcall(function() return item.ID() end)
            if ok3 and name and ok4 and id then
                mq.cmdf('/echo [Slot %d] %s (ID: %d)', i, name, id)
            end
        end
    end
end

mq.cmdf('/echo Item 120895 should show up at the OffHand slot')
