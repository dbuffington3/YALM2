--[[
    Check Upgrades Script
    Scans character's equipped items vs inventory to find equipment upgrades
    Usage: /lua run check_upgrades.lua
]]

local mq = require('mq')
local inspect = require('yalm2.lib.inspect')

-- Import the database module and ensure it's initialized
require('yalm2.lib.database')
local db = YALM2_Database
if not db.database then
    -- OpenDatabase() will auto-detect the correct path based on YALM2's installation location
    -- It searches: <MQ2_ROOT>/resources/MQ2LinkDB.db first, then fallback locations
    db.database = db.OpenDatabase()
    if not db.database then
        error("Failed to open database. Ensure MQ2LinkDB.db is in <MQ2_ROOT>/resources/ directory")
    end
end

-- ============================================================================
-- Stat Weights by Class
-- ============================================================================

local CLASS_WEIGHTS = {
    -- Tank classes: AC is critical, endurance helps with long fights
    ['Shadowknight'] = { ac = 3, hp = 2, mana = 0.5, endurance = 1.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Shadow Knight'] = { ac = 3, hp = 2, mana = 0.5, endurance = 1.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },  -- MQ2 API returns "Shadow Knight" with space
    ['Warrior'] = { ac = 3, hp = 2, mana = 0, endurance = 1.5, resists = 1, attack = 1, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Paladin'] = { ac = 3, hp = 2, mana = 1, endurance = 1.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 0.5, heal = 1, clairvoyance = 0 },
    
    -- Melee DPS: Endurance and attack are primary
    ['Ranger'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Rogue'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Monk'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    ['Berserker'] = { ac = 1.5, hp = 1.5, mana = 0, endurance = 2, resists = 0.5, attack = 2, regen = 0.5, manaregen = 0, heal = 0, clairvoyance = 0 },
    
    -- Hybrid melee/caster: Some endurance, some mana
    ['Bard'] = { ac = 1, hp = 1.5, mana = 1.5, endurance = 1.5, resists = 0.5, attack = 1, regen = 0.5, manaregen = 0.5, heal = 0.5, clairvoyance = 1 },
    
    -- Caster healers: Mana and healing, minimal endurance (spell casting doesn't use endurance)
    ['Cleric'] = { ac = 1, hp = 2, mana = 2, endurance = 0, resists = 1, attack = 0, regen = 1, manaregen = 1, heal = 2, clairvoyance = 0.5 },
    ['Druid'] = { ac = 0.5, hp = 1.5, mana = 2, endurance = 0, resists = 1, attack = 0, regen = 1, manaregen = 1, heal = 1.5, clairvoyance = 0.5 },
    
    -- Pure casters: Mana is king, but AC still matters for survival
    ['Wizard'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0, clairvoyance = 1 },
    ['Enchanter'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0, clairvoyance = 1.5 },
    ['Necromancer'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0.5, clairvoyance = 1 },
    ['Magician'] = { ac = 1, hp = 1.5, mana = 3, endurance = 0, resists = 1.5, attack = 0, regen = 0.2, manaregen = 2, heal = 0, clairvoyance = 0.5 },
    ['Shaman'] = { ac = 1, hp = 1.5, mana = 2.5, endurance = 0.5, resists = 1, attack = 0.5, regen = 0.5, manaregen = 1.5, heal = 1.5, clairvoyance = 0.5 },
    ['Beastlord'] = { ac = 1, hp = 1.5, mana = 1.5, endurance = 1.5, resists = 0.5, attack = 1.5, regen = 0.5, manaregen = 0.5, heal = 0.5, clairvoyance = 0 },
}

-- Default weights (fallback) - conservative caster defaults
local DEFAULT_WEIGHTS = { ac = 0.5, hp = 1.5, mana = 2, endurance = 0, resists = 1, attack = 0, regen = 0.5, manaregen = 1, heal = 1, clairvoyance = 0.5 }

-- ============================================================================
-- Equipment Slots
-- ============================================================================

local EQUIPMENT_SLOTS = {
    'Head', 'Neck', 'Shoulders', 'Chest', 'Wrist', 'Hands',
    'Finger', 'Waist', 'Legs', 'Feet', 'Back', 'MainHand', 'OffHand'
}

-- Slot number to human-readable name mapping
-- Based on MQ2 equipment slot indices (from InventorySlots.lua)
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
    --[[
    Convert slot number to human-readable name with slot number
    ]]
    if SLOT_NAMES[slot_num] then
        return string.format('Slot %d: %s', slot_num, SLOT_NAMES[slot_num])
    end
    return string.format('Slot %d', slot_num)
end

-- ============================================================================
-- Utility Functions
-- ============================================================================

local function parse_roman_numeral(text)
    if not text then return 0 end
    
    local roman_values = {
        ['I'] = 1, ['II'] = 2, ['III'] = 3, ['IV'] = 4, ['V'] = 5,
        ['VI'] = 6, ['VII'] = 7, ['VIII'] = 8, ['IX'] = 9, ['X'] = 10,
        ['XI'] = 11, ['XII'] = 12, ['XIII'] = 13, ['XIV'] = 14, ['XV'] = 15,
        ['XVI'] = 16, ['XVII'] = 17, ['XVIII'] = 18, ['XIX'] = 19, ['XX'] = 20
    }
    
    -- Extract roman numeral from text
    for roman, value in pairs(roman_values) do
        if text:match(roman) then
            return value
        end
    end
    
    return 0
end

local function compare_effects(current_effect, new_effect)
    --[[
    Returns:
    - 1 if new effect is better
    - 0 if effects are equal/unknown
    - -1 if new effect is worse
    ]]
    
    if not current_effect or current_effect == '' then
        return new_effect and new_effect ~= '' and 1 or 0
    end
    
    if not new_effect or new_effect == '' then
        return -1
    end
    
    -- Extract base effect name (everything before numeral)
    local current_base = current_effect:gsub('%s+[IVX]+$', '')
    local new_base = new_effect:gsub('%s+[IVX]+$', '')
    
    -- If base names are the same, compare numerals
    if current_base == new_base then
        local current_num = parse_roman_numeral(current_effect)
        local new_num = parse_roman_numeral(new_effect)
        
        if new_num > current_num then
            return 1
        elseif new_num == current_num then
            return 0
        else
            return -1
        end
    end
    
    -- Different effect types - return 0 (user decision needed)
    return 0
end

local function get_item_stats(item_id)
    --[[
    Query database for item stats
    Returns table with all relevant stats
    ]]
    
    if not item_id or item_id == 0 then
        return nil
    end
    
    local item_data = db.QueryDatabaseForItemId(item_id)
    
    if not item_data then
        return nil
    end
    
    -- Normalize the field names and ensure numeric values
    -- Database fields use exact names: ac, hp, mana, endur, regen, manaregen, healamt, clairvoyance, etc.
    
    local slots_val = tonumber(item_data.slots) or 0
    local itemtype_val = tonumber(item_data.itemtype) or 0
    
    return {
        ac = tonumber(item_data.ac) or 0,
        hp = tonumber(item_data.hp) or 0,
        mana = tonumber(item_data.mana) or 0,
        endurance = tonumber(item_data.endur) or 0,  -- Database field is "endur"
        resists_magic = tonumber(item_data.mr) or 0,  -- Database field is "mr" (magic resistance)
        resists_fire = tonumber(item_data.fr) or 0,   -- Database field is "fr" (fire resistance)
        resists_cold = tonumber(item_data.cr) or 0,   -- Database field is "cr" (cold resistance)
        resists_poison = tonumber(item_data.pr) or 0, -- Database field is "pr" (poison resistance)
        resists_disease = tonumber(item_data.dr) or 0, -- Database field is "dr" (disease resistance)
        attack = tonumber(item_data.attack) or 0,
        hp_regen = tonumber(item_data.regen) or 0,    -- Database field is "regen"
        mana_regen = tonumber(item_data.manaregen) or 0, -- Database field is "manaregen"
        heal_amount = tonumber(item_data.healamt) or 0, -- Database field is "healamt"
        clairvoyance = tonumber(item_data.clairvoyance) or 0,
        spell_effect = '',  -- Not available in Lucy data
        worn_effect = '',   -- Not available in Lucy data
        required_level = tonumber(item_data.reqlevel) or 0, -- Database field is "reqlevel"
        classes = tonumber(item_data.classes) or 0,
        slots = slots_val,
        itemtype = itemtype_val, -- KEY FIELD: Equipment type (1=2H Slash, 2=1H Pierce, 3=1H Blunt, 4=2H Blunt, 5=Ranged, 7=Ammo, 8=Shield, 10=Armor)
        -- Weapon DPS fields
        damage = tonumber(item_data.damage) or 0,  -- Weapon damage value
        delay = tonumber(item_data.delay) or 0,    -- Weapon delay (attack speed)
        backstabdmg = tonumber(item_data.backstabdmg) or 0,  -- Backstab damage bonus (column 39)
    }
end

local function are_items_comparable(equipped_stats, inv_stats)
    --[[
    Check if two items are comparable for upgrade purposes
    Uses slots bitmask AND itemtype to determine valid comparisons
    
    Only equipment itemtypes are comparable:
    1 = 2H Slashing
    2 = Piercing (1H)
    3 = 1H Blunt
    4 = 2H Blunt
    5 = Ranged (Bows)
    7 = Ranged Ammo
    8 = Shield
    
    Non-equipment types (10, 11, 12, 14, 15, etc.) are never comparable as equipment upgrades
    
    Returns: true if items can be compared, false otherwise
    ]]
    
    if not equipped_stats or not inv_stats then
        return false
    end
    
    local equipped_slots = equipped_stats.slots or 0
    local inv_slots = inv_stats.slots or 0
    
    -- If either item has no valid slots (slots=0), they can't be equipped/compared
    if equipped_slots == 0 or inv_slots == 0 then
        return false
    end
    
    -- Check if there's any overlap in slots using bitwise AND
    local slot_overlap = bit.band(equipped_slots, inv_slots)
    
    if slot_overlap == 0 then
        return false
    end
    
    -- Both items can be equipped in overlapping slots
    -- Now check if they're valid equipment based on itemtype
    local equipped_type = equipped_stats.itemtype or 0
    local inv_type = inv_stats.itemtype or 0
    
    -- For weapons, check category compatibility (1H vs 2H vs other)
    -- This prevents comparing 1H to 2H weapons, but allows comparing across different categories if slots overlap
    local function get_weapon_category(itemtype)
        -- Weapon types: 1=2H Slash, 2=1H Pierce, 3=1H Blunt, 4=2H Blunt, 5=Ranged
        if itemtype == 2 or itemtype == 3 then return "1h_weapon"
        elseif itemtype == 1 or itemtype == 4 then return "2h_weapon"
        elseif itemtype == 5 then return "ranged_weapon"
        else return "other"  -- Includes armor (10), jewelry (18,19,29,30,etc), shields (8), ammo (7), etc.
        end
    end
    
    local equipped_category = get_weapon_category(equipped_type)
    local inv_category = get_weapon_category(inv_type)
    
    -- Can't compare 1H to 2H weapons (different hand slot requirements)
    -- But can compare 1H to 1H, 2H to 2H, and any "other" items with each other
    if equipped_category:match("weapon") and inv_category:match("weapon") then
        if equipped_category ~= inv_category then
            return false  -- Different weapon categories (1H vs 2H vs ranged)
        end
    end
    
    -- All other comparisons are OK if slots overlap
    return true
end

local function calculate_damage_bonus_at_level(character_level, character_class)
    --[[
    Calculate damage bonus for a given level and class.
    The UI displays damage bonus for level 70 viewing the item.
    For consistency and comparison, we calculate as level 70.
    
    Base formula: damage bonus = (character_level / 50) for melee classes
    For simplicity and consistency with Lucy data (level 70 baseline):
    We use a fixed level 70 damage bonus calculation.
    
    This varies by class and weapon type, but for standardized comparison,
    we use a moderate value that represents level 70 melee damage bonus.
    Typical values: 15-25 for melee classes at level 70.
    ]]
    
    -- For level 70 baseline comparison (as Lucy UI does)
    -- Melee classes get higher damage bonus
    local level_70_bonus = {
        ['Warrior'] = 20,
        ['Shadowknight'] = 20,
        ['Shadow Knight'] = 20,
        ['Paladin'] = 18,
        ['Ranger'] = 22,
        ['Rogue'] = 25,
        ['Monk'] = 20,
        ['Berserker'] = 25,
        ['Bard'] = 15,
        ['Beastlord'] = 18,
        ['Cleric'] = 0,
        ['Druid'] = 0,
        ['Wizard'] = 0,
        ['Enchanter'] = 0,
        ['Necromancer'] = 0,
        ['Magician'] = 0,
        ['Shaman'] = 5,
    }
    
    return level_70_bonus[character_class] or 0
end

local function calculate_mainhand_efficiency(damage, delay, backstabdmg, character_class)
    --[[
    Calculate Comparative Efficiency for MainHand (slot 13)
    Formula: (((damage * 2) + damage_bonus) / delay) * 50
    
    For Rogues, backstab damage is extremely valuable, add it to the calculation.
    Backstab damage makes up a significant portion of a Rogue's DPS.
    ]]
    
    if not damage or not delay or delay == 0 then
        return 0
    end
    
    local damage_bonus = calculate_damage_bonus_at_level(70, character_class)
    local effective_damage = (damage * 2) + damage_bonus
    
    -- For Rogues, include backstab damage as bonus to effective damage
    -- Backstab is a special attack that can deal massive damage if behind target
    if character_class == 'Rogue' and (backstabdmg or 0) > 0 then
        -- Backstab is risky/situational, so weight it at 50% of its value
        effective_damage = effective_damage + (backstabdmg * 0.5)
    end
    
    local efficiency = (effective_damage / delay) * 50
    return efficiency
end

local function calculate_offhand_efficiency(damage, delay, backstabdmg, character_class)
    --[[
    Calculate Offhand Efficiency for OffHand (slot 14)
    Formula: (((damage * 2) / delay) * 50) * 0.62
    
    Offhand weapons do 62% of the damage a mainhand weapon would do.
    For Rogues, backstab cannot be used from offhand, so don't include it here.
    ]]
    
    if not damage or not delay or delay == 0 then
        return 0
    end
    
    local efficiency = (((damage * 2) / delay) * 50) * 0.62
    return efficiency
end

local function calculate_stat_score(stats, weights, slot_num, character_class)
    --[[
    Calculate weighted score for an item's stats
    Params:
        stats: Item stats table
        weights: Class weight multipliers
        slot_num: Equipment slot (13=MainHand, 14=OffHand, etc.) - optional
        character_class: Character class for weapon efficiency calculation - optional
    ]]
    
    if not stats or not weights then
        return 0
    end
    
    local score = 0
    
    score = score + (stats.ac or 0) * weights.ac
    score = score + (stats.hp or 0) * weights.hp
    score = score + (stats.mana or 0) * weights.mana
    score = score + (stats.endurance or 0) * weights.endurance
    score = score + ((stats.resists_magic or 0) + (stats.resists_fire or 0) + (stats.resists_cold or 0) + 
                     (stats.resists_poison or 0) + (stats.resists_disease or 0)) * weights.resists
    score = score + (stats.attack or 0) * weights.attack
    score = score + (stats.hp_regen or 0) * weights.regen
    score = score + (stats.mana_regen or 0) * weights.manaregen
    score = score + (stats.heal_amount or 0) * weights.heal
    score = score + (stats.clairvoyance or 0) * weights.clairvoyance
    
    -- For weapons, calculate efficiency based on slot and character class
    -- This is critical for melee DPS classes and tanks
    if (stats.damage or 0) > 0 and (stats.delay or 0) > 0 then
        local efficiency = 0
        character_class = character_class or 'Wizard'  -- Default to caster if not provided
        
        -- Slot 13 is MainHand: Use Comparative Efficiency formula
        if slot_num == 13 then
            efficiency = calculate_mainhand_efficiency(stats.damage, stats.delay, stats.backstabdmg, character_class)
        -- Slot 14 is OffHand: Use Offhand Efficiency formula
        elseif slot_num == 14 then
            efficiency = calculate_offhand_efficiency(stats.damage, stats.delay, stats.backstabdmg, character_class)
        else
            -- For non-weapon slots, just use simple DPS
            efficiency = (stats.damage / stats.delay) * 1000
        end
        
        -- Weight efficiency based on class attack weight
        -- Higher attack weight = weapons are more important
        local efficiency_weight = weights.attack * 10
        score = score + efficiency * efficiency_weight
    end
    
    return score
end

local function get_stat_delta(current_stats, new_stats, weights)
    --[[
    Calculate stat deltas between two items
    Returns table with only changed stats
    ]]
    
    if not current_stats or not new_stats then
        return {}
    end
    
    local deltas = {}
    local stat_fields = {'ac', 'hp', 'mana', 'endurance', 'resists_magic', 'resists_fire', 'resists_cold', 
                         'resists_poison', 'resists_disease', 'attack', 'hp_regen', 'mana_regen', 'heal_amount', 'clairvoyance'}
    
    for _, field in ipairs(stat_fields) do
        local current_val = current_stats[field] or 0
        local new_val = new_stats[field] or 0
        local delta = new_val - current_val
        
        if delta ~= 0 then
            deltas[field] = delta
        end
    end
    
    return deltas
end

local function is_tank_class(character_class)
    --[[
    Determine if a class is a tank class
    Tank classes: Warrior, Paladin, Shadowknight/Shadow Knight
    These classes benefit from shields in offhand slots
    ]]
    if not character_class then return false end
    return character_class == 'Warrior' or 
           character_class == 'Paladin' or 
           character_class == 'Shadowknight' or 
           character_class == 'Shadow Knight'
end

local function is_caster_class(character_class)
    --[[
    Determine if a class is primarily a caster
    Caster classes: Cleric, Druid, Wizard, Enchanter, Necromancer, Magician, Shaman
    These classes may use shields in offhand for defense while casting
    ]]
    if not character_class then return false end
    return character_class == 'Cleric' or
           character_class == 'Druid' or
           character_class == 'Wizard' or
           character_class == 'Enchanter' or
           character_class == 'Necromancer' or
           character_class == 'Magician' or
           character_class == 'Shaman'
end

local function can_equip_shield_in_offhand(character_class)
    --[[
    Determine if a class can/should equip shields in the offhand slot (slot 14)
    Tank and caster classes can use shields effectively
    Melee DPS classes (Rogue, Ranger, Monk, Berserker, Bard, Beastlord) should not
    ]]
    return is_tank_class(character_class) or is_caster_class(character_class)
end

local function can_equip_item(item_id, character_level, character_class)
    --[[
    Check if character can equip item based on level and class requirements
    Classes field is a bitmask where each bit represents a class (1-indexed)
    ]]
    
    if not item_id or item_id == 0 then
        return false
    end
    
    local item_data = get_item_stats(item_id)
    if not item_data then
        return false
    end
    
    -- Items with no slots cannot be equipped
    if not item_data.slots or item_data.slots == 0 then
        return false
    end
    
    -- Check level requirement
    if item_data.required_level and item_data.required_level > character_level then
        return false
    end
    
    -- Check class restriction (classes field is bitmask)
    -- Classes.lua defines: WAR=1, CLR=2, PAL=3, RNG=4, SHD=5, DRU=6, MNK=7, BRD=8, ROG=9, SHM=10, NEC=11, WIZ=12, MAG=13, ENC=14, BST=15, BER=16
    -- If classes > 0, item is restricted to specific classes
    if item_data.classes and item_data.classes > 0 then
        -- Map character class name to class index (1-based)
        local class_map = {
            ['Warrior'] = 1, ['WAR'] = 1,
            ['Cleric'] = 2, ['CLR'] = 2,
            ['Paladin'] = 3, ['PAL'] = 3,
            ['Ranger'] = 4, ['RNG'] = 4,
            ['Shadowknight'] = 5, ['Shadow Knight'] = 5, ['SHD'] = 5,  -- MQ2 API returns "Shadow Knight" with space
            ['Druid'] = 6, ['DRU'] = 6,
            ['Monk'] = 7, ['MNK'] = 7,
            ['Bard'] = 8, ['BRD'] = 8,
            ['Rogue'] = 9, ['ROG'] = 9,
            ['Shaman'] = 10, ['SHM'] = 10,
            ['Necromancer'] = 11, ['NEC'] = 11,
            ['Wizard'] = 12, ['WIZ'] = 12,
            ['Magician'] = 13, ['MAG'] = 13,
            ['Enchanter'] = 14, ['ENC'] = 14,
            ['Beastlord'] = 15, ['BST'] = 15,
            ['Berserker'] = 16, ['BER'] = 16,
        }
        
        local class_index = class_map[character_class]
        if not class_index then
            -- Unknown class, be conservative and reject
            return false
        end
        
        -- Check if this class's bit is set in the classes bitmask
        -- Bit N is set if (classes & (2^(N-1))) > 0
        local class_bit = bit.lshift(1, class_index - 1)
        if bit.band(item_data.classes, class_bit) == 0 then
            -- This class is NOT in the bitmask, so they can't use it
            return false
        end
    end
    
    return true
end

local function get_slot_type(item_id)
    --[[
    Get the slot type(s) for an item (e.g., "MainHand", "Finger", "Neck", etc.)
    Returns the first/primary slot type or nil if not equippable
    ]]
    if not item_id or item_id == 0 then
        return nil
    end
    
    local item_data = get_item_stats(item_id)
    if not item_data then
        return nil
    end
    
    -- The item_type field should tell us what slot it goes in
    -- Common types: Armor, Weapon, Shield, Jewelry, etc.
    -- We need to check item_class or similar field
    -- For now, we'll use a simplified check based on item_type
    
    local item_type = item_data.item_type or ''
    local item_class = item_data.item_class or ''
    
    -- Basic classification
    if item_type:match('Shield') or item_class:match('Shield') then
        return 'OffHand'
    elseif item_type:match('2H') or item_class:match('2H') then
        return 'MainHand'  -- Could also be OffHand empty, but primarily MainHand
    elseif item_class:match('Ring') or item_type:match('Ring') then
        return 'Finger'
    elseif item_class:match('Neck') or item_type:match('Neck') then
        return 'Neck'
    end
    
    return nil
end

local function can_equip_in_slot(inv_item, equipped_slot_index)
    --[[
    Check if an inventory item can be equipped in the same slot type as what's equipped
    Uses wearslot field from database to compare item types
    ]]
    
    if not inv_item or not inv_item.item_id then
        return false
    end
    
    local inv_stats = get_item_stats(inv_item.item_id)
    if not inv_stats then
        return false
    end
    
    -- If we couldn't retrieve wearslot info from database, allow all for now
    -- (better to compare too many than too few)
    if not inv_stats.wearslot or inv_stats.wearslot == '' then
        return true
    end
    
    -- TODO: Compare wearslot values from both equipped and inventory items
    -- For now, we just allow through - the real filtering will come from
    -- comparing that both items have similar slot types
    
    return true
end

local function get_equipped_item_id(slot_name)
    --[[
    Get equipped item ID from character
    ]]
    
    local me = mq.TLO.Me
    if not me then
        return nil
    end
    
    local ok, equip_slot = pcall(function() return me.Equipment(slot_name) end)
    if not ok or not equip_slot then
        return nil
    end
    
    local ok2, item_exists = pcall(function() return equip_slot() end)
    if not ok2 or not item_exists then
        return nil
    end
    
    local ok3, item_id = pcall(function() return equip_slot.ID() end)
    if not ok3 or not item_id or item_id == 0 then
        return nil
    end
    
    return item_id
end

local function get_equipped_item_name(slot_name)
    --[[
    Get equipped item name from character
    ]]
    
    local me = mq.TLO.Me
    if not me then
        return 'Empty'
    end
    
    local ok, equip_slot = pcall(function() return me.Equipment(slot_name) end)
    if not ok or not equip_slot then
        return 'Empty'
    end
    
    local ok2, item_exists = pcall(function() return equip_slot() end)
    if not ok2 or not item_exists then
        return 'Empty'
    end
    
    local ok3, item_name = pcall(function() return equip_slot.Name() end)
    if not ok3 or not item_name then
        return 'Empty'
    end
    
    return item_name
end

-- ============================================================================
-- Equipment and Inventory Scanning (using direct slot access)
-- ============================================================================

local function get_equipped_items()
    --[[
    Get all currently equipped items (slots 0-22)
    Returns table of {item_id, item_name, slot}
    ]]
    
    local items = {}
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    
    if not ok_me or not me then
        return items
    end
    
    -- Equipment slots are 0-22
    for i = 0, 22 do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if ok_item and item then
            local ok_id, item_id = pcall(function() return item.ID() end)
            if not ok_id or not item_id or item_id == 0 then
                break  -- Empty slot
            end
            
            local ok_name, item_name = pcall(function() return item.Name() end)
            
            if ok_name and item_name then
                table.insert(items, {
                    item_id = item_id,
                    item_name = item_name,
                    slot = i
                })
            end
        end
    end
    
    return items
end

local function get_inventory_items()
    --[[
    Get all items in inventory including inside containers (slots 23+)
    Returns table of {item_id, item_name}
    ]]
    
    local items = {}
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    
    if not ok_me or not me then
        return items
    end
    
    -- Inventory slots start at 23
    local max_slots = 500  -- Much higher max to ensure we get all inventory items
    local items_found = 0
    
    for i = 23, max_slots do
        local ok_item, item = pcall(function() return me.Inventory(i) end)
        if not ok_item or not item then
            goto next_inventory_slot  -- Skip this slot and continue to next
        end
        
        -- Check if item actually exists (not an empty slot)
        local ok_id, item_id = pcall(function() return item.ID() end)
        if not ok_id or not item_id or item_id == 0 then
            goto next_inventory_slot  -- Skip empty slots, continue to next
        end
        
        local ok_name, item_name = pcall(function() return item.Name() end)
        
        if ok_name and item_name then
            items_found = items_found + 1
            table.insert(items, {
                item_id = item_id,
                item_name = item_name,
                slot_index = i
            })
        end
        
        -- Also scan inside this container for sub-items
        local ok_container, is_container = pcall(function() return item.Container() end)
        if ok_container and is_container then
            -- This item is a container, scan its contents
            local max_container_slots = 100  -- Increased max to ensure we get all items
            local items_found_in_container = 0
            
            for j = 1, max_container_slots do
                local ok_sub, sub_item = pcall(function() return item.Item(j) end)
                if not ok_sub or not sub_item then
                    goto skip_this_item  -- Skip empty slots instead of breaking
                end
                
                local ok_sub_id, sub_id = pcall(function() return sub_item.ID() end)
                if not ok_sub_id or not sub_id or sub_id == 0 then
                    goto skip_this_item  -- Skip invalid items
                end
                
                local ok_sub_name, sub_name = pcall(function() return sub_item.Name() end)
                
                if ok_sub_name and sub_name then
                    items_found_in_container = items_found_in_container + 1
                    items_found = items_found + 1
                    table.insert(items, {
                        item_id = sub_id,
                        item_name = sub_name,
                        slot_index = i,
                        container_slot = j
                    })
                end
                
                ::skip_this_item::
            end
            
        end
        
        ::next_inventory_slot::
    end
    
    return items
end

local function format_stat_change(field, delta)
    --[[
    Format a single stat change for display
    ]]
    
    local display_name = {
        ['ac'] = 'AC',
        ['hp'] = 'HP',
        ['mana'] = 'Mana',
        ['endurance'] = 'Endurance',
        ['resists_magic'] = 'Magic Resist',
        ['resists_fire'] = 'Fire Resist',
        ['resists_cold'] = 'Cold Resist',
        ['resists_poison'] = 'Poison Resist',
        ['resists_disease'] = 'Disease Resist',
        ['attack'] = 'Attack',
        ['hp_regen'] = 'HP Regen',
        ['mana_regen'] = 'Mana Regen',
        ['heal_amount'] = 'Heal Amt',
        ['clairvoyance'] = 'Clairvoyance',
    }
    
    local name = display_name[field] or field
    local sign = delta > 0 and '+' or ''
    
    return string.format("%s: %s%d", name, sign, delta)
end

-- ============================================================================
-- Main Logic
-- ============================================================================

local function check_upgrades()
    local ok_me, me = pcall(function() return mq.TLO.Me end)
    
    if not ok_me or not me then
        mq.cmdf('/echo Unable to access character data')
        return
    end
    
    local ok_exists, me_exists = pcall(function() return me() end)
    if not ok_exists or not me_exists then
        mq.cmdf('/echo Unable to access character data')
        return
    end
    
    local ok_name, char_name = pcall(function() return me.DisplayName() end)
    local ok_class, char_class = pcall(function() return me.Class.Name() end)
    local ok_level, char_level = pcall(function() return me.Level() end)
    
    if not ok_name or not char_name or not ok_class or not char_class or not ok_level or not char_level then
        mq.cmdf('/echo Unable to access character data')
        return
    end
    
    mq.cmdf('/echo \at[CHECK UPGRADES]\ax for %s (Level %d %s)', char_name, char_level, char_class)
    mq.cmdf('/echo \ao=================================================\ax')
    
    -- Get class weights
    -- Try exact match first, then try case-insensitive match
    local weights = CLASS_WEIGHTS[char_class]
    
    if not weights then
        -- Try case-insensitive search
        for class_name, class_weights in pairs(CLASS_WEIGHTS) do
            if class_name:lower() == char_class:lower() then
                weights = class_weights
                break
            end
        end
    end
    
    if not weights then
        weights = DEFAULT_WEIGHTS
    end
    
    local upgrade_count = 0
    
    -- Get all equipped and inventory items
    local equipped_items = get_equipped_items()
    local inventory_items = get_inventory_items()
    
    -- Filter out non-equippable items (slots=0) before comparison to avoid wasting CPU
    local equippable_items = {}
    for _, inv_item in ipairs(inventory_items) do
        local inv_stats = get_item_stats(inv_item.item_id)
        if inv_stats and inv_stats.slots and inv_stats.slots > 0 then
            table.insert(equippable_items, inv_item)
        end
    end
    
    -- For each equipped item, find best upgrade from inventory
    for _, equipped in ipairs(equipped_items) do
        local equipped_slot_num = equipped.slot
        local slot_display_name = get_slot_display_name(equipped_slot_num)
        local equipped_name = equipped.item_name
        
        local equipped_stats = get_item_stats(equipped.item_id)
        
        if not equipped_stats then
            goto next_equipped
        end
        
        -- Show which slot we're checking
        mq.cmdf('/echo Checking %s: %s', slot_display_name, equipped_name)
        
        -- Track rejection reasons for this slot
        local comparisons = {}
        local compared_ids = {}
        
        -- Find best upgrade for this item from inventory
        local best_upgrade = nil
        local best_score_delta = 0
        
        local equipped_score = calculate_stat_score(equipped_stats, weights, equipped_slot_num, char_class)
        
        for _, inv_item in ipairs(equippable_items) do
            if inv_item.item_id ~= equipped.item_id then  -- Don't compare against itself
                local inv_stats = get_item_stats(inv_item.item_id)
                if not inv_stats then
                    goto next_inventory_item
                end
                
                -- Only compare items that can fit in the same slots
                if not are_items_comparable(equipped_stats, inv_stats) then
                    goto next_inventory_item
                end
                
                -- For primary/secondary weapon slots (13/14), apply class-aware shield filtering
                -- Shields (itemtype=8) should not replace weapons, with exceptions based on class
                -- Weapon slots: 13=MainHand, 14=OffHand
                if (equipped_slot_num == 13 or equipped_slot_num == 14) then
                    local equipped_is_weapon = equipped_stats.itemtype and equipped_stats.itemtype >= 1 and equipped_stats.itemtype <= 5
                    local inv_is_shield = inv_stats.itemtype == 8
                    local equipped_is_shield = equipped_stats.itemtype == 8
                    local inv_is_weapon = inv_stats.itemtype and inv_stats.itemtype >= 1 and inv_stats.itemtype <= 5
                    
                    -- MAINHAND (slot 13): Never allow shields
                    -- Shields in mainhand are always a bad idea for all classes
                    if equipped_slot_num == 13 then
                        if equipped_is_weapon and inv_is_shield then
                            goto next_inventory_item  -- Weapon -> Shield in mainhand is always bad
                        end
                        if equipped_is_shield and inv_is_weapon then
                            goto next_inventory_item  -- Shield -> Weapon comparison in mainhand (weapon is better)
                        end
                    end
                    
                    -- OFFHAND (slot 14): Class-aware shield filtering
                    -- Tank and caster classes can use shields, but melee DPS should not
                    if equipped_slot_num == 14 then
                        if inv_is_shield and not can_equip_shield_in_offhand(char_class) then
                            -- This is a shield being recommended to a melee DPS class in offhand
                            goto next_inventory_item
                        end
                        
                        -- Also prevent melee DPS from losing weapon for shield in offhand
                        if equipped_is_weapon and inv_is_shield and not can_equip_shield_in_offhand(char_class) then
                            goto next_inventory_item
                        end
                    end
                end
                
                -- Track this ID as being compared
                table.insert(compared_ids, inv_item.item_id)
                
                local rejection_reason = nil
                
                -- Check if can equip (includes level and class checks)
                if not can_equip_item(inv_item.item_id, char_level, char_class) then
                    rejection_reason = "Level or class requirement failed"
                    goto next_inventory_item
                end
                
                -- Skip non-equipment items (bags, food, drinks, misc, etc.)
                -- Equipment itemtypes include: weapons, armor, shields, jewelry, etc.
                -- 1=2H Slash, 2=1H Pierce, 3=1H Blunt, 4=2H Blunt, 5=Ranged, 7=Ammo, 8=Shield, 10=Armor
                -- 18=Jewelry (rings), 19=Jewelry (necklace), 29=Jewelry (ring?), etc.
                -- For now, accept any itemtype that has slots (filtered earlier)
                -- Non-equippable items were already filtered out in the pre-filter step
                -- No additional itemtype rejection needed here
                
                local inv_score = calculate_stat_score(inv_stats, weights, equipped_slot_num, char_class)
                local score_delta = inv_score - equipped_score
                
                -- Sanity check: If AC gets significantly worse, require a much higher score improvement
                -- This prevents trading defensive stats for offensive/utility stats
                local ac_delta = (inv_stats.ac or 0) - (equipped_stats.ac or 0)
                if ac_delta < -10 then
                    -- Penalty: Losing more than 10 AC requires 5x the score improvement
                    score_delta = score_delta - (math.abs(ac_delta) * 2)
                end
                
                -- Compare effects
                local effect_comparison = compare_effects(equipped_stats.spell_effect, inv_stats.spell_effect)
                
                -- If effect is significantly better (new effect or higher rank), boost score
                if effect_comparison == 1 then
                    score_delta = score_delta + 10  -- Bonus for better effect
                elseif effect_comparison == -1 then
                    score_delta = score_delta - 5   -- Penalty for worse effect
                end
                
                -- Record this comparison
                if score_delta > 0 then
                    table.insert(comparisons, {item_name = inv_item.item_name, item_id = inv_item.item_id, 
                        score_delta = score_delta, equipped_score = equipped_score, inv_score = inv_score})
                else
                    rejection_reason = string.format("No improvement (delta=%.1f)", score_delta)
                    table.insert(comparisons, {item_name = inv_item.item_name, item_id = inv_item.item_id, reason = rejection_reason})
                end
                
                if score_delta > best_score_delta then
                    best_score_delta = score_delta
                    best_upgrade = {
                        item_id = inv_item.item_id,
                        item_name = inv_item.item_name,
                        stats = inv_stats,
                        score_delta = score_delta,
                        effect_comparison = effect_comparison
                    }
                end
                
                ::next_inventory_item::
            end
        end
        
        -- Debug: Show what items were compared for this slot
        -- if #compared_ids > 0 then
        --     local id_list = table.concat(compared_ids, ', ')
        --     mq.cmdf('/echo   Compared IDs: %s', id_list)
        -- else
        --     mq.cmdf('/echo   No items to compare (no matching slot types)')
        -- end
        
        -- Report best upgrade if found
        if best_upgrade and best_score_delta > 0 then
            upgrade_count = upgrade_count + 1
            mq.cmdf('/echo \ag✓ %s:\ax', slot_display_name)
            mq.cmdf('/echo   Current: %s', equipped_name)
            mq.cmdf('/echo   \agUpgrade:\ax %s', best_upgrade.item_name)
            
            -- Show stat deltas
            local deltas = get_stat_delta(equipped_stats, best_upgrade.stats, weights)
            for field, delta in pairs(deltas) do
                mq.cmdf('/echo     %s', format_stat_change(field, delta))
            end
            
            -- Show effect change
            if best_upgrade.effect_comparison == 1 then
                mq.cmdf('/echo     \agEffect:\ax %s → %s', 
                        equipped_stats.spell_effect or 'None',
                        best_upgrade.stats.spell_effect or 'None')
            elseif best_upgrade.effect_comparison == -1 then
                mq.cmdf('/echo     \arEffect:\ax %s → %s (downgrade)',
                        equipped_stats.spell_effect or 'None',
                        best_upgrade.stats.spell_effect or 'None')
            end
            
            mq.cmdf('/echo   Score Improvement: \ag+%.1f\ax', best_score_delta)
            mq.cmdf('/echo')
        else
            -- No upgrades found for this slot - skip display
        end
        
        ::next_equipped::
    end
    
    -- Summary
    mq.cmdf('/echo \ao=================================================\ax')
    if upgrade_count > 0 then
        mq.cmdf('/echo \ag✓ Found %d upgrade(s)\ax', upgrade_count)
    else
        mq.cmdf('/echo \ayNo clear upgrades found\ax')
    end
end

-- ============================================================================
-- Main Execution
-- ============================================================================

check_upgrades()
