-- Debug: Check what get_inventory_items is actually finding
package.path = package.path .. ';' .. mq.luaDir .. '/?'
package.path = package.path .. ';' .. mq.luaDir .. '/yalm2/?'

local inventory_items = {}

local me = mq.TLO.Me()

mq.cmdf('/echo [DEBUG] Scanning inventory slots 23-100...')

local inventory_items = {}
local max_slots = 100

for i = 23, max_slots do
    local ok_item, item = pcall(function() return me.Inventory(i) end)
    if not ok_item or not item then
        mq.cmdf('/echo [DEBUG] Slot %d: No item object (break)', i)
        break
    end
    
    local ok_exists, item_exists = pcall(function() return item() end)
    if not ok_exists or not item_exists then
        mq.cmdf('/echo [DEBUG] Slot %d: Item call failed (break)', i)
        break
    end
    
    local ok_id, item_id = pcall(function() return item.ID() end)
    local ok_name, item_name = pcall(function() return item.Name() end)
    
    if ok_id and item_id and item_id > 0 and ok_name and item_name then
        mq.cmdf('/echo [DEBUG] Slot %d: %s (ID: %d)', i, item_name, item_id)
        table.insert(inventory_items, {
            item_id = item_id,
            item_name = item_name,
            slot_index = i
        })
        
        -- Check container
        local ok_container, is_container = pcall(function() return item.Container() end)
        if ok_container and is_container then
            mq.cmdf('/echo [DEBUG]   → This is a container, scanning...')
            local max_container_slots = 50
            for j = 1, max_container_slots do
                local ok_sub, sub_item = pcall(function() return item.Item(j) end)
                if not ok_sub or not sub_item then
                    break
                end
                
                local ok_sub_exists, sub_exists = pcall(function() return sub_item() end)
                if not ok_sub_exists or not sub_exists then
                    break
                end
                
                local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
                local ok_sub_name, sub_name = pcall(function() return sub_item.Name() end)
                
                if ok_sub_id and sub_id and sub_id > 0 and ok_sub_name and sub_name then
                    mq.cmdf('/echo [DEBUG]     Sub %d: %s (ID: %d)', j, sub_name, sub_id)
                    table.insert(inventory_items, {
                        item_id = sub_id,
                        item_name = sub_name,
                        slot_index = i,
                        container_slot = j
                    })
                end
            end
        end
    else
        mq.cmdf('/echo [DEBUG] Slot %d: Invalid item (ok_id=%s, ok_name=%s, id=%s, name=%s)', 
                 i, tostring(ok_id), tostring(ok_name), tostring(item_id), tostring(item_name))
    end
end

mq.cmdf('/echo [DEBUG] TOTAL ITEMS FOUND: %d', #inventory_items)
