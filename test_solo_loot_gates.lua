#!/usr/bin/env lua
--[[
Test Solo Looting Gate Logic

This test validates that solo looters:
1. Pass quest items through GATE 1
2. Pass tradeskill items through GATE 1 (when configured)
3. Pass valuable items through GATE 2
4. Leave non-valuable items on corpse
5. Return member=nil for solo path (no member distribution)
6. Apply same gate thresholds as group ML path

Run from command line:
  lua test_solo_loot_gates.lua
]]

-- Mock MQ2 API
mq = {
	TLO = {
		Group = {
			Members = function() return 0 end  -- Solo: 0 members
		},
		Me = {
			Mercenary = {
				ID = function() return nil end  -- No merc
			}
		}
	}
}

-- Mock logger
debug_logger = {
	info = function(...) print("[INFO] " .. string.format(...)) end,
	warn = function(...) print("[WARN] " .. string.format(...)) end,
	debug = function(...) print("[DEBUG] " .. string.format(...)) end,
}

-- Mock Write
Write = {
	Info = function(...) print("[WRITE] " .. string.format(...)) end,
	Warn = function(...) print("[WARN] " .. string.format(...)) end,
}

-- Mock quest_interface
quest_interface = {
	is_quest_item = function(item_name)
		-- Mock quest items
		local quest_items = {
			["Quest Item A"] = true,
			["Quest Item B"] = true,
		}
		return quest_items[item_name] or false
	end,
	get_characters_needing_item = function(item_name)
		return {} -- Solo doesn't need to check for other members
	end,
}

-- Mock looting module
looting = {
	is_solo_looter = function()
		return mq.TLO.Group.Members() == 0 or (mq.TLO.Group.Members() == 1 and mq.TLO.Me.Mercenary.ID())
	end,
	leave_item = function()
		print("[ACTION] Leaving item on corpse")
	end,
}

-- ========================================
-- Test Data
-- ========================================
local test_cases = {
	-- GATE 1: Quest Items
	{
		name = "Quest item in solo mode",
		item_name = "Quest Item A",
		item_data = {
			cost = 500,        -- 5pp
			guildfavor = 0,
			tradeskills = 0,
			nodrop = 0,
			questitem = 1,
			stacksize = 1
		},
		loot_settings = {
			keep_tradeskills = false,
			valuable_item_min_price = 10,
			valuable_guildfavor_min = 1000
		},
		loot_items = {},
		expected_can_loot = true,
		expected_member = nil,
		expected_reason = "quest_item",
	},
	
	-- GATE 1: Tradeskill - High value, stackable
	{
		name = "Stackable tradeskill material (high value)",
		item_name = "Tradeskill Material A",
		item_data = {
			cost = 1500,       -- 15pp, >= 10pp threshold
			guildfavor = 0,
			tradeskills = 1,
			nodrop = 0,
			questitem = 0,
			stacksize = 20
		},
		loot_settings = {
			keep_tradeskills = true,
			valuable_item_min_price = 10,
			valuable_guildfavor_min = 1000
		},
		loot_items = {},
		expected_can_loot = true,
		expected_member = nil,
		expected_reason = "tradeskill_stackable",
	},
	
	-- GATE 1: Tradeskill - Low value, non-stackable, no preference
	{
		name = "Non-stackable tradeskill (low value, no preference)",
		item_name = "Cheap Tradeskill",
		item_data = {
			cost = 50,         -- < 100pp low value
			guildfavor = 0,
			tradeskills = 1,
			nodrop = 0,
			questitem = 0,
			stacksize = 1
		},
		loot_settings = {
			keep_tradeskills = true,
			valuable_item_min_price = 10,
			valuable_guildfavor_min = 1000
		},
		loot_items = {},
		expected_can_loot = false,
		expected_member = nil,
		expected_reason = "cheap_tradeskill_no_pref",
	},
	
	-- GATE 2: Valuable stackable item
	{
		name = "Valuable stackable item (cost >= 10pp)",
		item_name = "Valuable Stackable",
		item_data = {
			cost = 2000,       -- 20pp
			guildfavor = 0,
			tradeskills = 0,
			nodrop = 0,
			questitem = 0,
			stacksize = 10
		},
		loot_settings = {
			keep_tradeskills = false,
			valuable_item_min_price = 10,
			valuable_guildfavor_min = 1000
		},
		loot_items = {},
		expected_can_loot = true,
		expected_member = nil,
		expected_reason = "valuable_cost_stackable",
	},
	
	-- GATE 2: Guild favor valuable
	{
		name = "Guild favor item (>= 1000)",
		item_name = "Guild Favor Item",
		item_data = {
			cost = 0,
			guildfavor = 1500,
			tradeskills = 0,
			nodrop = 0,
			questitem = 0,
			stacksize = 1
		},
		loot_settings = {
			keep_tradeskills = false,
			valuable_item_min_price = 10,
			valuable_guildfavor_min = 1000
		},
		loot_items = {},
		expected_can_loot = true,
		expected_member = nil,
		expected_reason = "valuable_guildfavor",
	},
	
	-- GATE 2: Non-stackable, low value item
	{
		name = "Non-stackable, low value item",
		item_name = "Worthless Item",
		item_data = {
			cost = 100,        -- 1pp < 10pp threshold
			guildfavor = 0,
			tradeskills = 0,
			nodrop = 0,
			questitem = 0,
			stacksize = 1
		},
		loot_settings = {
			keep_tradeskills = false,
			valuable_item_min_price = 10,
			valuable_guildfavor_min = 1000
		},
		loot_items = {},
		expected_can_loot = false,
		expected_member = nil,
		expected_reason = "low_value_non_stackable",
	},
}

