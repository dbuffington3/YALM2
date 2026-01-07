# Gate System Configuration Reference

This document defines the configuration keys used by the three-gate looting system in `core/looting.lua`.

## Gate 1: Quest Items

### Check 1a - Quest Need Detection
- **No config keys** - uses `quest_interface.get_characters_needing_item()` to check if anyone needs the item for an active quest

### Check 1b - Tradeskill Configuration
- **Config Key:** `loot.settings.keep_tradeskills`
- **Type:** Boolean
- **Default:** `true` (from `config/defaults/global_settings.lua`)
- **Purpose:** If `true`, quest items that are used in tradeskills are kept
- **Location in Code:** `looting.get_member_can_loot()` line ~270

### Check 1c - Quest Item Value Check
- **Config Keys:** 
  - `loot.settings.valuable_guildfavor_min` - minimum guild favor to be considered valuable
  - Item value is checked: `item_guildfavor > 0 OR item_cost > 0`
- **Type:** Number (for guildfavor_min)
- **Default:** `10` (for guildfavor_min)
- **Purpose:** Quest items with ANY value (cost or favor) are kept
- **Location in Code:** `looting.get_member_can_loot()` line ~275

---

## Gate 2: Non-Quest Items (No-Drop / Stack / Value)

### Check 2a - Valuable Stackable Items
- **Config Keys:**
  - `loot.settings.valuable_item_min_price` - minimum cost to be considered valuable
  - `loot.settings.valuable_guildfavor_min` - minimum guild favor to be considered valuable
- **Type:** Number
- **Defaults:** 
  - `valuable_item_min_price = 100000`
  - `valuable_guildfavor_min = 10`
- **Logic:** Item is kept if:
  - `(item_cost >= valuable_item_min_price OR item_guildfavor >= valuable_guildfavor_min)` 
  - AND `item_stack_size > 1`
- **Location in Code:** `looting.get_member_can_loot()` line ~302

---

## CRITICAL NAMING NOTES

⚠️ **IMPORTANT:** The config uses `valuable_item_min_price` for the cost threshold, NOT `valuable_item_min_cost`

This can be confusing because:
- The field is named `price` in config
- The field is named `cost` in the database (raw_item_data.cost column)
- They refer to the same thing: the vendor value of the item

---

## Default Config Location
`c:\MQ2\lua\yalm2\config\defaults\global_settings.lua` - Lines 410-430

