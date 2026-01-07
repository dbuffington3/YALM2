--[[
    Cross-Character Upgrade Checker
    Scans current character's tradeable inventory to find upgrades for other characters on DAN net
    Usage: /lua run check_cross_character_upgrades.lua
    
    *** CRITICAL RULE FOR INVENTORY OPERATIONS ***
    IMPORTANT: When dealing with inventory-related operations in ANY script, you MUST:
    1. Always scan BOTH direct inventory slots (23-500+) AND items INSIDE containers
    2. Use item.Container() to detect if a slot contains a container object
    3. If container, use item.Item(j) to iterate through 1-100 slots inside the container
    4. Store BOTH slot_index (the container itself) and container_slot (the item inside)
    5. When picking up items from containers, use: /shift /itemnotify in pack[idx] [slot] leftmouseup
    
    Items are ALMOST ALWAYS stored inside containers - never assume direct inventory scanning is sufficient!
]]

local mq = require('mq')
local inspect = require('yalm2.lib.inspect')
local ImGui = require('ImGui')

-- Import the database module and ensure it's initialized
require('yalm2.lib.database')
local db = YALM2_Database
if not db.database then
    db.database = db.OpenDatabase()
    if not db.database then
        error("Failed to open database. Ensure MQ2LinkDB.db is in <MQ2_ROOT>/resources/ directory")
    end
end

-- Global results storage for ImGui display
local cross_char_results = {
    upgrades_by_character = {},  -- {char_name -> {upgrades = {...}, class, level}}
    source_character = nil,
    scan_complete = false,
    scan_start_time = 0
}

local show_cross_upgrade_window = false
local auto_distribute = false  -- Set to true to automatically distribute after scan

-- Trading state machine
local pending_trade = nil  -- {char_name, upgrade, step} - step: "pickup", "target", "usetarget", "trade_button"
local trade_step_timer = 0

-- ============================================================================
-- Class Classification Functions
-- ============================================================================

local function is_tank_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'warrior' or c == 'war' or
           c == 'paladin' or c == 'pal' or 
           c == 'shadowknight' or c == 'shadow knight' or c == 'shd'
end

local function is_caster_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'cleric' or c == 'clr' or
           c == 'druid' or c == 'dru' or
           c == 'wizard' or c == 'wiz' or
           c == 'enchanter' or c == 'enc' or
           c == 'necromancer' or c == 'nec' or
           c == 'magician' or c == 'mag' or
           c == 'shaman' or c == 'shm'
end

local function is_hybrid_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'bard' or c == 'brd' or
           c == 'beastlord' or c == 'bst' or
           c == 'ranger' or c == 'rng' or
           c == 'rogue' or c == 'rog' or
           c == 'monk' or c == 'mnk' or
           c == 'berserker' or c == 'ber'
end

local function is_healer_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'cleric' or c == 'clr' or
           c == 'druid' or c == 'dru' or
           c == 'shaman' or c == 'shm'
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

local function is_pure_caster_class(character_class)
    if not character_class then return false end
    local c = character_class:lower()
    return c == 'magician' or c == 'mag' or
           c == 'wizard' or c == 'wiz' or
           c == 'enchanter' or c == 'enc' or
           c == 'necromancer' or c == 'nec'
end

-- ============================================================================
-- Role-Based Character Priority System
-- ============================================================================

local function get_character_role_priority(character_class)
    --[[
    Returns (priority_order, role_name) where lower priority_order = processed first
    
    Priority hierarchy:
    1. TANKS (priority 1) - WAR, PAL, SHD process first for everything
    2. MELEE DPS (priority 2) - ROG, BER, MNK, RNG, BRD get weapons before casters
    3. MELEE HYBRID (priority 3) - BST, DRU get weapons + armor but after melee DPS
    4. HEALERS (priority 4) - CLR, SHM get armor when tanks don't need it
    5. CASTERS (priority 5) - MAG, WIZ, ENC, NEC get leftovers
    ]]
    
    if is_tank_class(character_class) then
        return 1, "TANK"
    elseif is_melee_dps_class(character_class) then
        return 2, "MELEE_DPS"
    elseif is_melee_hybrid_class(character_class) then
        return 3, "MELEE_HYBRID"
    elseif is_healer_class(character_class) then
        return 4, "HEALER"
    else
        return 5, "CASTER"
    end
end

local function sort_characters_by_priority(characters)
    --[[
    Sort characters by role priority (tanks first, then melee DPS, etc.)
    Within same priority, sort alphabetically by name for consistency
    ]]
    local char_with_priority = {}
    
    for _, char in ipairs(characters) do
        local priority, role = get_character_role_priority(char.class)
        table.insert(char_with_priority, {
            priority = priority,
            role = role,
            name = char.name,
            class = char.class,
            level = char.level
        })
    end
    
    -- Sort by priority first, then by name
    table.sort(char_with_priority, function(a, b)
        if a.priority ~= b.priority then
            return a.priority < b.priority  -- Lower priority number goes first
        end
        return a.name:lower() < b.name:lower()  -- Alphabetical as tiebreaker
    end)
    
    return char_with_priority
end

-- ============================================================================
-- Stat Weights by Class (duplicated from check_upgrades.lua)
-- ============================================================================

