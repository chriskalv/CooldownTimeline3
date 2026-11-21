--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}
private.dynamicTextPollRate = 10
private.timeTextPollRate = 2
-- seconds after an item's use in which a readable 0 cooldown read means "no cooldown"
private.itemNoCooldownWindow = 2
-- a lane mode's settings table in lane.mode, by mode type
private.modeKeys = { LINEAR = "linear", LINEAR_ABS = "linearAbs", SPLIT = "split", SPLIT_ABS = "splitAbs" }
private.splitModeKeys = { SPLIT = "split", SPLIT_ABS = "splitAbs" }

function CDTL3:CreateCooldown(UID, cdType, cdData)
	local fName = "CDTL3_CD_"..UID
	local f = CreateFrame("Frame", fName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

	f.updateCount = 0

	-- the spell data's flag wins whenever it lists the spell (a flag saved by an older build
	-- can be stale, e.g. Forever's Elemental Mastery); otherwise keep the saved one
	local oaf = cdData["oaf"]
	if cdType == "spells" or cdType == "petspells" then
		local dataOaf, dataKnows = CDTL3:IsAuraFadeSpell(cdData["id"], cdData["name"])
		if dataKnows then
			oaf = dataOaf
		end
	end

	f.data = {
		uid = UID,
		id = cdData["id"],
		type = cdType,
		name = cdData["name"],
		rank = cdData["rank"],
		desc = cdData["desc"],
		icon = cdData["icon"],
		oaf = oaf or nil,
		stacks = 0,

		targetID = cdData["targetID"],
		targetName = cdData["targetName"],

		itemID = cdData["itemID"],
		itemName = cdData["itemName"],

		link = cdData["link"],

		enabled = cdData["enabled"],
		ignored = cdData["ignored"],
		highlight = cdData["highlight"],
		pinned = cdData["pinned"],

		lane = cdData["lane"],
		barFrame = cdData["barFrame"],
		readyFrame = cdData["readyFrame"],

		baseCD = cdData["bCD"] / 1000,
		currentCD = cdData["bCD"] / 1000,
		endTime = cdData["endTime"],
		-- a timer from another addon (CDTL3:StartTimer, API.lua)
		owner = cdData["owner"],
		class = cdData["class"],
		timerEnd = cdData["timerEnd"],
		pendingCD = cdData["pendingCD"],
		overrideCD = false,
	}

	if cdData["charges"] then
		f.data["charges"] = cdData["charges"]
	end

	-- warnings and buff alerts (IconFx.lua)
	CDTL3.IconFx:CopyEntry(f.data, cdData)

	if cdData["school"] then
		f.data["school"] = cdData["school"]
	end

	if cdData["customColor"] then
		f.data["customColor"] = cdData["customColor"]
		f.data["color"] = cdData["color"]
	end

	if cdData["runeIndex"] then
		f.data["runeIndex"] = cdData["runeIndex"]
	end

	if cdType == "runes" then
		f.data["runeGraceTime"] = 0
	end

	if cdData["setCustomCD"] then
		f.data["setCustomCD"] = cdData["setCustomCD"]

		if cdData["customCDTime"] then
			f.data["customCDTime"] = cdData["customCDTime"]
			f.data["baseCD"] = f.data["customCDTime"] / 1000
		end
	end

	if cdType == "items" then
		if cdData["itemIcon"] then
			f.data["itemIcon"] = cdData["itemIcon"]
		else
			local _, icon = CDTL3:GetSpellInfo(f.data["id"])
			f.data["icon"] = icon

			local item = Item:CreateFromItemID(f.data["itemID"])
			item:ContinueOnItemLoad(function()
				f.data["itemIcon"] = item:GetItemIcon()

				CDTL3:SetItemData(f.data["itemID"], "icon", f.data["icon"])
				CDTL3:SetItemData(f.data["itemID"], "itemIcon", f.data["itemIcon"])
			end)
		end
	end

	if cdData["trigger"] then
		f.data["trigger"] = cdData["trigger"]
	end

	-- ON UPDATE
	f:HookScript("OnUpdate", function(frame, elapsed)
		private.CooldownUpdate(frame, elapsed)
	end)

	f.icon = CDTL3:CreateIcon(fName, f)

	-- Create bar BEFORE SendToLane so a RefreshIcon/LSM error in SendToLane
	-- cannot leave f.bar nil and cause 1000x CooldownUpdate crashes.
	f.bar = CDTL3:CreateBar(fName, f)

	CDTL3:SendToLane(f)
	CDTL3:SendToBarFrame(f)

	table.insert(CDTL3.cooldowns, f)

	return f
end

-- An icon's or a bar's unlock box (frameName_DB): shown while frames are unlocked, and in debug mode
private.CreateUnlockBox = function(f, frameName)
	f.db = CreateFrame("Frame", frameName.."_DB", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.db:SetParent(f --[[@as Frame]])
	f.db.bg = f.db:CreateTexture(nil, "BACKGROUND")
	f.db.text = f.db:CreateFontString(nil,"ARTWORK")
	if not CDTL3.db.profile.global["unlockFrames"] then
		f.db:Hide()
	end
end

function CDTL3:CreateIcon(fName, cd)
	local frameName = fName.."_Icon"
	local f = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

	f.uid = cd.data["uid"]
	f.valid = cd.data["enabled"]
	f.readyTime = 0
	f.yOffset = 0
	f.sOffset = 0
	f.currentCD = 0

	f.tx = f:CreateTexture()

	private.CreateUnlockBox(f, frameName)

	f:SetFrameLevel(20)
	return f
end

function CDTL3:CreateBar(fName, cd)
	local frameName = fName.."_Bar"
	local f = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

	f.valid = cd.data["enabled"]

	f.bar = CreateFrame("StatusBar", frameName.."_BA", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.bar:SetParent(f --[[@as Frame]])
	f.bar.transitionThreshold = 0
	f.bar.bg = f:CreateTexture(nil, "BACKGROUND")

	f.icon = CreateFrame("Frame", frameName.."_IC", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.icon:SetParent(f --[[@as Frame]])
	f.icon.tx = f.icon:CreateTexture(nil, "BACKGROUND")

	private.CreateUnlockBox(f, frameName)

	f:SetFrameLevel(20)
	return f
end

function CDTL3:RefreshAllBars()
	for _, cd in pairs(CDTL3.cooldowns) do
		CDTL3:RefreshBar(cd)
	end
end

function CDTL3:RefreshAllIcons()
	for _, cd in pairs(CDTL3.cooldowns) do
		CDTL3:RefreshIcon(cd)
	end
end

-- an icon's or a bar's texts 1 to 3, by number
private.TEXT_KEYS = { "text1", "text2", "text3" }

-- An icon's or a bar's texts (ss = its icons or bar settings), anchored to f. nudge2 is added to text 2's
-- y offset (nil: none).
private.RefreshTexts = function(f, cd, ss, nudge2)
	if ss["text1"]["enabled"] or ss["text2"]["enabled"] or ss["text3"]["enabled"] then
		if not f.txt then
			f.txt = CreateFrame("Frame", f:GetName().."_TEXT", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.txt:SetParent(f)
			f.txt.bg = f.txt:CreateTexture(nil, "BACKGROUND")
		end

		for i = 1, 3 do
			local key = private.TEXT_KEYS[i]
			local ts = ss[key]
			local t = f.txt[key]
			if ts["enabled"] then
				if not t then
					t = f.txt:CreateFontString(nil, "ARTWORK")
					f.txt[key] = t
				end

				local offY = ts["offY"]
				if i == 2 and nudge2 then
					offY = offY + nudge2
				end
				t:ClearAllPoints()
				t:SetPoint(ts["align"], f, ts["anchor"], ts["offX"], offY)
				local outline = ts["outline"]
				if type(outline) ~= "string" or outline == "NONE" or outline == "" then outline = nil end
				local font, size = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
				if font and size > 0 then t:SetFont(font, size, outline) end
				t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
				t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
				t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
				t:SetShadowOffset(ts["shadX"], ts["shadY"])
				t:SetNonSpaceWrap(false)
				t:Show()
			elseif t then
				t:Hide()
			end
		end
	elseif f.txt then
		-- all texts off: f.txt only exists if one was enabled before
		for i = 1, 3 do
			local t = f.txt[private.TEXT_KEYS[i]]
			if t then
				t:Hide()
			end
		end
	end
end

function CDTL3:RefreshBar(cd)
	local f = cd.bar
	local s
	local p = f:GetParent():GetName()

	if CDTL3:SlotOfParent(p) == "barFrames" then
		-- bar frame 0 shows as frame 1
		local n = cd.data["barFrame"]
		s = CDTL3:SlotSettings("barFrames", n == 0 and 1 or n)
	else
		s = CDTL3:SlotSettings("barFrames", 1)
	end

	f:ClearAllPoints()
	f:SetPoint("CENTER", 0, 0)
	f:SetWidth(s["width"])
	f:SetHeight(s["height"])

	-- ICON
	local barWidth = s["width"]
	local iconOffset = 0
	if s["bar"]["iconEnabled"] then
		if not f.icon then
			f.icon = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.icon:SetParent(f)
		end

		barWidth = barWidth - s["height"]
		iconOffset = s["height"]

		if s["bar"]["iconPosition"] == "RIGHT" then
			iconOffset = -s["height"]
		end

		f.icon:ClearAllPoints()
		f.icon:SetPoint(s["bar"]["iconPosition"], 0, 0)
		f.icon:SetWidth(s["height"])
		f.icon:SetHeight(s["height"])

		f.icon.tx:SetAllPoints(f.icon)

		local icon = cd.data["icon"]
		f.icon.tx:SetTexture(icon)

		local zoom = CDTL3.db.profile.global["zoom"]
		local tl = zoom - 1
		local br = 1 - (zoom - 1)
		f.icon.tx:SetTexCoord(tl, br, tl, br)

		-- Masque: the timer type's own group (Media.lua)
		CDTL3:MasqueSkin(f.icon, f.icon.tx, cd.data["type"])

		f.icon:Show()
	else
		if f.icon then
			barWidth = s["width"]
			iconOffset = 0

			f.icon:ClearAllPoints()
			f.icon:SetPoint(s["bar"]["iconPosition"], 0, 0)
			f.icon:SetWidth(s["height"])
			f.icon:SetHeight(s["height"])

			f.icon:Hide()
		end
	end

	-- BAR
	f.bar:ClearAllPoints()
	f.bar:SetPoint(s["bar"]["iconPosition"], iconOffset, 0)
	f.bar:SetSize(barWidth, s["height"])

	-- FOREGROUND
	f.bar:SetMinMaxValues(0, 1)
	f.bar:SetValue(0.5)
	CDTL3:SetBarTexture(f.bar, s["bar"]["fgTexture"])
	f.bar:GetStatusBarTexture():SetHorizTile(false)
	f.bar:GetStatusBarTexture():SetVertTile(false)
	--[[f.bar:SetStatusBarColor(
		s["bar"]["fgTextureColor"]["r"],
		s["bar"]["fgTextureColor"]["g"],
		s["bar"]["fgTextureColor"]["b"],
		s["bar"]["fgTextureColor"]["a"]
	)]]--

	local fgColor = private.GetBarFGColor(s, cd.data)

	f.bar:SetStatusBarColor(
		fgColor["r"],
		fgColor["g"],
		fgColor["b"],
		fgColor["a"]
	)

	-- BACKGROUND
	CDTL3:SetBarTexture(f.bar.bg, s["bar"]["bgTexture"])
	f.bar.bg:SetAllPoints(true)
	--[[f.bar.bg:SetVertexColor(
		s["bar"]["bgTextureColor"]["r"],
		s["bar"]["bgTextureColor"]["g"],
		s["bar"]["bgTextureColor"]["b"],
		s["bar"]["bgTextureColor"]["a"]
	)]]--

	local bgColor = s["bar"]["bgTextureColor"]
	if CDTL3.player["class"] then
		if s["bar"]["bgClassColor"] then
			bgColor = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]]
		end
	end

	f.bar.bg:SetVertexColor(
		bgColor["r"],
		bgColor["g"],
		bgColor["b"],
		bgColor["a"]
	)

	-- TEXT
	private.RefreshTexts(f, cd, s["bar"])

	-- TRANSITION
	if s["transition"]["showTI"] then
		if not f.bar.ti then
			f.bar.ti = CreateFrame("Frame", f:GetName().."_TI", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bar.ti:SetParent(f.bar)
			f.bar.ti.bg = f.bar.ti:CreateTexture(nil, "BACKGROUND")
		end

		private.CalcTransitionIndicator(cd, s)
		f.bar.ti:Show()
		if f.txt then
			f.txt:SetFrameLevel(f.bar.ti:GetFrameLevel() + 1)
		end
	else
		if f.bar.ti then
			f.bar.ti:Hide()
		end

		private.CalcTransitionIndicator(cd, s)
	end

	-- BORDER
	if s["bar"]["border"]["style"] ~= "None" then
		if not f.bd then
			f.bd = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bd:SetParent(f)
		end

		CDTL3:SetBorder(f.bd, s["bar"]["border"])
		f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
		f.bd:Show()
	else
		if f.bd then
			f.bd:Hide()
		end
	end

	-- DEBUG/UNLOCK
	f.db:ClearAllPoints()
	f.db:SetPoint("CENTER", 0, 0)
	f.db.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 10)
	f.db.text:ClearAllPoints()
	f.db.text:SetPoint("CENTER", 0, 0)
	f.db.text:SetText(cd.data["uid"].."_B\n"..cd.data["name"])
	f.db:SetSize(s["width"], s["height"])
	f.db.bg:SetAllPoints(true)
	f.db.bg:SetColorTexture( 0.1, 0.1, 0.1, 0.5 )

	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:DebugOn(f)
	else
		CDTL3:DebugOff(f)
	end
end

-- Highlight effects (Highlight Style): every animation group is made once per icon, kept on its
-- highlight frame (f.hl) and stopped in CDTL3:RemoveHighlights (Helpers.lua). They only change how the
-- icon is drawn: nothing here reads the icon's size or position (a riding icon's are hidden), and an
-- animation never moves the icon's anchors or its texts.
-- Pulse, Bounce, Scale and Shake act on the icon frame (Shake on its texture: only textures rotate).
-- Highlight Style: GLOW, BORDER, BORDER_FLASH, FLASH, PULSE, BOUNCE, SHAKE, SCALE.
-- Border and Border Pulse with no border texture chosen, and Glow, are drawn with plain textures round
-- the highlight frame (IconFx.lua FX.Ring), not a backdrop: a backdrop's edge pieces wait for a size the
-- game can hide (Helpers.lua SetBorder), and the game's action-button glow is not on every client.
private.EDGE = 2				-- the plain border's thickness
private.GLOW_COLOR = { 1, 0.82, 0 }	-- the glow's gold

private.RingColor = function(ring, r, g, b, a)
	for i = 1, 4 do
		ring[i]:SetColorTexture(r, g, b, a)
	end
end

-- the plain edge, made once per icon
private.HighlightEdge = function(hl)
	if not hl.edge then
		hl.edge = CDTL3.IconFx.Ring(hl, private.EDGE, 1, 1, 1, 1)
	end
	return hl.edge
end

-- Masque: an icon wearing a round skin (Cirque and the like) gets round highlights: the plain edge, the
-- glow and the Flash Icon fill. Masque keeps the shape of the skin it put on a button in its own
-- record (Masque Core/Button.lua: _MSQ_CFG.Shape, "Circle" for round skins); any other shape, or no
-- Masque, keeps the square ones. A border texture you choose stays as it is.
private.IsRound = function(f)
	local cfg = rawget(f, "_MSQ_CFG")
	return type(cfg) == "table" and cfg.Shape == "Circle"
end

-- a white circle (Media/ring.tga) or disc on frame, centred, made once and kept under key
private.RoundTexture = function(frame, key, file, layer)
	local t = frame[key]
	if not t then
		t = frame:CreateTexture(nil, layer or "OVERLAY")
		t:SetTexture(file)
		t:SetPoint("CENTER", frame, "CENTER", 0, 0)
		frame[key] = t
	end
	return t
end

-- the glow round or square: the square bars, or two gold circles round the icon
private.GlowShape = function(glow, round, size)
	local fx, c = CDTL3.IconFx, private.GLOW_COLOR
	fx.RingShow(glow.inner, not round)
	fx.RingShow(glow.outer, not round)
	if round then
		local inner = private.RoundTexture(glow, "roundInner", fx.RING_TEX)
		inner:SetSize(size + 6, size + 6)
		inner:SetVertexColor(c[1], c[2], c[3], 0.9)
		inner:Show()
		local outer = private.RoundTexture(glow, "roundOuter", fx.RING_TEX, "ARTWORK")
		outer:SetSize(size + 16, size + 16)
		outer:SetVertexColor(c[1], c[2], c[3], 0.35)
		outer:Show()
	else
		if glow.roundInner then
			glow.roundInner:Hide()
			glow.roundOuter:Hide()
		end
	end
end

-- Effect speed (icons.highlight.speed): 1 is the original's own timings, 0.5 half as fast (the
-- default), 2 twice as fast. Each animation keeps its timing at 1 (private.Timed) and every play sets
-- it for the frame's speed, so a changed slider shows on the next refresh.
private.DEFAULT_SPEED = 0.5

private.Timed = function(g, a, duration, endDelay)
	g.cdtl3Times = g.cdtl3Times or {}
	g.cdtl3Times[#g.cdtl3Times + 1] = { a, duration, endDelay }
	a:SetDuration(duration)
	if endDelay then
		a:SetEndDelay(endDelay)
	end
end

private.PlayHighlight = function(hl, key, build, speed)
	local g = hl[key]
	if not g then
		g = build(hl:GetParent(), hl)
		hl[key] = g
	end
	speed = (type(speed) == "number" and speed > 0) and speed or private.DEFAULT_SPEED
	if g.cdtl3Speed ~= speed then
		g.cdtl3Speed = speed
		for _, t in ipairs(g.cdtl3Times or {}) do
			t[1]:SetDuration(t[2] / speed)
			if t[3] then
				t[1]:SetEndDelay(t[3] / speed)
			end
		end
	end
	g:Play()
end

private.BuildBorderPulse = function(_, hl)
	local g = hl:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	g:SetToFinalAlpha(true)
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(0.2)
	a:SetToAlpha(1)
	private.Timed(g, a, 0.5)
	a:SetOrder(1)
	return g
end

-- Glow: a gold halo round the icon, a bright inner band and a faint outer one, breathing from dim to
-- full and back over a second (the frame and its group are made once per icon)
private.BuildGlow = function(_, hl)
	local fx, c = CDTL3.IconFx, private.GLOW_COLOR
	local glow = CreateFrame("Frame", nil, hl)
	glow:SetAllPoints(hl)
	glow.inner = fx.Ring(glow, 3, c[1], c[2], c[3], 0.9)
	local outer = CreateFrame("Frame", nil, glow)
	outer:SetPoint("TOPLEFT", glow, "TOPLEFT", -3, 3)
	outer:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 3, -3)
	glow.outer = fx.Ring(outer, 4, c[1], c[2], c[3], 0.35)
	hl.glow = glow
	local g = glow:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(0.35)
	a:SetToAlpha(1)
	private.Timed(g, a, 0.5)
	a:SetOrder(1)
	return g
end

-- the Flash Icon fill: the same beat on the white fill
private.BuildFlash = private.BuildBorderPulse

-- the whole icon's alpha 0.2 to 1 and back (no final alpha: the icon's own alpha is its to set)
private.BuildIconPulse = function(f)
	local g = f:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	local a = g:CreateAnimation("Alpha")
	a:SetFromAlpha(0.2)
	a:SetToAlpha(1)
	private.Timed(g, a, 0.5)
	a:SetOrder(1)
	return g
