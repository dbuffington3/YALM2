-- Debug script to check what fields are in the database for items
package.path = package.path .. ';' .. mq.luaDir .. '/yalm2/?'

require('yalm2.lib.database')
local db = YALM2_Database
if not db.database then
    db.database = db.OpenDatabase()
    if not db.database then
        mq.cmdf('/echo Failed to open database')
        return
    end
end

-- Check what columns are in the raw_item_data table
local query = "PRAGMA table_info(raw_item_data);"
local result = db.database:exec(query)

mq.cmdf('/echo ========== DATABASE SCHEMA FOR raw_item_data ==========')

if result and result[1] then
    for _, row in ipairs(result[1]) do
        -- PRAGMA returns: cid, name, type, notnull, dflt_value, pk
        mq.cmdf('/echo [%d] %s (%s)', row.cid, row.name, row.type)
    end
else
    mq.cmdf('/echo No results from PRAGMA')
end

mq.cmdf('/echo ===================================================')

-- Also check a sample item to see what values are available
mq.cmdf('/echo')
mq.cmdf('/echo ========== SAMPLE ITEM DATA ==========')

local sample_query = "SELECT * FROM raw_item_data WHERE id = 120571 LIMIT 1;"  -- Runic Partisan
local sample = db.database:exec(sample_query)

if sample and sample[1] and sample[1][1] then
    local item = sample[1][1]
    for key, value in pairs(item) do
        if value and value ~= '' and value ~= 0 then
            mq.cmdf('/echo %s: %s', key, tostring(value))
        end
    end
else
    mq.cmdf('/echo No item data found')
end

mq.cmdf('/echo ===================================================')
