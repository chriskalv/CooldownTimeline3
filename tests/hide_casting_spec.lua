-- Spec for Hide while casting (runs after hide_casting_env.lua and the extracted addon code).
local results = { pass = 0, fail = 0, msgs = {} }
local function check(cond, msg)
	if cond then results.pass = results.pass + 1
	else results.fail = results.fail + 1; results.msgs[#results.msgs + 1] = msg end
end
local gl = CDTL3.db.profile.global

local function fire(event, unit)
	local f = CDTL3.unitEventFrame
	local reg = f.registered[event]
	if not reg then return false end
	if reg[1] ~= "*" and reg[1] ~= unit and reg[2] ~= unit then return false end
	f.scripts.OnEvent(f, event, unit)
	return true
end

local function reset()
	if CDTL3.enabled then CDTL3:TurnOff() end
	CAST, CHANNEL, CAST_ERROR = nil, nil, false
	nextFrame()	-- like the client: pending timers of the last scenario still run
	TIMER_QUEUE = {}
	UNKNOWN_EVENTS = {}
	IN_COMBAT = false
	CDTL3.combat, CDTL3.casting, CDTL3.testing = false, false, false
	gl.hideOutOfCombat, gl.hideWhileCasting = false, false
	gl.unlockFrames, gl.debugMode, gl.autohide = false, false, false
	CDTL3.inEncounter, FLIGHT = false, false
	ResetFrameSettings()
	for _, f in pairs(FR) do f.alpha = 1 end
	REFRESH_CALLS = 0
end
local function visible() return FR.lane.alpha == 1 and FR.bar.alpha == 1 and FR.ready.alpha == 1 end
local function hidden() return FR.lane.alpha == 0 and FR.bar.alpha == 0 and FR.ready.alpha == 0 end

-- (a) Autohide matrix: each frame's Show (Use the global setting with Hide out of combat on or
-- off, Always, Only in combat, Boss fights only) x Dim instead of hide x Hide while casting x
-- combat x boss fight x casting x the exceptions (test mode, unlocked frames, debug, a flight) x
-- a frame shown or already hidden. Hide while casting lies over the Show rule, Always included.
local MODES = { "GLOBAL", "ALWAYS", "COMBAT", "BOSS" }
local EXCEPTIONS = { "none", "testing", "unlock", "debug", "flight" }
local function showHides(mode, hoc, combat, boss)
	if mode == "ALWAYS" then return false end
	if mode == "COMBAT" then return not combat end
	if mode == "BOSS" then return not boss end
	return hoc and not combat
end
for _, mode in ipairs(MODES) do
for _, dim in ipairs({ false, true }) do
for _, hoc in ipairs({ false, true }) do
for _, hwc in ipairs({ false, true }) do
for _, combat in ipairs({ false, true }) do
for _, boss in ipairs({ false, true }) do
for _, casting in ipairs({ false, true }) do
for _, exc in ipairs(EXCEPTIONS) do
for _, startAlpha in ipairs({ 1, 0 }) do
	reset()
	gl.hideOutOfCombat, gl.hideWhileCasting = hoc, hwc
	CDTL3.combat, CDTL3.casting, CDTL3.inEncounter = combat, casting, boss
	CDTL3.testing = exc == "testing"
	gl.unlockFrames = exc == "unlock"
	gl.debugMode = exc == "debug"
	FLIGHT = exc == "flight"
	local s = { alpha = 1, showMode = mode, dimInsteadOfHide = dim, dimAlpha = 0.3 }
	local expectHidden = (showHides(mode, hoc, combat, boss) or (hwc and casting)) and exc == "none"
	local plain = newTestFrame(false)
	plain.alpha = startAlpha
	CDTL3:Autohide(plain, s)
	local anim = newTestFrame(true)
	anim.alpha = startAlpha
	CDTL3:Autohide(anim, s)
	local tag = string.format("matrix show=%s dim=%s hoc=%s hwc=%s combat=%s boss=%s casting=%s exc=%s start=%s",
		mode, tostring(dim), tostring(hoc), tostring(hwc), tostring(combat), tostring(boss), tostring(casting), exc, tostring(startAlpha))
	if expectHidden and dim then
		check(plain.alpha == 0.3 and anim.alpha == 0.3, tag .. ": dimmed to 0.3 (" .. plain.alpha .. "/" .. anim.alpha .. ")")
		check(anim.outPlays == 0, tag .. ": a dimmed frame plays no fade-out")
	elseif expectHidden then
		check(plain.alpha == 0, tag .. ": plain frame should be alpha 0")
		check(anim.outPlays == (startAlpha ~= 0 and 1 or 0), tag .. ": animateOut should play once when visible")
		check(anim.alpha == 0, tag .. ": animated frame should end hidden")
	else
		check(plain.alpha == 1, tag .. ": plain frame should be alpha 1")
		check(anim.outPlays == 0, tag .. ": animateOut must not play")
		check(anim.alpha == 1, tag .. ": animated frame should be visible")
	end
	check(CDTL3:CastRuleHides() == (hwc and casting), tag .. ": CastRuleHides")
