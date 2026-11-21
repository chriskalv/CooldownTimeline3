-- CDTL3 public messages and read-only API, for other addons and WeakAuras. See docs/EXTENDING.md.
--
-- Messages (AceEvent / CallbackHandler, sent by CDTL3:SendMessage; listen with RegisterMessage):
--   CDTL3_TimerStarted, CDTL3_TimerReady, CDTL3_TimerEnded, each with one table of plain data:
--   { type, id, name, icon, duration, expires, estimated }
-- API: CDTL3.API.GetTimers / GetTimer / IsReady / GetLane, each returning fresh copies.
--
-- Where the game hides a value (Retail and Forever in combat) duration and expires are nil. Nothing
-- here ever hands out, compares or does maths on a hidden value: the numbers come from CDTL3's own
-- timer, which a riding timer (CombatTimers.lua) does not keep, so those are left out.
local CDTL3 = CDTL3
local private = {}

local API = { version = 1 }
CDTL3.API = API

-- timers that are only scaffolding
local SKIP = { testing = true, test = true, spacer = true }

local function IsSecret(v)
	if not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, v)
	return ok and secret == true
end

-- are this timer's times hidden from us right now
private.Hidden = function(f)
	local d = f.data
	if f.ct and f.ct.riding then
		return true
	end
	if d["itemUnread"] then
		return true
	end
	-- a spell cast in combat where combat timers run is about to ride: its times are hidden too
	local CT = CDTL3.CombatTimers
	if CT and (d["type"] == "spells" or d["type"] == "petspells") and InCombatLockdown and InCombatLockdown() then
		local ok, on = pcall(CT.Enabled, CT)
		if ok and on then
			return true
		end
	end
	return false
end

private.Estimated = function(f)
	local d = f.data
	if d["estimated"] then
		return true
	end
	local CT = CDTL3.CombatTimers
	if CT then
		local ok, est = pcall(CT.Estimated, CT, f)
		if ok and est then
			return true
		end
	end
	return false
end

-- seconds left (a number or nil), inside a pcall like every other read of a timer value
private.Remaining = function(f)
	local ok, left = pcall(function()
		local cd = f.data["currentCD"]
		if type(cd) ~= "number" or IsSecret(cd) or cd ~= cd then
			return nil
		end
		return cd
	end)
	return ok and left or nil
end

private.Counting = function(f)
	local left = private.Remaining(f)
	if not left then
		return false
	end
	local ok, counting = pcall(function() return left > 0 end)
	return ok and counting or false
end

-- a fresh table of plain data for one timer; withState adds lane and ready (API only)
private.Snapshot = function(f, withState)
	local d = f.data
	local t = {
		type = d["type"],
		id = d["id"],
		name = d["name"],
		icon = (d["type"] == "items" and d["itemIcon"]) or d["icon"],
		estimated = private.Estimated(f),
	}
	if not private.Hidden(f) then
		local left = private.Remaining(f)
		if left then
			local ok, expires, duration = pcall(function()
				local base = d["baseCD"]
				if type(base) ~= "number" or IsSecret(base) or base ~= base or base <= 0 then
					base = nil
				end
				return GetTime() + math.max(left, 0), base
			end)
			if ok then
				t.expires = expires
				t.duration = duration
			end
		end
	end
	if withState then
		t.lane = d["lane"]
		t.ready = not private.Counting(f)
	end
	return t
end