end

-- up 10, down 10, rest a quarter second, again
private.BuildBounce = function(f)
	local g = f:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local up = g:CreateAnimation("Translation")
	up:SetOffset(0, 10)
	private.Timed(g, up, 0.25)
	up:SetOrder(1)
	local down = g:CreateAnimation("Translation")
	down:SetOffset(0, -10)
	private.Timed(g, down, 0.25, 0.25)
	down:SetOrder(2)
	return g
end

-- 10 degrees each way: out to one side, across to the other, and back (BOUNCE plays it in reverse)
private.BuildShake = function(f)
	local g = f.tx:CreateAnimationGroup()
	g:SetLooping("BOUNCE")
	local one = g:CreateAnimation("Rotation")
	one:SetDegrees(10)
	private.Timed(g, one, 0.25)
	one:SetOrigin("CENTER", 0, 0)
	one:SetOrder(1)
	local two = g:CreateAnimation("Rotation")
	two:SetDegrees(-20)
	private.Timed(g, two, 0.5)
	two:SetOrigin("CENTER", 0, 0)
	two:SetOrder(2)
	return g
end

-- to 1.2 in a quarter second, then to 0.8 in a quarter second, again
private.BuildScale = function(f)
	local g = f:CreateAnimationGroup()
	g:SetLooping("REPEAT")
	local up = g:CreateAnimation("Scale")
	local down = g:CreateAnimation("Scale")
	if up.SetScaleFrom then
		up:SetScaleFrom(1, 1)
		up:SetScaleTo(1.2, 1.2)
		down:SetScaleFrom(1.2, 1.2)
		down:SetScaleTo(0.8, 0.8)
	else
		-- older clients: SetScale multiplies what is there
		up:SetScale(1.2, 1.2)
		down:SetScale(0.8 / 1.2, 0.8 / 1.2)
	end
	up:SetOrigin("CENTER", 0, 0)
	private.Timed(g, up, 0.25)
	up:SetOrder(1)
	down:SetOrigin("CENTER", 0, 0)
	private.Timed(g, down, 0.25)
	down:SetOrder(2)
	return g
