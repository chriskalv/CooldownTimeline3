-- Stub world (from the review): time, frames, 0.3 s fade animations with SetToFinalAlpha,
-- C_Timer queue (After(0) = next frame), unit event frame, client cast state.
NOW, FRAME = 0, 0
TIMERS = {}
CAST, CHANNEL, CAST_ERR = nil, nil, false
IN_COMBAT = false
GA_MODE = "base"   -- "base": GetAlpha ignores running animations; "anim": returns animated alpha
UNKNOWN = {}
REFRESHES = 0

C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = { at = NOW + d, fr = FRAME + 1, fn = fn } end }
function UnitCastingInfo(u) if CAST_ERR then error("boom") end if u == "player" then return CAST end end
function UnitChannelInfo(u) if u == "player" then return CHANNEL end end
function UnitAffectingCombat() return IN_COMBAT end

function CreateFrame()
	local f = { reg = {}, scripts = {} }
	function f:SetScript(n, fn) self.scripts[n] = fn end
	function f:RegisterUnitEvent(ev, u1, u2)
		if UNKNOWN[ev] then error("unknown event " .. ev) end
		self.reg[ev] = { [u1 or "?"] = true, [u2 or "?"] = true }
	end
	function f:RegisterEvent(ev)
		if UNKNOWN[ev] then error("unknown event " .. ev) end
		self.reg[ev] = { ["*"] = true }
	end
	function f:UnregisterEvent(ev)
		if UNKNOWN[ev] then error("unknown event " .. ev) end
		self.reg[ev] = nil
	end
	return f
end

local function animValue(a) local p = (NOW - a.t0) / 0.3; if p > 1 then p = 1 end; return a.from + (a.to - a.from) * p end
local function newAnim(f, from, to)
	local a = { playing = false, from = from, to = to, plays = 0 }
	function a:IsPlaying() return self.playing end
	function a:Play() self.playing = true; self.t0 = NOW; self.plays = self.plays + 1; f.last = self end
	function a:Stop() self.playing = false end
	return a
end
local function newFrame(name, anim)
	local f = { name = name, base = 1, childCount = 1 }
	function f:GetAlpha()
		if GA_MODE == "anim" and self.last and self.last.playing then return animValue(self.last) end
		return self.base
	end
	function f:SetAlpha(v) self.base = v end
	function f:Rendered()
		if self.last and self.last.playing then return animValue(self.last) end
		return self.base
	end
	if anim then
		f.animateIn = newAnim(f, 0, 1)
		f.animateOut = newAnim(f, 1, 0)
	end
	return f
end
FRAMES = { newFrame("lane", true), newFrame("bar", true), newFrame("plain", false) }

function step(dt)
	FRAME = FRAME + 1
	NOW = NOW + (dt or 1 / 60)
	local due, keep = {}, {}
	for _, t in ipairs(TIMERS) do
		if t.at <= NOW + 1e-9 and t.fr <= FRAME then due[#due + 1] = t else keep[#keep + 1] = t end
	end
	TIMERS = keep
	for _, t in ipairs(due) do t.fn() end
	for _, f in ipairs(FRAMES) do
		for _, a in ipairs({ f.animateIn, f.animateOut }) do
			if a and a.playing and NOW - a.t0 >= 0.3 - 1e-9 then a.playing = false; f.base = a.to end
		end
		-- the real OnUpdate only runs Autohide when triggerUpdate is set (child changes)
		if f.triggerUpdate then f.triggerUpdate = false; CDTL3:Autohide(f, { alpha = 1 }) end
	end
end
function run(sec) local n = math.floor(sec * 60 + 0.5); for _ = 1, n do step() end end

function fire(ev, unit)
	local r = CDTL3.unitEventFrame.reg[ev]
	if not r then return false end
	if not (r[unit] or r["*"]) then return false end
	CDTL3.unitEventFrame.scripts.OnEvent(CDTL3.unitEventFrame, ev, unit)
	return true
end

CDTL3 = {
	db = { profile = { global = { hideOutOfCombat = false, hideWhileCasting = true,
		unlockFrames = false, debugMode = false, autohide = false },
		ready = { ready1 = { pTime = 0 }, ready2 = { pTime = 0 }, ready3 = { pTime = 0 } } } },
	lanes = { { number = 1 } }, barFrames = { { number = 1 } },
	testing = false, combat = false, casting = false, enabled = false,
	retailAPI = false, tocversion = 11507, isForever = true,
}
function CDTL3:Print() end
function CDTL3:RegisterEvent() end
function CDTL3:UnregisterEvent() end
function CDTL3:UNIT_SPELLCAST_SUCCEEDED() end
REFRESH_ARGS = {}
function CDTL3:RefreshLane(i) REFRESH_ARGS.lane = i; REFRESHES = REFRESHES + 1; CDTL3:Autohide(FRAMES[1], { alpha = 1 }) end
function CDTL3:RefreshBarFrame(i) REFRESH_ARGS.bar = i; REFRESHES = REFRESHES + 1; CDTL3:Autohide(FRAMES[2], { alpha = 1 }) end
function CDTL3:RefreshReady() REFRESHES = REFRESHES + 1; CDTL3:Autohide(FRAMES[3], nil) end
CDTL3_Ready_1 = { }

function reset(opts)
	opts = opts or {}
	NOW, FRAME, TIMERS = 0, 0, {}
	CAST, CHANNEL, CAST_ERR, IN_COMBAT = nil, nil, false, false
	UNKNOWN = opts.unknown or {}
	GA_MODE = opts.ga or "base"
	REFRESHES = 0
	local g = CDTL3.db.profile.global
	g.hideOutOfCombat = opts.hoc or false
	g.hideWhileCasting = (opts.hwc == nil) and true or opts.hwc
	g.unlockFrames = opts.unlock or false
	g.debugMode = false
	g.autohide = opts.autohide or false
	CDTL3.testing = false
	CDTL3.enabled = false
	CDTL3.combat = false
	CDTL3.casting = false
	CDTL3.unitEventFrame.reg = {}
	for _, f in ipairs(FRAMES) do
		f.base = 1; f.last = nil; f.triggerUpdate = false
		if f.animateIn then f.animateIn.playing = false; f.animateOut.playing = false; f.animateIn.plays = 0; f.animateOut.plays = 0 end
	end
	CDTL3:TurnOn()
end
function rendered()
	local out = {}
	for i, f in ipairs(FRAMES) do out[i] = f:Rendered() end
	return out
end
