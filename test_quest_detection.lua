-- Test Quest Item Detection
local mq = require("mq")
local Write = require("yalm2.lib.Write")
local database = require("yalm2.lib.database")
local quest_interface = require("yalm2.core.quest_interface")

print("=== QUEST ITEM DETECTION TEST ===")

-- Test if quest interface is working
print("Testing quest interface...")
if quest_interface and quest_interface.get_characters_needing_item then
    print("✅ Quest interface loaded")
    
    -- Test with a known quest item
    local success, chars, task_name, objective = pcall(quest_interface.get_characters_needing_item, "Orbweaver Silk")
    if success then
        if chars and #chars > 0 then
            print(string.format("✅ Orbweaver Silk needed by %d characters: %s", #chars, table.concat(chars, ", ")))
        else
            print("ℹ️  Orbweaver Silk not needed by any characters")
        end
    else
        print("❌ Error calling get_characters_needing_item:", chars)
    end
else
    print("❌ Quest interface not available")
end

print()

-- Test database lookup for a few items
local test_items = {
    "Orbweaver Silk",
    "Missing Journal Page", 
    "Nightmare Ruby",
    "Blighted Blood Sample"
}

print("Testing database lookups...")
for _, item_name in ipairs(test_items) do
    local item_db = database.get_item_by_name(item_name)
    if item_db then
        local is_quest_item = (item_db.norent == 1)
        print(string.format("✅ %s: NoRent=%s, QuestItem=%s", 
            item_name, tostring(item_db.norent), tostring(is_quest_item)))
    else
        print(string.format("❌ %s: Not found in database", item_name))
    end
end

print()

-- Test global quest data
print("Testing global quest data...")
if _G.YALM2_QUEST_DATA then
    print("✅ Global quest data available")
    local item_count = 0
    for item_name, _ in pairs(_G.YALM2_QUEST_DATA.quest_items or {}) do
        item_count = item_count + 1
        print(string.format("  - %s", item_name))
        if item_count >= 5 then
            print("  ... (showing first 5)")
            break
        end
    end
else
    print("❌ Global quest data not available")
end

print("=== TEST COMPLETE ===")