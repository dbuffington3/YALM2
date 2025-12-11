local mq = require("mq")

local configuration = require("yalm2.config.configuration")
local settings = require("yalm2.config.settings")

local inventory = require("yalm2.core.inventory")

local Item = require("yalm2.definitions.Item")

require("yalm2.lib.database")  -- Initialize the global Database table
local dannet = require("yalm2.lib.dannet")
local utils = require("yalm2.lib.utils")
local Write = require("yalm2.lib.Write")
local debug_logger = require("yalm2.lib.debug_logger")
local quest_interface = require("yalm2.core.quest_interface")

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
	debug_logger.info("CHECK_CAN_LOOT: Function called for member: %s", tostring(member and member.CleanName and member.CleanName() or "Unknown"))
	
	local char_settings =
		evaluate.get_member_char_settings(member, save_slots, dannet_delay, always_loot, unmatched_item_rule)

	local char_save_slots = char_settings.settings.save_slots
	local char_dannet_delay = char_settings.settings.dannet_delay
	local char_always_loot = char_settings.settings.always_loot
	local char_unmatched_item_rule = char_settings.settings.unmatched_item_rule

	local preference = evaluate.get_loot_preference(item, loot, char_settings, char_unmatched_item_rule)

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
		
		debug_logger.info("DB_LOOKUP: AdvLoot item - ID: %s, Name: '%s'", tostring(item_id), tostring(item_name))
		
		loot_item = Item:new(nil, YALM2_Database.QueryDatabaseForItemId(item_id))

		if not loot_item.item_db then
			debug_logger.info("DB_LOOKUP: Item ID %s not found, trying by name: '%s'", tostring(item_id), tostring(item_name))
			loot_item = Item:new(nil, YALM2_Database.QueryDatabaseForItemName(item_name))
		else
			debug_logger.info("DB_LOOKUP: Item ID %s found in database successfully", tostring(item_id))
		end

		if not loot_item.item_db then
			debug_logger.error("DB_LOOKUP: Item '%s' (ID: %s) not found in database by ID or name", tostring(item_name), tostring(item_id))
			loot_item = nil
		else
			debug_logger.info("DB_LOOKUP: Item data loaded - DB ID: %s, DB Name: '%s'", 
				tostring(loot_item.item_db.id), tostring(loot_item.item_db.name))
			debug_logger.info("DB_LOOKUP: NoRent: %s, NoDrop: %s, QuestItemFlag: %s", 
				tostring(loot_item.item_db.norent), tostring(loot_item.item_db.nodrop), tostring(loot_item.item_db.questitemflag))
		end
	end

	return loot_item
end

