import re
from pathlib import Path

file_path = Path(r'C:\MQ2\lua\yalm2\config\armor_sets.lua')

# Read
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Tier mapping
tier_map = {
    1:6, 2:7, 3:8, 4:9,           # Underfoot
    5:10, 6:11, 7:12, 8:13,       # House of Thule
    9:14, 10:15, 11:16, 12:17,    # Veil of Alaris
    13:18, 14:19, 15:20, 16:21,   # Rain of Fear
    17:22, 18:23                   # Call of Forsaken
}

# Count before
tier_counts_before = {}
for match in re.finditer(r'tier\s*=\s*(\d+)', content):
    tier_val = int(match.group(1))
    tier_counts_before[tier_val] = tier_counts_before.get(tier_val, 0) + 1

# Perform replacements (reverse order to avoid conflicts)
new_content = content
total_replacements = 0

for old_tier in sorted(tier_map.keys(), reverse=True):
    new_tier = tier_map[old_tier]
    pattern = r'(\s+tier\s*=\s*)' + str(old_tier) + r'(\s)'
    replacement = r'\g<1>' + str(new_tier) + r'\g<2>'
    new_content, count = re.subn(pattern, replacement, new_content)
    total_replacements += count

# Count after
tier_counts_after = {}
for match in re.finditer(r'tier\s*=\s*(\d+)', new_content):
    tier_val = int(match.group(1))
    tier_counts_after[tier_val] = tier_counts_after.get(tier_val, 0) + 1

# Write backup
backup_path = file_path.with_suffix('.lua.backup')
with open(backup_path, 'w', encoding='utf-8') as f:
    f.write(content)

# Write new content
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

# Report
print("TIER RENUMBERING COMPLETE")
print("=" * 60)
print("\nBEFORE:")
for tier in sorted(tier_counts_before.keys()):
    print(f"  tier = {tier}: {tier_counts_before[tier]} entries")

print("\nAFTER:")
for tier in sorted(tier_counts_after.keys()):
    print(f"  tier = {tier}: {tier_counts_after[tier]} entries")

print(f"\nTotal replacements: {total_replacements}")
print(f"Backup saved to: {backup_path}")
print("✓ File updated successfully")
