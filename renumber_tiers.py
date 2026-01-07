#!/usr/bin/env python3
"""
Renumber all tier values in armor_sets.lua based on correct expansion order.

Old scale (incorrect):
  1-4: Underfoot
  5-8: House of Thule
  9-12: Veil of Alaris
  13-16: Rain of Fear
  17-18: Call of Forsaken

New scale (correct - SoD oldest):
  1-5: Seeds of Destruction (oldest)
  6-9: Underfoot
  10-13: House of Thule
  14-17: Veil of Alaris
  18-21: Rain of Fear
  22-23: Call of Forsaken
"""

import re
from pathlib import Path

file_path = Path(r"C:\MQ2\lua\yalm2\config\armor_sets.lua")

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Create tier mapping
tier_map = {
    # Underfoot: 1-4 → 6-9
    1: 6,
    2: 7,
    3: 8,
    4: 9,
    
    # House of Thule: 5-8 → 10-13
    5: 10,
    6: 11,
    7: 12,
    8: 13,
    
    # Veil of Alaris: 9-12 → 14-17
    9: 14,
    10: 15,
    11: 16,
    12: 17,
    
    # Rain of Fear: 13-16 → 18-21
    13: 18,
    14: 19,
    15: 20,
    16: 21,
    
    # Call of Forsaken: 17-18 → 22-23
    17: 22,
    18: 23,
}

# Count current tiers
tier_counts_before = {}
for match in re.finditer(r'tier\s*=\s*(\d+)', content):
    tier_val = int(match.group(1))
    tier_counts_before[tier_val] = tier_counts_before.get(tier_val, 0) + 1

print("=" * 70)
print("TIER RENUMBERING ANALYSIS")
print("=" * 70)
print("\nBEFORE - Current tier distribution:")
for tier in sorted(tier_counts_before.keys()):
    print(f"  tier = {tier:2d}: {tier_counts_before[tier]:3d} entries")

total_before = sum(tier_counts_before.values())
print(f"\n  TOTAL: {total_before} tier fields")

# Perform the replacement
new_content = content
replacements = 0

# Sort in reverse order to avoid replacing "1" in "10", "11", etc.
for old_tier in sorted(tier_map.keys(), reverse=True):
    new_tier = tier_map[old_tier]
    # Use word boundaries to match only complete numbers
    pattern = r'(\s+tier\s*=\s*)' + str(old_tier) + r'(\s)'
    replacement = r'\g<1>' + str(new_tier) + r'\g<2>'
    new_content, count = re.subn(pattern, replacement, new_content)
    replacements += count
    if count > 0:
        print(f"\n✓ Replaced tier = {old_tier:2d} → tier = {new_tier:2d}: {count:3d} replacements")

# Count new tiers
tier_counts_after = {}
for match in re.finditer(r'tier\s*=\s*(\d+)', new_content):
    tier_val = int(match.group(1))
    tier_counts_after[tier_val] = tier_counts_after.get(tier_val, 0) + 1

print("\n" + "=" * 70)
print("AFTER - New tier distribution:")
for tier in sorted(tier_counts_after.keys()):
    print(f"  tier = {tier:2d}: {tier_counts_after[tier]:3d} entries")

total_after = sum(tier_counts_after.values())
print(f"\n  TOTAL: {total_after} tier fields")

# Validate
print("\n" + "=" * 70)
print("VALIDATION:")
print("=" * 70)

# Check that no old tiers remain (except any that shouldn't exist)
remaining_old_tiers = set(tier_counts_after.keys()) & set(tier_map.keys())
if remaining_old_tiers:
    print(f"⚠ WARNING: Old tier values still present: {remaining_old_tiers}")
else:
    print("✓ No old tier values remain")

# Check totals match
if total_before == total_after:
    print(f"✓ Total tier fields preserved: {total_before}")
else:
    print(f"✗ ERROR: Tier count mismatch! Before: {total_before}, After: {total_after}")

# Check for balanced braces
open_braces = new_content.count('{')
close_braces = new_content.count('}')
if open_braces == close_braces:
    print(f"✓ Braces balanced: {open_braces} open, {close_braces} close")
else:
    print(f"✗ ERROR: Braces unbalanced! {open_braces} open, {close_braces} close")

print("\n" + "=" * 70)
print("CONFIRMATION:")
print("=" * 70)

if replacements > 0 and total_before == total_after and open_braces == close_braces:
    response = input(f"\n✓ Ready to apply {replacements} tier renumbering changes. Proceed? (y/n): ").strip().lower()
    
    if response == 'y':
        # Backup the original file
        backup_path = file_path.with_suffix('.lua.backup')
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"\n✓ Backup created: {backup_path}")
        
        # Write the new content
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"✓ Updated file: {file_path}")
        print(f"✓ Applied {replacements} tier renumbering changes")
        print("\n✓ Tier renumbering COMPLETE")
    else:
        print("\n✗ Cancelled - no changes made")
else:
    print("\n✗ Cannot proceed - validation failed")
    print(f"  Replacements: {replacements}")
    print(f"  Tier count match: {total_before == total_after}")
    print(f"  Braces balanced: {open_braces == close_braces}")
