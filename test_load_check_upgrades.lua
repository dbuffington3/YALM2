-- Test script to load check_upgrades module
print("Testing check_upgrades module load...")

local success, result = pcall(require, 'check_upgrades')
if success then
    print("✓ Module loaded successfully")
else
    print("✗ Module load failed:", result)
end
