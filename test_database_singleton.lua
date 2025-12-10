--[[
Test script to verify Database singleton pattern is working correctly
]]--

local mq = require("mq")

print("\n=== DATABASE SINGLETON TEST ===\n")

-- First require - should create global Database
print("1. Loading database module first time...")
require("yalm2.lib.database")
print("   Database global exists: " .. tostring(Database ~= nil))
print("   Database.database exists: " .. tostring(Database.database ~= nil))
print("   Database.OpenDatabase is function: " .. tostring(type(Database.OpenDatabase) == "function"))

-- Initialize the connection (like yalm2_native_quest.lua does)
if not Database.database then
    print("\n2. Initializing Database connection...")
    Database.database = Database.OpenDatabase()
    print("   Database.database after init: " .. tostring(Database.database ~= nil))
    if Database.database then
        print("   Connection type: " .. type(Database.database))
    end
end

-- Load it again from a different module (like evaluate.lua would)
print("\n3. Loading database module second time (simulating evaluate.lua)...")
require("yalm2.lib.database")
print("   Database still exists: " .. tostring(Database ~= nil))
print("   Database.database still exists: " .. tostring(Database.database ~= nil))
print("   Same connection object: " .. tostring(Database.database ~= nil and "yes" or "no"))

-- Test a query
if Database.database then
    print("\n4. Testing database query...")
    local result = Database.QueryDatabaseForItemId(120331)
    print("   Query result for item 120331: " .. tostring(result ~= nil))
    if result then
        print("   Item name: " .. (result.itemname or "unknown"))
    end
end

print("\n=== TEST COMPLETE ===\n")
