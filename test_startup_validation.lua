--[[
Native Quest System Startup Validation Test
Tests the comprehensive startup validation to ensure consistent results
Usage: /lua run yalm2\test_startup_validation
]]

local mq = require("mq")

print("=== Native Quest System Startup Validation Test ===")
print("")

-- Test the new startup validation functions directly
local native_tasks = require("yalm2.core.native_tasks")

print("Step 1: Get Expected Group Composition")
local composition = native_tasks.get_expected_group_composition()
print(string.format("  Type: %s", composition.type))
print(string.format("  Members Count: %d", #composition.members))
print(string.format("  Member Names: [%s]", table.concat(composition.names, ", ")))
print("")

print("Step 2: Validate DanNet Connectivity")
local connectivity = native_tasks.validate_dannet_connectivity(composition)
print(string.format("  Expected: %d", #composition.members))
print(string.format("  Connected: %d", connectivity.connected_count))
print(string.format("  Missing: %d", #connectivity.missing))

if #connectivity.missing > 0 then
    print(string.format("  Missing Members: [%s]", table.concat(connectivity.missing, ", ")))
end

print("")
print("Connectivity Details:")
for name, details in pairs(connectivity.details) do
    if details.connected then
        print(string.format("  ✅ %s - %s %s in %s", name, details.level, details.class, details.zone))
    else
        print(string.format("  ❌ %s - %s", name, details.error))
    end
end

print("")
print("=== Validation Results ===")

local success_rate = (connectivity.connected_count / #composition.members) * 100
print(string.format("Success Rate: %.1f%% (%d/%d)", success_rate, connectivity.connected_count, #composition.members))

if success_rate == 100 then
    print("✅ PERFECT - All group/raid members have DanNet connectivity")
    print("✅ Native quest system should work flawlessly")
elseif success_rate >= 80 then
    print("⚠️ GOOD - Most members connected, quest system will work with reduced functionality")
elseif success_rate >= 50 then
    print("⚠️ PARTIAL - Some members missing, quest distribution may be inconsistent")
else
    print("❌ POOR - Many members missing, quest system will have limited functionality")
end

print("")
print("=== Recommendations ===")
if success_rate < 100 then
    print("1. Check DanNet connectivity for missing members:")
    for _, missing_name in ipairs(connectivity.missing) do
        print(string.format("   /dquery %s Me.Name", missing_name))
    end
    print("2. Ensure all group/raid members are running MQ2 with DanNet")
    print("3. Verify network connectivity between characters")
    print("4. Consider restarting MQ2 on disconnected characters")
end

print("")
print("=== Next Steps ===")
print("If results look good, test the full native quest system:")
print("1. /yalm2 nativequest  (enable native system)")
print("2. /lua stop yalm2     (restart YALM2)")  
print("3. /lua run yalm2      (start with validation)")
print("4. Check startup logs for consistent member detection")
print("")
print("The native quest system should now report the same number")
print("of connected members every time it starts!")