end

-- Draws one highlight effect on an icon frame (f needs f.tx and a name): the Highlight Style effects
-- RefreshIcon gives a highlighted icon, and the samples in the What's new window. s is a lane's (or
-- Ready frame's) settings, style one of GLOW, BORDER, BORDER_FLASH, FLASH, PULSE, BOUNCE, SHAKE, SCALE.
function CDTL3:ApplyHighlight(f, s, style)
	local hs = s["icons"]["highlight"]
	if not f.hl then
		f.hl = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f.hl:SetParent(f)
		f.hl.tx = f.hl:CreateTexture()
	end

	-- the chosen border texture (Border and Border Pulse use it; None draws no backdrop edge)
	CDTL3:SetBorder(f.hl, hs["border"])
	f.hl:ClearAllPoints()
	f.hl:SetPoint("CENTER", 0, 0)
	f.hl:SetSize(s["icons"]["size"], s["icons"]["size"])
	-- SetAllPoints(true) fills the parent; the definitions only take a region there
	---@diagnostic disable-next-line: param-type-mismatch
	f.hl.tx:SetAllPoints(true)
	f.hl.tx:SetColorTexture( 1, 1, 1, 0.5 )
	-- fixed offset above the icon (border is +1); incrementing climbed on every refresh
	f.hl:SetFrameLevel(f:GetFrameLevel() + 2)

	CDTL3:RemoveHighlights(f, s)

	local c = hs["border"]["color"]
	local plain = hs["border"]["style"] == "None"
	local round = private.IsRound(f)
	local size = s["icons"]["size"]
	if style == "GLOW" then
		private.PlayHighlight(f.hl, "agGlow", private.BuildGlow, hs["speed"])
		private.GlowShape(f.hl.glow, round, size)
		f.hl.glow:Show()
	elseif style == "BORDER" or style == "BORDER_FLASH" then
		if plain and round then
			local edge = private.RoundTexture(f.hl, "roundEdge", CDTL3.IconFx.RING_TEX)
			edge:SetSize(size + 2 * private.EDGE, size + 2 * private.EDGE)
			edge:SetVertexColor(c["r"], c["g"], c["b"], c["a"])
			edge:Show()
		elseif plain then
			local edge = private.HighlightEdge(f.hl)
			private.RingColor(edge, c["r"], c["g"], c["b"], c["a"])
			CDTL3.IconFx.RingShow(edge, true)
		else
			f.hl:SetBackdropBorderColor(c["r"], c["g"], c["b"], c["a"])
		end
		if style == "BORDER_FLASH" then
			private.PlayHighlight(f.hl, "agBorderPulse", private.BuildBorderPulse, hs["speed"])
		end
	elseif style == "FLASH" then
		f.hl:ClearAllPoints()
		f.hl:SetPoint("CENTER", 0, 0)
		f.hl:SetSize(s["icons"]["size"], s["icons"]["size"])
		if round then
			f.hl.tx:SetTexture(CDTL3.IconFx.DISC_TEX)
			f.hl.tx:SetVertexColor(1, 1, 1, 1)
		else
			f.hl.tx:SetColorTexture( 1, 1, 1, 1 )
		end
		private.PlayHighlight(f.hl, "agPulse", private.BuildFlash, hs["speed"])
	elseif style == "PULSE" then
		private.PlayHighlight(f.hl, "agIconPulse", private.BuildIconPulse, hs["speed"])
	elseif style == "BOUNCE" then
		private.PlayHighlight(f.hl, "agBounce", private.BuildBounce, hs["speed"])
	elseif style == "SHAKE" then
		private.PlayHighlight(f.hl, "agShake", private.BuildShake, hs["speed"])
	elseif style == "SCALE" then
		private.PlayHighlight(f.hl, "agScale", private.BuildScale, hs["speed"])
	end

	f.hl:Show()
end

function CDTL3:RefreshIcon(cd)
	local f = cd.icon
	local s = CDTL3:SlotSettings("lanes", 1)
	local p = f:GetParent():GetName()
	local group = CDTL3:SlotOfParent(p)

	-- on a lane or in a Ready frame: that slot's settings (0 counts as 1); anything else keeps lane 1's
	if group == "lanes" then
		local n = cd.data["lane"]
		s = CDTL3:SlotSettings("lanes", n == 0 and 1 or n) or s
	elseif group == "ready" then
		local n = cd.data["readyFrame"]
		s = CDTL3:SlotSettings("ready", n == 0 and 1 or n) or s
	end

	if cd.data["setCustomCD"] then
		if cd.data["customCDTime"] then
			cd.data["baseCD"] = cd.data["customCDTime"] / 1000
		else
			local specialCase = false
			if cd.data["type"] == "items" then
				specialCase = true
			end
			local cds = CDTL3:GetSpellSettings(cd.data["name"], cd.data["type"], specialCase)
			if cds then
				cd.data["baseCD"] = cds["bCD"] / 1000
			end
		end
	else
		if cd.data["type"] ~= "testing" then
			local specialCase = false
			if cd.data["type"] == "items" then
				specialCase = true
			end

			local cds = CDTL3:GetSpellSettings(cd.data["name"], cd.data["type"], specialCase)
			if cds then
				cd.data["baseCD"] = cds["bCD"] / 1000
			end
		end
	end

	f.yOffset = s["iconOffset"]

	f:ClearAllPoints()
	f:SetPoint("CENTER", 0, 0)
	f.placeNow = true	-- slid back into place on its next update, whatever the Update rate
	f:SetSize(s["icons"]["size"], s["icons"]["size"])

	-- Set the icon texture
	local icon = cd.data["icon"]
	if cd.data["type"] == "items" then
		if CDTL3.db.profile.global[cd.data["type"]]["useItemIcon"] then
			icon = cd.data["itemIcon"]
		end
	end
	f.tx:SetAllPoints()
	f.tx:SetTexture(icon)
	f.tx:SetAlpha(s["icons"]["alpha"])

	-- Set the icon texture zoom
	local zoom = CDTL3.db.profile.global["zoom"]
	local tl = zoom - 1
	local br = 1 - (zoom - 1)
	f.tx:SetTexCoord(tl, br, tl, br)

	-- Masque: the timer type's own group (Media.lua)
	CDTL3:MasqueSkin(f, f.tx, cd.data["type"])

	-- TEXT
	-- text 2 stands 4 px higher while charge pips show under it (IconFx.lua)
	private.RefreshTexts(f, cd, s["icons"], f.fxNudge and 4 or 0)

	-- BORDER
	if s["icons"]["border"]["style"] ~= "None" then
		if not f.bd then
			f.bd = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bd:SetParent(f)
		end

		CDTL3:SetBorder(f.bd, s["icons"]["border"])
		f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
		f.bd:Show()
	else
		if f.bd then
			f.bd:Hide()
		end
	end

	-- HIGHLIGHT
	-- Flash when ready (Filters): while it waits in a Ready frame the icon flashes with the Flash
	-- Icon highlight, whatever that frame's own highlight settings are
	local readyFlash = cd.data["readyLit"] and not cd.data["highlight"] and group == "ready"
	if cd.data["highlight"] or readyFlash then
		local hs = s["icons"]["highlight"]
		CDTL3:ApplyHighlight(f, s, readyFlash and "FLASH" or hs["style"])
	else
		if f.hl then
			CDTL3:RemoveHighlights(f, s)
			f.hl:Hide()
		end
	end

	f:EnableMouse(false)

	-- DEBUG/UNLOCK
	f.db:ClearAllPoints()
	f.db:SetPoint("CENTER", 0, 0)
	f.db.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 10)
	f.db.text:ClearAllPoints()
	f.db.text:SetPoint("CENTER", 0, 0)
	f.db.text:SetText(cd.data["uid"].."_B\n"..cd.data["name"])
	f.db:SetSize(s["icons"]["size"], s["icons"]["size"])
	f.db.bg:SetAllPoints(true)
	f.db.bg:SetColorTexture( 0.1, 0.1, 0.1, 0.5 )

	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:DebugOn(f)
	else
		CDTL3:DebugOff(f)
	end

	-- Caster lane names (Group.lua)
	CDTL3:CasterRefreshIcon(cd)
