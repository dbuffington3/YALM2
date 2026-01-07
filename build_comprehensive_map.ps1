# Comprehensive tier mapping for all 380+ armor sets
# Based on PHASE_1_ARMOR_SET_TIER_MAPPING.md

$tierMapComprehensive = @{
    # === UNDERFOOT (Tier 2, 4) ===
    'Celestrium' = 2
    'Damascite' = 4
    
    # === HOUSE OF THULE (Tier 5-8) - Group (4) + Raid (4) ===
    'Abstruse' = 5
    'Recondite' = 6
    'Ambiguous' = 7
    'Lucid' = 8
    'Enigmatic' = 5
    'Esoteric' = 6
    'Obscure' = 7
    'Perspicuous' = 8
    
    # === VEIL OF ALARIS (Tier 9-12) - Group (4) + Raid (4) ===
    'Rustic' = 9
    'Formal' = 10
    'Embellished' = 11
    'Grandiose' = 12
    'Modest' = 9
    'Elegant of Oseka' = 10
    'Embellished of Kolos' = 11
    'Stately' = 12
    'Ostentatious' = 12
    
    # === RAIN OF FEAR (Tier 1-4) - Group (4) + Raid (4) ===
    'Boreal' = 1
    'Distorted' = 2
    'Twilight' = 3
    'Frightweave' = 4
    'Dread Touched' = 1
    'Dread Stained' = 2
    'Dread Washed' = 3
    'Dread Infused' = 4
    
    # Component items from Rain of Fear (Tier 2)
    'Distorted Coeval' = 2
    'Distorted Eternal' = 2
    'Distorted Medial' = 2
    'Distorted Primeval' = 2
    
    # === CALL OF THE FORSAKEN (Tier 17-18) - Group (2) + Raid (2) ===
    'Latent Ether' = 17
    'Manifested Ether' = 18
    'Suppressed Ether' = 17
    'Flowing Ether' = 18
    
    # === THE DARKENED SEA (Tier 19-21) - Group (3) + Raid (1) ===
    'Castaway' = 19
    'Tideworn' = 20
    'Highwater' = 21
    'Darkwater' = 21
    
    # === THE BROKEN MIRROR (Tier 22-24) - Group (3) + Raid (1) ===
    'Crypt-Hunter' = 24
    'Deathseeker' = 24
    
    # === EMPIRES OF KUNARK (Tier 25-26) - Group (2) + Raid (1) ===
    'Amorphous Cohort' = 25
    'Amorphous Selrach' = 26
    'Amorphous Velazul' = 26
    
    # === RING OF SCALE (Tier 27-29) - Group (2 + TS) + Raid (1 + TS) ===
    'Scale Touched' = 27
    'Scaled' = 28
    'Conflagrant' = 28
    'Phlogiston' = 29
    'Scaleborn' = 28
    
    # === THE BURNING LANDS (Tier 30-32) - Group (2 + TS) + Raid (1 + TS) ===
    'Weeping Undefeated Heaven' = 30
    'Battleworn Stalwart Moon' = 31
    'Adamant Triumphant Cloud' = 31
    'Veiled Victorious Horizon' = 31
    'Heavenly Glorious Void Binding' = 32
    
    # === TORMENT OF VELIOUS (Tier 33-35) - Similar pattern ===
    'Icebound' = 34
    'Velium Infused' = 34
    'Ice Woven' = 34
    'Velium Empowered' = 35
    
    # === CLAWS OF VEESHAN (Tier 36-38) ===
    'Snowsquall' = 36
    'Blizzard' = 37
    'Velium Threaded' = 37
    'Hoarfrost' = 37
    'Velium Endowed' = 38
    
    # === TERROR OF LUCLIN (Tier 39-41) ===
    'Luclinite Ensanguined' = 40
    'Luclinite Coagulated' = 41
    
    # === NIGHT OF SHADOWS (Tier 42-44) ===
    'Phantasmal Luclinite' = 43
    'Spectral Luclinite' = 44
    
    # === LAURION'S SONG (Tier 45-47) ===
    'Perpetual Reverie' = 46
    'Eternal Reverie' = 47
    
    # === THE OUTER BROOD (Tier 48-50) ===
    'Enthralled' = 48
    'Shackled' = 49
    'Uprising' = 49
    'Bound' = 49
    'Rebellion' = 50
    
    # === SHATTERING OF RO (Tier 51-53) ===
    'Unraveling Order' = 52
    'Resonant Fracture' = 53
}

Write-Host "Comprehensive tier map: $($tierMapComprehensive.Count) entries"
$tierMapComprehensive | ConvertTo-Json | Out-File "C:\MQ2\lua\yalm2\comprehensive_tier_map.json"
Write-Host "Saved to comprehensive_tier_map.json"
