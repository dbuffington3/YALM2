---@type Mq
local mq = require("mq")

local evaluate = require("yalm2.core.evaluate")
local inventory = require("yalm2.core.inventory")
local tasks = require("yalm2.core.tasks")
local quest_interface = require("yalm2.core.quest_interface")

local dannet = require("yalm2.lib.dannet")
local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")
local quest_db = require("yalm2.lib.quest_database")
require("yalm2.lib.database")  -- Initialize the global Database table

local looting = {}

--- Helper function to generate descriptive "why kept" message
looting.get_keep_reason = function(preference)
	if not preference then
		return "unknown reason"
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
	
	-- Update the quest database to reflect this character received an item
	-- Increment their quest progress immediately (e.g., 0/2 → 1/2)
	-- This way the ML knows the distribution state without waiting for refresh
	if item_name and quest_interface.is_quest_item(item_name) then
		local result = quest_db.increment_quantity_received(character_name, item_name)
		if result and result.success then
			debug_logger.quest("QUEST_DB: Incremented %s's %s status to %s", character_name, item_name, result.status)
			
			-- Broadcast the quest item update to the UI so it can refresh just that one row
			-- without needing a full character task refresh
			mq.docommand(string.format("/danknet -k quest_ml_update -- QUEST_ITEM_GIVEN|%s|%s|%s", 
				character_name, item_name, result.status))
		end
	end
	
	-- If this was a quest item, refresh the recipient's task data
	if item_name and quest_interface.is_quest_item(item_name) then
		debug_logger.quest("QUEST_LOOT: %s received quest item %s - triggering character refresh", character_name, item_name)
		
		-- Trigger character-specific task refresh after loot distribution
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

looting.get_member_can_loot = function(item, loot, save_slots, dannet_delay, always_loot, unmatched_item_rule)
	local group_or_raid_tlo = looting.get_group_or_raid_tlo()

	local can_loot, check_rematch, member, preference = false, true, nil, nil

	-- QUEST ITEM HANDLING: Check if this is a quest item and handle it separately
	local item_name = item and item.Name() or "unknown"
	debug_logger.info("LOOT_CHECK: Processing item: %s", item_name)
	
	-- Check if this is a quest item
	local is_quest_item = quest_interface.is_quest_item(item_name)
	
	if is_quest_item then
		-- Check if anyone needs this item for a quest
		local needed_by = quest_interface.get_characters_needing_item(item_name)
		
		if needed_by and #needed_by > 0 then
			debug_logger.info("QUEST_ITEM: %s is needed for quests by [%s]", item_name, table.concat(needed_by, ", "))
			Write.Info("Quest item detected: %s - using quest distribution logic", item_name)
			
			-- Distribute to the first character who needs it
			local recipient = mq.TLO.Group.Member(needed_by[1])
			if recipient then
				looting.give_item(recipient, item_name)
			end
		else
			-- Quest item but not needed by anyone - skip it immediately
			debug_logger.info("QUEST_ITEM: %s is a quest item but not needed by anyone - leaving on corpse", item_name)
			Write.Info("Quest item %s not needed - leaving on corpse", item_name)
			looting.leave_item()
		end
		return
	end
	
	-- NOT A QUEST ITEM: Continue with normal preference-based loot evaluation
	debug_logger.info("LOOT_CHECK: %s is not a quest item - using normal loot rules", item_name)

	local count = looting.get_member_count(group_or_raid_tlo)

	-- SMART CLASS PRIORITY: For class-restricted items, try usable classes first
	local loot_item = evaluate.get_loot_item(item)
	local is_class_restricted = false
	local usable_members = {}
	local other_members = {}
	
	-- Check if this item has class restrictions
	if loot_item and loot_item.item_db and loot_item.item_db.classes then
		local class_bitmask = loot_item.item_db.classes
		-- If classes field exists and isn't 65535 (all classes), it's class-restricted
		if class_bitmask and class_bitmask ~= 65535 and class_bitmask > 0 then
			is_class_restricted = true
			
			-- Categorize members by whether they can use this item
			for i = 0, count do
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
		for i = 0, count do
			local test_member = looting.get_valid_member(group_or_raid_tlo, i)
			if test_member then
				table.insert(member_list, test_member)
			end
		end
	end

	-- Evaluate members in priority order
	local selected_member = nil
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

looting.handle_master_looting = function(global_settings)
	if not looting.am_i_master_looter() or looting.is_solo_looter() then
		return
	end

	if looting.get_group_or_raid_tlo() == "Raid" and global_settings.settings.do_raid_loot == false then
		return
	end

	local loot_count_tlo, loot_list_tlo = looting.get_loot_tlos()

	if not looting.can_i_loot(loot_count_tlo) then
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
	debug_logger.info("QUEST_ITEM_CHECK: Starting check for %s, item_id=%s", item_name, tostring(item_id))
	
	if not item_id then
		debug_logger.warn("QUEST_ITEM_CHECK: %s has nil item_id, skipping database quest detection", item_name)
	elseif item_id <= 0 then
		debug_logger.warn("QUEST_ITEM_CHECK: %s has invalid item_id: %d, skipping database quest detection", item_name, item_id)
	end
	
	if item_id and item_id > 0 then
		debug_logger.info("QUEST_ITEM_CHECK: %s has valid ID: %d, attempting database query", item_name, item_id)
		
		local item_db = nil
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
				Write.Info("QUEST ITEM SKIPPED: %s - not needed by any characters (checking if valuable or tradeskill)", item_name)
				debug_logger.info("QUEST_DISTRIBUTION: %s not needed by any characters", item_name)
			end
			
			-- If we get here, no quest distribution occurred, fall through to normal processing
			debug_logger.info("QUEST_DISTRIBUTION: Falling back to normal processing for %s", item_name)
		end
	end

	local can_loot, check_rematch, member, preference = looting.get_member_can_loot(
		item,
		global_settings,
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

	if not can_loot or not member then
		Write.Warn("No one is able to loot \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		return
	end

	if item_name == mq.TLO.AdvLoot[loot_list_tlo](1).Name() then
		Write.Info("Looting \a-t%s\ax → \ao%s\ax", item_name, member.Name())
		looting.give_item(member, item_name)

		mq.delay(global_settings.settings.distribute_delay)
	end
end

looting.handle_solo_looting = function(global_settings)
	if not looting.is_solo_looter() then
		return
	end

	local loot_count_tlo, loot_list_tlo = looting.get_loot_tlos()

	if not looting.can_i_loot(loot_count_tlo) then
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