end

-- Spell schools only come from the combat log. Where it isn't available (CDTL3:NoCombatLog,
-- which Options.lua also uses to hide the Spell School Color toggle there) the saved setting
-- is ignored, so a profile imported from another client can't paint every bar "Other" with
-- no visible way to turn it off. The setting itself is left as saved.

-- Resolves the foreground color for a bar: the entry's own color (Filters) -> school ->
-- class -> the bar frame's color. Shared by RefreshBar and the dynamic-color restore.
private.GetBarFGColor = function(s, d)
	local fgColor = s["bar"]["fgTextureColor"] or { r = 0.77647, g = 0.11765, b = 0.28235, a = 1 }
	if d and d["customColor"] and d["color"] then
		fgColor = d["color"]
	elseif s["bar"]["fgSchoolColor"] and not CDTL3:NoCombatLog() then
		local schoolColor = CDTL3.db.profile.global["schoolColors"]["Other"]
		if d and d["school"] then
			schoolColor = CDTL3.db.profile.global["schoolColors"][d["school"]] or schoolColor
		end

		fgColor = schoolColor
	else
		-- a timer from another addon can name the class it belongs to
		local class = (d and d["class"]) or CDTL3.player["class"]
		if class and s["bar"]["fgClassColor"] then
			fgColor = CDTL3.db.profile.global["classColors"][class] or fgColor
		end
	end

	return fgColor
end

-- Dynamic ready-state color: below the warn threshold the bar blends warnColor -> readyColor
-- as the cooldown approaches ready; above it (or when disabled) the configured color applies
private.UpdateBarDynamicColor = function(ba, s, d)
	if not ( s and s["bar"] ) then return end
	local dyn = s["bar"]["dynamicColor"]
	if dyn and dyn["enabled"] then
		local remaining = d["currentCD"]
		local warnT = dyn["warnTime"] or 5

		if remaining <= warnT and warnT > 0 then
			local t = 1 - (remaining / warnT)
			if t < 0 then t = 0 elseif t > 1 then t = 1 end

			local c1 = dyn["warnColor"] or { r = 1, g = 0.6, b = 0, a = 1 }
			local c2 = dyn["readyColor"] or { r = 0.2, g = 0.9, b = 0.2, a = 1 }

			ba.bar:SetStatusBarColor(
				c1["r"] + (c2["r"] - c1["r"]) * t,
				c1["g"] + (c2["g"] - c1["g"]) * t,
				c1["b"] + (c2["b"] - c1["b"]) * t,
				(c1["a"] or 1) + ((c2["a"] or 1) - (c1["a"] or 1)) * t
			)
			ba.dynTinted = true
			return
		end
	end

	if ba.dynTinted then
		ba.dynTinted = false
		local fgColor = private.GetBarFGColor(s, d)
		ba.bar:SetStatusBarColor(fgColor["r"], fgColor["g"], fgColor["b"], fgColor["a"])
	end
end

-- UPDATE RATE (Global > Update rate): which frames move icons, fill bars and redo texts. Timers, Ready
-- and sounds run every frame whatever it is set to. At Full (0) every frame is a visual frame; at 30 or
-- 15 a second only frames at least that far apart are. Decided once per frame (GetTime() doesn't change
-- within one), so every icon and bar moves on the same frames.
private.visualAt = nil
private.visualDue = true
private.lastVisual = nil
private.throttled = false
private.VisualDue = function()
	local rate = CDTL3.db.profile.global["updateRate"]
	if not rate or rate <= 0 then
		private.throttled = false
		return true
	end
	private.throttled = true
	local now = GetTime()
	if now ~= private.visualAt then
		private.visualAt = now
		local last = private.lastVisual
		-- a little slack so 30 a second at 60 fps is every other frame, not every third
		if not last or now - last >= 1 / rate - 0.002 or now < last then
			private.lastVisual = now
			private.visualDue = true
		else
			private.visualDue = false
		end
	end
	return private.visualDue
end

-- a lane faded to nothing: alpha 0 and not fading in
private.LaneFaded = function(lane)
	if lane:GetAlpha() ~= 0 then
		return false
	end
	local fadeIn = lane.animateIn
	return not (fadeIn and fadeIn:IsPlaying())
end

-- An icon on a lane: whether to slide it and redo its texts this frame, and whether its texts must be
-- redone now. Forced on the first frame after it (re)starts on a lane (SendToLane resets updateCount)
-- and after RefreshIcon re-centred it, so it never shows out of place. Pause while hidden: while its
-- lane is faded to nothing it skips them, and catches up, texts too, on the first frame the lane shows.
private.IconVisual = function(f, ic, s)
	local due = private.VisualDue()
	if s["pauseHidden"] and private.LaneFaded(ic:GetParent()) then
		ic.visualPaused = true
		return false, false
	end
	local force = (ic.visualPaused or f.updateCount == 0) and true or false
	local place = ic.placeNow
	ic.visualPaused = nil
	ic.placeNow = nil
	return (due or force or place) and true or false, force
end

-- Below Full a text's poll counts in time, not frames (the frames it would skip are skipped): it is due
-- once as long has passed as its poll takes at 60 frames a second.
private.TextDueByTime = function(f, tf, s)
	local interval = nil
	if s["dtags"] then
		interval = private.dynamicTextPollRate / 60
	end
	if s["ttags"] then
		local timeRate = private.timeTextPollRate
		if f.data["currentCD"] > 10 then
			timeRate = timeRate * 3
		end
		if not interval or timeRate / 60 < interval then
			interval = timeRate / 60
		end
	end
	if not interval then
		return false
	end
	local last = tf.cdtlTextAt
	return not last or GetTime() - last >= interval - 0.002
end

private.BarUpdate = function(f, elapsed)
	local d = f.data
	local ba = f.bar
	ba.currentCD = d["currentCD"]

	local p = ba:GetParent():GetName()
	if CDTL3:SlotOfParent(p) == "barFrames" then
		if d["currentCD"] > 0 then
			local s = CDTL3:SlotSettings("barFrames", d["barFrame"])

			local pBase = d["baseCD"]
			local pCurrent = d["currentCD"]
			-- a riding cooldown's bar drains from the game's timer (CombatTimers.lua)
			local CT = CDTL3.CombatTimers
			local riding = CT and CT:Riding(f)

			-- an item whose cooldown hasn't been read yet shows no bar (see the ITEMS poll)
			if d["itemUnread"] then
				if ba.valid then
					ba.valid = false
					ba:GetParent().triggerUpdate = true
				end
				return
			end

			-- "Transition bars" hides a bar once its cooldown is under the lane's Max Time. With the
			-- option off (or no lane), a bar it hid earlier comes back: it used to stay hidden until
			-- a /reload, so unticking the option looked like it did nothing. A lane that's switched
			-- off counts as no lane: its icons have nowhere to show, so its bars stay.
			local lane = CDTL3:SlotSettings("lanes", d["lane"])
			local laneOn = lane and lane["enabled"]
			if (not laneOn or not s["transition"]["hideTransitioned"]) and not ba.valid
				and d["enabled"] and not d["ignored"] then
				ba.valid = true
				ba:GetParent().triggerUpdate = true
			end

			if not laneOn then
				-- For now, do nothing
			else
				if s["transition"]["hideTransitioned"] then
					--CDTL3:Print(tostring(d["currentCD"]).." - "..tostring(ba.transitionThreshold))
					if d["currentCD"] > ba.transitionThreshold then
						if not ba.valid then
							ba.valid = true
							ba:GetParent().triggerUpdate = true
						end

						if s["transition"]["style"] == "SHORTEN" and not riding then
							pBase = pBase - ba.transitionThreshold
							pCurrent = pCurrent - ba.transitionThreshold
						end
					else
						if ba.valid then
							ba.valid = false
							ba:GetParent().triggerUpdate = true
						end
					end
				end
			end

			-- the fill, its colour and the texts follow the Update rate (and the first frame after a restart)
			if private.VisualDue() or f.updateCount == 0 then
				if not (riding and CT:DriveBar(f)) then
					local iconPercent = private.CalcLinearPosition(pCurrent, pBase)
					ba.bar:SetValue(iconPercent)
				end

				private.UpdateBarDynamicColor(ba, s, d)

				if ba:GetAlpha() ~= 0 and ba.txt then
					private.UpdateText(f, ba.txt.text1, s["bar"]["text1"], s["bar"]["text1"]["text"])
					private.UpdateText(f, ba.txt.text2, s["bar"]["text2"], s["bar"]["text2"]["text"])
					private.UpdateText(f, ba.txt.text3, s["bar"]["text3"], s["bar"]["text3"]["text"])
				end
			end
		else
			CDTL3:SendToBarHolding(f)
		end
	end
