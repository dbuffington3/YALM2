# Phase 1 Implementation Specification (PERMANENT REFERENCE)

**Date Created:** December 30, 2025
**Status:** SPECIFICATION (Ready to implement)
**Objective:** Add tier field to armor_sets.lua and expand ARMOR_PROGRESSION table

---

## Overview

This document specifies exactly what will be changed in Phase 1, using the complete expansion hierarchy data from COMPLETE_EXPANSION_ARMOR_HIERARCHY.md. This prevents data loss and allows anyone to pick up where we left off.

---

## Tier Numbering System (Source: COMPLETE_EXPANSION_ARMOR_HIERARCHY.md)

Use this progression_level scale for ALL armor sets:

```
PROGRESSION LEVEL SCALE (1-53):
1-4:    Underfoot T6-T9
5-8:    House of Thule T1-T4
9-12:   Veil of Alaris T1-T4
13-16:  Rain of Fear T1-T4
17-18:  Call of the Forsaken T1-T2
19-21:  The Darkened Sea T1-T3
22-24:  The Broken Mirror T1-T3
25-26:  Empires of Kunark T1-T2
27-28:  Ring of Scale T1-T2 (group)
29:     Ring of Scale Tradeskill T2
30-31:  The Burning Lands T1-T2 (group)
32:     The Burning Lands Tradeskill T2
33-34:  Torment of Velious T1-T2 (group)
35:     Torment of Velious Tradeskill T2
36-37:  Claws of Veeshan T1-T2 (group)
38:     Claws of Veeshan Tradeskill T2
39-40:  Terror of Luclin T1-T2 (group)
41:     Terror of Luclin Tradeskill T2
42-43:  Night of Shadows T1-T2 (group)
44:     Night of Shadows Tradeskill T2
45-46:  Laurion's Song T1-T2 (group)
47:     Laurion's Song Tradeskill T2
48-49:  The Outer Brood T1-T2 (group)
50:     The Outer Brood Tradeskill T2
51-52:  Shattering of Ro T1-T2 (group)
53:     Shattering of Ro Tradeskill T2
```

---

## Phase 1 Changes: 3 Core Modifications

### Change 1: Expand ARMOR_PROGRESSION Table

**File:** `config/armor_sets.lua`

**Current State:** Only has Fear Touched → Boreal → Distorted → Twilight → Frightweave (Rain of Fear)

**Target State:** Add House of Thule and Veil of Alaris progression chains

**Exact Additions:**

```lua
-- HOUSE OF THULE PROGRESSION (tier 5-8)
['Abstruse'] = {
    creates = 'Recondite',
    tier = 5,
    secondary = nil  -- Drops alone, tier 1 HoT
},
['Recondite'] = {
    creates = 'Ambiguous',
    tier = 6,
    secondary = 'Recondite Coalescing Agent'  -- Agent required for T2
},
['Ambiguous'] = {
    creates = 'Lucid',
    tier = 7,
    secondary = 'Ambiguous Coalescing Agent'  -- Agent required for T3
},
['Lucid'] = {
    tier = 8,
    secondary = 'Lucid Coalescing Agent'  -- Agent required for T4
},

-- VEIL OF ALARIS PROGRESSION (tier 9-12)
['Rustic'] = {
    creates = 'Formal',
    tier = 9,
    secondary = nil  -- Tier 1 VOA
},
['Formal'] = {
    creates = 'Embellished',
    tier = 10,
    secondary = 'Plain Unadorned Template'  -- Template + wrap required
},
['Embellished'] = {
    creates = 'Grandiose',
    tier = 11,
    secondary = 'Detailed Unadorned Template'  -- Template + wrap required
},
['Grandiose'] = {
    tier = 12,
    secondary = 'Sophisticated Unadorned Template'  -- Template + wrap required
},
```

**Notes:**
- Fear Touched (tier 1) through Frightweave (tier 4) already exist
- HoT adds tiers 5-8
- VOA adds tiers 9-12
- Secondary materials document what's needed for each progression

---

### Change 2: Add Tier Field to All Armor Sets

**File:** `config/armor_sets.lua`

