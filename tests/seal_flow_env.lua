-- Stub world for the seal flow simulation (tests/seal_flow.test.mjs): game time, the player's
-- spellbook, the GCD, seal auras, hidden ("secret") values in combat as on WoW: Forever, the
-- holding and lane frames, and a CDTL3 table with the settings of the owner's setup. The real
-- addon code (cast handler, aura handler, cooldown poll, combat timers) runs on top of it.
NOW = 100
function GetTime() return NOW end

-- Secret values: reading one is allowed, any comparison or arithmetic throws (12.x rules).
local secretMT = {}
local function boom() error("attempt to use a secret value") end
for _, k in ipairs({ "__lt", "__le", "__add", "__sub", "__mul", "__div", "__concat", "__unm" }) do secretMT[k] = boom end
function Secret(v) return setmetatable({ hidden = v }, secretMT) end
function issecretvalue(v) return type(v) == "table" and getmetatable(v) == secretMT end

SECRET_CD, SECRET_AURAS, IN_COMBAT = false, false, false
function InCombatLockdown() return IN_COMBAT end
function UnitAffectingCombat() return IN_COMBAT end
function UnitExists(u) return u == "player" end
function UnitIsUnit(a, b) return a == b end
function UnitIsFriend() return true end
UIParent = { IsShown = function() return true end }
GameTooltip = { IsOwned = function() return false end, Hide = function() end }

-- spells: names from the client, the spellbook, real cooldowns, the GCD
SPELLS = {
	[20375] = "Seal of Command", [20154] = "Seal of Righteousness", [20305] = "Seal of the Crusader",
	[20165] = "Seal of Light", [20166] = "Seal of Wisdom", [20164] = "Seal of Justice",
	[20424] = "Seal of Command",	-- the proc: same name, its own spell ID, not in the spellbook
	[20271] = "Judgement",
}
KNOWN = { [20375] = true, [20154] = true, [20271] = true }
COOLDOWNS = {}		-- id -> { start, dur } for spells with a cooldown of their own
GCD_START, GCD_END = -100, -100

local function hide(v) if SECRET_CD then return Secret(v) end return v end
C_Spell = {
	GetSpellName = function(id) return SPELLS[id] end,
	-- isActive / isOnGCD are never hidden; startTime / duration are hidden in combat
	GetSpellCooldown = function(id)
		local cd = COOLDOWNS[id]
		if cd and NOW < cd.start + cd.dur then
			return { isEnabled = true, isActive = true, isOnGCD = false, startTime = hide(cd.start), duration = hide(cd.dur) }
		end
		if KNOWN[id] and NOW < GCD_END then
			return { isEnabled = true, isActive = true, isOnGCD = true, startTime = hide(GCD_START), duration = hide(1.5) }
		end
		return { isEnabled = true, isActive = false, isOnGCD = false, startTime = hide(0), duration = hide(0) }
	end,
	GetSpellCooldownDuration = function() return { durationObject = true } end,
	GetSpellCharges = function() return nil end,
	GetSpellChargeDuration = function() return nil end,
}
C_Secrets = {
	ShouldSpellCooldownBeSecret = function() return SECRET_CD end,
	ShouldCooldownsBeSecret = function() return SECRET_CD end,
	ShouldAurasBeSecret = function() return SECRET_AURAS end,
}
C_CurveUtil, C_DurationUtil = {}, {}
function GetSpellBaseCooldown(id) return (id == 20271) and 10000 or 0, 1500 end

-- player auras; the index accessor errors while auras are secret, an aura handed out then has
-- secret fields
AURAS, NEXT_AURA = {}, 1
local function secretAura(a)
	local s = {}
	for k, v in pairs(a) do s[k] = (type(v) == "number" or k == "name") and Secret(v) or v end
	return s
