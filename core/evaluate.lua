local mq = require("mq")

local configuration = require("yalm.config.configuration")
local settings = require("yalm.config.settings")

local inventory = require("yalm.core.inventory")

local Item = require("yalm.definitions.Item")

local database = require("yalm.lib.database")
local dannet = require("yalm.lib.dannet")
local utils = require("yalm.lib.utils")
local tasks = require("yalm2.core.tasks")

local evaluate = {}

-- Helper functions to avoid circular dependency with looting.lua
local function get_group_or_raid_tlo()
	local tlo = "Group"
	if mq.TLO.Raid.Members() > 0 then
		tlo = "Raid"
	end
	return tlo
end

local function get_member_count(tlo)
	return mq.TLO[tlo].Members() or 0
end

local function get_valid_member(tlo, index)
	local member
	if index == 0 or mq.TLO[tlo].Member(index).Name() == mq.TLO.Me.CleanName() then
		member = mq.TLO.Me
	else
		member = mq.TLO[tlo].Member(index)
	end
	if member.ID() == 0 or member.Dead() then
		return nil
	end
	return member
end

evaluate.check_can_loot = function(member, item, loot, save_slots, dannet_delay, always_loot, unmatched_item_rule)
	-- Debug: Log function entry for Blighted Blood Sample only
	if item and item.Name() == "Blighted Blood Sample" then
		Write.Error("*** DEBUG: check_can_loot called for Blighted Blood Sample, member: %s ***", 
			member and member.CleanName() or "unknown")
	end
	
	local char_settings =
		evaluate.get_member_char_settings(member, save_slots, dannet_delay, always_loot, unmatched_item_rule)

	local char_save_slots = char_settings.settings.save_slots
	local char_dannet_delay = char_settings.settings.dannet_delay
	local char_always_loot = char_settings.settings.always_loot
	local char_unmatched_item_rule = char_settings.settings.unmatched_item_rule

	if item and item.Name() == "Blighted Blood Sample" then
		Write.Error("*** DEBUG: About to call get_loot_preference for Blighted Blood Sample ***")
	end
	local preference = evaluate.get_loot_preference(item, loot, char_settings, char_unmatched_item_rule)
	if item and item.Name() == "Blighted Blood Sample" then
		Write.Error("*** DEBUG: get_loot_preference returned for Blighted Blood Sample: %s ***", 
			preference and (preference.setting or "unknown setting") or "nil")
	end

	local can_loot = evaluate.check_loot_preference(preference, loot)

	-- NO TRADE SAFETY CHECK: For NO TRADE items, enforce strict class restrictions
	if can_loot and item then
		local loot_item = evaluate.get_loot_item(item)
		if loot_item and loot_item.NoRent and loot_item.NoRent() then
			-- This is a NO TRADE item - be extra strict about class restrictions
			local member_class = nil
			local member_name = member.Name()
			
			-- Get the member's class
			if member_name == mq.TLO.Me.DisplayName() then
				member_class = mq.TLO.Me.Class.ShortName()
			else
				member_class = tostring(dannet.query(member_name, "Me.Class.ShortName", char_dannet_delay)) or nil
			end
			
			-- Check if this class can actually use the item
			if member_class and loot_item.Class then
				local class_match = loot_item.Class(member_class)
				if class_match == "NULL" then
					-- Class cannot use this NO TRADE item - block distribution
					Write.Warn("NO TRADE SAFETY: Preventing %s from getting %s (class %s cannot use it)", 
						member_name, loot_item.Name(), member_class)
					can_loot = false
				else
					Write.Info("NO TRADE SAFETY: %s can use %s (class %s allowed)", 
						member_name, loot_item.Name(), member_class)
				end
			end
		end
	end

	if can_loot then
		can_loot = inventory.check_group_member(member, preference.list, char_dannet_delay, char_always_loot)
	end

	local check_rematch = true

	if can_loot then
		can_loot = inventory.check_lore(member, item, char_dannet_delay)
		check_rematch = can_loot
	end

	if can_loot then
		local total_save_slots =
			inventory.check_total_save_slots(member, char_settings, char_save_slots, char_dannet_delay)
		can_loot = inventory.check_inventory(member, item, total_save_slots, char_dannet_delay)
		check_rematch = can_loot
	end

	if can_loot then
		can_loot = inventory.check_quantity(member, item, preference.quantity, char_dannet_delay, char_always_loot)
	end

	return can_loot, check_rematch, preference
