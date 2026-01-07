# Armor Tier Filtering System

## Overview
The armor tier filtering system allows you to automatically ignore low-tier armor **and weapons** on a **per-character basis**. This prevents your high-level characters from picking up or receiving low-tier equipment like Crude Defiant while still allowing your low-level alts to collect it.

## How It Works

### Automatic Tier Detection
The system automatically identifies armor and weapons by name and assigns a tier number:

**Defiant Equipment Tiers** (1-8):
- Tier 1: **Crude Defiant** (armor + weapons)
- Tier 2: **Rough Defiant** (armor + weapons)
- Tier 3: **Simple Defiant** (armor + weapons)
- Tier 4: **Flawed Defiant** (armor + weapons)
- Tier 5: **Elaborate Defiant** (armor + weapons)
- Tier 6: **Intricate Defiant** (armor + weapons)
- Tier 7: **Ornate Defiant** (armor + weapons)
- Tier 8: **Elegant Defiant** (armor + weapons)

**Defiant Weapons Include:**
- Primary: Axe, Sword, Mace, Club, Dagger, Spear, Staff, Fists, Greatspear, Greatsword, Shortsword, Quarterstaff
- Secondary: Shield, Buckler, Spiked Shield
- Ranged: Bow, Pebbles, Fragments, Shards

**Progression Armor Tiers**:
- Tiers 10-13: **House of Thule** (Abstruse → Recondite → Ambiguous → Lucid)
- Tiers 14-17: **Veil of Alaris** (Rustic → Formal → Embellished → Grandiose)
- Tiers 18-21: **Fear Progression** (Fear Touched → Boreal → Distorted → Twilight → Frightweave)

### Tier Comparison Logic
When equipment is found on a corpse:
1. System identifies the equipment tier (e.g., "Crude Defiant Axe" = tier 1)
2. Checks your character's `min_armor_tier` setting
3. If `item_tier < min_armor_tier`, the equipment is **left on corpse**
4. If `item_tier >= min_armor_tier`, normal distribution logic applies

This works for **both Master Looter and Solo Looting** modes.

## Commands

### Set Minimum Tier
```
/yalm2 mintier <tier_number>
```

**Examples:**
```
/yalm2 mintier 5       # Ignore Crude/Rough/Simple/Flawed Defiant, keep Elaborate+ Defiant
/yalm2 mintier 9       # Ignore ALL Defiant (tiers 1-8), keep progression armor (10+)
/yalm2 mintier 15      # Ignore Defiant + HoT + Rustic/Formal VoA, keep Embellished+ VoA
/yalm2 mintier 0       # Disable tier filtering (accept all armor)
```

### Check Current Setting
```
/yalm2 mintier
```

This displays:
- Your current minimum tier setting
- Which Defiant tiers will be ignored/kept
- Usage examples and tier reference

## Use Cases

### Scenario 1: Level 85 Character with Boreal Armor
You have **Boreal armor (tier 19)** equipped and are farming in zones that drop Defiant gear.

**Problem:** You keep picking up Crude/Rough/Simple Defiant armor and weapons that you don't need.

**Solution:**
```
/yalm2 mintier 9
```

**Result:** All Defiant equipment (tiers 1-8) is automatically ignored. You'll only pick up tier 9+ armor (HoT, VoA, Fear progression).

### Scenario 2: Level 50 Character Upgrading Defiant
You're wearing **Flawed Defiant (tier 4)** and want to upgrade to better Defiant only.

**Problem:** You keep getting offered Crude/Rough/Simple Defiant armor and weapons that you've already outgrown.

**Solution:**
```
/yalm2 mintier 5
```

**Result:** You'll only pick up **Elaborate (5), Intricate (6), Ornate (7), and Elegant (8)** Defiant equipment. Lower tiers are ignored.

### Scenario 3: New Alt Character
You just created a new character and want to collect any Defiant you can find.

**Problem:** Your other characters have tier filters set, but this alt needs everything.

