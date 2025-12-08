--- Comprehensive Test for TaskHUD-Style Native Quest System
--- Tests the complete flow: coordinator → data collection → YALM2 integration

local mq = require("mq") 
local Write = require("yalm2.lib.Write")

Write.Info("=== COMPREHENSIVE NATIVE QUEST TEST ===")

-- Test 1: Module Loading
Write.Info("Test 1: Loading native_tasks module...")
local native_tasks = require("yalm2.core.native_tasks")
Write.Info("✓ Module loaded successfully")

-- Test 2: System Initialization 
Write.Info("Test 2: Initializing native quest system...")
local init_success = native_tasks.initialize()
if init_success then
    Write.Info("✓ System initialization returned success")
else
    Write.Error("✗ System initialization failed")
    return
end

-- Wait for coordinator to start
Write.Info("Waiting 3 seconds for coordinator startup...")
mq.delay(3000)

-- Test 3: Check if coordinator script is running
Write.Info("Test 3: Checking coordinator status...")
-- We can't easily check if the script is running from here, but we can check responses

-- Test 4: Initial Status Check
Write.Info("Test 4: Getting initial system status...")
local status = native_tasks.get_status()
Write.Info("Initial Status:")
for key, value in pairs(status) do
    Write.Info("  " .. key .. ": " .. tostring(value))
end

-- Test 5: Force Data Collection
Write.Info("Test 5: Forcing immediate data collection...")
native_tasks.refresh_all_characters()

-- Test 6: Process Loop Simulation
Write.Info("Test 6: Simulating YALM2 main loop processing...")
local test_start = mq.gettime()
local max_wait = 15000  -- 15 seconds max

while (mq.gettime() - test_start) < max_wait do
    native_tasks.process()
    mq.delay(500)
    
    -- Check if we have data yet
    local current_status = native_tasks.get_status()
    if current_status.characters_tracked > 0 then
        Write.Info("✓ Characters detected after " .. (mq.gettime() - test_start) .. "ms")
        break
    end
    
    Write.Info("Waiting for character data... (" .. (mq.gettime() - test_start) .. "ms)")
end

-- Test 7: Final Status and Data Analysis
Write.Info("Test 7: Final system analysis...")
local final_status = native_tasks.get_status()
Write.Info("Final Status:")
for key, value in pairs(final_status) do
    Write.Info("  " .. key .. ": " .. tostring(value))
end

if final_status.characters_tracked > 0 then
    Write.Info("✓ SUCCESS: System is tracking characters!")
    
    -- Test character data
    local characters = native_tasks.get_tracked_characters()
    Write.Info("Tracked Characters:")
    for i, char in ipairs(characters) do
        Write.Info("  " .. i .. ". " .. char)
        
        -- Test quest item extraction
        local quest_items = native_tasks.get_quest_items_for_character(char)
        local item_count = 0
        for item_name, item_info in pairs(quest_items) do
            item_count = item_count + 1
            if item_count <= 3 then  -- Show first 3 items
                Write.Info("    Quest Item: " .. item_name)
                Write.Info("      Task: " .. item_info.task_name)
                Write.Info("      Status: " .. item_info.status)
            end
        end
        Write.Info("    Total Quest Items: " .. item_count)
    end
    
    -- Test item lookup function
    local all_quest_items = native_tasks.get_all_quest_items()
    total_unique_items = 0
    for _ in pairs(all_quest_items) do total_unique_items = total_unique_items + 1 end
    Write.Info("Total Unique Quest Items Across All Characters: " .. total_unique_items)
    
    -- Test item needed function with a sample
    if total_unique_items > 0 then
        local sample_item = next(all_quest_items)
        local is_needed = native_tasks.is_item_needed_for_quest(sample_item)
        Write.Info("Sample Item '" .. sample_item .. "' needed: " .. tostring(is_needed))
    end
    
else
    total_unique_items = 0
    Write.Warn("No characters tracked - possible communication issues")
    Write.Info("Troubleshooting info:")
    Write.Info("  - Check if other characters are in group/raid")  
    Write.Info("  - Verify DanNet connectivity")
    Write.Info("  - Check if /yalm2quest command works manually")
end

-- Test 8: System Activity Check
Write.Info("Test 8: System activity verification...")
local is_active = native_tasks.is_active()
Write.Info("System active: " .. tostring(is_active))

if is_active then
    Write.Info("✓ System is fully operational!")
else
    Write.Warn("System not considered active - check data freshness")
end

-- Test 9: Cleanup
Write.Info("Test 9: System cleanup...")
native_tasks.shutdown()
Write.Info("✓ System shutdown completed")

Write.Info("=== TEST COMPLETE ===")
Write.Info("Summary:")
Write.Info("  - Module integration: ✓")
Write.Info("  - System initialization: " .. (init_success and "✓" or "✗"))
Write.Info("  - Character detection: " .. (final_status.characters_tracked > 0 and "✓" or "✗"))
Write.Info("  - Data processing: " .. (is_active and "✓" or "?"))
Write.Info("  - Quest item extraction: " .. (total_unique_items and total_unique_items > 0 and "✓" or "?"))

if final_status.characters_tracked > 0 and is_active then
    Write.Info("🎉 OVERALL RESULT: SUCCESS - Native quest system is working!")
else
    Write.Warn("⚠️  OVERALL RESULT: PARTIAL - Some issues detected, see details above")
end