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
	local f = { alpha = 1, outPlays = 0, inPlays = 0, childCount = 1, stops = 0 }
	function f:GetAlpha() return self.alpha end
	function f:SetAlpha(a) self.alpha = a end
	if withAnim then
		f.animateOut = { IsPlaying = function() return false end, Stop = function() f.stops = f.stops + 1 end,
			Play = function() f.outPlays = f.outPlays + 1; f.alpha = 0 end }
		f.animateIn = { IsPlaying = function() return false end, Stop = function() f.stops = f.stops + 1 end,
			Play = function() f.inPlays = f.inPlays + 1; f.alpha = 1 end }
	end
	return f
end
newTestFrame = newFrame
FR = { lane = newFrame(false), bar = newFrame(true), ready = newFrame(false) }

-- the settings of lane 1, bar frame 1 and ready frame 1 (Show, Dim instead of hide)
local function frameSettings() return { alpha = 1, showMode = "GLOBAL", dimInsteadOfHide = false, dimAlpha = 0.3 } end
FLIGHT = false
function UnitExists() return false end

CDTL3 = {
	db = { profile = {
		global = { hideOutOfCombat = false, hideWhileCasting = false,
			unlockFrames = false, debugMode = false, autohide = false },
		lanes = { lane1 = frameSettings() }, barFrames = { frame1 = frameSettings() }, ready = { ready1 = frameSettings() },
	} },
	lanes = { { number = 1 } }, barFrames = { { number = 1 } },
	testing = false, combat = false, casting = false, enabled = false, inEncounter = false,
	retailAPI = true, tocversion = 11507, isForever = true,
	succeeded = 0,
	Flights = { Holds = function() return FLIGHT end },
}
function CDTL3:Print() end
function CDTL3:RegisterEvent() end
function CDTL3:UnregisterEvent() end
function CDTL3:UNIT_SPELLCAST_SUCCEEDED() CDTL3.succeeded = CDTL3.succeeded + 1 end
local p = CDTL3.db.profile
function CDTL3:RefreshLane(k) REFRESH_CALLS = REFRESH_CALLS + 1; CDTL3:Autohide(FR.lane, p.lanes["lane" .. k]) end
function CDTL3:RefreshBarFrame(k) REFRESH_CALLS = REFRESH_CALLS + 1; CDTL3:Autohide(FR.bar, p.barFrames["frame" .. k]) end
function CDTL3:RefreshReady(i) REFRESH_CALLS = REFRESH_CALLS + 1; CDTL3:Autohide(FR.ready, p.ready["ready" .. i]) end
function ResetFrameSettings()
	p.lanes.lane1, p.barFrames.frame1, p.ready.ready1 = frameSettings(), frameSettings(), frameSettings()
end
CDTL3_Ready_1 = true

-- Frames with the release's own Show and hide animations (3.3.0, CDTL3:SetFadeAnimations in
-- Lanes.lua): animation groups that run in game time, as in the client. While a group plays, its
-- Alpha (and Scale) animation drives the frame's alpha (and scale), and GetAlpha reads the driven
-- value; when it stops (Stop) or runs to its end the frame is back at the alpha it had before
-- Play; only a group that ran to its end calls OnFinished (requested false), where the release
-- sets the frame's resting alpha. ANIM_GROUPS lists every group so tickAnims can run them.
ANIM_GROUPS = {}
local function newAnim(kind)
	local a = { kind = kind, duration = 0, order = 1 }
	function a:SetDuration(d) self.duration = d end
	function a:SetOrder(o) self.order = o end
	function a:SetSmoothing() end
	function a:SetOrigin() end
	function a:SetFromAlpha(v) self.fromA = v end
	function a:SetToAlpha(v) self.toA = v end
	function a:SetScaleFrom(x) self.fromS = x end
	function a:SetScaleTo(x) self.toS = x end
	return a
end
function newAnimFrame(childCount)
	local f = { alpha = 1, scale = 1, childCount = childCount or 1, plays = { animateIn = 0, animateOut = 0 } }
	function f:GetAlpha() return self.alpha end
	function f:SetAlpha(v) self.alpha = v end
	function f:CreateAnimationGroup()
		local g = { anims = {}, playing = false, t = 0, frame = f, scripts = {} }
		function g:SetLooping() end
		function g:CreateAnimation(kind) local a = newAnim(kind); self.anims[#self.anims + 1] = a; return a end
		function g:SetScript(name, fn) self.scripts[name] = fn end
		function g:IsPlaying() return self.playing end
		function g:Total()
			local per = {}
			for _, a in ipairs(self.anims) do per[a.order] = math.max(per[a.order] or 0, a.duration) end
			local sum = 0
			for _, d in pairs(per) do sum = sum + d end
			return sum
		end
		function g:Apply()
			-- the animations of the current order drive the frame
			local t, start = self.t, 0
			for order = 1, 100 do
				local d = 0
				for _, a in ipairs(self.anims) do if a.order == order then d = math.max(d, a.duration) end end
				if d == 0 then break end
				if t <= start + d or order == 100 then
					local k = math.min(1, (t - start) / d)
					for _, a in ipairs(self.anims) do
						if a.order == order then
							if a.kind == "Alpha" then f.alpha = a.fromA + (a.toA - a.fromA) * k end
							if a.kind == "Scale" then f.scale = a.fromS + (a.toS - a.fromS) * k end
						end
					end
					return
				end
				start = start + d
			end
		end
		function g:Play()
			for _, o in ipairs({ "animateIn", "animateOut" }) do
				if f[o] == self then f.plays[o] = f.plays[o] + 1 end
			end
			self.base, self.playing, self.t = f.alpha, true, 0
			self:Apply()
		end
		function g:Rest()
			self.playing = false
			f.alpha, f.scale = self.base, 1
		end
		function g:Stop() if self.playing then self:Rest() end end
		function g:Tick(dt)
			if not self.playing then return end
			self.t = self.t + dt
			if self.t >= self:Total() then
				self:Rest()
				if self.scripts.OnFinished then self.scripts.OnFinished(self, false) end
			else
				self:Apply()
			end
		end
		ANIM_GROUPS[#ANIM_GROUPS + 1] = g
		return g
	end
	return f
end
function tickAnims(dt)
	for _, g in ipairs(ANIM_GROUPS) do g:Tick(dt) end
end
