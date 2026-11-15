--[[
	Fight timeline (feature panel card 27, "Fight timeline"): a strip from the pull to a set time (6:00),
	a moving now line, flags at 2:00, 3:00 and 5:00, and one row for each pinned cooldown: a bar from the
	moment it was used to the moment it is back, with its icon and that fight time at the end. It shows
	where each pinned cooldown will be at each flag, past the lane's Max Time. Off until switched on
	(Fight Timeline tab). Out of combat the now line sits at the pull, so it forecasts "if I pulled now".

	Classic clients read the cooldown the addon already keeps for each icon (exact). On Retail and WoW:
	Forever the cooldown is hidden in combat: a cooldown that rides the game's own timer (CombatTimers.lua)
	is placed from the cast time plus its base cooldown, and every end time there reads "~" (an estimate).
	Nothing here is ever positioned from a hidden value.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")

local FT = {}
CDTL3.FightTimeline = FT
local private = {}

private.MAXROWS = 8
private.PAD = 20		-- the strip's side margin
private.ROW_H = 28
private.TICK = 0.1
private.LIST_EVERY = 0.5
private.FONT = "Fira Sans Condensed"
private.COLORS = {
	{ 0.933, 0.482, 0.173 }, { 0.722, 0.471, 0.878 }, { 0.890, 0.678, 0.267 },
	{ 0.337, 0.780, 0.918 }, { 0.600, 0.850, 0.400 }, { 0.900, 0.450, 0.550 },
	{ 0.800, 0.800, 0.800 }, { 0.950, 0.650, 0.350 },
}

private.inCombat = false
private.started = 0
private.list = {}
private.listCount = 0

-- the saved settings
private.S = function()
	return CDTL3.db and CDTL3.db.profile.global["fightTimeline"]
end

-- m:ss
private.Clock = function(t)
	t = math.floor(t + 0.5)
	if t < 0 then
		t = 0
	end
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

private.FontPath = function()
	return CDTL3.LSM:Fetch("font", private.FONT) or STANDARD_TEXT_FONT
end

---------------------------------------------------------------- pieces
private.Text = function(f, size, r, g, b)
	local fs = f:CreateFontString(nil, "OVERLAY")
	fs:SetFont(private.FontPath(), size, "OUTLINE")
	fs:SetTextColor(r, g, b, 1)
	return fs
end

-- place only when it changed: the strip updates ten times a second
private.PutAt = function(obj, point, f, x, y)
	if obj.px ~= x or obj.py ~= y or obj.pp ~= point then
		obj.px, obj.py, obj.pp = x, y, point
		obj:ClearAllPoints()
		obj:SetPoint(point, f, "TOPLEFT", x, y)
	end
end

private.SizeTo = function(obj, w, h)
	if obj.sw ~= w or obj.sh ~= h then
		obj.sw, obj.sh = w, h
		obj:SetSize(w, h)
	end
end

private.SetLabel = function(fs, text)
	if fs.cdtl3Text ~= text then
		fs.cdtl3Text = text
		fs:SetText(text)
	end
end

private.Build = function()
	local f = CreateFrame("Frame", "CDTL3_FightTimeline", UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	f.acc = 0
	f.listAcc = 0

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetAllPoints(true)
	f.bg:SetColorTexture(0.15, 0.15, 0.15, 0.62)

	f.past = f:CreateTexture(nil, "BORDER")
	f.past:SetColorTexture(0, 0, 0, 0.34)

	f.flags = {}
	f.flagText = {}
	for k = 1, 3 do
		local line = f:CreateTexture(nil, "ARTWORK")
		line:SetColorTexture(1, 0.82, 0, 0.75)
		f.flags[k] = line
		f.flagText[k] = private.Text(f, 11, 1, 0.82, 0)
	end

	f.nowLine = f:CreateTexture(nil, "OVERLAY")
	f.nowLine:SetColorTexture(1, 1, 1, 1)
	f.nowText = private.Text(f, 11, 1, 1, 1)
	f.axisL = private.Text(f, 10, 0.6, 0.63, 0.65)
	f.axisR = private.Text(f, 10, 0.6, 0.63, 0.65)
	f.empty = private.Text(f, 11, 0.8, 0.8, 0.8)

	f.rows = {}
	for k = 1, private.MAXROWS do
		local c = private.COLORS[k]
		local row = {}
		row.was = f:CreateTexture(nil, "ARTWORK")
		row.was:SetColorTexture(c[1], c[2], c[3], 0.35)
		row.seg = f:CreateTexture(nil, "ARTWORK")
		row.seg:SetColorTexture(c[1], c[2], c[3], 1)
		row.ic = f:CreateTexture(nil, "OVERLAY")
		row.ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		row.lbl = private.Text(f, 10.5, 1, 1, 1)
		f.rows[k] = row
	end

	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self)
		if CDTL3.db.profile.global["unlockFrames"] then
			self:StartMoving()
		end
	end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local s = private.S()
		local point, _, _, x, y = self:GetPoint()
		if s and point then
			s["point"], s["x"], s["y"] = point, x, y
		end
	end)
	f:SetScript("OnUpdate", function(self, elapsed)
		private.Tick(self, elapsed)
	end)
	return f
end

---------------------------------------------------------------- what to show
-- The pinned entries: saved in Filters, this character's, showing, of a kind that has a cooldown. Into
-- out (the entry) and kinds (its type), in list order; readyFrame nil takes every Ready frame's.
-- A cooldown's frame only exists once it has been used, so these are the saved entries, and the live
-- cooldown is looked up by name. Shared with ReadyBoard.lua. Returns how many.
private.PINNED_KINDS = { "spells", "petspells", "items" }
function CDTL3:CollectPinned(out, kinds, readyFrame, max)
	local n = 0
	local tables = CDTL3.db.profile.tables
	for _, kind in ipairs(private.PINNED_KINDS) do
		local entries = tables[kind]
		if entries then
			for _, e in pairs(entries) do
				if n < max and e["pinned"] and e["enabled"] and (not readyFrame or e["readyFrame"] == readyFrame)
						and CDTL3:IsMyEntry(e) and not CDTL3:IsIgnored(e, kind) then
					n = n + 1
					out[n] = e
					kinds[n] = kind
				end
			end
		end
	end
	for k = n + 1, #out do
		out[k] = nil
		kinds[k] = nil
	end
	return n
end

-- the pinned cooldowns (rebuilt twice a second into the same tables)
private.kinds = {}
private.Collect = function()
	private.listCount = CDTL3:CollectPinned(private.list, private.kinds, nil, private.MAXROWS)
end

-- seconds left and whether that is an estimate. A cooldown riding the game's own timer is never read:
-- its time is the cast plus its base cooldown. One that hasn't been used yet (no frame), or isn't on a
-- lane or bar frame (parked in holding), isn't counted down, so it reads ready.
private.Remaining = function(cd)
	if not cd then
		return 0, false
	end
	local d = cd.data
	local ct = cd.ct
	if ct and ct.riding then
		local base = d["baseCD"] or 0
		local cast = CDTL3.spellCastTimes and CDTL3.spellCastTimes[d["id"]]
		if cast and base > 0 then
			return math.max(cast + base - GetTime(), 0), true
		end
		return base, true
	end

	if not (cd.icon:IsVisible() or cd.bar:IsVisible()) then
		return 0, false
	end

	local left = d["currentCD"]
	if left > 0 then
		return left, (CDTL3.retailAPI and private.inCombat) and true or false
	end
	return 0, false
end

---------------------------------------------------------------- the strip
private.Update = function(f, s)
	local W = tonumber(s["width"]) or 340
	local span = math.max(tonumber(s["span"]) or 360, 1)
	local PAD = private.PAD
	local inner = math.max(W - 2 * PAD, 1)
	local n = private.listCount
	local strip = 8 + private.ROW_H * math.max(n, 1)
	local H = 46 + private.ROW_H * math.max(n, 1)

	private.SizeTo(f, W, H)

	local now = private.inCombat and (GetTime() - private.started) or 0
	local xNow = PAD + math.min(math.max(now / span, 0), 1) * inner

	-- the time already fought
	if xNow > PAD then
		private.PutAt(f.past, "TOPLEFT", f, PAD, -18)
		private.SizeTo(f.past, xNow - PAD, strip)
		f.past:Show()
	else
		f.past:Hide()
	end

	-- flags
	for k = 1, 3 do
		local at = tonumber(s["flag" .. k]) or 0
		local line, text = f.flags[k], f.flagText[k]
		if at > 0 and at <= span then
			local x = PAD + (at / span) * inner
			private.PutAt(line, "TOPLEFT", f, x, -18)
			private.SizeTo(line, 1, strip)
			private.PutAt(text, "TOP", f, x, -4)
			private.SetLabel(text, private.Clock(at))
			line:Show()
			text:Show()
		else
			line:Hide()
			text:Hide()
		end
	end

	-- now
	private.PutAt(f.nowLine, "TOPLEFT", f, xNow - 1, -14)
	private.SizeTo(f.nowLine, 2, strip + 4)
	private.PutAt(f.nowText, "TOP", f, xNow, -4)
	private.SetLabel(f.nowText, string.format(L["now %s"], private.Clock(now)))

	-- the ends of the strip
	private.PutAt(f.axisL, "TOPLEFT", f, PAD, -(18 + strip + 4))
	private.SetLabel(f.axisL, L["pull"])
	private.PutAt(f.axisR, "TOPRIGHT", f, W - PAD,-(18 + strip + 4))
	private.SetLabel(f.axisR, private.Clock(span))

	if n == 0 then
		private.PutAt(f.empty, "TOPLEFT", f, PAD, -34)
		private.SetLabel(f.empty, L["Pin cooldowns in Filters to see them here"])
		f.empty:Show()
	else
		f.empty:Hide()
	end

	local size = tonumber(s["iconSize"]) or 22
	for k = 1, private.MAXROWS do
		local row = f.rows[k]
		local e = private.list[k]
		if not e or k > n then
			row.was:Hide()
			row.seg:Hide()
			row.ic:Hide()
			row.lbl:Hide()
			row.e, row.cd = nil, nil
		else
			if row.e ~= e then
				row.e, row.cd, row.kind = e, nil, private.kinds[k]
				row.ic:SetTexture((row.kind == "items" and e["itemIcon"]) or e["icon"])
			end
			if not row.cd then
				row.cd = CDTL3:GetExistingCooldown(e["name"], row.kind)
			end
			local cd = row.cd

			local left, estimate = private.Remaining(cd)
			local base = (cd and cd.data["baseCD"]) or 0
			local used = (left > 0 and base > left) and (base - left) or 0
			local tStart = math.max(now - used, 0)
			local tEnd = now + left
			local yc = 8 + private.ROW_H * k

			local x0 = PAD + math.min(tStart / span, 1) * inner
			local x1 = PAD + math.min(tEnd / span, 1) * inner

			if left > 0 then
				if xNow > x0 then
					private.PutAt(row.was, "TOPLEFT", f, x0, -(yc - 3))
					private.SizeTo(row.was, xNow - x0, 6)
					row.was:Show()
				else
					row.was:Hide()
				end
				private.PutAt(row.seg, "TOPLEFT", f, xNow, -(yc - 3))
				private.SizeTo(row.seg, math.max(x1 - xNow, 1), 6)
				row.seg:Show()
			else
				row.was:Hide()
				row.seg:Hide()
			end

			private.SizeTo(row.ic, size, size)
			private.PutAt(row.ic, "TOPLEFT", f, x1 - size / 2, -(yc - size / 2))
			row.ic:Show()

			local text
			if left > 0 then
				text = private.Clock(tEnd)
				if estimate then
					text = "~" .. text
				end
			else
				text = L["ready"]
			end
			-- left of the icon when it is too close to the right edge for the text
			row.lbl:ClearAllPoints()
			if x1 > W - 60 then
				row.lbl:SetPoint("RIGHT", f, "TOPLEFT", x1 - size / 2 - 3, -yc)
			else
				row.lbl:SetPoint("LEFT", f, "TOPLEFT", x1 + size / 2 + 3, -yc)
			end
			private.SetLabel(row.lbl, text)
			row.lbl:Show()
		end
	end
end

private.Tick = function(f, elapsed)
	f.acc = f.acc + elapsed
	if f.acc < private.TICK then
		return
	end
	f.acc = 0

	local s = private.S()
	if not s then
		return
	end

	f.listAcc = f.listAcc + private.TICK
	if f.listAcc >= private.LIST_EVERY or f.listFirst == nil then
		f.listAcc = 0
		f.listFirst = true
		private.Collect()
	end

	local ok, err = pcall(private.Update, f, s)
	if not ok then
		CDTL3:LogFailure("FightTimeline.Update", err)
	end
end

---------------------------------------------------------------- showing and placing
function FT.Apply()
	local s = private.S()
	local f = CDTL3_FightTimeline
	if not s then
		return
	end
	if not f then
		if not s["enabled"] then
			return
		end
		f = private.Build()
	end

	local unlocked = CDTL3.db.profile.global["unlockFrames"]
	f:ClearAllPoints()
	f:SetPoint(s["point"] or "CENTER", UIParent, s["point"] or "CENTER", s["x"] or 0, s["y"] or -150)
	f:EnableMouse(unlocked and true or false)

	local show = s["enabled"] and (unlocked or not s["hideOutOfCombat"] or private.inCombat)
	if show then
		f.listFirst = nil
		f.acc = private.TICK
		f:Show()
	else
		f:Hide()
	end
end

private.events = CreateFrame("Frame")
private.events:RegisterEvent("PLAYER_REGEN_DISABLED")
private.events:RegisterEvent("PLAYER_REGEN_ENABLED")
private.events:RegisterEvent("PLAYER_ENTERING_WORLD")
private.events:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_REGEN_DISABLED" then
		private.inCombat = true
		private.started = GetTime()
	elseif event == "PLAYER_REGEN_ENABLED" then
		private.inCombat = false
	else
		local was = private.inCombat
		private.inCombat = UnitAffectingCombat("player") and true or false
		if private.inCombat and not was then
			private.started = GetTime()
		end
	end
	FT.Apply()
end)