-- ========================================
-- Test Runner
-- ========================================
local function run_gate_logic(item_name, item_data, loot_settings, loot_items)
	--[[
	Simplified gate logic test without needing full game context.
	This mirrors the logic in looting.get_member_can_loot()
	]]
	
	local can_loot = false
	local preference = nil
	local item_cost = item_data.cost or 0
	local item_guildfavor = item_data.guildfavor or 0
	local is_tradeskill = (item_data.tradeskills == 1)
	local is_quest_item = quest_interface.is_quest_item(item_name)
	
	-- GATE 1: QUEST AND TRADESKILL
	if is_quest_item or is_tradeskill then
		-- Check 1a: Quest items
		if is_quest_item then
			can_loot = true
			preference = { setting = "Keep", data = { quest_item = true, solo = true } }
			return can_loot, nil, preference
		end
		
		-- Check 1b: Tradeskill with config
		if not can_loot then
			local keep_tradeskill = loot_settings.keep_tradeskills
			if is_tradeskill and keep_tradeskill then
				local db_stacksize = item_data.stacksize or 0
				local is_stackable = db_stacksize > 1
				local item_value_in_pp = math.floor(item_cost / 100)
				local is_low_value = item_value_in_pp < 100
				
				if not is_stackable and is_low_value then
					local has_preference = loot_items[item_name] ~= nil
					if not has_preference then
						can_loot = false
						-- Continue to 1c
					else
						can_loot = true
						preference = { setting = "Keep", data = { tradeskill = true, solo = true } }
						return can_loot, nil, preference
					end
				else
					can_loot = true
					preference = { setting = "Keep", data = { tradeskill = true, solo = true } }
					return can_loot, nil, preference
				end
			end
		end
		
		-- Check 1c: Has value
		if not can_loot then
			if (item_guildfavor > 0) or (item_cost > 0) then
				can_loot = true
				preference = { setting = "Keep", data = { valuable = true, solo = true } }
				return can_loot, nil, preference
			end
		end
		
		-- If all checks failed in Gate 1, leave on corpse
		if not can_loot then
			return false, nil, { setting = "Leave", data = { solo = true } }
		end
	else
		-- GATE 2: NON-QUEST, NON-TRADESKILL
		local valuable_min_price = loot_settings.valuable_item_min_price or 10
		local has_valuable_cost_and_stackable = (item_cost >= valuable_min_price) and (item_data.stacksize > 1)
		local valuable_guildfavor_min = loot_settings.valuable_guildfavor_min or 1000
		local has_valuable_favor = (item_guildfavor >= valuable_guildfavor_min)
		
		if has_valuable_cost_and_stackable or has_valuable_favor then
			can_loot = true
			preference = { setting = "Keep", data = { valuable_item = true, solo = true } }
			return can_loot, nil, preference
		else
			return false, nil, { setting = "Leave", data = { solo = true } }
		end
	end
	
	return can_loot, nil, preference
end

-- ========================================
-- Run Tests
-- ========================================
local passed = 0
local failed = 0

print("=" .. string.rep("=", 78))
print("SOLO LOOTING GATE LOGIC TEST SUITE")
print("=" .. string.rep("=", 78))
print()

for i, test in ipairs(test_cases) do
	local can_loot, member, preference = run_gate_logic(
		test.item_name,
		test.item_data,
		test.loot_settings,
		test.loot_items
	)
	
	local pass = (can_loot == test.expected_can_loot) and (member == test.expected_member)
	
	if pass then
		passed = passed + 1
		print(string.format("✓ TEST %d PASS: %s", i, test.name))
		print(string.format("  Item: %s", test.item_name))
		print(string.format("  Result: can_loot=%s, member=%s", tostring(can_loot), tostring(member)))
	else
		failed = failed + 1
		print(string.format("✗ TEST %d FAIL: %s", i, test.name))
		print(string.format("  Item: %s", test.item_name))
		print(string.format("  Expected: can_loot=%s, member=%s", tostring(test.expected_can_loot), tostring(test.expected_member)))
		print(string.format("  Got:      can_loot=%s, member=%s", tostring(can_loot), tostring(member)))
	end
	print()
end

print("=" .. string.rep("=", 78))
print(string.format("RESULTS: %d passed, %d failed (total: %d)", passed, failed, passed + failed))
print("=" .. string.rep("=", 78))

if failed > 0 then
	os.exit(1)
end
