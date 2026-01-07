---@type Mq
local mq = require("mq")

local evaluate = require("yalm2.core.evaluate")
local inventory = require("yalm2.core.inventory")
local quest_interface = require("yalm2.core.quest_interface")

local dannet = require("yalm2.lib.dannet")
local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")
local quest_db = require("yalm2.lib.quest_database")
local equipment_dist = require("yalm2.lib.equipment_distribution")
require("yalm2.lib.database")  -- Initialize the global Database table

local looting = {}

-- Retry queue for items that failed can_i_loot() check due to LootInProgress
local retry_queue = {}
local max_retries = 3
local retry_delay_ms = 150  -- Wait 150ms between retries

--- Wait for LootInProgress to clear so next item can be processed
--- This prevents items from being skipped when multiple items are on same corpse
looting.wait_for_loot_clear = function(item_name, max_wait_seconds)
	max_wait_seconds = max_wait_seconds or 5
	local wait_start = os.time()
	
	while mq.TLO.AdvLoot.LootInProgress() and (os.time() - wait_start) < max_wait_seconds do
		mq.delay(50)  -- Check every 50ms
	end
	
	if mq.TLO.AdvLoot.LootInProgress() then
		debug_logger.warn("LOOT_WAIT: LootInProgress still true after %d seconds for %s", max_wait_seconds, item_name or "item")
	else
		debug_logger.debug("LOOT_WAIT: LootInProgress cleared for %s", item_name or "item")
	end
end

--- Helper function to generate descriptive "why kept" message
looting.get_keep_reason = function(preference)
	if not preference then
		return "unknown reason"
	end
	
	-- Check if this is equipment distribution
	if preference.data and preference.data.equipment_dist then
		return string.format("equipment distribution (%s / %s, score: %d)", 
			preference.data.armor_set, preference.data.piece_type, preference.data.satisfaction_score or 0)
	end
	
	-- Check if this is a quest item being distributed
	if preference.data and preference.data.quest_item then
		if preference.data.task_name then
			return "quest needed by " .. preference.list[1] .. " for " .. preference.data.task_name
		end
		return "quest item needed"
	end
	
	-- Check for valuable quest item override
	if preference.data and preference.data.valuable_quest_item then
		return "valuable quest item (worth keeping regardless of quest status)"
	end
	
	-- Check for tradeskill material
	if preference.data and preference.data.tradeskill then
		return "tradeskill material"
	end
	
	-- Check for class-specific rule
	if preference.data and preference.data.class_specific then
		return "needed for " .. (preference.list and preference.list[1] or "group member")
	end
	
	-- Check for item-specific rule
	if preference.data and preference.data.item_rule then
		return "matches item preference rule"
	end
	
	-- Check for loot rule
	if preference.data and preference.data.loot_rule then
		return "matches loot rule"
	end
	
	-- Character-specific or global preference
	if preference.list and #preference.list > 0 then
		local who = table.concat(preference.list, ", ")
		return "preference for " .. who
	end
	
	return "configured preference"
end

looting.am_i_master_looter = function()
	return mq.TLO.Me.Name() == mq.TLO.Group.MasterLooter.Name()
end

looting.can_i_loot = function(loot_count_tlo)
	return mq.TLO.AdvLoot[loot_count_tlo]() > 0 and not mq.TLO.AdvLoot.LootInProgress()
end

looting.is_solo_looter = function()
	return mq.TLO.Group.Members() == 0 or (mq.TLO.Group.Members() == 1 and mq.TLO.Me.Mercenary.ID())
end

looting.get_group_or_raid_tlo = function()
	local tlo = "Group"
	if mq.TLO.Raid.Members() > 0 then
		tlo = "Raid"
	end

	return tlo
end

looting.get_loot_tlos = function()
	local solo_looter = looting.is_solo_looter()
	local loot_count_tlo = solo_looter and "PCount" or "SCount"
	local loot_list_tlo = solo_looter and "PList" or "SList"

	return loot_count_tlo, loot_list_tlo
end

looting.get_loot_prefix = function()
	local solo_looter = looting.is_solo_looter()
	return solo_looter and "personal" or "shared"
end

looting.leave_item = function()
	local prefix = looting.get_loot_prefix()
	mq.cmdf("/advloot %s 1 leave", prefix)
	-- CRITICAL: Wait for AdvLoot to complete the leave operation
	-- Without this delay, LootInProgress remains true and the next item in the list gets skipped
	mq.delay(100)  -- 100ms should be enough for the command to complete
end

looting.give_item = function(member, item_name)
	if not member then
		Write.Error("CRITICAL ERROR: give_item called with nil member for item %s", item_name or "unknown")
		return
	end
	
	local character_name = member.Name()
	debug_logger.info("LOOT_DISTRIBUTE: Giving %s to %s", item_name or "item", character_name)
	
	-- Distribute the item via advloot
	mq.cmdf("/advloot shared 1 giveto %s 1", character_name)
	-- CRITICAL: Wait for AdvLoot to complete the give operation
	-- Without this delay, LootInProgress remains true and the next item in the list gets skipped
	mq.delay(100)  -- 100ms should be enough for the command to complete
	
	-- Update the quest database to reflect this character received an item
	-- Increment their quest progress immediately (e.g., 0/2 → 1/2)
	-- This way the ML knows the distribution state without waiting for refresh
	if item_name and quest_interface.is_quest_item(item_name) then
		quest_db.increment_quantity_received(character_name, item_name)
		debug_logger.quest("QUEST_DB: Incremented %s's %s status in database", character_name, item_name)
		-- Trigger character-specific quest UI refresh (much faster than full system refresh)
		quest_interface.refresh_character_after_loot(character_name, item_name)
	end
end

looting.loot_item = function()
	mq.cmd("/advloot personal 1 loot")
end

--- Quest-specific loot distribution - handles quest items without preference rules
--- Returns: member to receive item, or nil if no one needs it
looting.get_quest_item_recipient = function(item_name, needed_by, item_quantities)
	--[[
	Quest Item Distribution Logic:
	1. Check if item is needed by anyone
	2. If not needed: return nil (leave on corpse)
	3. If needed: find who needs it MOST (least inventory quantity)
	   - If Master Looter is in the list, give to others first, ML last
	   - If tied on quantity, prioritize non-ML characters
	4. Return the member object for that character
	]]--
	
	if not needed_by or #needed_by == 0 then
		debug_logger.info("QUEST_DISTRIBUTION: No one needs %s - item will be left on corpse", item_name)
		return nil
	end
	
	item_quantities = item_quantities or {}
	local group_or_raid_tlo = looting.get_group_or_raid_tlo()
	local group_size = looting.get_member_count(group_or_raid_tlo)
	
	-- Get Master Looter name for prioritization
	local master_looter_name = mq.TLO.Group.MainAssist.CleanName() or mq.TLO.Me.CleanName()
	
	debug_logger.info("QUEST_DISTRIBUTION: Finding recipient for %s needed by [%s]", 
		item_name, table.concat(needed_by, ", "))
	debug_logger.info("QUEST_DISTRIBUTION: Master Looter: %s", master_looter_name)
	
	-- Build list of group members who need this item with their quantities
	local candidates = {}
	
	for _, char_name in ipairs(needed_by) do
		-- Find the group member object
		for i = 0, group_size do
			local member = looting.get_valid_member(group_or_raid_tlo, i)
			if member and member.CleanName():lower() == char_name:lower() then
				local qty_needed = item_quantities[char_name] or 0
				local is_ml = (member.CleanName():lower() == master_looter_name:lower())
				
				debug_logger.info("QUEST_DISTRIBUTION: Candidate %s - needs %d items, ML: %s", 
					char_name, qty_needed, tostring(is_ml))
				
				table.insert(candidates, {
					name = char_name,
					member = member,
					qty_needed = qty_needed,
					is_master_looter = is_ml
				})
				break
			end
		end
	end
	
	if #candidates == 0 then
		debug_logger.info("QUEST_DISTRIBUTION: No candidates in group need this item")
		return nil
	end
	
	-- Sort by: quantity needed (ascending), then non-ML first
	-- This way: 
	--   - Person needing 2 items gets priority over person needing 1
	--   - If tied on quantity, non-ML characters get priority (ML gets it last)
	table.sort(candidates, function(a, b)
		-- Primary: Person needing more gets priority (descending qty)
		if a.qty_needed ~= b.qty_needed then
			return a.qty_needed > b.qty_needed
		end
		-- Secondary: Non-ML before ML
		if a.is_master_looter ~= b.is_master_looter then
			return not a.is_master_looter  -- false (non-ML) comes before true (ML)
		end
		-- Tertiary: Alphabetical for consistency
		return a.name < b.name
	end)
	
	local winner = candidates[1]
	debug_logger.info("QUEST_DISTRIBUTION: SELECTED %s (needs %d items, ML: %s)", 
		winner.name, winner.qty_needed, tostring(winner.is_master_looter))
	
	return winner.member
