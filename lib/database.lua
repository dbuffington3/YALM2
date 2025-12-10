--- @type Mq
local mq = require("mq")

local sql = require("lsqlite3")

local utils = require("yalm.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")

Database = {
	database = nil,
	path = ("%s/MQ2LinkDB.db"):format(mq.TLO.MacroQuest.Path("resources")),
}

Database.OpenDatabase = function(path)
	if not path then
		path = Database.path
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

Database.QueryDatabaseForItemId = function(item_id)
	local item_db = nil
	
	local query = string.format("SELECT * FROM raw_item_data WHERE id = %d LIMIT 1", item_id)
	for row in Database.database:nrows(query) do
		item_db = row
		break
	end
	
	return item_db
end

local function query_item_name(item_name)
	
	local item_db = nil
	local search_variations = { item_name }
	
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
		for row in Database.database:nrows(query) do
			item_db = row
			break
		end
	end
	
	return item_db
end

-- Assign function to Database table
Database.QueryDatabaseForItemName = query_item_name

-- Refresh database connection to ensure we get updated data
Database.RefreshConnection = function()
	if Database.database then
		Database.database:close()
	end
	Database.database = Database.OpenDatabase()
	return Database.database
end

return Database
