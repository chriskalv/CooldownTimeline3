-- Group play (feature panel cards 18, 19 and 24; owner's picks "Caster lane", "Strip on the cooldown icon",
-- "Burst lane" with an optional "Burst strip").
--
--   Caster lane   a lane setting (lane.casterLane) that puts each caster's name under their icon in their class
--                 colour. Two feeds fill it, both through CDTL3:StartTimer: (1) on MoP, TBC and Era the combat log
--                 (other players' casts of the ticked spells, timer type "raidcds"); (2) on any client the
--                 CooldownCollaborator addon's own timers (type "cdcGroup", owner and class on each timer).
--   Effect strip  Filters > Spells > Show effect on target: a thin countdown strip and the target's name on the
--                 spell's own icon. Exact where the combat log is open (aura applied / removed by you); an
--                 estimate from your cast on Retail and WoW: Forever.
--   Burst pack    Filters > Defaults > Burst pack: custom timers for lust and Sated, your trinkets and a potion,
--                 sent to one lane (the Burst lane) set to the long-buff scale; plus an optional Burst strip.
--
-- Everything is off until turned on. Hidden (secret) values are never read here: every number comes from the
-- combat log (Classic clients only), the player's own cast event or CDTL3's own timers.
local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
local private = {}
CDTL3.Group = private

local GetInfo = (C_CombatLog and C_CombatLog.GetCurrentEventInfo) or CombatLogGetCurrentEventInfo

local DEFAULTS = { raidCasts = false, burstLane = 3, strip = false, stripX = 0, stripY = -200 }

-- a saved group setting, or its default (nothing is written until the player changes one)
private.Get = function(key)
	local g = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.global
	local s = g and g["group"]
	if type(s) == "table" and s[key] ~= nil then
		return s[key]
	end
	return DEFAULTS[key]
end

private.Set = function(key, val)
	local g = CDTL3.db.profile.global
	if type(g["group"]) ~= "table" then
		g["group"] = {}
	end
	g["group"][key] = val
end

private.ClassColor = function(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		return c.r or 1, c.g or 1, c.b or 1
	end
	return 1, 1, 1
end

private.Short = function(name)
	return type(name) == "string" and (name:match("^[^-]+") or name) or ""
end

---------------------------------------------------------------- Caster lane: names under the icons
-- Called at the end of RefreshIcon (Cooldown.lua). A timer with an owner on a lane whose Caster lane box is
-- ticked gets the owner's short name under its icon, in the owner's class colour.
function CDTL3:CasterRefreshIcon(cd)
	local d, ic = cd.data, cd.icon
	local lane = d["owner"] and d["lane"] and CDTL3.db.profile.lanes["lane" .. d["lane"]]
	local fs = ic.cdtl3Caster
	if not (lane and lane["casterLane"]) then
		if fs then
			fs:Hide()
		end
		return
	end

	if not fs then
		fs = ic:CreateFontString(nil, "OVERLAY")
		ic.cdtl3Caster = fs
	end
	local ts = lane["icons"]["text3"]
	local font = CDTL3.LSM:Fetch("font", ts["font"])
	local size = tonumber(ts["size"]) or 11
	if font and size > 0 then
		fs:SetFont(font, size, "OUTLINE")
	end
	fs:ClearAllPoints()
	fs:SetPoint("TOP", ic, "BOTTOM", 0, -2)
	fs:SetText(private.Short(d["owner"]))
	fs:SetTextColor(private.ClassColor(d["class"]))
	fs:Show()
end

-- Lane settings (Lanes > a lane > General)
function CDTL3:AddCasterLaneArgs(args, i, lane)
	args["casterLane"] = {
		name = L["Caster lane"],
		desc = L["Puts each caster's name under their icon in their class colour. Timers from other players (Raid cooldowns on MoP, TBC and Era, or CooldownCollaborator on any client) show this way; nothing shows until one of them sends timers to this lane."],
		order = 201.6,
		type = "toggle",
		get = function(info)
				return lane["casterLane"] and true or false
			end,
		set = function(info, val)
				lane["casterLane"] = val
				CDTL3:RefreshAllIcons()
			end,
	}
	args["casterScale"] = {
		name = L["Caster lane scale"],
		desc = L["Sets this lane to Linear (Time) over 3 minutes and labels it Ready, 45s, 1m30s, 2m15s and 3m. Cooldowns longer than 3 minutes wait at the far end."],
		order = 201.7,
		type = "execute",
		func = function(info)
				lane["mode"]["type"] = "LINEAR_ABS"
				local la = lane["mode"]["linearAbs"]
				la["max"] = 180
				la["hideTimeSurplus"] = false
				la["timeFormat"] = "XhYmZs"
				local labels = { "Ready", "45s", "1m30s", "2m15s", "3m" }
				for n = 1, 5 do
					lane["modeText"]["text" .. n]["text"] = labels[n]
				end
				CDTL3:RefreshLane(i)
			end,
	}
end

---------------------------------------------------------------- Raid cooldowns from the combat log
-- { spell id, cooldown seconds }. Matched by the spell's game name as well as its ID (ranks). MoP, TBC and Era
-- only: Retail and Forever close the combat log. Check the lengths against game data with tools/spell-list-check.
private.RAID = {
	mop = {
		{ 97462, 180 }, { 62618, 180 }, { 51052, 120 }, { 98008, 180 }, { 64843, 180 }, { 64901, 360 },
		{ 31821, 180 }, { 115310, 180 }, { 740, 480 }, { 108280, 180 }, { 120668, 300 }, { 15286, 180 },
		{ 47788, 180 }, { 33206, 180 }, { 116849, 120 }, { 102342, 60 }, { 6940, 120 }, { 1022, 300 },
		{ 1038, 120 }, { 29166, 180 }, { 20484, 600 },
	},
	tbc = {
		{ 29166, 360 }, { 26994, 1200 }, { 16190, 300 }, { 10060, 180 }, { 33206, 120 }, { 19752, 3600 },
		{ 27154, 3600 }, { 10278, 300 }, { 871, 1800 }, { 1161, 600 }, { 27239, 1800 }, { 34477, 120 },
		{ 740, 600 }, { 34433, 300 }, { 2062, 1200 },
	},
	era = {
		{ 29166, 360 }, { 20484, 1800 }, { 10060, 180 }, { 16190, 300 }, { 19752, 3600 }, { 633, 3600 },
		{ 1022, 300 }, { 871, 1800 }, { 1161, 600 }, { 20707, 1800 }, { 740, 300 }, { 5209, 600 },
	},
}

-- the list for this client, or nil where the combat log is closed
private.RaidList = function()
	if CDTL3.retailAPI then
		return nil
	end
	local v = CDTL3.tocversion or 0
	if v < 20000 then
		return private.RAID.era
	elseif v < 30000 then
		return private.RAID.tbc
	elseif v >= 50000 and v < 60000 then
		return private.RAID.mop
	end
	return nil
end

private.byID, private.byName, private.classOf, private.classTry = {}, {}, {}, {}

private.BuildRaid = function()
	for k in pairs(private.byID) do private.byID[k] = nil end
	for k in pairs(private.byName) do private.byName[k] = nil end
	local list = private.RaidList()
	for _, row in ipairs(list or {}) do
		local name, icon = CDTL3:GetSpellInfo(row[1])
		if name then
			local e = { id = row[1], cd = row[2], name = name, icon = icon }
			private.byID[row[1]] = e
			private.byName[name] = e
		end
	end
end

private.TickedOff = function(id)
	local g = CDTL3.db.profile.global["group"]
	return type(g) == "table" and type(g["ticksOff"]) == "table" and g["ticksOff"][id] == true
end

-- CooldownCollaborator (1.1.0 on) hears the same casts from the combat log and sends them as "Group cooldowns":
-- while it does, and that type is switched on here, these casts are left to it so none shows twice
private.CollaboratorFeeds = function()
	local cc = _G["CooldownCollaborator"]
	if type(cc) ~= "table" or type(cc.BridgeActive) ~= "function" or not CDTL3.timerTypes["cdcgroup"] then
		return false
	end
	local ok, on = pcall(cc.BridgeActive, cc)
	if not (ok and on) then
		return false
	end
	local s = CDTL3:TimerTypeSettings("cdcgroup")
	return s ~= nil and s["enabled"] ~= false
end

private.RaidCast = function(srcGUID, srcName, srcFlags, spellID, spellName)
	if type(srcFlags) ~= "number" or type(srcName) ~= "string" then
		return
	end
	-- a player in my party or raid: any affiliation bit for party (0x2) or raid (0x4), and the player type bit (0x400)
	local partyOrRaid = (COMBATLOG_OBJECT_AFFILIATION_PARTY or 0x2) + (COMBATLOG_OBJECT_AFFILIATION_RAID or 0x4)
	if bit.band(srcFlags, partyOrRaid) == 0 or bit.band(srcFlags, COMBATLOG_OBJECT_TYPE_PLAYER or 0x400) == 0 then
		return
	end
	local e = private.byID[spellID] or private.byName[spellName]
	if not e or private.TickedOff(e.id) or private.CollaboratorFeeds() then
		return
	end
	local class = private.classOf[srcGUID]
	if not class then
		-- a failed lookup is not kept: the next cast of that caster tries again, at most every 10 s
		local now = GetTime()
		local last = private.classTry[srcGUID]
		if not last or now - last >= 10 then
			private.classTry[srcGUID] = now
			local ok, c = pcall(function() return select(2, GetPlayerInfoByGUID(srcGUID)) end)
			if ok and c then
				class = c
				private.classOf[srcGUID] = c
				private.classTry[srcGUID] = nil
			end
		end
	end
	CDTL3:StartTimer("raidcds", srcGUID .. ":" .. e.id, { name = e.name, icon = e.icon, duration = e.cd,
		startedAt = GetTime(), owner = srcName, class = class or nil })
end

---------------------------------------------------------------- Effect on target (card 19)
-- private.effects[spell name] = reused table { active, untilT, len, name, class, estimated, guid }
private.effects = {}
private.extNames = {}
private.extDirty = true
CDTL3.effectsLive = false

private.RebuildExt = function()
	for k in pairs(private.extNames) do private.extNames[k] = nil end
	local list = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.tables and CDTL3.db.profile.tables["spells"]
	for _, e in pairs(list or {}) do
		if e["showEffect"] and e["name"] and CDTL3:IsMyEntry(e) then
			private.extNames[e["name"]] = e
		end
	end
	private.extOn = next(private.extNames) ~= nil
	private.extDirty = false
end

private.UNITS = { "target", "focus", "mouseover" }
for n = 1, 4 do private.UNITS[#private.UNITS + 1] = "party" .. n end
for n = 1, 40 do private.UNITS[#private.UNITS + 1] = "raid" .. n end

-- the real length of an aura I just put on someone, read from their unit while I can find it (Classic only)
private.AuraLength = function(guid, spellName)
	for _, unit in ipairs(private.UNITS) do
		local ok, found = pcall(function()
			if UnitGUID(unit) ~= guid then
				return nil
			end
			for i = 1, 40 do
				local name, _, duration = CDTL3:GetUnitAura(unit, i, "HELPFUL")
				if not name then
					return nil
				end
				if name == spellName and type(duration) == "number" and duration > 0 then
					return duration
				end
			end
		end)
		if ok and found then
			return found
		end
	end
	return nil
end

private.StartEffect = function(spellName, guid, targetName, class, length, estimated)
	local e = private.extNames[spellName]
	if not e then
		return
	end
	local len = length or tonumber(e["effectLength"]) or 10
	local ex = private.effects[spellName]
	if not ex then
		ex = {}
		private.effects[spellName] = ex
	end
	ex.active, ex.guid, ex.len, ex.untilT = true, guid, len, GetTime() + len
	ex.name, ex.class, ex.estimated = targetName and private.Short(targetName) or nil, class, estimated and true or false
	for _, f in ipairs(CDTL3.cooldowns) do
		if f.data["name"] == spellName and f.data["type"] == "spells" and f.icon.cdtl3Strip then
			f.icon.cdtl3Strip.named = nil	-- the new target's name is drawn on the next tick
		end
	end
	CDTL3.effectsLive = true
end

private.EndEffect = function(spellName)
	local ex = private.effects[spellName]
	if not ex or not ex.active then
		return
	end
	ex.active = false
	local live = false
	for _, other in pairs(private.effects) do
		if other.active then
			live = true
		end
	end
	CDTL3.effectsLive = live
	for _, f in ipairs(CDTL3.cooldowns) do
		local st = f.icon.cdtl3Strip
		if st and f.data["name"] == spellName then
			st:Hide()
			st.shown = false
		end
	end
end

local function StripFor(ic)
	local st = ic.cdtl3Strip
	if st then
		return st
	end
	st = CreateFrame("Frame", nil, ic)
	st:SetSize(ic:GetWidth(), 4)
	st:SetPoint("BOTTOMLEFT", ic, "TOPLEFT", 0, 2)
	st.bg = st:CreateTexture(nil, "BACKGROUND")
	st.bg:SetAllPoints()
	st.bg:SetColorTexture(0, 0, 0, 0.7)
	st.fill = st:CreateTexture(nil, "ARTWORK")
	st.fill:SetPoint("TOPLEFT")
	st.fill:SetPoint("BOTTOMLEFT")
	st.fill:SetColorTexture(1, 1, 1, 1)
	st.name = st:CreateFontString(nil, "OVERLAY")
	st.name:SetPoint("BOTTOMLEFT", st, "TOPLEFT", 0, 2)
	st.time = st:CreateFontString(nil, "OVERLAY")
	st.time:SetPoint("LEFT", st.name, "RIGHT", 3, 0)
	ic.cdtl3Strip = st
	return st
end

-- Called from IconUpdate (Cooldown.lua) while any effect is live: draws the strip on the spell's icon
function CDTL3:EffectStripTick(f)
	local d = f.data
	if d["type"] ~= "spells" then
		return
	end
	local ex = private.effects[d["name"]]
	if not ex or not ex.active then
		return
	end
	local left = ex.untilT - GetTime()
	if left <= 0 then
		private.EndEffect(d["name"])
		return
	end

	local ic = f.icon
	local st = StripFor(ic)
	if not st.named then
		local font = CDTL3.LSM:Fetch("font", "Fira Sans Condensed")
		if font then
			st.name:SetFont(font, 11, "OUTLINE")
			st.time:SetFont(font, 11, "OUTLINE")
		end
		st.name:SetText(ex.name or "")
		st.name:SetTextColor(private.ClassColor(ex.class))
		st.fill:SetColorTexture(private.ClassColor(ex.class))
		st.named = true
		st:SetAlpha(ex.estimated and 0.6 or 1)
		st:SetWidth(ic:GetWidth())
	end
	if not st.shown then
		st:Show()
		st.shown = true
	end
	local frac = left / ex.len
	if frac > 1 then
		frac = 1
	end
	st.fill:SetWidth(math.max(0.1, st:GetWidth() * frac))
	local now = GetTime()
	if not st.nextText or now >= st.nextText then
		st.time:SetText(string.format("%.1f", left))
		st.nextText = now + 0.1
	end
end

-- Retail and Forever: an estimate from the cast (the combat log is closed). The name comes from the target
-- at the moment of the cast; if the game won't give it, the strip shows the time only.
private.OnCast = function(spellID)
	local name = CDTL3:GetSpellInfo(spellID)
	if not name or not private.extNames[name] then
		return
	end
	local targetName, class
	local ok = pcall(function()
		if UnitExists("target") and not UnitIsUnit("target", "player") and UnitIsFriend("player", "target") then
			local n = UnitName("target")
			local _, c = UnitClass("target")
			if type(n) == "string" and not (issecretvalue and issecretvalue(n)) then
				targetName = n
			end
			if type(c) == "string" and not (issecretvalue and issecretvalue(c)) then
				class = c
			end
		end
	end)
	if not ok then
		targetName, class = nil, nil
	end
	private.StartEffect(name, nil, targetName, class, nil, true)
end

-- Filters > Spells entry: Show effect on target
function CDTL3:AddEffectArgs(args, t, entryFn)
	if t ~= "spells" then
		return
	end
	local function hidden()
		return CDTL3.currentFilterHidden[t]
	end
	args["showEffect"] = {
		name = L["Show effect on target"],
		desc = L["After you cast this on someone else, a thin countdown strip and their name appear on this spell's icon until the effect ends. Exact on Classic Era, TBC Anniversary and MoP Classic (read from the combat log). On Retail and WoW: Forever it is an estimate from your cast, shown dimmed: the name is read from your target when you cast, and if the game will not give it the strip shows the time only. It cannot see the effect being removed early there."],
		order = 710,
		type = "toggle",
		hidden = hidden,
		get = function(info)
				local s = entryFn(t)
				return s and s["showEffect"] and true or false
			end,
		set = function(info, val)
				local s = entryFn(t)
				if s then
					s["showEffect"] = val and true or nil
					private.extDirty = true
					private.RebuildExt()
				end
			end,
	}
	args["effectLength"] = {
		name = L["Effect length"],
		desc = L["How many seconds the effect lasts. Used on Retail and WoW: Forever, and on the other clients when the game does not tell the length."],
		order = 711,
		type = "range",
		min = 1,
		max = 120,
		bigStep = 1,
		hidden = function()
				local s = entryFn(t)
				return CDTL3.currentFilterHidden[t] or not (s and s["showEffect"])
			end,
		get = function(info)
				local s = entryFn(t)
				return s and tonumber(s["effectLength"]) or 10
			end,
		set = function(info, val)
				local s = entryFn(t)
				if s then
					s["effectLength"] = val
				end
			end,
	}
end

---------------------------------------------------------------- Burst pack (card 24)
-- { aura spell ID, seconds, slot } slot 1 = lust, 2 = Sated. Where they exist on the client: Classic Era has
-- neither; TBC has Bloodlust and Heroism but no Sated; MoP adds Time Warp, Ancient Hysteria and the four
-- lockout debuffs; Retail adds Fury of the Aspects and Primal Rage.
private.BURST = {
	tbc = { { 2825, 40, 1 }, { 32182, 40, 1 } },
	mop = { { 2825, 40, 1 }, { 32182, 40, 1 }, { 80353, 40, 1 }, { 90355, 40, 1 },
		{ 57724, 600, 2 }, { 57723, 600, 2 }, { 80354, 600, 2 }, { 95809, 600, 2 } },
	retail = { { 2825, 40, 1 }, { 32182, 40, 1 }, { 80353, 40, 1 }, { 390386, 40, 1 }, { 264667, 40, 1 },
		{ 57724, 600, 2 }, { 57723, 600, 2 }, { 80354, 600, 2 }, { 95809, 600, 2 }, { 264689, 600, 2 } },
}

-- Trinkets with no on-use spell that start a proc and a hidden internal cooldown: [item ID] = { aura spell ID,
-- seconds the aura is up }. The card says the built-in data lacks these; fill in from game data (the pack
-- adds the row for a trinket you wear, so nothing here changes anything until an ID is listed).
private.PROCS = {}

private.BurstList = function()
	local v = CDTL3.tocversion or 0
	if v >= 60000 then
		return private.BURST.retail
	elseif v >= 50000 then
		return private.BURST.mop
	elseif v >= 20000 and v < 30000 then
		return private.BURST.tbc
	end
	return nil
end

private.BurstLane = function()
	local n = tonumber(private.Get("burstLane")) or 3
	return (n >= 1 and n <= 3) and n or 3
end

private.ApplyLongScale = function(lane)
	lane["mode"]["type"] = "SPLIT_ABS"
	local sa = lane["mode"]["splitAbs"]
	sa["max"] = 3600
	sa["hideTimeSurplus"] = false
	sa["count"] = 3
	sa["s1v"], sa["s1p"] = 30, 0.25
	sa["s2v"], sa["s2p"] = 120, 0.5
	sa["s3v"], sa["s3p"] = 600, 0.75
end

-- send one saved entry (and its live icon) to the burst lane
private.Route = function(s, cdType, n)
	s["lane"], s["readyFrame"], s["enabled"], s["ignored"] = n, n, true, false
	local name = cdType == "items" and s["itemName"] or s["name"]
	local f = name and CDTL3:GetExistingCooldown(name, cdType)
	if f then
		f.data["lane"], f.data["readyFrame"], f.data["enabled"], f.data["ignored"] = n, n, true, false
		CDTL3:MoveToLane(f)
	end
end

-- The pack only changes entries that belong to this character (CDTL3:IsMyEntry). A same-named entry
-- that only other characters use is left alone and counted in private.skipped.
private.skipped = 0
private.MyAuraCustom = function(name)
	for _, e in pairs(CDTL3.db.profile.tables["customs"]) do
		if e["name"] == name and e["triggerType"] == "aura" then
			if CDTL3:IsMyEntry(e) then
				return e
			end
			private.skipped = private.skipped + 1
			return nil, true
		end
	end
	return nil, false
end

private.ItemEntry = function(itemID, mark)
	local list = CDTL3.db.profile.tables["items"]
	for _, e in pairs(list) do
		if e["itemID"] == itemID then
			if not CDTL3:IsMyEntry(e) then
				private.skipped = private.skipped + 1
				return nil
			end
			e["burst"] = mark
			return e, false
		end
	end
	local spellName, spellID = CDTL3.Compat.GetItemSpell(itemID)
	if not spellID then
		return nil
	end
	local s = CDTL3:NewItemEntry(spellName, spellID, itemID, 0)
	s["burst"] = mark
	s["ignored"] = false
	CDTL3:SaveNewEntry(s, "items", true)
	return s, true
end

-- Filters > Defaults > Burst pack. Returns the number of entries added and moved.
function CDTL3:BuildBurstPack()
	local n = private.BurstLane()
	local added, moved = 0, 0
	private.skipped = 0

	for _, row in ipairs(private.BurstList() or {}) do
		local name, icon = CDTL3:GetSpellInfo(row[1])
		if name then
			local s, foreign = private.MyAuraCustom(name)
			if foreign then
				s = nil
			elseif s then
				moved = moved + 1
			else
				s = CDTL3:ApplyEntryDefaults({ id = row[1], name = name, icon = icon, type = "customs", bCD = row[2] * 1000,
					setCustomCD = false, triggerType = "aura", link = CDTL3:GetSpellLink(row[1]) }, "customs")
				table.insert(CDTL3.db.profile.tables["customs"], s)
				added = added + 1
			end
			if s then
				s["burst"] = row[3] == 1 and "lust" or "sated"
				private.Route(s, "customs", n)
			end
		end
	end

	for slot = 13, 14 do
		local itemID = GetInventoryItemID("player", slot)
		if itemID then
			local s, isNew = private.ItemEntry(itemID, "trinket")
			if s then
				added = added + (isNew and 1 or 0)
				moved = moved + (isNew and 0 or 1)
				private.Route(s, "items", n)
			end
			local proc = private.PROCS[itemID]
			if proc then
				local name, icon = CDTL3:GetSpellInfo(proc[1])
				if name then
					local c, foreign = private.MyAuraCustom(name)
					if not c and not foreign then
						c = CDTL3:ApplyEntryDefaults({ id = proc[1], name = name, icon = icon, type = "customs", bCD = proc[2] * 1000,
							setCustomCD = false, triggerType = "aura", link = CDTL3:GetSpellLink(proc[1]) }, "customs")
						table.insert(CDTL3.db.profile.tables["customs"], c)
						added = added + 1
					end
					if c then
						c["burst"], c["burstItem"] = "proc", itemID
						private.Route(c, "customs", n)
					end
				end
			end
		end
	end

	-- the potion: the first potion carried that has a use spell
	local potion
	for bag = 0, 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemID = not potion and C_Container.GetContainerItemID(bag, slot)
			if itemID then
				local _, _, _, _, _, classID, subclassID = CDTL3.Compat.GetItemInfoInstant(itemID)
				if classID == 0 and subclassID == 1 and select(2, CDTL3.Compat.GetItemSpell(itemID)) then
					potion = itemID
				end
			end
		end
	end
	if potion then
		local s, isNew = private.ItemEntry(potion, "potion")
		if s then
			added = added + (isNew and 1 or 0)
			moved = moved + (isNew and 0 or 1)
			private.Route(s, "items", n)
		end
	end

	-- the lane: its own name, on and on the long-buff scale
	local lane = CDTL3.db.profile.lanes["lane" .. n]
	if lane then
		if type(lane["name"]) ~= "string" or lane["name"]:match("^Lane %d+$") then
			lane["name"] = L["Burst"]
		end
		private.ApplyLongScale(lane)
		local wasOn = lane["enabled"]
		lane["enabled"] = true
		if not wasOn then
			CDTL3:CreateLanes()
		end
		CDTL3:RefreshLane(n)
	end
	private.RebuildSlots()
	CDTL3:Print(string.format(L["Burst pack: %d added, %d already there, all on lane %d."], added, moved, n))
	if private.skipped > 0 then
		CDTL3:Print(string.format(L["Burst pack: %d entries only other characters use were left alone."], private.skipped))
	end
	return added, moved
end

---------------------------------------------------------------- Burst strip (the optional second look)
-- The look is the "Burst strip" choice of looks-boards.html fp24: a dark panel (padding 8 and 10, gap 8), five 40 px
-- slots, a gold label above each, a coloured state word below (up and ready green, sated red, proc gold, cooling grey).
local SLOT_W, ICON, GAP, PADX, PADY = 40, 40, 8, 10, 8
local GOLD, GREY, GREEN, RED = { 1, 0.82, 0 }, { 0.604, 0.627, 0.651 }, { 0.369, 0.941, 0.369 }, { 1, 0.478, 0.42 }
private.STATE_COLOR = { up = GREEN, ready = GREEN, sated = RED, proc = GOLD, cooling = GREY }

-- four bars round a frame, outside its edge: a border (thick, opaque) or a soft shadow (thick, faint)
local function Ring(frame, thick, r, g, b, a, layer)
	local ring = {}
	for i = 1, 4 do
		ring[i] = frame:CreateTexture(nil, layer or "BACKGROUND")
		ring[i]:SetColorTexture(r, g, b, a)
	end
	ring[1]:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -thick, 0)
	ring[1]:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", thick, 0)
	ring[1]:SetHeight(thick)
	ring[2]:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -thick, 0)
	ring[2]:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", thick, 0)
	ring[2]:SetHeight(thick)
	ring[3]:SetPoint("TOPRIGHT", frame, "TOPLEFT", 0, 0)
	ring[3]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
	ring[3]:SetWidth(thick)
	ring[4]:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, 0)
	ring[4]:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
	ring[4]:SetWidth(thick)
	return ring
end

local function RingShow(ring, shown)
	for i = 1, 4 do
		if shown then ring[i]:Show() else ring[i]:Hide() end
	end
end

private.SLOTS = { L["Lust"], L["Sated"], L["Trinket 1"], L["Trinket 2"], L["Potion"] }
-- name -> slot (1-5), aura-based names flagged in auraOf; rebuilt when the pack or the equipment changes
private.slotOf, private.auraOf, private.slotIcon = {}, {}, {}
private.slotAura, private.slotItem = {}, {}

private.RebuildSlots = function()
	for k in pairs(private.slotOf) do private.slotOf[k] = nil end
	for k in pairs(private.auraOf) do private.auraOf[k] = nil end
	for k in pairs(private.slotIcon) do private.slotIcon[k] = nil end
	local t = CDTL3.db and CDTL3.db.profile and CDTL3.db.profile.tables
	if not t then
		return
	end
	local trinket = { [GetInventoryItemID("player", 13) or 0] = 3, [GetInventoryItemID("player", 14) or 0] = 4 }
	for _, e in pairs(t["customs"] or {}) do
		local kind = e["burst"]
		local slot = (kind == "lust" and 1) or (kind == "sated" and 2) or (kind == "proc" and trinket[e["burstItem"] or 0]) or nil
		if slot and e["name"] then
			private.slotOf[e["name"]], private.auraOf[e["name"]] = slot, true
			private.slotIcon[slot] = private.slotIcon[slot] or e["icon"]
		end
	end
	for _, e in pairs(t["items"] or {}) do
		local slot = (e["burst"] == "trinket" and trinket[e["itemID"] or 0]) or (e["burst"] == "potion" and 5) or nil
		if slot and e["itemName"] then
			private.slotOf[e["itemName"]] = slot
			private.slotIcon[slot] = e["itemIcon"] or e["icon"]
		end
	end
end

local function Clock(s)
	if s >= 60 then
		return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60))
	end
	return string.format("%d", math.ceil(s))
