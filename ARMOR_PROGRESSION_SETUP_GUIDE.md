# Armor Progression Setup - Integration Guide

## Overview
This setup script configures 530 armor craft components globally across all characters in YALM2. It's designed to automatically set appropriate KEEP quantities (KEEP|1 for most items, KEEP|2 for wrist pieces).

## Files Created

### 1. `config/commands/armor_progression_setup.lua`
Main command handler - contains all item definitions and setup logic.

### 2. `armor_progression_setup.lua` (alternate version)
Standalone script that reads from CRAFT_COMPONENTS_LIST.md for dynamic item loading.

## Installation

### Method 1: Automatic Command Registration

If your YALM2 command system automatically loads commands from `config/commands/`, the setup is automatic. Simply ensure:

1. File is in: `C:\MQ2\lua\yalm2\config\commands\armor_progression_setup.lua`
2. Your main YALM2 initialization calls command handlers from that directory

### Method 2: Manual Integration

Add to your main YALM2 command dispatcher (likely in `init.lua` or `config/configuration.lua`):

```lua
-- Load armor progression setup command
local armorSetup = require('config.commands.armor_progression_setup')

-- Add to command dispatcher
if command:lower():find("armorprogressionsetup") then
    return armorSetup(args, fullCommandLine)
end
```

## Usage

In-game, simply type:

```
/yalm2 ArmorProgressionSetup
```

The script will:
1. Iterate through all 530 armor craft components
2. Set KEEP|1 for standard pieces (helm, arms, gloves, boots, legs, chest)
3. Set KEEP|2 for wrist pieces (bracer, wristguard, wristband)
4. Display progress every 50 items
5. Print summary upon completion

## What Gets Configured

**13 Expansions:**
1. Luminessence/Incandessence (40 items)
2. Encrusted Clay (56 items)
3. Remnant Tiers (56 items)
4. Armor Tiers (56 items)
5. Fear & Dread Components (56 items)
6. Ether Components (28 items)
7. Water-Themed Components (28 items)
8. Raw Crypt-Hunter (7 items)
9. Amorphous Templates (21 items)
10. Scale Touched Facets (7 items)
11. Scaled & Scaleborn Facets (14 items)
12. Binding Muhbis (35 items)
13. Faded & Obscured Armor (126 items)

**Total: 530 items**

## Configuration Details

### Wrist Pieces (KEEP|2)
Items containing "Bracer", "Wrist", or "Wristguard" in their names are set to KEEP|2 to ensure you accumulate enough wrist components.

### All Other Pieces (KEEP|1)
Helms, arms, gloves, boots, legs, and chest pieces are set to KEEP|1 as you typically need fewer of these per tier.

## Global Storage

All configurations are stored globally in YALM2's preference system, ensuring:
- Settings persist across character login/logout
- New characters automatically inherit the armor settings
- No per-character configuration needed

## Troubleshooting

### Items not being configured:
1. Verify the script is in the correct location
2. Check that the command dispatcher is loading from `config/commands/`
3. Ensure item names match exactly with database entries
4. Check for typos in the item name list

### Configuration not persisting:
1. Verify YALM2 preference save is enabled
2. Check that `/yalm2 setitem` commands are functioning
3. Review YALM2 logs for errors

## Alternate Approach: Dynamic Loading

If you prefer to load items dynamically from the CRAFT_COMPONENTS_LIST.md file instead of maintaining a hardcoded list, use `armor_progression_setup.lua` (the alternate version) instead. This:

- Reads directly from the markdown document
- Requires less maintenance if items are added/removed
- Parses the markdown table format automatically

**Note:** The dynamic loader requires the mq library and file I/O access.

## Rollback

If you need to remove/modify individual item configurations after setup:

```
/yalm2 setitem "Item Name" "Destroy"
```

Or to modify a specific quantity:

```
/yalm2 setitem "Item Name" "Keep" 3
```

## Performance

Setting 530 items takes approximately 15-30 seconds depending on:
- System speed
- YALM2 database performance
- Current server load

The script displays progress every 50 items.

## Questions & Support

Refer to CRAFT_COMPONENTS_LIST.md for the comprehensive item list with item IDs and verification.