end

private.CalcLinearPosition = function(current, total, s)
	local p = 1

	if current < total then
		p = current / total
	end

	return p
end

-- a split lane's marks by number: the value and the position of each (mode.split / mode.splitAbs)
private.SPLIT_VALUES = { "s1v", "s2v", "s3v", "s4v", "s5v" }
private.SPLIT_POSITIONS = { "s1p", "s2p", "s3p", "s4p", "s5p" }

private.CalcSplitPosition = function(current, total, s)
	local p = 1
	local max = 100
	local value = (current / total) * 100

	-- the lane's split settings: mode.split or mode.splitAbs (nil in any other mode; only Split lanes call this)
	local ss = s["mode"][private.splitModeKeys[s["mode"]["type"]] or ""]
	local abs = s["mode"]["type"] == "SPLIT_ABS"
	if s["mode"]["type"] == "SPLIT" then
		if total > ss["max"] then
			total = ss["max"]
		end
	elseif abs then
		max = ss["max"]
		value = current
		total = ss["max"]
	end

	-- Split (Time): only the marks inside Max Time split the lane (a 10m mark on a 3:00 lane does not)
	local splits = nil
	if abs then
		splits = CDTL3:SplitAbsCount(ss)
	else
		splits = CDTL3:SplitCount(ss)
	end

	if current < total then
		if abs and splits == 0 then
			-- Split (Time) with no mark inside Max Time: a straight line to it
			p = current / total
		elseif splits and splits >= 1 and splits <= #private.SPLIT_VALUES then
			-- the stretch from the highest mark value is past to the next mark (past the last mark: to
			-- max, at 1); under the first mark, the stretch up to it. Checked from the last mark down.
			local k = splits
			local toV, toP = max, 1
			while k > 1 and not (value > ss[private.SPLIT_VALUES[k]]) do
				toV, toP = ss[private.SPLIT_VALUES[k]], ss[private.SPLIT_POSITIONS[k]]
				k = k - 1
			end
			local markV, markP = ss[private.SPLIT_VALUES[k]], ss[private.SPLIT_POSITIONS[k]]

			local rPercent, rSize
			if value > markV then
				rPercent = toV - markV
				rSize = toP - markP
			else
				rPercent = markV
				rSize = markP
			end
			local cPercent = value - markV
			local aPercent = cPercent / rPercent
			p = markP + (rSize * aPercent)
		end
	end

	return p
end
-- shared with CombatTimers.lua, whose split-lane curves sample it
CDTL3.CalcSplitPosition = private.CalcSplitPosition

