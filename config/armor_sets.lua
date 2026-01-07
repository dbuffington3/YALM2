--[[
    Equipment Distribution Configuration
    
    Defines all armor sets that use equipment-aware distribution logic.
    Each set can have multiple piece types (e.g., Wrist, Chest, etc.)
    
    Structure:
    {
        ['ArmorSetName'] = {
            display_name = "Human-readable name",  -- For logging
            pieces = {
                ['PieceName'] = {
                    slots = {slot_numbers},        -- Equipment slots (e.g., {9, 10})
                    remnant_name = "Item Name",    -- Name of crafting material
                    remnant_id = 12345,            -- Item ID of crafting material
                    max_slots = 2,                 -- Max slots for this piece
                }
            }
        }
    }
]]

-- ============================================================================
-- ARMOR PROGRESSION CHAIN
-- ============================================================================
-- Defines combine recipes and tier progression for armor sets
-- Combine recipes:
--   Fear Touched â†’ Boreal (no secondary material needed)
--   Boreal + Fear Stained â†’ Distorted
--   Distorted + Fear Washed â†’ Twilight
--   Twilight + Fear Infused â†’ Frightweave
--
-- Tier numbering represents progression level (higher = better equipment)
-- When distributing a crafting material, exclude candidates with equal/higher tier equipped
local ARMOR_PROGRESSION = {
    -- DEFIANT ARMOR PROGRESSION (tier 1-8)
    -- Dropped armor that scales with level, no crafting progression
    ['Crude Defiant'] = {
        creates = nil,
        tier = 1,
        secondary = nil
    },
    ['Rough Defiant'] = {
        creates = nil,
        tier = 2,
        secondary = nil
    },
    ['Simple Defiant'] = {
        creates = nil,
        tier = 3,
        secondary = nil
    },
    ['Flawed Defiant'] = {
        creates = nil,
        tier = 4,
        secondary = nil
    },
    ['Elaborate Defiant'] = {
        creates = nil,
        tier = 5,
        secondary = nil
    },
    ['Intricate Defiant'] = {
        creates = nil,
        tier = 6,
        secondary = nil
    },
    ['Ornate Defiant'] = {
        creates = nil,
        tier = 7,
        secondary = nil
    },
    ['Elegant Defiant'] = {
        creates = nil,
        tier = 8,
        secondary = nil
    },
    -- FEAR AND BEYOND PROGRESSION (tier 18-21)
    ['Fear Touched'] = {
        creates = 'Boreal',
        tier = 18,
        secondary = nil  -- Fear Touched combines alone
    },
    ['Boreal'] = {
        creates = 'Distorted',
        tier = 19,
        secondary = 'Fear Stained'  -- Boreal + Fear Stained â†’ Distorted
    },
    ['Fear Stained'] = {
        creates = 'Distorted',
        tier = 19,
        secondary = 'Boreal'  -- Fear Stained + Boreal â†’ Distorted
    },
    ['Distorted'] = {
        creates = 'Twilight',
        tier = 20,
        secondary = 'Fear Washed'  -- Distorted + Fear Washed â†’ Twilight
    },
    ['Fear Washed'] = {
        creates = 'Twilight',
        tier = 20,
        secondary = 'Distorted'  -- Fear Washed + Distorted â†’ Twilight
    },
    ['Twilight'] = {
        creates = 'Frightweave',
        tier = 21,
        secondary = 'Fear Infused'  -- Twilight + Fear Infused â†’ Frightweave
    },
    ['Fear Infused'] = {
        creates = 'Frightweave',
        tier = 21,
        secondary = 'Twilight'  -- Fear Infused + Twilight â†’ Frightweave
    },
    -- HOUSE OF THULE PROGRESSION (tier 10-13)
    ['Abstruse'] = {
        creates = 'Recondite',
        tier = 10,
        secondary = nil  -- Drops alone, tier 1 HoT
    },
    ['Recondite'] = {
        creates = 'Ambiguous',
        tier = 11,
        secondary = 'Recondite Coalescing Agent'  -- Agent required for T2
    },
    ['Ambiguous'] = {
        creates = 'Lucid',
        tier = 12,
        secondary = 'Ambiguous Coalescing Agent'  -- Agent required for T3
    },
    ['Lucid'] = {
        creates = nil,  -- Lucid is T4, no progression beyond
        tier = 13,
        secondary = 'Lucid Coalescing Agent'  -- Agent required for T4
    },
    -- VEIL OF ALARIS PROGRESSION (tier 14-17)
    ['Rustic'] = {
        creates = 'Formal',
        tier = 14,
        secondary = nil  -- Tier 1 VOA
    },
    ['Formal'] = {
        creates = 'Embellished',
        tier = 15,
        secondary = 'Plain Unadorned Template'  -- Template + wrap required
    },
    ['Embellished'] = {
        creates = 'Grandiose',
        tier = 16,
        secondary = 'Detailed Unadorned Template'  -- Template + wrap required
    },
    ['Grandiose'] = {
        creates = nil,  -- Grandiose is T4, no progression beyond
        tier = 17,
        secondary = 'Sophisticated Unadorned Template'  -- Template + wrap required
    },
}