end end end end end end end end end
FLIGHT = false

-- ApplyCombatVisibility: skips only when no Show rule changes with combat and Hide while casting
-- is off; with bossOnly only the Boss fights only frames
local p = CDTL3.db.profile
reset(); CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 0, "ApplyCombatVisibility should do nothing with both options off")
reset(); gl.hideWhileCasting = true; CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 3, "ApplyCombatVisibility should refresh with hideWhileCasting on (got " .. REFRESH_CALLS .. ")")
reset(); gl.hideOutOfCombat = true; CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 3, "ApplyCombatVisibility should refresh with hideOutOfCombat on")
reset(); p.barFrames.frame1.showMode = "COMBAT"; CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 3, "ApplyCombatVisibility should refresh with a frame on Only in combat")
reset(); p.lanes.lane1.showMode = "ALWAYS"; CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 0, "ApplyCombatVisibility: Always alone changes nothing with combat")
reset(); gl.hideWhileCasting = true; CDTL3:ApplyCombatVisibility(true)
check(REFRESH_CALLS == 0, "ApplyCombatVisibility(bossOnly) refreshes only Boss fights only frames")
reset(); gl.hideWhileCasting = true; p.ready.ready1.showMode = "BOSS"; CDTL3:ApplyCombatVisibility(true)
check(REFRESH_CALLS == 1, "ApplyCombatVisibility(bossOnly) refreshes the Boss fights only frame (" .. REFRESH_CALLS .. ")")

-- registration
reset(); CDTL3:TurnOn()
local f = CDTL3.unitEventFrame
for _, ev in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
		"UNIT_SPELLCAST_EMPOWER_START", "UNIT_SPELLCAST_EMPOWER_STOP" }) do
	local r = f.registered[ev]
	check(r and r[1] == "player" and r[2] == nil, "TurnOn should register " .. ev .. " for the player only")
	check(type(CDTL3[ev]) == "function", "handler CDTL3." .. ev .. " missing")
end
check(f.registered.UNIT_SPELLCAST_SUCCEEDED and f.registered.UNIT_SPELLCAST_SUCCEEDED[2] == "pet",
	"SUCCEEDED registration for player and pet must stay")
CDTL3:TurnOff()
for ev in pairs(f.registered) do
	check(not ev:find("^UNIT_SPELLCAST"), "TurnOff should unregister " .. ev)
end

-- EMPOWER unknown to the client: TurnOn/TurnOff must not fail, the rest stays registered
reset()
UNKNOWN_EVENTS = { UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_STOP = true }
local ok, err = pcall(CDTL3.TurnOn, CDTL3)
check(ok, "TurnOn must survive unknown EMPOWER events: " .. tostring(err))
check(f.registered.UNIT_SPELLCAST_CHANNEL_STOP ~= nil and f.registered.UNIT_SPELLCAST_EMPOWER_START == nil,
	"without EMPOWER the other cast events stay registered")
