local quest_interface = require("yalm2.core.quest_interface")
local mq = require("mq")
local Write = require("yalm2.lib.Write")

local function action(global_settings, char_settings, args)
	if not args[2] then
		Write.Info("Usage: /yalm2 taskinfo [status|items|refresh|simulate]")
		Write.Info("  status   - Show current task data and character counts")
		Write.Info("  items    - List all quest items being tracked")
		Write.Info("  refresh  - Request fresh task data from TaskHUD")
		Write.Info("  simulate [item] - Test quest-aware loot evaluation")
		return
	end
	
	local subcommand = args[2]:lower()
	
	if subcommand == "status" then
		-- Show current task data status
		Write.Info("Task Awareness Status:")
		
		-- Check native quest system first
		if _G.YALM2_QUEST_DATA then
			Write.Info("  Native Quest System: Active")
			Write.Info("  Last Update: %s", _G.YALM2_QUEST_DATA.timestamp and 
				os.date("%H:%M:%S", _G.YALM2_QUEST_DATA.timestamp / 1000) or "Never")
			
			-- Show quest items being tracked
			if _G.YALM2_QUEST_DATA.quest_items then
				local item_count = 0
				for _ in pairs(_G.YALM2_QUEST_DATA.quest_items) do
					item_count = item_count + 1
				end
				Write.Info("  Quest items tracked: %d", item_count)
			end
		else
			Write.Info("  Native Quest System: Not active")
		end
		
	elseif subcommand == "items" then
		-- Show quest items being tracked
		local quest_items = quest_interface.get_all_quest_items()
		Write.Info("Quest Items Currently Tracked:")
		for item_name, quest_info in pairs(quest_items) do
			Write.Info("  %s:", item_name)
			Write.Info("    Task: %s", quest_info.task_name or "Unknown")
			Write.Info("    Needed by: %s", table.concat(quest_info.needed_by, ", "))
			if quest_info.objective then
				Write.Info("    Objective: %s", quest_info.objective)
			end
		end
		if next(quest_items) == nil then
			Write.Info("  No quest items currently tracked")
		end
		
	elseif subcommand == "refresh" then
		-- Request fresh task data
		Write.Info("Refreshing quest data...")
		-- Native system refreshes automatically, but we can trigger a manual update
		
		-- Wait a moment and check for response
		Write.Info("Waiting for TaskHUD response...")
		mq.delay(1000)
		
		Write.Info("Checking quest system status...")
		if _G.YALM2_QUEST_DATA then
			Write.Info("Native quest system active - data will refresh automatically")
		else
			Write.Info("Native quest system not available")
		end
		
	elseif subcommand == "simulate" then
		-- Simulate quest-aware loot evaluation
		local item_name = args[3] or "Blighted Blood Sample"
		Write.Info("=== QUEST-AWARE LOOT SIMULATION ===")
		Write.Info("Testing item: %s", item_name)
		
		-- Step 1: Check if we have quest item data
		Write.Info("Current quest items in task_data:")
		local all_quest_items = quest_interface.get_all_quest_items()
		for item, info in pairs(all_quest_items) do
			Write.Info("  - %s: needed by %s", item, table.concat(info.needed_by or {}, ", "))
		end
		
		local needed_by, task_name, objective = quest_interface.get_characters_needing_item(item_name)
		Write.Info("Step 1 - Quest item lookup:")
		if needed_by and #needed_by > 0 then
			Write.Info("  ✅ Item needed by: %s", table.concat(needed_by, ", "))
			Write.Info("  📋 Task: %s", task_name or "Unknown")
			Write.Info("  🎯 Objective: %s", objective or "Unknown")
		else
			Write.Info("  ❌ Item not needed by any characters")
			Write.Info("  ➡️  Would fall back to global settings")
			return
		end
		
		-- Step 2: Check group/raid membership (simulate)
		Write.Info("Step 2 - Group/Raid membership check:")
		local group_or_raid_tlo = mq.TLO.Raid.Members() > 0 and "Raid" or "Group"
		local count = mq.TLO[group_or_raid_tlo].Members() or 0
		Write.Info("  🏛️  In %s with %d members", group_or_raid_tlo:lower(), count + 1)
		
		local valid_recipients = {}
		for _, char_name in ipairs(needed_by) do
			-- Check if this character is in our group/raid
			local found_in_group = false
			if char_name:lower() == mq.TLO.Me.CleanName():lower() then
				found_in_group = true
			else
				for i = 1, count do
					local member = mq.TLO[group_or_raid_tlo].Member(i)
					if member and member.CleanName():lower() == char_name:lower() then
						found_in_group = true
						break
					end
				end
			end
			
			if found_in_group then
				table.insert(valid_recipients, char_name)
				Write.Info("  ✅ %s is in %s", char_name, group_or_raid_tlo:lower())
			else
				Write.Info("  ❌ %s not in %s", char_name, group_or_raid_tlo:lower())
			end
		end
		
		-- Step 3: Loot decision (matching actual quest-aware logic)
		Write.Info("Step 3 - Loot decision:")
		if #valid_recipients > 0 then
			-- Select the best recipient for this quest item (same logic as evaluate.lua)
			local selected_recipient = valid_recipients[1]  -- Default to first
			local master_looter = mq.TLO.Group.MasterLooter.CleanName()
			
			-- Try to find a non-master-looter recipient first
			for _, recipient in ipairs(valid_recipients) do
				if recipient:lower() ~= master_looter:lower() then
					selected_recipient = recipient
					break
				end
			end
			
			Write.Info("  🎉 QUEST PRIORITY: Distribute to %s", table.concat(valid_recipients, ", "))
			Write.Info("  🎯 SELECTED RECIPIENT: %s (Master Looter: %s)", selected_recipient, master_looter)
			Write.Info("  📦 Preference: { setting='Keep', list=%s }", selected_recipient)
		else
			Write.Info("  ⚠️  No group members need this quest item")
			Write.Info("  ➡️  Would fall back to global settings (Keep/Tribute/Destroy/etc.)")
		end
		
		Write.Info("=== SIMULATION COMPLETE ===")
		
	else
		Write.Error("Unknown subcommand: %s", subcommand)
		Write.Info("Usage: /yalm2 taskinfo [status|items|refresh|simulate]")
		Write.Info("  simulate [item] - Test quest-aware loot evaluation (default: 'Blighted Blood Sample')")
	end
end

return { action_func = action }