hooksecurefunc(CDTL3, "CreateLanes", function() FT.Apply() end)
hooksecurefunc(CDTL3, "RefreshConfig", function() FT.Apply() end)
hooksecurefunc(CDTL3, "ToggleFrameLock", function() FT.Apply() end)

---------------------------------------------------------------- options
-- the Fight Timeline tab (CDTL3:GetFullOptions)
function CDTL3:GetFightTimelineOptions()
	local function s()
		return CDTL3.db.profile.global["fightTimeline"]
	end
	local function off()
		return not s()["enabled"]
	end
	local function flag(key, order, name)
		return {
			name = name,
			desc = L["Seconds into the fight this flag stands at (0 for no flag, up to 3600)"],
			order = order,
			type = "range",
			min = 0, max = 3600, step = 1, bigStep = 10,
			disabled = off,
			get = function(info) return s()[key] end,
			set = function(info, val)
					s()[key] = val
				end,
		}
	end

	return {
		name = L["Fight Timeline"],
		type = "group",
		args = {
			about = {
				name = L["A strip from the pull to a set time, with a moving line for now and flags at the times you pick. Each pinned cooldown is a bar that ends where it is back, so you can see which ones are ready for the 3:00 burst, past a lane's Max Time. Pin cooldowns in Filters. On Retail and WoW: Forever the cooldowns are hidden in combat, so their end times there are estimates from your cast and read with a ~."],
				type = "description",
				order = 1,
				fontSize = "medium",
			},
			enabled = {
				name = L["Enabled"],
				order = 2,
				type = "toggle",
				get = function(info) return s()["enabled"] end,
				set = function(info, val)
						s()["enabled"] = val
						FT.Apply()
					end,
			},
			hideOutOfCombat = {
				name = L["Hide out of combat"],
				desc = L["Shows the timeline only in combat (while frames are unlocked it always shows)"],
				order = 3,
				type = "toggle",
				disabled = off,
				get = function(info) return s()["hideOutOfCombat"] end,
				set = function(info, val)
						s()["hideOutOfCombat"] = val
						FT.Apply()
					end,
			},
			spacer10 = { name = "", type = "description", order = 10 },
			width = {
				name = L["Width"],
				order = 11,
				type = "range",
				min = 160, max = 1200, step = 1, bigStep = 10,
				disabled = off,
				get = function(info) return s()["width"] end,
				set = function(info, val) s()["width"] = val end,
			},
			span = {
				name = L["Length"],
				desc = L["Seconds from the pull to the end of the strip (up to 3600)"],
				order = 12,
				type = "range",
				min = 30, max = 3600, step = 1, bigStep = 10,
				disabled = off,
				get = function(info) return s()["span"] end,
				set = function(info, val) s()["span"] = val end,
			},
			iconSize = {
				name = L["Icon size"],
				order = 13,
				type = "range",
				min = 10, max = 60, step = 1, bigStep = 1,
				disabled = off,
				get = function(info) return s()["iconSize"] end,
				set = function(info, val) s()["iconSize"] = val end,
			},
			spacer20 = { name = "", type = "description", order = 20 },
			flag1 = flag("flag1", 21, L["Flag 1"]),
			flag2 = flag("flag2", 22, L["Flag 2"]),
			flag3 = flag("flag3", 23, L["Flag 3"]),
			spacer30 = { name = "", type = "description", order = 30 },
			reset = {
				name = L["Reset position"],
				desc = L["Puts the timeline back at its starting place. Unlock frames to drag it."],
				order = 31,
				type = "execute",
				disabled = off,
				func = function(info)
						local t = s()
						t["point"], t["x"], t["y"] = "CENTER", 0, -150
						FT.Apply()
					end,
			},
		},
	}
end
