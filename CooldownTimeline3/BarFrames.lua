--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}

function CDTL3:CreateBarFrames()
	for i = 1, 3 do
		if CDTL3:SlotSettings("barFrames", i)["enabled"] then
			if CDTL3:SlotFrame("barFrames", i) then
				CDTL3:RefreshBarFrame(i)
			else
				private.CreateBarFrame(i)
			end
		end
	end
end

function CDTL3:RefreshBarFrame(i)
	local f = CDTL3:SlotFrame("barFrames", i)
	local s = CDTL3:SlotSettings("barFrames", i)

	if not f then
		return
	end

	CDTL3:RefreshStackFrame(f, s, "barFrames")
end

private.CreateBarFrame = function(frameNumber)
	local f = CDTL3:CreateStackFrame("barFrames", frameNumber, "CDTL3_BarFrame_"..frameNumber, private.BarFrameUpdate)

	CDTL3:RefreshBarFrame(frameNumber)
	table.insert(CDTL3.barFrames, f)
end

private.BarFrameUpdate = function(f, elapsed)
	local s = CDTL3:SlotSettings("barFrames", f.number)

	f.forceShow = false

	-- UPDATE
	if f.mf.triggerUpdate then
		f.childCount = CDTL3:StackChildren(f, s, "barFrames")

		if s["enabled"] then
			CDTL3:Autohide(f, s)
		else
			f:SetAlpha(0)
		end

		f.mf.triggerUpdate = false
	end

	if f:GetAlpha() ~= 0 then
		-- FRAME (UN)LOCKING (a frame on another frame keeps its screen position; a drag sets its offset)
		if CDTL3.db.profile.global["unlockFrames"] and not f.cdtl3AnchoredTo then
			local _, _, relativeTo, xOfs, yOfs = f:GetPoint()

			s["relativeTo"] = relativeTo
			s["posX"] = xOfs
			s["posY"] = yOfs
		end
	end

	-- UPDATE COUNT
	--[[f.updateCount = f.updateCount + 1
	if f.updateCount > 12000 then
		f.updateCount = 1
	end]]--
end

---------------------------------------------------------------- shared with Ready.lua
-- Bar frames and ready frames hold their bars or icons in a mover frame (f.mf) and are built,
-- refreshed and stacked the same way. By group ("barFrames" or "ready"): the size of one bar or
-- icon, and the gaps between them.
private.CELLS = {
	barFrames = function(s)
		return s["width"], s["height"], s["bar"]["xPadding"], s["bar"]["yPadding"]
	end,
	ready = function(s)
		return s["icons"]["size"], s["icons"]["size"], s["icons"]["xPadding"], s["icons"]["yPadding"]
	end,
}

