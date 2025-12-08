local mq = require("mq")

local function action(global_settings, char_settings, args)
	if not args[2] then
		Write.Info("Usage: /yalm2 queryitem [item_id|item_name]")
		Write.Info("  Queries the database for detailed item information")
		return
	end
	
	local query = args[2]
	local item_data = nil
	
	-- Determine if it's an ID (numeric) or name
	local item_id = tonumber(query)
	if item_id then
		Write.Info("Querying database for item ID: %d", item_id)
		item_data = Database.QueryDatabaseForItemId(item_id)
	else
		Write.Info("Querying database for item name: %s", query)
		item_data = Database.QueryDatabaseForItemName(query)
	end
	
	if item_data then
		Write.Info("Item found in database:")
		Write.Info("  ID: %s", tostring(item_data.id or "unknown"))
		Write.Info("  Name: %s", tostring(item_data.name or "unknown"))
		Write.Info("  Class: %s", tostring(item_data.classes or "unknown"))
		
		-- Check specifically for quest-related fields
		Write.Info("Quest-related fields:")
		local quest_fields = {"quest", "questflag", "nodrop", "magic", "lore", "tradeskills"}
		for _, field in ipairs(quest_fields) do
			local value = item_data[field]
			if value ~= nil and value ~= 0 and value ~= "" then
				Write.Info("  %s: %s", field, tostring(value))
			end
		end
		
		-- Show all non-zero/non-empty fields for debugging
		if args[3] and args[3]:lower() == "all" then
			Write.Info("All fields:")
			local sorted_keys = {}
			for key in pairs(item_data) do
				table.insert(sorted_keys, key)
			end
			table.sort(sorted_keys)
			
			for _, key in ipairs(sorted_keys) do
				local value = item_data[key]
				if value ~= nil and value ~= 0 and value ~= "" then
					Write.Info("  %s: %s", key, tostring(value))
				end
			end
		end
		
	else
		Write.Error("Item not found in database: %s", query)
	end
end

return { action_func = action }