check(CDTL3.enabled == true, "TurnOn should complete")
ok, err = pcall(CDTL3.TurnOff, CDTL3)
check(ok, "TurnOff must survive unknown EMPOWER events: " .. tostring(err))
UNKNOWN_EVENTS = {}

-- (b) event sequences, Hide while casting on
local function scenario(name, fn)
	reset()
	gl.hideWhileCasting = true
	CDTL3:TurnOn()
	REFRESH_CALLS = 0
	local ok2, e = pcall(fn)
	check(ok2, name .. ": error " .. tostring(e))
end

scenario("START->STOP", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(CDTL3.casting == true and hidden(), "START->STOP: frames hidden while casting")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player")
	-- stop events read on the next frame (a chained START may follow in the same frame)
	check(CDTL3.casting == true and hidden() and #TIMER_QUEUE >= 1, "START->STOP: unchanged in the STOP frame, recheck pending")
	nextFrame()
	check(CDTL3.casting == false and visible(), "START->STOP: frames back on the next frame")
end)
scenario("START->INTERRUPTED", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(hidden(), "START->INTERRUPTED: hidden")
	CAST = nil; fire("UNIT_SPELLCAST_INTERRUPTED", "player"); nextFrame()
	check(CDTL3.casting == false and visible(), "START->INTERRUPTED: visible after INTERRUPTED")
end)
scenario("START->FAILED", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	CAST = nil; fire("UNIT_SPELLCAST_FAILED", "player"); nextFrame()
	check(CDTL3.casting == false and visible(), "START->FAILED: visible after FAILED")
end)
scenario("CHANNEL", function()
	CHANNEL = "Arcane Missiles"; fire("UNIT_SPELLCAST_CHANNEL_START", "player")
	check(CDTL3.casting == true and hidden(), "CHANNEL: hidden while channeling")
	CHANNEL = nil; fire("UNIT_SPELLCAST_CHANNEL_STOP", "player"); nextFrame()
	check(CDTL3.casting == false and visible(), "CHANNEL: visible after CHANNEL_STOP")
end)
scenario("EMPOWER", function()
	CHANNEL = "Fire Breath"; fire("UNIT_SPELLCAST_EMPOWER_START", "player")
	check(CDTL3.casting == true, "EMPOWER: casting")
	CHANNEL = nil; fire("UNIT_SPELLCAST_EMPOWER_STOP", "player"); nextFrame()
	check(CDTL3.casting == false, "EMPOWER: done")
end)
scenario("START before the client reports the cast", function()
	CAST = nil; fire("UNIT_SPELLCAST_START", "player")
	check(CDTL3.casting == true and hidden(), "START sets casting even before UnitCastingInfo reports it")
end)
scenario("STOP with cast still reported", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	fire("UNIT_SPELLCAST_STOP", "player")	-- client still reports the cast this frame
	check(CDTL3.casting == true, "STOP-same-frame: state follows the read value")
	CAST = nil
	nextFrame()
	check(CDTL3.casting == false and visible(), "STOP-same-frame: next-frame read shows the frames again")
end)
scenario("STOP + INTERRUPTED schedule a recheck", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	fire("UNIT_SPELLCAST_STOP", "player")
	fire("UNIT_SPELLCAST_INTERRUPTED", "player")
	check(#TIMER_QUEUE >= 1, "a pending recheck, got " .. #TIMER_QUEUE)
	CAST = nil; nextFrame()
	check(CDTL3.casting == false and visible(), "recheck clears the state")
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player")
	fire("UNIT_SPELLCAST_STOP", "player")
	check(#TIMER_QUEUE >= 1, "a later stop schedules a new recheck")
	CAST = nil; nextFrame()
	check(CDTL3.casting == false, "second recheck clears the state")
end)
scenario("chained casts in the same frame", function()
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player")
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player")
	local n = REFRESH_CALLS
	nextFrame()
	check(CDTL3.casting == true and hidden() and REFRESH_CALLS == n, "chain: frames stay hidden, no re-apply between the casts")
end)
scenario("instant spell", function()
	fire("UNIT_SPELLCAST_SUCCEEDED", "player")
	check(CDTL3.succeeded == 1 or CDTL3.succeeded > 0, "SUCCEEDED still delivered")
	check(CDTL3.casting == false and visible() and REFRESH_CALLS == 0, "instant spell changes nothing")
end)
scenario("error in UnitCastingInfo", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	CAST_ERROR = true
	fire("UNIT_SPELLCAST_STOP", "player")
	nextFrame()
	check(CDTL3.casting == false and visible(), "a read error counts as not casting")
end)
scenario("other units", function()
	CAST = "Fireball"
	CDTL3:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "target")
	check(CDTL3.casting == false, "a START for another unit is ignored")
	CDTL3.casting = true
	CDTL3:UNIT_SPELLCAST_STOP("UNIT_SPELLCAST_STOP", "party1")
	check(CDTL3.casting == true and #TIMER_QUEUE == 0, "a STOP for another unit is ignored")
end)
scenario("apply only on change", function()
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	local n = REFRESH_CALLS
	fire("UNIT_SPELLCAST_START", "player")
	check(REFRESH_CALLS == n, "a second START without change does not re-apply")
end)
scenario("option off", function()
	gl.hideWhileCasting = false
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(CDTL3.casting == true and REFRESH_CALLS == 0 and visible(), "option off: state tracked, frames untouched")
	CDTL3:RefreshLane(1)
	check(FR.lane.alpha == 1, "option off: the per-frame refresh keeps the frames shown")
end)
scenario("unlock wins", function()
	gl.unlockFrames = true
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(CDTL3.casting == true and visible(), "unlocked frames stay visible while casting")
end)
scenario("combined with hide out of combat", function()
	gl.hideOutOfCombat = true
	CDTL3.combat = true
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(hidden(), "in combat and casting: hidden")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); nextFrame()
	check(visible(), "in combat, cast over: visible")
end)

-- (b2) the new Show rules of the release with Hide while casting
local function allShow(mode, dim)
	for _, s in ipairs({ p.lanes.lane1, p.barFrames.frame1, p.ready.ready1 }) do s.showMode, s.dimInsteadOfHide = mode, dim end
end
local function dimmed() return FR.lane.alpha == 0.3 and FR.bar.alpha == 0.3 and FR.ready.alpha == 0.3 end
scenario("Show Always", function()
	allShow("ALWAYS", false)
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(hidden(), "Show Always: hidden while casting")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); nextFrame()
	check(visible(), "Show Always: visible after the cast")
end)
scenario("Only in combat, dim", function()
	allShow("COMBAT", true)
	CDTL3.combat = true
	CDTL3:ApplyCombatVisibility()
	check(visible(), "Only in combat, dim: visible in combat")
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(dimmed(), "Only in combat, dim: dimmed while casting in combat")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); nextFrame()
	check(visible(), "Only in combat, dim: visible after the cast")
	CDTL3.combat = false; CDTL3:ApplyCombatVisibility()
	check(dimmed(), "Only in combat, dim: dimmed out of combat")
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); nextFrame()
	check(dimmed(), "Only in combat, dim: still dimmed out of combat after a cast")
