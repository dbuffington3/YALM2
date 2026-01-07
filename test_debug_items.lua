--[[
    Debug: Show what the script finds for a specific slot
]]

local mq = require('mq')

-- Import the database module
require('yalm2.lib.database')
local db = YALM2_Database
if not db.database then
    db.database = db.OpenDatabase()
    if not db.database then
        mq.cmdf('/echo Failed to open database')
        return
    end
end

mq.cmdf('/echo === DEBUG: OffHand Slot Analysis ===')

local me = mq.TLO.Me
if not me then
    mq.cmdf('/echo Cannot access character')
    return
end

-- Get equipped offhand
local ok_equip, offhand = pcall(function() return me.Equipment('OffHand') end)
mq.cmdf('/echo Equipment(OffHand) access: %s', ok_equip and 'OK' or 'FAILED')

if ok_equip and offhand then
    local ok_exists, exists = pcall(function() return offhand() end)
    mq.cmdf('/echo offhand exists: %s', ok_exists and exists and 'YES' or 'NO')
    
    if ok_exists and exists then
        local ok_id, id = pcall(function() return offhand.ID() end)
        local ok_name, name = pcall(function() return offhand.Name() end)
        mq.cmdf('/echo Equipped OffHand: ID %s, Name: %s', id or '?', name or '?')
        
        if ok_id and id and id > 0 then
            local stats = db.QueryDatabaseForItemId(id)
            if stats then
                mq.cmdf('/echo Equipped stats: AC=%s, HP=%s, Mana=%s', 
                    stats.ac or 0, stats.hp or 0, stats.mana or 0)
            else
                mq.cmdf('/echo Equipped item NOT in database')
            end
        end
    end
end

-- Get inventory items and check offhand slot specifically
mq.cmdf('/echo Scanning inventory for potential OffHand items:')

local found_120895 = false
local found_121290 = false

for i = 1, 200 do
    local ok_item, item = pcall(function() return me.Inventory(i) end)
    if not ok_item or not item then break end
    
    local ok_exists, exists = pcall(function() return item() end)
    if not ok_exists or not exists then break end
    
    local ok_id, id = pcall(function() return item.ID() end)
    
    if ok_id and id then
        if id == 120895 then
            found_120895 = true
            mq.cmdf('/echo   Found 120895 at slot %d (main inventory)', i)
        elseif id == 121290 then
            found_121290 = true
            mq.cmdf('/echo   Found 121290 at slot %d (main inventory)', i)
        end
    end
    
    -- Also scan containers
    local ok_container, is_container = pcall(function() return item.Container() end)
    if ok_container and is_container then
        for j = 1, 50 do
            local ok_sub, sub_item = pcall(function() return item.Item(j) end)
            if not ok_sub or not sub_item then break end
            
            local ok_sub_exists, sub_exists = pcall(function() return sub_item() end)
            if not ok_sub_exists or not sub_exists then break end
            
            local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
            
            if ok_sub_id and sub_id then
                if sub_id == 120895 then
                    found_120895 = true
                    mq.cmdf('/echo   Found 120895 at slot %d, container slot %d', i, j)
                elseif sub_id == 121290 then
                    found_121290 = true
                    mq.cmdf('/echo   Found 121290 at slot %d, container slot %d', i, j)
                    
                    -- Query this item
                    local stats = db.QueryDatabaseForItemId(121290)
                    if stats then
                        mq.cmdf('/echo   121290 stats: AC=%s, HP=%s, Mana=%s', 
                            stats.ac or 0, stats.hp or 0, stats.mana or 0)
                    else
                        mq.cmdf('/echo   121290 NOT in database')
                    end
                end
            end
        end
    end
end

mq.cmdf('/echo Found 120895: %s', found_120895 and 'YES' or 'NO')
mq.cmdf('/echo Found 121290: %s', found_121290 and 'YES' or 'NO')
