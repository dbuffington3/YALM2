# Armor Sets Configuration Build Plan

## What I Can Do (Based on ArmorProgressionSetup.lua)

### TIER 1: REMNANT SETS (8 Tiers × 7 Piece Types = 56 Items)
Pattern: `[Tier] Remnant of [Type]`

**Status: QUERYABLE**
- ✅ Recondite - DONE in armor_sets.lua
- ✅ Lucid - DONE in armor_sets.lua
- ❓ Abstruse - Can query database for IDs
- ❓ Ambiguous - Can query database for IDs
- ❓ Enigmatic - Can query database for IDs
- ❓ Esoteric - Can query database for IDs
- ❓ Obscure - Can query database for IDs
- ❓ Perspicuous - Can query database for IDs

**What I Need:** For each above, confirm the slot mapping (should be same as Recondite/Lucid):
- Knowledge → Hands (slot 12)
- Devotion → Arms (slot 7)
- Truth → Wrist (slots 9, 10)
- Greed → Head (slot 2)
- Desire → Chest (slot 17)
- Fear → Legs (slot 18)
- Survival → Feet (slot 19)

---

### TIER 2: LUMINESSENCE/INCANDESSENCE (14 Base Items + 14 Piece Armor)
Pattern: `[Luminessence/Incandessence] of [Type]` + `[Helm/Armguards/Bracer/Gloves/Boots/Leggings/Tunic] of [Luminessence/Incandessence]`

**Status: QUERYABLE BUT NEED SLOT MAPPING**

Example items in database:
- "Luminessence of Knowledge"
- "Helm of Luminessence"
- "Armguards of Luminessence"
- "Bracer of Luminessence"
- "Gloves of Luminessence"
- "Boots of Luminessence"
- "Leggings of Luminessence"
- "Tunic of Luminessence"
- (Same for Incandessence)

**What I Need:** 
- Which slots does each piece type map to?
  - Helm → slot ?
  - Armguards → slot ?
  - Bracer → slot ? (Is this wrist? If so, 2 slots?)
  - Gloves → slot ?
  - Boots → slot ?
  - Leggings → slot ?
  - Tunic → slot ?

---

### TIER 3: ENCRUSTED CLAY (7 Material Types × 8 Armor Types = 56 Items)
Pattern: `[Material] Encrusted [Piece] Clay`

Materials: Celestrium, Damascite, Iridium, Palladium, Rhodium, Stellite, Vitallium

Example: "Celestrium Encrusted Helm Clay", "Celestrium Encrusted Armguards Clay", etc.

**Status: QUERYABLE BUT NEED SLOT MAPPING**

**What I Need:**
- Same as Luminessence - which slots for Helm, Armguards, Bracer, Gloves, Boots, Leggings, Tunic?

---

### TIER 4: ARMOR PROGRESSION (Multiple Tiers)
These are the actual armor pieces, not crafting materials.

**4A: Rustic, Formal, Embellished, Grandiose (4 tiers × 7 pieces = 28)**
Pattern: `[Tier] of [Location]`
Example: "Rustic of Argath", "Formal of Lunanyn", etc.

**Status: NEEDS INVESTIGATION**
- Do these follow the same 7-piece pattern (Head, Arms, Wrist, Hands, Chest, Legs, Feet)?
- Do they correspond to the crafting materials above?

**What I Need:**
- Confirm the 7 piece types and their slots
- Confirm which crafting material tier corresponds to each armor tier

---

### TIER 5: ADVANCED ARMOR SETS
Including: Modest/Elegant/Stately/Ostentatious of various zones, plus the Amorphous variants, Scale Touched Facets, etc.

**Status: NOT YET ANALYZED**

---

## Database Query Capability

**I CAN DO:**
```sql
SELECT id, name FROM raw_item_data WHERE name LIKE '%Abstruse Remnant%' ORDER BY name
```

**Result:** Get exact IDs for all Abstruse remnants and any other set where I know the exact naming pattern.

---

## What You Need To Provide

For **EACH** armor set/tier you want added, tell me:

```
Armor Set: [Name]
Piece Mappings:
  - Head/Helm → Slot ?
  - Arms/Armguards → Slot ?
  - Wrist/Bracer → Slot ? (Single or dual?)
  - Hands/Gloves → Slot ?
  - Chest/Tunic/Breastplate → Slot ?
  - Legs/Leggings → Slot ?
  - Feet/Boots → Slot ?
Crafting Material Pattern: [Example item names]
```

---

## Build Process

Once you provide the slot mappings, I will:

1. Query the database for ALL items matching each set's naming pattern
2. Extract IDs and map to piece types
3. Build config entries in armor_sets.lua
4. Test item identification for each set

