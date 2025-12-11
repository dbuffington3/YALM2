--- Quest Task Database Module
--- Stores quest task data in SQLite for inter-script communication
--- Each character updates their own tasks, master looter reads and distributes

local mq = require("mq")
local lfs = require("lfs")
local sql = require("lsqlite3")
local Write = require("yalm2.lib.Write")

local quest_db = {}

-- Database file path
local db_path = mq.configDir .. "/YALM2/quest_tasks.db"

--- Initialize the database and create schema if needed
function quest_db.init()
    -- Ensure directory exists
    local dir = mq.configDir .. "/YALM2"
    if not lfs.attributes(dir, "mode") then
        lfs.mkdir(dir)
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database: %s", db_path)
        return false
    end
    
    -- Create table if it doesn't exist
    local create_sql = [[
        CREATE TABLE IF NOT EXISTS quest_tasks (
            character TEXT NOT NULL,
            task_name TEXT NOT NULL,
            objective TEXT NOT NULL,
            status TEXT NOT NULL,
            item_name TEXT,
            updated_at INTEGER,
            PRIMARY KEY (character, task_name, objective)
        )
    ]]
    
    local result = db:exec(create_sql)
    if result ~= sql.OK then
        Write.Error("[QuestDB] Failed to create table: %s", db:errmsg())
        db:close()
        return false
    end
    
    db:close()
    -- Silent init - no spam messages
    return true
end

