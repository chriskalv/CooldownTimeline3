--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

-- Fonts
CDTL3.LSM:Register("font", "Fira Sans Condensed", [[Interface\Addons\CooldownTimeline3\Media\FiraSansCondensed-Regular.ttf]])

-- Sounds
CDTL3.LSM:Register("sound", "CDTL3 Click", [[Interface\Addons\CooldownTimeline3\Media\ready-click.ogg]])
CDTL3.LSM:Register("sound", "CDTL3 Rattle", [[Interface\Addons\CooldownTimeline3\Media\ready-rattle.ogg]])
CDTL3.LSM:Register("sound", "CDTL3 Tinks", [[Interface\Addons\CooldownTimeline3\Media\ready-tinks.ogg]])

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
