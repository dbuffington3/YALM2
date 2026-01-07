---@type Mq
local mq = require("mq")

local evaluate = require("yalm2.core.evaluate")
local helpers = require("yalm2.core.helpers")
local Write = require("yalm2.lib.Write")
local YALM2_Database = require("yalm2.lib.database")

local function is_donate_button_enabled()
	local handle = "TributeMasterWnd/TMW_DonateButton"
	return mq.TLO.Window(handle).Enabled()
end

local function get_character_class()
	-- Use Me.Class() which returns the full class name like "Shadow Knight"
	-- Then map it to the class ID for bitmask calculation
	local class_name = mq.TLO.Me.Class()
	
	-- Map class names (with spaces!) to class IDs
	local class_name_to_id = {
		['Warrior'] = 1,
		['Cleric'] = 2,
		['Paladin'] = 3,
		['Ranger'] = 4,
		['Shadow Knight'] = 5,  -- NOTE: Space in the name!
		['Druid'] = 6,
		['Monk'] = 7,
		['Bard'] = 8,
		['Rogue'] = 9,
		['Shaman'] = 10,
		['Necromancer'] = 11,
		['Wizard'] = 12,
		['Magician'] = 13,
		['Enchanter'] = 14,
		['Beastlord'] = 15,
		['Berserker'] = 16,
	}
	
	local class_id = class_name_to_id[class_name]
	if not class_id then
		Write.Info("[get_character_class] WARNING: Unknown class name: %s", tostring(class_name))
		return nil
	end
	
	return class_id  -- Return the class ID (1-16), not the name
end

local function can_character_use_item(item)
	--[[
	Check if current character can use item based on class restrictions
	Uses database to get class bitmask and checks against current character class
	Returns true if character CAN use the item (or no restrictions)
	Returns false if character CANNOT use the item
	]]
	if not item or not item.ID() then
		return true  -- Default to allowing if we can't determine
	end
	
	-- Check if database is available
	if not YALM2_Database or not YALM2_Database.QueryDatabaseForItemId then
		return true  -- Database not available, assume usable
	end
	
	local item_id = item.ID()
	local item_name = item.Name()
	local ok, item_data = pcall(function() return YALM2_Database.QueryDatabaseForItemId(item_id) end)
	
	if not ok or not item_data then
		Write.Debug("[can_character_use_item] %s (ID: %s) - Query failed or not in database", item_name, item_id)
		return true  -- If query fails or not in database, assume usable
	end
	
	-- Parse class bitmask from database
	local classes_bitmask = tonumber(item_data.classes) or 0
	if classes_bitmask == 0 then
		return true  -- No class restrictions
	end
	
	-- Get current character's class ID (1-16)
	local class_id = get_character_class()
	
	if not class_id then
		return true  -- Unknown class, assume usable
	end
	
	-- Check if character's class bit is set in the bitmask
	-- Class ID 1-16 maps to bit position 0-15 (bit_position = class_id - 1)
	local bit_offset = class_id - 1
	local is_allowed = bit.band(classes_bitmask, bit.lshift(1, bit_offset)) ~= 0
	
	return is_allowed
end