end

evaluate.check_loot_conditions = function(item, loot_helpers, loot_conditions, set_conditions)
	local preference

	for i in ipairs(set_conditions) do
		local func, condition = nil, set_conditions[i]
		if loot_conditions[condition.name] and loot_conditions[condition.name].loaded then
			func = loot_conditions[condition.name].func.condition_func
		elseif loot_helpers[condition.name] and loot_helpers[condition.name].loaded then
			func = loot_helpers[condition.name].func.helper_func
		end

		if func then
			local success, result = pcall(func, item)
			if success and result then
				preference = evaluate.convert_rule_preference(item, loot_helpers, condition)
				break
			elseif not success and result then
				Write.Error(result)
			end
		end
	end

	return preference
end

evaluate.check_loot_items = function(item, loot_helpers, loot_items)
	local preference

	if loot_items[item.Name()] then
		preference = evaluate.convert_rule_preference(item, loot_helpers, loot_items[item.Name()])
	end

	return preference
end

evaluate.check_loot_preference = function(preference, loot)
	if not preference then
		return false
	end

	if not evaluate.is_valid_preference(loot.preferences, preference) then
		return false
	end

	if loot.preferences[preference.setting].leave then
		return false
	end

	return true
end

evaluate.check_loot_rules = function(item, loot_helpers, loot_conditions, loot_rules, char_rules)
	local preference

	for i in ipairs(char_rules) do
		local rule = char_rules[i]
		if loot_rules[rule.name] and rule.enabled then
			if loot_rules[rule.name][configuration.types.item.settings_key] then
				preference = evaluate.check_loot_items(
					item,
					loot_helpers,
					loot_rules[rule.name][configuration.types.item.settings_key]
				)
			end
			if preference == nil and loot_rules[rule.name][configuration.types.condition.settings_key] then
				preference = evaluate.check_loot_conditions(
					item,
					loot_helpers,
					loot_conditions,
					loot_rules[rule.name][configuration.types.condition.settings_key]
				)
			end
			if preference then
				break
			end
		end
	end

	return preference
end

evaluate.parse_preference_string = function(preference)
	local parts = utils.split(preference, "|")

	local setting = utils.title_case(tostring(parts[1]))
	local quantity = tonumber(parts[2])
	local list = parts[3] and utils.split(parts[3], ",") or nil

	return {
		["setting"] = setting,
		["quantity"] = quantity,
		["list"] = list,
	}
end

evaluate.convert_rule_preference = function(item, helpers, preference)
	local converted = utils.shallow_copy(preference)

	if type(preference) == "string" then
		return evaluate.parse_preference_string(preference)
	end

	local setting_function = helpers[preference["setting"]]
	if setting_function and setting_function.loaded then
		converted["setting"] = setting_function.func.helper_func(item)
	end

	local quantity_function = helpers[preference["quantity"]]
	if quantity_function and quantity_function.loaded then
		converted["quantity"] = quantity_function.func.helper_func(item)
	end

	local list_function = helpers[preference["list"]]
	if list_function and list_function.loaded then
		converted["list"] = list_function.func.helper_func(item)
	end

	return converted
end

evaluate.get_member_char_settings = function(member, save_slots, dannet_delay, always_loot, unmatched_item_rule)
	local char_name = member.CleanName():lower()

	local char_settings = settings.init_char_settings(char_name)

	if char_settings.settings.save_slots == nil then
		char_settings.settings.save_slots = save_slots
	end

	if char_settings.settings.dannet_delay == nil then
		char_settings.settings.dannet_delay = dannet_delay
	end

	if char_settings.settings.always_loot == nil then
		char_settings.settings.always_loot = always_loot
	end

	if char_settings.settings.unmatched_item_rule == nil then
		char_settings.settings.unmatched_item_rule = unmatched_item_rule
	end

	return char_settings
