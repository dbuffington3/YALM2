--- @type Mq
local mq = require("mq")

local dannet = require("yalm2.lib.dannet")

local utils = require("yalm2.lib.utils")

local debug_logger = require("yalm2.lib.debug_logger")

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
	
	-- Query each bag slot (23-32) - slot 23 is first bag, slots 24-32 are additional bags
	for bag_slot = 23, 32 do
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
				
				-- Query total slots in this bag (Container returns TOTAL slots, not current count)
				local total_slots_str = dannet.query(character_name, string.format("Me.Inventory[%d].Container", bag_slot), dannet_delay)
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

-- Simple function: Get total free inventory slots without bag-type awareness
-- This is MUCH faster than counting individual bags
inventory.get_total_free_slots = function(character_name, dannet_delay)
	if character_name == mq.TLO.Me.DisplayName() then
		-- Local character: direct query
		local total_slots = mq.TLO.Me.Inventory() or 0
		local used_slots = mq.TLO.Me.Inventory.Items() or 0
		return math.max(0, total_slots - used_slots)
	else
		-- Remote character: DanNet query
		local total_slots = tonumber(dannet.query(character_name, "Me.Inventory", dannet_delay)) or 0
		local used_slots = tonumber(dannet.query(character_name, "Me.Inventory.Items", dannet_delay)) or 0
		return math.max(0, total_slots - used_slots)
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

inventory.count_available_slots_for_item = function(item_id)
	--[[
	Count how many slots are available for a specific item locally
	
	Simple approach:
	1. Get total FreeInventory (works across all bags)
	2. If item is tradeskill: return FreeInventory directly
	3. If item is NOT tradeskill: subtract tradeskill-only bag free slots
	
	Returns: number of available slots that can hold this item
	]]
	
	local item_data = YALM2_Database.QueryDatabaseForItemId(item_id)
	if not item_data then
		return 0
	end
	
	local is_tradeskill = (tonumber(item_data.tradeskills) or 0) > 0
	
	-- Get total free inventory slots
	local total_free = mq.TLO.Me.FreeInventory()
	
	-- If tradeskill item, can use any bag
	if is_tradeskill then
		return total_free
	end
	
	-- Non-tradeskill item: need to subtract tradeskill-only bag free slots
	local tradeskill_bag_free_slots = 0
	
	-- Scan bags for tradeskill-only bags
	for bag_slot = 23, 32 do
		local bag = mq.TLO.Me.Inventory(bag_slot)
		if bag() then
			local bag_id = bag.ID()
			local bag_data = YALM2_Database.QueryDatabaseForItemId(bag_id)
			
			if bag_data then
				local bagtype = tonumber(bag_data.bagtype) or 0
				if bagtype == 58 then
					-- This is a tradeskill-only bag, count its free slots
					local total_slots = bag.Container() or 0
					local used_slots = bag.Items() or 0
					local free_in_bag = math.max(0, total_slots - used_slots)
					tradeskill_bag_free_slots = tradeskill_bag_free_slots + free_in_bag
				end
			end
		end
	end
	
	-- Non-tradeskill slots = total free - tradeskill-only bag free
	return math.max(0, total_free - tradeskill_bag_free_slots)
end

inventory.count_available_slots_for_item_remote = function(character_name, item_id, dannet_delay)
	--[[
	Count available slots for a remote character, respecting bag type constraints
	
	Simple approach:
	1. Get total FreeInventory (works across all bags)
	2. If item is tradeskill: return FreeInventory directly
	3. If item is NOT tradeskill: subtract tradeskill-only bag free slots
	
	Args:
		character_name (string): Name of remote character
		item_id (int): Item ID to check
		dannet_delay (int): Delay for DanNet queries
	
	Returns:
		(int) Number of available slots that can hold this item
	]]
	
	if not character_name or not item_id then
		debug_logger.warn("COUNT_SLOTS_REMOTE: character_name=%s, item_id=%s - returning 0", tostring(character_name), tostring(item_id))
		return 0
	end
	
	-- Query item data to check if tradeskill
	local item_data = YALM2_Database.QueryDatabaseForItemId(item_id)
	if not item_data then
		debug_logger.warn("COUNT_SLOTS_REMOTE: item_id=%d not found in database - returning 0", item_id)
		return 0
	end
	
	local is_tradeskill = (tonumber(item_data.tradeskills) or 0) > 0
	
	-- Get total free inventory slots
	local total_free = tonumber(dannet.query(character_name, "Me.FreeInventory", dannet_delay)) or 0
	
	debug_logger.info("COUNT_SLOTS_REMOTE: %s - item: %s (ID: %d, tradeskill=%s), total_free: %d", 
		character_name, item_data.name, item_id, tostring(is_tradeskill), total_free)
	
	-- If tradeskill item, can use any bag
	if is_tradeskill then
		return total_free
	end
	
	-- Non-tradeskill item: need to subtract tradeskill-only bag free slots
	local tradeskill_bag_free_slots = 0
	
	-- Get cached bag info
	local bag_cache = get_character_bag_cache(character_name)
	if utils.length(bag_cache) == 0 then
		-- Build cache if needed
		debug_logger.info("COUNT_SLOTS_REMOTE: Building bag cache for %s", character_name)
		cache_character_bags(character_name, dannet_delay)
		bag_cache = get_character_bag_cache(character_name)
	end
	
	-- Find tradeskill-only bags and sum their free slots
	for bag_slot, bag_info in pairs(bag_cache) do
		if bag_info.is_tradeskill_bag then
			-- This is a tradeskill-only bag, query its free slots
			local bag_total = tonumber(bag_info.total_slots) or 0
			local bag_used = tonumber(dannet.query(character_name, 
				string.format("Me.Inventory[%d].Items", bag_slot), dannet_delay)) or 0
			local bag_free = math.max(0, bag_total - bag_used)
			
			debug_logger.debug("COUNT_SLOTS_REMOTE: Tradeskill bag slot %d has %d free slots", bag_slot, bag_free)
			tradeskill_bag_free_slots = tradeskill_bag_free_slots + bag_free
		end
	end
	
	-- Non-tradeskill slots = total free - tradeskill-only bag free
	local available_for_non_tradeskill = math.max(0, total_free - tradeskill_bag_free_slots)
	
	debug_logger.info("COUNT_SLOTS_REMOTE: %s - total_free: %d, tradeskill_bag_free: %d, non_tradeskill_available: %d",
		character_name, total_free, tradeskill_bag_free_slots, available_for_non_tradeskill)
	
	return available_for_non_tradeskill
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
