--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}

CDTL3.icons = {
	era = {
		--R
		134153,		-- Head of Onyxia
		136124,		-- Hakkari Blood
		134085,		-- Heart of Hakkar
		132155,		-- Gouge
		134396,		-- Red Qiraji Resonating Crystal
		--O
		136207,		-- Shadow Word Pain
		135926,		-- Inner Fire
		134010,		-- Carrot on a Stick
		135812,		-- Fireball
		134015,		-- Pumpkin Bag
		--Y
		133784,		-- Gold
		134123,		-- Golden Pearl
		134395,		-- Yellow Qiraji Resonating Crystal
		132226,		-- Summon Charger
		136026,		-- Earth Shock
		--G
		136145,		-- Death Coil
		134397,		-- Green Qiraji Resonating Crystal
		136074,		-- Aspect of the Wild
		135941,		-- Prayer of Fortitude
		135230,		-- Healthstone
		--B
		135840,		-- Improved Frost Nova
		136184,		-- Psychic Scream
		134398,		-- Blue Qiraji Resonating Crystal
		135846,		-- Frostbolt
		132866,		-- Greater Magic Essence
		--I
		135741,		-- Portal Darnassus
		134805,		-- Greater Arcane Elixir
		136123,		-- Devouring Plague
		134399,		-- Black Qiraji Resonating Crystal
		136113,		-- Spider's Silk
		--V
		134336,		-- Soulstone
		134129,		-- Star Ruby
		136033,		-- Faerie Fire
		132126,		-- Enrage
		133874,		-- Amplified Circuitry
		-- W
		134414,		-- Hearthstone
		132382,		-- Rough Arrow
		136071,		-- Polymorph
		132788,		-- Diamond Flask
		132264,		-- Deathcharger's Reins
	},
	classic = {

	},
	retail = {
		-- R
		4667427,	-- Shield Charge
		463568,		-- Volatile Life
		841383,		-- Fixated State Red
		309183,		-- Cranberry Sauce
		1357795,	-- Bloodeye Nightmare
		-- O
		451164,		-- Flame Orb
		133981,		-- Pumpkin
		132847,		-- Primal Fire
		1417427,	-- Halls of Valor
		1068953,	-- Gorehowl
		-- Y
		252269,		-- Holy Rune
		4622479,	-- Time Spiral
		135725,		-- Find Treasure
		134135,		-- Arcane Crystal
		134888,		-- Quiraj Jewel Blessed
		-- G
		136067,		-- Nullify Poison
		1305151,	-- Chaos Nova
		135795,		-- Fellfire Nova
		136094,		-- Spirit Armor
		1378283,	-- Demonic Empowerment
		-- B
		3636846,	-- Paladin Winter
		334365,		-- Frost Emblem
		237551,		-- Mana Gain
		1519351,	-- Celestial Map
		252174,		-- Electro Charge
		-- I
		1386547,	-- Shadow Mend
		132885,		-- Void Crystal
		136039,		-- Grounding Totem
		136181,		-- Pain Spike
		538516,		-- Swarm
		-- V
		3636845,	-- Paladin Summer
		237564,		-- Fel Mending
		1062855,	-- PVP Draenors
		5976940,	-- Nullstone
		252272,		-- Shadow Rune
		-- W
		348543,		-- Ember Cloth
		651087,		-- Blue Flame Ring
		1033183,	-- Taladite Crystal
		2011154,	-- Waycrest Mannor
		463493,		-- White Hydra Figurine
	}
}

function CDTL3:GetAllSpellData(class, race)
	local d = {}
	
	for _, spell in pairs(private.GetRacialData()) do
		table.insert(d, spell)
		--CDTL3:Print("    RACIAL ADDED: "..spell["id"].." - "..spell["name"].." - "..spell["rank"])
	end
	
	for _, spell in pairs(private.GetOtherData()) do
		table.insert(d, spell)
		--CDTL3:Print("    RACIAL ADDED: "..spell["id"].." - "..spell["name"].." - "..spell["rank"])
	end
	
	for _, spell in pairs(private.GetClassData(class)) do
		table.insert(d, spell)
		--CDTL3:Print("    SPELL ADDED: "..spell["id"].." - "..spell["name"].." - "..spell["rank"])
	end
	
	if class == "DEATHKNIGHT" or class == "HUNTER" or class == "WARLOCK" then
		for _, spell in pairs(private.GetPetData(class)) do
			table.insert(d, spell)
			--CDTL3:Print("    PETSPELL ADDED: "..spell["id"].." - "..spell["name"].." - "..spell["rank"])
		end
	end
	
	if CDTL3.isForever then
		d = private.ForeverSpellData(d, class)
	end
	
	return d
end

function CDTL3:GetSpellData(id, name)
	if name then
		for _, spell in pairs(CDTL3.spellData) do
			if spell["name"] == name then
				return spell
			end
		end
	else
		for _, spell in pairs(CDTL3.spellData) do
			if spell["id"] == id then
				return spell
			end
		end
	end
end

-- STRUCTURES
	--[[
	cooldowns = {
		id,
		name,
		rank,
		icon,
		oaf,
		enabled,
		ignored,
		type,
		lane,
		barFrame,
		highlight,
	}
	]]--

-- UNCATAGORISED
private.GetOtherData = function()
	--local _, _, _, tocversion = GetBuildInfo()
	local d = {}
	
	-- CLASSIC
	if CDTL3.tocversion < 20000 then
		table.insert(d, { id = 818, name = "Basic Campfire", rank = "", bCD = 300000 } )
		
	-- TBC
	elseif CDTL3.tocversion < 30000 then
		table.insert(d, { id = 818, name = "Basic Campfire", rank = "", bCD = 300000 } )
	
	-- WOTLK
	elseif CDTL3.tocversion < 40000 then
		table.insert(d, { id = 818, name = "Basic Campfire", rank = "", bCD = 300000 } )
		table.insert(d, { id = 55428, name = "Lifeblood", rank = "1", bCD = 180000 } )
		table.insert(d, { id = 55480, name = "Lifeblood", rank = "2", bCD = 180000 } )
		table.insert(d, { id = 55500, name = "Lifeblood", rank = "3", bCD = 180000 } )
		table.insert(d, { id = 55501, name = "Lifeblood", rank = "4", bCD = 180000 } )
		table.insert(d, { id = 55502, name = "Lifeblood", rank = "5", bCD = 180000 } )
		table.insert(d, { id = 55503, name = "Lifeblood", rank = "6", bCD = 180000 } )
	end
		
	return d
end

