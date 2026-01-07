# Enhanced script to add tier fields to ALL armor sets
# Handles both grouped and individual piece entries

$filePath = "C:\MQ2\lua\yalm2\config\armor_sets.lua"
$content = Get-Content $filePath -Raw

# Create a function to extract base set name from piece names
function Get-BaseSetName($name) {
    if ($name -match '(.*?)\s+(Arms|Chest|Feet|Hands|Head|Legs|Wrist)$') {
        return $matches[1]
    }
    return $name
}

# Create comprehensive tier mapping
$tierMap = @{
    # Underfoot
    'Celestrium' = 2; 'Damascite' = 4
    
    # House of Thule
    'Abstruse' = 5; 'Recondite' = 6; 'Ambiguous' = 7; 'Lucid' = 8
    'Enigmatic' = 5; 'Esoteric' = 6; 'Obscure' = 7; 'Perspicuous' = 8
    
    # Veil of Alaris
    'Rustic' = 9; 'Formal' = 10; 'Embellished' = 11; 'Grandiose' = 12
    'Modest' = 9; 'Elegant of Oseka' = 10; 'Embellished of Kolos' = 11; 'Stately' = 12; 'Ostentatious' = 12
    
    # Rain of Fear
    'Boreal' = 1; 'Distorted' = 2; 'Twilight' = 3; 'Frightweave' = 4
    'Dread Touched' = 1; 'Dread Stained' = 2; 'Dread Washed' = 3; 'Dread Infused' = 4; 'Dread' = 2
    'Distorted Coeval' = 2; 'Distorted Eternal' = 2; 'Distorted Medial' = 2; 'Distorted Primeval' = 2; 'Distorted Seminal' = 2
    
    # Call of the Forsaken
    'Latent Ether' = 17; 'Manifested Ether' = 18; 'Suppressed Ether' = 17; 'Flowing Ether' = 18
    
    # The Darkened Sea
    'Castaway' = 19; 'Tideworn' = 20; 'Highwater' = 21; 'Darkwater' = 21
    
    # The Broken Mirror
    'Crypt-Hunter' = 24; 'Deathseeker' = 24
    
    # Empires of Kunark
    'Amorphous Cohort' = 25; 'Amorphous Selrach' = 26; 'Amorphous Velazul' = 26
    
    # Ring of Scale
    'Scale Touched' = 27; 'Scaled' = 28; 'Conflagrant' = 28; 'Phlogiston' = 29; 'Scaleborn' = 28
    
    # The Burning Lands
    'Weeping Undefeated Heaven' = 30; 'Battleworn Stalwart Moon' = 31; 'Adamant Triumphant Cloud' = 31
    'Veiled Victorious Horizon' = 31; 'Heavenly Glorious Void Binding' = 32
    
    # Torment of Velious
    'Icebound' = 34; 'Velium Infused' = 34; 'Ice Woven' = 34; 'Velium Empowered' = 35
    'Faded Snowbound' = 33
    
    # Claws of Veeshan
    'Snowsquall' = 36; 'Blizzard' = 37; 'Velium Threaded' = 37; 'Hoarfrost' = 37; 'Velium Endowed' = 38
    'Faded Blizzard' = 36
    
    # Terror of Luclin
    'Luclinite Ensanguined' = 40; 'Luclinite Coagulated' = 41
    'Waxing Crescent' = 39; 'Waning Crescent' = 40; 'Waning Gibbous' = 40
    
    # Night of Shadows
    'Phantasmal Luclinite' = 43; 'Spectral Luclinite' = 44
    'Faded Ascending Spirit' = 42; 'Faded Celestial Zenith' = 43; 'Spectral Luminosity' = 43
    
    # Laurion's Song
    'Perpetual Reverie' = 46; 'Eternal Reverie' = 47
    'Fleeting Memory' = 45; 'Fading Memory' = 46; 'Heroic Reflections' = 46
    
    # The Outer Brood
    'Enthralled' = 48; 'Shackled' = 49; 'Uprising' = 49; 'Bound' = 49; 'Rebellion' = 50
    
    # Shattering of Ro
    'Unraveling Order' = 52; 'Resonant Fracture' = 53
    'Diminished Broken Accord' = 51; 'Riven Accord' = 52; 'Eternal Verdict' = 52
}

Write-Host "Tier map entries: $($tierMap.Count)"

# Split and process
$lines = $content -split "`n"
$output = @()
$tierAdded = 0
$setsSeen = @{}

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $output += $line
    
    # Look for display_name line
    if ($line -match "display_name\s+=\s+""([^""]+)""") {
        $displayName = $matches[1]
        
        # Check if next line already has tier field
        $nextLineIdx = $i + 1
        $nextLine = if ($nextLineIdx -lt $lines.Count) { $lines[$nextLineIdx] } else { '' }
        
        if ($nextLine -notmatch "tier\s*=" -and $nextLine -notmatch "^\s*\}") {
            # Find which set this belongs to by looking backwards
            $setName = $null
            for ($j = $i - 1; $j -ge [Math]::Max(0, $i - 10); $j--) {
                if ($lines[$j] -match "\['([^']+)'\]\s*=\s*\{") {
                    $setName = $matches[1]
                    break
                }
            }
            
            if ($setName) {
                # Try exact match first
                $tier = $null
                if ($tierMap.ContainsKey($setName)) {
                    $tier = $tierMap[$setName]
                } else {
                    # Try base set name (for piece variants)
                    $baseName = Get-BaseSetName $setName
                    if ($tierMap.ContainsKey($baseName)) {
                        $tier = $tierMap[$baseName]
                    }
                }
                
                if ($tier) {
                    $indent = "        "
                    $output += "$indent" + "tier = $tier,"
                    $tierAdded++
                    $setsSeen[$setName] = $true
                } else {
                    Write-Host "WARNING: No tier found for: $setName"
                }
            }
        }
    }
}

Write-Host "Added $tierAdded tier fields"
Write-Host "Unique sets processed: $($setsSeen.Count)"

# Write back
$output -join "`n" | Out-File $filePath -Encoding UTF8 -Force
Write-Host "File updated"
