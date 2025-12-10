local quest_interface = require("yalm2.core.quest_interface")
local evaluate = require("yalm.core.evaluate")
local looting = require("yalm.core.looting")
local mq = require("mq")
local Write = require("yalm.lib.Write")

local function action(global_settings, char_settings, args)
	Write.Info("=== LOOT EVALUATION DEBUG TEST ===")
	
	-- Create a mock item object that mimics AdvLoot item
	local mock_item = {
		Name = function() return "Blighted Blood Sample" end,
		ID = function() return 17578 end,
		Index = 1  -- This makes it look like an AdvLoot item
	}
	
	Write.Info("Step 1: Testing get_loot_item...")
	local loot_item = evaluate.get_loot_item(mock_item)
	Write.Info("  loot_item result: %s", loot_item and "created" or "nil")
	
	Write.Info("Step 2: Testing get_loot_preference...")
	Write.Info("  Mock item name: '%s'", mock_item.Name())
	Write.Info("  Mock item ID: %s", mock_item.ID())
	
	local test_char_settings = evaluate.get_member_char_settings(
		mq.TLO.Me,  -- Use current character
		global_settings.settings.save_slots,
		global_settings.settings.dannet_delay,
		false,
		global_settings.settings.unmatched_item_rule
	)
	
	Write.Info("  About to call get_loot_preference...")
	-- Call get_loot_preference with the same parameters as check_can_loot
	local preference = evaluate.get_loot_preference(
		mock_item,
		global_settings,  -- This is the 'loot' parameter 
		test_char_settings,
		test_char_settings.settings.unmatched_item_rule
	)
	Write.Info("  get_loot_preference call completed")
	
	Write.Info("  preference result: %s", preference and preference.setting or "nil")
	if preference and preference.list then
		Write.Info("  preference list: %s", table.concat(preference.list, ", "))
	end
	
	Write.Info("Step 3: Testing task data lookup...")
	
	-- First check if we have quest items at all
	local all_quest_items = quest_interface.get_all_quest_items()
	local quest_item_count = 0
	for _ in pairs(all_quest_items) do quest_item_count = quest_item_count + 1 end
	Write.Info("  Total quest items tracked: %d", quest_item_count)
	
	-- Check if Blighted Blood Sample is in the quest items
	local bbs_info = all_quest_items["Blighted Blood Sample"]
	if bbs_info then
		Write.Info("  Blighted Blood Sample found in quest items")
		Write.Info("    Needed by: %s", table.concat(bbs_info.needed_by or {}, ", "))
		Write.Info("    Task: %s", bbs_info.task_name or "unknown")
	else
		Write.Info("  Blighted Blood Sample NOT found in quest items")
	end
	
	-- Test the specific function
	local needed_by, task_name, objective = quest_interface.get_characters_needing_item("Blighted Blood Sample")
	Write.Info("  get_characters_needing_item result:")
	Write.Info("    needed_by: %s", needed_by and table.concat(needed_by, ", ") or "nil")
	Write.Info("    task_name: %s", task_name or "nil")
	
	Write.Info("Step 4: Testing member-by-member evaluation...")
	local group_or_raid_tlo = looting.get_group_or_raid_tlo()
	local count = looting.get_member_count(group_or_raid_tlo)
	
	Write.Info("  Group type: %s, Member count: %d", group_or_raid_tlo, count)
	
	for i = 0, count do
		local member = looting.get_valid_member(group_or_raid_tlo, i)
		if member then
			Write.Info("  Testing member: %s", member.CleanName())
			local can_loot, check_rematch, test_preference = evaluate.check_can_loot(
				member,
				mock_item,
				global_settings,
				global_settings.settings.save_slots,
				global_settings.settings.dannet_delay,
				false,
				global_settings.settings.unmatched_item_rule
			)
			
			Write.Info("    can_loot: %s, preference: %s", 
				tostring(can_loot), 
				test_preference and (test_preference.setting or "unknown") or "nil"
			)
			
			-- Show detailed preference analysis
			if test_preference then
				Write.Info("    preference.list: [%s]", 
					test_preference.list and table.concat(test_preference.list, ", ") or "empty/nil"
				)
				Write.Info("    preference.data: %s", 
					test_preference.data and "exists" or "nil"
				)
				if test_preference.data then
					Write.Info("    preference.data.quest_item: %s", 
						tostring(test_preference.data.quest_item)
					)
					Write.Info("    preference.data.task_name: %s", 
						test_preference.data.task_name or "nil"
					)
				end
			else
				Write.Info("    preference object is nil!")
			end
			
			if can_loot then
				Write.Info("    WINNER: %s would get the item", member.CleanName())
				break
			end
		end
	end
	
	Write.Info("=== DEBUG TEST COMPLETE ===")
end

return { action_func = action }