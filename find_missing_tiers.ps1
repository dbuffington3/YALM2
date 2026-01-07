# Identify remaining unmapped armor sets

$filePath = "C:\MQ2\lua\yalm2\config\armor_sets.lua"
$content = Get-Content $filePath -Raw

# Find all armor set definitions and check for tier fields
$matches = [regex]::Matches($content, "\['([^']+)'\]\s*=\s*\{[\s\S]{0,500}?display_name", [System.Text.RegularExpressions.RegexOptions]::Multiline)

$missing = @()
foreach ($match in $matches) {
    $setName = $match.Groups[1].Value
    $fullBlock = $match.Value
    
    # Check if has tier field
    if ($fullBlock -notmatch "tier\s*=") {
        $missing += $setName
    }
}

Write-Host "Missing tier fields: $($missing.Count)"
Write-Host ""
Write-Host "Sets needing tier assignments:"
$missing | Sort-Object -Unique | ForEach-Object { Write-Host "  $_" }

# Export for manual mapping
$missing | Sort-Object -Unique | Out-File "C:\MQ2\lua\yalm2\missing_tiers.txt"