-- RACIALS
private.GetRacialData = function()
	--local _, _, _, tocversion = GetBuildInfo()
	local d = {}
	
	-- CLASSIC
	if CDTL3.tocversion < 20000 then
		table.insert(d, { id = 20554, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 26296, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 26297, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20572, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20577, name = "Cannibalize", race = "Undead", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20589, name = "Escape Artist", race = "Gnome", rank = "", bCD = 60000 } )
		table.insert(d, { id = 20600, name = "Perception", race = "Human", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20580, name = "Shadowmeld", race = "Nightelf", rank = "", bCD = 10000, oaf = true } )
		table.insert(d, { id = 20594, name = "Stoneform", race = "Dwarf", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20549, name = "War Stomp", race = "Tauren", rank = "", bCD = 120000 } )
		table.insert(d, { id = 7744, name = "Will of the Forsaken", race = "Undead", rank = "", bCD = 120000 } )
		
	-- TBC
	elseif CDTL3.tocversion < 30000 then
		table.insert(d, { id = 25046, name = "Arcane Torrent", race = "Bloodelf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 28730, name = "Arcane Torrent", race = "Bloodelf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20554, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 26296, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 26297, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20572, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 33697, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 33702, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20577, name = "Cannibalize", race = "Undead", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20589, name = "Escape Artist", race = "Gnome", rank = "", bCD = 105000 } )
		table.insert(d, { id = 28880, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 28734, name = "Mana Tap", race = "Bloodelf", rank = "", bCD = 30000 } )
		table.insert(d, { id = 20600, name = "Perception", race = "Human", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20580, name = "Shadowmeld", race = "Nightelf", rank = "", bCD = 10000, oaf = true } )
		table.insert(d, { id = 20594, name = "Stoneform", race = "Dwarf", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20549, name = "War Stomp", race = "Tauren", rank = "", bCD = 120000 } )
		table.insert(d, { id = 7744, name = "Will of the Forsaken", race = "Undead", rank = "", bCD = 120000 } )
	
	-- WOTLK
	elseif CDTL3.tocversion < 40000 then
		table.insert(d, { id = 25046, name = "Arcane Torrent", race = "Bloodelf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 28730, name = "Arcane Torrent", race = "Bloodelf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 50613, name = "Arcane Torrent", race = "Bloodelf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 26297, name = "Berserking", race = "Troll", rank = "", bCD = 180000 } )
		table.insert(d, { id = 20572, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 33697, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 33702, name = "Blood Fury", race = "Orc", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20577, name = "Cannibalize", race = "Undead", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20589, name = "Escape Artist", race = "Gnome", rank = "", bCD = 105000 } )
		table.insert(d, { id = 2481, name = "Find Treasure", race = "Dwarf", rank = "", bCD = 1500 } )
		table.insert(d, { id = 28880, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 59542, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 59543, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 59544, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 59545, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 59547, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 59548, name = "Gift of the Naaru", race = "Draenei", rank = "", bCD = 180000 } )
		table.insert(d, { id = 58984, name = "Shadowmeld", race = "Nightelf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20594, name = "Stoneform", race = "Dwarf", rank = "", bCD = 120000 } )
		table.insert(d, { id = 20549, name = "War Stomp", race = "Tauren", rank = "", bCD = 120000 } )
		table.insert(d, { id = 7744, name = "Will of the Forsaken", race = "Undead", rank = "", bCD = 120000 } )
		table.insert(d, { id = 59752, name = "Will to Survive", race = "Human", rank = "", bCD = 120000 } )
	end
		
	return d
end

-- CLASS
-- MoP and retail list only the spells whose cooldown starts when their effect ends (oaf);
-- every other spell takes its cooldown from the game when it is first cast.
private.GetClassData = function(class)
	--local _, _, _, tocversion = GetBuildInfo()
	local d = {}
	
	-- Death Knight
	if class == "DEATHKNIGHT" then		
		-- WOTLK: these are Wrath IDs; on MoP and retail many are gone or now other spells
		if CDTL3.tocversion < 40000 then
			-- MAIN SPELLS
			table.insert(d, { id = 48707, name = "Anti-Magic Shell", rank = "", bCD = 45000 } )
			table.insert(d, { id = 42650, name = "Army of the Dead", rank = "", bCD = 600000 } )
			table.insert(d, { id = 48266, name = "Blood Presence", rank = "", bCD = 1000 } )
			table.insert(d, { id = 45529, name = "Blood Tap", rank = "", bCD = 60000 } )
			table.insert(d, { id = 56222, name = "Dark Command", rank = "", bCD = 8000 } )
			table.insert(d, { id = 43265, name = "Death and Decay", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 49936, name = "Death and Decay", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 49937, name = "Death and Decay", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 49938, name = "Death and Decay", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 49576, name = "Death Grip", rank = "", bCD = 35000 } )
			table.insert(d, { id = 48743, name = "Death Pact", rank = "", bCD = 120000 } )
			table.insert(d, { id = 47568, name = "Empower Rune Weapon", rank = "", bCD = 300000 } )
			table.insert(d, { id = 48263, name = "Frost Presence", rank = "", bCD = 1000 } )
			table.insert(d, { id = 57330, name = "Horn of Winter", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 57623, name = "Horn of Winter", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 48792, name = "Icebound Fortitude", rank = "", bCD = 120000 } )
			table.insert(d, { id = 47528, name = "Mind Freeze", rank = "", bCD = 10000 } )
			table.insert(d, { id = 61999, name = "Raise Ally", rank = "", bCD = 600000 } )
			table.insert(d, { id = 46584, name = "Raise Dead", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 47476, name = "Strangulate", rank = "", bCD = 120000 } )
			table.insert(d, { id = 48265, name = "Unholy Presence", rank = "", bCD = 1000 } )
			
			-- TALENT SPELLS
			table.insert(d, { id = 51052, name = "Anti-Magic Zone", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 49222, name = "Bone Shield", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49158, name = "Corpse Explosion", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 51325, name = "Corpse Explosion", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 51326, name = "Corpse Explosion", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 51327, name = "Corpse Explosion", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 51328, name = "Corpse Explosion", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 49028, name = "Dancing Rune Weapon", rank = "", bCD = 90000 } )
			table.insert(d, { id = 49796, name = "Deathchill", rank = "", bCD = 120000 } )
			table.insert(d, { id = 63560, name = "Ghoul Frenzy", rank = "", bCD = 10000 } )
			table.insert(d, { id = 49184, name = "Howling Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 51409, name = "Howling Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 51410, name = "Howling Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 51411, name = "Howling Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 49203, name = "Hungering Cold", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 49039, name = "Lichborne", rank = "", bCD = 120000 } )
			table.insert(d, { id = 49005, name = "Mark of Blood", rank = "", bCD = 180000 } )
			table.insert(d, { id = 48982, name = "Rune Tap", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49206, name = "Summon Gargoyle", rank = "", bCD = 180000 } )
			table.insert(d, { id = 51271, name = "Unbreakable Armor", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49016, name = "Unholy Frenzy", rank = "", bCD = 180000 } )
			table.insert(d, { id = 55233, name = "Vampiric Blood", rank = "", bCD = 60000 } )
		end
	end
	
	-- Demon Hunter
	if class == "DEMONHUNTER" then
		-- RETAIL
		if CDTL3.tocversion >= 60000 then
			table.insert(d, { id = 188501, name = "Spectral Sight", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 1251417, name = "Spectral Sight", rank = "", bCD = 30000, oaf = true } )
		end
	end
	
	-- Druid
	if class == "DRUID" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 22812, name = "Barkskin", rank = "", bCD = 60000 } )
			table.insert(d, { id = 5211, name = "Bash", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 6798, name = "Bash", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 8983, name = "Bash", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 5209, name = "Challenging Roar", rank = "", bCD = 600000 } )
			table.insert(d, { id = 8998, name = "Cower", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 9000, name = "Cower", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 9892, name = "Cower", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 1850, name = "Dash", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 9821, name = "Dash", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 5229, name = "Enrage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 22842, name = "Frenzied Regeneration", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 22895, name = "Frenzied Regeneration", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 22896, name = "Frenzied Regeneration", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 6795, name = "Growl", rank = "", bCD = 10000 } )
			table.insert(d, { id = 16914, name = "Hurricane", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 17401, name = "Hurricane", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 17402, name = "Hurricane", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 29166, name = "Innervate", rank = "", bCD = 360000 } )
			table.insert(d, { id = 5215, name = "Prowl", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 6783, name = "Prowl", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 9913, name = "Prowl", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 20484, name = "Rebirth", rank = "1", bCD = 1800000 } )
			table.insert(d, { id = 20739, name = "Rebirth", rank = "2", bCD = 1800000 } )
			table.insert(d, { id = 20742, name = "Rebirth", rank = "3", bCD = 1800000 } )
			table.insert(d, { id = 20747, name = "Rebirth", rank = "4", bCD = 1800000 } )
			table.insert(d, { id = 20748, name = "Rebirth", rank = "5", bCD = 1800000 } )
			table.insert(d, { id = 5217, name = "Tiger's Fury", rank = "1", bCD = 1000 } )
			table.insert(d, { id = 6793, name = "Tiger's Fury", rank = "2", bCD = 1000 } )
			table.insert(d, { id = 9845, name = "Tiger's Fury", rank = "3", bCD = 1000 } )
			table.insert(d, { id = 9846, name = "Tiger's Fury", rank = "4", bCD = 1000 } )
			table.insert(d, { id = 740, name = "Tranquility", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 8918, name = "Tranquility", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 9862, name = "Tranquility", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 9863, name = "Tranquility", rank = "4", bCD = 300000 } )
			
			-- TALENTS
			table.insert(d, { id = 16857, name = "Faerie Fire (Feral)", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 17390, name = "Faerie Fire (Feral)", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 17391, name = "Faerie Fire (Feral)", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 17392, name = "Faerie Fire (Feral)", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 16979, name = "Feral Charge", rank = "", bCD = 15000 } )
			table.insert(d, { id = 16689, name = "Nature's Grasp", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 16810, name = "Nature's Grasp", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 16811, name = "Nature's Grasp", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 16812, name = "Nature's Grasp", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 16813, name = "Nature's Grasp", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 17329, name = "Nature's Grasp", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 17116, name = "Nature's Swiftness", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 18562, name = "Swiftmend", rank = "", bCD = 15000 } )

			-- RUNES
			table.insert(d, { id = 407995, name = "Mangle", rank = "", bCD = 6000 } )
			table.insert(d, { id = 410176, name = "Skull Bash", rank = "", bCD = 10000 } )
			table.insert(d, { id = 417157, name = "Starsurge", rank = "", bCD = 6000 } )
			table.insert(d, { id = 417045, name = "Tiger's Fury", rank = "", bCD = 30000 } )
			table.insert(d, { id = 408120, name = "Wild Growth", rank = "", bCD = 6000 } )

			table.insert(d, { id = 417141, name = "Berserk", rank = "", bCD = 180000 } )
			table.insert(d, { id = 408024, name = "Survival Instincts", rank = "", bCD = 180000 } )
			
		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 22812, name = "Barkskin", rank = "", bCD = 60000 } )
			table.insert(d, { id = 5211, name = "Bash", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 6798, name = "Bash", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 8983, name = "Bash", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 5209, name = "Challenging Roar", rank = "", bCD = 600000 } )
			table.insert(d, { id = 8998, name = "Cower", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 9000, name = "Cower", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 9892, name = "Cower", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 31709, name = "Cower", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 27004, name = "Cower", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 1850, name = "Dash", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 9821, name = "Dash", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 33357, name = "Dash", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 5229, name = "Enrage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 22842, name = "Frenzied Regeneration", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 22895, name = "Frenzied Regeneration", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 22896, name = "Frenzied Regeneration", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 26999, name = "Frenzied Regeneration", rank = "4", bCD = 180000 } )
			table.insert(d, { id = 6795, name = "Growl", rank = "", bCD = 10000 } )
			table.insert(d, { id = 16914, name = "Hurricane", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 17401, name = "Hurricane", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 17402, name = "Hurricane", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 27012, name = "Hurricane", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 29166, name = "Innervate", rank = "", bCD = 360000 } )
			table.insert(d, { id = 22570, name = "Maim", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 33878, name = "Mangle (Bear)", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 33986, name = "Mangle (Bear)", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 33987, name = "Mangle (Bear)", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 5215, name = "Prowl", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 6783, name = "Prowl", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 9913, name = "Prowl", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 20484, name = "Rebirth", rank = "1", bCD = 1200000 } )
			table.insert(d, { id = 20739, name = "Rebirth", rank = "2", bCD = 1200000 } )
			table.insert(d, { id = 20742, name = "Rebirth", rank = "3", bCD = 1200000 } )
			table.insert(d, { id = 20747, name = "Rebirth", rank = "4", bCD = 1200000 } )
			table.insert(d, { id = 20748, name = "Rebirth", rank = "5", bCD = 1200000 } )
			table.insert(d, { id = 26994, name = "Rebirth", rank = "6", bCD = 1200000 } )
			table.insert(d, { id = 5217, name = "Tiger's Fury", rank = "1", bCD = 1000 } )
			table.insert(d, { id = 6793, name = "Tiger's Fury", rank = "2", bCD = 1000 } )
			table.insert(d, { id = 9845, name = "Tiger's Fury", rank = "3", bCD = 1000 } )
			table.insert(d, { id = 9846, name = "Tiger's Fury", rank = "4", bCD = 1000 } )
			table.insert(d, { id = 740, name = "Tranquility", rank = "1", bCD = 600000 } )
			table.insert(d, { id = 8918, name = "Tranquility", rank = "2", bCD = 600000 } )
			table.insert(d, { id = 9862, name = "Tranquility", rank = "3", bCD = 600000 } )
			table.insert(d, { id = 9863, name = "Tranquility", rank = "4", bCD = 600000 } )
			table.insert(d, { id = 26983, name = "Tranquility", rank = "5", bCD = 600000 } )
			
			-- TALENTS
			table.insert(d, { id = 16857, name = "Faerie Fire (Feral)", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 17390, name = "Faerie Fire (Feral)", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 17391, name = "Faerie Fire (Feral)", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 17392, name = "Faerie Fire (Feral)", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 27011, name = "Faerie Fire (Feral)", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 16979, name = "Feral Charge", rank = "", bCD = 15000 } )
			table.insert(d, { id = 33831, name = "Force of Nature", rank = "", bCD = 180000 } )
			table.insert(d, { id = 16689, name = "Nature's Grasp", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 16810, name = "Nature's Grasp", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 16811, name = "Nature's Grasp", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 16812, name = "Nature's Grasp", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 16813, name = "Nature's Grasp", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 17329, name = "Nature's Grasp", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 27009, name = "Nature's Grasp", rank = "7", bCD = 60000 } )
			table.insert(d, { id = 17116, name = "Nature's Swiftness", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 18562, name = "Swiftmend", rank = "", bCD = 15000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 22812, name = "Barkskin", rank = "", bCD = 60000 } )
			table.insert(d, { id = 5211, name = "Bash", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 6798, name = "Bash", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 8983, name = "Bash", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 5209, name = "Challenging Roar", rank = "", bCD = 180000 } )
			table.insert(d, { id = 8998, name = "Cower", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 9000, name = "Cower", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 9892, name = "Cower", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 31709, name = "Cower", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 27004, name = "Cower", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 48575, name = "Cower", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 1850, name = "Dash", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 9821, name = "Dash", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 33357, name = "Dash", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 5229, name = "Enrage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 16857, name = "Faerie Fire (Feral)", rank = "", bCD = 6000 } )
			table.insert(d, { id = 16979, name = "Feral Charge - Bear", rank = "", bCD = 15000 } )
			table.insert(d, { id = 49376, name = "Feral Charge - Cat", rank = "", bCD = 30000 } )
			table.insert(d, { id = 22842, name = "Frenzied Regeneration", rank = "", bCD = 180000 } )
			table.insert(d, { id = 6795, name = "Growl", rank = "", bCD = 8000 } )
			table.insert(d, { id = 29166, name = "Innervate", rank = "", bCD = 180000 } )
			table.insert(d, { id = 22570, name = "Maim", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 49802, name = "Maim", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 33878, name = "Mangle (Bear)", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 33986, name = "Mangle (Bear)", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 33987, name = "Mangle (Bear)", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 48563, name = "Mangle (Bear)", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 48564, name = "Mangle (Bear)", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 16689, name = "Nature's Grasp", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 16810, name = "Nature's Grasp", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 16811, name = "Nature's Grasp", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 16812, name = "Nature's Grasp", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 16813, name = "Nature's Grasp", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 17329, name = "Nature's Grasp", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 27009, name = "Nature's Grasp", rank = "7", bCD = 60000 } )
			table.insert(d, { id = 53312, name = "Nature's Grasp", rank = "8", bCD = 60000 } )
			table.insert(d, { id = 5215, name = "Prowl", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 20484, name = "Rebirth", rank = "1", bCD = 600000 } )
			table.insert(d, { id = 20739, name = "Rebirth", rank = "2", bCD = 600000 } )
			table.insert(d, { id = 20742, name = "Rebirth", rank = "3", bCD = 600000 } )
			table.insert(d, { id = 20747, name = "Rebirth", rank = "4", bCD = 600000 } )
			table.insert(d, { id = 20748, name = "Rebirth", rank = "5", bCD = 600000 } )
			table.insert(d, { id = 26994, name = "Rebirth", rank = "6", bCD = 600000 } )
			table.insert(d, { id = 48477, name = "Rebirth", rank = "7", bCD = 600000 } )
			table.insert(d, { id = 5217, name = "Tiger's Fury", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 6793, name = "Tiger's Fury", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 9845, name = "Tiger's Fury", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 9846, name = "Tiger's Fury", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 50212, name = "Tiger's Fury", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 50213, name = "Tiger's Fury", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 5225, name = "Track Humanoids", rank = "", bCD = 1500 } )
			table.insert(d, { id = 740, name = "Tranquility", rank = "1", bCD = 480000 } )
			table.insert(d, { id = 8918, name = "Tranquility", rank = "2", bCD = 480000 } )
			table.insert(d, { id = 9862, name = "Tranquility", rank = "3", bCD = 480000 } )
			table.insert(d, { id = 9863, name = "Tranquility", rank = "4", bCD = 480000 } )
			table.insert(d, { id = 26983, name = "Tranquility", rank = "5", bCD = 480000 } )
			table.insert(d, { id = 48446, name = "Tranquility", rank = "6", bCD = 480000 } )
			table.insert(d, { id = 48447, name = "Tranquility", rank = "7", bCD = 480000 } )
			
			-- TALENTS
			table.insert(d, { id = 50334, name = "Berserk", rank = "", bCD = 180000 } )
			table.insert(d, { id = 33831, name = "Force of Nature", rank = "", bCD = 180000 } )
			table.insert(d, { id = 17116, name = "Nature's Swiftness", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 48505, name = "Starfall", rank = "1", bCD = 90000 } )
			table.insert(d, { id = 53199, name = "Starfall", rank = "2", bCD = 90000 } )
			table.insert(d, { id = 53200, name = "Starfall", rank = "3", bCD = 90000 } )
			table.insert(d, { id = 53201, name = "Starfall", rank = "4", bCD = 90000 } )
			table.insert(d, { id = 61336, name = "Survival Instincts", rank = "", bCD = 180000 } )
			table.insert(d, { id = 18562, name = "Swiftmend", rank = "", bCD = 15000 } )
			table.insert(d, { id = 50516, name = "Typhoon", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 53223, name = "Typhoon", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 53225, name = "Typhoon", rank = "3", bCD = 20000 } )
			table.insert(d, { id = 53226, name = "Typhoon", rank = "4", bCD = 20000 } )
			table.insert(d, { id = 61384, name = "Typhoon", rank = "5", bCD = 20000 } )
			table.insert(d, { id = 48438, name = "Wild Growth", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 53248, name = "Wild Growth", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 53249, name = "Wild Growth", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 53251, name = "Wild Growth", rank = "4", bCD = 6000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 132158, name = "Nature's Swiftness", rank = "", bCD = 60000, oaf = true } )
			table.insert(d, { id = 5215, name = "Prowl", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 102547, name = "Prowl", rank = "", bCD = 10000, oaf = true } )
			
		-- RETAIL
		else
			table.insert(d, { id = 132158, name = "Nature's Swiftness", rank = "", bCD = 60000, oaf = true } )
			table.insert(d, { id = 5215, name = "Prowl", rank = "", bCD = 6000, oaf = true } )
			table.insert(d, { id = 102547, name = "Prowl", rank = "", bCD = 6000, oaf = true } )
		end
	end
	
	-- Evoker
	if class == "EVOKER" then
		-- RETAIL
		if CDTL3.tocversion >= 60000 then
			table.insert(d, { id = 370537, name = "Stasis", rank = "", bCD = 90000, oaf = true } )
			table.insert(d, { id = 370553, name = "Tip the Scales", rank = "", bCD = 120000, oaf = true } )
		end
	end
	
	-- Hunter
	if class == "HUNTER" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 3044, name = "Arcane Shot", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 14281, name = "Arcane Shot", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 14282, name = "Arcane Shot", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 14283, name = "Arcane Shot", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 14284, name = "Arcane Shot", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 14285, name = "Arcane Shot", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 14286, name = "Arcane Shot", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 14287, name = "Arcane Shot", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 5116, name = "Concussive Shot", rank = "", bCD = 12000 } )
			table.insert(d, { id = 781, name = "Disengage", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14272, name = "Disengage", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14273, name = "Disengage", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 20736, name = "Distracting Shot", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 14274, name = "Distracting Shot", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 15629, name = "Distracting Shot", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 15630, name = "Distracting Shot", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 15631, name = "Distracting Shot", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 15632, name = "Distracting Shot", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 13813, name = "Explosive Trap", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 14316, name = "Explosive Trap", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 14317, name = "Explosive Trap", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 5384, name = "Feign Death", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 1543, name = "Flare", rank = "", bCD = 15000 } )
			table.insert(d, { id = 1499, name = "Freezing Trap", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 14310, name = "Freezing Trap", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 14311, name = "Freezing Trap", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 13809, name = "Frost Trap", rank = "", bCD = 15000 } )
			table.insert(d, { id = 13795, name = "Immolation Trap", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 14302, name = "Immolation Trap", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 14303, name = "Immolation Trap", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 14304, name = "Immolation Trap", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 14305, name = "Immolation Trap", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 1495, name = "Mongoose Bite", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14269, name = "Mongoose Bite", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14270, name = "Mongoose Bite", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 14271, name = "Mongoose Bite", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 2643, name = "Multi-Shot", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 14288, name = "Multi-Shot", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 14289, name = "Multi-Shot", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 14290, name = "Multi-Shot", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25294, name = "Multi-Shot", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 3045, name = "Rapid Fire", rank = "", bCD = 300000 } )
			table.insert(d, { id = 2973, name = "Raptor Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 14260, name = "Raptor Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 14261, name = "Raptor Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 14262, name = "Raptor Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 14263, name = "Raptor Strike", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 14264, name = "Raptor Strike", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 14265, name = "Raptor Strike", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 14266, name = "Raptor Strike", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 23989, name = "Readiness", rank = "", bCD = 300000 } )
			table.insert(d, { id = 1513, name = "Scare Beast", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14326, name = "Scare Beast", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14327, name = "Scare Beast", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 19801, name = "Tranquilizing Shot", rank = "", bCD = 20000 } )
			table.insert(d, { id = 1510, name = "Volley", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 14294, name = "Volley", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 14295, name = "Volley", rank = "3", bCD = 60000 } )
		
			-- TALENTS
			table.insert(d, { id = 19434, name = "Aimed Shot", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 20900, name = "Aimed Shot", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 20901, name = "Aimed Shot", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 20902, name = "Aimed Shot", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 20903, name = "Aimed Shot", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 20904, name = "Aimed Shot", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 19574, name = "Bestial Wrath", rank = "", bCD = 120000 } )
			table.insert(d, { id = 19306, name = "Counterattack", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 20909, name = "Counterattack", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 20910, name = "Counterattack", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 19263, name = "Deterrence", rank = "", bCD = 300000 } )
			table.insert(d, { id = 19577, name = "Intimidation", rank = "", bCD = 60000 } )
			table.insert(d, { id = 19503, name = "Scatter Shot", rank = "", bCD = 30000 } )
			table.insert(d, { id = 19386, name = "Wyvern Sting", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 24132, name = "Wyvern Sting", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 24133, name = "Wyvern Sting", rank = "3", bCD = 120000 } )

			-- RUNES
			table.insert(d, { id = 409552, name = "Explosive Shot", rank = "", bCD = 6000 } )
			table.insert(d, { id = 409532, name = "Explosive Trap", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 409534, name = "Explosive Trap", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 409535, name = "Explosive Trap", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 415320, name = "Flanking Strike", rank = "", bCD = 30000 } )
			table.insert(d, { id = 409510, name = "Freezing Trap", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 409512, name = "Freezing Trap", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 409519, name = "Freezing Trap", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 409520, name = "Frost Trap", rank = "", bCD = 15000 } )
			table.insert(d, { id = 409521, name = "Immolation Trap", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 409524, name = "Immolation Trap", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 409526, name = "Immolation Trap", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 409528, name = "Immolation Trap", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 409530, name = "Immolation Trap", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 409379, name = "Kill Command", rank = "", bCD = 60000 } )
			table.insert(d, { id = 415335, name = "Raptor Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 415336, name = "Raptor Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 415337, name = "Raptor Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 415338, name = "Raptor Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 415340, name = "Raptor Strike", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 415341, name = "Raptor Strike", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 415342, name = "Raptor Strike", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 415343, name = "Raptor Strike", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 409748, name = "Raptor Strike", rank = "3", bCD = 0 } )
			table.insert(d, { id = 409750, name = "Raptor Strike", rank = "4", bCD = 0 } )
			table.insert(d, { id = 409751, name = "Raptor Strike", rank = "5", bCD = 0 } )
			table.insert(d, { id = 409752, name = "Raptor Strike", rank = "6", bCD = 0 } )
			table.insert(d, { id = 409754, name = "Raptor Strike", rank = "7", bCD = 0 } )
			table.insert(d, { id = 409755, name = "Raptor Strike", rank = "8", bCD = 0 } )
			
		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 3044, name = "Arcane Shot", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 14281, name = "Arcane Shot", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 14282, name = "Arcane Shot", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 14283, name = "Arcane Shot", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 14284, name = "Arcane Shot", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 14285, name = "Arcane Shot", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 14286, name = "Arcane Shot", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 14287, name = "Arcane Shot", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 27019, name = "Arcane Shot", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 5116, name = "Concussive Shot", rank = "", bCD = 12000 } )
			table.insert(d, { id = 781, name = "Disengage", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14272, name = "Disengage", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14273, name = "Disengage", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 27015, name = "Disengage", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 20736, name = "Distracting Shot", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 14274, name = "Distracting Shot", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 15629, name = "Distracting Shot", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 15630, name = "Distracting Shot", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 15631, name = "Distracting Shot", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 15632, name = "Distracting Shot", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 27020, name = "Distracting Shot", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 13813, name = "Explosive Trap", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14316, name = "Explosive Trap", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14317, name = "Explosive Trap", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 27025, name = "Explosive Trap", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 5384, name = "Feign Death", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 1543, name = "Flare", rank = "", bCD = 20000 } )
			table.insert(d, { id = 1499, name = "Freezing Trap", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14310, name = "Freezing Trap", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14311, name = "Freezing Trap", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13809, name = "Frost Trap", rank = "", bCD = 30000 } )
			table.insert(d, { id = 13795, name = "Immolation Trap", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14302, name = "Immolation Trap", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14303, name = "Immolation Trap", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 14304, name = "Immolation Trap", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 14305, name = "Immolation Trap", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 27023, name = "Immolation Trap", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 34026, name = "Kill Command", rank = "", bCD = 5000 } )
			table.insert(d, { id = 34477, name = "Misdirection", rank = "", bCD = 120000 } )
			table.insert(d, { id = 1495, name = "Mongoose Bite", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14269, name = "Mongoose Bite", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14270, name = "Mongoose Bite", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 14271, name = "Mongoose Bite", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 36916, name = "Mongoose Bite", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 2643, name = "Multi-Shot", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 14288, name = "Multi-Shot", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 14289, name = "Multi-Shot", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 14290, name = "Multi-Shot", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25294, name = "Multi-Shot", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 27021, name = "Multi-Shot", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 3045, name = "Rapid Fire", rank = "", bCD = 300000 } )
			table.insert(d, { id = 2973, name = "Raptor Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 14260, name = "Raptor Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 14261, name = "Raptor Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 14262, name = "Raptor Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 14263, name = "Raptor Strike", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 14264, name = "Raptor Strike", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 14265, name = "Raptor Strike", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 14266, name = "Raptor Strike", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 27014, name = "Raptor Strike", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 1513, name = "Scare Beast", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14326, name = "Scare Beast", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14327, name = "Scare Beast", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 34600, name = "Snake Trap", rank = "", bCD = 30000 } )
			table.insert(d, { id = 19801, name = "Tranquilizing Shot", rank = "", bCD = 20000 } )
			table.insert(d, { id = 3034, name = "Viper Sting", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 14279, name = "Viper Sting", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 14280, name = "Viper Sting", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 27018, name = "Viper Sting", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 1510, name = "Volley", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 14294, name = "Volley", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 14295, name = "Volley", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 27022, name = "Volley", rank = "4", bCD = 60000 } )
			
			-- TALENTS
			table.insert(d, { id = 19434, name = "Aimed Shot", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 20900, name = "Aimed Shot", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 20901, name = "Aimed Shot", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 20902, name = "Aimed Shot", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 20903, name = "Aimed Shot", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 20904, name = "Aimed Shot", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 27065, name = "Aimed Shot", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 19574, name = "Bestial Wrath", rank = "", bCD = 120000 } )
			table.insert(d, { id = 19306, name = "Counterattack", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 20909, name = "Counterattack", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 20910, name = "Counterattack", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 27067, name = "Counterattack", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 19263, name = "Deterrence", rank = "", bCD = 300000 } )
			table.insert(d, { id = 19577, name = "Intimidation", rank = "", bCD = 60000 } )
			table.insert(d, { id = 23989, name = "Readiness", rank = "", bCD = 300000 } )
			table.insert(d, { id = 19503, name = "Scatter Shot", rank = "", bCD = 30000 } )
			table.insert(d, { id = 34490, name = "Silencing Shot", rank = "", bCD = 20000 } )
			table.insert(d, { id = 19386, name = "Wyvern Sting", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 24132, name = "Wyvern Sting", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 24133, name = "Wyvern Sting", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 27068, name = "Wyvern Sting", rank = "4", bCD = 120000 } )
				
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 3044, name = "Arcane Shot", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 14281, name = "Arcane Shot", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 14282, name = "Arcane Shot", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 14283, name = "Arcane Shot", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 14284, name = "Arcane Shot", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 14285, name = "Arcane Shot", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 14286, name = "Arcane Shot", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 14287, name = "Arcane Shot", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 27019, name = "Arcane Shot", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 49044, name = "Arcane Shot", rank = "10", bCD = 6000 } )
			table.insert(d, { id = 49045, name = "Arcane Shot", rank = "11", bCD = 6000 } )
			table.insert(d, { id = 13161, name = "Aspect of the Beast", rank = "", bCD = 1000 } )
			table.insert(d, { id = 5118, name = "Aspect of the Cheetah", rank = "", bCD = 1000 } )
			table.insert(d, { id = 61846, name = "Aspect of the Dragonhawk", rank = "1", bCD = 1000 } )
			table.insert(d, { id = 61847, name = "Aspect of the Dragonhawk", rank = "2", bCD = 1000 } )
			table.insert(d, { id = 13165, name = "Aspect of the Hawk", rank = "1", bCD = 1000 } )
			table.insert(d, { id = 14318, name = "Aspect of the Hawk", rank = "2", bCD = 1000 } )
			table.insert(d, { id = 14319, name = "Aspect of the Hawk", rank = "3", bCD = 1000 } )
			table.insert(d, { id = 14320, name = "Aspect of the Hawk", rank = "4", bCD = 1000 } )
			table.insert(d, { id = 14321, name = "Aspect of the Hawk", rank = "5", bCD = 1000 } )
			table.insert(d, { id = 14322, name = "Aspect of the Hawk", rank = "6", bCD = 1000 } )
			table.insert(d, { id = 25296, name = "Aspect of the Hawk", rank = "7", bCD = 1000 } )
			table.insert(d, { id = 27044, name = "Aspect of the Hawk", rank = "8", bCD = 1000 } )
			table.insert(d, { id = 13163, name = "Aspect of the Monkey", rank = "", bCD = 1000 } )
			table.insert(d, { id = 13159, name = "Aspect of the Pack", rank = "", bCD = 1000 } )
			table.insert(d, { id = 34074, name = "Aspect of the Viper", rank = "", bCD = 1000 } )
			table.insert(d, { id = 20043, name = "Aspect of the Wild", rank = "1", bCD = 1000 } )
			table.insert(d, { id = 20190, name = "Aspect of the Wild", rank = "2", bCD = 1000 } )
			table.insert(d, { id = 27045, name = "Aspect of the Wild", rank = "3", bCD = 1000 } )
			table.insert(d, { id = 49071, name = "Aspect of the Wild", rank = "4", bCD = 1000 } )
			table.insert(d, { id = 62757, name = "Call Stabled Pet", rank = "", bCD = 300000 } )
			table.insert(d, { id = 5116, name = "Concussive Shot", rank = "", bCD = 12000 } )
			table.insert(d, { id = 19263, name = "Deterrence", rank = "", bCD = 90000 } )
			table.insert(d, { id = 781, name = "Disengage", rank = "", bCD = 25000 } )
			table.insert(d, { id = 20736, name = "Distracting Shot", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 13813, name = "Explosive Trap", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14316, name = "Explosive Trap", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14317, name = "Explosive Trap", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 27025, name = "Explosive Trap", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 49066, name = "Explosive Trap", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 49067, name = "Explosive Trap", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 6991, name = "Feed Pet", rank = "", bCD = 10000 } )
			table.insert(d, { id = 5384, name = "Feign Death", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 1543, name = "Flare", rank = "", bCD = 20000 } )
			table.insert(d, { id = 60192, name = "Freezing Arrow", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 1499, name = "Freezing Trap", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14310, name = "Freezing Trap", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14311, name = "Freezing Trap", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13809, name = "Frost Trap", rank = "", bCD = 30000 } )
			table.insert(d, { id = 13795, name = "Immolation Trap", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14302, name = "Immolation Trap", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14303, name = "Immolation Trap", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 14304, name = "Immolation Trap", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 14305, name = "Immolation Trap", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 27023, name = "Immolation Trap", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 49055, name = "Immolation Trap", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 49056, name = "Immolation Trap", rank = "8", bCD = 30000 } )
			table.insert(d, { id = 34026, name = "Kill Command", rank = "", bCD = 60000 } )
			table.insert(d, { id = 53351, name = "Kill Shot", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 61005, name = "Kill Shot", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 61006, name = "Kill Shot", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 53271, name = "Master's Call", rank = "", bCD = 60000 } )
			table.insert(d, { id = 34477, name = "Misdirection", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 1495, name = "Mongoose Bite", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14269, name = "Mongoose Bite", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14270, name = "Mongoose Bite", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 14271, name = "Mongoose Bite", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 36916, name = "Mongoose Bite", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 53339, name = "Mongoose Bite", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 2643, name = "Multi-Shot", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 14288, name = "Multi-Shot", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 14289, name = "Multi-Shot", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 14290, name = "Multi-Shot", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25294, name = "Multi-Shot", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 27021, name = "Multi-Shot", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 49047, name = "Multi-Shot", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 49048, name = "Multi-Shot", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 3045, name = "Rapid Fire", rank = "", bCD = 300000 } )
			table.insert(d, { id = 2973, name = "Raptor Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 14260, name = "Raptor Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 14261, name = "Raptor Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 14262, name = "Raptor Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 14263, name = "Raptor Strike", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 14264, name = "Raptor Strike", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 14265, name = "Raptor Strike", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 14266, name = "Raptor Strike", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 27014, name = "Raptor Strike", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 48995, name = "Raptor Strike", rank = "10", bCD = 6000 } )
			table.insert(d, { id = 48996, name = "Raptor Strike", rank = "11", bCD = 6000 } )
			table.insert(d, { id = 1513, name = "Scare Beast", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 14326, name = "Scare Beast", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 14327, name = "Scare Beast", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 34600, name = "Snake Trap", rank = "", bCD = 30000 } )
			table.insert(d, { id = 1494, name = "Track Beasts", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19878, name = "Track Demons", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19879, name = "Track Dragonkin", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19880, name = "Track Elementals", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19882, name = "Track Giants", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19885, name = "Track Hidden", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19883, name = "Track Humanoids", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19884, name = "Track Undead", rank = "", bCD = 1500 } )
			table.insert(d, { id = 19801, name = "Tranquilizing Shot", rank = "", bCD = 8000 } )
			table.insert(d, { id = 3034, name = "Viper Sting", rank = "", bCD = 15000 } )
			
			-- TALENTS
			table.insert(d, { id = 49050, name = "Aimed Shot", rank = "9", bCD = 10000 } )
			table.insert(d, { id = 19434, name = "Aimed Shot", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 20901, name = "Aimed Shot", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 20903, name = "Aimed Shot", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 20902, name = "Aimed Shot", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 20904, name = "Aimed Shot", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 49049, name = "Aimed Shot", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 27065, name = "Aimed Shot", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 20900, name = "Aimed Shot", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 19574, name = "Bestial Wrath", rank = "", bCD = 120000 } )
			table.insert(d, { id = 63670, name = "Black Arrow", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 63672, name = "Black Arrow", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 63669, name = "Black Arrow", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 63671, name = "Black Arrow", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 63668, name = "Black Arrow", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 53209, name = "Chimera Shot", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 20910, name = "Counterattack", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 19306, name = "Counterattack", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 27067, name = "Counterattack", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 20909, name = "Counterattack", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 48998, name = "Counterattack", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 48999, name = "Counterattack", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 60053, name = "Explosive Shot", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 53301, name = "Explosive Shot", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 60052, name = "Explosive Shot", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 60051, name = "Explosive Shot", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 19577, name = "Intimidation", rank = "", bCD = 60000 } )
			table.insert(d, { id = 23989, name = "Readiness", rank = "", bCD = 180000 } )
			table.insert(d, { id = 19503, name = "Scatter Shot", rank = "", bCD = 30000 } )
			table.insert(d, { id = 34490, name = "Silencing Shot", rank = "", bCD = 20000 } )
			table.insert(d, { id = 19386, name = "Wyvern Sting", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 24132, name = "Wyvern Sting", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 24133, name = "Wyvern Sting", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 27068, name = "Wyvern Sting", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 49011, name = "Wyvern Sting", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 49012, name = "Wyvern Sting", rank = "6", bCD = 60000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 5384, name = "Feign Death", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 34477, name = "Misdirection", rank = "", bCD = 30000, oaf = true } )
			
		-- RETAIL
		else
			table.insert(d, { id = 199483, name = "Camouflage", rank = "", bCD = 60000, oaf = true } )
			table.insert(d, { id = 5384, name = "Feign Death", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 34477, name = "Misdirection", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 209997, name = "Play Dead", rank = "", bCD = 30000, oaf = true } )
		end
	end
	
	-- Mage
	if class == "MAGE" then	
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 1953, name = "Blink", rank = "", bCD = 15000 } )
			table.insert(d, { id = 120, name = "Cone of Cold", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 8492, name = "Cone of Cold", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 10159, name = "Cone of Cold", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 10160, name = "Cone of Cold", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 10161, name = "Cone of Cold", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 2139, name = "Counterspell", rank = "", bCD = 30000 } )
			table.insert(d, { id = 12051, name = "Evocation", rank = "", bCD = 480000 } )
			table.insert(d, { id = 2136, name = "Fire Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 2137, name = "Fire Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 2138, name = "Fire Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 8412, name = "Fire Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 8413, name = "Fire Blast", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 10197, name = "Fire Blast", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 10199, name = "Fire Blast", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 543, name = "Fire Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8457, name = "Fire Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 8458, name = "Fire Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10223, name = "Fire Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10225, name = "Fire Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 122, name = "Frost Nova", rank = "1", bCD = 25000 } )
			table.insert(d, { id = 865, name = "Frost Nova", rank = "2", bCD = 25000 } )
			table.insert(d, { id = 6131, name = "Frost Nova", rank = "3", bCD = 25000 } )
			table.insert(d, { id = 10230, name = "Frost Nova", rank = "4", bCD = 25000 } )
			table.insert(d, { id = 6143, name = "Frost Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8461, name = "Frost Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 8462, name = "Frost Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10177, name = "Frost Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 28609, name = "Frost Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 11419, name = "Portal: Darnassus", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11416, name = "Portal: Ironforge", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11417, name = "Portal: Orgrimmar", rank = "", bCD = 60000 } )
			table.insert(d, { id = 10059, name = "Portal: Stormwind", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11420, name = "Portal: Thunder Bluff", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11418, name = "Portal: Undercity", rank = "", bCD = 60000 } )
			
			-- TALENTS
			table.insert(d, { id = 12042, name = "Arcane Power", rank = "", bCD = 180000 } )
			table.insert(d, { id = 11113, name = "Blast Wave", rank = "1", bCD = 45000 } )
			table.insert(d, { id = 13018, name = "Blast Wave", rank = "2", bCD = 45000 } )
			table.insert(d, { id = 13019, name = "Blast Wave", rank = "3", bCD = 45000 } )
			table.insert(d, { id = 13020, name = "Blast Wave", rank = "4", bCD = 45000 } )
			table.insert(d, { id = 13021, name = "Blast Wave", rank = "5", bCD = 45000 } )
			table.insert(d, { id = 12472, name = "Cold Snap", rank = "", bCD = 600000 } )
			table.insert(d, { id = 11129, name = "Combustion", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 11426, name = "Ice Barrier", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 13031, name = "Ice Barrier", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 13032, name = "Ice Barrier", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13033, name = "Ice Barrier", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 11958, name = "Ice Block", rank = "", bCD = 300000 } )
			table.insert(d, { id = 12043, name = "Presence of Mind", rank = "", bCD = 180000, oaf = true } )
			
			-- RUNES
			table.insert(d, { id = 425124, name = "Arcane Surge", rank = "", bCD = 120000 } )
			table.insert(d, { id = 425121, name = "Icy Veins", rank = "", bCD = 180000 } )
			table.insert(d, { id = 401556, name = "Living Flame", rank = "", bCD = 30000 } )
			table.insert(d, { id = 412510, name = "Mass Regeneration", rank = "", bCD = 12000 } )
			table.insert(d, { id = 401462, name = "Rewind Time", rank = "", bCD = 30000 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 1953, name = "Blink", rank = "", bCD = 15000 } )
			table.insert(d, { id = 120, name = "Cone of Cold", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 8492, name = "Cone of Cold", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 10159, name = "Cone of Cold", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 10160, name = "Cone of Cold", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 10161, name = "Cone of Cold", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 27087, name = "Cone of Cold", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 2139, name = "Counterspell", rank = "", bCD = 24000 } )
			table.insert(d, { id = 12051, name = "Evocation", rank = "", bCD = 480000 } )
			table.insert(d, { id = 2136, name = "Fire Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 2137, name = "Fire Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 2138, name = "Fire Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 8412, name = "Fire Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 8413, name = "Fire Blast", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 10197, name = "Fire Blast", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 10199, name = "Fire Blast", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 27078, name = "Fire Blast", rank = "8", bCD = 8000 } )
			table.insert(d, { id = 27079, name = "Fire Blast", rank = "9", bCD = 8000 } )
			table.insert(d, { id = 543, name = "Fire Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8457, name = "Fire Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 8458, name = "Fire Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10223, name = "Fire Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10225, name = "Fire Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 27128, name = "Fire Ward", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 122, name = "Frost Nova", rank = "1", bCD = 25000 } )
			table.insert(d, { id = 865, name = "Frost Nova", rank = "2", bCD = 25000 } )
			table.insert(d, { id = 6131, name = "Frost Nova", rank = "3", bCD = 25000 } )
			table.insert(d, { id = 10230, name = "Frost Nova", rank = "4", bCD = 25000 } )
			table.insert(d, { id = 27088, name = "Frost Nova", rank = "5", bCD = 25000 } )
			table.insert(d, { id = 6143, name = "Frost Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8461, name = "Frost Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 8462, name = "Frost Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10177, name = "Frost Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 28609, name = "Frost Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 32796, name = "Frost Ward", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 45438, name = "Ice Block", rank = "", bCD = 300000 } )
			table.insert(d, { id = 66, name = "Invisibility", rank = "", bCD = 300000 } )
			table.insert(d, { id = 11419, name = "Portal: Darnassus", rank = "", bCD = 60000 } )
			table.insert(d, { id = 32266, name = "Portal: Exodar", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11416, name = "Portal: Ironforge", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11417, name = "Portal: Orgrimmar", rank = "", bCD = 60000 } )
			table.insert(d, { id = 33691, name = "Portal: Shattrath", rank = "", bCD = 60000 } )
			table.insert(d, { id = 35717, name = "Portal: Shattrath", rank = "", bCD = 60000 } )
			table.insert(d, { id = 32267, name = "Portal: Silvermoon", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49361, name = "Portal: Stonard", rank = "", bCD = 60000 } )
			table.insert(d, { id = 10059, name = "Portal: Stormwind", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49360, name = "Portal: Theramore", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11420, name = "Portal: Thunder Bluff", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11418, name = "Portal: Undercity", rank = "", bCD = 60000 } )
			table.insert(d, { id = 43987, name = "Ritual of Refreshment", rank = "1", bCD = 300000, oaf = true } )
			
			-- TALENTS
			table.insert(d, { id = 12042, name = "Arcane Power", rank = "", bCD = 180000 } )
			table.insert(d, { id = 11113, name = "Blast Wave", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 13018, name = "Blast Wave", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 13019, name = "Blast Wave", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13020, name = "Blast Wave", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 13021, name = "Blast Wave", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 27133, name = "Blast Wave", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 33933, name = "Blast Wave", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 11958, name = "Cold Snap", rank = "", bCD = 480000 } )
			table.insert(d, { id = 11129, name = "Combustion", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 31661, name = "Dragon's Breath", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 33041, name = "Dragon's Breath", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 33042, name = "Dragon's Breath", rank = "3", bCD = 20000 } )
			table.insert(d, { id = 33043, name = "Dragon's Breath", rank = "4", bCD = 20000 } )
			table.insert(d, { id = 11426, name = "Ice Barrier", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 13031, name = "Ice Barrier", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 13032, name = "Ice Barrier", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13033, name = "Ice Barrier", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 27134, name = "Ice Barrier", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 33405, name = "Ice Barrier", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 12472, name = "Icy Veins", rank = "", bCD = 180000 } )
			table.insert(d, { id = 12043, name = "Presence of Mind", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 31687, name = "Summon Water Elemental", rank = "", bCD = 180000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 1953, name = "Blink", rank = "", bCD = 15000 } )
			table.insert(d, { id = 120, name = "Cone of Cold", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 8492, name = "Cone of Cold", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 10159, name = "Cone of Cold", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 10160, name = "Cone of Cold", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 10161, name = "Cone of Cold", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 27087, name = "Cone of Cold", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 42930, name = "Cone of Cold", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 42931, name = "Cone of Cold", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 2139, name = "Counterspell", rank = "", bCD = 24000 } )
			table.insert(d, { id = 12051, name = "Evocation", rank = "", bCD = 240000 } )
			table.insert(d, { id = 2136, name = "Fire Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 2137, name = "Fire Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 2138, name = "Fire Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 8412, name = "Fire Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 8413, name = "Fire Blast", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 10197, name = "Fire Blast", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 10199, name = "Fire Blast", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 27078, name = "Fire Blast", rank = "8", bCD = 8000 } )
			table.insert(d, { id = 27079, name = "Fire Blast", rank = "9", bCD = 8000 } )
			table.insert(d, { id = 42872, name = "Fire Blast", rank = "10", bCD = 8000 } )
			table.insert(d, { id = 42873, name = "Fire Blast", rank = "11", bCD = 8000 } )
			table.insert(d, { id = 543, name = "Fire Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8457, name = "Fire Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 8458, name = "Fire Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10223, name = "Fire Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10225, name = "Fire Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 27128, name = "Fire Ward", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 43010, name = "Fire Ward", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 122, name = "Frost Nova", rank = "1", bCD = 25000 } )
			table.insert(d, { id = 865, name = "Frost Nova", rank = "2", bCD = 25000 } )
			table.insert(d, { id = 6131, name = "Frost Nova", rank = "3", bCD = 25000 } )
			table.insert(d, { id = 10230, name = "Frost Nova", rank = "4", bCD = 25000 } )
			table.insert(d, { id = 27088, name = "Frost Nova", rank = "5", bCD = 25000 } )
			table.insert(d, { id = 42917, name = "Frost Nova", rank = "6", bCD = 25000 } )
			table.insert(d, { id = 6143, name = "Frost Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8461, name = "Frost Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 8462, name = "Frost Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10177, name = "Frost Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 28609, name = "Frost Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 32796, name = "Frost Ward", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 43012, name = "Frost Ward", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 45438, name = "Ice Block", rank = "", bCD = 300000 } )
			table.insert(d, { id = 66, name = "Invisibility", rank = "", bCD = 180000 } )
			table.insert(d, { id = 55342, name = "Mirror Image", rank = "", bCD = 180000 } )
			table.insert(d, { id = 53142, name = "Portal: Dalaran", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11419, name = "Portal: Darnassus", rank = "", bCD = 60000 } )
			table.insert(d, { id = 32266, name = "Portal: Exodar", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11416, name = "Portal: Ironforge", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11417, name = "Portal: Orgrimmar", rank = "", bCD = 60000 } )
			table.insert(d, { id = 33691, name = "Portal: Shattrath", rank = "", bCD = 60000 } )
			table.insert(d, { id = 35717, name = "Portal: Shattrath", rank = "", bCD = 60000 } )
			table.insert(d, { id = 32267, name = "Portal: Silvermoon", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49361, name = "Portal: Stonard", rank = "", bCD = 60000 } )
			table.insert(d, { id = 10059, name = "Portal: Stormwind", rank = "", bCD = 60000 } )
			table.insert(d, { id = 49360, name = "Portal: Theramore", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11420, name = "Portal: Thunder Bluff", rank = "", bCD = 60000 } )
			table.insert(d, { id = 11418, name = "Portal: Undercity", rank = "", bCD = 60000 } )
			table.insert(d, { id = 43987, name = "Ritual of Refreshment", rank = "1", bCD = 300000, oaf = true } )
			table.insert(d, { id = 58659, name = "Ritual of Refreshment", rank = "2", bCD = 300000, oaf = true } )
			table.insert(d, { id = 70909, name = "Summon Water Elemental (Prototype)", rank = "", bCD = 180000 } )
		
			-- TALENTS
			table.insert(d, { id = 44425, name = "Arcane Barrage", rank = "1", bCD = 3000 } )
			table.insert(d, { id = 44780, name = "Arcane Barrage", rank = "2", bCD = 3000 } )
			table.insert(d, { id = 44781, name = "Arcane Barrage", rank = "3", bCD = 3000 } )
			table.insert(d, { id = 12042, name = "Arcane Power", rank = "", bCD = 120000 } )
			table.insert(d, { id = 11113, name = "Blast Wave", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 13018, name = "Blast Wave", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 13019, name = "Blast Wave", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13020, name = "Blast Wave", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 13021, name = "Blast Wave", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 27133, name = "Blast Wave", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 33933, name = "Blast Wave", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 42944, name = "Blast Wave", rank = "8", bCD = 30000 } )
			table.insert(d, { id = 42945, name = "Blast Wave", rank = "9", bCD = 30000 } )
			table.insert(d, { id = 11958, name = "Cold Snap", rank = "", bCD = 480000 } )
			table.insert(d, { id = 11129, name = "Combustion", rank = "", bCD = 120000, oaf = true } )
			table.insert(d, { id = 44572, name = "Deep Freeze", rank = "", bCD = 30000 } )
			table.insert(d, { id = 31661, name = "Dragon's Breath", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 33041, name = "Dragon's Breath", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 33042, name = "Dragon's Breath", rank = "3", bCD = 20000 } )
			table.insert(d, { id = 33043, name = "Dragon's Breath", rank = "4", bCD = 20000 } )
			table.insert(d, { id = 42949, name = "Dragon's Breath", rank = "5", bCD = 20000 } )
			table.insert(d, { id = 42950, name = "Dragon's Breath", rank = "6", bCD = 20000 } )
			table.insert(d, { id = 11426, name = "Ice Barrier", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 13031, name = "Ice Barrier", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 13032, name = "Ice Barrier", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 13033, name = "Ice Barrier", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 27134, name = "Ice Barrier", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 33405, name = "Ice Barrier", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 43038, name = "Ice Barrier", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 43039, name = "Ice Barrier", rank = "8", bCD = 30000 } )
			table.insert(d, { id = 12472, name = "Icy Veins", rank = "", bCD = 180000 } )
			table.insert(d, { id = 12043, name = "Presence of Mind", rank = "", bCD = 120000, oaf = true } )
			table.insert(d, { id = 31687, name = "Summon Water Elemental", rank = "", bCD = 180000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 12043, name = "Presence of Mind", rank = "", bCD = 90000, oaf = true } )
			
		-- RETAIL
		else
			table.insert(d, { id = 205025, name = "Presence of Mind", rank = "", bCD = 45000, oaf = true } )
		end
	end
	
	-- Monk
	if class == "MONK" then
		-- MOP
		if CDTL3.tocversion < 60000 then
			table.insert(d, { id = 116680, name = "Thunder Focus Tea", rank = "", bCD = 45000, oaf = true } )
		end
	end
	
	-- Paladin
	if class == "PALADIN" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 1044, name = "Blessing of Freedom", rank = "", bCD = 20000 } )
			table.insert(d, { id = 1022, name = "Blessing of Protection", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 5599, name = "Blessing of Protection", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 10278, name = "Blessing of Protection", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 19752, name = "Divine Intervention", rank = "", bCD = 3600000 } )
			table.insert(d, { id = 498, name = "Divine Protection", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 5573, name = "Divine Protection", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 642, name = "Divine Shield", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 1020, name = "Divine Shield", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 879, name = "Exorcism", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 5614, name = "Exorcism", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 5615, name = "Exorcism", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 10312, name = "Exorcism", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 10313, name = "Exorcism", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 10314, name = "Exorcism", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 853, name = "Hammer of Justice", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 5588, name = "Hammer of Justice", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 5589, name = "Hammer of Justice", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 10308, name = "Hammer of Justice", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 24275, name = "Hammer of Wrath", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 24274, name = "Hammer of Wrath", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 24239, name = "Hammer of Wrath", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 2812, name = "Holy Wrath", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 10318, name = "Holy Wrath", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 20271, name = "Judgement", rank = "", bCD = 10000 } )
			table.insert(d, { id = 633, name = "Lay on Hands", rank = "1", bCD = 3600000 } )
			table.insert(d, { id = 2800, name = "Lay on Hands", rank = "2", bCD = 3600000 } )
			table.insert(d, { id = 10310, name = "Lay on Hands", rank = "3", bCD = 3600000 } )
			table.insert(d, { id = 2878, name = "Turn Undead", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 5627, name = "Turn Undead", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 10326, name = "Turn Undead", rank = "3", bCD = 30000 } )
			
			-- TALENTS
			table.insert(d, { id = 26573, name = "Consecration", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 20924, name = "Consecration", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 20923, name = "Consecration", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 20922, name = "Consecration", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 20116, name = "Consecration", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 20216, name = "Divine Favor", rank = "", bCD = 120000, oaf = true } )
			table.insert(d, { id = 20925, name = "Holy Shield", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 20928, name = "Holy Shield", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 20927, name = "Holy Shield", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 20473, name = "Holy Shock", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 20930, name = "Holy Shock", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 20929, name = "Holy Shock", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 20066, name = "Repentance", rank = "", bCD = 60000 } )
			
			-- RUNES
			table.insert(d, { id = 407669, name = "Avenger's Shield", rank = "", bCD = 15000 } )
			table.insert(d, { id = 407676, name = "Crusader Strike", rank = "", bCD = 6000 } )
			table.insert(d, { id = 407804, name = "Divine Sacrifice", rank = "", bCD = 120000 } )
			table.insert(d, { id = 407778, name = "Divine Storm", rank = "", bCD = 10000 } )
			table.insert(d, { id = 415068, name = "Exorcism", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 415069, name = "Exorcism", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 415070, name = "Exorcism", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 415071, name = "Exorcism", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 415072, name = "Exorcism", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 415073, name = "Exorcism", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 407631, name = "Hand of Reckoning", rank = "", bCD = 10000 } )
			table.insert(d, { id = 425600, name = "Horn of Lordaeron", rank = "", bCD = 20000 } )
			table.insert(d, { id = 425609, name = "Rebuke", rank = "", bCD = 15000 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 31884, name = "Avenging Wrath", rank = "", bCD = 180000 } )
			table.insert(d, { id = 1044, name = "Blessing of Freedom", rank = "", bCD = 25000 } )
			table.insert(d, { id = 1022, name = "Blessing of Protection", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 5599, name = "Blessing of Protection", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 10278, name = "Blessing of Protection", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 6940, name = "Blessing of Sacrifice", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 20729, name = "Blessing of Sacrifice", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 27147, name = "Blessing of Sacrifice", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 27148, name = "Blessing of Sacrifice", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 26573, name = "Consecration", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 20116, name = "Consecration", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 20922, name = "Consecration", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 20923, name = "Consecration", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 20924, name = "Consecration", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 27173, name = "Consecration", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 19752, name = "Divine Intervention", rank = "", bCD = 3600000 } )
			table.insert(d, { id = 498, name = "Divine Protection", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 5573, name = "Divine Protection", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 642, name = "Divine Shield", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 1020, name = "Divine Shield", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 879, name = "Exorcism", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 5614, name = "Exorcism", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 5615, name = "Exorcism", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 10312, name = "Exorcism", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 10313, name = "Exorcism", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 10314, name = "Exorcism", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 27138, name = "Exorcism", rank = "7", bCD = 15000 } )
			table.insert(d, { id = 853, name = "Hammer of Justice", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 5588, name = "Hammer of Justice", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 5589, name = "Hammer of Justice", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 10308, name = "Hammer of Justice", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 24275, name = "Hammer of Wrath", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 24274, name = "Hammer of Wrath", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 24239, name = "Hammer of Wrath", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 27180, name = "Hammer of Wrath", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 2812, name = "Holy Wrath", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 10318, name = "Holy Wrath", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 27139, name = "Holy Wrath", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 20271, name = "Judgement", rank = "", bCD = 10000 } )
			table.insert(d, { id = 633, name = "Lay on Hands", rank = "1", bCD = 3600000 } )
			table.insert(d, { id = 2800, name = "Lay on Hands", rank = "2", bCD = 3600000 } )
			table.insert(d, { id = 10310, name = "Lay on Hands", rank = "3", bCD = 3600000 } )
			table.insert(d, { id = 27154, name = "Lay on Hands", rank = "4", bCD = 3600000 } )
			table.insert(d, { id = 31789, name = "Righteous Defense", rank = "", bCD = 15000 } )
			table.insert(d, { id = 10326, name = "Turn Evil", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 2878, name = "Turn Undead", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 5627, name = "Turn Undead", rank = "2", bCD = 30000 } )
			
			-- TALENTS
			table.insert(d, { id = 31935, name = "Avenger's Shield", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 32699, name = "Avenger's Shield", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 32700, name = "Avenger's Shield", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 35395, name = "Crusader Strike", rank = "", bCD = 6000 } )
			table.insert(d, { id = 20216, name = "Divine Favor", rank = "", bCD = 120000, oaf = true } )
			table.insert(d, { id = 31842, name = "Divine Illumination", rank = "", bCD = 180000 } )
			table.insert(d, { id = 20925, name = "Holy Shield", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 20927, name = "Holy Shield", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 20928, name = "Holy Shield", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 27179, name = "Holy Shield", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 20473, name = "Holy Shock", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 20929, name = "Holy Shock", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 20930, name = "Holy Shock", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 27174, name = "Holy Shock", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 33072, name = "Holy Shock", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 20066, name = "Repentance", rank = "", bCD = 60000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 31884, name = "Avenging Wrath", rank = "", bCD = 180000 } )
			table.insert(d, { id = 26573, name = "Consecration", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 20116, name = "Consecration", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 20922, name = "Consecration", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 20923, name = "Consecration", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 20924, name = "Consecration", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 27173, name = "Consecration", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 48818, name = "Consecration", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 48819, name = "Consecration", rank = "8", bCD = 8000 } )
			table.insert(d, { id = 19752, name = "Divine Intervention", rank = "", bCD = 600000 } )
			table.insert(d, { id = 54428, name = "Divine Plea", rank = "", bCD = 60000 } )
			table.insert(d, { id = 498, name = "Divine Protection", rank = "", bCD = 180000 } )
			table.insert(d, { id = 642, name = "Divine Shield", rank = "", bCD = 300000 } )
			table.insert(d, { id = 879, name = "Exorcism", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 5614, name = "Exorcism", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 5615, name = "Exorcism", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 10312, name = "Exorcism", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 10313, name = "Exorcism", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 10314, name = "Exorcism", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 27138, name = "Exorcism", rank = "7", bCD = 15000 } )
			table.insert(d, { id = 48800, name = "Exorcism", rank = "8", bCD = 15000 } )
			table.insert(d, { id = 48801, name = "Exorcism", rank = "9", bCD = 15000 } )
			table.insert(d, { id = 853, name = "Hammer of Justice", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 5588, name = "Hammer of Justice", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 5589, name = "Hammer of Justice", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 10308, name = "Hammer of Justice", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 24275, name = "Hammer of Wrath", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 24274, name = "Hammer of Wrath", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 24239, name = "Hammer of Wrath", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 27180, name = "Hammer of Wrath", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 48805, name = "Hammer of Wrath", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 48806, name = "Hammer of Wrath", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 1044, name = "Hand of Freedom", rank = "", bCD = 25000 } )
			table.insert(d, { id = 1022, name = "Hand of Protection", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 5599, name = "Hand of Protection", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 10278, name = "Hand of Protection", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 62124, name = "Hand of Reckoning", rank = "", bCD = 8000 } )
			table.insert(d, { id = 6940, name = "Hand of Sacrifice", rank = "", bCD = 120000 } )
			table.insert(d, { id = 1038, name = "Hand of Salvation", rank = "", bCD = 120000 } )
			table.insert(d, { id = 2812, name = "Holy Wrath", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 10318, name = "Holy Wrath", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 27139, name = "Holy Wrath", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 48816, name = "Holy Wrath", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 48817, name = "Holy Wrath", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 53407, name = "Judgement of Justice", rank = "", bCD = 10000 } )
			table.insert(d, { id = 20271, name = "Judgement of Light", rank = "", bCD = 10000 } )
			table.insert(d, { id = 53408, name = "Judgement of Wisdom", rank = "", bCD = 10000 } )
			table.insert(d, { id = 633, name = "Lay on Hands", rank = "1", bCD = 1200000 } )
			table.insert(d, { id = 2800, name = "Lay on Hands", rank = "2", bCD = 1200000 } )
			table.insert(d, { id = 10310, name = "Lay on Hands", rank = "3", bCD = 1200000 } )
			table.insert(d, { id = 27154, name = "Lay on Hands", rank = "4", bCD = 1200000 } )
			table.insert(d, { id = 48788, name = "Lay on Hands", rank = "5", bCD = 1200000 } )
			table.insert(d, { id = 31789, name = "Righteous Defense", rank = "", bCD = 8000 } )
			table.insert(d, { id = 53600, name = "Shield of Righteousness", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 61411, name = "Shield of Righteousness", rank = "2", bCD = 6000 } )
			
			-- TALENTS
			table.insert(d, { id = 31821, name = "Aura Mastery", rank = "", bCD = 120000 } )
			table.insert(d, { id = 31935, name = "Avenger's Shield", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 32699, name = "Avenger's Shield", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 32700, name = "Avenger's Shield", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 48826, name = "Avenger's Shield", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 48827, name = "Avenger's Shield", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 35395, name = "Crusader Strike", rank = "", bCD = 4000 } )
			table.insert(d, { id = 20216, name = "Divine Favor", rank = "", bCD = 120000, oaf = true } )
			table.insert(d, { id = 31842, name = "Divine Illumination", rank = "", bCD = 180000 } )
			table.insert(d, { id = 64205, name = "Divine Sacrifice", rank = "", bCD = 120000 } )
			table.insert(d, { id = 53385, name = "Divine Storm", rank = "", bCD = 10000 } )
			table.insert(d, { id = 53595, name = "Hammer of the Righteous", rank = "", bCD = 6000 } )
			table.insert(d, { id = 20925, name = "Holy Shield", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 20927, name = "Holy Shield", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 20928, name = "Holy Shield", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 27179, name = "Holy Shield", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 48951, name = "Holy Shield", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 48952, name = "Holy Shield", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 20473, name = "Holy Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 20929, name = "Holy Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 20930, name = "Holy Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 27174, name = "Holy Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 33072, name = "Holy Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 48824, name = "Holy Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 48825, name = "Holy Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 20066, name = "Repentance", rank = "", bCD = 60000 } )
			
		-- RETAIL (MoP has none)
		elseif CDTL3.tocversion >= 60000 then
			table.insert(d, { id = 215652, name = "Shield of Virtue", rank = "", bCD = 45000, oaf = true } )
		end
	end
	
	-- Priest
	if class == "PRIEST" then
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 13908, name = "Desperate Prayer", rank = "1", bCD = 600000 } )
			table.insert(d, { id = 19236, name = "Desperate Prayer", rank = "2", bCD = 600000 } )
			table.insert(d, { id = 19238, name = "Desperate Prayer", rank = "3", bCD = 600000 } )
			table.insert(d, { id = 19240, name = "Desperate Prayer", rank = "4", bCD = 600000 } )
			table.insert(d, { id = 19241, name = "Desperate Prayer", rank = "5", bCD = 600000 } )
			table.insert(d, { id = 19242, name = "Desperate Prayer", rank = "6", bCD = 600000 } )
			table.insert(d, { id = 19243, name = "Desperate Prayer", rank = "7", bCD = 600000 } )
			table.insert(d, { id = 2944, name = "Devouring Plague", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 19276, name = "Devouring Plague", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 19277, name = "Devouring Plague", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 19278, name = "Devouring Plague", rank = "4", bCD = 180000 } )
			table.insert(d, { id = 19279, name = "Devouring Plague", rank = "5", bCD = 180000 } )
			table.insert(d, { id = 19280, name = "Devouring Plague", rank = "6", bCD = 180000 } )
			table.insert(d, { id = 2651, name = "Elune's Grace", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 19289, name = "Elune's Grace", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 19291, name = "Elune's Grace", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 19292, name = "Elune's Grace", rank = "4", bCD = 300000 } )
			table.insert(d, { id = 19293, name = "Elune's Grace", rank = "5", bCD = 300000 } )
			table.insert(d, { id = 586, name = "Fade", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 9578, name = "Fade", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 9579, name = "Fade", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 9592, name = "Fade", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10941, name = "Fade", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 10942, name = "Fade", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 6346, name = "Fear Ward", rank = "", bCD = 30000 } )
			table.insert(d, { id = 13896, name = "Feedback", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 19271, name = "Feedback", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 19273, name = "Feedback", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 19274, name = "Feedback", rank = "4", bCD = 180000 } )
			table.insert(d, { id = 19275, name = "Feedback", rank = "5", bCD = 180000 } )
			table.insert(d, { id = 8092, name = "Mind Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 8102, name = "Mind Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 8103, name = "Mind Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 8104, name = "Mind Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 8105, name = "Mind Blast", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 8106, name = "Mind Blast", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 10945, name = "Mind Blast", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 10946, name = "Mind Blast", rank = "8", bCD = 8000 } )
			table.insert(d, { id = 10947, name = "Mind Blast", rank = "9", bCD = 8000 } )
			table.insert(d, { id = 17, name = "Power Word: Shield", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 592, name = "Power Word: Shield", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 600, name = "Power Word: Shield", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 3747, name = "Power Word: Shield", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 6065, name = "Power Word: Shield", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 6066, name = "Power Word: Shield", rank = "6", bCD = 4000 } )
			table.insert(d, { id = 10898, name = "Power Word: Shield", rank = "7", bCD = 4000 } )
			table.insert(d, { id = 10899, name = "Power Word: Shield", rank = "8", bCD = 4000 } )
			table.insert(d, { id = 10900, name = "Power Word: Shield", rank = "9", bCD = 4000 } )
			table.insert(d, { id = 10901, name = "Power Word: Shield", rank = "10", bCD = 4000 } )
			table.insert(d, { id = 8122, name = "Psychic Scream", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8124, name = "Psychic Scream", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 10888, name = "Psychic Scream", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10890, name = "Psychic Scream", rank = "4", bCD = 30000 } )
			
			-- TALENTS
			table.insert(d, { id = 14751, name = "Inner Focus", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 724, name = "Lightwell", rank = "1", bCD = 600000 } )
			table.insert(d, { id = 27870, name = "Lightwell", rank = "2", bCD = 600000 } )
			table.insert(d, { id = 27871, name = "Lightwell", rank = "3", bCD = 600000 } )
			table.insert(d, { id = 10060, name = "Power Infusion", rank = "", bCD = 180000 } )
			table.insert(d, { id = 15473, name = "Shadowform", rank = "", bCD = 1500, oaf = true } )
			table.insert(d, { id = 15487, name = "Silence", rank = "", bCD = 45000 } )
			table.insert(d, { id = 15286, name = "Vampiric Embrace", rank = "", bCD = 10000 } )
			
			-- RUNES
			table.insert(d, { id = 401946, name = "Circle of Healing", rank = "", bCD = 6000 } )
			table.insert(d, { id = 402799, name = "Homunculi", rank = "", bCD = 120000 } )
			table.insert(d, { id = 402174, name = "Penance", rank = "", bCD = 12000 } )
			table.insert(d, { id = 425207, name = "Power Word: Barrier", rank = "", bCD = 180000 } )
			table.insert(d, { id = 401859, name = "Prayer of Mending", rank = "", bCD = 10000 } )
			table.insert(d, { id = 401955, name = "Shadow Word: Death", rank = "", bCD = 12000 } )
			table.insert(d, { id = 425204, name = "Void Plague", rank = "", bCD = 6000 } )

			table.insert(d, { id = 425294, name = "Dispersion", rank = "", bCD = 120000 } )
			table.insert(d, { id = 402004, name = "Pain Suppression", rank = "", bCD = 180000 } )
			table.insert(d, { id = 401977, name = "Shadowfiend", rank = "", bCD = 300000 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 44041, name = "Chastise", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 44043, name = "Chastise", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 44044, name = "Chastise", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 44045, name = "Chastise", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 44046, name = "Chastise", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 44047, name = "Chastise", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 32676, name = "Consume Magic", rank = "", bCD = 120000 } )
			table.insert(d, { id = 13908, name = "Desperate Prayer", rank = "1", bCD = 600000 } )
			table.insert(d, { id = 19236, name = "Desperate Prayer", rank = "2", bCD = 600000 } )
			table.insert(d, { id = 19238, name = "Desperate Prayer", rank = "3", bCD = 600000 } )
			table.insert(d, { id = 19240, name = "Desperate Prayer", rank = "4", bCD = 600000 } )
			table.insert(d, { id = 19241, name = "Desperate Prayer", rank = "5", bCD = 600000 } )
			table.insert(d, { id = 19242, name = "Desperate Prayer", rank = "6", bCD = 600000 } )
			table.insert(d, { id = 19243, name = "Desperate Prayer", rank = "7", bCD = 600000 } )
			table.insert(d, { id = 25437, name = "Desperate Prayer", rank = "8", bCD = 600000 } )
			table.insert(d, { id = 2944, name = "Devouring Plague", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 19276, name = "Devouring Plague", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 19277, name = "Devouring Plague", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 19278, name = "Devouring Plague", rank = "4", bCD = 180000 } )
			table.insert(d, { id = 19279, name = "Devouring Plague", rank = "5", bCD = 180000 } )
			table.insert(d, { id = 19280, name = "Devouring Plague", rank = "6", bCD = 180000 } )
			table.insert(d, { id = 25467, name = "Devouring Plague", rank = "7", bCD = 180000 } )
			table.insert(d, { id = 2651, name = "Elune's Grace", rank = "", bCD = 180000 } )
			table.insert(d, { id = 586, name = "Fade", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 9578, name = "Fade", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 9579, name = "Fade", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 9592, name = "Fade", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10941, name = "Fade", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 10942, name = "Fade", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 25429, name = "Fade", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 6346, name = "Fear Ward", rank = "", bCD = 180000 } )
			table.insert(d, { id = 13896, name = "Feedback", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 19271, name = "Feedback", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 19273, name = "Feedback", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 19274, name = "Feedback", rank = "4", bCD = 180000 } )
			table.insert(d, { id = 19275, name = "Feedback", rank = "5", bCD = 180000 } )
			table.insert(d, { id = 25441, name = "Feedback", rank = "6", bCD = 180000 } )
			table.insert(d, { id = 8092, name = "Mind Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 8102, name = "Mind Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 8103, name = "Mind Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 8104, name = "Mind Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 8105, name = "Mind Blast", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 8106, name = "Mind Blast", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 10945, name = "Mind Blast", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 10946, name = "Mind Blast", rank = "8", bCD = 8000 } )
			table.insert(d, { id = 10947, name = "Mind Blast", rank = "9", bCD = 8000 } )
			table.insert(d, { id = 25372, name = "Mind Blast", rank = "10", bCD = 8000 } )
			table.insert(d, { id = 25375, name = "Mind Blast", rank = "11", bCD = 8000 } )
			table.insert(d, { id = 17, name = "Power Word: Shield", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 592, name = "Power Word: Shield", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 600, name = "Power Word: Shield", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 3747, name = "Power Word: Shield", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 6065, name = "Power Word: Shield", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 6066, name = "Power Word: Shield", rank = "6", bCD = 4000 } )
			table.insert(d, { id = 10898, name = "Power Word: Shield", rank = "7", bCD = 4000 } )
			table.insert(d, { id = 10899, name = "Power Word: Shield", rank = "8", bCD = 4000 } )
			table.insert(d, { id = 10900, name = "Power Word: Shield", rank = "9", bCD = 4000 } )
			table.insert(d, { id = 10901, name = "Power Word: Shield", rank = "10", bCD = 4000 } )
			table.insert(d, { id = 25217, name = "Power Word: Shield", rank = "11", bCD = 4000 } )
			table.insert(d, { id = 25218, name = "Power Word: Shield", rank = "12", bCD = 4000 } )
			table.insert(d, { id = 33076, name = "Prayer of Mending", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 8122, name = "Psychic Scream", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8124, name = "Psychic Scream", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 10888, name = "Psychic Scream", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10890, name = "Psychic Scream", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 32379, name = "Shadow Word: Death", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 32996, name = "Shadow Word: Death", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 34433, name = "Shadowfiend", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 10797, name = "Starshards", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 19296, name = "Starshards", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 19299, name = "Starshards", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 19302, name = "Starshards", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 19303, name = "Starshards", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 19304, name = "Starshards", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 19305, name = "Starshards", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 25446, name = "Starshards", rank = "8", bCD = 30000 } )
			table.insert(d, { id = 32548, name = "Symbol of Hope", rank = "", bCD = 300000 } )
			
			-- TALENTS
			table.insert(d, { id = 14751, name = "Inner Focus", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 724, name = "Lightwell", rank = "1", bCD = 360000 } )
			table.insert(d, { id = 27870, name = "Lightwell", rank = "2", bCD = 360000 } )
			table.insert(d, { id = 27871, name = "Lightwell", rank = "3", bCD = 360000 } )
			table.insert(d, { id = 28275, name = "Lightwell", rank = "4", bCD = 360000 } )
			table.insert(d, { id = 33206, name = "Pain Suppression", rank = "", bCD = 120000 } )
			table.insert(d, { id = 10060, name = "Power Infusion", rank = "", bCD = 180000 } )
			table.insert(d, { id = 15473, name = "Shadowform", rank = "", bCD = 1500, oaf = true } )
			table.insert(d, { id = 15487, name = "Silence", rank = "", bCD = 45000 } )
			table.insert(d, { id = 15286, name = "Vampiric Embrace", rank = "", bCD = 10000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 64843, name = "Divine Hymn", rank = "1", bCD = 480000 } )
			table.insert(d, { id = 586, name = "Fade", rank = "", bCD = 30000 } )
			table.insert(d, { id = 6346, name = "Fear Ward", rank = "", bCD = 180000 } )
			table.insert(d, { id = 14914, name = "Holy Fire", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 15262, name = "Holy Fire", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 15263, name = "Holy Fire", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 15264, name = "Holy Fire", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 15265, name = "Holy Fire", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 15266, name = "Holy Fire", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 15267, name = "Holy Fire", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 15261, name = "Holy Fire", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 25384, name = "Holy Fire", rank = "9", bCD = 10000 } )
			table.insert(d, { id = 48134, name = "Holy Fire", rank = "10", bCD = 10000 } )
			table.insert(d, { id = 48135, name = "Holy Fire", rank = "11", bCD = 10000 } )
			table.insert(d, { id = 64901, name = "Hymn of Hope", rank = "", bCD = 360000 } )
			table.insert(d, { id = 8092, name = "Mind Blast", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 8102, name = "Mind Blast", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 8103, name = "Mind Blast", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 8104, name = "Mind Blast", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 8105, name = "Mind Blast", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 8106, name = "Mind Blast", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 10945, name = "Mind Blast", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 10946, name = "Mind Blast", rank = "8", bCD = 8000 } )
			table.insert(d, { id = 10947, name = "Mind Blast", rank = "9", bCD = 8000 } )
			table.insert(d, { id = 25372, name = "Mind Blast", rank = "10", bCD = 8000 } )
			table.insert(d, { id = 25375, name = "Mind Blast", rank = "11", bCD = 8000 } )
			table.insert(d, { id = 48126, name = "Mind Blast", rank = "12", bCD = 8000 } )
			table.insert(d, { id = 48127, name = "Mind Blast", rank = "13", bCD = 8000 } )
			table.insert(d, { id = 17, name = "Power Word: Shield", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 592, name = "Power Word: Shield", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 600, name = "Power Word: Shield", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 3747, name = "Power Word: Shield", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 6065, name = "Power Word: Shield", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 6066, name = "Power Word: Shield", rank = "6", bCD = 4000 } )
			table.insert(d, { id = 10898, name = "Power Word: Shield", rank = "7", bCD = 4000 } )
			table.insert(d, { id = 10899, name = "Power Word: Shield", rank = "8", bCD = 4000 } )
			table.insert(d, { id = 10900, name = "Power Word: Shield", rank = "9", bCD = 4000 } )
			table.insert(d, { id = 10901, name = "Power Word: Shield", rank = "10", bCD = 4000 } )
			table.insert(d, { id = 25217, name = "Power Word: Shield", rank = "11", bCD = 4000 } )
			table.insert(d, { id = 25218, name = "Power Word: Shield", rank = "12", bCD = 4000 } )
			table.insert(d, { id = 48065, name = "Power Word: Shield", rank = "13", bCD = 4000 } )
			table.insert(d, { id = 48066, name = "Power Word: Shield", rank = "14", bCD = 4000 } )
			table.insert(d, { id = 33076, name = "Prayer of Mending", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 48112, name = "Prayer of Mending", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 48113, name = "Prayer of Mending", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 8122, name = "Psychic Scream", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 8124, name = "Psychic Scream", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 10888, name = "Psychic Scream", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 10890, name = "Psychic Scream", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 32379, name = "Shadow Word: Death", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 32996, name = "Shadow Word: Death", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 48157, name = "Shadow Word: Death", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 48158, name = "Shadow Word: Death", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 34433, name = "Shadowfiend", rank = "", bCD = 300000 } )
			
			-- TALENTS
			table.insert(d, { id = 34861, name = "Circle of Healing", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 34863, name = "Circle of Healing", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 34864, name = "Circle of Healing", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 34865, name = "Circle of Healing", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 34866, name = "Circle of Healing", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 48088, name = "Circle of Healing", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 48089, name = "Circle of Healing", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 19236, name = "Desperate Prayer", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 19238, name = "Desperate Prayer", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 19240, name = "Desperate Prayer", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 19241, name = "Desperate Prayer", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 19242, name = "Desperate Prayer", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 19243, name = "Desperate Prayer", rank = "6", bCD = 120000 } )
			table.insert(d, { id = 25437, name = "Desperate Prayer", rank = "7", bCD = 120000 } )
			table.insert(d, { id = 48172, name = "Desperate Prayer", rank = "8", bCD = 120000 } )
			table.insert(d, { id = 48173, name = "Desperate Prayer", rank = "9", bCD = 120000 } )
			table.insert(d, { id = 47585, name = "Dispersion", rank = "", bCD = 120000 } )
			table.insert(d, { id = 47788, name = "Guardian Spirit", rank = "", bCD = 180000 } )
			table.insert(d, { id = 14751, name = "Inner Focus", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 724, name = "Lightwell", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 27870, name = "Lightwell", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 27871, name = "Lightwell", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 28275, name = "Lightwell", rank = "4", bCD = 180000 } )
			table.insert(d, { id = 48086, name = "Lightwell", rank = "5", bCD = 180000 } )
			table.insert(d, { id = 48087, name = "Lightwell", rank = "6", bCD = 180000 } )
			table.insert(d, { id = 33206, name = "Pain Suppression", rank = "", bCD = 180000 } )
			table.insert(d, { id = 47540, name = "Penance", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 53005, name = "Penance", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 53006, name = "Penance", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 53007, name = "Penance", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 10060, name = "Power Infusion", rank = "", bCD = 120000 } )
			table.insert(d, { id = 64044, name = "Psychic Horror", rank = "", bCD = 120000 } )
			table.insert(d, { id = 15473, name = "Shadowform", rank = "", bCD = 1500, oaf = true } )
			table.insert(d, { id = 15487, name = "Silence", rank = "", bCD = 45000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 89485, name = "Inner Focus", rank = "", bCD = 45000, oaf = true } )
		end
	end
	
	-- Rogue
	if class == "ROGUE" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 2094, name = "Blind", rank = "", bCD = 300000 } )
			table.insert(d, { id = 1725, name = "Distract", rank = "", bCD = 30000 } )
			table.insert(d, { id = 5277, name = "Evasion", rank = "", bCD = 300000 } )
			table.insert(d, { id = 1966, name = "Feint", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 6768, name = "Feint", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 8637, name = "Feint", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 11303, name = "Feint", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25302, name = "Feint", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 1776, name = "Gouge", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 1777, name = "Gouge", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 8629, name = "Gouge", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 11285, name = "Gouge", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 11286, name = "Gouge", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 1766, name = "Kick", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 1767, name = "Kick", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 1768, name = "Kick", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 1769, name = "Kick", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 408, name = "Kidney Shot", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 8643, name = "Kidney Shot", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 2983, name = "Sprint", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 8696, name = "Sprint", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 11305, name = "Sprint", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 1784, name = "Stealth", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1785, name = "Stealth", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1786, name = "Stealth", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1787, name = "Stealth", rank = "4", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1856, name = "Vanish", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 1857, name = "Vanish", rank = "2", bCD = 300000 } )
			
			-- TALENTS
			table.insert(d, { id = 13750, name = "Adrenaline Rush", rank = "", bCD = 300000 } )
			table.insert(d, { id = 13877, name = "Blade Flurry", rank = "", bCD = 120000 } )
			table.insert(d, { id = 14177, name = "Cold Blood", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 14278, name = "Ghostly Strike", rank = "", bCD = 20000 } )
			table.insert(d, { id = 14183, name = "Premeditation", rank = "", bCD = 120000 } )
			table.insert(d, { id = 14185, name = "Preparation", rank = "", bCD = 600000 } )
			table.insert(d, { id = 14251, name = "Riposte", rank = "", bCD = 6000 } )
			
			-- RUNES
			table.insert(d, { id = 400009, name = "Between the Eyes", rank = "", bCD = 20000 } )
			table.insert(d, { id = 424919, name = "Main Gauche", rank = "", bCD = 15000 } )
			table.insert(d, { id = 398196, name = "Quick Draw", rank = "", bCD = 10000 } )

			table.insert(d, { id = 425012, name = "Poisoned Knife", rank = "", bCD = 6000 } )
			table.insert(d, { id = 438040, name = "Redirect", rank = "", bCD = 10000 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 2094, name = "Blind", rank = "", bCD = 180000 } )
			table.insert(d, { id = 31224, name = "Cloak of Shadows", rank = "", bCD = 60000 } )
			table.insert(d, { id = 1725, name = "Distract", rank = "", bCD = 30000 } )
			table.insert(d, { id = 5277, name = "Evasion", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 26669, name = "Evasion", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 1966, name = "Feint", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 6768, name = "Feint", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 8637, name = "Feint", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 11303, name = "Feint", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25302, name = "Feint", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 27448, name = "Feint", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 1776, name = "Gouge", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 1777, name = "Gouge", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 8629, name = "Gouge", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 11285, name = "Gouge", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 11286, name = "Gouge", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 38764, name = "Gouge", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 1766, name = "Kick", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 1767, name = "Kick", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 1768, name = "Kick", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 1769, name = "Kick", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 38768, name = "Kick", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 408, name = "Kidney Shot", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 8643, name = "Kidney Shot", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 2983, name = "Sprint", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 8696, name = "Sprint", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 11305, name = "Sprint", rank = "3", bCD = 300000 } )
			table.insert(d, { id = 1784, name = "Stealth", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1785, name = "Stealth", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1786, name = "Stealth", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1787, name = "Stealth", rank = "4", bCD = 10000, oaf = true } )
			table.insert(d, { id = 1856, name = "Vanish", rank = "1", bCD = 300000 } )
			table.insert(d, { id = 1857, name = "Vanish", rank = "2", bCD = 300000 } )
			table.insert(d, { id = 26889, name = "Vanish", rank = "3", bCD = 300000 } )
			
			-- TALENTS
			table.insert(d, { id = 13750, name = "Adrenaline Rush", rank = "", bCD = 300000 } )
			table.insert(d, { id = 13877, name = "Blade Flurry", rank = "", bCD = 120000 } )
			table.insert(d, { id = 14177, name = "Cold Blood", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 14278, name = "Ghostly Strike", rank = "", bCD = 20000 } )
			table.insert(d, { id = 14183, name = "Premeditation", rank = "", bCD = 120000 } )
			table.insert(d, { id = 14185, name = "Preparation", rank = "", bCD = 600000 } )
			table.insert(d, { id = 14251, name = "Riposte", rank = "", bCD = 6000 } )
			table.insert(d, { id = 36554, name = "Shadowstep", rank = "", bCD = 30000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 2094, name = "Blind", rank = "", bCD = 180000 } )
			table.insert(d, { id = 31224, name = "Cloak of Shadows", rank = "", bCD = 90000 } )
			table.insert(d, { id = 51722, name = "Dismantle", rank = "", bCD = 60000 } )
			table.insert(d, { id = 1725, name = "Distract", rank = "", bCD = 30000 } )
			table.insert(d, { id = 5277, name = "Evasion", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 26669, name = "Evasion", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 1966, name = "Feint", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 6768, name = "Feint", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 8637, name = "Feint", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 11303, name = "Feint", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25302, name = "Feint", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 27448, name = "Feint", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 48658, name = "Feint", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 48659, name = "Feint", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 1776, name = "Gouge", rank = "", bCD = 10000 } )
			table.insert(d, { id = 1766, name = "Kick", rank = "", bCD = 10000 } )
			table.insert(d, { id = 408, name = "Kidney Shot", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 8643, name = "Kidney Shot", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 2983, name = "Sprint", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 8696, name = "Sprint", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 11305, name = "Sprint", rank = "3", bCD = 180000 } )
			table.insert(d, { id = 1784, name = "Stealth", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 57934, name = "Tricks of the Trade", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 1856, name = "Vanish", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 1857, name = "Vanish", rank = "2", bCD = 180000 } )
			table.insert(d, { id = 26889, name = "Vanish", rank = "3", bCD = 180000 } )
			
			-- TALENTS
			table.insert(d, { id = 13750, name = "Adrenaline Rush", rank = "", bCD = 180000 } )
			table.insert(d, { id = 13877, name = "Blade Flurry", rank = "", bCD = 120000 } )
			table.insert(d, { id = 14177, name = "Cold Blood", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 14278, name = "Ghostly Strike", rank = "", bCD = 20000 } )
			table.insert(d, { id = 51690, name = "Killing Spree", rank = "", bCD = 120000 } )
			table.insert(d, { id = 14183, name = "Premeditation", rank = "", bCD = 20000 } )
			table.insert(d, { id = 14185, name = "Preparation", rank = "", bCD = 480000 } )
			table.insert(d, { id = 14251, name = "Riposte", rank = "", bCD = 6000 } )
			table.insert(d, { id = 51713, name = "Shadow Dance", rank = "", bCD = 60000 } )
			table.insert(d, { id = 36554, name = "Shadowstep", rank = "", bCD = 30000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 1784, name = "Stealth", rank = "", bCD = 6000, oaf = true } )
			table.insert(d, { id = 57934, name = "Tricks of the Trade", rank = "", bCD = 30000, oaf = true } )
			
		-- RETAIL
		else
			table.insert(d, { id = 1784, name = "Stealth", rank = "", bCD = 2000, oaf = true } )
			table.insert(d, { id = 57934, name = "Tricks of the Trade", rank = "", bCD = 30000, oaf = true } )
		end
	end
	
	-- Shaman
	if class == "SHAMAN" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 556, name = "Astral Recall", rank = "", bCD = 900000 } )
			table.insert(d, { id = 421, name = "Chain Lightning", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 930, name = "Chain Lightning", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 2860, name = "Chain Lightning", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10605, name = "Chain Lightning", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 8042, name = "Earth Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8044, name = "Earth Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8045, name = "Earth Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 8046, name = "Earth Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 10412, name = "Earth Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 10413, name = "Earth Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 10414, name = "Earth Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 2484, name = "Earthbind Totem", rank = "", bCD = 15000 } )
			table.insert(d, { id = 1535, name = "Fire Nova Totem", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 8498, name = "Fire Nova Totem", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 8499, name = "Fire Nova Totem", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 11314, name = "Fire Nova Totem", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 11315, name = "Fire Nova Totem", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 8050, name = "Flame Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8052, name = "Flame Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8053, name = "Flame Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10447, name = "Flame Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 10448, name = "Flame Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 29228, name = "Flame Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 8056, name = "Frost Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8058, name = "Frost Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 10472, name = "Frost Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10473, name = "Frost Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 8177, name = "Grounding Totem", rank = "", bCD = 15000 } )
			table.insert(d, { id = 5730, name = "Stoneclaw Totem", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 6390, name = "Stoneclaw Totem", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 6391, name = "Stoneclaw Totem", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 6392, name = "Stoneclaw Totem", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10427, name = "Stoneclaw Totem", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 10428, name = "Stoneclaw Totem", rank = "6", bCD = 30000 } )
			
			-- TALENTS
			table.insert(d, { id = 16166, name = "Elemental Mastery", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 16188, name = "Nature's Swiftness", rank = "", bCD = 180000, oaf = true } )

			-- RUNES
			table.insert(d, { id = 409324, name = "Ancestral Guidance", rank = "", bCD = 60000 } )
			table.insert(d, { id = 415236, name = "Healing Rain", rank = "", bCD = 10000 } )
			table.insert(d, { id = 408490, name = "Lava Burst", rank = "", bCD = 8000 } )
			table.insert(d, { id = 408507, name = "Lava Lash", rank = "", bCD = 6000 } )
			table.insert(d, { id = 425339, name = "Molten Blast", rank = "", bCD = 6000 } )
			table.insert(d, { id = 425336, name = "Shamanistic Rage", rank = "", bCD = 60000 } )

			table.insert(d, { id = 425874, name = "Decoy Totem", rank = "", bCD = 20000 } )
			table.insert(d, { id = 408341, name = "Fire Nova", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 408342, name = "Fire Nova", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 408343, name = "Fire Nova", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 408345, name = "Fire Nova", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 437009, name = "Totemic Projection", rank = "", bCD = 10000 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 556, name = "Astral Recall", rank = "", bCD = 900000 } )
			table.insert(d, { id = 2825, name = "Bloodlust", rank = "1", bCD = 600000 } )
			table.insert(d, { id = 421, name = "Chain Lightning", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 930, name = "Chain Lightning", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 2860, name = "Chain Lightning", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10605, name = "Chain Lightning", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25439, name = "Chain Lightning", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 25442, name = "Chain Lightning", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 2062, name = "Earth Elemental Totem", rank = "1", bCD = 1200000 } )
			table.insert(d, { id = 8042, name = "Earth Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8044, name = "Earth Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8045, name = "Earth Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 8046, name = "Earth Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 10412, name = "Earth Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 10413, name = "Earth Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 10414, name = "Earth Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 25454, name = "Earth Shock", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 2484, name = "Earthbind Totem", rank = "", bCD = 15000 } )
			table.insert(d, { id = 2894, name = "Fire Elemental Totem", rank = "1", bCD = 1200000 } )
			table.insert(d, { id = 1535, name = "Fire Nova Totem", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 8498, name = "Fire Nova Totem", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 8499, name = "Fire Nova Totem", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 11314, name = "Fire Nova Totem", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 11315, name = "Fire Nova Totem", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 25546, name = "Fire Nova Totem", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 25547, name = "Fire Nova Totem", rank = "7", bCD = 15000 } )
			table.insert(d, { id = 8050, name = "Flame Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8052, name = "Flame Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8053, name = "Flame Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10447, name = "Flame Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 10448, name = "Flame Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 29228, name = "Flame Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 25457, name = "Flame Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 8056, name = "Frost Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8058, name = "Frost Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 10472, name = "Frost Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10473, name = "Frost Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25464, name = "Frost Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 8177, name = "Grounding Totem", rank = "", bCD = 15000 } )
			table.insert(d, { id = 32182, name = "Heroism", rank = "", bCD = 600000 } )
			table.insert(d, { id = 5730, name = "Stoneclaw Totem", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 6390, name = "Stoneclaw Totem", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 6391, name = "Stoneclaw Totem", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 6392, name = "Stoneclaw Totem", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10427, name = "Stoneclaw Totem", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 10428, name = "Stoneclaw Totem", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 25525, name = "Stoneclaw Totem", rank = "7", bCD = 30000 } )
			
			-- TALENTS
			table.insert(d, { id = 16166, name = "Elemental Mastery", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 16190, name = "Mana Tide Totem", rank = "", bCD = 300000 } )
			table.insert(d, { id = 16188, name = "Nature's Swiftness", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 30823, name = "Shamanistic Rage", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17364, name = "Stormstrike", rank = "", bCD = 10000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 556, name = "Astral Recall", rank = "", bCD = 900000 } )
			table.insert(d, { id = 2825, name = "Bloodlust", rank = "", bCD = 300000 } )
			table.insert(d, { id = 421, name = "Chain Lightning", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 930, name = "Chain Lightning", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 2860, name = "Chain Lightning", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10605, name = "Chain Lightning", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25439, name = "Chain Lightning", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 25442, name = "Chain Lightning", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 49270, name = "Chain Lightning", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 49271, name = "Chain Lightning", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 2062, name = "Earth Elemental Totem", rank = "", bCD = 600000 } )
			table.insert(d, { id = 8042, name = "Earth Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8044, name = "Earth Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8045, name = "Earth Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 8046, name = "Earth Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 10412, name = "Earth Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 10413, name = "Earth Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 10414, name = "Earth Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 25454, name = "Earth Shock", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 49230, name = "Earth Shock", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 49231, name = "Earth Shock", rank = "10", bCD = 6000 } )
			table.insert(d, { id = 2484, name = "Earthbind Totem", rank = "", bCD = 15000 } )
			table.insert(d, { id = 2894, name = "Fire Elemental Totem", rank = "", bCD = 600000 } )
			table.insert(d, { id = 1535, name = "Fire Nova", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 8498, name = "Fire Nova", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 8499, name = "Fire Nova", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 11314, name = "Fire Nova", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 11315, name = "Fire Nova", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 25546, name = "Fire Nova", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 25547, name = "Fire Nova", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 61649, name = "Fire Nova", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 61657, name = "Fire Nova", rank = "9", bCD = 10000 } )
			table.insert(d, { id = 8050, name = "Flame Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8052, name = "Flame Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8053, name = "Flame Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10447, name = "Flame Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 10448, name = "Flame Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 29228, name = "Flame Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 25457, name = "Flame Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 49232, name = "Flame Shock", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 49233, name = "Flame Shock", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 8056, name = "Frost Shock", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8058, name = "Frost Shock", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 10472, name = "Frost Shock", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 10473, name = "Frost Shock", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25464, name = "Frost Shock", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 49235, name = "Frost Shock", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 49236, name = "Frost Shock", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 8177, name = "Grounding Totem", rank = "", bCD = 15000 } )
			table.insert(d, { id = 32182, name = "Heroism", rank = "", bCD = 300000 } )
			table.insert(d, { id = 51514, name = "Hex", rank = "", bCD = 45000 } )
			table.insert(d, { id = 51505, name = "Lava Burst", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 60043, name = "Lava Burst", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 5730, name = "Stoneclaw Totem", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 6390, name = "Stoneclaw Totem", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 6391, name = "Stoneclaw Totem", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 6392, name = "Stoneclaw Totem", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 10427, name = "Stoneclaw Totem", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 10428, name = "Stoneclaw Totem", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 25525, name = "Stoneclaw Totem", rank = "7", bCD = 30000 } )
			table.insert(d, { id = 58580, name = "Stoneclaw Totem", rank = "8", bCD = 30000 } )
			table.insert(d, { id = 58581, name = "Stoneclaw Totem", rank = "9", bCD = 30000 } )
			table.insert(d, { id = 58582, name = "Stoneclaw Totem", rank = "10", bCD = 30000 } )
			table.insert(d, { id = 57994, name = "Wind Shear", rank = "", bCD = 6000 } )
			
			-- TALENTS
			table.insert(d, { id = 16166, name = "Elemental Mastery", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 51533, name = "Feral Spirit", rank = "", bCD = 180000 } )
			table.insert(d, { id = 60103, name = "Lava Lash", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 16190, name = "Mana Tide Totem", rank = "", bCD = 300000 } )
			table.insert(d, { id = 16188, name = "Nature's Swiftness", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 61295, name = "Riptide", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 61299, name = "Riptide", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 61300, name = "Riptide", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 61301, name = "Riptide", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 30823, name = "Shamanistic Rage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 17364, name = "Stormstrike", rank = "", bCD = 8000 } )
			table.insert(d, { id = 51490, name = "Thunderstorm", rank = "1", bCD = 45000 } )
			table.insert(d, { id = 59156, name = "Thunderstorm", rank = "2", bCD = 45000 } )
			table.insert(d, { id = 59158, name = "Thunderstorm", rank = "3", bCD = 45000 } )
			table.insert(d, { id = 59159, name = "Thunderstorm", rank = "4", bCD = 45000 } )
			table.insert(d, { id = 55198, name = "Tidal Force", rank = "", bCD = 180000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 16188, name = "Ancestral Swiftness", rank = "", bCD = 90000, oaf = true } )
			
		-- RETAIL
		else
			table.insert(d, { id = 443454, name = "Ancestral Swiftness", rank = "", bCD = 30000, oaf = true } )
			table.insert(d, { id = 378081, name = "Nature's Swiftness", rank = "", bCD = 60000, oaf = true } )
		end
	end
	
	-- Warlock
	if class == "WARLOCK" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 603, name = "Curse of Doom", rank = "", bCD = 60000 } )
			table.insert(d, { id = 6789, name = "Death Coil", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17925, name = "Death Coil", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 17926, name = "Death Coil", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 5484, name = "Howl of Terror", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 17928, name = "Howl of Terror", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 1122, name = "Inferno", rank = "", bCD = 3600000 } )
			table.insert(d, { id = 18540, name = "Ritual of Doom", rank = "", bCD = 3600000, oaf = true } )
			table.insert(d, { id = 6229, name = "Shadow Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 11739, name = "Shadow Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 11740, name = "Shadow Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 28610, name = "Shadow Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 6353, name = "Soul Fire", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 17924, name = "Soul Fire", rank = "2", bCD = 60000 } )
			
			-- TALENTS
			table.insert(d, { id = 18288, name = "Amplify Curse", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 17962, name = "Conflagrate", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 18930, name = "Conflagrate", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 18931, name = "Conflagrate", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 18932, name = "Conflagrate", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 18708, name = "Fel Domination", rank = "", bCD = 900000 } )
			table.insert(d, { id = 17877, name = "Shadowburn", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 18867, name = "Shadowburn", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 18868, name = "Shadowburn", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 18869, name = "Shadowburn", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 18870, name = "Shadowburn", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 18871, name = "Shadowburn", rank = "6", bCD = 15000 } )
			
			-- RUNES
			table.insert(d, { id = 403629, name = "Chaos Bolt", rank = "", bCD = 12000 } )
			table.insert(d, { id = 412788, name = "Demon Charge", rank = "", bCD = 15000 } )
			table.insert(d, { id = 425463, name = "Demonic Grace", rank = "", bCD = 20000 } )
			table.insert(d, { id = 412789, name = "Demonic Howl", rank = "", bCD = 600000 } )
			table.insert(d, { id = 403685, name = "Drain Life", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 403677, name = "Drain Life", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 403689, name = "Drain Life", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 403687, name = "Drain Life", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 403686, name = "Drain Life", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 403688, name = "Drain Life", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 403501, name = "Haunt", rank = "", bCD = 12000 } )
			table.insert(d, { id = 403828, name = "Menace", rank = "", bCD = 10000 } )
			table.insert(d, { id = 403835, name = "Shadow Cleave", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 403839, name = "Shadow Cleave", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 403840, name = "Shadow Cleave", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 403841, name = "Shadow Cleave", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 403842, name = "Shadow Cleave", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 403843, name = "Shadow Cleave", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 403844, name = "Shadow Cleave", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 403848, name = "Shadow Cleave", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 403851, name = "Shadow Cleave", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 403852, name = "Shadow Cleave", rank = "10", bCD = 6000 } )

			table.insert(d, { id = 437169, name = "Portal of Summoning", rank = "", bCD = 120000 } )
			table.insert(d, { id = 426320, name = "Shadowflame", rank = "", bCD = 0 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 603, name = "Curse of Doom", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 30910, name = "Curse of Doom", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 6789, name = "Death Coil", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17925, name = "Death Coil", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 17926, name = "Death Coil", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 27223, name = "Death Coil", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 5484, name = "Howl of Terror", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 17928, name = "Howl of Terror", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 1122, name = "Inferno", rank = "", bCD = 3600000 } )
			table.insert(d, { id = 18540, name = "Ritual of Doom", rank = "", bCD = 3600000, oaf = true } )
			table.insert(d, { id = 29893, name = "Ritual of Souls", rank = "1", bCD = 300000, oaf = true } )
			table.insert(d, { id = 6229, name = "Shadow Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 11739, name = "Shadow Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 11740, name = "Shadow Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 28610, name = "Shadow Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 6353, name = "Soul Fire", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 17924, name = "Soul Fire", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 27211, name = "Soul Fire", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 30545, name = "Soul Fire", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 29858, name = "Soulshatter", rank = "", bCD = 300000 } )
			
			-- TALENTS
			table.insert(d, { id = 18288, name = "Amplify Curse", rank = "", bCD = 180000, oaf = true } )
			table.insert(d, { id = 17962, name = "Conflagrate", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 18930, name = "Conflagrate", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 18931, name = "Conflagrate", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 18932, name = "Conflagrate", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 27266, name = "Conflagrate", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 30912, name = "Conflagrate", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 18708, name = "Fel Domination", rank = "", bCD = 900000 } )
			table.insert(d, { id = 17877, name = "Shadowburn", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 18867, name = "Shadowburn", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 18868, name = "Shadowburn", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 18869, name = "Shadowburn", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 18870, name = "Shadowburn", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 18871, name = "Shadowburn", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 27263, name = "Shadowburn", rank = "7", bCD = 15000 } )
			table.insert(d, { id = 30546, name = "Shadowburn", rank = "8", bCD = 15000 } )
			table.insert(d, { id = 30283, name = "Shadowfury", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 30413, name = "Shadowfury", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 30414, name = "Shadowfury", rank = "3", bCD = 20000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 59671, name = "Challenging Howl", rank = "", bCD = 15000 } )
			table.insert(d, { id = 603, name = "Curse of Doom", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 30910, name = "Curse of Doom", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 47867, name = "Curse of Doom", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 6789, name = "Death Coil", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17925, name = "Death Coil", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 17926, name = "Death Coil", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 27223, name = "Death Coil", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 47859, name = "Death Coil", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 47860, name = "Death Coil", rank = "6", bCD = 120000 } )
			table.insert(d, { id = 48020, name = "Demonic Circle: Teleport", rank = "", bCD = 30000 } )
			table.insert(d, { id = 5484, name = "Howl of Terror", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 17928, name = "Howl of Terror", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 50589, name = "Immolation Aura", rank = "", bCD = 30000 } )
			table.insert(d, { id = 1122, name = "Inferno", rank = "", bCD = 600000 } )
			table.insert(d, { id = 18540, name = "Ritual of Doom", rank = "", bCD = 1800000, oaf = true } )
			table.insert(d, { id = 29893, name = "Ritual of Souls", rank = "1", bCD = 300000, oaf = true } )
			table.insert(d, { id = 58887, name = "Ritual of Souls", rank = "2", bCD = 300000, oaf = true } )
			table.insert(d, { id = 698, name = "Ritual of Summoning", rank = "", bCD = 120000 } )
			table.insert(d, { id = 50581, name = "Shadow Cleave", rank = "", bCD = 6000 } )
			table.insert(d, { id = 6229, name = "Shadow Ward", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 11739, name = "Shadow Ward", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 11740, name = "Shadow Ward", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 28610, name = "Shadow Ward", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 47890, name = "Shadow Ward", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 47891, name = "Shadow Ward", rank = "6", bCD = 30000 } )
			table.insert(d, { id = 47897, name = "Shadowflame", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 61290, name = "Shadowflame", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 29858, name = "Soulshatter", rank = "", bCD = 180000 } )
			
			-- TALENTS
			table.insert(d, { id = 50796, name = "Chaos Bolt", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 59170, name = "Chaos Bolt", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 59171, name = "Chaos Bolt", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 59172, name = "Chaos Bolt", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 17962, name = "Conflagrate", rank = "", bCD = 10000 } )
			table.insert(d, { id = 47193, name = "Demonic Empowerment", rank = "", bCD = 60000 } )
			table.insert(d, { id = 18708, name = "Fel Domination", rank = "", bCD = 180000 } )
			table.insert(d, { id = 48181, name = "Haunt", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 59161, name = "Haunt", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 59163, name = "Haunt", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 59164, name = "Haunt", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 47241, name = "Metamorphosis", rank = "", bCD = 180000 } )
			table.insert(d, { id = 17877, name = "Shadowburn", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 18867, name = "Shadowburn", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 18868, name = "Shadowburn", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 18869, name = "Shadowburn", rank = "4", bCD = 15000 } )
			table.insert(d, { id = 18870, name = "Shadowburn", rank = "5", bCD = 15000 } )
			table.insert(d, { id = 18871, name = "Shadowburn", rank = "6", bCD = 15000 } )
			table.insert(d, { id = 27263, name = "Shadowburn", rank = "7", bCD = 15000 } )
			table.insert(d, { id = 30546, name = "Shadowburn", rank = "8", bCD = 15000 } )
			table.insert(d, { id = 47826, name = "Shadowburn", rank = "9", bCD = 15000 } )
			table.insert(d, { id = 47827, name = "Shadowburn", rank = "10", bCD = 15000 } )
			table.insert(d, { id = 30283, name = "Shadowfury", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 30413, name = "Shadowfury", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 30414, name = "Shadowfury", rank = "3", bCD = 20000 } )
			table.insert(d, { id = 47846, name = "Shadowfury", rank = "4", bCD = 20000 } )
			table.insert(d, { id = 47847, name = "Shadowfury", rank = "5", bCD = 20000 } )
			
		-- RETAIL (MoP has none)
		elseif CDTL3.tocversion >= 60000 then
			table.insert(d, { id = 328774, name = "Amplify Curse", rank = "", bCD = 60000, oaf = true } )
		end
	end
	
	-- Warrior
	if class == "WARRIOR" then		
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			-- SPELLS
			table.insert(d, { id = 2457, name = "Battle Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 18499, name = "Berserker Rage", rank = "", bCD = 30000 } )
			table.insert(d, { id = 2458, name = "Berserker Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 2687, name = "Bloodrage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 1161, name = "Challenging Shout", rank = "", bCD = 600000 } )
			table.insert(d, { id = 100, name = "Charge", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 6178, name = "Charge", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 11578, name = "Charge", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 71, name = "Defensive Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 676, name = "Disarm", rank = "", bCD = 60000 } )
			table.insert(d, { id = 20252, name = "Intercept", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 20616, name = "Intercept", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 20617, name = "Intercept", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 5246, name = "Intimidating Shout", rank = "", bCD = 180000 } )
			table.insert(d, { id = 694, name = "Mocking Blow", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 7400, name = "Mocking Blow", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 7402, name = "Mocking Blow", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 20559, name = "Mocking Blow", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 20560, name = "Mocking Blow", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 7384, name = "Overpower", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 7887, name = "Overpower", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 11584, name = "Overpower", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 11585, name = "Overpower", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 6552, name = "Pummel", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 6554, name = "Pummel", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 1719, name = "Recklessness", rank = "", bCD = 1800000 } )
			table.insert(d, { id = 20230, name = "Retaliation", rank = "", bCD = 1800000 } )
			table.insert(d, { id = 6572, name = "Revenge", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 6574, name = "Revenge", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 7379, name = "Revenge", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 11600, name = "Revenge", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 11601, name = "Revenge", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 25288, name = "Revenge", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 72, name = "Shield Bash", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 1671, name = "Shield Bash", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 1672, name = "Shield Bash", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 2565, name = "Shield Block", rank = "", bCD = 5000 } )
			table.insert(d, { id = 871, name = "Shield Wall", rank = "", bCD = 1800000 } )
			table.insert(d, { id = 355, name = "Taunt", rank = "", bCD = 10000 } )
			table.insert(d, { id = 6343, name = "Thunder Clap", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 8198, name = "Thunder Clap", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 8204, name = "Thunder Clap", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 8205, name = "Thunder Clap", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 11580, name = "Thunder Clap", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 11581, name = "Thunder Clap", rank = "6", bCD = 4000 } )
			table.insert(d, { id = 1680, name = "Whirlwind", rank = "", bCD = 10000 } )
			
			-- TALENTS
			table.insert(d, { id = 23881, name = "Bloodthirst", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 23892, name = "Bloodthirst", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 23893, name = "Bloodthirst", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 23894, name = "Bloodthirst", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 12809, name = "Concussion Blow", rank = "", bCD = 45000 } )
			table.insert(d, { id = 12328, name = "Death Wish", rank = "", bCD = 180000 } )
			table.insert(d, { id = 12975, name = "Last Stand", rank = "", bCD = 600000 } )
			table.insert(d, { id = 12294, name = "Mortal Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 21551, name = "Mortal Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 21552, name = "Mortal Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 21553, name = "Mortal Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 23922, name = "Shield Slam", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 23923, name = "Shield Slam", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 23924, name = "Shield Slam", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 23925, name = "Shield Slam", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 12292, name = "Sweeping Strikes", rank = "", bCD = 30000 } )
			
			-- RUNES
			table.insert(d, { id = 402911, name = "Raging Blow", rank = "", bCD = 8000 } )
			table.insert(d, { id = 402927, name = "Victory Rush", rank = "", bCD = 8000 } )

			table.insert(d, { id = 402913, name = "Enraged Regeneration", rank = "", bCD = 180000 } )
			table.insert(d, { id = 403338, name = "Intervene", rank = "", bCD = 30000 } )
			table.insert(d, { id = 426490, name = "Rallying Cry", rank = "", bCD = 180000 } )

		-- TBC
		elseif CDTL3.tocversion < 30000 then
			-- SPELLS
			table.insert(d, { id = 2457, name = "Battle Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 18499, name = "Berserker Rage", rank = "", bCD = 30000 } )
			table.insert(d, { id = 2458, name = "Berserker Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 2687, name = "Bloodrage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 1161, name = "Challenging Shout", rank = "", bCD = 600000 } )
			table.insert(d, { id = 100, name = "Charge", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 6178, name = "Charge", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 11578, name = "Charge", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 71, name = "Defensive Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 676, name = "Disarm", rank = "", bCD = 60000 } )
			table.insert(d, { id = 20252, name = "Intercept", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 20616, name = "Intercept", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 20617, name = "Intercept", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 25272, name = "Intercept", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 25275, name = "Intercept", rank = "5", bCD = 30000 } )
			table.insert(d, { id = 3411, name = "Intervene", rank = "", bCD = 30000 } )
			table.insert(d, { id = 5246, name = "Intimidating Shout", rank = "", bCD = 180000 } )
			table.insert(d, { id = 694, name = "Mocking Blow", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 7400, name = "Mocking Blow", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 7402, name = "Mocking Blow", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 20559, name = "Mocking Blow", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 20560, name = "Mocking Blow", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 25266, name = "Mocking Blow", rank = "6", bCD = 120000 } )
			table.insert(d, { id = 7384, name = "Overpower", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 7887, name = "Overpower", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 11584, name = "Overpower", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 11585, name = "Overpower", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 6552, name = "Pummel", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 6554, name = "Pummel", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 1719, name = "Recklessness", rank = "", bCD = 1800000 } )
			table.insert(d, { id = 20230, name = "Retaliation", rank = "", bCD = 1800000 } )
			table.insert(d, { id = 6572, name = "Revenge", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 6574, name = "Revenge", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 7379, name = "Revenge", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 11600, name = "Revenge", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 11601, name = "Revenge", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 25288, name = "Revenge", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 25269, name = "Revenge", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 30357, name = "Revenge", rank = "8", bCD = 5000 } )
			table.insert(d, { id = 72, name = "Shield Bash", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 1671, name = "Shield Bash", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 1672, name = "Shield Bash", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 29704, name = "Shield Bash", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 2565, name = "Shield Block", rank = "", bCD = 5000 } )
			table.insert(d, { id = 871, name = "Shield Wall", rank = "", bCD = 1800000 } )
			table.insert(d, { id = 23920, name = "Spell Reflection", rank = "", bCD = 10000 } )
			table.insert(d, { id = 355, name = "Taunt", rank = "", bCD = 10000 } )
			table.insert(d, { id = 6343, name = "Thunder Clap", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 8198, name = "Thunder Clap", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 8204, name = "Thunder Clap", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 8205, name = "Thunder Clap", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 11580, name = "Thunder Clap", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 11581, name = "Thunder Clap", rank = "6", bCD = 4000 } )
			table.insert(d, { id = 25264, name = "Thunder Clap", rank = "7", bCD = 4000 } )
			table.insert(d, { id = 1680, name = "Whirlwind", rank = "", bCD = 10000 } )
			
			-- TALENTS
			table.insert(d, { id = 23881, name = "Bloodthirst", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 23892, name = "Bloodthirst", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 23893, name = "Bloodthirst", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 23894, name = "Bloodthirst", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25251, name = "Bloodthirst", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 30335, name = "Bloodthirst", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 12809, name = "Concussion Blow", rank = "", bCD = 45000 } )
			table.insert(d, { id = 12292, name = "Death Wish", rank = "", bCD = 180000 } )
			table.insert(d, { id = 12975, name = "Last Stand", rank = "", bCD = 480000 } )
			table.insert(d, { id = 12294, name = "Mortal Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 21551, name = "Mortal Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 21552, name = "Mortal Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 21553, name = "Mortal Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25248, name = "Mortal Strike", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 30330, name = "Mortal Strike", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 23922, name = "Shield Slam", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 23923, name = "Shield Slam", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 23924, name = "Shield Slam", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 23925, name = "Shield Slam", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25258, name = "Shield Slam", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 30356, name = "Shield Slam", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 12328, name = "Sweeping Strikes", rank = "", bCD = 30000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			-- SPELLS
			table.insert(d, { id = 2457, name = "Battle Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 18499, name = "Berserker Rage", rank = "", bCD = 30000 } )
			table.insert(d, { id = 2458, name = "Berserker Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 2687, name = "Bloodrage", rank = "", bCD = 60000 } )
			table.insert(d, { id = 1161, name = "Challenging Shout", rank = "", bCD = 180000 } )
			table.insert(d, { id = 100, name = "Charge", rank = "1", bCD = 15000 } )
			table.insert(d, { id = 6178, name = "Charge", rank = "2", bCD = 15000 } )
			table.insert(d, { id = 11578, name = "Charge", rank = "3", bCD = 15000 } )
			table.insert(d, { id = 71, name = "Defensive Stance", rank = "", bCD = 1000 } )
			table.insert(d, { id = 676, name = "Disarm", rank = "", bCD = 60000 } )
			table.insert(d, { id = 55694, name = "Enraged Regeneration", rank = "", bCD = 180000 } )
			table.insert(d, { id = 57755, name = "Heroic Throw", rank = "", bCD = 60000 } )
			table.insert(d, { id = 20252, name = "Intercept", rank = "", bCD = 30000 } )
			table.insert(d, { id = 3411, name = "Intervene", rank = "", bCD = 30000 } )
			table.insert(d, { id = 5246, name = "Intimidating Shout", rank = "", bCD = 120000 } )
			table.insert(d, { id = 694, name = "Mocking Blow", rank = "", bCD = 60000 } )
			table.insert(d, { id = 7384, name = "Overpower", rank = "", bCD = 5000 } )
			table.insert(d, { id = 6552, name = "Pummel", rank = "", bCD = 10000 } )
			table.insert(d, { id = 1719, name = "Recklessness", rank = "", bCD = 300000 } )
			table.insert(d, { id = 20230, name = "Retaliation", rank = "", bCD = 300000 } )
			table.insert(d, { id = 6572, name = "Revenge", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 6574, name = "Revenge", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 7379, name = "Revenge", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 11600, name = "Revenge", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 11601, name = "Revenge", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 25288, name = "Revenge", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 25269, name = "Revenge", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 30357, name = "Revenge", rank = "8", bCD = 5000 } )
			table.insert(d, { id = 57823, name = "Revenge", rank = "9", bCD = 5000 } )
			table.insert(d, { id = 64382, name = "Shattering Throw", rank = "", bCD = 300000 } )
			table.insert(d, { id = 72, name = "Shield Bash", rank = "", bCD = 12000 } )
			table.insert(d, { id = 2565, name = "Shield Block", rank = "", bCD = 60000 } )
			table.insert(d, { id = 23922, name = "Shield Slam", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 23923, name = "Shield Slam", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 23924, name = "Shield Slam", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 23925, name = "Shield Slam", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25258, name = "Shield Slam", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 30356, name = "Shield Slam", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 47487, name = "Shield Slam", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 47488, name = "Shield Slam", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 871, name = "Shield Wall", rank = "", bCD = 300000 } )
			table.insert(d, { id = 23920, name = "Spell Reflection", rank = "", bCD = 10000 } )
			table.insert(d, { id = 355, name = "Taunt", rank = "", bCD = 8000 } )
			table.insert(d, { id = 6343, name = "Thunder Clap", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 8198, name = "Thunder Clap", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 8204, name = "Thunder Clap", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 8205, name = "Thunder Clap", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 11580, name = "Thunder Clap", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 11581, name = "Thunder Clap", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 25264, name = "Thunder Clap", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 47501, name = "Thunder Clap", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 47502, name = "Thunder Clap", rank = "9", bCD = 6000 } )
			table.insert(d, { id = 1680, name = "Whirlwind", rank = "", bCD = 10000 } )
			
			-- TALENTS
			table.insert(d, { id = 46924, name = "Bladestorm", rank = "", bCD = 90000 } )
			table.insert(d, { id = 23881, name = "Bloodthirst", rank = "", bCD = 4000 } )
			table.insert(d, { id = 12809, name = "Concussion Blow", rank = "", bCD = 30000 } )
			table.insert(d, { id = 12292, name = "Death Wish", rank = "", bCD = 180000 } )
			table.insert(d, { id = 60970, name = "Heroic Fury", rank = "", bCD = 45000 } )
			table.insert(d, { id = 12975, name = "Last Stand", rank = "", bCD = 180000 } )
			table.insert(d, { id = 12294, name = "Mortal Strike", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 21551, name = "Mortal Strike", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 21552, name = "Mortal Strike", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 21553, name = "Mortal Strike", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 25248, name = "Mortal Strike", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 30330, name = "Mortal Strike", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 47485, name = "Mortal Strike", rank = "7", bCD = 6000 } )
			table.insert(d, { id = 47486, name = "Mortal Strike", rank = "8", bCD = 6000 } )
			table.insert(d, { id = 46968, name = "Shockwave", rank = "", bCD = 20000 } )
			table.insert(d, { id = 12328, name = "Sweeping Strikes", rank = "", bCD = 30000 } )
		end
	end
	
	return d
end

-- PET SPELLS
private.GetPetData = function(class)
	--local _, _, _, tocversion = GetBuildInfo()
	local d = {}
	
	-- Death Knight
	if class == "DEATHKNIGHT" then			
		-- WOTLK
		if CDTL3.tocversion < 40000 then
			table.insert(d, { id = 47481, name = "Gnaw", rank = "", bCD = 60000 } )
			table.insert(d, { id = 47484, name = "Huddle", rank = "", bCD = 45000 } )
			table.insert(d, { id = 47482, name = "Leap", rank = "", bCD = 20000 } )
		end
	end
	
	-- Hunter
	if class == "HUNTER" then
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			table.insert(d, { id = 17253, name = "Bite", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 17255, name = "Bite", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 17256, name = "Bite", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 17257, name = "Bite", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 17258, name = "Bite", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 17259, name = "Bite", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 17260, name = "Bite", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 17261, name = "Bite", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 7371, name = "Charge", rank = "1", bCD = 25000 } )
			table.insert(d, { id = 26177, name = "Charge", rank = "2", bCD = 25000 } )
			table.insert(d, { id = 26178, name = "Charge", rank = "3", bCD = 25000 } )
			table.insert(d, { id = 26179, name = "Charge", rank = "4", bCD = 25000 } )
			table.insert(d, { id = 26201, name = "Charge", rank = "5", bCD = 25000 } )
			table.insert(d, { id = 27685, name = "Charge", rank = "6", bCD = 25000 } )
			table.insert(d, { id = 1742, name = "Cower", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 1753, name = "Cower", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 1754, name = "Cower", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 1755, name = "Cower", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 1756, name = "Cower", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 16697, name = "Cower", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 23099, name = "Dash", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 23109, name = "Dash", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 23110, name = "Dash", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 23145, name = "Dive", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 23147, name = "Dive", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 23148, name = "Dive", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 24604, name = "Furious Howl", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 24605, name = "Furious Howl", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 24603, name = "Furious Howl", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 24597, name = "Furious Howl", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 2649, name = "Growl", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14916, name = "Growl", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14917, name = "Growl", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 14918, name = "Growl", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 14919, name = "Growl", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 14920, name = "Growl", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 14921, name = "Growl", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 24450, name = "Prowl", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24452, name = "Prowl", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24453, name = "Prowl", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24640, name = "Scorpid Poison", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 24583, name = "Scorpid Poison", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 24586, name = "Scorpid Poison", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 24587, name = "Scorpid Poison", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 26064, name = "Shell Shield", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 26090, name = "Thunderstomp", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 26187, name = "Thunderstomp", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 26188, name = "Thunderstomp", rank = "3", bCD = 60000 } )
			
		-- TBC
		elseif CDTL3.tocversion < 30000 then
			table.insert(d, { id = 17253, name = "Bite", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 17255, name = "Bite", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 17256, name = "Bite", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 17257, name = "Bite", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 17258, name = "Bite", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 17259, name = "Bite", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 17260, name = "Bite", rank = "7", bCD = 10000 } )
			table.insert(d, { id = 17261, name = "Bite", rank = "8", bCD = 10000 } )
			table.insert(d, { id = 27050, name = "Bite", rank = "9", bCD = 10000 } )
			table.insert(d, { id = 7371, name = "Charge", rank = "1", bCD = 25000 } )
			table.insert(d, { id = 26177, name = "Charge", rank = "2", bCD = 25000 } )
			table.insert(d, { id = 26178, name = "Charge", rank = "3", bCD = 25000 } )
			table.insert(d, { id = 26179, name = "Charge", rank = "4", bCD = 25000 } )
			table.insert(d, { id = 26201, name = "Charge", rank = "5", bCD = 25000 } )
			table.insert(d, { id = 27685, name = "Charge", rank = "6", bCD = 25000 } )
			table.insert(d, { id = 1742, name = "Cower", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 1753, name = "Cower", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 1754, name = "Cower", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 1755, name = "Cower", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 1756, name = "Cower", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 16697, name = "Cower", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 27048, name = "Cower", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 23099, name = "Dash", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 23109, name = "Dash", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 23110, name = "Dash", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 23145, name = "Dive", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 23147, name = "Dive", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 23148, name = "Dive", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 34889, name = "Fire Breath", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 35323, name = "Fire Breath", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 24604, name = "Furious Howl", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 24605, name = "Furious Howl", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 24603, name = "Furious Howl", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 24597, name = "Furious Howl", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 2649, name = "Growl", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14916, name = "Growl", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14917, name = "Growl", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 14918, name = "Growl", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 14919, name = "Growl", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 14920, name = "Growl", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 14921, name = "Growl", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 27047, name = "Growl", rank = "8", bCD = 5000 } )
			table.insert(d, { id = 35387, name = "Poison Spit", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 35389, name = "Poison Spit", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 35392, name = "Poison Spit", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 24450, name = "Prowl", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24452, name = "Prowl", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24453, name = "Prowl", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24640, name = "Scorpid Poison", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 24583, name = "Scorpid Poison", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 24586, name = "Scorpid Poison", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 24587, name = "Scorpid Poison", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 27060, name = "Scorpid Poison", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 26064, name = "Shell Shield", rank = "1", bCD = 180000 } )
			table.insert(d, { id = 26090, name = "Thunderstomp", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 26187, name = "Thunderstomp", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 26188, name = "Thunderstomp", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 27063, name = "Thunderstomp", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 35346, name = "Warp", rank = "", bCD = 15000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			table.insert(d, { id = 55749, name = "Acid Spit", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 55750, name = "Acid Spit", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 55751, name = "Acid Spit", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 55752, name = "Acid Spit", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 55753, name = "Acid Spit", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55754, name = "Acid Spit", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 50433, name = "Bad Attitude", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 52395, name = "Bad Attitude", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 52396, name = "Bad Attitude", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 52397, name = "Bad Attitude", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 52398, name = "Bad Attitude", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 52399, name = "Bad Attitude", rank = "6", bCD = 120000 } )
			table.insert(d, { id = 53490, name = "Bullheaded", rank = "", bCD = 180000 } )
			table.insert(d, { id = 53434, name = "Call of the Wild", rank = "", bCD = 300000 } )
			table.insert(d, { id = 54044, name = "Carrion Feeder", rank = "", bCD = 30000 } )
			table.insert(d, { id = 61685, name = "Charge", rank = "", bCD = 25000 } )
			table.insert(d, { id = 1742, name = "Cower", rank = "", bCD = 45000 } )
			table.insert(d, { id = 61684, name = "Dash", rank = "", bCD = 32000 } )
			table.insert(d, { id = 24423, name = "Demoralizing Screech", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 24577, name = "Demoralizing Screech", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 24578, name = "Demoralizing Screech", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 24579, name = "Demoralizing Screech", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 27051, name = "Demoralizing Screech", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55487, name = "Demoralizing Screech", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 23145, name = "Dive", rank = "", bCD = 32000 } )
			table.insert(d, { id = 50285, name = "Dust Cloud", rank = "", bCD = 40000 } )
			table.insert(d, { id = 34889, name = "Fire Breath", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 35323, name = "Fire Breath", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 55482, name = "Fire Breath", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 55483, name = "Fire Breath", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 55484, name = "Fire Breath", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55485, name = "Fire Breath", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 54644, name = "Froststorm Breath", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 55488, name = "Froststorm Breath", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 55489, name = "Froststorm Breath", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 55490, name = "Froststorm Breath", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 55491, name = "Froststorm Breath", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55492, name = "Froststorm Breath", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 24604, name = "Furious Howl", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 64491, name = "Furious Howl", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 64492, name = "Furious Howl", rank = "3", bCD = 40000 } )
			table.insert(d, { id = 64493, name = "Furious Howl", rank = "4", bCD = 40000 } )
			table.insert(d, { id = 64494, name = "Furious Howl", rank = "5", bCD = 40000 } )
			table.insert(d, { id = 64495, name = "Furious Howl", rank = "6", bCD = 40000 } )
			table.insert(d, { id = 35290, name = "Gore", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 35291, name = "Gore", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 35292, name = "Gore", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 35293, name = "Gore", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 35294, name = "Gore", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 35295, name = "Gore", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 2649, name = "Growl", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 14916, name = "Growl", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 14917, name = "Growl", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 14918, name = "Growl", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 14919, name = "Growl", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 14920, name = "Growl", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 14921, name = "Growl", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 27047, name = "Growl", rank = "8", bCD = 5000 } )
			table.insert(d, { id = 61676, name = "Growl", rank = "9", bCD = 5000 } )
			table.insert(d, { id = 55709, name = "Heart of the Phoenix", rank = "", bCD = 480000 } )
			table.insert(d, { id = 53476, name = "Intervene", rank = "", bCD = 30000 } )
			table.insert(d, { id = 53478, name = "Last Stand", rank = "", bCD = 360000 } )
			table.insert(d, { id = 58604, name = "Lava Breath", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 58607, name = "Lava Breath", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 58608, name = "Lava Breath", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 58609, name = "Lava Breath", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 58610, name = "Lava Breath", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 58611, name = "Lava Breath", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 53426, name = "Lick Your Wounds", rank = "", bCD = 180000 } )
			table.insert(d, { id = 24844, name = "Lightning Breath", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 25008, name = "Lightning Breath", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 25009, name = "Lightning Breath", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 25010, name = "Lightning Breath", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 25011, name = "Lightning Breath", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 25012, name = "Lightning Breath", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 54680, name = "Monstrous Bite", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 55495, name = "Monstrous Bite", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 55496, name = "Monstrous Bite", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 55497, name = "Monstrous Bite", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 55498, name = "Monstrous Bite", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55499, name = "Monstrous Bite", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 50479, name = "Nether Shock", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 53584, name = "Nether Shock", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 53586, name = "Nether Shock", rank = "3", bCD = 40000 } )
			table.insert(d, { id = 53587, name = "Nether Shock", rank = "4", bCD = 40000 } )
			table.insert(d, { id = 53588, name = "Nether Shock", rank = "5", bCD = 40000 } )
			table.insert(d, { id = 53589, name = "Nether Shock", rank = "6", bCD = 40000 } )
			table.insert(d, { id = 50245, name = "Pin", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 53544, name = "Pin", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 53545, name = "Pin", rank = "3", bCD = 40000 } )
			table.insert(d, { id = 53546, name = "Pin", rank = "4", bCD = 40000 } )
			table.insert(d, { id = 53547, name = "Pin", rank = "5", bCD = 40000 } )
			table.insert(d, { id = 53548, name = "Pin", rank = "6", bCD = 40000 } )
			table.insert(d, { id = 35387, name = "Poison Spit", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 35389, name = "Poison Spit", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 35392, name = "Poison Spit", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 55555, name = "Poison Spit", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 55556, name = "Poison Spit", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55557, name = "Poison Spit", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 24450, name = "Prowl", rank = "1", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24452, name = "Prowl", rank = "2", bCD = 10000, oaf = true } )
			table.insert(d, { id = 24453, name = "Prowl", rank = "3", bCD = 10000, oaf = true } )
			table.insert(d, { id = 26090, name = "Pummel", rank = "", bCD = 30000 } )
			table.insert(d, { id = 53401, name = "Rabid", rank = "", bCD = 45000 } )
			table.insert(d, { id = 59881, name = "Rake", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 59882, name = "Rake", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 59883, name = "Rake", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 59884, name = "Rake", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 59885, name = "Rake", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 59886, name = "Rake", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 50518, name = "Ravage", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 53558, name = "Ravage", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 53559, name = "Ravage", rank = "3", bCD = 40000 } )
			table.insert(d, { id = 53560, name = "Ravage", rank = "4", bCD = 40000 } )
			table.insert(d, { id = 53561, name = "Ravage", rank = "5", bCD = 40000 } )
			table.insert(d, { id = 53562, name = "Ravage", rank = "6", bCD = 40000 } )
			table.insert(d, { id = 53517, name = "Roar of Recovery", rank = "", bCD = 180000 } )
			table.insert(d, { id = 53480, name = "Roar of Sacrifice", rank = "", bCD = 60000 } )
			table.insert(d, { id = 50498, name = "Savage Rend", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 53578, name = "Savage Rend", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 53579, name = "Savage Rend", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 53580, name = "Savage Rend", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 53581, name = "Savage Rend", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 53582, name = "Savage Rend", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 24640, name = "Scorpid Poison", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 24583, name = "Scorpid Poison", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 24586, name = "Scorpid Poison", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 24587, name = "Scorpid Poison", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 27060, name = "Scorpid Poison", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 55728, name = "Scorpid Poison", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 50318, name = "Serenity Dust", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 52012, name = "Serenity Dust", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 52013, name = "Serenity Dust", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 52014, name = "Serenity Dust", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 52015, name = "Serenity Dust", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 52016, name = "Serenity Dust", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 26064, name = "Shell Shield", rank = "", bCD = 60000 } )
			table.insert(d, { id = 50541, name = "Snatch", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 53537, name = "Snatch", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 53538, name = "Snatch", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 53540, name = "Snatch", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 53542, name = "Snatch", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 53543, name = "Snatch", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 50519, name = "Sonic Blast", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 53564, name = "Sonic Blast", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 53565, name = "Sonic Blast", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 53566, name = "Sonic Blast", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 53567, name = "Sonic Blast", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 53568, name = "Sonic Blast", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 61193, name = "Spirit Strike", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 61194, name = "Spirit Strike", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 61195, name = "Spirit Strike", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 61196, name = "Spirit Strike", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 61197, name = "Spirit Strike", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 61198, name = "Spirit Strike", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 50274, name = "Spore Cloud", rank = "1", bCD = 10000 } )
			table.insert(d, { id = 53593, name = "Spore Cloud", rank = "2", bCD = 10000 } )
			table.insert(d, { id = 53594, name = "Spore Cloud", rank = "3", bCD = 10000 } )
			table.insert(d, { id = 53596, name = "Spore Cloud", rank = "4", bCD = 10000 } )
			table.insert(d, { id = 53597, name = "Spore Cloud", rank = "5", bCD = 10000 } )
			table.insert(d, { id = 53598, name = "Spore Cloud", rank = "6", bCD = 10000 } )
			table.insert(d, { id = 57386, name = "Stampede", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 57389, name = "Stampede", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 57390, name = "Stampede", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 57391, name = "Stampede", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 57392, name = "Stampede", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 57393, name = "Stampede", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 56626, name = "Sting", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 56627, name = "Sting", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 56628, name = "Sting", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 56629, name = "Sting", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 56630, name = "Sting", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 56631, name = "Sting", rank = "6", bCD = 6000 } )
			table.insert(d, { id = 50256, name = "Swipe", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 53526, name = "Swipe", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 53528, name = "Swipe", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 53529, name = "Swipe", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 53532, name = "Swipe", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 53533, name = "Swipe", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 52825, name = "Swoop", rank = "", bCD = 25000 } )
			table.insert(d, { id = 53477, name = "Taunt", rank = "", bCD = 180000 } )
			table.insert(d, { id = 50271, name = "Tendon Rip", rank = "1", bCD = 20000 } )
			table.insert(d, { id = 53571, name = "Tendon Rip", rank = "2", bCD = 20000 } )
			table.insert(d, { id = 53572, name = "Tendon Rip", rank = "3", bCD = 20000 } )
			table.insert(d, { id = 53573, name = "Tendon Rip", rank = "4", bCD = 20000 } )
			table.insert(d, { id = 53574, name = "Tendon Rip", rank = "5", bCD = 20000 } )
			table.insert(d, { id = 53575, name = "Tendon Rip", rank = "6", bCD = 20000 } )
			table.insert(d, { id = 63900, name = "Thunderstomp", rank = "", bCD = 10000 } )
			table.insert(d, { id = 54706, name = "Venom Web Spray", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 55505, name = "Venom Web Spray", rank = "2", bCD = 40000 } )
			table.insert(d, { id = 55506, name = "Venom Web Spray", rank = "3", bCD = 40000 } )
			table.insert(d, { id = 55507, name = "Venom Web Spray", rank = "4", bCD = 40000 } )
			table.insert(d, { id = 55508, name = "Venom Web Spray", rank = "5", bCD = 40000 } )
			table.insert(d, { id = 55509, name = "Venom Web Spray", rank = "6", bCD = 40000 } )
			table.insert(d, { id = 35346, name = "Warp", rank = "", bCD = 15000 } )
			table.insert(d, { id = 4167, name = "Web", rank = "1", bCD = 40000 } )
			table.insert(d, { id = 53508, name = "Wolverine Bite", rank = "", bCD = 10000 } )
			
		-- MOP
		elseif CDTL3.tocversion < 60000 then
			table.insert(d, { id = 24450, name = "Prowl", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 90328, name = "Spirit Walk", rank = "", bCD = 10000, oaf = true } )
			
		-- RETAIL
		else
			table.insert(d, { id = 24450, name = "Prowl", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 90328, name = "Spirit Walk", rank = "", bCD = 10000, oaf = true } )
		end
	end
	
	-- Warlock
	if class == "WARLOCK" then
		-- CLASSIC
		if CDTL3.tocversion < 20000 then
			table.insert(d, { id = 19505, name = "Devour Magic", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 19731, name = "Devour Magic", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 19734, name = "Devour Magic", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 19736, name = "Devour Magic", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 7814, name = "Lash of Pain", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 7815, name = "Lash of Pain", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 7816, name = "Lash of Pain", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 11778, name = "Lash of Pain", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 11779, name = "Lash of Pain", rank = "5", bCD = 12000 } )
			table.insert(d, { id = 11780, name = "Lash of Pain", rank = "6", bCD = 12000 } )
			table.insert(d, { id = 4511, name = "Phase Shift", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 6360, name = "Soothing Kiss", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 7813, name = "Soothing Kiss", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 11784, name = "Soothing Kiss", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 11785, name = "Soothing Kiss", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 19244, name = "Spell Lock", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 19647, name = "Spell Lock", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 17735, name = "Suffering", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17750, name = "Suffering", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 17751, name = "Suffering", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 17752, name = "Suffering", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 3716, name = "Torment", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 7809, name = "Torment", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 7810, name = "Torment", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 7811, name = "Torment", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 11774, name = "Torment", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 11775, name = "Torment", rank = "6", bCD = 5000 } )
			
		-- TBC
		elseif CDTL3.tocversion < 30000 then
			table.insert(d, { id = 19505, name = "Devour Magic", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 19731, name = "Devour Magic", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 19734, name = "Devour Magic", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 19736, name = "Devour Magic", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 27276, name = "Devour Magic", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 27277, name = "Devour Magic", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 7814, name = "Lash of Pain", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 7815, name = "Lash of Pain", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 7816, name = "Lash of Pain", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 11778, name = "Lash of Pain", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 11779, name = "Lash of Pain", rank = "5", bCD = 12000 } )
			table.insert(d, { id = 11780, name = "Lash of Pain", rank = "6", bCD = 12000 } )
			table.insert(d, { id = 27274, name = "Lash of Pain", rank = "7", bCD = 12000 } )
			table.insert(d, { id = 4511, name = "Phase Shift", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 6360, name = "Soothing Kiss", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 7813, name = "Soothing Kiss", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 11784, name = "Soothing Kiss", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 11785, name = "Soothing Kiss", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 27275, name = "Soothing Kiss", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 19244, name = "Spell Lock", rank = "1", bCD = 24000 } )
			table.insert(d, { id = 19647, name = "Spell Lock", rank = "2", bCD = 24000 } )
			table.insert(d, { id = 17735, name = "Suffering", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17750, name = "Suffering", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 17751, name = "Suffering", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 17752, name = "Suffering", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 27271, name = "Suffering", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 33701, name = "Suffering", rank = "6", bCD = 120000 } )
			table.insert(d, { id = 3716, name = "Torment", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 7809, name = "Torment", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 7810, name = "Torment", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 7811, name = "Torment", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 11774, name = "Torment", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 11775, name = "Torment", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 27270, name = "Torment", rank = "7", bCD = 5000 } )
			
		-- WOTLK
		elseif CDTL3.tocversion < 40000 then
			table.insert(d, { id = 33698, name = "Anguish", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 33699, name = "Anguish", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 33700, name = "Anguish", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 47993, name = "Anguish", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 30213, name = "Cleave", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 30219, name = "Cleave", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 30223, name = "Cleave", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 47994, name = "Cleave", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 19505, name = "Devour Magic", rank = "1", bCD = 8000 } )
			table.insert(d, { id = 19731, name = "Devour Magic", rank = "2", bCD = 8000 } )
			table.insert(d, { id = 19734, name = "Devour Magic", rank = "3", bCD = 8000 } )
			table.insert(d, { id = 19736, name = "Devour Magic", rank = "4", bCD = 8000 } )
			table.insert(d, { id = 27276, name = "Devour Magic", rank = "5", bCD = 8000 } )
			table.insert(d, { id = 27277, name = "Devour Magic", rank = "6", bCD = 8000 } )
			table.insert(d, { id = 48011, name = "Devour Magic", rank = "7", bCD = 8000 } )
			table.insert(d, { id = 30151, name = "Intercept", rank = "1", bCD = 30000 } )
			table.insert(d, { id = 30194, name = "Intercept", rank = "2", bCD = 30000 } )
			table.insert(d, { id = 30198, name = "Intercept", rank = "3", bCD = 30000 } )
			table.insert(d, { id = 47996, name = "Intercept", rank = "4", bCD = 30000 } )
			table.insert(d, { id = 7814, name = "Lash of Pain", rank = "1", bCD = 12000 } )
			table.insert(d, { id = 7815, name = "Lash of Pain", rank = "2", bCD = 12000 } )
			table.insert(d, { id = 7816, name = "Lash of Pain", rank = "3", bCD = 12000 } )
			table.insert(d, { id = 11778, name = "Lash of Pain", rank = "4", bCD = 12000 } )
			table.insert(d, { id = 11779, name = "Lash of Pain", rank = "5", bCD = 12000 } )
			table.insert(d, { id = 11780, name = "Lash of Pain", rank = "6", bCD = 12000 } )
			table.insert(d, { id = 27274, name = "Lash of Pain", rank = "7", bCD = 12000 } )
			table.insert(d, { id = 47991, name = "Lash of Pain", rank = "8", bCD = 12000 } )
			table.insert(d, { id = 47992, name = "Lash of Pain", rank = "9", bCD = 12000 } )
			table.insert(d, { id = 4511, name = "Phase Shift", rank = "", bCD = 10000, oaf = true } )
			table.insert(d, { id = 7812, name = "Sacrifice", rank = "1", bCD = 60000 } )
			table.insert(d, { id = 19438, name = "Sacrifice", rank = "2", bCD = 60000 } )
			table.insert(d, { id = 19440, name = "Sacrifice", rank = "3", bCD = 60000 } )
			table.insert(d, { id = 19441, name = "Sacrifice", rank = "4", bCD = 60000 } )
			table.insert(d, { id = 19442, name = "Sacrifice", rank = "5", bCD = 60000 } )
			table.insert(d, { id = 19443, name = "Sacrifice", rank = "6", bCD = 60000 } )
			table.insert(d, { id = 27273, name = "Sacrifice", rank = "7", bCD = 60000 } )
			table.insert(d, { id = 47985, name = "Sacrifice", rank = "8", bCD = 60000 } )
			table.insert(d, { id = 47986, name = "Sacrifice", rank = "9", bCD = 60000 } )
			table.insert(d, { id = 54049, name = "Shadow Bite", rank = "1", bCD = 6000 } )
			table.insert(d, { id = 54050, name = "Shadow Bite", rank = "2", bCD = 6000 } )
			table.insert(d, { id = 54051, name = "Shadow Bite", rank = "3", bCD = 6000 } )
			table.insert(d, { id = 54052, name = "Shadow Bite", rank = "4", bCD = 6000 } )
			table.insert(d, { id = 54053, name = "Shadow Bite", rank = "5", bCD = 6000 } )
			table.insert(d, { id = 6360, name = "Soothing Kiss", rank = "1", bCD = 4000 } )
			table.insert(d, { id = 7813, name = "Soothing Kiss", rank = "2", bCD = 4000 } )
			table.insert(d, { id = 11784, name = "Soothing Kiss", rank = "3", bCD = 4000 } )
			table.insert(d, { id = 11785, name = "Soothing Kiss", rank = "4", bCD = 4000 } )
			table.insert(d, { id = 27275, name = "Soothing Kiss", rank = "5", bCD = 4000 } )
			table.insert(d, { id = 19244, name = "Spell Lock", rank = "1", bCD = 24000 } )
			table.insert(d, { id = 19647, name = "Spell Lock", rank = "2", bCD = 24000 } )
			table.insert(d, { id = 17735, name = "Suffering", rank = "1", bCD = 120000 } )
			table.insert(d, { id = 17750, name = "Suffering", rank = "2", bCD = 120000 } )
			table.insert(d, { id = 17751, name = "Suffering", rank = "3", bCD = 120000 } )
			table.insert(d, { id = 17752, name = "Suffering", rank = "4", bCD = 120000 } )
			table.insert(d, { id = 27271, name = "Suffering", rank = "5", bCD = 120000 } )
			table.insert(d, { id = 33701, name = "Suffering", rank = "6", bCD = 120000 } )
			table.insert(d, { id = 47989, name = "Suffering", rank = "7", bCD = 120000 } )
			table.insert(d, { id = 47990, name = "Suffering", rank = "8", bCD = 120000 } )
			table.insert(d, { id = 3716, name = "Torment", rank = "1", bCD = 5000 } )
			table.insert(d, { id = 7809, name = "Torment", rank = "2", bCD = 5000 } )
			table.insert(d, { id = 7810, name = "Torment", rank = "3", bCD = 5000 } )
			table.insert(d, { id = 7811, name = "Torment", rank = "4", bCD = 5000 } )
			table.insert(d, { id = 11774, name = "Torment", rank = "5", bCD = 5000 } )
			table.insert(d, { id = 11775, name = "Torment", rank = "6", bCD = 5000 } )
			table.insert(d, { id = 27270, name = "Torment", rank = "7", bCD = 5000 } )
			table.insert(d, { id = 47984, name = "Torment", rank = "8", bCD = 5000 } )
		end
	end
	
	return d
end

-- WOW: FOREVER
-- Forever's interface number is 16xxx, so it loads the Classic lists above, but its spells
-- are not Era's: some ranks and Season of Discovery spells are gone, a few are renamed and
-- many cooldowns differ. These are the differences between the Classic lists and Forever's
-- game data (wago.tools, build 1.60.1.70707); tools/spell-list-check re-checks them.
-- DROP = the spell does not exist on Forever; otherwise the fields replace the Classic
-- entry's, and oaf = false clears the flag.
local DROP = "drop"
private.foreverChanges = {
	-- Racials
	[26296] = DROP,	-- Berserking
	[26297] = DROP,	-- Berserking
	[20589] = { bCD = 120000 },	-- Escape Artist
	[20549] = { bCD = 90000 },	-- War Stomp
	-- Druid
	[16857] = DROP,	-- Faerie Fire (Feral) (1)
	[17390] = DROP,	-- Faerie Fire (Feral) (2)
	[17391] = DROP,	-- Faerie Fire (Feral) (3)
	[17392] = DROP,	-- Faerie Fire (Feral) (4)
	[16979] = { name = "Feral Charge (Bear)" },	-- Feral Charge
	[22895] = DROP,	-- Frenzied Regeneration (2)
	[22896] = DROP,	-- Frenzied Regeneration (3)
	[6795] = { bCD = 8000 },	-- Growl
	[16914] = { bCD = 0 },	-- Hurricane (4)
	[17401] = { bCD = 0 },	-- Hurricane (5)
	[17402] = { bCD = 0 },	-- Hurricane (6)
	[407995] = { name = "Primal Bite" },	-- Mangle
	[5217] = { bCD = 30000 },	-- Tiger's Fury (1)
	[6793] = DROP,	-- Tiger's Fury (2)
	[9845] = DROP,	-- Tiger's Fury (3)
	[9846] = DROP,	-- Tiger's Fury (4)
	[417045] = { bCD = 0 },	-- Tiger's Fury
	-- Hunter
	[409552] = DROP,	-- Explosive Shot
	[13813] = { bCD = 30000 },	-- Explosive Trap (1)
	[14316] = { bCD = 30000 },	-- Explosive Trap (2)
	[14317] = { bCD = 30000 },	-- Explosive Trap (3)
	[409532] = DROP,	-- Explosive Trap (1)
	[409534] = DROP,	-- Explosive Trap (2)
	[409535] = DROP,	-- Explosive Trap (3)
	[1499] = { bCD = 30000 },	-- Freezing Trap (1)
	[14310] = { bCD = 30000 },	-- Freezing Trap (2)
	[14311] = { bCD = 30000 },	-- Freezing Trap (3)
	[409510] = DROP,	-- Freezing Trap (1)
	[409512] = DROP,	-- Freezing Trap (2)
	[409519] = DROP,	-- Freezing Trap (3)
	[13809] = { bCD = 30000 },	-- Frost Trap
	[409520] = DROP,	-- Frost Trap
	[24597] = { bCD = 30000 },	-- Furious Howl (4)
	[24603] = { bCD = 30000 },	-- Furious Howl (3)
	[24604] = { bCD = 30000 },	-- Furious Howl (1)
	[24605] = { bCD = 30000 },	-- Furious Howl (2)
	[13795] = { bCD = 30000 },	-- Immolation Trap (1)
	[14302] = { bCD = 30000 },	-- Immolation Trap (2)
	[14303] = { bCD = 30000 },	-- Immolation Trap (3)
	[14304] = { bCD = 30000 },	-- Immolation Trap (4)
	[14305] = { bCD = 30000 },	-- Immolation Trap (5)
	[409521] = DROP,	-- Immolation Trap (1)
	[409524] = DROP,	-- Immolation Trap (2)
	[409526] = DROP,	-- Immolation Trap (3)
	[409528] = DROP,	-- Immolation Trap (4)
	[409530] = DROP,	-- Immolation Trap (5)
	[2643] = { bCD = 6000 },	-- Multi-Shot (1)
	[14288] = DROP,	-- Multi-Shot (2)
	[14289] = DROP,	-- Multi-Shot (3)
	[14290] = DROP,	-- Multi-Shot (4)
	[25294] = DROP,	-- Multi-Shot (5)
	[1510] = { bCD = 0 },	-- Volley (1)
	[14294] = { bCD = 0 },	-- Volley (2)
	[14295] = { bCD = 0 },	-- Volley (3)
	[19386] = DROP,	-- Wyvern Sting (1)
	[24132] = DROP,	-- Wyvern Sting (2)
	[24133] = DROP,	-- Wyvern Sting (3)
	-- Paladin
	[407669] = DROP,	-- Avenger's Shield
	[407676] = DROP,	-- Crusader Strike
	[407631] = DROP,	-- Hand of Reckoning
	[20473] = { bCD = 10000 },	-- Holy Shock (1)
	[20929] = { bCD = 10000 },	-- Holy Shock (2)
	[20930] = { bCD = 10000 },	-- Holy Shock (3)
	[633] = { bCD = 1200000 },	-- Lay on Hands (1)
	[2800] = { bCD = 1200000 },	-- Lay on Hands (2)
	[10310] = { bCD = 1200000 },	-- Lay on Hands (3)
	-- Priest
	[2944] = { bCD = 24000 },	-- Devouring Plague (1)
	[19276] = { bCD = 24000 },	-- Devouring Plague (2)
	[19277] = { bCD = 24000 },	-- Devouring Plague (3)
	[19278] = { bCD = 24000 },	-- Devouring Plague (4)
	[19279] = { bCD = 24000 },	-- Devouring Plague (5)
	[19280] = { bCD = 24000 },	-- Devouring Plague (6)
	[19289] = DROP,	-- Elune's Grace (2)
	[19291] = DROP,	-- Elune's Grace (3)
	[19292] = DROP,	-- Elune's Grace (4)
	[19293] = DROP,	-- Elune's Grace (5)
	[6346] = { bCD = 180000 },	-- Fear Ward
	[15286] = { bCD = 30000 },	-- Vampiric Embrace
	-- Shaman
	[16166] = { oaf = false },	-- Elemental Mastery
	[1535] = DROP,	-- Fire Nova Totem (1)
	[8498] = DROP,	-- Fire Nova Totem (2)
	[8499] = DROP,	-- Fire Nova Totem (3)
	[11314] = DROP,	-- Fire Nova Totem (4)
	[11315] = DROP,	-- Fire Nova Totem (5)
	[408490] = { bCD = 10000 },	-- Lava Burst
	[425336] = { name = "Rage of the Farseer", bCD = 180000 },	-- Shamanistic Rage
	[437009] = { bCD = 60000 },	-- Totemic Projection
	-- Warlock
	[603] = { name = "Bane of Doom" },	-- Curse of Doom
	[18708] = { bCD = 300000 },	-- Fel Domination
	[403501] = { bCD = 15000 },	-- Haunt
	[437169] = { bCD = 3600000 },	-- Portal of Summoning
	-- Warrior
	[403338] = DROP,	-- Intervene
	[12975] = { bCD = 180000 },	-- Last Stand
	[20230] = { bCD = 900000 },	-- Retaliation
	[871] = { bCD = 900000 },	-- Shield Wall
	[355] = { bCD = 8000 },	-- Taunt
	[6343] = { bCD = 6000 },	-- Thunder Clap (1)
	[8198] = { bCD = 6000 },	-- Thunder Clap (2)
	[8204] = { bCD = 6000 },	-- Thunder Clap (3)
	[8205] = { bCD = 6000 },	-- Thunder Clap (4)
	[11580] = { bCD = 6000 },	-- Thunder Clap (5)
	[11581] = { bCD = 6000 },	-- Thunder Clap (6)
	[402927] = { bCD = 30000 },	-- Victory Rush
}

-- Spells only Forever has
private.GetForeverData = function(class)
	local d = {}
	
	if class == "PALADIN" then
		table.insert(d, { id = 1310994, name = "Swift Judgement", rank = "", bCD = 60000, oaf = true } )
	end
	
	return d
end

-- The Classic list d with Forever's changes applied, plus Forever's own spells
private.ForeverSpellData = function(d, class)
	local out = {}
	
	for _, spell in ipairs(d) do
		local change = private.foreverChanges[spell["id"]]
		if change ~= DROP then
			if change then
				for k, v in pairs(change) do
					if v == false then
						spell[k] = nil
					else
						spell[k] = v
					end
				end
			end
			table.insert(out, spell)
		end
	end
	
	for _, spell in ipairs(private.GetForeverData(class)) do
		table.insert(out, spell)
	end
	
	return out
end

-- The String for the custom text tag description
function CDTL3:GetCustomTextTagDescription()
	local text = ""
	
	text = text.."Currently custom tags are in the following format:\n\n"
	text = text.."    [p.hp.max]\n\n"
	text = text.."Currently supports the following categories:\n\n"
	text = text.."    'cdtl' - CDTL specific\n"
	text = text.."    'p' - Player\n"
	text = text.."    'f' - Focus\n"
	text = text.."    't' - Target\n\n"
	text = text.."Supports the following sub types for CDTL:\n\n"
	text = text.."    '.name.n' - Name of next due CD\n"
	text = text.."    '.name.l' - Name of last due CD\n"
	text = text.."    '.name.nh' - Name of next due highlighted CD\n"
	text = text.."    '.name.lh' - Name of last due highlighted CD\n"
	text = text.."    '.time.n' - Time left of next due CD\n"
	text = text.."    '.time.l' - Time left of last due CD\n"
	text = text.."    '.time.nh' - Time left of next due highlighted CD\n"
	text = text.."    '.time.lh' - Time left of last due highlighted CD\n\n"
	text = text.."Supports the following sub types for non-CDTL:\n\n"
	text = text.."    '.name' - Unit name\n"
	text = text.."    '.class' - Unit class\n"
	text = text.."    '.level' - Unit level\n"
	text = text.."    '.hp.cur' - Current HP\n"
	text = text.."    '.hp.max' - Max HP\n"
	text = text.."    '.pow.cur' - Current power amount\n"
	text = text.."    '.pow.max' - Max power amount\n"
	
	return text
end

-- The String for the icon text tag description
function CDTL3:GetCustomIconTagDescription()
	local text = ""
	
	text = text.."Currently custom tags are in the following format:\n\n"
	text = text.."    [cd.name]\n\n"
	text = text.."Supports the following tags:\n\n"
	text = text.."    'cd.name' - Cooldown name\n"
	text = text.."    'cd.name.s' - Cooldown name in a short format\n"
	text = text.."    'cd.time' - Time remaining for the icon class\n"
	text = text.."    'cd.type' - Icon type (SPELL, ITEM, etc.)\n"
	text = text.."    'cd.stacks' - Stack count\n"
	
	--CDTL3:Print(text)
	return text
end

function CDTL3:ScanForDynamicTags(iString)
	for _, tag in pairs(private.customTextDynamicTags) do
		if tostring(iString):find(tag["tag"]) then
			return true
		end
	end
	
	return false
end

function CDTL3:ScanForTimeTags(iString)
	for _, tag in pairs(private.customTextTimeTags) do
		if tostring(iString):find(tag["tag"]) then
			return true
		end
	end
	
	return false
end

-- Replace every tag of one family in oString. The template (unconverted text) decides
-- which tags are present, so detection never runs on an already-converted string. Tag
-- functions can return SECRET values (unit health/power on Midnight / WoW: Forever):
-- a substitution that fails shows "?" instead, and both attempts run inside pcalls.
local function ApplyTags(tags, template, oString, frame)
	for _, tag in pairs(tags) do
		if tostring(template):find(tag["tag"]) then
			local ok, replaced = pcall(function()
				return (string.gsub(oString, tag["tag"], tag["func"](frame)))
			end)
			if not ok then
				ok, replaced = pcall(function()
					return (string.gsub(oString, tag["tag"], "?"))
				end)
			end
			if ok then
				oString = replaced
			end
		end
	end

	return oString
end

function CDTL3:ConvertTextTags(iString, frame)
	return ApplyTags(private.customTextTags, iString, iString, frame)
end

function CDTL3:ConvertTextDynamicTags(iString, frame)
	return ApplyTags(private.customTextDynamicTags, iString, iString, frame)
end

function CDTL3:ConvertTextTimeTags(iString, frame)
	return ApplyTags(private.customTextTimeTags, iString, iString, frame)
end

-- Static, dynamic and time tags in one pass. Converting the raw template with one
-- family at a time (and letting the last SetText win) left the other families as
-- literal "[tag]" text, e.g. "[cd.name] [cd.time]" showed as "[cd.name] 12".
function CDTL3:ConvertAllTextTags(iString, frame)
	local oString = ApplyTags(private.customTextTags, iString, iString, frame)
	oString = ApplyTags(private.customTextDynamicTags, iString, oString, frame)
	return ApplyTags(private.customTextTimeTags, iString, oString, frame)
end

-- Holds all the custom text tags
private.customTextTags = {
	-- PLAYER --
	{	name = "Player Name",
		cat = "Player",
		desc = "Show the player name",
		tag = "%[p.name%]",
		func = function()
					return GetUnitName("player")
				end,
	},
	{	name = "Player Class",
		cat = "Player",
		desc = "Show the player class",
		tag = "%[p.class%]",
		func = function()
					local className, _, _ = UnitClass("player")
					return className
				end,
	},


	-- CURRENT --
	{	name = "Cooldown Name",
		cat = "CD",
		desc = "Show the name of this CD",
		tag = "%[cd.name%]",
		func = function(frame)
					if frame then
						local name = ""
						if frame.data["type"] == "icds" then
							name = frame.data["itemName"]
						else
							name = frame.data["name"]
						end
						
						--return frame.data["name"]
						return name
					end
					
					return "Error"
				end,
	},
	{	name = "Cooldown Name (Short)",
		cat = "CD",
		desc = "Show the abbreviated name of this CD",
		tag = "%[cd.name.s%]",
		func = function(frame)
					if frame then
						local name = ""
						
						local inputName = ""
						if frame.data["type"] == "icds" then
							inputName = frame.data["itemName"]
						else
							inputName = frame.data["name"]
						end
						
						--local words = frame.data["name"]:gmatch("%S+")
						local words = inputName:gmatch("%S+")
						
						for w in words do
							w = string.gsub(w , "[()]", "")
							name = name..w:sub(1, 1)
						end
						
						return name
					end
					
					return "Error"
				end,
	},
	{	name = "Cooldown Type",
		cat = "CD",
		desc = "Show the name of this CD",
		tag = "%[cd.type%]",
		func = function(frame)
					if frame then
						return frame.data["type"]
					end
					
					return "Error"
				end,
	},
	
	-- TESTING --
	--[[{	name = "Icon Stack",
		cat = "CD",
		desc = "Show the stack number of this icon",
		tag = "%[cd.iconstack%]",
		func = function(frame)
					if frame then
						if frame.icon.stack then
							return frame.icon.stack
						else
							return ""
						end
					end
					
					return "Error"
				end,
	},]]--
}

private.customTextDynamicTags = {
	-- CDTL --
	{	name = "Next CD Name",
		cat = "CDTL",
		desc = "Show the name of the next CD due",
		tag = "%[cdtl.name.n%]",
		func = function()
					local name = ""
					local lowestTime = 10000
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["currentCD"] > 0 then
									if cd.data["currentCD"] < lowestTime then
										if cd.data["type"] == "icds" then
											name = cd.data["itemName"]
										else
											name = cd.data["name"]
										end
										lowestTime = cd.data["currentCD"]
									end
								end
							end
						end
					end
					
					return name
				end,
	},
	{	name = "Last CD Name",
		cat = "CDTL",
		desc = "Show the name of the last CD due",
		tag = "%[cdtl.name.l%]",
		func = function()
					local name = ""
					local lowestTime = 0
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["currentCD"] > 0 then
									if cd.data["currentCD"] > lowestTime then
										if cd.data["type"] == "icds" then
											name = cd.data["itemName"]
										else
											name = cd.data["name"]
										end
										lowestTime = cd.data["currentCD"]
									end
								end
							end
						end
					end
					
					return name
				end,
	},
	{	name = "Next CD Time",
		cat = "CDTL",
		desc = "Show the time left of the next CD due",
		tag = "%[cdtl.time.n%]",
		func = function()
					local timeString = ""
					local lowestTime = 10000
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["currentCD"] > 0 then
									if cd.data["currentCD"] < lowestTime then
										timeString = CDTL3:ConvertTime(cd.data["currentCD"], "XhYmZs")
										lowestTime = cd.data["currentCD"]
									end
								end
							end
						end
					end
					
					return timeString
				end,
	},
	{	name = "Last CD Time",
		cat = "CDTL",
		desc = "Show the time left of the last CD due",
		tag = "%[cdtl.time.l%]",
		func = function()
					local timeString = ""
					local lowestTime = 0
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["currentCD"] > 0 then
									if cd.data["currentCD"] > lowestTime then
										timeString = CDTL3:GetReadableTime(cd.data["currentCD"])
										lowestTime = cd.data["currentCD"]
									end
								end
							end
						end
					end
					
					return timeString
				end,
	},
	{	name = "Next Highlighted CD Name",
		cat = "CDTL",
		desc = "Show the name of the next highlighted CD due",
		tag = "%[cdtl.name.nh%]",
		func = function()
					local name = ""
					local lowestTime = 10000
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["highlight"] == true then
									if cd.data["currentCD"] > 0 then
										if cd.data["currentCD"] < lowestTime then
											if cd.data["type"] == "icds" then
												name = cd.data["itemName"]
											else
												name = cd.data["name"]
											end
											lowestTime = cd.data["currentCD"]
										end
									end
								end
							end
						end
					end
					
					return name
				end,
	},
	{	name = "Next Highlighted CD Name",
		cat = "CDTL",
		desc = "Show the name of the last highlighted CD due",
		tag = "%[cdtl.name.lh%]",
		func = function()
					local name = ""
					local lowestTime = 0
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["highlight"] == true then
									if cd.data["currentCD"] > 0 then
										if cd.data["currentCD"] > lowestTime then
											if cd.data["type"] == "icds" then
												name = cd.data["itemName"]
											else
												name = cd.data["name"]
											end
											lowestTime = cd.data["currentCD"]
										end
									end
								end
							end
						end
					end
					
					return name
				end,
	},
	{	name = "Next Highlighted CD Time",
		cat = "CDTL",
		desc = "Show the time left of the next highlighted CD due",
		tag = "%[cdtl.time.nh%]",
		func = function()
					local timeString = ""
					local lowestTime = 10000
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["highlight"] == true then
									if cd.data["currentCD"] > 0 then
										if cd.data["currentCD"] < lowestTime then
											timeString = CDTL3:GetReadableTime(cd.data["currentCD"])
											lowestTime = cd.data["currentCD"]
										end
									end
								end
							end
						end
					end
					
					return timeString
				end,
	},
	{	name = "Last Highlighted CD Time",
		cat = "CDTL",
		desc = "Show the time left of the last highlighted CD due",
		tag = "%[cdtl.time.lh%]",
		func = function()
					local timeString = ""
					local lowestTime = 0
					
					for _, cd in ipairs(CDTL3.cooldowns) do
						if cd.data["enabled"] == true then
							if cd.icon.valid == true or cd.bar.valid == true then
								if cd.data["highlight"] == true then
									if cd.data["currentCD"] > 0 then
										if cd.data["currentCD"] > lowestTime then
											timeString = CDTL3:GetReadableTime(cd.data["currentCD"])
											lowestTime = cd.data["currentCD"]
										end
									end
								end
							end
						end
					end
					
					return timeString
				end,
	},
	
	-- PLAYER --
	{	name = "Player Power Current",
		cat = "Player",
		desc = "Show the current amount of power used by the player",
		tag = "%[p.pow.cur%]",
		func = function()
					local _, className = UnitClass("player")	-- class token ("ROGUE"), not the localized name
					local powerType = CDTL3:GetPlayerPower(className)
						
					return UnitPower("player", powerType)
				end,
	},
	{	name = "Player Power Max",
		cat = "Player",
		desc = "Show the max amount of power used by player",
		tag = "%[p.pow.max%]",
		func = function()
					local _, className = UnitClass("player")	-- class token ("ROGUE"), not the localized name
					local powerType = CDTL3:GetPlayerPower(className)
						
					return UnitPowerMax("player", powerType)
				end,
	},
	{	name = "Player Level",
		cat = "Player",
		desc = "Show the player level",
		tag = "%[p.level%]",
		func = function()
					return UnitLevel("player")
				end,
	},
	{	name = "Player HP Current",
		cat = "Player",
		desc = "Show the current player HP",
		tag = "%[p.hp.cur%]",
		func = function()
					return UnitHealth("player")
				end,
	},
	{	name = "Player HP Max",
		cat = "Player",
		desc = "Show the max player HP",
		tag = "%[p.hp.max%]",
		func = function()
					return UnitHealthMax("player")
				end,
	},

	-- FOCUS --
	{	name = "Focus Name",
		cat = "Focus",
		desc = "Show the name of your focus",
		tag = "%[f.name%]",
		func = function()
					if UnitExists("focus") then
						return GetUnitName("focus")
					end
					
					return ""
				end,
	},
	{	name = "Focus Class",
		cat = "Focus",
		desc = "Show the class of your focus",
		tag = "%[f.class%]",
		func = function()
					if UnitExists("focus") then
						local className, _, _ = UnitClass("focus")
						return className
					end
					
					return ""
				end,
	},
	{	name = "Focus Power Current",
		cat = "Focus",
		desc = "Show the current amount of power used by the class of your focus",
		tag = "%[f.pow.cur%]",
		func = function()
					if UnitExists("focus") then
						local _, className = UnitClass("focus")	-- class token ("ROGUE"), not the localized name
						local powerType = CDTL3:GetPlayerPower(className)
						
						return UnitPower("focus", powerType)
					end
					
					return ""
				end,
	},
	{	name = "Focus Power Max",
		cat = "Focus",
		desc = "Show the max amount of power used by the class of your focus",
		tag = "%[f.pow.max%]",
		func = function()
					if UnitExists("focus") then
						local _, className = UnitClass("focus")	-- class token ("ROGUE"), not the localized name
						local powerType = CDTL3:GetPlayerPower(className)
						
						return UnitPowerMax("focus", powerType)
					end
					
					return ""
				end,
	},
	{	name = "Focus Level",
		cat = "Focus",
		desc = "Show the level of your focus",
		tag = "%[f.level%]",
		func = function()
					if UnitExists("focus") then
						return UnitLevel("focus")
					end
					
					return ""
				end,
	},
	{	name = "Focus HP Current",
		cat = "Focus",
		desc = "Show the current HP of your focus",
		tag = "%[f.hp.cur%]",
		func = function()
					if UnitExists("focus") then
						return UnitHealth("focus")
					end
					
					return ""
				end,
	},
	{	name = "Focus HP Max",
		cat = "Focus",
		desc = "Show the max HP of your focus",
		tag = "%[f.hp.max%]",
		func = function()
					if UnitExists("focus") then
						return UnitHealthMax("focus")
					end
					
					return ""
				end,
	},
	
	-- TARGET --
	{	name = "Target Name",
		cat = "Target",
		desc = "Show the name of your target",
		tag = "%[t.name%]",
		func = function()
					if UnitExists("target") then
						return GetUnitName("target")
					end
					
					return ""
				end,
	},
	{	name = "Target Class",
		cat = "Target",
		desc = "Show the class of your target",
		tag = "%[t.class%]",
		func = function()
					if UnitExists("target") then
						local className, _, _ = UnitClass("target")
						return className
					end
					
					return ""
				end,
	},
	{	name = "Target Power Current",
		cat = "Target",
		desc = "Show the current amount of power used by the class of your target",
		tag = "%[t.pow.cur%]",
		func = function()
					if UnitExists("target") then
						local _, className = UnitClass("target")	-- class token ("ROGUE"), not the localized name
						local powerType = CDTL3:GetPlayerPower(className)
						
						return UnitPower("target", powerType)
					end
					
					return ""
				end,
	},
	{	name = "Target Power Max",
		cat = "Target",
		desc = "Show the max amount of power used by the class of your target",
		tag = "%[t.pow.max%]",
		func = function()
					if UnitExists("target") then
						local _, className = UnitClass("target")	-- class token ("ROGUE"), not the localized name
						local powerType = CDTL3:GetPlayerPower(className)
						
						return UnitPowerMax("target", powerType)
					end
					
					return ""
				end,
	},
	{	name = "Target Level",
		cat = "Target",
		desc = "Show the level of your target",
		tag = "%[t.level%]",
		func = function()
					if UnitExists("target") then
						return UnitLevel("target")
					end
					
					return ""
				end,
	},
	{	name = "Target HP Current",
		cat = "Target",
		desc = "Show the current HP of your target",
		tag = "%[t.hp.cur%]",
		func = function()
					if UnitExists("target") then
						return UnitHealth("target")
					end
					
					return ""
				end,
	},
	{	name = "Target HP Max",
		cat = "Target",
		desc = "Show the max HP of your target",
		tag = "%[t.hp.max%]",
		func = function()
					if UnitExists("target") then
						return UnitHealthMax("target")
					end
					
					return ""
				end,
	},
	
	-- CURRENT --
	{	name = "Cooldown Stacks",
		cat = "CD",
		desc = "Show the number of stacks of this CD",
		tag = "%[cd.stacks%]",
		func = function(frame)
					if frame then
						if frame.data["stacks"] == 0 then
							return ""
						else
							return frame.data["stacks"]
						end
					end
					
					return "Error"
				end,
	},
}

private.customTextTimeTags = {
	-- CURRENT --
	{	name = "Cooldown Time",
		cat = "CD",
		desc = "Show the name of this CD",
		tag = "%[cd.time%]",
		func = function(frame)
					if frame then
						return tostring(CDTL3:GetReadableTime(frame.data["currentCD"]))
					end
					
					return "Error"
				end,
	},
}