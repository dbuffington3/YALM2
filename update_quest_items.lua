-- Quick update script for specific quest items
local mq = require("mq")
local sql = require("lsqlite3")
local json = require("yalm2.lib.simple_json")

-- Open database
local db_path = ("%s/MQ2LinkDB.db"):format(mq.TLO.MacroQuest.Path("resources"))
local db = sql.open(db_path)
if not db then
    print("ERROR: Could not open database")
    return
end

print("Connected to database")

-- Function to read Lucy JSON
local function read_lucy_json(item_id)
    local filename = string.format("lucy_item_%s.json", item_id)
    local filepath = "c:/MQ2/lua/yalm2/" .. filename
    
    local file = io.open(filepath, "r")
    if not file then
        print("ERROR: Could not open file " .. filepath)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    local success, data = pcall(json.decode, content)
    if not success then
        print("ERROR: Could not parse JSON")
        return nil
    end
    
    return data
end

-- Function to update questitem field
local function update_questitem(item_id)
    local lucy_data = read_lucy_json(item_id)
    if not lucy_data then
        return false
    end
    
    local questitem_value = lucy_data.questitem or 0
    
    -- Update the database
    local stmt = db:prepare("UPDATE raw_item_data SET questitem = ? WHERE id = ?")
    if not stmt then
        print("ERROR: Could not prepare statement")
        return false
    end
    
    stmt:bind_values(questitem_value, item_id)
    local result = stmt:step()
    local changes = db:changes()
    stmt:finalize()
    
    if result == sql.DONE and changes > 0 then
        print(string.format("✓ Updated item %s: questitem = %s (%d changes)", item_id, questitem_value, changes))
        return true
    else
        print(string.format("✗ Failed to update item %s: result=%s, changes=%d", item_id, tostring(result), changes))
        return false
    end
end

-- Update our test items
print("=== Updating Quest Items ===")
update_questitem(50814)  -- Venom-Tipped Arachnid Fang (should be 0)
update_questitem(17596)  -- Orbweaver Silk (should be 1)

-- Verify the updates
print("\n=== Verification ===")
for row in db:nrows("SELECT id, name, questitem FROM raw_item_data WHERE id IN (50814, 17596)") do
    print(string.format("Item %s (%s): questitem = %s", row.id, row.name, row.questitem))
end

db:close()
print("\n=== Update Complete ===")