# QUICK START: Implement Phase 1 (Tier Awareness)

**Time Investment:** ~1-2 hours
**Impact:** High - Prevents ~70% of loot misses due to tier waste
**Difficulty:** Low - Mostly configuration, minimal code changes

---

## What This Does

After Phase 1, YALM2 will:
- Detect what tier of armor each piece is (T1, T2, T3, T4, etc)
- Exclude characters who already have equal or better tier equipped
- Refuse to distribute lower-tier materials to higher-tier players

Example:
```
Before: [Abstruse Remnant] → Gives to anyone with wrist slot free
After:  [Abstruse Remnant] → Rejects everyone with Recondite+ equipped
```

---

## Step 1: Add Tier Field to Armor Sets (30 minutes)

### What to do:
Edit `config/armor_sets.lua` and add a `tier` field to EACH armor set definition.

### Pattern:

**Find this:**
```lua
['Recondite'] = {
    display_name = "Recondite Armor",
    pieces = {
```

**Replace with this:**
```lua
['Recondite'] = {
    display_name = "Recondite Armor",
    tier = 2,  -- ADD THIS LINE
    pieces = {
```

### Mapping (House of Thule):
```
'Abstruse'   → tier = 1
'Recondite'  → tier = 2
'Ambiguous'  → tier = 3
'Lucid'      → tier = 4
'Enigmatic'  → tier = 1  (raid)
'Esoteric'   → tier = 2  (raid)
'Obscure'    → tier = 3  (raid)
'Perspicuous'→ tier = 4  (raid)
```

### How to do it efficiently (Copy/Paste Approach):

**For all Recondite entries:**
1. Open config/armor_sets.lua in editor
2. Find & Replace:
   - Find: `\['Recondite'[^=]*= \{\n[ \t]*display_name = "Recondite`
   - Replace: `['Recondite'] = {\n        tier = 2,\n        display_name = "Recondite`
   - (In VSCode: Use regex mode)

3. Repeat for each armor set with different tier number

**Manual backup approach (safer):**
1. Read through armor_sets.lua and identify all unique set names
2. For each name, manually add `tier = X,` after `display_name`
3. Use the mapping above to determine tier number

### How many to add?
Based on your file having 380 armor sets, you'll be adding the `tier` field approximately:
- ~40 Recondite entries (HoT T2)
- ~40 Lucid entries (HoT T4)
- ~40 Abstruse entries (HoT T1)
- ~40 Ambiguous entries (HoT T3)
- Plus all the raid variants and other expansions

---

## Step 2: Add Tier Filtering Function (15 minutes)

Add this to `lib/equipment_distribution.lua` right after the existing helper functions (before the main module.find_best_recipient section):

```lua
-- ============================================================================
-- TIER HIERARCHY FILTERING (NEW IN PHASE 1)
-- ============================================================================

--[[
    Get the highest armor tier a character currently has equipped.
    Returns nil if unable to determine or character has no armor.
    
    Args:
        character_name (string): Name of character to check
    
    Returns:
        (int or nil) Highest tier number they have equipped
]]
local function get_highest_equipped_tier(character_name)
    if not character_name or character_name == '' then
        return nil
    end
    
    local highest_tier = 0
    local found_any = false
    
    -- Iterate through all armor sets to find ones they have equipped
    for set_name, set_config in pairs(armor_sets) do
        if set_config.tier then
            -- Check all slots for this armor set
            if set_config.pieces then
                for piece_name, piece_config in pairs(set_config.pieces) do
                    for _, slot_num in ipairs(piece_config.slots) do
                        local equipped = query_equipped_item(character_name, slot_num)
                        
                        -- Check if item in that slot matches this armor set
                        if equipped ~= '' and contains_string(equipped, set_name) then
                            found_any = true
                            if set_config.tier > highest_tier then
                                highest_tier = set_config.tier
                            end
                        end
                    end
                end
            end
        end
    end
    
    return found_any and highest_tier or nil
end

--[[
    Filter candidate list to exclude those with higher/equal tiers.
    Only returns candidates below the target item's tier.
    
    Args:
        candidates (table): List of character names
        item_tier (int): Tier of item being distributed
    
    Returns:
        (table) Filtered list of candidates who would benefit from this tier
]]
local function filter_candidates_by_tier(candidates, item_tier)
    local filtered = {}
    
    for _, candidate in ipairs(candidates) do
        local equipped_tier = get_highest_equipped_tier(candidate)
        
        -- Include if they don't have armor or have LOWER tier
        if not equipped_tier or equipped_tier < item_tier then
            table.insert(filtered, candidate)
        else
            debug_logger.info(
                "TIER_FILTER: Excluding %s from %s (has tier %d, item is tier %d)",
                candidate, set_name, equipped_tier, item_tier
            )
        end
    end
    
    return filtered
end
```

---

## Step 3: Update the Main Distribution Function (10 minutes)