local CLASS_WEIGHTS = {
    ['Shadowknight'] = { ac = 3, hp = 2, mana = 0.5, endurance = 1.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Shadow Knight'] = { ac = 3, hp = 2, mana = 0.5, endurance = 1.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Warrior'] = { ac = 3, hp = 2, mana = 0, endurance = 1.5, resists = 1, attack = 1, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Paladin'] = { ac = 3, hp = 2, mana = 1, endurance = 1.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 0.5, heal = 1, clairvoyance = 0 },
    
    ['Ranger'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Rogue'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Monk'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Berserker'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    
    ['Bard'] = { ac = 1, hp = 1.5, mana = 1.5, endurance = 1.5, resists = 0.5, attack = 1, regen = 0.5, manaregen = 0.5, heal = 0.5, clairvoyance = 1 },
    
    ['Cleric'] = { ac = 1, hp = 2, mana = 2, endurance = 0, resists = 1, attack = 0, regen = 1, manaregen = 1, heal = 2, clairvoyance = 0.5 },
    ['Druid'] = { ac = 0.5, hp = 1.5, mana = 2, endurance = 0, resists = 1, attack = 0, regen = 1, manaregen = 1, heal = 1.5, clairvoyance = 0.5 },
    
    ['Wizard'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0, clairvoyance = 1 },
    ['Enchanter'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0, clairvoyance = 1.5 },
    ['Necromancer'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0.5, clairvoyance = 1 },
    ['Magician'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0, clairvoyance = 0.5 },
    ['Shaman'] = { ac = 1, hp = 1.5, mana = 2.5, endurance = 0.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 1.5, heal = 1.5, clairvoyance = 0.5 },
    ['Beastlord'] = { ac = 1, hp = 1.5, mana = 1.5, endurance = 1.5, resists = 0.5, attack = 1.5, regen = 0.5, manaregen = 0.5, heal = 0.5, clairvoyance = 0 },
}

local DEFAULT_WEIGHTS = { ac = 0.5, hp = 1.5, mana = 2, endurance = 0, resists = 1, attack = 0, regen = 0.5, manaregen = 1, heal = 1, clairvoyance = 0.5 }

-- ============================================================================
-- Slot Names and Mapping
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

local function get_slot_display_name(slot_num)
    if SLOT_NAMES[slot_num] then
        return string.format('Slot %d: %s', slot_num, SLOT_NAMES[slot_num])
    end
    return string.format('Slot %d', slot_num)
end

-- ============================================================================
-- Database and Item Functions
-- ============================================================================

local function get_item_stats(item_id)
    --[[
    Get item stats from database: AC, HP, Mana, Endurance, Resists, etc.
    Returns table with all relevant stats or nil if not found
    ]]
    if not item_id or item_id == 0 then
        return nil
    end
    
    local item_data = db.QueryDatabaseForItemId(item_id)
    
    if not item_data or not item_data.id then
        return nil
    end
    
    -- Convert database field names to stat names (database uses abbreviations)
    local row = item_data
    return {
        ac = tonumber(row.ac) or 0,
        hp = tonumber(row.hp) or 0,
        mana = tonumber(row.mana) or 0,
        endurance = tonumber(row.endur) or 0,  -- Database field is "endur"
        resists_magic = tonumber(row.mr) or 0,  -- Database field is "mr"
        resists_fire = tonumber(row.fr) or 0,   -- Database field is "fr"
        resists_cold = tonumber(row.cr) or 0,   -- Database field is "cr"
        resists_poison = tonumber(row.pr) or 0, -- Database field is "pr"
        resists_disease = tonumber(row.dr) or 0, -- Database field is "dr"
        attack = tonumber(row.attack) or 0,
        hp_regen = tonumber(row.regen) or 0,    -- Database field is "regen"
        mana_regen = tonumber(row.manaregen) or 0, -- Database field is "manaregen"
        heal_amount = tonumber(row.healamt) or 0, -- Database field is "healamt"
        clairvoyance = tonumber(row.clairvoyance) or 0,
        itemtype = tonumber(row.itemtype) or 0,
        slots = tonumber(row.slots) or 0,
        classes = tonumber(row.classes) or 0,
        required_level = tonumber(row.reqlevel) or 0, -- Database field is "reqlevel"
        nodrop = tonumber(row.nodrop) or 0,
        questitem = tonumber(row.questitem) or 0,
        tradeskills = tonumber(row.tradeskills) or 0,
    }
end

local function can_equip_item_for_class(item_id, character_level, character_class)
    --[[
    Check if a character can equip an item based on level, class, and trade restrictions
    
    Class Bitmask Mapping (0-indexed bit positions):
    Bit 0  = 2^0  = 1      = Warrior
    Bit 1  = 2^1  = 2      = Cleric
    Bit 2  = 2^2  = 4      = Paladin
    Bit 3  = 2^3  = 8      = Ranger
    Bit 4  = 2^4  = 16     = Shadowknight
    Bit 5  = 2^5  = 32     = Druid
    Bit 6  = 2^6  = 64     = Monk
    Bit 7  = 2^7  = 128    = Bard
    Bit 8  = 2^8  = 256    = Rogue
    Bit 9  = 2^9  = 512    = Shaman
    Bit 10 = 2^10 = 1024   = Necromancer
    Bit 11 = 2^11 = 2048   = Wizard
    Bit 12 = 2^12 = 4096   = Magician
    Bit 13 = 2^13 = 8192   = Enchanter
    Bit 14 = 2^14 = 16384  = Beastlord
    Bit 15 = 2^15 = 32768  = Berserker
    ]]
    if not item_id or item_id == 0 then
        return false, "Invalid item ID"
    end
    
    local item_data = get_item_stats(item_id)
    if not item_data then
        return false, "Item not found in database"
    end
    
    -- Items with no slots cannot be equipped
    if not item_data.slots or item_data.slots == 0 then
        return false, "Item has no equipment slots"
    end
    
    -- Check level requirement
    if item_data.level and item_data.level > 0 and character_level < item_data.level then
        return false, string.format("Level %d required (char is %d)", item_data.level, character_level)
    end
    
    -- Check class requirement (bitmask)
    if item_data.classes and item_data.classes > 0 then
        -- Class bit positions (0-indexed): WAR=0, CLR=1, PAL=2, RNG=3, SHD=4, DRU=5, MNK=6, BRD=7, ROG=8, SHM=9, NEC=10, WIZ=11, MAG=12, ENC=13, BST=14, BER=15
        local class_bit_positions = {
            ['Warrior'] = 0, ['WAR'] = 0,
            ['Cleric'] = 1, ['CLR'] = 1,
            ['Paladin'] = 2, ['PAL'] = 2,
            ['Ranger'] = 3, ['RNG'] = 3,
            ['Shadowknight'] = 4, ['Shadow Knight'] = 4, ['SHD'] = 4,
            ['Druid'] = 5, ['DRU'] = 5,
            ['Monk'] = 6, ['MNK'] = 6,
            ['Bard'] = 7, ['BRD'] = 7,
            ['Rogue'] = 8, ['ROG'] = 8,
            ['Shaman'] = 9, ['SHM'] = 9,
            ['Necromancer'] = 10, ['NEC'] = 10,
            ['Wizard'] = 11, ['WIZ'] = 11,
            ['Magician'] = 12, ['MAG'] = 12,
            ['Enchanter'] = 13, ['ENC'] = 13,
            ['Beastlord'] = 14, ['BST'] = 14,
            ['Berserker'] = 15, ['BER'] = 15,
        }
        
        local char_class_lower = character_class:lower()
        local class_bit = nil
        for class_name, bit_pos in pairs(class_bit_positions) do
            if class_name:lower() == char_class_lower then
                class_bit = bit_pos
                break
            end
        end
        
        if class_bit ~= nil then
            -- Check if this bit is set in the classes bitmask
            local can_equip = bit.band(item_data.classes, bit.lshift(1, class_bit))
            if can_equip == 0 then
                return false, string.format("Class %s cannot equip (classes bitmask=%d)", character_class, item_data.classes)
            end
        end
    end
    
    -- Check trade restrictions
    if item_data.nodrop == 1 then
        return false, "Item is NO TRADE (cannot trade)"
    end
    
    -- Check quest item restriction
    if item_data.questitem == 1 then
        return false, "Item is a quest item (cannot trade)"
    end
    
    return true, "Can equip"
end

local function can_remote_character_equip(item_id, character_level, character_class)
    --[[
    Check if a REMOTE character can equip an item based only on level and class.
    Does NOT check trade restrictions since the source character already owns the item.
    
    Class Bitmask Mapping (0-indexed bit positions):
    Bit 0  = 2^0  = 1      = Warrior
    Bit 1  = 2^1  = 2      = Cleric
    Bit 2  = 2^2  = 4      = Paladin
    Bit 3  = 2^3  = 8      = Ranger
    Bit 4  = 2^4  = 16     = Shadowknight
    Bit 5  = 2^5  = 32     = Druid
    Bit 6  = 2^6  = 64     = Monk
    Bit 7  = 2^7  = 128    = Bard
    Bit 8  = 2^8  = 256    = Shaman
    Bit 9  = 2^9  = 512    = Necromancer
    Bit 10 = 2^10 = 1024   = Wizard
    Bit 11 = 2^11 = 2048   = Magician
    Bit 12 = 2^12 = 4096   = Enchanter
    Bit 13 = 2^13 = 8192   = (unused)
    Bit 14 = 2^14 = 16384  = Beastlord
    Bit 15 = 2^15 = 32768  = Berserker
    ]]
    if not item_id or item_id == 0 then
        return false, "Invalid item ID"
    end
    
    local item_data = get_item_stats(item_id)
    if not item_data then
        return false, "Item not found in database"
    end
    
    -- Items with no slots cannot be equipped
    if not item_data.slots or item_data.slots == 0 then
        return false, "Item has no equipment slots"
    end
    
    -- Check level requirement
    if item_data.level and item_data.level > 0 and character_level < item_data.level then
        return false, string.format("Level %d required (char is %d)", item_data.level, character_level)
    end
    
    -- Check class requirement (bitmask)
    if item_data.classes and item_data.classes > 0 then
        -- Class bit positions (0-indexed): WAR=0, CLR=1, PAL=2, RNG=3, SHD=4, DRU=5, MNK=6, BRD=7, ROG=8, SHM=9, NEC=10, WIZ=11, MAG=12, ENC=13, BST=14, BER=15
        local class_bit_positions = {
            ['Warrior'] = 0, ['WAR'] = 0,
            ['Cleric'] = 1, ['CLR'] = 1,
            ['Paladin'] = 2, ['PAL'] = 2,
            ['Ranger'] = 3, ['RNG'] = 3,
            ['Shadowknight'] = 4, ['Shadow Knight'] = 4, ['SHD'] = 4,
            ['Druid'] = 5, ['DRU'] = 5,
            ['Monk'] = 6, ['MNK'] = 6,
            ['Bard'] = 7, ['BRD'] = 7,
            ['Rogue'] = 8, ['ROG'] = 8,
            ['Shaman'] = 9, ['SHM'] = 9,
            ['Necromancer'] = 10, ['NEC'] = 10,
            ['Wizard'] = 11, ['WIZ'] = 11,
            ['Magician'] = 12, ['MAG'] = 12,
            ['Enchanter'] = 13, ['ENC'] = 13,
            ['Beastlord'] = 14, ['BST'] = 14,
            ['Berserker'] = 15, ['BER'] = 15,
        }
        
        local char_class_lower = character_class:lower()
        local class_bit = nil
        for class_name, bit_pos in pairs(class_bit_positions) do
            if class_name:lower() == char_class_lower then
                class_bit = bit_pos
                break
            end
        end
        
        if class_bit ~= nil then
            -- Check if this bit is set in the classes bitmask
            local can_equip = bit.band(item_data.classes, bit.lshift(1, class_bit))
            if can_equip == 0 then
                return false, string.format("Class %s cannot equip (classes bitmask=%d)", character_class, item_data.classes)
            end
        end
    end
    
    -- Note: We do NOT check trade restrictions here since the source character already owns the item
    
    return true, "Can equip"
end

-- ============================================================================
-- Stat Scoring and Comparison
-- ============================================================================

local function get_stat_delta(old_stats, new_stats, weights)
    --[[
    Calculate the delta for each stat between old and new items
    ]]
    local deltas = {}
    
    for field, weight in pairs(weights) do
        local old_val = (old_stats[field] or 0)
        local new_val = (new_stats[field] or 0)
        local delta = new_val - old_val
        
        if delta ~= 0 then
            deltas[field] = delta
        end
    end
    
    return deltas
end

local function calculate_stat_score(item_stats, weights, slot_num, character_class)
    --[[
    Calculate an overall score for an item based on character class weights
    ]]
    local score = 0
    
    for field, weight in pairs(weights) do
        local value = item_stats[field] or 0
        score = score + (value * weight)
    end
    
    return score
end

local function are_items_comparable(item1_stats, item2_stats)
    --[[
    Check if two items can be compared (have overlapping slot types)
    ]]
    if not item1_stats or not item2_stats then
        return false
    end
    
    local slots1 = item1_stats.slots or 0
    local slots2 = item2_stats.slots or 0
    
    -- Check if they have overlapping slot types
    return bit.band(slots1, slots2) > 0
end

-- ============================================================================
-- DAN Net Query Functions
-- ============================================================================

local function get_dannet_characters()
    --[[
    Query DAN net for all available characters
    Returns table of {name, class, level} for each character
    Strategy: Get group members first, then iterate DAN net clients to find others
    ]]
    local characters = {}
    local found_names = {}  -- Track which names we've already added
    
    -- Strategy 1: Get group members (most reliable)
    local ok_group, group = pcall(function() return mq.TLO.Group end)
    if ok_group and group then
        local ok_members, members = pcall(function() return group.Members() end)
        if ok_members and members then
            local member_count = tonumber(members) or 0
            
            for i = 1, member_count do
                local ok_member, member = pcall(function() return group.Member(i) end)
                if ok_member and member then
                    local ok_name, name = pcall(function() return member.Name() end)
                    if ok_name and name and name ~= "" then
                        local ok_class, class = pcall(function() return member.Class.ShortName() end)
                        local ok_level, level = pcall(function() return member.Level() end)
                        
                        table.insert(characters, {
                            name = name,
                            class = (ok_class and class) or "Unknown",
                            level = (ok_level and (tonumber(level) or 1)) or 1
                        })
                        found_names[name:lower()] = true
                    end
                end
            end
        end
    end
    
    -- Strategy 2: Query DAN net peers using DanNet.PeerCount and DanNet.Peers
    local ok_dannet, dannet = pcall(function() return mq.TLO.DanNet end)
    if ok_dannet and dannet then
        -- Get the peer count
        local ok_peercount, peercount = pcall(function() return dannet.PeerCount() end)
        if ok_peercount and peercount then
            peercount = tonumber(peercount) or 0
            
            -- Try to get the peer list
            local ok_peers, peers = pcall(function() return dannet.Peers() end)
            if ok_peers and peers then
                peers = tostring(peers)
                
                -- Parse the peer list (format is pipe-delimited)
                -- Split by pipe delimiter
                for peer_name in string.gmatch(peers, '[^|]+') do
                    peer_name = peer_name:match('^%s*(.-)%s*$')  -- Trim whitespace
                    
                    if peer_name and peer_name ~= "" then
                        -- Extract just the character name (remove server prefix if present)
                        local char_name = peer_name
                        if string.find(peer_name, '_') then
                            -- Fully-qualified name like "servername_charactername"
                            char_name = peer_name:match('_(.*)$') or peer_name
                        end
                        
                        if not found_names[char_name:lower()] then
                            -- Use /dquery to get remote character info
                            -- First, check group member (fast)
                            local is_in_group = false
                            local ok_group, group = pcall(function() return mq.TLO.Group end)
                            if ok_group and group then
                                local ok_members, members = pcall(function() return group.Members() end)
                                if ok_members and members then
                                    local member_count = tonumber(members) or 0
                                    for i = 1, member_count do
                                        local ok_member, member = pcall(function() return group.Member(i) end)
                                        if ok_member and member then
                                            local ok_name, name = pcall(function() return member.Name() end)
                                            if ok_name and name and name:lower() == char_name:lower() then
                                                is_in_group = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                            
                            if not is_in_group then
                                -- Query via /dquery command
                                -- /dquery sends a query to peer and stores result in ${DanNet.Query}
                                local class = "Unknown"
                                local level = 1
                                
                                -- Query class using /dquery
                                mq.cmdf('/dquery %s -q Me.Class.ShortName -o DanQuery_Class', peer_name)
                                mq.delay(250)  -- Give it time to respond
                                
                                -- Try to read the DanNet.Query result
                                local ok_query, query_result = pcall(function()
                                    return dannet.Query()
                                end)
                                
                                if ok_query and query_result then
                                    class = tostring(query_result)
                                end
                                
                                -- Query level using /dquery
                                mq.cmdf('/dquery %s -q Me.Level -o DanQuery_Level', peer_name)
                                mq.delay(250)
                                
                                ok_query, query_result = pcall(function()
                                    return dannet.Query()
                                end)
                                
                                if ok_query and query_result then
                                    level = tonumber(query_result) or 1
                                end
                                
                                table.insert(characters, {
                                    name = char_name,
                                    class = class,
                                    level = level
                                })
                                found_names[char_name:lower()] = true
                            end
                        end
                    end
                end
            else
                -- Fallback: Try iterating by index if we know the count
                if peercount and peercount > 0 then
                    for i = 1, math.min(peercount, 50) do
                        local ok_client, client = pcall(function() return dannet.Client(i) end)
                        if ok_client and client then
                            local ok_name, name = pcall(function() return client.Name() end)
                            if ok_name and name and name ~= "" and not found_names[name:lower()] then
                                local ok_class, class = pcall(function() return client.Class() end)
                                local ok_level, level = pcall(function() return client.Level() end)
                                
                                table.insert(characters, {
                                    name = name,
                                    class = (ok_class and class) or "Unknown",
                                    level = (ok_level and (tonumber(level) or 1)) or 1
                                })
                                found_names[name:lower()] = true
                            end
                        end
                    end
                end
            end
        end
    end
    
    mq.cmdf('/echo Found %d characters to check', #characters)
    return characters
end

local function get_dannet_equipped_items(character_name)
    --[[
    Query a specific character's equipped items via DAN net
    Returns table of {slot, item_id, item_name} for each equipped item
    ]]
    local items = {}
    
    local ok, dannet = pcall(function() return mq.TLO.DanNet end)
    if not ok or not dannet then
        return items
    end
    
    -- Equipped slots are 0-22
    for slot = 0, 22 do
        local ok_item, item = pcall(function() return dannet.Client(character_name).Inventory(slot) end)
        if ok_item and item then
            local ok_id, item_id = pcall(function() return item.ID() end)
            if ok_id and item_id and tonumber(item_id) and tonumber(item_id) > 0 then
                local ok_name, item_name = pcall(function() return item.Name() end)
                if ok_name and item_name then
                    table.insert(items, {
                        slot = slot,
                        item_id = tonumber(item_id),
                        item_name = item_name
                    })
                end
            end
        end
    end
    
    return items
end

-- ============================================================================
-- Inventory Functions
-- ============================================================================

local function get_tradeable_inventory_items()
    --[[
    Get all tradeable items from current character's inventory (slots 23+)
    Scans both direct inventory slots AND items inside containers
    Returns table of {item_id, item_name, slot_index, container_slot}
    
    CRITICAL: Uses TLO item properties for trade status instead of database,
    because items can become attuned after pickup and the database may have
    stale/incorrect nodrop data.
    
    CRITICAL RULE FOR FUTURE DEVELOPMENT:
    When dealing with inventory scanning, ALWAYS check:
    1. Direct inventory slots (23-500+)
    2. Items INSIDE containers for each direct slot
    Use item.Container() to detect if slot is a container
    Use item.Item(j) to scan inside containers (j = 1 to 100)
    Store both slot_index (container) and container_slot (item inside)
    ]]
    local items = {}
    
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    if not ok_me or not me then
        return items
    end
    
    -- Inventory slots start at 23
    local max_slots = 500
    
    for i = 23, max_slots do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if not ok_item or not item then
            goto next_inv_slot
        end
        
        local ok_id, item_id = pcall(function() return item.ID() end)
        if not ok_id or not item_id or tonumber(item_id) == 0 then
            goto next_inv_slot
        end
        
        item_id = tonumber(item_id)
        
        local ok_name, item_name = pcall(function() return item.Name() end)
        item_name = ok_name and item_name or 'Unknown'
        
        -- Get database stats for equipment slot info
        local item_stats = get_item_stats(item_id)
        if not item_stats then
            goto next_inv_slot
        end
        
        -- Skip augmentations (itemtype 54) - they're not useful for gear distribution
        if item_stats.itemtype == 54 then
            goto next_inv_slot
        end
        
        -- Check trade status using TLO instead of database (database may have stale data)
        -- An item is NO TRADE if NoTrade property is non-zero (items get attuned after pickup)
        local ok_notrade, is_notrade = pcall(function() return item.NoTrade() end)
        local item_is_notrade = ok_notrade and is_notrade and (tonumber(is_notrade) ~= 0 or is_notrade == true)
        
        -- If this item is tradeable AND has equipment slots, add it to the list
        if not item_is_notrade and item_stats.slots and item_stats.slots > 0 then
            mq.cmdf('/echo   Found tradeable item: %s (ID: %d)', item_name, item_id)
            table.insert(items, {
                item_id = item_id,
                item_name = item_name,
                slot_index = i,
                container_slot = nil,  -- Direct inventory item, not in a container
            })
        end
        
        -- IMPORTANT: Check if this item is a container REGARDLESS of whether it's equipment or NO TRADE
        -- We want to scan inside ALL containers because items INSIDE might be tradeable
        local ok_container, is_container = pcall(function() return item.Container() end)
        if ok_container and is_container then
            -- This item is a container, scan its contents
            local max_container_slots = 100  -- Containers have max 100 slots
            
            for j = 1, max_container_slots do
                local ok_sub, sub_item = pcall(function() return item.Item(j) end)
                if not ok_sub or not sub_item then
                    goto skip_container_item  -- Skip empty slots instead of breaking
                end
                
                local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
                if not ok_sub_id or not sub_id or tonumber(sub_id) == 0 then
                    goto skip_container_item  -- Skip invalid items
                end
                
                sub_id = tonumber(sub_id)
                
                -- Get database stats for equipment slot info
                local sub_item_stats = get_item_stats(sub_id)
                if not sub_item_stats then
                    goto skip_container_item
                end
                
                -- Skip augmentations (itemtype 54) - they're not useful for gear distribution
                if sub_item_stats.itemtype == 54 then
                    goto skip_container_item
                end
                
                local ok_sub_name, sub_name = pcall(function() return sub_item.Name() end)
                sub_name = ok_sub_name and sub_name or 'Unknown'
                
                -- Check trade status using TLO instead of database
                local ok_sub_notrade, sub_is_notrade = pcall(function() return sub_item.NoTrade() end)
                if ok_sub_notrade and sub_is_notrade and tonumber(sub_is_notrade) ~= 0 then
                    goto skip_container_item
                end
                
                -- Skip items with no equipment slots inside containers
                if not sub_item_stats.slots or sub_item_stats.slots == 0 then
                    goto skip_container_item
                end
                
                -- Found a tradeable equipment item inside a container!
                mq.cmdf('/echo   Found tradeable item: %s (ID: %d) in container', sub_name, sub_id)
                table.insert(items, {
                    item_id = sub_id,
                    item_name = sub_name,
                    slot_index = i,
                    container_slot = j,  -- Item is inside a container
                })
                
                ::skip_container_item::
            end
        end
        
        ::next_inv_slot::
    end
    
    return items
end

-- ============================================================================
-- Slot Name Mapping (from Gearly)
-- ============================================================================

local SLOT_NAMES_BY_NUMBER = {
    [0] = 'charm',
    [1] = 'leftear',
    [2] = 'head',
    [3] = 'face',
    [4] = 'rightear',
    [5] = 'neck',
    [6] = 'shoulder',
    [7] = 'arms',
    [8] = 'back',
    [9] = 'leftwrist',
    [10] = 'rightwrist',
    [11] = 'ranged',
    [12] = 'hands',
    [13] = 'mainhand',
    [14] = 'offhand',
    [15] = 'leftfinger',
    [16] = 'rightfinger',
    [17] = 'chest',
    [18] = 'legs',
    [19] = 'feet',
    [20] = 'waist',
    [21] = 'powersource',
    [22] = 'ammo',
}

-- ============================================================================
-- Remote Item Comparison via DanNet Named Slot Queries
-- ============================================================================

local function query_remote_item_equipability(peer_name, item_id, item_name, character_class, character_level)
    --[[
    Reads what a remote character has equipped using DanNet named slot queries.
    Much faster and simpler than database/INI files.
    Uses syntax: /dquery <peer> -q Me.Inventory[slotname].ID

    Returns: {can_equip, slot_id, candidate_item, equipped_item}
    or nil if query fails
    ]]
    -- First try to get slot from item stats (which comes from database)
    local item_stats = get_item_stats(item_id)
    if not item_stats then
        mq.cmdf('/echo [DEBUG] Item %d (%s): No database entry', item_id, item_name)
        return nil
    end
    
    -- Try to determine slot from local FindItem first (more reliable if item is available)
    local slot = nil
    local ok_item, item = pcall(function() return mq.TLO.FindItem(item_id) end)
    if ok_item and item then
        local ok_slot, slot_result = pcall(function() return item.WornSlot() end)
        if ok_slot and slot_result then
            slot = tonumber(slot_result) or -1
        end
    end
    
    -- If we couldn't get it from FindItem, derive slot from bitmask by finding first bit set
    if not slot or slot < 0 then
        if item_stats.slots and item_stats.slots > 0 then
            -- Find the first bit position that's set in the bitmask
            -- The bit position IS the slot number (0-31)
            local bit_pos = 0
            local remaining = item_stats.slots
            while remaining > 0 and bit_pos < 32 do
                if remaining % 2 == 1 then
                    slot = bit_pos
                    break
                end
                remaining = math.floor(remaining / 2)
                bit_pos = bit_pos + 1
            end
            
            if not slot or slot < 0 then
                return nil
            end
        else
            return nil
        end
    end
    
    -- Get the slot name from our mapping
    local slot_name = SLOT_NAMES_BY_NUMBER[slot]
    if not slot_name then
        return nil
    end
    
    -- Query remote character's equipped item using DanNet named slot
    -- Execute: /dquery <peer> -q Me.Inventory[slotname].ID
    local query_id = string.format('Me.Inventory[%s].ID', slot_name)
    local query_name = string.format('Me.Inventory[%s].Name', slot_name)
    
    mq.cmdf('/dquery %s -q %s', peer_name, query_id)
    mq.delay(250)  -- Wait for response
    
    -- Try to read the result from DanNet.Query
    local ok_dannet, dannet = pcall(function() return mq.TLO.DanNet end)
    if not ok_dannet or not dannet then
        return nil
    end
    
    local ok_query, query_result = pcall(function() return dannet.Query() end)
    if not ok_query or not query_result then
        return nil
    end
    
    local equipped_id = tonumber(query_result) or 0
    
    -- Check if the REMOTE character can equip this item (class and level only, not trade restrictions)
    local can_equip_item, equip_reason = can_remote_character_equip(item_id, character_level, character_class)
    if not can_equip_item then
        return nil
    end
    
    if equipped_id and equipped_id > 0 then
        -- Now query the item name
        mq.cmdf('/dquery %s -q %s', peer_name, query_name)
        mq.delay(250)
        
        local ok_name_query, name_result = pcall(function() return dannet.Query() end)
        local equipped_name = (ok_name_query and name_result) or "Unknown"
        
        return {
            can_equip = true,
            slot_id = slot,
            candidate_item = { id = item_id, name = item_name },
            equipped_item = { id = equipped_id, name = equipped_name }
        }
    else
        -- No item currently equipped in this slot
        return {
            can_equip = true,
            slot_id = slot,
            candidate_item = { id = item_id, name = item_name },
            equipped_item = nil  -- Empty slot
        }
    end
end

local function compare_items_for_character(peer_name, character_class, candidate_item, equipped_item)
    --[[
    Compares a candidate item against what's currently equipped for a remote character
    Returns upgrade_score (positive = upgrade, negative = downgrade, 0 = sidestep)
    ]]
    if not character_class or character_class == "Unknown" then
        return nil  -- Can't score without class info
    end
    
    local weights = CLASS_WEIGHTS[character_class] or CLASS_WEIGHTS['Warrior']  -- Fallback
    if not weights then
        return nil
    end
    
    -- If no equipped item, it's definitely an upgrade (non-zero score)
    if not equipped_item or equipped_item.id == 0 then
        return 1  -- Placeholder upgrade
    end
    
    -- Get stats for both items
    local candidate_stats = get_item_stats(candidate_item.id)
    local equipped_stats = get_item_stats(equipped_item.id)
    
    if not candidate_stats or not equipped_stats then
        return nil
    end
    
    -- Calculate weighted scores
    local candidate_score = calculate_stat_score(candidate_stats, character_class)
    local equipped_score = calculate_stat_score(equipped_stats, character_class)
    
    return (candidate_score - equipped_score)
end

-- ============================================================================
-- Cross-Character Upgrade Checking
-- ============================================================================

local function check_cross_character_upgrades()
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    if not ok_me or not me then
        mq.cmdf('/echo Unable to access character data')
        return
    end
    
    local ok_name, char_name = pcall(function() return me.DisplayName() end)
    if not ok_name or not char_name then
        mq.cmdf('/echo Unable to get character name')
        return
    end
    
    mq.cmdf('/echo \at[CROSS-CHARACTER UPGRADES]\ax for %s', char_name)
    mq.cmdf('/echo \ao=================================================\ax')
    
    -- Reset results
    cross_char_results.upgrades_by_character = {}
    cross_char_results.source_character = char_name
    cross_char_results.scan_complete = false
    
    -- Get all tradeable items from current character
    local tradeable_items = get_tradeable_inventory_items()
    mq.cmdf('/echo Found %d tradeable items in inventory', #tradeable_items)
    
    if #tradeable_items == 0 then
        mq.cmdf('/echo No tradeable items found')
        cross_char_results.scan_complete = true
        return
    end
    
    -- Get all other characters on DAN net
    local dannet_characters = get_dannet_characters()
    mq.cmdf('/echo Found %d characters on DAN net', #dannet_characters)
    
    if #dannet_characters == 0 then
        mq.cmdf('/echo No other characters on DAN net')
        cross_char_results.scan_complete = true
        return
    end
    
    -- Sort characters by priority: Tanks first, then Melee DPS, then Healers, then Casters
    dannet_characters = sort_characters_by_priority(dannet_characters)
    
    -- Build character lookup by class for faster filtering
    local chars_by_class = {}
    for _, target_char in ipairs(dannet_characters) do
        if target_char.name:lower() ~= char_name:lower() then  -- Skip self
            local class_lower = target_char.class:lower()
            if not chars_by_class[class_lower] then
                chars_by_class[class_lower] = {}
            end
            table.insert(chars_by_class[class_lower], target_char)
        end
    end
    
    -- Process items first, then check only relevant characters
    local all_upgrades = {}
    
    for _, inv_item in ipairs(tradeable_items) do
        local inv_stats = get_item_stats(inv_item.item_id)
        if not inv_stats then
            goto next_item
        end
        
        -- Get the item's class restrictions from database
        local item_classes = inv_stats.classes or 0
        if item_classes == 0 then
            goto next_item  -- Skip items with no class restrictions
        end
        
        -- Determine which slot this item goes in
        local item_slot = nil
        local item_slot_name = nil
        if inv_stats.slots and inv_stats.slots > 0 then
            local bit_pos = 0
            local remaining = inv_stats.slots
            while remaining > 0 and bit_pos < 32 do
                if remaining % 2 == 1 then
                    item_slot = bit_pos
                    item_slot_name = SLOT_NAMES_BY_NUMBER[bit_pos]
                    break
                end
                remaining = math.floor(remaining / 2)
                bit_pos = bit_pos + 1
            end
        end
        
        if not item_slot or not item_slot_name then
            goto next_item  -- Can't determine slot, skip
        end
        
        -- For each character that can equip this class of item
        for _, target_char in ipairs(dannet_characters) do
            -- Skip self
            if target_char.name:lower() == char_name:lower() then
                goto next_char_for_item
            end
            
            -- Check if this character's class can equip this item (using bitmask)
            if not can_remote_character_equip(inv_item.item_id, target_char.level, target_char.class) then
                goto next_char_for_item
            end
            
            -- This character can equip it! Query what they have equipped in this slot
            local ok_dannet, dannet = pcall(function() return mq.TLO.DanNet end)
            if not ok_dannet or not dannet then
                goto next_char_for_item
            end
            
            -- Query equipped item ID in this slot
            local query_id = string.format('Me.Inventory[%s].ID', item_slot_name)
            mq.cmdf('/dquery %s -q %s', target_char.name, query_id)
            mq.delay(250)
            
            local ok_query, query_result = pcall(function() return dannet.Query() end)
            if not ok_query or not query_result then
                goto next_char_for_item
            end
            
            local equipped_id = tonumber(query_result) or 0
            
            -- If they have something equipped, get its name and compare
            if equipped_id and equipped_id > 0 then
                local query_name = string.format('Me.Inventory[%s].Name', item_slot_name)
                mq.cmdf('/dquery %s -q %s', target_char.name, query_name)
                mq.delay(250)
                
                local ok_name_query, name_result = pcall(function() return dannet.Query() end)
                local equipped_name = (ok_name_query and name_result) or "Unknown"
                
                -- Compare items
                local current_stats = get_item_stats(equipped_id)
                if current_stats then
                    local weights = CLASS_WEIGHTS[target_char.class] or CLASS_WEIGHTS['Warrior']
                    local current_score = calculate_stat_score(current_stats, weights, item_slot, target_char.class)
                    local new_score = calculate_stat_score(inv_stats, weights, item_slot, target_char.class)
                    local score_delta = new_score - current_score
                    
                    if score_delta > 0 then
                        -- This is an upgrade!
                        if not all_upgrades[target_char.name] then
                            all_upgrades[target_char.name] = {
                                class = target_char.class,
                                level = target_char.level,
                                upgrades = {}
                            }
                        end
                        
                        table.insert(all_upgrades[target_char.name].upgrades, {
                            slot_id = item_slot,
                            slot_name = item_slot_name,
                            current_item = equipped_name,
                            current_item_id = equipped_id,
                            current_stats = current_stats,
                            upgrade_item = inv_item.item_name,
                            upgrade_item_id = inv_item.item_id,
                            upgrade_stats = inv_stats,
                            score_delta = score_delta,
                            upgrade_slot_index = inv_item.slot_index,
                            upgrade_container_slot = inv_item.container_slot,
                        })
                    end
                end
            else
                -- Empty slot - any item is an upgrade
                if not all_upgrades[target_char.name] then
                    all_upgrades[target_char.name] = {
                        class = target_char.class,
                        level = target_char.level,
                        upgrades = {}
                    }
                end
                
                table.insert(all_upgrades[target_char.name].upgrades, {
                    slot_id = item_slot,
                    slot_name = item_slot_name,
                    current_item = "[Empty]",
                    current_item_id = 0,
                    current_stats = nil,
                    upgrade_item = inv_item.item_name,
                    upgrade_item_id = inv_item.item_id,
                    upgrade_stats = inv_stats,
                    score_delta = 1.0,
                    upgrade_slot_index = inv_item.slot_index,
                    upgrade_container_slot = inv_item.container_slot,
                })
            end
            
            ::next_char_for_item::
        end
        
        ::next_item::
    end
    
    -- Output results in character priority order
    for _, target_char in ipairs(dannet_characters) do
        if all_upgrades[target_char.name] then
            mq.cmdf('/echo Checking %s (%s Lvl %d)...', target_char.name, target_char.class, target_char.level)
            local char_upgrades = all_upgrades[target_char.name].upgrades
            for _, upgrade in ipairs(char_upgrades) do
                mq.cmdf('/echo   Potential upgrade: %s -> %s (delta: +%.1f)', 
                    upgrade.current_item, upgrade.upgrade_item, upgrade.score_delta)
            end
            mq.cmdf('/echo Finished checking %s - found %d upgrade(s)', target_char.name, #char_upgrades)
        end
    end
    
    cross_char_results.upgrades_by_character = all_upgrades
    cross_char_results.scan_complete = true
    mq.cmdf('/echo \ao=================================================\ax')
    
    local total_upgrades = 0
    for _, char_data in pairs(all_upgrades) do
        total_upgrades = total_upgrades + #char_data.upgrades
    end
    
    if total_upgrades > 0 then
        mq.cmdf('/echo \ag✓ Scan complete: Found %d total upgrade(s)\ax', total_upgrades)
    else
        mq.cmdf('/echo \ayNo upgrades found\ax')
    end
    
    -- Always show the window after scan completes
    show_cross_upgrade_window = true
end

-- ============================================================================
-- Item Distribution Functions (must be before ImGui display function)
-- ============================================================================

local function pick_up_item_from_inventory(slot_index, container_slot)
    --[[
    Pick up an item from inventory
    
    If container_slot is nil: item is in direct inventory
    If container_slot is set: item is inside a container at slot_index
    ]]
    if not slot_index then
        mq.cmdf('/echo ERROR: Invalid slot index')
        return false
    end
    
    if container_slot and container_slot > 0 then
        -- Item is inside a container
        -- Use /shift /itemnotify to pick up from container
        -- Container slots are packs: slot 23=pack1, 24=pack2, etc.
        local pack_slot = slot_index - 22
        mq.cmdf('/shift /itemnotify in pack%d %d leftmouseup', pack_slot, container_slot)
    else
        -- Item is in direct inventory
        mq.cmdf('/shift /itemnotify in inv%d leftmouseup', slot_index)
    end
    
    return true
end

local function distribute_single_upgrade(char_name, upgrade, char_class)
    --[[
    Queue a single upgrade for trading
    The actual trade will be executed by the main loop with proper delays
    Convert class shortname to long name for targeting
    ]]
    if not char_name or not upgrade then
        return false
    end
    
    -- Convert short class name to long name for /target command
    local class_map = {
        war = "warrior", pal = "paladin", shd = "shadowknight",
        rog = "rogue", ber = "berserker", mnk = "monk", rng = "ranger", brd = "bard",
        bst = "beastlord", dru = "druid",
        clr = "cleric", shm = "shaman",
        mag = "magician", wiz = "wizard", enc = "enchanter", nec = "necromancer"
    }
    
    local long_class = class_map[char_class:lower()] or char_class:lower()
    
    -- Set pending trade
    pending_trade = {
        char_name = char_name,
        char_class = long_class,
        upgrade = upgrade,
        step = "pickup"
    }
    trade_step_timer = 0
    
    mq.cmdf('/echo Queued trade: %s -> %s', upgrade.upgrade_item, char_name)
    return true
end

-- Process pending trade with state machine (called from main loop)
local function process_pending_trade()
    if not pending_trade then return end
    
    trade_step_timer = trade_step_timer + 1
    
    if pending_trade.step == "pickup" then
        if trade_step_timer == 1 then
            -- Pick up the item
            if pick_up_item_from_inventory(pending_trade.upgrade.upgrade_slot_index, pending_trade.upgrade.upgrade_container_slot) then
                mq.cmdf('/echo [Trade] Picked up item')
                pending_trade.step = "target"
                trade_step_timer = 0
            else
                mq.cmdf('/echo [Trade] ERROR: Failed to pick up item')
                pending_trade = nil
            end
        end
        
    elseif pending_trade.step == "target" then
        if trade_step_timer >= 5 then  -- Wait 500ms (5 * 100ms ticks)
            -- Target the character by name and class (avoids pets)
            mq.cmdf('/target %s class %s', pending_trade.char_name, pending_trade.char_class)
            mq.cmdf('/echo [Trade] Targeted %s (%s)', pending_trade.char_name, pending_trade.char_class)
            pending_trade.step = "usetarget"
            trade_step_timer = 0
        end
        
    elseif pending_trade.step == "usetarget" then
        if trade_step_timer >= 5 then  -- Wait 500ms
            -- Use /usetarget to open trade window
            mq.cmdf('/usetarget')
            mq.cmdf('/echo [Trade] Opened trade window')
            pending_trade.step = "verify_target"
            trade_step_timer = 0
        end
        
    elseif pending_trade.step == "verify_target" then
        if trade_step_timer >= 5 then  -- Wait 500ms for window to stabilize
            -- Re-target the character by name and class to ensure correct target
            mq.cmdf('/target %s class %s', pending_trade.char_name, pending_trade.char_class)
            mq.cmdf('/echo [Trade] Re-verified target: %s (%s)', pending_trade.char_name, pending_trade.char_class)
            pending_trade.step = "trade_button"
            trade_step_timer = 0
        end
        
    elseif pending_trade.step == "trade_button" then
        if trade_step_timer >= 5 then  -- Wait 500ms after re-target
            -- Click the trade button
            mq.cmdf('/notify TradeWND TRDW_Trade_Button leftmouseup')
            mq.cmdf('/echo \ag✓ Traded %s to %s\ax', pending_trade.upgrade.upgrade_item, pending_trade.char_name)
            pending_trade = nil
        end
    end
end

local function distribute_upgrades_auto()
    --[[
    Automatically distribute all recommended upgrades
    Items are queued one at a time to be processed by the state machine
    ]]
    if not cross_char_results or not cross_char_results.upgrades then
        mq.cmdf('/echo No upgrades to distribute')
        return
    end
    
    local total_trades = 0
    for char_name, upgrades in pairs(cross_char_results.upgrades) do
        for _, upgrade in ipairs(upgrades) do
            if upgrade.upgrade_item and upgrade.upgrade_item ~= "" then
                total_trades = total_trades + 1
            end
        end
    end
    
    mq.cmdf('/echo \ag%d upgrades will be distributed\ax', total_trades)
    -- TODO: Implement bulk queueing if needed
    -- For now, users will click individual trade buttons
end

-- ============================================================================
-- ImGui Display Function
-- ============================================================================

local function display_cross_upgrades_window()
    if not show_cross_upgrade_window then return end
    
    if not cross_char_results then
        return
    end
    
    ImGui.SetNextWindowSize(900, 650)
    local ok, open = pcall(function() return ImGui.Begin("Cross-Character Upgrades##CrossUpgrades", true) end)
    
    if not ok or not open then
        show_cross_upgrade_window = false
        if ok then ImGui.End() end
        return
    end
    
    -- Count characters with upgrades
    local char_count = 0
    for _ in pairs(cross_char_results.upgrades_by_character) do
        char_count = char_count + 1
    end
    
    -- Wrap rendering in error handling
    local render_ok = pcall(function()
        -- Header
        ImGui.TextColored(0.2, 0.8, 1.0, 1.0, string.format("Source: %s | Found items for %d character(s)",
            cross_char_results.source_character or "Unknown",
            char_count))
        ImGui.Separator()
        
        if char_count > 0 then
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "Green = improvement, Red = regression")
            
            ImGui.BeginChild("##CrossUpgradesScroll", 0, -40)
            
            for char_name, char_data in pairs(cross_char_results.upgrades_by_character) do
                ImGui.TextColored(1.0, 0.84, 0.0, 1.0, string.format("%s Lvl %d %s (%d upgrades)", 
                    char_name, char_data.level, char_data.class, #char_data.upgrades))
                ImGui.Separator()
                
                for upgrade_idx, upgrade in ipairs(char_data.upgrades) do
                    ImGui.PushID(char_name .. "_" .. upgrade_idx)
                    
                    -- Slot and item info
                    ImGui.TextColored(1.0, 0.84, 0.0, 1.0, upgrade.slot_name)
                    ImGui.SameLine(150)
                    ImGui.TextColored(0.8, 0.8, 0.8, 1.0, upgrade.current_item)
                    ImGui.SameLine()
                    ImGui.Text(" -> ")
                    ImGui.SameLine()
                    ImGui.TextColored(0.2, 1.0, 0.2, 1.0, upgrade.upgrade_item)
                    ImGui.SameLine()
                    
                    if ImGui.SmallButton(string.format("Trade##%s_%d", char_name, upgrade_idx)) then
                        distribute_single_upgrade(char_name, upgrade, char_data.class)
                    end
                    
                    -- Score improvement
                    ImGui.TextColored(0.2, 1.0, 0.2, 1.0, string.format("Score +%.1f", upgrade.score_delta))
                    
                    ImGui.PopID()
                end
                
                ImGui.Spacing()
            end
            
            ImGui.EndChild()
        else
            ImGui.TextColored(1.0, 1.0, 0.0, 1.0, "No cross-character upgrades found")
        end
        
        ImGui.Separator()
        
        -- Distribute button
        if ImGui.Button("Distribute Upgrades", 150, 0) then
            mq.cmdf('/echo Starting upgrade distribution...')
            distribute_upgrades_auto()
        end
        
        if ImGui.IsItemHovered() then
            ImGui.SetTooltip("Trade all recommended upgrades to characters\nin priority order (Tank->Melee->Healer->Caster)")
        end
        
        ImGui.SameLine()
        
        if ImGui.Button("Close Window", 100, 0) then
            show_cross_upgrade_window = false
        end
    end)
    
    if not render_ok then
        mq.cmdf('/echo \arERROR: Failed to render upgrade window\ax')
        show_cross_upgrade_window = false
    end
    
    pcall(function() ImGui.End() end)
end

-- ============================================================================
-- Item Distribution Functions
-- ============================================================================

local function pick_up_item_from_inventory(slot_index, container_slot)
    --[[
    Pick up an item from inventory
    
    If container_slot is nil: item is in direct inventory
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
    
    if container_slot and container_slot > 0 then
        -- Item is inside a container
        -- Use /shift /itemnotify to pick up from container
        local pack_number = slot_index - 22  -- Packs start at slot 23, so pack 1 = slot 23
        mq.cmdf('/shift /itemnotify in pack[%d] %d leftmouseup', pack_number, container_slot)
    else
        -- Item is in direct inventory
        mq.cmdf('/shift /itemnotify in inv%d leftmouseup', slot_index)
    end
    
    mq.delay(500)
    return true
end

local function trade_item_to_character(target_name)
    --[[
    Initiate a trade with the target character
    Item should already be on cursor
    Uses a timed sequence: drop item on target, then confirm targeting
    ]]
    if not target_name or target_name == "" then
        mq.cmdf('/echo ERROR: Invalid target name')
        return false
    end
    
    -- Target the character first
    mq.cmdf('/target %s', target_name)
    mq.delay(250)
    
    -- Drop item on target with timed re-targeting to confirm
    mq.cmdf('/multiline ; /nomodkey /shiftkey /itemnotify #${Cursor.ID} leftmouseup; /timed 5 /target ${Target.Name}')
    mq.delay(1500)  -- Wait for trade to complete
    
    return true
end

local function distribute_upgrades_auto()
    --[[
    Automatically distribute all upgrades to characters in priority order
    Goes through all items and trades them based on upgrade recommendations
    ]]
    
    if not cross_char_results.scan_complete then
        mq.cmdf('/echo ERROR: Scan not complete')
        return
    end
    
    local results = cross_char_results.upgrades_by_character
    if not results or table.maxn(results) == 0 then
        mq.cmdf('/echo No upgrades to distribute')
        return
    end
    
    mq.cmdf('/echo \ao=================================================\ax')
    mq.cmdf('/echo \ag✓ Starting automated upgrade distribution\ax')
    mq.cmdf('/echo \ao=================================================\ax')
    
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
    
    -- Sort by priority (must match the priority system from the scanner)
    table.sort(char_list, function(a, b)
        local priority_a, _ = get_character_role_priority(a.class)
        local priority_b, _ = get_character_role_priority(b.class)
        if priority_a ~= priority_b then
            return priority_a < priority_b
        end
        return a.name < b.name
    end)
    
    -- Distribution tracking
    local total_traded = 0
    local total_skipped = 0
    
    -- Process each character in priority order
    for _, char_info in ipairs(char_list) do
        if char_info.upgrades and #char_info.upgrades > 0 then
            mq.cmdf('/echo \ay--- Sending items to %s (%s Lvl %d) ---\ax', 
                char_info.name, char_info.class, char_info.level)
            
            for idx, upgrade in ipairs(char_info.upgrades) do
                mq.cmdf('/echo [%d/%d] Sending %s -> %s', idx, #char_info.upgrades, 
                    upgrade.current_item, upgrade.upgrade_item)
                
                -- Pick up the item
                if not pick_up_item_from_inventory(upgrade.upgrade_slot_index, upgrade.upgrade_container_slot) then
                    mq.cmdf('/echo   ERROR: Failed to pick up item')
                    total_skipped = total_skipped + 1
                    goto continue_item
                end
                
                -- Trade to character
                if not trade_item_to_character(char_info.name) then
                    mq.cmdf('/echo   ERROR: Failed to trade item')
                    total_skipped = total_skipped + 1
                    goto continue_item
                end
                
                mq.cmdf('/echo   \ag✓ Item sent\ax')
                total_traded = total_traded + 1
                
                ::continue_item::
                mq.delay(2000)  -- Wait between trades
            end
        end
    end
    
    mq.cmdf('/echo \ao=================================================\ax')
    mq.cmdf('/echo \ag✓ Distribution complete!\ax')
    mq.cmdf('/echo   Sent: %d | Skipped: %d | Total: %d', 
        total_traded, total_skipped, total_traded + total_skipped)
    mq.cmdf('/echo \ao=================================================\ax')
end

check_cross_character_upgrades()

-- Initialize ImGui window and show results with error handling
local imgui_ok = pcall(function()
    mq.imgui.init('displayCrossUpgradesWindow', display_cross_upgrades_window)
end)

if not imgui_ok then
    mq.cmdf('/echo \arERROR: Failed to initialize cross-character upgrade window\ax')
    mq.delay(3000)
else
    -- Keep showing the window while it's open or while still showing upgrades
    while show_cross_upgrade_window or cross_char_results.scan_complete do
        mq.doevents()
        
        -- Process pending trade with state machine
        process_pending_trade()
        
        mq.delay(100)
        
        -- Exit loop if window is closed and scan is complete
        if not show_cross_upgrade_window and cross_char_results.scan_complete then
            break
        end
    end
end