private.CalcTransitionIndicator = function(f, s)
	local ls = CDTL3:SlotSettings("lanes", f.data["lane"])

	if ls then
		-- the lane's settings for its mode (mode.linear, mode.linearAbs, ...)
		local ms = ls["mode"][private.modeKeys[ls["mode"]["type"]] or ""]

		f.bar.transitionThreshold = ms["max"]

		-- INDICATOR: only on a bar that will hand off to its lane (the lane is on, Transition bars is
		-- on and the cooldown is longer than the lane's Max Time), and never past the bar's end. A
		-- 1 minute spell on a 5 minute lane put its line five bar widths out to the right, over
		-- other frames; a bar whose lane is off never hands off at all.
		local position = 0
		local width = s["transition"]["width"]
		local baseCD = f.data["baseCD"] or 0
		local handsOff = ls["enabled"] and s["transition"]["hideTransitioned"] and (baseCD <= 0 or baseCD > ms["max"])
		if s["transition"]["showTI"] and handsOff then
			local style = s["transition"]["style"]

			if style == "SHORTEN" then
				f.bar.bar.ti:SetAlpha(0)
			else
				if style == "LINE" then
					local bWidth = s["width"] - width
					if s["bar"]["iconEnabled"] then
						bWidth = bWidth - s["height"]
					end

					--position = (ms["max"] / f.data["baseCD"]) * bWidth
					position = baseCD > 0 and math.min(ms["max"] / baseCD, 1) * bWidth or bWidth
				elseif style == "REGION" then
					-- same zero guard as LINE: a not-yet-learned cooldown (baseCD 0) spans the bar
					local percent = baseCD > 0 and math.min(ms["max"] / baseCD, 1) or 1

					local bWidth = s["width"] - width
					if s["bar"]["iconEnabled"] then
						bWidth = bWidth - s["height"]
					end

					width = bWidth * percent
					position = percent / 2
				end

				if f.bar.bar.ti then
					f.bar.bar.ti:SetAlpha(1)
				end
			end
		else
			if f.bar.bar.ti then
				f.bar.bar.ti:SetAlpha(0)
			end
		end

		if f.bar.bar.ti then
			f.bar.bar.ti:ClearAllPoints()
			f.bar.bar.ti:SetPoint("LEFT", position, 0)
			f.bar.bar.ti:SetSize(width, s["height"])
			CDTL3:SetBarTexture(f.bar.bar.ti.bg, s["transition"]["texture"])
			f.bar.bar.ti.bg:SetAllPoints(true)
			f.bar.bar.ti.bg:SetVertexColor(
				s["transition"]["textureColor"]["r"],
				s["transition"]["textureColor"]["g"],
				s["transition"]["textureColor"]["b"],
				s["transition"]["textureColor"]["a"]
			)
		end
	else
		if f.bar.bar.ti then
			f.bar.bar.ti:SetAlpha(0)
		end

		f.bar.transitionThreshold = 10000000
	end
end

-- Start of a spell running on its Custom CD Time. A spell the game gives no cooldown (a
-- seal) reports a start of 0, so count from the last cast. A real start from the game wins.
private.CustomCDStart = function(d, start)
	if not start or start == 0 then
		local castTime = CDTL3.spellCastTimes and CDTL3.spellCastTimes[d["id"]]
		if castTime then
			return castTime
		end
	end

	return start
end

-- A spell counting down: every frame, and re-read from the game on the first frame and every 50th
-- (not while overridden). True on the frames it was re-read.
private.SpellCountdown = function(f, d, elapsed)
	if d["currentCD"] >= 0 then
		d["currentCD"] = d["currentCD"] - elapsed

		if not d["overrideCD"] then
			if f.updateCount == 0 or f.updateCount % 50 == 0 then
				if d["setCustomCD"] then
					if d["customCDTime"] then
						d["baseCD"] = d["customCDTime"] / 1000
					end
				end

				local start, duration = CDTL3:GetSpellCooldown(d["id"])
				-- Manual override wins: the live Midnight duration is the talent-blind base
				-- CD, so when a custom CD is set, drive the countdown from that instead.
				if d["setCustomCD"] and d["customCDTime"] then
					d["baseCD"] = d["customCDTime"] / 1000
					duration = d["baseCD"]
					start = private.CustomCDStart(d, start)
				end
				d["currentCD"] = start + duration - GetTime()
				return true
			end
		end
	end
	return false
end

private.CooldownUpdate = function(f, elapsed)
	local d = f.data
	local ic = f.icon
	local ba = f.bar

	-- Guard: f.bar (ba) can be nil if CreateCooldown was interrupted before
	-- the bar was created.  Skip this tick rather than throwing 1000+ errors.
	if not ic or not ba then return end

	local icVisible = ic:IsVisible()
	local baVisible = ba:IsVisible()
	local CT = CDTL3.CombatTimers

	if icVisible or baVisible then
		-- SPELLS
		if d["type"] == "spells" or d["type"] == "petspells" then
			if d["oaf"] then
				-- On-aura-fade spells (e.g. Stealth) hold their cooldown while the aura is up,
				-- during a channel, or while the game reports the cooldown disabled. Checked on
				-- the 50-frame poll and cached: the aura scan is too costly for every frame,
				-- and the countdown re-syncs from the game on the same poll, so nothing drifts.
				-- enabled is a boolean on retail-API clients and 0/1 on Classic.
				if f.updateCount == 0 or f.updateCount % 50 == 0 or d["oafHeld"] == nil then
					local auraUp = CDTL3:AuraExists("player", d["name"])
					local channelOK, channeling = pcall(function()
						return UnitChannelInfo("player") and true or false
					end)
					local _, _, enabled = CDTL3:GetSpellCooldown(d["id"])
					-- the game's own hold: the effect is up, or the cooldown is reported not started
					local gameHeld = (auraUp or enabled == 0 or enabled == false) and true or false

					-- The cooldown really starts when the game's hold ends, not at the cast. Record
					-- that as the spell's start for GetSpellCooldown's secret-value fallback
					-- (Helpers.lua), which counts from the cast time it finds here: a Stealth
					-- opener after 20s of stealth showed Ready with 10s left. Readable timing still
					-- wins, since the fallback only runs while it's secret. A channel alone doesn't
					-- count, so channelling mid-cooldown doesn't restart it.
					if d["oafGameHeld"] and not gameHeld then
						if not CDTL3.spellCastTimes then CDTL3.spellCastTimes = {} end
						CDTL3.spellCastTimes[d["id"]] = GetTime()
					end

					d["oafGameHeld"] = gameHeld
					d["oafHeld"] = (gameHeld or (channelOK and channeling)) and true or false
				end

				if not d["oafHeld"] then
					private.SpellCountdown(f, d, elapsed)
				end
			else
				if private.SpellCountdown(f, d, elapsed) then
					CDTL3.IconFx:PollCharges(f)	-- charge pips: the icon rides the recharge (IconFx.lua)

					if f.updateCount == 0 and CDTL3.db.profile.global["detectSharedCD"] then
						CDTL3:ScanSharedSpellCooldown(d["name"], d["currentCD"])
					end
				end
			end

		-- ITEMS
		elseif d["type"] == "items" then
			if f.updateCount % 50 == 0 then
				-- An item saved without a cooldown yet (bCD 0) learns it, and whether it's
				-- ignored, while it's counting down: from any positive, readable read, and from
				-- a readable 0 only right after its use (see below). nil (secret) teaches
				-- nothing. A ready item waits for its next use.
				if d["baseCD"] == 0 and d["currentCD"] >= 0 then
					d["currentCD"] = 1000

					-- nil while the item cooldown is secret: decide nothing yet, retry next poll
					local duration = nil
					local read = false
					local tinker, slot = CDTL3:CheckEngTinkerCases(d["name"])
					if tinker then
						local _, spellID = CDTL3.Compat.GetItemSpell(d["itemID"])
						if spellID == d["id"] then
							local _
							_, duration = CDTL3:GetInventoryItemCooldown(slot)
							read = true
						end
					else
						local _
						_, duration = CDTL3:GetItemCooldown(d["itemID"])
						read = true
					end

					-- While it's secret the item shows nothing (IconUpdate, BarUpdate): the 1000 above
					-- only keeps this poll going, it isn't a timer. It used to show as a full bar
					-- reading 16:40 until combat ended.
					d["itemUnread"] = read and duration == nil

					-- A 0 read means "no cooldown" (food, drink: saved as ignored) only when it's
					-- taken within a moment of the use, which the use handler records as the
					-- cast time: a real cooldown would already show. A later 0, e.g. the first
					-- readable read after a cooldown that stayed secret until it ran out (WoW:
					-- Forever, in combat), teaches nothing: it used to hide the item for good.
					local usedAt = CDTL3.spellCastTimes and CDTL3.spellCastTimes[d["id"]]
					local justUsed = usedAt and GetTime() - usedAt <= private.itemNoCooldownWindow

					if duration and (duration > 0 or justUsed) then
						d["baseCD"] = duration
						CDTL3:SetItemData(d["itemID"], "bCD", duration * 1000)

						if d["baseCD"] > 3 and d["baseCD"] <= CDTL3.db.profile.global["items"]["ignoreThreshold"] then
							d["ignored"] = false
							CDTL3:SetItemData(d["itemID"], "ignored", false)
						else
							if not d["ignored"] then
								CDTL3:NoteAutoIgnore({ name = d["name"], itemName = d["itemName"], bCD = duration * 1000 }, "items")
							end
							d["ignored"] = true
							CDTL3:SetItemData(d["itemID"], "ignored", true)

							CDTL3:SendToHolding(f)
							CDTL3:SendToBarHolding(f)
						end
					end
				end
			end

			d["currentCD"] = d["currentCD"] - elapsed
			if d["currentCD"] >= 0 then
				if f.updateCount % 50 == 0 then
					local tinker, slot = CDTL3:CheckEngTinkerCases(d["name"])
					if tinker then
						local _, spellID = CDTL3.Compat.GetItemSpell(d["itemID"])
						if spellID == d["id"] then
							--local start, duration, enabled = GetInventoryItemCooldown("player", slot)
							--d["baseCD"] = duration
							--d["currentCD"] = start + duration - GetTime()

							local start, duration = CDTL3:GetInventoryItemCooldown(slot)
							if start and duration then
								-- a 0 read means ready: it ends the countdown but doesn't unlearn the cooldown
								if duration > 0 then
									d["baseCD"] = duration
								end
								d["currentCD"] = start + duration - GetTime()
							end
						end
					else
						local start, duration = CDTL3:GetItemCooldown(d["itemID"])
						if duration and start then
							if duration > 0 then
								d["baseCD"] = duration
							end
							d["currentCD"] = start + duration - GetTime()
						end
					end
				end
			end

		-- AURAS
		elseif d["type"] == "buffs" or d["type"] == "debuffs" then
			if f.updateCount == 0 or f.updateCount % 50 == 0 then
				local s, unknown = CDTL3:AuraExists("player", d["name"])
				if s then
					d["currentCD"] = s["endTime"] - GetTime()
					d["stacks"] = s["stacks"]
				elseif unknown then
					-- Auras are secret (combat, encounters, M+, PvP): keep counting down from
					-- the last known expiry instead of dropping the icon. Re-read once
					-- readable; PLAYER_REGEN_ENABLED also rescans for recasts made meanwhile.
					if d["currentCD"] >= 0 then
						d["currentCD"] = d["currentCD"] - elapsed
					end
				else
					d["currentCD"] = -1
				end
			else
				if d["currentCD"] >= 0 then
					d["currentCD"] = d["currentCD"] - elapsed
				end
			end

		-- OFFENSIVES
		elseif d["type"] == "offensives" then
			if f.updateCount == 0 or f.updateCount % 50 == 0 then
				if d["baseCD"] == 0 then
					local s = CDTL3:AuraExists("target", d["name"])
					if s then
						d["baseCD"] = s["bCD"] / 1000
						d["currentCD"] = s["endTime"] - GetTime()
						d["stacks"] = s["stacks"]

						CDTL3:SetSpellData(d["name"], "offensives", "bCD", s["bCD"])

						-- the live cooldown's flag (d), not the throwaway aura table, decides visibility
						if d["baseCD"] > 3 and d["baseCD"] <= CDTL3.db.profile.global["offensives"]["ignoreThreshold"] then
							d["ignored"] = false
							CDTL3:SetSpellData(d["name"], "offensives", "ignored", false)
						else
							if not d["ignored"] then
								CDTL3:NoteAutoIgnore({ name = d["name"], bCD = s["bCD"] }, "offensives")
							end
							d["ignored"] = true
							CDTL3:SetSpellData(d["name"], "offensives", "ignored", true)

							CDTL3:SendToHolding(f)
							CDTL3:SendToBarHolding(f)
						end
					end
				end
			end

			-- count down every frame (the poll used to skip it once every 50 frames)
			if d["currentCD"] >= 0 then
				d["currentCD"] = d["currentCD"] - elapsed
			end

		-- CUSTOMS
		elseif d["type"] == "customs" then
			d["currentCD"] = d["currentCD"] - elapsed

		-- FLIGHTS (Flights.lua): counts down, and waits at the end until the flight lands
		elseif d["type"] == "flights" then
			d["currentCD"] = d["currentCD"] - elapsed
			if CDTL3.Flights then
				CDTL3.Flights:Hold(f)
			end

		-- TIMERS FROM OTHER ADDONS (API.lua): counted against their end time
		elseif d["timerEnd"] then
			d["currentCD"] = d["timerEnd"] - GetTime()

		-- RUNES
		elseif d["type"] == "runes" then
			d["currentCD"] = d["currentCD"] - elapsed

		-- TEST/UTILITY
		elseif d["type"] == "testing" or d["type"] == "spacer" then
			d["currentCD"] = d["currentCD"] - elapsed
		end

		-- combat timers (CombatTimers.lua): starts/ends riding, may end or hold the estimate
		if CT then
			CT:Update(f, elapsed)
		end

		if icVisible then
			private.IconUpdate(f, elapsed)
		end

		if baVisible then
			private.BarUpdate(f, elapsed)
		end

		-- an icon parked in holding (lane set to Hide, bar only) has no Ready frame to end in
		CDTL3:FireTimerIfHeldOver(f)
	elseif CT and f.ct and f.ct.riding then
		-- moved off its lane and bar frame: stop riding
		CT:Update(f, elapsed)
	end

	f.updateCount = f.updateCount + 1

	if f.updateCount > 12000 then
		f.updateCount = 1
	end

	private.ShowHide(f)
end

-- A riding icon's position is hidden from addons (it hangs off a fill fed a hidden value), so
-- its mouse-over test may error or come back hidden: treat that as "not over".
private.IsMouseOver = function(ic)
	if not ic.ctRiding then
		return ic:IsMouseOver()
	end
	local ok, over = pcall(ic.IsMouseOver, ic)
	if not ok or (issecretvalue and issecretvalue(over)) then
		return false
	end
	return over
end

private.IconUpdate = function(f, elapsed)
	local d = f.data
	local ic = f.icon
	ic.currentCD = d["currentCD"]
	ic.pinned = d["pinned"]
	-- an effect on a target (Group.lua) draws its strip on the spell's icon while one is live
	if CDTL3.effectsLive then
		CDTL3:EffectStripTick(f)
	end

	local group = CDTL3:SlotOfParent(ic:GetParent():GetName())
	if group == "lanes" then
		if d["currentCD"] > 0 then
			local s = CDTL3:SlotSettings("lanes", d["lane"])

			local iconPercent = 1
			local mode = s["mode"]["type"]
			local max = nil
			local hideTimeSurplus = nil

			if mode == "LINEAR" then
				max = s["mode"]["linear"]["max"]
				hideTimeSurplus = s["mode"]["linear"]["hideTimeSurplus"]

				local baseCD = d["baseCD"]
				if d["baseCD"] > max then
					baseCD = max
				end

				iconPercent = private.CalcLinearPosition(d["currentCD"], baseCD, s)
			elseif mode == "LINEAR_ABS" then
				max = s["mode"]["linearAbs"]["max"]
				hideTimeSurplus = s["mode"]["linearAbs"]["hideTimeSurplus"]
				iconPercent = private.CalcLinearPosition(d["currentCD"], max, s)
			elseif mode == "SPLIT" then
				max = s["mode"]["split"]["max"]
				hideTimeSurplus = s["mode"]["split"]["hideTimeSurplus"]

				local baseCD = d["baseCD"]
				if d["baseCD"] > max then
					baseCD = max
				end

				iconPercent = private.CalcSplitPosition(d["currentCD"], baseCD, s)
			elseif mode == "SPLIT_ABS" then
				max = s["mode"]["splitAbs"]["max"]
				hideTimeSurplus = s["mode"]["splitAbs"]["hideTimeSurplus"]

				iconPercent = private.CalcSplitPosition(d["currentCD"], d["baseCD"], s)
			end

			if d["itemUnread"] then
				-- an item whose cooldown hasn't been read yet shows nothing (see the ITEMS poll)
				if ic.valid then
					ic.valid = false
					ic:GetParent().triggerUpdate = true
				end
			elseif d["currentCD"] > max then
				-- a flight always shows: it often runs past a lane's Max Time
				if hideTimeSurplus == true and d["type"] ~= "flights" then
					if ic.valid then
						ic.valid = false
						ic:GetParent().triggerUpdate = true
					end
				else
					if not ic.valid then
						ic.valid = true
						ic:GetParent().triggerUpdate = true
					end
				end
			else
				if not ic.valid then
					ic.valid = true
					ic:GetParent().triggerUpdate = true
				end
			end

			-- charge pips, the ready-soon pulse, buff alerts, GCD waits (IconFx.lua)
			if CDTL3.IconFx:LaneIcon(f, ic, s, d) then
				return	-- it went to its Ready frame to wait out the GCD
			end

			-- the slide and the texts follow the Update rate and Pause while hidden (IconVisual)
			local visual, force = private.IconVisual(f, ic, s)

			-- a riding icon follows its rider's fill edge instead (CombatTimers.lua)
			local CT = CDTL3.CombatTimers
			if visual and not (ic.ctRiding and CT and CT:PlaceIcon(f, s, mode, max)) then
				local iconPosition = (s["width"] - s["icons"]["size"]) * iconPercent

				local anchor = "LEFT"
				if s["vertical"] then
					if s["reversed"] then
						anchor = "TOP"
						iconPosition = -iconPosition
					else
						anchor = "BOTTOM"
					end

					ic:ClearAllPoints()
					ic:SetPoint(anchor, ic.yOffset + ic.sOffset, iconPosition)
				else
					if s["reversed"] then
						anchor = "RIGHT"
						iconPosition = -iconPosition
					end

					ic:ClearAllPoints()
					ic:SetPoint(anchor, iconPosition, ic.yOffset + ic.sOffset)
					ic:SetPoint(anchor, iconPosition, ic.yOffset + ic.sOffset)
				end
			end

			if visual and ic:GetAlpha() ~= 0 then
				if ic.txt then
					private.UpdateText(f, ic.txt.text1, s["icons"]["text1"], s["icons"]["text1"]["text"], force)
					private.UpdateText(f, ic.txt.text2, s["icons"]["text2"], s["icons"]["text2"]["text"], force)
					private.UpdateText(f, ic.txt.text3, s["icons"]["text3"], s["icons"]["text3"]["text"], force)
				end
			end

			if CDTL3.db.profile.global["enableTooltip"] then
				if private.IsMouseOver(ic) then
					-- build the tooltip once per hover, not every frame
					if d.link and not (GameTooltip:IsOwned(ic) and GameTooltip:IsShown()) then
						GameTooltip_SetDefaultAnchor(GameTooltip, ic)
						GameTooltip:SetHyperlink(d.link)
						CDTL3:EstimateTooltip(f)
						GameTooltip:Show()
					end
				else
					if GameTooltip:IsOwned(ic) then
						GameTooltip:Hide()
					end
				end
			end

			if s["stacking"]["raiseOnMouseOver"] then
				if private.IsMouseOver(ic) then
					ic:SetFrameStrata("HIGH")
				else
					ic:SetFrameStrata("MEDIUM")
				end
			end
		else
			if d["type"] == "spacer" then

			elseif d["type"] == "test" then

			else
				CDTL3.IconFx:Ended(f)	-- a buff that was up: the lane flash (IconFx.lua)
				-- Finish effect: played once at the lane's Ready end as the icon leaves it (IconFx.lua)
				CDTL3.IconFx:Finish(f, ic, CDTL3:SlotSettings("lanes", d["lane"]))
				CDTL3:FireTimer("CDTL3_TimerReady", f)
				CDTL3:SendToReady(f)
				CDTL3:FireTimerIfHeld(f)
				-- a setup preview's sample (Start.lua) with no Ready frame to wait in starts again at once
				if d["sampleLoop"] and ic:GetParent():GetName() == "CDTL3_Active_Icon_Holding" then
					CDTL3:SendToLane(f)
					CDTL3:SendToBarFrame(f)
				end
			end
		end
	elseif group == "ready" then
		-- a GCD wait ends here, and the lane's pips and pulse go (IconFx.lua)
		CDTL3.IconFx:ReadyFrame(f, ic)

		if ic.readyTime > 0 then
			-- an icon waiting out the GCD holds its time until the wait is over
			if not f.data["pinned"] and not ic.fxGCD then
				ic.readyTime = ic.readyTime - elapsed
			end

			if CDTL3.db.profile.global["enableTooltip"] then
				if ic:IsMouseOver() then
					-- build the tooltip once per hover, not every frame
					if d.link and not (GameTooltip:IsOwned(ic) and GameTooltip:IsShown()) then
						GameTooltip_SetDefaultAnchor(GameTooltip, ic)
						GameTooltip:SetHyperlink(d.link)
						CDTL3:EstimateTooltip(f)
						GameTooltip:Show()
					end
				else
					if GameTooltip:IsOwned(ic) then
						GameTooltip:Hide()
					end
				end
			end
		else
			CDTL3:FireTimer("CDTL3_TimerEnded", f)
			if d["type"] == "testing" then
				-- Test Panel's Loop, or a setup preview's sample (Start.lua): starts again
				if CDTL3.db.profile.global["testingLoop"] or d["sampleLoop"] then
					CDTL3:SendToLane(f)
					CDTL3:SendToBarFrame(f)
				else
					CDTL3:SendToHolding(f)
				end
			else
				CDTL3:SendToHolding(f)
			end
		end
	else
		-- Do Nothing
	end

	if CDTL3.db.profile.global["notUsableTint"] then
		if f.data["type"] == "spells" or f.data["type"] == "petspells" then
			local _, noPower = CDTL3:IsUsableSpell(f.data["id"])
			if noPower then
				if CDTL3.db.profile.global["notUsableDesaturate"] then
					ic.tx:SetDesaturated(1)
				else
					ic.tx:SetDesaturated(nil)
					ic.tx:SetVertexColor(
						CDTL3.db.profile.global["notUsableColor"]["r"],
						CDTL3.db.profile.global["notUsableColor"]["g"],
						CDTL3.db.profile.global["notUsableColor"]["b"],
						CDTL3.db.profile.global["notUsableColor"]["a"]
					)
				end
			else
				ic.tx:SetDesaturated(nil)
				ic.tx:SetVertexColor(1, 1, 1, 1)
			end
		end
	end
end

function CDTL3:SendToBarFrame(f)
	local ba = f.bar

	-- bar frame 1-3, while it exists: its mover frame (CDTL3_BarFrame_n_MF); anything else: holding
	local mf = CDTL3:SlotParent("barFrames", f.data["barFrame"])
	if mf then
		ba:GetParent().triggerUpdate = true
		ba:SetParent(mf)
		mf.triggerUpdate = true
	else
		CDTL3:SendToBarHolding(f)
	end

	CDTL3:RefreshBar(f)
end

-- the holding frames are made by name in Holders.lua (CreateHolders)
function CDTL3:SendToBarHolding(f)
	local ba = f.bar

	if f.data["type"] == "offensives" then
		ba:GetParent().triggerUpdate = true
		ba:SetParent(_G["CDTL3_Offensive_Bar_Holding"])
	else
		ba:GetParent().triggerUpdate = true
		ba:SetParent(_G["CDTL3_Bar_Holding"])
	end

	CDTL3:RefreshBar(f)
end

function CDTL3:SendToHolding(f)
	local ic = f.icon

	if f.data["type"] == "offensives" then
		ic:GetParent().triggerUpdate = true
		ic:SetParent(_G["CDTL3_Offensive_Icon_Holding"])
		f.data["overrideCD"] = false
	else
		ic:GetParent().triggerUpdate = true
		ic:SetParent(_G["CDTL3_Active_Icon_Holding"])
		f.data["overrideCD"] = false
		--ic:Hide()
	end

	if GameTooltip:IsOwned(ic) then
		GameTooltip:Hide()
	end

	CDTL3:RefreshIcon(f)
end

function CDTL3:SendToLane(f)
	local ic = f.icon

	-- lane 1-3, while it exists: the lane itself (CDTL3_Lane_n); anything else: holding
	local lane = CDTL3:SlotParent("lanes", f.data["lane"])
	if lane then
		ic:GetParent().triggerUpdate = true
		ic:SetParent(lane)
		lane.triggerUpdate = true
	else
		CDTL3:SendToHolding(f)
	end

	CDTL3:RefreshIcon(f)

	-- restart the poll counter so the next update re-syncs with the game immediately
	f.updateCount = 0
	-- (a timer from another addon starts partway through: pendingCD is what is left)
	f.data["currentCD"] = f.data["pendingCD"] or f.data["baseCD"]
	f.data["pendingCD"] = nil
	CDTL3:FireTimer("CDTL3_TimerStarted", f)
	CDTL3.IconFx:Started(f)
end

-- Move a cooldown to its (newly set) lane without restarting it. SendToLane restarts the
-- countdown, which is right for a cast but not for a settings change: on a finished icon it
-- restarted custom timers at full length, played a ready sound per icon, and made a ready
-- item read 0 and unlearn its cooldown. An icon still counting down moves and keeps its
-- remaining time; a finished one stays put and uses the new lane from its next use.
function CDTL3:MoveToLane(f)
	local remaining = f.data["currentCD"]
	if remaining and remaining > 0 then
		CDTL3.movingLane = true
		CDTL3:SendToLane(f)
		CDTL3.movingLane = nil
		f.data["currentCD"] = remaining
	end
end

-- Say a spell's name (Filters: Say its name when ready). Every client CDTL3 runs on documents
-- C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap) (destination was dropped in 12.0.0),
-- with the voice, rate and volume from the game's own text to speech settings, as Blizzard's
-- TextToSpeech_Speak does. The option hides where the call is missing.
function CDTL3:CanSpeak()
	return (C_VoiceChat and C_VoiceChat.SpeakText and C_TTSSettings and C_TTSSettings.GetVoiceOptionID) and true or false
