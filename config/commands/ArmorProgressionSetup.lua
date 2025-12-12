-- Armor Progression Setup Command Handler
-- Integrates with YALM2 command system
-- Place in: config/commands/armor_progression_setup.lua

local mq = require("mq")
local Write = require("yalm2.lib.Write")

local function setupArmorProgression()
    print("^2[YALM2] Starting Armor Progression Setup...^0")
    print("^3[YALM2] This will configure 530 armor craft component items globally.^0")
    
    -- Define all armor craft component items with their keep quantities
    local armorItems = {
        -- ===== EXPANSION 1: Luminessence/Incandessence =====
        "Luminessence of Knowledge", "Luminessence of Devotion", "Luminessence of Truth",
        "Luminessence of Greed", "Luminessence of Desire", "Luminessence of Fear",
        "Luminessence of Survival", "Incandessence of Knowledge", "Incandessence of Devotion",
        "Incandessence of Truth", "Incandessence of Greed", "Incandessence of Desire",
        "Incandessence of Fear", "Incandessence of Survival",
        "Helm of Luminessence", "Armguards of Luminessence", "Bracer of Luminessence",
        "Gloves of Luminessence", "Boots of Luminessence", "Leggings of Luminessence",
        "Tunic of Luminessence", "Helm of Incandessence", "Armguards of Incandessence",
        "Bracer of Incandessence", "Gloves of Incandessence", "Boots of Incandessence",
        "Leggings of Incandessence", "Tunic of Incandessence",
        "Glowing Luminessence Shard", "Glowing Incandessence Shard",
        "Radiant Luminessence Fragment", "Radiant Incandessence Fragment",
        "Shimmering Luminessence Essence", "Shimmering Incandessence Essence",
        "Pulsing Luminessence Core", "Pulsing Incandessence Core",
        "Crystalline Luminessence Cluster", "Crystalline Incandessence Cluster",
        "Luminescent Residue", "Incandescent Residue",
        
        -- ===== EXPANSION 2: Encrusted Clay =====
        "Celestrium Encrusted Helm Clay", "Celestrium Encrusted Armguards Clay",
        "Celestrium Encrusted Bracer Clay", "Celestrium Encrusted Gloves Clay",
        "Celestrium Encrusted Boots Clay", "Celestrium Encrusted Leggings Clay",
        "Celestrium Encrusted Tunic Clay", "Celestrium Encrusted Breastplate Clay",
        "Damascite Encrusted Helm Clay", "Damascite Encrusted Armguards Clay",
        "Damascite Encrusted Bracer Clay", "Damascite Encrusted Gloves Clay",
        "Damascite Encrusted Boots Clay", "Damascite Encrusted Leggings Clay",
        "Damascite Encrusted Tunic Clay", "Damascite Encrusted Breastplate Clay",
        "Iridium Encrusted Helm Clay", "Iridium Encrusted Armguards Clay",
        "Iridium Encrusted Bracer Clay", "Iridium Encrusted Gloves Clay",
        "Iridium Encrusted Boots Clay", "Iridium Encrusted Leggings Clay",
        "Iridium Encrusted Tunic Clay", "Iridium Encrusted Breastplate Clay",
        "Palladium Encrusted Helm Clay", "Palladium Encrusted Armguards Clay",
        "Palladium Encrusted Bracer Clay", "Palladium Encrusted Gloves Clay",
        "Palladium Encrusted Boots Clay", "Palladium Encrusted Leggings Clay",
        "Palladium Encrusted Tunic Clay", "Palladium Encrusted Breastplate Clay",
        "Rhodium Encrusted Helm Clay", "Rhodium Encrusted Armguards Clay",
        "Rhodium Encrusted Bracer Clay", "Rhodium Encrusted Gloves Clay",
        "Rhodium Encrusted Boots Clay", "Rhodium Encrusted Leggings Clay",
        "Rhodium Encrusted Tunic Clay", "Rhodium Encrusted Breastplate Clay",
        "Stellite Encrusted Helm Clay", "Stellite Encrusted Armguards Clay",
        "Stellite Encrusted Bracer Clay", "Stellite Encrusted Gloves Clay",
        "Stellite Encrusted Boots Clay", "Stellite Encrusted Leggings Clay",
        "Stellite Encrusted Tunic Clay", "Stellite Encrusted Breastplate Clay",
        "Vitallium Encrusted Helm Clay", "Vitallium Encrusted Armguards Clay",
        "Vitallium Encrusted Bracer Clay", "Vitallium Encrusted Gloves Clay",
        "Vitallium Encrusted Boots Clay", "Vitallium Encrusted Leggings Clay",
        "Vitallium Encrusted Tunic Clay", "Vitallium Encrusted Breastplate Clay",
        
        -- ===== EXPANSION 3: Remnant Tiers (8 × 7) =====
        "Abstruse Remnant of Knowledge", "Abstruse Remnant of Devotion", "Abstruse Remnant of Truth",
        "Abstruse Remnant of Greed", "Abstruse Remnant of Desire", "Abstruse Remnant of Fear",
        "Abstruse Remnant of Survival",
        "Recondite Remnant of Knowledge", "Recondite Remnant of Devotion", "Recondite Remnant of Truth",
        "Recondite Remnant of Greed", "Recondite Remnant of Desire", "Recondite Remnant of Fear",
        "Recondite Remnant of Survival",
        "Ambiguous Remnant of Knowledge", "Ambiguous Remnant of Devotion", "Ambiguous Remnant of Truth",
        "Ambiguous Remnant of Greed", "Ambiguous Remnant of Desire", "Ambiguous Remnant of Fear",
        "Ambiguous Remnant of Survival",
        "Lucid Remnant of Knowledge", "Lucid Remnant of Devotion", "Lucid Remnant of Truth",
        "Lucid Remnant of Greed", "Lucid Remnant of Desire", "Lucid Remnant of Fear",
        "Lucid Remnant of Survival",
        "Enigmatic Remnant of Knowledge", "Enigmatic Remnant of Devotion", "Enigmatic Remnant of Truth",
        "Enigmatic Remnant of Greed", "Enigmatic Remnant of Desire", "Enigmatic Remnant of Fear",
        "Enigmatic Remnant of Survival",
        "Esoteric Remnant of Knowledge", "Esoteric Remnant of Devotion", "Esoteric Remnant of Truth",
        "Esoteric Remnant of Greed", "Esoteric Remnant of Desire", "Esoteric Remnant of Fear",
        "Esoteric Remnant of Survival",
        "Obscure Remnant of Knowledge", "Obscure Remnant of Devotion", "Obscure Remnant of Truth",
        "Obscure Remnant of Greed", "Obscure Remnant of Desire", "Obscure Remnant of Fear",
        "Obscure Remnant of Survival",
        "Perspicuous Remnant of Knowledge", "Perspicuous Remnant of Devotion", "Perspicuous Remnant of Truth",
        "Perspicuous Remnant of Greed", "Perspicuous Remnant of Desire", "Perspicuous Remnant of Fear",
        "Perspicuous Remnant of Survival",
        
        -- ===== EXPANSION 4: Armor Tiers (8 × 7) =====
        "Rustic of Argath", "Rustic of Lunanyn", "Rustic of Takish-Hiz", "Rustic of Tormax",
        "Rustic of Ssraeshza", "Rustic of Chardok", "Rustic of Shei-Viatha",
        "Formal of Argath", "Formal of Lunanyn", "Formal of Takish-Hiz", "Formal of Tormax",
        "Formal of Ssraeshza", "Formal of Chardok", "Formal of Shei-Viatha",
        "Embellished of Argath", "Embellished of Lunanyn", "Embellished of Takish-Hiz", "Embellished of Tormax",
        "Embellished of Ssraeshza", "Embellished of Chardok", "Embellished of Shei-Viatha",
        "Grandiose of Argath", "Grandiose of Lunanyn", "Grandiose of Takish-Hiz", "Grandiose of Tormax",
        "Grandiose of Ssraeshza", "Grandiose of Chardok", "Grandiose of Shei-Viatha",
        "Modest of Illdaera", "Elegant of Illdaera", "Stately of Illdaera", "Ostentatious of Illdaera",
        "Illdaera of Vasty", "Illdaera of Kodtaz", "Illdaera of Sebilis",
        "Elegant of Valinteir", "Stately of Valinteir", "Ostentatious of Valinteir",
        "Valinteir of Vexthal", "Valinteir of Plane of Storms", "Valinteir of Plane of Innovation",
        
        -- ===== EXPANSION 5: Fear & Dread (8 × 7) =====
        "Fear Touched of Knowledge", "Fear Touched of Devotion", "Fear Touched of Truth",
        "Fear Touched of Greed", "Fear Touched of Desire", "Fear Touched of Fear",
        "Fear Touched of Survival",
        "Fear Stained of Knowledge", "Fear Stained of Devotion", "Fear Stained of Truth",
        "Fear Stained of Greed", "Fear Stained of Desire", "Fear Stained of Fear",
        "Fear Stained of Survival",
        "Fear Washed of Knowledge", "Fear Washed of Devotion", "Fear Washed of Truth",
        "Fear Washed of Greed", "Fear Washed of Desire", "Fear Washed of Fear",
        "Fear Washed of Survival",
        "Fear Infused of Knowledge", "Fear Infused of Devotion", "Fear Infused of Truth",
        "Fear Infused of Greed", "Fear Infused of Desire", "Fear Infused of Fear",
        "Fear Infused of Survival",
        "Dread Touched of Knowledge", "Dread Touched of Devotion", "Dread Touched of Truth",
        "Dread Touched of Greed", "Dread Touched of Desire", "Dread Touched of Fear",
        "Dread Touched of Survival",
        "Dread of Knowledge", "Dread of Devotion", "Dread of Truth",
        "Dread of Greed", "Dread of Desire", "Dread of Fear",
        "Dread of Survival",
        "Dread Washed of Knowledge", "Dread Washed of Devotion", "Dread Washed of Truth",
        "Dread Washed of Greed", "Dread Washed of Desire", "Dread Washed of Fear",
        "Dread Washed of Survival",
        "Dread Infused of Knowledge", "Dread Infused of Devotion", "Dread Infused of Truth",
        "Dread Infused of Greed", "Dread Infused of Desire", "Dread Infused of Fear",
        "Dread Infused of Survival",
        
        -- ===== EXPANSION 6: Ether (4 × 7) =====
        "Helm of Latent Ether", "Armguards of Latent Ether", "Bracer of Latent Ether",
        "Gloves of Latent Ether", "Boots of Latent Ether", "Leggings of Latent Ether",
        "Tunic of Latent Ether",
        "Helm of Suppressed Ether", "Armguards of Suppressed Ether", "Bracer of Suppressed Ether",
        "Gloves of Suppressed Ether", "Boots of Suppressed Ether", "Leggings of Suppressed Ether",
        "Tunic of Suppressed Ether",
        "Helm of Manifested Ether", "Armguards of Manifested Ether", "Bracer of Manifested Ether",
        "Gloves of Manifested Ether", "Boots of Manifested Ether", "Leggings of Manifested Ether",
        "Tunic of Manifested Ether",
        "Helm of Flowing Ether", "Armguards of Flowing Ether", "Bracer of Flowing Ether",
        "Gloves of Flowing Ether", "Boots of Flowing Ether", "Leggings of Flowing Ether",
        "Tunic of Flowing Ether",
        
        -- ===== EXPANSION 7: Water-Themed (4 × 7) =====
        "Castaway Helm", "Castaway Armguards", "Castaway Bracer", "Castaway Gloves",
        "Castaway Boots", "Castaway Leggings", "Castaway Tunic",
        "Tideworn Helm", "Tideworn Armguards", "Tideworn Bracer", "Tideworn Gloves",
        "Tideworn Boots", "Tideworn Leggings", "Tideworn Tunic",
        "Highwater Helm", "Highwater Armguards", "Highwater Bracer", "Highwater Gloves",
        "Highwater Boots", "Highwater Leggings", "Highwater Tunic",
        "Darkwater Helm", "Darkwater Armguards", "Darkwater Bracer", "Darkwater Gloves",
        "Darkwater Boots", "Darkwater Leggings", "Darkwater Tunic",
        
        -- ===== EXPANSION 8: Raw Crypt-Hunter =====
        "Raw Crypt-Hunter's Cap", "Raw Crypt-Hunter's Sleeves", "Raw Crypt-Hunter's Wristguard",
        "Raw Crypt-Hunter's Gloves", "Raw Crypt-Hunter's Boots", "Raw Crypt-Hunter's Leggings",
        "Raw Crypt-Hunter's Chestpiece",
        
        -- ===== EXPANSION 9: Amorphous Templates (3 × 7) =====
        "Amorphous Cohort's Helm", "Amorphous Cohort's Sleeves", "Amorphous Cohort's Wristguard",
        "Amorphous Cohort's Gauntlets", "Amorphous Cohort's Boots", "Amorphous Cohort's Leggings",
        "Amorphous Cohort's Breastplate",
        "Amorphous Selrach's Helm", "Amorphous Selrach's Sleeves", "Amorphous Selrach's Wristguard",
        "Amorphous Selrach's Gauntlets", "Amorphous Selrach's Boots", "Amorphous Selrach's Leggings",
        "Amorphous Selrach's Breastplate",
        "Amorphous Velazul's Helm", "Amorphous Velazul's Sleeves", "Amorphous Velazul's Wristguard",
        "Amorphous Velazul's Gauntlets", "Amorphous Velazul's Boots", "Amorphous Velazul's Leggings",
        "Amorphous Velazul's Breastplate",
        
        -- ===== EXPANSION 10: Scale Touched Facets =====
        "Scale Touched Cap Facet", "Scale Touched Sleeve Facet", "Scale Touched Bracer Facet",
        "Scale Touched Gloves Facet", "Scale Touched Shoes Facet", "Scale Touched Pants Facet",
        "Scale Touched Tunic Facet",
        
        -- ===== EXPANSION 11: Scaled & Scaleborn Facets (2 × 7) =====
        "Scaled Cap Facet", "Scaled Sleeve Facet", "Scaled Bracer Facet", "Scaled Gloves Facet",
        "Scaled Shoes Facet", "Scaled Pants Facet", "Scaled Tunic Facet",
        "Scaleborn Cap Facet", "Scaleborn Sleeve Facet", "Scaleborn Bracer Facet", "Scaleborn Gloves Facet",
        "Scaleborn Shoes Facet", "Scaleborn Pants Facet", "Scaleborn Tunic Facet",
        
        -- ===== EXPANSION 12: Binding Muhbis (5 × 7) =====
        "Adamant Triumphant Cloud Binding Head Muhbis", "Adamant Triumphant Cloud Binding Arms Muhbis",
        "Adamant Triumphant Cloud Binding Wrist Muhbis", "Adamant Triumphant Cloud Binding Hands Muhbis",
        "Adamant Triumphant Cloud Binding Feet Muhbis", "Adamant Triumphant Cloud Binding Legs Muhbis",
        "Adamant Triumphant Cloud Binding Chest Muhbis",
        "Battleworn Stalwart Moon Binding Head Muhbis", "Battleworn Stalwart Moon Binding Arms Muhbis",
        "Battleworn Stalwart Moon Binding Wrist Muhbis", "Battleworn Stalwart Moon Binding Hands Muhbis",
        "Battleworn Stalwart Moon Binding Feet Muhbis", "Battleworn Stalwart Moon Binding Legs Muhbis",
        "Battleworn Stalwart Moon Binding Chest Muhbis",
        "Heavenly Glorious Void Binding Head Muhbis", "Heavenly Glorious Void Binding Arms Muhbis",
        "Heavenly Glorious Void Binding Wrist Muhbis", "Heavenly Glorious Void Binding Hands Muhbis",
        "Heavenly Glorious Void Binding Feet Muhbis", "Heavenly Glorious Void Binding Legs Muhbis",
        "Heavenly Glorious Void Binding Chest Muhbis",
        "Veiled Victorious Horizon Binding Head Muhbis", "Veiled Victorious Horizon Binding Arms Muhbis",
        "Veiled Victorious Horizon Binding Wrist Muhbis", "Veiled Victorious Horizon Binding Hands Muhbis",
        "Veiled Victorious Horizon Binding Feet Muhbis", "Veiled Victorious Horizon Binding Legs Muhbis",
        "Veiled Victorious Horizon Binding Chest Muhbis",
        "Weeping Undefeated Heaven Binding Head Muhbis", "Weeping Undefeated Heaven Binding Arms Muhbis",
        "Weeping Undefeated Heaven Binding Wrist Muhbis", "Weeping Undefeated Heaven Binding Hands Muhbis",
        "Weeping Undefeated Heaven Binding Feet Muhbis", "Weeping Undefeated Heaven Binding Legs Muhbis",
        "Weeping Undefeated Heaven Binding Chest Muhbis",
        
        -- ===== EXPANSION 13: Faded & Obscured Armor (18 × 7) =====
        "Faded Icebound Head Armor", "Faded Icebound Arms Armor", "Faded Icebound Wrist Armor",
        "Faded Icebound Hands Armor", "Faded Icebound Feet Armor", "Faded Icebound Legs Armor",
        "Faded Icebound Chest Armor",
        "Faded Ice Woven Head Armor", "Faded Ice Woven Arms Armor", "Faded Ice Woven Wrist Armor",
        "Faded Ice Woven Hands Armor", "Faded Ice Woven Feet Armor", "Faded Ice Woven Legs Armor",
        "Faded Ice Woven Chest Armor",
        "Faded Snowbound Head Armor", "Faded Snowbound Arms Armor", "Faded Snowbound Wrist Armor",
        "Faded Snowbound Hands Armor", "Faded Snowbound Feet Armor", "Faded Snowbound Legs Armor",
        "Faded Snowbound Chest Armor",
        "Faded Snowsquall Head Armor", "Faded Snowsquall Arms Armor", "Faded Snowsquall Wrist Armor",
        "Faded Snowsquall Hands Armor", "Faded Snowsquall Feet Armor", "Faded Snowsquall Legs Armor",
        "Faded Snowsquall Chest Armor",
        "Faded Blizzard Head Armor", "Faded Blizzard Arms Armor", "Faded Blizzard Wrist Armor",
        "Faded Blizzard Hands Armor", "Faded Blizzard Feet Armor", "Faded Blizzard Legs Armor",
        "Faded Blizzard Chest Armor",
        "Faded Hoarfrost Head Armor", "Faded Hoarfrost Arms Armor", "Faded Hoarfrost Wrist Armor",
        "Faded Hoarfrost Hands Armor", "Faded Hoarfrost Feet Armor", "Faded Hoarfrost Legs Armor",
        "Faded Hoarfrost Chest Armor",
        "Faded Waxing Crescent Head Armor", "Faded Waxing Crescent Arms Armor", "Faded Waxing Crescent Wrist Armor",
        "Faded Waxing Crescent Hands Armor", "Faded Waxing Crescent Feet Armor", "Faded Waxing Crescent Legs Armor",
        "Faded Waxing Crescent Chest Armor",
        "Faded Waning Crescent Head Armor", "Faded Waning Crescent Arms Armor", "Faded Waning Crescent Wrist Armor",
        "Faded Waning Crescent Hands Armor", "Faded Waning Crescent Feet Armor", "Faded Waning Crescent Legs Armor",
        "Faded Waning Crescent Chest Armor",
        "Faded Waning Gibbous Head Armor", "Faded Waning Gibbous Arms Armor", "Faded Waning Gibbous Wrist Armor",
        "Faded Waning Gibbous Hands Armor", "Faded Waning Gibbous Feet Armor", "Faded Waning Gibbous Legs Armor",
        "Faded Waning Gibbous Chest Armor",
        "Faded Ascending Spirit Head Armor", "Faded Ascending Spirit Arms Armor", "Faded Ascending Spirit Wrist Armor",
        "Faded Ascending Spirit Hands Armor", "Faded Ascending Spirit Feet Armor", "Faded Ascending Spirit Legs Armor",
        "Faded Ascending Spirit Chest Armor",
        "Faded Celestial Zenith Head Armor", "Faded Celestial Zenith Arms Armor", "Faded Celestial Zenith Wrist Armor",
        "Faded Celestial Zenith Hands Armor", "Faded Celestial Zenith Feet Armor", "Faded Celestial Zenith Legs Armor",
        "Faded Celestial Zenith Chest Armor",
        "Faded Spectral Luminosity Head Armor", "Faded Spectral Luminosity Arms Armor", "Faded Spectral Luminosity Wrist Armor",
        "Faded Spectral Luminosity Hands Armor", "Faded Spectral Luminosity Feet Armor", "Faded Spectral Luminosity Legs Armor",
        "Faded Spectral Luminosity Chest Armor",
        "Obscured Gallant Resonance Head Armor", "Obscured Gallant Resonance Arms Armor", "Obscured Gallant Resonance Wrist Armor",
        "Obscured Gallant Resonance Hands Armor", "Obscured Gallant Resonance Feet Armor", "Obscured Gallant Resonance Legs Armor",
        "Obscured Gallant Resonance Chest Armor",
        "Obscured Steadfast Resolve Head Armor", "Obscured Steadfast Resolve Arms Armor", "Obscured Steadfast Resolve Wrist Armor",
        "Obscured Steadfast Resolve Hands Armor", "Obscured Steadfast Resolve Feet Armor", "Obscured Steadfast Resolve Legs Armor",
        "Obscured Steadfast Resolve Chest Armor",
        "Obscured Heroic Reflections Head Armor", "Obscured Heroic Reflections Arms Armor", "Obscured Heroic Reflections Wrist Armor",
        "Obscured Heroic Reflections Hands Armor", "Obscured Heroic Reflections Feet Armor", "Obscured Heroic Reflections Legs Armor",
        "Obscured Heroic Reflections Chest Armor",
        "Obscured Head Armor of the Enthralled", "Obscured Arms Armor of the Enthralled", "Obscured Wrist Armor of the Enthralled",
        "Obscured Hands Armor of the Enthralled", "Obscured Feet Armor of the Enthralled", "Obscured Legs Armor of the Enthralled",
        "Obscured Chest Armor of the Enthralled",
        "Obscured Head Armor of the Shackled", "Obscured Arms Armor of the Shackled", "Obscured Wrist Armor of the Shackled",
        "Obscured Hands Armor of the Shackled", "Obscured Feet Armor of the Shackled", "Obscured Legs Armor of the Shackled",
        "Obscured Chest Armor of the Shackled",
        "Obscured Head Armor of the Bound", "Obscured Arms Armor of the Bound", "Obscured Wrist Armor of the Bound",
        "Obscured Hands Armor of the Bound", "Obscured Feet Armor of the Bound", "Obscured Legs Armor of the Bound",
        "Obscured Chest Armor of the Bound",
    }
    
    local count = 0
    local errors = 0
    
    print("^2[YALM2] Configuring 530 armor craft components...^0")
    
    for _, itemName in ipairs(armorItems) do
        -- Determine keep quantity: wrist items get 2, all others get 1
        -- Wrist items contain "Bracer" or "Wrist" in the name
        local keep = 1
        if itemName:find("Bracer") or itemName:find("Wrist") or itemName:find("Wristguard") then
            keep = 2
        end
        
        -- Build and execute the command
        -- Format: Keep|1 or Keep|2 where the number is the quantity
        local cmd = string.format('/yalm2 setitem "%s" "Keep|%d" all', itemName, keep)
        mq.cmd(cmd)
        
        count = count + 1
        if count % 50 == 0 then
            print(string.format("^3[YALM2] Progress: %d/530 items configured^0", count))
        end
    end
    
    print(string.format("^2[YALM2] Setup Complete! ^3Configured %d items^0", count))
end

local function action(global_settings, char_settings, args)
    setupArmorProgression()
end

return { action_func = action }
