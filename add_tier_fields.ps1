# PowerShell script to add tier fields to armor_sets.lua
# This script will:
# 1. Read the armor_sets.lua file
# 2. Find each armor set definition
# 3. Add tier = X field after display_name line
# 4. Write back the modified file

$filePath = "C:\MQ2\lua\yalm2\config\armor_sets.lua"
$content = Get-Content $filePath -Raw

# Create comprehensive tier mapping
$tierMap = @{
    'Celestrium' = 2; 'Damascite' = 4
    'Abstruse' = 5; 'Recondite' = 6; 'Ambiguous' = 7; 'Lucid' = 8
    'Enigmatic' = 5; 'Esoteric' = 6; 'Obscure' = 7; 'Perspicuous' = 8
    'Rustic' = 9; 'Formal' = 10; 'Embellished' = 11; 'Grandiose' = 12
    'Modest' = 9; 'Elegant of Oseka' = 10; 'Embellished of Kolos' = 11; 'Stately' = 12; 'Ostentatious' = 12
    'Boreal' = 1; 'Distorted' = 2; 'Twilight' = 3; 'Frightweave' = 4
    'Dread Touched' = 1; 'Dread Stained' = 2; 'Dread Washed' = 3; 'Dread Infused' = 4
    'Distorted Coeval' = 2; 'Distorted Eternal' = 2; 'Distorted Medial' = 2; 'Distorted Primeval' = 2
    'Latent Ether' = 17; 'Manifested Ether' = 18; 'Suppressed Ether' = 17; 'Flowing Ether' = 18
    'Castaway' = 19; 'Tideworn' = 20; 'Highwater' = 21; 'Darkwater' = 21
    'Crypt-Hunter' = 24; 'Deathseeker' = 24
    'Amorphous Cohort' = 25; 'Amorphous Selrach' = 26; 'Amorphous Velazul' = 26
    'Scale Touched' = 27; 'Scaled' = 28; 'Conflagrant' = 28; 'Phlogiston' = 29; 'Scaleborn' = 28
    'Weeping Undefeated Heaven' = 30; 'Battleworn Stalwart Moon' = 31; 'Adamant Triumphant Cloud' = 31
    'Veiled Victorious Horizon' = 31; 'Heavenly Glorious Void Binding' = 32
    'Icebound' = 34; 'Velium Infused' = 34; 'Ice Woven' = 34; 'Velium Empowered' = 35
    'Snowsquall' = 36; 'Blizzard' = 37; 'Velium Threaded' = 37; 'Hoarfrost' = 37; 'Velium Endowed' = 38
    'Luclinite Ensanguined' = 40; 'Luclinite Coagulated' = 41
    'Phantasmal Luclinite' = 43; 'Spectral Luclinite' = 44
    'Perpetual Reverie' = 46; 'Eternal Reverie' = 47
    'Enthralled' = 48; 'Shackled' = 49; 'Uprising' = 49; 'Bound' = 49; 'Rebellion' = 50
    'Unraveling Order' = 52; 'Resonant Fracture' = 53
}

Write-Host "Tier map has $($tierMap.Count) entries"

# Split into lines for processing
$lines = $content -split "`n"
$output = @()
$tierAdded = 0

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $output += $line
    
    # Look for display_name line that comes after a set name
    if ($line -match "^\s+display_name\s+=") {
        # Check if next line is already a tier field (skip if so)
        $nextLineIdx = $i + 1
        $nextLine = if ($nextLineIdx -lt $lines.Count) { $lines[$nextLineIdx] } else { '' }
        
        if ($nextLine -notmatch "^\s+tier\s+=") {
            # Find the armor set name by looking backwards
            $setName = $null
            for ($j = $i - 1; $j -ge [Math]::Max(0, $i - 5); $j--) {
                if ($lines[$j] -match "\['([^']+)'\]\s*=\s*\{") {
                    $setName = $matches[1]
                    break
                }
            }
            
            if ($setName -and $tierMap.ContainsKey($setName)) {
                $tier = $tierMap[$setName]
                # Get indentation from display_name line
                if ($line -match "^(\s+)display_name") {
                    $indent = $matches[1]
                    $output += "$indent" + "tier = $tier,"
                    $tierAdded++
                }
            }
        }
    }
}

# Write back to file
$output -join "`n" | Out-File $filePath -Encoding UTF8 -Force
Write-Host "Added $tierAdded tier fields to armor_sets.lua"