**Current Example:**
```lua
['Recondite'] = {
    display_name = "Recondite Armor",
    pieces = {
        ['Wrist'] = {
            slots = { 9, 10 },
            remnant_name = 'Recondite Remnant of Truth',
            ...
        },
        ...
    }
}
```

**Target (Add tier field):**
```lua
['Recondite'] = {
    display_name = "Recondite Armor",
    tier = 6,  -- NEW FIELD: House of Thule T2 = progression level 6
    pieces = {
        ['Wrist'] = {
            slots = { 9, 10 },
            remnant_name = 'Recondite Remnant of Truth',
            ...
        },
        ...
    }
}
```

**Implementation Strategy:**
1. Query armor_sets.lua to extract all armor set names
2. Map each set to its expansion and tier using ARMOR_PROGRESSION table and armor naming conventions
3. Add `tier = X` field to each set definition
4. Example mappings:

| Armor Set Name | Expansion | Tier Value | Reason |
|---|---|---|---|
| Fear Touched | Rain of Fear | 1 | T1 ROF |
| Boreal | Rain of Fear | 2 | T2 ROF |
| Recondite | House of Thule | 6 | T2 HoT |
| Abstruse | House of Thule | 5 | T1 HoT |
| Rustic | Veil of Alaris | 9 | T1 VOA |
| Formal | Veil of Alaris | 10 | T2 VOA |
| Castaway | The Darkened Sea | 19 | T1 TDS |
| Tideworn | The Darkened Sea | 20 | T2 TDS |

**Full Mapping Reference:**

See section "Complete Armor Set Tier Mapping" below.

---

### Change 3: Update Equipment Distribution Logic

**File:** `core/equipment_distribution.lua`

**Current Logic:** Distributes armor based on... (need to check current file)

**Target Logic:** 
```lua
local function find_best_recipient(item_name)
    local loot_tier = get_tier_from_item_name(item_name)
    
    for _, player_name in ipairs(group_players) do
        local current_armor_tier = get_player_equipped_armor_tier(player_name)
        
        -- Skip if player already has equal or higher tier armor
        if current_armor_tier >= loot_tier then
            YALM_DEBUG("Skipping " .. player_name .. ": has tier " .. current_armor_tier .. ", loot is tier " .. loot_tier)
            continue
        end
        
        -- Prefer larger tier gaps (greater upgrade)
        local tier_gap = loot_tier - current_armor_tier
        if tier_gap > best_tier_gap then
            best_recipient = player_name
            best_tier_gap = tier_gap
        end
    end
    
    return best_recipient
end
```

**Helper Function:**
```lua
local function get_tier_from_item_name(item_name)
    -- Look up item_name in armor_sets.lua ARMOR_PROGRESSION table
    -- Return tier value (1-53)
    -- If not found, return 0 (unknown item, don't distribute)
    
    for armor_name, armor_data in pairs(ARMOR_PROGRESSION) do
        if string.match(item_name, armor_name) then
            return armor_data.tier
        end
    end
    return 0
end

local function get_player_equipped_armor_tier(player_name)
    -- Query player's equipped armor
    -- Cross-reference with armor_sets.lua tier field
    -- Return highest tier value equipped (or 0 if no armor)
    
    local max_tier = 0
    local equipped_items = get_player_equipped_items(player_name)
    
    for _, item_name in ipairs(equipped_items) do
        local tier = get_tier_from_item_name(item_name)
        if tier > max_tier then
            max_tier = tier
        end
    end
    
    return max_tier
end
```

---

## Complete Armor Set Tier Mapping

### House of Thule (Tier 5-8)

| Set Name | Tier | Notes |
|---|---|---|
| Abstruse | 5 | T1 HoT - remnant-based |
| Recondite | 6 | T2 HoT - requires agent |
| Ambiguous | 7 | T3 HoT - requires agent + template |
| Lucid | 8 | T4 HoT - requires agent + template |

### Veil of Alaris (Tier 9-12)

| Set Name | Tier | Notes |
|---|---|---|
| Rustic | 9 | T1 VOA - wrap-based |
| Formal | 10 | T2 VOA - requires agent + template |
| Embellished | 11 | T3 VOA - requires agent + template + language |
| Grandiose | 12 | T4 VOA - requires agent + template + language |

