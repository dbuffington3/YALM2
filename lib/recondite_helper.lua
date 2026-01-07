--[[
    Recondite Equipment-Aware Distribution Helper
    
    Handles distribution logic for Recondite armor pieces based on character's
    current equipment and inventory status.
    
    Key Features:
    - Queries remote characters for equipped wrist armor via DanNet
    - Calculates need (0, 1, or 2) based on Recondite gear count
    - Checks inventory for existing Recondite Remnant items
    - Returns need values for optimal distribution
    
    Usage:
        local recondite = require('yalm2.lib.recondite_helper')
        local need = recondite.calculate_need('CharacterName', 'Wrist')
]]

local mq = require('mq')
local dannet = require('yalm2.lib.dannet')

-- ============================================================================
-- Recondite Armor Slot Mappings
-- ============================================================================

-- Armor slot definitions for Recondite items
-- Each armor type maps to which equipment slots store its pieces
local RECONDITE_ARMOR_SLOTS = {
    ['Wrist'] = {
        slots = { 9, 10 },  -- Left Wrist (9), Right Wrist (10)
        remnant_name = 'Recondite Remnant of Truth',
        remnant_id = 56186,
        max_need = 2,
    },
    ['Chest'] = {
        slots = { 17 },  -- Chest
        remnant_name = 'Recondite Remnant of Desire',
        remnant_id = 56192,
        max_need = 1,
    },
    ['Arms'] = {
        slots = { 7 },  -- Arms
        remnant_name = 'Recondite Remnant of Devotion',
        remnant_id = 56190,
        max_need = 1,
    },
    ['Legs'] = {
        slots = { 18 },  -- Legs
        remnant_name = 'Recondite Remnant of Fear',
        remnant_id = 56191,
        max_need = 1,
    },
    ['Head'] = {
        slots = { 2 },  -- Head
        remnant_name = 'Recondite Remnant of Greed',
        remnant_id = 56187,
        max_need = 1,
    },
    ['Hands'] = {
        slots = { 12 },  -- Hands
        remnant_name = 'Recondite Remnant of Knowledge',
        remnant_id = 56189,
        max_need = 1,
    },
    ['Feet'] = {
        slots = { 19 },  -- Feet
        remnant_name = 'Recondite Remnant of Survival',
        remnant_id = 56188,
        max_need = 1,
    },
}

-- Slot number to human-readable name mapping (from check_upgrades.lua)
local SLOT_NAMES = {
    [0] = 'Charm',
    [1] = 'Left Ear',
    [2] = 'Head',
    [3] = 'Face',
    [4] = 'Right Ear',
    [5] = 'Neck',
    [6] = 'Shoulder',
    [7] = 'Arms',
    [8] = 'Back',
    [9] = 'Left Wrist',
    [10] = 'Right Wrist',
    [11] = 'Ranged',
    [12] = 'Hands',
    [13] = 'Main Hand',
    [14] = 'Off Hand',
    [15] = 'Left Finger',
    [16] = 'Right Finger',
    [17] = 'Chest',
    [18] = 'Legs',
    [19] = 'Feet',
    [20] = 'Waist',
    [21] = 'Power Source',
    [22] = 'Ammo',
}

-- ============================================================================
-- DanNet Query Interface
-- ============================================================================

--[[
    Query a character's equipped item in a specific slot via DanNet
    
    Args:
        character_name (string): Name of character to query
        slot_number (int): Equipment slot number (0-22)
    
    Returns:
        (string) Item name in that slot, or empty string if unequipped/unreachable
]]
local function query_equipped_item(character_name, slot_number)
    if not character_name or character_name == '' then
        return ''
    end
    
    -- Use the dannet module to query remote character's equipped item
    local query = string.format('Me.Inventory[%d].Name', slot_number)
    local result = dannet.query(character_name, query, 100)
    
    if result and result ~= '' then
        return result
    end
    
    return ''
end

--[[
    Query a character's inventory count for Recondite Remnant by item ID
    
    Args:
        character_name (string): Name of character to query
        item_id (int): Item ID of the remnant to search for
    
    Returns:
        (int) Number of remnant items found in inventory, or 0 if none/unreachable
    
    Note: Recondite Remnants are crafting materials. Each armor slot has a different remnant.
          Item IDs must be used instead of names for reliable counting.
]]
local function query_inventory_count(character_name, item_id)
    if not character_name or character_name == '' or not item_id then
        return 0
    end
    
    -- Use dannet.query with item ID (not name) for reliable results
    local query = string.format('FindItemCount[%d]', item_id)
    local result = dannet.query(character_name, query, 100)
    
    -- Parse the result, handling NULL returns
    if result and result ~= 'NULL' and result ~= '' then
        local count = tonumber(result)
        if count then
            return count
        end
    end
    
    -- Fallback: return 0 if we can't determine the count
    return 0
end

-- ============================================================================
-- Recondite Equipment Analysis
-- ============================================================================

--[[
    Check if an equipped item contains "Recondite" in its name
    
    Args:
        item_name (string): Name of the equipped item
    
    Returns:
        (bool) True if item is a Recondite piece
]]
local function is_recondite_item(item_name)
    if not item_name or item_name == '' then
        return false
    end
    
    return item_name:lower():find('recondite', 1, true) ~= nil
end

