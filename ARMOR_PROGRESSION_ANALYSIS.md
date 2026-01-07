# Armor Progression Analysis for Intelligent Distribution

## Overview
This document maps out armor progression chains across multiple EverQuest expansions to enable smarter loot distribution decisions. When you know what materials combine into which pieces, you can distribute crafting materials to people who will actually benefit from them.

---

## HOUSE OF THULE (T2 Expansion)

### Armor Tier Structure
**4 Tiers of Craftable Armor** (both Group and Raid)

| Tier | Group Name | Raid Name | Status | HP/Mana Range | Notes |
|------|-----------|-----------|--------|--------------|-------|
| 1 | Abstruse | Enigmatic | Standalone | 940-995 | T2 group content |
| 2 | Recondite | Esoteric | T1→T2 | 1120-1200 | Can upgrade from T1 |
| 3 | Ambiguous | Obscure | T2→T3 | 1250-1375 | Mid-tier progression |
| 4 | Lucid | Perspicuous | T3→T4 | 1400-1575 | End-game for expansion |

### Crafting Requirements
**Container:** Shroud of Dreams (purchased)
**Components (per piece):**
- **Remnant** (dropped by mobs, 7 types per tier): Truth, Desire, Devotion, Fear, Knowledge, Greed, Survival
- **Coalescing Agent** (class-specific, purchased by class pairs)
- **Template** (T2-T4 only, purchased by tier)

### Progression Recipes
```
T1: Remnant + Coalescing Agent + Vanadium/Immaculate Template
T2: T1 piece OR Remnant + T1 Remnant + Coalescing Agent + Inchoate Template
T3: T2 piece OR Remnant + T2 Remnant + Coalescing Agent + Nebulous Template
T4: T3 piece OR Remnant + T3 Remnant + Coalescing Agent + Amorphous Template
```

### Distribution Strategy
1. **Priority mapping by current gear tier:**
   - If player has NO HoT armor → Give T1 Remnants
   - If player has T1 → Give T2 Remnants
   - If player has T2 → Give T3 Remnants
   - If player has T3 → Give T4 Remnants

2. **Slot precedence:** Chest, Legs, Head, Arms, Hands, Feet, Wrist (last)

3. **Key insight:** A character with a T2 Chest doesn't need another T2 Chest. Give them T3 Remnants for the same slot to upgrade.

---

## SEEDS OF DESTRUCTION (T3+ Expansion)

### Complex Multi-Path Armor System

#### GROUP ARMOR TIERS
| Tier | Zones | T1 Name | T3 Name | T4 Names | T5 Names |
|------|-------|---------|---------|----------|----------|
| 1 | Oceangreen | Archaic* | - | - | - |
| 2 | Bloody Kithicor | - | - | - | - |
| 3 | Field of Scale | - | Concordant/Discordant | - | - |
| 4 | Earth | - | Balanced/Chaotic/Vested | Balanced/Chaotic/Vested | - |
| 5 | Kuua/Discord | - | - | Inflicted/Ordained/Tainted/Tarnished | - |

*Standalone armor, cannot be upgraded

#### T3→T4 PROGRESSION
**Two essence types, multiple craft paths:**
```
Concordant T3 + Medial Luminessence → Vested T4
Concordant T3 + Medial Incandessence → Balanced T4
Discordant T3 + Medial Luminessence → Balanced T4
Discordant T3 + Medial Incandessence → Chaotic T4
(OR craft fresh from Primeval Essences without T3 piece)
```

#### T4→T5 PROGRESSION
**6 different paths based on T4 type:**
```
Chaotic + Eternal Incandessence → Inflicted
Vested + Eternal Luminessence → Ordained
Balanced + Eternal Incandessence → Tainted
Chaotic + Eternal Luminessence → Tainted
Vested + Eternal Incandessence → Tarnished
Balanced + Eternal Luminessence → Tarnished
```

### Key SOD Naming Conventions
**Essence Types:**
- **Slot indicator (first word):**
  - Distorted = Arms/Legs
  - Fractured = Wrist/Hands
  - Phased = Chest
  - Warped = Head/Feet

- **Theme/Zone (second word):**
  - Eternal = Kuua/Discord (T5 group)
  - Medial = Earth (T4 group)
  - Primeval = Earth/Korafax (T4 raid)
  - Coeval = Tower of Discord (T5 raid)
  - Seminal = Field of Scale (T3 group)

- **Type (third word):**
  - Luminessence / Incandessence (affects final stats)

### Distribution Strategy for SOD
1. **Never give essences without knowing what the player has equipped**
   - A player with Concordant T3 needs Medial essences, not Seminal
   - Someone at T4 Chaotic needs Eternal Incandessence for Inflicted path

