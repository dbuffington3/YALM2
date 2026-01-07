--- @type Mq
local mq = require("mq")

local dannet = require("yalm2.lib.dannet")

local utils = require("yalm2.lib.utils")

local inventory = {}

-- ============================================================================
-- CHARACTER BAG CACHE SYSTEM
-- ============================================================================
-- Cache bag configurations per character to avoid repeated DanNet queries
-- Bags don't change often, so cache them indefinitely until reload
local character_bag_cache = {}

--[[
	Get cached bag information for a character
	
	Returns a table with format:
	{
		[24] = { bag_id=67633, bagtype=58, total_slots=20, is_tradeskill_bag=true },
		[25] = { bag_id=12345, bagtype=0, total_slots=20, is_tradeskill_bag=false },
		...
	}
]]
local function get_character_bag_cache(character_name)
	if not character_bag_cache[character_name] then
		character_bag_cache[character_name] = {}
	end
	return character_bag_cache[character_name]
end

--[[
	Scan and cache a character's bags
	Called once per character, results cached for entire session
]]
local function cache_character_bags(character_name, dannet_delay)
	local bag_cache = get_character_bag_cache(character_name)
	
	-- Query each bag slot (24-32)
	for bag_slot = 24, 32 do
		-- Query bag name - returns NULL if no bag in slot
		local bag_name = dannet.query(character_name, string.format("Me.Inventory[%d].Name", bag_slot), dannet_delay)
		
		if bag_name and bag_name ~= 'NULL' and bag_name ~= '' then
			-- Bag exists - get its ID
			local bag_id_str = dannet.query(character_name, string.format("Me.Inventory[%d].ID", bag_slot), dannet_delay)
			local bag_id = tonumber(bag_id_str) or 0
			
			if bag_id > 0 then
				-- Look up bag type in database
				local bag_data = YALM2_Database.QueryDatabaseForItemId(bag_id)
				local bagtype = 0
				
				if bag_data then
					bagtype = tonumber(bag_data.bagtype) or 0
				end
				
				-- Query total slots in this bag
				local total_slots_str = dannet.query(character_name, string.format("Me.Inventory[%d].Items", bag_slot), dannet_delay)
				local total_slots = tonumber(total_slots_str) or 0
				
				-- Cache this bag's info
				bag_cache[bag_slot] = {
					bag_id = bag_id,
					bagtype = bagtype,
					total_slots = total_slots,
					is_tradeskill_bag = (bagtype == 58)
				}
			end
		end
	end
end

inventory.check_group_member = function(member, list, dannet_delay, always_loot)
	-- Debug for quest items disabled
	local member_name = member and member.Name() or "unknown"
	
	if always_loot then
		return true
	end

	local class

	if not list or #list == 0 then
		return true
	end

	local name = member.Name()

	if name == mq.TLO.Me.DisplayName() then
		class = mq.TLO.Me.Class.ShortName()
	else
		class = tostring(dannet.query(name, "Me.Class.ShortName", dannet_delay)) or nil
	end

	for i in ipairs(list) do
		if list[i] == name or list[i] == class then
			return true
		end
	end

	return false
end

inventory.check_inventory = function(member, item, save_slots, dannet_delay)
	local slots, count, stacksize

	local name = member.Name()
	local item_id = item.ID()

	if name == mq.TLO.Me.DisplayName() then
		-- LOCAL CHARACTER: Count only slots that can hold this specific item type
		-- This prevents deadlock where tradeskill-only bags are full but look empty
		slots = inventory.count_available_slots_for_item(item_id)
		
		count = mq.TLO.FindItemCount(item_id)() or 0
		stacksize = mq.TLO.FindItem(item_id).StackSize() or 0
	else
		-- REMOTE CHARACTER: Check if they have room for this item type
		-- Uses the new remote bag type checking to respect tradeskill-only bags
		slots = inventory.count_available_slots_for_item_remote(name, item_id, dannet_delay)
		
		count = tonumber(dannet.query(name, string.format("FindItemCount[%s]", item_id), dannet_delay)) or 0
		stacksize = tonumber(dannet.query(name, string.format("FindItem[%s].StackSize", item_id), dannet_delay)) or 0
	end

	if (count == 0 or (count > 0 and count + 1 > stacksize)) and slots <= save_slots then
		return false
	end

	return true
end

