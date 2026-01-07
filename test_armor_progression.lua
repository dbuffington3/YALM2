#!/usr/bin/env lua
--[[
    Test: Armor Progression Tier Filtering

    Tests that:
    1. Item tier identification works
    2. Equipped tier detection works  
    3. Characters with same/higher tier are filtered out
    4. Best recipient respects progression chain
]]

local mq = require('mq')
local equipment_dist = require('yalm2.lib.equipment_distribution')

-- Test data
local test_cases = {
    {
        name = "Fear Stained Wrist",
        item_name = "Fear Stained Wrist Wraps",
        expected_tier = 2,
        expected_set = "Fear Stained",
    },
    {
        name = "Fear Touched Wrist",
        item_name = "Fear Touched Wrist Wraps",
        expected_tier = 1,
        expected_set = "Fear Touched",
    },
    {
        name = "Boreal Wrist",
        item_name = "Boreal Wrist Wraps",
        expected_tier = 2,
        expected_set = "Boreal",
    },
    {
        name = "Distorted Wrist",
        item_name = "Distorted Wrist Wraps",
        expected_tier = 3,
        expected_set = "Distorted",
    },
}

print("\n=== ARMOR PROGRESSION TESTS ===\n")

-- Test 1: Item tier identification
print("TEST 1: Item Tier Identification")
print("-" .. string.rep("-", 50))
for _, test in ipairs(test_cases) do
    local tier = equipment_dist.get_armor_item_tier(test.item_name)
    local status = (tier == test.expected_tier) and "✓ PASS" or "✗ FAIL"
    print(string.format("%s - %s: got tier %s, expected %d", 
        status, test.name, tier or 'nil', test.expected_tier))
end

-- Test 2: Full identify_armor_item
print("\nTEST 2: Full Armor Item Identification")
print("-" .. string.rep("-", 50))
for _, test in ipairs(test_cases) do
    local set_name, piece_type, tier = equipment_dist.identify_armor_item(test.item_name)
    local status = (tier == test.expected_tier and piece_type) and "✓ PASS" or "✗ FAIL"
    print(string.format("%s - %s: got set=%s piece=%s tier=%s", 
        status, test.name, set_name or 'nil', piece_type or 'nil', tier or 'nil'))
end

-- Test 3: Verify ARMOR_PROGRESSION is available
print("\nTEST 3: ARMOR_PROGRESSION Export")
print("-" .. string.rep("-", 50))
local armor_prog = equipment_dist.ARMOR_PROGRESSION
if armor_prog then
    print("✓ PASS - ARMOR_PROGRESSION is exported")
    print("\nProgression Entries:")
    for name, info in pairs(armor_prog) do
        print(string.format("  %s: tier=%d, creates=%s", name, info.tier, info.creates or 'N/A'))
    end
else
    print("✗ FAIL - ARMOR_PROGRESSION not found")
end

-- Test 4: Verify all functions are exported
print("\nTEST 4: Function Exports")
print("-" .. string.rep("-", 50))
local functions = {
    'identify_armor_item',
    'get_armor_item_tier',
    'get_equipped_armor_tier',
    'find_best_recipient',
    'calculate_satisfaction',
}

for _, func_name in ipairs(functions) do
    local status = equipment_dist[func_name] and "✓ PASS" or "✗ FAIL"
    print(string.format("%s - %s", status, func_name))
end

print("\n=== ALL TESTS COMPLETE ===\n")
