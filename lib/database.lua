--- @type Mq
local mq = require("mq")

local sql = require("lsqlite3")

local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")

YALM2_Database = {
	database = nil,
	path = ("%s/MQ2LinkDB.db"):format(mq.TLO.MacroQuest.Path("resources")),
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
	local item_db = nil
	
	if not YALM2_Database.database then
		debug_logger.error("DATABASE: YALM2_Database.database is nil!")
		print("ERROR: YALM2_Database.database is nil - connection not initialized")
		return nil
	end
	
	local query = string.format("SELECT * FROM raw_item_data WHERE id = %d LIMIT 1", item_id)
	debug_logger.debug("DATABASE: Query: %s", query)
	
	local found = false
	local row_count = 0
	
	local success, err = pcall(function()
		for row in YALM2_Database.database:nrows(query) do
			row_count = row_count + 1
			item_db = row
			found = true
			debug_logger.debug("DATABASE: Found item id=%d, name=%s", row.id or 0, row.name or "nil")
			break
		end
	end)
	
	if not success then
		debug_logger.error("DATABASE: Query error: %s", tostring(err))
		return nil
	end
	
	if not found then
		debug_logger.warn("DATABASE: Item id %d not found in raw_item_data", item_id)
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
