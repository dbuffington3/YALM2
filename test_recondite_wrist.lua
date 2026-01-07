--[[
    Test Recondite Helper - Wrist Armor Distribution Logic
    
    This tests the logic for distributing Recondite Remnant of Truth items.
    Distribution should go to the character with the LOWEST satisfaction score
    (fewest equipped pieces + fewest remnants in inventory).
]]

local mq = require('mq')
local dannet = require('yalm2.lib.dannet')

print('==============================================================================')
print('Testing Recondite Wrist Armor Distribution Logic')
print('==============================================================================')

-- Test characters
local test_chars = { 'Echoveil', 'Malrik', 'Calystris' }

print('\n[Test 1] Query Equipped Wrist Items')
print('----------------------------------------------------------------------')

for _, char in ipairs(test_chars) do
    print(string.format('\nCharacter: %s', char))
    
    local slot9_item = dannet.query(char, 'Me.Inventory[9].Name', 100)
    local slot10_item = dannet.query(char, 'Me.Inventory[10].Name', 100)
    
    print(string.format('  Slot 9 (Left Wrist): %s', slot9_item or 'EMPTY'))
    print(string.format('  Slot 10 (Right Wrist): %s', slot10_item or 'EMPTY'))
end

print('\n[Test 2] Query Recondite Remnant of Truth Inventory (Item ID 120331)')
print('----------------------------------------------------------------------')

for _, char in ipairs(test_chars) do
    print(string.format('\nCharacter: %s', char))
    
    local count = dannet.query(char, 'FindItemCount[120331]', 100)
    print(string.format('  Remnant count: %s', tostring(count)))
end

print('\n[Test 3] Load Recondite Helper Module & Calculate Need')
print('----------------------------------------------------------------------')

local success, recondite_helper = pcall(require, 'yalm2.lib.recondite_helper')

if success then
    print('✓ Module loaded successfully\n')
    
    -- Show breakdown for each character
    print('[Satisfaction Scores (lower = more need, higher = more satisfied)]')
    for _, char in ipairs(test_chars) do
        local breakdown = recondite_helper.get_need_breakdown(char, 'Wrist')
        print(string.format('%s:', char))
        print(string.format('  - Equipped Recondite wrist pieces: %d/2', breakdown.equipped))
        print(string.format('  - %s in inventory: %d', breakdown.remnant_name, breakdown.remnants))
        print(string.format('  - Satisfaction score: %d (equipped + remnants)', breakdown.satisfaction))
    end
    
    -- Determine best recipient
    print('\n[Distribution Decision]')
    local best, score = recondite_helper.find_best_recipient(test_chars, 'Wrist')
    if best then
        print(string.format('✓ Best recipient: %s (score: %d)', best, score))
    else
        print('✗ No valid recipient found')
    end
    
else
    print('✗ Failed to load module: ' .. tostring(recondite_helper))
end

print('\n==============================================================================')
print('TEST COMPLETE')
print('==============================================================================')
print('\nExpected behavior:')
print('- Character with LOWEST score (fewest equipped + fewest remnants) gets the drop')
print('- If both have 2/2 equipped + remnants, they have same score (already satisfied)')
