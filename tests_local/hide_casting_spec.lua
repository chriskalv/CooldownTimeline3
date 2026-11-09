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
	for _, f in pairs(FR) do f.alpha = 1 end
	REFRESH_CALLS = 0
end
local function visible() return FR.lane.alpha == 1 and FR.bar.alpha == 1 and FR.ready.alpha == 1 end
local function hidden() return FR.lane.alpha == 0 and FR.bar.alpha == 0 and FR.ready.alpha == 0 end

-- (a) Autohide matrix
for _, hoc in ipairs({ false, true }) do
for _, hwc in ipairs({ false, true }) do
for _, combat in ipairs({ false, true }) do
for _, casting in ipairs({ false, true }) do
for _, exc in ipairs({ "none", "testing", "unlock", "debug" }) do
for _, startAlpha in ipairs({ 1, 0 }) do
	reset()
	gl.hideOutOfCombat, gl.hideWhileCasting = hoc, hwc
	CDTL3.combat, CDTL3.casting = combat, casting
	CDTL3.testing = exc == "testing"
	gl.unlockFrames = exc == "unlock"
	gl.debugMode = exc == "debug"
	local expectHidden = ((hoc and not combat) or (hwc and casting)) and exc == "none"
	local plain = newTestFrame(false)
	plain.alpha = startAlpha
	CDTL3:Autohide(plain, { alpha = 1 })
	local anim = newTestFrame(true)
	anim.alpha = startAlpha
	CDTL3:Autohide(anim, { alpha = 1 })
	local tag = string.format("matrix hoc=%s hwc=%s combat=%s casting=%s exc=%s start=%s",
		tostring(hoc), tostring(hwc), tostring(combat), tostring(casting), exc, tostring(startAlpha))
	if expectHidden then
		check(plain.alpha == 0, tag .. ": plain frame should be alpha 0")
		check(anim.outPlays == (startAlpha ~= 0 and 1 or 0), tag .. ": animateOut should play once when visible")
		check(anim.alpha == 0, tag .. ": animated frame should end hidden")
	else
		check(plain.alpha == 1, tag .. ": plain frame should be alpha 1")
		check(anim.outPlays == 0, tag .. ": animateOut must not play")
		check(anim.alpha == 1, tag .. ": animated frame should be visible")
	end
end end end end end end

-- ApplyCombatVisibility only skips when both options are off
reset(); CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 0, "ApplyCombatVisibility should do nothing with both options off")
reset(); gl.hideWhileCasting = true; CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 3, "ApplyCombatVisibility should refresh with hideWhileCasting on (got " .. REFRESH_CALLS .. ")")
reset(); gl.hideOutOfCombat = true; CDTL3:ApplyCombatVisibility()
check(REFRESH_CALLS == 3, "ApplyCombatVisibility should refresh with hideOutOfCombat on")

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

return results
