-- Seal scenarios on the real addon code (after seal_flow_env.lua and the extracted code).
-- COOLDOWN_UPDATE is Cooldown.lua's private.CooldownUpdate, CT the combat timers module.
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. m end
local CT = CDTL3.CombatTimers
local SOC, SOR, PROC, JUDGE = 20375, 20154, 20424, 20271

local function frame(name, kind) return CDTL3:GetExistingCooldown(name, kind) end
local function onLane(f) return f ~= nil and f.icon:GetParent() == CDTL3_Lane_1 and f.bar:GetParent() == CDTL3_BarFrame_1_MF end
local function held(f)
	return f ~= nil and f.icon:GetParent() == CDTL3_Active_Icon_Holding and f.bar:GetParent() == CDTL3_Bar_Holding
		and f.data["currentCD"] < 0
end
local function left(f) return f and f.data["currentCD"] or -99 end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 0.6) end
local function count(list, entry) local n = 0; for _, e in ipairs(list) do if e == entry then n = n + 1 end end return n end
local function riding(f) return f ~= nil and f.ct ~= nil and f.ct.riding == true end

local DT = 1 / 30
-- every frame: each cooldown's OnUpdate (the poll re-reads the game every 50 frames) and the
-- combat timers' own OnUpdate; watch(f) runs after each frame
local function run(sec, watch)
	for _ = 1, math.floor(sec / DT + 0.5) do
		NOW = NOW + DT
		for _, f in ipairs(CDTL3.cooldowns) do COOLDOWN_UPDATE(f, DT) end
		if CT.internal.eventFrame then CT.internal.OnUpdate(DT) end
		if watch then watch() end
	end
end

local function fireCast(id)
	CDTL3:UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id .. "-" .. NOW, id)
end

