--[[
	Cooldown Timeline 3 - icon and lane extras (feature panel of 12 Nov 2026, cards 2, 5, 22, 23, 25, 26)

	Every part is off until its setting is turned on, so existing setups look the same:
	  - Charge pips (lane): a pip per charge along a spell icon's bottom edge, the next one filling.
	  - Lane flash (buff, Filters): the lane flashes green when the buff lands, red at its Ready end
	    when it drops, leaving a struck-out ghost of the buff for 2 s; each with its own sound.
	  - Burst window (lane): Ready to "in N s" shaded and tagged on a Time lane (the default look),
	    and/or a Ready-by list of the pinned cooldowns under the lane.
	  - Refresh zone (lane): the last part of a Linear (%) lane, for DoTs (Era, TBC and MoP only).
	  - Ready-soon warning (Filters): the icon pulses an orange border in its last N seconds.
	  - GCD waits (lane): an icon whose only wait is the GCD sits in its Ready frame under a sweep.

	Hidden (secret) values are never compared or used in maths: the charge count only goes into
	StatusBars, the Ready-by list's timers in combat into a duration text binding (CombatTimers.lua).
	Everything that reads the game runs in a pcall. The hot paths (LaneIcon, LaneUpdate, ReadyFrame)
	make no tables or closures.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")

local FX = {}
CDTL3.IconFx = FX

local private = {}

private.FILL = [[Interface\Buttons\WHITE8X8]]
private.STRIPES = [[Interface\AddOns\CooldownTimeline3\Media\zone-stripes.tga]]	-- tools/make-stripes.py
private.LANE_KEYS = { "lane1", "lane2", "lane3" }
private.READY_FRAMES = { CDTL3_Ready_1_MF = true, CDTL3_Ready_2_MF = true, CDTL3_Ready_3_MF = true }
private.GCD_REF = 8921			-- the spell Lanes.lua reads the GCD from (any spell without a cooldown)
private.GCD_MAX = 3				-- a wait longer than this is not a GCD
private.PIP_MAX = 6
private.LIST_ROWS = 8
private.FLASH = 1.5				-- seconds a lane flash takes to fade
private.GHOST = 2				-- seconds a dropped buff's ghost stays
private.QUIET = 8				-- no buff alerts this long after logging in or zoning (a reload isn't a gain)
private.worldAt = -1000

-- the keys copied from a saved entry onto its live cooldown
private.ENTRY_KEYS = { "warnSecs", "warnSound", "alertGain", "alertEnd", "gainSound", "endSound" }

-- the saved lane settings of lane n (nil for 0 = Hide, or anything else)
private.LaneSettings = function(n)
	local key = private.LANE_KEYS[n]
	return key and CDTL3.db and CDTL3.db.profile.lanes[key] or nil
end

private.PlaySound = function(name)
	if name and name ~= "None" then
		local path = CDTL3.LSM:Fetch("sound", name)
		if path then
			PlaySoundFile(path, "SFX")
		end
	end
end

private.SetFont = function(fs, size, flags)
	local path = CDTL3.LSM:Fetch("font", "Fira Sans Condensed")
	if path then
		fs:SetFont(path, size, flags)
	end
end

-- four bars round a frame, outside its edge (a border, or a glow when thick and faint)
private.Ring = function(frame, thick, r, g, b, a, layer)
	local ring = {}
	for i = 1, 4 do
		local t = frame:CreateTexture(nil, layer or "OVERLAY")
		t:SetColorTexture(r, g, b, a)
		ring[i] = t
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

private.RingShow = function(ring, shown)
	for i = 1, 4 do
		if shown then
			ring[i]:Show()
		else
			ring[i]:Hide()
		end
	end
end

-- the saved entry's settings on a live cooldown (CreateCooldown)
function FX:CopyEntry(d, e)
	for i = 1, #private.ENTRY_KEYS do
		local k = private.ENTRY_KEYS[i]
		if e[k] ~= nil then
			d[k] = e[k]
		end
	end
end

---------------------------------------------------------------- charge pips
-- A StatusBar per pip: pip i spans i-1 to i and is fed the charge count, so the count is only ever
-- handed to a widget (it can be hidden in combat on Retail and Forever). The recharge fill of the
-- next pip needs the count compared, so it is drawn only where the count can be read.
private.Fetch = function(id)
	if CDTL3.retailAPI then
		local info = C_Spell.GetSpellCharges(id)
		if not info then
			return nil
		end
		return info["currentCharges"], info["maxCharges"], info["cooldownStartTime"], info["cooldownDuration"]
	end
	return GetSpellCharges(id)
end

private.Pips = function(ic)
	local pf = ic.fxPips
	if pf then
		return pf
	end
	pf = CreateFrame("Frame", nil, ic)
	pf:SetFrameLevel(ic:GetFrameLevel() + 5)
	pf:EnableMouse(false)
	pf:SetPoint("BOTTOMLEFT", ic, "BOTTOMLEFT", 4, 3)
	pf:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", -4, 3)
	pf:SetHeight(5)
	pf.pip = {}
	pf.n = 0
	for i = 1, private.PIP_MAX do
		local p = CreateFrame("Frame", nil, pf)
		p.bg = p:CreateTexture(nil, "BACKGROUND")
		p.bg:SetAllPoints(p)
		p.bg:SetColorTexture(0, 0, 0, 0.65)
		p.part = CreateFrame("StatusBar", nil, p)
		p.part:SetAllPoints(p)
		p.part:SetStatusBarTexture(private.FILL)
		p.part:SetStatusBarColor(1, 0.82, 0.29, 0.5)
		p.part:SetMinMaxValues(0, 1)
		p.part:SetValue(0)
		p.lit = CreateFrame("StatusBar", nil, p)
		p.lit:SetAllPoints(p)
		p.lit:SetStatusBarTexture(private.FILL)
		p.lit:SetStatusBarColor(1, 0.82, 0.29, 1)
		p.lit:SetMinMaxValues(i - 1, i)
		p.lit:SetValue(0)
		p:Hide()
		pf.pip[i] = p
	end
	ic.fxPips = pf
	return pf
end

private.LayoutPips = function(pf, n, width)
	if pf.n == n and pf.width == width then
		return
	end
	pf.n, pf.width = n, width
	local gap = 2
	local w = (width - 8 - gap * (n - 1)) / n
	for i = 1, private.PIP_MAX do
		local p = pf.pip[i]
		if i <= n then
			p:ClearAllPoints()
			p:SetSize(w, 5)
			p:SetPoint("LEFT", pf, "LEFT", (i - 1) * (w + gap), 0)
			p:Show()
		else
			p:Hide()
		end
	end
end

-- for pcall; the values left for FillPart (all of them may be hidden)
private.cc, private.pipStart, private.pipDur, private.pipN = nil, nil, nil, 0
private.ReadMax = function(max)
	return max + 0	-- throws while the number is hidden
end

-- which combat we are in, so a failure is logged once per icon per combat (counted when PipsTick sees the change)
private.combatId, private.wasCombat = 0, false

private.ApplyPips = function(ic, id)
	local cc, max, start, dur = private.Fetch(id)
	if not max then
		return false
	end
	-- the number of pips: the max when it can be read, else the last readable one (kept per icon)
	local readable, n = pcall(private.ReadMax, max)
	if readable then
		ic.fxMaxRead = n
	else
		n = ic.fxMaxRead
		if not n then
			error("max charges hidden and none seen before", 0)
		end
	end
	if n < 2 then
		return false
	end
	if n > private.PIP_MAX then
		n = private.PIP_MAX
	end
	local pf = private.Pips(ic)
	private.LayoutPips(pf, n, ic:GetWidth())
	for i = 1, n do
		pf.pip[i].lit:SetValue(cc)
	end
	private.cc, private.pipStart, private.pipDur, private.pipN = cc, start, dur, n
	return true
end

-- for pcall: the recharging pip fills; a hidden count or time throws and the fills are cleared
private.FillPart = function(pf)
	local n, cc = private.pipN, private.cc
	for i = 1, n do
		pf.pip[i].part:SetValue(0)
	end
	if cc < n then
		local frac = (GetTime() - private.pipStart) / private.pipDur
		if frac > 1 then
			frac = 1
		end
		pf.pip[cc + 1].part:SetValue(frac)
	end
end

private.ClearParts = function(pf)
	for i = 1, private.PIP_MAX do
		pf.pip[i].part:SetValue(0)
	end
end

-- with pips on, the icon's timer text (text 2) stands 4 px higher so the pips don't sit on it (fp02);
-- Cooldown.lua's RefreshIcon reads ic.fxNudge for the same 4 px
private.TIMER_NUDGE = 4
private.Nudge = function(ic, on, lane)
	on = on and true or false
	if (ic.fxNudge or false) == on then
		return
	end
	ic.fxNudge = on
	local s = lane and private.LaneSettings(lane)
	local ts = s and s["icons"] and s["icons"]["text2"]
	local t = ic.txt and ic.txt.text2
	if t and ts and ts["enabled"] then
		t:ClearAllPoints()
		t:SetPoint(ts["align"], ic, ts["anchor"], ts["offX"], ts["offY"] + (on and private.TIMER_NUDGE or 0))
	end
end

private.PipsOff = function(ic)
	if ic.fxPips then
		ic.fxPips:Hide()
	end
	if ic.fxPipsOn then
		private.Nudge(ic, false, ic.fxNudgeLane)
	end
	ic.fxPipsOn = nil
end

private.PipsTick = function(ic, d)
	if d["fxMax"] == false then
		return
	end
	local now = GetTime()
	if ic.fxPipAt and now - ic.fxPipAt < 0.1 then
		return
	end
	ic.fxPipAt = now

	local inCombat = InCombatLockdown() and true or false
	if inCombat ~= private.wasCombat then
		private.wasCombat = inCombat
		if inCombat then
			private.combatId = private.combatId + 1
		end
	end

	local ok, applied = pcall(private.ApplyPips, ic, d["id"])
	if not ok then
		if ic.fxFailCombat ~= private.combatId then	-- once per icon per combat, not every 0.1 s
			ic.fxFailCombat = private.combatId
			CDTL3:LogFailure("IconFx.Pips", applied)
		end
		private.PipsOff(ic)
		return
	end
	if not applied then
		d["fxMax"] = false	-- not a charge spell
		private.PipsOff(ic)
		return
	end
	d["fxMax"] = true
	if not ic.fxPipsOn then
		ic.fxPips:Show()
		ic.fxPipsOn = true
		ic.fxNudgeLane = d["lane"]
		private.Nudge(ic, true, d["lane"])
	end
	if not pcall(private.FillPart, ic.fxPips) then
		private.ClearParts(ic.fxPips)
	end
end

-- for pcall: the time left of the recharging charge, only while a charge is missing and the times can be read
private.RechargeLeft = function(id)
	local cc, max, start, dur = private.Fetch(id)
	if not max then
		return nil
	end
	if cc < max and dur > 0 then
		return start + dur - GetTime()
	end
	return nil
end

-- from the cooldown poll (Cooldown.lua): with pips on, a charge spell rides its recharge, so the icon
-- stays on the lane while a charge is missing and goes to Ready once they are all back
function FX:PollCharges(f)
	local d = f.data
	if d["setCustomCD"] or d["fxMax"] == false then
		return
	end
	local s = private.LaneSettings(d["lane"])
	if not (s and s["fx"] and s["fx"]["chargePips"]) then
		return
	end
	local ok, left = pcall(private.RechargeLeft, d["id"])
	if ok and left then
		d["currentCD"] = left
	end
end

---------------------------------------------------------------- ready-soon pulse
private.PulseFrame = function(ic)
	local p = ic.fxPulse
	if p then
		return p
	end
	p = CreateFrame("Frame", nil, ic)
	p:SetAllPoints(ic)
	p:SetFrameLevel(ic:GetFrameLevel() + 6)
	p:EnableMouse(false)
	p.glow = private.Ring(p, 5, 1, 0.6, 0, 0.35, "ARTWORK")
	p.ring = private.Ring(p, 2, 1, 0.6, 0, 1)
	p.ag = p:CreateAnimationGroup()
	p.ag:SetLooping("BOUNCE")
	p.ag:SetToFinalAlpha(true)
	local a = p.ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.45)
	a:SetDuration(0.5)
	a:SetOrder(1)
	-- the icon itself grows to about 1.07 at the pulse peak (fp25): a second group on the icon, same beat
	pcall(function()
		local sg = ic:CreateAnimationGroup()
		sg:SetLooping("BOUNCE")
		local sc = sg:CreateAnimation("Scale")
		if sc.SetScaleFrom then
			sc:SetScaleFrom(1, 1)
			sc:SetScaleTo(private.PULSE_SCALE, private.PULSE_SCALE)
		else
			sc:SetScale(private.PULSE_SCALE, private.PULSE_SCALE)
		end
		sc:SetOrigin("CENTER", 0, 0)
		sc:SetDuration(0.5)
		sc:SetOrder(1)
		p.sg = sg
	end)
	p:Hide()
	ic.fxPulse = p
	return p
end

private.PULSE_SCALE = 1.07

private.PulseOn = function(ic, d)
	local p = private.PulseFrame(ic)
	if not ic.fxPulseOn then
		ic.fxPulseOn = true
		p:Show()
		p.ag:Play()
		if p.sg then
			p.sg:Play()
		end
	end
	if not d["fxWarned"] then
		d["fxWarned"] = true
		private.PlaySound(d["warnSound"])
	end
end

private.PulseOff = function(ic)
	if ic.fxPulseOn then
		ic.fxPulseOn = nil
		ic.fxPulse.ag:Stop()
		if ic.fxPulse.sg then
			ic.fxPulse.sg:Stop()
		end
		ic.fxPulse:Hide()
	end
end

---------------------------------------------------------------- lane flash and ghost
private.FlashFrame = function(lane)
	local fl = lane.fxFlash
	if fl then
		return fl
	end
	fl = CreateFrame("Frame", nil, lane)
	fl:SetAllPoints(lane)
	fl:SetFrameLevel(lane:GetFrameLevel() + 3)
	fl:EnableMouse(false)
	fl.greenGlow = private.Ring(fl, 7, 0.37, 0.88, 0.48, 0.3, "ARTWORK")
	fl.greenRing = private.Ring(fl, 2, 0.37, 0.88, 0.48, 1)
	fl.redEnd = fl:CreateTexture(nil, "ARTWORK")
	fl.redEdge = fl:CreateTexture(nil, "OVERLAY")
	fl:Hide()
	lane.fxFlash = fl
	return fl
end

-- red, fading to nothing along 38% of the lane from its Ready end
private.PlaceRed = function(fl, lane, s)
	local vertical, reversed = s["vertical"], s["reversed"]
	local long = s["width"] * 0.38
	local re, edge = fl.redEnd, fl.redEdge
	re:ClearAllPoints()
	edge:ClearAllPoints()
	edge:SetColorTexture(1, 0.29, 0.24, 0.9)
	local lo, hi = CreateColor(1, 0.29, 0.24, 0.85), CreateColor(1, 0.29, 0.24, 0)
	local orientation, first, second
	if vertical then
		orientation = "VERTICAL"
		if reversed then
			re:SetPoint("TOPLEFT", fl, "TOPLEFT", 0, 0)
			re:SetPoint("TOPRIGHT", fl, "TOPRIGHT", 0, 0)
			edge:SetPoint("BOTTOMLEFT", fl, "TOPLEFT", 0, 0)
			edge:SetPoint("BOTTOMRIGHT", fl, "TOPRIGHT", 0, 0)
			first, second = hi, lo
		else
			re:SetPoint("BOTTOMLEFT", fl, "BOTTOMLEFT", 0, 0)
			re:SetPoint("BOTTOMRIGHT", fl, "BOTTOMRIGHT", 0, 0)
			edge:SetPoint("TOPLEFT", fl, "BOTTOMLEFT", 0, 0)
			edge:SetPoint("TOPRIGHT", fl, "BOTTOMRIGHT", 0, 0)
			first, second = lo, hi
		end
		re:SetHeight(long)
		edge:SetHeight(4)
	else
		orientation = "HORIZONTAL"
		if reversed then
			re:SetPoint("TOPRIGHT", fl, "TOPRIGHT", 0, 0)
			re:SetPoint("BOTTOMRIGHT", fl, "BOTTOMRIGHT", 0, 0)
			edge:SetPoint("TOPLEFT", fl, "TOPRIGHT", 0, 0)
			edge:SetPoint("BOTTOMLEFT", fl, "BOTTOMRIGHT", 0, 0)
			first, second = hi, lo
		else
			re:SetPoint("TOPLEFT", fl, "TOPLEFT", 0, 0)
			re:SetPoint("BOTTOMLEFT", fl, "BOTTOMLEFT", 0, 0)
			edge:SetPoint("TOPRIGHT", fl, "TOPLEFT", 0, 0)
			edge:SetPoint("BOTTOMRIGHT", fl, "BOTTOMLEFT", 0, 0)
			first, second = lo, hi
		end
		re:SetWidth(long)
		edge:SetWidth(4)
	end
	re:SetColorTexture(1, 0.29, 0.24, 0.5)	-- where a client has no gradient
	if re.SetGradientAlpha then
		pcall(re.SetGradientAlpha, re, orientation, 1, 0.29, 0.24, first == lo and 0.85 or 0, 1, 0.29, 0.24, first == lo and 0 or 0.85)
	elseif re.SetGradient then
		pcall(re.SetGradient, re, orientation, first, second)
	end
end

private.Ghost = function(lane)
	local g = lane.fxGhost
	if g then
		return g
	end
	g = CreateFrame("Frame", nil, lane)
	g:SetFrameLevel(21)
	g:EnableMouse(false)
	g.tex = g:CreateTexture(nil, "ARTWORK")
	g.tex:SetAllPoints(g)
	g.ring = private.Ring(g, 2, 1, 0.29, 0.24, 1)
	g.strike = g:CreateTexture(nil, "OVERLAY")
	g.strike:SetColorTexture(1, 0.29, 0.24, 1)
	g.strike:SetPoint("CENTER", g, "CENTER", 0, 0)
	if g.strike.SetRotation then
		g.strike:SetRotation(math.rad(45))
	end
	g:Hide()
	lane.fxGhost = g
	return g
end

-- the dropped buff, struck out at the lane's Ready end
private.PlaceGhost = function(lane, s, d)
	local g = private.Ghost(lane)
	local size = s["icons"]["size"]
	local zoom = CDTL3.db.profile.global["zoom"] or 1
	local tl, br = zoom - 1, 1 - (zoom - 1)
	g:SetSize(size, size)
	g:ClearAllPoints()
	if s["vertical"] then
		g:SetPoint(s["reversed"] and "TOP" or "BOTTOM", lane, s["reversed"] and "TOP" or "BOTTOM", s["iconOffset"] or 0, 0)
	else
		g:SetPoint(s["reversed"] and "RIGHT" or "LEFT", lane, s["reversed"] and "RIGHT" or "LEFT", 0, s["iconOffset"] or 0)
	end
	g.tex:SetTexture(d["icon"])
	g.tex:SetTexCoord(tl, br, tl, br)
	if g.tex.SetDesaturated then
		g.tex:SetDesaturated(true)
	end
	g.tex:SetVertexColor(0.8, 0.8, 0.8, 1)
	g.strike:SetSize(size * 1.414, 4)
	g:Show()
	lane.fxGhostUntil = GetTime() + private.GHOST
end

-- kind "gain": green round the lane; "end": red at its Ready end and the buff's ghost
private.Flash = function(lane, s, kind, d)
	local fl = private.FlashFrame(lane)
	local green = kind == "gain"
	private.RingShow(fl.greenGlow, green)
	private.RingShow(fl.greenRing, green)
	if green then
		fl.redEnd:Hide()
		fl.redEdge:Hide()
	else
		private.PlaceRed(fl, lane, s)
		fl.redEnd:Show()
		fl.redEdge:Show()
		private.PlaceGhost(lane, s, d)
	end
	fl:SetAlpha(1)
	fl:Show()
	lane.fxFlashUntil = GetTime() + private.FLASH
end

-- A buff that landed or dropped: its own sound, and the flash on its lane. On Retail and Forever,
-- while auras are hidden, only for a buff in the Cooldown Manager's Tracked Bars (its end is real);
-- an estimated buff would flash on a guess.
private.Alert = function(f, kind)
	local d = f.data
	if not (kind == "gain" and d["alertGain"] or kind == "end" and d["alertEnd"]) then
		return
	end
	if GetTime() - private.worldAt < private.QUIET then
		return
	end
	if CDTL3.retailAPI and CDTL3:AurasAreSecret() == true then
		local CT = CDTL3.CombatTimers
		if not (CT and CT:BuffInTrackedBars(d["name"]) == true) then
			return
		end
	end

	local lane = f.icon:GetParent()
	local s = lane and lane.number and private.LaneSettings(lane.number)
	if s then
		private.Flash(lane, s, kind, d)
	end
	if kind == "gain" then
		private.PlaySound(d["gainSound"] or "CDTL3 Click")
	else
		private.PlaySound(d["endSound"] or "CDTL3 Tinks")
	end
end

-- a cooldown (re)started on its lane (SendToLane): a fresh run for every one-run mark. A buff only
-- counts as landed once it survives its first poll (a cooldown made at login for a buff that isn't up
-- never was), see LaneIcon.
function FX:Started(f)
	local d, ic = f.data, f.icon
	d["fxMax"] = nil
	d["fxLive"] = nil
	if not CDTL3.movingLane then
		d["fxWarned"] = nil
		d["fxPending"] = (d["type"] == "buffs" and (d["alertGain"] or d["alertEnd"])) and true or nil
	end
	if ic.fxGCD then
		private.EndGCD(ic)
	end
	private.PulseOff(ic)
	private.PipsOff(ic)
end

-- the buff's time is up (IconUpdate, before Ready)
function FX:Ended(f)
	local d = f.data
	d["fxPending"] = nil
	if d["fxLive"] then
		d["fxLive"] = nil
		private.Alert(f, "end")
	end
end

---------------------------------------------------------------- GCD waits
-- for pcall: is the spell waiting on nothing but the global cooldown? Retail: the game says (isOnGCD is
-- never hidden). Classic: its cooldown is the very same one the GCD spell reports.
private.GCDOnlyRead = function(id)
	if CDTL3.retailAPI then
		local info = C_Spell.GetSpellCooldown(id)
		return (info and info["isActive"] == true and info["isOnGCD"] == true) and true or false
	end
	local start, dur = CDTL3:GetSpellCooldown(id)
	if not (start and dur and dur > 0) then
		return false
	end
	local gs, gd = CDTL3:GetSpellCooldown(private.GCD_REF)
	return (gd and gd > 0 and math.abs(start - gs) < 0.05 and math.abs(dur - gd) < 0.05) and true or false
end

-- for pcall: the seconds left on the spell's own cooldown according to the game (nil: none)
private.RealLeft = function(id)
	local start, dur = CDTL3:GetSpellCooldown(id)
	if start and dur and dur > 0 then
		return start + dur - GetTime()
	end
	return nil
end

private.GCDOnly = function(d)
	local ok, only = pcall(private.GCDOnlyRead, d["id"])
	return ok and only == true
end

private.Sweep = function(ic, remaining)
	local sw = ic.fxSweep
	if not sw then
		sw = CreateFrame("Cooldown", nil, ic, "CooldownFrameTemplate")
		sw:SetAllPoints(ic)
		sw:SetFrameLevel(ic:GetFrameLevel() + 1)
		if sw.SetDrawEdge then sw:SetDrawEdge(false) end
		if sw.SetDrawBling then sw:SetDrawBling(false) end
		if sw.SetHideCountdownNumbers then sw:SetHideCountdownNumbers(true) end
		if sw.SetSwipeColor then sw:SetSwipeColor(0, 0, 0, 0.62) end
		ic.fxSweep = sw
	end
	local total = remaining
	local ok, _, gd = pcall(CDTL3.GetSpellCooldown, CDTL3, private.GCD_REF)
	if ok and gd and gd > total then
		total = gd
	end
	sw:Show()
	sw:SetCooldown(GetTime() - (total - remaining), total)
end

-- the READY text of an icon in a Ready frame (rs: that frame's settings): its FontString and settings
private.ReadyText = function(ic, rs)
	if not ic.txt then
		return nil
	end
	for i = 1, 3 do
		local ts = rs["icons"]["text" .. i]
		local fs = ic.txt["text" .. i]
		if fs and ts and ts["enabled"] and ts["text"] == "READY" then
			return fs, ts
		end
	end
end

-- "GCD" where READY goes, in the same place and font, grey
private.GCDLabel = function(ic, rs)
	local ready, ts = private.ReadyText(ic, rs)
	local label = ic.fxGCDText
	if not label then
		label = (ic.txt or ic):CreateFontString(nil, "OVERLAY")
		ic.fxGCDText = label
	end
	label:ClearAllPoints()
	if ready and ts then
		label:SetPoint(ts["align"], ic, ts["anchor"], ts["offX"], ts["offY"])
		local path = CDTL3.LSM:Fetch("font", ts["font"])
		local flags = ts["outline"]
		if type(flags) ~= "string" or flags == "NONE" or flags == "" then
			flags = nil
		end
		if path then
			label:SetFont(path, tonumber(ts["size"]) or 12, flags)
		end
		ready:SetAlpha(0)
		ic.fxGCDHidden = ready
	else
		label:SetPoint("CENTER", ic, "CENTER", 0, -6)
		private.SetFont(label, 12, "OUTLINE")
	end
	label:SetTextColor(0.85, 0.85, 0.85, 1)
	label:SetText(L["GCD"])
	label:Show()
end

private.EndGCD = function(ic)
	ic.fxGCD = nil
	if ic.fxSweep then
		ic.fxSweep:SetCooldown(0, 0)
		ic.fxSweep:Hide()
	end
	if ic.fxGCDText then
		ic.fxGCDText:Hide()
	end
	if ic.fxGCDHidden then
		ic.fxGCDHidden:SetAlpha(1)
		ic.fxGCDHidden = nil
	end
end

-- the icon waits in its Ready frame, silent, until the GCD is over
function FX:GCDWait(f)
	local d, ic = f.data, f.icon
	local n = tonumber(d["readyFrame"])
	local rs = n and n >= 1 and n <= 3 and CDTL3.db.profile.ready["ready" .. n] or nil
	if not (rs and rs["enabled"] and _G["CDTL3_Ready_" .. n .. "_MF"]) then
		return	-- no Ready frame to wait in: it stays on its lane
	end

	local remaining = d["currentCD"]
	FX.silent = true
	CDTL3:SendToReady(f)
	FX.silent = nil

	local parent = ic:GetParent()
	if not (parent and parent == _G["CDTL3_Ready_" .. n .. "_MF"]) then
		return
	end
	ic.fxGCD = true
	private.Sweep(ic, remaining)
	private.GCDLabel(ic, rs)
end

private.GCDTick = function(f, ic, d)
	local now = GetTime()
	if ic.fxGCDAt and now - ic.fxGCDAt < 0.1 then
		return
	end
	ic.fxGCDAt = now
	if private.GCDOnly(d) then
		FX:GCDWait(f)
	end
end

---------------------------------------------------------------- the lane's icons (IconUpdate)
-- every frame for an icon on a lane that is counting down
function FX:LaneIcon(f, ic, s, d)
	if d["fxPending"] then
		d["fxPending"] = nil
		d["fxLive"] = true
		private.Alert(f, "gain")
	end

	local warn = d["warnSecs"]
	if warn and warn > 0 and not d["itemUnread"] then
		if d["currentCD"] <= warn then
			private.PulseOn(ic, d)
		elseif ic.fxPulseOn then
			private.PulseOff(ic)
		end
	elseif ic.fxPulseOn then
		private.PulseOff(ic)
	end

	local fx = s["fx"]
	if not fx then
		return false
	end
	local spell = d["type"] == "spells" or d["type"] == "petspells"
	if fx["chargePips"] and spell then
		private.PipsTick(ic, d)
	elseif ic.fxPipsOn then
		private.PipsOff(ic)
	end
	if fx["gcdWait"] and spell and d["currentCD"] <= private.GCD_MAX then
		private.GCDTick(f, ic, d)
		return ic.fxGCD and true or false	-- true: it left the lane for its Ready frame
	end
	return false
end

-- every frame for an icon in a Ready frame: the pips and the pulse are the lane's; a GCD wait ends here
function FX:ReadyFrame(f, ic)
	if ic.fxPipsOn then
		private.PipsOff(ic)
	end
	if ic.fxPulseOn then
		private.PulseOff(ic)
	end
	if not ic.fxGCD then
		return
	end
	local now = GetTime()
	if ic.fxGCDAt and now - ic.fxGCDAt < 0.1 then
		return
	end
	ic.fxGCDAt = now

	local d = f.data
	if d["currentCD"] > 0 and private.GCDOnly(d) then
		return	-- still only the GCD
	end

	-- over, by the estimate: ask the game once more (the cooldown poll can be a moment behind) whether
	-- the GCD still runs, a real cooldown is left, or the spell is ready
	local ok, left = pcall(private.RealLeft, d["id"])
	if ok then
		if left and left > 0.05 then
			if private.GCDOnly(d) then
				return
			end
			d["currentCD"] = left
		else
			d["currentCD"] = 0
		end
	end
	private.EndGCD(ic)
	if d["currentCD"] > 0 then
		CDTL3:MoveToLane(f)	-- a real cooldown after all
	else
		CDTL3:FireTimer("CDTL3_TimerReady", f)
	end
end

---------------------------------------------------------------- shaded zones: burst window and refresh zone
private.Zone = function(lane, key)
	local z = lane[key]
	if z then
		return z
	end
	z = CreateFrame("Frame", nil, lane)
	z:SetFrameLevel(lane:GetFrameLevel() + 2)
	z:EnableMouse(false)
	-- a dark base, the white stripe tile over it in the zone's colour (fp23, fp22 mockups: 135 degree stripes)
	z.base = z:CreateTexture(nil, "BACKGROUND")
	z.base:SetAllPoints(z)
	z.base:SetColorTexture(0, 0, 0, 0.3)
	z.fill = z:CreateTexture(nil, "ARTWORK")
	z.fill:SetAllPoints(z)
	z.fill:SetTexture(private.STRIPES, "REPEAT", "REPEAT")
	z.fill:SetHorizTile(true)
	z.fill:SetVertTile(true)
	z.edge = z:CreateTexture(nil, "OVERLAY")
	z.tag = z:CreateFontString(nil, "OVERLAY")
	private.SetFont(z.tag, 12, "OUTLINE")
	z:Hide()
	lane[key] = z
	return z
end

-- frac of the lane's travel, drawn from its Ready end, 5 beyond its sides; the icon's own size is
-- inside it, as an icon at that point sits wholly in it
private.PlaceZone = function(z, lane, s, frac, r, g, b, tag)
	local len = (s["width"] - s["icons"]["size"]) * frac + s["icons"]["size"]
	local vertical, reversed = s["vertical"], s["reversed"]
	z:ClearAllPoints()
	z.edge:ClearAllPoints()
	z.tag:ClearAllPoints()
	z.fill:SetVertexColor(r, g, b, 1)
	z.edge:SetColorTexture(r, g, b, 1)
	if vertical then
		if reversed then
			z:SetPoint("TOPLEFT", lane, "TOPLEFT", -5, 0)
			z:SetPoint("TOPRIGHT", lane, "TOPRIGHT", 5, 0)
			z.edge:SetPoint("BOTTOMLEFT", z, "BOTTOMLEFT", 0, 0)
			z.edge:SetPoint("BOTTOMRIGHT", z, "BOTTOMRIGHT", 0, 0)
			z.tag:SetPoint("TOP", z.edge, "BOTTOM", 0, -1)
		else
			z:SetPoint("BOTTOMLEFT", lane, "BOTTOMLEFT", -5, 0)
			z:SetPoint("BOTTOMRIGHT", lane, "BOTTOMRIGHT", 5, 0)
			z.edge:SetPoint("TOPLEFT", z, "TOPLEFT", 0, 0)
			z.edge:SetPoint("TOPRIGHT", z, "TOPRIGHT", 0, 0)
			z.tag:SetPoint("BOTTOM", z.edge, "TOP", 0, 1)
		end
		z:SetHeight(len)
		z.edge:SetHeight(2)
	else
		if reversed then
			z:SetPoint("TOPRIGHT", lane, "TOPRIGHT", 0, 5)
			z:SetPoint("BOTTOMRIGHT", lane, "BOTTOMRIGHT", 0, -5)
			z.edge:SetPoint("TOPLEFT", z, "TOPLEFT", 0, 0)
			z.edge:SetPoint("BOTTOMLEFT", z, "BOTTOMLEFT", 0, 0)
		else
			z:SetPoint("TOPLEFT", lane, "TOPLEFT", 0, 5)
			z:SetPoint("BOTTOMLEFT", lane, "BOTTOMLEFT", 0, -5)
			z.edge:SetPoint("TOPRIGHT", z, "TOPRIGHT", 0, 0)
			z.edge:SetPoint("BOTTOMRIGHT", z, "BOTTOMRIGHT", 0, 0)
		end
		z:SetWidth(len)
		z.edge:SetWidth(2)
		z.tag:SetPoint("BOTTOM", z.edge, "TOP", 0, 1)
	end
	if tag then
		z.tag:SetTextColor(r, g, b, 1)
		z.tag:SetText(tag)
		z.tag:Show()
	else
		z.tag:Hide()
	end
	z.len = len
	z:Show()
end

-- where seconds lands on a Time lane, as a fraction of its travel (nil on any other lane)
private.TimeFraction = function(s, secs)
	local mode = s["mode"]["type"]
	if mode == "LINEAR_ABS" then
		local max = s["mode"]["linearAbs"]["max"]
		return secs >= max and 1 or secs / max
	elseif mode == "SPLIT_ABS" then
		local ok, p = pcall(CDTL3.CalcSplitPosition, secs, s["mode"]["splitAbs"]["max"], s)
		if ok and type(p) == "number" then
			return p
		end
	end
	return nil
end

---------------------------------------------------------------- the Ready-by list
private.List = function(lane)
	local lf = lane.fxList
	if lf then
		return lf
	end
	lf = CreateFrame("Frame", nil, lane)
	lf:SetFrameLevel(lane:GetFrameLevel() + 3)
	lf:EnableMouse(false)
	lf:SetWidth(230)
	lf.bg = lf:CreateTexture(nil, "BACKGROUND")
	lf.bg:SetAllPoints(lf)
	lf.bg:SetColorTexture(0.15, 0.15, 0.15, 0.55)
	lf.head = lf:CreateFontString(nil, "OVERLAY")
	private.SetFont(lf.head, 12, "OUTLINE")
	lf.head:SetTextColor(1, 0.82, 0.29, 1)
	lf.head:SetPoint("TOPLEFT", lf, "TOPLEFT", 8, -6)
	lf.row = {}
	for i = 1, private.LIST_ROWS do
		local r = {}
		r.icon = lf:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(18, 18)
		r.icon:SetPoint("TOPLEFT", lf, "TOPLEFT", 8, -(24 + (i - 1) * 20))
		r.name = lf:CreateFontString(nil, "OVERLAY")
		private.SetFont(r.name, 12, "OUTLINE")
		r.name:SetJustifyH("LEFT")
		r.name:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
		r.name:SetWidth(120)
		r.mark = lf:CreateTexture(nil, "ARTWORK")
		r.mark:SetSize(12, 12)
		r.mark:SetPoint("LEFT", r.icon, "RIGHT", 132, 0)
		r.icon:Hide()
		r.name:Hide()
		r.mark:Hide()
		lf.row[i] = r
	end
	lf:Hide()
	lane.fxList = lf
	return lf
end

-- one timer per cooldown, so a combat text binding never follows a row to another spell
private.TimeText = function(c, lf)
	local fs = c.fxListTime
	if not fs then
		fs = lf:CreateFontString(nil, "OVERLAY")
		private.SetFont(fs, 12, "OUTLINE")
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(40)
		c.fxListTime = fs
	end
	return fs
end

private.Listable = function(c, n)
	local d = c.data
	return d and d["pinned"] and d["lane"] == n and d["enabled"] and not d["ignored"]
		and d["type"] ~= "spacer" and d["type"] ~= "testing" and d["type"] ~= "test"
end

private.ListRow = function(lf, i, c, secs)
	local d, r = c.data, lf.row[i]
	r.icon:SetTexture(d["type"] == "items" and d["itemIcon"] or d["icon"])
	r.icon:Show()
	r.name:SetText(d["type"] == "items" and d["itemName"] or d["name"])
	r.name:Show()

	local fs = private.TimeText(c, lf)
	fs:ClearAllPoints()
	fs:SetPoint("TOPRIGHT", lf, "TOPRIGHT", -8, -(26 + (i - 1) * 20))
	fs:Show()
	c.fxListStamp = lf.stamp

	local CT = CDTL3.CombatTimers
	if CT and CT:Riding(c) and CT:BindText(c, fs) then
		-- the time is hidden: the game's own timer, and no tick (it can't be worked out)
		r.mark:Hide()
		return
	end

	local left = d["currentCD"]
	if left > 0 then
		fs:SetText(tostring(CDTL3:GetReadableTime(left)))
	else
		fs:SetText("")
	end
	if left <= secs then
		r.mark:SetTexture([[Interface\RaidFrame\ReadyCheck-Ready]])
	else
		r.mark:SetTexture([[Interface\RaidFrame\ReadyCheck-NotReady]])
	end
	r.mark:Show()
end

-- every 0.2 s: the pinned cooldowns of this lane, soonest first (no tables: each row takes the next
-- smallest time after the last one)
private.UpdateList = function(lane, s, secs)
	local lf = lane.fxList
	lf.stamp = (lf.stamp or 0) + 1
	local cds = CDTL3.cooldowns
	local n = 0
	local lastKey, lastIdx = -1, 0
	for row = 1, private.LIST_ROWS do
		local bestKey, bestIdx
		for idx = 1, #cds do
			local c = cds[idx]
			if private.Listable(c, lane.number) then
				local key = c.data["currentCD"] > 0 and c.data["currentCD"] or 0
				if (key > lastKey or (key == lastKey and idx > lastIdx)) and (not bestKey or key < bestKey) then
					bestKey, bestIdx = key, idx
				end
			end
		end
		if not bestIdx then
			break
		end
		n = n + 1
		lastKey, lastIdx = bestKey, bestIdx
		private.ListRow(lf, row, cds[bestIdx], secs)
	end
	for row = n + 1, private.LIST_ROWS do
		local r = lf.row[row]
		r.icon:Hide()
		r.name:Hide()
		r.mark:Hide()
	end
	for idx = 1, #cds do
		local c = cds[idx]
		if c.fxListTime and c.fxListStamp ~= lf.stamp then
			c.fxListTime:Hide()
		end
	end
	lf:SetHeight(30 + n * 20 + 4)
end

---------------------------------------------------------------- lane refresh and update
-- from RefreshLane: place or hide the zones and the list
function FX:RefreshLane(lane, s)
	local fx = s["fx"]
	local burst = fx and fx["burst"]
	local refresh = fx and fx["refresh"]

	-- burst window: shaded, on a Time lane
	local zone = nil
	if burst and burst["enabled"] and burst["shaded"] then
		local frac = private.TimeFraction(s, burst["secs"])
		if frac then
			zone = private.Zone(lane, "fxBurst")
			private.PlaceZone(zone, lane, s, frac, 1, 0.82, 0.29, string.format(L["Burst %ds"], burst["secs"]))
		end
	end
	if not zone and lane.fxBurst then
		lane.fxBurst:Hide()
	end

	-- refresh zone: the last part of a Linear (%) lane, only where debuffs on enemies can be seen
	zone = nil
	if refresh and refresh["enabled"] and not CDTL3.retailAPI and s["mode"]["type"] == "LINEAR" then
		zone = private.Zone(lane, "fxRefresh")
		private.PlaceZone(zone, lane, s, math.min(math.max((refresh["pct"] or 30) / 100, 0), 1), 0.65, 0.91, 0.23, nil)
	end
	if not zone and lane.fxRefresh then
		lane.fxRefresh:Hide()
	end

	-- the Ready-by list under the lane
	if burst and burst["enabled"] and burst["list"] then
		local lf = private.List(lane)
		lf:ClearAllPoints()
		lf:SetPoint("TOPLEFT", lane, "BOTTOMLEFT", 0, -8)
		lf.head:SetText(string.format(L["Burst in %d s"], burst["secs"]))
		lf.listOn = true
		lf.listAt = nil
		lf:Show()
	elseif lane.fxList then
		lane.fxList.listOn = nil
		lane.fxList:Hide()
	end
end

-- every frame (LaneUpdate): the flash fades, the ghost goes, the list refreshes
function FX:LaneUpdate(lane, s)
	if lane.fxFlashUntil then
		local left = lane.fxFlashUntil - GetTime()
		if left <= 0 then
			lane.fxFlashUntil = nil
			lane.fxFlash:Hide()
		else
			lane.fxFlash:SetAlpha(left >= private.FLASH * 0.5 and 1 or left / (private.FLASH * 0.5))
		end
	end
	if lane.fxGhostUntil and GetTime() >= lane.fxGhostUntil then
		lane.fxGhostUntil = nil
		lane.fxGhost:Hide()
	end

	local lf = lane.fxList
	if lf and lf.listOn then
		local now = GetTime()
		if not lf.listAt or now - lf.listAt >= 0.2 then
			lf.listAt = now
			local burst = s["fx"] and s["fx"]["burst"]
			if burst then
				private.UpdateList(lane, s, burst["secs"])
			end
		end
	end
end

---------------------------------------------------------------- options
-- Lanes > Lane > Effects
function FX:AddLaneArgs(args, i)
	local function fx()
		local lane = CDTL3.db.profile.lanes["lane" .. i]
		return lane and lane["fx"]
	end
	local function refresh()
		CDTL3:RefreshLane(i)
	end
	local function burstOff()
		local f = fx()
		return not (f and f["burst"]["enabled"])
	end
	local function toggle(key, name, desc, order, group)
		return {
			name = name, desc = desc, order = order, type = "toggle",
			get = function(info)
					local f = fx()
					if not f then return false end
					local holder = group and f[group] or f
					return holder[key]
				end,
			set = function(info, val)
					local f = fx()
					if f then
						local holder = group and f[group] or f
						holder[key] = val and true or false
						refresh()
					end
				end,
		}
	end
	local function range(key, name, desc, order, group, min, max)
		return {
			name = name, desc = desc, order = order, type = "range",
			min = min, max = max, step = 1,
			get = function(info)
					local f = fx()
					return f and f[group][key] or min
				end,
			set = function(info, val)
					local f = fx()
					if f then
						f[group][key] = val
						refresh()
					end
				end,
		}
	end

	local group = {
		name = L["Effects"],
		type = "group",
		order = 450,
		args = {
			chargesHeader = { name = L["Charges"], type = "header", order = 10 },
			chargePips = toggle("chargePips", L["Charge pips"],
				L["Spells with charges show a pip along the bottom of their icon for each charge, the next one filling as it recharges, and the icon rides the recharge until every charge is back. On Retail and Forever in combat the count is shown but can't be compared, so the filling pip isn't drawn there."], 11),
			gcdHeader = { name = L["Global cooldown"], type = "header", order = 20 },
			gcdWait = toggle("gcdWait", L["GCD waits in the Ready frame"],
				L["An icon whose only wait is the global cooldown goes straight to its Ready frame under a GCD sweep, with no ready sound, instead of riding the lane. It needs a Ready frame (not Hide) for that spell."], 21),
			burstHeader = { name = L["Burst window"], type = "header", order = 30 },
			burstEnabled = {
				name = L["Mark a burst window"],
				desc = L["Marks the next few seconds of this lane, for lining your pinned cooldowns up. Works on every client."],
				order = 31, type = "toggle",
				get = function(info) local f = fx(); return f and f["burst"]["enabled"] or false end,
				set = function(info, val) local f = fx(); if f then f["burst"]["enabled"] = val and true or false; refresh() end end,
			},
			burstSecs = range("secs", L["Burst in (seconds)"], L["How many seconds from now the burst is"], 32, "burst", 1, 3600),
			burstShaded = toggle("shaded", L["Shaded window"],
				L["Shades the lane from Ready to the burst point and tags it, so icons inside it make the burst. Nothing is worked out, so it works in combat on every client. It draws on Linear (Time) and Split (Time) lanes."], 33, "burst"),
			burstList = toggle("list", L["Ready-by list"],
				L["Lists your pinned cooldowns under the lane, soonest first, with a tick when one is back before the burst point. The ticks are Classic only; on Retail and Forever the list shows just the timers in combat."], 34, "burst"),
			refreshHeader = { name = L["Refresh zone"], type = "header", order = 40, hidden = function() return CDTL3.retailAPI end },
			refreshEnabled = {
				name = L["Mark a refresh zone"],
				desc = L["Shades the last part of the lane, where each debuff is in the stretch of its length you refresh it in. It draws on a Linear (%) lane; Classic Era, TBC and MoP only, where debuffs on enemies can be seen."],
				order = 41, type = "toggle",
				hidden = function() return CDTL3.retailAPI end,
				get = function(info) local f = fx(); return f and f["refresh"]["enabled"] or false end,
				set = function(info, val) local f = fx(); if f then f["refresh"]["enabled"] = val and true or false; refresh() end end,
			},
			refreshPct = range("pct", L["Refresh zone (%)"], L["The last part of a debuff's length that is the refresh window"], 42, "refresh", 1, 100),
		},
	}
	group.args.refreshPct.hidden = function() return CDTL3.retailAPI end
	group.args.burstSecs.disabled = burstOff
	group.args.burstShaded.disabled = burstOff
	group.args.burstList.disabled = burstOff
	group.args.refreshPct.disabled = function()
		local f = fx()
		return not (f and f["refresh"]["enabled"])
	end
	args["effects"] = group
end

-- Filters > an entry: Warn before ready (every type), and for a buff the gained and ended alerts
function FX:AddEntryArgs(args, t)
	local function hidden()
		return CDTL3.currentFilterHidden[t]
	end
	local function entry()
		if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
			return CDTL3.custom
		end
		return CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, t == "items")
	end
	local function get(key, default)
		local e = entry()
		local v = e and e[key]
		if v == nil then
			return default
		end
		return v
	end
	-- on the entry, and on its live icons (items are listed by item name)
	local function apply(key, val)
		local e = entry()
		if not e then
			return
		end
		e[key] = val
		if e == CDTL3.custom then
			return
		end
		local name = CDTL3.currentFilter[t]
		for _, cd in pairs(CDTL3.cooldowns) do
			if cd.data["type"] == t and (cd.data["name"] == name or cd.data["itemName"] == name) then
				cd.data[key] = val
			end
		end
	end
	local function sound(key, name, desc, order, default, shown)
		-- its Play sound button, key.."Test", sits right after it (SplitBlizzardSound lays the rows out)
		args[key.."Test"] = {
			name = L["Play sound"], desc = L["Plays this sound once, so you can hear it"],
			order = order + 0.1, type = "execute", width = "normal",
			hidden = function(info) return hidden() or not shown() end,
			func = function(info) private.PlayTestSound(get(key, default)) end,
		}
		return {
			name = name, desc = desc, order = order, type = "select", width = "double",
			dialogControl = "LSM30_Sound",
			values = AceGUIWidgetLSMlists.sound,
			hidden = function(info) return hidden() or not shown() end,
			get = function(info) return get(key, default) end,
			set = function(info, val)
				apply(key, val)
				CDTL3:PlayPicked(val)
			end,
		}
	end

	args["spacer760"] = { name = "\n", type = "description", order = 760, hidden = hidden }
	args["warnSecs"] = {
		name = L["Warn before ready (seconds)"],
		desc = L["Pulses its icon with an orange border in its last seconds before it's ready, so you can hold a pull or a potion. 0 is off. On Retail and Forever, while the time is hidden in combat, it's timed from CDTL3's own estimate."],
		order = 761, type = "range", min = 0, max = 120, step = 1,
		hidden = hidden,
		get = function(info) return get("warnSecs", 0) end,
		set = function(info, val) apply("warnSecs", val > 0 and val or nil) end,
	}
	args["warnSound"] = sound("warnSound", L["Warning Sound"], L["The sound this plays as the warning starts (None is silent)"], 762, "None",
		function() return get("warnSecs", 0) > 0 end)

	if t == "buffs" then
		args["spacer765"] = { name = "", type = "description", order = 765, hidden = hidden }
		args["alertGain"] = {
			name = L["Alert when gained"],
			desc = L["When this buff lands, its lane flashes green and its sound plays. On Retail and Forever, in combat, only for buffs in the Cooldown Manager's Tracked Bars."],
			order = 766, type = "toggle", hidden = hidden,
			get = function(info) return get("alertGain", false) end,
			set = function(info, val) apply("alertGain", val and true or false) end,
		}
		args["gainSound"] = sound("gainSound", L["Gained Sound"], L["The sound this plays when it lands (None is silent)"], 767, "CDTL3 Click",
			function() return get("alertGain", false) end)
		args["alertEnd"] = {
			name = L["Alert when it ends"],
			desc = L["When this buff drops, its lane flashes red at its Ready end, a struck-out ghost of the buff stays for 2 seconds, and its sound plays. On Retail and Forever, in combat, only for buffs in the Cooldown Manager's Tracked Bars."],
			order = 768, type = "toggle", hidden = hidden,
			get = function(info) return get("alertEnd", false) end,
			set = function(info, val) apply("alertEnd", val and true or false) end,
		}
		args["endSound"] = sound("endSound", L["Ended Sound"], L["The sound this plays when it drops (None is silent)"], 769, "CDTL3 Tinks",
			function() return get("alertEnd", false) end)
	end
end

-- a login or a zoning isn't a buff landing: no alerts for a few seconds after it
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:SetScript("OnEvent", function()
	private.worldAt = GetTime()
end)
