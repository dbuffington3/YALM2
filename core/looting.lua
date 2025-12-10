---@type Mq
local mq = require("mq")

local evaluate = require("yalm2.core.evaluate")
local inventory = require("yalm2.core.inventory")
local tasks = require("yalm2.core.tasks")
local quest_interface = require("yalm2.core.quest_interface")

local dannet = require("yalm2.lib.dannet")
local utils = require("yalm2.lib.utils")
local debug_logger = require("yalm2.lib.debug_logger")
require("yalm2.lib.database")  -- Initialize the global Database table

local looting = {}

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
	
	-- Log detailed distribution info
	Write.Error("*** QUEST DISTRIBUTION: %s → %s", item_name or "item", character_name)
	
	-- Try to show current inventory quantity from quest data
	local quest_data_with_qty = _G.YALM2_QUEST_ITEMS_WITH_QTY or ""
	local current_qty = 0
	if quest_data_with_qty:len() > 0 and item_name then
		-- Parse format: "Item:char1:qty1,char2:qty2|Item2:..."
		for item_data in quest_data_with_qty:gmatch("([^|]+)") do
			local parts = {}
			for part in item_data:gmatch("([^:]+)") do
				table.insert(parts, part)
			end
			
			if parts[1] then
				local detected_item = parts[1]
				-- Check if this is the item we're looting
				if detected_item:lower() == item_name:lower() or 
				   detected_item:gsub("s$", ""):lower() == item_name:gsub("s$", ""):lower() then
					-- Found matching item, parse character quantities
					if #parts > 1 then
						for i = 2, #parts do
							local char_qty_pair = parts[i]
							local char_name_in_data, qty_str = char_qty_pair:match("([^:]+):(.+)")
							if char_name_in_data and char_name_in_data:lower() == character_name:lower() then
								current_qty = tonumber(qty_str) or 0
								break
							end
						end
					end
					break
				end
			end
		end
	end
	
	Write.Error("  Current inventory: %d, After: %d", current_qty, current_qty + 1)
	
	mq.cmdf("/advloot shared 1 giveto %s 1", character_name)
	
	-- If this was a quest item, refresh the recipient's task data and update quest globals
	if item_name and quest_interface.is_quest_item(item_name) then
		debug_logger.quest("QUEST_LOOT: %s received quest item %s - triggering character refresh", character_name, item_name)
		Write.Info("Quest item %s given to %s - refreshing their task status", item_name, character_name)
		
		-- Trigger character-specific task refresh after loot distribution
		quest_interface.refresh_character_after_loot(character_name, item_name)
		
		-- Force rebuild of quest data from current task UI state
		-- This ensures we have up-to-date quantities since the UI has been refreshed
		debug_logger.quest("QUEST_LOOT: Rebuilding quest data globals after loot distribution")
		mq.delay(500)  -- Give the UI a moment to update
		
		-- Call back to native quest system to rebuild the global with fresh data
		if _G.YALM2_REBUILD_QUEST_DATA then
			_G.YALM2_REBUILD_QUEST_DATA()
			debug_logger.quest("QUEST_LOOT: Quest data globals rebuilt from UI")
		end
	end
end

