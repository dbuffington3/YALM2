--[[
DanNet Performance Test - Compare Fast vs Detailed Connectivity Testing
Usage: /lua run yalm2\test_dannet_speed
]]

local mq = require("mq")

print("=== DanNet Performance Comparison Test ===")

-- Test the different timeout modes
local native_tasks = require("yalm2.core.native_tasks")

-- Get expected composition
local composition = native_tasks.get_expected_group_composition()
print(string.format("Testing with %d %s members: [%s]", 
    #composition.members, composition.type, table.concat(composition.names, ", ")))
print("")

-- Test 1: Fast Mode
print("=== Test 1: Fast Mode (250ms timeouts, connectivity only) ===")
local start_time = os.time()
local fast_results = native_tasks.validate_dannet_connectivity(composition, true)
local fast_duration = os.time() - start_time

print(string.format("Fast Mode Results: %d/%d connected in %d seconds", 
    fast_results.connected_count, #composition.members, fast_duration))
print("")

-- Wait a moment between tests
mq.delay(1000)

-- Test 2: Detailed Mode
print("=== Test 2: Detailed Mode (500ms timeouts, full character info) ===")
start_time = os.time()
local detailed_results = native_tasks.validate_dannet_connectivity(composition, false)
local detailed_duration = os.time() - start_time

print(string.format("Detailed Mode Results: %d/%d connected in %d seconds", 
    detailed_results.connected_count, #composition.members, detailed_duration))
print("")

-- Performance comparison
print("=== Performance Comparison ===")
print(string.format("Fast Mode:     %d seconds", fast_duration))
print(string.format("Detailed Mode: %d seconds", detailed_duration))

if fast_duration < detailed_duration then
    local speedup = detailed_duration / math.max(fast_duration, 1)
    print(string.format("Fast mode is %.1fx faster (%.1f%% speed improvement)", 
        speedup, ((detailed_duration - fast_duration) / detailed_duration) * 100))
else
    print("No significant difference in speed")
end

print("")
print("=== Recommendations ===")
if fast_duration <= 5 then
    print("✅ Fast startup performance - good for production use")
else
    print("⚠️ Still slow - may need further timeout optimization")
end

print("Current native quest system uses fast mode for startup")
print("Use detailed mode only for diagnostics (/yalm2 dannetdiag)")