-- Simple debug script to verify the fixed get_inventory_items function
package.path = package.path .. ';' .. mq.luaDir .. '/yalm2/?'

local function get_inventory_items()
    --[[
    Get all items in inventory including inside containers (slots 23+)
    Returns table of {item_id, item_name}
    ]]
    
    local items = {}
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    
    if not ok_me or not me then
        mq.cmdf('/echo [TEST] Failed to get Me object')
        return items
    end
    
    -- Inventory slots start at 23
    local max_slots = 50  -- Only go up to reasonable max
    
    for i = 23, max_slots do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if not ok_item or not item then
            mq.cmdf('/echo [TEST] Slot %d: pcall failed or no item', i)
            break  -- End of inventory
        end
        
        -- Check if item actually exists (not an empty slot)
        local ok_id, item_id = pcall(function() return item.ID() end)
        if not ok_id or not item_id or item_id == 0 then
            mq.cmdf('/echo [TEST] Slot %d: ID check failed or empty (id=%s)', i, tostring(item_id))
            break  -- No more items
        end
        
        local ok_name, item_name = pcall(function() return item.Name() end)
        
        if ok_name and item_name then
            mq.cmdf('/echo [TEST] Slot %d: %s (ID: %d)', i, item_name, item_id)
            table.insert(items, {
                item_id = item_id,
                item_name = item_name,
                slot_index = i
            })
        end
        
        -- Also scan inside this container for sub-items
        local ok_container, is_container = pcall(function() return item.Container() end)
        if ok_container and is_container then
            mq.cmdf('/echo [TEST]   → Container detected')
            -- This item is a container, scan its contents
            local max_container_slots = 50  -- Max items in a container
            for j = 1, max_container_slots do
                local ok_sub, sub_item = pcall(function() return item.Item(j) end)
                if not ok_sub or not sub_item then
                    break  -- End of container
                end
                
                local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
                if not ok_sub_id or not sub_id or sub_id == 0 then
                    break
                end
                
                local ok_sub_name, sub_name = pcall(function() return sub_item.Name() end)
                
                if ok_sub_name and sub_name then
                    mq.cmdf('/echo [TEST]     Sub %d: %s (ID: %d)', j, sub_name, sub_id)
                    table.insert(items, {
                        item_id = sub_id,
                        item_name = sub_name,
                        slot_index = i,
                        container_slot = j
                    })
                end
            end
        end
    end
    
    return items
end

mq.cmdf('/echo ========== TESTING INVENTORY SCANNING ==========')
local items = get_inventory_items()
mq.cmdf('/echo [TEST] TOTAL ITEMS FOUND: %d', #items)
mq.cmdf('/echo ========== END TEST ==========')
