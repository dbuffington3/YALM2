#!/usr/bin/env lua

local db = require('yalm2.lib.database')
local database = db.OpenDatabase()

if not database then
    print("ERROR: Could not open database")
    os.exit(1)
end

-- Query both items
local function get_item_info(item_id)
    local query = [[
        SELECT id, name, ac, hp, mana, endur, attack, mr, fr, cr, pr, dr, itemtype, slots, classes
        FROM raw_item_data WHERE id = ?
    ]]
    local stmt = database:prepare(query)
    stmt:bind_values(item_id)
    local result = stmt:step()
    stmt:finalize()
    return result
end

local item1 = get_item_info(121564)
local item2 = get_item_info(4654)

if not item1 then
    print("Item 121564 not found")
    os.exit(1)
end

if not item2 then
    print("Item 4654 not found")
    os.exit(1)
end

print("Item 121564: " .. item1.name)
print("Item 4654: " .. item2.name)
print()

-- Check if comparable
print("COMPARABILITY CHECK:")
print("  Itemtype: " .. item1.itemtype .. " vs " .. item2.itemtype)
if item1.itemtype ~= item2.itemtype then
    print("  ✗ NOT COMPARABLE - Different itemtypes!")
    os.exit(0)
end

local slots_overlap = bit.band(item1.slots, item2.slots)
print("  Slots: " .. item1.slots .. " vs " .. item2.slots .. " (overlap: " .. slots_overlap .. ")")
if slots_overlap == 0 then
    print("  ✗ NOT COMPARABLE - No slot overlap!")
    os.exit(0)
end

print("  ✓ Items ARE comparable")
print()

-- Rogue weights: ac=1.5, hp=1.5, mana=0, endurance=2, attack=2, resists=0.5
local rogue_weights = {ac=1.5, hp=1.5, mana=0, endurance=2, resists=0.5, attack=2}

print("STAT COMPARISON (121564 → 4654):")
print(string.rep("=", 60))

local ac_delta = item1.ac - item2.ac
local hp_delta = item1.hp - item2.hp
local mana_delta = item1.mana - item2.mana
local endur_delta = item1.endur - item2.endur
local attack_delta = item1.attack - item2.attack
local resist_avg_delta = ((item1.mr - item2.mr) + (item1.fr - item2.fr) + (item1.cr - item2.cr) + (item1.pr - item2.pr) + (item1.dr - item2.dr)) / 5

print(string.format("AC:        %4d → %4d   (delta: %+3d)", item2.ac, item1.ac, ac_delta))
print(string.format("HP:        %4d → %4d   (delta: %+3d)", item2.hp, item1.hp, hp_delta))
print(string.format("Mana:      %4d → %4d   (delta: %+3d, weight=0 → ignored)", item2.mana, item1.mana, mana_delta))
print(string.format("Endurance: %4d → %4d   (delta: %+3d)", item2.endur, item1.endur, endur_delta))
print(string.format("Attack:    %4d → %4d   (delta: %+3d)", item2.attack, item1.attack, attack_delta))
print(string.format("Avg Resist:%+4.1f → %+4.1f (delta: %+.1f)", 
    (item2.mr + item2.fr + item2.cr + item2.pr + item2.dr)/5,
    (item1.mr + item1.fr + item1.cr + item1.pr + item1.dr)/5,
    resist_avg_delta))
print()

print("WEIGHTED SCORE CALCULATION (Rogue weights):")
print(string.rep("=", 60))

local ac_score = ac_delta * rogue_weights.ac
local hp_score = hp_delta * rogue_weights.hp
local mana_score = mana_delta * rogue_weights.mana
local endur_score = endur_delta * rogue_weights.endurance
local attack_score = attack_delta * rogue_weights.attack
local resist_score = resist_avg_delta * rogue_weights.resists

print(string.format("AC:        %+3d × 1.5 = %+7.1f", ac_delta, ac_score))
print(string.format("HP:        %+3d × 1.5 = %+7.1f", hp_delta, hp_score))
print(string.format("Mana:      %+3d × 0.0 = %+7.1f  (Rogue doesn't value mana)", mana_delta, mana_score))
print(string.format("Endurance: %+3d × 2.0 = %+7.1f", endur_delta, endur_score))
print(string.format("Attack:    %+3d × 2.0 = %+7.1f", attack_delta, attack_score))
print(string.format("Resists:   %+.1f × 0.5 = %+7.1f", resist_avg_delta, resist_score))
print(string.rep("-", 60))

local total_score = ac_score + hp_score + mana_score + endur_score + attack_score + resist_score
print(string.format("TOTAL SCORE DELTA: %+.1f", total_score))
print()

if total_score > 0 then
    print("✓ Item 121564 IS an upgrade over 4654")
elseif total_score < 0 then
    print("✗ Item 121564 is NOT an upgrade over 4654")
else
    print("= Items are equivalent")
end
