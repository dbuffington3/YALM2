--[[
    Inspect Item Object Properties
    Usage: /lua run inspect_item_object [item_id]
    
    This script finds an item by ID (or uses first item in inventory)
    and prints ALL available properties on the item object.
    
    Example: /lua run inspect_item_object 133918
]]

local mq = require('mq')

local function inspect_item_object(item_id_arg)
    mq.cmdf('/echo ===== INSPECTING ITEM OBJECT PROPERTIES =====')
    
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    if not ok_me or not me then
        mq.cmdf('/echo Unable to access Me TLO')
        return
    end
    
    local item_id_to_find = nil
    if item_id_arg then
        item_id_to_find = tonumber(item_id_arg)
    end
    
    mq.cmdf('/echo Looking for item (ID: %s)', item_id_arg or "first available")
    
    -- Scan inventory for the item (including inside containers)
    local found_item = nil
    local found_slot = nil
    local found_container_slot = nil
    
    for i = 0, 500 do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if not ok_item or not item then
            goto next_inv_slot
        end
        
        local ok_id, item_id = pcall(function() return item.ID() end)
        if not ok_id or not item_id then
            goto next_inv_slot
        end
        
        item_id = tonumber(item_id) or 0
        
        -- Check this item directly
        if item_id > 0 then
            if item_id_to_find then
                -- Looking for specific item
                if item_id == item_id_to_find then
                    found_item = item
                    found_slot = i
                    found_container_slot = nil
                    break
                end
            else
                -- Use first available item
                found_item = item
                found_slot = i
                found_container_slot = nil
                break
            end
        end
        
        -- Check if this is a container and scan inside
        local ok_container, is_container = pcall(function() return item.Container() end)
        if ok_container and is_container then
            -- Scan inside the container
            for j = 1, 100 do
                local ok_sub, sub_item = pcall(function() return item.Item(j) end)
                if not ok_sub or not sub_item then
                    goto next_container_item
                end
                
                local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
                if not ok_sub_id or not sub_id then
                    goto next_container_item
                end
                
                sub_id = tonumber(sub_id) or 0
                
                if sub_id > 0 then
                    if item_id_to_find then
                        -- Looking for specific item
                        if sub_id == item_id_to_find then
                            found_item = sub_item
                            found_slot = i
                            found_container_slot = j
                            break
                        end
                    else
                        -- Use first available item
                        found_item = sub_item
                        found_slot = i
                        found_container_slot = j
                        break
                    end
                end
                
                ::next_container_item::
            end
            
            if found_item then
                break
            end
        end
        
        ::next_inv_slot::
    end
    
    if not found_item then
        mq.cmdf('/echo Item not found in inventory')
        return
    end
    
    -- Get basic info
    local ok_name, item_name = pcall(function() return found_item.Name() end)
    local ok_id, item_id = pcall(function() return found_item.ID() end)
    
    mq.cmdf('/echo')
    if found_container_slot then
        mq.cmdf('/echo Found item: %s (ID: %d) at slot %d, inside container slot %d', item_name or "Unknown", item_id or 0, found_slot, found_container_slot)
    else
        mq.cmdf('/echo Found item: %s (ID: %d) at slot %d', item_name or "Unknown", item_id or 0, found_slot)
    end
    mq.cmdf('/echo')
    mq.cmdf('/echo ===== TESTING ALL COMMON PROPERTIES =====')
    mq.cmdf('/echo')
    
    -- Test common properties
    local test_props = {
        -- Basic properties
        'ID', 'Name', 'Lore', 'NoRent', 'NoDrop', 'NoTrade',
        
        -- Equipment properties
        'Slots', 'Classes', 'Race', 'Level', 'ReqLevel',
        
        -- Stats
        'AC', 'HP', 'Mana', 'Endurance', 'CHA', 'DEX', 'INT', 'STR', 'AGI', 'WIS',
        'MR', 'FR', 'CR', 'PR', 'DR',
        
        -- Spell/Effect properties
        'Clicky', 'ClickName', 'ClickType', 'ClickLevel', 'ClickEffect',
        'Proc', 'ProcName', 'ProcType', 'ProcLevel', 'ProcEffect',
        'Worn', 'WornName', 'WornType', 'WornLevel', 'WornEffect',
        'Focus', 'FocusName', 'FocusType', 'FocusLevel', 'FocusEffect',
        
        -- Trade/Quest properties
        'Quest', 'QuestFlag', 'Magic', 'Attuned', 'Tradable', 'Trade',
        'Value', 'SellPrice', 'Cost',
        
        -- Container properties
        'Container', 'Charges', 'MaxCharges',
        
        -- Other
        'Type', 'ItemType', 'Material', 'Size', 'Weight', 'Stackable', 'StackSize',
        'Augmentable', 'Lore', 'Heirloom', 'Cursed', 'Collectible', 'Rare',
        'Attack', 'Damage', 'Delay', 'Range', 'Clairvoyance', 'HealAmount',
        'Augment', 'AugType', 'AugRestrict',
    }
    
    for _, prop in ipairs(test_props) do
        local ok, result = pcall(function() return found_item[prop]() end)
        if ok and result ~= nil and result ~= "NULL" and result ~= 0 and result ~= "" then
            mq.cmdf('/echo \ag✓\ax %s: \ay%s\ax (type: %s)', prop, tostring(result), type(result))
        end
    end
    
    mq.cmdf('/echo')
    mq.cmdf('/echo ===== TRYING DIRECT TABLE ACCESS (NOT FUNCTION CALLS) =====')
    mq.cmdf('/echo')
    
    -- Try direct table access without calling as functions
    for _, prop in ipairs(test_props) do
        local ok, result = pcall(function() return found_item[prop] end)
        if ok and result ~= nil and type(result) ~= "function" then
            mq.cmdf('/echo \ag✓\ax %s (direct): \ay%s\ax (type: %s)', prop, tostring(result), type(result))
        end
    end
    
    mq.cmdf('/echo')
    mq.cmdf('/echo ===== INSPECTING TABLE STRUCTURE =====')
    mq.cmdf('/echo')
    
    -- Try to iterate the table
    local ok_pairs, count = pcall(function()
        local c = 0
        for key, value in pairs(found_item) do
            c = c + 1
            if c <= 50 then  -- Limit output to first 50 keys
                local val_str = tostring(value)
                if string.len(val_str) > 50 then
                    val_str = val_str:sub(1, 50) .. "..."
                end
                mq.cmdf('/echo  Key: %s, Type: %s, Value: %s', tostring(key), type(value), val_str)
            end
        end
        return c
    end)
    
    if ok_pairs then
        mq.cmdf('/echo Total keys in table: %d', count)
    else
        mq.cmdf('/echo Could not iterate table pairs')
    end
    
    mq.cmdf('/echo')
    mq.cmdf('/echo ===== DONE =====')
end

-- Get argument from command line
local args = {...}
inspect_item_object(args[1])
