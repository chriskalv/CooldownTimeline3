--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}

function CDTL3:CreateReadyFrames()
	for i = 1, 3 do
		if CDTL3:SlotSettings("ready", i)["enabled"] then
			if CDTL3:SlotFrame("ready", i) then
				CDTL3:RefreshReady(i)
			else
				private.CreateReady(i)
			end
		end
	end
end

private.CreateReady = function(frameNumber)
	local f = CDTL3:CreateStackFrame("ready", frameNumber, "CDTL3_Ready_"..frameNumber, private.ReadyUpdate)
	f.combatTimer = 0
	f.forceHide = false

	CDTL3:RefreshReady(frameNumber)
	table.insert(CDTL3.readyFrames, f)
end

-- every icon showing in the frame is pinned (IconUpdate keeps each icon's pinned flag current)
private.OnlyPinned = function(f)
	for _, child in ipairs(f.validChildren) do
		if not child.pinned then
			return false
		end
	end
	return true
end

private.ReadyUpdate = function(f, elapsed)
	local s = CDTL3:SlotSettings("ready", f.number)

	-- Pinned Hide Time (with Auto-hide Frames): out of combat, a frame holding only pinned icons hides
	-- pTime after combat ends or its last icon arrives; an icon with Normal or Highlight Duration left
	-- keeps it showing. Autohide only runs on an update, so a change asks for one (the flag was set
	-- after the only Autohide call that reads it: never hid).
	-- (a Stay until used board, ReadyBoard.lua, keeps its frame up)
	local forceHide = (not CDTL3.combat and f.combatTimer >= s["pTime"] and not f.boardOn and private.OnlyPinned(f)) and true or false
	if forceHide ~= f.forceHide then
		f.forceHide = forceHide
		f.mf.triggerUpdate = true
	end

	-- UPDATE
	if f.mf.triggerUpdate then
		f.childCount = CDTL3:StackChildren(f, s, "ready") + (f.boardCount or 0)

		if s["enabled"] then
			CDTL3:Autohide(f, s)
		else
			f:SetAlpha(0)
		end

		f.mf.triggerUpdate = false
	end

	if f:GetAlpha() ~= 0 then
		if not CDTL3.combat then
			if f.combatTimer < s["pTime"] then
				f.combatTimer = f.combatTimer + elapsed
			end
		end

		-- FRAME (UN)LOCKING (a frame on another frame keeps its screen position; a drag sets its offset)
		if CDTL3.db.profile.global["unlockFrames"] and not f.cdtl3AnchoredTo then
			local _, _, relativeTo, xOfs, yOfs = f:GetPoint()

			s["relativeTo"] = relativeTo
			s["posX"] = xOfs
			s["posY"] = yOfs
		end
	end
end

-- ReadyBoard.lua wraps this on purpose: its version calls this one first
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:RefreshReady(i)
	local f = CDTL3:SlotFrame("ready", i)
	local s = CDTL3:SlotSettings("ready", i)

	if not f then
		return
	end

	CDTL3:RefreshStackFrame(f, s, "ready")
end