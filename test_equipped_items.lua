--[[
    Show all currently equipped items
]]

local mq = require('mq')

mq.cmdf('/echo === Currently Equipped Items ===')

local me = mq.TLO.Me
if not me then
    mq.cmdf('/echo Cannot access character')
    return
end

local SLOTS = {
    'Head', 'Neck', 'Shoulders', 'Chest', 'Wrist', 'Hands',
    'Finger', 'Waist', 'Legs', 'Feet', 'Back', 'MainHand', 'OffHand'
}

for _, slot in ipairs(SLOTS) do
    local ok, equip = pcall(function() return me.Equipment(slot) end)
    if ok and equip then
        local ok2, exists = pcall(function() return equip() end)
        if ok2 and exists then
            local ok3, name = pcall(function() return equip.Name() end)
            local ok4, id = pcall(function() return equip.ID() end)
            if ok3 and name then
                mq.cmdf('/echo [%s] %s (ID: %s)', slot, name, id or '?')
            else
                mq.cmdf('/echo [%s] (no name)', slot)
            end
        else
            mq.cmdf('/echo [%s] (empty)', slot)
        end
    else
        mq.cmdf('/echo [%s] (error accessing)', slot)
    end
end

mq.cmdf('/echo === Inventory Items ===')
local count = 0
for i = 1, 50 do  -- Show first 50 items
    local ok, item = pcall(function() return me.Inventory(i) end)
    if not ok or not item then break end
    
    local ok2, exists = pcall(function() return item() end)
    if not ok2 or not exists then break end
    
    local ok3, name = pcall(function() return item.Name() end)
    local ok4, id = pcall(function() return item.ID() end)
    
    if ok3 and name then
        mq.cmdf('/echo [%d] %s (ID: %d)', i, name, id or 0)
        count = count + 1
    end
end

mq.cmdf('/echo Total inventory items shown: %d', count)
