--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
	
	Update notes:
		- Almost complete re-write, see changelog in game for details
]]--

CDTL3 = LibStub("AceAddon-3.0"):NewAddon("CDTL3", "AceConsole-3.0", "AceEvent-3.0")
CDTL3.Masque = LibStub("Masque", true)
CDTL3.LSM = LibStub("LibSharedMedia-3.0")
CDTL3.GUI = LibStub("AceGUI-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")

local _, _, _, tocversion = GetBuildInfo()
CDTL3.tocversion = tocversion

-- WoW: Forever runs the modern Mainline engine and API (the old spell/aura/spellbook
-- globals are gone, values can be secret) but reports a vanilla-era interface number
-- (16xxx). So tocversion only picks era CONTENT (spell lists, class colours);
-- retailAPI picks which API calls exist. Detect Forever by its 16xxx interface band:
-- WOW_PROJECT_ID was Mainline (1) on early beta builds but changed to 18 in 70205.
CDTL3.isForever = (tocversion >= 16000 and tocversion < 17000)
	or (WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and tocversion < 110000)
CDTL3.retailAPI = tocversion >= 110000 or CDTL3.isForever

-- The combat log is closed to addons on retail 12.x and Forever. Settle that at load so the
-- options that need it are hidden even while TurnOn hasn't run (it only runs when detection
-- is on); on the other clients TurnOn records whether the event could be registered.
if CDTL3.retailAPI then
	CDTL3.combatLogRegistered = false
end

-- The Classic clients now call it C_CombatLog.GetCurrentEventInfo; the old global is a deprecated
-- alias there (and a stub on retail). Prefer the new name, fall back to the old one.
local GetCombatLogEventInfo = (C_CombatLog and C_CombatLog.GetCurrentEventInfo) or CombatLogGetCurrentEventInfo

-- True where nothing fed only by the combat log can fire. Options.lua hides those options,
-- Cooldown.lua ignores Spell School Color.
function CDTL3:NoCombatLog()
	return CDTL3.combatLogRegistered == false or not GetCombatLogEventInfo
end

-- Globals that no longer exist on Forever (or on retail from 12.1.5): GetItemSpell and
-- GetItemInfoInstant were removed in 12.1.5 (C_Item since 10.2.6); IsSpellKnown and
-- IsSpellKnownOrOverridesKnown survive only in Blizzard's deprecation fallbacks since 11.2.
-- Resolved per call, preferring whatever the client still provides.
local function SpellBank(isPet)
	return isPet and Enum.SpellBookSpellBank.Pet or Enum.SpellBookSpellBank.Player
end

