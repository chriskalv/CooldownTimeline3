--[[
	Cooldown Timeline 3 - getting started (feature panel cards 3, 8, 10, 13, 15 and 43)
	  - Simple tab first (card 13), Help tab with every /cdtl3 command (card 15)
	  - Starter / Healer / Tank / DPS setups, tried on screen first (card 3)
	  - Look cards in Quick Style: save, share and apply looks (card 43)
	  - a ~ before a time CDTL3 counts itself (card 8)
	  - the three-step tour on a first install (card 10)
	The settings tabs are added to the tree CDTL3:GetFullOptions builds, so Options.lua stays as it is.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
local S = {}
CDTL3.Start = S

local private = {}

local function Profile()
	return CDTL3.db.profile
end

local function Gold(text)
	return "|cffffd100" .. text .. "|r"
end

----------------------------------------------------------------------------------------------------
-- ESTIMATE OR EXACT (card 8)
-- Which timers CDTL3 counts itself instead of following the game's own. Reads only flags (the
-- entry's type, a Custom CD Time, whether combat timers ride it): never a cooldown or aura value,
-- which can be hidden in combat.
----------------------------------------------------------------------------------------------------
function S.EstimateKind(f)
	local d = f and f.data
	if type(d) ~= "table" then
		return nil
	end
	if d["estimated"] then
		return "flight"
	end
	if not CDTL3.retailAPI then
		return nil
	end
	if f.ct and f.ct.riding then
		return nil	-- the game's own timer drives it
	end

	local CT = CDTL3.CombatTimers
	if CT then
		local ok, est = pcall(CT.Estimated, CT, f)
		if ok and est then
			return "buff"
		end
	end
	if d["setCustomCD"] and d["customCDTime"] then
		return "custom"
	end
	if d["type"] == "items" and (CDTL3.combat or (InCombatLockdown and InCombatLockdown())) then
		return "item"
	end
	return nil
end

-- "~" in front of the time when the player switched that on and the timer is an estimate, else ""
function CDTL3:EstimateMark(f)
	if not Profile().global["estimateTilde"] then
		return ""
	end
	return S.EstimateKind(f) and "~" or ""
end

-- the line under an icon's tooltip, naming what the estimate comes from
function CDTL3:EstimateTooltip(f)
	if not Profile().global["estimateTilde"] then
		return
	end
	local kind = S.EstimateKind(f)
	if not kind then
		return
	end
	local text = ({
		custom = L["~ Estimate, from your Custom CD Time"],
		item = L["~ Estimate, from when you used it"],
		buff = L["~ Estimate, from when it was gained"],
		flight = L["~ Estimate, from the route's length"],
	})[kind]
	GameTooltip:AddLine(text, 1, 0.82, 0)
end

----------------------------------------------------------------------------------------------------
-- SETUPS BY ROLE (card 3)
-- A setup says which lanes are on, how long each one shows (Max Time), where each kind of timer
-- goes (spells over `split` seconds to `long`, shorter ones to `short`) and the buffs' Ignore
-- Threshold. Quick Style shows it on the real frames first; Keep saves it, Undo puts it back.
----------------------------------------------------------------------------------------------------
-- gauge = true: the lane gets its Mana gauge (ResourceBars.lua), as the Healer look shows mana beside it
local function Lane(on, max, label, size, gauge)
	return { on = on, max = max, label = label, size = size, gauge = gauge }
end

S.setups = {
	{
		key = "starter", name = L["Starter"], blurb = L["One lane, bigger icons"],
		lanes = { Lane(true, 120, L["Everything, up to 2:00"], 48), Lane(false), Lane(false) },
		long = 1, short = 1, items = 1, buffs = 1, debuffs = 1,
	},
	{
		key = "healer", name = L["Healer"], blurb = L["Short cooldowns, big cooldowns and buffs"],
		lanes = { Lane(true, 300, L["Big cooldowns, up to 5:00"], nil, true), Lane(true, 30, L["Short cooldowns, up to 30 s"]), Lane(true, 60, L["Buffs, up to 1:00"]) },
		split = 30, long = 1, short = 2, items = 1, buffs = 3, debuffs = 3, buffThreshold = 300,
	},
	{
		key = "tank", name = L["Tank"], blurb = L["Taunt and interrupt, buffs on you, defensives"],
		lanes = { Lane(true, 300, L["Defensives, up to 5:00"]), Lane(true, 30, L["Taunt and interrupt, up to 30 s"]), Lane(true, 60, L["Buffs on you, up to 1:00"]) },
		split = 30, long = 1, short = 2, items = 1, buffs = 3, debuffs = 3, buffThreshold = 300,
	},
	{
		key = "dps", name = L["DPS"], blurb = L["Procs, burst and rotation"],
		lanes = { Lane(true, 180, L["Burst, up to 3:00"]), Lane(true, 30, L["Rotation, up to 30 s"]), Lane(true, 60, L["Procs, up to 1:00"]) },
		split = 30, long = 1, short = 2, items = 1, buffs = 3, debuffs = 3,
	},
}

function S.GetSetup(key)
	for _, s in ipairs(S.setups) do
		if s.key == key then
			return s
		end
	end
	return nil
end

-- the lane a timer of this type and length (seconds) goes to under a setup
function S.LaneFor(setup, ttype, seconds)
	if ttype == "spells" or ttype == "petspells" then
		if setup.split and (tonumber(seconds) or 0) <= setup.split then
			return setup.short
		end
		return setup.long
	elseif ttype == "items" then
		return setup.items
	elseif ttype == "buffs" then
		return setup.buffs
	elseif ttype == "debuffs" then
		return setup.debuffs
	end
	return nil
end

-- A new saved entry follows the kept setup (ApplyEntryDefaults, Helpers.lua); bCD is in ms
function S.NewEntryLane(entry, ttype)
	local key = CDTL3.db and Profile().global["setupKey"]
	local setup = key and key ~= "" and S.GetSetup(key)
	if not setup then
		return nil
	end
	return S.LaneFor(setup, ttype, (tonumber(entry["bCD"]) or 0) / 1000)
end

private.TYPES = { "spells", "petspells", "items", "buffs", "debuffs" }
private.MODE_TABLES = { "linear", "linearAbs", "split", "splitAbs" }

-- A setup's Split (Time) marks, inside each Max Time it uses and in rising order (the Healer look:
-- Ready, 30s, 1m, 2m, 5m), at a quarter, half and three quarters of the lane
private.MARKS = {
	[30] = { 5, 10, 20 },
	[60] = { 10, 20, 30 },
	[120] = { 15, 30, 60 },
	[180] = { 30, 60, 120 },
	[300] = { 30, 60, 120 },
}
private.MARK_POS = { 0.25, 0.5, 0.75 }
-- what a setup changes in mode.splitAbs besides max, so Undo can put the player's own marks back
private.MARK_KEYS = { "count", "s1v", "s1p", "s2v", "s2p", "s3v", "s3p" }

function S.MarksFor(max)
	local marks = private.MARKS[max]
	if marks then
		return marks
	end
	-- any other Max Time: a tenth, a fifth and two fifths of it
	return { max * 0.1, max * 0.2, max * 0.4 }
end

local function CopyMarks(sa)
	local marks = {}
	for _, k in ipairs(private.MARK_KEYS) do
		marks[k] = sa[k]
	end
	return marks
end

local function MyLists()
	local out = {}
	for _, t in ipairs(private.TYPES) do
		local list = Profile().tables[t]
		if type(list) == "table" then
			for k, e in pairs(list) do
				if type(e) == "table" and CDTL3:IsMyEntry(e) then
					out[#out + 1] = { entry = e, type = t, key = k }
				end
			end
		end
	end
	return out
end

-- everything a setup can change, so Undo can put it back
function private.Snapshot()
	local p = Profile()
	local snap = { lanes = {}, defaults = {}, thresholds = {}, entries = {}, cooldowns = {}, setupKey = p.global["setupKey"] }
	for n = 1, 3 do
		local lane = p.lanes["lane" .. n]
		local max = {}
		for _, k in ipairs(private.MODE_TABLES) do
			max[k] = lane.mode[k].max
		end
		snap.lanes[n] = { enabled = lane.enabled, size = lane.icons.size, max = max, gauge = lane.gauge and lane.gauge.enabled or false,
			marks = CopyMarks(lane.mode.splitAbs) }
	end
	for _, t in ipairs(private.TYPES) do
		local g = p.global[t]
		snap.defaults[t] = g["defaultLane"]
		snap.thresholds[t] = g["ignoreThreshold"]
	end
	snap.saved = {}	-- the same entries by list and position, for the copy that survives a reload
	for _, item in ipairs(MyLists()) do
		snap.entries[item.entry] = item.entry["lane"]
		snap.saved[#snap.saved + 1] = { t = item.type, k = item.key, lane = item.entry["lane"] }
	end
	-- sample icons aren't moved back: every preview makes its own and Keep or Undo clears them
	for _, cd in ipairs(CDTL3.cooldowns) do
		if cd.data["type"] ~= "testing" then
			snap.cooldowns[cd] = cd.data["lane"]
		end
	end
	return snap
end

-- A preview is saved with the profile while it waits for Keep or Undo, so a reload can't make it
-- count as kept: the next login puts the old lanes back (S.ResolveStale).
function private.Persist(snap, p)
	p = p or Profile()
	local saved = { profile = CDTL3.db:GetCurrentProfile(), setupKey = snap.setupKey, lanes = {}, defaults = {},
		thresholds = {}, entries = {} }
	for n, was in pairs(snap.lanes) do
		local max = {}
		for k, v in pairs(was.max) do
			max[k] = v
		end
		saved.lanes[n] = { enabled = was.enabled, size = was.size, max = max, gauge = was.gauge, marks = was.marks and CopyMarks(was.marks) }
	end
	for t, v in pairs(snap.defaults) do
		saved.defaults[t] = v
	end
	for t, v in pairs(snap.thresholds) do
		saved.thresholds[t] = v
	end
	for i, e in ipairs(snap.saved) do
		saved.entries[i] = { t = e.t, k = e.k, lane = e.lane }
	end
	p.global["setupUndo"] = saved
end

-- p = the profile the preview started in (a preview belongs to it, whatever profile is active now)
function private.ClearPersisted(p)
	p = p or (CDTL3.db and Profile())
	if p and p.global and p.global["setupUndo"] ~= nil then
		p.global["setupUndo"] = nil
	end
end

local function MoveCooldown(cd, lane)
	if lane and cd.data["lane"] ~= lane then
		cd.data["lane"] = lane
		CDTL3:MoveToLane(cd)
	end
end

-- the saved values only (no frames yet at login)
function private.RestoreValues(snap, p)
	p = p or Profile()
	for n = 1, 3 do
		local lane, was = p.lanes["lane" .. n], snap.lanes[n]
		lane.enabled = was.enabled
		lane.icons.size = was.size
		for _, k in ipairs(private.MODE_TABLES) do
			lane.mode[k].max = was.max[k]
		end
		if lane.gauge and was.gauge ~= nil then
			lane.gauge.enabled = was.gauge
		end
		-- the player's own Split (Time) marks (a copy saved before this build has none)
		if type(was.marks) == "table" then
			local sa = lane.mode.splitAbs
			for _, k in ipairs(private.MARK_KEYS) do
				sa[k] = was.marks[k]
			end
		end
	end
	for _, t in ipairs(private.TYPES) do
		p.global[t]["defaultLane"] = snap.defaults[t]
		p.global[t]["ignoreThreshold"] = snap.thresholds[t]
	end
	p.global["setupKey"] = snap.setupKey
	for entry, lane in pairs(snap.entries) do
		entry["lane"] = lane
	end
end

-- the saved Filters entry a live cooldown of a setup's types was made from (nil: none, or another type)
function private.EntryOf(d)
	local t = d["type"]
	for _, k in ipairs(private.TYPES) do
		if k == t then
			if t == "items" then
				return CDTL3:GetSpellSettings(d["itemName"] or d["name"], t, true)
			end
			return CDTL3:GetSpellSettings(d["name"], t)
		end
	end
	return nil
end

function private.Restore(snap, p)
	p = p or Profile()
	private.RestoreValues(snap, p)
	if p ~= Profile() then
		return	-- not the active profile: its values are back, there are no frames of it to move
	end
	for cd, lane in pairs(snap.cooldowns) do
		MoveCooldown(cd, lane)
	end
	-- A cooldown made while the preview was up (a buff gained, a spell cast) isn't in the snapshot: it was made on
	-- the preview's lane, and every recast restarts it on that lane. It goes to the lane its entry is back on; it
	-- used to stay on the preview's lane (hidden past that lane's Max Time) while Filters named its own, until a /reload.
	for _, cd in ipairs(CDTL3.cooldowns) do
		if snap.cooldowns[cd] == nil then
			local e = private.EntryOf(cd.data)
			MoveCooldown(cd, e and tonumber(e["lane"]))
		end
	end
	CDTL3:RefreshConfig()
end

-- At login: a setup that was previewed and neither kept nor undone before the reload is undone here.
-- Runs right after the profile is loaded, so it only writes values; the frames are built from them.
function S.ResolveStale()
	local saved = CDTL3.db and Profile().global["setupUndo"]
	if type(saved) ~= "table" then
		return false
	end
	local snap = { lanes = saved.lanes, defaults = saved.defaults, thresholds = saved.thresholds, setupKey = saved.setupKey or "",
		entries = {} }
	local ok = pcall(function()
		for _, e in ipairs(saved.entries or {}) do
			local list = Profile().tables[e.t]
			local entry = type(list) == "table" and list[e.k]
			if type(entry) == "table" then
				snap.entries[entry] = e.lane
			end
		end
		private.RestoreValues(snap)
	end)
	private.ClearPersisted()
	if ok then
		S.undoneStale = true
		C_Timer.After(6, function()
			CDTL3:Print(L["A setup you were trying was not kept, so your old lanes are back."])
		end)
	end
	return ok
end

function private.Apply(setup)
	local p = Profile()
	for n = 1, 3 do
		local lane, want = p.lanes["lane" .. n], setup.lanes[n]
		lane.enabled = want.on
		if want.max then
			for _, k in ipairs(private.MODE_TABLES) do
				lane.mode[k].max = want.max
			end
			-- Split (Time) marks that fit the new Max Time (a 3:00 lane used to keep a 10m mark)
			local sa, marks = lane.mode.splitAbs, S.MarksFor(want.max)
			sa.count = 3
			sa.s1v, sa.s2v, sa.s3v = marks[1], marks[2], marks[3]
			sa.s1p, sa.s2p, sa.s3p = private.MARK_POS[1], private.MARK_POS[2], private.MARK_POS[3]
		end
		if want.size then
			lane.icons.size = want.size
		end
		if want.gauge and lane.gauge then
			lane.gauge.enabled = true
		end
	end
	for _, t in ipairs(private.TYPES) do
		if p.global[t]["defaultLane"] ~= 0 then	-- a type set to Hide stays hidden
			p.global[t]["defaultLane"] = S.LaneFor(setup, t, math.huge)
		end
	end
	if setup.buffThreshold then
		p.global.buffs["ignoreThreshold"] = setup.buffThreshold
	end
	p.global["setupKey"] = setup.key

	for _, item in ipairs(MyLists()) do
		if item.entry["lane"] ~= 0 then	-- an entry set to Hide stays hidden
			item.entry["lane"] = S.LaneFor(setup, item.type, (tonumber(item.entry["bCD"]) or 0) / 1000) or item.entry["lane"]
		end
	end
	for _, cd in ipairs(CDTL3.cooldowns) do
		local d = cd.data
		if d["type"] ~= "testing" and d["lane"] ~= 0 then
			MoveCooldown(cd, S.LaneFor(setup, d["type"], d["baseCD"]))
		end
	end
	CDTL3:RefreshConfig()
end

-- SAMPLE ICONS
-- Each lane of a setup gets its own samples, timed as fractions of its Max Time (the Healer look:
-- two on the 30 s lane, three on the 5:00 one at 48 s, 1:20 and 2:40). They start again each time
-- they reach Ready (sampleLoop, Cooldown.lua) until Keep or Undo; the Test Panel's own settings
-- (number, times, Loop) are neither used nor changed.
private.SAMPLES = {
	long = { 0.16, 4 / 15, 8 / 15 },	-- 48, 80 and 160 s on a 5:00 lane
	short = { 0.1, 0.2 },	-- 3 and 6 s on a 30 s lane
	buffs = { 0.25, 0.5 },	-- 15 and 30 s on a 1:00 lane
}

-- what a lane of a setup holds: its big cooldowns, its short ones or its buffs (nil: none of them)
function private.LaneRole(setup, n)
	if n == setup.long then
		return "long"
	elseif n == setup.short then
		return "short"
	elseif n == setup.buffs then
		return "buffs"
	end
	return nil
end

-- every sample icon off the frames (all = the player's own Test Panel ones too); a sample loses its loop
function private.ClearSamples(all)
	for _, cd in ipairs(CDTL3.cooldowns) do
		local d = cd.data
		if d["type"] == "testing" and (all or d["sampleLoop"]) then
			d["sampleLoop"] = nil
			if cd.icon:GetParent():GetName() ~= "CDTL3_Active_Icon_Holding" then
				CDTL3:SendToHolding(cd)
			end
			if cd.bar:GetParent():GetName() ~= "CDTL3_Bar_Holding" then
				CDTL3:SendToBarHolding(cd)
			end
		end
	end
end

-- a fresh set of samples fitted to the setup's lanes, each on its lane
function private.MakeSamples(setup)
	local list = {}
	for n = 1, 3 do
		local want = setup.lanes[n]
		local role = want.on and want.max and private.LaneRole(setup, n)
		local fractions = role and private.SAMPLES[role]
		if fractions then
			for _, fraction in ipairs(fractions) do
				local data = CDTL3:GetTestTableData(role == "buffs" and "buffs" or "spells", math.floor(want.max * fraction + 0.5), #list + 1)
				data["lane"] = n
				data["sampleLoop"] = true
				list[#list + 1] = data
			end
		end
	end
	return CDTL3:MakeTestCooldowns(list)
end

-- the lane labels and the Previewing banner (what the player sees while a setup is tried)
function private.BuildBanner()
	if private.banner then
		return private.banner
	end

	local f = CreateFrame("Frame", "CDTL3_Setup_Banner", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(560, 34)
	f:SetPoint("TOP", 0, -110)
	f:SetFrameStrata("DIALOG")
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(true)
	f.bg:SetColorTexture(0.05, 0.05, 0.055, 0.96)
	f.bd = CreateFrame("Frame", "CDTL3_Setup_Banner_BD", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	CDTL3:SetBorder(f.bd, { style = "CDTL3 Pixel", color = { r = 0.79, g = 0.65, b = 0.27, a = 1 }, size = 1, padding = 0, inset = 0 })
	f.bd:SetFrameLevel(f:GetFrameLevel() + 1)

	f.text = f:CreateFontString(nil, "ARTWORK")
	f.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.text:SetPoint("LEFT", 8, 0)

	f.chips = {}
	local x = 130
	for _, setup in ipairs(S.setups) do
		local b = CreateFrame("Button", "CDTL3_Setup_Chip_" .. setup.key, f, "UIPanelButtonTemplate")
		b:SetSize(58, 22)
		b:SetText(setup.name)
		b:SetPoint("LEFT", x, 0)
		b:SetScript("OnClick", function()
			S.PreviewSetup(setup.key)
		end)
		f.chips[setup.key] = b
		x = x + 60
	end

	f.keep = CreateFrame("Button", "CDTL3_Setup_Keep", f, "UIPanelButtonTemplate")
	f.keep:SetSize(60, 22)
	f.keep:SetText(L["Keep"])
	f.keep:SetPoint("RIGHT", -70, 0)
	f.keep:SetScript("OnClick", function() S.KeepSetup() end)
	f.undo = CreateFrame("Button", "CDTL3_Setup_Undo", f, "UIPanelButtonTemplate")
	f.undo:SetSize(60, 22)
	f.undo:SetText(L["Undo"])
	f.undo:SetPoint("RIGHT", -6, 0)
	f.undo:SetScript("OnClick", function() S.UndoSetup() end)

	f:Hide()
	private.banner = f
	private.labels = {}
	for n = 1, 3 do
		local lf = CreateFrame("Frame", "CDTL3_Setup_Label_" .. n, UIParent)
		lf:SetSize(400, 14)
		lf:SetFrameStrata("DIALOG")
		lf.text = lf:CreateFontString(nil, "ARTWORK")
		lf.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
		lf.text:SetTextColor(1, 0.82, 0)
		lf.text:SetPoint("LEFT", 0, 0)
		lf:Hide()
		private.labels[n] = lf
	end
	return f
end

function private.ShowBanner(setup)
	local f = private.BuildBanner()
	f.text:SetText(string.format(L["Previewing: %s"], Gold(setup.name)))
	for key, chip in pairs(f.chips) do
		chip:SetEnabled(key ~= setup.key)
	end
	f:Show()

	for n = 1, 3 do
		local lf, want, lane = private.labels[n], setup.lanes[n], _G["CDTL3_Lane_" .. n]
		if want.on and want.label and lane then
			lf.text:SetText(string.format(L["Lane %d, %s"], n, want.label))
			lf:ClearAllPoints()
			lf:SetPoint("BOTTOMLEFT", lane, "TOPLEFT", 0, 6)
			lf:Show()
		else
			lf:Hide()
		end
	end
end

function private.HideBanner()
	if private.banner then
		private.banner:Hide()
		for n = 1, 3 do
			private.labels[n]:Hide()
		end
	end
end

-- Show a setup on the real frames with sample icons. Choosing another one starts again from the
-- player's own lanes, with a fresh set of samples for its lanes (sample mode on or not).
function S.PreviewSetup(key)
	local setup = S.GetSetup(key)
	if not setup then
		return false
	end

	if S.pending and S.pending.profile ~= Profile() then
		S.UndoSetup()	-- a preview from another profile is undone there first
	end
	if S.pending then
		private.Restore(S.pending.snapshot, S.pending.profile)
	else
		S.pending = { snapshot = private.Snapshot(), startedPreview = not CDTL3.testing, profile = Profile() }
		private.Persist(S.pending.snapshot, S.pending.profile)
	end
	S.pending.key = key

	private.Apply(setup)
	if not CDTL3.testing then
		CDTL3:EnableTesting()	-- sample mode, ended again by Keep or Undo
		S.pending.startedPreview = true
	end
	private.ClearSamples(true)
	private.MakeSamples(setup)
	CDTL3:ApplyCombatVisibility()
	private.ShowBanner(setup)
	return true
end

function S.KeepSetup()
	local pending = S.pending
	if not pending then
		return false
	end
	S.pending = nil
	private.ClearPersisted(pending.profile)
	private.HideBanner()
	private.ClearSamples()
	if pending.startedPreview and CDTL3.testing then
		CDTL3:StopPreview()
	end
	local setup = S.GetSetup(pending.key)
	CDTL3:Print(string.format(L["Kept the %s setup."], setup and setup.name or pending.key))
	return true
end

function S.UndoSetup()
	local pending = S.pending
	if not pending then
		return false
	end
	S.pending = nil
	private.ClearPersisted(pending.profile)
	private.HideBanner()
	private.Restore(pending.snapshot, pending.profile)
	private.ClearSamples()
	if pending.startedPreview and CDTL3.testing then
		CDTL3:StopPreview()
	end
	CDTL3:Print(L["Put your old lanes back."])
	return true
end

-- A preview belongs to the profile it started in: when the profile is about to change (Profiles tab,
-- spec swap, zone profile) it is undone there first, then the switch goes on. AceDB fires this
-- before it moves, while the old profile is still the active one.
function S.OnProfileShutdown()
	if S.pending then
		S.UndoSetup()
	end
end

----------------------------------------------------------------------------------------------------
-- FIRST-RUN TOUR (card 10)
-- A first install (no saved variables at all) gets three steps on the real frames, with sample
-- icons running: Lane, Bars, Ready. The last step offers Preview, Lock in place and Open settings.
-- Players who already have CDTL3 keep the welcome window (what's new) as before.
----------------------------------------------------------------------------------------------------
do
	local original = CDTL3.OnInitialize
	function CDTL3:OnInitialize(...)
		local fresh = (CDTL3DB == nil and CDTL2DB == nil)
		local result = original(self, ...)
		if fresh and CDTL3.db and CDTL3.db.global then
			CDTL3.db.global.tourPending = true
		end
		pcall(S.ResolveStale)	-- a setup tried before the reload and never kept is undone
		if CDTL3.db then
			CDTL3.db.RegisterCallback(S, "OnProfileShutdown", function() S.OnProfileShutdown() end)
		end
		return result
	end
end

function S:TourDue()
	return (CDTL3.db and CDTL3.db.global and CDTL3.db.global.tourPending) and true or false
end

function private.TourSteps()
	local steps = {}
	local function add(frame, title, text)
		if frame then
			steps[#steps + 1] = { frame = frame, title = title, text = text }
		end
	end
	add(_G["CDTL3_Lane_1"], L["Lane"], L["Cooldowns slide left. When one reaches Ready it's back, and you hear a click."])
	add(_G["CDTL3_BarFrame_1"], L["Bars"], L["The same cooldowns as countdown bars: each bar drains until its cooldown is back."])
	add(_G["CDTL3_Ready_1"], L["Ready"], L["An icon pops up here the moment a cooldown is back. Drag any frame where you like, then lock it so it can't move in a fight."])
	if #steps == 0 then
		steps[1] = { frame = UIParent, title = L["Lane"], text = L["Cooldowns slide left. When one reaches Ready it's back, and you hear a click."] }
	end
	return steps
end

local function MakeButton(parent, name, width, text, onClick)
	local b = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

function private.BuildTour()
	if private.tour then
		return private.tour
	end

	local f = CreateFrame("Frame", "CDTL3_Tour", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(330, 124)
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(true)
	f.bg:SetColorTexture(0.05, 0.05, 0.055, 0.96)
	f.bd = CreateFrame("Frame", "CDTL3_Tour_BD", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	CDTL3:SetBorder(f.bd, { style = "CDTL3 Pixel", color = { r = 0.79, g = 0.65, b = 0.27, a = 1 }, size = 1, padding = 0, inset = 0 })
	f.bd:SetFrameLevel(f:GetFrameLevel() + 1)

	local font = CDTL3.LSM:Fetch("font", "Fira Sans Condensed")
	f.head = f:CreateFontString(nil, "ARTWORK")
	f.head:SetFont(font, 12)
	f.head:SetTextColor(1, 0.82, 0)
	f.head:SetPoint("TOPLEFT", 12, -10)
	f.body = f:CreateFontString(nil, "ARTWORK")
	f.body:SetFont(font, 12)
	f.body:SetWidth(306)
	f.body:SetJustifyH("LEFT")
	f.body:SetPoint("TOPLEFT", 12, -28)

	f.dots = {}
	for i = 1, 3 do
		local dot = f:CreateTexture(nil, "ARTWORK")
		dot:SetSize(8, 8)
		dot:SetPoint("BOTTOMLEFT", 12 + (i - 1) * 13, 14)
		f.dots[i] = dot
	end

	f.close = MakeButton(f, "CDTL3_Tour_Skip", 22, "x", function() S:EndTour() end)
	f.close:SetPoint("TOPRIGHT", -4, -4)
	f.next = MakeButton(f, "CDTL3_Tour_Next", 70, L["Next"], function() S:TourStep(private.tourStep + 1) end)
	f.next:SetPoint("BOTTOMRIGHT", -10, 8)
	f.preview = MakeButton(f, "CDTL3_Tour_Preview", 92, L["Stop preview"], function()
		CDTL3:TogglePreview()
		S:TourRefreshButtons()
	end)
	f.preview:SetPoint("BOTTOMLEFT", 12, 8)
	f.lock = MakeButton(f, "CDTL3_Tour_Lock", 92, L["Lock in place"], function()
		if Profile().global["unlockFrames"] then
			CDTL3:ToggleFrameLock()
		end
		S:EndTour()
	end)
	f.lock:SetPoint("LEFT", f.preview, "RIGHT", 6, 0)
	f.settings = MakeButton(f, "CDTL3_Tour_Settings", 96, L["Open settings"], function()
		S:EndTour()
		CDTL3:ChatCommand("")
	end)
	f.settings:SetPoint("LEFT", f.lock, "RIGHT", 6, 0)

	f.badges = {}
	for i = 1, 3 do
		local b = CreateFrame("Frame", "CDTL3_Tour_Badge_" .. i, UIParent)
		b:SetSize(18, 18)
		b:SetFrameStrata("DIALOG")
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints(true)
		b.bg:SetColorTexture(1, 0.82, 0, 1)
		b.text = b:CreateFontString(nil, "ARTWORK")
		b.text:SetFont(font, 11)
		b.text:SetTextColor(0.07, 0.07, 0.07)
		b.text:SetPoint("CENTER", 0, 0)
		b.text:SetText(tostring(i))
		b:Hide()
		f.badges[i] = b
	end

	f:Hide()
	private.tour = f
	return f
end

function S:TourRefreshButtons()
	local f = private.tour
	if f then
		f.preview:SetText(CDTL3.testing and L["Stop preview"] or L["Preview"])
	end
end

function S:TourStep(i)
	local f = private.BuildTour()
	local steps = private.tourSteps
	if i > #steps then
		return self:EndTour()
	end
	private.tourStep = i
	local step = steps[i]

	f.head:SetText(string.format(L["%d of %d, %s"], i, #steps, step.title))
	f.body:SetText(step.text)
	f:ClearAllPoints()
	f:SetPoint("BOTTOM", step.frame, "TOP", 0, 18)
	for n, dot in ipairs(f.dots) do
		dot:SetShown(n <= #steps)
		if n == i then
			dot:SetColorTexture(1, 0.82, 0, 1)
		else
			dot:SetColorTexture(0.45, 0.45, 0.45, 1)
		end
	end

	local last = (i == #steps)
	f.next:SetShown(not last)
	f.preview:SetShown(last)
	f.lock:SetShown(last)
	f.settings:SetShown(last)
	self:TourRefreshButtons()

	for n, badge in ipairs(f.badges) do
		local s = steps[n]
		if s and s.frame ~= UIParent then
			badge:ClearAllPoints()
			badge:SetPoint("CENTER", s.frame, "TOPRIGHT", 0, 0)
			badge:Show()
		else
			badge:Hide()
		end
	end
	f:Show()
end

-- force: start it on demand (the welcome window's Take the tour), not only on a first install
function S:StartTour(force)
	if private.tourStep or not (force or self:TourDue()) then
		return false
	end
	if force and CDTL3.db and CDTL3.db.global then
		CDTL3.db.global.tourPending = true	-- EndTour clears it, as after a first install's tour
	end
	private.tourStarted = not CDTL3.testing
	if not CDTL3.testing then
		CDTL3:StartPreview()
	end
	private.tourSteps = private.TourSteps()
	self:TourStep(1)
	return true
end

-- every way out (Lock in place, Open settings, the x) ends it for good
function S:EndTour()
	local f = private.tour
	if f then
		f:Hide()
		for _, badge in ipairs(f.badges) do
			badge:Hide()
		end
	end
	private.tourStep = nil
	if CDTL3.db and CDTL3.db.global then
		CDTL3.db.global.tourPending = nil
	end
	Profile().global["firstRun"] = false
	Profile().global["previousVersion"] = CDTL3.version
	if private.tourStarted and CDTL3.testing then
		CDTL3:StopPreview()
	end
	private.tourStarted = nil
end

----------------------------------------------------------------------------------------------------
-- LOOK CARDS (card 43)
----------------------------------------------------------------------------------------------------
private.lookTarget = "all"
private.MAX_CARDS = 4 + 12

-- Built-in styles this client has, then the player's own looks: { name, spec, builtin }
function private.CardList()
	local list = {}
	local have = CDTL3:GetPresetList()
	for _, preset in ipairs(CDTL3.presets) do
		if have[preset.key] then
			list[#list + 1] = { name = preset.name, spec = preset, builtin = true, key = preset.key }
		end
	end
	for _, look in ipairs(CDTL3:GetLooks()) do
		list[#list + 1] = { name = look.name, spec = look }
	end
	return list
end

-- a small drawing of a look: its lane stripe, and a bar over its background colour (inline textures
-- tinted with the look's colours)
function private.Swatch(spec)
	local function byte(v)
		return math.max(0, math.min(255, math.floor((v or 0) * 255 + 0.5)))
	end
	local function strip(w, h, c)
		return string.format("|TInterface\\Buttons\\WHITE8X8:%d:%d:0:0:8:8:0:8:0:8:%d:%d:%d|t", h, w, byte(c.r), byte(c.g), byte(c.b))
	end

	local fill = { r = 0.78, g = 0.12, b = 0.28 }
	if spec.classColor then
		local class = CDTL3.player and CDTL3.player["class"]
		local c = class and Profile().global["classColors"] and Profile().global["classColors"][class]
		if c then
			fill = c
		end
	end
	local back = spec.bgColor or { r = 0.15, g = 0.15, b = 0.15 }
	return strip(150, 12, fill) .. "\n" .. strip(96, 9, fill) .. strip(54, 9, back)
end

function private.TargetValues()
	local values = { all = L["Everything"] }
	for n = 1, 3 do
		values["lanes:" .. n] = L["Lane"] .. " " .. n
	end
	for n = 1, 3 do
		values["barFrames:" .. n] = L["Bar Frame"] .. " " .. n
	end
	for n = 1, 3 do
		values["ready:" .. n] = L["Ready Frame"] .. " " .. n
	end
	return values
end

function private.TargetLabel(target)
	return private.TargetValues()[target] or L["Everything"]
end

function private.ApplyCard(card)
	local target = private.lookTarget
	if card.builtin then
		CDTL3:ApplyPreset(card.key, target ~= "all" and target or nil)
		return
	end
	CDTL3:ApplyStyle(card.spec, target)
	CDTL3:RefreshConfig()
	if target == "all" then
		CDTL3:Print(string.format(L["Applied the %s style."], card.name))
	else
		CDTL3:Print(string.format(L["Applied the %s style to %s."], card.name, private.TargetLabel(target)))
	end
end

function private.NotifyOptions()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("CDTL3")
end

function S.SaveCurrentLook(name)
	local look, why = CDTL3:SaveLook(name)
	if look then
		CDTL3:Print(string.format(L["Saved the look %s."], look.name))
	else
		CDTL3:Print(why)
	end
	private.NotifyOptions()
	return look
end

function S.ImportLook(text)
	local look, why = CDTL3:ReadLookString(text)
	if look then
		local clash
		for _, p in ipairs(CDTL3.presets) do
			if p.name == look.name then
				clash = true
			end
		end
		if clash then
			look.name = look.name .. " 2"
		end
		local stored, why2 = CDTL3:StoreLook(look)
		if stored then
			CDTL3:Print(string.format(L["Imported the look %s."], stored.name))
		else
			CDTL3:Print(why2)
		end
		look = stored
	else
		CDTL3:Print(why)
	end
	private.NotifyOptions()
	return look
end

function private.BuildCards(args)
	args["lookTarget"] = {
		name = L["Apply to"],
		desc = L["Apply a look to everything, or to one lane, bar frame or ready frame"],
		order = 120,
		type = "select",
		values = function() return private.TargetValues() end,
		get = function() return private.lookTarget end,
		set = function(info, val) private.lookTarget = val end,
	}

	for i = 1, private.MAX_CARDS do
		local function card()
			return private.CardList()[i]
		end
		args["card" .. i] = {
			name = function()
					local c = card()
					return c and c.name or ""
				end,
			type = "group",
			inline = true,
			order = 200 + i,
			hidden = function() return card() == nil end,
			args = {
				preview = {
					name = function()
							local c = card()
							return c and private.Swatch(c.spec) or ""
						end,
					type = "description",
					order = 1,
				},
				kind = {
					name = function()
							local c = card()
							return c and (c.builtin and L["Built in"] or L["Yours"]) or ""
						end,
					type = "description",
					order = 2,
				},
				apply = {
					name = L["Apply"],
					desc = L["Apply this look to the frames chosen under Apply to"],
					order = 3,
					type = "execute",
					width = 0.7,
					confirm = function()
							if private.lookTarget == "all" then
								return L["Apply this style to every lane, bar frame and ready frame? Your current textures, colours, borders and fonts will be replaced (export your profile first if you want to keep them)."]
							end
							return false
						end,
					func = function()
							local c = card()
							if c then
								private.ApplyCard(c)
							end
						end,
				},
				share = {
					name = L["Share"],
					desc = L["Show this look as a string to copy and send to someone else"],
					order = 4,
					type = "execute",
					width = 0.7,
					hidden = function()
							local c = card()
							return not c or c.builtin
						end,
					func = function()
							local c = card()
							if c then
								private.shareName = c.name
								private.shareText = CDTL3:ExportString("LOOK", nil, c.spec)
							end
						end,
				},
				delete = {
					name = L["Delete"],
					order = 5,
					type = "execute",
					width = 0.7,
					confirm = true,
					hidden = function()
							local c = card()
							return not c or c.builtin
						end,
					func = function()
							local c = card()
							if c then
								CDTL3:DeleteLook(c.name)
								if private.shareName == c.name then
									private.shareName, private.shareText = nil, nil
								end
							end
						end,
				},
			},
		}
	end

	args["saveCard"] = {
		name = L["Save current look"],
		type = "group",
		inline = true,
		order = 230,
		args = {
			saveName = {
				name = L["Save current look as"],
				desc = L["Type a name and press Enter: the textures, colours, borders and fonts of lane 1, bar frame 1 and its icons are kept under it"],
				order = 1,
				type = "input",
				get = function() return "" end,
				set = function(info, val) S.SaveCurrentLook(val) end,
			},
		},
	}
	args["shareBox"] = {
		name = function()
				return string.format(L["Share %s (select all of it and copy it with Ctrl+C)"], private.shareName or "")
			end,
		order = 231,
		type = "input",
		multiline = 3,
		width = "full",
		hidden = function() return not private.shareText end,
		get = function() return private.shareText end,
		set = function() return nil end,
	}
	args["importLook"] = {
		name = L["Import a look (paste a string)"],
		desc = L["A string from Share adds that look to your own"],
		order = 232,
		type = "input",
		multiline = 3,
		width = "full",
		get = function() return "" end,
		set = function(info, val) S.ImportLook(val) end,
	}
end

----------------------------------------------------------------------------------------------------
-- THE SETTINGS TREE
----------------------------------------------------------------------------------------------------
function private.SimpleTab()
	local p = function() return Profile() end
	local function typeToggle(key, label, desc, order)
		return {
			name = label, desc = desc, order = order, type = "toggle",
			get = function() return p().global[key]["enabled"] end,
			set = function(info, val)
					p().global[key]["enabled"] = val
					for _, cd in pairs(CDTL3.cooldowns) do
						if cd.data["type"] == key then
							cd.data["enabled"] = val
						end
					end
				end,
		}
	end

	return {
		name = L["Simple"],
		type = "group",
		order = 50,
		args = {
			intro = {
				name = L["The settings most people change. Everything else is in the other tabs."] .. "\n",
				type = "description", fontSize = "medium", order = 1,
			},
			showHeader = { name = L["What to show"], type = "header", order = 10 },
			spells = typeToggle("spells", L["Spells"], L["Track your spell cooldowns"], 11),
			items = typeToggle("items", L["Items"], L["Track item cooldowns (trinkets, potions, Healthstones)"], 12),
			buffs = typeToggle("buffs", L["Buffs"], L["Track your buffs"], 13),
			debuffs = typeToggle("debuffs", L["Debuffs"], L["Track debuffs on you"], 14),
			sizeHeader = { name = L["Size"], type = "header", order = 20 },
			width = {
				name = L["Timeline width"],
				desc = L["How wide lane 1 is"],
				order = 21, type = "range", min = 1, max = 1000, bigStep = 1,
				get = function() return p().lanes.lane1["width"] end,
				set = function(info, val)
						p().lanes.lane1["width"] = val
						CDTL3:RefreshLane(1)
					end,
			},
			iconSize = {
				name = L["Icon size"],
				desc = L["How big the icons on lane 1 are"],
				order = 22, type = "range", softMin = 1, softMax = 128, bigStep = 1,
				get = function() return p().lanes.lane1["icons"]["size"] end,
				set = function(info, val)
						p().lanes.lane1["icons"]["size"] = val
						CDTL3:RefreshAllIcons()
					end,
			},
			soundHeader = { name = L["Sound and position"], type = "header", order = 30 },
			readySound = {
				name = L["Ready sound"],
				desc = L["The sound that plays when a cooldown is back"],
				order = 31, type = "select", width = "double", dialogControl = "LSM30_Sound",
				values = AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.sound or {},
				get = function() return p().ready.ready1["nSound"] end,
				set = function(info, val)
					p().ready.ready1["nSound"] = val
					CDTL3:PlayPicked(val)
				end,
			},
			readySoundTest = {
				name = L["Play sound"],
				order = 32, type = "execute", width = "normal",
				func = function()
						local name = p().ready.ready1["nSound"]
						if name and name ~= "None" then
							PlaySoundFile(CDTL3.LSM:Fetch("sound", name), "SFX")
						end
					end,
			},
			lockFrames = {
				name = function()
						return p().global["unlockFrames"] and L["Lock frames"] or L["Unlock frames"]
					end,
				desc = L["Frames can be dragged while they are unlocked"],
				order = 33, type = "execute", width = 1,
				func = function()
						CDTL3:ToggleFrameLock()
						private.NotifyOptions()
					end,
			},
			lockNote = {
				name = L["or move them in Edit Mode (not on Classic Era)"],
				type = "description", order = 34, width = "double",
			},
		},
	}
end

-- Help tab: every /cdtl3 command from the list /cdtl3 help prints, each with a Run button
function private.HelpTab()
	local args = {}
	for i, line in ipairs(CDTL3.helpLines or {}) do
		local command, text = line[1], line[2]
		args["row" .. i] = {
			name = function() return Gold("/cdtl3 " .. command) .. ": " .. text end,
			type = "description", fontSize = "medium", order = i * 2, width = 2.4,
		}
		args["run" .. i] = {
			name = L["Run"],
			type = "execute", order = i * 2 + 1, width = 0.5,
			hidden = function() return command == "" or command == "help" end,
			func = function()
					local run = command
					if run == "lock / unlock" then
						run = Profile().global["unlockFrames"] and "lock" or "unlock"
					end
					run = run:gsub("%s*%[.*$", "")
					CDTL3:ChatCommand(run)
				end,
		}
	end
	args["collaborator"] = {
		name = "\n" .. L["Works with the addon CooldownCollaborator: its group cooldowns show on Lane 1. To change the lane, pick Group cooldowns under Filters › Defaults."],
		type = "description", fontSize = "medium", order = (#(CDTL3.helpLines or {}) + 1) * 2 + 2,
	}
	return { name = L["Help"], type = "group", order = 2007, args = args }
end

function private.SetupArgs(args)
	args["setupHeader"] = { name = L["Setup"], type = "header", order = 10 }
	args["setupIntro"] = {
		name = L["Pick a role to see its lanes on your real frames with sample icons. Keep saves it, Undo puts your old lanes back. Your Filters entries move to the lane for their length; frame positions stay."],
		type = "description", fontSize = "medium", order = 11,
	}
	for i, setup in ipairs(S.setups) do
		args["setup" .. setup.key] = {
			name = setup.name,
			desc = setup.blurb,
			order = 11 + i, type = "execute", width = 0.8,
			func = function() S.PreviewSetup(setup.key) end,
		}
	end
	args["styleHeader"] = { name = L["Style"], type = "header", order = 100 }
end

function private.Extend(options)
	options.args.simple = private.SimpleTab()
	options.args.help = private.HelpTab()
	if CDTL3.AddMediaNotes then
		CDTL3.AddMediaNotes(options.args.simple)
	end

	local style = options.args.style
	if style then
		-- the Style list and Apply Style button stay; the look cards sit below them
		private.SetupArgs(style.args)
		private.BuildCards(style.args)
	end

	local g = options.args.global
	if g then
		g.args.estimateTilde = {
			name = L["Mark estimated times with ~"],
			desc = L["Puts a ~ in front of a time CDTL3 counts itself (an estimate), on icons and bars, and says so in the icon's tooltip. Times that follow the game's own timer stay plain. Retail and Forever, in combat."],
			order = 352, type = "toggle", width = "full",
			hidden = function() return not CDTL3.retailAPI end,
			get = function() return Profile().global["estimateTilde"] and true or false end,
			set = function(info, val)
					Profile().global["estimateTilde"] = val and true or false
					CDTL3:RefreshAllIcons()
				end,
		}
	end

	local lanes = options.args.lanes
	if lanes then
		for n = 1, 3 do
			local lane = lanes.args["lane" .. n]
			if lane and lane.args.general then
				lane.args.general.args.estimateLegend = {
					name = "\n" .. L["A ~ before a time means CDTL3's estimate; plain numbers follow the game's own timer. Switch it on under Global › Mark estimated times with ~."],
					type = "description", order = 890,
					hidden = function() return not CDTL3.retailAPI end,
				}
			end
		end
	end
end

do
	local original = CDTL3.GetFullOptions
	function CDTL3:GetFullOptions(...)
		local options = original(self, ...)
		private.Extend(options)
		return options
	end
end
