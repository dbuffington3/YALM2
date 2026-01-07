--[[
    Test Recondite Helper - All Armor Types
    
    Tests the distribution logic for all Recondite armor pieces:
    - Wrist (2 slots) - Remnant of Truth (56186)
    - Chest (1 slot) - Remnant of Desire (56192)
    - Arms (1 slot) - Remnant of Devotion (56190)
    - Legs (1 slot) - Remnant of Fear (56191)
    - Head (1 slot) - Remnant of Greed (56187)
    - Hands (1 slot) - Remnant of Knowledge (56189)
    - Feet (1 slot) - Remnant of Survival (56188)
]]

local mq = require('mq')

print('==============================================================================')
print('Testing Recondite Helper - All Armor Types')
print('==============================================================================')

-- Test characters
local test_chars = { 'Echoveil', 'Malrik', 'Calystris' }

-- Load the module
local success, recondite_helper = pcall(require, 'yalm2.lib.recondite_helper')

if not success then
    print('✗ Failed to load module: ' .. tostring(recondite_helper))
    return
end

print('✓ Module loaded successfully\n')

-- Test all armor types
local armor_types = { 'Wrist', 'Chest', 'Arms', 'Legs', 'Head', 'Hands', 'Feet' }

for _, armor_type in ipairs(armor_types) do
    print(string.format('=============================================================================='))
    print(string.format('[%s Armor]', armor_type:upper()))
    print(string.format('=============================================================================='))
    
    -- Get armor config to show slot info
    local config = recondite_helper.RECONDITE_ARMOR_SLOTS[armor_type]
    if config then
        print(string.format('Remnant: %s (ID: %d)', config.remnant_name, config.remnant_id))
        print(string.format('Slots: %s', table.concat(config.slots, ', ')))
        print()
    end
    
    -- Show breakdown for each character
    print('[Satisfaction Scores (lower = more need)]')
    for _, char in ipairs(test_chars) do
        local breakdown = recondite_helper.get_need_breakdown(char, armor_type)
        
        local slot_desc = ''
        if armor_type == 'Wrist' then
            slot_desc = string.format(' (%d/2 slots)', breakdown.equipped)
        else
            slot_desc = string.format(' (%d/1 slot)', breakdown.equipped)
        end
        
        print(string.format('  %s: %d equipped + %d remnants = score %d%s',
            char, breakdown.equipped, breakdown.remnants, breakdown.satisfaction, slot_desc))
    end
    
    -- Determine best recipient
    local best, score = recondite_helper.find_best_recipient(test_chars, armor_type)
    if best then
        print(string.format('\n✓ Best recipient: %s (score: %d)\n', best, score))
    else
        print('\n✗ No valid recipient found\n')
    end
end

print('==============================================================================')
print('TEST COMPLETE')
print('==============================================================================')