inventory.check_total_save_slots = function(member, char_settings, save_slots, dannet_delay)
	local total_save_slots = save_slots

	local name = member.Name()

	if not char_settings.saved or utils.length(char_settings.saved) == 0 then
		return total_save_slots
	end

	for i in ipairs(char_settings.saved) do
		local slots = char_settings.saved[i]

		if slots.itemslot then
			local container_slots, item_count, item_name

			if slots.itemslot2 then
				if name == mq.TLO.Me.DisplayName() then
					item_name = mq.TLO.Me.Inventory(slots.itemslot).Item(slots.itemslot2).Name()
				else
					item_count = tostring(
						dannet.query(
							name,
							("Me.Inventory[%s].Item[%s].Name"):format(slots.itemslot, slots.itemslot2),
							dannet_delay
						)
					) or nil
				end

				if not item_name then
					total_save_slots = total_save_slots + 1
				end
			else
				if name == mq.TLO.Me.DisplayName() then
					container_slots = mq.TLO.Me.Inventory(slots.itemslot).Container()
					item_count = mq.TLO.Me.Inventory(slots.itemslot).Items()
					item_name = mq.TLO.Me.Inventory(slots.itemslot).Name()
				else
					container_slots = tonumber(
						dannet.query(name, ("Me.Inventory[%s].Container"):format(slots.itemslot), dannet_delay)
					) or 0
					item_count = tonumber(
						dannet.query(name, ("Me.Inventory[%s].Items"):format(slots.itemslot), dannet_delay)
					) or 0
					item_count = tostring(
						dannet.query(name, ("Me.Inventory[%s].Name"):format(slots.itemslot), dannet_delay)
					) or nil
				end

				if not item_name then
					total_save_slots = total_save_slots + 1
				elseif container_slots > 0 and item_count < container_slots then
					total_save_slots = total_save_slots + container_slots - item_count
				end
			end
		end
	end
end

inventory.check_lore = function(member, item, dannet_delay)
	local lore, banklore

	local name = member.Name()
	local item_id = item.ID()

	-- if it's me, do this locally
	if name == mq.TLO.Me.DisplayName() then
		lore = mq.TLO.FindItem(item_id).Lore()
		banklore = mq.TLO.FindItemBank(item_id).Lore()
	else
		-- use dannet
		lore = tostring(dannet.query(name, string.format("FindItem[%s].Lore", item_id), dannet_delay)) == "TRUE"
		banklore = tostring(dannet.query(name, string.format("FindItemBank[%s].Lore", item_id), dannet_delay)) == "TRUE"
	end

	if lore == true or banklore == true then
		return false
	end

	return true
end

inventory.check_lore_equip_prompt = function()
	local confirmation_dialog_box = "ConfirmationDialogBox"
	local confirmation_dialog_box_text = confirmation_dialog_box .. "/CD_TextOutput"
	if mq.TLO.Window(confirmation_dialog_box).Open() then
		if mq.TLO.Window(confirmation_dialog_box_text).Text():find("LORE-EQUIP", 1, true) then
			mq.cmd("/notify ConfirmationDialogBox CD_YES_Button leftmouseup")

			while mq.TLO.Window(confirmation_dialog_box).Open() do
				mq.delay(100)
			end
		end
	end
end

inventory.check_quantity = function(member, item, quantity, dannet_delay, always_loot)
	local count, bankcount

	-- If no quantity preference is set, allow looting (unless always_loot is false)
	if quantity == nil then
		return true
	end

	-- If quantity IS set, always respect it - don't bypass with always_loot
	-- always_loot only applies when there's no quantity constraint
	local name = member.Name()
	local item_id = item.ID()

	-- if it's me, do this locally
	if name == mq.TLO.Me.DisplayName() then
		count = mq.TLO.FindItemCount(item_id)()
		bankcount = mq.TLO.FindItemBankCount(item_id)()
	else
		-- use dannet
		count = tonumber(dannet.query(name, string.format("FindItemCount[%s]", item_id), dannet_delay)) or 0
		bankcount = tonumber(dannet.query(name, string.format("FindItemBankCount[%s]", item_id), dannet_delay)) or 0
	end

	if (count + bankcount) >= quantity then
		return false
	end

	return true
end

inventory.count_open_slots_in_bag = function(bag_slot)
	--[[
	Count the number of open slots in a specific bag (inventory slot)
	Returns: number of empty slots, or 0 if not a container
	]]
	local bag = mq.TLO.Me.Inventory(bag_slot)
	if not bag() then
		return 0
	end
	
	local container_slots = tonumber(bag.Container()) or 0
	if container_slots <= 0 then
		return 0  -- Not a container
	end
	
	local items_in_bag = tonumber(bag.Items()) or 0
	return math.max(0, container_slots - items_in_bag)
end

inventory.count_available_slots_for_item = function(item_id)
	--[[
	Count how many slots are available for a specific item across all bags
	
	Logic:
	- If item is tradeskill (tradeskills=1): can use tradeskill bags OR general bags
	- If item is NOT tradeskill (tradeskills=0): can ONLY use general bags
	
	This prevents the ML from thinking it has room when only tradeskill bags are empty
	
	Returns: number of available slots that can hold this item
	]]
	
	local item_data = YALM2_Database.QueryDatabaseForItemId(item_id)
	if not item_data then
		return 0
	end
	
	local is_tradeskill = (tonumber(item_data.tradeskills) or 0) > 0
	local available_slots = 0
	
	-- Scan bags in order (24 = first bag, 32 = typically last)
	for bag_slot = 24, 32 do
		local bag = mq.TLO.Me.Inventory(bag_slot)
		if bag() then
			-- Get the bag's type from the item database
			local bag_id = bag.ID()
			local bag_data = YALM2_Database.QueryDatabaseForItemId(bag_id)
			local bagtype = 0
			
			if bag_data then
				bagtype = tonumber(bag_data.bagtype) or 0
			end
			
			local is_tradeskill_bag = (bagtype == 58)
			local open_slots = inventory.count_open_slots_in_bag(bag_slot)
			
			-- Count open slots in this bag if it can hold this item
			if is_tradeskill then
				-- Tradeskill items: can go in ANY bag
				available_slots = available_slots + open_slots
			else
				-- Non-tradeskill items: only go in non-tradeskill bags
				if not is_tradeskill_bag then
					available_slots = available_slots + open_slots
				end
			end
		end
	end
	
	return available_slots