-- a cast from the spellbook: GCD, the game swaps the seal aura, then (or first) the events
local function cast(id, auraFirst)
	GCD_START, GCD_END = NOW, NOW + 1.5
	local name = SPELLS[id]
	local added, removed = {}, {}
	if name:find("^Seal of ") then
		for i = #AURAS, 1, -1 do
			if AURAS[i].name ~= name then
				removed[#removed + 1] = AURAS[i].auraInstanceID
				table.remove(AURAS, i)
			end
		end
		local a = nil
		for _, x in ipairs(AURAS) do if x.name == name then a = x end end
		if a then
			removed[#removed + 1] = a.auraInstanceID
			for i, x in ipairs(AURAS) do if x == a then table.remove(AURAS, i) end end
		end
		a = { auraInstanceID = NEXT_AURA, name = name, spellId = id, duration = 30, expirationTime = NOW + 30,
			sourceUnit = "player", isHarmful = false, applications = 0, icon = 1 }
		NEXT_AURA = NEXT_AURA + 1
		AURAS[#AURAS + 1] = a
		added[1] = HandOut(a)
	elseif id == JUDGE then
		COOLDOWNS[id] = { start = NOW, dur = 10 }
	end
	local info = { addedAuras = added, removedAuraInstanceIDs = removed, updatedAuraInstanceIDs = {} }
	if auraFirst then CDTL3:UNIT_AURA("UNIT_AURA", "player", info) end
	fireCast(id)
	if not auraFirst then CDTL3:UNIT_AURA("UNIT_AURA", "player", info) end
end

local function enterCombat()
	IN_COMBAT, SECRET_CD, SECRET_AURAS = true, true, true
	CDTL3:PLAYER_REGEN_DISABLED()
	CT.internal.OnEvent("PLAYER_REGEN_DISABLED")
end
local function leaveCombat()
	IN_COMBAT, SECRET_CD, SECRET_AURAS = false, false, false
	CDTL3:PLAYER_REGEN_ENABLED()	-- rescans the auras (UNIT_AURA full update)
	CT.internal.OnEvent("PLAYER_REGEN_ENABLED")
end

-- (1) Custom CD 30 on a spell without a cooldown (the dropped patch Seal as custom cooldown, now
-- the release's private.CustomCDStart): 30 s from the player's own cast, past the GCD and in
-- combat; a recast restarts it. A fallback test against the release's code.
for _, combat in ipairs({ false, true }) do
for _, ct in ipairs({ false, true }) do
	local tag = string.format("custom CD combat=%s ct=%s:", tostring(combat), tostring(ct))
	Setup({ ct = ct, buffs = false })
	if combat then enterCombat() end
	local t0 = NOW
	cast(SOC)
	local soc = frame("Seal of Command", "spells")
	check(onLane(soc) and near(left(soc), 30, 0.05), tag .. " cast puts the seal on its lane at 30 s (" .. left(soc) .. ")")
	check(CDTL3.spellCastTimes[SOC] == t0, tag .. " the cast time is recorded")
	run(0.5)
	check(onLane(soc) and near(left(soc), 29.5), tag .. " during the GCD: 29.5 s left (" .. left(soc) .. ")")
	run(2.5)
	check(onLane(soc) and near(left(soc), 27), tag .. " after the GCD the seal keeps counting (" .. left(soc) .. ")")
	run(26)
	check(onLane(soc) and near(left(soc), 1), tag .. " at 29 s still on the lane (" .. left(soc) .. ")")
	check(not riding(soc), tag .. " a Custom CD Time never rides the game's timer")
	run(1.6)
	check(count(READY, "spells:Seal of Command") == 1, tag .. " at 30 s the seal goes to Ready once")
	-- recast: restarts from the new cast
	cast(SOC); run(10); cast(SOC)
	local t1 = NOW
	run(25)
	check(onLane(soc) and near(left(soc), 5), tag .. " a recast restarts the 30 s (" .. left(soc) .. ")")
	check(CDTL3.spellCastTimes[SOC] == t1, tag .. " the recast's time counts")
	check(count(READY, "spells:Seal of Command") == 1, tag .. " no Ready before the recast's 30 s are up")
	run(5.6)
	check(count(READY, "spells:Seal of Command") == 2, tag .. " Ready 30 s after the last recast")
	check(#ERRORS == 0, tag .. " no failures logged (" .. tostring(ERRORS[1]) .. ")")
end end

-- private.CustomCDStart on its own: a missing or 0 start counts from the cast, a real start wins
Setup({})
CDTL3.spellCastTimes = { [SOC] = 42 }
check(CUSTOM_CD_START({ id = SOC }, 0) == 42 and CUSTOM_CD_START({ id = SOC }, nil) == 42,
	"CustomCDStart: start 0 or nil counts from the last cast")
check(CUSTOM_CD_START({ id = SOC }, 77) == 77, "CustomCDStart: a real start from the game wins")
check(CUSTOM_CD_START({ id = SOR }, 0) == 0, "CustomCDStart: without a cast time the start stays 0")

-- (2) seal switch: in and out of combat, combat timers on and off, the seals' buffs tracked or
-- ignored, the aura event before or after the cast event
for _, combat in ipairs({ false, true }) do
for _, ct in ipairs({ false, true }) do
for _, buffs in ipairs({ false, true }) do
for _, auraFirst in ipairs({ false, true }) do
	local tag = string.format("switch combat=%s ct=%s buffs=%s auraFirst=%s:", tostring(combat), tostring(ct), tostring(buffs), tostring(auraFirst))
	Setup({ ct = ct, buffs = buffs })
	if combat then enterCombat() end
	cast(JUDGE, auraFirst)
	cast(SOC, auraFirst)
	local soc, judge = frame("Seal of Command", "spells"), frame("Judgement", "spells")
	local socBuff = frame("Seal of Command", "buffs")
	check(onLane(soc) and onLane(judge), tag .. " Seal of Command and Judgement run")
	check(buffs == (socBuff ~= nil and onLane(socBuff)), tag .. " the seal's buff shows when tracked")
	run(3)
	-- the combat timers really run here: in combat Judgement rides the game's own timer
	check(riding(judge) == (combat and ct), tag .. " Judgement rides the game's timer only in combat with combat timers on")

	-- a proc of the active seal (its own spell ID) restarts nothing and ends nothing
	local before, beforeBuff = left(soc), left(socBuff)
	fireCast(PROC)
	run(DT)
	check(onLane(soc) and left(soc) < before, tag .. " a proc of the active seal doesn't restart its timer")
	if buffs then check(onLane(socBuff) and left(socBuff) < beforeBuff, tag .. " a proc doesn't restart the seal's buff") end

	-- the switch
	local endedBefore = count(EVENTS, "CDTL3_TimerEnded:spells:Seal of Command")
	cast(SOR, auraFirst)
	local sor, sorBuff = frame("Seal of Righteousness", "spells"), frame("Seal of Righteousness", "buffs")
	check(held(soc), tag .. " casting another seal sends the old seal's timer to holding")
	check(onLane(sor) and near(left(sor), 30, 0.05), tag .. " the new seal runs 30 s")
	check(count(READY, "spells:Seal of Command") == 0, tag .. " the old seal goes to no Ready frame (no ready sound)")
	check(count(EVENTS, "CDTL3_TimerEnded:spells:Seal of Command") == endedBefore + 1, tag .. " other addons hear the old timer end")
	check(onLane(judge), tag .. " Judgement is untouched")
	if buffs then
		check(held(socBuff), tag .. " the old seal's buff timer ends too")
		check(onLane(sorBuff), tag .. " the new seal's buff shows")
		check(count(READY, "buffs:Seal of Command") == 0, tag .. " the old seal's buff goes to no Ready frame")
	end

	-- nothing brings the old seal back: a late proc (seal twisting), the cooldown poll (its last
	-- cast is less than 30 s ago, so private.CustomCDStart would give it time left), the combat
	-- timers, the aura events, the end of combat
	local back = false
	local function watch()
		if not held(soc) or (socBuff and buffs and not held(socBuff)) or riding(soc) then back = true end
	end
	fireCast(PROC)
	watch()
	check(not back, tag .. " a late proc of the old seal doesn't bring it back")
	check(onLane(sor) and near(left(sor), 30, 0.05), tag .. " a late proc of the old seal doesn't end the new one")
	run(5, watch)
	CDTL3:UNIT_AURA("UNIT_AURA", "player", nil)	-- full update (zoning, /reload)
	watch()
	if combat then leaveCombat(); watch() end
	run(23, watch)	-- past the old seal's 30 s, short of the new seal's
	check(not back, tag .. " the old seal stays gone until its 30 s would have run out")
	check(count(READY, "spells:Seal of Command") == 0 and count(READY, "buffs:Seal of Command") == 0,
		tag .. " the old seal never reaches Ready")
	check(onLane(judge) or count(READY, "spells:Judgement") == 1, tag .. " Judgement ran its own course")

	-- the old seal cast again restarts its timer and ends the other one
	if combat then enterCombat() end
	cast(SOC, auraFirst)
	check(onLane(soc) and near(left(soc), 30, 0.05), tag .. " the old seal cast again restarts at 30 s (" .. left(soc) .. ")")
	check(held(sor), tag .. " and ends the other seal")
	if buffs then
		check(onLane(socBuff) and held(sorBuff), tag .. " the buffs follow")
	end
	run(3)
	check(onLane(soc) and near(left(soc), 27), tag .. " the restarted seal counts down (" .. left(soc) .. ")")
	check(count(READY, "spells:Seal of Righteousness") == 0, tag .. " the ended seal goes to no Ready frame")
	check(#ERRORS == 0, tag .. " no failures logged (" .. tostring(ERRORS[1]) .. ")")
end end end end

-- (3) the cast handler only ends seal timers for a seal from the spellbook
Setup({ buffs = true })
cast(SOC); run(1)
local soc = frame("Seal of Command", "spells")
KNOWN[SOR] = nil	-- Seal of Righteousness reported as not known (a proc of its own)
fireCast(SOR)
KNOWN[SOR] = true
check(onLane(soc), "a seal that is not in the spellbook ends no other seal")
check(frame("Seal of Righteousness", "spells") == nil, "and starts no spell timer")