--- Store a character's quest tasks in the database
--- Called by yalm2_native_quest when syncing task data
--- @param character_name string - Character name
--- @param tasks table - Array of task objects {task_name, objectives:[{objective, status, item_name}]}
function quest_db.store_character_tasks(character_name, tasks)
    if not character_name or not tasks then
        Write.Error("[QuestDB] Invalid input to store_character_tasks")
        return false
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database")
        return false
    end
    
    local timestamp = mq.gettime()
    local success = true
    
    -- Start transaction
    db:exec("BEGIN TRANSACTION")
    
    -- Delete existing tasks for this character
    local delete_sql = "DELETE FROM quest_tasks WHERE character = ?"
    local stmt = db:prepare(delete_sql)
    if not stmt then
        Write.Error("[QuestDB] Failed to prepare delete statement")
        db:close()
        return false
    end
    
    stmt:bind_values(character_name)
    stmt:step()
    stmt:finalize()
    
    -- Insert new tasks
    local insert_sql = [[
        INSERT INTO quest_tasks (character, task_name, objective, status, item_name, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ]]
    
    local insert_count = 0
    for _, task in ipairs(tasks) do
        if task.objectives then
            for _, obj in ipairs(task.objectives) do
                local stmt = db:prepare(insert_sql)
                if stmt then
                    stmt:bind_values(
                        character_name,
                        task.task_name or "",
                        obj.objective or "",
                        obj.status or "",
                        obj.item_name or "",
                        timestamp
                    )
                    if stmt:step() == sql.DONE then
                        insert_count = insert_count + 1
                    end
                    stmt:finalize()
                end
            end
        end
    end
    
    -- Commit transaction
    db:exec("COMMIT")
    db:close()
    
    Write.Info("[QuestDB] Stored %d tasks for %s", insert_count, character_name)
    return true
end

--- Get all characters who need a specific item
--- Called by native_tasks when distributing loot
--- @param item_name string - Item name to search for
--- @return table - Array of {character, status, task_name, objective}
function quest_db.get_characters_needing_item(item_name)
    if not item_name then
        return {}
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database")
        return {}
    end
    
    local result = {}
    local query = [[
        SELECT character, status, task_name, objective
        FROM quest_tasks
        WHERE item_name = ? AND status NOT LIKE 'Done'
        ORDER BY character
    ]]
    
    local stmt = db:prepare(query)
    if stmt then
        stmt:bind_values(item_name)
        while stmt:step() == sql.ROW do
            table.insert(result, {
                character = stmt:get_value(0),
                status = stmt:get_value(1),
                task_name = stmt:get_value(2),
                objective = stmt:get_value(3)
            })
        end
        stmt:finalize()
    end
    
    db:close()
    
    Write.Debug("[QuestDB] Found %d characters needing %s", #result, item_name)
    return result
end

--- Get all quest items and who needs them
--- Called for debugging or status display
--- @return table - {item_name = [{character, status}, ...], ...}
function quest_db.get_all_quest_items()
    local db = sql.open(db_path)
    if not db then
        return {}
    end
    
    local result = {}
    local query = [[
        SELECT DISTINCT item_name, character, status
        FROM quest_tasks
        WHERE item_name IS NOT NULL AND status NOT LIKE 'Done'
        ORDER BY item_name, character
    ]]
    
    local stmt = db:prepare(query)
    if stmt then
        while stmt:step() == sql.ROW do
            local item = stmt:get_value(0)
            if item and item ~= "" then
                if not result[item] then
                    result[item] = {}
                end
                table.insert(result[item], {
                    character = stmt:get_value(1),
                    status = stmt:get_value(2)
                })
            end
        end
        stmt:finalize()
    end
    
    db:close()
    return result
end

--- Update a character's task status after giving them loot
--- Called by looting.lua after distributing an item
--- @param character_name string - Character name
--- @param item_name string - Item that was given
--- @param new_status string - New status (e.g., "Done" or updated progress like "1/4")
function quest_db.update_character_item_status(character_name, item_name, new_status)
    if not character_name or not item_name or not new_status then
        Write.Error("[QuestDB] Invalid input to update_character_item_status")
        return false
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database")
        return false
    end
    
    local update_sql = [[
        UPDATE quest_tasks
        SET status = ?, updated_at = ?
        WHERE character = ? AND item_name = ?
    ]]
    
    local stmt = db:prepare(update_sql)
    if stmt then
        stmt:bind_values(new_status, mq.gettime(), character_name, item_name)
        stmt:step()
        stmt:finalize()
        Write.Info("[QuestDB] Updated %s's status for %s to %s", character_name, item_name, new_status)
    end
    
    db:close()
    return true
end

--- Clear all tasks (useful for testing or reset)
function quest_db.clear_all()
    local db = sql.open(db_path)
    if not db then
        return false
    end
    
    db:exec("DELETE FROM quest_tasks")
    db:close()
    
    Write.Info("[QuestDB] Cleared all quest tasks")
    return true
end

--- Get debug info about the database
function quest_db.get_status()
    local db = sql.open(db_path)
    if not db then
        return {valid = false, message = "Database not found"}
    end
    
    local count = 0
    local char_count = 0
    local stmt = db:prepare("SELECT COUNT(*) FROM quest_tasks")
    if stmt then
        if stmt:step() == sql.ROW then
            count = stmt:get_value(0) or 0
        end
        stmt:finalize()
    end
    
    stmt = db:prepare("SELECT COUNT(DISTINCT character) FROM quest_tasks")
    if stmt then
        if stmt:step() == sql.ROW then
            char_count = stmt:get_value(0) or 0
        end
        stmt:finalize()
    end
    
    db:close()
    
    return {
        valid = true,
        path = db_path,
        total_tasks = count,
        characters = char_count
    }
end

--- Store quest items from manual refresh (simpler format)
--- Called by yalm2_native_quest during manual refresh
--- @param quest_items table - {item_name = [{character, task_name, objective, status}, ...]}
function quest_db.store_quest_items_from_refresh(quest_items)
    if not quest_items then
        Write.Error("[QuestDB] Invalid input to store_quest_items_from_refresh")
        return false
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database")
        return false
    end
    
    local timestamp = mq.gettime()
    local insert_count = 0
    
    -- Start transaction for efficiency
    db:exec("BEGIN TRANSACTION")
    
    -- MERGE STRATEGY: Only update entries for items currently in active tasks
    -- Keep "Done" entries - they're no longer needed but shouldn't be overwritten
    
    -- First, collect all item names from the current refresh
    local current_items = {}
    for item_name, _ in pairs(quest_items) do
        current_items[item_name] = true
    end
    
    -- Delete only rows for items that are actively being tracked NOW
    -- This preserves "Done" entries for items not in current tasks
    for item_name, _ in pairs(current_items) do
        local delete_sql = "DELETE FROM quest_tasks WHERE item_name = ? AND status != 'Done'"
        local stmt = db:prepare(delete_sql)
        if stmt then
            stmt:bind_values(item_name)
            stmt:step()
            stmt:finalize()
        end
    end
    
    -- Now insert the fresh data for active items
    local insert_sql = [[
        INSERT OR REPLACE INTO quest_tasks (character, task_name, objective, status, item_name, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ]]
    
    -- quest_items format: {item_name = [{character, task_name, objective, status}, ...]}
    for item_name, char_list in pairs(quest_items) do
        for _, item_data in ipairs(char_list) do
            local stmt = db:prepare(insert_sql)
            if stmt then
                stmt:bind_values(
                    item_data.character,
                    item_data.task_name or "",
                    item_data.objective or "",
                    item_data.status or "",
                    item_name,
                    timestamp
                )
                if stmt:step() == sql.DONE then
                    insert_count = insert_count + 1
                end
                stmt:finalize()
            end
        end
    end
    
    -- Commit transaction
    db:exec("COMMIT")
    db:close()
    
    Write.Info("[QuestDB] Stored %d quest item records from refresh (kept Done entries)", insert_count)
    return true
end

--- Increment the quantity received for a character's quest item
--- Called by ML immediately after distributing loot
--- Parses status like "0/2" → "1/2", and "2/2" → "Done"
--- @param character_name string - Character name
--- @param item_name string - Item that was given
--- @return table - {success: boolean, status: string} - Success flag and new status value
function quest_db.increment_quantity_received(character_name, item_name)
    if not character_name or not item_name then
        Write.Error("[QuestDB] Invalid input to increment_quantity_received")
        return { success = false, status = nil }
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database")
        return { success = false, status = nil }
    end
    
    -- First, get the current status
    local query = [[
        SELECT status FROM quest_tasks
        WHERE character = ? AND item_name = ?
        LIMIT 1
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then
        db:close()
        return { success = false, status = nil }
    end
    
    stmt:bind_values(character_name, item_name)
    local current_status = ""
    if stmt:step() == sql.ROW then
        current_status = stmt:get_value(0) or ""
    end
    stmt:finalize()
    
    -- Parse the status string (e.g., "0/2" or "1/3")
    local received, needed = current_status:match("(%d+)/(%d+)")
    
    if not received or not needed then
        -- If status doesn't match the pattern, can't increment
        Write.Error("[QuestDB] Cannot parse status for %s: %s", item_name, current_status)
        db:close()
        return { success = false, status = nil }
    end
    
    received = tonumber(received)
    needed = tonumber(needed)
    
    -- Increment received count
    received = received + 1
    
    -- Determine new status
    local new_status
    if received >= needed then
        new_status = "Done"
    else
        new_status = string.format("%d/%d", received, needed)
    end
    
    -- Update the database
    local update_sql = [[
        UPDATE quest_tasks
        SET status = ?, updated_at = ?
        WHERE character = ? AND item_name = ?
    ]]
    
    stmt = db:prepare(update_sql)
    if stmt then
        stmt:bind_values(new_status, mq.gettime(), character_name, item_name)
        stmt:step()
        stmt:finalize()
    end
    
    db:close()
    
    -- Return table with success and new status so caller can notify UI
    return {
        success = true,
        status = new_status
    }
end

return quest_db
    

