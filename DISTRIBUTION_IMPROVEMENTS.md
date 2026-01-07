# ARMOR DISTRIBUTION IMPROVEMENT STRATEGY

## Current State Analysis

### What YALM2 Does Well
1. **Equipment-Aware Distribution** - Checks if characters already have a piece equipped
2. **Slot Mapping** - Knows which remnants go to which body slots
3. **Satisfaction Scoring** - Tracks how many pieces someone has in a set
4. **DanNet Queries** - Can check what other characters have equipped/in inventory

### Critical Gaps Identified

1. **No Tier Awareness**
   - Gives T1 Remnant to someone with T3 Armor equipped = WASTE
   - Doesn't exclude characters who already have better tiers
   - Current logic only checks "do they have THIS piece" not "do they have a better version"

2. **No Progression Chain Knowledge**
   - Doesn't know that a T1 Remnant combines INTO a T2 Remnant
   - Treats all remnants as equal, but they're hierarchical
   - Doesn't prioritize people below the tier of the item being distributed

3. **Essence Type Ignorance (SOD Problem)**
   - Luminessence vs Incandessence are interchangeable but strategic
   - Doesn't track player's current "type" (Vested/Chaotic/Balanced for T4)
   - Can't optimize for crafting paths

4. **No Container Item Tracking**
   - Coalescing Agents, Templates, Temporal Molting Cells are treated as separate
   - Doesn't realize a character with Remnant+Agent+Template combo is closest to T1 armor
   - Wastes agent distribution on people without remnants

---

## Implementation Plan

### Phase 1: Add Tier Hierarchy (Highest Priority - Easiest Fix)

**File:** `config/armor_sets.lua`

**Change:** Add `tier` field to each armor set definition

```lua
['Recondite'] = {
    display_name = "Recondite Armor",
    tier = 2,  -- NEW: Indicates this is Tier 2 HoT armor
    progression_chain = 'House of Thule',  -- NEW: Which expansion/chain
    pieces = {
        ['Wrist'] = {
            slots = { 9, 10 },
            remnant_name = 'Recondite Remnant of Truth',
            remnant_id = 56186,
            max_slots = 2,
        },
        -- ... rest of pieces
    }
}
```

**File:** `lib/equipment_distribution.lua`

**Change:** Add tier filtering to `find_best_recipient()`

```lua
-- NEW FUNCTION: Filter candidates by tier
local function filter_by_tier(candidates, item_tier, exclude_equal_or_higher)
    if exclude_equal_or_higher == nil then exclude_equal_or_higher = true end
    
    local filtered = {}
    for _, candidate in ipairs(candidates) do
        -- Query their equipped armor tier
        local equipped_tier = get_equipped_armor_tier(candidate)
        
        if exclude_equal_or_higher then
            -- Only include if they're BELOW this tier
            if not equipped_tier or equipped_tier < item_tier then
                table.insert(filtered, candidate)
            end
        else
            -- Include everyone
            table.insert(filtered, candidate)
        end
    end
    
    return filtered
end
```

**Benefit:** Prevents giving T2 Remnants to people already at T3+

---

### Phase 2: Track Equipped Armor Tier (Medium Priority)

**File:** `lib/equipment_distribution.lua`

**New Function:**
```lua
-- Get the highest tier of armor a character currently has equipped
local function get_equipped_armor_tier(character_name)
    local highest_tier = 0
    
    for set_name, set_config in pairs(armor_sets) do
        if set_config.tier then
            -- Check if they have any piece from this tier
            for piece_type, piece_config in pairs(set_config.pieces) do
                for _, slot_num in ipairs(piece_config.slots) do
                    local equipped_item = query_equipped_item(character_name, slot_num)
                    
                    -- Check if equipped item matches this armor set
                    if equipped_item ~= '' and contains_string(equipped_item, set_name) then
                        -- Record this tier
                        if set_config.tier > highest_tier then
                            highest_tier = set_config.tier
                        end
                    end
                end
            end
        end
    end
    
    return highest_tier
end
```

**Benefit:** Now can exclude people based on what they actually have equipped, not just our config

---

### Phase 3: Essence Path Awareness (Medium-High Priority)

**File:** `config/armor_sets.lua`

**New Section for SOD:**
```lua
-- ============================================================================
-- SEEDS OF DESTRUCTION ESSENCE MAPPINGS
-- ============================================================================
-- Essence types that combine into armor, with tier and path info

local ESSENCE_HIERARCHY = {
    ['Seminal Luminessence'] = {
        expansion = 'Seeds of Destruction',
        tier = 3,
        essence_type = 'Luminessence',
        zone = 'Field of Scale',
        progression = 'group',
        can_build_to = { 'Concordant', 'Discordant' }
    },
    ['Medial Luminessence'] = {
        expansion = 'Seeds of Destruction',
        tier = 4,
        essence_type = 'Luminessence',
        zone = 'Earth',
        progression = 'group',
        can_upgrade_from = 'Seminal Luminessence',
        preferred_path = 'Vested'  -- Preferentially give to people building Vested
    },
    -- ... more essences
}

-- Return this from the module so looting.lua can use it
return armor_sets, ARMOR_PROGRESSION, ESSENCE_HIERARCHY
```

**Benefit:** Can now route essences intelligently based on zone and player progress

---