end
C_UnitAuras = {
	GetAuraDataByIndex = function(unit, i, filter)
		if SECRET_AURAS then error("aura data is secret") end
		if unit ~= "player" or filter ~= "HELPFUL" then return nil end
		return AURAS[i]
	end,
	GetAuraDataByAuraInstanceID = function(unit, id)
		for _, a in ipairs(AURAS) do
			if a.auraInstanceID == id then return SECRET_AURAS and secretAura(a) or a end
		end
	end,
}
function HandOut(a) return SECRET_AURAS and secretAura(a) or a end

-- frames: lanes, bar frames and ready frames are shown, the holding areas are hidden
local function holder(name, shown)
	return { name = name, shown = shown, GetName = function(self) return self.name end,
		IsShown = function(self) return self.shown end }
end
CDTL3_Lane_1 = holder("CDTL3_Lane_1", true)
CDTL3_BarFrame_1_MF = holder("CDTL3_BarFrame_1_MF", true)
CDTL3_Ready_1_MF = holder("CDTL3_Ready_1_MF", true)
CDTL3_Active_Icon_Holding = holder("CDTL3_Active_Icon_Holding", false)
CDTL3_Bar_Holding = holder("CDTL3_Bar_Holding", false)
CDTL3_Offensive_Icon_Holding = holder("CDTL3_Offensive_Icon_Holding", false)
CDTL3_Offensive_Bar_Holding = holder("CDTL3_Offensive_Bar_Holding", false)

local function region()
	local r = { parent = CDTL3_Active_Icon_Holding }
	function r:SetParent(p) self.parent = p end
	function r:GetParent() return self.parent end
	function r:IsVisible() return self.parent ~= nil and self.parent.shown end
	function r:ClearAllPoints() end
	function r:SetPoint() end
	function r:Hide() end
	function r:SetAlpha(a) self.alpha = a end
	return r
end

function CreateFrame()
	local f = {}
	function f:SetScript() end
	function f:RegisterEvent() end
	function f:UnregisterEvent() end
	return f
end

