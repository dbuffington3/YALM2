--[[
    YALM2 Database Module
    ====================
    
    Manages SQLite database connections for equipment data lookup.
    
    INSTALLATION & SETUP:
    =====================
    1. Database file should be placed at: <MQ2_ROOT>/resources/MQ2LinkDB.db
    2. If your MQ2 installation is at a non-standard location:
       - The script will automatically detect the MQ2 root directory
       - It navigates up from the YALM2 lua directory (/lua/yalm2)
       - No manual configuration needed
    
    INSTALLATION EXAMPLES:
    ======================
    Standard installation (auto-detected):
        C:\MQ2\
        ├── lua\
        │   └── yalm2\          (YALM2 installed here)
        ├── resources\
        │   └── MQ2LinkDB.db    (Database auto-detected here)
        └── config\
    
    Custom location example:
        D:\EverQuest\
        ├── lua\
        │   └── yalm2\          (YALM2 installed here)
        ├── resources\
        │   └── MQ2LinkDB.db    (Database auto-detected here)
        └── config\
    
    TROUBLESHOOTING:
    ================
    If the database is not found:
    1. Ensure MQ2LinkDB.db exists in <MQ2_ROOT>/resources/
    2. Check your MQ2 installation location
    3. The auto-detection looks for the 'lua' directory and works backward
]]

--- @type Mq
local mq = require("mq")

local sql = require("lsqlite3")

local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")

--[[
    Auto-detect MQ2LinkDB.db path based on YALM2 installation location.
    
    YALM2 is typically installed at: <MQ2_ROOT>/lua/yalm2/
    This function discovers the MQ2 root directory and looks for the database.
    
    Search order:
    1. <MQ2_ROOT>/resources/MQ2LinkDB.db (standard location)
    2. Fall back to MQ2's configured resources path
    
    This is self-contained and requires no configuration from users.
]]
local function get_database_path()
	-- Try to get the MQ2 root directory by navigating up from YALM2's location
	-- YALM2 is at: <MQ2_ROOT>/lua/yalm2
	local lua_dir = tostring(mq.TLO.MacroQuest.Path("lua"))  -- e.g., C:\MQ2\lua or D:\EQ\lua
	
	-- Extract MQ2 root by removing /lua from the path
	local mq2_root = lua_dir:gsub("/lua$", ""):gsub("\\lua$", "")
	
	-- Try resources directory (standard location)
	local resources_db = mq2_root .. "/resources/MQ2LinkDB.db"
	local resources_db_win = mq2_root .. "\\resources\\MQ2LinkDB.db"
	
	if utils.file_exists(resources_db) or utils.file_exists(resources_db_win) then
		return utils.file_exists(resources_db) and resources_db or resources_db_win
	end
	
	-- Fall back to MQ2's configured resources path
	local fallback_path = ("%s/MQ2LinkDB.db"):format(tostring(mq.TLO.MacroQuest.Path("resources")))
	
	debug_logger.warn("DATABASE: Could not auto-detect MQ2LinkDB.db in standard location. Using fallback: %s", fallback_path)
	return fallback_path
end

YALM2_Database = {
	database = nil,
	path = get_database_path(),
	mq2_root = tostring(mq.TLO.MacroQuest.Path("lua")):gsub("/lua$", ""):gsub("\\lua$", ""),
}

YALM2_Database.OpenDatabase = function(path)
	if not path then
		path = YALM2_Database.path
	end
	if not utils.file_exists(path) then
		print("ERROR: Database file does not exist [" .. path .. "]")
		return nil;
	end
	local db, ec, em = sql.open(path)
	if db then
		for row in db:nrows("select sqlite_version() as ver;") do
			print("SQLite version: " .. row.ver)
		end
	else
		print("ERROR: Could not open database [" .. path .. "] (" .. ec .. "): " .. em)
		return nil;
	end
	return db
end

YALM2_Database.QueryDatabaseForItemId = function(item_id)
	local item_db = {}
	
	if not YALM2_Database.database then
		debug_logger.error("DATABASE: YALM2_Database.database is nil!")
		print("ERROR: YALM2_Database.database is nil - connection not initialized")
		return nil
	end
	
	-- Query the columns we need using nrows() which returns named tables
	local query = string.format(
		"SELECT id, name, ac, hp, mana, endur, mr, fr, cr, pr, dr, attack, regen, manaregen, healamt, clairvoyance, reqlevel, classes, slots, itemtype, questitem, nodrop, guildfavor, cost, tradeskills, stacksize, collectible, bagtype FROM raw_item_data WHERE id = %d LIMIT 1",
		item_id
	)
	debug_logger.debug("DATABASE: Query: %s", query)
	
	local success, err = pcall(function()
		for row in YALM2_Database.database:nrows(query) do
			-- Copy all fields from the row into item_db
			item_db = row
			return  -- Only process first row
		end
	end)
	
	if not success then
		debug_logger.error("DATABASE: Query error: %s", tostring(err))
		return nil
	end
	
	if not item_db or not item_db.id then
		debug_logger.warn("DATABASE: Item id %d not found in raw_item_data", item_id)
		return nil
	end
	
	return item_db
end

local function query_item_name(item_name)
	
	local item_db = nil
	local search_variations = { item_name }
	
	if not YALM2_Database.database then
		debug_logger.error("DATABASE: YALM2_Database.database is nil!")
		return nil
	end
	
	-- Try removing trailing 's' for common plurals (Silks -> Silk)
	if item_name:match('s$') then
		table.insert(search_variations, item_name:sub(1, -2))
	end
	
	-- Try removing trailing 'es' for words like "boxes"
	if item_name:match('es$') then
		table.insert(search_variations, item_name:sub(1, -3))
	end
	
	-- Try each variation
	for idx, search_term in ipairs(search_variations) do
		if item_db then break end
		
		local escaped = search_term:gsub("'", "''")
		
		local query = string.format("SELECT * FROM raw_item_data WHERE name = '%s' LIMIT 1", escaped)
		debug_logger.debug("DATABASE: Trying variation %d: %s", idx, search_term)
		
		local found = false
		for row in YALM2_Database.database:nrows(query) do
			item_db = row
			found = true
			debug_logger.debug("DATABASE: Found item id=%d, name=%s", row.id or 0, row.name or "nil")
			break
		end
	end
	
	if not item_db then
		debug_logger.warn("DATABASE: Item '%s' not found in raw_item_data", item_name)
	end
	
	return item_db
end

-- Assign function to YALM2_Database table
YALM2_Database.QueryDatabaseForItemName = query_item_name

-- Refresh database connection to ensure we get updated data
YALM2_Database.RefreshConnection = function()
	if YALM2_Database.database then
		YALM2_Database.database:close()
	end
	YALM2_Database.database = YALM2_Database.OpenDatabase()
	return YALM2_Database.database
end

return YALM2_Database
