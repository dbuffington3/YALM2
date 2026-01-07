--[[
    Inventory Cleanup Module
    
    Provides functionality to scan inventory for NO DROP items that shouldn't be kept
    based on the same gate logic used for looting decisions.
]]

local mq = require('mq')
local quest_interface = require('yalm2.core.quest_interface')
local database = require('yalm2.lib.database')
local equipment_dist = require('yalm2.lib.equipment_distribution')
local debug_logger = require('yalm2.lib.debug_logger')

local cleanup = {}

--[[
    Evaluate a single inventory item using the same gate logic as looting
    
    Args:
        item: MQ TLO item object
        char_loot: Character loot settings
        loot: Global loot settings
        
    Returns:
        should_keep (bool): True if item should be kept
        reason (string): Explanation of decision
]]
local function evaluate_inventory_item(item, char_loot, loot)
    if not item or not item.Name then
        return true, "Invalid item"
    end
    
    local item_name = item.Name()
    local item_id = item.ID()
    
    -- Get item database info using the database module directly
    local item_db = database.QueryDatabaseForItemId(item_id)
    if not item_db then
        return true, "Not in database - keeping for safety"
    end
    
    local item_cost = tonumber(item_db.cost) or 0
    local item_guildfavor = tonumber(item_db.guildfavor) or 0
    local is_tradeskill = (tonumber(item_db.tradeskills) == 1)
    local is_nodrop = (tonumber(item_db.nodrop) == 1)
    local db_stacksize = tonumber(item_db.stacksize) or 1
    local is_stackable = db_stacksize > 1
    local item_value_pp = math.floor(item_cost / 1000)  -- Convert packed format to platinum
    
    debug_logger.info("CLEANUP_EVAL: %s - cost=%dpp, favor=%d, tradeskill=%s, nodrop=%s, stackable=%s", 
        item_name, item_value_pp, item_guildfavor, tostring(is_tradeskill), tostring(is_nodrop), tostring(is_stackable))
    
    -- GATE 0: Check if it's an armor tier item that's below minimum tier
    local set_name, piece_type, item_tier = equipment_dist.identify_armor_item(item_name)
    if set_name and item_tier then
        local min_armor_tier = char_loot and char_loot.settings and char_loot.settings.min_armor_tier or 0
        if min_armor_tier > 0 and item_tier < min_armor_tier then
            return false, string.format("Tier %d armor below minimum tier %d", item_tier, min_armor_tier)
        end
    end
    
    -- GATE 1: Quest Items
    local is_quest_item = quest_interface.is_quest_item(item_name)
    if is_quest_item then
        local quest_chars = quest_interface.get_quest_characters_local(item_name)
        local someone_needs_it = quest_chars and next(quest_chars) ~= nil
        
        if someone_needs_it then
            return true, "Needed for active quest"
        end
        
        -- Quest item but not actively needed - THIS is what cleanup targets
        -- Only flag quest items with no value for deletion
        if item_guildfavor == 0 and item_value_pp == 0 then
            return false, "Quest item not currently needed and no resale value"
        else
            return true, string.format("Quest item with value (%dpp, %d favor) - keeping for safety", item_value_pp, item_guildfavor)
        end
    end
    
    -- NOT a quest item - ALWAYS keep it (cleanup only targets quest items)
    return true, "Not a quest item - keeping (cleanup only removes unneeded quest items)"
end

--[[
    Scan character inventory for NO DROP items that can be safely destroyed
    
    Args:
        char_loot: Character loot settings
        loot: Global loot settings
        dry_run: If true, only report what would be destroyed (default: true)
        
    Returns:
        items_to_destroy: Array of {item=item, slot=slot, reason=reason}
]]
function cleanup.scan_inventory(char_loot, loot, dry_run)
    if dry_run == nil then dry_run = true end
    
    local items_to_destroy = {}
    local char_name = mq.TLO.Me.CleanName()
    
    debug_logger.info("CLEANUP: Starting inventory scan for %s (dry_run=%s)", char_name, tostring(dry_run))
    
    -- Scan all inventory slots (pack slots 1-10, plus main inventory slots 23-32)
    local slots_to_check = {}
    
    -- Main inventory (top level)
    for i = 23, 32 do
        table.insert(slots_to_check, {type = "InvSlot", slot = i})
    end
    
    -- Packs (slots 1-10 contain bags, each bag has slots 1-N)
    for pack = 1, 10 do
        local container = mq.TLO.Me.Inventory("pack" .. pack).Container
        if container and container() and container() > 0 then
            local num_slots = container()
            for slot = 1, num_slots do
                table.insert(slots_to_check, {type = "pack", pack = pack, slot = slot})
            end
        end
    end
    
    debug_logger.info("CLEANUP: Checking %d inventory locations", #slots_to_check)
    
    -- Check each slot
    for _, location in ipairs(slots_to_check) do
        local item
        local slot_name
        
        if location.type == "InvSlot" then
            item = mq.TLO.Me.Inventory(location.slot)
            slot_name = string.format("InvSlot %d", location.slot)
        else
            item = mq.TLO.Me.Inventory("pack" .. location.pack).Item(location.slot)
            slot_name = string.format("Pack %d Slot %d", location.pack, location.slot)
        end
        
    if item and item.ID() and item.ID() > 0 then
        local item_name = item.Name()
        local is_nodrop = item.NoDrop()
        
        -- Skip bags/containers - never destroy those
        local is_container = item.Container() and item.Container() > 0
        if is_container then
            debug_logger.info("CLEANUP: Skipping %s in %s - it's a bag/container", item_name, slot_name)
        -- Only evaluate NO DROP items
        elseif is_nodrop then
            local should_keep, reason = evaluate_inventory_item(item, char_loot, loot)                if not should_keep then
                    table.insert(items_to_destroy, {
                        item = item,
                        name = item_name,
                        slot = slot_name,
                        reason = reason
                    })
                    debug_logger.info("CLEANUP: %s [%s] - DESTROY: %s", item_name, slot_name, reason)
                else
                    debug_logger.debug("CLEANUP: %s [%s] - KEEP: %s", item_name, slot_name, reason)
                end
            end
        end
    end
    
    return items_to_destroy
end

--[[
    Destroy items from the scan results
    
    Args:
        items_to_destroy: Array from scan_inventory()
        
    Returns:
        destroyed_count: Number of items destroyed
]]
function cleanup.destroy_items(items_to_destroy)
    local destroyed_count = 0
    
    for _, entry in ipairs(items_to_destroy) do
        debug_logger.info("CLEANUP_DESTROY: Destroying %s [%s] - %s", entry.name, entry.slot, entry.reason)
        
        -- Use /destroy command to destroy the item
        mq.cmdf('/destroy "%s"', entry.name)
        mq.delay(500)  -- Small delay to allow destruction
        
        destroyed_count = destroyed_count + 1
    end
    
    return destroyed_count
end

return cleanup
