--[[
    Debug: Discover actual DanNet peer structure and members
]]

local mq = require('mq')

print('==============================================================================')
print('DanNet Peer Structure Investigation')
print('==============================================================================')

print('\n[Step 1] Get DanNet peer and examine it')
print('----------------------------------------------------------------------')

local dannet_peer = mq.TLO.DanNet('Echoveil')
print('DanNet peer: ' .. tostring(dannet_peer))
print('Type: ' .. type(dannet_peer))

-- Try to inspect what members it has
print('\n[Step 2] Check common accessor patterns')
print('----------------------------------------------------------------------')

-- Pattern 1: Try calling it as a function (like TLO members often work)
print('\nPattern 1: Calling dannet_peer()')
local result1 = pcall(function() 
    local r = dannet_peer()
    print('  Result: ' .. tostring(r))
end)
if not result1 then print('  (Not callable)') end

-- Pattern 2: Try bracket notation on the string
print('\nPattern 2: Direct bracket notation')
local result2 = pcall(function()
    local r = mq.TLO['DanNet']['Echoveil']
    print('  Result: ' .. tostring(r))
end)
if not result2 then print('  (Failed)') end

-- Pattern 3: Check if we need to use Me specifically
print('\nPattern 3: Using Me directly from TLO (local control test)')
local me_inventory = mq.TLO.Me.Inventory(9).Name()
print('  Me.Inventory[9].Name(): ' .. tostring(me_inventory))

-- Pattern 4: Try using GetMember or similar
print('\nPattern 4: Checking TLO.DanNet members')
print('  DanNet.Peers: ' .. tostring(mq.TLO.DanNet.Peers()))
print('  DanNet.PeerCount: ' .. tostring(mq.TLO.DanNet.PeerCount()))

-- Pattern 5: Try accessing with parentheses on specific member
print('\nPattern 5: Try DanNet(char).Me()')
local result5 = pcall(function()
    local r = mq.TLO.DanNet('Echoveil').Me()
    print('  DanNet.Me(): ' .. tostring(r))
end)
if not result5 then print('  (Failed)') end

print('\n[Step 3] Trying direct property access patterns')
print('----------------------------------------------------------------------')

-- Pattern 6: Check if the TLO supports direct chaining
print('\nPattern 6: Using full qualifier in macroquest format')
-- In MQ macros, you'd use: ${DanNet[Echoveil].Inventory[9].Name}
-- In Lua MQ, we need to figure out the equivalent

-- Pattern 7: Try using a fully qualified name
print('\nPattern 7: Using server-qualified name')
local fq_peer = mq.TLO.DanNet('bristle_echoveil')
print('  DanNet(bristle_echoveil): ' .. tostring(fq_peer))

print('\n==============================================================================')
