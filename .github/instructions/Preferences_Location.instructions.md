---
applyTo: 'core/looting.lua'
---

# YALM2 Preferences File Location & Structure

## FILE LOCATION
**Global Preferences:** `c:\MQ2\config\YALM2.lua`

The preferences are stored in a Lua table under `["preferences"]` key.

## PREFERENCES STRUCTURE

```lua
["preferences"] = {
    ["Bank"] = {
        ["name"] = "Bank",
    },
    ["Buy"] = {
        ["name"] = "Buy",
    },
    ["Destroy"] = {
        ["name"] = "Destroy",
        ["leave"] = true,  -- Item is left on corpse if this preference
    },
    ["Guild"] = {
        ["name"] = "Guild",
    },
    ["Ignore"] = {
        ["name"] = "Ignore",
        ["leave"] = true,
    },
    ["Keep"] = {
        ["name"] = "Keep",
    },
    ["Sell"] = {
        ["name"] = "Sell",
    },
    ["Tribute"] = {
        ["name"] = "Tribute",
    },
}
```

## HOW TO CHECK FOR A PREFERENCE ON AN ITEM

**Default Settings Location:**
- File: `c:\MQ2\lua\yalm2\config\defaults\global_settings.lua`
- Preferences accessed via: `loot.preferences[item_name]`
- Rules/Items accessed via: `loot.items[item_name]` (character rules)

## CHECKING IF ITEM HAS PREFERENCE

In `core/looting.lua`:
```lua
-- To check if item has any preference rule:
if loot.items and loot.items[item_name] then
    -- Item has a specific preference rule
    local rule = loot.items[item_name]
    local setting = rule.setting  -- e.g., "Keep", "Destroy", "Sell", etc.
end

-- loot.items comes from character settings (c:\MQ2\config\yalm2-server-character.lua)
-- loot.preferences is the global preference types (Bank, Keep, Destroy, etc.)
```

## CONTEXT FOR LOW-VALUE NON-STACKABLE TRADESKILL ITEMS

**Gate 1 Check 1b Logic:**
When checking if a tradeskill item should be kept:
1. Item is tradeskill (tradeskills = 1)
2. keep_tradeskills = true (config setting)
3. BUT if item is non-stackable (stackable = 0 or null) AND cost < 100pp:
   - Check if item has a preference rule in `loot.items[item_name]`
   - If NO preference exists → LEAVE ON CORPSE
   - If preference exists → FOLLOW THE PREFERENCE

## VARIABLES IN GATE 1 CHECK

- `item_name` - The item name (e.g., "Velium Morning Star")
- `is_tradeskill` - Boolean, true if tradeskills = 1 in database
- `stackable` - Database field value (0 or null = non-stackable, >0 = stackable)
- `item_cost` - Database cost field (in copper, divide by 100 for pp)
- `loot.items` - Character-specific item preferences
- `loot.settings.keep_tradeskills` - Global setting to keep tradeskill items