READY, EVENTS, ERRORS = {}, {}, {}
-- the parts of Cooldown.lua's icon update this test needs: a spent timer on its lane goes to
-- its Ready frame (with the ready sound)
ICON_UPDATE = function(f)
	if f.icon:GetParent() == CDTL3_Lane_1 and f.data["currentCD"] < 0 then
		READY[#READY + 1] = f.data["type"] .. ":" .. f.data["name"]
		f.icon:SetParent(CDTL3_Ready_1_MF)
	end
end

CDTL3 = {
	retailAPI = true, isForever = true, tocversion = 11507, enabled = true, combat = false,
	player = { guid = "Player-1" }, cooldowns = {}, recentAuras = {}, auraExpiry = {}, tracking = {},
	Compat = {
		IsSpellKnown = function(id) return KNOWN[id] or false end,
		IsSpellKnownOrOverridesKnown = function(id) return KNOWN[id] or false end,
		GetItemSpell = function() return nil end,
	},
	IconFx = { Started = function() end, Ended = function() end, PollCharges = function() end, CopyEntry = function() end },
}
function CDTL3:Print() end
-- GetSpellCooldown and AuraExists log every hidden read in combat by design; anything else is
-- a failure
function CDTL3:LogFailure(place, err)
	if place ~= "GetSpellCooldown" and place ~= "AuraExists" then ERRORS[#ERRORS + 1] = tostring(place) .. ": " .. tostring(err) end
end
function CDTL3:GetCharacterData() end
function CDTL3:GetSpellInfo(id) return SPELLS[id], 1, 1 end
function CDTL3:IsIgnored(s) return s["ignored"] and true or false end
function CDTL3:CheckEdgeCases() end
function CDTL3:IsUsedBy() return true end
function CDTL3:AddUsedBy() end
function CDTL3:GetItemSpell() return nil end
function CDTL3:NewSpellEntry() return nil end
function CDTL3:SaveNewEntry() return nil end
function CDTL3:ApplyEntryDefaults(s) return s end
function CDTL3:IgnoredByDefault() return true end
function CDTL3:GetSpellLink() return "" end
function CDTL3:ApplyCombatVisibility() end
function CDTL3:RefreshIcon() end
function CDTL3:RefreshBar() end
function CDTL3:ScanSharedSpellCooldown() end
function CDTL3:FireTimerIfHeldOver() end
function CDTL3:FireTimer(message, f)
	EVENTS[#EVENTS + 1] = message .. ":" .. f.data["type"] .. ":" .. f.data["name"]
	if message == "CDTL3_TimerStarted" then f.pubLive = true elseif message == "CDTL3_TimerEnded" then f.pubLive = nil end
end
local uid = 0
function CDTL3:GetUID() uid = uid + 1; return uid end
-- the fields of Cooldown.lua's CreateCooldown that the spell and buff paths read
function CDTL3:CreateCooldown(UID, cdType, s)
	local f = { updateCount = 0, data = {
		uid = UID, id = s["id"], type = cdType, name = s["name"], enabled = true, ignored = s["ignored"],
		lane = s["lane"], barFrame = s["barFrame"], readyFrame = s["readyFrame"],
		baseCD = s["bCD"] / 1000, currentCD = s["bCD"] / 1000, overrideCD = false, stacks = 0,
	} }
	if s["setCustomCD"] then
		f.data["setCustomCD"] = s["setCustomCD"]
		if s["customCDTime"] then
			f.data["customCDTime"] = s["customCDTime"]
			f.data["baseCD"] = s["customCDTime"] / 1000
		end
	end
	f.icon = region()
	f.bar = region()
	f.bar.bar = { SetMinMaxValues = function() end }
	CDTL3:SendToLane(f)
	CDTL3:SendToBarFrame(f)
	table.insert(CDTL3.cooldowns, f)
	return f
end

-- the owner's setup: Filters > Spells > Seal of Command (and Righteousness): Ignored off,
-- Custom CD 30, Custom CD on; Judgement as a normal cooldown. Buffs: the seals' buffs, tracked
-- or ignored per scenario.
function Setup(opts)
	NOW = 100
	SECRET_CD, SECRET_AURAS, IN_COMBAT = false, false, false
	COOLDOWNS, GCD_START, GCD_END = {}, -100, -100
	AURAS, NEXT_AURA = {}, 1
	READY, EVENTS, ERRORS = {}, {}, {}
	CDTL3.cooldowns, CDTL3.recentAuras, CDTL3.auraExpiry = {}, {}, {}
	CDTL3.spellCastTimes, CDTL3.spellBaseCDs = {}, {}
	CDTL3.combat = false
	local function spell(id, name, custom)
		return { id = id, name = name, type = "spells", ignored = false, enabled = true, bCD = custom and 0 or 10000,
			setCustomCD = custom, customCDTime = custom and 30000 or nil, lane = 1, barFrame = 1, readyFrame = 1 }
	end
	local function buff(id, name)
		return { id = id, name = name, type = "buffs", ignored = not opts.buffs, enabled = true, bCD = 30000,
			lane = 1, barFrame = 1, readyFrame = 1 }
	end
	CDTL3.db = { profile = {
		global = {
			debugMode = false, customDetection = false, detectSharedCD = false, hideOutOfCombat = false,
			spells = { enabled = true }, items = { enabled = true }, customs = { enabled = true },
			buffs = { enabled = true, onlyPlayer = true }, debuffs = { enabled = true, onlyPlayer = true },
			combatTimers = { enabled = opts.ct and true or false, hideBlizzardBars = false },
		},
		tables = {
			spells = { spell(20375, "Seal of Command", true), spell(20154, "Seal of Righteousness", true), spell(20271, "Judgement", false) },
			buffs = { buff(20375, "Seal of Command"), buff(20154, "Seal of Righteousness") },
			debuffs = {}, items = {}, customs = {}, detected = {},
		},
	} }
end