-- A bar frame or ready frame named frameName: the frame, its mover frame and its debug box (f.db),
-- dragged as its group, with onUpdate(f, elapsed) every frame. The caller adds its own fields, then
-- refreshes it.
function CDTL3:CreateStackFrame(group, frameNumber, frameName, onUpdate)
	local f = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

	f.number = frameNumber
	f.childCount = 0
	f.validChildren = {}
	f.overrideAutohide = false

	f.mf = CreateFrame("Frame", frameName.."_MF", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	-- f is a Frame; the optional template argument makes the definitions give a union
	---@diagnostic disable-next-line: param-type-mismatch
	f.mf:SetParent(f)
	f.mf.bg = f.mf:CreateTexture(nil, "BACKGROUND")

	f.currentCount = 0
	f.previousCount = 0
	f.mf.triggerUpdate = false

	f.db = CreateFrame("Frame", frameName.."_DB", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	-- f is a Frame; the optional template argument makes the definitions give a union
	---@diagnostic disable-next-line: param-type-mismatch
	f.db:SetParent(f)
	f.db.bg = f.db:CreateTexture(nil, "BACKGROUND")
	f.db.text = f.db:CreateFontString(nil,"ARTWORK")

	-- ON UPDATE
	f:HookScript("OnUpdate", function(frame, elapsed)
		onUpdate(frame, elapsed)
	end)

	-- DRAG AND DROP MOVEMENT
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", function(frame) CDTL3:FrameDragStop(frame, group) end)

	return f
end

-- Refresh a bar frame or ready frame from its settings: its name, place and size (one bar or icon),
-- background, border and fades, then its debug box and the rest (CDTL3:FinishFrameRefresh).
function CDTL3:RefreshStackFrame(f, s, group)
	local width, height = private.CELLS[group](s)

	f.name = s["name"]

	-- the screen position, or on the frame it is anchored to (Anchors.lua)
	CDTL3:PlaceFrame(f, s, group)
	f:SetSize(width, height)

	f.mf:ClearAllPoints()
	f.mf:SetPoint("CENTER", 0, 0)
	f.mf:SetSize(width, height)

	-- MOVE FRAME BACKGROUND
	CDTL3:SetBarTexture(f.mf.bg, s["bgTexture"])
	f.mf.bg:SetAllPoints(true)
	f.mf.bg:SetVertexColor(
		s["bgTextureColor"]["r"],
		s["bgTextureColor"]["g"],
		s["bgTextureColor"]["b"],
		s["bgTextureColor"]["a"]
	)

	-- BORDER
	if s["border"]["style"] ~= "None" then
		if not f.mf.bd then
			f.mf.bd = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.mf.bd:SetParent(f)
		end

		CDTL3:SetBorder(f.mf.bd, s["border"])
		f.mf.bd:SetFrameLevel(f.mf:GetFrameLevel() + 1)
		f.mf.bd:Show()
	else
		if f.mf.bd then
			f.mf.bd:Hide()
		end
	end

	-- ANIMATION
	CDTL3:SetFadeAnimations(f, s["alpha"] or 1, s)

	-- DEBUG/UNLOCK
	f.db:SetSize(width + (s["padding"] * 2), height + (s["padding"] * 2))
	CDTL3:FinishFrameRefresh(f, s)
end

-- Stack the bars or icons showing in the mover frame (f.mf) one after another the way s.grow says,
-- and size and place f.mf around them; they become f.validChildren. Returns how many show.
function CDTL3:StackChildren(f, s, group)
	local children = { f.mf:GetChildren() }
	f.validChildren = {}

	local count = 0
	for _, child in ipairs(children) do
		if child.valid then
			if child:GetAlpha() ~= 0 then
				count = count + 1
				table.insert(f.validChildren, child)
			end
		end
	end

	local bWidth, bHeight, bPadX, bPadY = private.CELLS[group](s)
	local fPad = s["padding"]

	local mfSizeX = bWidth + (fPad * 2)
	local mfSizeY = bHeight + (fPad * 2)
	local xInset = 0
	local yInset = 0
	local xOffset = 0
	local yOffset = 0
	local xMod = 0
	local yMod = 0
	local mfAnchor = "CENTER"

	if count == 1 then
		f.validChildren[1]:ClearAllPoints()
		f.validChildren[1]:SetPoint("CENTER", xOffset, yOffset)
	elseif count > 1 then
		local anchor = "TOP"

		if s["grow"] == "UP" then
			mfAnchor = "BOTTOM"
			anchor = "BOTTOM"
			xInset = (-bPadX * (count - 1)) / 2
			yInset = fPad
			xMod = 0
			yMod = 1

			mfSizeX = bWidth + (fPad * 2) + (math.abs(bPadX) * (count - 1))
			mfSizeY = (bHeight * count) + (fPad * 2) + (bPadY * (count - 1))
			yOffset = -fPad

		elseif s["grow"] == "DOWN" then
			mfAnchor = "TOP"
			anchor = "TOP"
			xInset = (-bPadX * (count - 1)) / 2
			yInset = -fPad
			xMod = 0
			yMod = -1

			mfSizeX = bWidth + (fPad * 2) + (math.abs(bPadX) * (count - 1))
			mfSizeY = (bHeight * count) + (fPad * 2) + (-bPadY * (count - 1))
			yOffset = fPad

		elseif s["grow"] == "LEFT" then
			mfAnchor = "RIGHT"
			anchor = "LEFT"
			xInset = fPad
			yInset = (-bPadY * (count - 1)) / 2
			xMod = 1
			yMod = 0

			mfSizeX = (bWidth * count) + (fPad * 2) + (bPadX * (count - 1))
			mfSizeY = bHeight + (fPad * 2) + (math.abs(bPadY) * (count - 1))
			xOffset = fPad

		elseif s["grow"] == "RIGHT" then
			mfAnchor = "LEFT"
			anchor = "RIGHT"
			xInset = -fPad
			yInset = (-bPadY * (count - 1)) / 2
			xMod = -1
			yMod = 0

			mfSizeX = (bWidth * count) + (fPad * 2) + (-bPadX * (count - 1))
			mfSizeY = bHeight + (fPad * 2) + (math.abs(bPadY) * (count - 1))
			xOffset = -fPad

		elseif s["grow"] == "CENTER_V" then
			mfAnchor = "CENTER"
			anchor = "BOTTOM"
			xInset = (-bPadX * (count - 1)) / 2
			yInset = fPad
			xMod = 0
			yMod = 1

			mfSizeX = bWidth + (fPad * 2) + (math.abs(bPadX) * (count - 1))
			mfSizeY = (bHeight * count) + (fPad * 2) + (bPadY * (count - 1))

		elseif s["grow"] == "CENTER_H" then
			mfAnchor = "CENTER"
			anchor = "LEFT"
			xInset = fPad
			yInset = (-bPadY * (count - 1)) / 2
			xMod = 1
			yMod = 0

			mfSizeX = (bWidth * count) + (fPad * 2) + (bPadX * (count - 1))
			mfSizeY = bHeight + (fPad * 2) + (math.abs(bPadY) * (count - 1))

		end

		for k, child in ipairs(f.validChildren) do
			local x = (bWidth * (k - 1) * xMod) + (bPadX * (k - 1))
			local y = (bHeight * (k - 1) * yMod) + (bPadY * (k - 1))

			child:ClearAllPoints()
			child:SetPoint(anchor, x + xInset, y + yInset)
		end
	end

	f.mf:SetSize(mfSizeX, mfSizeY)
	f.mf:ClearAllPoints()
	f.mf:SetPoint(mfAnchor, xOffset, yOffset)

	return count
end
