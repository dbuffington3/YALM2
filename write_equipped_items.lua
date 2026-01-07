--[[
write_equipped_items.lua
Each character runs this script to write their currently equipped items to a shared database table.
This solves the DAN net remote TLO query limitation by having each character locally output their equipment data.

Usage: /lua run write_equipped_items

The script will:
1. Connect to the quest_tasks.db SQLite database
2. Create the 'equipped_items' table if it doesn't exist
3. Iterate through all 23 equipment slots (0-22)
4. Get the item ID from each slot
5. Write/update records with character name, slot, item ID, and item name
6. Exit

This data can then be read by check_cross_character_upgrades.lua via database queries
instead of DAN net remote TLO queries.
]]

mq = require('mq')

-- Database configuration
local db_path = 'C:\\MQ2\\config\\YALM2\\quest_tasks.db'
local sqlite_exe = 'C:\\MQ2\\lua\\yalm2\\sqlite3.exe'

-- Slot mapping from slot number to display name
local slot_names = {
    [0] = "charm",
    [1] = "leftear", 
    [2] = "head",
    [3] = "face",
    [4] = "rightear",
    [5] = "neck",
    [6] = "shoulder",
    [7] = "arms",
    [8] = "back",
    [9] = "leftwrist",
    [10] = "rightwrist",
    [11] = "ranged",
    [12] = "hands",
    [13] = "mainhand",
    [14] = "offhand",
    [15] = "leftfinger",
    [16] = "rightfinger",
    [17] = "chest",
    [18] = "legs",
    [19] = "feet",
    [20] = "waist",
    [21] = "powersource",
    [22] = "ammo"
}

local function create_table()
    --[[
    Create the equipped_items table if it doesn't exist.
    This table stores what each character has equipped in each slot.
    ]]
    local create_sql = [[
        CREATE TABLE IF NOT EXISTS equipped_items (
            character_name TEXT NOT NULL,
            slot_number INTEGER NOT NULL,
            item_id INTEGER,
            item_name TEXT,
            last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (character_name, slot_number)
        );
    ]]
    
    -- Execute the CREATE TABLE command
    local cmd = string.format('"%s" "%s" "%s"', sqlite_exe, db_path, create_sql:gsub('"', '\\"'))
    mq.cmdf('/echo [WriteEquippedItems] Creating table...')
    os.execute(cmd)
end

local function write_equipped_items()
    --[[
    Write all equipped items for the current character to the database.
    Uses a temporary SQL file to avoid long command lines and escaping issues.
    ]]
    local char_name = mq.TLO.Me.CleanName()
    local start_time = os.time()
    mq.cmdf('/echo [WriteEquippedItems] Writing equipped items for %s...', char_name)
    
    -- Build all INSERT statements at once
    local sql_statements = {}
    local read_start = os.time()
    
    -- Iterate through all 23 slots
    for slot = 0, 22 do
        local item = mq.TLO.Me.Inventory(slot)
        local item_id = 0
        local item_name = ""
        
        if item and item() then
            -- Item exists in this slot
            local ok_id, id_result = pcall(function() return item.ID() end)
            if ok_id and id_result then
                item_id = tonumber(id_result) or 0
            end
            
            local ok_name, name_result = pcall(function() return item.Name() end)
            if ok_name and name_result then
                item_name = tostring(name_result)
            end
        end
        
        -- Build the INSERT OR REPLACE command
        local slot_name = slot_names[slot] or "unknown"
        local insert_sql = string.format(
            "INSERT OR REPLACE INTO equipped_items (character_name, slot_number, item_id, item_name, last_updated) VALUES ('%s', %d, %s, '%s', CURRENT_TIMESTAMP);",
            char_name:gsub("'", "''"),  -- Escape single quotes
            slot,
            item_id > 0 and tostring(item_id) or "NULL",
            item_name:gsub("'", "''")   -- Escape single quotes
        )
        
        table.insert(sql_statements, insert_sql)
        
        if item_id > 0 then
            mq.cmdf('/echo [WriteEquippedItems] Slot %d (%s): %d (%s)', slot, slot_name, item_id, item_name)
        else
            mq.cmdf('/echo [WriteEquippedItems] Slot %d (%s): EMPTY', slot, slot_name)
        end
    end
    
    local read_end = os.time()
    mq.cmdf('/echo [WriteEquippedItems] TLO read time: %d seconds', read_end - read_start)
    
    -- Write SQL to a temporary file
    local temp_sql_file = os.tmpname() .. '.sql'
    local sql_file = io.open(temp_sql_file, 'w')
    if not sql_file then
        mq.cmdf('/echo [WriteEquippedItems] ERROR: Could not create temporary SQL file')
        return
    end
    
    sql_file:write(table.concat(sql_statements, '\n'))
    sql_file:close()
    
    -- Execute sqlite3 with the SQL file
    mq.cmdf('/echo [WriteEquippedItems] Executing batch insert...')
    local db_start = os.time()
    local cmd = string.format('"%s" "%s" < "%s"', sqlite_exe, db_path, temp_sql_file)
    os.execute(cmd)
    local db_end = os.time()
    
    mq.cmdf('/echo [WriteEquippedItems] Database write time: %d seconds', db_end - db_start)
    
    -- Clean up temp file
    os.remove(temp_sql_file)
    
    local total_time = os.time() - start_time
    mq.cmdf('/echo [WriteEquippedItems] ✓ Finished in %d seconds total', total_time)
    mq.cmdf('/echo [WriteEquippedItems] ✓ Data written for %s', char_name)
end

-- Main execution
mq.cmdf('/echo [WriteEquippedItems] Starting equipment writer...')
create_table()
write_equipped_items()
mq.cmdf('/echo [WriteEquippedItems] Done! Database updated.')