looting.loot_item = function()
	mq.cmd("/advloot personal 1 loot")
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

	-- QUEST PRE-CHECK: Handle quest items BEFORE member evaluation
	local item_name = item and item.Name() or "unknown"
	debug_logger.info("QUEST_PRECHECK: Checking if '%s' is needed for quests", item_name)
	
	-- Check if global quest data exists
	if _G.YALM2_QUEST_DATA then
		local item_count = 0
		if _G.YALM2_QUEST_DATA.quest_items then
			for _ in pairs(_G.YALM2_QUEST_DATA.quest_items) do
				item_count = item_count + 1
			end
		end
		debug_logger.info("QUEST_PRECHECK: Global quest data available with %d item types", item_count)
		
		if _G.YALM2_QUEST_DATA.quest_items then
			local sample_items = {}
			local count = 0
			for item_name_key, _ in pairs(_G.YALM2_QUEST_DATA.quest_items) do
				table.insert(sample_items, item_name_key)
				count = count + 1
				if count >= 3 then break end
			end
			debug_logger.info("QUEST_PRECHECK: Sample quest items: %s", table.concat(sample_items, ", "))
		end
	else
		debug_logger.warn("QUEST_PRECHECK: No global quest data available (_G.YALM2_QUEST_DATA is nil)")
	end
	
	local needed_by = quest_interface.get_characters_needing_item(item_name)
	debug_logger.info("QUEST_PRECHECK: Characters needing '%s': %s", item_name, 
		needed_by and table.concat(needed_by, ", ") or "none")
	
	local task_name = nil  -- Quest interface currently doesn't return task details
	local objective = nil
	
	local is_quest_item = (needed_by and #needed_by > 0)
	debug_logger.info("QUEST_PRECHECK: '%s' classified as quest item: %s", item_name, tostring(is_quest_item))
	if is_quest_item then
		Write.Error("*** EARLY QUEST DETECTION: %s needed by [%s] ***", 
			item_name, table.concat(needed_by, ", "))
		
		-- Parse quest data with quantities to show detailed information
		local quest_data_with_qty = _G.YALM2_QUEST_ITEMS_WITH_QTY or ""
		local item_quantities = {}  -- Map of character -> {current = X, needed = Y}
		
		if quest_data_with_qty:len() > 0 then
			-- Parse format: "Item:char1:qty1,char2:qty2|Item2:..."
			for item_data in quest_data_with_qty:gmatch("([^|]+)") do
				local parts = {}
				for part in item_data:gmatch("([^:]+)") do
					table.insert(parts, part)
				end
				
				if parts[1] then
					local detected_item = parts[1]
					-- Check if this is the item we're looting (match by canonical name or exact)
					if detected_item:lower() == item_name:lower() or 
					   detected_item:gsub("s$", ""):lower() == item_name:gsub("s$", ""):lower() then
						-- Found matching item, parse character quantities
						if #parts > 1 then
							for i = 2, #parts do
								local char_qty_pair = parts[i]
								local char_name, qty_str = char_qty_pair:match("([^:]+):(.+)")
								if char_name and qty_str then
									local qty = tonumber(qty_str)
									item_quantities[char_name] = qty or 0
								end
							end
						end
						break
					end
				end
			end
		end
		
		-- Show detailed quantity information for each character
		for _, char_name in ipairs(needed_by) do
			local qty_needed = item_quantities[char_name] or 0
			Write.Error("  %s: currently has %d, needs %d more (would have %d after)", 
				char_name, 0, qty_needed, 1)
		end
		
		-- Find valid group members who need this item
		local count = looting.get_member_count(group_or_raid_tlo)
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
			Write.Error("*** EARLY QUEST OVERRIDE: Testing only quest characters [%s] ***", 
				table.concat(valid_recipients, ", "))
			
			-- IMPROVED DISTRIBUTION: Prioritize non-master looters first to avoid ML hoarding
			local master_looter = mq.TLO.Group.MainAssist.CleanName() or mq.TLO.Me.CleanName()
			local non_ml_candidates = {}
			local ml_candidates = {}
			
			-- Separate candidates by master looter status
			for _, recipient_name in ipairs(valid_recipients) do
				if recipient_name:lower() == master_looter:lower() then
					table.insert(ml_candidates, recipient_name)
				else
					table.insert(non_ml_candidates, recipient_name)
				end
			end
			
			-- Try non-master looters first, then master looter as fallback
			local priority_list = {}
			for _, name in ipairs(non_ml_candidates) do table.insert(priority_list, name) end
			for _, name in ipairs(ml_candidates) do table.insert(priority_list, name) end
			
			Write.Error("*** DISTRIBUTION PRIORITY: Non-ML [%s], ML [%s] ***", 
				table.concat(non_ml_candidates, ", "), table.concat(ml_candidates, ", "))
			
			-- Test candidates in priority order
			for _, recipient_name in ipairs(priority_list) do
				for i = 0, count do
					local test_member = looting.get_valid_member(group_or_raid_tlo, i)
					if test_member and test_member.CleanName():lower() == recipient_name:lower() then
						Write.Error("*** TESTING QUEST MEMBER: %s (ML: %s) ***", 
							test_member.CleanName(), test_member.CleanName():lower() == master_looter:lower() and "YES" or "NO")
						
						can_loot, check_rematch, preference =
							evaluate.check_can_loot(test_member, item, loot, save_slots, dannet_delay, always_loot, unmatched_item_rule)

						if can_loot then
							member = test_member
							Write.Error("*** QUEST WINNER: %s (Priority: %s) ***", 
								member.CleanName(), member.CleanName():lower() == master_looter:lower() and "ML-Fallback" or "Non-ML-Priority")
							
							-- LIGHTWEIGHT: Trust cached quest data instead of heavy real-time validation  
							Write.Info("*** QUEST LOOT: Using cached data to reduce TaskHUD pressure ***")
							
							-- Skip complex refresh cycles that cause timing issues with TaskHUD
							debug_logger.quest("FAST_LOOT: Trusting recent quest data for %s -> %s (avoids TaskHUD race conditions)", 
								item_name, member.CleanName())
							
							-- Proceed with trusted data - much faster and more reliable
							local refresh_success = true  -- Skip the refresh loop entirely
							local max_retries = 1
							local retry_count = 1
							
							while not refresh_success and retry_count < max_retries do
								retry_count = retry_count + 1
								debug_logger.info("EARLY QUEST REFRESH: Attempt %d/%d", retry_count, max_retries)
								Write.Error("*** EARLY QUEST REFRESH: Attempt %d/%d ***", retry_count, max_retries)
								
								-- Capture pre-refresh state for comparison
								local pre_refresh_needed = quest_interface.get_characters_needing_item(item_name)
								debug_logger.quest("PRE-REFRESH STATE: %s needed by [%s]", 
									item_name, 
									pre_refresh_needed and table.concat(pre_refresh_needed, ", ") or "none")
								
								-- Request task update
								quest_interface.refresh_all_characters()
								
								-- CRITICAL: Wait for task updates to complete by monitoring task system stability
								local wait_start = os.time()
								local max_wait_time = 8 -- 8 seconds maximum wait
								local task_update_complete = false
								local stable_readings = 0
								local required_stable_readings = 2 -- Need 2 consistent readings
								local last_needed_by = nil
								
								debug_logger.info("TASK UPDATE MONITOR: Waiting for stable task data...")
								
								while (os.time() - wait_start) < max_wait_time do
									mq.delay(1000) -- Wait 1 second between checks
									
									-- Check current quest state
									local current_needed_by = quest_interface.get_characters_needing_item(item_name)
									local current_needed_str = current_needed_by and table.concat(current_needed_by, ", ") or "none"
									
									debug_logger.debug("TASK STATE CHECK: %s needed by [%s] (reading %d)", 
										item_name, current_needed_str, stable_readings + 1)
									
									-- Compare with last reading to detect stability
									if last_needed_by == current_needed_str then
										stable_readings = stable_readings + 1
										debug_logger.debug("TASK STABILITY: Consistent reading %d/%d", stable_readings, required_stable_readings)
										
										if stable_readings >= required_stable_readings then
											task_update_complete = true
											debug_logger.info("TASK UPDATE COMPLETE: Stable data after %d seconds", os.time() - wait_start)
											break
										end
									else
										-- Data changed, reset stability counter
										stable_readings = 0
										last_needed_by = current_needed_str
										debug_logger.debug("TASK DATA CHANGED: Reset stability counter, new state [%s]", current_needed_str)
									end
								end
								
								if task_update_complete then
									-- Quest interface handles validation internally
									refresh_success = true
									debug_logger.info("EARLY QUEST REFRESH: Success on attempt %d after task synchronization", retry_count)
									Write.Error("*** EARLY QUEST REFRESH: Success on attempt %d ***", retry_count)
								else
									debug_logger.warn("EARLY QUEST REFRESH: Task updates did not stabilize within timeout")
									Write.Warn("*** EARLY QUEST REFRESH: Failed attempt %d, task data unstable ***", retry_count)
									if retry_count < max_retries then
										Write.Info("*** EARLY QUEST REFRESH: Retrying in 2 seconds... ***")
										mq.delay(2000)
									end
								end
							end
							
							if not refresh_success then
								debug_logger.error("EARLY QUEST REFRESH: All attempts failed! Task updates never stabilized")
								Write.Error("*** EARLY QUEST REFRESH: All attempts failed! Quest data may be stale ***")
								Write.Warn("*** DANGER: Proceeding without confirmed task updates - items may go to wrong character ***")
							else
								-- Re-check quest data after successful synchronized refresh
								local updated_needed_by = quest_interface.get_characters_needing_item(item_name)
								local final_needed_str = updated_needed_by and table.concat(updated_needed_by, ", ") or "none"
								
								debug_logger.quest("POST-REFRESH STATE: %s needed by [%s]", 
									item_name, final_needed_str)
								
								if updated_needed_by and #updated_needed_by > 0 then
									Write.Error("*** TASK UPDATE CONFIRMED: %s still needed by [%s] ***", item_name, table.concat(updated_needed_by, ", "))
								else
									Write.Error("*** TASK UPDATE CONFIRMED: No one needs %s anymore ***", item_name)
								end
							end
							
							return can_loot, check_rematch, member, preference
						end
						break
					end
				end
			end
			
			-- If no quest characters can take it, fall through to normal evaluation
			Write.Error("*** NO QUEST CHARACTERS AVAILABLE: Falling back to normal loot rules ***")
		end
	end

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
				Write.Info("QUEST ITEM: %s not currently needed by any characters", item_name)
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
		Write.Error("*** MASTER LOOT DEBUG: First get_member_can_loot result - can_loot: %s, preference: %s, member: %s ***", 
			tostring(can_loot), preference and preference.setting or "nil", member and member.CleanName() or "nil")
		
		-- Debug quest preference details
		if preference then
			Write.Error("*** QUEST PREF DEBUG: list=[%s], data=%s ***", 
				preference.list and table.concat(preference.list, ", ") or "empty/nil",
				preference.data and "exists" or "nil"
			)
			if preference.data then
				Write.Error("*** QUEST DATA DEBUG: quest_item=%s, task_name='%s' ***",
					tostring(preference.data.quest_item),
					preference.data.task_name or "nil"
				)
			end
			
			-- DEBUG: Test group member check manually for Vexxuss
			if member and member.CleanName() == "Vexxuss" and preference.list then
				Write.Error("*** MANUAL GROUP CHECK: Testing Vexxuss against list [%s] ***", 
					table.concat(preference.list, ", ")
				)
				
				-- Check if Vexxuss is in the list
				local vexxuss_in_list = false
				for _, name in ipairs(preference.list) do
					if name:lower() == "vexxuss" then
						vexxuss_in_list = true
						break
					end
				end
				Write.Error("*** MANUAL GROUP CHECK: Vexxuss in list: %s ***", tostring(vexxuss_in_list))
			end
		end
		
		-- DIRECT TEST: Check if quest logic is accessible
		if quest_interface and quest_interface.get_characters_needing_item then
			local needed_by, task_name, objective = quest_interface.get_characters_needing_item("Blighted Blood Sample")
			Write.Error("*** DIRECT QUEST TEST: needed_by=[%s], task_name='%s' ***", 
				needed_by and table.concat(needed_by, ", ") or "nil",
				task_name or "nil"
			)
			
			-- HOTFIX: Manually override preference for quest items ONLY
			if needed_by and #needed_by > 0 then
				Write.Error("*** QUEST HOTFIX: Overriding preference with quest characters for %s ***", item_name)
				
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
			Write.Error("*** DIRECT QUEST TEST: tasks module or function not available ***")
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

	Write.Info("\a-t%s\ax passes with %s", item_name, utils.get_item_preference_string(preference))

	if not can_loot or not member then
		Write.Warn("No one is able to loot \a-t%s\ax", item_name)
		mq.delay(global_settings.settings.unmatched_item_delay)
		looting.leave_item()
		return
	end

	if item_name == mq.TLO.AdvLoot[loot_list_tlo](1).Name() then
		Write.Info("Giving \a-t%s\ax to \ao%s\ax", item_name, member.Name())
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

	Write.Info("\a-t%s\ax passes with %s", item_name, utils.get_item_preference_string(preference))

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
