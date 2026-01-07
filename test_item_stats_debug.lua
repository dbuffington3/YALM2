--[[
    Test script to log item stats for 72204 (Fear Touched Bracer) and 120698 (Recondite Wildroar)
    Run in-game to verify what stats are being retrieved
]]

-- Must be run from check_cross_character_upgrades context or standalone
if not mq then
    mq = require('mq')
end

-- Import the database module the same way check_cross_character_upgrades does
local db = require('yalm2.lib.database')

-- Test the two items
mq.cmdf('/echo ========================================')
mq.cmdf('/echo TEST: Item Stats Comparison')
mq.cmdf('/echo ========================================')

mq.cmdf('/echo Testing item 72204 (Fear Touched Bracer)...')
local item_data_72204 = db.QueryDatabaseForItemId(72204)
if item_data_72204 and item_data_72204.id then
    mq.cmdf('/echo Item 72204 ID: %s', item_data_72204.id)
    mq.cmdf('/echo Item 72204 Name: %s', item_data_72204.name)
    mq.cmdf('/echo Item 72204 AC: %s', item_data_72204.ac or 'nil')
    mq.cmdf('/echo Item 72204 HP: %s', item_data_72204.hp or 'nil')
    mq.cmdf('/echo Item 72204 Mana: %s', item_data_72204.mana or 'nil')
    mq.cmdf('/echo Item 72204 Attack: %s', item_data_72204.attack or 'nil')
    mq.cmdf('/echo Item 72204 Regen: %s', item_data_72204.regen or 'nil')
else
    mq.cmdf('/echo Item 72204: NO DATA FOUND')
end

mq.cmdf('/echo ')
mq.cmdf('/echo Testing item 120698 (Recondite Wildroar Wristguard)...')
local item_data_120698 = db.QueryDatabaseForItemId(120698)
if item_data_120698 and item_data_120698.id then
    mq.cmdf('/echo Item 120698 ID: %s', item_data_120698.id)
    mq.cmdf('/echo Item 120698 Name: %s', item_data_120698.name)
    mq.cmdf('/echo Item 120698 AC: %s', item_data_120698.ac or 'nil')
    mq.cmdf('/echo Item 120698 HP: %s', item_data_120698.hp or 'nil')
    mq.cmdf('/echo Item 120698 Mana: %s', item_data_120698.mana or 'nil')
    mq.cmdf('/echo Item 120698 Attack: %s', item_data_120698.attack or 'nil')
    mq.cmdf('/echo Item 120698 Regen: %s', item_data_120698.regen or 'nil')
else
    mq.cmdf('/echo Item 120698: NO DATA FOUND')
end

mq.cmdf('/echo ')
mq.cmdf('/echo ========================================')
mq.cmdf('/echo TEST COMPLETE')
mq.cmdf('/echo ========================================')
