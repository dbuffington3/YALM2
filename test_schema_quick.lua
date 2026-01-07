-- Quick debug to see database schema
package.path = package.path .. ';' .. mq.luaDir .. '/yalm2/?'

require('yalm2.lib.database')
local db = YALM2_Database
if not db.database then
    db.database = db.OpenDatabase()
end

-- Simple query to get schema
mq.cmdf('/echo ===== CHECKING RUNIC PARTISAN (120571) DATA =====')

for row in db.database:nrows("SELECT * FROM raw_item_data WHERE id = 120571") do
    for k, v in pairs(row) do
        if v and v ~= 0 and v ~= '' then
            mq.cmdf('/echo %s = %s', k, tostring(v):sub(1, 100))
        end
    end
end

mq.cmdf('/echo ===== CHECKING SHIELD (120895) DATA =====')

for row in db.database:nrows("SELECT * FROM raw_item_data WHERE id = 120895") do
    for k, v in pairs(row) do
        if v and v ~= 0 and v ~= '' then
            mq.cmdf('/echo %s = %s', k, tostring(v):sub(1, 100))
        end
    end
end

mq.cmdf('/echo ===== DATABASE COLUMNS =====')

for row in db.database:nrows("PRAGMA table_info(raw_item_data)") do
    mq.cmdf('/echo [%d] %s (%s)', row.cid, row.name, row.type)
end