-- a spell a Filters rule hides (Show only the ticked spells, Only for this spec, Hide spells I don't know)
private.RuleHidden = function(d)
	if d["type"] ~= "spells" then
		return false
	end
	local ok, hidden = pcall(function()
		local s = CDTL3:GetSpellSettings(d["name"], "spells")
		return s and CDTL3:RuleHides(s, "spells") ~= nil
	end)
	return ok and hidden or false
end

-- a timer the player sees: not ignored, not switched off, not hidden by a rule, not scaffolding
private.Tracked = function(f)
	local d = f and f.data
	return d and not SKIP[d["type"] or ""] and d["enabled"] and not d["ignored"] and not private.RuleHidden(d) and true or false
end

-- Sent from Cooldown.lua. A broken listener must never reach the update loop.
function CDTL3:FireTimer(message, f)
	if not private.Tracked(f) then
		return
	end
	if message == "CDTL3_TimerStarted" and CDTL3.movingLane then
		return	-- MoveToLane keeps the countdown: a move is not a start
	end
	if message == "CDTL3_TimerStarted" then
		f.pubLive = true
	elseif message == "CDTL3_TimerEnded" then
		f.pubLive = nil
	end
	pcall(function()
		CDTL3:SendMessage(message, private.Snapshot(f, false))
	end)
end

-- A started timer whose icon sits in holding (lane set to Hide, bar only) never reaches a Ready
-- frame: when its countdown is over it is ready and over at once.
local HOLDING = { CDTL3_Active_Icon_Holding = true, CDTL3_Offensive_Icon_Holding = true }
function CDTL3:FireTimerIfHeldOver(f)
	if not f.pubLive then
		return
	end
	local ok, held = pcall(function()
		return HOLDING[f.icon:GetParent():GetName() or ""] and f.data["currentCD"] <= 0
	end)
	if ok and held then
		CDTL3:FireTimer("CDTL3_TimerReady", f)
		CDTL3:FireTimer("CDTL3_TimerEnded", f)
		f.pubLive = nil
	end
end

-- After SendToReady: a timer that found no Ready frame to wait in is over at once
function CDTL3:FireTimerIfHeld(f)
	local ok, parent = pcall(function() return f.icon:GetParent():GetName() end)
	if ok and CDTL3:SlotOfParent(parent) ~= "ready" then
		CDTL3:FireTimer("CDTL3_TimerEnded", f)
	end
end

---------------------------------------------------------------- timer types from other addons
-- CDTL3:RegisterTimerType(key, { name, icon }), CDTL3:StartTimer(key, id, { name, icon, duration, startedAt,
-- owner, class }), CDTL3:StopTimer(key, id). A timer shows like a custom timer on the lane, bar frame and
-- Ready frame its type's Filters > Defaults name, counting down to startedAt + duration (plain numbers from
-- GetTime(), never hidden values). One cooldown frame per (type, id), reused on a restart. Keys are
-- case-insensitive (kept lower case). See docs/EXTENDING.md.
CDTL3.timerTypes = {}
private.timerFrames = {}

-- keys the addon itself uses
private.BUILTIN = { spells = true, petspells = true, items = true, buffs = true, debuffs = true, offensives = true,
	runes = true, customs = true, detected = true, flights = true, testing = true, test = true, spacer = true, icds = true }

private.TypeKey = function(key)
	if type(key) ~= "string" or key == "" then
		return nil
	end
	return key:lower()
end

-- a plain number: not hidden, not NaN
private.Plain = function(v)
	return type(v) == "number" and not IsSecret(v) and v == v and v ~= math.huge and v ~= -math.huge
end

-- this type's Filters > Defaults values in the current profile, made when missing (also after a profile switch)
function CDTL3:TimerTypeSettings(key)
	local g = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.global
	if not g or not CDTL3.timerTypes[key] then
		return nil
	end
	local s = g[key]
	if type(s) ~= "table" then
		s = {}
		g[key] = s
	end
	for k, v in pairs({ enabled = true, defaultLane = 1, defaultBar = 1, defaultReady = 1 }) do
		if s[k] == nil then
			s[k] = v
		end
	end
	return s
end

function CDTL3:RegisterTimerType(key, info)
	local k = private.TypeKey(key)
	if not k or private.BUILTIN[k] or type(info) ~= "table" then
		return false
	end
	local t = CDTL3.timerTypes[k]
	if not t then
		t = { key = k }
		CDTL3.timerTypes[k] = t
		private.timerFrames[k] = {}
	end
	if type(info["name"]) == "string" and info["name"] ~= "" then
		t.name = info["name"]
	end
	t.name = t.name or key
	if info["icon"] ~= nil then
		t.icon = info["icon"]
	end
	CDTL3:TimerTypeSettings(k)
	return true
end

