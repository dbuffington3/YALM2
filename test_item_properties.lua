--[[
Test script to discover what item properties are available on MQ2 item objects
Usage: /lua run yalm2/test_item_properties
]]

local mq = require('mq')

local function test_item_properties()
    mq.cmdf('/echo ===== TESTING ITEM PROPERTIES =====')
    
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    if not ok_me or not me then
        mq.cmdf('/echo Unable to access Me TLO')
        return
    end
    
    -- Check inventory slot 34 (the NO TRADE container)
    local ok_item, item = pcall(function() return me.Inventory(34) end)
    if not ok_item or not item then
        mq.cmdf('/echo No item in slot 34')
        return
    end
    
    mq.cmdf('/echo Slot 34 item found, testing properties...')
    
    -- Test various properties
    local test_props = {
        'ID', 'Name', 'Container', 'NoTrade', 'Tradable', 'Trade',
        'Attuned', 'Lore', 'Magic', 'Augmentable', 'SellPrice',
        'Value', 'Rare', 'Heirloom', 'Cursed'
    }
    
    for _, prop in ipairs(test_props) do
        local ok, result = pcall(function() return item[prop]() end)
        if ok then
            mq.cmdf('/echo %s: %s (type: %s)', prop, tostring(result), type(result))
        else
            mq.cmdf('/echo %s: NOT AVAILABLE', prop)
        end
    end
    
    -- Now check an item inside slot 34
    mq.cmdf('/echo ===== TESTING ITEM INSIDE SLOT 34 =====')
    local ok_sub, sub_item = pcall(function() return item.Item(6) end)
    if ok_sub and sub_item then
        mq.cmdf('/echo Found sub-item, testing properties...')
        
        local ok_name, sub_name = pcall(function() return sub_item.Name() end)
        mq.cmdf('/echo Sub-item name: %s', sub_name)
        
        for _, prop in ipairs(test_props) do
            local ok, result = pcall(function() return sub_item[prop]() end)
            if ok and result ~= nil then
                mq.cmdf('/echo %s: %s (type: %s)', prop, tostring(result), type(result))
            end
        end
    else
        mq.cmdf('/echo No sub-item at position 6')
    end
end

test_item_properties()
mq.cmdf('/echo Test complete')
