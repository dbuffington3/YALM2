--[[
    Test Generic Equipment Distribution Module
    
    Tests the new generic equipment_distribution.lua which works with
    any armor set defined in config/armor_sets.lua
]]

local mq = require('mq')

print('==============================================================================')
print('Testing Generic Equipment Distribution Module')
print('==============================================================================')

-- Test characters
local test_chars = { 'Echoveil', 'Malrik', 'Calystris' }

-- Load the module
local success, eq_dist = pcall(require, 'yalm2.lib.equipment_distribution')

if not success then
    print('✗ Failed to load module: ' .. tostring(eq_dist))
    return
end

print('✓ Module loaded successfully\n')

-- Show available armor sets
print('[Available Armor Sets]')
for set_name, set_config in pairs(eq_dist.armor_sets) do
    print(string.format('  - %s (%s)', set_name, set_config.display_name))
    for piece_type, piece_config in pairs(set_config.pieces) do
        print(string.format('    - %s (slots: %s, ID: %d)', piece_type, table.concat(piece_config.slots, ','), piece_config.remnant_id))
    end
end

print('\n' .. string.rep('=', 78))
print('[Test 1] Item Identification')
print(string.rep('=', 78))

local test_items = {
    'Recondite Remnant of Truth',
    'Recondite Remnant of Desire',
    'Random Item Name',
    'Recondite Remnant of Survival',
}

for _, item in ipairs(test_items) do
    local set, piece = eq_dist.identify_armor_item(item)
    if set then
        print(string.format('✓ %s → %s / %s', item, set, piece))
    else
        print(string.format('✗ %s → Not an armor item', item))
    end
end

print('\n' .. string.rep('=', 78))
print('[Test 2] Equipment Status & Distribution (Recondite - Wrist)')
print(string.rep('=', 78))

local set_name = 'Recondite'
local piece_type = 'Wrist'

print(string.format('Set: %s, Piece: %s\n', set_name, piece_type))

for _, char in ipairs(test_chars) do
    local breakdown = eq_dist.get_need_breakdown(char, set_name, piece_type)
    print(string.format('%s:', char))
    print(string.format('  - Equipped: %d/%d', breakdown.equipped, breakdown.max_slots))
    print(string.format('  - %s: %d', breakdown.remnant_name, breakdown.remnants))
    print(string.format('  - Satisfaction: %d\n', breakdown.satisfaction))
end

local best, score = eq_dist.find_best_recipient(test_chars, set_name, piece_type)
if best then
    print(string.format('✓ Best recipient: %s (satisfaction: %d)\n', best, score))
else
    print('✗ No valid recipient found\n')
end

print(string.rep('=', 78))
print('[Test 3] All Recondite Piece Types')
print(string.rep('=', 78))

local recondite_config = eq_dist.armor_sets['Recondite']
if recondite_config and recondite_config.pieces then
    for piece_type in pairs(recondite_config.pieces) do
        print(string.format('\n%s:', piece_type:upper()))
        
        for _, char in ipairs(test_chars) do
            local breakdown = eq_dist.get_need_breakdown(char, 'Recondite', piece_type)
            print(string.format('  %s: equipped=%d, remnants=%d, satisfaction=%d',
                char, breakdown.equipped, breakdown.remnants, breakdown.satisfaction))
        end
        
        local best, score = eq_dist.find_best_recipient(test_chars, 'Recondite', piece_type)
        if best then
            print(string.format('  → Best: %s (score: %d)', best, score))
        end
    end
end

print('\n' .. string.rep('=', 78))
print('TEST COMPLETE')
print(string.rep('=', 78))
print('\nModule is ready for integration into looting.lua')
print('To add a new armor set:')
print('  1. Edit config/armor_sets.lua')
print('  2. Add new set with piece definitions')
print('  3. No code changes needed - it works automatically!')