end

looting.get_member_count = function(tlo)
	return mq.TLO[tlo].Members() or 0
end

looting.get_valid_member = function(tlo, index)
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

looting.get_member_can_loot = function(item, loot, char_loot, save_slots, dannet_delay, always_loot, unmatched_item_rule)
	local group_or_raid_tlo = looting.get_group_or_raid_tlo()

	local can_loot, check_rematch, member, preference = false, true, nil, nil

	local item_name = item and item.Name() or "unknown"
	debug_logger.info("LOOT_CHECK: Processing item: %s", item_name)
	
	local loot_item = evaluate.get_loot_item(item)
	
	-- Defensive logging: Check if item was found in database
	if not loot_item or not loot_item.item_db then
		Write.Warn("ITEM_NOT_FOUND: %s - not found in database, will be left on corpse", item_name)
		debug_logger.info("LOOT_CHECK: Item %s not found in database - loot_item=%s, item_db=%s", 
			item_name, tostring(loot_item), loot_item and tostring(loot_item.item_db) or "nil")
	else
		-- Defensive logging: Log the values retrieved from database
		debug_logger.info("LOOT_CHECK: Item %s found in DB - cost=%s, guildfavor=%s, tradeskills=%s, nodrop=%s, questitem=%s", 
			item_name, 
			tostring(loot_item.item_db.cost), 
			tostring(loot_item.item_db.guildfavor),
			tostring(loot_item.item_db.tradeskills),
			tostring(loot_item.item_db.nodrop),
			tostring(loot_item.item_db.questitem))
end

