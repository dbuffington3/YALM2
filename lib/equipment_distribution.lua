--[[
    Generic Equipment Distribution Helper
    
    Handles equipment-aware distribution for armor sets defined in config/armor_sets.lua
    
    Features:
    - Works with any armor set configuration
    - Detects equipped pieces across multiple slots
    - Counts crafting materials (remnants) in inventory
    - Calculates character need based on equipment + inventory
    - Picks best recipient (lowest satisfaction = highest need)
    
    Usage:
        local equipment_dist = require('yalm2.lib.equipment_distribution')
        
        -- Check if item is part of an armor set
        local set_name, piece_type = equipment_dist.identify_armor_item(item_name)
        
        -- Find best recipient from member list
        local best_member, score = equipment_dist.find_best_recipient(member_list, set_name, piece_type)
        
        -- Get detailed breakdown for a character
        local breakdown = equipment_dist.get_need_breakdown(char_name, set_name, piece_type)
]]

local mq = require('mq')
local dannet = require('yalm2.lib.dannet')
local debug_logger = require('yalm2.lib.debug_logger')
local armor_module = require('yalm2.config.armor_sets')
local armor_sets = armor_module.armor_sets
local ARMOR_PROGRESSION = armor_module.ARMOR_PROGRESSION

-- ============================================================================
-- Slot Names Mapping
-- ============================================================================

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
-- Equipment Queries via DanNet
-- ============================================================================

--[[
    Query a character's equipped item in a specific slot
    
    Args:
        character_name (string): Name of character to query
        slot_number (int): Equipment slot number (0-22)
    
    Returns:
        (string) Item name in that slot, or empty string if unequipped
]]
local function query_equipped_item(character_name, slot_number)
    if not character_name or character_name == '' then
        return ''
    end
    
    local query = string.format('Me.Inventory[%d].Name', slot_number)
    local result = dannet.query(character_name, query, 100)
    
    if result and result ~= '' then
        return result
    end
    
    return ''
end

--[[
    Query a character's inventory count for a specific item by ID
    
    Args:
        character_name (string): Name of character to query
        item_id (int): Item ID to search for
    
    Returns:
        (int) Number of items found in inventory, or 0 if none
]]
local function query_inventory_count(character_name, item_id)
    if not character_name or character_name == '' or not item_id then
        return 0
    end
    
    local query = string.format('FindItemCount[%d]', item_id)
    local result = dannet.query(character_name, query, 100)
    
    if result and result ~= 'NULL' and result ~= '' then
        local count = tonumber(result)
        if count then
            return count
        end
    end
    
    return 0
end