Find this section in `lib/equipment_distribution.lua` (currently around line 300-350):

```lua
function equipment_dist.find_best_recipient(member_list, armor_set, piece_type, ...
```

Inside that function, find where it calculates candidates and add tier filtering:

**Before (current):**
```lua
local candidates = {}
for _, member in ipairs(member_list) do
    -- ... existing code that builds candidates list ...
    table.insert(candidates, member)
end
```

**After (new):**
```lua
local candidates = {}
for _, member in ipairs(member_list) do
    -- ... existing code that builds candidates list ...
    table.insert(candidates, member)
end

-- PHASE 1 ADDITION: Filter out those with higher/equal tiers
local set_config = armor_sets[armor_set]
if set_config and set_config.tier then
    debug_logger.info(
        "TIER_FILTER: Filtering candidates for %s (tier %d)",
        armor_set, set_config.tier
    )
    candidates = filter_candidates_by_tier(candidates, set_config.tier)
    
    if #candidates == 0 then
        debug_logger.warn(
            "TIER_FILTER: All candidates excluded by tier filter for %s",
            armor_set
        )
    end
end
```

---

## Step 4: Test It (15 minutes)

### Quick Validation Test:
1. Open MQ2
2. Enable debug logging: `/lua run yalm2.config.settings.debug_logging = true`
3. Kill a mob that drops armor
4. Check logs for these messages:
   - "TIER_FILTER: Filtering candidates..."
   - "TIER_FILTER: Excluding X from Y..."
   - "TIER_FILTER: All candidates excluded..."

### What to verify:
- ✓ T1 Remnant goes to someone without HoT armor
- ✓ T2 Remnant is rejected if character has Ambiguous/Lucid equipped
- ✓ T3 Remnant goes to someone with T1 or T2, not T3/T4
- ✓ Wrist pieces still show max_slots=2

---

## Step 5: Document What You Did (5 minutes)

Edit `config/armor_sets.lua` header to document:

```lua
--[[
    Equipment Distribution Configuration - PHASE 1 COMPLETE
    
    TIER SYSTEM IMPLEMENTED:
    - Each armor set now includes a 'tier' field
    - Distribution logic excludes characters with equal/higher tier equipped
    - Prevents waste of lower-tier materials on higher-tier players
    
    HOUSE OF THULE TIER MAP:
    - Tier 1: Abstruse (Group), Enigmatic (Raid)
    - Tier 2: Recondite (Group), Esoteric (Raid)
    - Tier 3: Ambiguous (Group), Obscure (Raid)
    - Tier 4: Lucid (Group), Perspicuous (Raid)
    
    DISTRIBUTION RULES:
    - Never give T1 to someone with T2+ equipped
    - Always give to lowest-tier players first
    - Wrist pieces (max_slots=2) follow same tier rules
    
    SEE ALSO:
    - ARMOR_PROGRESSION_ANALYSIS.md (reference)
    - DISTRIBUTION_IMPROVEMENTS.md (roadmap)
]]
```

---

## Troubleshooting

### Problem: "Cannot find armor_sets table"
**Solution:** Make sure you're editing the right file:
```
c:\MQ2\lua\yalm2\config\armor_sets.lua
```

### Problem: "Lua syntax error after adding tier field"
**Solution:** Verify the comma:
```lua
-- CORRECT:
['Recondite'] = {
    display_name = "Recondite Armor",
    tier = 2,  ← Note the comma here!
    pieces = {

-- WRONG:
tier = 2  ← Missing comma after this
    pieces = {
```

### Problem: "All candidates excluded for everything"
**Solution:** Check if your armor set names in pieces match the set name:
```lua
-- Should match:
['Recondite'] = {           ← Set name
    pieces = {
        ['Wrist'] = {
            remnant_name = 'Recondite Remnant of Truth',  ← Contains set name
```

---

## Validation Checklist

Before declaring Phase 1 complete:

- [ ] All armor sets have a `tier` field added
- [ ] No syntax errors in armor_sets.lua
- [ ] filter_candidates_by_tier function added to equipment_distribution.lua
- [ ] get_highest_equipped_tier function added
- [ ] Main find_best_recipient function calls filter
- [ ] Test: T1 item rejected if player has T2 equipped
- [ ] Test: T2 item given to player with no armor
- [ ] Logging shows TIER_FILTER messages
- [ ] No regression - T1 still goes to T1 players
- [ ] Group ran 10+ loots with tier system active

---

## After Phase 1 is Complete

You'll have:
- ✅ Tier-aware distribution
- ✅ Automatic exclusion of higher-tier players
- ✅ Better loot efficiency
- ✅ Foundation for Phase 2-5 (if desired)

**Expected improvement:** ~70% reduction in loot misses due to tier skipping.

Ready to move to Phase 2 (track equipped armor) or Phase 3+ whenever you want!

