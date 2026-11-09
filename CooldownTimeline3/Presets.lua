--[[
	Cooldown Timeline 3 - appearance presets and "copy settings from"
]]--

local private = {}

-- One-pixel border for the Minimal preset (a plain white edge file tinted by the border colour)
CDTL3.LSM:Register("border", "CDTL3 Pixel", [[Interface\Buttons\WHITE8X8]])

-- The containers presets and copying work on: profile group, key prefix, count
private.GROUPS = {
	lanes = { prefix = "lane", count = 3 },
	barFrames = { prefix = "frame", count = 3 },
	ready = { prefix = "ready", count = 3 },
}

local function DeepCopy(t)
	if type(t) ~= "table" then
		return t
	end

	local c = {}
	for k, v in pairs(t) do
		c[k] = DeepCopy(v)
	end

	return c
end

-- What a settings table actually holds: AceDB keeps only values that differ from the
-- defaults (the rest come through a metatable), so walk the defaults as well as the
-- stored keys to see every effective value.
local function Effective(live, default)
	local out = {}

	if type(default) == "table" then
		for k, d in pairs(default) do
			local v = live[k]
			if type(v) == "table" then
				out[k] = Effective(v, d)
			else
				out[k] = v
			end
		end
	end

	for k, v in pairs(live) do
		if out[k] == nil then
			out[k] = type(v) == "table" and Effective(v, nil) or v
		end
	end

	return out
end

-- Write values into an existing settings table, merging into sub-tables so the tables the
-- options window and frames hold on to stay the same ones
local function WriteInto(target, values, skip)
	for k, v in pairs(values) do
		if not (skip and skip[k]) then
			if type(v) == "table" and type(target[k]) == "table" and not v["r"] then
				WriteInto(target[k], v)
			else
				target[k] = DeepCopy(v)
			end
		end
	end
end

private.Defaults = function(group, key)
	return CDTL3.db.defaults and CDTL3.db.defaults.profile[group] and CDTL3.db.defaults.profile[group][key]
end

-- COPY SETTINGS
-- Everything except what identifies the target: its name, whether it's shown, and where it is
private.KEEP_ON_COPY = { name = true, enabled = true, posX = true, posY = true, relativeTo = true, editMode = true }

function CDTL3:CopyFrameSettings(group, from, to)
	local p = CDTL3.db.profile[group]
	local prefix = private.GROUPS[group].prefix
	local src, dst = p[prefix..from], p[prefix..to]
	if not (src and dst) or from == to then
		return
	end

	WriteInto(dst, Effective(src, private.Defaults(group, prefix..from)), private.KEEP_ON_COPY)
	CDTL3:RefreshConfig()
end

-- PRESETS
-- A preset only touches looks: textures, colours, borders, fonts. Sizes, positions, modes and
-- what is tracked are left alone. Fields left out keep the current value.
--   fg / bg          bar and background textures (lane bars, bars, frame backgrounds)
--   bgColor          frame and bar background colour
--   border           frame borders (lanes, bar frames, ready frames, bars)
--   iconBorder       icon borders (lanes, ready frames)
--   highlightBorder  border style/size for highlighted icons (colour is kept)
--   font / outline   every text
--   classColor       lane and bar fill in the class colour
--   laneFg / barFg   override fg for lanes / bars only
CDTL3.presets = {
	{
		key = "classic",
		name = "CDTL3 Classic",
		desc = "The look CDTL3 ships with",
		classic = true,
	},
	{
		key = "minimal",
		name = "Minimal",
		desc = "Flat bars, dark backgrounds, one-pixel borders, class colours",
		fg = "Solid",
		bg = "Solid",
		bgColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.75 },
		border = { style = "CDTL3 Pixel", size = 1, padding = 1, color = { r = 0, g = 0, b = 0, a = 1 } },
		iconBorder = { style = "CDTL3 Pixel", size = 1, padding = 0, color = { r = 0, g = 0, b = 0, a = 1 } },
		highlightBorder = { style = "CDTL3 Pixel", size = 2, padding = 1 },
		font = "Fira Sans Condensed",
		outline = "OUTLINE",
		classColor = true,
	},
	{
		key = "modern",
		name = "Blizzard Modern",
		desc = "Blizzard's current unit-frame and cast bar art, tooltip borders, the game font",
		needsAtlas = "Blizzard Modern: Cast",
		laneFg = "Blizzard Modern: Health (tintable)",
		barFg = "Blizzard Modern: Cast",
		bg = "Solid",
		bgColor = { r = 0, g = 0, b = 0, a = 0.6 },
		border = { style = "Blizzard Tooltip", size = 12, padding = 3, color = { r = 0.8, g = 0.8, b = 0.8, a = 1 } },
		iconBorder = { style = "CDTL3 Pixel", size = 1, padding = 0, color = { r = 0, g = 0, b = 0, a = 1 } },
		highlightBorder = { style = "Blizzard Tooltip", size = 12, padding = 3 },
		font = "Friz Quadrata TT",
		outline = "OUTLINE",
		classColor = false,
	},
	{
		key = "class",
		name = "Class Colours",
		desc = "Only switches lane and bar fills to your class colour",
		classColor = true,
	},
}

-- Presets this client can show (Blizzard Modern needs the modern bar atlases)
function CDTL3:GetPresetList()
	local list = {}
	for _, preset in ipairs(CDTL3.presets) do
		if not preset.needsAtlas or (CDTL3.barAtlases and CDTL3.barAtlases[preset.needsAtlas]) then
			list[preset.key] = preset.name
		end
	end

	return list
