--[[
    Test script to log item stats for 72204 (Fear Touched Bracer) and 120698 (Recondite Wildroar)
    Run in-game to verify what stats are being retrieved
]]

-- Import the database module
local db = require('lib.database')

local function get_item_stats(item_id)
    --[[
    Get item stats from database: AC, HP, Mana, Endurance, Resists, etc.
    Returns table with all relevant stats or nil if not found
    ]]
    if not item_id or item_id == 0 then
        return nil
    end
    
    local item_data = db.QueryDatabaseForItemId(item_id)
    
    if not item_data or not item_data.id then
        return nil
    end
    
    -- Convert database field names to stat names (database uses abbreviations)
    local row = item_data
    return {
        ac = tonumber(row.ac) or 0,
        hp = tonumber(row.hp) or 0,
        mana = tonumber(row.mana) or 0,
        endurance = tonumber(row.endur) or 0,
        resists_magic = tonumber(row.mr) or 0,
        resists_fire = tonumber(row.fr) or 0,
        resists_cold = tonumber(row.cr) or 0,
        resists_poison = tonumber(row.pr) or 0,
        resists_disease = tonumber(row.dr) or 0,
        attack = tonumber(row.attack) or 0,
        hp_regen = tonumber(row.regen) or 0,
        mana_regen = tonumber(row.manaregen) or 0,
        heal_amount = tonumber(row.healamt) or 0,
        clairvoyance = tonumber(row.clairvoyance) or 0,
        itemtype = tonumber(row.itemtype) or 0,
        slots = tonumber(row.slots) or 0,
        classes = tonumber(row.classes) or 0,
        required_level = tonumber(row.reqlevel) or 0,
        nodrop = tonumber(row.nodrop) or 0,
        questitem = tonumber(row.questitem) or 0,
        tradeskills = tonumber(row.tradeskills) or 0,
    }
end

-- Test the two items
mq.cmdf('/echo ========================================')
mq.cmdf('/echo TEST: Item Stats Comparison')
mq.cmdf('/echo ========================================')

mq.cmdf('/echo Testing item 72204 (Fear Touched Bracer)...')
local stats_72204 = get_item_stats(72204)
if stats_72204 then
    mq.cmdf('/echo Item 72204 AC: %d', stats_72204.ac)
    mq.cmdf('/echo Item 72204 HP: %d', stats_72204.hp)
    mq.cmdf('/echo Item 72204 Mana: %d', stats_72204.mana)
    mq.cmdf('/echo Item 72204 Attack: %d', stats_72204.attack)
    mq.cmdf('/echo Item 72204 HP Regen: %d', stats_72204.hp_regen)
    mq.cmdf('/echo Item 72204 Itemtype: %d', stats_72204.itemtype)
    mq.cmdf('/echo Item 72204 All values zero? AC=%d, HP=%d, Mana=%d, Attack=%d', 
        stats_72204.ac, stats_72204.hp, stats_72204.mana, stats_72204.attack)
else
    mq.cmdf('/echo Item 72204: NO DATA FOUND')
end

mq.cmdf('/echo ')
mq.cmdf('/echo Testing item 120698 (Recondite Wildroar Wristguard)...')
local stats_120698 = get_item_stats(120698)
if stats_120698 then
    mq.cmdf('/echo Item 120698 AC: %d', stats_120698.ac)
    mq.cmdf('/echo Item 120698 HP: %d', stats_120698.hp)
    mq.cmdf('/echo Item 120698 Mana: %d', stats_120698.mana)
    mq.cmdf('/echo Item 120698 Attack: %d', stats_120698.attack)
    mq.cmdf('/echo Item 120698 HP Regen: %d', stats_120698.hp_regen)
    mq.cmdf('/echo Item 120698 Itemtype: %d', stats_120698.itemtype)
else
    mq.cmdf('/echo Item 120698: NO DATA FOUND')
end

mq.cmdf('/echo ')
mq.cmdf('/echo ========================================')
mq.cmdf('/echo TEST COMPLETE')
mq.cmdf('/echo ========================================')