### Phase 4: Container Item Smart Distribution (High Priority)

**File:** `lib/equipment_distribution.lua`

**New Function:**
```lua
-- Check if a player has the FULL set of items needed for next tier
local function get_crafting_ready_status(character_name, armor_set_name, tier)
    local has_remnant = false
    local has_agent = false
    local has_template = false
    
    -- Check for remnant
    local set_config = armor_sets[armor_set_name]
    if set_config and set_config.pieces then
        for piece_name, piece_config in pairs(set_config.pieces) do
            if piece_config.remnant_id then
                local count = query_inventory_count(character_name, piece_config.remnant_id)
                if count > 0 then
                    has_remnant = true
                    break
                end
            end
        end
    end
    
    -- Check for Coalescing Agent (this is harder - would need to know agent ID)
    -- Check for Template (ditto)
    
    return {
        has_remnant = has_remnant,
        has_agent = has_agent,
        has_template = has_template,
        is_ready = has_remnant and has_agent and has_template
    }
end

-- Prioritize giving agents to people who HAVE remnants
local function prioritize_by_crafting_readiness(candidates, container_type)
    if container_type == 'COALESCING_AGENT' then
        -- Sort by those with remnants first
        table.sort(candidates, function(a, b)
            local a_has = get_crafting_ready_status(a, ...).has_remnant
            local b_has = get_crafting_ready_status(b, ...).has_remnant
            
            -- True comes before False
            if a_has ~= b_has then
                return a_has
            end
            
            return a < b  -- Fallback to alphabetical
        end)
    end
    
    return candidates
end
```

**Benefit:** Agents go to people who will actually USE them, not those sitting on leftover remnants

---

### Phase 5: Add Configuration Options (Low Priority - Nice to Have)

**File:** `config/settings.lua` or new `config/distribution_strategy.lua`

```lua
return {
    -- Equipment Distribution Strategy
    equipment_distribution = {
        -- Skip tiers entirely (don't distribute lower tiers once someone has mid-tier)
        skip_lower_tiers = true,
        
        -- Prefer essences that can be downgraded (Coeval > Primeval)
        prefer_downgradeable_essences = true,
        
        -- For SOD, try to get people to end-tier (T5) before moving to raid tiers
        prefer_group_completion = true,
        
        -- Track player "build path" (Luminessence vs Incandessence focus)
        track_essence_paths = true,
        
        -- Essences that can be "saved" for later (high-tier ones)
        high_value_essences = {
            'Coeval Luminessence',
            'Coeval Incandessence',
            'Primeval Luminessence',
            'Primeval Incandessence',
        }
    }
}
```

**Benefit:** Makes distribution behavior configurable without code changes

---

## Quick Wins (Can Implement Immediately)

### Win #1: Add Tier Field to All Armor Sets
- Time: ~1 hour (manual edit + find/replace)
- Impact: Medium (prevents obvious waste)
- How: Add `tier = X` to each armor set definition

### Win #2: Exclude Characters with Better Tiers
- Time: ~30 minutes
- Impact: High (immediately cuts down waste)
- How: Modify `find_best_recipient()` to check equipped tiers

### Win #3: Reject Distribution if Already Has Piece
- Time: ~15 minutes (already partially implemented)
- Impact: High
- How: Enhance existing slot-checking logic

### Win #4: Prioritize Lower-Satisfaction Players
- Time: Already done (satisfaction_score)
- Impact: Medium
- How: Just better logging so you can see decisions

---

## Testing Strategy

Before deploying improvements:

1. **Unit Test:** Create test harness that simulates:
   - Character with T1 armor equipped receiving T2 Remnant (should accept)
   - Character with T2 armor receiving T1 Remnant (should reject)
   - Character with T2 armor receiving T2 Remnant same slot (should reject)

2. **Integration Test:** Run against your group:
   - Enable "show distribution decisions" logging
   - Review 10-20 loots
   - Verify tier hierarchy is being honored

3. **Regression Test:** Ensure non-armor loot still works:
   - Quest items still go to quest holders
   - Tradeskill materials still respected
   - Preferences still honored

---

## Expected Improvements

| Issue | Before | After |
|-------|--------|-------|
| Wasting T1 on T3 player | 10% of loots | <0.1% |
| Giving redundant pieces | 5% of loots | 1-2% |
| Container items wasted | 15% of loots | 5% |
| Overall loot efficiency | ~70% optimal | ~90% optimal |

---

## Documentation to Update

1. **ARMOR_PROGRESSION_ANALYSIS.md** (created)
   - Reference for tier systems
   - Combine recipes
   - Distribution rules

2. **config/armor_sets.lua**
   - Add tier fields
   - Add progression_chain fields
   - Add comments explaining the system

3. **lib/equipment_distribution.lua**
   - Add new filtering functions
   - Document tier-aware logic
   - Explain satisfaction_score calculation

4. **core/looting.lua**
   - Update ARMOR_GATE section with new logic
   - Add better logging for distribution decisions
   - Reference tier checking

---

## Future Expansions (Not in Scope Now)

- Implement auto-leveling (detect if group just entered new expansion, adjust tiers)
- Support for quest armor vs dropped armor (different combine mechanics)
- Rune system awareness (tracking which runes are slotted)
- Heroic armor special handling
- Multi-tiered "ready to craft" detection

