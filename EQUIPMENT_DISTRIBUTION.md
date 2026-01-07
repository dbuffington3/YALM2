--[[
    Equipment Distribution Integration Summary
    
    This document summarizes the integration of the equipment-aware distribution
    system into YALM2's looting logic.
]]

-- ============================================================================
-- WHAT WAS CHANGED
-- ============================================================================

-- 1. NEW FILES CREATED
--    - lib/equipment_distribution.lua  (Generic distribution logic)
--    - config/armor_sets.lua            (Armor set configurations)
--    - test_equipment_distribution.lua  (Comprehensive test suite)

-- 2. MODIFIED FILES
--    - core/looting.lua  (Added equipment distribution check + logging)

-- ============================================================================
-- HOW IT WORKS
-- ============================================================================

-- FLOW:
-- 1. Item arrives in loot list
-- 2. Looting.lua evaluates the item through normal Gate 1 & Gate 2 logic
-- 3. If item passes and gets distributed, NEW STEP:
--    → Check if item is an armor set piece (equipment_distribution.identify_armor_item)
--    → If YES: Use equipment-aware distribution logic
--       - Query all group members' equipped items in target slots
--       - Query all group members' inventory for crafting materials
--       - Calculate "satisfaction score" (equipped + crafting materials)
--       - Award to character with LOWEST score (greatest need)
--    → If NO: Continue with normal preference-based logic
-- 4. Item is distributed to selected member

-- ============================================================================
-- ADDING NEW ARMOR SETS
-- ============================================================================

-- TO ADD A NEW ARMOR SET (e.g., Abstruse):

-- 1. Query the database to find remnant IDs:
--    SELECT id, name FROM raw_item_data WHERE name LIKE '%Remnant%' ORDER BY name

-- 2. Edit config/armor_sets.lua and add:
--    ['Abstruse'] = {
--        display_name = "Abstruse Armor",
--        pieces = {
--            ['Wrist'] = {
--                slots = { 9, 10 },
--                remnant_name = 'Abstruse Remnant of ....',
--                remnant_id = 12345,
--                max_slots = 2,
--            },
--            ['Chest'] = {
--                slots = { 17 },
--                remnant_name = 'Abstruse Remnant of ...',
--                remnant_id = 12346,
--                max_slots = 1,
--            },
--            -- ... more pieces
--        }
--    }

-- 3. That's it! No code changes needed. The system automatically handles:
--    - Item identification
--    - Equipment querying
--    - Need calculation
--    - Best recipient selection

-- ============================================================================
-- LOGGING & DEBUGGING
-- ============================================================================

-- Equipment distribution decisions are logged with:
-- - EQUIPMENT_DIST: Item identified as armor set piece
-- - Assignment: Which character got the item and their satisfaction score
-- - Example: "Equipment Distribution: Recondite Remnant of Truth → Calystris (satisfaction: 0)"

-- ============================================================================
-- CHARACTERISTICS
-- ============================================================================

-- Satisfaction Score Model:
--   satisfaction = equipped_count + remnant_count
--   - Higher score = more satisfied / has more resources
--   - Lower score = greater need / most deserving
--   - Award to character with LOWEST score

-- Example (Recondite Wrist):
--   Echoveil: 2 equipped + 0 remnants = score 2
--   Malrik:   2 equipped + 0 remnants = score 2
--   Calystris: 0 equipped + 0 remnants = score 0 ← GETS THE ITEM

-- Example (Recondite Feet):
--   Echoveil: 0 equipped + 1 remnant = score 1
--   Malrik:   0 equipped + 0 remnants = score 0 ← GETS THE ITEM
--   Calystris: 0 equipped + 0 remnants = score 0 ← TIED, gets first in list

-- ============================================================================
-- FALLBACK BEHAVIOR
-- ============================================================================

-- If a character is unreachable via DanNet:
-- - Equipment queries return empty (no items equipped)
-- - Remnant queries return 0 (no inventory items)
-- - Character gets score 0 (highest priority)
-- - This prevents penalizing offline/unreachable characters

-- ============================================================================
-- TESTING
-- ============================================================================

-- To test the system:
--   /lua run yalm2/test_equipment_distribution

-- Test validates:
--   ✓ Armor set identification
--   ✓ Equipment queries via DanNet
--   ✓ Remnant inventory counting
--   ✓ Satisfaction score calculation
--   ✓ Best recipient selection
--   ✓ All Recondite piece types
