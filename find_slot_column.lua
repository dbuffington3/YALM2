-- Find the slot column by comparing two OffHand items
package.path = package.path .. ';' .. mq.luaDir .. '/yalm2/?'

require('yalm2.lib.database')
local db = YALM2_Database
if not db.database then
    db.database = db.OpenDatabase()
end

-- Item 120895 = Shield of the Dreaming Centaur (currently equipped in OffHand - slot 12)
-- Item 121290 = Rabbit-Hide Roundshield (in inventory, also OffHand slot)

mq.cmdf('/echo ===== FINDING SLOT COLUMN =====')
mq.cmdf('/echo Item 120895 (Shield of the Dreaming Centaur - equipped in OffHand slot 12):')

for row in db.database:nrows("SELECT * FROM raw_item_data WHERE id = 120895") do
    for k, v in pairs(row) do
        if v == 12 or v == '12' then
            mq.cmdf('/echo *** FOUND IT! Column "%s" = %s ***', k, tostring(v))
        end
    end
end

mq.cmdf('/echo')
mq.cmdf('/echo Item 121290 (Rabbit-Hide Roundshield - also OffHand):')

for row in db.database:nrows("SELECT * FROM raw_item_data WHERE id = 121290") do
    for k, v in pairs(row) do
        if v == 12 or v == '12' then
            mq.cmdf('/echo *** FOUND IT! Column "%s" = %s ***', k, tostring(v))
        end
    end
end

mq.cmdf('/echo')
mq.cmdf('/echo Checking all columns for both items to show the pattern:')
mq.cmdf('/echo')

for row in db.database:nrows("SELECT * FROM raw_item_data WHERE id = 120895") do
    for k, v in pairs(row) do
        if type(v) == 'number' and (v == 12 or v == 14) then
            mq.cmdf('/echo [120895] %s = %s', k, tostring(v))
        end
    end
end

for row in db.database:nrows("SELECT * FROM raw_item_data WHERE id = 121290") do
    for k, v in pairs(row) do
        if type(v) == 'number' and (v == 12 or v == 14) then
            mq.cmdf('/echo [121290] %s = %s', k, tostring(v))
        end
    end
end