evaluate.get_loot_preference = function(item, loot, char_settings, unmatched_item_rule)
	local preference = nil

	-- LOOT DEBUG: Comprehensive logging to debug file
	debug_logger.info("=== LOOT ANALYSIS START ===")
	
	-- Get basic item information
	local item_name = "Unknown"
	local item_id = "Unknown" 
	if item and item.Name then
		item_name = item.Name()
		if item.ID then
			item_id = tostring(item.ID())
		end
	end
	
	debug_logger.info("LOOT: Analyzing item '%s' (ID: %s)", item_name, item_id)
	debug_logger.info("LOOT: Item type: %s", type(item))
	if item then
		debug_logger.info("LOOT: Item has Index: %s", tostring(item.Index ~= nil))
		debug_logger.info("LOOT: Item has ID method: %s", tostring(item.ID ~= nil))
	end
	
	-- Database lookup
	debug_logger.info("LOOT: Calling get_loot_item for database lookup...")
	local loot_item = evaluate.get_loot_item(item)
	
	if loot_item ~= nil then
		debug_logger.info("LOOT: Database lookup successful")
		debug_logger.info("LOOT: Database item name: %s", tostring(loot_item.Name and loot_item.Name() or "N/A"))
		debug_logger.info("LOOT: Database item ID: %s", tostring(loot_item.ID and loot_item.ID() or "N/A"))
		
		if loot_item.item_db then
			debug_logger.info("LOOT: Database flags available")
			debug_logger.info("LOOT: NoRent flag: %s", tostring(loot_item.item_db.norent))
			debug_logger.info("LOOT: NoDrop flag: %s", tostring(loot_item.item_db.nodrop)) 
			debug_logger.info("LOOT: QuestItem flag: %s", tostring(loot_item.item_db.questitemflag))
			
			-- Check if this is a quest item using the questitem column
			local is_quest_item = (loot_item.item_db.questitem == 1)
			debug_logger.info("LOOT: Quest Item Detection: %s (questitem=%s)", tostring(is_quest_item), tostring(loot_item.item_db.questitem))
			
			-- QUEST SYSTEM CHECK - ONLY for items flagged as quest items
			if is_quest_item and quest_interface and quest_interface.get_quest_characters_local then
				debug_logger.info("QUEST: This is a quest item - checking for characters who need it...")
				debug_logger.info("QUEST: Looking for characters needing item: %s", item_name)
				
				local chars = quest_interface.get_quest_characters_local(item_name)
				debug_logger.info("QUEST: Direct local check returned %d characters", chars and #chars or 0)
				
				if chars and #chars > 0 then
					debug_logger.info("QUEST: Characters needing this item: %s", table.concat(chars, ", "))
					debug_logger.info("QUEST: DIRECT ASSIGNMENT - Quest item needed by quest characters")
					debug_logger.info("=== LOOT ANALYSIS END: QUEST DIRECT ===")
					return { 
						setting = "Keep", 
						list = chars,
						data = { quest_item = true, direct_assignment = true }
					}
				else
					debug_logger.info("QUEST: No characters need this quest item right now")
					-- Quest item is not needed right now, but don't let saved preferences block it
					-- We want future quests to be able to pick it up
					-- Simply ignore it for now - saved preferences are for non-quest items only
					debug_logger.info("QUEST: Quest item not needed by anyone - ignoring (will be available for future quests)")
					debug_logger.info("=== LOOT ANALYSIS END: QUEST IGNORE ===")
					return { setting = "Ignore" }
				end
			elseif not is_quest_item then
				debug_logger.info("LOOT: Not a quest item (questitem=0) - skipping quest system, using normal loot rules")
			end
		else
			debug_logger.warn("LOOT: No database information available for item")
		end
	else
		debug_logger.warn("LOOT: Database lookup failed - loot_item is nil")
	end
	
	-- NORMAL LOOT PROCESSING
	debug_logger.info("LOOT: Starting normal loot rule evaluation...")
	if loot_item ~= nil and preference == nil then
		debug_logger.info("LOOT: Checking character-specific item settings...")
		if char_settings[configuration.types.item.settings_key] then
			debug_logger.info("LOOT: Character has item settings configured")
			preference = evaluate.check_loot_items(loot_item, loot.helpers, char_settings[configuration.types.item.settings_key])
			if preference then
				debug_logger.info("LOOT: Found character-specific preference: %s", tostring(preference.setting or preference))
			else
				debug_logger.info("LOOT: No character-specific preference found")
			end
		else
			debug_logger.info("LOOT: No character-specific item settings configured")
		end

		-- Check global item settings
		if preference == nil then
			debug_logger.info("LOOT: Checking global item settings...")
			if loot.items then
				debug_logger.info("LOOT: Global item settings available")
				preference = evaluate.check_loot_items(loot_item, loot.helpers, loot.items)
				if preference then
					debug_logger.info("LOOT: Found global item preference: %s", tostring(preference.setting or preference))
				else
					debug_logger.info("LOOT: No global item preference found")
				end
			else
				debug_logger.info("LOOT: No global item settings available")
			end
		end

		-- Check loot rules
		if preference == nil then
			debug_logger.info("LOOT: Checking loot rules...")
			if char_settings[configuration.types.rule.settings_key] then
				debug_logger.info("LOOT: Character has loot rules configured")
				preference = evaluate.check_loot_rules(
					loot_item,
					loot.helpers,
					loot.conditions,
					loot.rules,
					char_settings[configuration.types.rule.settings_key]
				)
				if preference then
					debug_logger.info("LOOT: Found rule-based preference: %s", tostring(preference.setting or preference))
				else
					debug_logger.info("LOOT: No rule-based preference found")
				end
			else
				debug_logger.info("LOOT: No loot rules configured for character")
			end
		end
	else
		if loot_item == nil then
			debug_logger.warn("LOOT: Cannot process - loot_item is nil")
		end
		if preference ~= nil then
			debug_logger.info("LOOT: Already has preference from quest processing: %s", tostring(preference.setting or preference))
		end
	end

	-- Apply unmatched item rule if no preference found
	if preference == nil and unmatched_item_rule then
		debug_logger.info("LOOT: No preference found, applying unmatched item rule: %s", tostring(unmatched_item_rule))
		preference = unmatched_item_rule
	end

	-- Final result
	if preference then
		debug_logger.info("LOOT: Final preference: %s", tostring(preference.setting or preference))
		if preference.list then
			debug_logger.info("LOOT: Target list: %s", table.concat(preference.list, ", "))
		end
	else
		debug_logger.info("LOOT: No preference determined")
	end
	
	debug_logger.info("=== LOOT ANALYSIS END ===")
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
	if not loot_preferences then
		return false
	end
	
	for name in pairs(loot_preferences) do
		if name == preference.setting then
			return true
		end
	end

	return false
end

return evaluate
