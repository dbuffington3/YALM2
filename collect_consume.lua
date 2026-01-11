--[[
    Collectible Consumer
    
    Scans your inventory for collectible items and right-clicks them to add 
    them to your collections. If already collected, nothing happens.
    
    Usage: /lua run yalm2/collect_consume
    
    This is meant to be run on each character after collectibles have been
    distributed to them via collection_distribute.lua
]]

local mq = require('mq')

-- Configuration
local DELAY_BETWEEN_ITEMS = 500  -- ms between each item consumption

local function is_collectible(item)
    if not item or not item() then return false end
    return item.Collectible() == true
end

local function find_collectibles_in_inventory()
    local collectibles = {}
    
    -- Scan pack slots (bags in inventory)
    for pack_idx = 1, 10 do
        local pack = mq.TLO.Me.Inventory('pack' .. pack_idx)
        if pack() then
            local container_size = pack.Container() or 0
            if container_size > 0 then
                -- It's a bag, scan inside
                for slot = 1, container_size do
                    local item = pack.Item(slot)
                    if item() and is_collectible(item) then
                        local item_name = item.Name()
                        if item_name then
                            table.insert(collectibles, {
                                item_name = item_name,
                                pack_idx = pack_idx,
                                slot = slot
                            })
                        end
                    end
                end
            end
        end
    end
    
    return collectibles
end

local function consume_collectible(pack_idx, slot, item_name)
    -- Use the item to add it to collection
    -- /useitem works on items in inventory by name
    mq.cmdf('/useitem "%s"', item_name)
    mq.delay(DELAY_BETWEEN_ITEMS)
    
    -- Wait a bit more for the action to complete
    mq.delay(200)
    
    -- Check if the item is still there (means it wasn't consumed - already collected)
    local item = mq.TLO.Me.Inventory('pack' .. pack_idx).Item(slot)
    if item() and item.Name() == item_name then
        return false  -- Item still there, already collected
    end
    return true  -- Item consumed
end

local function main()
    local my_name = mq.TLO.Me.DisplayName()
    mq.cmdf('/echo \ay[CollectConsume] Scanning %s for collectibles...\ax', my_name)
    
    local collectibles = find_collectibles_in_inventory()
    
    if #collectibles == 0 then
        mq.cmd('/echo \ag[CollectConsume] No collectible items found in inventory.\ax')
        return
    end
    
    mq.cmdf('/echo \ay[CollectConsume] Found %d collectible items. Consuming...\ax', #collectibles)
    
    local consumed = 0
    local already_collected = 0
    
    for i, item in ipairs(collectibles) do
        mq.cmdf('/echo [CollectConsume] (%d/%d) %s...', i, #collectibles, item.item_name)
        
        if consume_collectible(item.pack_idx, item.slot, item.item_name) then
            consumed = consumed + 1
            mq.cmdf('/echo \ag  -> Added to collection!\ax')
        else
            already_collected = already_collected + 1
            mq.cmdf('/echo \ay  -> Already collected (keeping item)\ax')
        end
    end
    
    mq.cmd('/echo ')
    mq.cmdf('/echo \ag[CollectConsume] Done! Added %d items to collections.\ax', consumed)
    if already_collected > 0 then
        mq.cmdf('/echo \ay[CollectConsume] %d items were already collected and remain in inventory.\ax', already_collected)
    end
end

main()
