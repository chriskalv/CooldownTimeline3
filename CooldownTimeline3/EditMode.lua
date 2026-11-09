--[[
	Cooldown Timeline 3 - Blizzard Edit Mode integration (LibEditMode)

	Lanes, bar frames and ready frames appear in Edit Mode: select one to drag it, use the
	dialog for quick size changes, or open the full CDTL3 settings for it. Positions are kept
	per Edit Mode layout (switching layout moves them too). LibEditMode is only bundled by the
	TOCs of clients that have Edit Mode; elsewhere (Classic Era) /cdtl3 unlock still works.
]]--

local LEM = LibStub("LibEditMode", true)
if not LEM then
	return
end

local private = {}

-- frame -> { group, key, number }
private.registered = {}

private.KINDS = {
	{ group = "lanes", prefix = "lane", list = "lanes", label = "Lane", tab = "lanes", sub = "lane" },
	{ group = "barFrames", prefix = "frame", list = "barFrames", label = "Bar Frame", tab = "barFrames", sub = "barFrame" },
	{ group = "ready", prefix = "ready", list = "readyFrames", label = "Ready Frame", tab = "ready", sub = "ready" },
}

private.Refresh = function(info)
	if info.group == "lanes" then
		CDTL3:RefreshLane(info.number)
	elseif info.group == "barFrames" then
		CDTL3:RefreshBarFrame(info.number)
		CDTL3:RefreshAllBars()
	else
		CDTL3:RefreshReady(info.number)
	end
end

private.Settings = function(info)
	return CDTL3.db.profile[info.group][info.key]
end

-- A frame was dragged in Edit Mode: remember it for this layout, and as its plain position
-- (what the options window and clients without Edit Mode use)
private.OnMoved = function(frame, layoutName, point, x, y)
	local info = private.registered[frame]
	if not info then
		return
	end

	local s = private.Settings(info)
	if layoutName then
		s["editMode"] = s["editMode"] or {}
		s["editMode"][layoutName] = { point = point, x = x, y = y }
	end
	s["relativeTo"], s["posX"], s["posY"] = point, x, y
end

-- Move every frame to where it was placed in this layout (a layout it was never placed in
-- keeps the current position)
private.ApplyLayout = function(layoutName)
	if not layoutName then
		return
	end

	for frame, info in pairs(private.registered) do
		local s = private.Settings(info)
		local pos = s["editMode"] and s["editMode"][layoutName]
		if pos then
			s["relativeTo"], s["posX"], s["posY"] = pos.point, pos.x, pos.y
			private.Refresh(info)
		end
	end
end

