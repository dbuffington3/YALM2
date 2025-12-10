# Quest Item Distribution Implementation

## Status: IN PROGRESS

### What's Complete ✅

1. **Quest Detection**
   - Database lookup identifies `questitem=1` flag in MQ2LinkDB
   - Quest interface API returns characters needing each item
   - Per-character quantities parsed from quest data

2. **Quest Data Structure** 
   - `_G.YALM2_QUEST_ITEMS_WITH_QTY` format: `"Item:char1:qty1,char2:qty2|Item2:..."`
   - Example: `"Orbweaver Silks:Forestess:2,Lumarra:2,Vexxuss:0,Tarnook:2,Vaeloraa:2,Lyricen:2|"`
   - Automatically updated after quest refreshes

3. **Quest Distribution Logic** ✅
   - New function: `looting.get_quest_item_recipient(item_name, needed_by, item_quantities)`
   - Selects who should receive the item:
     * Person needing MOST items gets priority (fairness)
     * If tied, non-Master Looters get priority over ML
     * Returns nil if no one needs item (leave on corpse)
   - Pure quest logic, NO preference/keep/ignore rules

### What's Next 🔄

**IMMEDIATE: Integrate Quest Distribution into Loot Flow**

Currently the flow is:
```
Item drops
  ↓
check_can_loot() called for EACH character
  ↓
evaluate.get_loot_preference() looks for preferences
  ↓
No preferences found → Everyone fails → Item left on corpse ❌
```

Should be:
```
Item drops
  ↓
Detect: questitem=1 in database? ✅
  ↓
Get needed_by list from quest interface
  ↓
Call get_quest_item_recipient(item, needed_by, quantities)
  ↓
Get single winner
  ↓
Give item to winner → Done! ✅
  ↓
(If not a quest item, use normal preference rules)
```

### Implementation Steps

1. **Modify check_can_loot() function** (core/looting.lua)
   - Early quest detection (before preference checks)
   - If item is questitem=1:
     * Extract needed_by from quest interface
     * Extract quantities from _G.YALM2_QUEST_ITEMS_WITH_QTY
     * Call get_quest_item_recipient()
     * Return winner (or nil if no one needs it)
   - If not a quest item, continue with normal preference logic

2. **Parse item quantities properly**
   - Extract from _G.YALM2_QUEST_ITEMS_WITH_QTY
   - Build qty map: { "Forestess" = 2, "Lumarra" = 2, "Vexxuss" = 0, ... }
   - Pass to get_quest_item_recipient()

3. **Test with simulator**
   - Simulate quest item (Orbweaver Silk)
   - Verify correct character selected
   - Verify quantity logic (person with 0 gets priority over person with 2)

### Key Files

- **looting.lua** - get_quest_item_recipient() [CREATED ✅]
- **looting.lua** - check_can_loot() [NEEDS MODIFICATION 🔄]
- **quest_interface.lua** - get_characters_needing_item() [EXISTS ✅]
- **yalm2_native_quest.lua** - Builds YALM2_QUEST_ITEMS_WITH_QTY [EXISTS ✅]

### Example: Orbweaver Silk Distribution

```
Item drops: Orbweaver Silk (questitem=1)

1. Query database → questitem=1 ✅ (is a quest item)
2. Get needed_by = ["Forestess", "Lumarra", "Tarnook", "Vaeloraa", "Lyricen", "Vexxuss"]
3. Parse quantities:
   - Forestess: 2
   - Lumarra: 2
   - Tarnook: 2
   - Vaeloraa: 2
   - Lyricen: 2
   - Vexxuss: 0 ← Needs MOST (already done, needs 0 more)
4. Call get_quest_item_recipient()
5. Returns: Vexxuss (doesn't need it anymore)... wait that's wrong
```

WAIT - The logic needs refinement:
- If Vexxuss is DONE (needs 0), we should give it to someone else
- Priority should be: Person needing LEAST items (gives them an item sooner)
- OR: Person needing MOST items gets priority first distribution round

Let me clarify the distribution philosophy with the user...

### Distribution Philosophy (NEEDS CLARIFICATION)

When multiple people need an item, who gets it?

**Option A: Person needing most gets priority**
- "Give Forestess all the Silks first since she needs 2"
- Downside: Others wait longer
- Upside: Fast completion for high-needs character

**Option B: Person needing least gets priority** 
- "Give Lyricen her 1 Silk ASAP since she'll be done sooner"
- Downside: High-needs character waits
- Upside: Fairness - everyone finishes at similar time

**Current Implementation:** A (highest quantity first)
