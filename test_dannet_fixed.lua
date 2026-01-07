--[[
    Test fixed DanNet query syntax using direct TLO access on peer
    This validates the corrected approach discovered in test_dannet_debug.lua
]]

local mq = require('mq')

print('==============================================================================')
print('Testing Fixed DanNet Query Syntax (Direct TLO Access)')
print('==============================================================================')

-- Test characters
local test_chars = { 'Echoveil', 'Malrik' }

print('\n[Test 1] Query Equipped Items Using Direct Peer Access')
print('----------------------------------------------------------------------')
print('Using syntax: mq.TLO.DanNet(char).Inventory(slot).Name()')

for _, char in ipairs(test_chars) do
    print(string.format('\nCharacter: %s', char))
    
    -- Try accessing the DanNet peer and then its inventory
    local dannet_peer = mq.TLO.DanNet(char)
    
    if dannet_peer then
        print(string.format('  DanNet peer object: %s', tostring(dannet_peer)))
        
        -- Try slot 9 (Left Wrist)
        local slot9_item = dannet_peer.Inventory(9).Name()
        if slot9_item and slot9_item ~= '' then
            print(string.format('  ✓ Slot 9 (Left Wrist): %s', slot9_item))
        else
            print(string.format('  ✗ Slot 9 returned: %s', tostring(slot9_item)))
        end
        
        -- Try slot 10 (Right Wrist)
        local slot10_item = dannet_peer.Inventory(10).Name()
        if slot10_item and slot10_item ~= '' then
            print(string.format('  ✓ Slot 10 (Right Wrist): %s', slot10_item))
        else
            print(string.format('  ✗ Slot 10 returned: %s', tostring(slot10_item)))
        end
    else
        print(string.format('  ✗ Failed to get DanNet peer'))
    end
end

print('\n[Test 2] Query Inventory Count Using Direct Peer Access')
print('----------------------------------------------------------------------')
print('Using syntax: mq.TLO.DanNet(char).Finditemcount(item_name)()')

local search_item = 'Recondite Remnant of Truth'

for _, char in ipairs(test_chars) do
    print(string.format('\nCharacter: %s, Item: %s', char, search_item))
    
    local dannet_peer = mq.TLO.DanNet(char)
    
    if dannet_peer then
        local count = dannet_peer.Finditemcount(search_item)()
        if count and tonumber(count) then
            print(string.format('  ✓ Inventory count: %d', tonumber(count)))
        else
            print(string.format('  ✗ Count returned: %s', tostring(count)))
        end
    else
        print(string.format('  ✗ Failed to get DanNet peer'))
    end
end

print('\n[Test 3] Full Recondite Helper Module Test')
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
    
else
    print('✗ Failed to load module: ' .. tostring(recondite_helper))
end

print('\n==============================================================================')
print('TEST COMPLETE')
print('==============================================================================')