**Solution:**
```
/yalm2 mintier 0
```
(or just don't set it - 0 is the default)

**Result:** Character accepts all armor tiers.

### Scenario 4: Raid Group with Mixed Gear Levels
Your raid has characters in various gear levels from Lucid (tier 13) to Distorted (tier 20).

**Problem:** Master Looter keeps trying to distribute Defiant/HoT gear to high-tier players.

**Solution:** Each character sets their own minimum tier:
```
# High-tier characters (Distorted+):
/yalm2 mintier 18

# Mid-tier characters (VoA):
/yalm2 mintier 14

# Lower-tier characters (HoT/Defiant):
/yalm2 mintier 5 (or leave unset)
```

**Result:** Master Looter automatically skips characters who have tier filters set above the item's tier. Only eligible characters receive distribution offers.

## Technical Details

### Settings Location
The `min_armor_tier` setting is stored in your **character-specific** config file:
```
C:\MQ2\config\YALM2\yalm2-<server>-<character>.lua
```

Under the `loot.settings` section:
```lua
["loot"] = {
    ["settings"] = {
        ["min_armor_tier"] = 5,  -- Minimum tier (or nil if disabled)
    }
}
```

### Integration Points

**Master Looter Distribution:**
- `equipment_dist.find_best_recipient()` checks each candidate's `min_armor_tier`
- Candidates with `min_armor_tier > item_tier` are automatically skipped
- Prevents distribution to characters who don't want that tier

**Solo Looting:**
- Armor gate in `looting.lua` checks `char_loot.settings.min_armor_tier`
- Items below minimum tier are left on corpse before satisfaction score calculation
- No inventory/preference checks are wasted on filtered items

### Logging
When an item is filtered by tier:
```
[YALM2] Armor tier filter: Crude Defiant Plate Helm (tier 1) is below minimum tier 5 - leaving on corpse
```

Debug log shows:
```
[INFO] ARMOR_GATE: Crude Defiant Plate Helm tier 1 is below minimum tier 5 - LEAVING ON CORPSE
```

## FAQ

**Q: Does this affect non-armor items?**
A: No. Only items identified as armor set pieces (with a tier) are affected. Weapons, jewelry, quest items, tradeskills, etc. are unaffected.

**Q: Can I set different tiers for different armor pieces?**
A: No. The `min_armor_tier` applies to all armor pieces uniformly. If you need piece-specific control, use item preferences (`/yalm2 setitem ignore <item_name>`).

**Q: What if I have a global item preference set?**
A: Tier filtering happens at the **armor gate** level, before preference checks. If an item is filtered by tier, it won't reach the preference check. If you explicitly set a preference for a specific Defiant item, you'll need to either raise your tier filter or remove the preference.

**Q: Does this work with DanNet for distributing to other characters?**
A: Yes. When Master Looter distributes armor, it queries each character's `min_armor_tier` setting via DanNet and respects their individual tier requirements.

**Q: Can I see what tier I currently have equipped?**
A: Run `/yalm2 cu` (equipment upgrade checker) to see your current gear and tier levels. The debug log also shows equipped tiers during distribution.

**Q: What happens if I don't set a minimum tier?**
A: The filter is disabled (equivalent to `min_armor_tier = 0`). All armor tiers are accepted, and the system falls back to satisfaction score / progression tier checks only.

## Best Practices

1. **Set it and forget it**: Once you've outgrown a tier level, set your minimum and don't worry about adjusting it constantly.

2. **Be conservative**: Set your minimum tier to the *lowest* tier you'd still consider upgrading to, not your current tier. For example, if you have tier 15 gear but would take tier 14 for an empty slot, set `mintier 14`.

3. **Use with progression tracking**: Combine tier filtering with the equipment distribution system's satisfaction scoring. The tier filter handles "too low" items, while satisfaction scoring handles "same tier, better piece" decisions.

4. **Coordinate in groups**: In raid/group scenarios, have each player set their own tier requirement so the ML doesn't waste time offering low-tier items to high-tier players.

5. **Update as you progress**: When you fully upgrade to a new tier (all 7 pieces), bump your minimum tier to prevent collecting old gear.

## Related Systems

- **Equipment Distribution** (`equipment_distribution.lua`): Handles armor piece satisfaction scoring and progression tracking
- **Armor Progression** (`armor_sets.lua`): Defines all armor sets and their tier assignments
- **Single Item Collection** (`/yalm2 singleitem`): Per-character toggle for non-stackable tradeskill items (separate from armor filtering)
- **Item Preferences** (`/yalm2 setitem`): Manual override for specific items (bypasses tier filtering if set to "Keep")
