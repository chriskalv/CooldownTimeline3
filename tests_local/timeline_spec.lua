-- Timeline scenarios (0.3 s fades, Autohide only on triggerUpdate or visibility edges), taken
-- over from the review of Hide while casting. RESULTS collects "ok"/"FAIL" lines.
RESULTS = {}
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. m end
local function all(v) local r = rendered(); for _, a in ipairs(r) do if math.abs(a - v) > 1e-6 then return false end end return true end
local function show() local r = rendered(); return string.format("[%.2f %.2f %.2f]", r[1], r[2], r[3]) end
local function settle() CDTL3:ApplyCombatVisibility(); run(0.5) end

local CONFIGS = {
	{ tag = "ah=off ga=base", autohide = false, ga = "base" },
	{ tag = "ah=on  ga=base", autohide = true, ga = "base" },
	{ tag = "ah=off ga=anim", autohide = false, ga = "anim" },
	{ tag = "ah=on  ga=anim", autohide = true, ga = "anim" },
}

local function startStop(kind, stopEv, castLen)
	return function(c)
		reset(c)
		local startEv = (kind == "channel") and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START"
		if kind == "channel" then CHANNEL = "Drain" else CAST = "Fireball" end
		fire(startEv, "player")
		check(CDTL3.casting == true, c.tag .. " " .. stopEv .. ": casting after start")
		run(math.min(castLen, 0.5))
		if castLen >= 0.35 then check(all(0), c.tag .. " " .. stopEv .. ": hidden during cast " .. show()) end
		run(math.max(0, castLen - 0.5))
		CAST, CHANNEL = nil, nil
		fire(stopEv, "player")
		step()	-- stop events read the state on the next frame
		check(CDTL3.casting == false, c.tag .. " " .. stopEv .. ": not casting one frame after stop")
		run(1.0)
		check(all(1), c.tag .. " " .. stopEv .. " (cast " .. castLen .. " s): visible 1 s after stop " .. show())
	end
end

