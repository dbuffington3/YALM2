# Renumber all tier values in armor_sets.lua
# Old scale → New scale mapping

$filePath = "C:\MQ2\lua\yalm2\config\armor_sets.lua"
$backupPath = "C:\MQ2\lua\yalm2\config\armor_sets.lua.backup"

# Read file
$content = Get-Content $filePath -Raw

# Create backup
Copy-Item $filePath $backupPath
Write-Host "✓ Backup created: $backupPath"
Write-Host ""

# Define tier mapping
$tierMap = @{
    # Underfoot: 1-4 → 6-9
    '1' = '6'
    '2' = '7'
    '3' = '8'
    '4' = '9'
    
    # House of Thule: 5-8 → 10-13
    '5' = '10'
    '6' = '11'
    '7' = '12'
    '8' = '13'
    
    # Veil of Alaris: 9-12 → 14-17
    '9' = '14'
    '10' = '15'
    '11' = '16'
    '12' = '17'
    
    # Rain of Fear: 13-16 → 18-21
    '13' = '18'
    '14' = '19'
    '15' = '20'
    '16' = '21'
    
    # Call of Forsaken: 17-18 → 22-23
    '17' = '22'
    '18' = '23'
}

# Count before
$tierCountsBefore = @{}
[regex]::Matches($content, 'tier\s*=\s*(\d+)') | ForEach-Object {
    $tier = $_.Groups[1].Value
    if ($tierCountsBefore.ContainsKey($tier)) {
        $tierCountsBefore[$tier]++
    } else {
        $tierCountsBefore[$tier] = 1
    }
}

Write-Host "BEFORE - Current tier distribution:"
$tierCountsBefore.Keys | Sort-Object {[int]$_} | ForEach-Object {
    Write-Host "  tier = $_  : $($tierCountsBefore[$_]) entries"
}
$totalBefore = ($tierCountsBefore.Values | Measure-Object -Sum).Sum
Write-Host "  TOTAL: $totalBefore tier fields"
Write-Host ""

# Perform replacements (process in reverse order to avoid conflicts with multi-digit numbers)
$newContent = $content
$totalReplacements = 0

foreach ($oldTier in ($tierMap.Keys | Sort-Object {[int]$_} -Descending)) {
    $newTier = $tierMap[$oldTier]
    # Match tier = N surrounded by spaces/newlines
    $pattern = "(\s+tier\s*=\s*)$oldTier(\s)"
    $replacement = "`$1$newTier`$2"
    
    $beforeCount = ([regex]::Matches($newContent, $pattern)).Count
    $newContent = [regex]::Replace($newContent, $pattern, $replacement)
    $afterCount = ([regex]::Matches($newContent, $pattern)).Count
    
    $count = $beforeCount - $afterCount
    if ($count -gt 0) {
        Write-Host "✓ Replaced tier = $oldTier → tier = $newTier : $count replacements"
        $totalReplacements += $count
    }
}

Write-Host ""

# Count after
$tierCountsAfter = @{}
[regex]::Matches($newContent, 'tier\s*=\s*(\d+)') | ForEach-Object {
    $tier = $_.Groups[1].Value
    if ($tierCountsAfter.ContainsKey($tier)) {
        $tierCountsAfter[$tier]++
    } else {
        $tierCountsAfter[$tier] = 1
    }
}

Write-Host "AFTER - New tier distribution:"
$tierCountsAfter.Keys | Sort-Object {[int]$_} | ForEach-Object {
    Write-Host "  tier = $_  : $($tierCountsAfter[$_]) entries"
}
$totalAfter = ($tierCountsAfter.Values | Measure-Object -Sum).Sum
Write-Host "  TOTAL: $totalAfter tier fields"
Write-Host ""

# Validation
Write-Host "VALIDATION:"
Write-Host "==========="

# Check old tiers don't remain
$oldTiersRemaining = @()
foreach ($oldTier in $tierMap.Keys) {
    if ($tierCountsAfter.ContainsKey($oldTier) -and $tierCountsAfter[$oldTier] -gt 0) {
        $oldTiersRemaining += $oldTier
    }
}

if ($oldTiersRemaining.Count -eq 0) {
    Write-Host "✓ No old tier values remain"
} else {
    Write-Host "⚠ WARNING: Old tier values still present: $($oldTiersRemaining -join ', ')"
}

# Check totals match
if ($totalBefore -eq $totalAfter) {
    Write-Host "✓ Total tier fields preserved: $totalBefore"
} else {
    Write-Host "✗ ERROR: Tier count mismatch! Before: $totalBefore, After: $totalAfter"
}

# Check braces balanced
$openBraces = ($newContent | Select-String -AllMatches '{').Matches.Count
$closeBraces = ($newContent | Select-String -AllMatches '}').Matches.Count
if ($openBraces -eq $closeBraces) {
    Write-Host "✓ Braces balanced: $openBraces open, $closeBraces close"
} else {
    Write-Host "✗ ERROR: Braces unbalanced! $openBraces open, $closeBraces close"
}

# Write file if validation passes
if ($oldTiersRemaining.Count -eq 0 -and $totalBefore -eq $totalAfter -and $openBraces -eq $closeBraces) {
    Write-Host ""
    Write-Host "✓ All validations passed - applying changes"
    
    Set-Content -Path $filePath -Value $newContent
    Write-Host "✓ File updated: $filePath"
    Write-Host "✓ Applied $totalReplacements tier renumbering changes"
    Write-Host ""
    Write-Host "✓ TIER RENUMBERING COMPLETE"
} else {
    Write-Host ""
    Write-Host "✗ Validation failed - reverting to backup"
    Copy-Item $backupPath $filePath -Force
    Write-Host "✗ File restored from backup"
}