end)
scenario("Boss fights only", function()
	allShow("BOSS", false)
	CDTL3.inEncounter = true; CDTL3:ApplyCombatVisibility(true)
	check(visible(), "Boss fights only: visible in a boss fight")
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(hidden(), "Boss fights only: hidden while casting in a boss fight")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); nextFrame()
	check(visible(), "Boss fights only: visible after the cast")
end)
scenario("flight", function()
	FLIGHT = true
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(CDTL3.casting == true and visible(), "a flight timer keeps its frames showing while casting")
	FLIGHT = false
end)
scenario("debug", function()
	gl.debugMode = true
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(visible(), "debug mode keeps the frames showing while casting")
end)
scenario("testing", function()
	CDTL3.testing = true
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	check(visible(), "test mode keeps the frames showing while casting")
end)

-- (c) TurnOn during a cast or channel
reset(); CAST = "Hearthstone"; CDTL3:TurnOn()
check(CDTL3.casting == true, "TurnOn during a cast seeds casting = true")
CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); nextFrame()
check(CDTL3.casting == false, "after that cast ends the state clears")
reset(); gl.hideWhileCasting = true; CAST = "Hearthstone"; CDTL3:TurnOn()
check(CDTL3.casting == true and hidden(), "TurnOn during a cast hides the frames at once")
CDTL3:TurnOff()
check(CDTL3.casting == false and visible(), "TurnOff during a cast shows the frames at once")
reset(); CHANNEL = "Drain Life"; CDTL3:TurnOn()
check(CDTL3.casting == true, "TurnOn during a channel seeds casting = true")
reset(); CDTL3.casting = true; CDTL3:TurnOn()
check(CDTL3.casting == false, "TurnOn outside a cast clears a stale state")
reset(); CAST_ERROR = true; ok, err = pcall(CDTL3.TurnOn, CDTL3)
check(ok and CDTL3.casting == false, "TurnOn with a failing read: not casting, no error")
reset(); CAST = "Fireball"; CDTL3:TurnOn(); CDTL3:TurnOff()
check(CDTL3.casting == false, "TurnOff clears the state")
reset(); gl.hideWhileCasting = true; CAST = "Fireball"; CDTL3:TurnOn()
fire("UNIT_SPELLCAST_STOP", "player"); CDTL3:TurnOff(); nextFrame()
check(CDTL3.casting == false and visible(), "a recheck after TurnOff leaves the state cleared")

