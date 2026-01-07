--[[
    Check if item 121290 is in inventory
]]

local mq = require('mq')

mq.cmdf('/echo === Searching for Item 121290 ===')

local me = mq.TLO.Me
if me then
    local found = false
    local max_attempts = 200  -- Higher limit
    
    for i = 1, max_attempts do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if not ok_item or not item then
            break
        end
        
        local ok_exists, item_exists = pcall(function() return item() end)
        if not ok_exists or not item_exists then
            break
        end
        
        local ok_id, item_id = pcall(function() return item.ID() end)
        if ok_id and item_id then
            if item_id == 121290 then
                local ok_name, item_name = pcall(function() return item.Name() end)
                mq.cmdf('/echo FOUND at slot %d: ID %d - %s', i, item_id, item_name or '?')
                found = true
                break
            end
        end
    end
    
    if not found then
        mq.cmdf('/echo Item 121290 not found in inventory (scanned %d slots)', 200)
    end
else
    mq.cmdf('/echo Me is nil')
end