--[[
    Query character's equipped items for a specific armor type
    Counts how many Recondite pieces are already equipped
    
    Args:
        character_name (string): Name of character to query
        armor_type (string): Type of armor ('Wrist', 'Chest', etc.)
    
    Returns:
        (int) Number of Recondite pieces equipped in those slots
]]
local function count_equipped_recondite(character_name, armor_type)
    local armor_config = RECONDITE_ARMOR_SLOTS[armor_type]
    if not armor_config then
        return 0
    end
    
    local count = 0
    
    -- Query each slot for this armor type
    for _, slot_num in ipairs(armor_config.slots) do
        local equipped_item = query_equipped_item(character_name, slot_num)
        if is_recondite_item(equipped_item) then
            count = count + 1
        end
    end
    
    return count
end

--[[
    Calculate how many Recondite pieces a character needs
    
    Algorithm:
    1. Count equipped Recondite pieces in the target armor slots
    2. Count Recondite Remnant items in inventory (crafting materials)
    3. If either count > 0, character doesn't need this drop (they can equip or craft)
    4. Return need value (lower = more need, higher = less need)
    
    For distribution: Give the drop to the character with the LOWEST need value
    
    Args:
        character_name (string): Name of character to evaluate
        armor_type (string): Type of armor ('Wrist', 'Chest', etc.)
    
    Returns:
        (int) Combined need value (0 = no need, higher = satisfied)
]]
local function calculate_need(character_name, armor_type)
    -- Default to 'Wrist' if not specified
    armor_type = armor_type or 'Wrist'
    
    local armor_config = RECONDITE_ARMOR_SLOTS[armor_type]
    if not armor_config then
        return 0
    end
    
    -- Count equipped Recondite pieces (they have equipped items, so less need)
    local equipped_count = count_equipped_recondite(character_name, armor_type)
    
    -- Count Recondite Remnant items in inventory (they can craft more, so less need)
    local remnant_count = query_inventory_count(character_name, armor_config.remnant_id)
    
    -- Combined "satisfaction" score
    -- Higher value = character is more satisfied/has more resources
    -- Lower value = character has greater need
    local satisfaction = equipped_count + remnant_count
    
    return satisfaction
end

-- ============================================================================
-- Distribution Helper Functions
-- ============================================================================

--[[
    Determine best recipient for a Recondite drop from a list of members
    
    Compares need/satisfaction scores and returns the member with the LOWEST score
    (least equipped + fewest remnants = greatest need).
    
    Args:
        member_list (table): List of member objects OR character names to evaluate
                           Each member object should have .Name() method
                           OR can be strings (character names)
        armor_type (string): Type of armor ('Wrist', 'Chest', etc.)
    
    Returns:
        (string, int) Best recipient character name and their satisfaction score
        Returns (nil, 999) if no valid recipients found
]]
local function find_best_recipient(member_list, armor_type)
    if not member_list or #member_list == 0 then
        return nil, 999
    end
    
    armor_type = armor_type or 'Wrist'
    
    local best_char = nil
    local lowest_score = 999  -- Start high, find the lowest
    
    for _, member in ipairs(member_list) do
        -- Extract character name from member object or use string directly
        local char_name = type(member) == 'string' and member or (member.Name and member.Name())
        
        if char_name then
            local score = calculate_need(char_name, armor_type)
            
            -- Select member with LOWEST score (most need)
            if score < lowest_score then
                lowest_score = score
                best_char = char_name
            end
        end
    end
    
    return best_char, lowest_score
end

--[[
    Get detailed breakdown for a character's Recondite status
    Useful for logging and debugging distribution decisions
    
    Args:
        character_name (string): Name of character to analyze
        armor_type (string): Type of armor ('Wrist', 'Chest', etc.)
    
    Returns:
        (table) Breakdown with: equipped, remnants, satisfaction_score
]]
local function get_need_breakdown(character_name, armor_type)
    armor_type = armor_type or 'Wrist'
    
    local armor_config = RECONDITE_ARMOR_SLOTS[armor_type]
    if not armor_config then
        return { equipped = 0, remnants = 0, satisfaction = 0 }
    end
    
    local equipped_count = count_equipped_recondite(character_name, armor_type)
    local remnant_count = query_inventory_count(character_name, armor_config.remnant_id)
    local satisfaction = equipped_count + remnant_count
    
    return {
        character = character_name,
        armor_type = armor_type,
        equipped = equipped_count,
        max_slots = armor_config.max_need,
        remnants = remnant_count,
        remnant_name = armor_config.remnant_name,
        satisfaction = satisfaction,
    }
end

-- ============================================================================
-- Public API
-- ============================================================================

--[[
    Identify if an item is a Recondite Remnant and return its armor type
    
    Args:
        item_name (string): Name of the item
    
    Returns:
        (string, table) Armor type (e.g., 'Wrist') and config, or (nil, nil) if not a remnant
]]
local function identify_recondite_remnant(item_name)
    if not item_name or item_name == '' then
        return nil, nil
    end
    
    local lower_name = item_name:lower()
    
    for armor_type, config in pairs(RECONDITE_ARMOR_SLOTS) do
        if lower_name:find(config.remnant_name:lower(), 1, true) then
            return armor_type, config
        end
    end
    
    return nil, nil
end

return {
    -- Main calculation function
    calculate_need = calculate_need,
    
    -- Distribution helpers
    find_best_recipient = find_best_recipient,
    get_need_breakdown = get_need_breakdown,
    
    -- Item identification
    identify_recondite_remnant = identify_recondite_remnant,
    
    -- Internal utilities (exposed for testing/debugging)
    count_equipped_recondite = count_equipped_recondite,
    query_equipped_item = query_equipped_item,
    query_inventory_count = query_inventory_count,
    is_recondite_item = is_recondite_item,
    
    -- Configuration access
    RECONDITE_ARMOR_SLOTS = RECONDITE_ARMOR_SLOTS,
    SLOT_NAMES = SLOT_NAMES,
}