end

--[[
	Count available inventory slots for a remote character via DanNet
	
	This uses a cached bag configuration (built at startup/first-use) to determine
	which bags can hold which items. Avoids repeated DanNet queries for bag info.
	
	The only per-call query is UsedSlots (changes frequently).
	Bag type/structure is cached (changes rarely).
	
	Args:
		character_name (string): Name of remote character
		item_id (int): Item ID to check
		dannet_delay (int): Delay for DanNet queries
	
	Returns:
		(int) Number of available slots that can hold this item
]]
inventory.count_available_slots_for_item_remote = function(character_name, item_id, dannet_delay)
	if not character_name or not item_id then
		return 0
	end
	
	local item_data = YALM2_Database.QueryDatabaseForItemId(item_id)
	
	if not item_data then
		return 0
	end
	
	local is_tradeskill = (tonumber(item_data.tradeskills) or 0) > 0
	
	-- Get cached bag info for this character, building cache if needed
	local bag_cache = get_character_bag_cache(character_name)
	
	-- If cache is empty, scan bags first
	if utils.length(bag_cache) == 0 then
		cache_character_bags(character_name, dannet_delay)
		bag_cache = get_character_bag_cache(character_name)
	end
	
	local available_slots = 0
	
	-- For each cached bag, count available slots
	for bag_slot, bag_info in pairs(bag_cache) do
		-- Determine if this bag can hold the item
		local can_use_this_bag = false
		
		if is_tradeskill then
			-- Tradeskill items: can go in ANY bag
			can_use_this_bag = true
		else
			-- Non-tradeskill items: only go in non-tradeskill bags
			can_use_this_bag = not bag_info.is_tradeskill_bag
		end
		
		-- If this bag can hold the item, estimate used slots from available queries
		if can_use_this_bag then
			-- Since UsedSlots doesn't work remotely, we assume the bag is getting full
			-- For safety, assume at least 1 slot is used if we have items in the bag
			-- Query just the first slot to see if bag has any items
			local first_item = dannet.query(character_name, string.format("Me.Inventory[%d].Item[1]", bag_slot), dannet_delay)
			
			local used_slots = 0
			if first_item and first_item ~= "NULL" and first_item ~= "" then
				-- Bag has items, conservatively assume most slots are used
				-- Better to report 0 slots available than give items to a full bag
				-- Query a middle slot to estimate fill
				local mid_item = dannet.query(character_name, string.format("Me.Inventory[%d].Item[%d]", bag_slot, math.ceil(bag_info.total_slots / 2)), dannet_delay)
				
				if mid_item and mid_item ~= "NULL" and mid_item ~= "" then
					-- Mid slot has item too, assume bag is ~75% full
					used_slots = math.ceil(bag_info.total_slots * 0.75)
				else
					-- Only early slots have items, assume 30% full
					used_slots = math.ceil(bag_info.total_slots * 0.3)
				end
			else
				-- First slot is empty, bag has space
				used_slots = 0
			end
			
			local open_slots = math.max(0, bag_info.total_slots - used_slots)
			available_slots = available_slots + open_slots
		end
	end
	
	return available_slots
end

inventory.verify_tradeskill_bag_placement = function()
	--[[
	At startup, verify that tradeskill bags (bagtype=58) are placed in the FIRST
	available bag slots so that auto-inventory deposits items correctly
	
	Returns: true if OK, false if tradeskill bags are misplaced
	]]
	
	local has_tradeskill_bag = false
	local has_general_bag = false
	local error_found = false
	
	for bag_slot = 24, 32 do
		local bag = mq.TLO.Me.Inventory(bag_slot)
		if bag() then
			local bag_id = bag.ID()
			local bag_data = YALM2_Database.QueryDatabaseForItemId(bag_id)
			
			if not bag_data then
				goto next_bag
			end
			
			local bagtype = tonumber(bag_data.bagtype) or 0
			local bag_name = bag.Name()
			
			if bagtype == 58 then
				-- This is a tradeskill-only bag
				if has_general_bag then
					-- ERROR: Found a general bag BEFORE this tradeskill bag
					mq.cmdf('/echo \ar⚠️ BAG PLACEMENT ERROR:\ax Tradeskill bag "%s" (slot %d) is AFTER general bags!', bag_name, bag_slot)
					error_found = true
				end
				has_tradeskill_bag = true
			else
				-- This is a general bag (or not a recognized container)
				has_general_bag = true
			end
		end
		
		::next_bag::
	end
	
	if error_found then
		mq.cmdf('/echo \ar→ Move tradeskill bags to slots 24-26 (first slots) for proper auto-inventory!:\ax')
		return false
	end
	
	return true
end

return inventory
