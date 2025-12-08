--[[
Test Native Quest System Setting Save/Load
Verifies that the nativequest toggle properly saves and persists
Usage: /lua run yalm2\test_setting_persistence
]]

local mq = require("mq")
local settings = require("yalm2.config.settings")

print("=== Native Quest System Setting Persistence Test ===")

-- Load current settings
local global_settings, char_settings = settings.init_settings()

print(string.format("Current setting: use_native_quest_system = %s", 
    tostring(global_settings.settings.use_native_quest_system)))

-- Test the toggle and save functionality
local old_value = global_settings.settings.use_native_quest_system
local new_value = not old_value

print(string.format("Testing toggle: %s -> %s", tostring(old_value), tostring(new_value)))

-- Apply the change
global_settings.settings.use_native_quest_system = new_value

-- Save it
print("Saving setting...")
settings.save_global_settings(settings.get_global_settings_filename(), global_settings)

-- Reload settings to verify persistence
print("Reloading settings to verify save...")
local reloaded_global_settings, _ = settings.init_settings()

print(string.format("Reloaded setting: use_native_quest_system = %s", 
    tostring(reloaded_global_settings.settings.use_native_quest_system)))

-- Verify the change persisted
if reloaded_global_settings.settings.use_native_quest_system == new_value then
    print("✅ SUCCESS: Setting was saved and persisted correctly!")
else
    print("❌ FAILED: Setting was not saved properly")
end

-- Restore original setting
print("Restoring original setting...")
global_settings.settings.use_native_quest_system = old_value
settings.save_global_settings(settings.get_global_settings_filename(), global_settings)

print(string.format("Restored to original value: %s", tostring(old_value)))

print("")
print("=== Test Complete ===")
print("The /yalm2 nativequest command should now save settings properly!")
print("Try: /yalm2 nativequest -> restart YALM2 -> check if native system is used")