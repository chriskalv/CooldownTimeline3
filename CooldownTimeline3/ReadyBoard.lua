--[[
	Ready frame mode "Stay until used" (feature panel card 28, "Stay-until-used column"). A Ready frame
	set to it holds a board: one fixed slot for each cooldown pinned to that Ready frame (Filters), in the
	frame's grow direction. A ready one is bright with its Ready text; one that is cooling is dimmed with
	its time left. The slot goes back to bright the moment the game says the cooldown is over.

	Whether a cooldown is running is never hidden from addons (CombatTimers.lua ends a hidden cooldown
	from isActive), so ready or cooling reads right in combat on every client. The time left on a cooling
	slot follows the game's own timer where the cooldown rides it (Retail and WoW: Forever, in combat),
	else the countdown the addon keeps, and is an estimate marked "~" when it can't be read.

	A cooldown's frame only exists once it has been used, so the board is built from the saved entries
	(CDTL3:CollectPinned, FightTimeline.lua) and a slot reads ready until its cooldown is running. The
	pinned icons themselves no longer wait in the Ready frame while it is in this mode (the board shows
	them); everything else (sounds, other icons) works as before. A cooldown has to be on a lane or a bar
	frame to be counted down, as always.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")

local RD = {}
CDTL3.ReadyBoard = RD
local private = {}

private.MAXSLOTS = 12
private.TICK = 0.12
private.LIST_EVERY = 0.5
private.TIME_TEXT = { enabled = true, text = "[cd.time]" }
private.ANCHORS = { UP = "BOTTOM", DOWN = "TOP", LEFT = "RIGHT", RIGHT = "LEFT", CENTER_H = "CENTER", CENTER_V = "CENTER" }

-- 1:42, 18, 4.2
private.Clock = function(t)
	if t >= 60 then
		t = math.floor(t + 0.5)
		return string.format("%d:%02d", math.floor(t / 60), t % 60)
	elseif t >= 10 then
		return string.format("%d", math.floor(t + 0.5))
	end
	return string.format("%.1f", t)
end

-- seconds left. A cooldown riding the game's own timer is never read: its time is the cast plus its
-- base cooldown (an estimate, true as the second value).
private.Left = function(cd)
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
	return d["currentCD"], false
end

-- running now? One that hasn't been used yet has no frame; one that isn't on a lane or bar frame
-- (parked in holding) isn't counted down: both read ready.
private.Cooling = function(cd)
	if not cd or not (cd.icon:IsVisible() or cd.bar:IsVisible()) then
		return false
	end
	return cd.data["currentCD"] > 0
end

---------------------------------------------------------------- the board
private.FontPath = function(name)
	return CDTL3.LSM:Fetch("font", name) or STANDARD_TEXT_FONT
end

private.NewSlot = function(b)
	local slot = CreateFrame("Frame", nil, b)
	slot.tx = slot:CreateTexture(nil, "BACKGROUND")
	slot.tx:SetAllPoints(true)
	slot.dim = slot:CreateTexture(nil, "ARTWORK")
	slot.dim:SetAllPoints(true)
	slot.dim:SetColorTexture(10 / 255, 12 / 255, 14 / 255, 0.6)
	slot.name = slot:CreateFontString(nil, "OVERLAY")
	slot.state = slot:CreateFontString(nil, "OVERLAY")
	return slot
end

private.Style = function(fs, ts, slot)
	fs:ClearAllPoints()
	fs:SetPoint(ts["align"], slot, ts["anchor"], ts["offX"], ts["offY"])
	local outline = ts["outline"]
	if type(outline) ~= "string" or outline == "NONE" or outline == "" then
		outline = nil
	end
	local size = tonumber(ts["size"]) or 0
	if size > 0 then
		fs:SetFont(private.FontPath(ts["font"]), size, outline)
	end
	fs:SetTextColor(ts["color"]["r"], ts["color"]["g"], ts["color"]["b"], ts["color"]["a"])
	fs:SetShadowColor(ts["shadColor"]["r"], ts["shadColor"]["g"], ts["shadColor"]["b"], ts["shadColor"]["a"])
	fs:SetShadowOffset(ts["shadX"], ts["shadY"])
	fs:SetShown(ts["enabled"] and true or false)
end

-- this Ready frame's pinned entries into b.tmp / b.tmpKinds; true (and swapped in) when they differ from b.list
private.Collect = function(f, b)
	local n = CDTL3:CollectPinned(b.tmp, b.tmpKinds, f.number, private.MAXSLOTS)

	local same = (n == b.count)
	if same then
		for k = 1, n do
			if b.tmp[k] ~= b.list[k] or b.tmpKinds[k] ~= b.kinds[k] then
				same = false
				break
			end
		end
	end
	if same then
		return false
	end

	b.tmp, b.list = b.list, b.tmp
	b.tmpKinds, b.kinds = b.kinds, b.tmpKinds
	b.count = n
	return true
end

private.Layout = function(f, b, s)
	local size = s["icons"]["size"]
	local px, py = s["icons"]["xPadding"], s["icons"]["yPadding"]
	local pad = s["padding"]
	local grow = s["grow"]
	local n = b.count
	local column = (grow == "UP" or grow == "DOWN" or grow == "CENTER_V")
	-- the same sign rules as the Ready frame's own icons
	local stepX = size + ((grow == "LEFT") and px or -px)
	local stepY = size + ((grow == "UP") and py or -py)
	local zoom = CDTL3.db.profile.global["zoom"]
	local tl, br = zoom - 1, 1 - (zoom - 1)

	for k = 1, private.MAXSLOTS do
		local slot = b.slots[k]
		local e = b.list[k]
		if not e or k > n then
			slot:Hide()
			slot.e, slot.cd = nil, nil
		else
			local kind = b.kinds[k]
			slot.e, slot.kind, slot.cd = e, kind, CDTL3:GetExistingCooldown(e["name"], kind)
			slot.cooling = nil
			slot.last = nil
			slot:SetSize(size, size)
			slot:ClearAllPoints()
			if column then
				slot:SetPoint("TOPLEFT", b, "TOPLEFT", pad, -(pad + (k - 1) * stepY))
			else
				slot:SetPoint("TOPLEFT", b, "TOPLEFT", pad + (k - 1) * stepX, -pad)
			end

			slot.tx:SetTexture((kind == "items" and e["itemIcon"]) or e["icon"])
			slot.tx:SetTexCoord(tl, br, tl, br)

			-- the texts' tags read a cooldown's data: the saved entry stands in until it has a frame
			local stand = slot.cd or { data = { name = e["name"], itemName = e["itemName"], type = kind, stacks = 0, currentCD = 0 } }
			private.Style(slot.name, s["icons"]["text1"], slot)
			private.Style(slot.state, s["icons"]["text2"], slot)
			slot.name:SetText(CDTL3:ConvertAllTextTags(s["icons"]["text1"]["text"], stand))
			slot.readyText = CDTL3:ConvertAllTextTags(s["icons"]["text2"]["text"], stand)
			slot:Show()
		end
	end

	local w, h
	if column then
		w = size + 2 * pad
		h = math.max(n, 1) * size + 2 * pad + (math.max(n, 1) - 1) * (stepY - size)
	else
		w = math.max(n, 1) * size + 2 * pad + (math.max(n, 1) - 1) * (stepX - size)
		h = size + 2 * pad
	end
	b:SetSize(w, h)

	local at = private.ANCHORS[grow] or "TOP"
	b:ClearAllPoints()
	b:SetPoint(at, f, at, 0, 0)

	-- the Ready frame counts the board's slots (Ready.lua), so Auto-hide Frames keeps it up
	f.boardCount = n
	f.mf.triggerUpdate = true
end

-- every slot, a few times a second
private.Slots = function(b)
	local CT = CDTL3.CombatTimers
	for k = 1, b.count do
		local slot = b.slots[k]
		if slot.e then
			-- a cooldown's frame appears when it is first used
			local cd = slot.cd
			if not cd then
				cd = CDTL3:GetExistingCooldown(slot.e["name"], slot.kind)
				slot.cd = cd
			end

			local cooling = private.Cooling(cd)
			if cooling ~= slot.cooling then
				slot.cooling = cooling
				slot.last = nil
				slot.tx:SetDesaturated(cooling and true or false)
				slot.dim:SetShown(cooling and true or false)
				if not cooling then
					slot.state:SetText(slot.readyText or "")
				end
			end

			if cooling then
				if CT and cd.ct and cd.ct.riding and CT:OwnsText(cd, slot.state, private.TIME_TEXT) then
					slot.last = nil	-- the game's own timer is writing it
				else
					local left, estimate = private.Left(cd)
					local text = private.Clock(math.max(left, 0))
					if estimate then
						text = "~" .. text
					end
					if text ~= slot.last then
						slot.last = text
						slot.state:SetText(text)
					end
				end
			end
		end
	end
end

private.BoardTick = function(b, elapsed)
	b.acc = b.acc + elapsed
	if b.acc < private.TICK then
		return
	end
	b.acc = 0

	local f = b.ready
	local s = CDTL3.db and CDTL3.db.profile.ready["ready" .. f.number]
	if not s then
		return
	end

	b.listAcc = b.listAcc + private.TICK
	if b.listAcc >= private.LIST_EVERY then
		b.listAcc = 0
		if private.Collect(f, b) then
			private.Layout(f, b, s)
		end
	end

	local ok, err = pcall(private.Slots, b)
	if not ok then
		CDTL3:LogFailure("ReadyBoard.Slots", err)
	end
end

private.Build = function(f)
	local b = CreateFrame("Frame", f:GetName() .. "_Board", f)
	b.ready = f
	b.acc = 0
	b.listAcc = 0
	b.count = 0
	b.list, b.kinds, b.tmp, b.tmpKinds, b.slots = {}, {}, {}, {}, {}
	b.bg = b:CreateTexture(nil, "BACKGROUND")
	b.bg:SetAllPoints(true)
	for k = 1, private.MAXSLOTS do
		b.slots[k] = private.NewSlot(b)
	end
	b:SetScript("OnUpdate", private.BoardTick)
	f.board = b
	return b
end

-- the pinned icons of this Ready frame: into holding while the board shows them, back into Ready when the mode ends
private.Hand = function(f, toBoard)
	local s = CDTL3.db.profile.ready["ready" .. f.number]
	for _, cd in pairs(CDTL3.cooldowns) do
		local d = cd.data
		if d["pinned"] and d["readyFrame"] == f.number then
			local ic = cd.icon
			if toBoard then
				if ic:GetParent() == f.mf then
					CDTL3:SendToHolding(cd)
				end
			elseif d["currentCD"] <= 0 and ic:GetParent() == CDTL3_Active_Icon_Holding and d["enabled"] and not d["ignored"] then
				-- ready and waiting: back in the frame, without a second ready sound
				ic:GetParent().triggerUpdate = true
				ic:SetParent(f.mf)
				ic.valid = true
				ic.readyTime = d["highlight"] and s["hTime"] or s["nTime"]
				f.combatTimer = 0
				f.mf.triggerUpdate = true
				CDTL3:RefreshIcon(cd)
			end
		end
	end
end

function RD.Refresh(i)
	local f = _G["CDTL3_Ready_" .. i]
	local s = CDTL3.db and CDTL3.db.profile.ready["ready" .. i]
	if not f or not s then
		return
	end

	local on = s["mode"] == "STAY" and s["enabled"]
	if not on then
		if f.boardOn then
			f.boardOn = nil
			f.boardCount = 0
			f.board:Hide()
			private.Hand(f, false)
			f.mf.triggerUpdate = true
		end
		return
	end

	local b = f.board or private.Build(f)
	local first = not f.boardOn
	f.boardOn = true

	CDTL3:SetBarTexture(b.bg, s["bgTexture"])
	b.bg:SetVertexColor(s["bgTextureColor"]["r"], s["bgTextureColor"]["g"], s["bgTextureColor"]["b"], s["bgTextureColor"]["a"])

	-- lay out afresh (the settings may have changed): forget what was collected
	b.count = -1
	b.listAcc = 0
	b:Show()
	private.Collect(f, b)
	private.Layout(f, b, s)
	if first then
		private.Hand(f, true)
	end
end

local refreshReady = CDTL3.RefreshReady
function CDTL3:RefreshReady(i)
	refreshReady(self, i)
	RD.Refresh(i)
end

-- a pinned icon that would wait in the Ready frame goes to holding instead (the sound has played)
local sendToReady = CDTL3.SendToReady
function CDTL3:SendToReady(cd)
	sendToReady(self, cd)

	local d = cd.data
	local n = d["readyFrame"]
	local f = n and d["pinned"] and _G["CDTL3_Ready_" .. n]
	if f and f.boardOn and cd.icon:GetParent() == f.mf then
		CDTL3:SendToHolding(cd)
	end
end

---------------------------------------------------------------- options
-- Ready > Ready N > General, under Grow Direction
function CDTL3:AddReadyBoardArgs(args, ready, i)
	args["mode"] = {
		name = L["Mode"],
		desc = L["Normal: icons wait in the frame for their Normal Duration. Stay until used: the frame keeps a slot for each cooldown pinned to it, bright with its ready text while it is ready and dimmed with its time left while it cools. Whether it is ready stays right in combat on every client."],
		order = 202,
		type = "select",
		values = {
			["NORMAL"] = L["Normal"],
			["STAY"] = L["Stay until used"],
		},
		sorting = { "NORMAL", "STAY" },
		get = function(info) return ready["mode"] or "NORMAL" end,
		set = function(info, val)
				ready["mode"] = val
				CDTL3:RefreshReady(i)
			end,
	}
end