end

private.BuildStrip = function()
	local f = CreateFrame("Frame", "CDTL3_BurstStrip", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(SLOT_W * 5 + GAP * 4 + PADX * 2, PADY * 2 + 12 + 4 + ICON + 4 + 12)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints()
	f.bg:SetColorTexture(38 / 255, 38 / 255, 38 / 255, 0.62)
	f.shadow = Ring(f, 3, 0, 0, 0, 0.2)
	f.slots = {}
	local font = CDTL3.LSM:Fetch("font", "Fira Sans Condensed")
	private.font = font
	for i = 1, 5 do
		local s = {}
		s.label = f:CreateFontString(nil, "OVERLAY")
		s.label:SetPoint("TOP", f, "TOPLEFT", PADX + (SLOT_W + GAP) * (i - 1) + SLOT_W / 2, -PADY)
		s.tx = f:CreateTexture(nil, "ARTWORK")
		s.tx:SetSize(ICON, ICON)
		s.tx:SetPoint("TOP", s.label, "BOTTOM", 0, -4)
		s.edge = Ring(s.tx, 1, 0, 0, 0, 0.85)
		s.dim = f:CreateTexture(nil, "ARTWORK", nil, 1)
		s.dim:SetAllPoints(s.tx)
		s.dim:SetColorTexture(10 / 255, 12 / 255, 14 / 255, 0.6)
		s.dim:Hide()
		s.glow = Ring(s.tx, 5, GOLD[1], GOLD[2], GOLD[3], 0.3)
		s.ring = Ring(s.tx, 2, GOLD[1], GOLD[2], GOLD[3], 1)
		RingShow(s.glow, false)
		RingShow(s.ring, false)
		s.count = f:CreateFontString(nil, "OVERLAY")
		s.count:SetPoint("CENTER", s.tx, "CENTER", 0, 0)
		s.state = f:CreateFontString(nil, "OVERLAY")
		s.state:SetPoint("TOP", s.tx, "BOTTOM", 0, -4)
		if font then
			s.label:SetFont(font, 10, "OUTLINE")
			s.count:SetFont(font, 14, "OUTLINE")
			s.state:SetFont(font, 10, "OUTLINE")
		end
		s.label:SetText(private.SLOTS[i])
		s.label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		f.slots[i] = s
	end
	f:SetScript("OnDragStart", function(self)
		if CDTL3.db.profile.global["unlockFrames"] then
			self:StartMoving()
		end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local cx, cy = self:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if cx and ux then
			private.Set("stripX", math.floor(cx - ux + 0.5))
			private.Set("stripY", math.floor(cy - uy + 0.5))
		end
	end)
	f.next = 0
	f:SetScript("OnUpdate", function(self, elapsed)
		self.next = self.next - elapsed
		if self.next <= 0 then
			self.next = 0.25
			private.StripRefresh(self)
		end
	end)
	private.strip = f
	return f
end

private.PlaceStrip = function()
	local f = private.strip
	if f then
		f:ClearAllPoints()
		f:SetPoint("CENTER", UIParent, "CENTER", tonumber(private.Get("stripX")) or 0, tonumber(private.Get("stripY")) or -200)
		f:EnableMouse(CDTL3.db.profile.global["unlockFrames"] and true or false)
	end
end

-- states: up (lust), sated, proc (trinket aura), cooling, ready; "-" where this client has nothing for the slot
private.StripRefresh = function(f)
	local sa, si = private.slotAura, private.slotItem
	for i = 1, 5 do
		sa[i], si[i] = nil, nil
	end
	for _, cd in ipairs(CDTL3.cooldowns) do
		local d = cd.data
		local slot = private.slotOf[d["type"] == "items" and d["itemName"] or d["name"]]
		if slot and d["currentCD"] and d["currentCD"] > 0 and d["enabled"] and not d["ignored"] then
			if private.auraOf[d["name"]] and d["type"] ~= "items" then
				sa[slot] = cd
			else
				si[slot] = cd
			end
		end
	end
	for i = 1, 5 do
		local s = f.slots[i]
		local tex = private.slotIcon[i]
		if not tex and (i == 3 or i == 4) then
			tex = GetInventoryItemTexture("player", i == 3 and 13 or 14)
		end
		s.tx:SetTexture(tex or 134400)
		local a, it = sa[i], si[i]
		local active = a or it
		local text = "-"
		if i == 1 then
			text = a and L["up"] or (private.slotIcon[1] and L["ready"] or "-")
		elseif i == 2 then
			text = a and L["sated"] or (private.slotIcon[2] and L["ready"] or "-")
		elseif a then
			text = L["proc"]
		elseif it then
			text = L["cooling"]
		elseif tex then
			text = L["ready"]
		end
		local c = private.STATE_COLOR[text] or GREY
		s.state:SetText(text)
		s.state:SetTextColor(c[1], c[2], c[3])
		-- on the icon: the time left, or READY where it waits (the look's ready slot)
		local waiting = text == "ready" and not active
		s.count:SetText(active and Clock(active.data["currentCD"]) or (waiting and L["READY"] or ""))
		if private.font then
			s.count:SetFont(private.font, waiting and 10 or 14, "OUTLINE")
		end
		-- cooling: greyed and dimmed; proc: a gold ring and glow
		local cooling = text == "cooling"
		s.tx:SetDesaturated(cooling or tex == nil)
		if cooling then s.dim:Show() else s.dim:Hide() end
		RingShow(s.ring, text == "proc")
		RingShow(s.glow, text == "proc")
	end
end

private.ApplyStrip = function()
	if not CDTL3.db then
		return
	end
	if private.Get("strip") then
		local f = private.strip or private.BuildStrip()
		private.RebuildSlots()
		private.PlaceStrip()
		f:Show()
		private.StripRefresh(f)
	elseif private.strip then
		private.strip:Hide()
	end
end

---------------------------------------------------------------- settings in Filters > Defaults
-- Called from GetFilterOptions (Options.lua) with the Defaults group's args
function CDTL3:AddGroupDefaultsArgs(args)
	local function noLog()
		return CDTL3:NoCombatLog()
	end
	args["groupHeader"] = { name = L["Group play"], type = "header", order = 900 }
	-- Burst pack
	args["burstPack"] = {
		name = L["Burst pack"],
		desc = function(info)
				return string.format(L["Adds timers for lust and Sated, your two trinkets and a potion you carry, where they exist on this client, and sends them all to lane %d. That lane is named Burst and set to the long-buff scale. Trinkets with no on-use effect need their proc listed in the addon's data."], private.BurstLane())
			end,
		order = 901,
		type = "execute",
		confirm = function(info)
				return string.format(L["The Burst pack will add timers for lust and Sated (where this client has them), your two trinkets and a potion you carry. It names lane %d Burst (if it still has its default name), sets it to the long-buff scale and moves your existing entries with the same names there. Other characters' entries are not touched. Go ahead?"], private.BurstLane())
			end,
		func = function(info)
				CDTL3:BuildBurstPack()
			end,
	}
	args["burstLane"] = {
		name = L["Burst lane"],
		desc = L["The lane the Burst pack sends its timers to. The pack's ready icons wait in the Ready frame with the same number."],
		order = 902,
		type = "select",
		width = "half",
		values = { [1] = "1", [2] = "2", [3] = "3" },
		get = function(info)
				return private.BurstLane()
			end,
		set = function(info, val)
				private.Set("burstLane", val)
			end,
	}
	args["burstStrip"] = {
		name = L["Burst strip"],
		desc = L["Shows five fixed slots (lust, Sated, two trinkets, potion) that never move, each saying up, sated, proc, cooling or ready. Unlock the frames to drag it, or set its position here. It reads the Burst pack's timers."],
		order = 903,
		type = "toggle",
		get = function(info)
				return private.Get("strip") and true or false
			end,
		set = function(info, val)
				private.Set("strip", val)
				private.ApplyStrip()
			end,
	}
	args["burstStripX"] = {
		name = L["Strip horizontal position"],
		desc = L["Pixels right (or left, if negative) of the screen centre"],
		order = 904,
		type = "range",
		min = -2000,
		max = 2000,
		bigStep = 1,
		hidden = function() return not private.Get("strip") end,
		get = function(info) return tonumber(private.Get("stripX")) or 0 end,
		set = function(info, val)
				private.Set("stripX", val)
				private.PlaceStrip()
			end,
	}
	args["burstStripY"] = {
		name = L["Strip vertical position"],
		desc = L["Pixels above (or below, if negative) the screen centre"],
		order = 905,
		type = "range",
		min = -2000,
		max = 2000,
		bigStep = 1,
		hidden = function() return not private.Get("strip") end,
		get = function(info) return tonumber(private.Get("stripY")) or -200 end,
		set = function(info, val)
				private.Set("stripY", val)
				private.PlaceStrip()
			end,
	}
	-- Raid cooldowns
	args["raidNote"] = {
		name = "\n" .. L["Raid cooldowns need the combat log, which Retail and WoW: Forever close to addons. A Caster lane still shows timers that CooldownCollaborator sends."],
		type = "description",
		order = 910,
		hidden = function() return not noLog() end,
	}
	args["raidCasts"] = {
		name = L["Track raid cooldowns"],
		desc = L["Shows other party and raid members' big cooldowns from the combat log, one icon per caster, in the lane chosen under Defaults › Raid cooldowns. Tick the spells that count below. Turn on a lane's Caster lane box to see the names. While CooldownCollaborator sends its Group cooldowns, the casts show from it instead, so none shows twice."],
		order = 911,
		type = "toggle",
		hidden = noLog,
		get = function(info) return private.Get("raidCasts") and true or false end,
		set = function(info, val)
				private.Set("raidCasts", val)
				private.Apply()
			end,
	}
	args["raidTicks"] = {
		name = L["Spells that count"],
		desc = L["Untick a spell to stop showing it"],
		order = 912,
		type = "multiselect",
		hidden = function() return noLog() or not private.Get("raidCasts") end,
		values = function(info)
				local v = {}
				for _, row in ipairs(private.RaidList() or {}) do
					local name = CDTL3:GetSpellInfo(row[1])
					if name then
						v[row[1]] = name
					end
				end
				return v
			end,
		get = function(info, key) return not private.TickedOff(key) end,
		set = function(info, key, val)
				local g = CDTL3.db.profile.global
				if type(g["group"]) ~= "table" then g["group"] = {} end
				if type(g["group"]["ticksOff"]) ~= "table" then g["group"]["ticksOff"] = {} end
				g["group"]["ticksOff"][key] = (not val) or nil
			end,
	}
end

---------------------------------------------------------------- wiring
-- (re)read the settings: which feeds are on. Safe to call any time.
private.Apply = function()
	if not (CDTL3.db and CDTL3.db.profile) then
		return
	end
	private.BuildRaid()
	private.raidOn = private.Get("raidCasts") and next(private.byID) ~= nil and not CDTL3:NoCombatLog() or false
	if private.raidOn then
		CDTL3:RegisterTimerType("raidcds", { name = L["Raid cooldowns"], icon = 136080 })
	end
	private.RebuildExt()
	private.ApplyStrip()
end

private.OnLog = function()
	local _, sub, _, srcGUID, srcName, srcFlags, _, dstGUID = GetInfo()
	local me = CDTL3.player["guid"]
	if sub == "SPELL_CAST_SUCCESS" then
		if private.raidOn and srcGUID ~= me then
			local spellID, spellName = select(12, GetInfo())
			private.RaidCast(srcGUID, srcName, srcFlags, spellID, spellName)
		end
	elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
		if private.extOn and srcGUID == me and dstGUID ~= me then
			local _, spellName = select(12, GetInfo())
			if private.extNames[spellName] then
				local dstName = select(9, GetInfo())
				local class = select(2, GetPlayerInfoByGUID(dstGUID))
				private.StartEffect(spellName, dstGUID, dstName, class, private.AuraLength(dstGUID, spellName), false)
			end
		end
	elseif sub == "SPELL_AURA_REMOVED" then
		if private.extOn and srcGUID == me then
			local _, spellName = select(12, GetInfo())
			local ex = private.effects[spellName]
			if ex and ex.active and ex.guid == dstGUID then
				private.EndEffect(spellName)
			end
		end
	end
end

-- chain behind the existing handler: a failure here never reaches it
if CDTL3.COMBAT_LOG_EVENT_UNFILTERED and GetInfo then
	local orig = CDTL3.COMBAT_LOG_EVENT_UNFILTERED
	function CDTL3:COMBAT_LOG_EVENT_UNFILTERED(...)
		if private.raidOn or private.extOn then
			pcall(private.OnLog)
		end
		return orig(self, ...)
	end
end

do
	local origRefresh = CDTL3.RefreshConfig
	if origRefresh then
		function CDTL3:RefreshConfig(...)
			local r = origRefresh(self, ...)
			pcall(private.Apply)
			return r
		end
	end

	local origLock = CDTL3.ToggleFrameLock
	if origLock then
		function CDTL3:ToggleFrameLock(...)
			local r = origLock(self, ...)
			pcall(private.PlaceStrip)
			return r
		end
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:SetScript("OnEvent", function(self, event, unit, castGUID, spellID)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		-- no combat log (Retail, Forever): the effect is an estimate from the cast
		if private.extOn and CDTL3:NoCombatLog() then
			pcall(private.OnCast, spellID)
		end
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		if private.strip and private.strip:IsShown() then
			pcall(private.RebuildSlots)
		end
	else
		pcall(private.Apply)
	end
end)
