-- Example showing how item ID 120331 class restriction issue occurs

-- SCENARIO: Item ID 120331 is a caster-only item (WIZ/MAG/ENC/NEC only)
-- but SHD (Shadow Knight) received it due to missing class restrictions

-- What SHOULD happen:
local correct_item_rule = {
    setting = "Keep",
    list = {"WIZ", "MAG", "ENC", "NEC"},  -- Only casters can loot
    quantity = 1
}

-- What ACTUALLY happened (likely):
local actual_item_rule = {
    setting = "Keep", 
    list = {},  -- EMPTY LIST = NO CLASS RESTRICTIONS!
    quantity = 1
}

-- OR it fell back to unmatched_item_rule:
local unmatched_fallback = {
    setting = "Keep",
    list = {}  -- No restrictions, anyone can loot
}

print("=== ITEM 120331 CLASS RESTRICTION ANALYSIS ===")
print("")
print("What should have happened:")
print("- Item rule: Keep for classes [WIZ, MAG, ENC, NEC]")
print("- SHD check: SHD not in list → FAIL → Skip to next member")
print("- Next member check: Find WIZ/MAG/ENC/NEC → SUCCESS → Give to caster")
print("")
print("What actually happened (likely):")
print("- No specific item rule for ID 120331")
print("- Falls back to unmatched_item_rule with empty class list")
print("- SHD check: Empty list = no restrictions → PASS") 
print("- SHD is master looter (checked first) → Gets the item")
print("- Wrong class receives item!")
print("")
print("SOLUTION: Create specific rule for item ID 120331 with proper class restrictions")

-- Example of how to fix it:
print("=== FIX EXAMPLE ===")
print("Add to item rules:")
print('120331 = { setting = "Keep", list = {"WIZ", "MAG", "ENC", "NEC"} }')
print("")
print("Or create loot rule that matches this item type and restricts by class")