local armor_sets = {
    -- DEFIANT ARMOR (Tier 1-8)
    -- Dropped armor with 4 types: Plate, Chain, Leather, Cloth
    -- No crafting/remnants - purely dropped gear
    ['Crude Defiant'] = {
        display_name = "Crude Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Rough Defiant'] = {
        display_name = "Rough Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Simple Defiant'] = {
        display_name = "Simple Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Flawed Defiant'] = {
        display_name = "Flawed Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Elaborate Defiant'] = {
        display_name = "Elaborate Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Intricate Defiant'] = {
        display_name = "Intricate Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Ornate Defiant'] = {
        display_name = "Ornate Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Elegant Defiant'] = {
        display_name = "Elegant Defiant Armor",
        pieces = {
            ['Head'] = { slots = { 2 }, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, max_slots = 1 },
            ['Primary'] = { slots = { 13 }, max_slots = 1 },
            ['Secondary'] = { slots = { 14 }, max_slots = 1 },
            ['Ranged'] = { slots = { 11 }, max_slots = 1 },
        }
    },
    ['Recondite'] = {
        display_name = "Recondite Armor",
        tier = 11,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Recondite Remnant of Truth',
                remnant_id = 56186,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Recondite Remnant of Desire',
                remnant_id = 56192,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Recondite Remnant of Devotion',
                remnant_id = 56190,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Recondite Remnant of Fear',
                remnant_id = 56191,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Recondite Remnant of Knowledge',
                remnant_id = 56189,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Recondite Remnant of Greed',
                remnant_id = 56187,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Recondite Remnant of Survival',
                remnant_id = 56188,
                max_slots = 1,
            },
        }
    },

    ['Lucid'] = {
        display_name = "Lucid Armor",
        tier = 13,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Lucid Remnant of Truth',
                remnant_id = 56200,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Lucid Remnant of Desire',
                remnant_id = 56206,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Lucid Remnant of Devotion',
                remnant_id = 56204,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Lucid Remnant of Fear',
                remnant_id = 56205,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Lucid Remnant of Knowledge',
                remnant_id = 56203,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Lucid Remnant of Greed',
                remnant_id = 56201,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Lucid Remnant of Survival',
                remnant_id = 56202,
                max_slots = 1,
            },
        }
    },

    ['Abstruse'] = {
        display_name = "Abstruse Armor",
        tier = 10,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Abstruse Remnant of Truth',
                remnant_id = 56179,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Abstruse Remnant of Desire',
                remnant_id = 56185,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Abstruse Remnant of Devotion',
                remnant_id = 56183,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Abstruse Remnant of Fear',
                remnant_id = 56184,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Abstruse Remnant of Knowledge',
                remnant_id = 56182,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Abstruse Remnant of Greed',
                remnant_id = 56180,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Abstruse Remnant of Survival',
                remnant_id = 56181,
                max_slots = 1,
            },
        }
    },

    ['Ambiguous'] = {
        display_name = "Ambiguous Armor",
        tier = 12,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Ambiguous Remnant of Truth',
                remnant_id = 56193,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Ambiguous Remnant of Desire',
                remnant_id = 56199,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Ambiguous Remnant of Devotion',
                remnant_id = 56197,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Ambiguous Remnant of Fear',
                remnant_id = 56198,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Ambiguous Remnant of Knowledge',
                remnant_id = 56196,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Ambiguous Remnant of Greed',
                remnant_id = 56194,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Ambiguous Remnant of Survival',
                remnant_id = 56195,
                max_slots = 1,
            },
        }
    },

    ['Enigmatic'] = {
        display_name = "Enigmatic Armor",
        tier = 10,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Enigmatic Remnant of Truth',
                remnant_id = 56207,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Enigmatic Remnant of Desire',
                remnant_id = 56213,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Enigmatic Remnant of Devotion',
                remnant_id = 56211,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Enigmatic Remnant of Fear',
                remnant_id = 56212,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Enigmatic Remnant of Knowledge',
                remnant_id = 56210,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Enigmatic Remnant of Greed',
                remnant_id = 56208,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Enigmatic Remnant of Survival',
                remnant_id = 56209,
                max_slots = 1,
            },
        }
    },

    ['Esoteric'] = {
        display_name = "Esoteric Armor",
        tier = 11,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Esoteric Remnant of Truth',
                remnant_id = 56214,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Esoteric Remnant of Desire',
                remnant_id = 56220,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Esoteric Remnant of Devotion',
                remnant_id = 56218,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Esoteric Remnant of Fear',
                remnant_id = 56219,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Esoteric Remnant of Knowledge',
                remnant_id = 56217,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Esoteric Remnant of Greed',
                remnant_id = 56215,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Esoteric Remnant of Survival',
                remnant_id = 56216,
                max_slots = 1,
            },
        }
    },

    ['Obscure'] = {
        display_name = "Obscure Armor",
        tier = 12,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Obscure Remnant of Truth',
                remnant_id = 56221,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Obscure Remnant of Desire',
                remnant_id = 56227,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Obscure Remnant of Devotion',
                remnant_id = 56225,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Obscure Remnant of Fear',
                remnant_id = 56226,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Obscure Remnant of Knowledge',
                remnant_id = 56224,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Obscure Remnant of Greed',
                remnant_id = 56222,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Obscure Remnant of Survival',
                remnant_id = 56223,
                max_slots = 1,
            },
        }
    },

    ['Perspicuous'] = {
        display_name = "Perspicuous Armor",
        tier = 13,
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Perspicuous Remnant of Truth',
                remnant_id = 56228,
                max_slots = 2,
            },
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Perspicuous Remnant of Desire',
                remnant_id = 56234,
                max_slots = 1,
            },
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Perspicuous Remnant of Devotion',
                remnant_id = 56232,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Perspicuous Remnant of Fear',
                remnant_id = 56233,
                max_slots = 1,
            },
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Perspicuous Remnant of Knowledge',
                remnant_id = 56231,
                max_slots = 1,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Perspicuous Remnant of Greed',
                remnant_id = 56229,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Perspicuous Remnant of Survival',
                remnant_id = 56230,
                max_slots = 1,
            },
        }
    },
    
    -- ===== LUMINESSENCE ARMOR SETS (20 sets: 4 variants Ã— 5 tiers) =====
    ['Distorted Coeval Luminessence'] = {
        display_name = "Distorted Coeval Luminessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Coeval Luminessence',
                remnant_id = 103035,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Coeval Luminessence',
                remnant_id = 103035,
                max_slots = 1,
            },
        }
    },
    ['Distorted Eternal Luminessence'] = {
        display_name = "Distorted Eternal Luminessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Eternal Luminessence',
                remnant_id = 103019,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Eternal Luminessence',
                remnant_id = 103019,
                max_slots = 1,
            },
        }
    },
    ['Distorted Medial Luminessence'] = {
        display_name = "Distorted Medial Luminessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Medial Luminessence',
                remnant_id = 103011,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Medial Luminessence',
                remnant_id = 103011,
                max_slots = 1,
            },
        }
    },
    ['Distorted Primeval Luminessence'] = {
        display_name = "Distorted Primeval Luminessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Primeval Luminessence',
                remnant_id = 103027,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Primeval Luminessence',
                remnant_id = 103027,
                max_slots = 1,
            },
        }
    },
    ['Distorted Seminal Luminessence'] = {
        display_name = "Distorted Seminal Luminessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Seminal Luminessence',
                remnant_id = 103003,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Seminal Luminessence',
                remnant_id = 103003,
                max_slots = 1,
            },
        }
    },
    
    ['Fractured Coeval Luminessence'] = {
        display_name = "Fractured Coeval Luminessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Coeval Luminessence',
                remnant_id = 103033,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Coeval Luminessence',
                remnant_id = 103033,
                max_slots = 1,
            },
        }
    },
    ['Fractured Eternal Luminessence'] = {
        display_name = "Fractured Eternal Luminessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Eternal Luminessence',
                remnant_id = 103017,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Eternal Luminessence',
                remnant_id = 103017,
                max_slots = 1,
            },
        }
    },
    ['Fractured Medial Luminessence'] = {
        display_name = "Fractured Medial Luminessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Medial Luminessence',
                remnant_id = 103009,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Medial Luminessence',
                remnant_id = 103009,
                max_slots = 1,
            },
        }
    },
    ['Fractured Primeval Luminessence'] = {
        display_name = "Fractured Primeval Luminessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Primeval Luminessence',
                remnant_id = 103025,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Primeval Luminessence',
                remnant_id = 103025,
                max_slots = 1,
            },
        }
    },
    ['Fractured Seminal Luminessence'] = {
        display_name = "Fractured Seminal Luminessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Seminal Luminessence',
                remnant_id = 103001,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Seminal Luminessence',
                remnant_id = 103001,
                max_slots = 1,
            },
        }
    },
    
    ['Phased Coeval Luminessence'] = {
        display_name = "Phased Coeval Luminessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Coeval Luminessence',
                remnant_id = 103036,
                max_slots = 1,
            },
        }
    },
    ['Phased Eternal Luminessence'] = {
        display_name = "Phased Eternal Luminessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Eternal Luminessence',
                remnant_id = 103020,
                max_slots = 1,
            },
        }
    },
    ['Phased Medial Luminessence'] = {
        display_name = "Phased Medial Luminessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Medial Luminessence',
                remnant_id = 103012,
                max_slots = 1,
            },
        }
    },
    ['Phased Primeval Luminessence'] = {
        display_name = "Phased Primeval Luminessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Primeval Luminessence',
                remnant_id = 103028,
                max_slots = 1,
            },
        }
    },
    ['Phased Seminal Luminessence'] = {
        display_name = "Phased Seminal Luminessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Seminal Luminessence',
                remnant_id = 103004,
                max_slots = 1,
            },
        }
    },
    
    ['Warped Coeval Luminessence'] = {
        display_name = "Warped Coeval Luminessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Coeval Luminessence',
                remnant_id = 103034,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Coeval Luminessence',
                remnant_id = 103034,
                max_slots = 1,
            },
        }
    },
    ['Warped Eternal Luminessence'] = {
        display_name = "Warped Eternal Luminessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Eternal Luminessence',
                remnant_id = 103018,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Eternal Luminessence',
                remnant_id = 103018,
                max_slots = 1,
            },
        }
    },
    ['Warped Medial Luminessence'] = {
        display_name = "Warped Medial Luminessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Medial Luminessence',
                remnant_id = 103010,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Medial Luminessence',
                remnant_id = 103010,
                max_slots = 1,
            },
        }
    },
    ['Warped Primeval Luminessence'] = {
        display_name = "Warped Primeval Luminessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Primeval Luminessence',
                remnant_id = 103026,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Primeval Luminessence',
                remnant_id = 103026,
                max_slots = 1,
            },
        }
    },
    ['Warped Seminal Luminessence'] = {
        display_name = "Warped Seminal Luminessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Seminal Luminessence',
                remnant_id = 103002,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Seminal Luminessence',
                remnant_id = 103002,
                max_slots = 1,
            },
        }
    },
    
    -- ===== INCANDESSENCE ARMOR SETS (20 sets: 4 variants Ã— 5 tiers) =====
    ['Distorted Coeval Incandessence'] = {
        display_name = "Distorted Coeval Incandessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Coeval Incandessence',
                remnant_id = 103039,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Coeval Incandessence',
                remnant_id = 103039,
                max_slots = 1,
            },
        }
    },
    ['Distorted Eternal Incandessence'] = {
        display_name = "Distorted Eternal Incandessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Eternal Incandessence',
                remnant_id = 103023,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Eternal Incandessence',
                remnant_id = 103023,
                max_slots = 1,
            },
        }
    },
    ['Distorted Medial Incandessence'] = {
        display_name = "Distorted Medial Incandessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Medial Incandessence',
                remnant_id = 103015,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Medial Incandessence',
                remnant_id = 103015,
                max_slots = 1,
            },
        }
    },
    ['Distorted Primeval Incandessence'] = {
        display_name = "Distorted Primeval Incandessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Primeval Incandessence',
                remnant_id = 103031,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Primeval Incandessence',
                remnant_id = 103031,
                max_slots = 1,
            },
        }
    },
    ['Distorted Seminal Incandessence'] = {
        display_name = "Distorted Seminal Incandessence",
        pieces = {
            ['Arms'] = {
                slots = { 7 },
                remnant_name = 'Distorted Seminal Incandessence',
                remnant_id = 103007,
                max_slots = 1,
            },
            ['Legs'] = {
                slots = { 18 },
                remnant_name = 'Distorted Seminal Incandessence',
                remnant_id = 103007,
                max_slots = 1,
            },
        }
    },
    
    ['Fractured Coeval Incandessence'] = {
        display_name = "Fractured Coeval Incandessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Coeval Incandessence',
                remnant_id = 103037,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Coeval Incandessence',
                remnant_id = 103037,
                max_slots = 1,
            },
        }
    },
    ['Fractured Eternal Incandessence'] = {
        display_name = "Fractured Eternal Incandessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Eternal Incandessence',
                remnant_id = 103021,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Eternal Incandessence',
                remnant_id = 103021,
                max_slots = 1,
            },
        }
    },
    ['Fractured Medial Incandessence'] = {
        display_name = "Fractured Medial Incandessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Medial Incandessence',
                remnant_id = 103013,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Medial Incandessence',
                remnant_id = 103013,
                max_slots = 1,
            },
        }
    },
    ['Fractured Primeval Incandessence'] = {
        display_name = "Fractured Primeval Incandessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Primeval Incandessence',
                remnant_id = 103029,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Primeval Incandessence',
                remnant_id = 103029,
                max_slots = 1,
            },
        }
    },
    ['Fractured Seminal Incandessence'] = {
        display_name = "Fractured Seminal Incandessence",
        pieces = {
            ['Wrist'] = {
                slots = { 9, 10 },
                remnant_name = 'Fractured Seminal Incandessence',
                remnant_id = 103005,
                max_slots = 2,
            },
            ['Hands'] = {
                slots = { 12 },
                remnant_name = 'Fractured Seminal Incandessence',
                remnant_id = 103005,
                max_slots = 1,
            },
        }
    },
    
    ['Phased Coeval Incandessence'] = {
        display_name = "Phased Coeval Incandessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Coeval Incandessence',
                remnant_id = 103040,
                max_slots = 1,
            },
        }
    },
    ['Phased Eternal Incandessence'] = {
        display_name = "Phased Eternal Incandessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Eternal Incandessence',
                remnant_id = 103024,
                max_slots = 1,
            },
        }
    },
    ['Phased Medial Incandessence'] = {
        display_name = "Phased Medial Incandessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Medial Incandessence',
                remnant_id = 103016,
                max_slots = 1,
            },
        }
    },
    ['Phased Primeval Incandessence'] = {
        display_name = "Phased Primeval Incandessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Primeval Incandessence',
                remnant_id = 103032,
                max_slots = 1,
            },
        }
    },
    ['Phased Seminal Incandessence'] = {
        display_name = "Phased Seminal Incandessence",
        pieces = {
            ['Chest'] = {
                slots = { 17 },
                remnant_name = 'Phased Seminal Incandessence',
                remnant_id = 103008,
                max_slots = 1,
            },
        }
    },
    
    ['Warped Coeval Incandessence'] = {
        display_name = "Warped Coeval Incandessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Coeval Incandessence',
                remnant_id = 103038,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Coeval Incandessence',
                remnant_id = 103038,
                max_slots = 1,
            },
        }
    },
    ['Warped Eternal Incandessence'] = {
        display_name = "Warped Eternal Incandessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Eternal Incandessence',
                remnant_id = 103022,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Eternal Incandessence',
                remnant_id = 103022,
                max_slots = 1,
            },
        }
    },
    ['Warped Medial Incandessence'] = {
        display_name = "Warped Medial Incandessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Medial Incandessence',
                remnant_id = 103014,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Medial Incandessence',
                remnant_id = 103014,
                max_slots = 1,
            },
        }
    },
    ['Warped Primeval Incandessence'] = {
        display_name = "Warped Primeval Incandessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Primeval Incandessence',
                remnant_id = 103030,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Primeval Incandessence',
                remnant_id = 103030,
                max_slots = 1,
            },
        }
    },
    ['Warped Seminal Incandessence'] = {
        display_name = "Warped Seminal Incandessence",
        pieces = {
            ['Head'] = {
                slots = { 2 },
                remnant_name = 'Warped Seminal Incandessence',
                remnant_id = 103006,
                max_slots = 1,
            },
            ['Feet'] = {
                slots = { 19 },
                remnant_name = 'Warped Seminal Incandessence',
                remnant_id = 103006,
                max_slots = 1,
            },
        }
    },
    
    -- ===== ENCRUSTED CLAY ARMOR SETS (49 sets: 7 materials Ã— 7 piece types) =====
    -- Celestrium (7 pieces)
    ['Celestrium Encrusted Brachial Clay'] = {
        display_name = "Celestrium Encrusted Brachial Clay",
        tier = 2,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Celestrium Encrusted Brachial Clay', remnant_id = 47582, max_slots = 1 },
        }
    },
    ['Celestrium Encrusted Carpal Clay'] = {
        display_name = "Celestrium Encrusted Carpal Clay",
        tier = 2,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Celestrium Encrusted Carpal Clay', remnant_id = 47581, max_slots = 2 },
        }
    },
    ['Celestrium Encrusted Cephalic Clay'] = {
        display_name = "Celestrium Encrusted Cephalic Clay",
        tier = 2,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Celestrium Encrusted Cephalic Clay', remnant_id = 47586, max_slots = 1 },
        }
    },
    ['Celestrium Encrusted Crural Clay'] = {
        display_name = "Celestrium Encrusted Crural Clay",
        tier = 2,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Celestrium Encrusted Crural Clay', remnant_id = 47584, max_slots = 1 },
        }
    },
    ['Celestrium Encrusted Phalangeal Clay'] = {
        display_name = "Celestrium Encrusted Phalangeal Clay",
        tier = 2,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Celestrium Encrusted Phalangeal Clay', remnant_id = 47580, max_slots = 1 },
        }
    },
    ['Celestrium Encrusted Tarsal Clay'] = {
        display_name = "Celestrium Encrusted Tarsal Clay",
        tier = 2,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Celestrium Encrusted Tarsal Clay', remnant_id = 47583, max_slots = 1 },
        }
    },
    ['Celestrium Encrusted Thoracic Clay'] = {
        display_name = "Celestrium Encrusted Thoracic Clay",
        tier = 2,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Celestrium Encrusted Thoracic Clay', remnant_id = 47585, max_slots = 1 },
        }
    },
    
    -- Damascite (7 pieces)
    ['Damascite Encrusted Brachial Clay'] = {
        display_name = "Damascite Encrusted Brachial Clay",
        tier = 4,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Damascite Encrusted Brachial Clay', remnant_id = 47596, max_slots = 1 },
        }
    },
    ['Damascite Encrusted Carpal Clay'] = {
        display_name = "Damascite Encrusted Carpal Clay",
        tier = 4,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Damascite Encrusted Carpal Clay', remnant_id = 47595, max_slots = 2 },
        }
    },
    ['Damascite Encrusted Cephalic Clay'] = {
        display_name = "Damascite Encrusted Cephalic Clay",
        tier = 4,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Damascite Encrusted Cephalic Clay', remnant_id = 47600, max_slots = 1 },
        }
    },
    ['Damascite Encrusted Crural Clay'] = {
        display_name = "Damascite Encrusted Crural Clay",
        tier = 4,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Damascite Encrusted Crural Clay', remnant_id = 47598, max_slots = 1 },
        }
    },
    ['Damascite Encrusted Phalangeal Clay'] = {
        display_name = "Damascite Encrusted Phalangeal Clay",
        tier = 4,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Damascite Encrusted Phalangeal Clay', remnant_id = 47594, max_slots = 1 },
        }
    },
    ['Damascite Encrusted Tarsal Clay'] = {
        display_name = "Damascite Encrusted Tarsal Clay",
        tier = 4,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Damascite Encrusted Tarsal Clay', remnant_id = 47597, max_slots = 1 },
        }
    },
    ['Damascite Encrusted Thoracic Clay'] = {
        display_name = "Damascite Encrusted Thoracic Clay",
        tier = 4,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Damascite Encrusted Thoracic Clay', remnant_id = 47599, max_slots = 1 },
        }
    },
    
    -- Iridium (7 pieces)
    ['Iridium Encrusted Brachial Clay'] = {
        display_name = "Iridium Encrusted Brachial Clay",
        tier = 4,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Iridium Encrusted Brachial Clay', remnant_id = 47610, max_slots = 1 },
        }
    },
    ['Iridium Encrusted Carpal Clay'] = {
        display_name = "Iridium Encrusted Carpal Clay",
        tier = 4,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Iridium Encrusted Carpal Clay', remnant_id = 47609, max_slots = 2 },
        }
    },
    ['Iridium Encrusted Cephalic Clay'] = {
        display_name = "Iridium Encrusted Cephalic Clay",
        tier = 4,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Iridium Encrusted Cephalic Clay', remnant_id = 47614, max_slots = 1 },
        }
    },
    ['Iridium Encrusted Crural Clay'] = {
        display_name = "Iridium Encrusted Crural Clay",
        tier = 4,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Iridium Encrusted Crural Clay', remnant_id = 47612, max_slots = 1 },
        }
    },
    ['Iridium Encrusted Phalangeal Clay'] = {
        display_name = "Iridium Encrusted Phalangeal Clay",
        tier = 4,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Iridium Encrusted Phalangeal Clay', remnant_id = 47608, max_slots = 1 },
        }
    },
    ['Iridium Encrusted Tarsal Clay'] = {
        display_name = "Iridium Encrusted Tarsal Clay",
        tier = 4,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Iridium Encrusted Tarsal Clay', remnant_id = 47611, max_slots = 1 },
        }
    },
    ['Iridium Encrusted Thoracic Clay'] = {
        display_name = "Iridium Encrusted Thoracic Clay",
        tier = 4,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Iridium Encrusted Thoracic Clay', remnant_id = 47613, max_slots = 1 },
        }
    },
    
    -- Palladium (7 pieces)
    ['Palladium Encrusted Brachial Clay'] = {
        display_name = "Palladium Encrusted Brachial Clay",
        tier = 3,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Palladium Encrusted Brachial Clay', remnant_id = 47603, max_slots = 1 },
        }
    },
    ['Palladium Encrusted Carpal Clay'] = {
        display_name = "Palladium Encrusted Carpal Clay",
        tier = 3,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Palladium Encrusted Carpal Clay', remnant_id = 47602, max_slots = 2 },
        }
    },
    ['Palladium Encrusted Cephalic Clay'] = {
        display_name = "Palladium Encrusted Cephalic Clay",
        tier = 3,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Palladium Encrusted Cephalic Clay', remnant_id = 47607, max_slots = 1 },
        }
    },
    ['Palladium Encrusted Crural Clay'] = {
        display_name = "Palladium Encrusted Crural Clay",
        tier = 3,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Palladium Encrusted Crural Clay', remnant_id = 47605, max_slots = 1 },
        }
    },
    ['Palladium Encrusted Phalangeal Clay'] = {
        display_name = "Palladium Encrusted Phalangeal Clay",
        tier = 3,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Palladium Encrusted Phalangeal Clay', remnant_id = 47601, max_slots = 1 },
        }
    },
    ['Palladium Encrusted Tarsal Clay'] = {
        display_name = "Palladium Encrusted Tarsal Clay",
        tier = 3,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Palladium Encrusted Tarsal Clay', remnant_id = 47604, max_slots = 1 },
        }
    },
    ['Palladium Encrusted Thoracic Clay'] = {
        display_name = "Palladium Encrusted Thoracic Clay",
        tier = 3,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Palladium Encrusted Thoracic Clay', remnant_id = 47606, max_slots = 1 },
        }
    },
    
    -- Rhodium (7 pieces)
    ['Rhodium Encrusted Brachial Clay'] = {
        display_name = "Rhodium Encrusted Brachial Clay",
        tier = 4,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Rhodium Encrusted Brachial Clay', remnant_id = 47617, max_slots = 1 },
        }
    },
    ['Rhodium Encrusted Carpal Clay'] = {
        display_name = "Rhodium Encrusted Carpal Clay",
        tier = 4,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Rhodium Encrusted Carpal Clay', remnant_id = 47616, max_slots = 2 },
        }
    },
    ['Rhodium Encrusted Cephalic Clay'] = {
        display_name = "Rhodium Encrusted Cephalic Clay",
        tier = 4,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Rhodium Encrusted Cephalic Clay', remnant_id = 47621, max_slots = 1 },
        }
    },
    ['Rhodium Encrusted Crural Clay'] = {
        display_name = "Rhodium Encrusted Crural Clay",
        tier = 4,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Rhodium Encrusted Crural Clay', remnant_id = 47619, max_slots = 1 },
        }
    },
    ['Rhodium Encrusted Phalangeal Clay'] = {
        display_name = "Rhodium Encrusted Phalangeal Clay",
        tier = 4,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Rhodium Encrusted Phalangeal Clay', remnant_id = 47615, max_slots = 1 },
        }
    },
    ['Rhodium Encrusted Tarsal Clay'] = {
        display_name = "Rhodium Encrusted Tarsal Clay",
        tier = 4,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Rhodium Encrusted Tarsal Clay', remnant_id = 47618, max_slots = 1 },
        }
    },
    ['Rhodium Encrusted Thoracic Clay'] = {
        display_name = "Rhodium Encrusted Thoracic Clay",
        tier = 4,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Rhodium Encrusted Thoracic Clay', remnant_id = 47620, max_slots = 1 },
        }
    },
    
    -- Stellite (7 pieces)
    ['Stellite Encrusted Brachial Clay'] = {
        display_name = "Stellite Encrusted Brachial Clay",
        tier = 1,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Stellite Encrusted Brachial Clay', remnant_id = 47575, max_slots = 1 },
        }
    },
    ['Stellite Encrusted Carpal Clay'] = {
        display_name = "Stellite Encrusted Carpal Clay",
        tier = 1,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Stellite Encrusted Carpal Clay', remnant_id = 47574, max_slots = 2 },
        }
    },
    ['Stellite Encrusted Cephalic Clay'] = {
        display_name = "Stellite Encrusted Cephalic Clay",
        tier = 1,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Stellite Encrusted Cephalic Clay', remnant_id = 47579, max_slots = 1 },
        }
    },
    ['Stellite Encrusted Crural Clay'] = {
        display_name = "Stellite Encrusted Crural Clay",
        tier = 1,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Stellite Encrusted Crural Clay', remnant_id = 47577, max_slots = 1 },
        }
    },
    ['Stellite Encrusted Phalangeal Clay'] = {
        display_name = "Stellite Encrusted Phalangeal Clay",
        tier = 1,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Stellite Encrusted Phalangeal Clay', remnant_id = 47573, max_slots = 1 },
        }
    },
    ['Stellite Encrusted Tarsal Clay'] = {
        display_name = "Stellite Encrusted Tarsal Clay",
        tier = 1,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Stellite Encrusted Tarsal Clay', remnant_id = 47576, max_slots = 1 },
        }
    },
    ['Stellite Encrusted Thoracic Clay'] = {
        display_name = "Stellite Encrusted Thoracic Clay",
        tier = 1,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Stellite Encrusted Thoracic Clay', remnant_id = 47578, max_slots = 1 },
        }
    },
    
    -- Vitallium (7 pieces)
    ['Vitallium Encrusted Brachial Clay'] = {
        display_name = "Vitallium Encrusted Brachial Clay",
        tier = 3,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Vitallium Encrusted Brachial Clay', remnant_id = 47589, max_slots = 1 },
        }
    },
    ['Vitallium Encrusted Carpal Clay'] = {
        display_name = "Vitallium Encrusted Carpal Clay",
        tier = 3,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Vitallium Encrusted Carpal Clay', remnant_id = 47588, max_slots = 2 },
        }
    },
    ['Vitallium Encrusted Cephalic Clay'] = {
        display_name = "Vitallium Encrusted Cephalic Clay",
        tier = 3,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Vitallium Encrusted Cephalic Clay', remnant_id = 47593, max_slots = 1 },
        }
    },
    ['Vitallium Encrusted Crural Clay'] = {
        display_name = "Vitallium Encrusted Crural Clay",
        tier = 3,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Vitallium Encrusted Crural Clay', remnant_id = 47591, max_slots = 1 },
        }
    },
    ['Vitallium Encrusted Phalangeal Clay'] = {
        display_name = "Vitallium Encrusted Phalangeal Clay",
        tier = 3,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Vitallium Encrusted Phalangeal Clay', remnant_id = 47587, max_slots = 1 },
        }
    },
    ['Vitallium Encrusted Tarsal Clay'] = {
        display_name = "Vitallium Encrusted Tarsal Clay",
        tier = 3,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Vitallium Encrusted Tarsal Clay', remnant_id = 47590, max_slots = 1 },
        }
    },
    ['Vitallium Encrusted Thoracic Clay'] = {
        display_name = "Vitallium Encrusted Thoracic Clay",
        tier = 3,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Vitallium Encrusted Thoracic Clay', remnant_id = 47592, max_slots = 1 },
        }
    },
    
    -- ===== ARMOR TIER SETS (56 sets: 8 locations Ã— 7 pieces) =====
    -- Rustic of Argath (7 pieces)
    ['Rustic of Argath'] = {
        display_name = "Rustic of Argath",
        tier = 14,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Rustic Headdress of Argath', remnant_id = 64753, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Rustic Armwraps of Argath', remnant_id = 64754, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Rustic Wristwraps of Argath', remnant_id = 64750, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Rustic Handwraps of Argath', remnant_id = 64751, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Rustic Stole of Argath', remnant_id = 64756, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Rustic Legwraps of Argath', remnant_id = 64755, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Rustic Footwraps of Argath', remnant_id = 64752, max_slots = 1 },
        }
    },
    
    -- Formal of Lunanyn (7 pieces)
    ['Formal of Lunanyn'] = {
        display_name = "Formal of Lunanyn",
        tier = 15,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Formal Headdress of Lunanyn', remnant_id = 64760, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Formal Armwraps of Lunanyn', remnant_id = 64761, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Formal Wristwraps of Lunanyn', remnant_id = 64757, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Formal Handwraps of Lunanyn', remnant_id = 64758, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Formal Stole of Lunanyn', remnant_id = 64763, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Formal Legwraps of Lunanyn', remnant_id = 64762, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Formal Footwraps of Lunanyn', remnant_id = 64759, max_slots = 1 },
        }
    },
    
    -- Embellished of Kolos (7 pieces)
    ['Embellished of Kolos'] = {
        display_name = "Embellished of Kolos",
        tier = 16,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Embellished Headdress of Kolos', remnant_id = 64767, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Embellished Armwraps of Kolos', remnant_id = 64768, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Embellished Wristwraps of Kolos', remnant_id = 64764, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Embellished Handwraps of Kolos', remnant_id = 64765, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Embellished Stole of Kolos', remnant_id = 64770, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Embellished Legwraps of Kolos', remnant_id = 64769, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Embellished Footwraps of Kolos', remnant_id = 64766, max_slots = 1 },
        }
    },
    
    -- Grandiose of Alra (7 pieces)
    ['Grandiose of Alra'] = {
        display_name = "Grandiose of Alra",
        tier = 17,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Grandiose Headdress of Alra', remnant_id = 64774, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Grandiose Armwraps of Alra', remnant_id = 64775, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Grandiose Wristwraps of Alra', remnant_id = 64771, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Grandiose Handwraps of Alra', remnant_id = 64772, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Grandiose Stole of Alra', remnant_id = 64777, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Grandiose Legwraps of Alra', remnant_id = 64776, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Grandiose Footwraps of Alra', remnant_id = 64773, max_slots = 1 },
        }
    },
    
    -- Modest of Illdaera (7 pieces)
    ['Modest of Illdaera'] = {
        display_name = "Modest of Illdaera",
        tier = 14,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Modest Headdress of Illdaera', remnant_id = 64781, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Modest Armwraps of Illdaera', remnant_id = 64782, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Modest Wristwraps of Illdaera', remnant_id = 64778, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Modest Handwraps of Illdaera', remnant_id = 64779, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Modest Stole of Illdaera', remnant_id = 64784, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Modest Legwraps of Illdaera', remnant_id = 64783, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Modest Footwraps of Illdaera', remnant_id = 64780, max_slots = 1 },
        }
    },
    
    -- Ostentatious of Ryken (7 pieces)
    ['Ostentatious of Ryken'] = {
        display_name = "Ostentatious of Ryken",
        tier = 17,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Ostentatious Headdress of Ryken', remnant_id = 64802, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Ostentatious Armwraps of Ryken', remnant_id = 64803, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Ostentatious Wristwraps of Ryken', remnant_id = 64799, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Ostentatious Handwraps of Ryken', remnant_id = 64800, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Ostentatious Stole of Ryken', remnant_id = 64805, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Ostentatious Legwraps of Ryken', remnant_id = 64804, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Ostentatious Footwraps of Ryken', remnant_id = 64801, max_slots = 1 },
        }
    },
    
    -- Elegant of Oseka (7 pieces)
    ['Elegant of Oseka'] = {
        display_name = "Elegant of Oseka",
        tier = 15,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Elegant Headdress of Oseka', remnant_id = 64788, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Elegant Armwraps of Oseka', remnant_id = 64789, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Elegant Wristwraps of Oseka', remnant_id = 64785, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Elegant Handwraps of Oseka', remnant_id = 64786, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Elegant Stole of Oseka', remnant_id = 64791, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Elegant Legwraps of Oseka', remnant_id = 64790, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Elegant Footwraps of Oseka', remnant_id = 64787, max_slots = 1 },
        }
    },
    
    -- Stately of Ladrys (7 pieces)
    ['Stately of Ladrys'] = {
        display_name = "Stately of Ladrys",
        tier = 17,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Stately Headdress of Ladrys', remnant_id = 64795, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Stately Armwraps of Ladrys', remnant_id = 64796, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Stately Wristwraps of Ladrys', remnant_id = 64792, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Stately Handwraps of Ladrys', remnant_id = 64793, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Stately Stole of Ladrys', remnant_id = 64798, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Stately Legwraps of Ladrys', remnant_id = 64797, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Stately Footwraps of Ladrys', remnant_id = 64794, max_slots = 1 },
        }
    },
    
    -- ===== FEAR & DREAD ARMOR SETS (56 sets: 8 tiers Ã— 7 pieces) =====
    -- Fear Touched (7 pieces)
    ['Fear Touched'] = {
        display_name = "Fear Touched",
        tier = 1,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Fear Touched Helm', remnant_id = 72207, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Fear Touched Armguards', remnant_id = 72208, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Fear Touched Bracer', remnant_id = 72204, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Fear Touched Gloves', remnant_id = 72205, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Fear Touched Tunic', remnant_id = 72210, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Fear Touched Leggings', remnant_id = 72209, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Fear Touched Boots', remnant_id = 72206, max_slots = 1 },
        }
    },
    
    -- Fear Stained (7 pieces)
    ['Fear Stained'] = {
        display_name = "Fear Stained",
        tier = 2,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Fear Stained Helm', remnant_id = 72214, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Fear Stained Armguards', remnant_id = 72215, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Fear Stained Bracer', remnant_id = 72211, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Fear Stained Gloves', remnant_id = 72212, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Fear Stained Tunic', remnant_id = 72217, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Fear Stained Leggings', remnant_id = 72216, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Fear Stained Boots', remnant_id = 72213, max_slots = 1 },
        }
    },
    
    -- Fear Washed (7 pieces)
    ['Fear Washed'] = {
        display_name = "Fear Washed",
        tier = 3,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Fear Washed Helm', remnant_id = 72221, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Fear Washed Armguards', remnant_id = 72222, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Fear Washed Bracer', remnant_id = 72218, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Fear Washed Gloves', remnant_id = 72219, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Fear Washed Tunic', remnant_id = 72224, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Fear Washed Leggings', remnant_id = 72223, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Fear Washed Boots', remnant_id = 72220, max_slots = 1 },
        }
    },
    
    -- Fear Infused (7 pieces)
    ['Fear Infused'] = {
        display_name = "Fear Infused",
        tier = 4,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Fear Infused Helm', remnant_id = 81194, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Fear Infused Armguards', remnant_id = 81195, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Fear Infused Bracer', remnant_id = 81191, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Fear Infused Gloves', remnant_id = 81192, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Fear Infused Tunic', remnant_id = 81197, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Fear Infused Leggings', remnant_id = 81196, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Fear Infused Boots', remnant_id = 81193, max_slots = 1 },
        }
    },
    
    -- Dread Touched (7 pieces)
    ['Dread Touched'] = {
        display_name = "Dread Touched",
        tier = 1,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Dread Touched Helm', remnant_id = 72228, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Dread Touched Armguards', remnant_id = 72229, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Dread Touched Bracer', remnant_id = 72225, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Dread Touched Gloves', remnant_id = 72226, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Dread Touched Tunic', remnant_id = 72231, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Dread Touched Leggings', remnant_id = 72230, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Dread Touched Boots', remnant_id = 72227, max_slots = 1 },
        }
    },
    
    -- Dread (7 pieces)
    ['Dread'] = {
        display_name = "Dread",
        tier = 2,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Dread Helm', remnant_id = 72235, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Dread Armguards', remnant_id = 72236, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Dread Bracer', remnant_id = 72232, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Dread Gloves', remnant_id = 72233, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Dread Tunic', remnant_id = 72238, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Dread Leggings', remnant_id = 72237, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Dread Boots', remnant_id = 72234, max_slots = 1 },
        }
    },
    
    -- Dread Washed (7 pieces)
    ['Dread Washed'] = {
        display_name = "Dread Washed",
        tier = 3,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Dread Washed Helm', remnant_id = 72242, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Dread Washed Armguards', remnant_id = 72243, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Dread Washed Bracer', remnant_id = 72239, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Dread Washed Gloves', remnant_id = 72240, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Dread Washed Tunic', remnant_id = 72245, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Dread Washed Leggings', remnant_id = 72244, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Dread Washed Boots', remnant_id = 72241, max_slots = 1 },
        }
    },
    
    -- Dread Infused (7 pieces)
    ['Dread Infused'] = {
        display_name = "Dread Infused",
        tier = 4,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Dread Infused Helm', remnant_id = 81201, max_slots = 1 },
            ['Arms'] = { slots = { 7 }, remnant_name = 'Dread Infused Armguards', remnant_id = 81202, max_slots = 1 },
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Dread Infused Bracer', remnant_id = 81198, max_slots = 2 },
            ['Hands'] = { slots = { 12 }, remnant_name = 'Dread Infused Gloves', remnant_id = 81199, max_slots = 1 },
            ['Chest'] = { slots = { 17 }, remnant_name = 'Dread Infused Tunic', remnant_id = 81204, max_slots = 1 },
            ['Legs'] = { slots = { 18 }, remnant_name = 'Dread Infused Leggings', remnant_id = 81203, max_slots = 1 },
            ['Feet'] = { slots = { 19 }, remnant_name = 'Dread Infused Boots', remnant_id = 81200, max_slots = 1 },
        }
    },
    
    -- Ether Armor (4 tiers Ã— 7 pieces = 28 sets)
    ['Latent Ether Head'] = {
        display_name = "Latent Ether Head",
        tier = 17,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Helm of Latent Ether', remnant_id = 85288, max_slots = 1 },
        }
    },
    ['Latent Ether Arms'] = {
        display_name = "Latent Ether Arms",
        tier = 17,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Armguards of Latent Ether', remnant_id = 85289, max_slots = 1 },
        }
    },
    ['Latent Ether Wrist'] = {
        display_name = "Latent Ether Wrist",
        tier = 17,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Bracer of Latent Ether', remnant_id = 85285, max_slots = 2 },
        }
    },
    ['Latent Ether Hands'] = {
        display_name = "Latent Ether Hands",
        tier = 17,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Gloves of Latent Ether', remnant_id = 85286, max_slots = 1 },
        }
    },
    ['Latent Ether Chest'] = {
        display_name = "Latent Ether Chest",
        tier = 17,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Tunic of Latent Ether', remnant_id = 85291, max_slots = 1 },
        }
    },
    ['Latent Ether Legs'] = {
        display_name = "Latent Ether Legs",
        tier = 17,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Leggings of Latent Ether', remnant_id = 85290, max_slots = 1 },
        }
    },
    ['Latent Ether Feet'] = {
        display_name = "Latent Ether Feet",
        tier = 17,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Boots of Latent Ether', remnant_id = 85287, max_slots = 1 },
        }
    },
    
    ['Suppressed Ether Head'] = {
        display_name = "Suppressed Ether Head",
        tier = 17,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Helm of Suppressed Ether', remnant_id = 85302, max_slots = 1 },
        }
    },
    ['Suppressed Ether Arms'] = {
        display_name = "Suppressed Ether Arms",
        tier = 17,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Armguards of Suppressed Ether', remnant_id = 85303, max_slots = 1 },
        }
    },
    ['Suppressed Ether Wrist'] = {
        display_name = "Suppressed Ether Wrist",
        tier = 17,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Bracer of Suppressed Ether', remnant_id = 85299, max_slots = 2 },
        }
    },
    ['Suppressed Ether Hands'] = {
        display_name = "Suppressed Ether Hands",
        tier = 17,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Gloves of Suppressed Ether', remnant_id = 85300, max_slots = 1 },
        }
    },
    ['Suppressed Ether Chest'] = {
        display_name = "Suppressed Ether Chest",
        tier = 17,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Tunic of Suppressed Ether', remnant_id = 85305, max_slots = 1 },
        }
    },
    ['Suppressed Ether Legs'] = {
        display_name = "Suppressed Ether Legs",
        tier = 17,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Leggings of Suppressed Ether', remnant_id = 85304, max_slots = 1 },
        }
    },
    ['Suppressed Ether Feet'] = {
        display_name = "Suppressed Ether Feet",
        tier = 17,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Boots of Suppressed Ether', remnant_id = 85301, max_slots = 1 },
        }
    },
    
    ['Manifested Ether Head'] = {
        display_name = "Manifested Ether Head",
        tier = 18,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Helm of Manifested Ether', remnant_id = 85295, max_slots = 1 },
        }
    },
    ['Manifested Ether Arms'] = {
        display_name = "Manifested Ether Arms",
        tier = 18,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Armguards of Manifested Ether', remnant_id = 85296, max_slots = 1 },
        }
    },
    ['Manifested Ether Wrist'] = {
        display_name = "Manifested Ether Wrist",
        tier = 18,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Bracer of Manifested Ether', remnant_id = 85292, max_slots = 2 },
        }
    },
    ['Manifested Ether Hands'] = {
        display_name = "Manifested Ether Hands",
        tier = 18,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Gloves of Manifested Ether', remnant_id = 85293, max_slots = 1 },
        }
    },
    ['Manifested Ether Chest'] = {
        display_name = "Manifested Ether Chest",
        tier = 18,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Tunic of Manifested Ether', remnant_id = 85298, max_slots = 1 },
        }
    },
    ['Manifested Ether Legs'] = {
        display_name = "Manifested Ether Legs",
        tier = 18,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Leggings of Manifested Ether', remnant_id = 85297, max_slots = 1 },
        }
    },
    ['Manifested Ether Feet'] = {
        display_name = "Manifested Ether Feet",
        tier = 18,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Boots of Manifested Ether', remnant_id = 85294, max_slots = 1 },
        }
    },
    
    ['Flowing Ether Head'] = {
        display_name = "Flowing Ether Head",
        tier = 18,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Helm of Flowing Ether', remnant_id = 85309, max_slots = 1 },
        }
    },
    ['Flowing Ether Arms'] = {
        display_name = "Flowing Ether Arms",
        tier = 18,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Armguards of Flowing Ether', remnant_id = 85310, max_slots = 1 },
        }
    },
    ['Flowing Ether Wrist'] = {
        display_name = "Flowing Ether Wrist",
        tier = 18,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Bracer of Flowing Ether', remnant_id = 85306, max_slots = 2 },
        }
    },
    ['Flowing Ether Hands'] = {
        display_name = "Flowing Ether Hands",
        tier = 18,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Gloves of Flowing Ether', remnant_id = 85307, max_slots = 1 },
        }
    },
    ['Flowing Ether Chest'] = {
        display_name = "Flowing Ether Chest",
        tier = 18,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Tunic of Flowing Ether', remnant_id = 85312, max_slots = 1 },
        }
    },
    ['Flowing Ether Legs'] = {
        display_name = "Flowing Ether Legs",
        tier = 18,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Leggings of Flowing Ether', remnant_id = 85311, max_slots = 1 },
        }
    },
    ['Flowing Ether Feet'] = {
        display_name = "Flowing Ether Feet",
        tier = 18,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Boots of Flowing Ether', remnant_id = 85308, max_slots = 1 },
        }
    },
    
    -- Water-Themed Armor (4 tiers Ã— 7 pieces = 28 sets)
    ['Castaway Head'] = {
        display_name = "Castaway Head",
        tier = 19,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Castaway Helm', remnant_id = 94249, max_slots = 1 },
        }
    },
    ['Castaway Arms'] = {
        display_name = "Castaway Arms",
        tier = 19,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Castaway Armguards', remnant_id = 94250, max_slots = 1 },
        }
    },
    ['Castaway Wrist'] = {
        display_name = "Castaway Wrist",
        tier = 19,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Castaway Bracer', remnant_id = 94246, max_slots = 2 },
        }
    },
    ['Castaway Hands'] = {
        display_name = "Castaway Hands",
        tier = 19,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Castaway Gloves', remnant_id = 94247, max_slots = 1 },
        }
    },
    ['Castaway Chest'] = {
        display_name = "Castaway Chest",
        tier = 19,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Castaway Tunic', remnant_id = 94252, max_slots = 1 },
        }
    },
    ['Castaway Legs'] = {
        display_name = "Castaway Legs",
        tier = 19,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Castaway Leggings', remnant_id = 94251, max_slots = 1 },
        }
    },
    ['Castaway Feet'] = {
        display_name = "Castaway Feet",
        tier = 19,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Castaway Boots', remnant_id = 94248, max_slots = 1 },
        }
    },
    
    ['Tideworn Head'] = {
        display_name = "Tideworn Head",
        tier = 20,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Tideworn Helm', remnant_id = 94256, max_slots = 1 },
        }
    },
    ['Tideworn Arms'] = {
        display_name = "Tideworn Arms",
        tier = 20,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Tideworn Armguards', remnant_id = 94257, max_slots = 1 },
        }
    },
    ['Tideworn Wrist'] = {
        display_name = "Tideworn Wrist",
        tier = 20,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Tideworn Bracer', remnant_id = 94253, max_slots = 2 },
        }
    },
    ['Tideworn Hands'] = {
        display_name = "Tideworn Hands",
        tier = 20,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Tideworn Gloves', remnant_id = 94254, max_slots = 1 },
        }
    },
    ['Tideworn Chest'] = {
        display_name = "Tideworn Chest",
        tier = 20,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Tideworn Tunic', remnant_id = 94259, max_slots = 1 },
        }
    },
    ['Tideworn Legs'] = {
        display_name = "Tideworn Legs",
        tier = 20,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Tideworn Leggings', remnant_id = 94258, max_slots = 1 },
        }
    },
    ['Tideworn Feet'] = {
        display_name = "Tideworn Feet",
        tier = 20,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Tideworn Boots', remnant_id = 94255, max_slots = 1 },
        }
    },
    
    ['Highwater Head'] = {
        display_name = "Highwater Head",
        tier = 21,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Highwater Helm', remnant_id = 94263, max_slots = 1 },
        }
    },
    ['Highwater Arms'] = {
        display_name = "Highwater Arms",
        tier = 21,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Highwater Armguards', remnant_id = 94264, max_slots = 1 },
        }
    },
    ['Highwater Wrist'] = {
        display_name = "Highwater Wrist",
        tier = 21,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Highwater Bracer', remnant_id = 94260, max_slots = 2 },
        }
    },
    ['Highwater Hands'] = {
        display_name = "Highwater Hands",
        tier = 21,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Highwater Gloves', remnant_id = 94261, max_slots = 1 },
        }
    },
    ['Highwater Chest'] = {
        display_name = "Highwater Chest",
        tier = 21,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Highwater Tunic', remnant_id = 94266, max_slots = 1 },
        }
    },
    ['Highwater Legs'] = {
        display_name = "Highwater Legs",
        tier = 21,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Highwater Leggings', remnant_id = 94265, max_slots = 1 },
        }
    },
    ['Highwater Feet'] = {
        display_name = "Highwater Feet",
        tier = 21,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Highwater Boots', remnant_id = 94262, max_slots = 1 },
        }
    },
    
    ['Darkwater Head'] = {
        display_name = "Darkwater Head",
        tier = 21,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Darkwater Helm', remnant_id = 94277, max_slots = 1 },
        }
    },
    ['Darkwater Arms'] = {
        display_name = "Darkwater Arms",
        tier = 21,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Darkwater Armguards', remnant_id = 94278, max_slots = 1 },
        }
    },
    ['Darkwater Wrist'] = {
        display_name = "Darkwater Wrist",
        tier = 21,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Darkwater Bracer', remnant_id = 94274, max_slots = 2 },
        }
    },
    ['Darkwater Hands'] = {
        display_name = "Darkwater Hands",
        tier = 21,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Darkwater Gloves', remnant_id = 94275, max_slots = 1 },
        }
    },
    ['Darkwater Chest'] = {
        display_name = "Darkwater Chest",
        tier = 21,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Darkwater Tunic', remnant_id = 94280, max_slots = 1 },
        }
    },
    ['Darkwater Legs'] = {
        display_name = "Darkwater Legs",
        tier = 21,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Darkwater Leggings', remnant_id = 94279, max_slots = 1 },
        }
    },
    ['Darkwater Feet'] = {
        display_name = "Darkwater Feet",
        tier = 21,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Darkwater Boots', remnant_id = 94276, max_slots = 1 },
        }
    },
    
    -- Raw Crypt-Hunter (1 tier Ã— 7 pieces = 7 sets)
    ['Raw Crypt-Hunter Head'] = {
        display_name = "Raw Crypt-Hunter Head",
        tier = 24,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Raw Crypt-Hunter\'s Cap', remnant_id = 147660, max_slots = 1 },
        }
    },
    ['Raw Crypt-Hunter Arms'] = {
        display_name = "Raw Crypt-Hunter Arms",
        tier = 24,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Raw Crypt-Hunter\'s Sleeves', remnant_id = 147661, max_slots = 1 },
        }
    },
    ['Raw Crypt-Hunter Wrist'] = {
        display_name = "Raw Crypt-Hunter Wrist",
        tier = 24,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Raw Crypt-Hunter\'s Wristguard', remnant_id = 147657, max_slots = 2 },
        }
    },
    ['Raw Crypt-Hunter Hands'] = {
        display_name = "Raw Crypt-Hunter Hands",
        tier = 24,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Raw Crypt-Hunter\'s Gloves', remnant_id = 147658, max_slots = 1 },
        }
    },
    ['Raw Crypt-Hunter Chest'] = {
        display_name = "Raw Crypt-Hunter Chest",
        tier = 24,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Raw Crypt-Hunter\'s Chestpiece', remnant_id = 147663, max_slots = 1 },
        }
    },
    ['Raw Crypt-Hunter Legs'] = {
        display_name = "Raw Crypt-Hunter Legs",
        tier = 24,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Raw Crypt-Hunter\'s Leggings', remnant_id = 147662, max_slots = 1 },
        }
    },
    ['Raw Crypt-Hunter Feet'] = {
        display_name = "Raw Crypt-Hunter Feet",
        tier = 24,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Raw Crypt-Hunter\'s Boots', remnant_id = 147659, max_slots = 1 },
        }
    },
    
    -- Amorphous Templates (3 tiers Ã— 7 pieces = 21 sets)
    ['Amorphous Cohort Head'] = {
        display_name = "Amorphous Cohort Head",
        tier = 25,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Amorphous Cohort\'s Helm', remnant_id = 148854, max_slots = 1 },
        }
    },
    ['Amorphous Cohort Arms'] = {
        display_name = "Amorphous Cohort Arms",
        tier = 25,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Amorphous Cohort\'s Sleeves', remnant_id = 148855, max_slots = 1 },
        }
    },
    ['Amorphous Cohort Wrist'] = {
        display_name = "Amorphous Cohort Wrist",
        tier = 25,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Amorphous Cohort\'s Wristguard', remnant_id = 148851, max_slots = 2 },
        }
    },
    ['Amorphous Cohort Hands'] = {
        display_name = "Amorphous Cohort Hands",
        tier = 25,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Amorphous Cohort\'s Gauntlets', remnant_id = 148852, max_slots = 1 },
        }
    },
    ['Amorphous Cohort Chest'] = {
        display_name = "Amorphous Cohort Chest",
        tier = 25,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Amorphous Cohort\'s Breastplate', remnant_id = 148857, max_slots = 1 },
        }
    },
    ['Amorphous Cohort Legs'] = {
        display_name = "Amorphous Cohort Legs",
        tier = 25,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Amorphous Cohort\'s Leggings', remnant_id = 148856, max_slots = 1 },
        }
    },
    ['Amorphous Cohort Feet'] = {
        display_name = "Amorphous Cohort Feet",
        tier = 25,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Amorphous Cohort\'s Boots', remnant_id = 148853, max_slots = 1 },
        }
    },
    
    ['Amorphous Selrach Head'] = {
        display_name = "Amorphous Selrach Head",
        tier = 26,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Amorphous Selrach\'s Helm', remnant_id = 148861, max_slots = 1 },
        }
    },
    ['Amorphous Selrach Arms'] = {
        display_name = "Amorphous Selrach Arms",
        tier = 26,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Amorphous Selrach\'s Sleeves', remnant_id = 148862, max_slots = 1 },
        }
    },
    ['Amorphous Selrach Wrist'] = {
        display_name = "Amorphous Selrach Wrist",
        tier = 26,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Amorphous Selrach\'s Wristguard', remnant_id = 148858, max_slots = 2 },
        }
    },
    ['Amorphous Selrach Hands'] = {
        display_name = "Amorphous Selrach Hands",
        tier = 26,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Amorphous Selrach\'s Gauntlets', remnant_id = 148859, max_slots = 1 },
        }
    },
    ['Amorphous Selrach Chest'] = {
        display_name = "Amorphous Selrach Chest",
        tier = 26,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Amorphous Selrach\'s Breastplate', remnant_id = 148864, max_slots = 1 },
        }
    },
    ['Amorphous Selrach Legs'] = {
        display_name = "Amorphous Selrach Legs",
        tier = 26,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Amorphous Selrach\'s Leggings', remnant_id = 148863, max_slots = 1 },
        }
    },
    ['Amorphous Selrach Feet'] = {
        display_name = "Amorphous Selrach Feet",
        tier = 26,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Amorphous Selrach\'s Boots', remnant_id = 148860, max_slots = 1 },
        }
    },
    
    ['Amorphous Velazul Head'] = {
        display_name = "Amorphous Velazul Head",
        tier = 26,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Amorphous Velazul\'s Helm', remnant_id = 148868, max_slots = 1 },
        }
    },
    ['Amorphous Velazul Arms'] = {
        display_name = "Amorphous Velazul Arms",
        tier = 26,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Amorphous Velazul\'s Sleeves', remnant_id = 148869, max_slots = 1 },
        }
    },
    ['Amorphous Velazul Wrist'] = {
        display_name = "Amorphous Velazul Wrist",
        tier = 26,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Amorphous Velazul\'s Wristguard', remnant_id = 148865, max_slots = 2 },
        }
    },
    ['Amorphous Velazul Hands'] = {
        display_name = "Amorphous Velazul Hands",
        tier = 26,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Amorphous Velazul\'s Gauntlets', remnant_id = 148866, max_slots = 1 },
        }
    },
    ['Amorphous Velazul Chest'] = {
        display_name = "Amorphous Velazul Chest",
        tier = 26,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Amorphous Velazul\'s Breastplate', remnant_id = 148871, max_slots = 1 },
        }
    },
    ['Amorphous Velazul Legs'] = {
        display_name = "Amorphous Velazul Legs",
        tier = 26,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Amorphous Velazul\'s Leggings', remnant_id = 148870, max_slots = 1 },
        }
    },
    ['Amorphous Velazul Feet'] = {
        display_name = "Amorphous Velazul Feet",
        tier = 26,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Amorphous Velazul\'s Boots', remnant_id = 148867, max_slots = 1 },
        }
    },
    
    -- Scale Facets (3 tiers Ã— 7 pieces = 21 sets)
    ['Scale Touched Head'] = {
        display_name = "Scale Touched Head",
        tier = 27,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Scale Touched Cap Facet', remnant_id = 151854, max_slots = 1 },
        }
    },
    ['Scale Touched Arms'] = {
        display_name = "Scale Touched Arms",
        tier = 27,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Scale Touched Sleeve Facet', remnant_id = 151855, max_slots = 1 },
        }
    },
    ['Scale Touched Wrist'] = {
        display_name = "Scale Touched Wrist",
        tier = 27,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Scale Touched Bracer Facet', remnant_id = 151851, max_slots = 2 },
        }
    },
    ['Scale Touched Hands'] = {
        display_name = "Scale Touched Hands",
        tier = 27,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Scale Touched Gloves Facet', remnant_id = 151852, max_slots = 1 },
        }
    },
    ['Scale Touched Chest'] = {
        display_name = "Scale Touched Chest",
        tier = 27,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Scale Touched Tunic Facet', remnant_id = 151857, max_slots = 1 },
        }
    },
    ['Scale Touched Legs'] = {
        display_name = "Scale Touched Legs",
        tier = 27,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Scale Touched Pants Facet', remnant_id = 151856, max_slots = 1 },
        }
    },
    ['Scale Touched Feet'] = {
        display_name = "Scale Touched Feet",
        tier = 27,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Scale Touched Shoes Facet', remnant_id = 151853, max_slots = 1 },
        }
    },
    
    ['Scaled Head'] = {
        display_name = "Scaled Head",
        tier = 28,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Scaled Cap Facet', remnant_id = 151861, max_slots = 1 },
        }
    },
    ['Scaled Arms'] = {
        display_name = "Scaled Arms",
        tier = 28,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Scaled Sleeve Facet', remnant_id = 151862, max_slots = 1 },
        }
    },
    ['Scaled Wrist'] = {
        display_name = "Scaled Wrist",
        tier = 28,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Scaled Bracer Facet', remnant_id = 151858, max_slots = 2 },
        }
    },
    ['Scaled Hands'] = {
        display_name = "Scaled Hands",
        tier = 28,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Scaled Gloves Facet', remnant_id = 151859, max_slots = 1 },
        }
    },
    ['Scaled Chest'] = {
        display_name = "Scaled Chest",
        tier = 28,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Scaled Tunic Facet', remnant_id = 151864, max_slots = 1 },
        }
    },
    ['Scaled Legs'] = {
        display_name = "Scaled Legs",
        tier = 28,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Scaled Pants Facet', remnant_id = 151863, max_slots = 1 },
        }
    },
    ['Scaled Feet'] = {
        display_name = "Scaled Feet",
        tier = 28,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Scaled Shoes Facet', remnant_id = 151860, max_slots = 1 },
        }
    },
    
    ['Scaleborn Head'] = {
        display_name = "Scaleborn Head",
        tier = 28,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Scaleborn Cap Facet', remnant_id = 151868, max_slots = 1 },
        }
    },
    ['Scaleborn Arms'] = {
        display_name = "Scaleborn Arms",
        tier = 28,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Scaleborn Sleeve Facet', remnant_id = 151869, max_slots = 1 },
        }
    },
    ['Scaleborn Wrist'] = {
        display_name = "Scaleborn Wrist",
        tier = 28,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Scaleborn Bracer Facet', remnant_id = 151865, max_slots = 2 },
        }
    },
    ['Scaleborn Hands'] = {
        display_name = "Scaleborn Hands",
        tier = 28,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Scaleborn Gloves Facet', remnant_id = 151866, max_slots = 1 },
        }
    },
    ['Scaleborn Chest'] = {
        display_name = "Scaleborn Chest",
        tier = 28,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Scaleborn Tunic Facet', remnant_id = 151871, max_slots = 1 },
        }
    },
    ['Scaleborn Legs'] = {
        display_name = "Scaleborn Legs",
        tier = 28,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Scaleborn Pants Facet', remnant_id = 151870, max_slots = 1 },
        }
    },
    ['Scaleborn Feet'] = {
        display_name = "Scaleborn Feet",
        tier = 28,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Scaleborn Shoes Facet', remnant_id = 151867, max_slots = 1 },
        }
    },
    
    -- Binding Muhbis (5 tiers Ã— 7 pieces = 35 sets)
    ['Adamant Triumphant Cloud Head'] = {
        display_name = "Adamant Triumphant Cloud Head",
        tier = 31,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Adamant Triumphant Cloud Binding Head Muhbis', remnant_id = 160752, max_slots = 1 },
        }
    },
    ['Adamant Triumphant Cloud Arms'] = {
        display_name = "Adamant Triumphant Cloud Arms",
        tier = 31,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Adamant Triumphant Cloud Binding Arms Muhbis', remnant_id = 160753, max_slots = 1 },
        }
    },
    ['Adamant Triumphant Cloud Wrist'] = {
        display_name = "Adamant Triumphant Cloud Wrist",
        tier = 31,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Adamant Triumphant Cloud Binding Wrist Muhbis', remnant_id = 160749, max_slots = 2 },
        }
    },
    ['Adamant Triumphant Cloud Hands'] = {
        display_name = "Adamant Triumphant Cloud Hands",
        tier = 31,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Adamant Triumphant Cloud Binding Hands Muhbis', remnant_id = 160750, max_slots = 1 },
        }
    },
    ['Adamant Triumphant Cloud Chest'] = {
        display_name = "Adamant Triumphant Cloud Chest",
        tier = 31,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Adamant Triumphant Cloud Binding Chest Muhbis', remnant_id = 160755, max_slots = 1 },
        }
    },
    ['Adamant Triumphant Cloud Legs'] = {
        display_name = "Adamant Triumphant Cloud Legs",
        tier = 31,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Adamant Triumphant Cloud Binding Legs Muhbis', remnant_id = 160754, max_slots = 1 },
        }
    },
    ['Adamant Triumphant Cloud Feet'] = {
        display_name = "Adamant Triumphant Cloud Feet",
        tier = 31,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Adamant Triumphant Cloud Binding Feet Muhbis', remnant_id = 160751, max_slots = 1 },
        }
    },
    
    ['Battleworn Stalwart Moon Head'] = {
        display_name = "Battleworn Stalwart Moon Head",
        tier = 31,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Battleworn Stalwart Moon Binding Head Muhbis', remnant_id = 161411, max_slots = 1 },
        }
    },
    ['Battleworn Stalwart Moon Arms'] = {
        display_name = "Battleworn Stalwart Moon Arms",
        tier = 31,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Battleworn Stalwart Moon Binding Arms Muhbis', remnant_id = 161412, max_slots = 1 },
        }
    },
    ['Battleworn Stalwart Moon Wrist'] = {
        display_name = "Battleworn Stalwart Moon Wrist",
        tier = 31,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Battleworn Stalwart Moon Binding Wrist Muhbis', remnant_id = 161408, max_slots = 2 },
        }
    },
    ['Battleworn Stalwart Moon Hands'] = {
        display_name = "Battleworn Stalwart Moon Hands",
        tier = 31,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Battleworn Stalwart Moon Binding Hands Muhbis', remnant_id = 161409, max_slots = 1 },
        }
    },
    ['Battleworn Stalwart Moon Chest'] = {
        display_name = "Battleworn Stalwart Moon Chest",
        tier = 31,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Battleworn Stalwart Moon Binding Chest Muhbis', remnant_id = 161414, max_slots = 1 },
        }
    },
    ['Battleworn Stalwart Moon Legs'] = {
        display_name = "Battleworn Stalwart Moon Legs",
        tier = 31,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Battleworn Stalwart Moon Binding Legs Muhbis', remnant_id = 161413, max_slots = 1 },
        }
    },
    ['Battleworn Stalwart Moon Feet'] = {
        display_name = "Battleworn Stalwart Moon Feet",
        tier = 31,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Battleworn Stalwart Moon Binding Feet Muhbis', remnant_id = 161410, max_slots = 1 },
        }
    },
    
    ['Heavenly Glorious Void Head'] = {
        display_name = "Heavenly Glorious Void Head",
        tier = 32,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Heavenly Glorious Void Binding Head Muhbis', remnant_id = 160759, max_slots = 1 },
        }
    },
    ['Heavenly Glorious Void Arms'] = {
        display_name = "Heavenly Glorious Void Arms",
        tier = 32,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Heavenly Glorious Void Binding Arms Muhbis', remnant_id = 160760, max_slots = 1 },
        }
    },
    ['Heavenly Glorious Void Wrist'] = {
        display_name = "Heavenly Glorious Void Wrist",
        tier = 32,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Heavenly Glorious Void Binding Wrist Muhbis', remnant_id = 160756, max_slots = 2 },
        }
    },
    ['Heavenly Glorious Void Hands'] = {
        display_name = "Heavenly Glorious Void Hands",
        tier = 32,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Heavenly Glorious Void Binding Hands Muhbis', remnant_id = 160757, max_slots = 1 },
        }
    },
    ['Heavenly Glorious Void Chest'] = {
        display_name = "Heavenly Glorious Void Chest",
        tier = 32,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Heavenly Glorious Void Binding Chest Muhbis', remnant_id = 160762, max_slots = 1 },
        }
    },
    ['Heavenly Glorious Void Legs'] = {
        display_name = "Heavenly Glorious Void Legs",
        tier = 32,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Heavenly Glorious Void Binding Legs Muhbis', remnant_id = 160761, max_slots = 1 },
        }
    },
    ['Heavenly Glorious Void Feet'] = {
        display_name = "Heavenly Glorious Void Feet",
        tier = 32,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Heavenly Glorious Void Binding Feet Muhbis', remnant_id = 160758, max_slots = 1 },
        }
    },
    
    ['Veiled Victorious Horizon Head'] = {
        display_name = "Veiled Victorious Horizon Head",
        tier = 31,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Veiled Victorious Horizon Binding Head Muhbis', remnant_id = 161418, max_slots = 1 },
        }
    },
    ['Veiled Victorious Horizon Arms'] = {
        display_name = "Veiled Victorious Horizon Arms",
        tier = 31,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Veiled Victorious Horizon Binding Arms Muhbis', remnant_id = 161419, max_slots = 1 },
        }
    },
    ['Veiled Victorious Horizon Wrist'] = {
        display_name = "Veiled Victorious Horizon Wrist",
        tier = 31,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Veiled Victorious Horizon Binding Wrist Muhbis', remnant_id = 161415, max_slots = 2 },
        }
    },
    ['Veiled Victorious Horizon Hands'] = {
        display_name = "Veiled Victorious Horizon Hands",
        tier = 31,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Veiled Victorious Horizon Binding Hands Muhbis', remnant_id = 161416, max_slots = 1 },
        }
    },
    ['Veiled Victorious Horizon Chest'] = {
        display_name = "Veiled Victorious Horizon Chest",
        tier = 31,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Veiled Victorious Horizon Binding Chest Muhbis', remnant_id = 161421, max_slots = 1 },
        }
    },
    ['Veiled Victorious Horizon Legs'] = {
        display_name = "Veiled Victorious Horizon Legs",
        tier = 31,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Veiled Victorious Horizon Binding Legs Muhbis', remnant_id = 161420, max_slots = 1 },
        }
    },
    ['Veiled Victorious Horizon Feet'] = {
        display_name = "Veiled Victorious Horizon Feet",
        tier = 31,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Veiled Victorious Horizon Binding Feet Muhbis', remnant_id = 161417, max_slots = 1 },
        }
    },
    
    ['Weeping Undefeated Heaven Head'] = {
        display_name = "Weeping Undefeated Heaven Head",
        tier = 30,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Weeping Undefeated Heaven Binding Head Muhbis', remnant_id = 161404, max_slots = 1 },
        }
    },
    ['Weeping Undefeated Heaven Arms'] = {
        display_name = "Weeping Undefeated Heaven Arms",
        tier = 30,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Weeping Undefeated Heaven Binding Arms Muhbis', remnant_id = 161405, max_slots = 1 },
        }
    },
    ['Weeping Undefeated Heaven Wrist'] = {
        display_name = "Weeping Undefeated Heaven Wrist",
        tier = 30,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Weeping Undefeated Heaven Binding Wrist Muhbis', remnant_id = 161401, max_slots = 2 },
        }
    },
    ['Weeping Undefeated Heaven Hands'] = {
        display_name = "Weeping Undefeated Heaven Hands",
        tier = 30,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Weeping Undefeated Heaven Binding Hands Muhbis', remnant_id = 161402, max_slots = 1 },
        }
    },
    ['Weeping Undefeated Heaven Chest'] = {
        display_name = "Weeping Undefeated Heaven Chest",
        tier = 30,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Weeping Undefeated Heaven Binding Chest Muhbis', remnant_id = 161407, max_slots = 1 },
        }
    },
    ['Weeping Undefeated Heaven Legs'] = {
        display_name = "Weeping Undefeated Heaven Legs",
        tier = 30,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Weeping Undefeated Heaven Binding Legs Muhbis', remnant_id = 161406, max_slots = 1 },
        }
    },
    ['Weeping Undefeated Heaven Feet'] = {
        display_name = "Weeping Undefeated Heaven Feet",
        tier = 30,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Weeping Undefeated Heaven Binding Feet Muhbis', remnant_id = 161403, max_slots = 1 },
        }
    },
    
    -- Faded Armor (2 tiers Ã— 7 pieces = 14 sets)
    ['Faded Icebound Head'] = {
        display_name = "Faded Icebound Head",
        tier = 33,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Icebound Head Armor', remnant_id = 164411, max_slots = 1 },
        }
    },
    ['Faded Icebound Arms'] = {
        display_name = "Faded Icebound Arms",
        tier = 33,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Icebound Arms Armor', remnant_id = 164412, max_slots = 1 },
        }
    },
    ['Faded Icebound Wrist'] = {
        display_name = "Faded Icebound Wrist",
        tier = 33,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Icebound Wrist Armor', remnant_id = 164408, max_slots = 2 },
        }
    },
    ['Faded Icebound Hands'] = {
        display_name = "Faded Icebound Hands",
        tier = 33,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Icebound Hands Armor', remnant_id = 164409, max_slots = 1 },
        }
    },
    ['Faded Icebound Chest'] = {
        display_name = "Faded Icebound Chest",
        tier = 33,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Icebound Chest Armor', remnant_id = 164414, max_slots = 1 },
        }
    },
    ['Faded Icebound Legs'] = {
        display_name = "Faded Icebound Legs",
        tier = 33,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Icebound Legs Armor', remnant_id = 164413, max_slots = 1 },
        }
    },
    ['Faded Icebound Feet'] = {
        display_name = "Faded Icebound Feet",
        tier = 33,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Icebound Feet Armor', remnant_id = 164410, max_slots = 1 },
        }
    },
    
    ['Faded Ice Woven Head'] = {
        display_name = "Faded Ice Woven Head",
        tier = 33,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Ice Woven Head Armor', remnant_id = 164418, max_slots = 1 },
        }
    },
    ['Faded Ice Woven Arms'] = {
        display_name = "Faded Ice Woven Arms",
        tier = 33,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Ice Woven Arms Armor', remnant_id = 164419, max_slots = 1 },
        }
    },
    ['Faded Ice Woven Wrist'] = {
        display_name = "Faded Ice Woven Wrist",
        tier = 33,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Ice Woven Wrist Armor', remnant_id = 164415, max_slots = 2 },
        }
    },
    ['Faded Ice Woven Hands'] = {
        display_name = "Faded Ice Woven Hands",
        tier = 33,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Ice Woven Hands Armor', remnant_id = 164416, max_slots = 1 },
        }
    },
    ['Faded Ice Woven Chest'] = {
        display_name = "Faded Ice Woven Chest",
        tier = 33,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Ice Woven Chest Armor', remnant_id = 164421, max_slots = 1 },
        }
    },
    ['Faded Ice Woven Legs'] = {
        display_name = "Faded Ice Woven Legs",
        tier = 33,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Ice Woven Legs Armor', remnant_id = 164420, max_slots = 1 },
        }
    },
    ['Faded Ice Woven Feet'] = {
        display_name = "Faded Ice Woven Feet",
        tier = 33,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Ice Woven Feet Armor', remnant_id = 164417, max_slots = 1 },
        }
    },
    
    ['Faded Snowbound Head'] = {
        display_name = "Faded Snowbound Head",
        tier = 33,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Snowbound Head Armor', remnant_id = 164404, max_slots = 1 },
        }
    },
    ['Faded Snowbound Arms'] = {
        display_name = "Faded Snowbound Arms",
        tier = 33,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Snowbound Arms Armor', remnant_id = 164405, max_slots = 1 },
        }
    },
    ['Faded Snowbound Wrist'] = {
        display_name = "Faded Snowbound Wrist",
        tier = 33,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Snowbound Wrist Armor', remnant_id = 164401, max_slots = 2 },
        }
    },
    ['Faded Snowbound Hands'] = {
        display_name = "Faded Snowbound Hands",
        tier = 33,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Snowbound Hands Armor', remnant_id = 164402, max_slots = 1 },
        }
    },
    ['Faded Snowbound Chest'] = {
        display_name = "Faded Snowbound Chest",
        tier = 33,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Snowbound Chest Armor', remnant_id = 164407, max_slots = 1 },
        }
    },
    ['Faded Snowbound Legs'] = {
        display_name = "Faded Snowbound Legs",
        tier = 33,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Snowbound Legs Armor', remnant_id = 164406, max_slots = 1 },
        }
    },
    ['Faded Snowbound Feet'] = {
        display_name = "Faded Snowbound Feet",
        tier = 33,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Snowbound Feet Armor', remnant_id = 164403, max_slots = 1 },
        }
    },
    
    -- ===== FADED SNOWSQUALL =====
    ['Faded Snowsquall Head'] = {
        display_name = "Faded Snowsquall Head",
        tier = 36,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Snowsquall Head Armor', remnant_id = 164904, max_slots = 1 },
        }
    },
    ['Faded Snowsquall Arms'] = {
        display_name = "Faded Snowsquall Arms",
        tier = 36,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Snowsquall Arms Armor', remnant_id = 164905, max_slots = 1 },
        }
    },
    ['Faded Snowsquall Wrist'] = {
        display_name = "Faded Snowsquall Wrist",
        tier = 36,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Snowsquall Wrist Armor', remnant_id = 164901, max_slots = 2 },
        }
    },
    ['Faded Snowsquall Hands'] = {
        display_name = "Faded Snowsquall Hands",
        tier = 36,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Snowsquall Hands Armor', remnant_id = 164902, max_slots = 1 },
        }
    },
    ['Faded Snowsquall Feet'] = {
        display_name = "Faded Snowsquall Feet",
        tier = 36,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Snowsquall Feet Armor', remnant_id = 164903, max_slots = 1 },
        }
    },
    ['Faded Snowsquall Legs'] = {
        display_name = "Faded Snowsquall Legs",
        tier = 36,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Snowsquall Legs Armor', remnant_id = 164906, max_slots = 1 },
        }
    },
    ['Faded Snowsquall Chest'] = {
        display_name = "Faded Snowsquall Chest",
        tier = 36,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Snowsquall Chest Armor', remnant_id = 164907, max_slots = 1 },
        }
    },
    
    -- ===== FADED BLIZZARD =====
    ['Faded Blizzard Head'] = {
        display_name = "Faded Blizzard Head",
        tier = 36,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Blizzard Head Armor', remnant_id = 164911, max_slots = 1 },
        }
    },
    ['Faded Blizzard Arms'] = {
        display_name = "Faded Blizzard Arms",
        tier = 36,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Blizzard Arms Armor', remnant_id = 164912, max_slots = 1 },
        }
    },
    ['Faded Blizzard Wrist'] = {
        display_name = "Faded Blizzard Wrist",
        tier = 36,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Blizzard Wrist Armor', remnant_id = 164908, max_slots = 2 },
        }
    },
    ['Faded Blizzard Hands'] = {
        display_name = "Faded Blizzard Hands",
        tier = 36,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Blizzard Hands Armor', remnant_id = 164909, max_slots = 1 },
        }
    },
    ['Faded Blizzard Feet'] = {
        display_name = "Faded Blizzard Feet",
        tier = 36,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Blizzard Feet Armor', remnant_id = 164910, max_slots = 1 },
        }
    },
    ['Faded Blizzard Legs'] = {
        display_name = "Faded Blizzard Legs",
        tier = 36,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Blizzard Legs Armor', remnant_id = 164913, max_slots = 1 },
        }
    },
    ['Faded Blizzard Chest'] = {
        display_name = "Faded Blizzard Chest",
        tier = 36,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Blizzard Chest Armor', remnant_id = 164914, max_slots = 1 },
        }
    },
    
    -- ===== FADED HOARFROST =====
    ['Faded Hoarfrost Head'] = {
        display_name = "Faded Hoarfrost Head",
        tier = 36,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Hoarfrost Head Armor', remnant_id = 164925, max_slots = 1 },
        }
    },
    ['Faded Hoarfrost Arms'] = {
        display_name = "Faded Hoarfrost Arms",
        tier = 36,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Hoarfrost Arms Armor', remnant_id = 164926, max_slots = 1 },
        }
    },
    ['Faded Hoarfrost Wrist'] = {
        display_name = "Faded Hoarfrost Wrist",
        tier = 36,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Hoarfrost Wrist Armor', remnant_id = 164922, max_slots = 2 },
        }
    },
    ['Faded Hoarfrost Hands'] = {
        display_name = "Faded Hoarfrost Hands",
        tier = 36,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Hoarfrost Hands Armor', remnant_id = 164923, max_slots = 1 },
        }
    },
    ['Faded Hoarfrost Feet'] = {
        display_name = "Faded Hoarfrost Feet",
        tier = 36,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Hoarfrost Feet Armor', remnant_id = 164924, max_slots = 1 },
        }
    },
    ['Faded Hoarfrost Legs'] = {
        display_name = "Faded Hoarfrost Legs",
        tier = 36,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Hoarfrost Legs Armor', remnant_id = 164927, max_slots = 1 },
        }
    },
    ['Faded Hoarfrost Chest'] = {
        display_name = "Faded Hoarfrost Chest",
        tier = 36,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Hoarfrost Chest Armor', remnant_id = 164928, max_slots = 1 },
        }
    },
    
    -- ===== FADED WAXING CRESCENT =====
    ['Faded Waxing Crescent Head'] = {
        display_name = "Faded Waxing Crescent Head",
        tier = 39,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Waxing Crescent Head Armor', remnant_id = 168004, max_slots = 1 },
        }
    },
    ['Faded Waxing Crescent Arms'] = {
        display_name = "Faded Waxing Crescent Arms",
        tier = 39,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Waxing Crescent Arms Armor', remnant_id = 168005, max_slots = 1 },
        }
    },
    ['Faded Waxing Crescent Wrist'] = {
        display_name = "Faded Waxing Crescent Wrist",
        tier = 39,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Waxing Crescent Wrist Armor', remnant_id = 168001, max_slots = 2 },
        }
    },
    ['Faded Waxing Crescent Hands'] = {
        display_name = "Faded Waxing Crescent Hands",
        tier = 39,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Waxing Crescent Hands Armor', remnant_id = 168002, max_slots = 1 },
        }
    },
    ['Faded Waxing Crescent Feet'] = {
        display_name = "Faded Waxing Crescent Feet",
        tier = 39,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Waxing Crescent Feet Armor', remnant_id = 168003, max_slots = 1 },
        }
    },
    ['Faded Waxing Crescent Legs'] = {
        display_name = "Faded Waxing Crescent Legs",
        tier = 39,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Waxing Crescent Legs Armor', remnant_id = 168006, max_slots = 1 },
        }
    },
    ['Faded Waxing Crescent Chest'] = {
        display_name = "Faded Waxing Crescent Chest",
        tier = 39,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Waxing Crescent Chest Armor', remnant_id = 168007, max_slots = 1 },
        }
    },
    
    -- ===== FADED WANING CRESCENT =====
    ['Faded Waning Crescent Head'] = {
        display_name = "Faded Waning Crescent Head",
        tier = 39,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Waning Crescent Head Armor', remnant_id = 168011, max_slots = 1 },
        }
    },
    ['Faded Waning Crescent Arms'] = {
        display_name = "Faded Waning Crescent Arms",
        tier = 39,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Waning Crescent Arms Armor', remnant_id = 168012, max_slots = 1 },
        }
    },
    ['Faded Waning Crescent Wrist'] = {
        display_name = "Faded Waning Crescent Wrist",
        tier = 39,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Waning Crescent Wrist Armor', remnant_id = 168008, max_slots = 2 },
        }
    },
    ['Faded Waning Crescent Hands'] = {
        display_name = "Faded Waning Crescent Hands",
        tier = 39,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Waning Crescent Hands Armor', remnant_id = 168009, max_slots = 1 },
        }
    },
    ['Faded Waning Crescent Feet'] = {
        display_name = "Faded Waning Crescent Feet",
        tier = 39,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Waning Crescent Feet Armor', remnant_id = 168010, max_slots = 1 },
        }
    },
    ['Faded Waning Crescent Legs'] = {
        display_name = "Faded Waning Crescent Legs",
        tier = 39,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Waning Crescent Legs Armor', remnant_id = 168013, max_slots = 1 },
        }
    },
    ['Faded Waning Crescent Chest'] = {
        display_name = "Faded Waning Crescent Chest",
        tier = 39,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Waning Crescent Chest Armor', remnant_id = 168014, max_slots = 1 },
        }
    },
    
    -- ===== FADED WANING GIBBOUS =====
    ['Faded Waning Gibbous Head'] = {
        display_name = "Faded Waning Gibbous Head",
        tier = 40,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Waning Gibbous Head Armor', remnant_id = 168025, max_slots = 1 },
        }
    },
    ['Faded Waning Gibbous Arms'] = {
        display_name = "Faded Waning Gibbous Arms",
        tier = 40,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Waning Gibbous Arms Armor', remnant_id = 168026, max_slots = 1 },
        }
    },
    ['Faded Waning Gibbous Wrist'] = {
        display_name = "Faded Waning Gibbous Wrist",
        tier = 40,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Waning Gibbous Wrist Armor', remnant_id = 168022, max_slots = 2 },
        }
    },
    ['Faded Waning Gibbous Hands'] = {
        display_name = "Faded Waning Gibbous Hands",
        tier = 40,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Waning Gibbous Hands Armor', remnant_id = 168023, max_slots = 1 },
        }
    },
    ['Faded Waning Gibbous Feet'] = {
        display_name = "Faded Waning Gibbous Feet",
        tier = 40,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Waning Gibbous Feet Armor', remnant_id = 168024, max_slots = 1 },
        }
    },
    ['Faded Waning Gibbous Legs'] = {
        display_name = "Faded Waning Gibbous Legs",
        tier = 40,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Waning Gibbous Legs Armor', remnant_id = 168027, max_slots = 1 },
        }
    },
    ['Faded Waning Gibbous Chest'] = {
        display_name = "Faded Waning Gibbous Chest",
        tier = 40,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Waning Gibbous Chest Armor', remnant_id = 168028, max_slots = 1 },
        }
    },
    
    -- ===== FADED ASCENDING SPIRIT =====
    ['Faded Ascending Spirit Head'] = {
        display_name = "Faded Ascending Spirit Head",
        tier = 42,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Ascending Spirit Head Armor', remnant_id = 168104, max_slots = 1 },
        }
    },
    ['Faded Ascending Spirit Arms'] = {
        display_name = "Faded Ascending Spirit Arms",
        tier = 42,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Ascending Spirit Arms Armor', remnant_id = 168105, max_slots = 1 },
        }
    },
    ['Faded Ascending Spirit Wrist'] = {
        display_name = "Faded Ascending Spirit Wrist",
        tier = 42,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Ascending Spirit Wrist Armor', remnant_id = 168101, max_slots = 2 },
        }
    },
    ['Faded Ascending Spirit Hands'] = {
        display_name = "Faded Ascending Spirit Hands",
        tier = 42,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Ascending Spirit Hands Armor', remnant_id = 168102, max_slots = 1 },
        }
    },
    ['Faded Ascending Spirit Feet'] = {
        display_name = "Faded Ascending Spirit Feet",
        tier = 42,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Ascending Spirit Feet Armor', remnant_id = 168103, max_slots = 1 },
        }
    },
    ['Faded Ascending Spirit Legs'] = {
        display_name = "Faded Ascending Spirit Legs",
        tier = 42,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Ascending Spirit Legs Armor', remnant_id = 168106, max_slots = 1 },
        }
    },
    ['Faded Ascending Spirit Chest'] = {
        display_name = "Faded Ascending Spirit Chest",
        tier = 42,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Ascending Spirit Chest Armor', remnant_id = 168107, max_slots = 1 },
        }
    },
    
    -- ===== FADED CELESTIAL ZENITH =====
    ['Faded Celestial Zenith Head'] = {
        display_name = "Faded Celestial Zenith Head",
        tier = 43,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Celestial Zenith Head Armor', remnant_id = 168111, max_slots = 1 },
        }
    },
    ['Faded Celestial Zenith Arms'] = {
        display_name = "Faded Celestial Zenith Arms",
        tier = 43,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Celestial Zenith Arms Armor', remnant_id = 168112, max_slots = 1 },
        }
    },
    ['Faded Celestial Zenith Wrist'] = {
        display_name = "Faded Celestial Zenith Wrist",
        tier = 43,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Celestial Zenith Wrist Armor', remnant_id = 168108, max_slots = 2 },
        }
    },
    ['Faded Celestial Zenith Hands'] = {
        display_name = "Faded Celestial Zenith Hands",
        tier = 43,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Celestial Zenith Hands Armor', remnant_id = 168109, max_slots = 1 },
        }
    },
    ['Faded Celestial Zenith Feet'] = {
        display_name = "Faded Celestial Zenith Feet",
        tier = 43,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Celestial Zenith Feet Armor', remnant_id = 168110, max_slots = 1 },
        }
    },
    ['Faded Celestial Zenith Legs'] = {
        display_name = "Faded Celestial Zenith Legs",
        tier = 43,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Celestial Zenith Legs Armor', remnant_id = 168113, max_slots = 1 },
        }
    },
    ['Faded Celestial Zenith Chest'] = {
        display_name = "Faded Celestial Zenith Chest",
        tier = 43,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Celestial Zenith Chest Armor', remnant_id = 168114, max_slots = 1 },
        }
    },
    
    -- ===== FADED SPECTRAL LUMINOSITY =====
    ['Faded Spectral Luminosity Head'] = {
        display_name = "Faded Spectral Luminosity Head",
        tier = 42,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Faded Spectral Luminosity Head Armor', remnant_id = 168118, max_slots = 1 },
        }
    },
    ['Faded Spectral Luminosity Arms'] = {
        display_name = "Faded Spectral Luminosity Arms",
        tier = 42,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Faded Spectral Luminosity Arms Armor', remnant_id = 168119, max_slots = 1 },
        }
    },
    ['Faded Spectral Luminosity Wrist'] = {
        display_name = "Faded Spectral Luminosity Wrist",
        tier = 42,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Faded Spectral Luminosity Wrist Armor', remnant_id = 168115, max_slots = 2 },
        }
    },
    ['Faded Spectral Luminosity Hands'] = {
        display_name = "Faded Spectral Luminosity Hands",
        tier = 42,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Faded Spectral Luminosity Hands Armor', remnant_id = 168116, max_slots = 1 },
        }
    },
    ['Faded Spectral Luminosity Feet'] = {
        display_name = "Faded Spectral Luminosity Feet",
        tier = 42,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Faded Spectral Luminosity Feet Armor', remnant_id = 168117, max_slots = 1 },
        }
    },
    ['Faded Spectral Luminosity Legs'] = {
        display_name = "Faded Spectral Luminosity Legs",
        tier = 42,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Faded Spectral Luminosity Legs Armor', remnant_id = 168120, max_slots = 1 },
        }
    },
    ['Faded Spectral Luminosity Chest'] = {
        display_name = "Faded Spectral Luminosity Chest",
        tier = 42,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Faded Spectral Luminosity Chest Armor', remnant_id = 168121, max_slots = 1 },
        }
    },
    
    -- ===== OBSCURED GALLANT RESONANCE =====
    ['Obscured Gallant Resonance Head'] = {
        display_name = "Obscured Gallant Resonance Head",
        tier = 50,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Obscured Gallant Resonance Head Armor', remnant_id = 171774, max_slots = 1 },
        }
    },
    ['Obscured Gallant Resonance Arms'] = {
        display_name = "Obscured Gallant Resonance Arms",
        tier = 50,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Obscured Gallant Resonance Arms Armor', remnant_id = 171775, max_slots = 1 },
        }
    },
    ['Obscured Gallant Resonance Wrist'] = {
        display_name = "Obscured Gallant Resonance Wrist",
        tier = 50,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Obscured Gallant Resonance Wrist Armor', remnant_id = 171771, max_slots = 2 },
        }
    },
    ['Obscured Gallant Resonance Hands'] = {
        display_name = "Obscured Gallant Resonance Hands",
        tier = 50,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Obscured Gallant Resonance Hands Armor', remnant_id = 171772, max_slots = 1 },
        }
    },
    ['Obscured Gallant Resonance Feet'] = {
        display_name = "Obscured Gallant Resonance Feet",
        tier = 50,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Obscured Gallant Resonance Feet Armor', remnant_id = 171773, max_slots = 1 },
        }
    },
    ['Obscured Gallant Resonance Legs'] = {
        display_name = "Obscured Gallant Resonance Legs",
        tier = 50,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Obscured Gallant Resonance Legs Armor', remnant_id = 171776, max_slots = 1 },
        }
    },
    ['Obscured Gallant Resonance Chest'] = {
        display_name = "Obscured Gallant Resonance Chest",
        tier = 50,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Obscured Gallant Resonance Chest Armor', remnant_id = 171777, max_slots = 1 },
        }
    },
    
    -- ===== OBSCURED STEADFAST RESOLVE =====
    ['Obscured Steadfast Resolve Head'] = {
        display_name = "Obscured Steadfast Resolve Head",
        tier = 50,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Obscured Steadfast Resolve Head Armor', remnant_id = 171781, max_slots = 1 },
        }
    },
    ['Obscured Steadfast Resolve Arms'] = {
        display_name = "Obscured Steadfast Resolve Arms",
        tier = 50,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Obscured Steadfast Resolve Arms Armor', remnant_id = 171782, max_slots = 1 },
        }
    },
    ['Obscured Steadfast Resolve Wrist'] = {
        display_name = "Obscured Steadfast Resolve Wrist",
        tier = 50,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Obscured Steadfast Resolve Wrist Armor', remnant_id = 171778, max_slots = 2 },
        }
    },
    ['Obscured Steadfast Resolve Hands'] = {
        display_name = "Obscured Steadfast Resolve Hands",
        tier = 50,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Obscured Steadfast Resolve Hands Armor', remnant_id = 171779, max_slots = 1 },
        }
    },
    ['Obscured Steadfast Resolve Feet'] = {
        display_name = "Obscured Steadfast Resolve Feet",
        tier = 50,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Obscured Steadfast Resolve Feet Armor', remnant_id = 171780, max_slots = 1 },
        }
    },
    ['Obscured Steadfast Resolve Legs'] = {
        display_name = "Obscured Steadfast Resolve Legs",
        tier = 50,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Obscured Steadfast Resolve Legs Armor', remnant_id = 171783, max_slots = 1 },
        }
    },
    ['Obscured Steadfast Resolve Chest'] = {
        display_name = "Obscured Steadfast Resolve Chest",
        tier = 50,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Obscured Steadfast Resolve Chest Armor', remnant_id = 171784, max_slots = 1 },
        }
    },
    
    -- ===== OBSCURED HEROIC REFLECTIONS =====
    ['Obscured Heroic Reflections Head'] = {
        display_name = "Obscured Heroic Reflections Head",
        tier = 48,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Obscured Heroic Reflections Head Armor', remnant_id = 171788, max_slots = 1 },
        }
    },
    ['Obscured Heroic Reflections Arms'] = {
        display_name = "Obscured Heroic Reflections Arms",
        tier = 48,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Obscured Heroic Reflections Arms Armor', remnant_id = 171789, max_slots = 1 },
        }
    },
    ['Obscured Heroic Reflections Wrist'] = {
        display_name = "Obscured Heroic Reflections Wrist",
        tier = 48,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Obscured Heroic Reflections Wrist Armor', remnant_id = 171785, max_slots = 2 },
        }
    },
    ['Obscured Heroic Reflections Hands'] = {
        display_name = "Obscured Heroic Reflections Hands",
        tier = 48,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Obscured Heroic Reflections Hands Armor', remnant_id = 171786, max_slots = 1 },
        }
    },
    ['Obscured Heroic Reflections Feet'] = {
        display_name = "Obscured Heroic Reflections Feet",
        tier = 48,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Obscured Heroic Reflections Feet Armor', remnant_id = 171787, max_slots = 1 },
        }
    },
    ['Obscured Heroic Reflections Legs'] = {
        display_name = "Obscured Heroic Reflections Legs",
        tier = 48,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Obscured Heroic Reflections Legs Armor', remnant_id = 171790, max_slots = 1 },
        }
    },
    ['Obscured Heroic Reflections Chest'] = {
        display_name = "Obscured Heroic Reflections Chest",
        tier = 48,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Obscured Heroic Reflections Chest Armor', remnant_id = 171791, max_slots = 1 },
        }
    },
    
    -- ===== OBSCURED OF THE ENTHRALLED =====
    ['Obscured of the Enthralled Head'] = {
        display_name = "Obscured of the Enthralled Head",
        tier = 49,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Obscured Head Armor of the Enthralled', remnant_id = 174004, max_slots = 1 },
        }
    },
    ['Obscured of the Enthralled Arms'] = {
        display_name = "Obscured of the Enthralled Arms",
        tier = 49,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Obscured Arms Armor of the Enthralled', remnant_id = 174005, max_slots = 1 },
        }
    },
    ['Obscured of the Enthralled Wrist'] = {
        display_name = "Obscured of the Enthralled Wrist",
        tier = 49,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Obscured Wrist Armor of the Enthralled', remnant_id = 174001, max_slots = 2 },
        }
    },
    ['Obscured of the Enthralled Hands'] = {
        display_name = "Obscured of the Enthralled Hands",
        tier = 49,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Obscured Hands Armor of the Enthralled', remnant_id = 174002, max_slots = 1 },
        }
    },
    ['Obscured of the Enthralled Feet'] = {
        display_name = "Obscured of the Enthralled Feet",
        tier = 49,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Obscured Feet Armor of the Enthralled', remnant_id = 174003, max_slots = 1 },
        }
    },
    ['Obscured of the Enthralled Legs'] = {
        display_name = "Obscured of the Enthralled Legs",
        tier = 49,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Obscured Legs Armor of the Enthralled', remnant_id = 174006, max_slots = 1 },
        }
    },
    ['Obscured of the Enthralled Chest'] = {
        display_name = "Obscured of the Enthralled Chest",
        tier = 49,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Obscured Chest Armor of the Enthralled', remnant_id = 174007, max_slots = 1 },
        }
    },
    
    -- ===== OBSCURED OF THE SHACKLED =====
    ['Obscured of the Shackled Head'] = {
        display_name = "Obscured of the Shackled Head",
        tier = 49,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Obscured Head Armor of the Shackled', remnant_id = 174011, max_slots = 1 },
        }
    },
    ['Obscured of the Shackled Arms'] = {
        display_name = "Obscured of the Shackled Arms",
        tier = 49,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Obscured Arms Armor of the Shackled', remnant_id = 174012, max_slots = 1 },
        }
    },
    ['Obscured of the Shackled Wrist'] = {
        display_name = "Obscured of the Shackled Wrist",
        tier = 49,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Obscured Wrist Armor of the Shackled', remnant_id = 174008, max_slots = 2 },
        }
    },
    ['Obscured of the Shackled Hands'] = {
        display_name = "Obscured of the Shackled Hands",
        tier = 49,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Obscured Hands Armor of the Shackled', remnant_id = 174009, max_slots = 1 },
        }
    },
    ['Obscured of the Shackled Feet'] = {
        display_name = "Obscured of the Shackled Feet",
        tier = 49,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Obscured Feet Armor of the Shackled', remnant_id = 174010, max_slots = 1 },
        }
    },
    ['Obscured of the Shackled Legs'] = {
        display_name = "Obscured of the Shackled Legs",
        tier = 49,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Obscured Legs Armor of the Shackled', remnant_id = 174013, max_slots = 1 },
        }
    },
    ['Obscured of the Shackled Chest'] = {
        display_name = "Obscured of the Shackled Chest",
        tier = 49,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Obscured Chest Armor of the Shackled', remnant_id = 174014, max_slots = 1 },
        }
    },
    
    -- ===== OBSCURED OF THE BOUND =====
    ['Obscured of the Bound Head'] = {
        display_name = "Obscured of the Bound Head",
        tier = 49,
        pieces = {
            ['Head'] = { slots = { 2 }, remnant_name = 'Obscured Head Armor of the Bound', remnant_id = 174025, max_slots = 1 },
        }
    },
    ['Obscured of the Bound Arms'] = {
        display_name = "Obscured of the Bound Arms",
        tier = 49,
        pieces = {
            ['Arms'] = { slots = { 7 }, remnant_name = 'Obscured Arms Armor of the Bound', remnant_id = 174026, max_slots = 1 },
        }
    },
    ['Obscured of the Bound Wrist'] = {
        display_name = "Obscured of the Bound Wrist",
        tier = 49,
        pieces = {
            ['Wrist'] = { slots = { 9, 10 }, remnant_name = 'Obscured Wrist Armor of the Bound', remnant_id = 174022, max_slots = 2 },
        }
    },
    ['Obscured of the Bound Hands'] = {
        display_name = "Obscured of the Bound Hands",
        tier = 49,
        pieces = {
            ['Hands'] = { slots = { 12 }, remnant_name = 'Obscured Hands Armor of the Bound', remnant_id = 174023, max_slots = 1 },
        }
    },
    ['Obscured of the Bound Feet'] = {
        display_name = "Obscured of the Bound Feet",
        tier = 49,
        pieces = {
            ['Feet'] = { slots = { 19 }, remnant_name = 'Obscured Feet Armor of the Bound', remnant_id = 174024, max_slots = 1 },
        }
    },
    ['Obscured of the Bound Legs'] = {
        display_name = "Obscured of the Bound Legs",
        tier = 49,
        pieces = {
            ['Legs'] = { slots = { 18 }, remnant_name = 'Obscured Legs Armor of the Bound', remnant_id = 174027, max_slots = 1 },
        }
    },
    ['Obscured of the Bound Chest'] = {
        display_name = "Obscured of the Bound Chest",
        tier = 49,
        pieces = {
            ['Chest'] = { slots = { 17 }, remnant_name = 'Obscured Chest Armor of the Bound', remnant_id = 174028, max_slots = 1 },
        }
    },
}

