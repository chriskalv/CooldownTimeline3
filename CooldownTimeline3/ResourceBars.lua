--[[
	Resource bars on a lane (feature panel cards 17 and 31). Both are off until switched on, and both
	hang off the lane's own frame, so a lane that isn't using them looks and runs as before.

	Mana gauge (card 17, "Gauge at the Ready end"): a short upright gauge just past the lane's Ready end,
	where the mana cooldowns come back, with the mana percent under it. The fill is a StatusBar fed the
	player's mana, which a StatusBar takes even while the value is hidden (Retail and WoW: Forever, in
	combat). The percent is read inside a pcall and is only shown where it can be read.

	Change color at (card 31, "Whole bar changes colour"): with Primary Tracking on Class Power, the whole
	fill takes another color while the resource is at or above a number. While the value is hidden (Retail
	and WoW: Forever, in combat) it can't be compared, so the fill keeps its normal color there.
	Hidden values are only ever handed to widgets or compared inside a pcall.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")

local RB = {}
CDTL3.ResourceBars = RB
local private = {}

private.MANA = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
private.TICK = 0.1	-- seconds between gauge reads
private.GAUGE_FONT = "Fira Sans Condensed"

---------------------------------------------------------------- mana gauge
-- one number -> percent, or -1 when there is no mana pool. Errors (hidden values) are for the caller's pcall.
private.Percent = function(current, max)
	if max <= 0 then
		return -1
	end
	return math.floor(current * 100 / max + 0.5)
end

-- inside a pcall (GaugeTick): the widgets take the hidden values, the text only a readable one
private.GaugeRead = function(g)
	local current = UnitPower("player", private.MANA)
	local max = UnitPowerMax("player", private.MANA)
	g:SetMinMaxValues(0, max)
	g:SetValue(current)

	local ok, got = pcall(private.Percent, current, max)
	local pct ---@type number?
	if ok then
		pct = got	-- hidden (not ok): the bar fills, the percent stays blank
	end

	-- A class with no mana shows nothing (the alpha, not Hide: the ticks keep running). Whether there is
	-- a mana pool is learned whenever the numbers are readable and kept while they are hidden; until
	-- then the class decides (these four never have mana).
	if pct ~= nil then
		private.hasMana = (pct ~= -1)
	elseif private.hasMana == nil then
		local _, class = UnitClass("player")
		if class == "WARRIOR" or class == "ROGUE" or class == "DEATHKNIGHT" or class == "DEMONHUNTER" then
			private.hasMana = false
		end
	end
	local alpha = (private.hasMana == false) and 0 or 1
	if g.cdtl3Alpha ~= alpha then
		g.cdtl3Alpha = alpha
		g:SetAlpha(alpha)
	end

	if g.pct then
		if pct and pct >= 0 then
			if g.lastPct ~= pct then
				g.lastPct = pct
				g.pct:SetText(string.format("%d%%", pct))
			end
		elseif g.lastPct ~= nil then
			g.lastPct = nil
			g.pct:SetText("")
		end
	end
end

private.GaugeTick = function(g, elapsed)
	g.acc = g.acc + elapsed
	if g.acc < private.TICK then
		return
	end
	g.acc = 0

	local ok, err = pcall(private.GaugeRead, g)
	if not ok then
		CDTL3:LogFailure("ResourceBars.GaugeRead", err)
	end
end

private.FontPath = function()
	return CDTL3.LSM:Fetch("font", private.GAUGE_FONT) or STANDARD_TEXT_FONT
end

-- where the gauge sits: at the lane's Ready end. A horizontal lane's Ready end is its left (right when
-- reversed); a vertical lane's is its bottom (top when reversed). The percent goes on the far side of the
-- gauge from the lane.
private.PlaceGauge = function(g, f, s, gs)
	local gap = tonumber(gs["gap"]) or 6
	g:ClearAllPoints()
	g.pct:ClearAllPoints()

	if s["vertical"] then
		if s["reversed"] then
			g:SetPoint("BOTTOM", f, "TOP", 0, gap)
			g.pct:SetPoint("BOTTOM", g, "TOP", 0, 4)
		else
			g:SetPoint("TOP", f, "BOTTOM", 0, -gap)
			g.pct:SetPoint("TOP", g, "BOTTOM", 0, -4)
		end
	elseif s["reversed"] then
		g:SetPoint("TOPLEFT", f, "TOPRIGHT", gap, 0)
		g.pct:SetPoint("TOP", g, "BOTTOM", 0, -4)
	else
		g:SetPoint("TOPRIGHT", f, "TOPLEFT", -gap, 0)
		g.pct:SetPoint("TOP", g, "BOTTOM", 0, -4)
	end
end

private.RefreshGauge = function(f, s)
	local gs = s["gauge"]
	local g = f.cdtl3Gauge

	if not (gs and gs["enabled"]) then
		if g then
			g:Hide()
		end
		return
	end

	if not g then
		g = CreateFrame("StatusBar", f:GetName() .. "_Gauge", f)
		g.acc = 0
		g.bg = g:CreateTexture(nil, "BACKGROUND")
		g.pct = g:CreateFontString(nil, "OVERLAY")
		g:SetOrientation("VERTICAL")
		g:SetMinMaxValues(0, 1)
		g:SetValue(0)
		g:EnableMouse(false)
		g:SetScript("OnUpdate", private.GaugeTick)
		f.cdtl3Gauge = g
	end

	g:SetSize(tonumber(gs["width"]) or 16, tonumber(gs["height"]) or 44)
	CDTL3:SetBarTexture(g, "CDTL3 Smooth")
	local c = gs["color"] or { r = 0.165, g = 0.373, b = 0.839, a = 1 }
	g:SetStatusBarColor(c["r"], c["g"], c["b"], c["a"] or 1)
	-- SetAllPoints(true) anchors to the parent; the definitions only list a region
	---@diagnostic disable-next-line: param-type-mismatch
	g.bg:SetAllPoints(true)
	g.bg:SetColorTexture(0.15, 0.15, 0.15, 0.5)
	g.pct:SetFont(private.FontPath(), 11, "OUTLINE")
	g.pct:SetTextColor(1, 1, 1, 1)
	g.pct:SetShown(gs["showPercent"] and true or false)
	private.PlaceGauge(g, f, s, gs)

	g.lastPct = nil
	g.pct:SetText("")
	g.cdtl3Alpha = nil
	g.acc = private.TICK	-- read at the next frame
	g:Show()
end

---------------------------------------------------------------- color threshold
private.AtLeast = function(current, value)
	return current >= value
end

-- Stagger's number is a percent of max health (for pcall: the values can be hidden)
private.StaggerAtLeast = function(stagger, max, pct)
	if stagger == nil then	-- no value at all (this runs in a pcall, so a hidden one just fails here)
		stagger = 0
	end
	return stagger * 100 >= pct * max
end

-- Primary Tracking choices the colour change works on
private.Thresholded = function(kind)
	return kind == "CLASS_POWER" or kind == "STAGGER"
end

private.SetHot = function(f, th, hot)
	if hot then
		local c = th["color"]
		f:SetStatusBarColor(c["r"], c["g"], c["b"], c["a"] or 1)
		f.cdtl3Hot = true
	else
		local b = f.cdtl3Base
		f:SetStatusBarColor(b[1], b[2], b[3], b[4])
		f.cdtl3Hot = nil
	end
end

-- every frame from the lane's OnUpdate, but only every third one does anything
private.ThresholdTick = function(f)
	local tr = f.cdtl3Trk
	if not tr or not f.cdtl3Base then
		return
	end

	local th = tr["threshold"]
	if not (th and th["enabled"] and private.Thresholded(tr["primaryTracking"])) then
		if f.cdtl3Hot then
			private.SetHot(f, th or private.noThreshold, false)
		end
		return
	end

	f.cdtl3ThN = (f.cdtl3ThN or 0) + 1
	if f.cdtl3ThN % 3 ~= 0 then
		return
	end

	-- the value is compared in a pcall: while it is hidden that fails, and the fill keeps its normal color
	local hot = nil
	if tr["primaryTracking"] == "STAGGER" then
		if UnitStagger then
			local ok, over = pcall(private.StaggerAtLeast, UnitStagger("player"), UnitHealthMax("player"), tonumber(th["value"]) or 0)
			if ok and over == true then
				hot = true
			end
		end
	else
		local pType = CDTL3.player["classPower"]
		if pType then
			local ok, over = pcall(private.AtLeast, UnitPower("player", pType), tonumber(th["value"]) or 0)
			if ok and over == true then
				hot = true
			end
		end
	end

	if hot ~= f.cdtl3Hot then
		private.SetHot(f, th, hot)
	end
end
private.noThreshold = {}

private.RefreshThreshold = function(f, s)
	local tr = s["tracking"]
	f.cdtl3Trk = tr
	f.cdtl3Hot = nil
	f.cdtl3ThN = 0

	-- the normal fill color RefreshLane just set (class color, lane color), to go back to
	local b = f.cdtl3Base
	if not b then
		b = {}
		f.cdtl3Base = b
	end
	b[1], b[2], b[3], b[4] = f:GetStatusBarColor()
	b[1], b[2], b[3], b[4] = b[1] or 1, b[2] or 1, b[3] or 1, b[4] or 1

	if not f.cdtl3ThHooked then
		f.cdtl3ThHooked = true
		f:HookScript("OnUpdate", private.ThresholdTick)
	end
end

---------------------------------------------------------------- lane refresh
function RB.Refresh(i)
	local f = _G["CDTL3_Lane_" .. i]
	local s = CDTL3.db and CDTL3.db.profile.lanes["lane" .. i]
	if not f or not s then
		return
	end

	private.RefreshThreshold(f, s)
	private.RefreshGauge(f, s)
end

local refreshLane = CDTL3.RefreshLane
-- deliberate wrapper: chains to the handler that was there before
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:RefreshLane(i)
	refreshLane(self, i)
	RB.Refresh(i)
end

---------------------------------------------------------------- options
-- Lanes > Lane N > General, below the tracking controls (orders 619 to 659)
function CDTL3:AddResourceBarArgs(args, i, lane)
	local function refresh()
		CDTL3:RefreshLane(i)
	end
	local function notClassPower()
		return not private.Thresholded(lane["tracking"]["primaryTracking"])
	end
	local function noThreshold()
		return notClassPower() or not lane["tracking"]["threshold"]["enabled"]
	end
	local function noGauge()
		return not lane["gauge"]["enabled"]
	end

	args["spacer619"] = { name = "\n", type = "description", order = 619 }
	args["thresholdEnabled"] = {
		name = L["Change color at"],
		desc = L["With Primary Tracking on Class Power or Stagger, the whole bar takes another color while your resource is at or above the number below. On Retail and WoW: Forever the number is hidden in combat and can't be compared, so the bar keeps its normal color there."],
		order = 620,
		type = "toggle",
		get = function(info) return lane["tracking"]["threshold"]["enabled"] end,
		set = function(info, val)
				lane["tracking"]["threshold"]["enabled"] = val
				refresh()
			end,
	}
	args["thresholdValue"] = {
		name = L["At or above"],
		desc = L["The resource number the bar changes color at, such as 40 rage. For Stagger it is a percent of your max health."],
		order = 621,
		type = "input",
		width = "half",
		disabled = noThreshold,
		validate = function(info, val)
				local n = tonumber(val)
				if n and n >= 0 then
					return true
				end
				return L["Enter a number, such as 40"]
			end,
		get = function(info) return tostring(lane["tracking"]["threshold"]["value"]) end,
		set = function(info, val)
				lane["tracking"]["threshold"]["value"] = tonumber(val)
			end,
	}
	args["thresholdColor"] = {
		name = L["Changed color"],
		desc = L["The color of the whole bar while the resource is at or above the number"],
		order = 622,
		type = "color",
		hasAlpha = true,
		disabled = noThreshold,
		get = function(info)
				local c = lane["tracking"]["threshold"]["color"]
				return c["r"], c["g"], c["b"], c["a"]
			end,
		set = function(info, r, g, b, a)
				lane["tracking"]["threshold"]["color"] = { r = r, g = g, b = b, a = a }
			end,
	}

	args["spacer640"] = { name = "\n", type = "description", order = 640 }
	args["gaugeEnabled"] = {
		name = L["Mana gauge"],
		desc = L["A short upright mana gauge just past this lane's Ready end, where the mana cooldowns come back, with the mana percent under it"],
		order = 641,
		type = "toggle",
		get = function(info) return lane["gauge"]["enabled"] end,
		set = function(info, val)
				lane["gauge"]["enabled"] = val
				refresh()
			end,
	}
	args["gaugePercent"] = {
		name = L["Show percent"],
		desc = L["Shows the mana percent under the gauge. On Retail and WoW: Forever mana is hidden in combat: the gauge still fills, and the percent comes back when it can be read."],
		order = 642,
		type = "toggle",
		disabled = noGauge,
		get = function(info) return lane["gauge"]["showPercent"] end,
		set = function(info, val)
				lane["gauge"]["showPercent"] = val
				refresh()
			end,
	}
	args["gaugeColor"] = {
		name = L["Gauge color"],
		desc = L["The color of the mana gauge"],
		order = 643,
		type = "color",
		hasAlpha = true,
		disabled = noGauge,
		get = function(info)
				local c = lane["gauge"]["color"]
				return c["r"], c["g"], c["b"], c["a"]
			end,
		set = function(info, r, g, b, a)
				lane["gauge"]["color"] = { r = r, g = g, b = b, a = a }
				refresh()
			end,
	}
	args["gaugeWidth"] = {
		name = L["Gauge width"],
		desc = L["How wide the mana gauge is"],
		order = 644,
		type = "range",
		min = 4, max = 200, step = 1, bigStep = 1,
		disabled = noGauge,
		get = function(info) return lane["gauge"]["width"] end,
		set = function(info, val)
				lane["gauge"]["width"] = val
				refresh()
			end,
	}
	args["gaugeHeight"] = {
		name = L["Gauge height"],
		desc = L["How tall the mana gauge is"],
		order = 645,
		type = "range",
		min = 8, max = 400, step = 1, bigStep = 1,
		disabled = noGauge,
		get = function(info) return lane["gauge"]["height"] end,
		set = function(info, val)
				lane["gauge"]["height"] = val
				refresh()
			end,
	}
	args["gaugeGap"] = {
		name = L["Gauge distance"],
		desc = L["The space between the lane and the mana gauge"],
		order = 646,
		type = "range",
		min = 0, max = 200, step = 1, bigStep = 1,
		disabled = noGauge,
		get = function(info) return lane["gauge"]["gap"] end,
		set = function(info, val)
				lane["gauge"]["gap"] = val
				refresh()
			end,
	}
end
