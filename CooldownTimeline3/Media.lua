--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

-- MEDIA FALLBACKS
-- A saved font, bar texture or sound whose name isn't registered (its media pack was removed,
-- or the settings came from someone else's string) uses CDTL3's own default of that kind
-- instead of LibSharedMedia's (Friz Quadrata, "Blizzard", and for sounds "None", which plays
-- nothing). CDTL3.LSM is CDTL3's own view of the library: everything passes straight through
-- except Fetch. Other addons keep the library itself. The options' dropdowns say when a saved
-- name is missing (CDTL3:MediaMissing, Options.lua AddMediaNotes).
local LSM = LibStub("LibSharedMedia-3.0")
CDTL3.mediaDefaults = { font = "Fira Sans Condensed", statusbar = "CDTL3 Smooth", sound = "CDTL3 Click" }

CDTL3.LSM = setmetatable({
	Fetch = function(self, kind, key, noDefault)
		local fallback = CDTL3.mediaDefaults[kind]
		if fallback and not noDefault and key ~= nil and not LSM:IsValid(kind, key) and not LSM:GetGlobal(kind) then
			return LSM:Fetch(kind, fallback)
		end
		return LSM:Fetch(kind, key, noDefault)
	end,
}, { __index = LSM })

-- Is a saved media name missing here? Then true and the name used instead. Bar textures can
-- also be the modern atlases below.
function CDTL3:MediaMissing(kind, name)
	if type(name) ~= "string" or name == "" or LSM:IsValid(kind, name) then
		return false
	end
	if kind == "statusbar" and CDTL3.barAtlases[name] then
		return false
	end

	local fallback = CDTL3.mediaDefaults[kind]
	local using = LSM:GetGlobal(kind) or (fallback and LSM:IsValid(kind, fallback) and fallback) or LSM:GetDefault(kind) or "None"
	return true, using
end

-- MASQUE
-- One Masque group per timer type inside CDTL3's own group, "CDTL3" (the one group there was
-- before, so a skin already chosen for it stays): a type's group follows that skin until it is
-- given its own in Masque's options. Types without a group of their own (test icons) stay in
-- the CDTL3 group itself.
local MASQUE_GROUPS = {
	spells = "Spells", petspells = "Pet Spells", items = "Items", buffs = "Buffs", debuffs = "Debuffs",
	offensives = "Offensives", runes = "Runes", customs = "Custom", flights = "Flights",
}

function CDTL3:MasqueGroup(cdType)
	local MSQ = CDTL3.Masque
	if not MSQ then
		return nil
	end

	CDTL3.masqueGroups = CDTL3.masqueGroups or {}
	local groups = CDTL3.masqueGroups
	if not groups["CDTL3"] then
		groups["CDTL3"] = MSQ:Group("CDTL3")
		CDTL3.masqueGroup = groups["CDTL3"]
	end

	local key = MASQUE_GROUPS[cdType] and cdType or "CDTL3"
	if not groups[key] then
		groups[key] = MSQ:Group("CDTL3", MASQUE_GROUPS[key], key)
	end

	return groups[key]
end

-- Skin a cooldown's icon (or its bar's icon) in its type's group; a frame now showing another
-- type leaves the group it was in. Removed and added again on every refresh, as before, so a
-- changed icon texture is picked up.
function CDTL3:MasqueSkin(button, icon, cdType)
	local group = CDTL3:MasqueGroup(cdType)
	if not group then
		return
	end

	local was = button.cdtl3MasqueGroup
	if was and was ~= group then
		was:RemoveButton(button)
	end
	group:RemoveButton(button)
	group:AddButton(button, { Icon = icon })
	button.cdtl3MasqueGroup = group
end

-- Fonts
CDTL3.LSM:Register("font", "Fira Sans Condensed", [[Interface\Addons\CooldownTimeline3\Media\FiraSansCondensed-Regular.ttf]])

-- Sounds
CDTL3.LSM:Register("sound", "CDTL3 Click", [[Interface\Addons\CooldownTimeline3\Media\ready-click.ogg]])
CDTL3.LSM:Register("sound", "CDTL3 Rattle", [[Interface\Addons\CooldownTimeline3\Media\ready-rattle.ogg]])
CDTL3.LSM:Register("sound", "CDTL3 Tinks", [[Interface\Addons\CooldownTimeline3\Media\ready-tinks.ogg]])

