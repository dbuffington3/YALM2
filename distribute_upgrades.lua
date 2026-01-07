--[[
    Distribute Upgrades Script
    Takes the results from check_cross_character_upgrades.lua and trades items to characters
    in priority order (Tanks -> Melee DPS -> Healers -> Casters)
    
    Usage: /lua run yalm2/distribute_upgrades.lua
    
    This script:
    1. Reads cross_char_results from the upgrade scanner
    2. Processes characters in priority order
    3. For each upgrade, picks up the item and trades it to the target character
    4. Tracks distribution progress in the log
]]

local mq = require('mq')

-- Access the global cross_char_results table that was populated by check_cross_character_upgrades.lua
-- The upgrade checker populates this global table which persists until the script ends
_G.YALM2_UpgradeResults = _G.YALM2_UpgradeResults or {}

-- ============================================================================
-- Character Priority System (must match check_cross_character_upgrades.lua)
-- ============================================================================

local function is_tank_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'warrior' or c == 'war' or
           c == 'paladin' or c == 'pal' or 
           c == 'shadowknight' or c == 'shadow knight' or c == 'shd'
end

local function is_melee_dps_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'rogue' or c == 'rog' or
           c == 'berserker' or c == 'ber' or
           c == 'monk' or c == 'mnk' or
           c == 'ranger' or c == 'rng' or
           c == 'bard' or c == 'brd'
end

local function is_melee_hybrid_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'beastlord' or c == 'bst' or
           c == 'druid' or c == 'dru'
end

local function is_healer_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'cleric' or c == 'clr' or
           c == 'druid' or c == 'dru' or
           c == 'shaman' or c == 'shm'
end

local function is_pure_caster_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'magician' or c == 'mag' or
           c == 'wizard' or c == 'wiz' or
           c == 'enchanter' or c == 'enc' or
           c == 'necromancer' or c == 'nec'
end

local function get_character_role_priority(character_class)
    if is_tank_class(character_class) then
        return 1, "TANK"
    elseif is_melee_dps_class(character_class) then
        return 2, "MELEE_DPS"
    elseif is_melee_hybrid_class(character_class) then
        return 3, "MELEE_HYBRID"
    elseif is_healer_class(character_class) then
        return 4, "HEALER"
    elseif is_pure_caster_class(character_class) then
        return 5, "CASTER"
    else
        return 99, "UNKNOWN"
    end
end

-- ============================================================================
-- Distribution Functions
-- ============================================================================

local function pick_up_item(slot_index, container_slot)
    --[[
    Pick up an item from inventory
    
    If container_slot is nil: item is in direct inventory (use /autoinventory or direct slot)
    If container_slot is set: item is inside a container at slot_index
    ]]
    if not slot_index then
        mq.cmdf('/echo ERROR: Invalid slot index')
        return false
    end
    
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    if not ok_me or not me then
        mq.cmdf('/echo ERROR: Cannot access character')
        return false
    end
    
    -- Get the item to pick up
    local item = nil
    if container_slot and container_slot > 0 then
        -- Item is inside a container
        local ok_container, container = pcall(function() return me.Inventory(slot_index) end)
        if not ok_container or not container then
            mq.cmdf('/echo ERROR: Cannot access container at slot %d', slot_index)
            return false
        end
        
        local ok_item, item_obj = pcall(function() return container.Item(container_slot) end)
        if not ok_item or not item_obj then
            mq.cmdf('/echo ERROR: Cannot access item in container')
            return false
        end
        
        item = item_obj
    else
        -- Item is in direct inventory
        local ok_item, item_obj = pcall(function() return me.Inventory(slot_index) end)
        if not ok_item or not item_obj then
            mq.cmdf('/echo ERROR: Cannot access item at slot %d', slot_index)
            return false
        end
        
        item = item_obj
    end
    
    if not item then
        mq.cmdf('/echo ERROR: Item not found')
        return false
    end
    
    local ok_name, item_name = pcall(function() return item.Name() end)
    item_name = ok_name and item_name or 'Unknown'
    
    mq.cmdf('/echo Picking up: %s', item_name)
    
    if container_slot and container_slot > 0 then
        -- Use /shift /itemnotify to pick up from container
        local pack_number = slot_index - 22  -- Packs start at slot 23, so pack 1 = slot 23
        mq.cmdf('/shift /itemnotify in pack[%d] %d leftmouseup', pack_number, container_slot)
    else
        -- Use /autoinventory or direct click for direct inventory slots
        mq.cmdf('/shift /itemnotify in inv%d leftmouseup', slot_index)
    end
    
    mq.delay(500)
    return true
