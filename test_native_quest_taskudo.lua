--- Test Native Quest System (TaskHUD Architecture)
--- Simple test to verify the new unified approach works

local mq = require("mq")
local Write = require("yalm2.lib.Write")

-- Simulate YALM2 settings
local test_settings = {
    use_native_quest_system = true
}

Write.Info("=== Testing New Native Quest System ===")
Write.Info("Loading native_tasks module...")

local native_tasks = require("yalm2.core.native_tasks")

Write.Info("Initializing native quest system...")
local success = native_tasks.initialize()

if success then
    Write.Info("Native quest system initialized successfully!")
    Write.Info("System status:")
    local status = native_tasks.get_status()
    for key, value in pairs(status) do
        Write.Info("  " .. key .. ": " .. tostring(value))
    end
    
    Write.Info("Waiting 5 seconds for system to collect data...")
    local start_time = mq.gettime()
    while mq.gettime() - start_time < 5000 do
        native_tasks.process()
        mq.delay(100)
    end
    
    Write.Info("Final status:")
    local final_status = native_tasks.get_status()
    for key, value in pairs(final_status) do
        Write.Info("  " .. key .. ": " .. tostring(value))
    end
    
    if final_status.characters_tracked > 0 then
        Write.Info("SUCCESS: System is tracking " .. final_status.characters_tracked .. " characters")
        local characters = native_tasks.get_tracked_characters()
        for i, char in ipairs(characters) do
            Write.Info("  Character " .. i .. ": " .. char)
            local quest_items = native_tasks.get_quest_items_for_character(char)
            local item_count = 0
            for _ in pairs(quest_items) do item_count = item_count + 1 end
            Write.Info("    Quest items: " .. item_count)
        end
    else
        Write.Warn("No characters tracked - communication may have failed")
    end
    
    Write.Info("Shutting down test...")
    native_tasks.shutdown()
else
    Write.Error("Failed to initialize native quest system!")
end

Write.Info("=== Test Complete ===")