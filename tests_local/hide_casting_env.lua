-- Stub environment for the Hide while casting tests (loaded before the extracted addon code).
UNKNOWN_EVENTS = {}
CAST, CHANNEL, CAST_ERROR = nil, nil, false
TIMER_QUEUE = {}
REFRESH_CALLS = 0
IN_COMBAT = false

function UnitCastingInfo(unit)
	if CAST_ERROR then error("secret value") end
	if unit == "player" then return CAST end
end
function UnitChannelInfo(unit)
	if unit == "player" then return CHANNEL end
end
function UnitAffectingCombat() return IN_COMBAT end
C_Timer = { After = function(d, fn) TIMER_QUEUE[#TIMER_QUEUE + 1] = { d = d, fn = fn } end }
function nextFrame()
	local q = TIMER_QUEUE
	TIMER_QUEUE = {}
	for _, t in ipairs(q) do t.fn() end
end

function CreateFrame()
	local f = { registered = {}, scripts = {} }
	function f:SetScript(name, fn) self.scripts[name] = fn end
	function f:RegisterUnitEvent(ev, u1, u2)
		if UNKNOWN_EVENTS[ev] then error("Attempt to register unknown event \"" .. ev .. "\"") end
		self.registered[ev] = { u1, u2 }
	end
	function f:RegisterEvent(ev)
		if UNKNOWN_EVENTS[ev] then error("Attempt to register unknown event \"" .. ev .. "\"") end
		self.registered[ev] = { "*" }
	end
	function f:UnregisterEvent(ev)
		if UNKNOWN_EVENTS[ev] then error("Attempt to unregister unknown event \"" .. ev .. "\"") end
		self.registered[ev] = nil
	end
	return f
end

local function newFrame(withAnim)
	local f = { alpha = 1, outPlays = 0, inPlays = 0, childCount = 1 }
	function f:GetAlpha() return self.alpha end
	function f:SetAlpha(a) self.alpha = a end
	if withAnim then
		f.animateOut = { IsPlaying = function() return false end,
			Play = function() f.outPlays = f.outPlays + 1; f.alpha = 0 end }
		f.animateIn = { IsPlaying = function() return false end,
			Play = function() f.inPlays = f.inPlays + 1; f.alpha = 1 end }
	end
	return f
end
newTestFrame = newFrame
FR = { lane = newFrame(false), bar = newFrame(true), ready = newFrame(false) }

CDTL3 = {
	db = { profile = { global = { hideOutOfCombat = false, hideWhileCasting = false,
		unlockFrames = false, debugMode = false, autohide = false } } },
	lanes = { [1] = true }, barFrames = { [1] = true },
	testing = false, combat = false, casting = false, enabled = false,
	retailAPI = true, tocversion = 11507, isForever = true,
	succeeded = 0,
}
function CDTL3:Print() end
function CDTL3:RegisterEvent() end
function CDTL3:UnregisterEvent() end
function CDTL3:UNIT_SPELLCAST_SUCCEEDED() CDTL3.succeeded = CDTL3.succeeded + 1 end
function CDTL3:RefreshLane(k) REFRESH_CALLS = REFRESH_CALLS + 1; CDTL3:Autohide(FR.lane, { alpha = 1 }) end
function CDTL3:RefreshBarFrame(k) REFRESH_CALLS = REFRESH_CALLS + 1; CDTL3:Autohide(FR.bar, { alpha = 1 }) end
function CDTL3:RefreshReady(i) REFRESH_CALLS = REFRESH_CALLS + 1; CDTL3:Autohide(FR.ready, nil) end
CDTL3_Ready_1 = true
