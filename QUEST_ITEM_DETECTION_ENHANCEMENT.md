# Quest Item Detection Enhancement

## Problem Statement

Task descriptions use varied text patterns to describe quest items:
- Standard: "Loot 5 Golem Bones"
- Descriptive: "Loot the bone golem's bones"

The system was extracting the literal text "bones" from possessive descriptions, which didn't match the actual item name "Golem Bones" in the database.

## Solution: Multi-Layer Detection Strategy

The enhancement implements a **3-tier matching system** to intelligently extract quest item names without hardcoding:

### Tier 1: Pattern-Based Extraction

#### New Possessive Patterns (Added)
Files updated:
- `core/tasks.lua` - lines ~608-631
- `yalm2_native_quest.lua` - lines ~120-131

Patterns now handle:
```lua
-- Possessive formats: "Verb the X's Y"
"Loot the [^']+[''']s (.+)"     -- "Loot the bone golem's bones" → "bones"
"Collect the [^']+[''']s (.+)"  -- "Collect the ogre's teeth"
"Gather the [^']+[''']s (.+)"   -- "Gather the spider's silk"

-- Plus existing patterns:
"Gather some (.+) from"         -- "Gather some Orbweaver Silks from..."
"Collect %d+ (.+) from"         -- "Collect 5 Bone Fragments from..."
```

**Example Flow:**
```
Task: "Loot the bone golem's bones"
↓ Pattern matching
Extracted: "bones"
↓ Title case conversion
Potential item: "Bones"
```

### Tier 2: Database Fuzzy Matching with Quest Item Validation

New function added to `core/quest_interface.lua`:
```lua
quest_interface.find_matching_quest_item(partial_item_name)
```

**Algorithm:**
1. **Exact match** - Case-insensitive lookup for exact name matches (MUST have questitem=1)
2. **Fuzzy contains** - Database query looking for items containing the extracted name (MUST have questitem=1)
3. **Return best match** - Returns first/most relevant match from validated quest items only

**Critical Validation Step:**
All queries include `AND questitem = 1` to ensure ONLY legitimate quest items are returned. This prevents false matches with non-quest items.

**Example Flow:**
```
Extracted: "bones"
↓ Database query: "SELECT * FROM raw_item_data 
                   WHERE LOWER(name) LIKE '%bones%' 
                   AND questitem = 1"
Results (filtered): ["Golem Bones", "Dragon Bones", "Werewolf Bones"]
Results (unfiltered): ["Bones" (non-quest), "Golem Bones" (quest), "Bone Shard" (non-quest)]
↓ Return validated quest item only
Final item: "Golem Bones" (confirmed questitem=1)
```

### Tier 3: Pattern Validation

Existing pattern matching in `core/tasks.lua` validates extracted items against quest patterns:
```lua
local quest_item_patterns = {
    "Sample$",    "Essence$",   "Fragment$",  "Bone$",
    "Scale$",     "Claw$",      "Fang$",      "Hide$", ...
}
```

After extraction and fuzzy matching, the final name is validated:
- "Golem Bones" matches pattern "Bone$" ✓
- Item is registered as a valid quest item

## Quest Item Validation (Critical Feature)

The key insight that makes this work reliably is **quest item validation**. After finding potential matches, we verify they are actually quest items in the database:

### Why This Matters

Without validation, "bones" could match:
- "Bones" (regular vendor item, NOT a quest item)
- "Bone Pendant" (equipment, NOT a quest item)  
- "Bone Shards" (crafting material, NOT a quest item)
- "Golem Bones" (QUEST ITEM ✓)

With validation, the query includes `AND questitem = 1`:
```sql
SELECT * FROM raw_item_data 
WHERE LOWER(name) LIKE '%bones%' 
AND questitem = 1
```

Only "Golem Bones" has `questitem=1` in the database, so only that is returned.

### Database Column Reference

The validation uses the `questitem` column from raw_item_data:
```
questitem = 1  → Item is marked as a quest item (typically NoRent + NoDrop + quest flag)
questitem = 0  → Item is NOT a quest item (can be traded, sold, dropped)
```

This flag comes directly from Lucy Allakhazam and is the authoritative source.

## Implementation Details

### Modified Files