2. **Track equipped armor types:**
   - Current tier level
   - Current type (Concordant/Discordant for T3; Vested/Chaotic/Balanced for T4)
   - Current essence type in wrist pieces (affects which essence they need)

3. **Essence conversion strategy:**
   - Luminessence vs Incandessence are swappable (with Temporal Polymorphic Cell)
   - Can downgrade essences from higher tiers to lower tiers (with Chronobines)
   - This means Coeval essences have higher value (can downgrade)

4. **Avoid waste:**
   - Don't give Primeval to someone with Group armor
   - Don't give Medial to someone already at T5
   - Coeval essences can always be saved for final upgrades

---

## LUMINESSENCE ARMOR (Later Expansions)

### Current armor_sets.lua contains 20+ Luminessence variants
Structure appears to be:
```
[Variant Type] Luminessence / Incandessence
- Slots: Arms, Legs (for Distorted/most types)
- Multiple tiers exist: Coeval, Eternal, Medial, Primeval, Seminal
```

**Question for validation:** Are these using the SOD essence system still?

---

## DISTRIBUTION LOGIC IMPROVEMENTS

### Phase 1: Tier Awareness
**Current gap:** Looting code doesn't know that giving a "Remnant" to someone who already has that tier of armor is wasteful.

**Solution:** Add `tier` field to armor_sets configuration:
```lua
remnant_tier = 2,  -- This item builds toward Tier 2 armor
```

Then filter distribution to exclude characters who already have that tier or better.

### Phase 2: Essence Type Tracking
**Current gap:** SOD essences are fungible but require knowing what the person currently has equipped.

**Solution:** When distributing an Essence:
1. Check what tier the character has equipped
2. Match essence theme to character's current armor tier
3. Prioritize characters below the essence's tier

### Phase 3: Crafting Path Optimization
**Current gap:** There are multiple valid paths to craft armor (e.g., Balanced can come from Concordant+Medial Lum OR Discordant+Medial Inc)

**Solution:** Implement a "preferred path" field that marks which combinations to encourage:
```lua
preferred_upgrades = {
    ['Concordant'] = 'Luminessence',  -- Encourage Concordant→Vested
    ['Discordant'] = 'Incandessence', -- Encourage Discordant→Chaotic
}
```

---

## CRITICAL DISTRIBUTION RULES

### Rule 1: Never Skip Tiers
✗ Don't give T4 Remnants to someone with no HoT armor
✓ Do give T1 Remnants to build the foundation

### Rule 2: Match Essence to Current Content
✗ Don't give Medial (T4) essences to someone at T3
✓ Do give Seminal (T3) essences to complete T3 before jumping to T4

### Rule 3: Account for Type Chains
✗ Don't give Ethereal Luminessence to someone with a Chaotic piece equipped
   (They need Incandessence to maintain their path to higher Chaotic)
✓ Do check what "type" they're building toward

### Rule 4: High-Tier Essences Have Higher Value
Coeval > Primeval > Eternal > Medial > Seminal

**Reasoning:** Higher-tier essences can be downgraded to lower tiers with currency, but not vice versa.

---

## DATA VALIDATION CHECKLIST

Check your armor_sets.lua against these facts:

### House of Thule
- [ ] All 7 remnant types exist for each tier (Abstruse, Recondite, Ambiguous, Lucid)
- [ ] Each tier has 7 pieces (Wrist, Chest, Arms, Legs, Head, Hands, Feet)
- [ ] Wrist slot has max_slots = 2 (all others = 1)
- [ ] Remnant IDs are sequential or logical within each tier

### Seeds of Destruction Essences
- [ ] Essence names decode correctly (e.g., "Distorted Medial Luminessence")
- [ ] T3/T4/T5 distinctions are clear
- [ ] Group vs Raid essences are separated
- [ ] Wrist pieces have max_slots = 2

### Luminessence Variants
- [ ] Verify each variant is a real in-game essence
- [ ] Check if they still use the SOD combine system or are standalone
- [ ] Confirm which expansions introduced which variants

---

## NEXT STEPS

1. **Add tier metadata** to armor_sets.lua configuration
2. **Implement tier-aware filtering** in looting distribution logic
3. **Track player armor types** in character state (not just names)
4. **Add essence path awareness** for SOD and later armor
5. **Create preference configuration** for upgrade paths (Luminessence vs Incandessence focus)

---

## Notes for Future Research

- Verify all 380 armor sets in current config against expansion sources
- Check if Luminessence variants are pre-SOD or post-SOD
- Look into whether "Fear Touched → Boreal → Distorted → Twilight → Frightweave" is HoT or earlier
- Determine what expansions introduced which remnant types
- Map out which expansions have quest armor vs dropped armor

