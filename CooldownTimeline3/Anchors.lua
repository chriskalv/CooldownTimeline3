--[[
	Cooldown Timeline 3 - Anchor to: lanes, bar frames and ready frames placed on another frame

	Each lane, bar frame and ready frame has Anchor to: Screen (its x/y position, as before and
	by default), Player frame, the Cooldown Manager (where the client has one) or a frame typed
	by name, with a side and X/Y offsets. Only CDTL3's own frames move. The other frame is only
	read: looked up by name, asked whether it can be used and, after a drag, where it is. It is
	never moved, resized, hooked or written to.

	A frame that isn't there (yet) leaves ours at its screen position; it is looked for again
	when an addon loads, at each loading screen and every few seconds while one is missing.

	Unlock-and-drag and Edit Mode: moving an anchored frame changes its X/Y offset from the
	frame it is anchored to, and it stays anchored. Its screen position, and its Edit Mode
	layout positions, are kept as they were for when Anchor to goes back to Screen.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
local A = {}
CDTL3.Anchors = A

-- profile group -> settings key prefix and the name the chat line uses
A.KINDS = {
	lanes = { prefix = "lane", label = "Lane" },
	barFrames = { prefix = "frame", label = "Bar Frame" },
	ready = { prefix = "ready", label = "Ready Frame" },
}

-- side -> our point, their point
A.SIDES = {
	ABOVE = { "BOTTOM", "TOP" },
	BELOW = { "TOP", "BOTTOM" },
	LEFT = { "RIGHT", "LEFT" },
	RIGHT = { "LEFT", "RIGHT" },
	CENTER = { "CENTER", "CENTER" },
}

-- the X/Y offset sliders' ends; a drag is held to them, so the sliders always show the value
A.OFFSET_LIMIT = 2000

A.pending = {}	-- our frame -> its profile group, while the frame it is anchored to is missing
A.told = {}	-- one chat line per frame and name per session

A.Settings = function(kind, number)
	local k = A.KINDS[kind]
	local group = k and CDTL3.db and CDTL3.db.profile[kind]
	return group and number and group[k.prefix..number]
end

-- Does this lane / bar frame / ready frame ask to sit on another frame?
A.Anchored = function(s)
	local a = s and s["anchor"]
	return type(a) == "table" and a["to"] ~= nil and a["to"] ~= "SCREEN"
end

function CDTL3:IsAnchored(s)
	return A.Anchored(s)
end

A.HasCooldownManager = function()
	return C_CooldownViewer ~= nil or _G["EssentialCooldownViewer"] ~= nil
end

-- The global name of the frame the setting asks for, or nil while no name is typed
A.TargetName = function(a)
	if a["to"] == "PLAYER" then
		return "PlayerFrame"
	elseif a["to"] == "COOLDOWNS" then
		return "EssentialCooldownViewer"
	elseif a["to"] == "NAMED" then
		local name = type(a["frame"]) == "string" and strtrim(a["frame"]) or ""
		if name ~= "" then
			return name
		end
	end
end

-- The frame to anchor to, if it exists and may be used. Only read here: a forbidden frame, one
-- whose anchoring is restricted or one whose place reads back hidden (a secret value) is left alone.
A.Find = function(name, own)
	local t = name and _G[name]
	if type(t) ~= "table" or t == own or type(t.GetObjectType) ~= "function" then
		return nil
	end

	local ok, usable = pcall(function()
		if t.IsForbidden and t:IsForbidden() then
			return false
		end
		if t.IsAnchoringRestricted and t:IsAnchoringRestricted() then
			return false
		end
		if issecretvalue and t.GetLeft and issecretvalue(t:GetLeft()) then
			return false
		end
		return true
	end)

	if ok and usable then
		return t
	end
end

-- Place one of our frames: on the frame it is anchored to, or at its screen position (Screen,
-- or while that frame is missing). kind is its profile group ("lanes", "barFrames", "ready").
function CDTL3:PlaceFrame(f, s, kind)
	f:ClearAllPoints()
	f.cdtl3AnchoredTo = nil

	if A.Anchored(s) then
		local a = s["anchor"]
		local name = A.TargetName(a)
		local target = A.Find(name, f)
		local side = A.SIDES[a["side"]] or A.SIDES.ABOVE
		if target and pcall(f.SetPoint, f, side[1], target, side[2], tonumber(a["x"]) or 0, tonumber(a["y"]) or 0) then
			A.pending[f] = nil
			f.cdtl3AnchoredTo = target
			return true
		end

		-- not there yet (or it can't be used, e.g. it is anchored to this frame): the screen position
		f:ClearAllPoints()
		A.Wait(f, s, kind, name)
	else
		A.pending[f] = nil
	end

	f:SetPoint(s["relativeTo"], s["posX"], s["posY"])
	return false
end

-- Look again later, and say once in chat why the frame is at its screen position
A.Wait = function(f, s, kind, name)
	if not name then
		-- "A frame by name" with no name typed yet: nothing to wait for
		A.pending[f] = nil
		return
	end

	A.pending[f] = kind

	local key = tostring(f:GetName()).."|"..name
	if not A.told[key] then
		A.told[key] = true
		CDTL3:Print(string.format(L["%s can't find the frame \"%s\" yet, so it stays at its screen position and moves there once that frame appears."], tostring(s["name"]), name))
	end

	A.ScheduleRetry()
end

A.ScheduleRetry = function()
	if A.retrying then
		return
	end

	A.retrying = true
	C_Timer.After(5, function()
		A.retrying = false
		A.Retry()
	end)
end

A.Retry = function()
	local waiting = {}
	for f, kind in pairs(A.pending) do
		waiting[f] = kind
	end

	-- a frame is placed again only once there is something to anchor to, so one being dragged
	-- at its screen position isn't pulled back every few seconds
	for f, kind in pairs(waiting) do
		local s = A.Settings(kind, f.number)
		if s and A.Anchored(s) then
			if A.Find(A.TargetName(s["anchor"]), f) then
				CDTL3:PlaceFrame(f, s, kind)
			end
		else
			A.pending[f] = nil
		end
	end

	if next(A.pending) then
		A.ScheduleRetry()
	end
end

-- a frame another addon makes, or one that turns up after a loading screen
A.events = CreateFrame("Frame")
A.events:RegisterEvent("ADDON_LOADED")
A.events:RegisterEvent("PLAYER_ENTERING_WORLD")
A.events:SetScript("OnEvent", function()
	if next(A.pending) then
		A.Retry()
	end
end)

-- Where a point of a frame is on the screen, in pixels
local function PointOnScreen(frame, point)
	local left, bottom, width, height = frame:GetRect()
	local scale = frame:GetEffectiveScale()

	local x = left + width / 2
	if point:find("LEFT") then
		x = left
	elseif point:find("RIGHT") then
		x = left + width
	end

	local y = bottom + height / 2
	if point:find("TOP") then
		y = bottom + height
	elseif point:find("BOTTOM") then
		y = bottom
	end

	return x * scale, y * scale
end

-- f was moved by hand while anchored: its new X/Y offset from the frame it is anchored to,
-- whole numbers held to the sliders' ends. Reads only where the two frames are; a place that
-- can't be read (or isn't a plain number) leaves the offset as it was.
A.TakeOffset = function(f, s)
	local target = f.cdtl3AnchoredTo
	local a = s["anchor"]
	if not target or type(a) ~= "table" then
		return false
	end

	local side = A.SIDES[a["side"]] or A.SIDES.ABOVE
	local limit = A.OFFSET_LIMIT
	local ok, x, y = pcall(function()
		local fx, fy = PointOnScreen(f, side[1])
		local tx, ty = PointOnScreen(target, side[2])
		local scale = f:GetEffectiveScale()
		local dx, dy = (fx - tx) / scale, (fy - ty) / scale
		if dx ~= dx or dy ~= dy then
			return nil
		end
		dx = math.max(-limit, math.min(limit, math.floor(dx + 0.5)))
		dy = math.max(-limit, math.min(limit, math.floor(dy + 0.5)))
		return dx, dy
	end)

	if ok and x and y then
		a["x"], a["y"] = x, y
		return true
	end

	return false
end

-- Unlocked frames: a drag of an anchored frame sets its offset and keeps it anchored; any other
-- drag ends as it always has (the frame's update saves the screen position while unlocked)
function CDTL3:FrameDragStop(f, kind)
	f:StopMovingOrSizing()

	if f.cdtl3AnchoredTo then
		local s = A.Settings(kind, f.number)
		if s and A.Anchored(s) then
			A.TakeOffset(f, s)
			CDTL3:PlaceFrame(f, s, kind)
		end
	end
end

-- Edit Mode moved f (a drag, the arrow keys or Reset Position) while it is anchored to another
-- frame: it stays anchored at its new offset (Reset Position: no offset). True when handled, so
-- EditMode.lua leaves the layout's screen position as it was.
function CDTL3:AnchorMoved(f, s, kind, point, x, y, default)
	if not (f.cdtl3AnchoredTo and A.Anchored(s)) then
		return false
	end

	local reset = default and point == default.point
		and type(x) == "number" and type(y) == "number"
		and math.abs(x - (default.x or 0)) < 0.01 and math.abs(y - (default.y or 0)) < 0.01
	if reset then
		s["anchor"]["x"], s["anchor"]["y"] = 0, 0
	else
		A.TakeOffset(f, s)
	end

	CDTL3:PlaceFrame(f, s, kind)
	return true
end

-- OPTIONS: Anchor to, Frame name, Side, X offset, Y offset, added to a frame's Appearance args
-- at first .. first + 5. settings() returns the frame's live settings, refresh() re-places it.
-- The screen position controls (x / y Position, Anchor Point) are greyed out while it is anchored.
function CDTL3:AddAnchorArgs(args, first, settings, refresh, what)
	local function anchor()
		return settings()["anchor"]
	end
	local function onScreen()
		return not A.Anchored(settings())
	end

	args["anchorSpacer"] = {
		name = "",
		type = "description",
		order = first,
	}
	args["anchorTo"] = {
		name = L["Anchor to"],
		desc = string.format(L["What this %s sits on: the screen, or another frame (only CDTL3's own frames ever move)"], what),
		order = first + 1,
		type = "select",
		values = function()
				local v = { SCREEN = "Screen", PLAYER = "Player frame", NAMED = "A frame by name" }
				if A.HasCooldownManager() or anchor()["to"] == "COOLDOWNS" then
					v["COOLDOWNS"] = "Cooldown Manager"
				end
				return v
			end,
		sorting = function()
				if A.HasCooldownManager() or anchor()["to"] == "COOLDOWNS" then
					return { "SCREEN", "PLAYER", "COOLDOWNS", "NAMED" }
				end
				return { "SCREEN", "PLAYER", "NAMED" }
			end,
		get = function(info) return anchor()["to"] end,
		set = function(info, val)
				anchor()["to"] = val
				refresh()
			end,
	}
	args["anchorFrame"] = {
		name = L["Frame name"],
		desc = L["The other frame's name, as /fstack shows it when you point at it (for example ElvUF_Player)"],
		order = first + 2,
		type = "input",
		hidden = function(info) return anchor()["to"] ~= "NAMED" end,
		get = function(info) return anchor()["frame"] end,
		set = function(info, val)
				anchor()["frame"] = strtrim(tostring(val or ""))
				refresh()
			end,
	}
	args["anchorSide"] = {
		name = L["Side"],
		desc = string.format(L["Which side of the other frame this %s sits on"], what),
		order = first + 3,
		type = "select",
		values = { ABOVE = "Above", BELOW = "Below", LEFT = "Left", RIGHT = "Right", CENTER = "Centred on it" },
		sorting = { "ABOVE", "BELOW", "LEFT", "RIGHT", "CENTER" },
		hidden = onScreen,
		get = function(info) return anchor()["side"] end,
		set = function(info, val)
				anchor()["side"] = val
				refresh()
			end,
	}
	args["anchorX"] = {
		name = L["X offset"],
		desc = L["Moves it right from that side of the other frame (left below 0)"],
		order = first + 4,
		type = "range",
		min = -A.OFFSET_LIMIT,
		max = A.OFFSET_LIMIT,
		step = 1,
		hidden = onScreen,
		get = function(info) return anchor()["x"] end,
		set = function(info, val)
				anchor()["x"] = val
				refresh()
			end,
	}
	args["anchorY"] = {
		name = L["Y offset"],
		desc = L["Moves it up from that side of the other frame (down below 0)"],
		order = first + 5,
		type = "range",
		min = -A.OFFSET_LIMIT,
		max = A.OFFSET_LIMIT,
		step = 1,
		hidden = onScreen,
		get = function(info) return anchor()["y"] end,
		set = function(info, val)
				anchor()["y"] = val
				refresh()
			end,
	}

	for _, key in ipairs({ "posX", "posY", "relativeTo" }) do
		local o = args[key]
		if o and o.disabled == nil then
			o.disabled = function(info) return not onScreen() end
		end
	end
end