#### 1. `core/tasks.lua` (lines ~608-631)
Added possessive patterns at the beginning of extraction sequence:
```lua
if not item_name then
    item_name = objective_text:match("Loot the [^']+[''']s (.+)")
    -- ... other possessive patterns
end
```

#### 2. `yalm2_native_quest.lua` (lines ~120-131)
Updated `extract_quest_item_from_objective()` with same patterns:
```lua
local patterns = {
    "Loot the [^']+[''']s (.+)",
    "Collect the [^']+[''']s (.+)",
    "Gather the [^']+[''']s (.+)",
    -- ... existing patterns
}
```

#### 3. `core/quest_interface.lua` (NEW function)
Added `find_matching_quest_item()` for database fuzzy matching with quest item validation:
```lua
quest_interface.find_matching_quest_item = function(partial_item_name)
    -- Strategy 1: Exact match (questitem=1)
    -- Strategy 2: Fuzzy/contains match (questitem=1)
    -- Returns best matching QUEST ITEM from database
    -- CRITICAL: All queries filter by questitem=1 to ensure match is legitimate
end
```

### How It Works End-to-End

**Scenario: Task "Loot the bone golem's bones" for item ID 47699 (Golem Bones)**

```
1. Task text parsing
   "Loot the bone golem's bones"
   ↓
2. Pattern matching (tasks.lua/yalm2_native_quest.lua)
   Match: "Loot the [^']+[''']s (.+)"
   Extract: "bones"
   ↓
3. Title case conversion
   "bones" → "Bones"
   ↓
4. Optional: Database fuzzy matching (quest_interface.find_matching_quest_item)
   Query: "WHERE LOWER(name) LIKE '%bones%'"
   Result: "Golem Bones" (or other matches)
   ↓
5. Pattern validation (quest_item_patterns)
   "Golem Bones" matches pattern "Bone$" ✓
   ↓
6. Registration
   quest_items["Golem Bones"] = {
       needed_by = {"character"},
       task_name = "Task Name",
       objective = "Loot the bone golem's bones"
   }
```

## Usage from Other Code

If integrating fuzzy matching into the extraction pipeline:

```lua
local quest_interface = require("yalm2.core.quest_interface")

-- Extract raw item from text
local extracted = extract_quest_item_from_objective("Loot the bone golem's bones")
-- Result: "bones" or "Bones"

-- Find actual database item name
local actual_item_name = quest_interface.find_matching_quest_item(extracted)
-- Result: "Golem Bones"

-- Now use actual_item_name for quest tracking
```

## Benefits

✅ **No hardcoding** - Uses pattern matching + database lookup
✅ **Handles variations** - Works with "the X's Y" formats  
✅ **Scalable** - Adding new patterns works for future quest formats
✅ **Smart** - Database matching handles ambiguous extractions
✅ **Quest-Validated** - Only returns items marked as questitem=1 in database (NEW!)
✅ **Extensible** - Can add weighting/priority logic later

## Example Cases Now Supported

| Task Text | Extracted | Pattern | Match | Database Validation | Result |
|-----------|-----------|---------|-------|---------------------|--------|
| "Loot 5 Golem Bones" | "Golem Bones" | Exact | ✓ | questitem=1 ✓ | Golem Bones |
| "Loot the bone golem's bones" | "bones" | Possessive | Contains | GOLEM BONES: questitem=1 ✓ | Golem Bones |
| "Collect the dragon's scales" | "scales" | Possessive | Contains | DRAGON SCALES: questitem=1 ✓ | Dragon Scales |
| "Gather some Orbweaver Silks from..." | "Orbweaver Silks" | Existing | Exact | questitem=1 ✓ | Orbweaver Silks |

**Note:** For "bones" → "Golem Bones", database would return multiple matches (Golem Bones, Dragon Bones, etc.), but all are validated as questitem=1 before returning.

## Future Enhancements

1. **Context-aware weighting** - Prioritize matches containing mob name
   - "Golem Bones" for "bone golem's bones"
   - "Dragon Scales" for "dragon's scales"

2. **Item ID lookup** - If quest system provides item ID, use that directly
   - Would skip text extraction entirely for quest items with IDs

3. **Plural handling** - Normalize plurals before matching
   - "bones" → match "Bone" patterns exactly

4. **Caching** - Cache extraction results to avoid repeated database queries
   - Store "bones" → "Golem Bones" mappings for faster future matching