local function should_tribute_item(item, global_settings, char_settings)
	--[[
	Determine if item should be tributed based on:
	1. NO TRADE/NO DROP flag (cannot be traded to others)
	2. Current character cannot use it (class/race restricted)
	3. Must have a tribute value (TLO) - items with no tribute value are junk
	4. Must not be a tradeskill item
	Returns true if item should be tributed
	]]
	if not item or not item.Name() then
		return false
	end
	
	local item_name = item.Name()
	local item_id = item.ID()
	
	-- Check if item is tradeskill item - skip these for auto-tribute
	if item.Tradeskills() then
		Write.Debug("[should_tribute] %s (ID: %s) - Skipped: Tradeskill item", item_name, item_id)
		return false  -- Item is used in tradeskills, don't auto-tribute
	end
	
	-- Check if item has tribute value - items with no value aren't worth tributing
	local tribute_value = item.Tribute()
	if not tribute_value or tribute_value == 0 then
		Write.Debug("[should_tribute] %s (ID: %s) - Skipped: No tribute value (%s)", item_name, item_id, tostring(tribute_value))
		return false  -- Item has no tribute value, don't tribute
	end
	
	-- Check if item is in a saved slot (don't tribute saved items)
	if evaluate.is_item_in_saved_slot(item, char_settings) then
		return false  -- Item is saved, don't tribute
	end
	
	-- Check database for NO TRADE / NO DROP flag
	if not item_id then
		return false
	end
	
	local ok, item_data = pcall(function() return YALM2_Database.QueryDatabaseForItemId(item_id) end)
	
	if not ok then
		Write.Info("[DEBUG] %s (ID: %s) - Database query FAILED", item_name, item_id)
		return false  -- Can't determine, don't tribute
	end
	
	if not item_data then
		Write.Info("[DEBUG] %s (ID: %s) - NOT IN DATABASE", item_name, item_id)
		return false  -- Not in database
	end
	
	-- Check if item is NO TRADE
	-- First try the actual item TLO property (handles attunable items correctly)
	-- Then fallback to database if TLO method unavailable
	local is_notrade = false
	
	-- Try to get NoTrade() from the item TLO (this is the reliable way for inventory items)
	-- Attunable items start as tradeable in database but become NO TRADE when equipped
	if item and item.NoTrade and item.NoTrade() then
		is_notrade = true
	else
		-- Fallback to database nodrop flag
		local nodrop_value = item_data.nodrop
		if nodrop_value ~= nil then
			is_notrade = (tonumber(nodrop_value) == 0)
		end
	end
	
	if not is_notrade then
		return false  -- Item is tradeable, don't tribute
	end
	
	-- Item is NO TRADE, now check if character can use it
	local can_use = can_character_use_item(item)
	local should_tribute = not can_use
	
	-- Tribute if we CANNOT use it (NO TRADE + can't use = tribute it)
	return should_tribute
end

local function can_donate_item(item, global_settings, char_settings)
	if item.Name() then
		local preference = evaluate.get_loot_preference(
			item,
			global_settings,
			char_settings,
			global_settings.settings.unmatched_item_rule
		)

		if preference then
			local loot_preference = global_settings.preferences[preference.setting]

			if loot_preference and loot_preference.name == "Tribute" then
				if not evaluate.is_item_in_saved_slot(item, char_settings) then
					return true
				end
			end
		end
	end

	return false
end

local function donate_item(item, global_settings, char_settings)
	--[[
	Donate an item if either:
	1. It matches the Tribute preference (from settings)
	2. It's NO TRADE and the character cannot use it
	
	Currently in TEST MODE - logging only, not actually donating
	]]
	local can_sell = can_donate_item(item, global_settings, char_settings)
	local should_tribute_restricted = should_tribute_item(item, global_settings, char_settings)

	-- Only log and process items that will actually be tributed
	if can_sell or should_tribute_restricted then
		local item_name = item.Name() or "unknown"
		
		if can_sell then
			Write.Info("Would tribute (preference): %s", item_name)
		end
		
		if should_tribute_restricted and not can_sell then
			Write.Info("Would tribute (NO TRADE - cannot use): %s", item_name)
		end
		
		-- Actual tribute action
		if item.ItemSlot2() ~= nil then
			mq.cmdf("/shift /itemnotify in pack%s %s leftmouseup", item.ItemSlot() - 22, item.ItemSlot2() + 1)
		else
			mq.cmdf("/shift /itemnotify %s leftmouseup", item.ItemSlot())
		end
		mq.delay(250)

		-- wait for the donate button
		while not is_donate_button_enabled() do
			mq.delay(250)
		end

		-- donate item
		mq.cmdf("/shift /notify TributeMasterWnd TMW_DonateButton leftmouseup")
		mq.delay(1000)

		while is_donate_button_enabled() do
			mq.delay(250)
		end
	end
end

local function action(global_settings, char_settings, args)
	if args[2] then
		if not (args[2] == "guild" or args[2] == "me") then
				Write.Error("That is not a valid option")
		end
	end

	if helpers.ready_tribute_window(true, args[2]) then
		Write.Info("Donating items...")
		mq.cmd("/keypress OPEN_INV_BAGS")

		helpers.call_func_on_inventory(donate_item, global_settings, char_settings)

		Write.Info("Finished donating")
		mq.cmd("/cleanup")
	end
end

return { action_func = action }
