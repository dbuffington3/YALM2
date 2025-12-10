--- Script to update MQ2LinkDB database with Lucy data
--- Starting with single item proof of concept

local mq = require("mq")
local sql = require("lsqlite3")
local json = require("yalm2.lib.simple_json")

local UpdateLinkDB = {}

-- Database connection
UpdateLinkDB.db_path = ("%s/MQ2LinkDB.db"):format(mq.TLO.MacroQuest.Path("resources"))

--- Open database connection
function UpdateLinkDB.open_database()
    local db = sql.open(UpdateLinkDB.db_path)
    if not db then
        print("ERROR: Could not open database at " .. UpdateLinkDB.db_path)
        return nil
    end
    print("Connected to database: " .. UpdateLinkDB.db_path)
    return db
end

--- Read Lucy JSON file
function UpdateLinkDB.read_lucy_json(item_id)
    local filename = string.format("lucy_item_%s.json", item_id)
    local filepath = "c:/MQ2/lua/yalm2/" .. filename
    
    local file = io.open(filepath, "r")
    if not file then
        print("ERROR: Could not open file " .. filepath)
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Parse JSON
    local success, data = pcall(json.decode, content)
    if not success then
        print("ERROR: Could not parse JSON from " .. filepath)
        return nil
    end
    
    print("Successfully read Lucy data for item " .. item_id)
    return data
end

--- Get current table columns
function UpdateLinkDB.get_table_columns(db, table_name)
    local columns = {}
    
    local stmt = db:prepare("PRAGMA table_info(" .. table_name .. ")")
    if not stmt then
        print("ERROR: Could not prepare PRAGMA statement")
        return columns
    end
    
    for row in stmt:nrows() do
        table.insert(columns, row.name)
    end
    stmt:finalize()
    
    print(string.format("Found %d existing columns in %s", #columns, table_name))
    return columns
end

--- Add missing columns to table
function UpdateLinkDB.add_missing_columns(db, table_name, lucy_data, existing_columns)
    local existing_set = {}
    for _, col in ipairs(existing_columns) do
        existing_set[col] = true
    end
    
    local added_count = 0
    for lucy_field, _ in pairs(lucy_data) do
        -- Skip fields that would make invalid column names
        if not lucy_field:match("[%s%-]") and lucy_field ~= "id" and not existing_set[lucy_field] then
            -- Determine data type based on value
            local data_type = "TEXT"
            local value = lucy_data[lucy_field]
            if type(value) == "string" and tonumber(value) then
                data_type = "INTEGER"
            end
            
            local sql_cmd = string.format("ALTER TABLE %s ADD COLUMN %s %s", table_name, lucy_field, data_type)
            local result = db:exec(sql_cmd)
            
            if result == sql.OK then
                print(string.format("Added column: %s (%s)", lucy_field, data_type))
                added_count = added_count + 1
            else
                print(string.format("ERROR adding column %s: %s", lucy_field, db:errmsg()))
            end
        end
    end
    
    print(string.format("Added %d new columns to %s", added_count, table_name))
    return added_count
end

--- Update item record with Lucy data
function UpdateLinkDB.update_item_record(db, table_name, item_id, lucy_data)
    -- Build UPDATE statement
    local set_clauses = {}
    local values = {}
    
    for field, value in pairs(lucy_data) do
        -- Skip invalid column names and ID field
        if field ~= "id" and not field:match("[%s%-]") then
            table.insert(set_clauses, field .. " = ?")
            table.insert(values, tostring(value))
        end
    end
    
    local sql_cmd = string.format("UPDATE %s SET %s WHERE id = ?", table_name, table.concat(set_clauses, ", "))
    table.insert(values, item_id)
    
    local stmt = db:prepare(sql_cmd)
    if not stmt then
        print("ERROR: Could not prepare UPDATE statement: " .. db:errmsg())
        return false
    end
    
    -- Use unpack or table.unpack depending on Lua version
    local unpack = unpack or table.unpack
    stmt:bind_values(unpack(values))
    local result = stmt:step()
    local changes = db:changes()
    stmt:finalize()
    
    if result == sql.DONE and changes > 0 then
        print(string.format("Successfully updated item %s in %s (%d changes)", item_id, table_name, changes))
        return true
    else
        print(string.format("ERROR or no changes updating item %s: result=%s, changes=%d", item_id, tostring(result), changes))
        return false
    end
end

--- Main function to update single item
function UpdateLinkDB.update_single_item(item_id)
    print("=== Starting LinkDB Update for Item " .. item_id .. " ===")
    
    -- Read Lucy data
    local lucy_data = UpdateLinkDB.read_lucy_json(item_id)
    if not lucy_data then
        return false
    end
    
    -- Open database
    local db = UpdateLinkDB.open_database()
    if not db then
        return false
    end
    
    -- Try both table names
    local tables = {"raw_item_data", "raw_item_data_315"}
    local updated = false
    
    for _, table_name in ipairs(tables) do
        print("\n--- Processing table: " .. table_name .. " ---")
        
        -- Get existing columns
        local existing_columns = UpdateLinkDB.get_table_columns(db, table_name)
        if #existing_columns == 0 then
            print("Table " .. table_name .. " not found or empty, skipping")
            goto continue
        end
        
        -- Add missing columns
        UpdateLinkDB.add_missing_columns(db, table_name, lucy_data, existing_columns)
        
        -- Update item record
        if UpdateLinkDB.update_item_record(db, table_name, item_id, lucy_data) then
            updated = true
        end
        
        ::continue::
    end
    
    db:close()
    print("\n=== Update Complete ===")
    return updated
end

--- Test with item 50814
print("Starting MQ2LinkDB update script...")
UpdateLinkDB.update_single_item("50814")