function CDTL3:StartTimer(key, id, info)
	local k = private.TypeKey(key)
	local t = k and CDTL3.timerTypes[k]
	if not t or (type(id) ~= "string" and type(id) ~= "number") or type(info) ~= "table" then
		return false
	end
	local s = CDTL3:TimerTypeSettings(k)
	if not s or s["enabled"] == false then
		return false
	end

	local duration, startedAt = info["duration"], info["startedAt"]
	if startedAt == nil then
		startedAt = GetTime()
	end
	if not (private.Plain(duration) and private.Plain(startedAt) and duration > 0) then
		return false
	end
	local remaining = startedAt + duration - GetTime()
	if remaining <= 0 then
		return false	-- already over
	end

	local name = type(info["name"]) == "string" and info["name"] ~= "" and info["name"] or tostring(id)
	local icon = info["icon"] ~= nil and info["icon"] or t.icon or 134400
	local owner = type(info["owner"]) == "string" and info["owner"] or nil
	local class = type(info["class"]) == "string" and info["class"] or nil

	local f = private.timerFrames[k][id]
	if f then
		local d = f.data
		d["name"], d["icon"], d["owner"], d["class"] = name, icon, owner, class
		d["baseCD"], d["pendingCD"], d["timerEnd"] = duration, remaining, startedAt + duration
		d["lane"], d["barFrame"], d["readyFrame"] = s["defaultLane"], s["defaultBar"], s["defaultReady"]
		d["enabled"], d["ignored"] = true, false
		CDTL3:SendToLane(f)
		CDTL3:SendToBarFrame(f)
	else
		f = CDTL3:CreateCooldown(CDTL3:GetUID(), k, {
			id = id,
			name = name,
			icon = icon,
			bCD = duration * 1000,
			enabled = true,
			ignored = false,
			highlight = false,
			pinned = false,
			lane = s["defaultLane"],
			barFrame = s["defaultBar"],
			readyFrame = s["defaultReady"],
			owner = owner,
			class = class,
			timerEnd = startedAt + duration,
			pendingCD = remaining,
		})
		private.timerFrames[k][id] = f
	end
	f.data["currentCD"] = remaining
	CDTL3:ApplyCombatVisibility()
	return true
end

-- gone at once: off its lane, bar frame and Ready frame, no Ready
function CDTL3:StopTimer(key, id)
	local k = private.TypeKey(key)
	local f = k and private.timerFrames[k] and private.timerFrames[k][id]
	if not f then
		return false
	end
	f.data["timerEnd"] = nil
	f.data["currentCD"] = 0
	CDTL3:SendToHolding(f)
	CDTL3:SendToBarHolding(f)
	if f.pubLive then
		CDTL3:FireTimer("CDTL3_TimerEnded", f)
		f.pubLive = nil
	end
	return true
end

-- GetTimers(): every running timer
function API.GetTimers()
	local out = {}
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		if private.Tracked(f) and private.Counting(f) then
			out[#out + 1] = private.Snapshot(f, true)
		end
	end
	return out
end

-- the cooldown frame for an entry: a running one first, else any
private.Find = function(cdType, id)
	local found
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		local d = f.data
		if d and d["type"] == cdType and d["id"] == id and private.Tracked(f) then
			if private.Counting(f) then
				return f
			end
			found = found or f
		end
	end
	return found
end

-- GetTimer(type, id): one timer (running or ready), or nil when CDTL3 does not track it
function API.GetTimer(cdType, id)
	local f = private.Find(cdType, id)
	return f and private.Snapshot(f, true) or nil
end

-- IsReady(type, id): true or false, or nil when CDTL3 does not track it
function API.IsReady(cdType, id)
	local f = private.Find(cdType, id)
	if not f then
		return nil
	end
	return not private.Counting(f)
end

-- GetLane(name or number): { number, name, enabled, timers = { running timers on it } }, or nil
function API.GetLane(which)
	local lanes = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.lanes
	if not lanes then
		return nil
	end
	local n
	if type(which) == "number" then
		n = which
	elseif type(which) == "string" then
		n = tonumber(which)
		if not n then
			local want = which:lower()
			for i = 1, 3 do
				local s = lanes["lane" .. i]
				if s and type(s["name"]) == "string" and s["name"]:lower() == want then
					n = i
					break
				end
			end
		end
	end
	local s = n and lanes["lane" .. n]
	if not s then
		return nil
	end
	local out = { number = n, name = s["name"], enabled = s["enabled"] and true or false, timers = {} }
	for _, f in ipairs(CDTL3.cooldowns or {}) do
		if f.data and f.data["lane"] == n and private.Tracked(f) and private.Counting(f) then
			out.timers[#out.timers + 1] = private.Snapshot(f, true)
		end
	end
	return out
end
