#!/usr/bin/env lua

--[[
Verify that the NO TRADE + class restriction logic works correctly
Test case: Item 120448 (Ring of Glamouring) with Malrik (Shadowknight)

Expected behavior:
- Item 120448: nodrop=0 (NO TRADE), classes=33096
- Malrik class: Shadowknight (ID 5)
- Class bit check: bit 4 (5-1) should NOT be set in 33096
- Result: Should auto-tribute = YES
]]

-- Item data from database query
local item_id = 120448
local item_name = "Ring of Glamouring"
local nodrop = 0
local classes_bitmask = 33096

-- Character data
local character_class = "Shadowknight"
local character_class_id = 5

-- Class map (from Tribute.lua)
local class_map = {
	['Warrior'] = 1,
	['Cleric'] = 2,
	['Paladin'] = 3,
	['Ranger'] = 4,
	['Shadowknight'] = 5,
	['Druid'] = 6,
	['Monk'] = 7,
	['Bard'] = 8,
	['Rogue'] = 9,
	['Shaman'] = 10,
	['Necromancer'] = 11,
	['Wizard'] = 12,
	['Magician'] = 13,
	['Enchanter'] = 14,
	['Beastlord'] = 15,
	['Berserker'] = 16,
}

-- Step 1: Check NO TRADE flag
print("=" .. string.rep("=", 70))
print("TRIBUTE AUTO-DETECT VERIFICATION")
print("=" .. string.rep("=", 70))
print()

print("ITEM DATA:")
print(string.format("  ID: %d", item_id))
print(string.format("  Name: %s", item_name))
print(string.format("  Database nodrop value: %d", nodrop))
print(string.format("  Database classes bitmask: %d (0x%X)", classes_bitmask, classes_bitmask))
print()

print("CHARACTER DATA:")
print(string.format("  Class: %s (ID %d)", character_class, character_class_id))
print()

-- Check NO TRADE
print("STEP 1: Check NO TRADE flag")
local is_notrade = (nodrop == 0)
print(string.format("  nodrop == 0? %s", tostring(is_notrade)))
if is_notrade then
	print("  ✓ Item IS NO TRADE/NO DROP")
else
	print("  ✗ Item is tradeable")
end
print()

if not is_notrade then
	print("RESULT: Item is tradeable, NOT auto-tributed")
	os.exit(0)
end

-- Step 2: Check class restrictions
print("STEP 2: Check class restrictions")
print(string.format("  Classes bitmask: %d (decimal)", classes_bitmask))

local bit = require("bit")
local bit_position = character_class_id - 1
print(string.format("  Character class bit position: %d (ID %d - 1)", bit_position, character_class_id))
print()

-- Convert to binary and show bits
local bits = {}
for i = 0, 15 do
	table.insert(bits, tostring(bit.band(bit.rshift(classes_bitmask, i), 1)))
end
print("  Bits set (right-to-left, position 0-15):")
print("  Position:  " .. table.concat({15,14,13,12,11,10,9,8,7,6,5,4,3,2,1,0}, " "))
print("  Bit value: " .. table.concat(bits, " "))
print()

-- Check specific bit
local is_allowed = bit.band(classes_bitmask, bit.lshift(1, bit_position)) ~= 0
print(string.format("  Checking bit %d (Shadowknight)...", bit_position))
print(string.format("  Bit value at position %d: %d", bit_position, bit.band(bit.rshift(classes_bitmask, bit_position), 1)))

if is_allowed then
	print("  ✓ Character CAN use this item")
else
	print("  ✗ Character CANNOT use this item")
end
print()

-- Step 3: Decision
print("STEP 3: Auto-Tribute Decision")
print(string.format("  Is NO TRADE? %s", tostring(is_notrade)))
print(string.format("  Can character use? %s", tostring(is_allowed)))
local should_tribute = is_notrade and not is_allowed
print()

if should_tribute then
	print("  ✓✓✓ RESULT: AUTO-TRIBUTE YES ✓✓✓")
	print()
	print("Reason: Item is NO TRADE and character cannot use it.")
	print("Item should be tributed to guild by auto-detect system.")
else
	print("  ✗ RESULT: NO AUTO-TRIBUTE")
	if not is_notrade then
		print("Reason: Item is not NO TRADE (can be traded)")
	else
		print("Reason: Character can use this item")
	end
end

print()
print("=" .. string.rep("=", 70))
