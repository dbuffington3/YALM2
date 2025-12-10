-- Batch update script to process all Lucy JSON files and update MQ2LinkDB
local mq = require("mq")
local sql = require("lsqlite3")
local json = require("yalm2.lib.simple_json")

local BatchUpdate = {}

-- Database connection
BatchUpdate.db_path = ("%s/MQ2LinkDB.db"):format(mq.TLO.MacroQuest.Path("resources"))
BatchUpdate.lucy_dir = "c:/MQ2/lua/yalm2/"

function BatchUpdate.get_all_lucy_files()
    local files = {}
    local command = string.format('dir "%s" /B', BatchUpdate.lucy_dir)
    
    -- This would need to be implemented differently in MQ2 environment
    -- For now, we'd need a way to list all lucy_item_*.json files
    
    -- Example file discovery (would need actual implementation)
    -- We could scan for files or have a pre-generated list
    
    return files
end

function BatchUpdate.read_lucy_json(item_id)
    local filename = string.format("lucy_item_%s.json", item_id)
    local filepath = BatchUpdate.lucy_dir .. filename
    
    local file = io.open(filepath, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    local success, data = pcall(json.decode, content)
    if not success then
        return nil
    end
    
    return data
end

function BatchUpdate.update_all_items()
    print("=== Starting Batch Update of All Lucy Items ===")
    
    local db = sql.open(BatchUpdate.db_path)
    if not db then
        print("ERROR: Could not open database")
        return false
    end
    
    -- Start transaction for performance
    db:exec("BEGIN TRANSACTION")
    
    local success_count = 0
    local error_count = 0
    local total_processed = 0
    
    -- We'd need to iterate through all item IDs
    -- This could be done by:
    -- 1. Reading all lucy_item_*.json files from directory
    -- 2. Or having a list of all item IDs to process
    -- 3. Or querying existing database for all IDs to update
    
    local item_ids = {}  -- Would be populated with all available item IDs
    
    for _, item_id in ipairs(item_ids) do
        total_processed = total_processed + 1
        
        if total_processed % 1000 == 0 then
            print(string.format("Processed %d items... (%d success, %d errors)", 
                total_processed, success_count, error_count))
        end
        
        local lucy_data = BatchUpdate.read_lucy_json(item_id)
        if lucy_data then
            local success = BatchUpdate.update_single_item(db, item_id, lucy_data)
            if success then
                success_count = success_count + 1
            else
                error_count = error_count + 1
            end
        else
            error_count = error_count + 1
        end
    end
    
    -- Commit transaction
    db:exec("COMMIT")
    db:close()
    
    print(string.format("=== Batch Update Complete ==="))
    print(string.format("Total processed: %d", total_processed))
    print(string.format("Successful updates: %d", success_count))
    print(string.format("Errors: %d", error_count))
    
    return true
end

function BatchUpdate.update_single_item(db, item_id, lucy_data)
    -- Update questitem field specifically
    local questitem_value = lucy_data.questitem or 0
    
    local stmt = db:prepare("UPDATE raw_item_data SET questitem = ? WHERE id = ?")
    if not stmt then
        return false
    end
    
    stmt:bind_values(questitem_value, item_id)
    local result = stmt:step()
    local changes = db:changes()
    stmt:finalize()
    
    return result == sql.DONE and changes > 0
end

-- For testing, let's create a smaller batch update for specific items
function BatchUpdate.update_quest_items_batch()
    print("=== Updating Known Quest Items ===")
    
    -- List of known quest item IDs we have JSON files for
    local quest_item_ids = {17596}  -- Orbweaver Silk
    -- Could add more: Tanglefang Pelt, etc.
    
    local db = sql.open(BatchUpdate.db_path)
    if not db then
        print("ERROR: Could not open database")
        return false
    end
    
    local updated = 0
    for _, item_id in ipairs(quest_item_ids) do
        local lucy_data = BatchUpdate.read_lucy_json(item_id)
        if lucy_data and BatchUpdate.update_single_item(db, item_id, lucy_data) then
            print(string.format("✓ Updated item %d: questitem=%s", item_id, lucy_data.questitem or 0))
            updated = updated + 1
        else
            print(string.format("✗ Failed to update item %d", item_id))
        end
    end
    
    db:close()
    print(string.format("Updated %d quest items", updated))
end

return BatchUpdate