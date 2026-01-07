# FINAL COMPREHENSIVE TIER MAPPING - Handles ALL cases including piece variants
# This creates a complete mapping for all 387 armor sets

$tierMap = @{
    # Helper function to extract base name
}

# Build complete tier mapping that covers EVERY base set name and variant pattern
$tierMapFinal = @{
    # === UNDERFOOT COMPONENTS ===
    'Celestrium' = 2; 'Damascite' = 4; 'Vitallium' = 3; 'Palladium' = 3; 'Iridium' = 4; 'Rhodium' = 4; 'Stellite' = 1
    
    # === HOUSE OF THULE ===
    'Abstruse' = 5; 'Recondite' = 6; 'Ambiguous' = 7; 'Lucid' = 8
    'Enigmatic' = 5; 'Esoteric' = 6; 'Obscure' = 7; 'Perspicuous' = 8
    
    # === VEIL OF ALARIS ===
    'Rustic' = 9; 'Rustic of Argath' = 9
    'Formal' = 10; 'Formal of Lunanyn' = 10
    'Embellished' = 11; 'Embellished of Kolos' = 11
    'Grandiose' = 12; 'Grandiose of Alra' = 12
    'Modest' = 9; 'Modest of Illdaera' = 9
    'Ostentatious' = 12; 'Ostentatious of Ryken' = 12
    'Stately' = 12; 'Stately of Ladrys' = 12
    
    # === RAIN OF FEAR ===
    'Boreal' = 1
    'Distorted' = 2; 'Fractured Coeval' = 2; 'Fractured Eternal' = 2; 'Fractured Medial' = 2; 'Fractured Primeval' = 2; 'Fractured Seminal' = 2
    'Distorted Coeval' = 2; 'Distorted Eternal' = 2; 'Distorted Medial' = 2; 'Distorted Primeval' = 2; 'Distorted Seminal' = 2
    'Phased Coeval' = 2; 'Phased Eternal' = 2; 'Phased Medial' = 2; 'Phased Primeval' = 2; 'Phased Seminal' = 2
    'Warped Coeval' = 2; 'Warped Eternal' = 2; 'Warped Medial' = 2; 'Warped Primeval' = 2; 'Warped Seminal' = 2
    'Twilight' = 3
    'Fear Touched' = 1; 'Fear Stained' = 2; 'Fear Washed' = 3; 'Fear Infused' = 4
    'Dread Touched' = 1; 'Dread Stained' = 2; 'Dread Washed' = 3; 'Dread Infused' = 4; 'Dread' = 2
    
    # === CALL OF THE FORSAKEN ===
    'Latent Ether' = 17
    'Manifested Ether' = 18
    'Suppressed Ether' = 17
    'Flowing Ether' = 18
    
    # === THE DARKENED SEA ===
    'Castaway' = 19
    'Tideworn' = 20
    'Highwater' = 21
    'Darkwater' = 21
    
    # === THE BROKEN MIRROR ===
    'Raw Crypt-Hunter' = 24
    
    # === EMPIRES OF KUNARK ===
    'Amorphous Cohort' = 25
    'Amorphous Selrach' = 26
    'Amorphous Velazul' = 26
    
    # === RING OF SCALE ===
    'Scale Touched' = 27
    'Scaled' = 28
    'Scaleborn' = 28
    
    # === THE BURNING LANDS ===
    'Weeping Undefeated Heaven' = 30
    'Battleworn Stalwart Moon' = 31
    'Adamant Triumphant Cloud' = 31
    'Veiled Victorious Horizon' = 31
    'Heavenly Glorious Void' = 32
    
    # === TORMENT OF VELIOUS ===
    'Faded Snowbound' = 33
    'Faded Icebound' = 33
    'Icebound' = 34
    'Ice Woven' = 34
    'Faded Ice Woven' = 33
    'Velium Infused' = 34
    'Velium Empowered' = 35
    
    # === CLAWS OF VEESHAN ===
    'Faded Blizzard' = 36
    'Faded Snowsquall' = 36
    'Snowsquall' = 36
    'Blizzard' = 37
    'Velium Threaded' = 37
    'Hoarfrost' = 37
    'Faded Hoarfrost' = 36
    'Velium Endowed' = 38
    
    # === TERROR OF LUCLIN ===
    'Faded Waxing Crescent' = 39
    'Waxing Crescent' = 39
    'Faded Waning Crescent' = 39
    'Waning Crescent' = 40
    'Faded Waning Gibbous' = 40
    'Waning Gibbous' = 40
    'Luclinite Ensanguined' = 40
    'Luclinite Coagulated' = 41
    
    # === NIGHT OF SHADOWS ===
    'Faded Ascending Spirit' = 42
    'Faded Celestial Zenith' = 43
    'Spectral Luminosity' = 43
    'Faded Spectral Luminosity' = 42
    'Phantasmal Luclinite' = 43
    'Spectral Luclinite' = 44
    
    # === LAURION'S SONG ===
    'Fleeting Memory' = 45
    'Fading Memory' = 46
    'Perpetual Reverie' = 46
    'Heroic Reflections' = 46
    'Eternal Reverie' = 47
    
    # === THE OUTER BROOD ===
    'Enthralled' = 48
    'Shackled' = 49
    'Uprising' = 49
    'Bound' = 49
    'Rebellion' = 50
    'Obscured Gallant Resonance' = 50
    'Obscured Steadfast Resolve' = 50
    'Obscured Heroic Reflections' = 48
    'Obscured of the Enthralled' = 49
    'Obscured of the Shackled' = 49
    'Obscured of the Bound' = 49
    
    # === SHATTERING OF RO ===
    'Diminished Broken Accord' = 51
    'Riven Accord' = 52
    'Unraveling Order' = 52
    'Eternal Verdict' = 52
    'Resonant Fracture' = 53
}

