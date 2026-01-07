--[[
    Simple inventory test
]]

local mq = require('mq')

mq.cmdf('/echo === Inventory Structure Test ===')

local me = mq.TLO.Me
if me then
    mq.cmdf('/echo Me exists')
    
    local ok, inv = pcall(function() return me.Inventory end)
    mq.cmdf('/echo Inventory access: %s', ok and 'OK' or 'FAILED')
    
    if ok and inv then
        mq.cmdf('/echo Trying to iterate inventory:')
        
        -- Try to iterate without knowing size
        local count = 0
        local max_attempts = 100  -- Safety limit
        
        for i = 1, max_attempts do
            local ok_item, item = pcall(function() return inv(i) end)
            if not ok_item or not item then
                mq.cmdf('/echo   Stopped at index %d (no item)', i)
                break
            end
            
            local ok_exists, item_exists = pcall(function() return item() end)
            if not ok_exists or not item_exists then
                mq.cmdf('/echo   Stopped at index %d (item falsy)', i)
                break
            end
            
            local ok_id, item_id = pcall(function() return item.ID() end)
            local ok_name, item_name = pcall(function() return item.Name() end)
            
            if ok_id and item_id and item_id > 0 then
                mq.cmdf('/echo   [%d] ID: %d, Name: %s', i, item_id, item_name or '?')
                count = count + 1
                if count >= 5 then  -- Show first 5 items
                    mq.cmdf('/echo   ... (and more)')
                    break
                end
            end
        end
        
        mq.cmdf('/echo Total scanned: %d items', count)
    end
else
    mq.cmdf('/echo Me is nil')
end
