--[[
    DanNet Query Test Script
    Simple script to test querying equipped items and inventory counts
    for remote characters via DanNet
    
    Usage: /lua run test_dannet_recondite.lua
    
    Tests:
    1. Query Malrik's wrist slot items (slots 9, 10)
    2. Query Echoveil's wrist slot items (slots 9, 10)
    3. Query inventory count of "Recondite Remnant of Truth" for both
]]

local mq = require('mq')

-- Character list to test
local test_characters = { 'Malrik', 'Echoveil' }

-- Wrist slot numbers (from check_upgrades.lua)
local WRIST_SLOTS = {
    [9] = 'Left Wrist',
    [10] = 'Right Wrist',
}

-- Item to search for
local ITEM_NAME = 'Recondite Remnant of Truth'

print("=" .. string.rep("=", 78))
print("DanNet Query Test - Recondite Equipment Check")
print("=" .. string.rep("=", 78))

-- ============================================================================
-- Test 1: Query Equipped Items
-- ============================================================================

print("\n[TEST 1] Querying Equipped Wrist Items")
print("-" .. string.rep("-", 78))

for _, char_name in ipairs(test_characters) do
    print(string.format("\nCharacter: %s", char_name))
    print(string.format("  Checking DanNet connectivity...", char_name))
    
    -- Try to query a simple property first to ensure connection
    local connectivity_query = 'Me.Name'
    local connectivity_result = mq.TLO.DanNet(char_name).Query(connectivity_query)()
    
    if connectivity_result and connectivity_result ~= '' then
        print(string.format("    ✓ Connected! (Me.Name = '%s')", connectivity_result))
        
        -- Now query each wrist slot
        for slot_num, slot_name in pairs(WRIST_SLOTS) do
            local query = string.format('Me.Inventory[%d].Name', slot_num)
            local result = mq.TLO.DanNet(char_name).Query(query)()
            
            if result and result ~= '' then
                print(string.format("    Slot %d (%s): %s", slot_num, slot_name, result))
            else
                print(string.format("    Slot %d (%s): [Empty/Unequipped]", slot_num, slot_name))
            end
        end
    else
        print(string.format("    ✗ Failed to connect via DanNet! (Query returned: '%s')", connectivity_result or "nil"))
    end
end

-- ============================================================================
-- Test 2: Query Inventory Item Count
-- ============================================================================

print("\n\n[TEST 2] Querying Inventory Item Count")
print("-" .. string.rep("-", 78))
print(string.format("Searching for: '%s'\n", ITEM_NAME))

for _, char_name in ipairs(test_characters) do
    local query = string.format('Finditemcount[%s]', ITEM_NAME)
    local result = mq.TLO.DanNet(char_name).Query(query)()
    
    print(string.format("Character: %s", char_name))
    
    if result then
        local count = tonumber(result)
        if count and count > 0 then
            print(string.format("  ✓ Found %d item(s)", count))
        elseif count == 0 then
            print(string.format("  ✓ Query successful, but found 0 items (empty/not in inventory)"))
        else
            print(string.format("  ✗ Unexpected result: '%s'", result))
        end
    else
        print(string.format("  ✗ Query returned nil or empty"))
    end
end

-- ============================================================================
-- Test 3: Raw TLO Access (Alternative Method)
-- ============================================================================

print("\n\n[TEST 3] Alternative: Raw TLO Access (non-DanNet reference)")
print("-" .. string.rep("-", 78))
print("Note: This tests local Me.Inventory for current character\n")

local current_char = mq.TLO.Me.Name()
print(string.format("Current character: %s\n", current_char))

for slot_num, slot_name in pairs(WRIST_SLOTS) do
    local query = string.format('Me.Inventory[%d].Name', slot_num)
    local result = mq.TLO.Me.Inventory(slot_num).Name()
    
    if result and result ~= '' then
        print(string.format("Slot %d (%s): %s", slot_num, slot_name, result))
    else
        print(string.format("Slot %d (%s): [Empty/Unequipped]", slot_num, slot_name))
    end
end

-- Test local inventory count
print(string.format("\nInventory count for '%s': ", ITEM_NAME))
local local_count = mq.TLO.FindItemCount(ITEM_NAME)()
if local_count then
    print(string.format("%d item(s)", tonumber(local_count) or 0))
else
    print("Failed to query")
end

-- ============================================================================
-- Summary
-- ============================================================================

print("\n\n" .. "=" .. string.rep("=", 78))
print("TEST COMPLETE")
print("=" .. string.rep("=", 78))
print("\nIf you see item names in Test 1, the equipped item queries are working!")
print("If you see counts in Test 2, the inventory count queries are working!")
print("\nCommon Issues:")
print("  - Empty results may mean no DanNet connection to that character")
print("  - Check that both characters are in the same DanNet group")
print("  - Make sure DanNet plugin is loaded on both characters")