end

local function Valid(mediaType, name)
	return name and (mediaType == "statusbar" and CDTL3.barAtlases and CDTL3.barAtlases[name] or CDTL3.LSM:IsValid(mediaType, name))
end

-- Walk one lane / bar frame / ready frame and apply the preset's looks
private.ApplyToContainer = function(preset, live, kind)
	local function SetTexture(t, key, name)
		if Valid("statusbar", name) then
			t[key] = name
		end
	end

	local function SetBorder(b, spec, keepColor)
		if not (spec and Valid("border", spec.style)) then
			return
		end

		b["style"] = spec.style
		b["size"] = spec.size or b["size"]
		b["padding"] = spec.padding or b["padding"]
		if spec.color and not keepColor then
			b["color"] = DeepCopy(spec.color)
		end
	end

	local function SetFonts(t)
		for k, v in pairs(t) do
			if type(v) == "table" and k:match("^text%d$") then
				if Valid("font", preset.font) then
					v["font"] = preset.font
				end
				if preset.outline then
					v["outline"] = preset.outline
				end
			end
		end
	end

	-- the container itself: background and border
	SetTexture(live, "bgTexture", preset.bg)
	if preset.bgColor then
		live["bgTextureColor"] = DeepCopy(preset.bgColor)
	end
	SetBorder(live["border"], preset.border)

	if kind == "lanes" then
		SetTexture(live, "fgTexture", preset.laneFg or preset.fg)
		SetTexture(live["tracking"], "stTexture", preset.laneFg or preset.fg)
		if preset.classColor ~= nil then
			live["fgClassColor"] = preset.classColor
		end
	elseif kind == "barFrames" then
		local bar = live["bar"]
		SetTexture(bar, "fgTexture", preset.barFg or preset.fg)
		SetTexture(bar, "bgTexture", preset.bg)
		SetTexture(live["transition"], "texture", preset.barFg or preset.fg)
		if preset.bgColor then
			bar["bgTextureColor"] = DeepCopy(preset.bgColor)
		end
		SetBorder(bar["border"], preset.iconBorder)
		if preset.classColor ~= nil then
			bar["fgClassColor"] = preset.classColor
		end
		SetFonts(bar)
	end

	local icons = live["icons"]
	if icons then
		SetBorder(icons["border"], preset.iconBorder)
		SetBorder(icons["highlight"]["border"], preset.highlightBorder, true)
		SetFonts(icons)
	end
	for _, block in ipairs({ "modeText", "customText" }) do
		if live[block] then
			SetFonts(live[block])
		end
	end
end

function CDTL3:ApplyPreset(key)
	local preset
	for _, p in ipairs(CDTL3.presets) do
		if p.key == key then
			preset = p
		end
	end
	if not preset then
		return
	end

	for group, g in pairs(private.GROUPS) do
		for n = 1, g.count do
			local live = CDTL3.db.profile[group][g.prefix..n]
			if preset.classic then
				local default = private.Defaults(group, g.prefix..n)
				if default then
					private.RestoreLooks(live, default, group)
				end
			else
				private.ApplyToContainer(preset, live, group)
			end
		end
	end

	CDTL3:RefreshConfig()
	CDTL3:Print("Applied the "..preset.name.." style.")
end

-- CDTL3 Classic: put back each container's shipped value for exactly the fields the other
-- presets change (ApplyToContainer), nothing else
private.RestoreLooks = function(live, d, kind)
	local function copy(t, dt, key)
		if t and dt and dt[key] ~= nil then
			t[key] = DeepCopy(dt[key])
		end
	end

	local function border(b, db, keepColor)
		if not (b and db) then
			return
		end
		copy(b, db, "style")
		copy(b, db, "size")
		copy(b, db, "padding")
		if not keepColor then
			copy(b, db, "color")
		end
	end

	local function fonts(t, dt)
		if not (t and dt) then
			return
		end
		for k, v in pairs(dt) do
			if type(v) == "table" and k:match("^text%d$") and type(t[k]) == "table" then
				copy(t[k], v, "font")
				copy(t[k], v, "outline")
			end
		end
	end

	copy(live, d, "bgTexture")
	copy(live, d, "bgTextureColor")
	border(live["border"], d["border"])

	if kind == "lanes" then
		copy(live, d, "fgTexture")
		copy(live["tracking"], d["tracking"], "stTexture")
		copy(live, d, "fgClassColor")
	elseif kind == "barFrames" then
		copy(live["bar"], d["bar"], "fgTexture")
		copy(live["bar"], d["bar"], "bgTexture")
		copy(live["transition"], d["transition"], "texture")
		copy(live["bar"], d["bar"], "bgTextureColor")
		border(live["bar"]["border"], d["bar"]["border"])
		copy(live["bar"], d["bar"], "fgClassColor")
		fonts(live["bar"], d["bar"])
	end

	if live["icons"] and d["icons"] then
		border(live["icons"]["border"], d["icons"]["border"])
		border(live["icons"]["highlight"]["border"], d["icons"]["highlight"]["border"], true)
		fonts(live["icons"], d["icons"])
	end
	for _, block in ipairs({ "modeText", "customText" }) do
		fonts(live[block], d[block])
	end
end
