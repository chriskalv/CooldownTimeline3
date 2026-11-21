--[[
	Cooldown Timeline 3 - flight timers

	Taking a flight path shows a countdown to landing, named for the destination. A route any
	character on the account has flown counts down from its last real time. A route nobody has
	flown counts down from an estimate (the route's length from FlightData/<client>.lua, built by
	tools/flight-data, divided by the taxi speed), in dimmed text. Landing saves the real time and
	refits the speed used for estimates.

	A flight that doesn't start from the taxi map (a flight master's chat option such as the
	druids' Moonglade flight, or a quest) is found by its takeoff: the flight point it took off at
	gives its route when only one route leaves there, and the one it lands at fixes the route for
	next time.

	Only post-hooks (TakeTaxiNode, TaxiRequestEarlyLanding, C_GossipInfo.SelectOptionByIndex and
	SelectOption) and reads:
	nothing of Blizzard's is replaced. None of the taxi calls or events are on Midnight's secret list.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
local FL = {}
CDTL3.Flights = FL

local private = {}

private.SPEED = 30.3		-- yards per second: taxis fly at about 433% of the 7 yd/s run speed
private.MIN_SPEED = 10		-- a fitted speed outside these is ignored
private.MAX_SPEED = 120
private.HOLD = 0.1			-- a countdown that runs out before landing waits here
private.TICK = 0.2			-- seconds between UnitOnTaxi reads while a flight is picked or flying
private.TAKEOFF_WAIT = 10	-- a picked route that never takes off is dropped after this
private.MIN_LEARN = 5		-- flights shorter than this aren't saved
private.SHORT = 0.6			-- a flight under this share of its saved time was cut short: not saved
private.STRAIGHT = 1.2		-- straight-line yards x this, for a route the data doesn't have
private.RESUME_DELAY = 2	-- seconds after login before a flight in progress is shown again
private.NODE_RANGE = 150	-- yards from a flight point's spot that count as taking off or landing there
private.DIM = 0.55
private.ICONS = {
	Horde = "Interface\\Icons\\Ability_Mount_Wyvern_01",
	Alliance = "Interface\\Icons\\Ability_Mount_Gryphon_01",
}
private.EVENTS = { "TAXIMAP_OPENED", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
	"PLAYER_ENTERING_WORLD", "PLAYER_LOGOUT", "GOSSIP_SHOW" }
-- saved times' format: 2 keys a route through stops by all its points (3.1.1); times saved by
-- the test builds keyed it by its ends only, so they're dropped once
private.FORMAT = 2

private.slots = nil		-- the open taxi map: [slot] = { name, type, nodeID, x, y, hops }
private.mapID = nil
private.pending = nil	-- a picked route waiting for takeoff, or (unpicked) a takeoff watched for
private.gossip = nil	-- the open chat window's options: [orderIndex] = gossipOptionID
private.flight = nil	-- the flight in the air
private.frame = nil		-- the flights cooldown frame (one, reused for every flight)
private.elapsed = 0

---------------------------------------------------------------- settings and saved data

private.Settings = function()
	return CDTL3.db and CDTL3.db.profile.global["flights"]
end

function FL:Enabled()
	local s = private.Settings()
	return s and s["enabled"] and true or false
end

function FL:SetEnabled(val)
	local s = private.Settings()
	if not s then
		return
	end
	s["enabled"] = val and true or false
	if not s["enabled"] then
		private.pending = nil
		if private.flight then
			private.EndCountdown()
			private.flight = nil
			CDTL3.db.char.flight = nil
		end
		private.StopTicker()
	elseif UnitOnTaxi and UnitOnTaxi("player") then
		private.StartTicker()
	end
end

-- flight point IDs differ between clients, so each keeps its own times
private.ClientKey = function()
	if CDTL3.isForever then
		return "forever"
	end
	return "project" .. tostring(WOW_PROJECT_ID or 0)
end

-- account-wide: routes["from-...-to"] = seconds, plus the yards and seconds behind the speed fit;
-- starts[how a flight off the taxi map started] = its route; names[flight point] = its name as
-- the game showed it (localized)
private.Store = function()
	local g = CDTL3.db.global
	g.flightTimes = g.flightTimes or {}
	local key = private.ClientKey()
	local t = g.flightTimes[key]
	if not t then
		t = { routes = {}, len = 0, time = 0, format = private.FORMAT }
		g.flightTimes[key] = t
	end
	if t.format ~= private.FORMAT then
		t.routes, t.starts, t.len, t.time = {}, {}, 0, 0
		t.format = private.FORMAT
	end
	t.routes = t.routes or {}
	t.starts = t.starts or {}
	t.names = t.names or {}
	t.len = t.len or 0
	t.time = t.time or 0
	return t
end

function FL:Speed()
	local t = private.Store()
	if t.time > 0 and t.len > 0 then
		local v = t.len / t.time
		if v >= private.MIN_SPEED and v <= private.MAX_SPEED then
			return v
		end
	end
	return private.SPEED
end

function FL:Forget()
	local g = CDTL3.db.global
	if g.flightTimes then
		g.flightTimes[private.ClientKey()] = nil
	end
end

function FL:LearnedCount()
	local n = 0
	for _ in pairs(private.Store().routes) do
		n = n + 1
	end
	return n
end

---------------------------------------------------------------- the taxi map

private.TaxiMapID = function()
	if GetTaxiMapID then
		local ok, id = pcall(GetTaxiMapID)
		if ok and type(id) == "number" and id > 0 then
			return id
		end
	end
	-- no GetTaxiMapID: the continent the player is on
	if C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo then
		local id = C_Map.GetBestMapForUnit("player")
		for _ = 1, 10 do
			if not id then
				break
			end
			local info = C_Map.GetMapInfo(id)
			if not info then
				break
			end
			if info.mapType == 2 then
				return id
			end
			id = info.parentMapID
		end
	end
	return nil
end

private.XY = function(pos)
	if type(pos) ~= "table" then
		return nil
	end
	if type(pos.x) == "number" and type(pos.y) == "number" then
		return pos.x, pos.y
	end
	if pos.GetXY then
		local ok, x, y = pcall(pos.GetXY, pos)
		if ok and type(x) == "number" and type(y) == "number" then
			return x, y
		end
	end
	return nil
end

-- read while the map is open: TakeTaxiNode closes it
private.ReadMap = function()
	local slots = {}
	local n = (NumTaxiNodes and NumTaxiNodes()) or 0
	for i = 1, n do
		slots[i] = { name = TaxiNodeName(i), type = TaxiNodeGetType(i) }
	end

	-- node IDs (not localized) and map positions, matched to slots
	local mapID = private.TaxiMapID()
	if mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes then
		local ok, nodes = pcall(C_TaxiMap.GetAllTaxiNodes, mapID)
		if ok and type(nodes) == "table" then
			local names = private.Store().names
			for _, node in ipairs(nodes) do
				local s = node.slotIndex and slots[node.slotIndex]
				if s then
					s.nodeID = node.nodeID
					s.x, s.y = private.XY(node.position)
					if s.nodeID and type(s.name) == "string" then
						names[s.nodeID] = private.ShortName(s.name)
					end
				end
			end
		end
	end

	-- the hops the game will fly to each reachable slot
	if GetNumRoutes and TaxiGetNodeSlot then
		for i, s in pairs(slots) do
			if s.type == "REACHABLE" then
				local hops = {}
				local count = GetNumRoutes(i) or 0
				for r = 1, count do
					-- the game's TaxiGetNodeSlot takes (slot, route, isStart); the definitions list no parameters
					---@diagnostic disable-next-line: redundant-parameter
					local a = TaxiGetNodeSlot(i, r, true)
					---@diagnostic disable-next-line: redundant-parameter
					local b = TaxiGetNodeSlot(i, r, false)
					if a and b then
						hops[#hops + 1] = { a, b }
					end
				end
				s.hops = hops
			end
		end
	end

	private.slots = slots
	private.mapID = mapID
end

private.Current = function(slots)
	for _, s in pairs(slots) do
		if s.type == "CURRENT" then
			return s
		end
	end
	return nil
end

-- a route's flight points in order: "from-to" for one hop, "from-stop-...-to" through stops. The
-- game routes each character through the points it knows, so the same ends can be different flights
private.RouteKey = function(src, dst, slots)
	if src.nodeID and dst.nodeID then
		local hops = dst.hops
		if slots and hops and #hops > 1 then
			local ids = {}
			for i, h in ipairs(hops) do
				local a, b = slots[h[1]], slots[h[2]]
				if not (a and b and a.nodeID and b.nodeID) then
					ids = nil
					break
				end
				if i == 1 then
					ids[1] = a.nodeID
				end
				ids[#ids + 1] = b.nodeID
			end
			if ids then
				return table.concat(ids, "-")
			end
		end
		return src.nodeID .. "-" .. dst.nodeID
	end
	return "n:" .. tostring(src.name) .. ">" .. tostring(dst.name)
end

-- the destination's name without its zone ("Thunder Bluff, Mulgore" -> "Thunder Bluff")
private.ShortName = function(name)
	if type(name) ~= "string" then
		return "Flight"
	end
	return name:match("^([^,]+),") or name
end

---------------------------------------------------------------- estimates

-- one route's yards and stop seconds from the data, or nil
private.PathLength = function(key)
	local p = key and CDTL3.flightData and CDTL3.flightData.paths and CDTL3.flightData.paths[key]
	if p and p[1] and p[1] > 0 then
		return p[1], p[2] or 0
	end
	return nil
end

-- from the route data: yards and stop seconds summed over the hops, or nil
private.DataLength = function(slots, hops)
	if not (CDTL3.flightData and CDTL3.flightData.paths) or not hops or #hops == 0 then
		return nil
	end
	local len, delay = 0, 0
	for _, h in ipairs(hops) do
		local a, b = slots[h[1]], slots[h[2]]
		local l, d = private.PathLength(a and b and a.nodeID and b.nodeID and (a.nodeID .. "-" .. b.nodeID))
		if not l then
			return nil
		end
		len = len + l
		delay = delay + d
	end
	return len, delay
end

-- straight lines between the hops' map positions, in yards, or nil
private.StraightLength = function(slots, hops, src, dst)
	if not (private.mapID and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then
		return nil
	end
	local points = {}
	if hops and #hops > 0 then
		points[1] = slots[hops[1][1]]
		for _, h in ipairs(hops) do
			points[#points + 1] = slots[h[2]]
		end
	else
		points = { src, dst }
	end
	local total = 0
	local lastX, lastY = nil, nil
	for _, p in ipairs(points) do
		if not (p and p.x and p.y) then
			return nil
		end
		local ok, _, world = pcall(C_Map.GetWorldPosFromMapPos, private.mapID, CreateVector2D(p.x, p.y))
		local wx, wy = nil, nil
		if ok then
			wx, wy = private.XY(world)
		end
		if not wx then
			return nil
		end
		if lastX then
			total = total + math.sqrt((wx - lastX) ^ 2 + (wy - lastY) ^ 2)
		end
		lastX, lastY = wx, wy
	end
	if total <= 0 then
		return nil
	end
	return total * private.STRAIGHT
end

-- seconds and whether that's an estimate: the route's saved time, else its yards / speed + stops
private.Time = function(key, len, delay)
	local saved = key and private.Store().routes[key]
	if saved then
		return saved, false
	end
	if len then
		return len / FL:Speed() + (delay or 0), true
	end
	return nil
end

-- seconds, estimated or not, and the route's data length and delay when known
private.Duration = function(key, slots, src, dst)
	local len, delay = private.DataLength(slots, dst.hops)
	local duration, estimated = private.Time(key, len, delay)
	if duration then
		return duration, estimated, len, delay
	end
	local straight = private.StraightLength(slots, dst.hops, src, dst)
	if straight then
		return straight / FL:Speed(), true, nil, nil
	end
	return nil
end

---------------------------------------------------------------- flights that don't start from the taxi map

-- the player's world position in TaxiNodes coordinates { cont, x, y }, or nil (in an instance)
private.PlayerPos = function()
	local ok, pos = pcall(function()
		-- adding 0 throws here, inside the pcall, if a value is ever secret
		if UnitPosition then
			-- UnitPosition's first value is TaxiNodes' x (north), its second the y (west)
			local x, y, _, cont = UnitPosition("player")
			if type(x) == "number" and type(y) == "number" and type(cont) == "number" then
				return { cont = cont + 0, x = x + 0, y = y + 0 }
			end
		end
		if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition and C_Map.GetWorldPosFromMapPos then
			local mapID = C_Map.GetBestMapForUnit("player")
			local v = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
			if v then
				-- v is only set when mapID is
				---@diagnostic disable-next-line: param-type-mismatch
				local cont, world = C_Map.GetWorldPosFromMapPos(mapID, v)
				local x, y = private.XY(world)
				if type(cont) == "number" and x then
					return { cont = cont + 0, x = x + 0, y = y + 0 }
				end
			end
		end
		return nil
	end)
	return ok and pos or nil
end

-- the flight point nearest pos on its continent and within range, skipping the other side's
private.NearestNode = function(pos)
	local nodes = CDTL3.flightData and CDTL3.flightData.nodes
	if not (pos and nodes) then
		return nil
	end
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	local other = (faction == "Horde" and 1) or (faction == "Alliance" and 2) or nil
	local best, bestD = nil, private.NODE_RANGE
	for id, n in pairs(nodes) do
		if n[1] == pos.cont and n[4] ~= other then
			local d = math.sqrt((n[2] - pos.x) ^ 2 + (n[3] - pos.y) ^ 2)
			if d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best
end

-- the one route the data has from a flight point; nil when it has none or several
private.OnlyRouteFrom = function(from)
	local data = CDTL3.flightData and CDTL3.flightData.paths
	if not (data and from) then
		return nil
	end
	local prefix = from .. "-"
	local found = nil
	for key in pairs(data) do
		if key:sub(1, #prefix) == prefix then
			if found then
				return nil
			end
			found = key
		end
	end
	return found
end

-- a flight point's name as a taxi map (or a landing) showed it, else the data's English one
private.NodeName = function(id)
	local n = CDTL3.flightData and CDTL3.flightData.nodes and CDTL3.flightData.nodes[id]
	return private.Store().names[id] or (n and n[5]) or nil
end

-- the route a takeoff off the taxi map flies: what was learned for how it started (the chat
-- option picked, else the flight point), else the one route the data has from that point
private.Unpicked = function(p)
	local store = private.Store()
	local from = private.NearestNode(p.pos or private.PlayerPos())
	local origin = p.origin or (from and ("n:" .. from)) or nil
	local key = (origin and store.starts[origin]) or private.OnlyRouteFrom(from)
	local flight = { from = from, origin = origin, key = key, delay = 0 }
	if key then
		local to = tonumber(key:match("%-(%d+)$"))
		flight.len, flight.delay = private.PathLength(key)
		flight.delay = flight.delay or 0
		flight.duration, flight.estimated = private.Time(key, flight.len, flight.delay)
		flight.name = (to and private.NodeName(to)) or L["Flight"]
	end
	return flight
end

-- landed after a takeoff off the taxi map: the flight point it landed at fixes its route
private.Arrived = function(flight)
	local head = flight.from or flight.origin
	local to = private.NearestNode(private.PlayerPos())
	if not (head and to) then
		return
	end
	local names = private.Store().names
	if not private.NodeName(to) and GetMinimapZoneText then
		local zone = GetMinimapZoneText()
		if type(zone) == "string" and zone ~= "" then
			names[to] = zone
		end
	end
	local key = head .. "-" .. to
	if key ~= flight.key then
		flight.key = key
		flight.len, flight.delay = private.PathLength(key)
		flight.delay = flight.delay or 0
	end
end

-- a taxi can also start from a chat option, a quest or a spell: watch a few seconds for a takeoff
private.WatchTakeoff = function(origin)
	if not FL:Enabled() or private.flight then
		return
	end
	local p = private.pending
	if p and not p.unpicked then
		return		-- a route picked on the taxi map
	end
	if not p then
		p = { unpicked = true, pos = private.PlayerPos() }
		private.pending = p
	end
	p.at = GetTime()
	p.origin = origin or p.origin
	private.StartTicker()
end

---------------------------------------------------------------- the countdown

private.Icon = function()
	local faction = UnitFactionGroup and UnitFactionGroup("player")
	return private.ICONS[faction] or private.ICONS.Alliance
end

private.ShowCountdown = function(flight, remaining)
	local s = private.Settings()
	local f = private.frame
	if f then
		local d = f.data
		d["name"] = flight.name
		d["icon"] = private.Icon()
		d["baseCD"] = flight.duration
		d["lane"] = s["defaultLane"]
		d["barFrame"] = s["defaultBar"]
		d["readyFrame"] = s["defaultReady"]
		d["enabled"] = true
		d["ignored"] = false
		d["estimated"] = flight.estimated or nil
		CDTL3:SendToLane(f)
		CDTL3:SendToBarFrame(f)
	else
		f = CDTL3:CreateCooldown(CDTL3:GetUID(), "flights", {
			id = 0,
			name = flight.name,
			icon = private.Icon(),
			bCD = flight.duration * 1000,
			enabled = true,
			ignored = false,
			highlight = false,
			pinned = false,
			lane = s["defaultLane"],
			barFrame = s["defaultBar"],
			readyFrame = s["defaultReady"],
		})
		f.data["estimated"] = flight.estimated or nil
		private.frame = f
	end
	if remaining then
		f.data["currentCD"] = math.max(remaining, private.HOLD)
	end
	CDTL3:ApplyCombatVisibility()
end

-- landed: the icon goes to its ready frame on its next update
private.EndCountdown = function()
	local f = private.frame
	if not f then
		return
	end
	if f.data["currentCD"] > 0 then
		f.data["currentCD"] = 0
	end
	f.data["estimated"] = nil
	if f.flDim then
		for tf in pairs(f.flDim) do
			tf:SetAlpha(1)
			tf.flDimmed = nil
		end
		f.flDim = nil
	end
end

-- from CooldownUpdate: the countdown is counted from takeoff (so time with the UI hidden isn't
-- lost: the frame doesn't update then) and waits at the end if it runs out before landing. A
-- flight with no countdown leaves the last one in its ready frame.
function FL:Hold(f)
	local flight = private.flight
	if flight and flight.duration and f == private.frame then
		local left = flight.duration - (GetTime() - flight.start)
		f.data["currentCD"] = math.max(left, private.HOLD)
	end
end

-- from UpdateText: an estimate's text is dimmed (only the flights frame is ever touched)
function FL:DimText(f, tf)
	if not tf or f.data["type"] ~= "flights" then
		return
	end
	local dim = f.data["estimated"] and true or false
	if dim ~= (tf.flDimmed and true or false) then
		tf:SetAlpha(dim and private.DIM or 1)
		tf.flDimmed = dim or nil
		f.flDim = f.flDim or {}
		f.flDim[tf] = dim or nil
	end
end

function FL:InFlight()
	return private.flight ~= nil
end

-- Hide out of combat: a frame showing the flight (or its landing in a ready frame) stays shown
function FL:Holds(frame)
	local f = private.frame
	if not f or not frame then
		return false
	end
	local ic, ba = f.icon, f.bar
	local inReady = false
	local p = ic and ic:GetParent()
	if p and p.GetName then
		local n = p:GetName()
		inReady = CDTL3:SlotOfParent(n) == "ready"
	end
	local counting = private.flight and private.flight.duration
	if not counting and not (inReady and ic.readyTime and ic.readyTime > 0) then
		return false
	end
	for _, r in ipairs({ ic, ba }) do
		local q = r and r:GetParent()
		for _ = 1, 2 do
			if not q then
				break
			end
			if q == frame then
				return true
			end
			q = q.GetParent and q:GetParent()
		end
	end
	return false
end

---------------------------------------------------------------- flight lifecycle

private.Debug = function(msg)
	if CDTL3.db and CDTL3.db.profile.global["debugMode"] then
		CDTL3:Print("FLIGHT: " .. msg)
	end
end

private.OnTakeTaxiNode = function(slot)
	if not FL:Enabled() then
		return
	end
	local slots = private.slots
	if not slots or not slots[slot] then
		private.ReadMap()
		slots = private.slots
	end
	local dst = slots and slots[slot]
	local src = slots and private.Current(slots)
	if not dst or not src then
		return
	end
	local key = private.RouteKey(src, dst, slots)
	local duration, estimated, len, delay = private.Duration(key, slots, src, dst)
	private.pending = {
		key = key,
		name = private.ShortName(dst.name),
		duration = duration,
		estimated = estimated,
		len = len,
		delay = delay or 0,
		at = GetTime(),
	}
	private.Debug(string.format("%s (%s) %s %s", tostring(dst.name), key,
		duration and string.format("%.0fs", duration) or "no time", estimated and "estimated" or "saved"))
	private.StartTicker()
end

private.Takeoff = function()
	local p = private.pending
	private.pending = nil
	if not p then
		return
	end
	local flight
	if p.unpicked then
		flight = private.Unpicked(p)
		private.Debug(string.format("off the taxi map from %s (%s): %s %s", tostring(flight.from),
			tostring(flight.origin), tostring(flight.key),
			flight.duration and string.format("%.0fs", flight.duration) or "no time"))
	else
		flight = {
			key = p.key,
			name = p.name,
			duration = p.duration,
			estimated = p.estimated,
			len = p.len,
			delay = p.delay,
		}
	end
	flight.start = GetTime()
	private.flight = flight
	CDTL3.db.char.flight = {
		key = flight.key,
		name = flight.name,
		duration = flight.duration,
		estimated = flight.estimated,
		len = flight.len,
		delay = flight.delay,
		from = flight.from,
		origin = flight.origin,
		serverStart = GetServerTime(),
	}
	if flight.duration then
		private.ShowCountdown(flight)
		pcall(private.FirstFlightNote, flight)
	end
end

-- The first flight CDTL3 counts down (ever, on this game client: account-wide), one chat line
-- says whose countdown it is and where to turn it off
private.FirstFlightNote = function(flight)
	local g = CDTL3.db.global
	if g.flightNoteShown then
		return
	end
	g.flightNoteShown = true
	if type(flight.name) == "string" and flight.name ~= "" then
		CDTL3:Print(string.format(L["The countdown to %s is CDTL3's flight timer. To turn flight timers off: /cdtl3, Global tab, Flight timers."], flight.name))
	else
		CDTL3:Print(L["The countdown is CDTL3's flight timer. To turn flight timers off: /cdtl3, Global tab, Flight timers."])
	end
end

private.Land = function()
	local flight = private.flight
	private.flight = nil
	CDTL3.db.char.flight = nil
	if not flight then
		return
	end
	local took = GetTime() - flight.start
	local store = private.Store()
	if flight.from or flight.origin then
		private.Arrived(flight)
	end
	local saved = flight.key and store.routes[flight.key]
	local cutShort = saved and took < saved * private.SHORT
	if flight.key and not flight.aborted and not flight.resumed and not cutShort and took >= private.MIN_LEARN then
		store.routes[flight.key] = math.floor(took * 10 + 0.5) / 10
		if flight.origin then
			store.starts[flight.origin] = flight.key
		end
		if flight.len and flight.len > 0 then
			store.len = store.len + flight.len
			store.time = store.time + math.max(took - (flight.delay or 0), 1)
		end
		private.Debug(string.format("landed: %s took %.1fs (saved)", tostring(flight.key), took))
	else
		private.Debug(string.format("landed: %s took %.1fs (not saved)", tostring(flight.key), took))
	end
	if flight.duration then
		private.EndCountdown()
	end
	CDTL3:ApplyCombatVisibility()
end

-- after a /reload or login in the air: the countdown picks up where it was
private.Resume = function(isReload)
	local saved = CDTL3.db.char.flight
	if not saved then
		return
	end
	if not (UnitOnTaxi and UnitOnTaxi("player")) or not FL:Enabled() then
		CDTL3.db.char.flight = nil
		return
	end
	local now = GetServerTime()
	local ran
	if isReload then
		ran = now - (saved.serverStart or now)
	else
		-- a flight is taken to pause while logged out
		ran = (saved.logoutAt or now) - (saved.serverStart or now)
	end
	ran = math.max(ran, 0)
	local flight = {
		key = saved.key,
		name = saved.name,
		duration = saved.duration,
		estimated = saved.estimated,
		len = saved.len,
		delay = saved.delay,
		from = saved.from,
		origin = saved.origin,
		start = GetTime() - ran,
		resumed = not isReload,
	}
	private.flight = flight
	saved.logoutAt = nil
	saved.serverStart = GetServerTime() - ran
	if flight.duration then
		private.ShowCountdown(flight, flight.duration - ran)
	end
	private.StartTicker()
end

---------------------------------------------------------------- events and polling

private.Tick = function()
	local onTaxi = UnitOnTaxi and UnitOnTaxi("player")
	if private.pending then
		if onTaxi then
			private.Takeoff()
		elseif GetTime() - private.pending.at > private.TAKEOFF_WAIT then
			private.pending = nil
		end
	elseif private.flight and not onTaxi then
		private.Land()
	end
	if not private.pending and not private.flight then
		private.StopTicker()
	end
end

private.StartTicker = function()
	private.elapsed = 0
	private.eventFrame:SetScript("OnUpdate", function(_, elapsed)
		private.elapsed = private.elapsed + elapsed
		if private.elapsed >= private.TICK then
			private.elapsed = 0
			local ok, err = pcall(private.Tick)
			if not ok then
				private.pending, private.flight = nil, nil
				private.StopTicker()
				private.Debug("error: " .. tostring(err))
			end
		end
	end)
end

private.StopTicker = function()
	private.eventFrame:SetScript("OnUpdate", nil)
end

private.OnEvent = function(_, event, ...)
	if not CDTL3.db then
		return
	end
	if event == "TAXIMAP_OPENED" then
		if FL:Enabled() then
			private.ReadMap()
		end
	elseif event == "PLAYER_CONTROL_LOST" or event == "PLAYER_CONTROL_GAINED" then
		if event == "PLAYER_CONTROL_LOST" then
			private.WatchTakeoff()
		end
		if private.pending or private.flight then
			private.Tick()
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		local _, isReload = ...
		if CDTL3.db.char.flight and not private.flight then
			C_Timer.After(private.RESUME_DELAY, function()
				if not private.flight then
					private.Resume(isReload and true or false)
				end
			end)
		end
	elseif event == "PLAYER_LOGOUT" then
		if private.flight and CDTL3.db.char.flight then
			CDTL3.db.char.flight.logoutAt = GetServerTime()
		end
	elseif event == "GOSSIP_SHOW" then
		if FL:Enabled() then
			private.ReadGossip()
		end
	end
end

-- the open chat window's options by their order, so a pick by index can be named by option ID
private.ReadGossip = function()
	local byIndex = {}
	if C_GossipInfo and C_GossipInfo.GetOptions then
		local ok, options = pcall(C_GossipInfo.GetOptions)
		if ok and type(options) == "table" then
			for _, o in ipairs(options) do
				if type(o) == "table" and type(o.orderIndex) == "number" and type(o.gossipOptionID) == "number" then
					byIndex[o.orderIndex] = o.gossipOptionID
				end
			end
		end
	end
	private.gossip = byIndex
end

-- Blizzard's chat window picks by index (C_GossipInfo.SelectOptionByIndex); other addons may pick
-- by option ID (SelectOption)
private.OnGossipPick = function(index)
	local id = private.gossip and private.gossip[index]
	if not id and type(index) == "number" then
		private.ReadGossip()
		id = private.gossip[index]
	end
	private.WatchTakeoff(id and ("g:" .. id) or nil)
end

private.eventFrame = CreateFrame("Frame")
for _, e in ipairs(private.EVENTS) do
	pcall(private.eventFrame.RegisterEvent, private.eventFrame, e)
end
private.eventFrame:SetScript("OnEvent", function(self, event, ...)
	local ok, err = pcall(private.OnEvent, self, event, ...)
	if not ok then
		private.Debug("error: " .. tostring(err))
	end
end)

if TakeTaxiNode then
	hooksecurefunc("TakeTaxiNode", function(slot)
		local ok, err = pcall(private.OnTakeTaxiNode, slot)
		if not ok then
			private.Debug("error: " .. tostring(err))
		end
	end)
end

-- a chat option can start a flight with no taxi map (the druids' Moonglade flight masters)
if C_GossipInfo and C_GossipInfo.SelectOptionByIndex then
	hooksecurefunc(C_GossipInfo, "SelectOptionByIndex", function(index)
		local ok, err = pcall(private.OnGossipPick, index)
		if not ok then
			private.Debug("error: " .. tostring(err))
		end
	end)
end
if C_GossipInfo and C_GossipInfo.SelectOption then
	hooksecurefunc(C_GossipInfo, "SelectOption", function(optionID)
		local ok, err = pcall(private.WatchTakeoff, type(optionID) == "number" and ("g:" .. optionID) or nil)
		if not ok then
			private.Debug("error: " .. tostring(err))
		end
	end)
end

if TaxiRequestEarlyLanding then
	hooksecurefunc("TaxiRequestEarlyLanding", function()
		if private.flight then
			private.flight.aborted = true
		end
	end)
end

-- for the harness
FL.private = private
