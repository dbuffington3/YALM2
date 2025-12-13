--- Quest Task Database Module
--- Stores quest task data in SQLite for inter-script communication
--- Each character updates their own tasks, master looter reads and distributes

local mq = require("mq")
local lfs = require("lfs")
local sql = require("lsqlite3")
local Write = require("yalm2.lib.Write")
local debug_logger = require("yalm2.lib.debug_logger")

local quest_db = {}

-- Database file path
local db_path = mq.configDir .. "/YALM2/quest_tasks.db"
local db_handle = nil  -- Keep persistent connection

--- Get or create the database connection
local function get_db()
    if db_handle then
        return db_handle
    end
    
    -- Ensure directory exists
    local dir = mq.configDir .. "/YALM2"
    if not lfs.attributes(dir, "mode") then
        lfs.mkdir(dir)
    end
    
    local db = sql.open(db_path)
    if not db then
        Write.Error("[QuestDB] Failed to open database: %s", db_path)
        return nil
    end
    
    -- Set pragmas for safety and performance
    db:exec("PRAGMA journal_mode = DELETE")  -- Use DELETE instead of WAL for better Windows compatibility
    db:exec("PRAGMA synchronous = NORMAL")
    db:exec("PRAGMA cache_size = 10000")
    
    -- Create quest_tasks table (stores task data with status per character)
    local create_tasks_sql = [[
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
    
    local result = db:exec(create_tasks_sql)
    if result ~= sql.OK then
        Write.Error("[QuestDB] Failed to create quest_tasks table: %s", db:errmsg())
        db:close()
        return nil
    end
    
    -- Create quest_objectives table (stores static objective data with matched items)
    -- This table is populated once per unique objective and never changes
    local create_objectives_sql = [[
        CREATE TABLE IF NOT EXISTS quest_objectives (
            objective TEXT PRIMARY KEY,
            task_name TEXT NOT NULL,
            item_name TEXT,
            matched_at INTEGER,
            created_at INTEGER
        )
    ]]
    
    result = db:exec(create_objectives_sql)
    if result ~= sql.OK then
        Write.Error("[QuestDB] Failed to create quest_objectives table: %s", db:errmsg())
        db:close()
        return nil
    end
    
    db_handle = db
    return db_handle
end

--- Initialize the database and create schema if needed
function quest_db.init()
    return get_db() ~= nil
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
    
    local db = get_db()
    if not db then
        Write.Error("[QuestDB] Failed to get database connection")
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
        db:exec("ROLLBACK")
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
    
    local db = get_db()
    if not db then
        Write.Error("[QuestDB] Failed to get database connection")
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
    
    Write.Debug("[QuestDB] Found %d characters needing %s", #result, item_name)
    return result
end

--- Get all quest items and who needs them
--- Called for debugging or status display
--- @return table - {item_name = [{character, status}, ...], ...}
function quest_db.get_all_quest_items()
    local db = get_db()
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
    
    return result
end

--- Get all quest items with enriched data from quest_objectives
--- Joins quest_tasks (status data) with quest_objectives (objective text) for enhanced UI display
--- @return table - Enhanced quest_items {item_name = {character, status, objective}, ...}
function quest_db.get_all_quest_items_with_objectives()
    local db = get_db()
    if not db then
        return {}
    end
    
    local result = {}
    -- Join quest_tasks with quest_objectives to get both status and objective text
    -- This gives us complete information for the UI to display
    local query = [[
        SELECT DISTINCT 
            qt.item_name, 
            qt.character, 
            qt.status,
            qo.objective
        FROM quest_tasks qt
        LEFT JOIN quest_objectives qo ON qt.item_name = qo.item_name
        WHERE qt.item_name IS NOT NULL AND qt.status NOT LIKE 'Done'
        ORDER BY qt.item_name, qt.character
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
                    status = stmt:get_value(2),
                    objective = stmt:get_value(3)  -- Can be nil if objective not cached yet
                })
            end
        end
        stmt:finalize()
    end
    
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
    
    local db = get_db()
    if not db then
        Write.Error("[QuestDB] Failed to get database connection")
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
    
    return true
end

--- Clear all tasks (useful for testing or reset)
function quest_db.clear_all()
    local db = get_db()
    if not db then
        return false
    end
    
    db:exec("DELETE FROM quest_tasks")
    
    Write.Info("[QuestDB] Cleared all quest tasks")
    return true
end

--- Clear the quest_objectives fuzzy match cache to force re-matching
--- Called at startup to ensure fresh fuzzy matching with latest code
function quest_db.clear_objective_cache()
    local db = get_db()
    if not db then
        return false
    end
    
    db:exec("DELETE FROM quest_objectives")
    
    Write.Debug("[QuestDB] Cleared quest objectives cache for fresh matching")
    return true
end

--- Get debug info about the database
function quest_db.get_status()
    local db = get_db()
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
    
    local db = get_db()
    if not db then
        Write.Error("[QuestDB] Failed to get database connection")
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
    local commit_result = db:exec("COMMIT")
    
    -- Force sync to ensure data is written to disk
    db:exec("PRAGMA synchronous = FULL")
    db:exec("PRAGMA optimize")
    
    debug_logger.quest("[QuestDB] Stored %d quest item records from refresh (kept Done entries)", insert_count)
    return true
end

--- Increment the quantity received for a character's quest item
--- Called by ML immediately after distributing loot
--- Parses status like "0/2" → "1/2", and "2/2" → "Done"
--- @param character_name string - Character name
--- @param item_name string - Item that was given
--- @return boolean - Success
function quest_db.increment_quantity_received(character_name, item_name)
    if not character_name or not item_name then
        Write.Error("[QuestDB] Invalid input to increment_quantity_received")
        return false
    end
    
    local db = get_db()
    if not db then
        Write.Error("[QuestDB] Failed to get database connection")
        return false
    end
    
    -- First, get the current status
    local query = [[
        SELECT status FROM quest_tasks
        WHERE character = ? AND item_name = ?
        LIMIT 1
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then
        return false
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
        return false
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
    
    -- Silent update - no spam messages
    return true
end

--- Check if we've already matched this objective to an item
--- Returns the previously matched item name if found, nil if not in database
--- @param character_name string - Character name
--- @param objective_text string - The objective text
--- @return string|nil - The cached matched item name, or nil if not found
function quest_db.get_cached_item_match(character_name, objective_text)
    if not character_name or not objective_text then
        return nil
    end
    
    local db = get_db()
    if not db then
        return nil
    end
    
    -- Query to find this objective for this character
    local query = [[
        SELECT item_name FROM quest_tasks 
        WHERE character = ? AND objective = ? AND item_name IS NOT NULL AND item_name != ''
        LIMIT 1
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then
        return nil
    end
    
    stmt:bind_values(character_name, objective_text)
    local result = nil
    
    if stmt:step() == sql.ROW then
        result = stmt:get_values()[1]
    end
    
    stmt:finalize()
    return result
end

--- Store a matched objective item for future reference
--- Called after fuzzy matching succeeds to avoid re-matching
--- @param character_name string - Character name
--- @param task_name string - Task name
--- @param objective_text string - The objective text
--- @param matched_item_name string - The matched item name from fuzzy matching
--- @return boolean - True if successful
function quest_db.store_matched_item(character_name, task_name, objective_text, matched_item_name)
    if not character_name or not objective_text or not matched_item_name then
        return false
    end
    
    local db = get_db()
    if not db then
        return false
    end
    
    -- Update or insert
    local update_sql = [[
        UPDATE quest_tasks 
        SET item_name = ?, updated_at = ?
        WHERE character = ? AND objective = ? AND task_name = ?
    ]]
    
    local stmt = db:prepare(update_sql)
    if stmt then
        stmt:bind_values(matched_item_name, mq.gettime(), character_name, objective_text, task_name or "")
        stmt:step()
        stmt:finalize()
    end
    
    return true
end

--- Check if an objective already exists in the quest_objectives table
--- @param objective_text string - The objective text
--- @return table|nil - {task_name, item_name, matched_at} if found, nil if not
function quest_db.get_objective(objective_text)
    if not objective_text then
        return nil
    end
    
    local db = get_db()
    if not db then
        return nil
    end
    
    local query = [[
        SELECT task_name, item_name, matched_at FROM quest_objectives WHERE objective = ?
    ]]
    
    local stmt = db:prepare(query)
    if not stmt then
        return nil
    end
    
    stmt:bind_values(objective_text)
    local result = nil
    
    if stmt:step() == sql.ROW then
        local row = stmt:get_values()
        result = {
            task_name = row[1],
            item_name = row[2],
            matched_at = row[3]
        }
    end
    
    stmt:finalize()
    return result
end

--- Store a new objective with its matched item name
--- Called when we encounter a new objective for the first time
--- @param objective_text string - The objective text
--- @param task_name string - The task name
--- @param item_name string - The matched item name (result of fuzzy matching)
--- @return boolean - True if successful
function quest_db.store_objective(objective_text, task_name, item_name)
    if not objective_text or not task_name or not item_name then
        return false
    end
    
    local db = get_db()
    if not db then
        return false
    end
    
    local now = mq.gettime()
    local insert_sql = [[
        INSERT OR REPLACE INTO quest_objectives (objective, task_name, item_name, matched_at, created_at)
        VALUES (?, ?, ?, ?, ?)
    ]]
    
    local stmt = db:prepare(insert_sql)
    if stmt then
        stmt:bind_values(objective_text, task_name, item_name, now, now)
        local result = stmt:step()
        stmt:finalize()
        return result == sql.DONE
    end
    
    return false
end

--- Get all cached objectives as a map for efficient lookups
--- Used for efficient refresh - check which objectives are already cached
--- @return table - Map of objective -> {task_name, item_name}
function quest_db.get_all_cached_objectives()
    local db = get_db()
    if not db then
        return {}
    end
    
    local cached_map = {}
    local query = "SELECT objective, task_name, item_name FROM quest_objectives"
    
    for row in db:nrows(query) do
        cached_map[row.objective] = {
            task_name = row.task_name,
            item_name = row.item_name
        }
    end
    
    return cached_map
end

--- Build quest_items directly from cached objectives and character task data
--- OPTIMIZATION: Skip fuzzy matching entirely - use cached item names only
--- Used by efficient refresh to populate quest_items with zero fuzzy matching
--- @param task_data table - Character tasks {character = {objectives...}}
--- @param cached_objectives table - Map from get_all_cached_objectives()
--- @return table - quest_items structure ready for storage
function quest_db.build_quest_items_from_cached_objectives(task_data, cached_objectives)
    if not task_data or not cached_objectives then
        return {}
    end
    
    local quest_items = {}
    
    -- Process all tasks using ONLY cached objective data
    for character_name, tasks in pairs(task_data) do
        for _, task in ipairs(tasks) do
            if task.objectives then
                for _, objective in ipairs(task.objectives) do
                    if objective and objective.objective then
                        -- EFFICIENCY: Check ONLY the cache, no extraction or fuzzy matching
                        local cached_data = cached_objectives[objective.objective]
                        if cached_data then
                            local item_name = cached_data.item_name
                            
                            -- Add to quest items (same logic as normal refresh)
                            if not quest_items[item_name] then
                                quest_items[item_name] = {}
                            end
                            
                            local already_added = false
                            for _, existing in ipairs(quest_items[item_name]) do
                                if existing.character == character_name then
                                    already_added = true
                                    break
                                end
                            end
                            
                            if not already_added then
                                table.insert(quest_items[item_name], {
                                    character = character_name,
                                    task_name = task.task_name,
                                    objective = objective.objective,
                                    status = objective.status
                                })
                            end
                        end
                        -- CRITICAL: Objectives NOT in cache are SKIPPED entirely
                        -- They will be added on next full refresh when someone completes them
                    end
                end
            end
        end
    end
    
    return quest_items
end

return quest_db
    

