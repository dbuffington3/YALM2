-- Script to update collectible and nodrop fields in MQ2LinkDB.db from items.txt
local sql = require("lsqlite3")

local items_txt_path = "C:/temp/itemcollect/items.txt"
local db_path = "C:/MQ2/lua/yalm2/MQ2LinkDB.db"

print("Opening database:", db_path)
local db = sql.open(db_path)
if not db then
	print("ERROR: Could not open database")
	return
end

print("Reading items.txt:", items_txt_path)
local file = io.open(items_txt_path, "r")
if not file then
	print("ERROR: Could not open items.txt")
	db:close()
	return
end

-- Read header line to get field positions
local header = file:read("*line")
local fields = {}
local field_index = {}
local idx = 1
for field in header:gmatch("[^|]+") do
	fields[idx] = field
	field_index[field] = idx
	idx = idx + 1
end

print("Parsed", #fields, "fields from header")
print("Key field positions:")
print("  id:", field_index["id"])
print("  name:", field_index["name"])
print("  nodrop:", field_index["nodrop"])
print("  collectible:", field_index["collectible"])

-- Begin transaction for faster updates
db:exec("BEGIN TRANSACTION")

local updates = 0
local errors = 0

-- Process each line
for line in file:lines() do
	local values = {}
	local val_idx = 1
	for value in line:gmatch("[^|]*") do
		values[val_idx] = value
		val_idx = val_idx + 1
	end
	
	if #values > 0 then
		local item_id = values[field_index["id"]]
		local item_name = values[field_index["name"]]
		local nodrop = values[field_index["nodrop"]]
		local collectible = values[field_index["collectible"]]
		
		if item_id and item_id ~= "" and tonumber(item_id) then
			-- Update the database
			local stmt = db:prepare([[
				UPDATE raw_item_data 
				SET nodrop = ?, collectible = ?
				WHERE id = ?
			]])
			
			if stmt then
				stmt:bind_values(tonumber(nodrop) or 0, tonumber(collectible) or 0, tonumber(item_id))
				local result = stmt:step()
				if result == sql.DONE then
					updates = updates + 1
					if updates % 1000 == 0 then
						print(string.format("Updated %d items...", updates))
					end
				else
					errors = errors + 1
					if errors <= 10 then
						print(string.format("ERROR updating item %s (%s): %s", item_id, item_name or "unknown", db:errmsg()))
					end
				end
				stmt:finalize()
			end
		end
	end
end

-- Commit transaction
db:exec("COMMIT")

file:close()
db:close()

print(string.format("Update complete: %d items updated, %d errors", updates, errors))
print("Verify with: SELECT id, name, nodrop, collectible FROM raw_item_data WHERE id = 88672")