-- Seeds of Destruction Essences (tiers 3-5)
-- These are crafting components used in SoD armor combines
-- Tier 3: Seminal essences (Field of Scale group tier 3)
-- Tier 4: Medial & Primeval essences (group and raid tier 4)
-- Tier 5: Eternal & Coeval essences (group tier 5 and raid tier 5)

local sod_essences = {
    -- SEMINAL ESSENCES (tier 3 - Field of Scale group combines)
    ['Seminal Incandessence'] = {
        display_name = 'Seminal Incandessence',
        tier = 3,
    },
    ['Seminal Luminessence'] = {
        display_name = 'Seminal Luminessence',
        tier = 3,
    },

    -- MEDIAL ESSENCES (tier 4 - Earth group combines)
    ['Distorted Medial Incandessence'] = {
        display_name = 'Distorted Medial Incandessence',
        tier = 4,
    },
    ['Distorted Medial Luminessence'] = {
        display_name = 'Distorted Medial Luminessence',
        tier = 4,
    },
    ['Fractured Medial Incandessence'] = {
        display_name = 'Fractured Medial Incandessence',
        tier = 4,
    },
    ['Fractured Medial Luminessence'] = {
        display_name = 'Fractured Medial Luminessence',
        tier = 4,
    },
    ['Phased Medial Incandessence'] = {
        display_name = 'Phased Medial Incandessence',
        tier = 4,
    },
    ['Phased Medial Luminessence'] = {
        display_name = 'Phased Medial Luminessence',
        tier = 4,
    },
    ['Warped Medial Incandessence'] = {
        display_name = 'Warped Medial Incandessence',
        tier = 4,
    },
    ['Warped Medial Luminessence'] = {
        display_name = 'Warped Medial Luminessence',
        tier = 4,
    },

    -- ETERNAL ESSENCES (tier 5 - Kuua/Discord group combines)
    ['Distorted Eternal Incandessence'] = {
        display_name = 'Distorted Eternal Incandessence',
        tier = 5,
    },
    ['Distorted Eternal Luminessence'] = {
        display_name = 'Distorted Eternal Luminessence',
        tier = 5,
    },
    ['Fractured Eternal Incandessence'] = {
        display_name = 'Fractured Eternal Incandessence',
        tier = 5,
    },
    ['Fractured Eternal Luminessence'] = {
        display_name = 'Fractured Eternal Luminessence',
        tier = 5,
    },
    ['Phased Eternal Incandessence'] = {
        display_name = 'Phased Eternal Incandessence',
        tier = 5,
    },
    ['Phased Eternal Luminessence'] = {
        display_name = 'Phased Eternal Luminessence',
        tier = 5,
    },
    ['Warped Eternal Incandessence'] = {
        display_name = 'Warped Eternal Incandessence',
        tier = 5,
    },
    ['Warped Eternal Luminessence'] = {
        display_name = 'Warped Eternal Luminessence',
        tier = 5,
    },

    -- PRIMEVAL ESSENCES (tier 4 - Earth/Korafax raid tier 4)
    ['Distorted Primeval Incandessence'] = {
        display_name = 'Distorted Primeval Incandessence',
        tier = 4,
    },
    ['Distorted Primeval Luminessence'] = {
        display_name = 'Distorted Primeval Luminessence',
        tier = 4,
    },
    ['Fractured Primeval Incandessence'] = {
        display_name = 'Fractured Primeval Incandessence',
        tier = 4,
    },
    ['Fractured Primeval Luminessence'] = {
        display_name = 'Fractured Primeval Luminessence',
        tier = 4,
    },
    ['Phased Primeval Incandessence'] = {
        display_name = 'Phased Primeval Incandessence',
        tier = 4,
    },
    ['Phased Primeval Luminessence'] = {
        display_name = 'Phased Primeval Luminessence',
        tier = 4,
    },
    ['Warped Primeval Incandessence'] = {
        display_name = 'Warped Primeval Incandessence',
        tier = 4,
    },
    ['Warped Primeval Luminessence'] = {
        display_name = 'Warped Primeval Luminessence',
        tier = 4,
    },

    -- COEVAL ESSENCES (tier 5 - Tower of Discord raid tier 5)
    ['Distorted Coeval Incandessence'] = {
        display_name = 'Distorted Coeval Incandessence',
        tier = 5,
    },
    ['Distorted Coeval Luminessence'] = {
        display_name = 'Distorted Coeval Luminessence',
        tier = 5,
    },
    ['Fractured Coeval Incandessence'] = {
        display_name = 'Fractured Coeval Incandessence',
        tier = 5,
    },
    ['Fractured Coeval Luminessence'] = {
        display_name = 'Fractured Coeval Luminessence',
        tier = 5,
    },
    ['Phased Coeval Incandessence'] = {
        display_name = 'Phased Coeval Incandessence',
        tier = 5,
    },
    ['Phased Coeval Luminessence'] = {
        display_name = 'Phased Coeval Luminessence',
        tier = 5,
    },
    ['Warped Coeval Incandessence'] = {
        display_name = 'Warped Coeval Incandessence',
        tier = 5,
    },
    ['Warped Coeval Luminessence'] = {
        display_name = 'Warped Coeval Luminessence',
        tier = 5,
    },
}

-- Merge SoD essences into armor_sets table
for key, value in pairs(sod_essences) do
    armor_sets[key] = value
end

-- Return a single table with both armor_sets and ARMOR_PROGRESSION
-- Note: require() only returns one value reliably, so we wrap both in a table
return {
    armor_sets = armor_sets,
    ARMOR_PROGRESSION = ARMOR_PROGRESSION
}







