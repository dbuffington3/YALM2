# Per-Character Needs - Data Examples

## Your Current Quest Setup (From UI)

Based on what's in your TaskWnd, here's what gets captured:

### Character: Forestess
- **Quest:** "Collect Orbweaver Silks"
  - Status: "0/4" → Needs 4 (current 0)
  - Data captured: { needed=4, current=0, item="Orbweaver Silks" }

### Character: Vaeloraa
- **Quest 1:** "Collect Orbweaver Silks"
  - Status: "0/3" → Needs 3 (current 0)
  - Data captured: { needed=3, current=0, item="Orbweaver Silks" }

- **Quest 2:** "Collect Tanglefang Pelts"
  - Status: "0/2" → Needs 2 (current 0)
  - Data captured: { needed=2, current=0, item="Tanglefang Pelts" }

### Character: Lumarra
- **Quest 1:** "Collect Orbweaver Silks"
  - Status: "0/2" → Needs 2
  - Data: { needed=2, current=0, item="Orbweaver Silks" }

- **Quest 2:** "Collect Tanglefang Pelts"
  - Status: "0/3" → Needs 3
  - Data: { needed=3, current=0, item="Tanglefang Pelts" }

### Character: Tarnook
- **Quest 1:** "Collect Orbweaver Silks"
  - Status: "0/6" → Needs 6
  - Data: { needed=6, current=0, item="Orbweaver Silks" }

- **Quest 2:** "Collect Tanglefang Pelts"
  - Status: "0/4" → Needs 4
  - Data: { needed=4, current=0, item="Tanglefang Pelts" }

### Character: Lyricen
- **Quest 1:** "Collect Orbweaver Silks"
  - Status: "0/3" → Needs 3
  - Data: { needed=3, current=0, item="Orbweaver Silks" }

- **Quest 2:** "Collect Tanglefang Pelts"
  - Status: "0/1" → Needs 1
  - Data: { needed=1, current=0, item="Tanglefang Pelts" }

### Character: Vexxuss
- **Quest:** "Collect Orbweaver Silks"
  - Status: "0/5" → Needs 5
  - Data: { needed=5, current=0, item="Orbweaver Silks" }

## Parsed Data Structure From `get_per_character_needs()`

```lua
{
    Forestess = {
        ["Orbweaver Silks"] = { quantity = 4, progress = "0/4", is_done = false }
    },
    
    Vaeloraa = {
        ["Orbweaver Silks"] = { quantity = 3, progress = "0/3", is_done = false },
        ["Tanglefang Pelts"] = { quantity = 2, progress = "0/2", is_done = false }
    },
    
    Lumarra = {
        ["Orbweaver Silks"] = { quantity = 2, progress = "0/2", is_done = false },
        ["Tanglefang Pelts"] = { quantity = 3, progress = "0/3", is_done = false }
    },
    
    Tarnook = {
        ["Orbweaver Silks"] = { quantity = 6, progress = "0/6", is_done = false },
        ["Tanglefang Pelts"] = { quantity = 4, progress = "0/4", is_done = false }
    },
    
    Lyricen = {
        ["Orbweaver Silks"] = { quantity = 3, progress = "0/3", is_done = false },
        ["Tanglefang Pelts"] = { quantity = 1, progress = "0/1", is_done = false }
    },
    
    Vexxuss = {
        ["Orbweaver Silks"] = { quantity = 5, progress = "0/5", is_done = false }
    }
}
```

## MQ2 Variables Generated

### YALM2_Quest_Items_WithQty
(Raw string format - what gets stored in MQ2 variable)

```
Orbweaver Silks:Forestess:4,Vaeloraa:3,Lumarra:2,Tarnook:6,Lyricen:3,Vexxuss:5|Tanglefang Pelts:Vaeloraa:2,Lumarra:3,Tarnook:4,Lyricen:1|
```

### YALM2_Quest_Items
(Backwards compatible - just character names)

```
Orbweaver Silks:Forestess,Vaeloraa,Lumarra,Tarnook,Lyricen,Vexxuss|Tanglefang Pelts:Vaeloraa,Lumarra,Tarnook,Lyricen|
```

## Distribution Priority Examples

### "Orbweaver Silks" - Who needs it most?
1. **Tarnook** - needs 6 (HIGHEST)
2. **Vexxuss** - needs 5
3. **Forestess** - needs 4
4. **Vaeloraa** - needs 3
5. **Lyricen** - needs 3
6. **Lumarra** - needs 2

→ If you find 1 Orbweaver Silk, give it to **Tarnook**

### "Tanglefang Pelts" - Who needs it most?
1. **Tarnook** - needs 4 (HIGHEST)
2. **Lumarra** - needs 3
3. **Vaeloraa** - needs 2
4. **Lyricen** - needs 1 (LOWEST)

→ If you find 1 Tanglefang Pelt, give it to **Tarnook**

## Important Notes

1. **Quantities are PER CHARACTER** - Forestess needs 4, Tarnook needs 6 (different amounts)

2. **Multiple Quests Per Character** - Vaeloraa has 2 quests, Forestess has 1

3. **Different Item Combinations** - Forestess doesn't need Pelts, so they don't appear in her data

4. **Progress is Tracked** - The "0/4" can change to "1/4", "2/4", etc. as items are collected

5. **This Data is FRESH** - Comes directly from ML's TaskWnd, not from other characters

6. **No Network Dependency** - Doesn't require DanNet messages to other characters

## Next Steps for Distribution Logic

With this data, you can implement:

```lua
function distribute_item(item_name, quantity)
    local needs = quest_interface.get_per_character_needs()
    
    -- Find the character who needs THIS ITEM the most
    local best_char = nil
    local highest_need = 0
    
    for char_name, items in pairs(needs) do
        if items[item_name] and items[item_name].quantity > highest_need then
            highest_need = items[item_name].quantity
            best_char = char_name
        end
    end
    
    -- best_char is who should get this item
    if best_char then
        return best_char, highest_need
    else
        return nil  -- Nobody needs this item
    end
end
```

This ensures fair distribution based on actual need!
