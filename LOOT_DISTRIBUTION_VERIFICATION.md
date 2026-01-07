# Loot Distribution Class Bitmask Validation - CORRECT ✓

## Summary
The loot distribution logic in `core/looting.lua` and `core/evaluate.lua` **IS CORRECT** and does NOT need fixing.

## How It Works

### The parseFlags Function (definitions/Item.lua, lines 9-20)
```lua
local function parseFlags(flags, object)
    local values = {}
    local newFlags = flags

    for i in ipairs(object) do
        local flag = bit.band(newFlags, 1)      -- Check if lowest bit is set
        newFlags = bit.rshift(newFlags, 1)      -- Right shift by 1
        if flag == 1 then
            table.insert(values, object[i])     -- Add class to usable list
        end
    end

    return values
end
```

This function correctly decodes the bitmask using 0-indexed bit positions.

### The Classes Array (definitions/Classes.lua)
```lua
local Classes = {
    "WAR",  -- Index 1, represents Bit 0 (2^0 = 1)
    "CLR",  -- Index 2, represents Bit 1 (2^1 = 2)
    "PAL",  -- Index 3, represents Bit 2 (2^2 = 4)
    "RNG",  -- Index 4, represents Bit 3 (2^3 = 8)
    "SHD",  -- Index 5, represents Bit 4 (2^4 = 16)
    "DRU",  -- Index 6, represents Bit 5 (2^5 = 32)
    "MNK",  -- Index 7, represents Bit 6 (2^6 = 64)
    "BRD",  -- Index 8, represents Bit 7 (2^7 = 128)
    "ROG",  -- Index 9, represents Bit 8 (2^8 = 256)  ✓ CORRECT
    "SHM",  -- Index 10, represents Bit 9 (2^9 = 512) ✓ CORRECT
    "NEC",  -- Index 11, represents Bit 10 (2^10 = 1024)
    "WIZ",  -- Index 12, represents Bit 11 (2^11 = 2048)
    "MAG",  -- Index 13, represents Bit 12 (2^12 = 4096)
    "ENC",  -- Index 14, represents Bit 13 (2^13 = 8192)
    "BST",  -- Index 15, represents Bit 14 (2^14 = 16384) ✓ CORRECT
    "BER",  -- Index 16, represents Bit 15 (2^15 = 32768) ✓ CORRECT
}
```

### Item.Class() Function (definitions/Item.lua, lines 76-83)
```lua
Item.Class = function(class)
    local classes = parseFlags(Item.item_db.classes, Classes)
    for i in ipairs(classes) do
        if classes[i]:find(class) then
            return class
        end
    end
    return "NULL"
end
```

This function:
1. Calls `parseFlags()` to decode the bitmask into a list of usable class codes
2. Checks if the provided `class` code is in that list
3. Returns the class code if found, or "NULL" if not

## Loot Distribution Usage (core/looting.lua, lines 452-510)
```lua
if member_class and loot_item.Class then
    local class_match = loot_item.Class(member_class)
    if class_match ~= "NULL" then
        table.insert(usable_members, test_member)  -- Can use item
    else
        table.insert(other_members, test_member)   -- Cannot use item
    end
end
```

This correctly:
- Determines which group members can use an item
- Prioritizes distribution to members who can actually equip it
- Falls back to other members only if needed

## NO TRADE Safety (core/evaluate.lua, lines 77-86)
```lua
if member_class and loot_item.Class then
    local class_match = loot_item.Class(member_class)
    if class_match == "NULL" then
        -- Block distribution to prevent NO TRADE item going to wrong class
        Write.Warn("NO TRADE SAFETY: Preventing %s from getting %s (class %s cannot use it)", 
            member_name, loot_item.Name(), member_class)
        can_loot = false
    end
end
```

This correctly:
- Prevents NO TRADE items from being distributed to classes that can't use them
- Is a critical safety check for valuable items

## Verification Examples
Using the Classes array and parseFlags logic:
- Item 256 (ROG-only): parseFlags(256, Classes) = {"ROG"} ✓
- Item 512 (SHM-only): parseFlags(512, Classes) = {"SHM"} ✓
- Item 133911 (16480 = 16384+96): parseFlags(16480, Classes) = {"DRU", "MNK", "BST"} ✓
- Item 133919 (15360 = 8192+4096+2048+1024): parseFlags(15360, Classes) = {"NEC", "WIZ", "MAG", "ENC"} ✓

## Conclusion
✓ **NO CHANGES NEEDED** - The loot distribution system correctly uses the proper 0-indexed bitmask decoding via the parseFlags function and Classes array.
