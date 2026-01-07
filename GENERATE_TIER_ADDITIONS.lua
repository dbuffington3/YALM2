-- This script generates the tier additions for armor_sets.lua
-- Run this in YALM2 context to see what needs to be added
-- Maps armor set names to their tier values

local tier_mappings = {
    -- Underfoot (Tier 2, 4)
    ['Celestrium'] = 2,
    ['Damascite'] = 4,
    
    -- House of Thule (Tier 5-8)
    ['Abstruse'] = 5,
    ['Recondite'] = 6,
    ['Ambiguous'] = 7,
    ['Lucid'] = 8,
    ['Enigmatic'] = 5,
    ['Esoteric'] = 6,
    ['Obscure'] = 7,
    ['Perspicuous'] = 8,
    
    -- Veil of Alaris (Tier 9-12)
    ['Rustic'] = 9,
    ['Formal'] = 10,
    ['Embellished'] = 11,
    ['Grandiose'] = 12,
    ['Modest'] = 9,
    ['Elegant of Oseka'] = 10,
    ['Embellished of Kolos'] = 11,
    ['Stately'] = 12,
    ['Ostentatious'] = 12,
    
    -- Rain of Fear (Tier 1-4)
    ['Boreal'] = 1,
    ['Distorted'] = 2,
    ['Twilight'] = 3,
    ['Frightweave'] = 4,
    ['Dread Touched'] = 1,
    ['Dread Stained'] = 2,
    ['Dread Washed'] = 3,
    ['Dread Infused'] = 4,
    
    -- Component items from Rain of Fear (all tier 2)
    ['Distorted Coeval'] = 2,
    ['Distorted Eternal'] = 2,
    ['Distorted Medial'] = 2,
    ['Distorted Primeval'] = 2,
    
    -- Call of the Forsaken (Tier 17-18)
    ['Latent Ether'] = 17,
    ['Manifested Ether'] = 18,
    ['Suppressed Ether'] = 17,
    ['Flowing Ether'] = 18,
    
    -- The Darkened Sea (Tier 19-21)
    ['Castaway'] = 19,
    ['Tideworn'] = 20,
    ['Highwater'] = 21,
    ['Darkwater'] = 21,
    
    -- The Broken Mirror (Tier 22-24)
    ['Crypt-Hunter'] = 24,
    ['Deathseeker'] = 24,
    
    -- Empires of Kunark (Tier 25-26)
    ['Amorphous Cohort'] = 25,
    ['Amorphous Selrach'] = 26,
    ['Amorphous Velazul'] = 26,
    
    -- Ring of Scale (Tier 27-29)
    ['Scale Touched'] = 27,
    ['Scaled'] = 28,
    ['Conflagrant'] = 28,
    ['Phlogiston'] = 29,
    ['Scaleborn'] = 28,
    
    -- The Burning Lands (Tier 30-32)
    ['Weeping Undefeated Heaven'] = 30,
    ['Battleworn Stalwart Moon'] = 31,
    ['Adamant Triumphant Cloud'] = 31,
    ['Veiled Victorious Horizon'] = 31,
    ['Heavenly Glorious Void Binding'] = 32,
    
    -- Torment of Velious (Tier 33-35)
    ['Icebound'] = 34,
    ['Velium Infused'] = 34,
    ['Ice Woven'] = 34,
    ['Velium Empowered'] = 35,
    
    -- Claws of Veeshan (Tier 36-38)
    ['Snowsquall'] = 36,
    ['Blizzard'] = 37,
    ['Velium Threaded'] = 37,
    ['Hoarfrost'] = 37,
    ['Velium Endowed'] = 38,
    
    -- Terror of Luclin (Tier 39-41)
    ['Luclinite Ensanguined'] = 40,
    ['Luclinite Coagulated'] = 41,
    
    -- Night of Shadows (Tier 42-44)
    ['Phantasmal Luclinite'] = 43,
    ['Spectral Luclinite'] = 44,
    
    -- Laurion's Song (Tier 45-47)
    ['Perpetual Reverie'] = 46,
    ['Eternal Reverie'] = 47,
    
    -- The Outer Brood (Tier 48-50)
    ['Enthralled'] = 48,
    ['Shackled'] = 49,
    ['Uprising'] = 49,
    ['Bound'] = 49,
    ['Rebellion'] = 50,
    
    -- Shattering of Ro (Tier 51-53)
    ['Unraveling Order'] = 52,
    ['Resonant Fracture'] = 53,
}

return tier_mappings
