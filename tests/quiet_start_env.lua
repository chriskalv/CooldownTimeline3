-- Stub world for the two quiet-start patches (Flight timers off by default, no automatic What's
-- new). Loaded before LibStub, CallbackHandler and the real AceDB-3.0, so saved variables, defaults
-- and the logout cleanup behave as in the game. SCENARIO is set by quiet_start.test.mjs.

-- time and C_Timer: a queue run in time order by runTimers
NOW = 1000
TIMERS = {}
function GetTime() return NOW end
function GetServerTime() return 1700000000 + math.floor(NOW) end
C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = { at = NOW + d, fn = fn } end }
-- advances the clock by sec, running every timer that falls due (timers started by timers too)
function runTimers(sec)
	local stop = NOW + sec
	while true do
		local best, bi = nil, nil
		for i, t in ipairs(TIMERS) do
			if t.at <= stop and (not best or t.at < best.at) then best, bi = t, i end
		end
		if not best then break end
		table.remove(TIMERS, bi)
		NOW = math.max(NOW, best.at)
		best.fn()
	end
	NOW = stop
end

-- frames: any method a test does not care about is a no-op returning another mock frame
local FrameMethods = {}
local FrameMT = { __index = function(t, k)
	local m = FrameMethods[k]
	if m then return m end
	return function() return newMock() end
end }
function newMock(name)
	local f = setmetatable({ scripts = {}, events = {}, shown = false, name = name }, FrameMT)
	if name then _G[name] = f end
	return f
end
function FrameMethods:SetScript(k, fn) self.scripts[k] = fn end
function FrameMethods:GetScript(k) return self.scripts[k] end
function FrameMethods:RegisterEvent(e) self.events[e] = true end
function FrameMethods:UnregisterEvent(e) self.events[e] = nil end
function FrameMethods:Show() self.shown = true end
function FrameMethods:Hide() self.shown = false end
function FrameMethods:IsShown() return self.shown end
function FrameMethods:GetFrameLevel() return 1 end
function FrameMethods:GetWidth() return 500 end
function FrameMethods:GetSize() return 500, 200 end
FRAMES_MADE = {}
function CreateFrame(kind, name)
	FRAMES_MADE[#FRAMES_MADE + 1] = name or kind
	return newMock(name)
end
UIParent = newMock()

-- AceDB's character keys and CallbackHandler's dispatch
function GetRealmName() return "Realm" end
function UnitName() return "Tester" end
function UnitClass() return "Paladin", "PALADIN" end
function UnitRace() return "Human", "Human" end
function UnitFactionGroup() return "Alliance" end
function GetLocale() return "enUS" end
function GetCurrentRegion() return 3 end
function GetCurrentRegionName() return "EU" end
function securecallfunction(fn, ...) return fn(...) end
function geterrorhandler() return function(e) error(e, 2) end end
function string.trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- post-hooks as in the game: the original runs first, then the hook
function hooksecurefunc(a, b, c)
	local tbl, name, hook = _G, a, b
	if type(a) == "table" then tbl, name, hook = a, b, c end
	local orig = tbl[name]
	tbl[name] = function(...)
		local r = orig(...)
		hook(...)
		return r
	end
end

-- the taxi map: two flight points, one route
ON_TAXI = false
TAXI_TAKEN = {}
function UnitOnTaxi() return ON_TAXI end
function NumTaxiNodes() return 2 end
local NODES = { { "Stormwind, Elwynn", "CURRENT" }, { "Ironforge, Dun Morogh", "REACHABLE" } }
function TaxiNodeName(i) return NODES[i][1] end
function TaxiNodeGetType(i) return NODES[i][2] end
function TakeTaxiNode(slot) TAXI_TAKEN[#TAXI_TAKEN + 1] = slot end
ROUTE_KEY = "n:Stormwind, Elwynn>Ironforge, Dun Morogh"

-- CDTL3 with what the extracted code calls; the rest records or does nothing
CDTL3 = {
	isForever = true, testing = false, retailAPI = false, enabled = false,
	tracking = {}, player = {}, currentFilter = {}, lanes = {}, cooldowns = {},
	LSM = newMock(),
}
CREATED, PRINTED, TOUR_STEPS, PREVIEWS = {}, {}, {}, 0
local uid = 0
function CDTL3:GetUID() uid = uid + 1; return uid end
function CDTL3:CreateCooldown(id, kind, data)
	local d = {}
	for k, v in pairs(data) do d[k] = v end
	d["type"] = kind
	d["currentCD"] = (data.bCD or 0) / 1000
	local f = { data = d }
	CREATED[#CREATED + 1] = f
	return f
end
function CDTL3:Print(msg) PRINTED[#PRINTED + 1] = tostring(msg) end
for _, n in ipairs({ "ApplyCombatVisibility", "SendToLane", "SendToBarFrame", "RegisterEvent", "BuildMinimapButton",
		"Cleanup", "CreateLanes", "CreateBarFrames", "CreateReadyFrames", "CreateHolders", "GetCharacterData",
		"ScanCurrentCooldowns", "RefreshLane", "SetBorder", "StopPreview" }) do
	CDTL3[n] = function() end
end
function CDTL3:GetAardvark() return "" end
function CDTL3:GetSpecialMessage() return "special\n" end
function CDTL3:GetChangeLog() return "changelog\n" end
function CDTL3:StartPreview() PREVIEWS = PREVIEWS + 1; CDTL3.testing = true end

-- the Start module (Start.lua's tour wrapper and TourDue/StartTour are the real ones)
CDTL3.Start = {}
function CDTL3.Start.ResolveStale() end
function CDTL3.Start.OnProfileShutdown() end
function CDTL3.Start:TourStep(i) TOUR_STEPS[#TOUR_STEPS + 1] = i end

-- the release's OnInitialize as far as these tests need it: the saved variables with the defaults
function CDTL3:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("CDTL3DB", DEFAULTS, true)
end

-- a stub AceLocale for Flights.lua: every key is its own text
function LoadLocaleStub()
	local AL = LibStub:NewLibrary("AceLocale-3.0", 1)
	function AL:GetLocale() return setmetatable({}, { __index = function(_, k) return k end }) end
end
