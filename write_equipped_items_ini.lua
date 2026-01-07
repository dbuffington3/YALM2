--[[
    Write Equipped Items to INI File
    Fast version using INI files like Gearly does
    Each character runs this locally to write their equipped items
    Usage: /lua run write_equipped_items_ini
]]

local mq = require('mq')
local LIP = require('yalm2.lib.LIP')

-- Get character name and build path
local char_name = mq.TLO.Me.Name()
local luaDir = mq.luaDir
local fileName = '/YALM2/equipped/' .. char_name .. '.ini'
local path = luaDir .. fileName

mq.cmdf('/echo [YALM2] Writing equipped items for %s to: %s', char_name, path)

-- Collect all equipped items into a table structure LIP can save
local equipped_data = {}

for slot = 0, 22 do
    local item = mq.TLO.Me.Inventory(slot)
    if item and item.ID() then
        local item_id = tonumber(item.ID()) or 0
        if item_id > 0 then
            local item_name = item.Name()
            -- Use slot name as key for clarity
            local slot_key = string.format('Slot_%d', slot)
            equipped_data[slot_key] = string.format('%d|%s', item_id, item_name)
            mq.cmdf('/echo [YALM2] Slot %d: %d (%s)', slot, item_id, item_name)
        end
    end
end

-- Create section for equipped items
local ini_table = {
    Equipped = equipped_data
}

-- Write to INI using LIP
local success = LIP.save(path, ini_table)

if success then
    local count = 0
    for _ in pairs(equipped_data) do count = count + 1 end
    mq.cmdf('/echo [YALM2] ✓ Successfully wrote %d equipped items to: %s', count, path)
else
    mq.cmdf('/echo [YALM2] ✗ ERROR: Failed to write INI file to: %s', path)
end