### Rain of Fear (Tier 1-4) - Already Exists

| Set Name | Tier | Notes |
|---|---|---|
| Boreal (Fear Touched) | 1 | T1 ROF |
| Distorted (Fear Stained) | 2 | T2 ROF |
| Twilight (Fear Washed) | 3 | T3 ROF |
| Frightweave (Fear Infused) | 4 | T4 ROF |

### The Darkened Sea (Tier 19-21)

| Set Name | Tier | Notes |
|---|---|---|
| Castaway | 19 | T1 TDS |
| Tideworn | 20 | T2 TDS |
| Highwater | 21 | T3 TDS |

### The Broken Mirror (Tier 22-24)

| Set Name | Tier | Notes |
|---|---|---|
| Generic | 22 | T1 TBM (right-click) |
| Vermiculated/Insidious/Apothic/Carmine | 23 | T2 TBM (class-named) |
| Crypt-Hunter | 24 | T3 TBM (crypt variant) |

### Other Expansions

(Full list would continue for all 17 expansions - see COMPLETE_EXPANSION_ARMOR_HIERARCHY.md for complete reference)

---

## Testing Plan

### Test 1: Tier Comparison
- Give player Recondite (tier 6) armor
- Drop Fear Touched (tier 1) loot
- **Expected:** Skipped (1 < 6)
- Give player Recondite (tier 6) armor
- Drop Ambiguous (tier 7) loot
- **Expected:** Accepted (7 > 6, tier gap = 1)

### Test 2: Upgrade Preference
- Two players: one has tier 5, one has tier 0
- Drop tier 6 loot
- **Expected:** Both could accept, but tier 5 player gets it (gap of 1 vs gap of 6)

### Test 3: Mixed Expansions
- Player has Mix: Rustic (tier 9), Fear Touched (tier 1), Castaway (tier 19)
- Current max tier = 19
- Drop Distorted (tier 2) loot
- **Expected:** Skipped (2 < 19)
- Drop Tideworn (tier 20) loot
- **Expected:** Accepted (20 > 19, tier gap = 1)

---

## Files Modified

- [x] **config/armor_sets.lua** - Add tier field to 380+ sets, expand ARMOR_PROGRESSION table
- [x] **core/equipment_distribution.lua** - Update find_best_recipient() with tier logic

## Files NOT Modified (Phase 1)

- ~~core/looting.lua~~ - Will use in Phase 2
- ~~config/settings.lua~~ - Existing settings work fine
- ~~lib/database.lua~~ - Not needed for Phase 1

---

## Data Source

All tier values derive from:
- **COMPLETE_EXPANSION_ARMOR_HIERARCHY.md** (definitive source)
- **Progression_level scale (1-53)** based on all 17 expansion armor guides

This ensures reproducibility: if we need to rebuild, follow COMPLETE_EXPANSION_ARMOR_HIERARCHY.md.

---

## Success Criteria

- ✅ All 380+ armor sets have `tier` field added
- ✅ ARMOR_PROGRESSION table expanded with HoT and VOA chains
- ✅ Equipment distribution logic uses tier comparison
- ✅ Testing shows correct upgrade paths (no tier downgrades)
- ✅ No regressions in existing functionality

---

## Notes for Future Reference

- **Why progression_level (1-53)?** Because each expansion has different tier counts, using a global scale prevents confusion between "T1 HoT" vs "T1 ROF"
- **Why start with HoT and VOA?** Because most players have these, gives immediate visible results
- **Why not all 17 at once?** Because Phase 1 is validation - we want to prove the system works before adding 200+ more armor sets
- **Next phase?** Phase 2 will add expansion field + handle tradeskill tiers (better stats) and cross-expansion comparisons

---

## Quick Reference Commands

If rebuilding this work:
1. Start from COMPLETE_EXPANSION_ARMOR_HIERARCHY.md (has all data)
2. Use progression_level scale above
3. Map armor set names from armor_sets.lua to tier values
4. Add tier field to each set
5. Expand ARMOR_PROGRESSION with new chains
6. Update distribution logic in equipment_distribution.lua

This document IS the specification. Follow it exactly to avoid data loss.
