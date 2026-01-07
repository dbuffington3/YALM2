# Strategic Roadmap: What's Next for YALM2 Armor Distribution

**Status as of December 30, 2025**
**Current Focus:** Armor tier distribution improvements

---

## Current State Assessment

### What We've Accomplished This Session
✅ Fetched and analyzed all **17 expansion armor guides** (complete data collection)
✅ Created **COMPLETE_EXPANSION_ARMOR_HIERARCHY.md** (authoritative reference)
✅ Identified **progression patterns** across all expansions
✅ Mapped **progression_level values (1-53)** for tier comparison
✅ Documented **380+ armor sets** currently in system

### What's Already Implemented
- Core armor_sets.lua with ~380 armor definitions
- Basic ARMOR_PROGRESSION table (Fear Touched → Boreal → Distorted → Twilight → Frightweave)
- equipment_distribution.lua with basic tier checking
- Multiple PHASE_1 implementation guides
- Quest system and task collection (separate feature, complete)
- Character-specific refresh logic

---

## Decision Point: Two Paths Forward

### Path A: Phase 1 (Quick Win - 2-4 hours)

**Goal:** Extend current tier system to cover MORE expansions quickly

**Steps:**
1. Add `tier` field to all 380+ armor sets in armor_sets.lua
   - Use progression_level values (1-53) from COMPLETE_EXPANSION_ARMOR_HIERARCHY
   - Can bulk-add using simple pattern matching
2. Extend ARMOR_PROGRESSION to cover:
   - House of Thule (Abstruse→Recondite→Ambiguous→Lucid)
   - Veil of Alaris (Rustic→Formal→Embellished→Grandiose)
   - Rain of Fear (Boreal→Distorted→Twilight→Frightweave) - already partially done
3. Update equipment_distribution.lua's find_best_recipient() to:
   - Compare player's current armor tier vs loot tier
   - Skip candidates with equal/higher tier already equipped
   - Prefer tier upgrades over same-tier alternatives

**Pros:** Quick implementation, immediate improvement, uses existing structure
**Cons:** Doesn't handle container/component logic, tradeskill tiers, expansion variants

**Scope:** ~2-4 hours
**ROI:** Moderate (covers maybe 60% of players' needs)

---

### Path B: Full Implementation (Complete - 8-16 hours)

**Goal:** Complete overhaul to handle ALL 17 expansions with full context

**Steps:**
1. **Redesign armor_sets.lua structure** to add:
   ```lua
   ['Recondite'] = {
       display_name = "Recondite Armor",
       expansion = "HouseOfThule",
       tier = 5,  -- progression_level from master chart
       tier_name = "T2",  -- local expansion tier
       tier_type = "group",  -- "group", "raid", "tradeskill"
       container_type = "ShroudOfDreams",
       requires_agent = true,
       requires_previous_tier = true,
       class_pair = "Purification",  -- for agents
       tradeskill_version = false,
       pieces = { ... }
   }
   ```

2. **Create smart comparison function** that handles:
   - Expansion tier jumps (T1 RoF vs T1 HoT - which is better?)
   - Tradeskill tier premiums (+15-20% stat boost)
   - Container/component requirements
   - Class-specific distribution (some classes get better TS variants)

3. **Map all 380+ armor sets** with complete metadata:
   - Every armor set gets expansion, tier, tier_name, tier_type fields
   - Database query to match item names to sets and tiers
   - Validation logic to ensure tier consistency

4. **Implement "best upgrade finder"** that considers:
   - Current armor tier vs available loot
   - Tradeskill tiers (prioritize for crafters)
   - Expansion progression (never go backwards)
   - Character class compatibility
   - Group needs vs individual upgrades

**Pros:** Future-proof, handles all edge cases, creates foundation for other improvements
**Cons:** Much larger effort, more complex logic, more testing needed

**Scope:** 8-16 hours
**ROI:** Very high (covers 100% of distribution cases, creates framework for future improvements)

---

## Recommendation Analysis

### Choose Path A IF:
- You want **immediate results** in the next 1-2 sessions
- You're OK with covering the **most common cases** (HoT, VOA, ROF, TBL mainly)
- You want to **validate** the tier system works before full redesign
- You prefer **incremental improvement** over big rewrites

### Choose Path B IF:
- You want a **complete, robust system** that handles edge cases
- You're willing to invest time for a **future-proof foundation**
- You want to eventually support **intelligent tradeskill distribution**
- You want to **document the entire armor ecosystem** for future reference

---

## Hybrid Approach (My Recommendation)

**Do Phase 1 first, then expand to Phase 2:**

### Immediate (1-2 hours):
1. Add `tier` field to all armor_sets using progression_level (1-53)
2. Update ARMOR_PROGRESSION table with HoT, VOA, ROF progressions
3. Test on one character to validate tier comparison works

### Follow-up (2-4 hours):
4. Add `expansion` field to armor_sets
5. Create smart comparison function that handles:
   - Same expansion tier jumps
   - Cross-expansion comparisons
   - Tradeskill premiums
6. Test on multiple characters with different armor combinations

### Future (4-8 hours):
7. Full metadata redesign with all fields from Path B
8. Database integration for armor set lookups
9. Comprehensive testing

**Advantage:** Quick wins validate the approach, then full implementation follows naturally

---

## Immediate Next Actions (Pick One)

### Option 1: Start Phase 1 Now
**Command:** Show me which armor sets are missing `tier` field and let's bulk-add them

### Option 2: Design Phase 1 Details First
**Command:** Create detailed specification of what ARMOR_PROGRESSION table should look like with HoT, VOA, ROF expansions

### Option 3: Design Full Path B Architecture
**Command:** Create complete spec for new armor_sets.lua structure with all metadata fields

### Option 4: Validate Current Data
**Command:** Let me query armor_sets.lua to count how many sets have tier info vs need it

---

## My Advice

Given that you just collected 17 comprehensive expansion armor guides and created authoritative documentation, **I'd recommend starting with Phase 1 immediately**:

1. **It's quick** (1-2 hours to add tier field + validation)
2. **It validates** the progression_level system works in practice
3. **It gives you wins** - players will immediately see better distribution
4. **It's non-breaking** - adding fields doesn't break existing logic
5. **It's a natural foundation** for Phase 2 expansion

**What do you want to tackle:**
- [ ] Phase 1 Quick Win
- [ ] Phase 1 Full Design Spec
- [ ] Phase 2 Architecture Design
- [ ] Something else entirely

Let me know and I'll jump right in! 🚀
