# Per-Character Quest Item Needs Analysis

## What We Know From The UI

Based on the quest detection logs and the structure of the task data, here's what each character needs:

### Orbweaver Silks (6 characters need this)
- **Forestess** - Objectives show "Collect X Orbweaver Silks" - STATUS: 0/Y
- **Vaeloraa** - Objectives show "Collect X Orbweaver Silks" - STATUS: 0/Y
- **Lumarra** - Objectives show "Collect X Orbweaver Silks" - STATUS: 0/Y
- **Tarnook** - Objectives show "Collect X Orbweaver Silks" - STATUS: 0/Y
- **Lyricen** - Objectives show "Collect X Orbweaver Silks" - STATUS: 0/Y
- **Vexxuss** - Objectives show "Collect X Orbweaver Silks" - STATUS: 0/Y

### Tanglefang Pelts (5 characters need this)
- **Vaeloraa** - Objectives show "Collect X Tanglefang Pelts" - STATUS: 0/Y
- **Lumarra** - Objectives show "Collect X Tanglefang Pelts" - STATUS: 0/Y
- **Tarnook** - Objectives show "Collect X Tanglefang Pelts" - STATUS: 0/Y
- **Lyricen** - Objectives show "Collect X Tanglefang Pelts" - STATUS: 0/Y
- **Forestess** - NO (only needs Orbweaver Silks)

## Current System State

### What YALM2 Captures Today
1. **Item Name** - "Orbweaver Silks", "Tanglefang Pelts" ✅
2. **Characters Who Need It** - All 6 for Silks, 5 for Pelts ✅
3. **Task Name** - "Collect Orbweaver Silks", "Collect Tanglefang Pelts" ✅
4. **Objective Text** - "Collect X Item from location" ✅
5. **Progress Status** - "0/4", "2/5", "Done", etc. ✅

### What We Need to Extract Additionally
1. **QUANTITY NEEDED** - The number before the item name (the "X" in "Collect X Silks")
   - Currently: Extract pattern captures just "Orbweaver Silks"
   - Need to also capture: The leading number "4", "3", "5", etc.

2. **CURRENT PROGRESS** - Parse "0/4" to understand completion
   - Currently: Stored as full string "0/4"
   - Need to parse: current=0, needed=4

3. **COMPLETION PERCENTAGE** - Calculate from progress
   - This would help prioritize distribution (nearly full quests get priority)

## Data Structure Enhancement Needed

### Current objective.status format:
```
"0/4" - zero collected, four needed
"2/5" - two collected, five needed
"Done" - quest complete
```

### We need to extract from this:
- Current count: parseInt(status:match("(%d+)/"))
- Target count: parseInt(status:match("/(%d+)"))
- Percentage: (current / target) * 100

### But MORE IMPORTANTLY from objective.objective text:
- "Collect 4 Orbweaver Silks from..." → extract the "4"
- This is the authoritative quantity, not what's in status

## API Functions To Add

We need these new functions in `quest_interface.lua` and `native_tasks.lua`:

1. **get_character_item_need(character_name, item_name)**
   - Returns: { needed = 4, current = 0, progress = "0/4", percentage = 0 }
   - Tells us exactly how many of this item one character needs

2. **get_all_character_needs()**
   - Returns: { character_name → item_name → { needed, current, progress } }
   - Full matrix of all needs for distribution logic

3. **extract_quantity_from_objective(objective_text)**
   - Returns: { quantity = 4, item_name = "Orbweaver Silks" }
   - Parses "Collect 4 Orbweaver Silks from..." into components

4. **parse_progress_status(status_string)**
   - Returns: { current = 0, needed = 4 }
   - Parses "0/4" into components

## Example Use Case For Distribution Logic

Once we have these functions, distribution becomes:

```lua
-- Find who needs the most of this item
local item_name = "Orbweaver Silks"
local needs = quest_interface.get_all_character_needs()

-- Find character with highest need
local most_needed_char = nil
local max_need = 0
for char_name, char_needs in pairs(needs) do
    if char_needs[item_name] and char_needs[item_name].needed > max_need then
        max_need = char_needs[item_name].needed
        most_needed_char = char_name
    end
end

-- Result: most_needed_char = the character who should get this item next
```

## Next Steps

1. Enhance `extract_quest_item_from_objective()` to also capture the quantity
2. Add `parse_progress_status(status_string)` function
3. Add `get_character_item_need(char, item)` to quest_interface
4. Add `get_all_character_needs()` to quest_interface
5. Add `extract_quantity_from_objective()` to quest_interface

These will provide the data needed for fair distribution logic.