end

evaluate.get_loot_item = function(item)
	local loot_item = item

	-- this is an advlootitem
	if item.Index and item.ID() then
		local item_id = item.ID()
		local item_name = item.Name()
		
		Write.Info("Looking up AdvLoot item - ID: %s, Name: '%s'", tostring(item_id), tostring(item_name))
		
		loot_item = Item:new(nil, database.QueryDatabaseForItemId(item_id))

		if not loot_item.item_db then
			Write.Warn("Item ID %s not found in database, trying by name: '%s'", tostring(item_id), tostring(item_name))
			loot_item = Item:new(nil, database.QueryDatabaseForItemName(item_name))
		else
			Write.Info("Item ID %s found in database successfully", tostring(item_id))
		end

		if not loot_item.item_db then
			Write.Error("Item '%s' (ID: %s) not found in database by ID or name", tostring(item_name), tostring(item_id))
			loot_item = nil
		else
			Write.Info("Item data loaded - DB ID: %s, DB Name: '%s'", 
				tostring(loot_item.item_db.id), tostring(loot_item.item_db.name))
		end
	end

	return loot_item
end

evaluate.get_loot_preference = function(item, loot, char_settings, unmatched_item_rule)
	local preference

	-- Debug for unmatched items
	Write.Error("*** DEBUG: get_loot_preference called with item: '%s' ***", item and item.Name() or "nil")
	if item and item.Name() == "Blighted Blood Sample" then
		Write.Error("*** QUEST DEBUG: Processing Blighted Blood Sample ***")
	end

	local loot_item = evaluate.get_loot_item(item)
	
	-- Debug: Always log function entry
	Write.Info("=== get_loot_preference called for item: %s ===", item and item.Name() or "unknown")
	Write.Info("loot_item status: %s", loot_item and "found" or "nil")

	-- PRIORITY 1: Check if item is needed for quests (quest flag OR in our task data)
	if loot_item ~= nil then
		local item_name = loot_item.Name()
		local has_quest_flag = loot_item.Quest and loot_item.Quest()
		
		-- Debug: Check the item database directly
		local questitemflag_value = nil
		if loot_item.item_db and loot_item.item_db.questitemflag then
			questitemflag_value = loot_item.item_db.questitemflag
		end
		
		-- Simplified quest detection to prevent crashes
		local needed_by, task_name, objective
		local in_task_data = false
		
		-- Safely check task data
		if tasks and tasks.get_characters_needing_item then
			local success, result1, result2, result3 = pcall(tasks.get_characters_needing_item, item_name)
			if success and result1 and #result1 > 0 then
				needed_by, task_name, objective = result1, result2, result3
				in_task_data = true
			end
		end
		
		if item_name == "Blighted Blood Sample" then
			Write.Error("*** SAFE QUEST CHECK: %s - in_task_data: %s ***", item_name, tostring(in_task_data))
		end
		
		if has_quest_flag or in_task_data then
			if item_name == "Blighted Blood Sample" then
				Write.Error("*** QUEST LOGIC ACTIVATED for %s ***", item_name)
			end
		
		if needed_by and #needed_by > 0 then
			-- Filter needed_by to only include group/raid members
			local group_or_raid_tlo = get_group_or_raid_tlo()
			local count = get_member_count(group_or_raid_tlo)
			local valid_recipients = {}
			
			-- Check each character who needs the item
			for _, char_name in ipairs(needed_by) do
				-- Check if this character is in our group/raid
				for i = 0, count do
					local member = get_valid_member(group_or_raid_tlo, i)
					if member and member.CleanName():lower() == char_name:lower() then
						table.insert(valid_recipients, char_name)
						break
					end
				end
			end
			
			if #valid_recipients > 0 then
				Write.Info("Quest item %s needed by group members: %s (task: %s)", 
					item_name, table.concat(valid_recipients, ", "), task_name or "Unknown")
				
				-- Select the best recipient for this quest item
				-- Priority: First non-master-looter who needs it, otherwise first recipient
				local selected_recipient = valid_recipients[1]  -- Default to first
				local master_looter = mq.TLO.Group.MasterLooter.CleanName()
				
				-- Try to find a non-master-looter recipient first
				for _, recipient in ipairs(valid_recipients) do
					if recipient:lower() ~= master_looter:lower() then
						selected_recipient = recipient
						break
					end
				end
				
				Write.Info("Quest priority: Assigning %s to %s", item_name, selected_recipient)
				
				-- Return quest preference with single selected recipient
				preference = { 
					setting = "Keep", 
					list = { selected_recipient },  -- Single recipient list
					data = { quest_item = true, task_name = task_name, objective = objective, all_recipients = valid_recipients }
				}
			else
				Write.Debug("Quest item %s not needed by any group/raid members, falling back to global settings", item_name)
				-- Quest item but no group members need it - fall through to global settings
			end
		else
			Write.Debug("Quest item %s not needed by any characters, falling back to global settings", item_name)
			-- Quest item but no one needs it - fall through to global settings
		end
		else
			Write.Info("Item %s has no quest flag, using normal loot evaluation", item_name)
		end
	end

	if loot_item ~= nil and preference == nil then
		-- Debug for specific item
		if item and item.Name() == "Blighted Blood Sample" then
			Write.Error("*** LOOT RULES DEBUG: Checking loot rules for Blighted Blood Sample ***")
		end
		
		if char_settings[configuration.types.item.settings_key] then
			preference = evaluate.check_loot_items(loot_item, loot.helpers, char_settings[configuration.types.item.settings_key])
			if item and item.Name() == "Blighted Blood Sample" and preference then
				Write.Error("*** FOUND in char items: %s ***", preference.setting or "unknown")
			end
		end

		if preference == nil and loot.items then
			preference = evaluate.check_loot_items(loot_item, loot.helpers, loot.items)
			if item and item.Name() == "Blighted Blood Sample" and preference then
				Write.Error("*** FOUND in global items: %s ***", preference.setting or "unknown")
			end
		end

		if preference == nil and char_settings[configuration.types.rule.settings_key] then
			preference = evaluate.check_loot_rules(
				loot_item,
				loot.helpers,
				loot.conditions,
				loot.rules,
				char_settings[configuration.types.rule.settings_key]
			)
			if item and item.Name() == "Blighted Blood Sample" and preference then
				Write.Error("*** FOUND in char rules: %s ***", preference.setting or "unknown")
			end
		end
	end

	-- QUEST ITEM INTELLIGENCE: Check if this is a quest item that's no longer needed
	if preference == nil and loot_item ~= nil then
		local has_quest_flag = loot_item.Quest and loot_item.Quest()
		if has_quest_flag then
			-- This is a quest item but no one currently needs it
			Write.Info("Quest item %s no longer needed - leaving it behind", loot_item.Name())
			preference = { setting = "Leave", list = {}, data = { former_quest_item = true } }
		end
	end

	if preference == nil and unmatched_item_rule then
		if item and item.Name() == "Blighted Blood Sample" then
			Write.Error("*** QUEST DEBUG: Blighted Blood Sample has no preference, using unmatched_item_rule: %s ***", 
				unmatched_item_rule and unmatched_item_rule.setting or "nil")
		end
		preference = unmatched_item_rule
	end

	return preference
end

evaluate.is_item_in_saved_slot = function(item, char_settings)
	if item.Name() then
		local saved = char_settings.saved

		if saved then
			for i in ipairs(saved) do
				local slots = saved[i]
				local slots_match = false

				if slots.itemslot then
					if slots.itemslot == item.ItemSlot() then
						slots_match = true
					end

					if slots.itemslot2 then
						if slots.itemslot2 ~= item.ItemSlot2() then
							slots_match = false
						end
					end
				end

				if slots_match then
					return true
				end
			end
		end
	end

	return false
end

evaluate.is_valid_preference = function(loot_preferences, preference)
	for name in pairs(loot_preferences) do
		if name == preference.setting then
			return true
		end
	end

	return false
end

return evaluate
