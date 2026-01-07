--[[
WARNING: This ItemTypes mapping is INCORRECT for weapon item types in the MQ2LinkDB database!
The mapping here does NOT match actual database itemtype values for weapons.
For example:
  - Database itemtype 3 = Piercing weapon (NOT "Piercing" as listed here)
  - Database itemtype 4 = 1H Blunt (NOT "1H Blunt" as listed here)  
  - Database itemtype 8 = Shield (NOT "Throwingv1" as listed here)

This file is still used for some item type checks (Food, Drink, Potion, Augmentation)
but DO NOT rely on it for weapon type comparisons or equipment filtering.
Use the raw itemtype values directly from the database for equipment logic.
]]

local ItemTypes = {
	"1H Slashing",
	"2H Slashing",
	"Piercing",
	"1H Blunt",
	"2H Blunt",
	"Archery",
	"Crossbow",
	"Throwingv1",
	"Shield",
	"Spell",
	"Armor",
	"Misc",
	"Lockpicks",
	"Fist",
	"Food",
	"Drink",
	"Light",
	"Combinable",
	"Bandages",
	"Ammo",
	"Scroll",
	"Potion",
	"Skill",
	"Wind Instrument",
	"Stringed Instrument",
	"Brass Instrument",
	"Percussion Instrument",
	"Arrow",
	"Bolt",
	"Jewelry",
	"Artifact",
	"Book",
	"Note",
	"Key",
	"Ticket",
	"2H Piercing",
	"Fishing Pole",
	"Fishing Bait",
	"Alcohol",
	"House Key",
	"Compass",
	"Metal Key",
	"Poison",
	"Magic Arrow",
	"Magic Bolt",
	"Martial",
	"Item Has Effect",
	"Haste Item",
	"Item Has FT",
	"Item Has Focus",
	"Singing Instrument",
	"All Instruments",
	"Charm",
	"Dye",
	"Augmentation",
	"Augmentat Destroy Solvent",
	"Augmentat Remove Solvent",
	"Alternate Ability",
	"Guild Banner Kit",
	"Guild Banner Modify Token",
	"Recipe Book",
	"Voluntary Spellcast Book",
	"Auto Spellcast Book",
	"Point Currency",
	"Universal Augment Solvent",
	"Placeable",
	"Collectible",
	"Container",
	"Mount",
	"Illusion",
	"Familiar",
}

return ItemTypes