-- Blizzard sounds worth offering as ready alerts: file data IDs that exist in every client's SoundKitEntry
-- (Era, Forever, TBC, MoP, Retail; see docs/sounds-shortlist.md and tools/spell-list-check/sounds.js)
CDTL3.LSM:Register("sound", "Blizzard: Raid Warning", 567397)
CDTL3.LSM:Register("sound", "Blizzard: PvP Warning", 567488)
CDTL3.LSM:Register("sound", "Blizzard: Quest Complete", 567439)
CDTL3.LSM:Register("sound", "Blizzard: Quest Accepted", 567400)
CDTL3.LSM:Register("sound", "Blizzard: Quest Progress", 567516)
CDTL3.LSM:Register("sound", "Blizzard: Level Up", 569593)
CDTL3.LSM:Register("sound", "Blizzard: Reputation Rank Up", 568016)
CDTL3.LSM:Register("sound", "Blizzard: Queue Joined", 568587)
CDTL3.LSM:Register("sound", "Blizzard: Queue Pop", 568011)
CDTL3.LSM:Register("sound", "Blizzard: Alarm Clock 1", 567436)
CDTL3.LSM:Register("sound", "Blizzard: Alarm Clock 2", 567399)
CDTL3.LSM:Register("sound", "Blizzard: Alarm Clock 3", 567458)
CDTL3.LSM:Register("sound", "Blizzard: Text Ping", 567484)
CDTL3.LSM:Register("sound", "Blizzard: Whisper", 567421)
CDTL3.LSM:Register("sound", "Blizzard: Group Invite", 567451)
CDTL3.LSM:Register("sound", "Blizzard: Map Ping", 567416)
CDTL3.LSM:Register("sound", "Blizzard: Friend Online", 567518)
CDTL3.LSM:Register("sound", "Blizzard: Battle.net Toast", 567402)
CDTL3.LSM:Register("sound", "Blizzard: Store Toast", 915759)
CDTL3.LSM:Register("sound", "Blizzard: Flight Point Discovered", 567497)
CDTL3.LSM:Register("sound", "Blizzard: Coin", 567428)
CDTL3.LSM:Register("sound", "Blizzard: Night Elf Bell", 566558)
CDTL3.LSM:Register("sound", "Blizzard: Shay's Bell", 568154)
CDTL3.LSM:Register("sound", "Blizzard: Holy Cast", 569763)
CDTL3.LSM:Register("sound", "Blizzard: Sparkle Chime", 5259954)
CDTL3.LSM:Register("sound", "Blizzard: Gold Cast", 6226466)
CDTL3.LSM:Register("sound", "Blizzard: Trading Post Celebration", 4906957)
CDTL3.LSM:Register("sound", "Blizzard: Trading Post Coins", 4910746)

-- Plays a sound the owner just picked in a dropdown, once, so it can be heard on the spot (None is silent)
function CDTL3:PlayPicked(name)
	if type(name) ~= "string" or name == "" or name == "None" then
		return false
	end
	local ok = pcall(function()
		PlaySoundFile(CDTL3.LSM:Fetch("sound", name), "SFX")
	end)
	return ok
end

-- Backgrounds
CDTL3.LSM:Register("background", "CDTL3 Icon Shadow", [[Interface\Addons\CooldownTimeline3\Media\icon-shadow.tga]])

-- Textures
CDTL3.LSM:Register("statusbar", "CDTL3 Fire", [[Interface\Addons\CooldownTimeline3\Media\bar-fire.tga]])
CDTL3.LSM:Register("statusbar", "CDTL3 Web", [[Interface\Addons\CooldownTimeline3\Media\bar-web.tga]])
CDTL3.LSM:Register("statusbar", "CDTL3 Smooth", [[Interface\Addons\CooldownTimeline3\Media\bar-smooth.tga]])

-- Borders
CDTL3.LSM:Register("border", "CDTL3 Shadow", [[Interface\Addons\CooldownTimeline3\Media\border-dropshad.tga]])

-- Blizzard's modern bar art (Retail / WoW: Forever engine) is atlas-based, which
-- LibSharedMedia can't list. Offer the bar atlases this client actually has, in CDTL3's own
-- texture dropdowns only (registering them with LSM would show broken entries in other
-- addons). CDTL3:SetBarTexture applies them; "Status" variants are grey and tint cleanly.
CDTL3.barAtlases = {}
CDTL3.barAtlasPreview = [[Interface\TargetingFrame\UI-StatusBar]]

local MODERN_BARS = {
	{ "Blizzard Modern: Health", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health" },
	{ "Blizzard Modern: Health (tintable)", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Status" },
	{ "Blizzard Modern: Mana", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana" },
	{ "Blizzard Modern: Mana (tintable)", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Status" },
	{ "Blizzard Modern: Rage", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Rage" },
	{ "Blizzard Modern: Energy", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Energy" },
	{ "Blizzard Modern: Focus", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Focus" },
	{ "Blizzard Modern: Runic Power", "UI-HUD-UnitFrame-Player-PortraitOn-Bar-RunicPower" },
	{ "Blizzard Modern: Cast", "ui-castingbar-filling-standard" },
	{ "Blizzard Modern: Cast (full)", "ui-castingbar-full-standard" },
	{ "Blizzard Modern: Channel", "ui-castingbar-filling-channel" },
	{ "Blizzard Modern: Crafting", "ui-castingbar-filling-applyingcrafting" },
	{ "Blizzard Modern: Uninterruptible", "ui-castingbar-uninterruptable" },
	{ "Blizzard Modern: Cast Background", "ui-castingbar-background" },
	{ "Blizzard Modern: Raid Resource", "_RaidFrame-Resource-Fill" },
}

if C_Texture and C_Texture.GetAtlasInfo then
	for _, bar in ipairs(MODERN_BARS) do
		local ok, info = pcall(C_Texture.GetAtlasInfo, bar[2])
		if ok and info then
			CDTL3.barAtlases[bar[1]] = bar[2]
		end
	end
end

-- Apply a bar texture by name (LSM name or a modern atlas above) to a StatusBar or Texture
function CDTL3:SetBarTexture(region, name)
	local atlas = CDTL3.barAtlases[name]

	if region.SetStatusBarTexture then
		region:SetStatusBarTexture(atlas or CDTL3.LSM:Fetch("statusbar", name))
	elseif atlas then
		region:SetAtlas(atlas, false)
	else
		region:SetTexture(CDTL3.LSM:Fetch("statusbar", name))
	end
end

-- Values for CDTL3's bar texture dropdowns: every LSM statusbar plus the modern atlases
-- (previewed with a plain bar, since the dropdown can only draw files)
function CDTL3:GetBarTextureList()
	local list = {}
	for name, path in pairs(CDTL3.LSM:HashTable("statusbar")) do
		list[name] = path
	end
	for name in pairs(CDTL3.barAtlases) do
		list[name] = CDTL3.barAtlasPreview
	end

	return list
end
