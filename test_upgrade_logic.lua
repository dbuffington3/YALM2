--[[
    Test upgrade logic for items 120895 vs 121290
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

mq.cmdf('/echo === Testing Item Comparison ===')

-- Query both items
local item1_data = db.QueryDatabaseForItemId(120895)
local item2_data = db.QueryDatabaseForItemId(121290)

if item1_data then
    mq.cmdf('/echo Item 120895: %s', item1_data.name or 'Unknown')
    mq.cmdf('/echo   AC: %s, HP: %s, Mana: %s, Endurance: %s', 
        item1_data.ac or 0, item1_data.hp or 0, item1_data.mana or 0, item1_data.endurance or 0)
else
    mq.cmdf('/echo Item 120895: NOT FOUND')
end

if item2_data then
    mq.cmdf('/echo Item 121290: %s', item2_data.name or 'Unknown')
    mq.cmdf('/echo   AC: %s, HP: %s, Mana: %s, Endurance: %s',
        item2_data.ac or 0, item2_data.hp or 0, item2_data.mana or 0, item2_data.endurance or 0)
else
    mq.cmdf('/echo Item 121290: NOT FOUND')
end

-- Check if they're in inventory/equipped
local me = mq.TLO.Me
if me then
    mq.cmdf('/echo Current inventory scan:')
    local count = me.Inventory.Pack.Size()
    for i = 1, count do
        local item = me.Inventory.Pack(i)
        if item and item() then
            local item_id = item.ID()
            local item_name = item.Name()
            if item_id == 120895 or item_id == 121290 then
                mq.cmdf('/echo   Slot %d: ID %d - %s', i, item_id, item_name)
            end
        end
    end
end
