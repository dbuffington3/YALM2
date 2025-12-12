#!/usr/bin/env lua
-- Direct test of extraction and fuzzy matching without the full system

-- First, let's test if we can load the database module
local successful_loads = {}
local failed_loads = {}

-- Try to load YALM2_Database from the global
if _G.YALM2_Database then
    table.insert(successful_loads, "YALM2_Database from global")
    print(string.format("✓ YALM2_Database loaded from global"))
else
    table.insert(failed_loads, "YALM2_Database from global")
    print(string.format("✗ YALM2_Database NOT in global"))
end

-- Try to load the database module directly
local database = nil
local db_path = "lib/database"
local status, result = pcall(function() 
    return require(db_path)
end)

if status and result then
    database = result
    table.insert(successful_loads, "database module")
    print(string.format("✓ Database module loaded from '%s'", db_path))
else
    table.insert(failed_loads, "database module")
    print(string.format("✗ Database module failed: %s", tostring(result)))
end

-- Try to load quest_interface
local quest_interface = nil
local qi_path = "core/quest_interface"
local status2, result2 = pcall(function() 
    return require(qi_path)
end)

if status2 and result2 then
    quest_interface = result2
    table.insert(successful_loads, "quest_interface module")
    print(string.format("✓ Quest interface module loaded from '%s'", qi_path))
else
    table.insert(failed_loads, "quest_interface module")
    print(string.format("✗ Quest interface module failed: %s", tostring(result2)))
end

print("")
print(string.format("Summary: %d loaded, %d failed", #successful_loads, #failed_loads))

-- Now test the extraction
print("\n=== TESTING EXTRACTION ===")
local test_objectives = {
    "Loot the bone golem's bones",
    "Loot the treants wood",
    "Collect rat fur from rats",
}

-- Load the native quest module to get extraction function
local status3, native_quest = pcall(function()
    return require("yalm2_native_quest")
end)

if status3 and native_quest and native_quest.extract_quest_item_from_objective then
    print("✓ Extract function found in native_quest module")
    for _, objective in ipairs(test_objectives) do
        local extracted = native_quest.extract_quest_item_from_objective(objective)
        print(string.format("  '%s' → '%s'", objective, extracted or "nil"))
    end
else
    print("✗ Could not load extraction function")
    print(string.format("  Status: %s, native_quest: %s", tostring(status3), tostring(native_quest)))
end

print("\n=== TESTING FUZZY MATCHING ===")
if quest_interface and quest_interface.find_matching_quest_item then
    print("✓ Fuzzy matcher function found")
    local test_items = {
        "bone golem's bones",
        "bones",
        "bone golem bones",
    }
    for _, item in ipairs(test_items) do
        local matched = quest_interface.find_matching_quest_item(item)
        print(string.format("  '%s' → '%s'", item, matched or "nil"))
    end
else
    print("✗ Fuzzy matcher function not found")
end
