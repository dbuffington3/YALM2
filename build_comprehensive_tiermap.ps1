# Enhanced tier mapping for component items, variants, and special cases

$tierMap = @{
    # === UNDERFOOT (Clay - Tier 1-4) ===
    # Main armor sets
    'Celestrium' = 2; 'Damascite' = 4; 'Vitallium' = 3; 'Palladium' = 3; 'Iridium' = 4; 'Rhodium' = 4; 'Stellite' = 1
    
    # === HOUSE OF THULE (Tier 5-8) ===
    'Abstruse' = 5; 'Recondite' = 6; 'Ambiguous' = 7; 'Lucid' = 8
    'Enigmatic' = 5; 'Esoteric' = 6; 'Obscure' = 7; 'Perspicuous' = 8
    
    # === VEIL OF ALARIS (Tier 9-12) ===
    'Rustic' = 9; 'Formal' = 10; 'Embellished' = 11; 'Grandiose' = 12
    'Modest' = 9; 'Elegant of Oseka' = 10; 'Embellished of Kolos' = 11; 'Stately' = 12; 'Ostentatious' = 12
    
    # Regional variants of VOA
    'Rustic of Argath' = 9; 'Formal of Lunanyn' = 10; 'Grandiose of Alra' = 12; 'Modest of Illdaera' = 9; 'Ostentatious of Ryken' = 12; 'Stately of Ladrys' = 12
    
    # === RAIN OF FEAR (Tier 1-4) ===
    'Boreal' = 1; 'Distorted' = 2; 'Twilight' = 3; 'Frightweave' = 4
    'Dread Touched' = 1; 'Dread Stained' = 2; 'Dread Washed' = 3; 'Dread Infused' = 4; 'Dread' = 2
    
    # Distorted variants (component items - all tier 2)
    'Distorted Coeval' = 2; 'Distorted Eternal' = 2; 'Distorted Medial' = 2; 'Distorted Primeval' = 2; 'Distorted Seminal' = 2
    'Fractured Coeval' = 2; 'Fractured Eternal' = 2; 'Fractured Medial' = 2; 'Fractured Primeval' = 2; 'Fractured Seminal' = 2
    'Phased Coeval' = 2; 'Phased Eternal' = 2; 'Phased Medial' = 2; 'Phased Primeval' = 2; 'Phased Seminal' = 2
    'Warped Coeval' = 2; 'Warped Eternal' = 2; 'Warped Medial' = 2; 'Warped Primeval' = 2; 'Warped Seminal' = 2
    
    # === CALL OF THE FORSAKEN (Tier 17-18) ===
    'Latent Ether' = 17; 'Manifested Ether' = 18; 'Suppressed Ether' = 17; 'Flowing Ether' = 18
    
    # === THE DARKENED SEA (Tier 19-21) ===
    'Castaway' = 19; 'Tideworn' = 20; 'Highwater' = 21; 'Darkwater' = 21
    
    # === THE BROKEN MIRROR (Tier 22-24) ===
    'Crypt-Hunter' = 24; 'Deathseeker' = 24; 'Raw Crypt-Hunter' = 24
    
    # === EMPIRES OF KUNARK (Tier 25-26) ===
    'Amorphous Cohort' = 25; 'Amorphous Selrach' = 26; 'Amorphous Velazul' = 26
    
    # === RING OF SCALE (Tier 27-29) ===
    'Scale Touched' = 27; 'Scaled' = 28; 'Conflagrant' = 28; 'Phlogiston' = 29; 'Scaleborn' = 28
    
    # === THE BURNING LANDS (Tier 30-32) ===
    'Weeping Undefeated Heaven' = 30; 'Battleworn Stalwart Moon' = 31; 'Adamant Triumphant Cloud' = 31
    'Veiled Victorious Horizon' = 31; 'Heavenly Glorious Void' = 32; 'Heavenly Glorious Void Binding' = 32
    
    # === TORMENT OF VELIOUS (Tier 33-35) ===
    'Faded Snowbound' = 33; 'Icebound' = 34; 'Velium Infused' = 34; 'Ice Woven' = 34; 'Velium Empowered' = 35
    'Faded Icebound' = 33; 'Faded Ice Woven' = 33
    
    # === CLAWS OF VEESHAN (Tier 36-38) ===
    'Faded Blizzard' = 36; 'Snowsquall' = 36; 'Blizzard' = 37; 'Velium Threaded' = 37; 'Hoarfrost' = 37; 'Velium Endowed' = 38
    'Faded Snowsquall' = 36; 'Faded Hoarfrost' = 36
    
    # === TERROR OF LUCLIN (Tier 39-41) ===
    'Faded Waxing Crescent' = 39; 'Waxing Crescent' = 39; 'Faded Waning Crescent' = 39; 'Waning Crescent' = 40
    'Faded Waning Gibbous' = 40; 'Waning Gibbous' = 40; 'Luclinite Ensanguined' = 40; 'Luclinite Coagulated' = 41
    
    # === NIGHT OF SHADOWS (Tier 42-44) ===
    'Faded Ascending Spirit' = 42; 'Faded Celestial Zenith' = 43; 'Spectral Luminosity' = 43; 'Faded Spectral Luminosity' = 42
    'Phantasmal Luclinite' = 43; 'Spectral Luclinite' = 44
    
    # === LAURION'S SONG (Tier 45-47) ===
    'Fleeting Memory' = 45; 'Fading Memory' = 46; 'Perpetual Reverie' = 46; 'Heroic Reflections' = 46; 'Eternal Reverie' = 47
    
    # === THE OUTER BROOD (Tier 48-50) ===
    'Enthralled' = 48; 'Shackled' = 49; 'Uprising' = 49; 'Bound' = 49; 'Rebellion' = 50
    'Obscured of the Enthralled' = 49; 'Obscured of the Shackled' = 49; 'Obscured of the Bound' = 49
    
    # === SHATTERING OF RO (Tier 51-53) ===
    'Diminished Broken Accord' = 51; 'Riven Accord' = 52; 'Unraveling Order' = 52; 'Eternal Verdict' = 52; 'Resonant Fracture' = 53
    
    # Special/raid variants
    'Obscured Gallant Resonance' = 50
    'Obscured Steadfast Resolve' = 50
    'Obscured Heroic Reflections' = 48
    
    # Helper entries for Fear Touched quest items
    'Fear Touched' = 1; 'Fear Stained' = 2; 'Fear Washed' = 3; 'Fear Infused' = 4
}

Write-Host "Comprehensive tier map ready with $($tierMap.Count) entries"
$tierMap | ConvertTo-Json | Out-File "C:\MQ2\lua\yalm2\comprehensive_tiermap.json"
