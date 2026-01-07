--[[
    Test inventory scanning
]]

local mq = require('mq')

local function scan_inventory()
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    if not ok_me or not me then
        print("Failed to get Me TLO")
        return
    end
    
    local items_found = 0
    local containers_found = 0
    local items_in_containers = 0
    
    -- Inventory slots start at 23
    for i = 23, 500 do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if not ok_item or not item then
            goto next_slot
        end
        
        local ok_id, item_id = pcall(function() return item.ID() end)
        if not ok_id or not item_id or item_id == 0 then
            goto next_slot
        end
        
        local ok_name, item_name = pcall(function() return item.Name() end)
        if ok_name and item_name then
            items_found = items_found + 1
            
            -- Check if it's a container
            local ok_cont, is_cont = pcall(function() return item.Container() end)
            if ok_cont and is_cont then
                containers_found = containers_found + 1
                print(string.format("[%d] %s (id=%d) - CONTAINER", i, item_name, item_id))
                
                -- Scan container items
                for j = 1, 100 do
                    local ok_sub, sub_item = pcall(function() return item.Item(j) end)
                    if not ok_sub or not sub_item then
                        goto skip_sub
                    end
                    
                    local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
                    if not ok_sub_id or not sub_id or sub_id == 0 then
                        goto skip_sub
                    end
                    
                    local ok_sub_name, sub_name = pcall(function() return sub_item.Name() end)
                    if ok_sub_name and sub_name then
                        items_in_containers = items_in_containers + 1
                        print(string.format("  [%d.%d] %s (id=%d)", i, j, sub_name, sub_id))
                    end
                    
                    ::skip_sub::
                end
            else
                print(string.format("[%d] %s (id=%d)", i, item_name, item_id))
            end
        end
        
        ::next_slot::
    end
    
    print("\n========================================")
    print(string.format("Total inventory items: %d", items_found))
    print(string.format("Containers found: %d", containers_found))
    print(string.format("Items in containers: %d", items_in_containers))
    print(string.format("Total items (with containers): %d", items_found + items_in_containers))
end

scan_inventory()