CDTL3.Compat = {
	GetItemSpell = function(item)
		-- inventory scans pass -1/0 for an empty slot; C_Item validates its argument
		if not item or (type(item) == "number" and item <= 0) then
			return nil
		end
		return ((C_Item and C_Item.GetItemSpell) or GetItemSpell)(item)
	end,
	GetItemInfoInstant = function(item)
		return ((C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant)(item)
	end,
	IsSpellKnown = function(spellID, isPet)
		if IsSpellKnown then
			return IsSpellKnown(spellID, isPet)
		end
		return C_SpellBook.IsSpellKnown(spellID, SpellBank(isPet))
	end,
	IsSpellKnownOrOverridesKnown = function(spellID, isPet)
		if IsSpellKnownOrOverridesKnown then
			return IsSpellKnownOrOverridesKnown(spellID, isPet)
		end
		return C_SpellBook.IsSpellKnownOrInSpellBook(spellID, SpellBank(isPet), true)
	end,
}

CDTL3.version = "3.2.1"
-- the welcome window (GetSpecialMessage + changelog) opens once for anyone whose last seen version is older
CDTL3.noticeVersion = "3.2"
CDTL3.cdUID = 999
-- where to report issues / make suggestions (first-run window, Changelog tab)
CDTL3.supportlink = "https://github.com/Nelnamara/cdtl3-dev/issues"
CDTL3.lanes = {}
CDTL3.barFrames = {}
CDTL3.readyFrames = {}
CDTL3.holders = {}
CDTL3.player = {}
CDTL3.cooldowns = {}
CDTL3.testing = false
CDTL3.tracking = {
	mhSwingTime = -1,
	ohSwingTime = -1,
	rSwingTime = -1,
}
CDTL3.spellData = {}
CDTL3.recentAuras = {}
CDTL3.auraExpiry = {}
CDTL3.colors = {
	bg = {},
	db = { r = 0.1, g = 0.1, b = 0.1, a = 0.85 },
}
CDTL3.custom = {}
CDTL3.combat = false
CDTL3.enabled = false
local private = {}

-- Deep copy of base with overrides applied on top (nested tables merge key by key).
-- Lanes, bar frames and ready frames 2 and 3 are #1 with a handful of values changed,
-- so each is declared once below and only the differences are listed per index.
local function WithOverrides(base, overrides)
	local copy = {}
	for k, v in pairs(base) do
		copy[k] = type(v) == "table" and WithOverrides(v) or v
	end

	for k, v in pairs(overrides or {}) do
		if type(v) == "table" then
			copy[k] = WithOverrides(type(copy[k]) == "table" and copy[k] or {}, v)
		else
			copy[k] = v
		end
	end

	return copy
end

-- Show (each lane, bar frame and ready frame): "GLOBAL" follows Global > Hide out of combat, or
-- "ALWAYS", "COMBAT" (only in combat), "BOSS" (boss fights only). Dim instead of hide keeps the
-- frame at dimAlpha while its Show rule would hide it (CDTL3:Autohide, Helpers.lua). The same
-- three settings are in barFrameDefaults and readyDefaults.
local laneDefaults = {
	enabled = true,
	showMode = "GLOBAL", dimInsteadOfHide = false, dimAlpha = 0.3,
	name = "Lane 1",
	reversed = false,
	vertical = false,

	posX = 0,
	posY = -250,
	width = 400,
	height = 44,
	relativeTo = "CENTER",
	-- Anchor to (Anchors.lua): SCREEN keeps the x/y position above; PLAYER, COOLDOWNS or NAMED (frame) place it on another frame's side
	anchor = { to = "SCREEN", frame = "", side = "ABOVE", x = 0, y = 0 },
	alpha = 1,
	-- Pause while hidden: icons skip their visual updates while the lane is faded to nothing (Cooldown.lua)
	pauseHidden = false,
	-- Caster lane (Group.lua): each owned timer's icon gets its caster's name under it
	casterLane = false,

	-- Effects (IconFx.lua), all off until turned on: charge pips on spell icons, GCD waits sent to the
	-- Ready frame, the burst window (shaded on a Time lane, and/or a Ready-by list) and the refresh zone
	fx = {
		chargePips = false,
		gcdWait = false,
		burst = { enabled = false, secs = 25, shaded = true, list = false },
		refresh = { enabled = false, pct = 30 },
	},

	iconOffset = 0,

	tracking = {
		primaryTracking = "NONE",
		secondaryTracking = "GCD",

		overrideAutohide = false,

		primaryReversed = false,
		secondaryReversed = false,

		stTexture = "CDTL3 Smooth",
		stTextureColor = { r = 1, g = 1, b = 1, a = 0.5 },

		stWidth = 5,
		stHeight = 44,

		-- Change color at (ResourceBars.lua, Primary Tracking on Class Power): the whole fill takes this color at or above value
		threshold = { enabled = false, value = 40, color = { r = 0.949, g = 0.761, b = 0.188, a = 1 } },
	},

	-- Mana gauge (ResourceBars.lua): an upright gauge at the lane's Ready end
	gauge = { enabled = false, showPercent = true, width = 16, height = 44, gap = 6, color = { r = 0.165, g = 0.373, b = 0.839, a = 1 } },

	stacking = {
		enabled = false,
		raiseOnMouseOver = false,
		style = "GROUPED",
		grow = "UP",
		height = 80,
	},

	fgTexture = "CDTL3 Smooth",
	fgTextureColor = { r = 0.77647, g = 0.11765, b = 0.28235, a = 1 },
	fgClassColor = true,
	bgTexture = "CDTL3 Smooth",
	bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },
	bgClassColor = false,

	border = {
		style = "CDTL3 Shadow",
		color = { r = 0, g = 0, b = 0, a = 0.25 },
		size = 5,
		padding = 5,
		inset = 0,
	},

	icons = {
		size = 40,
		hlStyle = "NONE",
		timeFormat = "H:MM:SS.MS",

		alpha = 1,

		bgTexture = "CDTL3 Icon Shadow",
		bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },

		border = {
			style = "None",
			color = { r = 0, g = 0, b = 0, a = 1 },
			size = 5,
			padding = 5,
			inset = 0,
		},

		highlight = {
			style = "BORDER",

			border = {
				style = "None",
				color = { r = 1, g = 1, b = 1, a = 1 },
				size = 5,
				padding = 5,
				inset = 0,
				flash = false,
			},
		},

		text1 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = true,
			ttags = false,
			text = "[cd.stacks]",
			font = "Fira Sans Condensed",
			size = 11,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "LEFT",
			anchor = "TOPLEFT",
			offX = 2,
			offY = -7,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
		text2 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = false,
			ttags = true,
			text = "[cd.time]",
			font = "Fira Sans Condensed",
			size = 16,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "CENTER",
			offX = 0,
			offY = 0,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
		text3 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "",
			font = "Fira Sans Condensed",
			size = 11,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "BOTTOM",
			offX = 2,
			offY = 5,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
	},

	mode = {
		type = "LINEAR",
		linear = {
			max = 120,
			hideTimeSurplus = true,
		},
		linearAbs = {
			max = 120,
			hideTimeSurplus = true,
			timeFormat = "XhYmZs",
		},
		split = {
			max = 120,
			hideTimeSurplus = true,
			count = 2,
			s1v = 10,
			s1p = 0.33,
			s2v = 33,
			s2p = 0.66,
			s3v = 66,
			s3p = 0.75,
		},
		splitAbs = {
			max = 120,
			hideTimeSurplus = true,
			timeFormat = "XhYmZs",
			count = 3,
			s1v = 10,
			s1p = 0.25,
			s2v = 30,
			s2p = 0.5,
			s3v = 60,
			s3p = 0.75,
		},
	},

	modeText = {
		text1 = {
			enabled = true,
			used = true,
			edit = false,
			text = "T1",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "LEFT",
			anchor = "LEFT",
			pos = 0,
			offX = 5,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text2 = {
			enabled = true,
			used = true,
			text = "T2",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "LEFT",
			pos = 0.25,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text3 = {
			enabled = true,
			used = true,
			text = "T3",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "LEFT",
			pos = 0.5,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text4 = {
			enabled = true,
			used = true,
			text = "T4",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "LEFT",
			pos = 0.75,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text5 = {
			enabled = true,
			used = true,
			text = "T5",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "RIGHT",
			anchor = "LEFT",
			pos = 1,
			offX = -5,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
	},
	customText = {				
		text1 = {
			enabled = false,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "Custom Text 1",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "TOPLEFT",
			pos = 0,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text2 = {
			enabled = false,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "Custom Text 2",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "TOPRIGHT",
			pos = 0,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text3 = {
			enabled = false,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "Custom Text 3",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "CENTER",
			pos = 0,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text4 = {
			enabled = false,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "Custom Text 4",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "BOTTOMLEFT",
			pos = 0,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
		text5 = {
			enabled = false,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "Custom Text 5",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "BOTTOMRIGHT",
			pos = 0,
			offX = 0,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 1 },
			shadX = 1.5,
			shadY = -1,
		},
	},
}

local barFrameDefaults = {
	enabled = true,
	showMode = "GLOBAL", dimInsteadOfHide = false, dimAlpha = 0.3,
	name = "Bar Frame 1",
	grow = "UP",
	horizontal = false,
	padding = 0,

	posX = -300,
	posY = 0,
	width = 180,
	height = 25,
	relativeTo = "CENTER",
	anchor = { to = "SCREEN", frame = "", side = "ABOVE", x = 0, y = 0 },
	alpha = 1,

	transition = {
		hideTransitioned = true,

		showTI = true,
		style = "LINE",

		texture = "CDTL3 Smooth",
		textureColor = { r = 1, g = 1, b = 1, a = 0.5 },

		width = 5,
	},

	bgTexture = "CDTL3 Smooth",
	bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },

	border = {
		style = "CDTL3 Shadow",
		color = { r = 0, g = 0, b = 0, a = 0.25 },
		size = 5,
		padding = 5,
		inset = 0,
	},

	bar = {
		iconEnabled = true,
		iconPosition = "LEFT",

		alpha = 1,

		xPadding = 0,
		yPadding = 0,

		fgTexture = "CDTL3 Smooth",
		fgTextureColor = { r = 0.77647, g = 0.11765, b = 0.28235, a = 1 },	
		fgClassColor = false,
		fgSchoolColor = false,
		bgTexture = "CDTL3 Smooth",
		bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },
		bgClassColor = false,
		bgSchoolColor = false,

		dynamicColor = {
			enabled = false,
			warnTime = 5,
			warnColor = { r = 1, g = 0.6, b = 0, a = 1 },
			readyColor = { r = 0.2, g = 0.9, b = 0.2, a = 1 },
		},

		border = {
			style = "None",
			color = { r = 1, g = 1, b = 1, a = 0.25 },
			size = 5,
			padding = 5,
			inset = 0,
		},

		text1 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = true,
			ttags = false,
			text = "[cd.stacks]",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "LEFT",
			offX = 14,
			offY = 0,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 0,
			shadY = 0,
		},
		text2 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "[cd.name]",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "LEFT",
			anchor = "LEFT",
			offX = 30,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
		text3 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = false,
			ttags = true,
			text = "[cd.time]",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "RIGHT",
			anchor = "RIGHT",
			offX = -5,
			offY = 0,
			outline = "",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
	}
}

local readyDefaults = {
	enabled = true,
	showMode = "GLOBAL", dimInsteadOfHide = false, dimAlpha = 0.3,
	name = "Ready 1",
	grow = "DOWN",
	padding = 0,

	nTime = 5,
	nSound = "CDTL3 Click",
	hTime = 10,
	hSound = "None",
	pTime = 10,
	-- NORMAL: icons wait their Normal Duration. STAY: a board of the pinned cooldowns that stays up (ReadyBoard.lua)
	mode = "NORMAL",

	posX = -300,
	posY = -75,
	relativeTo = "CENTER",
	anchor = { to = "SCREEN", frame = "", side = "ABOVE", x = 0, y = 0 },
	alpha = 1,

	bgTexture = "CDTL3 Smooth",
	bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },

	border = {
		style = "CDTL3 Shadow",
		color = { r = 0, g = 0, b = 0, a = 0.25 },
		size = 5,
		padding = 5,
		inset = 0,
	},

	icons = {
		size = 50,

		alpha = 1,

		xPadding = 0,
		yPadding = 0,

		bgTexture = "CDTL3 Icon Shadow",
		bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },

		border = {
			style = "None",
			color = { r = 0, g = 0, b = 0, a = 0.25 },
			size = 5,
			padding = 5,
			inset = 0,
		},

		highlight = {
			style = "BORDER",

			border = {
				style = "None",
				color = { r = 1, g = 1, b = 1, a = 0.25 },
				size = 5,
				padding = 5,
				inset = 0,
				flash = false,
			},
		},

		text1 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "[cd.name.s]",
			font = "Fira Sans Condensed",
			size = 18,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "CENTER",
			offX = 0,
			offY = 7,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
		text2 = {
			enabled = true,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "READY",
			font = "Fira Sans Condensed",
			size = 12,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "CENTER",
			offX = 0,
			offY = -7,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
		text3 = {
			enabled = false,
			used = true,
			edit = false,
			dtags = false,
			ttags = false,
			text = "[cd.type]",
			font = "Fira Sans Condensed",
			size = 10,
			color = { r = 1, g = 1, b = 1, a = 1 },
			align = "CENTER",
			anchor = "BOTTOM",
			offX = 0,
			offY = 7,
			outline = "OUTLINE",
			shadColor = { r = 0, g = 0, b = 0, a = 0.5 },
			shadX = 1.5,
			shadY = -1,
		},
	},
}

local defaults = {
    profile = {
		global = {
			firstRun = true,
			previousVersion = 0,

			unlockFrames = true,
			debugMode = false,

			customDetection = false,
			customDetectAll = false,

			autohide = false,
			enableTooltip = false,
			zoom = 1,
			-- Ready tab: silences every ready sound (the frames', the spells' own, spoken names)
			muteReadySounds = false,
			
			detectSharedCD = false,
			hideIgnored = true,
			
			notUsableTint = false,
			notUsableDesaturate = false,
			notUsableColor = { r = 0.75, g = 0.1, b = 0.1, a = 1 },
			
			enabledAlways = true,
			enabledGroup = false,
			enabledInstance = false,
			hideOutOfCombat = false,

			dynamicSpellDetection = false,

			-- Update rate (Cooldown.lua): 0 = every frame, else visual updates per second
			updateRate = 0,

			-- CombatTimers.lua: on for everyone since 3.1.0 (the owner's call), with a notice on the
			-- first login after the update. Blizzard's Tracked Bars stay visible unless the player hides them.
			combatTimers = { enabled = true, hideBlizzardBars = false },

			-- FightTimeline.lua: off until switched on. flag1..3 are seconds into the fight (0 = no flag).
			fightTimeline = {
				enabled = false, hideOutOfCombat = false,
				width = 340, span = 360, iconSize = 22,
				flag1 = 120, flag2 = 180, flag3 = 300,
				point = "CENTER", x = 0, y = -150,
			},
			-- Start.lua: a ~ before a time CDTL3 counts itself (off: nothing changes), and the starter
			-- setup the player kept in Quick Style ("" = none)
			estimateTilde = false,
			setupKey = "",

			exportMode = "SETTINGS",
			importMode = "SETTINGS",

			testingLoop = false,
			testingNumber = 10,
			testingType = "spells",
			testingMinTime = 10,
			testingMaxTime = 180,

			classColors = {
				DEATHKNIGHT = 	{ r = 0.77, g = 0.12, b = 0.23, a = 1 }, 	-- Red
				DEMONHUNTER = 	{ r = 0.64, g = 0.19, b = 0.79, a = 1 }, 	-- Dark Magenta
				DRUID = 		{ r = 1, g = 0.49, b = 0.04, a = 1 }, 		-- Orange
				EVOKER = 		{ r = 0.2, g = 0.58, b = 0.5, a = 1 }, 		-- Dark Emerald
				HUNTER = 		{ r = 0.67, g = 0.83, b = 0.45, a = 1 }, 	-- Pistachio
				MAGE = 			{ r = 0.25, g = 0.78, b = 0.92, a = 1 }, 	-- Light Blue
				MONK = 			{ r = 0, g = 1, b = 0.6, a = 1 }, 			-- Spring Green
				PALADIN = 		{ r = 0.96, g = 0.55, b = 0.73, a = 1 }, 	-- Pink
				PRIEST = 		{ r = 1, g = 1, b = 1, a = 1 }, 			-- White
				ROGUE = 		{ r = 1, g = 0.96, b = 0.41, a = 1 }, 		-- Yellow
				SHAMAN = 		{ r = 0, g = 0.44, b = 0.87, a = 1 }, 		-- Blue
				WARLOCK = 		{ r = 0.53, g = 0.53, b = 0.93, a = 1 }, 	-- Purple
				WARRIOR = 		{ r = 0.78, g = 0.61, b = 0.43, a = 1 }, 	-- Tan
			},
			
			schoolColors = {
				Physical = { r = 1, g = 1, b = 0, a = 1 },
				Holy = { r = 1, g = 0.90196, b = 0.5, a = 1 },
				Fire = { r = 1, g = 0.5, b = 0, a = 1 },
				Nature = { r = 0.30196, g = 1, b = 0.30196, a = 1 },
				Frost = { r = 0.5, g = 1, b = 1, a = 1 },
				Shadow = { r = 0.5, g = 0.5, b = 1, a = 1 },
				Arcane = { r = 1, g = 0.5, b = 1, a = 1 },
				Other = { r = 0.8, g = 0.8, b = 0.8, a = 1 },
			},
			
			spells = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 3600,
				defaultLane = 1,
				defaultReady = 1,
				defaultBar = 1,
				hideUnknown = false,	-- Filters > Spells > Hide spells I don't know
			},
			
			items = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 3600,
				defaultLane = 1,
				defaultReady = 1,
				defaultBar = 1,
				useItemIcon = true,
			},
			
			buffs = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 120,
				defaultLane = 2,
				defaultReady = 2,
				defaultBar = 2,
				onlyPlayer = true,
			},
			
			debuffs = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 300,
				defaultLane = 3,
				defaultReady = 3,
				defaultBar = 3,
				onlyPlayer = true,
			},
			
			offensives = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 600,
				defaultLane = 0,
				defaultReady = 0,
				defaultBar = 0,
			},
			
			petspells = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 3600,
				defaultLane = 1,
				defaultReady = 1,
				defaultBar = 1,
			},

			runes = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 3600,
				defaultLane = 1,
				defaultReady = 1,
				defaultBar = 1,
			},
			customs = {
				enabled = true,
				showByDefault = true,
				ignoreThreshold = 3600,
				defaultLane = 1,
				defaultReady = 1,
				defaultBar = 1,
			},

			-- flight timers (Flights.lua); learned times are account-wide in db.global.flightTimes
			flights = {
				enabled = true,
				defaultLane = 1,
				defaultReady = 1,
				defaultBar = 1,
			},
		},
	
		lanes = {
			global = {
				fgTexture = "CDTL3 Smooth",
				fgTextureColor = { r = 0.77647, g = 0.11765, b = 0.28235, a = 1 },
				fgClassColor = true,
				bgTexture = "CDTL3 Smooth",
				bgTextureColor = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 },
				bgClassColor = false,
			},
			lane1 = WithOverrides(laneDefaults),
			lane2 = WithOverrides(laneDefaults, {
				name = "Lane 2",
				height = 5,
				posY = -200,
				fgTextureColor = { r = 0.52941, g = 0.77647, b = 0.24314 },
				icons = {
					size = 30,
					highlight = { border = { color = { a = 0.25 } } },
					text1 = { offX = 0, offY = -5, size = 10 },
					text2 = { size = 13 },
					text3 = { align = "RIGHT", anchor = "BOTTOMRIGHT", offX = 0, size = 10 },
				},
				mode = { split = { count = 3, s1p = 0.25, s2p = 0.5, s2v = 25, s3v = 50 } },
				modeText = {
					text1 = { enabled = false },
					text2 = { enabled = false },
					text3 = { enabled = false },
					text4 = { enabled = false },
					text5 = { enabled = false },
				},
				tracking = { secondaryTracking = "NONE", stHeight = 30 },
			}),
			lane3 = WithOverrides(laneDefaults, {
				name = "Lane 3",
				height = 5,
				posY = -160,
				fgTextureColor = { r = 0.15294, g = 0.63922, b = 0.77647 },
				icons = {
					size = 30,
					highlight = { border = { color = { a = 0.25 } } },
					text1 = { offX = 0, offY = -3, size = 10 },
					text2 = { size = 13 },
					text3 = { anchor = "BOTTOMRIGHT", offX = -10, offY = 0, size = 10 },
				},
				mode = { split = { count = 3, s1p = 0.25, s1v = 5, s2p = 0.5, s2v = 25, s3v = 50 } },
				modeText = {
					text1 = { enabled = false },
					text2 = { enabled = false },
					text3 = { enabled = false },
					text4 = { enabled = false },
					text5 = { enabled = false },
				},
				tracking = { secondaryTracking = "NONE", stHeight = 20 },
			}),
		},
		
		barFrames = {
			frame1 = WithOverrides(barFrameDefaults),
			frame2 = WithOverrides(barFrameDefaults, {
				name = "Bar Frame 2",
				posX = 300,
				bar = { fgTextureColor = { r = 0.52941, g = 0.77647, b = 0.24314 } },
			}),
			frame3 = WithOverrides(barFrameDefaults, {
				name = "Bar Frame 3",
				posX = 0,
				posY = 175,
				bar = { fgTextureColor = { r = 0.15294, g = 0.63922, b = 0.77647 } },
			}),
		},
		
		ready = {
			ready1 = WithOverrides(readyDefaults),
			ready2 = WithOverrides(readyDefaults, {
				name = "Ready 2",
				posX = 300,
				nSound = "CDTL3 Tinks",
				icons = { border = { color = { a = 1 } } },
			}),
			ready3 = WithOverrides(readyDefaults, {
				name = "Ready 3",
				grow = "CENTER_H",
				posX = 0,
				posY = 100,
				nSound = "CDTL3 Tinks",
				icons = { border = { color = { a = 1 } } },
			}),
		},
		
		holders = {
			iconPadding = 12,
			iconSize = 48,
			barPadding = 6,
			barWidth = 150,
			barHeight = 22,
			fontSize = 10,
		},
		
		tables = {
			spells = {},
			petspells = {},
			items = {},
			buffs = {},
			debuffs = {},
			offensives = {},
			runes = {},
			customs = {},
			detected = {},
			flights = {},	-- always empty: lets lookups by type find nothing for a flight
		},
	}
}

