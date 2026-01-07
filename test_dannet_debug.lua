--[[
    DanNet Syntax Debug Script
    Tests different ways to call DanNet queries to find the correct syntax
    
    Usage: /lua run yalm2/test_dannet_debug.lua
]]

local mq = require('mq')

print("\n" .. string.rep("=", 80))
print("DanNet Syntax Debug - Testing Different Query Methods")
print(string.rep("=", 80) .. "\n")

-- Test 1: Check current DanNet peers
print("[Test 1] Available DanNet Peers")
print("-" .. string.rep("-", 78))
local peers = mq.TLO.DanNet.Peers()
print(string.format("Peers string: '%s'", peers or "nil"))

local peer_count = mq.TLO.DanNet.PeerCount()
print(string.format("Peer count: %s\n", peer_count or "nil"))

-- Test 2: Try different ways to access a character
print("[Test 2] Testing Different Query Access Methods")
print("-" .. string.rep("-", 78))

local test_char = 'Malrik'

-- Method 1: Using Query with string index
print(string.format("Method 1 - DanNet[%s].Query('Me.Name'):", test_char))
local result1 = mq.TLO.DanNet(test_char).Query('Me.Name')()
print(string.format("  Result: '%s'\n", result1 or "nil"))

-- Method 2: Using O (Observe) accessor instead
print(string.format("Method 2 - DanNet[%s].Observe('Me.Name'):", test_char))
local result2 = mq.TLO.DanNet(test_char).Observe('Me.Name')()
print(string.format("  Result: '%s'\n", result2 or "nil"))

-- Method 3: Direct character accessor without Query function
print(string.format("Method 3 - Direct DanNet character access:"))
local dannet_char = mq.TLO.DanNet(test_char)
print(string.format("  DanNet[%s]: %s", test_char, dannet_char))
if dannet_char then
    print(string.format("  Trying .Query member: %s", dannet_char.Query or "not available"))
    local q_result = dannet_char.Query('Me.Name')
    print(string.format("  Result: '%s'\n", q_result or "nil"))
end

-- Test 3: Test with bracket notation
print("[Test 3] Testing Different Bracket Notations")
print("-" .. string.rep("-", 78))

-- Try with brackets
print("Trying: mq.TLO.DanNet['Malrik'].Query('Me.Name')")
local result3 = mq.TLO.DanNet['Malrik'].Query('Me.Name')()
print(string.format("  Result: '%s'\n", result3 or "nil"))

-- Test 4: Check if character name needs server prefix
print("[Test 4] Testing with Server Prefix")
print("-" .. string.rep("-", 78))
local current_server = mq.TLO.EverQuest.Server()
print(string.format("Current server: '%s'", current_server or "nil"))

if current_server then
    local full_name = current_server .. '_Malrik'
    print(string.format("Trying with full name: %s", full_name))
    local result4 = mq.TLO.DanNet(full_name).Query('Me.Name')()
    print(string.format("  Result: '%s'\n", result4 or "nil"))
end

-- Test 5: Simple echo test (control)
print("[Test 5] Control Test - Local Me.Name")
print("-" .. string.rep("-", 78))
local local_name = mq.TLO.Me.Name()
print(string.format("Local Me.Name: '%s'\n", local_name or "nil"))

print(string.rep("=", 80))
print("DEBUG COMPLETE")
print(string.rep("=", 80) .. "\n")
