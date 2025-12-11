#!/usr/bin/env lua
--- QUICK_GLOBAL_TEST.lua
--- Quick test to check if quest globals have values

local should_continue = true

-- Quick check of the globals
local function check_globals()
    print("\n=== QUEST GLOBALS CHECK ===")
    print(string.format("_G.YALM2_QUEST_DATA exists: %s", tostring(_G.YALM2_QUEST_DATA ~= nil)))
    if _G.YALM2_QUEST_DATA then
        print(string.format("  .quest_items: %s", tostring(_G.YALM2_QUEST_DATA.quest_items ~= nil)))
        if _G.YALM2_QUEST_DATA.quest_items then
            local count = 0
            for _ in pairs(_G.YALM2_QUEST_DATA.quest_items) do count = count + 1 end
            print(string.format("  Item count: %d", count))
        end
    end
    
    local qty_val = _G.YALM2_QUEST_ITEMS_WITH_QTY or ""
    print(string.format("_G.YALM2_QUEST_ITEMS_WITH_QTY: %s (len=%d)", 
        qty_val:len() > 0 and "POPULATED" or "EMPTY", 
        qty_val:len()))
    if qty_val:len() > 0 then
        print(string.format("  Value (first 100 chars): %s", qty_val:sub(1, 100)))
    end
    print("===========================\n")
end

-- Hook into looting to see values when items drop
local function hook_looting()
    -- This will be called periodically
    check_globals()
end

print("QUICK_GLOBAL_TEST: Started. Press /lua stop QUICK_GLOBAL_TEST to exit.")
print("Check console output above for global variable status.")

-- Call it once immediately
check_globals()

-- Then every 2 seconds
while should_continue do
    local mq = require("mq")
    mq.delay(2000)
    check_globals()
end

print("QUICK_GLOBAL_TEST: Stopped")