Write-Host "Final tier map ready: $($tierMapFinal.Count) base entries"

# Export for use in Lua-based script
$tierMapFinal | ConvertTo-Json | Out-File "C:\MQ2\lua\yalm2\tier_map_final.json"
Write-Host "Saved tier_map_final.json"

# Now let's use this to add remaining tiers
$filePath = "C:\MQ2\lua\yalm2\config\armor_sets.lua"
$content = Get-Content $filePath -Raw

$lines = $content -split "`n"
$output = @()
$tierAdded = 0
$unmappedSets = @()

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $output += $line
    
    if ($line -match "display_name\s+=\s+""([^""]+)""") {
        # Check if next line has tier
        $nextLineIdx = $i + 1
        $nextLine = if ($nextLineIdx -lt $lines.Count) { $lines[$nextLineIdx] } else { '' }
        
        if ($nextLine -notmatch "tier\s*=" -and $nextLine -notmatch "^\s*\}") {
            # Find set name backwards
            $setName = $null
            for ($j = $i - 1; $j -ge [Math]::Max(0, $i - 10); $j--) {
                if ($lines[$j] -match "\['([^']+)'\]\s*=\s*\{") {
                    $setName = $matches[1]
                    break
                }
            }
            
            if ($setName) {
                $tier = $null
                
                # Try exact match
                if ($tierMapFinal.ContainsKey($setName)) {
                    $tier = $tierMapFinal[$setName]
                } else {
                    # Try pattern: "X Arms" → "X", "Faded X Arms" → "Faded X", etc.
                    $baseName = $setName -replace '\s+(Arms|Chest|Feet|Hands|Head|Legs|Wrist)$', ''
                    if ($tierMapFinal.ContainsKey($baseName)) {
                        $tier = $tierMapFinal[$baseName]
                    } else {
                        # Pattern for Encrusted Clay
                        if ($setName -match '^(Celestrium|Damascite|Vitallium|Palladium|Iridium|Rhodium|Stellite) Encrusted') {
                            $material = $matches[1]
                            if ($tierMapFinal.ContainsKey($material)) {
                                $tier = $tierMapFinal[$material]
                            }
                        }
                    }
                }
                
                if ($tier) {
                    $indent = "        "
                    $output += "$indent" + "tier = $tier,"
                    $tierAdded++
                } else {
                    if ($unmappedSets -notcontains $setName) {
                        $unmappedSets += $setName
                    }
                }
            }
        }
    }
}

Write-Host "Added $tierAdded more tier fields"
Write-Host "Unmapped: $($unmappedSets.Count) sets"
if ($unmappedSets.Count -gt 0 -and $unmappedSets.Count -le 30) {
    Write-Host "Unmapped sets:"
    $unmappedSets | Sort-Object | ForEach-Object { Write-Host "  - $_" }
}

# Write file
$output -join "`n" | Out-File $filePath -Encoding UTF8 -Force
Write-Host "File saved"