end

function CDTL3:SpeakText(text)
	if not CDTL3:CanSpeak() or type(text) ~= "string" or text == "" then
		return false
	end

	local ok, err = pcall(function()
		-- the voice as Blizzard's TextToSpeech_GetSelectedVoice picks it: the option's ID only when
		-- an installed voice has it, else the first installed voice
		local voices = C_VoiceChat.GetTtsVoices and C_VoiceChat.GetTtsVoices()
		local optionID = C_TTSSettings.GetVoiceOptionID((Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard) or 0)
		local voiceID
		if type(voices) == "table" then
			for _, voice in ipairs(voices) do
				if voice.voiceID == optionID then
					voiceID = voice.voiceID
					break
				end
			end
			if voiceID == nil and voices[1] then
				voiceID = voices[1].voiceID
			end
		end
		if voiceID == nil then
			error("no text to speech voice installed")
		end

		local rate = C_TTSSettings.GetSpeechRate and C_TTSSettings.GetSpeechRate() or 0
		local volume = C_TTSSettings.GetSpeechVolume and C_TTSSettings.GetSpeechVolume() or 100
		C_VoiceChat.SpeakText(voiceID, text, rate, volume, false)
	end)
	if not ok then
		CDTL3:LogFailure("Say its name", err)
	end

	return ok