local SCEN = {}
SCEN[#SCEN + 1] = startStop("cast", "UNIT_SPELLCAST_STOP", 1.5)
SCEN[#SCEN + 1] = startStop("cast", "UNIT_SPELLCAST_INTERRUPTED", 1.0)
SCEN[#SCEN + 1] = startStop("cast", "UNIT_SPELLCAST_FAILED", 1.0)
SCEN[#SCEN + 1] = startStop("channel", "UNIT_SPELLCAST_CHANNEL_STOP", 3.0)
-- quick casts / early interrupts shorter than the 0.3 s fade
SCEN[#SCEN + 1] = startStop("cast", "UNIT_SPELLCAST_INTERRUPTED", 0.1)
SCEN[#SCEN + 1] = startStop("cast", "UNIT_SPELLCAST_INTERRUPTED", 0.2)
SCEN[#SCEN + 1] = startStop("cast", "UNIT_SPELLCAST_STOP", 0.25)

-- STOP while the client still reports the cast: next-frame read corrects
SCEN[#SCEN + 1] = function(c)
	reset(c)
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(1.0)
	fire("UNIT_SPELLCAST_STOP", "player")   -- CAST still set in this frame
	check(CDTL3.casting == true, c.tag .. " late-stop: still casting in the stop frame")
	CAST = nil
	step()
	check(CDTL3.casting == false, c.tag .. " late-stop: next frame read clears casting")
	run(1.0)
	check(all(1), c.tag .. " late-stop: visible " .. show())
end
-- instant spell: no START, only SUCCEEDED
SCEN[#SCEN + 1] = function(c)
	reset(c)
	local r0 = REFRESHES
	fire("UNIT_SPELLCAST_SUCCEEDED", "player"); run(0.5)
	check(CDTL3.casting == false and REFRESHES == r0 and all(1), c.tag .. " instant: no change " .. show())
end
-- read error counts as not casting
SCEN[#SCEN + 1] = function(c)
	reset(c)
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(1.0)
	CAST_ERR = true
	local ok = pcall(fire, "UNIT_SPELLCAST_STOP", "player")
	ok = ok and pcall(step)
	check(ok and CDTL3.casting == false, c.tag .. " read error: not casting")
	run(1.0)
	check(all(1), c.tag .. " read error: visible " .. show())
end
-- TurnOn mid-cast
SCEN[#SCEN + 1] = function(c)
	reset(c); CDTL3:TurnOff()
	CAST = "Fireball"
	CDTL3:TurnOn()
	check(CDTL3.casting == true, c.tag .. " TurnOn mid-cast seeds casting")
	run(0.5)
	check(all(0), c.tag .. " TurnOn mid-cast: frames hidden for the rest of the cast " .. show())
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); run(1.0)
	check(all(1), c.tag .. " TurnOn mid-cast: visible after stop " .. show())
end
-- two casts back to back: STOP of cast 1 and START of cast 2 in the same frame
SCEN[#SCEN + 1] = function(c)
	reset(c)
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player"); run(1.5)
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player")
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player")
	check(CDTL3.casting == true, c.tag .. " chain: casting after START 2")
	local maxR = 0
	for _ = 1, 30 do step(); local r = rendered(); for _, a in ipairs(r) do if a > maxR then maxR = a end end end
	check(maxR < 0.05, c.tag .. string.format(" chain: no flash between the casts (max rendered alpha %.2f)", maxR))
	run(0.5)
	check(all(0), c.tag .. " chain: hidden during cast 2 " .. show())
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); run(1.0)
	check(all(1), c.tag .. " chain: visible after cast 2 " .. show())
end
-- chain with the gap of one frame
SCEN[#SCEN + 1] = function(c)
	reset(c)
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player"); run(1.5)
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); step(); step()
	CAST = "Frostbolt"; fire("UNIT_SPELLCAST_START", "player")
	run(1.0)
	check(all(0), c.tag .. " chain+2 frames: hidden during cast 2 " .. show())
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); run(1.0)
	check(all(1), c.tag .. " chain+2 frames: visible after cast 2 " .. show())
end
-- cast when entering combat, both options on
SCEN[#SCEN + 1] = function(c)
	local o = {}; for k, v in pairs(c) do o[k] = v end; o.hoc = true
	reset(o); settle()
	check(all(0), c.tag .. " enter-combat: hidden out of combat " .. show())
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(0.2)
	IN_COMBAT = true; CDTL3:PLAYER_REGEN_DISABLED(); run(0.5)
	check(all(0), c.tag .. " enter-combat: hidden while casting in combat " .. show())
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); run(1.0)
	check(all(1), c.tag .. " enter-combat: visible in combat after cast " .. show())
end
-- combat ends during a cast, both options on
SCEN[#SCEN + 1] = function(c)
	local o = {}; for k, v in pairs(c) do o[k] = v end; o.hoc = true
	reset(o); IN_COMBAT = true; CDTL3:PLAYER_REGEN_DISABLED(); run(0.5)
	check(all(1), c.tag .. " leave-combat: visible in combat " .. show())
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(0.5)
	check(all(0), c.tag .. " leave-combat: hidden while casting " .. show())
	IN_COMBAT = false; CDTL3:PLAYER_REGEN_ENABLED(); run(0.5)
	check(all(0), c.tag .. " leave-combat: still hidden " .. show())
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); run(1.0)
	check(all(0), c.tag .. " leave-combat: hidden out of combat after cast " .. show())
end
-- TurnOff during a cast
SCEN[#SCEN + 1] = function(c)
	reset(c)
	CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(0.5)
	CDTL3:TurnOff()
	check(CDTL3.casting == false, c.tag .. " TurnOff mid-cast clears casting")
	CAST = nil; run(1.0)
	check(all(1), c.tag .. " TurnOff mid-cast: frames visible again " .. show())
end
-- option off: tracked, not hidden; unlock wins; target events ignored
SCEN[#SCEN + 1] = function(c)
	local o = {}; for k, v in pairs(c) do o[k] = v end; o.hwc = false
	reset(o); CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(0.5)
	check(all(1), c.tag .. " option off: visible while casting " .. show())
	o.hwc = true; o.unlock = true
	reset(o); CAST = "Fireball"; fire("UNIT_SPELLCAST_START", "player"); run(0.5)
	check(all(1), c.tag .. " unlock: visible while casting " .. show())
	o.unlock = false
	reset(o)
	local delivered = fire("UNIT_SPELLCAST_START", "target")
	check(not delivered and CDTL3.casting == false, c.tag .. " target START not delivered")
	reset(o); CDTL3.testing = true; CAST = "x"; fire("UNIT_SPELLCAST_START", "player"); run(0.5)
	check(all(1), c.tag .. " testing: visible " .. show())
end
-- double stop (STOP + INTERRUPTED), registration, unknown EMPOWER events
SCEN[#SCEN + 1] = function(c)
	reset(c)
	CAST = "x"; fire("UNIT_SPELLCAST_START", "player"); run(0.6)
	CAST = nil; fire("UNIT_SPELLCAST_STOP", "player"); fire("UNIT_SPELLCAST_INTERRUPTED", "player"); run(1.0)
	check(all(1) and CDTL3.casting == false, c.tag .. " STOP+INTERRUPTED: visible " .. show())
	local reg = CDTL3.unitEventFrame.reg
	local n = 0
	for _, ev in ipairs({ "START", "STOP", "FAILED", "INTERRUPTED", "CHANNEL_START", "CHANNEL_STOP", "EMPOWER_START", "EMPOWER_STOP" }) do
		local r = reg["UNIT_SPELLCAST_" .. ev]
		if r and r.player and not r.pet and not r.target then n = n + 1 end
	end
	check(n == 8, c.tag .. " 8 cast events registered for player only (" .. n .. ")")
	CDTL3:TurnOff()
	local left = 0
	for ev in pairs(reg) do if ev:find("^UNIT_SPELLCAST_") then left = left + 1 end end
	check(left == 0, c.tag .. " TurnOff unregisters all cast events (" .. left .. " left)")
	local o = {}; for k, v in pairs(c) do o[k] = v end
	o.unknown = { UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_STOP = true }
	local ok = pcall(reset, o)
	check(ok and CDTL3.enabled and CDTL3.unitEventFrame.reg.UNIT_SPELLCAST_INTERRUPTED ~= nil and CDTL3.unitEventFrame.reg.UNIT_SPELLCAST_EMPOWER_START == nil, c.tag .. " unknown EMPOWER events: TurnOn ok")
	local ok2 = pcall(CDTL3.TurnOff, CDTL3)
	check(ok2 and not CDTL3.enabled, c.tag .. " unknown EMPOWER events: TurnOff ok")
end

-- ApplyCombatVisibility refreshes by frame number, not list index (lane 1 off, lane 2 on)
SCEN[#SCEN + 1] = function(c)
	reset(c)
	local lanes, bars = CDTL3.lanes, CDTL3.barFrames
	CDTL3.lanes, CDTL3.barFrames = { { number = 2 } }, { { number = 3 } }
	REFRESH_ARGS = {}
	CDTL3:ApplyCombatVisibility()
	CDTL3.lanes, CDTL3.barFrames = lanes, bars
	check(REFRESH_ARGS.lane == 2 and REFRESH_ARGS.bar == 3, c.tag .. " apply refreshes lane 2 / bar frame 3 by number ("
		.. tostring(REFRESH_ARGS.lane) .. "/" .. tostring(REFRESH_ARGS.bar) .. ")")
end

for _, c in ipairs(CONFIGS) do
	for _, s in ipairs(SCEN) do
		local ok, err = pcall(s, c)
		if not ok then check(false, c.tag .. " ERROR " .. tostring(err)) end
	end
end

-- Auto-hide Frames' own fade-out (empty frame) is never stopped by the hide rule's bookkeeping
for _, c in ipairs(CONFIGS) do
	local ok, err = pcall(function()
		local o = {}; for k, v in pairs(c) do o[k] = v end; o.autohide = true
		reset(o)
		local f = FRAMES[1]
		f.childCount = 0; f.triggerUpdate = true; step()
		check(f.animateOut.playing, c.tag .. " empty frame: autohide fade-out started")
		f.triggerUpdate = true; step(); run(0.5)
		check(f:Rendered() == 0, c.tag .. " empty frame: autohide fade-out completes " .. f:Rendered())
		-- hide rule fades a full frame, cast ends early, frame becomes empty meanwhile
		reset(o)
		CAST = "x"; fire("UNIT_SPELLCAST_START", "player"); run(0.1)
		f.childCount = 0
		CAST = nil; fire("UNIT_SPELLCAST_INTERRUPTED", "player"); run(1.0)
		check(f:Rendered() == 0, c.tag .. " empty frame after early interrupt stays hidden " .. f:Rendered())
		f.childCount = 1
	end)
	FRAMES[1].childCount = 1
	if not ok then check(false, c.tag .. " ERROR " .. tostring(err)) end
end
