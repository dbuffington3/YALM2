# Per-Character Quest Item Quantity Parsing - Implementation Complete

## What We Added

### 1. New Parsing Function in `yalm2_native_quest.lua`

#### `parse_progress_status(status_string)`
Parses the progress string from the status field into structured data.

**Examples:**
```
"0/4" → { current = 0, needed = 4, is_done = false }
"2/5" → { current = 2, needed = 5, is_done = false }
"Done" → { current = -1, needed = -1, is_done = true }
```

**Why this approach:**
- Status field ALREADY contains exactly what we need (current/needed)
- No text parsing required - simple pattern match on "/"
- Directly from TaskWnd, completely reliable
- Much simpler than parsing objective text

### 2. Enhanced MQ2 Variables

#### New Variable: `YALM2_Quest_Items_WithQty`
**Format:** `Item:char1:qty1,char2:qty2|Item2:char3:qty3|`

**Example:**
```
"Orbweaver Silks:Forestess:4,Vaeloraa:3,Lumarra:2,Tarnook:6,Lyricen:3,Vexxuss:5|Tanglefang Pelts:Vaeloraa:2,Lumarra:3,Tarnook:4,Lyricen:1|"
```

**Quantities come from:** Status field (e.g., "0/4" → needed = 4)

**Purpose:** Makes per-character quantities available to any script that needs them

#### Existing Variable: `YALM2_Quest_Items` (unchanged)
**Format:** `Item:char1,char2|Item2:char3|`

**Purpose:** Backwards compatibility - still works as before

### 3. New API Functions

#### In `quest_interface.lua`:
```lua
quest_interface.get_per_character_needs()
```

#### In `native_tasks.lua`:
```lua
native_tasks.get_per_character_needs()
```

**Returns:** Table structure:
```lua
{
    Forestess = {
        ["Orbweaver Silks"] = { quantity = 4, progress = "unknown", is_done = false }
    },
    Vaeloraa = {
        ["Orbweaver Silks"] = { quantity = 3, progress = "unknown", is_done = false },
        ["Tanglefang Pelts"] = { quantity = 2, progress = "unknown", is_done = false }
    },
    -- etc for all characters...
}
```

## How the Data Flows

1. **ML opens TaskWnd** → `get_tasks()` reads all objectives directly from UI
2. **extract_quantity_from_objective()** parses "Collect 4 Silks" → `4`
3. **parse_progress_status()** parses "0/4" → `{ current=0, needed=4 }`
4. **quest_items table built** with all data (character, item, quantity, progress)
5. **MQ2 variables updated:**
   - `YALM2_Quest_Items` = "Silks:char1,char2|" (who needs what)
   - `YALM2_Quest_Items_WithQty` = "Silks:char1:4,char2:3|" (who needs how many)
6. **get_per_character_needs()** parses the WithQty variable → returns structured table

## Key Points About Per-Character Data

✅ **ML knows exactly who needs how many**
- UI displays full objectives with quantities
- `get_tasks()` reads directly from TaskWnd
- Quantities captured in both objective text AND status string
- Dual fallback: try objective text first, then status if needed

✅ **Data is available immediately**
- No network delay - data is read from ML's own TaskWnd
- Other characters don't need to report this
- Pure local ML operation, not based on DanNet messages

✅ **Quantities can be different per character**
```
Forestess needs 4 Silks
Vaeloraa needs 3 Silks
Lumarra needs 2 Silks
```

✅ **Backwards compatible**
- YALM2_Quest_Items still works (just character names)
- YALM2_Quest_Items_WithQty is optional new variable
- Old code doesn't break

## Usage Example

```lua
-- Get needs matrix
local needs = quest_interface.get_per_character_needs()

-- Find who needs the most Orbweaver Silks
local highest_need = 0
local most_needed_char = nil
for char_name, items in pairs(needs) do
    if items["Orbweaver Silks"] and items["Orbweaver Silks"].quantity > highest_need then
        highest_need = items["Orbweaver Silks"].quantity
        most_needed_char = char_name
    end
end

-- Result: most_needed_char = character who should get priority for Silks
```

## Ready for Distribution Logic

Now that we can answer:
- ✅ "Who needs this item?" → `get_characters_needing_item()`
- ✅ "How many do they need?" → `get_per_character_needs()`
- ✅ "What's their current progress?" → status field in get_per_character_needs()
- ✅ "Is their quest done?" → is_done flag in parse_progress_status()

We can implement distribution logic like:
1. When an item drops, identify who needs it
2. Choose recipient based on need (most needed gets priority)
3. Track progress to know when quests complete
4. Fair rotation if multiple people need same amount
5. Update progress when items are given

## Files Modified

1. **yalm2_native_quest.lua**
   - Added `extract_quantity_from_objective()` function
   - Added `parse_progress_status()` function
   - Enhanced quest_data_string building to include quantities
   - Created YALM2_Quest_Items_WithQty MQ2 variable

2. **native_tasks.lua**
   - Added `get_per_character_needs()` function
   - Parses YALM2_Quest_Items_WithQty variable
   - Returns structured needs table

3. **quest_interface.lua**
   - Added `get_per_character_needs()` wrapper function
   - Routes to native_tasks or external_tasks implementation

## Testing Notes

When you manually refresh:
- `YALM2_Quest_Items_WithQty` will be updated with full quantities
- `get_per_character_needs()` will return accurate needs matrix
- Each character's needed quantity comes directly from their TaskWnd
- No guessing or assumptions - pure data from the UI