function CDTL3:OnInitialize()
	-- One-time migration: this addon's saved DB was historically named CDTL2DB.
	-- Carry it over so existing profiles survive the CDTL2->CDTL3 rename. Both names
	-- are declared in the TOC SavedVariables so the old global still loads here; the
	-- old CDTL2DB can be dropped from the TOC in a future version once users migrate.
	if not CDTL3DB and CDTL2DB then CDTL3DB = CDTL2DB end
	self.db = LibStub("AceDB-3.0"):New("CDTL3DB", defaults, true)
	self.registry = LibStub("AceConfigRegistry-3.0")
	self.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

	-- Per-spec profiles (Profiles tab): LibDualSpec switches profile when the spec / talent
	-- group changes, which fires OnProfileChanged -> RefreshConfig like a manual switch.
	-- Guarded so a client without spec APIs can't stop the addon loading.
	local LibDualSpec = LibStub("LibDualSpec-1.0", true)
	if LibDualSpec and pcall(LibDualSpec.EnhanceDatabase, LibDualSpec, self.db, "CDTL3") then
		pcall(LibDualSpec.EnhanceOptions, LibDualSpec, self.profile, self.db)
	end

	CDTL3.filterList = {}
	CDTL3.currentFilterHidden = {
		default = false,
		spells = true,
		items = true,
		buffs = true,
		debuffs = true,
		offensives = true,
		petspells = true,
		runes = true,
		customs = true,
		detected = true,
	}
	-- "default" (Filters -> Defaults) is read as soon as the options window opens, which
	-- can be before OnEnable's delayed step fills the rest
	CDTL3.currentFilter = { default = "SPELLS" }
	
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
	
	--LibStub("AceConfig-3.0"):RegisterOptionsTable("CDTL3", CDTL3:GetMainOptions(), { "cdtl2", "cooldowntimeline2"})
	-- ALL settings live in the standalone movable window (/cdtl3): the full tree with the
	-- Lanes/Ready/Bar Frames/Filters/Profiles panels as tabs. Blizzard's Settings frame is
	-- unmovable, so its AddOns list gets ONLY a launcher button — no settings live there.
	LibStub("AceConfig-3.0"):RegisterOptionsTable("CDTL3", CDTL3:GetFullOptions())

	LibStub("AceConfig-3.0"):RegisterOptionsTable("CDTL3Bliz", {
		name = "CDTL3",
		type = "group",
		args = {
			about = {
				name = L["CDTL3 is configured in its own movable window."] .. "\n\n",
				type = "description",
				fontSize = "medium",
				order = 1,
			},
			open = {
				name = L["Open CDTL3 Settings"],
				desc = L["Opens the CDTL3 configuration window (same as /cdtl3)"],
				type = "execute",
				width = 1.5,
				order = 2,
				func = function()
						if SettingsPanel and SettingsPanel:IsShown() then
							pcall(HideUIPanel, SettingsPanel)
						end
						LibStub("AceConfigDialog-3.0"):Open("CDTL3")
					end,
			},
		},
	})
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("CDTL3Bliz", "CDTL3")
	
	self:RegisterChatCommand("cdtl3", "ChatCommand")
	self:RegisterChatCommand("cooldowntimeline3", "ChatCommand")
	-- legacy aliases (kept so long-time users' muscle memory still works)
	self:RegisterChatCommand("cdtl2", "ChatCommand")
    self:RegisterChatCommand("cooldowntimeline2", "ChatCommand")
end

-- Minimap button — left-click opens settings, right-click toggles frame lock, drag repositions.
function CDTL3:BuildMinimapButton()
	if self.minimapBtn then return end
	-- Orbit radius follows the minimap's LIVE size (the Forever minimap is larger than the old
	-- one, and Edit Mode can rescale it): button center sits just past the rim so it rides the
	-- border instead of floating inside the map.
	local function offset(a)
		local radius = (Minimap:GetWidth() / 2) + 4
		return radius * math.cos(math.rad(a)), radius * math.sin(math.rad(a))
	end
	local function place(btn)
		local angle = (CDTL3.db.global and CDTL3.db.global.minimapAngle) or 225
		btn:ClearAllPoints()
		btn:SetPoint("CENTER", Minimap, "CENTER", offset(angle))
	end

	local btn = CreateFrame("Button", "CDTL3MinimapButton", Minimap)
	btn:SetSize(24, 24)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:EnableMouse(true)
	btn:RegisterForDrag("LeftButton")
	btn:RegisterForClicks("AnyUp")

	-- Self-contained round icon (gold ring baked in) — SetAllPoints centers it cleanly.
	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	icon:SetTexture("Interface\\AddOns\\CooldownTimeline3\\Media\\minimap.tga")

	place(btn)
	Minimap:HookScript("OnSizeChanged", function() place(btn) end)
	btn:SetShown(not (self.db.global and self.db.global.minimapHide))

	btn:SetScript("OnEnter", function(s)
		GameTooltip:SetOwner(s, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cFF54a3ffCDTL3|r |cffffffff(CooldownTimeline)|r")
		-- where things stand: frames locked or not, combat timers (Retail and Forever only)
		local unlocked = CDTL3.db.profile.global["unlockFrames"]
		GameTooltip:AddLine(string.format(L["Frames: %s"], "|cffffd100" .. (unlocked and L["unlocked"] or L["locked"]) .. "|r"), 1, 1, 1)
		local CT = CDTL3.CombatTimers
		if CT and CT:Available() then
			GameTooltip:AddLine(string.format(L["Combat timers: %s"], CT:Enabled() and L["on"] or L["off"]), 1, 1, 1)
		end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L["Left-click: Open settings"], 1, 1, 1)
		GameTooltip:AddLine(L["Right-click: Lock/unlock"], 1, 1, 1)
		GameTooltip:AddLine(CDTL3.testing and L["Shift-click: Stop preview"] or L["Shift-click: Preview with sample icons"], 1, 1, 1)
		GameTooltip:AddLine(L["Alt-click: Help"], 1, 1, 1)
		GameTooltip:AddLine(L["Drag: Reposition"], 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	btn:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			CDTL3:ToggleFrameLock()
		elseif IsShiftKeyDown and IsShiftKeyDown() then
			CDTL3:TogglePreview()
		elseif IsAltKeyDown and IsAltKeyDown() then	-- not Ctrl: on a Mac, Ctrl-click arrives as a right-click
			CDTL3:ChatCommand("help window")
		else
			CDTL3:ChatCommand("")
		end
	end)

	btn:SetScript("OnDragStart", function(s)
		s:SetScript("OnUpdate", function(s)
			local mx, my = Minimap:GetCenter()
			local px, py = GetCursorPosition()
			local sc = UIParent:GetEffectiveScale()
			local angle = math.deg(math.atan2(py / sc - my, px / sc - mx))
			CDTL3.db.global.minimapAngle = angle
			place(s)
		end)
	end)
	btn:SetScript("OnDragStop", function(s)
		s:SetScript("OnUpdate", nil)
	end)

	self.minimapBtn = btn
end

function CDTL3:OnEnable()	
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("GROUP_JOINED")
	self:RegisterEvent("GROUP_LEFT")
	self:BuildMinimapButton()
	--self:RegisterEvent("PLAYER_TALENT_UPDATE")
	--self:RegisterEvent("SPELLS_CHANGED")
	--self:RegisterEvent("ENCOUNTER_END")

	CDTL3:Cleanup()

	CDTL3:CreateLanes()
	CDTL3:CreateBarFrames()
	CDTL3:CreateReadyFrames()
	CDTL3:CreateHolders()
	
	private.CreateUnlockFrame()
	private.CreateDebugFrame()
	
	CDTL3:Print(string.format(L["Loaded version: %s"], CDTL3.version))
	CDTL3:Print(L["Type /cdtl3 or /cooldowntimeline3 for options"])
	
	CDTL3.tracking["manaTime"] = GetTime()
	CDTL3.tracking["manaPrevious"] = 0
	CDTL3.tracking["energyTimeCount"] = 2
	CDTL3.tracking["energyPrevious"] = 0
	
	C_Timer.After(5, function()
		CDTL3.currentFilter["default"] = "SPELLS"
		CDTL3.currentFilter["spells"] = CDTL3:GetAardvark("spells")
		CDTL3.currentFilter["items"] = CDTL3:GetAardvark("items")
		CDTL3.currentFilter["buffs"] = CDTL3:GetAardvark("buffs")
		CDTL3.currentFilter["debuffs"] = CDTL3:GetAardvark("debuffs")
		CDTL3.currentFilter["offensives"] = CDTL3:GetAardvark("offensives")
		CDTL3.currentFilter["petspells"] = CDTL3:GetAardvark("petspells")
		CDTL3.currentFilter["runes"] = CDTL3:GetAardvark("runes")
		CDTL3.currentFilter["customs"] = CDTL3:GetAardvark("customs")
		CDTL3.currentFilter["detected"] = CDTL3:GetAardvark("detected")

		--for t, c in pairs(CDTL3.currentFilter) do
			--CDTL3:Print("AARDVARK: "..tostring(t).." - "..tostring(c))
		--end

		CDTL3:GetCharacterData()

		CDTL3:ScanCurrentCooldowns(CDTL3.player["class"], CDTL3.player["race"])

		-- pick up auras the login full update had to skip (see UNIT_AURA)
		if CDTL3.retailAPI and CDTL3.enabled then
			CDTL3:UNIT_AURA("UNIT_AURA", "player")
		end

		-- Rune timers need a GetRuneCooldown-based rework before RUNE_POWER_UPDATE is registered again.
		--if CDTL3.player["class"] == "DEATHKNIGHT" then
			--self:RegisterEvent("RUNE_POWER_UPDATE")
		--end

		CDTL3:RefreshLane(1)
		CDTL3:RefreshLane(2)
		CDTL3:RefreshLane(3)
	end)
	
	-- After an update from anything older than noticeVersion the welcome window opens once, on
	-- every client (its text says what's new; the 3.1 combat timers block adds itself only where
	-- they run); a first run opens it everywhere, as before.
	local notice = CDTL3:IsNewerVersion()
	if CDTL3.Start and CDTL3.Start:TourDue() then
		-- a first install gets the three-step tour (Start.lua); what's new is for existing players
		C_Timer.After(10, function()
			CDTL3.Start:StartTour()
		end)
	elseif CDTL3.db.profile.global["firstRun"] or notice then
		C_Timer.After(10, function()
			private.CreateFirstRunFrame()
		end)
	end
end

-- /cdtl3 help: every subcommand, one line each (kept next to ChatCommand: add a line here with each new one)
private.helpLines = {
	{ "", L["open the settings window"] },
	{ "lanes", L["open the Lanes tab"] },
	{ "ready", L["open the Ready tab"] },
	{ "bars", L["open the Bar Frames tab"] },
	{ "filters", L["open the Filters tab"] },
	{ "profiles", L["open the Profiles tab"] },
	{ "lock / unlock", L["lock or unlock the frames for moving"] },
	{ "test", L["show test timers"] },
	{ "debug", L["toggle the debug window"] },
	{ "auras", L["report the player's auras as CDTL3 sees them (readable or hidden)"] },
	{ "oaf", L["report the spells whose cooldown starts when the effect is used"] },
	{ "combattimers [on|off]", L["show or switch the combat timers (Retail and Forever)"] },
	{ "minimap", L["show or hide the minimap button"] },
	{ "report", L["open a copyable bug-report box"] },
	{ "log", L["show the error log"] },
	{ "perf", L["show CPU, memory and frame counts"] },
	{ "tour", L["take the three-step tour again"] },
	{ "whatsnew", L["open the What's new window with the changelog"] },
	{ "help", L["show this list"] },
}

CDTL3.helpLines = private.helpLines	-- the Help tab lists the same commands (Start.lua)

function CDTL3:PrintHelp()
	CDTL3:Print(L["commands (/cdtl3 <command>):"])
	for _, l in ipairs(private.helpLines) do
		CDTL3:Print(string.format("  /cdtl3 %s - %s", l[1], l[2]))
	end
end

function CDTL3:ChatCommand(input)
    if not input or input:trim() == "" then
        LibStub("AceConfigDialog-3.0"):Open("CDTL3")
	elseif input:trim() == "lanes" then
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
		LibStub("AceConfigDialog-3.0"):SelectGroup("CDTL3", "lanes")
	elseif input:trim() == "ready" then
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
		LibStub("AceConfigDialog-3.0"):SelectGroup("CDTL3", "ready")
	elseif input:trim() == "bars" then
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
		LibStub("AceConfigDialog-3.0"):SelectGroup("CDTL3", "barFrames")
	elseif input:trim() == "filters" then
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
		LibStub("AceConfigDialog-3.0"):SelectGroup("CDTL3", "filters")
	elseif input:trim() == "profiles" then
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
		LibStub("AceConfigDialog-3.0"):SelectGroup("CDTL3", "profiles")
	elseif input:trim() == "lock" then
		-- lock / unlock set a state; ToggleFrameLock flips it, so only call it when needed
		if CDTL3.db.profile.global["unlockFrames"] then
			CDTL3:ToggleFrameLock()
		else
			CDTL3:Print(L["Frames are already locked"])
		end
	elseif input:trim() == "unlock" then
		if not CDTL3.db.profile.global["unlockFrames"] then
			CDTL3:ToggleFrameLock()
		else
			CDTL3:Print(L["Frames are already unlocked"])
		end
	elseif input:trim() == "test" then
		CDTL3:EnableTesting()
	elseif input:trim() == "debug" then
		CDTL3:ToggleDebug()
	elseif input:trim() == "help" or input:trim() == "?" then
		CDTL3:PrintHelp()
	elseif input:trim() == "help window" then
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
		LibStub("AceConfigDialog-3.0"):SelectGroup("CDTL3", "help")
	elseif input:trim() == "auras" then
		CDTL3:DiagnoseAuras()
	elseif input:trim() == "report" then
		CDTL3:ShowReport()	-- Diagnostics.lua
	elseif input:trim() == "log" then
		CDTL3:ShowLog()
	elseif input:trim() == "perf" then
		CDTL3:PrintPerf()
	elseif input:trim() == "tour" then
		-- the settings window would sit over the frames the tour points at
		LibStub("AceConfigDialog-3.0"):Close("CDTL3")
		if CDTL3.Start then
			CDTL3.Start:StartTour(true)
		end
	elseif input:trim() == "whatsnew" then
		CDTL3:ShowWhatsNew()
	elseif input:trim() == "minimap" then
		CDTL3.db.global.minimapHide = not CDTL3.db.global.minimapHide
		if CDTL3.minimapBtn then
			CDTL3.minimapBtn:SetShown(not CDTL3.db.global.minimapHide)
		end
		CDTL3:Print(CDTL3.db.global.minimapHide and L["Minimap button hidden"] or L["Minimap button shown"])
	elseif input:trim() == "oaf" then
		-- Diagnostic for "cooldown starts when the effect is used" spells (Nature's Swiftness etc.):
		-- prints every link of the chain so one paste shows which one is wrong on a live client.
		CDTL3:Print("OAF CHECK v" .. CDTL3.version .. " | built-in data: " .. #CDTL3.spellData .. " spells | detection on: " .. tostring(CDTL3.enabled))
		for _, s in pairs(CDTL3.db.profile.tables["spells"]) do
			local ok, flag = pcall(CDTL3.IsAuraFadeSpell, CDTL3, s["id"], s["name"])
			if s["oaf"] or (ok and flag) then
				CDTL3:Print(string.format("  saved: %s (id %s) saved-oaf=%s data-oaf=%s ignored=%s",
					tostring(s["name"]), tostring(s["id"]), tostring(s["oaf"]),
					tostring(ok and flag), tostring(s["ignored"])))
			end
		end
		local frames = 0
		for _, cd in pairs(CDTL3.cooldowns) do
			local d = cd.data
			if d and (d["type"] == "spells" or d["type"] == "petspells") and d["oaf"] then
				frames = frames + 1
				local okS, start, duration, enabled = pcall(CDTL3.GetSpellCooldown, CDTL3, d["id"])
				local okA, aura = pcall(CDTL3.AuraExists, CDTL3, "player", d["name"])
				CDTL3:Print(string.format("  frame: %s held=%s curCD=%s game-cd=%s/%s enabled=%s aura=%s",
					tostring(d["name"]), tostring(d["oafHeld"]),
					tostring(d["currentCD"] and math.floor(d["currentCD"] + 0.5)),
					tostring(okS and start), tostring(okS and duration), tostring(okS and enabled),
					(okA and aura) and "UP" or "down"))
			end
		end
		CDTL3:Print("  live oaf frames: " .. frames .. " | run once with the buff up and once after using it, paste both")
	elseif input:trim():match("^combattimers") then
		-- combat timers (CombatTimers.lua): status, or "on" / "off"
		local arg = input:trim():sub(13):trim():lower()
		local CT = CDTL3.CombatTimers
		if not (CT and CT:Available()) then
			CDTL3:Print(L["Combat timers: not available on this client"])
		else
			if arg == "on" then
				CT:SetEnabled(true)
			elseif arg == "off" then
				CT:SetEnabled(false)
			end
			CDTL3:Print(CT:StatusLine())
		end
    end
end

private.CreateDebugFrame = function()
	local frameName = "CDTL3_Debug_Frame"
	local f = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	
	f:ClearAllPoints()
	f:SetPoint("TOP", 300, -75)
	f:SetSize(300, 200)
	
	-- BACKGROUND
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(true)
	f.bg:SetColorTexture( 
		CDTL3.colors["db"]["r"],
		CDTL3.colors["db"]["g"],
		CDTL3.colors["db"]["b"],
		CDTL3.colors["db"]["a"]
	)
	
	f.text = f:CreateFontString(nil,"ARTWORK")
	f.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.text:SetShadowColor( 0, 0, 0, 1 )
	f.text:SetShadowOffset(1.5, -1)
	f.text:SetText("CDTL3: Debug Enabled")
	f.text:SetPoint("TOP", 0, -5)
	
	f.t1 = f:CreateFontString(nil,"ARTWORK")
	f.t1:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.t1:SetShadowColor( 0, 0, 0, 1 )
	f.t1:SetShadowOffset(1.5, -1)
	f.t1:SetText("Text 1")
	f.t1:SetPoint("TOP", 0, -30)
	
	f.t2 = f:CreateFontString(nil,"ARTWORK")
	f.t2:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.t2:SetShadowColor( 0, 0, 0, 1 )
	f.t2:SetShadowOffset(1.5, -1)
	f.t2:SetText("Text 2")
	f.t2:SetPoint("TOP", 0, -60)
	
	f.t3 = f:CreateFontString(nil,"ARTWORK")
	f.t3:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.t3:SetShadowColor( 0, 0, 0, 1 )
	f.t3:SetShadowOffset(1.5, -1)
	f.t3:SetText("Text 3")
	f.t3:SetPoint("TOP", 0, -90)
	
	local b = CreateFrame("Button", frameName.."_B_Reload", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(80 ,25) -- width, height
	b:SetText("Reload")
	b:SetPoint("TOPLEFT", 5, -25)
	b:SetScript("OnClick", function()
		ReloadUI()
	end)
	
	local b = CreateFrame("Button", frameName.."_B_Options", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(80 ,25) -- width, height
	b:SetText("Options")
	b:SetPoint("TOPLEFT", 5, -50)
	b:SetScript("OnClick", function()
		-- Settings.OpenToCategory("CDTL3") errors on Midnight / Forever (string category)
		LibStub("AceConfigDialog-3.0"):Open("CDTL3")
	end)
	
	local b = CreateFrame("Button", frameName.."_B_UnLock", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(80 ,25) -- width, height
	b:SetText("(Un)Lock")
	b:SetPoint("TOPLEFT", 5, -75)
	b:SetScript("OnClick", function()
		CDTL3:ToggleFrameLock()
	end)
	
	local b = CreateFrame("Button", frameName.."_B_TestCode1", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(80 ,25) -- width, height
	b:SetText("TestCode1")
	b:SetPoint("TOPLEFT", 5, -100)
	b:SetScript("OnClick", function()
		-- TEST CODE 1
	end)
		
	local b = CreateFrame("Button", frameName.."_B_TestCode2", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(80 ,25) -- width, height
	b:SetText("TestCode2")
	b:SetPoint("TOPLEFT", 5, -125)
	b:SetScript("OnClick", function()
		-- TEST CODE 2
	end)
	
	-- ON UPDATE
	f:HookScript("OnUpdate", function(self, elapsed)
		
	end)
		
	-- DRAG AND DROP MOVEMENT
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	
	if not CDTL3.db.profile.global["debugMode"] then
		f:Hide()
	end
	
	CDTL3.debugFrame = f
end

-- /cdtl3 whatsnew: the welcome window on demand. Opening it changes nothing; only its No and
-- Take the tour buttons mark it seen, as when it opens by itself.
function CDTL3:ShowWhatsNew()
	return private.CreateFirstRunFrame()
end

private.CreateFirstRunFrame = function()
	-- made once per session; opening it again shows the same window
	if private.firstRunFrame then
		private.firstRunFrame:Show()
		return private.firstRunFrame
	end
	local name = "CDTL3_Firstrun"
	local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	private.firstRunFrame = f
	f:SetPoint("TOP", 0, -150)
	f:SetSize(550, 300)
	
	-- BACKGROUND
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(true)
	f.bg:SetColorTexture( 0.1, 0.1, 0.1, 0.9 )
	
	-- HEADING TEXT
	f.text = f:CreateFontString(nil,"ARTWORK")
	f.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 20)
	f.text:SetShadowColor( 0, 0, 0, 1 )
	f.text:SetShadowOffset(1.5, -1)
	f.text:SetText("|cFF54a3ffCDTL3|r - |cffffffffv"..CDTL3.version)
	f.text:SetPoint("TOP", 0, -20)

	-- DRAG AND DROP MOVEMENT
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	
	-- SCROLL FRAME
	local sf = CreateFrame("ScrollFrame", "CDTL3_Firstrun_Scroll", CDTL3_Firstrun, "UIPanelScrollFrameTemplate")
	sf:SetPoint("LEFT", 16, 0)
	sf:SetPoint("RIGHT", -32, 0)
	sf:SetPoint("TOP", 0, -55)
	sf:SetPoint("BOTTOM", 0, 70)
	
	-- EDIT BOX
	local ef = CreateFrame("EditBox", name.."_Edit", CDTL3_Firstrun_Scroll)
	ef:SetSize(sf:GetSize())
	ef:SetMultiLine(true)
	ef:SetAutoFocus(false)
	ef:SetFontObject("GameFontWhite")
	
	-- TEXT FOR THE BOX
	local text = ""
	text = text.."Found a problem or have a suggestion? Open an issue on GitHub (or leave a comment on CurseForge):\n\n"
	text = text.."|cFF54a3ff"..CDTL3.supportlink.."|r\n\n"

	text = text..CDTL3:GetSpecialMessage()
	text = text..CDTL3:GetChangeLog()

	ef:SetText(text)
	
	sf:SetScrollChild(ef)

	-- BORDER
	local border = CreateFrame("Frame", "CDTL3_Firstrun_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	border:SetParent(f)
	local s = {
		style = "CDTL3 Shadow",
		color = { r = 0, g = 0, b = 0, a = 0.25 },
		size = 5,
		padding = 5,
		inset = 0,
	}
	CDTL3:SetBorder(border, s)
	border:Show()
	border:SetFrameLevel(f:GetFrameLevel() + 1)
	
	-- RESIZABLE
	f:SetResizable(true)
	local rb = CreateFrame("Button", name.."_Resize", CDTL3_Firstrun)
	rb:SetPoint("BOTTOMRIGHT", -6, 7)
	rb:SetSize(16, 16)
	rb:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	rb:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	rb:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	rb:SetScript("OnMouseDown", function(self, button)
		if button == "LeftButton" then
			f:StartSizing("BOTTOMRIGHT")
			self:GetHighlightTexture():Hide()
		end
	end)
	rb:SetScript("OnMouseUp", function(self, button)
		f:StopMovingOrSizing()
		self:GetHighlightTexture():Show()
		ef:SetWidth(sf:GetWidth())
	end)

	-- SHOW AGAIN TEXT
	f.text1 = f:CreateFontString(nil,"ARTWORK")
	f.text1:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.text1:SetShadowColor( 0, 0, 0, 1 )
	f.text1:SetShadowOffset(1.5, -1)
	f.text1:SetText("Show this message next login/reload?")
	f.text1:SetPoint("BOTTOM", 0, 40)

	local b1 = CreateFrame("Button", name.."_Yes", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b1:SetSize(80 ,25)
	b1:SetText("Yes")
	b1:SetPoint("BOTTOM", -45, 8)
	b1:SetScript("OnClick", function()
		f:Hide()
	end)
	
	local b2 = CreateFrame("Button", name.."_No", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b2:SetSize(80 ,25)
	b2:SetText("No")
	b2:SetPoint("BOTTOM", 45, 8)
	b2:SetScript("OnClick", function()
		CDTL3.db.profile.global["firstRun"] = false
		CDTL3.db.profile.global["previousVersion"] = CDTL3.version
		f:Hide()
	end)

	-- Take the tour: closes the window the way No does (seen), then runs the three-step tour
	local b3 = CreateFrame("Button", name.."_Tour", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b3:SetSize(110 ,25)
	b3:SetText(L["Take the tour"])
	b3:SetPoint("BOTTOM", 150, 8)
	b3:SetScript("OnClick", function()
		CDTL3.db.profile.global["firstRun"] = false
		CDTL3.db.profile.global["previousVersion"] = CDTL3.version
		f:Hide()
		if CDTL3.Start then
			CDTL3.Start:StartTour(true)
		end
	end)

	f:SetFrameStrata("DIALOG")
	f:Show()
	return f
end

-- The "Frames currently unlocked" box. Until frames have been locked once (db.global.lockedOnce,
-- set by ToggleFrameLock, account-wide) it says what to do: drag the frames, then click Lock, and,
-- where CDTL3's frames are in Edit Mode (LibEditMode loaded), that Edit Mode can place them too.
-- After that first lock it keeps its plain wording. Set when the box is made and each time it shows.
private.UnlockBoxText = function(f)
	local lockedOnce = CDTL3.db and CDTL3.db.global and CDTL3.db.global.lockedOnce
	if lockedOnce then
		f.text:SetText("CDTL3\nFrames currently unlocked\nDrag and drop to move")
		f:SetSize(180, 70)
	elseif LibStub("LibEditMode", true) then
		f.text:SetText("CDTL3\nFrames currently unlocked\nDrag the frames where you want them,\nthen click Lock.\nEdit Mode can place them too.")
		f:SetSize(230, 110)
	else
		f.text:SetText("CDTL3\nFrames currently unlocked\nDrag the frames where you want them,\nthen click Lock.")
		f:SetSize(230, 96)
	end
end

private.CreateUnlockFrame = function()
	local f = CreateFrame("Frame", "CDTL3_Unlock_Frame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	
	f:ClearAllPoints()
	f:SetPoint("TOP", 0, -70)
	f:SetSize(180, 70)
	
	-- BACKGROUND
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(true)
	f.bg:SetColorTexture( 
		CDTL3.colors["db"]["r"],
		CDTL3.colors["db"]["g"],
		CDTL3.colors["db"]["b"],
		CDTL3.colors["db"]["a"]
	)
	
	-- BORDER
	f.bd = CreateFrame("Frame", "CDTL3_Unlock_Frame_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.bd:SetParent(f)
	CDTL3:SetBorder(f.bd, {
					style = "CDTL3 Shadow",
					color = { r = 0, g = 0, b = 0, a = 0.25 },
					size = 5,
					padding = 5,
					inset = 0,
				})
	f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
	
	-- TEXT
	f.text = f:CreateFontString(nil,"ARTWORK")
	f.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.text:SetShadowColor( 0, 0, 0, 1 )
	f.text:SetShadowOffset(1.5, -1)
	f.text:SetPoint("TOP", 0, -5)
	private.UnlockBoxText(f)
	f:SetScript("OnShow", private.UnlockBoxText)

	local b = CreateFrame("Button", "CDTL3_Unlock_Frame_Button", f, "UIPanelButtonTemplate", BackdropTemplateMixin and "BackdropTemplate" or nil)
	b:SetSize(80 ,25) -- width, height
	b:SetText("Lock")
	b:SetPoint("BOTTOM", 0, 4)
	b:SetScript("OnClick", function()
		-- always locks: a toggle here unlocked frames that were already locked
		if CDTL3.db.profile.global["unlockFrames"] then
			CDTL3:ToggleFrameLock()
		end
		f:Hide()
	end)
	
	-- ON UPDATE
	f:HookScript("OnUpdate", function(self, elapsed)
		
	end)
	
	if not CDTL3.db.profile.global["unlockFrames"] then
		f:Hide()
	end
	
	CDTL3.unlockFrame = f
end

function CDTL3:EnableTesting()
	if CDTL3.testing then
		--CDTL3:Print("Already Testing")
	else
		CDTL3.testing = true
		CDTL3:CreateTestingFrame()
	end
end

-- Preview with sample icons (Global tab button, minimap Shift-click): test mode plus one set of
-- sample icons from the Test Panel's settings. Stop preview clears them (the panel's Clear) and
-- closes the panel. Test mode shows the frames whatever Hide out of combat or Show say.
function CDTL3:StartPreview()
	if not CDTL3.testing then
		CDTL3:EnableTesting()
	end
	CDTL3:GenerateTestCooldowns()
	CDTL3:ApplyCombatVisibility()
end

function CDTL3:StopPreview()
	local f = CDTL3.testingFrame
	CDTL3.testingFrame = nil
	if f then
		f:Hide()	-- AceGUI's frame closes on hide: OnClose releases it and ends test mode
		if CDTL3.testing then
			CDTL3.GUI:Release(f)
		end
	end
	CDTL3.testing = false

	for _, cd in ipairs(CDTL3.cooldowns) do
		if cd.data["type"] == "testing" and cd.icon:GetParent():GetName() ~= "CDTL3_Active_Icon_Holding" then
			CDTL3:SendToHolding(cd)
			CDTL3:SendToBarHolding(cd)
		end
	end
	CDTL3:ApplyCombatVisibility()
end

function CDTL3:TogglePreview()
	if CDTL3.testing then
		CDTL3:StopPreview()
	else
		CDTL3:StartPreview()
	end
	LibStub("AceConfigRegistry-3.0"):NotifyChange("CDTL3")
end

function CDTL3:CreateTestingFrame()
	if CDTL3.testing then
		--local name = "CDTL3_Testing_Frame"
		local testingType = CDTL3.db.profile.global["testingType"]
		local testingNumber = CDTL3.db.profile.global["testingNumber"]
		local testingMinTime = CDTL3.db.profile.global["testingMinTime"]
		local testingMaxTime = CDTL3.db.profile.global["testingMaxTime"]
		local testingLoop = CDTL3.db.profile.global["testingLoop"]

		local f = CDTL3.GUI:Create("Frame")
		f:SetTitle("|cFF54a3ffCDTL3|r - |cffffffffTesting|r")
		f:SetLayout("Flow")
		f:SetWidth(200)
		f:SetHeight(450)
		f:SetAutoAdjustHeight(true)
		f:SetPoint("LEFT", 20, 0)
		f:SetCallback("OnClose", function(widget)
				CDTL3.GUI:Release(widget)
				CDTL3.testing = false
				CDTL3.testingFrame = nil
				LibStub("AceConfigRegistry-3.0"):NotifyChange("CDTL3")	-- the Preview button's label
			end)
		CDTL3.testingFrame = f
		
		local lblMain = CDTL3.GUI:Create("Label")
		lblMain:SetText("Here you can create a series of test Cooldowns to assist with configuration\n\n")
		lblMain:SetFullWidth(true)
		f:AddChild(lblMain)

		local ddType = CDTL3.GUI:Create("Dropdown")
		ddType:SetLabel("Type of Cooldown to test")
		ddType:SetFullWidth(true)
		ddType:AddItem("spells", "Spells")
		ddType:AddItem("items", "Items")
		ddType:AddItem("buffs", "Buffs")
		ddType:AddItem("debuffs", "Debuffs")
		ddType:AddItem("offensives", "Offensives")
		ddType:AddItem("petspells", "Pet Spells")
		if CDTL3.player["class"] == "DEATHKNIGHT" then
			ddType:AddItem("runes", "Runes")
		end

		ddType:SetValue(testingType)
		ddType:SetCallback("OnValueChanged", function(widget)
			CDTL3.db.profile.global["testingType"] = widget["value"]
		end)
		f:AddChild(ddType)

				local lblSpacer01 = CDTL3.GUI:Create("Label")
				lblSpacer01:SetText("\n")
				f:AddChild(lblSpacer01)

		local sNumber = CDTL3.GUI:Create("Slider")
		sNumber:SetLabel("Number of Cooldowns to create")
		sNumber:SetFullWidth(true)
		sNumber:SetSliderValues(1, 20, 1)
		sNumber:SetValue(testingNumber)
		sNumber:SetCallback("OnMouseUp", function(widget)
			--CDTL3:Print("sNumber: "..tostring(widget["value"]))
			CDTL3.db.profile.global["testingNumber"] = widget["value"]
		end)
		f:AddChild(sNumber)

				local lblSpacer02 = CDTL3.GUI:Create("Label")
				lblSpacer02:SetText("\n")
				f:AddChild(lblSpacer02)

		local sMinTime = CDTL3.GUI:Create("Slider")
		sMinTime:SetLabel("First Cooldown Duration")
		sMinTime:SetFullWidth(true)
		sMinTime:SetSliderValues(1, 600, 1)
		sMinTime:SetValue(testingMinTime)
		sMinTime:SetCallback("OnMouseUp", function(widget)
			--CDTL3:Print("sMinTime: "..tostring(widget["value"]))
			CDTL3.db.profile.global["testingMinTime"] = widget["value"]
		end)
		f:AddChild(sMinTime)

				local lblSpacer03 = CDTL3.GUI:Create("Label")
				lblSpacer03:SetText("\n")
				f:AddChild(lblSpacer03)

		local sMaxTime = CDTL3.GUI:Create("Slider")
		sMaxTime:SetLabel("Last Cooldown Duration")
		sMaxTime:SetFullWidth(true)
		sMaxTime:SetSliderValues(1, 600, 1)
		sMaxTime:SetValue(testingMaxTime)
		sMaxTime:SetCallback("OnMouseUp", function(widget)
			--CDTL3:Print("sMaxTime: "..tostring(widget["value"]))
			CDTL3.db.profile.global["testingMaxTime"] = widget["value"]
		end)
		f:AddChild(sMaxTime)

				local lblSpacer04 = CDTL3.GUI:Create("Label")
				lblSpacer04:SetText("\n")
				f:AddChild(lblSpacer04)

		local cbLoop = CDTL3.GUI:Create("CheckBox")
		cbLoop:SetLabel("Loop")
		cbLoop:SetFullWidth(true)
		cbLoop:SetValue(testingLoop)
		cbLoop:SetCallback("OnValueChanged", function(widget)
			--CDTL3:Print("cbLoop: "..tostring(widget:GetValue()))
			CDTL3.db.profile.global["testingLoop"] = widget:GetValue()
		end)
		f:AddChild(cbLoop)

				local lblSpacer05 = CDTL3.GUI:Create("Label")
				lblSpacer05:SetText("\n")
				f:AddChild(lblSpacer05)

		local btnCreate = CDTL3.GUI:Create("Button")
		--btnCreate:SetWidth(170)
		btnCreate:SetText("Create")
		btnCreate:SetFullWidth(true)
		btnCreate:SetCallback("OnClick", function()
				--print("Click!")
				CDTL3:GenerateTestCooldowns()
			end)
		f:AddChild(btnCreate)

		local btnClear = CDTL3.GUI:Create("Button")
		--btnCreate:SetWidth(170)
		btnClear:SetText("Clear")
		btnClear:SetFullWidth(true)
		btnClear:SetCallback("OnClick", function()
				--print("Click!")
				for _, cd in ipairs(CDTL3.cooldowns) do
					if cd.data["type"] == "testing" then
						if cd.icon:GetParent():GetName() ~= "CDTL3_Active_Icon_Holding" then
							--CDTL3:Print(tostring(cd:GetName()).. " - "..tostring(cd.data["name"]))
							CDTL3:SendToHolding(cd)
							CDTL3:SendToBarHolding(cd)
						end
					end
				end
			end)
		f:AddChild(btnClear)

		if CDTL3.db.profile.global["debugMode"] then
			CDTL3:Print("Created Testing Frame")
		end
	end
end

-- A buff/debuff landed on the player. Fed by the combat log (SPELL_AURA_APPLIED) where
-- addons get it, and by UNIT_AURA on retail-API clients (WoW: Forever closes the combat
-- log, so UNIT_AURA is its only source). Both can report the same application, so a
-- repeat of the same aura within half a second is ignored. isScan: the aura was already
-- there (login / zoning / combat-end rescan), so custom aura triggers don't start.
function CDTL3:OnPlayerAuraApplied(spellID, spellName, auraType, sourceIsPlayer, isScan)
	local key = auraType..":"..tostring(spellName)
	local now = GetTime()
	if CDTL3.recentAuras[key] and now - CDTL3.recentAuras[key] < 0.5 then
		return
	end
	CDTL3.recentAuras[key] = now

	local validSource = false
	if sourceIsPlayer then
		validSource = true
	else
		if auraType == "buffs" and not CDTL3.db.profile.global["buffs"]["onlyPlayer"] then
			validSource = true
		end
		
		if auraType == "debuffs" and not CDTL3.db.profile.global["debuffs"]["onlyPlayer"] then
			validSource = true
		end
	end
	
	if validSource then
		-- CHECK FOR TRIGGERS
		--local spellName, _, _ = CDTL3:GetSpellInfo(spellID)
		--local s = CDTL3:GetSpellSettings(spellName, "customs")
		-- a scan sighting is an aura that was already there, not a new application
		local s = not isScan and CDTL3:GetCustomSpellSettings(spellName, "aura")
		if s then
			--if s["triggerType"] and s["triggerType"] == "aura" then
				if CDTL3.db.profile.global["debugMode"] then
					CDTL3:Print("CUSTOM_FOUND: aura - "..spellName)
				end

				if not s["ignored"] then
					local ef = CDTL3:GetExistingCooldown(s["name"], "customs")
					if ef then
						CDTL3:SendToLane(ef)
						CDTL3:SendToBarFrame(ef)
						--+CDTL3:CheckEdgeCases(spellName)
					else
						if CDTL3.db.profile.global["customs"]["enabled"] then
							CDTL3:CreateCooldown(CDTL3:GetUID(),"customs" , s)
							CDTL3:CheckEdgeCases(spellName)
							
							if CDTL3:IsUsedBy("customs", s["id"]) then
								--CDTL3:Print("USEDBY MATCH: "..s["id"])
							else
								CDTL3:AddUsedBy("customs", s["id"], CDTL3.player["guid"])
							end
						end
					end
				end
			--end
		else
			
		end

		local s = CDTL3:GetSpellSettings(spellName, auraType)
		if s then
			-- List it for this character: entries saved before the character was known
			-- (login), or by another character on this profile, weren't marked as theirs
			-- and so never showed up in Filters.
			if CDTL3.player["guid"] and not CDTL3:IsUsedBy(auraType, s["id"]) then
				CDTL3:AddUsedBy(auraType, s["id"], CDTL3.player["guid"])
			end

			-- a buff pulled from the Cooldown Manager before it was ever seen learns its length now
			if s["cdmPulled"] and (s["bCD"] or 0) <= 0 then
				local seen = CDTL3:AuraExists("player", spellName)
				if seen and (seen["bCD"] or 0) > 0 then
					s["bCD"] = seen["bCD"]
				end
			end

			if not s["ignored"] then
				local ef = CDTL3:GetExistingCooldown(s["name"], auraType)
				if ef then
					CDTL3:SendToLane(ef)
					CDTL3:SendToBarFrame(ef)
				elseif CDTL3.db.profile.global[auraType]["enabled"] then
					CDTL3:CreateCooldown(CDTL3:GetUID(), auraType, s)
				end
			end
		else
			s = CDTL3:AuraExists("player", spellName)
			if s then
				CDTL3:ApplyEntryDefaults(s, auraType)
				s["link"] = CDTL3:GetSpellLink(spellID)
				s["ignored"] = CDTL3:IgnoredByDefault(auraType, s["bCD"])

				CDTL3:SaveNewEntry(s, auraType)
			end
		end
	end
end

-- auraInstanceID and expiry of an aura; each is nil if secret (+ 0 forces the throw).
-- CDTL3.auraExpiry maps id -> expiry, or true for "seen, expiry unknown".
local function AuraKey(aura)
	local idOK, id = pcall(function()
		return aura.auraInstanceID + 0
	end)
	if not idOK then
		return nil
	end

	local expiryOK, expiry = pcall(function()
		return aura.expirationTime + 0
	end)

	return id, expiryOK and expiry or nil
end

-- Player auras from UNIT_AURA (see OnPlayerAuraApplied). Covers what the combat log's
-- SPELL_AURA_APPLIED would, plus two cases it never reported as "applied":
--  * a recast of a buff you already have arrives as an UPDATE, not an add
--  * on login, /reload or zoning, buffs already on you arrive only as a FULL update
-- Aura data can be SECRET (12.1 rules: combat, encounters, M+, PvP): the accessors and
-- the field reads/compares all run inside pcalls, and secret auras are skipped.
function CDTL3:UNIT_AURA(_, unitTarget, updateInfo)
	if unitTarget ~= "player" then
		return
	end

	CDTL3.unitAuraEvents = (CDTL3.unitAuraEvents or 0) + 1

	-- The login full update can arrive before the character is known (GetPlayerInfoByGUID
	-- isn't ready yet). Anything saved then would have no owner and never be listed, so
	-- wait: OnEnable rescans the player's auras once GetCharacterData has succeeded.
	if not CDTL3.player["guid"] then
		CDTL3:GetCharacterData()
		if not CDTL3.player["guid"] then
			return
		end
	end

	-- The event payload itself can be secret too (even isFullUpdate), so every read of
	-- it happens inside this pcall. Whatever was collected before a secret read stops
	-- the scan is still processed below.
	--
	-- Only a real application counts as "applied" (it restarts timers via SendToLane):
	--  * added auras
	--  * updated auras whose expiry moved later (a recast); stack / value / tooltip
	--    updates must not restart buff timers or custom aura triggers (ICDs)
	--  * on a full update (login, /reload, zoning, the combat-end rescan) only auras not
	--    seen before or refreshed meanwhile. These are flagged as scan sightings: they
	--    can add or restore buff entries but never start a custom aura trigger.
	local auras, scanned = {}, {}
	local known = CDTL3.auraExpiry
	pcall(function()
		if not updateInfo or updateInfo.isFullUpdate then
			local fresh = {}
			for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
				for i = 1, 40 do
					local aura = C_UnitAuras.GetAuraDataByIndex("player", i, filter)
					if not aura then
						break
					end

					local id, expiry = AuraKey(aura)
					if id then
						local old = known[id]
						fresh[id] = expiry or old or true
						if not old or (expiry and old ~= true and expiry > old + 0.5) then
							table.insert(auras, aura)
							scanned[aura] = true
						end
					end
				end
			end
			CDTL3.auraExpiry = fresh
		else
			for _, aura in ipairs(updateInfo.addedAuras or {}) do
				local id, expiry = AuraKey(aura)
				if id then
					known[id] = expiry or true
				end
				table.insert(auras, aura)
			end

			for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs or {}) do
				local ok, aura = pcall(C_UnitAuras.GetAuraDataByAuraInstanceID, "player", auraInstanceID)
				if ok and aura then
					local id, expiry = AuraKey(aura)
					if id and expiry then
						local old = known[id]
						known[id] = expiry
						if not old then
							-- first readable sighting (it was added while auras were secret)
							table.insert(auras, aura)
							scanned[aura] = true
						elseif old ~= true and expiry > old + 0.5 then
							table.insert(auras, aura)
						end
					end
				end
			end

			for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs or {}) do
				known[auraInstanceID] = nil
			end
		end
	end)

	for _, aura in ipairs(auras) do
		local ok, spellID, spellName, auraType = pcall(function()
			if aura.spellId > 0 and aura.name ~= "" then
				return aura.spellId, aura.name, aura.isHarmful and "debuffs" or "buffs"
			end
		end)

		if ok and spellID then
			local sourceOK, sourceIsPlayer = pcall(function()
				return aura.sourceUnit == "player"
			end)

			if CDTL3.db.profile.global["debugMode"] then
				CDTL3:Print("AURA ADDED: "..spellID.." - "..spellName.." - "..auraType.." - from player: "..tostring(sourceOK and sourceIsPlayer))
			end

			CDTL3:OnPlayerAuraApplied(spellID, spellName, auraType, sourceOK and sourceIsPlayer, scanned[aura])
		end
	end
end

-- /cdtl3 auras: read-only report of what CDTL3 can see of the player's auras and what it
-- has saved for each, to pin down why a buff isn't detected (detection off, no UNIT_AURA
-- events, secret aura data, or a saved entry that is ignored / not marked as yours).
-- out(line) gets each line (/cdtl3 report collects them); without it they go to chat.
function CDTL3:DiagnoseAuras(out)
	out = out or function(line)
		CDTL3:Print(line)
	end
	local g = CDTL3.db.profile.global
	out("AURA CHECK v"..CDTL3.version.." | detection on: "..tostring(CDTL3.enabled)
		.." | UNIT_AURA events: "..tostring(CDTL3.unitAuraEvents or 0)
		.." | combat log: "..tostring(CDTL3.combatLogRegistered))
	out("guid: "..tostring(CDTL3.player["guid"])
		.." | buffs enabled: "..tostring(g["buffs"]["enabled"])
		.." | only mine: "..tostring(g["buffs"]["onlyPlayer"])
		.." | ignore over: "..tostring(g["buffs"]["ignoreThreshold"]).."s"
		.." | default lane: "..tostring(g["buffs"]["defaultLane"]))

	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		local t = (filter == "HELPFUL") and "buffs" or "debuffs"
		for i = 1, 40 do
			local readOK, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, filter)
			if not readOK then
				out(t.." #"..i..": can't read auras right now (secret)")
				break
			end
			if not aura then
				break
			end

			local ok, line = pcall(function()
				if not (aura.spellId > 0) then
					return nil
				end

				local text = string.format("%s #%d: %s (%d) from %s, %ds", t, i, aura.name, aura.spellId,
					tostring(aura.sourceUnit), math.floor(aura.duration or 0))

				local s = CDTL3:GetSpellSettings(aura.name, t)
				if s then
					text = text.." -> saved: ignored="..tostring(s["ignored"]).." enabled="..tostring(s["enabled"])
						.." lane="..tostring(s["lane"]).." yours="..tostring(CDTL3:IsUsedBy(t, s["id"]))
						.." savedID="..tostring(s["id"])
				else
					text = text.." -> not saved"
				end

				if CDTL3:GetCustomSpellSettings(aura.name, "aura") then
					text = text.." (also a custom aura trigger)"
				end

				return text
			end)

			-- a line built from a hidden field is hidden too: it's left out
			if ok and line and not (issecretvalue and issecretvalue(line)) then
				out(line)
			else
				out(t.." #"..i..": details hidden (secret)")
			end
		end
	end
end

-- Spell school bitmask (combat log) -> the schoolColors key; multi-school -> Other
local SCHOOL_NAMES = { [1] = "Physical", [2] = "Holy", [4] = "Fire", [8] = "Nature", [16] = "Frost", [32] = "Shadow", [64] = "Arcane" }
CDTL3.spellSchools = {}

-- The combat log is the only place a spell's school is exposed. Remember it per spell name
-- (saved entries and live bars are matched by name) and apply it once when it's first seen.
function CDTL3:RecordSpellSchool(spellName, schoolMask)
	local school = SCHOOL_NAMES[schoolMask] or "Other"
	if not spellName or CDTL3.spellSchools[spellName] == school then
		return
	end
	CDTL3.spellSchools[spellName] = school

	for _, entries in pairs(CDTL3.db.profile.tables) do
		for _, e in pairs(entries) do
			if e["name"] == spellName then
				e["school"] = school
			end
		end
	end

	local changed = false
	for _, cd in pairs(CDTL3.cooldowns) do
		if cd.data["name"] == spellName then
			cd.data["school"] = school
			changed = true
		end
	end
	if changed then
		CDTL3:RefreshAllBars()
	end
end

function CDTL3:COMBAT_LOG_EVENT_UNFILTERED()
	local _, subevent, _, sourceGUID, sourceName, _, _, destGUID, destName, _, _ = GetCombatLogEventInfo()

	if sourceGUID == CDTL3.player["guid"] and (subevent == "SPELL_CAST_SUCCESS" or subevent == "SPELL_AURA_APPLIED") then
		local _, spellName, spellSchool = select(12, GetCombatLogEventInfo())
		CDTL3:RecordSpellSchool(spellName, spellSchool)
	end

	if subevent == "SPELL_AURA_APPLIED" then
		if sourceGUID == CDTL3.player["guid"] or destGUID == CDTL3.player["guid"] then
			local spellID, spellName, _, auraType, _, _, _, _, _, _, _, _, _ = select(12, GetCombatLogEventInfo())
			auraType = auraType:lower().."s"
			
			--CDTL3:Print(destGUID)
			
			if CDTL3.db.profile.global["debugMode"] then
				CDTL3:Print("AURA APPLIED: "..spellID.." - "..spellName.." - "..auraType.." - "..tostring(sourceName).." - "..destName)
			end
			
			-- PLAYER AURAS
			if destGUID == CDTL3.player["guid"] then
				CDTL3:OnPlayerAuraApplied(spellID, spellName, auraType, sourceGUID == CDTL3.player["guid"])
			
			-- OFFENSIVE AURAS
			else
				local s = CDTL3:GetSpellSettings(spellName, "offensives")
				if s then
					if not s["ignored"] then
						local ef = CDTL3:GetExistingCooldown(s["name"], "offensives", destGUID)
						if ef then
							CDTL3:SendToLane(ef)
							CDTL3:SendToBarFrame(ef)
							
							ef.data["currentCD"] = ef.data["baseCD"]
							ef.data["targetID"] = destGUID
							ef.data["targetName"] = destName
						else
							local rcd = CDTL3:RecycleOffensiveCD()
							if rcd then
								rcd.data["id"] = s["id"]
								rcd.data["name"] = s["name"]
								--rcd.data["rank"] = s["rank"]
								rcd.data["desc"] = s["desc"]
								rcd.data["icon"] = s["icon"]
								
								-- copy the entry's flags ("" is truthy in Lua, so the old
								-- ignored = "" hid every recycled offensive icon)
								rcd.data["ignored"] = s["ignored"]
								rcd.data["highlight"] = s["highlight"]
								rcd.data["enabled"] = s["enabled"]
								rcd.data["link"] = s["link"]
								
								rcd.data["lane"] = s["lane"]
								rcd.data["barFrame"] = s["barFrame"]
								rcd.data["readyFrame"] = s["readyFrame"]
								
								rcd.data["baseCD"] = s["bCD"] / 1000
								rcd.data["currentCD"] = s["bCD"] / 1000
								
								rcd.icon.icon = rcd.data["icon"]
								rcd.icon.name = rcd.data["name"]
								--rcd.icon.rank = rcd.data["rank"]
								rcd.icon.lane = rcd.data["lane"]
								
								rcd.data["targetID"] = destGUID
								rcd.data["targetName"] = destName
								
								CDTL3:SendToLane(rcd)
								CDTL3:SendToBarFrame(rcd)
							else
								if CDTL3.db.profile.global["offensives"]["enabled"] then
									local ncd = CDTL3:CreateCooldown(CDTL3:GetUID(),"offensives" , s)
									
									ncd.data["targetID"] = destGUID
									ncd.data["targetName"] = destName
									
									if not CDTL3:IsUsedBy("offensives", s["id"]) then
										CDTL3:AddUsedBy("offensives", s["id"], CDTL3.player["guid"])
									end
								end
							end
						end
					end
				else
					local spellName, icon, originalIcon = CDTL3:GetSpellInfo(spellID)
					
					-- no ignore check: an offensive's length is only known once it lands
					local s = CDTL3:ApplyEntryDefaults({
						id = spellID,
						bCD = 0,
						name = spellName,
						type = "offensives",
						icon = icon,
					}, "offensives")
					s["link"] = CDTL3:GetSpellLink(spellID)
					
					table.insert(CDTL3.db.profile.tables["offensives"], s)
										
					if CDTL3.db.profile.global["offensives"]["enabled"] then
						--s["targetID"] = destGUID
						--s["targetName"] = destName
						
						local ncd = CDTL3:CreateCooldown(CDTL3:GetUID(),"offensives" , s)
						
						ncd.data["targetID"] = destGUID
						ncd.data["targetName"] = destName
					end
				end
			end
		end
	elseif subevent == "SPELL_AURA_REFRESH" then
		if sourceGUID == CDTL3.player["guid"] then
			local spellID, spellName, _, auraType, _, _, _, _, _, _, _, _, _ = select(12, GetCombatLogEventInfo())
			auraType = auraType:lower().."s"
			
			if CDTL3.db.profile.global["debugMode"] then
				CDTL3:Print("AURA REFRESH: "..spellID.." - "..spellName.." - "..auraType.." - "..sourceName.." - "..destName)
			end
			
			local ef = CDTL3:GetExistingCooldown(spellName, "offensives", destGUID)
			if ef then
				ef.data["currentCD"] = ef.data["baseCD"]
			end
		end		
	elseif subevent == "SPELL_AURA_REMOVED" then
		if sourceGUID == CDTL3.player["guid"] then
			local spellID, spellName, _, auraType, _, _, _, _, _, _, _, _, _ = select(12, GetCombatLogEventInfo())
			auraType = auraType:lower().."s"
			
			if CDTL3.db.profile.global["debugMode"] then
				CDTL3:Print("AURA REMOVED: "..spellID.." - "..spellName.." - "..auraType.." - "..sourceName.." - "..destName)
			end
			
			local ef = CDTL3:GetExistingCooldown(spellName, "offensives", destGUID)
			if ef then
				ef.data["currentCD"] = -1
			end
		end
		
	-- SWING DAMAGE
	elseif subevent == "SWING_DAMAGE" then
		if sourceGUID == CDTL3.player["guid"] then
			local amount, _, _, _, _, _, _, _, _, isOffHand = select(12, GetCombatLogEventInfo())
			local mhSpeed, ohSpeed = UnitAttackSpeed("player")
			
			if isOffHand then
				CDTL3.tracking["ohSwingTime"] = ohSpeed
			else
				CDTL3.tracking["mhSwingTime"] = mhSpeed
			end
		end
	
	-- SWING MISSED
	elseif subevent == "SWING_MISSED" then
		if sourceGUID == CDTL3.player["guid"] then
			local _, isOffHand, _, _ = select(12, GetCombatLogEventInfo())
			local mhSpeed, ohSpeed = UnitAttackSpeed("player")
			
			if isOffHand then
				CDTL3.tracking["ohSwingTime"] = ohSpeed
			else
				CDTL3.tracking["mhSwingTime"] = mhSpeed
			end
		end
	end
end

-- Custom timers with trigger type "Spell": start or restart them on any player cast.
-- Returns true when the cast matches one, even an ignored one.
local function CheckCustomSpellTrigger(spellName, castGUID)
	local s = CDTL3:GetCustomSpellSettings(spellName, "spell")
	if not s then
		return false
	end

	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:Print("CUSTOM_FOUND: spell - "..spellName.."-"..castGUID)
	end

	if not s["ignored"] then
		local ef = CDTL3:GetExistingCooldown(s["name"], "customs")
		if ef then
			CDTL3:SendToLane(ef)
			CDTL3:SendToBarFrame(ef)
		elseif CDTL3.db.profile.global["customs"]["enabled"] then
			CDTL3:CreateCooldown(CDTL3:GetUID(), "customs", s)
			CDTL3:CheckEdgeCases(spellName)

			if not CDTL3:IsUsedBy("customs", s["id"]) then
				CDTL3:AddUsedBy("customs", s["id"], CDTL3.player["guid"])
			end
		end
	end

	return true
end

-- While aura data is secret UNIT_AURA can't see a recast of a buff you already have, but
-- the cast itself shows. Restart the buff's timer at its saved length as an estimate;
-- the buff poll re-syncs from the real expiry once auras are readable.
local function RestartBuffFromCast(spellName)
	if not CDTL3:AurasAreSecret() then
		return
	end

	-- The cast event doesn't say who the spell landed on. With another friendly player
	-- targeted it most likely went to them (a Blessing, a shield), so leave yours alone.
	-- If the check can't be read, assume the cast was yours.
	local otherOK, onOther = pcall(function()
		if UnitExists("target") and not UnitIsUnit("target", "player") and UnitIsFriend("player", "target") then
			return true
		end
		return false
	end)
	if otherOK and onOther then
		return
	end

	local s = CDTL3:GetSpellSettings(spellName, "buffs")
	if not s or s["ignored"] or (s["bCD"] or 0) <= 0 or not CDTL3.db.profile.global["buffs"]["enabled"] then
		return
	end

	local ef = CDTL3:GetExistingCooldown(s["name"], "buffs")
	if ef then
		if (ef.data["baseCD"] or 0) > 0 then
			CDTL3:SendToLane(ef)
			CDTL3:SendToBarFrame(ef)
		end
	else
		CDTL3:CreateCooldown(CDTL3:GetUID(), "buffs", s)
	end
end

function CDTL3:UNIT_SPELLCAST_SUCCEEDED(...)
	local temp, unitTarget, castGUID, spellID = ...

	if unitTarget == "player" then
		-- a cast in the first seconds after login can beat OnEnable's GetCharacterData;
		-- anything saved without the character's GUID would never be listed
		if not CDTL3.player["guid"] then
			CDTL3:GetCharacterData()
		end

		-- Midnight 12.x: track cast times so GetSpellCooldown fallback can compute
		-- time-remaining without accessing secret startTime/duration fields.
		if not CDTL3.spellCastTimes then CDTL3.spellCastTimes = {} end
		if not CDTL3.spellBaseCDs   then CDTL3.spellBaseCDs   = {} end
		CDTL3.spellCastTimes[spellID] = GetTime()
		-- the lanes' GCD tracking reads the GCD from it while the GCD's timing is hidden (Lanes.lua HiddenGCD)
		CDTL3.lastPlayerCast = spellID

		-- Ranged swing timer: Auto Shot (75) and wand Shoot (5019) fire this event on
		-- every shot, so it works without the combat log. The ranged speed can be
		-- secret; the timer is only started when it's readable.
		if spellID == 75 or spellID == 5019 then
			pcall(function()
				CDTL3.tracking["rSwingTime"] = UnitRangedDamage("player") + 0
			end)
		end
		if GetSpellBaseCooldown and not CDTL3.spellBaseCDs[spellID] then
			local ms = GetSpellBaseCooldown(spellID)
			if ms and ms > 0 then CDTL3.spellBaseCDs[spellID] = ms / 1000 end
		end

		local spellName, icon, originalIcon = CDTL3:GetSpellInfo(spellID)

		local isKnown = CDTL3.Compat.IsSpellKnown(spellID)
		local isKnownOrOverridesKnown = CDTL3.Compat.IsSpellKnownOrOverridesKnown(spellID)

		if CDTL3.db.profile.global["debugMode"] then
			CDTL3:Print("SPELLCAST: "..spellName.."-"..castGUID)
		end

		local customFound = CheckCustomSpellTrigger(spellName, castGUID)
		RestartBuffFromCast(spellName)

		if isKnown or isKnownOrOverridesKnown then
			local s = CDTL3:GetSpellSettings(spellName, "spells")
			if s then
				-- the poll reads the cooldown by the saved entry's id, which can be another rank's
				if s["id"] then
					CDTL3.spellCastTimes[s["id"]] = CDTL3.spellCastTimes[spellID]
				end

				-- the Ignored box, or a Filters > Spells rule (Show only the ticked spells, Only for this spec)
				if not CDTL3:IsIgnored(s, "spells") then
					local ef = CDTL3:GetExistingCooldown(s["name"], "spells")
					if ef then
						CDTL3:SendToLane(ef)
						CDTL3:SendToBarFrame(ef)
						CDTL3:CheckEdgeCases(spellName)
					else
						if CDTL3.db.profile.global["spells"]["enabled"] then
							CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)
							CDTL3:CheckEdgeCases(spellName)
							
							if CDTL3:IsUsedBy("spells", s["id"]) then
								--CDTL3:Print("USEDBY MATCH: "..s["id"])
							else
								CDTL3:AddUsedBy("spells", s["id"], CDTL3.player["guid"])
							end
						end
					end
				end
			else
				s = CDTL3:NewSpellEntry(spellID, spellName, icon, "spells")
				if CDTL3:SaveNewEntry(s, "spells") then
					CDTL3:CheckEdgeCases(spellName)
				end
			end
		else
			-- ITEM SPELLS
			local s = nil
			local is = CDTL3:GetItemSpell(spellID)
			if is then
				s = CDTL3:GetSpellSettings(is["itemName"], "items", true)
			else
				s = CDTL3:GetSpellSettings(spellName, "items", true, spellID)
			end
			
			if s then
				if not s["ignored"] then
					local ef = CDTL3:GetExistingCooldown(s["name"], "items")
					if ef then
						CDTL3:SendToLane(ef)
						CDTL3:SendToBarFrame(ef)
					else
						if CDTL3.db.profile.global["items"]["enabled"] then
							if not CDTL3:IsUsedBy("items", s["id"]) then
								CDTL3:AddUsedBy("items", s["id"], CDTL3.player["guid"])
							end
							
							CDTL3:CreateCooldown(CDTL3:GetUID(),"items" , s)
						end
					end
				end
			else
				s = is
				if s then
					if CDTL3:IsValidItem(s["itemID"]) then
						table.insert(CDTL3.db.profile.tables["items"], s)
						
						if CDTL3.db.profile.global["items"]["enabled"] then
							CDTL3:CreateCooldown(CDTL3:GetUID(),"items" , s)
						end
					end
				else
					--CDTL3:Print("NOTFOUND: "..spellID)

					-- 'OTHER' SPELLS: a custom spell trigger (checked above) takes the cast,
					-- otherwise record it
					if not customFound then
						if CDTL3.db.profile.global["customDetection"] then
							-- RECORD 'OTHER' SPELL
							s = CDTL3:GetSpellSettings(spellName, "detected")
							if s then
								if CDTL3.db.profile.global["debugMode"] then
									CDTL3:Print("OTHER_FOUND: "..spellName.."-"..castGUID)
								end
							else
								--if CDTL3.db.profile.global["customDetection"] then
									--local currentCharges, maxCharges, _, cooldownDuration, _ = GetSpellCharges(spellID)
									local currentCharges, maxCharges, cooldownStart, cooldownDuration = CDTL3:GetSpellCharges(spellID)
									local cooldownMS, gcdMS = GetSpellBaseCooldown(spellID)
									
									if cooldownDuration ~= nil and cooldownDuration ~= 0 then
										cooldownMS = cooldownDuration * 1000
									end

									if CDTL3.db.profile.global["debugMode"] then
										CDTL3:Print("OTHER_ADDING: "..spellName.." - "..spellID.." - "..cooldownMS.." - "..tostring(CDTL3.player["guid"]))
									end

									local s = {}
									
									s["id"] = spellID
									s["name"] = spellName
									s["type"] = "detected"
							
									if maxCharges then
										s["charges"] = maxCharges
										s["bCD"] = cooldownMS
									end

									s["icon"] = icon
									s["highlight"] = false
									s["pinned"] = false
									s["setCustomCD"] = false
									
									local link, _ = CDTL3:GetSpellLink(spellID)
									s["link"] = link
									
									table.insert(CDTL3.db.profile.tables["detected"], s)
							end
						else
							local cooldownMS, gcdMS = GetSpellBaseCooldown(spellID)
								
							if CDTL3.db.profile.global["debugMode"] then
								CDTL3:Print("OTHER_SKIPPED: "..tostring(spellName).." - "..tostring(spellID).." - "..tostring(cooldownMS).." - "..tostring(CDTL3.player["guid"]))
							end
						end
					end
				end
			end
		end
	elseif unitTarget == "pet" then
		-- Same secret-cooldown fallback as the player's casts: without a cast time
		-- GetSpellCooldown restarts the countdown from "now" on every poll.
		if not CDTL3.spellCastTimes then CDTL3.spellCastTimes = {} end
		CDTL3.spellCastTimes[spellID] = GetTime()

		local spellName, icon, originalIcon = CDTL3:GetSpellInfo(spellID)
		
		local isKnown = CDTL3.Compat.IsSpellKnown(spellID, true)
		local isKnownOrOverridesKnown = CDTL3.Compat.IsSpellKnownOrOverridesKnown(spellID, true)

		if CDTL3.db.profile.global["debugMode"] then
			CDTL3:Print("PETCAST: "..spellName.."-"..castGUID)
		end

		if isKnown or isKnownOrOverridesKnown then
			local s = CDTL3:GetSpellSettings(spellName, "petspells")
			if s then
				-- the poll reads the cooldown by the saved entry's id, which can be another rank's
				if s["id"] then
					CDTL3.spellCastTimes[s["id"]] = CDTL3.spellCastTimes[spellID]
				end

				if not s["ignored"] then
					local ef = CDTL3:GetExistingCooldown(s["name"], "petspells")
					if ef then
						CDTL3:SendToLane(ef)
						CDTL3:SendToBarFrame(ef)
						CDTL3:CheckEdgeCases(spellName)
					else
						if CDTL3.db.profile.global["petspells"]["enabled"] then
							CDTL3:CreateCooldown(CDTL3:GetUID(),"petspells" , s)
							CDTL3:CheckEdgeCases(spellName)
							
							if CDTL3:IsUsedBy("petspells", s["id"]) then
								--CDTL3:Print("USEDBY MATCH: "..s["id"])
							else
								CDTL3:AddUsedBy("petspells", s["id"], CDTL3.player["guid"])
							end
						end
					end
				end
			else
				s = CDTL3:NewSpellEntry(spellID, spellName, icon, "petspells")
				if CDTL3:SaveNewEntry(s, "petspells") then
					CDTL3:CheckEdgeCases(spellName)
				end
			end
		end
	end
end

function CDTL3:ITEM_LOCK_CHANGED(...)
	-- Detect item lock cooldowns
	-- Most commonly trinkets being equipped, that will begin a 30 second cooldown
	local _, bagOrSlotIndex, slotIndex = ...
	
	if not IsInventoryItemLocked(bagOrSlotIndex) and not IsInventoryItemLocked(slotIndex) then
		if slotIndex == nil then
			local itemId = GetInventoryItemID("player", bagOrSlotIndex)
			local spellName, spellID = CDTL3.Compat.GetItemSpell(itemId)
			
			if spellID then
				local s = CDTL3:GetSpellSettings(spellName, "items", false, spellID)
				if s then
					if not s["ignored"] then
						-- The equip lockout only changes the LIVE countdown. Writing 30000 into
						-- bCD changed nothing for an existing icon (the loop reads baseCD) and
						-- permanently overwrote the saved entry's real cooldown otherwise.
						local ef = CDTL3:GetExistingCooldown(s["name"], "items")
						if ef then
							CDTL3:SendToLane(ef)
							CDTL3:SendToBarFrame(ef)
							ef.data["currentCD"] = 30
						else
							if CDTL3.db.profile.global["items"]["enabled"] then
								if not CDTL3:IsUsedBy("items", s["id"]) then
									CDTL3:AddUsedBy("items", s["id"], CDTL3.player["guid"])
								end
								
								local ncd = CDTL3:CreateCooldown(CDTL3:GetUID(),"items" , s)
								if ncd then
									ncd.data["currentCD"] = 30
								end
							end
						end
					end
				else
					s = CDTL3:GetItemSpell(spellID)
					if s then
						if CDTL3:IsValidItem(s["itemID"]) then
							table.insert(CDTL3.db.profile.tables["items"], s)
							
							if CDTL3.db.profile.global["items"]["enabled"] then
								local ncd = CDTL3:CreateCooldown(CDTL3:GetUID(),"items" , s)
								if ncd then
									ncd.data["currentCD"] = 30
								end
							end
						end
					else
						--CDTL3:Print("NOTFOUND: "..spellID)
					end
				end
			end
		end
	end
end

function CDTL3:PLAYER_REGEN_DISABLED()
	CDTL3.combat = true
	CDTL3:ApplyCombatVisibility()
	
	
	if CDTL3_Ready_1 then
		CDTL3_Ready_1.combatTimer = CDTL3.db.profile.ready["ready1"]["pTime"]
	end
	
	if CDTL3_Ready_2 then
		CDTL3_Ready_2.combatTimer = CDTL3.db.profile.ready["ready2"]["pTime"]
	end
	
	if CDTL3_Ready_3 then
		CDTL3_Ready_3.combatTimer = CDTL3.db.profile.ready["ready3"]["pTime"]
	end
end

function CDTL3:PLAYER_REGEN_ENABLED()
	CDTL3.combat = false
	CDTL3:ApplyCombatVisibility()

	-- auras were secret during combat: pick up buffs gained or recast meanwhile
	if CDTL3.retailAPI and CDTL3.enabled then
		CDTL3:UNIT_AURA("UNIT_AURA", "player")
	end
	
	if CDTL3_Ready_1 then
		CDTL3_Ready_1.combatTimer = 0
	end
	
	if CDTL3_Ready_2 then
		CDTL3_Ready_2.combatTimer = 0
	end
	
	if CDTL3_Ready_3 then
		CDTL3_Ready_3.combatTimer = 0
	end
end

--[[function CDTL3:ENCOUNTER_END()
	CDTL3:Print("ENCOUNTER_END")

	for _, cd in pairs(CDTL3.cooldowns) do
		if cd then
			CDTL3:Print("RESET: "..tostring(cd.data["name"]))

			if cd.data["id"] then
				local start, duration, enabled = CDTL3:GetSpellCooldown(cd.data["id"])

				CDTL3:Print("    "..cd.data["currentCD"])
				CDTL3:Print("    "..tostring(duration))
			end
		end
	end
end]]--

function CDTL3:UNIT_POWER_FREQUENT(...)
	local _, unitTarget, powerType = ...
	
	if unitTarget == "player" and powerType == "MANA" then
		if CDTL3:AnyLaneTracks("MANA_TICK") then
			-- mana can be SECRET (Midnight / WoW: Forever): skip the tick estimate then
			pcall(function()
				local currentTime = GetTime()
				local currentMana = UnitPower("player", Enum.PowerType.Mana)
				if currentMana ~= UnitPowerMax("player", Enum.PowerType.Mana) then
					local difference = currentMana - CDTL3.tracking["manaPrevious"]
							
					local timeDifference = 0
					if CDTL3.tracking["manaTime"] then
						timeDifference = currentTime - CDTL3.tracking["manaTime"]
					end
				
					if difference < 0 then
						if CDTL3.combat then
							CDTL3.tracking["manaTime"] = currentTime
							CDTL3.tracking["fsr"] = true
						end
					end
				
					if difference > 0 then
						local low = 0.1
						local high = 1.9
					
						if CDTL3.tracking["fsr"] then
							high = 4.9	-- was "local high", which never widened the window
						end
					
						if timeDifference < low or  timeDifference > high then
							CDTL3.tracking["fsr"] = false
							CDTL3.tracking["manaTime"] = currentTime
						end
					end
				end

				-- track at full mana too, or the first cast after topping off reads as a
				-- regen tick (e.g. 4900 -> 5000 unrecorded, then a cast to 4950 = "+50")
				CDTL3.tracking["manaPrevious"] = currentMana
			end)
		end
	end
end

function CDTL3:UNIT_POWER_UPDATE(...)
	local _, unitTarget, powerType = ...
	
	if unitTarget == "player" and powerType == "ENERGY" then
		if CDTL3:AnyLaneTracks("ENERGY_TICK") then
			-- energy can be SECRET (Midnight / WoW: Forever): skip the tick estimate then
			pcall(function()
				local currentTime = GetTime()
				local maxenergy = UnitPowerMax("player", Enum.PowerType.Energy)
				local currentEnergy = UnitPower("player", Enum.PowerType.Energy)
			
				if currentEnergy < maxenergy then
					local difference = currentEnergy - CDTL3.tracking["energyPrevious"]
					if (difference > 18 and difference < 22) or (difference > 38 and difference < 42) then
						CDTL3.tracking["energyTimeCount"] = 0
					end
				end
			
				CDTL3.tracking["energyPrevious"] = currentEnergy
			end)
		end
	end
end

function CDTL3:RUNE_POWER_UPDATE(...)
	-- (event, runeIndex, added): added is true once the rune is usable again, false while it cools
	local _, runeIndex, added = ...

	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:Print("RUNES UPDATE: "..tostring(runeIndex).." - "..tostring(added))
	end
	
	if not added then
		local spellName = ""
		local icon = 0
		if runeIndex == 1 or runeIndex == 2 then
			spellName = "Blood Rune "..tostring(runeIndex)
			icon = 135770
		elseif runeIndex == 3 or runeIndex == 4 then
			spellName = "Unholy Rune "..tostring(runeIndex)
			icon = 135775
		elseif runeIndex == 5 or runeIndex == 6 then
			spellName = "Frost Rune "..tostring(runeIndex)
			icon = 135773
		end
		
		local s = CDTL3:GetSpellSettings(spellName, "runes")
		if s then
			if not s["ignored"] then
				local ef = CDTL3:GetExistingCooldown(s["name"], "runes")
				if ef then			
					local graceTime = GetTime() - ef.data["runeGraceTime"]
					if graceTime >= 2.5 then
						ef.data["baseCD"] = 7.5
					elseif graceTime > 0 then
						ef.data["baseCD"] = 10 - graceTime
					else
						ef.data["baseCD"] = 10
					end
					
					CDTL3:SendToLane(ef)
					CDTL3:SendToBarFrame(ef)
				else
					if CDTL3.db.profile.global["runes"]["enabled"] then
						CDTL3:CreateCooldown(CDTL3:GetUID(),"runes" , s)
					end
				end
			end
		else
			-- the rune duration can be secret on retail: fall back to the 10s rune base
			local bCD = 10000
			pcall(function()
				local _, duration = GetRuneCooldown(runeIndex)
				bCD = (duration + 0) * 1000
			end)

			local s = CDTL3:ApplyEntryDefaults({
				name = spellName,
				type = "runes",
				runeIndex = runeIndex,
				icon = icon,
				bCD = bCD,
			}, "runes")
			s["ignored"] = CDTL3:IgnoredByDefault("runes", s["bCD"])

			CDTL3:SaveNewEntry(s, "runes")
		end
	else
		for _, rune in pairs(CDTL3.cooldowns) do
			if rune.data["runeIndex"] == runeIndex then
				rune.data["runeGraceTime"] = GetTime()
			end
		end
	end
end

function CDTL3:ACTIVE_TALENT_GROUP_CHANGED()
	C_Timer.After(2, function()
		CDTL3:OnTalentChanges()
	end)
end

function CDTL3:TRAIT_CONFIG_UPDATED()
	C_Timer.After(2, function()
		CDTL3:OnTalentChanges()
	end)
end

function CDTL3:RUNE_UPDATED()
	C_Timer.After(2, function()
		CDTL3:OnTalentChanges()
	end)
end

-- The spellbook changed (talents, a new spell, a spec switch): Filters > Spells' Hide spells I don't
-- know and Only for this spec follow it. Bursts of the event are folded into one pass.
function CDTL3:SPELLS_CHANGED()
	CDTL3:ForgetSpellbook()
	if CDTL3.spellsChangedPending then
		return
	end
	CDTL3.spellsChangedPending = true
	C_Timer.After(1, function()
		CDTL3.spellsChangedPending = nil
		CDTL3:ForgetSpellbook()
		CDTL3:ApplyEntryRules()
	end)
end

function CDTL3:PLAYER_ENTERING_WORLD()	
	local turnOn = CDTL3:DetermineOnOff()
	
	if turnOn then
		CDTL3:TurnOn()
	else
		CDTL3:TurnOff()
	end
end

function CDTL3:GROUP_JOINED()	
	local turnOn = CDTL3:DetermineOnOff()
	
	if turnOn then
		CDTL3:TurnOn()
	else
		CDTL3:TurnOff()
	end
end

function CDTL3:GROUP_LEFT()	
	local turnOn = CDTL3:DetermineOnOff()
	
	if turnOn then
		CDTL3:TurnOn()
	else
		CDTL3:TurnOff()
	end
end

function CDTL3:DetermineOnOff()
	local turnOn = false
	
	if CDTL3.db.profile.global["enabledAlways"] then
		turnOn = true
	else
		local inInstance, instanceType = IsInInstance()
		local inGroup = IsInGroup()
		
		if inInstance or inGroup then
			if inInstance and CDTL3.db.profile.global["enabledInstance"] then
				turnOn = true
			end
			
			if inGroup and CDTL3.db.profile.global["enabledGroup"] then
				turnOn = true
			end
		end
	end
	
	return turnOn
end

-- Unit events are only wanted for the player (and pet). Registering them per unit on a
-- private frame stops the client waking the addon for every raid member's casts, auras
-- and power changes. Handlers keep the AceEvent signature: CDTL3:EVENT(event, unit, ...).
CDTL3.unitEventFrame = CreateFrame("Frame")
CDTL3.unitEventFrame:SetScript("OnEvent", function(_, event, ...)
	CDTL3[event](CDTL3, event, ...)
end)

function CDTL3:RegisterUnitEvents(event, unit1, unit2)
	local f = CDTL3.unitEventFrame
	if f.RegisterUnitEvent then
		f:RegisterUnitEvent(event, unit1, unit2)
	else
		f:RegisterEvent(event)	-- handlers still check the unit
	end
end

-- Does any lane show this tracking type, as primary or secondary?
function CDTL3:AnyLaneTracks(kind)
	for _, key in ipairs({ "lane1", "lane2", "lane3" }) do
		local tracking = CDTL3.db.profile.lanes[key]["tracking"]
		if tracking["primaryTracking"] == kind or tracking["secondaryTracking"] == kind then
			return true
		end
	end

	return false
end

function CDTL3:TurnOn()	
	if not CDTL3.enabled then
		if CDTL3.db.profile.global["debugMode"] then
			CDTL3:Print("ENABLING DETECTION")
		end
	
		-- The combat log is closed to addons on retail 12.x and WoW: Forever (retail still has
		-- CombatLogGetCurrentEventInfo as a deprecated stub, so the function alone proves
		-- nothing). Only register it on the other clients, where its accessor exists, and never
		-- let a refusal abort the rest of TurnOn.
		CDTL3.combatLogRegistered = false
		if not CDTL3.retailAPI and GetCombatLogEventInfo then
			CDTL3.combatLogRegistered = pcall(CDTL3.RegisterEvent, CDTL3, "COMBAT_LOG_EVENT_UNFILTERED")
		end
		CDTL3:RegisterUnitEvents("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
		CDTL3:RegisterEvent("ITEM_LOCK_CHANGED")
		CDTL3:RegisterEvent("PLAYER_REGEN_DISABLED")
		CDTL3:RegisterEvent("PLAYER_REGEN_ENABLED")
		-- seed the combat flag: a /reload DURING combat refires no REGEN event
		CDTL3.combat = (UnitAffectingCombat and UnitAffectingCombat("player")) or false
		CDTL3:RegisterUnitEvents("UNIT_POWER_FREQUENT", "player")
		CDTL3:RegisterUnitEvents("UNIT_POWER_UPDATE", "player")

		CDTL3:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		CDTL3:RegisterEvent("SPELLS_CHANGED")
		
		if CDTL3.retailAPI then
			CDTL3:RegisterUnitEvents("UNIT_AURA", "player")
			--CDTL3:RegisterEvent("TRAIT_CONFIG_UPDATED")
		end

		if CDTL3.tocversion < 20000 and not CDTL3.isForever then
			CDTL3:RegisterEvent("RUNE_UPDATED")
		end
		
		CDTL3.enabled = true
	end
end

function CDTL3:TurnOff()
	if CDTL3.enabled then
		if CDTL3.db.profile.global["debugMode"] then
			CDTL3:Print("DISABLING DETECTION")
		end
		
		pcall(CDTL3.UnregisterEvent, CDTL3, "COMBAT_LOG_EVENT_UNFILTERED")
		CDTL3.unitEventFrame:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED")
		CDTL3:UnregisterEvent("ITEM_LOCK_CHANGED")
		CDTL3:UnregisterEvent("PLAYER_REGEN_DISABLED")
		CDTL3:UnregisterEvent("PLAYER_REGEN_ENABLED")
		CDTL3.unitEventFrame:UnregisterEvent("UNIT_POWER_FREQUENT")
		CDTL3.unitEventFrame:UnregisterEvent("UNIT_POWER_UPDATE")

		CDTL3:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
		CDTL3:UnregisterEvent("SPELLS_CHANGED")
		
		if CDTL3.retailAPI then
			CDTL3.unitEventFrame:UnregisterEvent("UNIT_AURA")
			--CDTL3:UnregisterEvent("TRAIT_CONFIG_UPDATED")
		end

		if CDTL3.tocversion < 20000 and not CDTL3.isForever then
			CDTL3:UnregisterEvent("RUNE_UPDATED")
		end
		
		CDTL3.enabled = false
	end
end

-- true when the version this profile last saw is older than `version`. Compared part by part
-- (major.minor.patch), so 3.0.13 is older than 3.1 and 3.0.9 older than 3.0.13; a missing or
-- non-numeric part counts as 0 rather than erroring at login.
function CDTL3:LastSeenOlderThan(version)
	local function parts(v)
		local out = {}
		for piece in (tostring(v or "") .. "."):gmatch("([^%.]*)%.") do
			out[#out + 1] = tonumber(piece:match("^%d+")) or 0
		end
		return out
	end

	local nv = parts(version)
	local pv = parts(CDTL3.db.profile.global["previousVersion"])
	for i = 1, math.max(#nv, #pv) do
		local n, p = nv[i] or 0, pv[i] or 0
		if p ~= n then
			return p < n
		end
	end

	return false
end

-- true when the version this profile last saw is older than noticeVersion (the welcome window's rule)
function CDTL3:IsNewerVersion()
	return CDTL3:LastSeenOlderThan(CDTL3.noticeVersion)
end