local item_cost = loot_item and loot_item.item_db and (tonumber(loot_item.item_db.cost) or 0) or 0  -- Packed format (PPPPGGSC)
	local item_guildfavor = loot_item and loot_item.item_db and (tonumber(loot_item.item_db.guildfavor) or 0) or 0
	local is_tradeskill = loot_item and loot_item.item_db and (tonumber(loot_item.item_db.tradeskills) == 1) or false
	local item_stack_size = item and item.StackSize() or 0
	-- CRITICAL: Always prefer database stacksize as it represents the MAX stack size, not current quantity
	-- item.StackSize() returns the current quantity on corpse (1 item = StackSize() of 1)
	-- Database stacksize is the maximum stackable amount (e.g., 1000 for stackable items, 1 for non-stackable)
	local db_stacksize = loot_item and loot_item.item_db and (tonumber(loot_item.item_db.stacksize) or 0) or 0
	if db_stacksize > 0 then
		item_stack_size = db_stacksize
		debug_logger.info("LOOT_CHECK: Using database stacksize=%d for %s (StackSize() was %d)", db_stacksize, item_name, item and item.StackSize() or 0)
	end
	local is_nodrop = loot_item and loot_item.item_db and (loot_item.item_db.nodrop == 1) or false
	
	-- ========================================
	-- SOLO LOOTER PATH: Apply gates without member distribution
	-- ========================================
	if looting.is_solo_looter() then
		debug_logger.info("SOLO_LOOT: Processing item %s in solo mode", item_name)
		
		-- GATE 1: QUEST ITEMS AND TRADESKILL ITEMS (SOLO)
		local is_quest_item = quest_interface.is_quest_item(item_name)
		
		if is_quest_item or is_tradeskill then
			if is_quest_item then
				debug_logger.info("SOLO_GATE_1: %s is a quest item", item_name)
			else
				debug_logger.info("SOLO_GATE_1: %s is a tradeskill item", item_name)
			end
			
		-- Check 1a: Is it a quest item that someone actually needs?
		if is_quest_item then
			local quest_chars = quest_interface.get_quest_characters_local(item_name)
			local someone_needs_it = quest_chars and next(quest_chars) ~= nil
			
			if someone_needs_it then
				debug_logger.info("SOLO_GATE_1_1a: %s is a quest item actively needed - MARK FOR LOOTING", item_name)
				Write.Info("Quest item detected: %s - actively needed for quest - looting", item_name)
				can_loot = true
				preference = { setting = "Keep", data = { quest_item = true, solo = true } }
			else
				debug_logger.info("SOLO_GATE_1_1a: %s is quest-flagged but NOT actively needed - checking value threshold", item_name)
			end
		end			-- If Check 1a didn't pass, check 1b: Is it tradeskill and do we keep tradeskill items?
			if not can_loot then
				local keep_tradeskill = loot and loot.settings and loot.settings.keep_tradeskills
				if is_tradeskill and keep_tradeskill then
					-- Special handling for non-stackable, low-value tradeskill items
					-- Use already-calculated item_stack_size (which includes fallback to db stacksize)
					local is_stackable = item_stack_size > 1
					local item_value_in_pp = math.floor(item_cost / 1000)  -- Convert packed format to platinum
					local is_low_value = item_value_in_pp < 100
					
					debug_logger.info("SOLO_GATE_1_1b: %s tradeskill check - item_stack_size=%d, is_stackable=%s, value=%dpp", 
						item_name, item_stack_size, tostring(is_stackable), item_value_in_pp)
					
					if not is_stackable and is_low_value then
						-- Non-stackable AND low-value: check if there's an explicit preference
						local has_preference = loot.items and loot.items[item_name] ~= nil
						if not has_preference then
							-- Check "collect one sample" feature (per-character setting)
							local collect_one_sample = char_loot and char_loot.settings and char_loot.settings.collect_one_tradeskill_sample
							if collect_one_sample then
								-- Check if we already have one in inventory
								local already_have_one = mq.TLO.FindItem("=" .. item_name)() ~= nil
								if not already_have_one then
									debug_logger.info("SOLO_GATE_1_1b: %s is non-stackable tradeskill (%dpp) - collect_one_sample enabled, don't have one yet - LOOTING", item_name, item_value_in_pp)
									Write.Info("Tradeskill sample: %s - collecting one for recipes (%dpp)", item_name, item_value_in_pp)
									can_loot = true
									preference = { setting = "Keep", data = { tradeskill = true, solo = true, sample = true } }
								else
									debug_logger.info("SOLO_GATE_1_1b: %s is non-stackable tradeskill (%dpp) - collect_one_sample enabled but already have one - LEAVING ON CORPSE", item_name, item_value_in_pp)
									Write.Info("Item %s - already have one sample - leaving on corpse", item_name)
									can_loot = false
									-- Continue to Gate 1c to see if it has other value
								end
							else
								-- No preference rule exists and collect_one_sample disabled - leave it on corpse to save inventory space
								debug_logger.info("SOLO_GATE_1_1b: %s is non-stackable tradeskill worth %dpp - no preference rule - LEAVING ON CORPSE", item_name, item_value_in_pp)
								Write.Info("Item %s - non-stackable tradeskill material (only %dpp) - no preference rule, leaving on corpse", item_name, item_value_in_pp)
								can_loot = false
								-- Continue to Gate 1c to see if it has other value
							end
						else
							-- Has preference rule - follow it
							debug_logger.info("SOLO_GATE_1_1b: %s is non-stackable tradeskill (%dpp) but has preference rule - following preference", item_name, item_value_in_pp)
							Write.Info("Tradeskill item detected: %s - has preference rule, following preference", item_name)
							can_loot = true
							preference = { setting = "Keep", data = { tradeskill = true, solo = true } }
						end
					else
						-- Stackable OR high-value: keep as normal
						debug_logger.info("SOLO_GATE_1_1b: %s is tradeskill material (stackable=%s, value=%dpp) and config says to keep - LOOTING", item_name, tostring(is_stackable), item_value_in_pp)
						Write.Info("Tradeskill item detected: %s - keeping tradeskill material", item_name)
						can_loot = true
						preference = { setting = "Keep", data = { tradeskill = true, solo = true } }
					end
				end
			end
			
		-- If neither 1a nor 1b passed, check 1c: Does it have value?
		if not can_loot then
			-- Apply same value thresholds as Gate 2 (10pp min, stackable required for cost check)
			local valuable_min_price_copper = loot and loot.settings and loot.settings.valuable_item_min_price or 10000  -- 10000 = 10pp in packed format
			local has_valuable_cost_and_stackable = (item_cost >= valuable_min_price_copper) and (item_stack_size > 1)
			local valuable_guildfavor_min = loot and loot.settings and loot.settings.valuable_guildfavor_min or 1000
			local has_valuable_favor = (item_guildfavor >= valuable_guildfavor_min)
			
			if has_valuable_cost_and_stackable or has_valuable_favor then
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("SOLO_GATE_1_1c: %s has value (favor=%d, cost=%dpp, stack=%d) - LOOTING", item_name, item_guildfavor, item_value_pp, item_stack_size)
				Write.Info("Item detected: %s - has value (%dpp)", item_name, item_value_pp)
				can_loot = true
				preference = { setting = "Keep", data = { valuable = true, solo = true } }
			end
		end			-- Check 1d: Final fallback - does this specific item have an explicit preference rule?
			if not can_loot then
				local has_explicit_preference = loot.items and loot.items[item_name] ~= nil
				if has_explicit_preference then
					local item_preference = loot.items[item_name]
					debug_logger.info("SOLO_GATE_1_1d: %s has explicit preference '%s' - FOLLOWING PREFERENCE", item_name, item_preference)
					Write.Info("Item %s - explicit preference found: %s", item_name, item_preference)
					can_loot = true
					preference = { setting = item_preference, data = { explicit = true, solo = true } }
				end
			end
			
			-- If item entered Gate 1 but failed all checks AND has no explicit preference, leave it on corpse
			if not can_loot then
				debug_logger.info("SOLO_GATE_1: %s failed all checks (not needed, not tradeskill config, no value) and has no explicit preference - LEAVING ON CORPSE", item_name)
				Write.Info("Item %s - no reason to keep - leaving on corpse (cost=%d, favor=%d, quest=%s, tradeskill=%s)", 
					item_name, item_cost, item_guildfavor, tostring(is_quest_item), tostring(is_tradeskill))
				looting.leave_item()
				return false, false, nil, { setting = "Leave", data = { solo = true } }
			end
			
			-- If we get here, item passed a check in Gate 1
			debug_logger.info("SOLO_GATE_1: %s passed a check - LOOTING", item_name)
			return can_loot, check_rematch, nil, preference
		else
			-- GATE 2: NON-QUEST, NON-TRADESKILL ITEMS (SOLO)
			debug_logger.info("SOLO_GATE_2: %s is not a quest or tradeskill item", item_name)
			
			-- Check 2a: Value thresholds (same as group)
			local valuable_min_price_copper = loot and loot.settings and loot.settings.valuable_item_min_price or 10000  -- 10000 = 10pp in packed format
			local has_valuable_cost_and_stackable = (item_cost >= valuable_min_price_copper) and (item_stack_size > 1)
			local valuable_guildfavor_min = loot and loot.settings and loot.settings.valuable_guildfavor_min or 1000
			local has_valuable_favor = (item_guildfavor >= valuable_guildfavor_min)
			
			if has_valuable_cost_and_stackable or has_valuable_favor then
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("SOLO_GATE_2_2a: %s has value (cost=%dpp, favor=%d, stack=%d) - LOOTING", item_name, item_value_pp, item_guildfavor, item_stack_size)
				can_loot = true
				preference = { setting = "Keep", data = { valuable_item = true, solo = true } }
				return can_loot, check_rematch, nil, preference
			else
				-- Failed Gate 2 check - item doesn't pass value threshold
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("SOLO_GATE_2: %s failed value check (cost=%dpp, favor=%d, stack=%d, min=%dpp) - LEAVING ON CORPSE", item_name, item_value_pp, item_guildfavor, item_stack_size, math.floor(valuable_min_price_copper / 100))
				Write.Info("Item %s - insufficient value to keep (cost=%dpp, favor=%d, min=%dpp) - leaving on corpse", item_name, item_value_pp, item_guildfavor, math.floor(valuable_min_price_copper / 100))
				looting.leave_item()
				return false, false, nil, { setting = "Leave", data = { solo = true } }
			end
		end
	end
	
	-- ========================================
	-- GATE 1: QUEST ITEMS AND TRADESKILL ITEMS (GROUP/ML PATH)
	-- ========================================
	local is_quest_item = quest_interface.is_quest_item(item_name)
	
	if is_quest_item or is_tradeskill then
		if is_quest_item then
			debug_logger.info("GATE_1: %s is a quest item", item_name)
		else
			debug_logger.info("GATE_1: %s is a tradeskill item", item_name)
		end
		
		-- Check 1a: Is anyone needing it for a quest? (only for quest items)
		if is_quest_item then
			local needed_by = quest_interface.get_characters_needing_item(item_name)
			if needed_by and #needed_by > 0 then
				debug_logger.info("GATE_1_1a: %s is needed for quests by [%s] - MARK FOR LOOTING", item_name, table.concat(needed_by, ", "))
				Write.Info("Quest item detected: %s - needed by quest", item_name)
				can_loot = true
				preference = { setting = "Keep", data = { quest_item = true, needed_by = needed_by } }
				-- Continue to normal logic to find a member
			end
		end
		
		-- If Check 1a didn't pass, check 1b: Is it tradeskill and do we keep tradeskill items?
		if not can_loot then
			local keep_tradeskill = loot and loot.settings and loot.settings.keep_tradeskills
			if is_tradeskill and keep_tradeskill then
				-- Special handling for non-stackable, low-value tradeskill items
				local is_stackable = item_stack_size > 1
				local item_value_in_pp = math.floor(item_cost / 1000)  -- Convert packed format to platinum
				local is_low_value = item_value_in_pp < 100
				
				if not is_stackable and is_low_value then
					-- Non-stackable AND low-value: check if there's an explicit preference
					local has_preference = loot.items and loot.items[item_name] ~= nil
					if not has_preference then
						-- Check "collect one sample" feature (per-character setting)
						local collect_one_sample = char_loot and char_loot.settings and char_loot.settings.collect_one_tradeskill_sample
						if collect_one_sample then
							-- Check if we already have one in inventory
							local already_have_one = mq.TLO.FindItem("=" .. item_name)() ~= nil
							if not already_have_one then
								debug_logger.info("GATE_1_1b: %s is non-stackable tradeskill (%dpp) - collect_one_sample enabled, don't have one yet - LOOTING", item_name, item_value_in_pp)
								Write.Info("Tradeskill sample: %s - collecting one for recipes (%dpp)", item_name, item_value_in_pp)
								can_loot = true
								preference = { setting = "Keep", data = { tradeskill = true, sample = true } }
								-- Continue to normal logic to find a member
							else
								debug_logger.info("GATE_1_1b: %s is non-stackable tradeskill (%dpp) - collect_one_sample enabled but already have one - LEAVING ON CORPSE", item_name, item_value_in_pp)
								Write.Info("Item %s - already have one sample - leaving on corpse", item_name)
								can_loot = false
								-- Continue to Gate 1c to see if it has other value
							end
						else
							-- No preference rule exists and collect_one_sample disabled - leave it on corpse to save inventory space
							debug_logger.info("GATE_1_1b: %s is non-stackable tradeskill worth %dpp - no preference rule - LEAVING ON CORPSE", item_name, item_value_in_pp)
							Write.Info("Item %s - non-stackable tradeskill material (only %dpp) - no preference rule, leaving on corpse", item_name, item_value_in_pp)
							can_loot = false
							-- Continue to Gate 1c to see if it has other value
						end
					else
						-- Has preference rule - follow it
						debug_logger.info("GATE_1_1b: %s is non-stackable tradeskill (%dpp) but has preference rule - following preference", item_name, item_value_in_pp)
						Write.Info("Tradeskill item detected: %s - has preference rule, following preference", item_name)
						can_loot = true
						preference = { setting = "Keep", data = { tradeskill = true } }
					end
				else
					-- Stackable OR high-value: keep as normal
					debug_logger.info("GATE_1_1b: %s is tradeskill material (stackable=%s, value=%dpp) and config says to keep - LOOTING", item_name, tostring(is_stackable), item_value_in_pp)
					Write.Info("Tradeskill item detected: %s - keeping tradeskill material", item_name)
					can_loot = true
					preference = { setting = "Keep", data = { tradeskill = true } }
				end
			end
		end
		
		-- If neither 1a nor 1b passed, check 1c: Does it have value?
		if not can_loot then
			-- Apply same value thresholds as Gate 2 (10pp min, stackable required for cost check)
			local valuable_min_price_copper = loot and loot.settings and loot.settings.valuable_item_min_price or 10000  -- 10000 = 10pp in packed format
			local has_valuable_cost_and_stackable = (item_cost >= valuable_min_price_copper) and (item_stack_size > 1)
			local valuable_guildfavor_min = loot and loot.settings and loot.settings.valuable_guildfavor_min or 1000
			local has_valuable_favor = (item_guildfavor >= valuable_guildfavor_min)
			
			if has_valuable_cost_and_stackable or has_valuable_favor then
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("GATE_1_1c: %s has value (favor=%d, cost=%dpp, stack=%d) - LOOTING", item_name, item_guildfavor, item_value_pp, item_stack_size)
				Write.Info("Item detected: %s - has value (%dpp)", item_name, item_value_pp)
				can_loot = true
				preference = { setting = "Keep", data = { valuable = true } }
				-- Continue to normal logic to find a member
			end
		end
		
		-- Check 1d: Final fallback - does this specific item have an explicit preference rule?
		if not can_loot then
			local has_explicit_preference = loot.items and loot.items[item_name] ~= nil
			if has_explicit_preference then
				local item_preference = loot.items[item_name]
				debug_logger.info("GATE_1_1d: %s has explicit preference '%s' - FOLLOWING PREFERENCE", item_name, item_preference)
				Write.Info("Item %s - explicit preference found: %s", item_name, item_preference)
				can_loot = true
				preference = { setting = item_preference, data = { explicit = true } }
			end
		end

		-- If item entered Gate 1 but failed all checks AND has no explicit preference, leave it on corpse
		if not can_loot then
			debug_logger.info("GATE_1: %s failed all checks (not needed, not tradeskill config, no value) and has no explicit preference - LEAVING ON CORPSE", item_name)
			debug_logger.info("GATE_1_DETAIL: %s - is_quest=%s, is_tradeskill=%s (config=%s), has_value=%s (cost=%d, favor=%d)", 
				item_name, 
				tostring(is_quest_item), 
				tostring(is_tradeskill),
				tostring(loot and loot.settings and loot.settings.keep_tradeskills),
				tostring((item_guildfavor > 0) or (item_cost > 0)),
				item_cost,
				item_guildfavor)
			Write.Info("Item %s - no reason to keep - leaving on corpse (cost=%d, favor=%d, quest=%s, tradeskill=%s)", 
				item_name, item_cost, item_guildfavor, tostring(is_quest_item), tostring(is_tradeskill))
			looting.leave_item()
			return false, false, nil, { setting = "Leave" }
		end
		
		-- If we get here, item passed a check in Gate 1 - continue to normal member evaluation
		debug_logger.info("GATE_1: %s passed a check - continuing to normal member evaluation", item_name)
	else
		-- ========================================
		-- COLLECTIBLE CHECK: Before GATE_2 value checks
		-- ========================================
		-- Collectibles bypass GATE_2 entirely and use one-per-character distribution
		if loot_item and loot_item.item_db and loot_item.item_db.collectible and tonumber(loot_item.item_db.collectible) == 1 then
			debug_logger.info("COLLECTIBLE_GATE: %s is a collectible - bypassing GATE_2, using one-per-character distribution", item_name)
			Write.Info("Collectible item detected: %s - distributing one per character", item_name)
			
			local group_or_raid_tlo = looting.get_group_or_raid_tlo()
			local count = looting.get_member_count(group_or_raid_tlo)
			local found_recipient = false
			
			-- Find first character who doesn't have one
			for i = 0, count - 1 do
				local test_member = looting.get_valid_member(group_or_raid_tlo, i)
				if test_member then
					local member_name = test_member.CleanName()
					
					-- Check if this member already has the item (via DanNet query)
					local has_item = false
					local query_result = mq.TLO.DanNet(member_name).Observe("FindItem[=\"" .. item_name .. "\"]")()
					if query_result and query_result ~= "NULL" then
						has_item = true
						debug_logger.info("COLLECTIBLE_CHECK: %s already has %s", member_name, item_name)
					else
						debug_logger.info("COLLECTIBLE_CHECK: %s does NOT have %s", member_name, item_name)
					end
					
					if not has_item then
						Write.Info("COLLECTIBLE: Giving %s to %s (doesn't have one yet)", item_name, member_name)
						debug_logger.info("COLLECTIBLE_DISTRIBUTION: Giving %s to %s", item_name, member_name)
						looting.give_item(test_member, item_name)
						mq.delay(dannet_delay or 1000)
						return true, false, test_member, { setting = "Keep", data = { collectible = true } }
					end
				end
			end
			
		-- If everyone has one, leave on corpse
		Write.Info("COLLECTIBLE: Everyone has %s - leaving on corpse", item_name)
		debug_logger.info("COLLECTIBLE_DISTRIBUTION: All characters have %s - leaving on corpse", item_name)
		looting.leave_item()
		return false, false, nil, { setting = "Leave", data = { collectible_complete = true } }
	end
	
	-- ========================================
	-- ARMOR SET CHECK: Before GATE_2 value checks
	-- ========================================
	-- Check if this is an armor set item BEFORE value evaluation
	-- Armor set items bypass GATE_2 entirely (many have 0 vendor value)
	local armor_set_early, piece_type_early, item_tier_early = equipment_dist.identify_armor_item(item.Name())
	if armor_set_early and piece_type_early then
		debug_logger.info("ARMOR_GATE_EARLY: %s identified as %s / %s (tier %s) - bypassing GATE_2", 
			item_name, armor_set_early, piece_type_early, item_tier_early or 'UNKNOWN')
		-- Set flag to skip later armor check and continue to armor distribution logic
		can_loot = true
		preference = { setting = "Keep", data = { armor_set = true } }
	end
	
	-- ========================================
	-- GATE 2: NON-QUEST, NON-TRADESKILL ITEMS (No-Drop / Stack / Value)
	-- ========================================
	-- SKIP if item is already identified as armor set item
	if not (armor_set_early and piece_type_early) then
		debug_logger.info("GATE_2: %s is not a quest or tradeskill item", item_name)		-- Check 2a: Value thresholds (different rules for cost vs guild favor)
		-- Cost: >= 10pp (10000 in packed format) AND stackable = Keep
		-- Guild Favor: >= 1000 = Keep (regardless of stackable)
		-- NOTE: item_cost is in packed format (PPPPGGSC), valuable_min_price threshold is also in packed format
		local valuable_min_price_copper = loot and loot.settings and loot.settings.valuable_item_min_price or 10000  -- 10000 = 10pp in packed format
		local has_valuable_cost_and_stackable = (item_cost >= valuable_min_price_copper) and (item_stack_size > 1)
		local valuable_guildfavor_min = loot and loot.settings and loot.settings.valuable_guildfavor_min or 1000
		local has_valuable_favor = (item_guildfavor >= valuable_guildfavor_min)
		local is_stackable = (item_stack_size > 1)
		
		local valuable_min_price_pp = math.floor(valuable_min_price_copper / 1000)
		debug_logger.info("GATE_2_VALUE_CHECK: %s - cost=%d(packed) >= %d(packed=%dpp)? %s, stack=%d > 1? %s, favor=%d >= %d? %s", 
			item_name, item_cost, valuable_min_price_copper, valuable_min_price_pp, tostring(item_cost >= valuable_min_price_copper),
			item_stack_size, tostring(item_stack_size > 1),
			item_guildfavor, valuable_guildfavor_min, tostring(item_guildfavor >= valuable_guildfavor_min))
		
		if has_valuable_cost_and_stackable or has_valuable_favor then
			local item_value_pp = math.floor(item_cost / 1000)
			debug_logger.info("GATE_2_2a: %s has value (cost=%dpp, favor=%d, stack=%d) - LOOTING", item_name, item_value_pp, item_guildfavor, item_stack_size)
			can_loot = true
			preference = { setting = "Keep", data = { valuable_item = true } }
			-- Continue to normal logic to find a member
		else
			-- Failed Gate 2 check: no value
			if is_nodrop and not is_stackable then
				-- NO DROP non-stackable with no value - definitely ignore
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("GATE_2: %s is no-drop non-stackable with low value (cost=%dpp, favor=%d) - will use IGNORE default", item_name, item_value_pp, item_guildfavor)
				always_loot = false
				preference = { setting = "Ignore" }
			else
				-- Not NO DROP, or stackable, but still has no value - leave on corpse
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("GATE_2: %s has no value (cost=%dpp, favor=%d, nodrop=%d, stack=%d) - LEAVING ON CORPSE", 
					item_name, item_value_pp, item_guildfavor, is_nodrop and 1 or 0, item_stack_size)
				Write.Info("Item %s - no value - leaving on corpse (cost=%dpp, favor=%d)", item_name, item_value_pp, item_guildfavor)
				looting.leave_item()
				return
			end
		end
	end  -- End of GATE_2 check
	end  -- End of armor_set_early bypass check
	
	-- ========================================
	-- LOW-LEVEL EQUIPMENT FILTER: Reject obviously outdated equipment
	-- ========================================
	-- Check if this is equipment (wearable) but not valuable enough to keep
	-- This prevents looting trash gear like "Wooden Shield" at high levels
	-- SKIP if item already passed GATE_2 as valuable (high favor/cost)
	local item_slots = loot_item and loot_item.item_db and loot_item.item_db.slots
	local is_equipment = item_slots and tonumber(item_slots) and tonumber(item_slots) > 0
	local already_valuable = preference and preference.data and preference.data.valuable_item
	
	if is_equipment and not already_valuable then
		-- First check: Is it part of a known armor set?
		local pre_armor_set, pre_piece_type, pre_item_tier = equipment_dist.identify_armor_item(item.Name())
		
		if not pre_armor_set then
			-- Unknown equipment - use vendor value as a proxy for quality
			-- Equipment worth less than 10pp is likely trash gear from classic/early expansions
			local equipment_min_value = loot and loot.settings and loot.settings.equipment_min_value or 10
			local equipment_min_value_copper = equipment_min_value * 100  -- Convert pp to copper
			
			if item_cost < equipment_min_value_copper then
				local item_value_pp = math.floor(item_cost / 1000)
				debug_logger.info("EQUIPMENT_FILTER: %s is low-value equipment (%dpp, min=%dpp) - LEAVING ON CORPSE", item_name, item_value_pp, equipment_min_value)
				Write.Info("Item %s - low-level equipment (%dpp) - leaving on corpse", item_name, item_value_pp)
				looting.leave_item()
				return false, false, nil, { setting = "Leave", data = { low_level_equipment = true } }
			end
		end
	elseif is_equipment and already_valuable then
		debug_logger.info("EQUIPMENT_FILTER: %s is equipment but already marked as valuable (GATE_2) - skipping filter", item_name)
	end
	
	-- ========================================
	-- ARMOR GATE: CHECK FOR ARMOR SET ITEMS (PRIORITY OVER PREFERENCES)
	-- ========================================
	-- This must happen BEFORE preference evaluation so armor items are always distributed
	-- according to equipment needs, not global/personal preferences
	-- Re-use early detection if already identified, otherwise check now
	local armor_set, piece_type, item_tier
	if armor_set_early and piece_type_early then
		armor_set, piece_type, item_tier = armor_set_early, piece_type_early, item_tier_early
		debug_logger.info("ARMOR_GATE: Using early detection - %s is %s / %s (tier %s)", 
			item_name, armor_set, piece_type, item_tier or 'UNKNOWN')
	else
		debug_logger.info("ARMOR_GATE: Checking if %s is an armor set item", item_name)
		armor_set, piece_type, item_tier = equipment_dist.identify_armor_item(item.Name())
	end
	
	if armor_set and piece_type then
		debug_logger.info("ARMOR_GATE: %s identified as %s / %s (tier %s) - using equipment-aware distribution", 
			item_name, armor_set, piece_type, item_tier or 'UNKNOWN')
		
		-- Check if this character has a minimum tier requirement set
		if item_tier and char_loot and char_loot.settings and char_loot.settings.min_armor_tier then
			local min_tier = char_loot.settings.min_armor_tier
			if item_tier < min_tier then
				debug_logger.info("ARMOR_GATE: %s tier %d is below minimum tier %d - LEAVING ON CORPSE", 
					item_name, item_tier, min_tier)
				Write.Info("Armor tier filter: %s (tier %d) is below minimum tier %d - leaving on corpse", 
					item_name, item_tier, min_tier)
				looting.leave_item()
				return false, false, nil, { setting = "Leave", data = { armor_tier_filter = true } }
			end
		end
		
		-- Build member list for armor distribution
		local count = looting.get_member_count(group_or_raid_tlo)
		local member_list = {}
		for i = 0, count - 1 do
			local test_member = looting.get_valid_member(group_or_raid_tlo, i)
			if test_member then
				table.insert(member_list, test_member)
			end
		end
		
		-- Find best recipient based on equipment satisfaction score and progression tier
		-- If item_tier is provided, recipients with same/higher tier equipped will be filtered out
		local best_recipient, satisfaction_score = equipment_dist.find_best_recipient(member_list, armor_set, piece_type, item_tier)
		
		if best_recipient then
			-- Find the member object matching the best recipient name
			for _, member_obj in ipairs(member_list) do
				local member_name = type(member_obj) == 'string' and member_obj or (member_obj.Name and member_obj.Name())
				if member_name and member_name == best_recipient then
					debug_logger.info("ARMOR_GATE: Assigning %s to %s (satisfaction: %d)", 
						item_name, best_recipient, satisfaction_score)
					Write.Info("Equipment Distribution: %s → %s (satisfaction: %d)", 
						item_name, best_recipient, satisfaction_score)
					mq.cmd(string.format('/echo [ARMOR_LOOT] ASSIGNED: %s to %s (score: %d)', 
						item_name, best_recipient, satisfaction_score))
					return true, false, member_obj, {
						setting = "Keep",
						data = {
							equipment_dist = true,
							armor_set = armor_set,
							piece_type = piece_type,
							satisfaction_score = satisfaction_score
						}
					}
				end
			end
		else
			-- No recipient found for this armor piece - leave it on corpse
			debug_logger.warn("ARMOR_GATE: No valid recipient found for %s (%s / %s) - LEAVING ON CORPSE", 
				item_name, armor_set, piece_type)
			mq.cmd(string.format('/echo [ARMOR_LOOT] WARNING: No recipient for %s (%s/%s) - LEFT ON CORPSE', 
				item_name, armor_set, piece_type))
			looting.leave_item()
			return false, false, nil, { setting = "Leave" }
		end
	end

	-- NOT A QUEST ITEM: Continue with normal preference-based loot evaluation
	debug_logger.info("LOOT_CHECK: %s continuing to normal loot rules", item_name)

	local count = looting.get_member_count(group_or_raid_tlo)

	-- SMART CLASS PRIORITY: For class-restricted items, try usable classes first
	local is_class_restricted = false
	local usable_members = {}
	local other_members = {}
	
	-- Check if this item has class restrictions
	if loot_item and loot_item.item_db and loot_item.item_db.classes then
		local class_bitmask = tonumber(loot_item.item_db.classes)
		-- If classes field exists and isn't 65535 (all classes), it's class-restricted
		if class_bitmask and class_bitmask ~= 65535 and class_bitmask > 0 then
			is_class_restricted = true
			
			-- Categorize members by whether they can use this item
			for i = 0, count - 1 do
				local test_member = looting.get_valid_member(group_or_raid_tlo, i)
				if test_member then
					local member_name = test_member.Name()
					local member_class = nil
					
					if member_name == mq.TLO.Me.DisplayName() then
						member_class = mq.TLO.Me.Class.ShortName()
					else
						member_class = tostring(dannet.query(member_name, "Me.Class.ShortName", dannet_delay or 100)) or nil
					end
					
					-- Check if this class can use the item
					if member_class and loot_item.Class then
						local class_match = loot_item.Class(member_class)
						if class_match ~= "NULL" then
							table.insert(usable_members, test_member)
						else
							table.insert(other_members, test_member)
						end
					else
						-- If we can't determine class, add to other_members as fallback
						table.insert(other_members, test_member)
					end
				end
			end
			
			Write.Info("Class-restricted item %s: %d usable classes, %d others", 
				item.Name() or "unknown", #usable_members, #other_members)
		end
	end
	
	-- Create priority-ordered member list
	local member_list = {}
	if is_class_restricted then
		-- Add usable classes first, then others as fallback
		for _, member_obj in ipairs(usable_members) do
			table.insert(member_list, member_obj)
		end
		for _, member_obj in ipairs(other_members) do
			table.insert(member_list, member_obj)
		end
	else
		-- Not class-restricted, use normal group order
		for i = 0, count - 1 do
			local test_member = looting.get_valid_member(group_or_raid_tlo, i)
			if test_member then
				table.insert(member_list, test_member)
			end
		end
	end

	-- Note: Equipment Distribution Check has been moved to ARMOR_GATE (above)
	-- so that armor items are processed BEFORE preference evaluation

	for _, test_member in ipairs(member_list) do
		can_loot, check_rematch, preference =
			evaluate.check_can_loot(test_member, item, loot, save_slots, dannet_delay, always_loot, unmatched_item_rule)

		if can_loot then
			selected_member = test_member
			break
		end
	end

	return can_loot, check_rematch, selected_member, preference
end

--- Process retry queue for items that failed can_i_loot() due to race condition
--- Returns: true if an item was processed from retry queue, false otherwise
looting.process_retry_queue = function(global_settings, char_settings)
	if #retry_queue == 0 then
		return false
	end
	
	-- Get current loot count to check if items are still available
	local loot_count_tlo, loot_list_tlo = looting.get_loot_tlos()
	local current_loot_count = mq.TLO.AdvLoot[loot_count_tlo]() or 0
	
	if current_loot_count == 0 then
		-- No items available, clear queue
		debug_logger.info("RETRY_QUEUE: Loot window empty, clearing queue (%d items)", #retry_queue)
		retry_queue = {}
		return false
	end
	
	-- Check if we can loot now
	if not looting.can_i_loot(loot_count_tlo) then
		debug_logger.debug("RETRY_QUEUE: Still can't loot (LootInProgress), waiting...")
		return false
	end
	
	-- Process first item in queue
	local retry_item = table.remove(retry_queue, 1)
	
	debug_logger.info("RETRY_QUEUE: Processing retry item: %s (attempt %d/%d)", 
		retry_item.name, retry_item.attempts + 1, max_retries)
	
	-- Check if this item is still in the loot window
	local found = false
	for i = 1, current_loot_count do
		local item = mq.TLO.AdvLoot[loot_list_tlo](i)
		if item and item.Name() == retry_item.name then
			found = true
			-- Make this item the active one (index 1) by clicking it
			-- Note: This assumes the loot window shows items in order and we can select them
			-- If items can't be manually selected, we'd need a different approach
			debug_logger.info("RETRY_QUEUE: Found %s at index %d, processing...", retry_item.name, i)
			break
		end
	end
	
	if not found then
		debug_logger.info("RETRY_QUEUE: %s no longer in loot window, dropping from queue", retry_item.name)
		return true  -- Item was processed (removed from corpse by someone else)
	end
	
	-- Increment attempt counter
	retry_item.attempts = retry_item.attempts + 1
	
	-- If max retries reached, give up on this item
	if retry_item.attempts >= max_retries then
		debug_logger.warn("RETRY_QUEUE: %s exceeded max retries (%d), giving up", retry_item.name, max_retries)
		Write.Warn("Race condition: \a-t%s\ax could not be processed after %d retries", retry_item.name, max_retries)
		return true  -- Item was "processed" (we gave up on it)
	end
	
	-- Re-add to end of queue for another retry
	table.insert(retry_queue, retry_item)
	debug_logger.debug("RETRY_QUEUE: Re-queued %s for retry (attempt %d/%d)", 
		retry_item.name, retry_item.attempts, max_retries)
	
	-- Wait before next retry
	mq.delay(retry_delay_ms)
	
	return true  -- We processed a queue item (even if just re-queued it)
end

looting.handle_master_looting = function(global_settings, char_settings)
	if not looting.am_i_master_looter() or looting.is_solo_looter() then
		return
	end

	if looting.get_group_or_raid_tlo() == "Raid" and global_settings.settings.do_raid_loot == false then
		return
	end

	local loot_count_tlo, loot_list_tlo = looting.get_loot_tlos()
	local loot_count = mq.TLO.AdvLoot[loot_count_tlo]() or 0

	-- First, try to process retry queue
	if looting.process_retry_queue(global_settings, char_settings) then
		return  -- Processed a retry item, come back next iteration for new items
	end

	-- Check if we can loot
	if not looting.can_i_loot(loot_count_tlo) then
		-- If there are items but we can't loot (LootInProgress), add to retry queue
		if loot_count > 0 then
			local item = mq.TLO.AdvLoot[loot_list_tlo](1)
			local item_name = item and item.Name() or "UNKNOWN"
			
			-- Check if this item is already in retry queue
			local already_queued = false
			for _, queued_item in ipairs(retry_queue) do
				if queued_item.name == item_name then
					already_queued = true
					break
				end
			end
			
			if not already_queued then
				debug_logger.info("RETRY_QUEUE: Adding %s to retry queue (LootInProgress=%s)", 
					item_name, tostring(mq.TLO.AdvLoot.LootInProgress()))
				table.insert(retry_queue, {
					name = item_name,
					attempts = 0,
					timestamp = os.time()
				})
			end
		else
			debug_logger.debug("LOOT_GATE: can_i_loot returned false but loot_count=0")
		end
		return
	end

	local item = mq.TLO.AdvLoot[loot_list_tlo](1)
	local item_name = item.Name()

	if not item_name then
		return
	end

	-- QUEST ITEM CHECK: Check if item is questitem=1 (quest item) before any other processing
	local item_id = item.ID()
	local is_quest_item = nil -- Initialize quest detection result (will be set by database or legacy detection)
	local item_db = nil  -- Initialize item database record (will be populated below)
	debug_logger.info("QUEST_ITEM_CHECK: Starting check for %s, item_id=%s", item_name, tostring(item_id))
	
	if not item_id then
		debug_logger.warn("QUEST_ITEM_CHECK: %s has nil item_id, skipping database quest detection", item_name)
	elseif item_id <= 0 then
		debug_logger.warn("QUEST_ITEM_CHECK: %s has invalid item_id: %d, skipping database quest detection", item_name, item_id)
	end
	
	if item_id and item_id > 0 then
		debug_logger.info("QUEST_ITEM_CHECK: %s has valid ID: %d, attempting database query", item_name, item_id)
		
		local db_success, db_error = pcall(function()
			item_db = YALM2_Database.QueryDatabaseForItemId(item_id)
		end)
		
		if not db_success then
			debug_logger.error("QUEST_ITEM_CHECK: Database query failed for %s (ID: %d): %s", item_name, item_id, tostring(db_error))
			debug_logger.info("QUEST_ITEM_CHECK: Falling back to non-database quest detection for %s", item_name)
		else
			debug_logger.info("QUEST_ITEM_CHECK: %s (ID: %d) Database query result: %s", item_name, item_id, item_db and "found" or "nil")
		end
		if item_db then
			debug_logger.info("QUEST_ITEM_CHECK: %s (ID: %d) DB Fields - questitem: %s, norent: %s, nodrop: %s", 
				item_name, item_id, tostring(item_db.questitem), tostring(item_db.norent), tostring(item_db.nodrop))
		else
			debug_logger.warn("QUEST_ITEM_CHECK: %s (ID: %d) - No database entry found", item_name, item_id)
		end
		is_quest_item = item_db and item_db.questitem == 1  -- Set the quest detection result
		debug_logger.info("QUEST_ITEM_CHECK: %s (ID: %d) Final quest detection logic: item_db=%s, questitem=%s, is_quest=%s", 
			item_name, item_id, item_db and "exists" or "nil", item_db and tostring(item_db.questitem) or "n/a", tostring(is_quest_item))
		
		if is_quest_item then
			debug_logger.info("QUEST_ITEM_DETECTED: %s is a quest item (questitem=1), using quest distribution logic", item_name)
			Write.Info("Quest item detected: %s - using quest-specific distribution", item_name)
			
			-- Get characters who need this quest item
			local needed_by = quest_interface.get_characters_needing_item(item_name)
			debug_logger.info("QUEST_DISTRIBUTION: Characters needing '%s': %s", item_name, 
				needed_by and table.concat(needed_by, ", ") or "none")
			
			if needed_by and #needed_by > 0 then
				-- Find valid group members who need this item
				local group_or_raid_tlo = looting.get_group_or_raid_tlo()
				local count = looting.get_member_count(group_or_raid_tlo)
				local valid_recipients = {}
				
				for _, char_name in ipairs(needed_by) do
					for i = 0, count do
						local test_member = looting.get_valid_member(group_or_raid_tlo, i)
						if test_member and test_member.CleanName():lower() == char_name:lower() then
							table.insert(valid_recipients, test_member)
							break
						end
					end
				end
				
				if #valid_recipients > 0 then
					-- Give to first valid recipient who needs it
					local recipient = valid_recipients[1]
					Write.Info("QUEST DISTRIBUTION: Giving %s to %s (needs quest item)", item_name, recipient.Name())
					debug_logger.info("QUEST_DISTRIBUTION: Giving %s to %s", item_name, recipient.Name())
					looting.give_item(recipient, item_name)
					mq.delay(global_settings.settings.distribute_delay)
					return
				else
					Write.Warn("QUEST ITEM: %s needed by characters not in group: %s", item_name, table.concat(needed_by, ", "))
					debug_logger.warn("QUEST_DISTRIBUTION: No valid recipients in group for %s", item_name)
				end
			else
				debug_logger.info("QUEST_DISTRIBUTION: %s not needed by any characters - checking valuable/tradeskill overrides", item_name)
				
				-- EARLY SKIP: Check overrides immediately before calling get_member_can_loot
				-- This prevents the normal loot logic from evaluating quest items we want to skip
				local has_valuable = false
				local has_tradeskill = false
				
				-- Check if item is valuable based on database price
				-- Use same logic as evaluate.lua: price >= valuable_item_min_price (default 100000)
				if item_db then
					local valuable_min_price = global_settings.settings.valuable_item_min_price or 10000
					local item_price = item_db.price or 0
					has_valuable = (item_price >= valuable_min_price)
					
					if has_valuable then
						debug_logger.info("QUEST_DISTRIBUTION: %s is valuable (price=%d >= %d)", item_name, item_price, math.floor(valuable_min_price_copper / 100))
					end
				end
				
				-- Also check if it's a tradeskill material
				if item_db and not has_valuable then
					has_tradeskill = (item_db.tradeskills == 1)
					if has_tradeskill then
						debug_logger.info("QUEST_DISTRIBUTION: %s is tradeskill material (tradeskills=1)", item_name)
					end
				end
				
				if not (has_valuable or has_tradeskill) then
					Write.Info("QUEST ITEM SKIPPED: %s - not needed and no valuable/tradeskill override", item_name)
					debug_logger.info("QUEST_DISTRIBUTION: %s not needed and no overrides - leaving on corpse", item_name)
					looting.leave_item()
					return  -- Skip this item entirely, don't fall back to normal processing
				else
					debug_logger.info("QUEST_DISTRIBUTION: %s not needed but has override (valuable=%s, tradeskill=%s) - will process normally",
						item_name, tostring(has_valuable), tostring(has_tradeskill))
					-- Continue to normal loot processing below
				end
			end
			
			-- If we get here with a quest item that has no one needing it,
			-- it must have valuable_quest_item or tradeskill override, so process normally
			debug_logger.info("QUEST_DISTRIBUTION: Falling back to normal processing for %s", item_name)
		end
	end
	
	-- ========================================
	-- MEMBER EVALUATION: Find who can loot this item
	-- ========================================
	-- Note: Collectibles were already handled earlier (before GATE_2)
	local can_loot, check_rematch, member, preference = looting.get_member_can_loot(
		item,
		global_settings,
		char_settings and char_settings.loot or {},
		global_settings.settings.save_slots,
		global_settings.settings.dannet_delay,
		false,
		global_settings.settings.unmatched_item_rule
	)

	-- Debug for quest items - check if this item has quest data
	local needed_by = quest_interface.get_characters_needing_item(item_name)
	local task_name, objective = nil, nil
	
	-- IMPORTANT: Don't override database quest detection result if it already determined this is a quest item
	-- Only use legacy detection if database detection wasn't available or didn't find quest status
	local legacy_quest_detection = (needed_by and #needed_by > 0)
	-- is_quest_item was already set by database detection above, only override if it wasn't set to true
	if not is_quest_item then
		is_quest_item = legacy_quest_detection
	end
	
	debug_logger.info("QUEST_DETECTION_COMPARISON: %s - Database: %s, Legacy: %s, Final: %s", 
		item_name, 
		tostring(is_quest_item and not legacy_quest_detection), -- true if database detected but legacy didn't
		tostring(legacy_quest_detection), 
		tostring(is_quest_item))
	
	if is_quest_item then
		debug_logger.debug("Quest item loot check - can_loot: %s, preference: %s, member: %s", 
			tostring(can_loot), preference and preference.setting or "nil", member and member.CleanName() or "nil")
		
		-- Debug quest preference details
		if preference then
			debug_logger.debug("Quest preference - list=[%s], data=%s", 
				preference.list and table.concat(preference.list, ", ") or "empty/nil",
				preference.data and "exists" or "nil"
			)
			if preference.data then
				debug_logger.debug("Quest data - quest_item=%s, task_name='%s'",
					tostring(preference.data.quest_item),
					preference.data.task_name or "nil"
				)
			end
			
			-- Vexxuss group member check disabled
		end
		
		-- DIRECT TEST: Check if quest logic is accessible
		if quest_interface and quest_interface.get_characters_needing_item then
			local needed_by, task_name, objective = quest_interface.get_characters_needing_item("Blighted Blood Sample")
			debug_logger.debug("Quest characters check - needed_by=[%s], task_name='%s'", 
				needed_by and table.concat(needed_by, ", ") or "nil",
				task_name or "nil"
			)
			
			-- HOTFIX: Manually override preference for quest items ONLY
			if needed_by and #needed_by > 0 then
				debug_logger.debug("Overriding preference with quest characters for %s", item_name)
				
				-- Find valid group members who need this item
				local group_or_raid_tlo = mq.TLO.Raid.Members() > 0 and "Raid" or "Group"
				local count = mq.TLO[group_or_raid_tlo].Members() or 0
				local valid_recipients = {}
				
				for _, char_name in ipairs(needed_by) do
					for i = 0, count do
						local test_member = looting.get_valid_member(group_or_raid_tlo, i)
						if test_member and test_member.CleanName():lower() == char_name:lower() then
							table.insert(valid_recipients, char_name)
							break
						end
					end
				end
				
				if #valid_recipients > 0 then
					-- CREATE NEW preference object for quest characters (don't modify existing one)
					local quest_preference = {
						setting = "Keep",
						list = valid_recipients,
						data = { quest_item = true, task_name = task_name }
					}
					
					-- Replace the preference with the new quest-specific one
					preference = quest_preference
					
					Write.Error("*** QUEST HOTFIX: Created NEW preference list [%s] ***", table.concat(valid_recipients, ", "))
					
					-- Request quest data refresh after quest item distribution
					-- This ensures we have current data for the next quest item
					Write.Error("*** QUEST REFRESH: Requesting task update after quest item ***")
					
					-- Wait for and validate the refresh to prevent stale quest data
					local refresh_success = false
					local max_retries = 3
					local retry_count = 0
					
					while not refresh_success and retry_count < max_retries do
						retry_count = retry_count + 1
						Write.Error("*** QUEST REFRESH: Attempt %d/%d ***", retry_count, max_retries)
						
						-- Native system auto-refreshes, no manual update needed
						
						-- Wait for response (TaskHUD usually responds within 1-2 seconds)
						mq.delay(2000)
						
						-- Validate that we got updated quest data
						if _G.YALM2_QUEST_DATA then
							Write.Error("*** QUEST REFRESH: Success on attempt %d ***", retry_count)
							refresh_success = true
						else
							Write.Warn("*** QUEST REFRESH: Failed attempt %d, TaskHUD did not respond ***", retry_count)
							if retry_count < max_retries then
								Write.Info("*** QUEST REFRESH: Retrying in 1 second... ***")
								mq.delay(1000)
							end
						end
					end
					
					if not refresh_success then
						Write.Error("*** QUEST REFRESH: All attempts failed! Quest data may be stale ***")
						Write.Warn("*** Continuing with potentially stale quest data - manual /yalm2 taskinfo refresh recommended ***")
					else
						-- Re-check quest data after successful refresh to see if anyone still needs this item type
						local updated_needed_by, updated_task_name, updated_objective = quest_interface.get_characters_needing_item(item_name)
						if updated_needed_by and #updated_needed_by > 0 then
							Write.Error("*** QUEST REFRESH: After update, %s still needed by [%s] ***", item_name, table.concat(updated_needed_by, ", "))
							
							-- Update the preference list with current characters who still need it
							local updated_valid_recipients = {}
							for _, char_name in ipairs(updated_needed_by) do
								for i = 0, count do
									local test_member = looting.get_valid_member(group_or_raid_tlo, i)
									if test_member and test_member.CleanName():lower() == char_name:lower() then
										table.insert(updated_valid_recipients, char_name)
										break
									end
								end
							end
							
							if #updated_valid_recipients > 0 then
								-- Update the quest preference with current recipients
								preference.list = updated_valid_recipients
								Write.Error("*** QUEST REFRESH: Updated recipient list to [%s] ***", table.concat(updated_valid_recipients, ", "))
							else
								-- No valid group members need it anymore, ignore the item
								Write.Error("*** QUEST REFRESH: No valid group members need %s, changing to Ignore ***", item_name)
								preference = { setting = "Ignore", list = {}, data = { quest_item_completed = true } }
							end
						else
							Write.Error("*** QUEST REFRESH: After update, no one needs %s anymore ***", item_name)
							-- Change preference to ignore since no one needs this quest item
							Write.Error("*** QUEST REFRESH: Changing %s preference to Ignore ***", item_name)
							preference = { setting = "Ignore", list = {}, data = { quest_item_completed = true } }
						end
					end
				end
			end
		else
			debug_logger.debug("Quest interface not available for quest check")
		end
	end

	if not can_loot and check_rematch and global_settings.settings.always_loot and preference then
		Write.Warn("No one matched \a-t%s\ax loot preference", item_name)
		Write.Warn("Trying again ignoring quantity and list")

		can_loot, check_rematch, member, preference = looting.get_member_can_loot(
			item,
			global_settings,
			char_settings and char_settings.loot or {},
			global_settings.settings.save_slots,
			global_settings.settings.dannet_delay,
			global_settings.settings.always_loot,
			global_settings.settings.unmatched_item_rule
		)
	end

	if not can_loot or not preference then
		Write.Warn("No loot preference found for \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		looting.wait_for_loot_clear(item_name)
		return
	end

	if not evaluate.is_valid_preference(global_settings.preferences, preference) then
		Write.Warn("Invalid loot preference for \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		looting.wait_for_loot_clear(item_name)
		return
	end

	if global_settings.preferences[preference.setting].leave then
		Write.Info("Loot preference set to \aoleave\ax for \a-t%s\ax", item_name)
		looting.leave_item()
		looting.wait_for_loot_clear(item_name)
		return
	end

	Write.Info("\a-t%s\ax KEPT - %s", item_name, looting.get_keep_reason(preference))

	if not can_loot or not member then
		Write.Warn("No one is able to loot \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		looting.wait_for_loot_clear(item_name)
		return
	end

	-- FINAL INVENTORY CHECK: Verify member has space before giving item
	-- This catches cases where tradeskill-only bags have open slots but can't hold the item
	if item_name == mq.TLO.AdvLoot[loot_list_tlo](1).Name() then
		local member_name = member.Name()
		local item_id = mq.TLO.AdvLoot[loot_list_tlo](1).ID()
		
		-- For remote characters, verify they have actual available slots for this item
		if member_name ~= mq.TLO.Me.CleanName() then
			-- Query remote inventory
			local available_slots = inventory.count_available_slots_for_item_remote(
				member_name, 
				item_id, 
				global_settings.settings.dannet_delay
			)
			
			if available_slots == 0 then
				Write.Warn("INVENTORY FULL: %s cannot hold \a-t%s\ax - inventory full or no compatible bag slots", member_name, item_name)
				debug_logger.warn("INVENTORY_CHECK: %s has 0 available slots for %s (ID: %d) - LEAVING ON CORPSE", 
					member_name, item_name, item_id)
				looting.leave_item()
				looting.wait_for_loot_clear(item_name)
				return
			else
				debug_logger.info("INVENTORY_CHECK: %s has %d available slots for %s - proceeding with distribution", 
					member_name, available_slots, item_name)
			end
		end
		
		Write.Info("Looting \a-t%s\ax → \ao%s\ax", item_name, member_name)
		looting.give_item(member, item_name)

		mq.delay(global_settings.settings.distribute_delay)
		
		-- Wait for LootInProgress to clear so next item can be processed
		looting.wait_for_loot_clear(item_name)
	end
end

looting.handle_solo_looting = function(global_settings, char_settings)
	if not looting.is_solo_looter() then
		return
	end

	local loot_count_tlo, loot_list_tlo = looting.get_loot_tlos()
	local loot_count = mq.TLO.AdvLoot[loot_count_tlo]() or 0

	-- First, try to process retry queue
	if looting.process_retry_queue(global_settings, char_settings) then
		return  -- Processed a retry item, come back next iteration for new items
	end

	-- Check if we can loot
	if not looting.can_i_loot(loot_count_tlo) then
		-- If there are items but we can't loot (LootInProgress), add to retry queue
		if loot_count > 0 then
			local item = mq.TLO.AdvLoot[loot_list_tlo](1)
			local item_name = item and item.Name() or "UNKNOWN"
			
			-- Check if this item is already in retry queue
			local already_queued = false
			for _, queued_item in ipairs(retry_queue) do
				if queued_item.name == item_name then
					already_queued = true
					break
				end
			end
			
			if not already_queued then
				debug_logger.debug("RETRY_QUEUE: (SOLO) Adding %s to retry queue", item_name)
				table.insert(retry_queue, {
					name = item_name,
					attempts = 0,
					timestamp = os.time()
				})
			end
		end
		return
	end

	local item = mq.TLO.AdvLoot[loot_list_tlo](1)
	local item_name = item.Name()

	if item == "NULL" or not item_name then
		return
	end

	local member = mq.TLO.Me
	local can_loot, _, preference = evaluate.check_can_loot(
		member,
		item,
		global_settings,
		global_settings.settings.save_slots,
		global_settings.settings.dannet_delay,
		global_settings.settings.always_loot,
		global_settings.settings.unmatched_item_rule
	)

	if not can_loot or not preference then
		Write.Warn("No loot preference found for \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		return
	end

	if not evaluate.is_valid_preference(global_settings.preferences, preference) then
		Write.Warn("Invalid loot preference for \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		return
	end

	if global_settings.preferences[preference.setting].leave then
		Write.Info("Loot preference set to \aoleave\ax for \a-t%s\ax", item_name)
		looting.leave_item()
		return
	end

	Write.Info("\a-t%s\ax KEPT - %s", item_name, looting.get_keep_reason(preference))

	if not can_loot then
		Write.Warn("You are unable to loot \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		return
	end

	if item_name == mq.TLO.AdvLoot.PList(1).Name() then
		Write.Info("Looting \a-t%s\ax", item_name)
		looting.loot_item()

		mq.delay(global_settings.settings.distribute_delay)

		inventory.check_lore_equip_prompt()
	end
end

looting.handle_personal_loot = function()
	if looting.is_solo_looter() then
		return
	end

	if not looting.can_i_loot("PCount") then
		return
	end

	local item = mq.TLO.AdvLoot.PList(1)
	local item_name = item.Name()

	if item == "NULL" or not item_name then
		return
	end

	Write.Info("Looting \a-t%s\ax", item_name)
	looting.loot_item()

	inventory.check_lore_equip_prompt()
end

return looting