end

-- The saved Filters entry of a live cooldown (nil for test icons, flights and anything unsaved)
private.SavedEntry = function(d)
	local t = d["type"]
	if not (t and CDTL3.db.profile.tables[t]) then
		return nil
	end

	if t == "items" then
		return CDTL3:GetSpellSettings(d["itemName"] or d["name"], t, true)
	end
	return CDTL3:GetSpellSettings(d["name"], t)
end

-- Arriving in a Ready frame (s): the entry's own Ready sound if it has one (Filters: Own ready
-- sound), else the frame's Highlight or Normal Sound as before; its spoken name; and Flash when
-- ready for RefreshIcon. Mute ready sounds (Ready tab) silences the sounds and the name.
private.ReadyAlert = function(f, s)
	-- an icon waiting out the GCD in its Ready frame arrives silent (IconFx.lua)
	if CDTL3.IconFx.silent then
		return
	end

	local e = private.SavedEntry(f.data)
	f.data["readyLit"] = (e and e["readyFlash"]) and true or nil

	if CDTL3.db.profile.global["muteReadySounds"] then
		return
	end

	local sound
	if e and e["ownSound"] then
		sound = e["sound"] or "None"
	elseif f.data["highlight"] then
		sound = s["hSound"]
	else
		sound = s["nSound"]
	end
	if sound and sound ~= "None" then
		PlaySoundFile(CDTL3.LSM:Fetch("sound", sound) --[[@as string|number]], "SFX")
	end

	if e and e["sayName"] then
		CDTL3:SpeakText(f.data["type"] == "items" and f.data["itemName"] or f.data["name"])
	end
end

-- A switched-off Ready frame takes nothing (no sound, no icon waiting in the hidden frame). An icon
-- arriving is shown: one hidden on its lane for being over Max Time (Hide time surplus) used to stay
-- hidden in the Ready frame after an early reset (Cold Snap, Preparation, Readiness). A highlighted
-- icon stays the Highlight Duration.
-- ReadyBoard.lua wraps this ("Stay until used" slots).
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:SendToReady(f)
	local ic = f.icon

	-- Ready frame 1-3, while it exists and is switched on: its mover frame (CDTL3_Ready_n_MF)
	local n = f.data["readyFrame"]
	local mf = CDTL3:SlotParent("ready", n)
	local s = CDTL3:SlotSettings("ready", n)
	if mf and s["enabled"] then
		ic:GetParent().triggerUpdate = true
		ic:SetParent(mf)
		ic.valid = true
		ic.readyTime = f.data["highlight"] and s["hTime"] or s["nTime"]

		private.ReadyAlert(f, s)

		-- CDTL3_Ready_n is made together with its mover frame (Ready.lua)
		local ready = CDTL3:SlotFrame("ready", n) --[[@as table]]
		ready.combatTimer = 0
		mf.triggerUpdate = true
		f.data["overrideCD"] = false
	else
		CDTL3:SendToHolding(f)
	end

	CDTL3:RefreshIcon(f)
end

private.ShowHide = function(f)
	if f.data["ignored"] then
		f.icon.valid = false
		f.bar.valid = false

		if CDTL3.db.profile.global["debugMode"] then
			f.bar:SetAlpha(0.35)
			f.icon:SetAlpha(0.35)
		else
			f.bar:SetAlpha(0)
			f.icon:SetAlpha(0)
		end
	else
		if f.data["enabled"] then
			-- ICONS
			if f.icon.valid then
				f.icon:SetAlpha(1)
			else
				if CDTL3.db.profile.global["debugMode"] then
					f.icon:SetAlpha(0.35)
				else
					f.icon:SetAlpha(0)
				end
			end
			-- BARS
			if f.bar.valid then
				f.bar:SetAlpha(1)
			else
				if CDTL3.db.profile.global["debugMode"] then
					f.bar:SetAlpha(0.35)
				else
					f.bar:SetAlpha(0)
				end
			end
		else
			f.icon.valid = false
			f.bar.valid = false

			if CDTL3.db.profile.global["debugMode"] then
				f.bar:SetAlpha(0.35)
				f.icon:SetAlpha(0.35)
			else
				f.bar:SetAlpha(0)
				f.icon:SetAlpha(0)
			end
		end
	end
end

-- force: redo a text with tags now (an icon back from Pause while hidden, or just restarted)
private.UpdateText = function(f, tf, s, iString, force)
	-- combat timers (CombatTimers.lua): an estimated buff's text is dimmed, and a riding
	-- cooldown's [cd.time]-only text follows the game's timer
	local CT = CDTL3.CombatTimers
	if CT then
		CT:DimText(f, tf)
		if f.ct and f.ct.riding and CT:OwnsText(f, tf, s) then
			return
		end
	end
	-- an estimated flight time is dimmed too (Flights.lua)
	if CDTL3.Flights then
		CDTL3.Flights:DimText(f, tf)
	end

	if s["enabled"] then
		-- dynamic tags poll at their rate, time tags faster in the last 10s; whenever
		-- either is due the whole text is converted (all tag families in one pass)
		local due = false
		if private.throttled then
			due = private.TextDueByTime(f, tf, s)
		else
			if s["dtags"] and f.updateCount % private.dynamicTextPollRate == 0 then
				due = true
			end

			if s["ttags"] then
				local timeRate = private.timeTextPollRate
				if f.data["currentCD"] > 10 then
					timeRate = timeRate * 3
				end
				if f.updateCount % timeRate == 0 then
					due = true
				end
			end
		end
		if force and (s["dtags"] or s["ttags"]) then
			due = true
		end

		if due then
			if private.throttled then
				tf.cdtlTextAt = GetTime()
			end
			tf:SetText(CDTL3:ConvertAllTextTags(s["text"], f))
		end
	end
end