end

local function trade_to_character(target_name)
    --[[
    Initiate a trade with the target character
    Assumes the item is already picked up (in cursor)
    ]]
    if not target_name or target_name == "" then
        mq.cmdf('/echo ERROR: Invalid target name')
        return false
    end
    
    mq.cmdf('/echo Trading item to %s', target_name)
    
    -- Initiate trade using /declare or target+trade command
    mq.cmdf('/target %s', target_name)
    mq.delay(100)
    
    -- Request trade
    mq.cmdf('/keypress t')  -- Default bind for trade
    mq.delay(1000)
    
    -- Place item in trade window
    mq.cmdf('/shift /itemnotify trade1 leftmouseup')
    mq.delay(500)
    
    -- Accept trade
    mq.cmdf('/keypress y')  -- Accept trade
    mq.delay(1000)
    
    return true
end

local function distribute_upgrades()
    --[[
    Main distribution loop
    Goes through the upgrade results in priority order
    and trades items to characters
    ]]
    
    -- Check if we have scan results (stored in global table by check_cross_character_upgrades.lua)
    if not _G.YALM2_UpgradeResults or not _G.YALM2_UpgradeResults.upgrades_by_character then
        mq.cmdf('/echo ERROR: No upgrade scan results found. Run check_cross_character_upgrades.lua first')
        return
    end
    
    local results = _G.YALM2_UpgradeResults.upgrades_by_character
    if not results or table.maxn(results) == 0 then
        mq.cmdf('/echo ERROR: No upgrades found in scan results')
        return
    end
    
    mq.cmdf('/echo \ag=================================================\ax')
    mq.cmdf('/echo \ag✓ Starting upgrade distribution\ax')
    mq.cmdf('/echo \ag=================================================\ax')
    
    -- Build list of characters sorted by priority
    local char_list = {}
    for char_name, char_data in pairs(results) do
        table.insert(char_list, {
            name = char_name,
            class = char_data.class,
            level = char_data.level,
            upgrades = char_data.upgrades
        })
    end
    
    -- Sort by priority
    table.sort(char_list, function(a, b)
        local priority_a, _ = get_character_role_priority(a.class)
        local priority_b, _ = get_character_role_priority(b.class)
        if priority_a ~= priority_b then
            return priority_a < priority_b
        end
        return a.name < b.name  -- Alphabetical tiebreaker
    end)
    
    -- Distribution tracking
    local total_traded = 0
    local total_skipped = 0
    
    -- Process each character in priority order
    for _, char_info in ipairs(char_list) do
        if char_info.upgrades and #char_info.upgrades > 0 then
            mq.cmdf('/echo \ay--- Processing %s (%s Lvl %d) - %d upgrade(s) ---\ax', 
                char_info.name, char_info.class, char_info.level, #char_info.upgrades)
            
            for idx, upgrade in ipairs(char_info.upgrades) do
                mq.cmdf('/echo [%d/%d] %s -> %s', idx, #char_info.upgrades, 
                    upgrade.current_item, upgrade.upgrade_item)
                
                -- Pick up the item
                if not pick_up_item(upgrade.upgrade_slot_index, upgrade.upgrade_container_slot) then
                    mq.cmdf('/echo   ERROR: Failed to pick up item')
                    total_skipped = total_skipped + 1
                    goto continue_upgrade
                end
                
                -- Trade to character
                if not trade_to_character(char_info.name) then
                    mq.cmdf('/echo   ERROR: Failed to trade item')
                    total_skipped = total_skipped + 1
                    goto continue_upgrade
                end
                
                mq.cmdf('/echo   \ag✓ Successfully traded\ax')
                total_traded = total_traded + 1
                
                ::continue_upgrade::
                mq.delay(1000)  -- Wait between trades
            end
        end
    end
    
    mq.cmdf('/echo \ao=================================================\ax')
    mq.cmdf('/echo \ag✓ Distribution complete!\ax')
    mq.cmdf('/echo   Traded: %d | Skipped: %d | Total: %d', 
        total_traded, total_skipped, total_traded + total_skipped)
    mq.cmdf('/echo \ao=================================================\ax')
end

-- ============================================================================
-- Main Execution
-- ============================================================================

if _G.YALM2_UpgradeResults and _G.YALM2_UpgradeResults.scan_complete then
    mq.cmdf('/echo Starting distribution of %d upgrades...', table.maxn(_G.YALM2_UpgradeResults.upgrades_by_character))
    distribute_upgrades()
else
    mq.cmdf('/echo ERROR: Upgrade scan not complete. Run check_cross_character_upgrades.lua first')
end