-- Quick size controls in the Edit Mode dialog; everything else is one click away
private.Slider = function(info, name, path, minValue, maxValue, extraRefresh)
	local function Get()
		local t = private.Settings(info)
		for i = 1, #path - 1 do
			t = t[path[i]]
		end
		return t, path[#path]
	end

	return {
		kind = LEM.SettingType.Slider,
		name = name,
		default = (function()
				local d = CDTL3.db.defaults.profile[info.group][info.key]
				for i = 1, #path do
					d = d and d[path[i]]
				end
				return d or minValue
			end)(),
		minValue = minValue,
		maxValue = maxValue,
		valueStep = 1,
		get = function(layoutName)
				local t, k = Get()
				return t[k]
			end,
		set = function(layoutName, value)
				local t, k = Get()
				t[k] = value
				private.Refresh(info)
				if extraRefresh then
					extraRefresh()
				end
			end,
	}
end

private.Register = function(frame, kind, number)
	if private.registered[frame] then
		return
	end

	local info = { group = kind.group, key = kind.prefix..number, number = number }
	private.registered[frame] = info

	local d = CDTL3.db.defaults.profile[kind.group][info.key]
	local default = { point = d["relativeTo"], x = d["posX"], y = d["posY"] }
	LEM:AddFrame(frame, private.OnMoved, default, "CDTL3: "..kind.label.." "..number)

	local settings
	if kind.group == "lanes" then
		settings = {
			private.Slider(info, "Width", { "width" }, 20, 1000),
			private.Slider(info, "Height", { "height" }, 1, 200),
			private.Slider(info, "Icon Size", { "icons", "size" }, 8, 128, function() CDTL3:RefreshAllIcons() end),
		}
	elseif kind.group == "barFrames" then
		settings = {
			private.Slider(info, "Bar Width", { "width" }, 20, 600),
			private.Slider(info, "Bar Height", { "height" }, 2, 100),
		}
	else
		settings = {
			private.Slider(info, "Icon Size", { "icons", "size" }, 8, 128, function() CDTL3:RefreshAllIcons() end),
		}
	end
	LEM:AddFrameSettings(frame, settings)

	LEM:AddFrameSettingsButtons(frame, {
		{
			text = "CDTL3 Settings",
			click = function()
					local dialog = LibStub("AceConfigDialog-3.0")
					dialog:Open("CDTL3")
					dialog:SelectGroup("CDTL3", kind.tab, kind.sub..number)
				end,
		},
	})

	-- a frame created after the layout loaded (e.g. a lane enabled later) still goes to its spot
	private.ApplyLayout(LEM:GetActiveLayoutName())
end

-- Register whatever lanes / bar frames / ready frames exist (they're created on demand)
function CDTL3:RegisterEditModeFrames()
	for _, kind in ipairs(private.KINDS) do
		for _, frame in pairs(CDTL3[kind.list] or {}) do
			if frame.number then
				private.Register(frame, kind, frame.number)
			end
		end
	end
end

hooksecurefunc(CDTL3, "CreateLanes", function() CDTL3:RegisterEditModeFrames() end)
hooksecurefunc(CDTL3, "CreateBarFrames", function() CDTL3:RegisterEditModeFrames() end)
hooksecurefunc(CDTL3, "CreateReadyFrames", function() CDTL3:RegisterEditModeFrames() end)

-- a profile switch puts back the profile's plain positions; re-apply this layout's
hooksecurefunc(CDTL3, "RefreshConfig", function()
	private.ApplyLayout(LEM:GetActiveLayoutName())
end)

LEM:RegisterCallback("layout", function(layoutName)
	private.ApplyLayout(layoutName)
end)

-- keep positions attached to a renamed layout; forget a deleted one
private.ForEachSettings = function(fn)
	for _, kind in ipairs(private.KINDS) do
		for n = 1, 3 do
			local s = CDTL3.db.profile[kind.group][kind.prefix..n]
			if s and s["editMode"] then
				fn(s["editMode"])
			end
		end
	end
end

LEM:RegisterCallback("rename", function(oldName, newName)
	private.ForEachSettings(function(positions)
		positions[newName], positions[oldName] = positions[oldName], nil
	end)
end)

LEM:RegisterCallback("delete", function(layoutName)
	private.ForEachSettings(function(positions)
		positions[layoutName] = nil
	end)
end)

-- Frames dragged with /cdtl3 unlock (outside Edit Mode) keep that spot in the current layout
hooksecurefunc(CDTL3, "ToggleFrameLock", function(_, quiet)
	local layoutName = LEM:GetActiveLayoutName()
	if quiet or not layoutName or CDTL3.db.profile.global["unlockFrames"] then
		return
	end

	for frame, info in pairs(private.registered) do
		local s = private.Settings(info)
		if s["editMode"] then
			s["editMode"][layoutName] = { point = s["relativeTo"], x = s["posX"], y = s["posY"] }
		end
	end
end)

-- Show the frames (with their name plates) while Edit Mode is open, as /cdtl3 unlock does,
-- and put the lock back afterwards
LEM:RegisterCallback("enter", function()
	if CDTL3.db and not CDTL3.db.profile.global["unlockFrames"] then
		private.unlockedForEditMode = true
		CDTL3:ToggleFrameLock(true)
	end
end)

LEM:RegisterCallback("exit", function()
	if private.unlockedForEditMode then
		private.unlockedForEditMode = false
		if CDTL3.db.profile.global["unlockFrames"] then
			CDTL3:ToggleFrameLock(true)
		end
	end
end)