-- (d) Hide while casting with the release's Show and hide tab (3.3.0): every lane, bar frame and
-- ready frame shows and hides with its own animation (Fade or Scale, length, loops, Bounce), the
-- real groups of CDTL3:SetFadeAnimations (Lanes.lua) on the timed animation stub of the env. For
-- each shape (Fade or Scale, 1 or 2 plays, Bounce or not, 0.3 or 1.5 s; shown again with the same
-- shape or the longest one), with Auto-hide Frames on and off, a frame alpha of 1 and 0.8, Autohide only on the
-- cast edges or on every frame, and casts shorter than, about as long as and longer than the hide
-- animation, then a second cast right after: the frames are fully hidden at the end of a long cast,
-- never come back during a cast, never go away again after it, and always end at their own alpha
-- and scale with no animation left running (nothing hangs, nothing flickers).
local SAVED_FR = FR
local DT = 0.1
local function settle(n, everyFrame)
	for _ = 1, n do
		nextFrame()
		tickAnims(DT)
		if everyFrame then
			for _, k in ipairs({ "lane", "bar", "ready" }) do CDTL3:Autohide(FR[k], FR[k].cdtl3S) end
		end
	end
end
local function steps(t) return math.floor(t / DT + 0.5) end
local shapes = {}
for _, ty in ipairs({ "FADE", "SCALE" }) do
	for _, loops in ipairs({ 1, 2 }) do
		for _, bounce in ipairs({ false, true }) do
			for _, dur in ipairs({ 0.3, 1.5 }) do
				shapes[#shapes + 1] = { type = ty, loops = loops, bounce = bounce, duration = dur }
			end
		end
	end
end
local function anim(sh, hide)
	local from, to = hide and 1 or 0, hide and 0 or 1
	if sh.type == "SCALE" then from, to = hide and 1 or 0.5, hide and 0.5 or 1 end
	return { type = sh.type, duration = sh.duration, from = from, to = to, loops = sh.loops, bounce = sh.bounce }
end
local function total(sh) return sh.duration * sh.loops end
local cases = 0
for _, hideSh in ipairs(shapes) do
for _, showSh in ipairs({ shapes[#shapes], hideSh }) do
for _, autohide in ipairs({ false, true }) do
for _, fAlpha in ipairs({ 1, 0.8 }) do
for _, everyFrame in ipairs({ false, true }) do
for _, castLen in ipairs({ 0.1, total(hideSh) / 2, total(hideSh) + 0.5 }) do
	reset()
	ANIM_GROUPS = {}
	gl.hideWhileCasting, gl.autohide = true, autohide
	FR = { lane = newAnimFrame(1), bar = newAnimFrame(1), ready = newAnimFrame(1) }
	local all = { lane = p.lanes.lane1, bar = p.barFrames.frame1, ready = p.ready.ready1 }
	for k, st in pairs(all) do
		st.alpha, st.showAnim, st.hideAnim = fAlpha, anim(showSh, false), anim(hideSh, true)
		FR[k].alpha, FR[k].cdtl3S = fAlpha, st
		CDTL3:SetFadeAnimations(FR[k], fAlpha, st)
	end
	CDTL3:TurnOn()
	local tag = string.format("anim hide=%s%d%s/%.1f show=%s%d%s/%.1f autohide=%s alpha=%.1f %s cast=%.2f",
		hideSh.type, hideSh.loops, hideSh.bounce and "b" or "", hideSh.duration,
		showSh.type, showSh.loops, showSh.bounce and "b" or "", showSh.duration,
		tostring(autohide), fAlpha, everyFrame and "every-frame" or "edges", castLen)
	local function each(fn) local ok = true; for _, k in ipairs({ "lane", "bar", "ready" }) do ok = ok and fn(FR[k]) end; return ok end
	local function atRest() return each(function(f)
		return math.abs(f.alpha - fAlpha) < 1e-9 and f.scale == 1 and not f.animateIn:IsPlaying() and not f.animateOut:IsPlaying()
	end) end
	check(atRest(), tag .. ": shown at rest before the cast")
	for castNo = 1, 2 do
		local ins = each(function(f) f.inBefore = f.plays.animateIn; f.outBefore = f.plays.animateOut; return true end)
		CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
		settle(steps(castLen), everyFrame)
		check(each(function(f) return f.plays.animateIn == f.inBefore end), tag .. " #" .. castNo .. ": no show animation during the cast")
		check(each(function(f) return f.plays.animateOut <= f.outBefore + 1 end), tag .. " #" .. castNo .. ": the hide animation plays at most once per cast")
		if castLen > total(hideSh) then
			check(each(function(f) return f.alpha == 0 and f.scale == 1 and not f.animateOut:IsPlaying() end),
				tag .. " #" .. castNo .. ": fully hidden at the end of a long cast")
		end
		local outAtEnd = each(function(f) f.outAtEnd = f.plays.animateOut; f.inAtEnd = f.plays.animateIn; return true end)
		CAST = nil; fire("UNIT_SPELLCAST_STOP", "player")
		settle(steps(total(showSh) + 0.2), everyFrame)
		check(each(function(f) return f.plays.animateOut == f.outAtEnd end), tag .. " #" .. castNo .. ": no hide animation after the cast")
		check(each(function(f) return f.plays.animateIn <= f.inAtEnd + 1 end), tag .. " #" .. castNo .. ": the show animation plays at most once after the cast")
		check(atRest(), tag .. " #" .. castNo .. ": back at its own alpha and scale, nothing running (" .. FR.lane.alpha .. "/" .. FR.bar.alpha .. "/" .. FR.ready.alpha .. ")")
	end
	-- a cast that starts while the show animation of the last one still runs
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player")
	settle(steps(total(hideSh) + 0.5), everyFrame)
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player")
	settle(2, everyFrame)
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player")
	settle(steps(total(hideSh) + 0.5), everyFrame)
	check(each(function(f) return f.alpha == 0 and not f.animateIn:IsPlaying() and not f.animateOut:IsPlaying() end),
		tag .. ": a cast during the show animation hides the frames again")
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player")
	settle(steps(total(showSh) + 0.2), everyFrame)
	check(atRest(), tag .. ": back at rest after the chained casts")
	CDTL3:TurnOff()
	cases = cases + 1
end
end
end
end
end
end
check(cases == 16 * 2 * 2 * 2 * 2 * 3, "animation cases run: " .. cases)
FR = SAVED_FR
ANIM_GROUPS = {}
reset()

return results
