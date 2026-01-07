--[[
    Show what inventory items could be upgrades to current equipped gear
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

mq.cmdf('/echo === Potential Inventory Upgrades ===')

local me = mq.TLO.Me
if not me then
    mq.cmdf('/echo Cannot access character')
    return
end

-- Equipment slots to check
local EQUIPMENT_SLOTS = {
    'Head', 'Neck', 'Shoulders', 'Chest', 'Wrist', 'Hands',
    'Finger', 'Waist', 'Legs', 'Feet', 'Back', 'MainHand', 'OffHand'
}

-- Get all inventory items
local inventory_items = {}
for i = 1, 200 do
    local ok, item = pcall(function() return me.Inventory(i) end)
    if not ok or not item then break end
    
    local ok2, exists = pcall(function() return item() end)
    if not ok2 or not exists then break end
    
    local ok_id, id = pcall(function() return item.ID() end)
    local ok_name, name = pcall(function() return item.Name() end)
    
    if ok_id and id and id > 0 then
        table.insert(inventory_items, {
            id = id,
            name = name or '?'
        })
    end
end

mq.cmdf('/echo [Debug] Found %d inventory items', #inventory_items)

-- Check each equipped slot for potential upgrades
local found_count = 0
for _, slot_name in ipairs(EQUIPMENT_SLOTS) do
    local equipped = me.Equipment(slot_name)
    if equipped and equipped() then
        local equipped_id = equipped.ID()
        local equipped_name = equipped.Name()
        
        if equipped_id and equipped_id > 0 then
            -- Check each inventory item
            for _, inv_item in ipairs(inventory_items) do
                if inv_item.id ~= equipped_id then
                    found_count = found_count + 1
                    if found_count <= 5 then
                        mq.cmdf('/echo [%s] %s → %s (ID: %d)', slot_name, equipped_name, inv_item.name, inv_item.id)
                    end
                end
            end
        end
    end
end

mq.cmdf('/echo Total comparisons possible: %d', found_count)