--[[
    Count inventory (non-equipped) copies of an armor piece by name
    This counts pieces sitting in the character's bags but not equipped
    
    Args:
        character_name (string): Name of character
        item_name (string): Name of the armor piece to count
    
    Returns:
        (int) Count of that item in inventory (excluding what's equipped)
]]
local function count_inventory_pieces(character_name, item_name)
    if not character_name or character_name == '' or not item_name then
        return 0
    end
    
    -- Use FindItemCount with the item name - this counts ALL copies (equipped + inventory)
    -- We'll subtract equipped count in the caller to get just inventory pieces
    local query = string.format('FindItemCount[%s]', item_name)
    local result = dannet.query(character_name, query, 100)
    
    if result and result ~= 'NULL' and result ~= '' then
        local count = tonumber(result)
        if count then
            return count
        end
    end
    
    return 0
end

-- ============================================================================
-- Item/Armor Set Identification
-- ============================================================================

--[[
    Check if a string is part of an armor set piece name (case-insensitive)
    
    Args:
        item_name (string): Item name to check
        search_string (string): String to search for
    
    Returns:
        (bool) True if found
]]
local function contains_string(item_name, search_string)
    if not item_name or not search_string then
        return false
    end
    
    local lower_item = item_name:lower()
    local lower_search = search_string:lower()
    
    return lower_item:find(lower_search, 1, true) ~= nil
end

--[[
    Get the tier of an armor item by its name
    
    Args:
        item_name (string): Name of the item
    
    Returns:
        (int or nil) Tier number (1=Fear Touched/Fear Stained, 2=Boreal/Distorted, 3+)
        Returns nil if tier cannot be determined
]]
local function get_armor_item_tier(item_name)
    if not item_name or item_name == '' or not ARMOR_PROGRESSION then
        debug_logger.info("TIER_CHECK: item_name=%s, ARMOR_PROGRESSION exists=%s", tostring(item_name), tostring(ARMOR_PROGRESSION ~= nil))
        return nil
    end
    
    -- Check each progression entry to see if item name contains it
    for progression_set_name, progression_info in pairs(ARMOR_PROGRESSION) do
        if item_name:lower():find(progression_set_name:lower(), 1, true) then
            debug_logger.info("TIER_CHECK: %s matched progression '%s' with tier=%s", item_name, progression_set_name, tostring(progression_info.tier))
            return progression_info.tier
        end
    end
    
    debug_logger.info("TIER_CHECK: %s NOT FOUND in any progression entry", item_name)
    return nil
end

--[[
    Identify if an item is part of a defined armor set
    
    Args:
        item_name (string): Name of the item
    
    Returns:
        (string, string, int or nil) Armor set name, piece type, and tier (or nil if tier unknown)
        Example: ('Recondite', 'Wrist', 1)
]]
local function identify_armor_item(item_name)
    if not item_name or item_name == '' then
        return nil, nil, nil
    end
    
    for set_name, set_config in pairs(armor_sets) do
        if set_config.pieces then
            -- First check if item name contains the set name (e.g., "Crude Defiant Plate Helm" contains "Crude Defiant")
            if contains_string(item_name, set_name) then
                -- Now check which piece type it matches
                for piece_type, piece_config in pairs(set_config.pieces) do
                    -- For Defiant/dropped armor with no remnants, we just check if it's in this piece's slot
                    -- We can't check slots directly from item_name, so we assume the set name match is sufficient
                    -- and return the first piece that could plausibly match
                    -- This is a simplification - in practice, we rely on the item name keywords
                    local tier = get_armor_item_tier(item_name)
                    debug_logger.info("ARMOR_IDENTIFY: %s matched %s/%s, tier=%s", item_name, set_name, piece_type, tostring(tier))
                    
                    -- Try to identify piece type from item name keywords
                    local lower_name = item_name:lower()
                    if piece_type == 'Head' and (lower_name:find('helm') or lower_name:find('coif') or lower_name:find('cap')) then
                        return set_name, 'Head', tier
                    elseif piece_type == 'Arms' and (lower_name:find('vambrace') or lower_name:find('sleeves') or lower_name:find('arms')) then
                        return set_name, 'Arms', tier
                    elseif piece_type == 'Wrist' and (lower_name:find('bracer') or lower_name:find('wrist')) then
                        return set_name, 'Wrist', tier
                    elseif piece_type == 'Hands' and (lower_name:find('gauntlet') or lower_name:find('gloves') or lower_name:find('hands')) then
                        return set_name, 'Hands', tier
                    elseif piece_type == 'Chest' and (lower_name:find('breastplate') or lower_name:find('tunic') or lower_name:find('robe') or lower_name:find('chest')) then
                        return set_name, 'Chest', tier
                    elseif piece_type == 'Legs' and (lower_name:find('greaves') or lower_name:find('leggings') or lower_name:find('legs') or lower_name:find('trousers') or lower_name:find('pantaloons')) then
                        return set_name, 'Legs', tier
                    elseif piece_type == 'Feet' and (lower_name:find('boots') or lower_name:find('sandals') or lower_name:find('feet')) then
                        return set_name, 'Feet', tier
                    elseif piece_type == 'Primary' and (lower_name:find('axe') or lower_name:find('sword') or lower_name:find('mace') or lower_name:find('club') or lower_name:find('dagger') or lower_name:find('spear') or lower_name:find('staff') or lower_name:find('fists')) then
                        return set_name, 'Primary', tier
                    elseif piece_type == 'Secondary' and (lower_name:find('shield') or lower_name:find('buckler')) then
                        return set_name, 'Secondary', tier
                    elseif piece_type == 'Ranged' and (lower_name:find('bow') or lower_name:find('pebble') or lower_name:find('fragment') or lower_name:find('shard')) then
                        return set_name, 'Ranged', tier
                    end
                end
            end
            
            -- If set name didn't match, check remnant names (for crafted armor)
            for piece_type, piece_config in pairs(set_config.pieces) do
                if piece_config.remnant_name and contains_string(item_name, piece_config.remnant_name) then
                    local tier = get_armor_item_tier(item_name)
                    debug_logger.info("ARMOR_IDENTIFY: %s matched %s/%s (remnant), tier=%s", item_name, set_name, piece_type, tostring(tier))
                    return set_name, piece_type, tier
                end
            end
        end
    end
    
    -- Not found in any armor set
    debug_logger.info("ARMOR_IDENTIFY: %s NOT FOUND in any armor set", item_name)
    return nil, nil, nil
end

-- ============================================================================
-- Equipment Analysis
-- ============================================================================

--[[
    Check if a character already has a higher-tier final product equipped
    
    For example, if distributing "Fear Stained Leggings" (tier 2 crafting material
    that creates Distorted), check if character already has Distorted, Twilight, 
    or Frightweave equipped in the same piece type.
    
    Args:
        character_name (string): Name of character to check
        set_name (string): The set we're trying to distribute (e.g., 'Fear Stained')
        piece_type (string): Piece type (e.g., 'Legs')
    
    Returns:
        (bool) True if character has a higher-tier final product equipped
        (table or nil) The progression info of the higher-tier product if found
]]
local function has_higher_tier_product_equipped(character_name, set_name, piece_type)
    debug_logger.info("HIGHER_TIER_CHECK: ENTRY - Checking %s for %s / %s", character_name, set_name, piece_type)
    
    if not ARMOR_PROGRESSION or not ARMOR_PROGRESSION[set_name] then
        debug_logger.info("HIGHER_TIER_CHECK: EXIT EARLY - No ARMOR_PROGRESSION entry for %s", set_name)
        return false, nil
    end
    
    local current_tier = ARMOR_PROGRESSION[set_name].tier
    if not current_tier then
        debug_logger.info("HIGHER_TIER_CHECK: EXIT EARLY - No tier for %s", set_name)
        return false, nil
    end
    
    debug_logger.info("HIGHER_TIER_CHECK: %s is tier %d, checking for higher tiers...", set_name, current_tier)
    
    local set_config = armor_sets[set_name]
    if not set_config or not set_config.pieces or not set_config.pieces[piece_type] then
        debug_logger.info("HIGHER_TIER_CHECK: EXIT EARLY - No armor_sets config for %s / %s", set_name, piece_type)
        return false, nil
    end
    
    local piece_config = set_config.pieces[piece_type]
    if not piece_config.slots or #piece_config.slots == 0 then
        debug_logger.info("HIGHER_TIER_CHECK: EXIT EARLY - No slots configured for %s / %s", set_name, piece_type)
        return false, nil
    end
    
    -- Check what's currently equipped in this slot
    local slot_index = piece_config.slots[1]
    debug_logger.info("HIGHER_TIER_CHECK: Querying %s slot %d for equipped item...", character_name, slot_index)
    local query = string.format('Me.Inventory[%d].Name', slot_index)
    local equipped_item = dannet.query(character_name, query, 100)
    
    debug_logger.info("HIGHER_TIER_CHECK: %s slot %d query result: '%s' (checking for upgrades to %s tier %d)", 
        character_name, slot_index, tostring(equipped_item), set_name, current_tier)
    
    if not equipped_item or equipped_item == 'NULL' or equipped_item == '' then
        -- Nothing equipped, so no higher-tier product
        debug_logger.info("HIGHER_TIER_CHECK: %s has nothing equipped in slot %d", character_name, slot_index)
        return false, nil
    end
    
    -- Check if the equipped item matches any higher-tier armor set
    if ARMOR_PROGRESSION then
        for progression_name, progression_info in pairs(ARMOR_PROGRESSION) do
            -- Only check higher tiers (tier > current_tier)
            if progression_info and progression_info.tier and progression_info.tier > current_tier then
                debug_logger.info("HIGHER_TIER_CHECK: Checking if '%s' contains '%s' (tier %d > %d)", 
                    equipped_item, progression_name, progression_info.tier, current_tier)
                -- Check if character has this higher-tier armor equipped
                if armor_sets[progression_name] and armor_sets[progression_name].pieces and armor_sets[progression_name].pieces[piece_type] then
                    local higher_piece_config = armor_sets[progression_name].pieces[piece_type]
                    -- Check if equipped item matches this higher-tier set
                    if contains_string(equipped_item, progression_name) then
                        debug_logger.info("HIGHER_TIER: %s has %s equipped (tier %d) vs distributing %s (tier %d)", 
                            character_name, progression_name, progression_info.tier, set_name, current_tier)
                        return true, progression_info
                    else
                        debug_logger.info("HIGHER_TIER_CHECK: '%s' does NOT contain '%s'", equipped_item, progression_name)
                    end
                end
            end
        end
    end
    
    return false, nil
end

--[[
    Check if an equipped item is part of a specific armor set
    
    Args:
        item_name (string): Name of the equipped item
        set_name (string): Armor set name (e.g., 'Recondite')
    
    Returns:
        (bool) True if item is part of the armor set
]]
local function is_armor_set_piece(item_name, set_name)
    if not item_name or not set_name then
        return false
    end
    
    local set_config = armor_sets[set_name]
    if not set_config then
        return false
    end
    
    for _, piece_config in pairs(set_config.pieces) do
        if contains_string(item_name, set_name) then
            return true
        end
    end
    
    return false
end

--[[
    Count how many pieces of an armor set are equipped in target slots
    
    Args:
        character_name (string): Name of character to query
        set_name (string): Armor set name (e.g., 'Recondite')
        piece_type (string): Piece type within set (e.g., 'Wrist')
    
    Returns:
        (int) Number of armor set pieces equipped in those slots
]]
local function count_equipped_pieces(character_name, set_name, piece_type)
    local set_config = armor_sets[set_name]
    if not set_config or not set_config.pieces or not set_config.pieces[piece_type] then
        return 0
    end
    
    local piece_config = set_config.pieces[piece_type]
    local count = 0
    local slot_details = {}
    
    for _, slot_num in ipairs(piece_config.slots) do
        local equipped_item = query_equipped_item(character_name, slot_num)
        table.insert(slot_details, string.format("Slot%d:%s", slot_num, equipped_item or "EMPTY"))
        
        if is_armor_set_piece(equipped_item, set_name) then
            count = count + 1
        end
    end
    
    mq.cmd(string.format('/echo [ARMOR_EQUIPPED] %s - Slots[%s] -> %d/%d equipped for %s/%s', 
        character_name, table.concat(slot_details, ","), count, piece_config.max_slots, set_name, piece_type))
    
    return count
end

-- ============================================================================
-- Need Calculation
-- ============================================================================

--[[
    Calculate character's "satisfaction" score for an armor piece
    
    Algorithm:
    - Satisfaction = equipped_count + inventory_count + remnant_count
    - Higher score = more satisfied/has more resources
    - Lower score = greater need
    
    Args:
        character_name (string): Name of character to evaluate
        set_name (string): Armor set name
        piece_type (string): Piece type within set
    
    Returns:
        (int) Satisfaction score (0 = highest need)
]]
local function calculate_satisfaction(character_name, set_name, piece_type)
    local set_config = armor_sets[set_name]
    if not set_config or not set_config.pieces or not set_config.pieces[piece_type] then
        mq.cmd(string.format('/echo [ARMOR_SAT] ERROR: Invalid set or piece - Set: %s, Piece: %s for %s', 
            set_name, piece_type, character_name))
        return 0
    end
    
    local piece_config = set_config.pieces[piece_type]
    
    -- Count equipped pieces
    local equipped_count = count_equipped_pieces(character_name, set_name, piece_type)
    
    -- Count inventory pieces (unequipped copies in bags) - for dropped armor sets
    -- For crafted armor, remnant_name = the actual crafted piece name
    -- For dropped armor, remnant_name = the dropped piece name  
    local inventory_count = 0
    if piece_config.remnant_name then
        -- Get TOTAL count of item (equipped + inventory)
        local total_count = count_inventory_pieces(character_name, piece_config.remnant_name)
        -- Inventory count = total minus what's equipped
        inventory_count = math.max(0, total_count - equipped_count)
    end
    
    -- Count remnants (actual crafting materials, like leather for armor)
    -- This will be 0 for dropped armor sets, but used for crafted sets
    local remnant_count = query_inventory_count(character_name, piece_config.remnant_id)
    
    -- Combined satisfaction: higher = more satisfied
    local satisfaction = equipped_count + inventory_count + remnant_count
    
    mq.cmd(string.format('/echo [ARMOR_SAT] %s - Set:%s Piece:%s -> Equipped:%d + Inv:%d + Remnants:%d = Score:%d', 
        character_name, set_name, piece_type, equipped_count, inventory_count, remnant_count, satisfaction))
    
    return satisfaction
end

--[[
    Get the tier of armor currently equipped in a character's target slot
    
    Args:
        character_name (string): Name of character to check
        set_name (string): Armor set name (e.g., 'Recondite')
        piece_type (string): Piece type to check (e.g., 'Wrist')
    
    Returns:
        (int or nil) Tier number if armor is equipped (1=Fear Touched/Fear Stained, 2=Boreal/Distorted, 3=Distorted)
        Returns nil if no armor of this set/piece is equipped
        
    Logic:
        1. Query character for what item is equipped in this piece type's slots
        2. Match the item name against ARMOR_PROGRESSION to find tier
        3. Return the tier number or nil if unequipped
]]
local function get_equipped_armor_tier(character_name, set_name, piece_type)
    debug_logger.info("GET_TIER: Checking %s for %s/%s", character_name, set_name, piece_type)
    
    if not armor_sets[set_name] or not armor_sets[set_name].pieces[piece_type] then
        debug_logger.info("GET_TIER: No armor_sets config for %s/%s", set_name, piece_type)
        return nil
    end
    
    local piece_config = armor_sets[set_name].pieces[piece_type]
    if not piece_config.slots or #piece_config.slots == 0 then
        debug_logger.info("GET_TIER: No slots configured for %s/%s", set_name, piece_type)
        return nil
    end
    
    -- Check ALL slots for this piece type (e.g., both wrist slots)
    -- Only return a tier if ALL slots have items equipped
    -- Return the LOWEST tier found across all slots (the upgrade opportunity)
    local lowest_tier = nil
    local all_slots_filled = true
    
    for _, slot_index in ipairs(piece_config.slots) do
        local query = string.format('Me.Inventory[%d].Name', slot_index)
        
        debug_logger.info("GET_TIER: Querying %s slot %d...", character_name, slot_index)
        local result = dannet.query(character_name, query, 100)
        debug_logger.info("GET_TIER: %s slot %d result: '%s'", character_name, slot_index, tostring(result))
        
        if not result or result == 'NULL' or result == '' then
            -- This slot is empty - character could use the item here
            debug_logger.info("GET_TIER: %s slot %d is empty - character needs item", character_name, slot_index)
            all_slots_filled = false
            break
        end
        
        -- We have an item equipped. Find its tier in ARMOR_PROGRESSION
        local equipped_name = result
        
        debug_logger.info("GET_TIER: Searching ARMOR_PROGRESSION for '%s' in slot %d", equipped_name, slot_index)
        
        local found_tier = nil
        if ARMOR_PROGRESSION then
            for progression_set_name, progression_info in pairs(ARMOR_PROGRESSION) do
                if equipped_name:lower():find(progression_set_name:lower(), 1, true) then
                    found_tier = progression_info.tier
                    debug_logger.info("GET_TIER: MATCH! Slot %d '%s' contains '%s' (tier %d)", 
                        slot_index, equipped_name, progression_set_name, found_tier)
                    break
                end
            end
        end
        
        if not found_tier then
            -- Item in this slot isn't in our progression system - treat as no tier (can be replaced)
            debug_logger.info("GET_TIER: No ARMOR_PROGRESSION match for '%s' in slot %d - can be replaced", equipped_name, slot_index)
            all_slots_filled = false
            break
        end
        
        -- Track the lowest tier across all slots
        if not lowest_tier or found_tier < lowest_tier then
            lowest_tier = found_tier
        end
    end
    
    -- Only skip if ALL slots are filled AND all have tier >= item tier (checked by caller)
    if not all_slots_filled then
        debug_logger.info("GET_TIER: %s has empty/replaceable slots - returning nil (don't skip)", character_name)
        return nil
    end
    
    debug_logger.info("GET_TIER: %s has ALL slots filled, lowest tier = %s", character_name, tostring(lowest_tier))
    mq.cmd(string.format('/echo [ARMOR_TIER] %s has all %s slots filled (lowest tier %s)', 
        character_name, piece_type, tostring(lowest_tier)))
    return lowest_tier
end

-- ============================================================================
-- Distribution Helpers
-- ============================================================================

--[[
    Find the best recipient for an armor piece from a member list
    
    Args:
        member_list (table): List of member objects or character names
        set_name (string): Armor set name (e.g., 'Recondite')
        piece_type (string): Piece type within set (e.g., 'Wrist')
        item_tier (int or nil): Tier of the item being distributed (optional)
                                If provided, filters out characters with same/higher tier equipped
    
    Returns:
        (string, int) Best recipient character name and their satisfaction score
        Returns (nil, 999) if no valid recipients
]]
local function find_best_recipient(member_list, set_name, piece_type, item_tier)
    if not member_list or #member_list == 0 then
        mq.cmd(string.format('/echo [ARMOR_RECIPIENT] ERROR: Empty member_list for %s / %s', 
            set_name, piece_type))
        return nil, 999
    end
    
    if not armor_sets[set_name] or not armor_sets[set_name].pieces[piece_type] then
        mq.cmd(string.format('/echo [ARMOR_RECIPIENT] ERROR: Invalid armor set/piece - %s / %s', 
            set_name, piece_type))
        return nil, 999
    end
    
    local best_char = nil
    local lowest_score = 999
    
    if item_tier then
        mq.cmd(string.format('/echo [ARMOR_RECIPIENT] Evaluating %d members for %s / %s (tier %d, filtering by progression)...', 
            #member_list, set_name, piece_type, item_tier))
    else
        mq.cmd(string.format('/echo [ARMOR_RECIPIENT] Evaluating %d members for %s / %s (tier unknown, no filtering)...', 
            #member_list, set_name, piece_type))
    end
    
    for _, member in ipairs(member_list) do
        -- Extract character name from member object or use string directly
        local char_name = type(member) == 'string' and member or (member.Name and member.Name())
        
        if char_name then
            local skip_candidate = false
            
            -- Check if character already has a higher-tier final product equipped
            -- For example, don't give Fear Stained if they already have Distorted/Twilight/etc equipped
            local has_higher, higher_info = has_higher_tier_product_equipped(char_name, set_name, piece_type)
            if has_higher and higher_info then
                mq.cmd(string.format('/echo [ARMOR_RECIPIENT] SKIP: %s has higher-tier product equipped (tier %d vs item tier %s)', 
                    char_name, higher_info.tier, tostring(item_tier or 'unknown')))
                skip_candidate = true
            end
            
            -- Also check progression tier if item_tier is provided
            if not skip_candidate and item_tier then
                debug_logger.info("TIER_FILTER: Checking %s for tier filtering (item_tier=%s)", char_name, tostring(item_tier))
                local equipped_tier = get_equipped_armor_tier(char_name, set_name, piece_type)
                debug_logger.info("TIER_FILTER: %s equipped_tier=%s, item_tier=%s", char_name, tostring(equipped_tier), tostring(item_tier))
                if equipped_tier and equipped_tier >= item_tier then
                    mq.cmd(string.format('/echo [ARMOR_RECIPIENT] SKIP: %s already has tier %d equipment (item is tier %d)', 
                        char_name, equipped_tier, item_tier))
                    debug_logger.info("TIER_FILTER: SKIPPING %s (tier %d >= %d)", char_name, equipped_tier, item_tier)
                    skip_candidate = true
                else
                    debug_logger.info("TIER_FILTER: NOT skipping %s (equipped_tier=%s does not meet skip criteria)", char_name, tostring(equipped_tier))
                end
            else
                debug_logger.info("TIER_FILTER: Skipping tier check for %s (skip_candidate=%s, item_tier=%s)", char_name, tostring(skip_candidate), tostring(item_tier))
            end
            
            if not skip_candidate then
                local score = calculate_satisfaction(char_name, set_name, piece_type)
                
                -- Select member with LOWEST score (greatest need)
                if score < lowest_score then
                    mq.cmd(string.format('/echo [ARMOR_RECIPIENT] NEW BEST: %s with score %d (previous best was %s with %d)', 
                        char_name, score, best_char or 'NONE', lowest_score))
                    lowest_score = score
                    best_char = char_name
                end
            end
        end
    end
    
    if best_char then
        mq.cmd(string.format('/echo [ARMOR_RECIPIENT] FINAL WINNER: %s with satisfaction score %d', 
            best_char, lowest_score))
    else
        mq.cmd(string.format('/echo [ARMOR_RECIPIENT] ERROR: No valid recipient found for %s / %s', 
            set_name, piece_type))
    end
    
    return best_char, lowest_score
end

--[[
    Get detailed breakdown of a character's status for an armor piece
    
    Args:
        character_name (string): Name of character to analyze
        set_name (string): Armor set name
        piece_type (string): Piece type within set
    
    Returns:
        (table) Breakdown with: character, set_name, piece_type, equipped, max_slots, 
                remnants, remnant_name, satisfaction
]]
local function get_need_breakdown(character_name, set_name, piece_type)
    local set_config = armor_sets[set_name]
    if not set_config or not set_config.pieces or not set_config.pieces[piece_type] then
        return {
            character = character_name,
            set_name = set_name,
            piece_type = piece_type,
            equipped = 0,
            max_slots = 0,
            remnants = 0,
            satisfaction = 0,
        }
    end
    
    local piece_config = set_config.pieces[piece_type]
    local equipped_count = count_equipped_pieces(character_name, set_name, piece_type)
    local remnant_count = query_inventory_count(character_name, piece_config.remnant_id)
    local satisfaction = equipped_count + remnant_count
    
    return {
        character = character_name,
        set_name = set_name,
        display_name = set_config.display_name,
        piece_type = piece_type,
        equipped = equipped_count,
        max_slots = piece_config.max_slots,
        remnants = remnant_count,
        remnant_name = piece_config.remnant_name,
        satisfaction = satisfaction,
    }
end

-- ============================================================================
-- Public API
-- ============================================================================

return {
    -- Item identification
    identify_armor_item = identify_armor_item,
    get_armor_item_tier = get_armor_item_tier,
    is_armor_set_piece = is_armor_set_piece,
    
    -- Core calculation
    calculate_satisfaction = calculate_satisfaction,
    get_equipped_armor_tier = get_equipped_armor_tier,
    
    -- Distribution
    find_best_recipient = find_best_recipient,
    get_need_breakdown = get_need_breakdown,
    
    -- Configuration access
    armor_sets = armor_sets,
    ARMOR_PROGRESSION = ARMOR_PROGRESSION,
    SLOT_NAMES = SLOT_NAMES,
    
    -- Internal utilities (exposed for testing/debugging)
    count_equipped_pieces = count_equipped_pieces,
    query_equipped_item = query_equipped_item,
    query_inventory_count = query_inventory_count,
    contains_string = contains_string,
}
