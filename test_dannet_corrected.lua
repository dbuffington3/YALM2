--[[
    Test corrected DanNet query syntax using dannet.query() function
    This uses the existing dannet module that's used throughout YALM2
]]

local mq = require('mq')
local dannet = require('yalm2.lib.dannet')

print('==============================================================================')
print('Testing DanNet Queries Using dannet.query() Function')
print('==============================================================================')

-- Test characters
local test_chars = { 'Echoveil', 'Malrik' }

print('\n[Test 1] Query Equipped Items Using dannet.query()')
print('----------------------------------------------------------------------')
print('Using syntax: dannet.query(char, "Me.Inventory[slot].Name", timeout)')

for _, char in ipairs(test_chars) do
    print(string.format('\nCharacter: %s', char))
    
    -- Try slot 9 (Left Wrist)
    local slot9_item = dannet.query(char, 'Me.Inventory[9].Name', 100)
    if slot9_item and slot9_item ~= '' then
        print(string.format('  ✓ Slot 9 (Left Wrist): %s', slot9_item))
    else
        print(string.format('  ✗ Slot 9 returned: %s', tostring(slot9_item)))
    end
    
    -- Try slot 10 (Right Wrist)
    local slot10_item = dannet.query(char, 'Me.Inventory[10].Name', 100)
    if slot10_item and slot10_item ~= '' then
        print(string.format('  ✓ Slot 10 (Right Wrist): %s', slot10_item))
    else
        print(string.format('  ✗ Slot 10 returned: %s', tostring(slot10_item)))
    end
end

print('\n[Test 2] Query Inventory Count Using dannet.query()')
print('----------------------------------------------------------------------')
print('Using syntax: dannet.query(char, "Finditemcount[item_name]", timeout)')

local search_item = 'Recondite Remnant of Truth'

for _, char in ipairs(test_chars) do
    print(string.format('\nCharacter: %s, Item: %s', char, search_item))
    
    local count = dannet.query(char, string.format('Finditemcount[%s]', search_item), 100)
    if count and tonumber(count) then
        print(string.format('  ✓ Inventory count: %d', tonumber(count)))
    else
        print(string.format('  ✗ Count returned: %s', tostring(count)))
    end
end

print('\n[Test 3] Load and Test Recondite Helper Module')
print('----------------------------------------------------------------------')
print('Testing: require(\'yalm2.lib.recondite_helper\')')

local success, recondite_helper = pcall(require, 'yalm2.lib.recondite_helper')

if success then
    print('✓ Module loaded successfully')
    
    -- Test calculate_need for each character
    for _, char in ipairs(test_chars) do
        local need = recondite_helper.calculate_need(char, 'Wrist')
        print(string.format('  %s wrist need: %d (0=satisfied, 2=max need)', char, need))
    end
    
    -- Test find_best_recipient
    local best = recondite_helper.find_best_recipient(test_chars, 'Wrist')
    print(string.format('\nBest recipient for wrist armor: %s', best or 'NONE'))
    
    -- Show detailed breakdown for each character
    print('\n[Test 4] Detailed Need Breakdown')
    print('----------------------------------------------------------------------')
    for _, char in ipairs(test_chars) do
        local breakdown = recondite_helper.get_need_breakdown(char, 'Wrist')
        print(string.format('%s:', char))
        print(string.format('  - Equipped Recondite pieces: %d', breakdown.equipped_count))
        print(string.format('  - Inventory items: %d', breakdown.inventory_count))
        print(string.format('  - Final need: %d', breakdown.final_need))
    end
    
else
    print('✗ Failed to load module: ' .. tostring(recondite_helper))
end

print('\n==============================================================================')
print('TEST COMPLETE')
print('==============================================================================')
