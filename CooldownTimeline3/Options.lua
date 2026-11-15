--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}
local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")

-- Free-text seconds inputs: reject anything that isn't a positive number before the
-- setter runs (it used to do val * 1000 on raw text, which errors on "", "abc", "1,5")
private.ValidateSeconds = function(info, val)
	local n = tonumber(val)
	if n and n > 0 then
		return true
	end

	return L["Enter a time in seconds, e.g. 30 or 1.5"]
end

-- The combat log is closed to addons on retail 12.x and WoW: Forever (CDTL3:NoCombatLog in
-- CDTL3.lua). Anything fed only by it never fires there.
private.NoCombatLog = function()
	return CDTL3:NoCombatLog()
end

-- Clear Settings / Clear Quest Items act for this character only: an entry other characters
-- also use just loses this character from usedBy; one only this character uses goes.
-- Returns true when the entry stays saved.
private.KeepAfterClear = function(entry)
	if not CDTL3:IsMyEntry(entry) then
		return true
	end

	local others = {}
	for _, guid in pairs(entry["usedBy"]) do
		if guid ~= CDTL3.player["guid"] then
			table.insert(others, guid)
		end
	end

	if #others > 0 then
		entry["usedBy"] = others
		return true
	end

	return false
end

-- Filters › Clear Individual Settings: the saved entry of list t that Filters shows this character
-- under the selected name (items by item name), and its index
private.SelectedEntry = function(t)
	local name = CDTL3.currentFilter[t] or ""
	local index = nil
	for k, spell in pairs(CDTL3.db.profile.tables[t]) do
		local n = (t == "items") and spell["itemName"] or spell["name"]
		if n == name and CDTL3:IsMyEntry(spell) then
			index = k
		end
	end
	return index and CDTL3.db.profile.tables[t][index], index
end

-- another character on this profile uses the entry too
private.UsedByOthers = function(entry)
	for _, guid in pairs(entry["usedBy"] or {}) do
		if guid ~= CDTL3.player["guid"] then
			return true
		end
	end
	return false
end

-- Border texture, colour, size and padding controls, added to args: texture and colour at
-- first, first+1 (default base+1), size and padding at base+11, base+12. border() returns
-- the live { style, color, size, padding } settings table.
private.AddBorderArgs = function(args, base, border, refresh, first)
	first = first or base + 1

	args["border"] = {
		name = "                    " .. L["Border Texture"],
		desc = L["Selects the border texture"],
		order = first,
		type = "select",
		dialogControl = 'LSM30_Border',
		values = AceGUIWidgetLSMlists.border,
		get = function(info) return border()["style"] end,
		set = function(info, val)
				border()["style"] = val
				refresh()
			end,
	}
	args["borderColor"] = {
		name = L["Color"],
		desc = L["Selects the border color"],
		order = first + 1,
		type = "color",
		hasAlpha = true,
		get = function(info)
				local c = border()["color"]
				return c["r"], c["g"], c["b"], c["a"]
			end,
		set = function(info, red, green, blue, alpha)
				border()["color"] = { r = red, g = green, b = blue, a = alpha }
				refresh()
			end,
	}
	args["spacer"..(base + 10)] = {
		name = "",
		type = "description",
		order = base + 10,
	}
	args["borderSize"] = {
		name = L["Size"],
		desc = L["Sets the size of the border"],
		order = base + 11,
		type = "range",
		softMin = 1,
		softMax = 40,
		bigStep = 1,
		get = function(info) return border()["size"] end,
		set = function(info, val)
				border()["size"] = val
				refresh()
			end,
	}
	args["borderPadding"] = {
		name = L["Padding"],
		desc = L["Sets the space between the border and the frame"],
		order = base + 12,
		type = "range",
		softMin = 0,
		softMax = 40,
		bigStep = 1,
		get = function(info) return border()["padding"] end,
		set = function(info, val)
				border()["padding"] = val
				refresh()
			end,
	}
end

-- Spell school colors (Colors tab). Schools are learned from the combat log, so these and
-- the bar frames' "Spell School Color" option are hidden where the log is closed.
private.SCHOOLS = { "Physical", "Holy", "Fire", "Nature", "Frost", "Shadow", "Arcane", "Other" }
private.SCHOOL_LABELS = {
	Physical = L["Physical"], Holy = L["Holy"], Fire = L["Fire"], Nature = L["Nature"],
	Frost = L["Frost"], Shadow = L["Shadow"], Arcane = L["Arcane"], Other = L["Other"],
}

private.AddSchoolColorArgs = function(args)
	args["spacer300"] = {
		name = "\n\n" .. L["Spell School Colors\n|cffaaaaaaUsed by bar frames with Spell School Color ticked. Multi-school and not-yet-seen spells use Other.|r"],
		type = "description",
		fontSize = "large",
		order = 300,
		hidden = private.NoCombatLog,
	}
	for n, school in ipairs(private.SCHOOLS) do
		args["school"..school] = {
			name = private.SCHOOL_LABELS[school],
			desc = string.format(L["Set the %s school color"], private.SCHOOL_LABELS[school]),
			order = 300 + n,
			type = "color",
			hasAlpha = true,
			hidden = private.NoCombatLog,
			get = function(info)
					local c = CDTL3.db.profile.global["schoolColors"][school]
					return c["r"], c["g"], c["b"], c["a"]
				end,
			set = function(info, red, green, blue, alpha)
					CDTL3.db.profile.global["schoolColors"][school] = { r = red, g = green, b = blue, a = alpha }
					CDTL3:RefreshAllBars()
				end,
		}
	end
end

-- QUICK STYLE (main options tab): one-click looks for every lane, bar frame and ready frame
private.selectedPreset = "minimal"

private.AddStyleArgs = function(args)
	args["style"] = {
		name = L["Quick Style"],
		type = "group",
		order = 150,
		args = {
			intro = {
				name = "\n" .. L["Pick a style and apply it to every lane, bar frame and ready frame at once. Only looks change (textures, colours, borders, fonts); sizes, positions and what is tracked stay as they are. Fine-tune anything afterwards in the Lanes, Bar Frames and Ready tabs."] .. "\n",
				type = "description",
				fontSize = "medium",
				order = 100,
			},
			preset = {
				name = L["Style"],
				desc = function(info)
						for _, preset in ipairs(CDTL3.presets) do
							if preset.key == private.selectedPreset then
								return preset.desc
							end
						end
						return ""
					end,
				order = 101,
				type = "select",
				values = function() return CDTL3:GetPresetList() end,
				get = function(info) return private.selectedPreset end,
				set = function(info, val) private.selectedPreset = val end,
			},
			presetDesc = {
				name = function(info)
						for _, preset in ipairs(CDTL3.presets) do
							if preset.key == private.selectedPreset then
								return "|cffaaaaaa"..preset.desc.."|r"
							end
						end
						return ""
					end,
				type = "description",
				order = 102,
			},
			apply = {
				name = L["Apply Style"],
				desc = L["Apply the selected style to every lane, bar frame and ready frame"],
				order = 103,
				type = "execute",
				confirm = true,
				confirmText = L["Apply this style to every lane, bar frame and ready frame? Your current textures, colours, borders and fonts will be replaced (export your profile first if you want to keep them)."],
				func = function(info)
						CDTL3:ApplyPreset(private.selectedPreset)
					end,
			},
		},
	}
end

-- the Filters > Defaults selection's name inside a sentence ("all new spells icons"); a translator
-- gives each type its own wording
private.TypeNoun = function()
	local key = CDTL3.currentFilter["default"]
	local nouns = {
		SPELLS = L["spells"], ITEMS = L["items"], BUFFS = L["buffs"], DEBUFFS = L["debuffs"],
		OFFENSIVES = L["offensives"], PETSPELLS = L["pet spells"], CUSTOMS = L["customs"], RUNES = L["runes"],
	}
	return nouns[key] or string.lower(tostring(key))
end

-- "Copy settings from" (each lane / bar frame / ready frame's General tab)
private.copySource = {}

private.AddCopyArgs = function(args, group, i, label)
	local id = group..i

	args["copyHeader"] = {
		name = L["Copy Settings"],
		type = "header",
		order = 900,
	}
	args["copyFrom"] = {
		name = L["Copy From"],
		desc = string.format(L["Copy every setting from another %s to this one, except its name, position and whether it's enabled"], label:lower()),
		order = 901,
		type = "select",
		values = function()
				local list = {}
				for n = 1, 3 do
					if n ~= i then
						list[n] = label.." "..n
					end
				end
				return list
			end,
		get = function(info) return private.copySource[id] end,
		set = function(info, val) private.copySource[id] = val end,
	}
	args["copyApply"] = {
		name = L["Copy"],
		order = 902,
		type = "execute",
		confirm = true,
		confirmText = string.format(L["Replace this %s's settings with a copy?"], label:lower()),
		disabled = function(info) return not private.copySource[id] end,
		func = function(info)
				CDTL3:CopyFrameSettings(group, private.copySource[id], i)
				private.copySource[id] = nil
			end,
	}
end

-- "Copy this lane" (each lane's General tab, under Copy Settings): shows a share string of just
-- this lane, which the Import box (Import/Export tab) puts on the same lane number
private.laneShareShown = {}

private.AddShareLaneArgs = function(args, i)
	args["shareLane"] = {
		name = L["Copy this lane"],
		desc = L["Show this lane's settings as a share string to copy, for another profile or another player's Import box"],
		order = 910,
		type = "execute",
		func = function(info)
				private.laneShareShown[i] = true
			end,
	}
	args["shareLaneBox"] = {
		name = L["Lane share string (select all of it and copy it with Ctrl+C)"],
		desc = L["Importing it replaces that lane's settings, except its name, position and whether it's on"],
		order = 911,
		type = "input",
		multiline = 3,
		width = "full",
		hidden = function(info)
				return not private.laneShareShown[i]
			end,
		get = function(info)
				return CDTL3:ExportString("LANE", i)
			end,
		set = function(info, val)
				return nil
			end,
	}
end

-- FONT, BAR TEXTURE AND SOUND DROPDOWNS: a saved name that isn't registered here (its media
-- pack was removed, or the settings came from someone else's string) says so, "(missing)" on
-- the label and the tooltip naming what is used instead (CDTL3.LSM's fallback, Media.lua).
-- Added to every such dropdown in the window, whichever tab builds it (CDTL3:GetFullOptions).
private.MEDIA_CONTROLS = { LSM30_Font = "font", LSM30_Statusbar = "statusbar", LSM30_Sound = "sound" }
private.mediaNoted = setmetatable({}, { __mode = "k" })

private.AddMediaNote = function(option, kind, rawGet, applies)
	if private.mediaNoted[option] or type(option.get) ~= "function" then
		return
	end
	private.mediaNoted[option] = true

	local name, desc, get = option.name, option.desc, rawGet or option.get
	local function text(v, info)
		if type(v) == "function" then
			return v(info)
		end
		return v
	end
	local function missing(info)
		local ok, value = pcall(get, info)
		if not ok or (applies and not applies(value)) then
			return false
		end
		local gone, using = CDTL3:MediaMissing(kind, value)
		return gone, using, value
	end

	option.name = function(info)
			local base = text(name, info) or ""
			if missing(info) then
				return base.." |cffff9900"..L["(missing)"].."|r"
			end
			return base
		end
	option.desc = function(info)
			local base = text(desc, info)
			local gone, using, value = missing(info)
			if not gone then
				return base
			end
			local note = string.format(L["|cffff9900Missing, using the default: %s.|r \"%s\" isn't installed here (a media pack may have been removed)."], tostring(using), (tostring(value):gsub("|", "||")))
			if base and base ~= "" then
				return note.."\n\n"..base
			end
			return note
		end
end

-- SOUND DROPDOWNS: Blizzard's own sounds ("Blizzard: ...", Media.lua) get their own menu, "Blizzard
-- sound", right after the main one. Both read and write the same saved setting; the menu that
-- doesn't hold the saved sound shows no selection (a blank box). Lists are made when a menu is
-- opened, since other addons register sounds after this one loads.
private.BLIZZARD_SOUND_PREFIX = "Blizzard: "
private.soundSplit = setmetatable({}, { __mode = "k" })

private.IsBlizzardSound = function(value)
	return type(value) == "string" and value:sub(1, #private.BLIZZARD_SOUND_PREFIX) == private.BLIZZARD_SOUND_PREFIX
end

private.SplitBlizzardSound = function(args, key, option)
	if private.soundSplit[option] or type(option.get) ~= "function" then
		return
	end
	private.soundSplit[option] = true

	local rawGet, rawValues = option.get, option.values
	local function source(info)
		local list = rawValues
		if type(list) == "function" then
			list = list(info)
		end
		return list or (AceGUIWidgetLSMlists and AceGUIWidgetLSMlists.sound) or {}
	end
	local function listOf(blizzard)
		return function(info)
				local out = {}
				for name, v in pairs(source(info)) do
					if private.IsBlizzardSound(name) == blizzard then
						out[name] = v
					end
				end
				return out
			end
	end

	local blizzard = {}
	for k, v in pairs(option) do
		blizzard[k] = v
	end
	private.soundSplit[blizzard] = true

	option.values = listOf(false)
	option.get = function(info)
			local value = rawGet(info)
			if private.IsBlizzardSound(value) then
				return nil
			end
			return value
		end

	blizzard.name = L["Blizzard sound"]
	blizzard.desc = L["Blizzard's own game sounds. Picking one here replaces the sound chosen in the other menu."]
	-- Rows: the main menu starts its own row (a full-width break before it), its Play sound button
	-- (args[key.."Test"], where there is one) follows it, then a break, the Blizzard menu (same
	-- width, so the two line up) and a last break so the next control starts a new row.
	local main = option.order or 0
	local play = args[key.."Test"]
	local last = main
	if type(play) == "table" and type(play.order) == "number" and play.order > main then
		last = play.order
	end
	local function rowBreak(order)
		return { name = "", type = "description", width = "full", order = order, hidden = option.hidden }
	end
	args[key.."RowA"] = rowBreak(main - 0.3)
	args[key.."RowB"] = rowBreak(last + 0.2)
	args[key.."RowC"] = rowBreak(last + 0.4)

	blizzard.order = last + 0.3
	blizzard.values = listOf(true)
	blizzard.get = function(info)
			local value = rawGet(info)
			if private.IsBlizzardSound(value) then
				return value
			end
			return nil
		end
	private.AddMediaNote(blizzard, "sound", rawGet, private.IsBlizzardSound)
	args[key.."Blizzard"] = blizzard
end

private.AddMediaNotes = function(group, seen)
	seen = seen or {}
	if type(group) ~= "table" or type(group.args) ~= "table" or seen[group] then
		return
	end
	seen[group] = true

	local found = {}
	for key, option in pairs(group.args) do
		if type(option) == "table" then
			local kind = option.type == "select" and private.MEDIA_CONTROLS[option.dialogControl]
			if kind then
				private.AddMediaNote(option, kind)
				if kind == "sound" and not private.soundSplit[option] then
					found[#found + 1] = key
				end
			elseif option.type == "group" and key ~= "profiles" then
				private.AddMediaNotes(option, seen)
			end
		end
	end
	for _, key in ipairs(found) do
		private.SplitBlizzardSound(group.args, key, group.args[key])
	end
end

CDTL3.AddMediaNotes = private.AddMediaNotes	-- Start.lua's Simple tab has a sound dropdown too

-- The Filters entry being edited: the saved entry, or the in-progress custom when adding one
private.FilterEntry = function(t)
	if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
		return CDTL3.custom
	end

	return CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, t == "items")
end

-- Per-entry bar colour (Filters): wins over school, class and the bar frame's own colour
private.AddEntryColorArgs = function(args, t)
	local function apply(key, val)
		local s = private.FilterEntry(t)
		if not s then
			return
		end

		s[key] = val
		if s == CDTL3.custom then
			return
		end

		-- live icons/bars of this entry (items are listed by item name)
		local name = CDTL3.currentFilter[t]
		for _, cd in pairs(CDTL3.cooldowns) do
			if cd.data["type"] == t and (cd.data["name"] == name or cd.data["itemName"] == name) then
				cd.data[key] = val
			end
		end
		CDTL3:RefreshAllBars()
	end

	args["spacer700"] = {
		name = "\n",
		type = "description",
		order = 700,
		hidden = function(info)
				return CDTL3.currentFilterHidden[t]
			end,
	}
	args["customColor"] = {
		name = L["Own Bar Color"],
		desc = L["Give this entry's bar its own color instead of the bar frame's (class / school / frame color)"],
		order = 701,
		type = "toggle",
		hidden = function(info)
				return CDTL3.currentFilterHidden[t]
			end,
		get = function(info)
				local s = private.FilterEntry(t)
				return s and s["customColor"] or false
			end,
		set = function(info, val)
				apply("customColor", val)
			end,
	}
	args["color"] = {
		name = L["Bar Color"],
		desc = L["This entry's bar color"],
		order = 702,
		type = "color",
		hasAlpha = true,
		hidden = function(info)
				if CDTL3.currentFilterHidden[t] then
					return true
				end

				local s = private.FilterEntry(t)
				return not (s and s["customColor"])
			end,
		get = function(info)
				local s = private.FilterEntry(t)
				local c = s and s["color"] or { r = 1, g = 1, b = 1, a = 1 }
				return c["r"], c["g"], c["b"], c["a"]
			end,
		set = function(info, red, green, blue, alpha)
				apply("color", { r = red, g = green, b = blue, a = alpha })
			end,
	}
end

-- Lane tracking choices; melee swings come from SWING_DAMAGE/SWING_MISSED in the combat log
private.TrackingValues = function(info)
	local swingNote = ""
	if private.NoCombatLog() then
		swingNote = " "..L["(needs combat log)"]
	end

	local values = {
		["NONE"] = L["None"],
		["GCD"] = L["GCD"],
		["HEALTH"] = L["Health"],
		["CLASS_POWER"] = L["Class Power"],
		["COMBO_POINTS"] = L["Combo Points"],
		["MANA_TICK"] = L["Mana Tick"],
		["ENERGY_TICK"] = L["Energy Tick"],
		["MH_SWING"] = L["MH Swing"]..swingNote,
		["OH_SWING"] = L["OH Swing"]..swingNote,
		["RANGE_SWING"] = L["Ranged Auto-attack"],
	}
	-- Brewmaster stagger, offered to monks on a client that has UnitStagger (Retail; MoP if it has it)
	if UnitStagger and CDTL3.player and CDTL3.player["class"] == "MONK" then
		values["STAGGER"] = L["Stagger"]
	end
	return values
end

-- Lanes and bars only ever draw the player's own class colour
function CDTL3:RefreshClassColor(class)
	if class == CDTL3.player["class"] then
		for _, f in pairs(CDTL3.lanes) do
			CDTL3:RefreshLane(f.number)
		end
		CDTL3:RefreshAllBars()
	end
end

function CDTL3:GetChangeLog()
	local changeLog = ""
	changeLog = changeLog.."\n"
	changeLog = changeLog.."CDTL3 continues Cooldown Timeline for Retail (Midnight), Classic Era,\n"
	changeLog = changeLog.."TBC Anniversary, MoP Classic and World of Warcraft: Forever,\n"
	changeLog = changeLog.."based on the original by Vreenak and the v2 rewrite by cliffclive.\n\n"
	changeLog = changeLog.."Changelog 3.2.0:\n\n"
	changeLog = changeLog.."  - Getting started: a short tour on a first install, a Simple tab, setups\n"
	changeLog = changeLog.."    by role (Starter, Healer, Tank, DPS) shown on your frames with Keep or\n"
	changeLog = changeLog.."    Undo, and a Help tab (Alt-click the minimap button)\n"
	changeLog = changeLog.."  - Lanes and icons: charge pips, buff alerts, a burst window, a pulse before\n"
	changeLog = changeLog.."    a cooldown is back, a mana gauge, and GCD waits in the Ready frame\n"
	changeLog = changeLog.."  - Boards and groups: a Ready frame that shows every cooldown you pin, a\n"
	changeLog = changeLog.."    fight timeline, a Caster lane with each caster's name, and group\n"
	changeLog = changeLog.."    cooldowns from the addon CooldownCollaborator on your lanes\n"
	changeLog = changeLog.."  - Filters say why a spell or buff isn't showing, list your spellbook's\n"
	changeLog = changeLog.."    cooldowns, and can pull buffs from the Cooldown Manager\n"
	changeLog = changeLog.."  - A ready sound per spell, names said out loud, and Blizzard sounds in\n"
	changeLog = changeLog.."    their own menu next to every sound menu\n"
	changeLog = changeLog.."  - Frames can follow the player frame or any frame; profiles by zone and\n"
	changeLog = changeLog.."    for new characters; share strings show what's in them first\n"
	changeLog = changeLog.."  - /cdtl3 report, log, perf and help. The full list of fixes is on the\n"
	changeLog = changeLog.."    addon's page\n\n"
	changeLog = changeLog.."Changelog 3.1.1:\n\n"
	changeLog = changeLog.."  - Flight timers (every client, on by default): a countdown to landing on\n"
	changeLog = changeLog.."    every flight path, named for where you're going. Exact after one\n"
	changeLog = changeLog.."    flight, an estimate in dimmed text before that. Global tab: turn it\n"
	changeLog = changeLog.."    off, pick the lane, bar frame and ready frame, or forget learned times\n\n"
	changeLog = changeLog.."Changelog 3.1.0:\n\n"
	changeLog = changeLog.."  - Retail and Forever: combat timers (experimental, on by default). In\n"
	changeLog = changeLog.."    combat, spell icons, bars and countdown text follow the game's own timer\n"
	changeLog = changeLog.."    at the real length, and go to ready on time\n"
	changeLog = changeLog.."  - Buffs in the Cooldown Manager's Tracked Bars (/cdm) get an exact timer\n"
	changeLog = changeLog.."    in combat; other buffs show an estimate in dimmed text. Global tab:\n"
	changeLog = changeLog.."    turn combat timers off, or hide Blizzard's Tracked Bars\n"
	changeLog = changeLog.."  - Lanes: Max Time and Split (Time) values go up to an hour on the slider,\n"
	changeLog = changeLog.."    and a Long buffs scale button sets up a lane for 10 and 60 minute buffs\n"
	changeLog = changeLog.."  - Unticking Ignored on a buff that's up shows it at once\n"
	changeLog = changeLog.."  - Bar frames: unticking Transition bars brings hidden bars back without\n"
	changeLog = changeLog.."    a reload\n\n"
	changeLog = changeLog.."Changelog 3.0.13:\n\n"
	changeLog = changeLog.."  - Forever: spell list updated for the November changes (Lightning\n"
	changeLog = changeLog.."    Mastery, Totemic Call at 30 s, no Lava Burst; Swift Judgement is a\n"
	changeLog = changeLog.."    normal cooldown again)\n"
	changeLog = changeLog.."  - Forever and Retail: a buff you recast in combat restarts from its last\n"
	changeLog = changeLog.."    known length (an estimate, corrected when combat ends)\n"
	changeLog = changeLog.."  - Custom CD Time works on spells without a cooldown (e.g. seals): it\n"
	changeLog = changeLog.."    counts from your last cast\n"
	changeLog = changeLog.."  - Custom timers with trigger type Spell fire for spells you know\n\n"
	changeLog = changeLog.."Changelog 3.0.12:\n\n"
	changeLog = changeLog.."  - Forever: spell data corrected from Forever's own game data (spells\n"
	changeLog = changeLog.."    and ranks it doesn't have removed, renamed spells, changed cooldowns);\n"
	changeLog = changeLog.."    Swift Judgement now starts its cooldown when used, Elemental Mastery no\n"
	changeLog = changeLog.."    longer does\n"
	changeLog = changeLog.."  - MoP Classic and Retail: spells whose cooldown starts when their effect\n"
	changeLog = changeLog.."    is used no longer go straight to ready\n"
	changeLog = changeLog.."  - Forever and Retail: pet abilities and spells cast at a higher rank\n"
	changeLog = changeLog.."    count down properly in combat, and Stealth-style cooldowns count\n"
	changeLog = changeLog.."    from when the effect ends\n"
	changeLog = changeLog.."  - Retail: no longer shows as out of date on 12.1.5; options that need\n"
	changeLog = changeLog.."    the combat log are hidden, as on Forever\n"
	changeLog = changeLog.."  - Items are no longer hidden by mistake, and moving a cooldown to\n"
	changeLog = changeLog.."    another lane no longer restarts it\n"
	changeLog = changeLog.."  - Filters bulk controls change only this character's entries\n"
	changeLog = changeLog.."  - Spell School Color no longer greys out bars where the combat log is\n"
	changeLog = changeLog.."    closed; the minimap button's right-click now toggles lock\n\n"
	changeLog = changeLog.."Changelog 3.0.11:\n\n"
	changeLog = changeLog.."  - Fixed Nature's Swiftness and the other spells whose cooldown starts\n"
	changeLog = changeLog.."    when their effect is used on Classic Era, TBC Anniversary and Forever:\n"
	changeLog = changeLog.."    the built-in spell lists the 3.0.10 fix reads never loaded there\n"
	changeLog = changeLog.."  - Added Shaman Nature's Swiftness to the Classic Era list and marked\n"
	changeLog = changeLog.."    Classic Era Cold Blood as starting its cooldown when used\n"
	changeLog = changeLog.."  - New /cdtl3 oaf troubleshooting report for these spells\n\n"
	changeLog = changeLog.."Changelog 3.0.10:\n\n"
	changeLog = changeLog.."  - New: Hide out of combat (Global tab) — frames fade out of combat\n"
	changeLog = changeLog.."    and appear when a pull starts; detection keeps running throughout\n"
	changeLog = changeLog.."  - Fixed Nature's Swiftness, Presence of Mind, Divine Favor, Prowl,\n"
	changeLog = changeLog.."    Feign Death and other spells whose cooldown starts when their effect\n"
	changeLog = changeLog.."    is used: they went straight to ready and never showed the cooldown\n\n"
	changeLog = changeLog.."Changelog 3.0.9:\n\n"
	changeLog = changeLog.."  - The minimap button can be hidden: Global tab -> Minimap button,\n"
	changeLog = changeLog.."    or /cdtl3 minimap (account-wide)\n"
	changeLog = changeLog.."  - The minimap button now rides the rim of any minimap size (it sat\n"
	changeLog = changeLog.."    inside the larger WoW: Forever minimap) and follows resizes\n\n"
	changeLog = changeLog.."Changelog 3.0.8:\n\n"
	changeLog = changeLog.."  New:\n"
	changeLog = changeLog.."  - Edit Mode: lanes, bar frames and ready frames can be moved and\n"
	changeLog = changeLog.."    resized in Blizzard's Edit Mode (Retail, Forever, TBC Anniversary,\n"
	changeLog = changeLog.."    MoP Classic), with positions saved per Edit Mode layout\n"
	changeLog = changeLog.."  - Quick Style tab: one-click looks for everything (CDTL3 Classic,\n"
	changeLog = changeLog.."    Minimal, Blizzard Modern, Class Colours)\n"
	changeLog = changeLog.."  - Copy all settings from one lane / bar frame / ready frame to another\n"
	changeLog = changeLog.."  - Per-spell bar colors (Filters -> any entry -> Own Bar Color)\n"
	changeLog = changeLog.."  - Spell School Color now works: schools are learned as you cast, with\n"
	changeLog = changeLog.."    a color per school under Colors (needs the combat log)\n"
	changeLog = changeLog.."  - Blizzard's modern bar textures (unit-frame and cast bars) on Retail\n"
	changeLog = changeLog.."    and Forever\n"
	changeLog = changeLog.."  - Per-spec profiles (Profiles tab -> Enable spec profiles)\n\n"
	changeLog = changeLog.."  Fixes and clean-up (a full audit of the code):\n"
	changeLog = changeLog.."  - Import no longer silently fails to apply, and rejects bad strings\n"
	changeLog = changeLog.."  - Filters: Set All, Clear Individual Settings, Save Custom and item\n"
	changeLog = changeLog.."    entries fixed; time inputs are validated\n"
	changeLog = changeLog.."  - Power text tags work for every class; highlight-based tags fixed\n"
	changeLog = changeLog.."  - Class colour pickers update live; lane 2/3 time format fixed\n"
	changeLog = changeLog.."  - New spells, items and buffs all follow Filters -> Defaults the same\n"
	changeLog = changeLog.."    way (inclusive Ignore Threshold)\n"
	changeLog = changeLog.."  - Less work in raids: only your own and your pet's events are handled\n"
	changeLog = changeLog.."  - Options that need the combat log say so where it's closed\n\n"
	changeLog = changeLog.."  Forever and compatibility:\n"
	changeLog = changeLog.."  - World of Warcraft: Forever support — the addon now loads and tracks\n"
	changeLog = changeLog.."    cooldowns on Forever using the modern spell/aura/spellbook API\n"
	changeLog = changeLog.."  - Combat log registration can no longer abort cooldown detection on\n"
	changeLog = changeLog.."    clients where the combat log is closed to addons\n"
	changeLog = changeLog.."  - Updated Ace3 libraries (r1403): fixes options-window errors on\n"
	changeLog = changeLog.."    Forever and WoW 12.1.5 (checkboxes, tooltips)\n"
	changeLog = changeLog.."  - Item/spellbook lookups no longer use globals removed in 12.1.5\n"
	changeLog = changeLog.."  - Buffs/debuffs on you (and custom aura triggers) are detected from\n"
	changeLog = changeLog.."    aura updates, so they work on Forever without the combat log —\n"
	changeLog = changeLog.."    including recasts of a buff you already have, and buffs already on\n"
	changeLog = changeLog.."    you at login or after /reload\n"
	changeLog = changeLog.."  - Fixed detected buffs/debuffs missing from Filters for your character\n"
	changeLog = changeLog.."  - Fixed the debug frame's Options button erroring\n"
	changeLog = changeLog.."  - New /cdtl3 auras: shows what CDTL3 can see of your buffs/debuffs\n"
	changeLog = changeLog.."  - Fixed an options error when no entry is selected in a Filters list\n"
	changeLog = changeLog.."  - Lane health/power tracking, swing timers, item cooldowns, text tags\n"
	changeLog = changeLog.."    and aura detection no longer error on secret values (Forever, 12.x)\n"
	changeLog = changeLog.."  - Fixed buffs/debuffs recording spell ID 0 on Classic clients\n"
	changeLog = changeLog.."  - TOCs updated: MoP Classic 5.5.4, TBC Anniversary 2.5.6,\n"
	changeLog = changeLog.."    Classic Era 1.15.9, Forever 1.60.1\n\n"
	changeLog = changeLog.."Changelog 3.0.7:\n\n"
	changeLog = changeLog.."  - ALL settings now live in one movable window (/cdtl3) — every panel\n"
	changeLog = changeLog.."    (Lanes, Ready, Bar Frames, Filters, Profiles) is a tab there. The lane\n"
	changeLog = changeLog.."    and bar color/texture options were always in the addon, but the old\n"
	changeLog = changeLog.."    standalone window never showed them — now everything is reachable\n"
	changeLog = changeLog.."  - Blizzard's AddOns settings entry is now just a launcher button\n"
	changeLog = changeLog.."  - New slash shortcuts: /cdtl3 lanes | ready | bars | filters | profiles\n"
	changeLog = changeLog.."  - New: Dynamic Color for cooldown bars — the bar blends toward a ready\n"
	changeLog = changeLog.."    color over its final seconds (Bar Frames -> Bars -> Dynamic Color)\n"
	changeLog = changeLog.."  - New: Spell School Color toggle for bars exposed in options\n"
	changeLog = changeLog.."  - Midnight 12.1 compatibility: aura tracking hardened against secret\n"
	changeLog = changeLog.."    auras (no more errors in combat / M+ / PvP)\n"
	changeLog = changeLog.."  - Fixed aura-triggered entries recording spell ID 0\n\n"
	changeLog = changeLog.."Changelog 3.0.6:\n\n"
	changeLog = changeLog.."  - Fixed the manual Custom CD Time override being overwritten by the\n"
	changeLog = changeLog.."    live (base) cooldown every frame\n\n"
	changeLog = changeLog.."Changelog 3.0.5:\n\n"
	changeLog = changeLog.."  - Fixed checkerboard minimap button / AddOns-list icon (TGA textures)\n\n"
	changeLog = changeLog.."Changelog 3.0.4:\n\n"
	changeLog = changeLog.."  - Fixed secret-cooldown crashes on Midnight (Lane view error spam)\n"
	changeLog = changeLog.."  - Completed the CDTL2 -> CDTL3 rename with settings migration\n\n"
	changeLog = changeLog.."Changelog 3.0.2:\n\n"
	changeLog = changeLog.."  - Fixed profiles not saving on MoP / TBC / Vanilla Classic\n"
	changeLog = changeLog.."  - Added a minimap button and an AddOns-list icon\n"
	changeLog = changeLog.."  - Fixed the options command erroring on Midnight 12.0.7\n\n"
	changeLog = changeLog.."Changelog 3.0.1:\n\n"
	changeLog = changeLog.."  - Midnight 12.0.7 compatibility\n"
		
	return changeLog
end

-- Shown in the welcome window under the support link, above the changelog
function CDTL3:GetSpecialMessage()
	local message = ""

	-- 3.2.0: the big update, for every client
	message = message.."|cFFffd100New in 3.2.0|r\n\n"
	message = message.."This is the biggest update CDTL3 has had, so here's the quick version:\n\n"
	message = message.."  - The Simple tab is up front, with the settings most people actually change\n"
	message = message.."  - Quick Style > Setup has Healer, Tank and DPS setups. Try one on your own\n"
	message = message.."    frames first, then Keep it or Undo it\n"
	message = message.."  - Filters says why a spell or buff isn't showing, and you can pick spells\n"
	message = message.."    right out of your spellbook\n"
	message = message.."  - Every spell can have its own ready sound and say its name out loud, and\n"
	message = message.."    Blizzard's own sounds have their own menu\n"
	message = message.."  - Lanes > (a lane) > Effects has charge pips, a burst window and a pulse\n"
	message = message.."    right before a cooldown is back\n"
	message = message.."  - Tick Pinned on a spell in Filters to keep it on the Ready board\n"
	message = message.."    (Ready > Mode > Stay until used) and on the Fight Timeline tab\n"
	message = message.."  - The Caster lane, and your group's cooldowns from CooldownCollaborator\n"
	message = message.."  - Profiles by zone\n"
	message = message.."  - Alt-click the minimap button, or type /cdtl3 help, for every command\n\n"
	message = message.."CooldownCollaborator is my other addon. It shares your group's big cooldowns\n"
	message = message.."(yours, and anyone in your group who runs it) right onto CDTL3's lanes, on\n"
	message = message.."every client. Please try it! Testing in all kinds of groups (dungeons, raids,\n"
	message = message.."battlegrounds, with friends who run it too) is encouraged and really\n"
	message = message.."appreciated. Let me know what you see at\n"
	message = message.."https://github.com/Nelnamara/CooldownCollaborator/issues\n\n"
	message = message.."Hit Take the tour below for a quick look around.\n\n"

	-- 3.1.0: combat timers are on for everyone; say so once, with how to turn them off.
	-- Only where they run, and only for a player who hasn't seen 3.1 yet (or is new).
	local CT = CDTL3.CombatTimers
	if CT and CT:Available() and (CDTL3.db.profile.global["firstRun"] or CDTL3:LastSeenOlderThan("3.1")) then
		message = message.."|cFFffd100New in 3.1.0: combat timers (experimental), on for everyone|r\n\n"
		message = message.."In combat the game hides cooldown and buff timings from addons. CDTL3 now\n"
		message = message.."uses the game's own timer instead:\n\n"
		message = message.."  - Spell cooldowns keep sliding, draining and counting down in combat, at\n"
		message = message.."    their real length (talents and haste included), and go to ready on time\n"
		message = message.."  - Buffs you add to Tracked Bars in Blizzard's Cooldown Manager (/cdm) get\n"
		message = message.."    an exact timer in combat; other buffs show an estimate in dimmed text\n\n"
		message = message.."To turn them off: Global tab > Combat timers (experimental), or type\n"
		message = message.."/cdtl3 combattimers off\n\n"
		message = message.."This is new. If anything looks wrong, please report it at the link above,\n"
		message = message.."with your class and what you saw. Spells with charges are the least tested.\n\n"
	end

	return message
end

function CDTL3:GetMainOptions()
	local options = {
		name = "CDTL3",
		type = "group",
		childGroups  = "tab",
		args = {
			global = {
				name = L["Global"],
				type = "group",
				order = 100,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = "\n" .. L["Enabled:"] .. "\n",
						type = "description",
						order = 100,
					},
					enabledAlways = {
						name = L["Always"],
						desc = L["If selected, CD/Duration detection will always be on"],
						order = 101,
						type = "toggle",
						--width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["enabledAlways"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["enabledAlways"] = val
								
								local turnOn = CDTL3:DetermineOnOff()
	
								if turnOn then
									CDTL3:TurnOn()
								else
									CDTL3:TurnOff()
								end
							end,
					},
					enabledGroup = {
						name = L["In Group"],
						desc = L["If selected, CD/Duration detection will be enabled when in a party/raid"],
						order = 102,
						type = "toggle",
						--width = "full",
						disabled = function(info)
								return CDTL3.db.profile.global["enabledAlways"]
							end,
						get = function(info, index)
								return CDTL3.db.profile.global["enabledGroup"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["enabledGroup"] = val
								
								local turnOn = CDTL3:DetermineOnOff()
	
								if turnOn then
									CDTL3:TurnOn()
								else
									CDTL3:TurnOff()
								end
							end,
					},
					enabledInstance = {
						name = L["In Instance"],
						desc = L["If selected, CD/Duration detection will be enabled when in an instance/raid/bg/arena"],
						order = 103,
						type = "toggle",
						--width = "full",
						disabled = function(info)
								return CDTL3.db.profile.global["enabledAlways"]
							end,
						get = function(info, index)
								return CDTL3.db.profile.global["enabledInstance"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["enabledInstance"] = val
								
								local turnOn = CDTL3:DetermineOnOff()
	
								if turnOn then
									CDTL3:TurnOn()
								else
									CDTL3:TurnOff()
								end
							end,
					},
					spacer199 = {
						name = "\n\n",
						type = "description",
						order = 199,
					},
					unlockFrames = {
						name = L["Unlock Frames"],
						desc = L["Unlock frames to allow drag and drop movement"],
						order = 200,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["unlockFrames"]
							end,
						set = function(info, val)
								CDTL3:ToggleFrameLock()
							end,
					},
					hideOutOfCombat = {
						name = L["Hide out of combat"],
						desc = L["Frames appear when you enter combat and fade when you leave it. Cooldown detection keeps running the whole time, so a cooldown started on the last pull is still tracked and shown on the next one. Unlock frames, Edit Mode and test mode always show the frames"],
						order = 200.5,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["hideOutOfCombat"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["hideOutOfCombat"] = val
								CDTL3:RefreshConfig()
							end,
					},
					autohide = {
						name = L["Auto-hide Frames"],
						desc = L["If selected frames will hide themselves when there is no active bar/icon in it"],
						order = 201,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["autohide"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["autohide"] = val
								
								for i = 1, 3, 1 do
									CDTL3:RefreshLane(i)
									CDTL3:RefreshReady(i)
									CDTL3:RefreshBarFrame(i)
								end
							end,
					},
					showMinimapButton = {
						name = L["Minimap button"],
						desc = L["Show the CDTL3 button on the minimap (also: /cdtl3 minimap). Account-wide."],
						order = 299,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return not (CDTL3.db.global and CDTL3.db.global.minimapHide)
							end,
						set = function(info, val)
								CDTL3.db.global.minimapHide = not val
								if CDTL3.minimapBtn then
									CDTL3.minimapBtn:SetShown(val)
								end
							end,
					},
					combatTimers = {
						name = L["Combat timers (experimental)"],
						desc = L["Keeps spell cooldowns moving in combat with the game's own timer, and gives buffs in Blizzard's Cooldown Manager Tracked Bars an exact timer. Other buffs keep an estimate."],
						order = 350,
						type = "toggle",
						width = "full",
						hidden = function(info)
								local CT = CDTL3.CombatTimers
								return not (CT and CT:Available())
							end,
						get = function(info, index)
								local CT = CDTL3.CombatTimers
								return CT and CT:Enabled() or false
							end,
						set = function(info, val)
								local CT = CDTL3.CombatTimers
								if CT then
									CT:SetEnabled(val)
								end
							end,
					},
					combatTimersHideBars = {
						name = L["Hide Blizzard's Tracked Bars"],
						desc = L["Blizzard's bars must stay on to feed CDTL3; this makes them invisible."],
						order = 351,
						type = "toggle",
						width = "full",
						hidden = function(info)
								local CT = CDTL3.CombatTimers
								return not (CT and CT:Available())
							end,
						disabled = function(info)
								local CT = CDTL3.CombatTimers
								return not (CT and CT:Enabled())
							end,
						get = function(info, index)
								local ct = CDTL3.db.profile.global["combatTimers"]
								return ct and ct["hideBlizzardBars"] or false
							end,
						set = function(info, val)
								local CT = CDTL3.CombatTimers
								if CT then
									CT:SetHideBlizzardBars(val)
								end
							end,
					},
					flightsHeader = {
						name = L["Flight timers"],
						order = 360,
						type = "header",
					},
					flights = {
						name = L["Flight timers"],
						desc = L["Taking a flight path shows a countdown to landing, named for the destination. A route you've flown before (on any character) counts down from its real time; a new one from an estimate, in dimmed text, until you land."],
						order = 361,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.Flights and CDTL3.Flights:Enabled() or false
							end,
						set = function(info, val)
								if CDTL3.Flights then
									CDTL3.Flights:SetEnabled(val)
								end
							end,
					},
					flightsLane = {
						name = L["Lane"],
						desc = L["The lane the flight countdown uses"],
						order = 362,
						type = "select",
						width = "half",
						values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
						disabled = function(info)
								return not (CDTL3.Flights and CDTL3.Flights:Enabled())
							end,
						get = function(info)
								return CDTL3.db.profile.global["flights"]["defaultLane"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["flights"]["defaultLane"] = val
							end,
					},
					flightsBar = {
						name = L["Bar Frame"],
						desc = L["The bar frame the flight countdown uses"],
						order = 363,
						type = "select",
						width = "half",
						values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
						disabled = function(info)
								return not (CDTL3.Flights and CDTL3.Flights:Enabled())
							end,
						get = function(info)
								return CDTL3.db.profile.global["flights"]["defaultBar"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["flights"]["defaultBar"] = val
							end,
					},
					flightsReady = {
						name = L["Ready Frame"],
						desc = L["The ready frame the flight goes to when you land"],
						order = 364,
						type = "select",
						width = "half",
						values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
						disabled = function(info)
								return not (CDTL3.Flights and CDTL3.Flights:Enabled())
							end,
						get = function(info)
								return CDTL3.db.profile.global["flights"]["defaultReady"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["flights"]["defaultReady"] = val
							end,
					},
					flightsForget = {
						name = L["Forget learned flight times"],
						desc = function(info)
								local n = CDTL3.Flights and CDTL3.Flights:LearnedCount() or 0
								return string.format(n == 1 and L["Clears the %d flight time saved on this game client (every character) and the flight speed learned from them. Estimates are used again until each route is flown."] or L["Clears the %d flight times saved on this game client (every character) and the flight speed learned from them. Estimates are used again until each route is flown."], n)
							end,
						order = 365,
						type = "execute",
						confirm = true,
						func = function(info)
								if CDTL3.Flights then
									CDTL3.Flights:Forget()
								end
							end,
					},
					enableTooltip = {
						name = L["Enable tooltips"],
						desc = L["If selected mousing over icons will display a tooltip"],
						order = 300,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["enableTooltip"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["enableTooltip"] = val
							end,
					},
					detectSharedCD = {
						name = L["Detect Shared Spell Cooldowns"],
						desc = L["If selected the mod will attempt to detect other spells that share a cooldown as the initially cast spell and generate icons/bars for them"],
						order = 401,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["detectSharedCD"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["detectSharedCD"] = val
							end,
					},
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
					},
					zoom = {
						name = L["Icon Zoom"],
						desc = L["Sets the zoom level of icons"],
						order = 501,
						type = "range",
						softMin = 1,
						softMax = 1.5,
						get = function(info, index)
								return CDTL3.db.profile.global["zoom"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["zoom"] = val
								CDTL3:RefreshAllIcons()
								CDTL3:RefreshAllBars()
							end,
					},
					spacer600 = {
						name = "\n\n",
						type = "description",
						order = 600,
					},
					notUsableTint = {
						name = L["Tint Unusable Icons"],
						desc = L["If selected unusable icons (eg. not enough mana) will be desaturated/tinted"],
						order = 601,
						type = "toggle",
						width = "full",
						get = function(info, index)
								return CDTL3.db.profile.global["notUsableTint"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["notUsableTint"] = val
							end,
					},
					spacer602 = {
						name = "",
						type = "description",
						order = 602,
						hidden = function(info)
								return not CDTL3.db.profile.global["notUsableTint"]
							end,
					},
					notUsableDesaturate = {
						name = L["Desaturate"],
						desc = L["If selected non usable icons will be desaturated instead of colored"],
						order = 603,
						type = "toggle",
						hidden = function(info)
								return not CDTL3.db.profile.global["notUsableTint"]
							end,
						get = function(info, index)
								return CDTL3.db.profile.global["notUsableDesaturate"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["notUsableDesaturate"] = val
							end,
					},
					notUsableColor = {
						name = L["Not Usable Color"],
						desc = L["Select the tint color of non usable icons"],
						order = 604,
						type = "color",
						hidden = function(info)
								return not CDTL3.db.profile.global["notUsableTint"]
							end,
						hasAlpha = true,
						get = function(info)
								local r = CDTL3.db.profile.global["notUsableColor"]["r"]
								local g = CDTL3.db.profile.global["notUsableColor"]["g"]
								local b = CDTL3.db.profile.global["notUsableColor"]["b"]
								local a = CDTL3.db.profile.global["notUsableColor"]["a"]
								
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["notUsableColor"] = { r = red, g = green, b = blue, a = alpha }							
								CDTL3:RefreshAllIcons()
							end,
					},
					spacer680 = {
						name = "\n\n",
						type = "description",
						order = 680,
					},
					updateRate = {
						name = L["Update rate"],
						desc = L["How often icons slide, bars fill and texts change; lower saves some CPU, and timers, Ready and sounds stay exact"],
						order = 681,
						type = "select",
						values = { [0] = L["Full"], [30] = L["30 per second"], [15] = L["15 per second"] },
						sorting = { 0, 30, 15 },
						get = function(info)
								return CDTL3.db.profile.global["updateRate"] or 0
							end,
						set = function(info, val)
								CDTL3.db.profile.global["updateRate"] = val
							end,
					},
					spacer700 = {
						name = "\n\n",
						type = "description",
						order = 700,
					},
					openTestPanel = {
						name = function(info)
								return L["Open Test Panel"]
							end,
						desc = function(info)
								return ""
							end,
						order = 701,
						--width = "half",
						type = "execute",
						func = function(info)
								CDTL3:EnableTesting()
							end,
					},
				},
			},
			colors = {
				name = L["Colors"],
				type = "group",
				order = 200,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = "\n" .. L["Class Colors"],
						type = "description",
						fontSize = "large",
						order = 100,
					},
					spacer200 = {
						name = "\n",
						type = "description",
						order = 200,
					},
					deathknightColor = {
						name = L["Death Knight"],
						desc = L["Set the Death Knight class color"],
						order = 201,
						type = "color",
						hasAlpha = true,
						hidden = function(info)
							if CDTL3.tocversion >= 30000 then
								return false
							end
							
							return true
						end,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["DEATHKNIGHT"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["DEATHKNIGHT"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("DEATHKNIGHT")
							end,
					},
					demonhunterColor = {
						name = L["Demon Hunter"],
						desc = L["Set the Demon Hunter class color"],
						order = 202,
						type = "color",
						hasAlpha = true,
						hidden = function(info)
							if CDTL3.tocversion >= 70000 then
								return false
							end
							
							return true
						end,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["DEMONHUNTER"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["DEMONHUNTER"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("DEMONHUNTER")
							end,
					},
					druidColor = {
						name = L["Druid"],
						desc = L["Set the Druid class color"],
						order = 203,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["DRUID"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["DRUID"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("DRUID")
							end,
					},
					evokerColor = {
						name = L["Evoker"],
						desc = L["Set the Evoker class color"],
						order = 204,
						type = "color",
						hasAlpha = true,
						hidden = function(info)
							if CDTL3.tocversion >= 100000 then
								return false
							end
							
							return true
						end,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["EVOKER"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["EVOKER"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("EVOKER")
							end,
					},
					hunterColor = {
						name = L["Hunter"],
						desc = L["Set the Hunter class color"],
						order = 205,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["HUNTER"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["HUNTER"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("HUNTER")
							end,
					},
					mageColor = {
						name = L["Mage"],
						desc = L["Set the Mage class color"],
						order = 206,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["MAGE"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["MAGE"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("MAGE")
							end,
					},
					monkColor = {
						name = L["Monk"],
						desc = L["Set the Monk class color"],
						order = 207,
						type = "color",
						hasAlpha = true,
						hidden = function(info)
							if CDTL3.tocversion >= 50000 then
								return false
							end
							
							return true
						end,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["MONK"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["MONK"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("MONK")
							end,
					},
					paladinColor = {
						name = L["Paladin"],
						desc = L["Set the Paladin class color"],
						order = 208,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["PALADIN"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["PALADIN"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("PALADIN")
							end,
					},
					priestColor = {
						name = L["Priest"],
						desc = L["Set the Priest class color"],
						order = 209,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["PRIEST"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["PRIEST"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("PRIEST")
							end,
					},
					rogueColor = {
						name = L["Rogue"],
						desc = L["Set the Rogue class color"],
						order = 210,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["ROGUE"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["ROGUE"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("ROGUE")
							end,
					},
					shamanColor = {
						name = L["Shaman"],
						desc = L["Set the Shaman class color"],
						order = 211,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["SHAMAN"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["SHAMAN"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("SHAMAN")
							end,
					},
					warlockColor = {
						name = L["Warlock"],
						desc = L["Set the Warlock class color"],
						order = 212,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["WARLOCK"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["WARLOCK"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("WARLOCK")
							end,
					},
					warriorColor = {
						name = L["Warrior"],
						desc = L["Set the Warrior class color"],
						order = 213,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local t = CDTL3.db.profile.global["classColors"]["WARRIOR"]
								
								local r = t["r"]
								local g = t["g"]
								local b = t["b"]
								local a = t["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								CDTL3.db.profile.global["classColors"]["WARRIOR"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshClassColor("WARRIOR")
							end,
					},
				},
			},
			importexport = {
				name = L["Import/Export"],
				type = "group",
				order = 300,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = "\n" .. L["Export"],
						type = "description",
						fontSize = "large",
						order = 100,
						--width = "full",
					},
					exportMode = {
						name = "",
						desc = L["What should be exported"],
						order = 101,
						type = "select",
						values = {
								["ALL"] = L["All Settings and Data"],
								["CDDATA"] = L["Cooldown Data Only"],
								["SETTINGS"] = L["CDTL3 Settings Only"],
							},
						get = function(info, index)
								return CDTL3.db.profile.global["exportMode"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["exportMode"] = val
							end,
					},
					exportbox = {
						name = "",
						type = "input",
						multiline = 10,
						order = 200,
						width = "full",
						get = function(info)
								-- a "!CDTL3:2!" share string (Helpers.lua), with this client and CDTL3 version
								return CDTL3:ExportString(CDTL3.db.profile.global["exportMode"])
							end,
						set = function(info, val)
								return nil
							end,
					},
					spacer300 = {
						name = "\n" .. L["Import"],
						type = "description",
						fontSize = "large",
						order = 300,
						--width = "full",
					},
					importMode = {
						name = "",
						desc = L["What should be imported"],
						order = 301,
						type = "select",
						values = {
								["ALL"] = L["All Settings and Data"],
								["CDDATA"] = L["Cooldown Data Only"],
								["SETTINGS"] = L["CDTL3 Settings Only"],
							},
						get = function(info, index)
								return CDTL3.db.profile.global["importMode"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["importMode"] = val
							end,
					},
					importNewProfile = {
						name = L["Import into a new profile"],
						desc = L["Import into a new profile (Imported, Imported 2, ...) and switch to it, leaving this profile as it is"],
						order = 302,
						type = "toggle",
						width = 1.5,
						get = function(info)
								return CDTL3.db.global["importNewProfile"] == true
							end,
						set = function(info, val)
								CDTL3.db.global["importNewProfile"] = val or nil
							end,
					},
					importbox = {
						name = "",
						type = "input",
						multiline = 10,
						order = 400,
						width = "full",
						-- a preview of what the string holds, with Accept / Cancel, before anything is written
						confirm = function(info, val)
								return CDTL3:ImportPreview(val)
							end,
						get = function(info)
								return ""
							end,
						set = function(info, val)
								return CDTL3:ImportHandler(val)
							end,
					},
				}
			},
			changelog = {
				name = L["Changelog"],
				type = "group",
				order = 400,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = function() return "CDTL3 v"..CDTL3.version.."\n\n" end,
						fontSize = "large",
						type = "description",
						order = 100,
					},
					support = {
						name = L["Issues & suggestions (GitHub; or comment on CurseForge)"],
						type = "input",
						order = 200,
						width = "full",
						get = function(info)
							return CDTL3.supportlink
							end,
						set = function(info, val)
								return nil
							end,
					},
					spacer300 = {
						name = function(info)
							local info = ""
							info = info..CDTL3:GetChangeLog()
							return info
						end,
						type = "description",
						order = 300,
					},
				},
			},
		},
	}

	private.AddSchoolColorArgs(options.args.colors.args)
	private.AddStyleArgs(options.args)
	private.AddPreviewArgs(options.args.global.args)

	return options
end

function CDTL3:GetFilterOptions()
	local options = private.BuildFilterOptions()

	-- a timer type another addon registered has no saved list, Ignore Threshold or Set All: only
	-- Enabled and the default lane, bar frame and Ready frame apply
	local defaultsArgs = options.args.defaults.args
	for _, k in ipairs({ "clearAll", "showByDefault", "ignoreThreshold", "setDefaultLane", "setDefaultBar", "setDefaultReady" }) do
		local hidden = defaultsArgs[k].hidden
		defaultsArgs[k].hidden = function(info)
			if CDTL3.timerTypes and CDTL3.timerTypes[string.lower(CDTL3.currentFilter["default"] or "")] then
				return true
			end
			if type(hidden) == "function" then
				return hidden(info)
			end
			return hidden
		end
	end

	CDTL3:AddGroupDefaultsArgs(defaultsArgs)

	return options
end

private.BuildFilterOptions = function()
	local options = {
		name = L["Filters"],
		type = "group",
		childGroups  = "tab",
		args = {
			defaults = {
				name = L["Defaults"],
				type = "group",
				order = 100,
				args = {
					spacer100 = {
						name = "\n\n" .. L["Select a type to edit its default settings"] .. "\n",
						type = "description",
						order = 100,
					},
					list = {
						name = "",
						desc = "",
						order = 101,
						type = "select",
						values = function(info)
								local choices = {}
									choices["SPELLS"] = L["Spells"]
									choices["ITEMS"] = L["Items"]
									choices["BUFFS"] = L["Buffs"]
									choices["DEBUFFS"] = L["Debuffs"]
									choices["OFFENSIVES"] = L["Offensives"]
									choices["PETSPELLS"] = L["Pet Spells"]
									choices["CUSTOMS"] = L["Customs"]

									--[[if CDTL3.db.profile.global["debugMode"] then
										choices["OTHER"] = "Other"
									end]]--
									
								-- timer types other addons registered (CDTL3:RegisterTimerType)
									for key, t in pairs(CDTL3.timerTypes or {}) do
										CDTL3:TimerTypeSettings(key)
										choices[string.upper(key)] = t.name
									end

									if CDTL3.player["class"] == "DEATHKNIGHT" then
									choices["RUNES"] = L["Runes"]
								end
								
								return choices
							end,
						get = function(info)
								return CDTL3.currentFilter["default"]
							end,
						set = function(info, val)
								CDTL3.currentFilter["default"] = val
								CDTL3.currentFilterHidden["default"] = false
							end,
					},
					spacer102 = {
						name = "\n",
						type = "description",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						order = 102,
					},
					clearAll = {
						name = L["Clear Settings"],
						desc = function(info)
								return string.format(L["This will clear this character's %s cooldown settings"], private.TypeNoun())
							end,
						confirm = true,
						order = 103,
						type = "execute",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						func = function(info)
								local default = CDTL3.currentFilter["default"]
								
								-- only this character's entries (the ones Filters lists); other
								-- characters on a shared profile keep theirs, shared ones included.
								-- Rebuilt in place so the saved list stays a list with no holes.
								local list = CDTL3.db.profile.tables[string.lower(default)]
								local kept = {}
								for _, v in pairs(list) do
									if private.KeepAfterClear(v) then
										table.insert(kept, v)
									else
										CDTL3:ForgetSharedEntry(string.lower(default), v)
									end
								end
								for k in pairs(list) do
									list[k] = nil
								end
								for i, v in ipairs(kept) do
									list[i] = v
								end
								
								CDTL3.currentFilter[string.lower(default)] = "<< Select >>"
								CDTL3.currentFilterHidden[string.lower(default)] = true
							end
					},
					clearQuestItems = {
						name = L["Clear Quest Items"],
						desc = function(info)
								return L["This will clear this character's saved settings of quest items"]
							end,
						confirm = true,
						order = 104,
						type = "execute",
						hidden = function(info)
								if string.lower(CDTL3.currentFilter["default"]) ~= "items" then
									return true
								end
								
								return false
							end,
						func = function(info)
								local cleanTable = {}
						
								for k, v in pairs(CDTL3.db.profile.tables["items"]) do
									local _, _, _, _, _, classID, subclassID = CDTL3.Compat.GetItemInfoInstant(v["itemID"])
									
									if classID ~= 12 or private.KeepAfterClear(v) then
										table.insert(cleanTable, v)
									else
										CDTL3:ForgetSharedEntry("items", v)
									end
								end
								
								CDTL3.db.profile.tables["items"] = cleanTable

								-- the Items tab may still have a cleared item selected
								CDTL3:ResetStaleFilters()
							end
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						order = 200,
					},
					enabled = {
						name = L["Enabled"],
						desc = L["If unselected cooldowns of this type will be ignored"],
						order = 201.1,
						type = "toggle",
						--width = "half",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						get = function(info, index)
								local default = CDTL3.currentFilter["default"]
								return CDTL3.db.profile.global[string.lower(default)]["enabled"]
							end,
						set = function(info, val)
								local default = CDTL3.currentFilter["default"]
								CDTL3.db.profile.global[string.lower(default)]["enabled"] = val
								
								for _, cd in pairs(CDTL3.cooldowns) do
									if cd.data["type"] == string.lower(default) then
										cd.data["enabled"] = val
									end
								end
							end,
					},
					onlyPlayer = {
						name = L["Player Only"],
						desc = function(info)
								local default = string.lower(CDTL3.currentFilter["default"])
								return string.format(L["If selected only %s applied by the player will be tracked"], private.TypeNoun())
							end,
						order = 201.2,
						type = "toggle",
						--width = "half",
						hidden = function(info)
								local default = string.lower(CDTL3.currentFilter["default"])
								
								if default == "buffs" or default == "debuffs" then
									return false
								end
								
								return true
							end,
						get = function(info, index)
								local default = string.lower(CDTL3.currentFilter["default"])
								
								if default == "buffs" or default == "debuffs" then
									return CDTL3.db.profile.global[default]["onlyPlayer"]
								end
								
								return false
							end,
						set = function(info, val)
								local default = string.lower(CDTL3.currentFilter["default"])
								
								if default == "buffs" or default == "debuffs" then
									CDTL3.db.profile.global[default]["onlyPlayer"] = val
								end
							end,
					},
					showByDefault = {
						name = L["Show by Default"],
						desc = L["If unselected you will need to manually enable each newly detected cooldown in order for them to show as bars/icons"],
						order = 202.1,
						type = "toggle",
						--width = "half",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						get = function(info, index)
								local default = CDTL3.currentFilter["default"]
								return CDTL3.db.profile.global[string.lower(default)]["showByDefault"]
							end,
						set = function(info, val)
								local default = CDTL3.currentFilter["default"]
								CDTL3.db.profile.global[string.lower(default)]["showByDefault"] = val
							end,
					},
					useItemIcon = {
						name = L["Use Item Icon"],
						desc = L["If selected the displayed icon will be the item icon\nOtherwise the spell icon will be used instead"],
						order = 202.1,
						type = "toggle",
						--width = "half",
						hidden = function(info)
								local default = string.lower(CDTL3.currentFilter["default"])
								
								if default == "items" then
									return false
								end
								
								return true
							end,
						get = function(info, index)
								local default = string.lower(CDTL3.currentFilter["default"])
								if default == "items" then
									return CDTL3.db.profile.global[default]["useItemIcon"]
								end
								
								return nil
							end,
						set = function(info, val)
								local default = string.lower(CDTL3.currentFilter["default"])
								if default == "items" then
									CDTL3.db.profile.global[default]["useItemIcon"] = val
									CDTL3:RefreshAllIcons()
									CDTL3:RefreshAllBars()
								end
							end,
					},
					spacer250 = {
						name = "\n\n",
						type = "description",
						order = 250,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
					},
					ignoreThreshold = {
						name = L["Ignore Threshold"],
						desc = L["Any cooldown/duration longer than this (in seconds, up to 7200) will be disabled by default"] .. "\n",
						order = 251,
						type = "range",
						-- hard limits, so the slider can reach and show every value (defaults go to 3600)
						min = 1,
						max = 7200,
						bigStep = 1,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						get = function(info, index)
								local default = CDTL3.currentFilter["default"]
								return math.min(CDTL3.db.profile.global[string.lower(default)]["ignoreThreshold"] or 0, 7200)
							end,
						set = function(info, val)
								local default = CDTL3.currentFilter["default"]
								CDTL3.db.profile.global[string.lower(default)]["ignoreThreshold"] = val
								
								for _, spell in pairs(CDTL3.cooldowns) do
									if spell.data["type"] == string.lower(default) then
										if spell.data["baseCD"] > val then	-- baseCD is already in seconds
											CDTL3:SendToHolding(spell)
											CDTL3:SendToBarHolding(spell)
										else
											-- a move, not a restart (see MoveToLane, Cooldown.lua)
											CDTL3:MoveToLane(spell)
											CDTL3:SendToBarFrame(spell)
										end
									end
								end
								
								-- only this character's entries (the ones Filters lists)
								for _, spell in pairs(CDTL3.db.profile.tables[string.lower(default)]) do
									if CDTL3:IsMyEntry(spell) then
										if spell["bCD"] / 1000 > 3 and spell["bCD"] / 1000 <= val then
											spell["ignored"] = false
										else
											spell["ignored"] = true
										end
									end
								end
								
								CDTL3:ScanCurrentCooldowns(CDTL3.player["class"], CDTL3.player["race"])
							end,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
					},
					defaultLane = {
						name = L["Default Lane"],
						desc = function(info)
								return string.format(L["Set the default lane all new %s icons will use"], private.TypeNoun())
							end,
						order = 301,
						type = "select",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
						get = function(info)
								local default = CDTL3.currentFilter["default"]
								return CDTL3.db.profile.global[string.lower(default)]["defaultLane"]
							end,
						set = function(info, val)
								local default = CDTL3.currentFilter["default"]
								CDTL3.db.profile.global[string.lower(default)]["defaultLane"] = val
							end,
					},
					setDefaultLane = {
						name = L["Set All"],
						desc = function(info)
								return string.format(L["This will override current settings, and set all of this character's %s cooldowns to the default value"], private.TypeNoun())
							end,
						confirm = true,
						order = 302,
						type = "execute",hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						func = function(info)
								-- Move live cooldowns of this type too. (This used to compare seconds
								-- against a frame number and disable every cooldown over 3s.) Only
								-- icons still counting down are re-parented, keeping their remaining
								-- time; finished ones just get the new lane for next time.
								local default = CDTL3.currentFilter["default"]
								local target = CDTL3.db.profile.global[string.lower(default)]["defaultLane"]
								for _, spell in pairs(CDTL3.cooldowns) do
									if spell.data["type"] == string.lower(default) then
										spell.data["lane"] = target
										CDTL3:MoveToLane(spell)
									end
								end
								
								-- only this character's entries (the ones Filters lists)
								for _, spell in pairs(CDTL3.db.profile.tables[string.lower(default)]) do
									if CDTL3:IsMyEntry(spell) then
										spell["lane"] = CDTL3.db.profile.global[string.lower(default)]["defaultLane"]
									end
								end
								
								CDTL3:RefreshAllIcons()
							end
					},
					spacer310 = {
						name = "\n",
						type = "description",
						order = 310,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
					},
					defaultBar = {
						name = L["Default Bar"],
						desc = function(info)
								return string.format(L["Set the default bar frame all new %s will use"], private.TypeNoun())
							end,
						order = 311,
						type = "select",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
						get = function(info)
								local default = CDTL3.currentFilter["default"]
								return CDTL3.db.profile.global[string.lower(default)]["defaultBar"]
							end,
						set = function(info, val)
								local default = CDTL3.currentFilter["default"]
								CDTL3.db.profile.global[string.lower(default)]["defaultBar"] = val
							end,
					},
					setDefaultBar = {
						name = L["Set All"],
						desc = function(info)
								return string.format(L["This will override current settings, and set all of this character's %s cooldowns to the default value"], private.TypeNoun())
							end,
						confirm = true,
						order = 312,
						type = "execute",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						func = function(info)
								-- Move live cooldowns of this type too. (This used to compare seconds
								-- against a frame number and disable every cooldown over 3s.) Only
								-- icons still counting down are re-parented, keeping their remaining
								-- time; finished ones just get the new barFrame for next time.
								local default = CDTL3.currentFilter["default"]
								local target = CDTL3.db.profile.global[string.lower(default)]["defaultBar"]
								for _, spell in pairs(CDTL3.cooldowns) do
									if spell.data["type"] == string.lower(default) then
										spell.data["barFrame"] = target
										local remaining = spell.data["currentCD"]
										if remaining and remaining > 0 then
											CDTL3:SendToBarFrame(spell)
											spell.data["currentCD"] = remaining
										end
									end
								end
								
								-- only this character's entries (the ones Filters lists)
								for _, spell in pairs(CDTL3.db.profile.tables[string.lower(default)]) do
									if CDTL3:IsMyEntry(spell) then
										spell["barFrame"] = CDTL3.db.profile.global[string.lower(default)]["defaultBar"]
									end
								end
								
								CDTL3:RefreshAllBars()
							end
					},
					spacer320 = {
						name = "\n",
						type = "description",
						order = 320,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
					},
					defaultReady = {
						name = L["Default Ready"],
						desc = function(info)
								return string.format(L["Set the default ready frame all new %s icons will use"], private.TypeNoun())
							end,
						order = 321,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						type = "select",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
						get = function(info)
								local default = CDTL3.currentFilter["default"]
								return CDTL3.db.profile.global[string.lower(default)]["defaultReady"]
							end,
						set = function(info, val)
								local default = CDTL3.currentFilter["default"]
								CDTL3.db.profile.global[string.lower(default)]["defaultReady"] = val
							end,
					},
					setDefaultReady = {
						name = L["Set All"],
						desc = function(info)
								return string.format(L["This will override current settings, and set all of this character's %s cooldowns to the default value"], private.TypeNoun())
							end,
						confirm = true,
						order = 322,
						type = "execute",hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						func = function(info)
								-- Update live cooldowns of this type too. (This used to compare seconds
								-- against a frame number and disable every cooldown over 3s.) Icons
								-- only reach a Ready frame when they finish, so just record it.
								local default = CDTL3.currentFilter["default"]
								local target = CDTL3.db.profile.global[string.lower(default)]["defaultReady"]
								for _, spell in pairs(CDTL3.cooldowns) do
									if spell.data["type"] == string.lower(default) then
										spell.data["readyFrame"] = target
									end
								end
								
								-- only this character's entries (the ones Filters lists)
								for _, spell in pairs(CDTL3.db.profile.tables[string.lower(default)]) do
									if CDTL3:IsMyEntry(spell) then
										spell["readyFrame"] = CDTL3.db.profile.global[string.lower(default)]["defaultReady"]
									end
								end
								
								CDTL3:RefreshAllIcons()
							end
					},
				},
			},
			spells = private.GetFilterSet("spells", 100),
			items = private.GetFilterSet("items", 200),
			buffs = private.GetFilterSet("buffs", 300),
			debuffs = private.GetFilterSet("debuffs", 400),
			offensives = private.GetFilterSet("offensives", 500),
			petspells = private.GetFilterSet("petspells", 600),
			customs = private.GetCustomSet("customs", 800),
			runes = private.GetFilterSet("runes", 900),
		}
	}
	
	return options
end

function CDTL3:GetLaneOptions()
	local options = {
		name = L["Lanes"],
		type = "group",
		childGroups  = "tab",
		args = {
			lane1 = private.GetLaneSet(1),
			lane2 = private.GetLaneSet(2),
			lane3 = private.GetLaneSet(3),
		}
	}
	
	return options
end

function CDTL3:GetReadyOptions()
	local options = {
		name = L["Ready"],
		type = "group",
		childGroups  = "tab",
		args = {
			ready1 = private.GetReadySet(1),
			ready2 = private.GetReadySet(2),
			ready3 = private.GetReadySet(3),
		}
	}
	private.AddReadySoundArgs(options.args)

	return options
end

function CDTL3:GetBarFrameOptions()
	local options = {
		name = L["Bar Frames"],
		type = "group",
		childGroups  = "tab",
		args = {
			barFrame1 = private.GetBarFrameSet(1),
			barFrame2 = private.GetBarFrameSet(2),
			barFrame3 = private.GetBarFrameSet(3),
		}
	}
	
	return options	
end

private.GetBarFrameSet = function(i)
	local frame = nil
	
	if i == 1 then
		frame = CDTL3.db.profile.barFrames["frame1"]
	elseif i == 2 then
		frame = CDTL3.db.profile.barFrames["frame2"]
	elseif i == 3 then
		frame = CDTL3.db.profile.barFrames["frame3"]
	end
	
	local options = {
		name = function(info)
				return frame["name"]
			end,
		type = "group",
		order = 100,
		args = {
			general = {
				name = L["General"],
				type = "group",
				order = 100,
				args = {
					barFrameName = {
						name = L["Frame Name"],
						type = "input",
						order = 101,
						get = function(info)
								return frame["name"]
							end,
						set = function(info, val)
								frame["name"] = val
								CDTL3:RefreshBarFrame(i)
							end,
					},
					barFrameEnabled = {
						name = L["Enabled"],
						desc = "",
						order = 102,
						type = "toggle",
						get = function(info, index)
								return frame["enabled"]
							end,
						set = function(info, val)
								frame["enabled"] = val
								
								if val then
									CDTL3:CreateBarFrames()
								end
								
								CDTL3:RefreshBarFrame(i)
							end,
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						order = 200,
					},
					grow = {
						name = L["Grow Direction"],
						desc = L["Select which direction new bars will grow in"],
						order = 201,
						type = "select",
						values = {
								["UP"] = "UP",
								["DOWN"] = "DOWN",
								["LEFT"] = "LEFT",
								["RIGHT"] = "RIGHT",
								["CENTER_H"] = "CENTER (H)",
								["CENTER_V"] = "CENTER (V)",
							},
						get = function(info, index)
								return frame["grow"]
							end,
						set = function(info, val)
								frame["grow"] = val
							end,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					hideTransitioned = {
						name = L["Transition bars"],
						desc = L["If enabled, bars will be hidden once its cooldown drops below the lane max time, and its icon has appeared"],
						order = 301,
						type = "toggle",
						get = function(info, index)
								return frame["transition"]["hideTransitioned"]
							end,
						set = function(info, val)
								frame["transition"]["hideTransitioned"] = val
							end,
					},
					spacer310 = {
						name = "",
						type = "description",
						order = 310,
						hidden = function(info)
								return not frame["transition"]["hideTransitioned"]
							end,
					},
					showTI = {
						name = L["Show Indicator"],
						desc = L["If enabled, the bar will have an indicator showing when it will transition"],
						order = 311,
						type = "toggle",
						hidden = function(info)
								return not frame["transition"]["hideTransitioned"]
							end,
						get = function(info, index)
								return frame["transition"]["showTI"]
							end,
						set = function(info, val)
								frame["transition"]["showTI"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					style = {
						name = L["Indicator Style"],
						desc = L["Select a style of indicator"],
						order = 312,
						type = "select",
						hidden = function(info)
								if frame["transition"]["hideTransitioned"] then
									if frame["transition"]["showTI"] then
										return false
									end
								end
								
								return true
							end,
						values = {
								["SHORTEN"] = L["Shorten"],
								["LINE"] = L["Line"],
								["REGION"] = L["Region"],
							},
						get = function(info, index)
								return frame["transition"]["style"]
							end,
						set = function(info, val)
								frame["transition"]["style"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					spacer320 = {
						name = "",
						type = "description",
						hidden = function(info)
								if frame["transition"]["hideTransitioned"] then
									if frame["transition"]["showTI"] then
										local style = frame["transition"]["style"]
										if style == "LINE" or style == "REGION" then
											return false
										end
									end
								end
								
								return true
							end,
						order = 320,
					},
					fgTexture = {
						name = L["Indicator Texture"],
						desc = L["Selects the texture"],
						order = 321,
						type = "select",
						hidden = function(info)
								if frame["transition"]["hideTransitioned"] then
									if frame["transition"]["showTI"] then
										local style = frame["transition"]["style"]
										if style == "LINE" or style == "REGION" then
											return false
										end
									end
								end
								
								return true
							end,
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return frame["transition"]["texture"]
							end,
						set = function(info, val)
								frame["transition"]["texture"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					fgTextureColor = {
						name = L["Indicator Color"],
						desc = L["Sets the texture color"],
						order = 322,
						type = "color",
						hidden = function(info)
								if frame["transition"]["hideTransitioned"] then
									if frame["transition"]["showTI"] then
										local style = frame["transition"]["style"]
										if style == "LINE" or style == "REGION" then
											return false
										end
									end
								end
								
								return true
							end,
						hasAlpha = true,
						get = function(info)
								local r = frame["transition"]["textureColor"]["r"]
								local g = frame["transition"]["textureColor"]["g"]
								local b = frame["transition"]["textureColor"]["b"]
								local a = frame["transition"]["textureColor"]["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								frame["transition"]["textureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshAllBars()
							end,
					},
					spacer330 = {
						name = "",
						type = "description",
						order = 330,
						hidden = function(info)
								if frame["transition"]["hideTransitioned"] then
									if frame["transition"]["showTI"] then
										local style = frame["transition"]["style"]
										if style == "LINE" then
											return false
										end
									end
								end
								
								return true
							end,
					},
					widthTI = {
						name = L["Indicator Line Width"],
						desc = L["Sets the width of the transition indicator line"],
						order = 331,
						type = "range",
						hidden = function(info)
								if frame["transition"]["hideTransitioned"] then
									if frame["transition"]["showTI"] then
										local style = frame["transition"]["style"]
										if style == "LINE" then
											return false
										end
									end
								end
								
								return true
							end,
						softMin = 0,
						softMax = 40,
						bigStep = 1,
						get = function(info, index)
								return frame["transition"]["width"]
							end,
						set = function(info, val)
								frame["transition"]["width"] = val
						end,
					},
					
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
					},
					xPadding = {
						name = L["x Padding"],
						desc = L["Sets the x offset between growing bars"],
						order = 601,
						type = "range",
						softMin = -20,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return frame["bar"]["xPadding"]
							end,
						set = function(info, val)
								frame["bar"]["xPadding"] = val
						end,
					},
					yPadding = {
						name = L["y Padding"],
						desc = L["Sets the y offset between growing bars"],
						order = 602,
						type = "range",
						softMin = -20,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return frame["bar"]["yPadding"]
							end,
						set = function(info, val)
								frame["bar"]["yPadding"] = val
						end,
					},
				}
			},
			appearance = {
				name = L["Appearance"],
				type = "group",
				order = 200,
				args = {
					posX = {
						name = L["x Position"],
						desc = L["Sets the x position of the frame"],
						order = 111,
						type = "range",
						softMin = -500,
						softMax = 500,
						bigStep = 1,
						get = function(info, index)
								return frame["posX"]
							end,
						set = function(info, val)
								frame["posX"] = val
								CDTL3:RefreshBarFrame(i)
							end,
					},
					posY = {
						name = L["y Position"],
						desc = L["Sets the y position of the frame"],
						order = 112,
						type = "range",
						softMin = -500,
						softMax = 500,
						bigStep = 1,
						get = function(info, index)
								return frame["posY"]
							end,
						set = function(info, val)
								frame["posY"] = val
								CDTL3:RefreshBarFrame(i)
							end,
					},
					spacer113 = {
						name = "",
						type = "description",
						order = 113,
					},
					relativeTo = {
						name = L["Anchor Point"],
						desc = L["The x/y position is relative to this point of the screen"],
						order = 114,
						type = "select",
						values = {
								["TOPLEFT"] = "TOPLEFT",
								["TOP"] = "TOP",
								["TOPRIGHT"] = "TOPRIGHT",
								["LEFT"] = "LEFT",
								["CENTER"] = "CENTER",
								["RIGHT"] = "RIGHT",
								["BOTTOMLEFT"] = "BOTTOMLEFT",
								["BOTTOM"] = "BOTTOM",
								["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							},
						get = function(info, index)
								return frame["relativeTo"]
							end,
						set = function(info, val)
								frame["relativeTo"] = val
								CDTL3:RefreshBarFrame(i)
							end,
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						order = 200,
					},
					padding = {
						name = L["Padding"],
						desc = L["Sets the amount of padding in the frame"],
						order = 201,
						type = "range",
						softMin = 0,
						softMax = 40,
						bigStep = 1,
						get = function(info, index)
								return frame["padding"]
							end,
						set = function(info, val)
								frame["padding"] = val
								CDTL3:RefreshAllIcons()
								CDTL3:RefreshBarFrame(i)
						end,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					bgTexture = {
						name = L["Background Texture"],
						desc = L["Sets the background texture"],
						order = 301,
						type = "select",
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return frame["bgTexture"]
							end,
						set = function(info, val)
								frame["bgTexture"] = val
								CDTL3:RefreshBarFrame(i)
							end,
					},
					bgTextureColor = {
						name = L["Color"],
						desc = L["Sets the background texture color"],
						order = 302,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local r = frame["bgTextureColor"]["r"]
								local g = frame["bgTextureColor"]["g"]
								local b = frame["bgTextureColor"]["b"]
								local a = frame["bgTextureColor"]["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								frame["bgTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshBarFrame(i)
							end,
					},
					spacer400 = {
						name = "\n\n",
						type = "description",
						order = 400,
					},
				}
			},
			bars = {
				name = L["Bars"],
				type = "group",
				order = 300,
				args = {
					width = {
						name = L["Width"],
						desc = L["Sets the width of the bars"],
						order = 101,
						type = "range",
						min = 1,
						max = 600,
						bigStep = 1,
						get = function(info, index)
								return frame["width"]
							end,
						set = function(info, val)
								frame["width"] = val
								CDTL3:RefreshAllBars()
								CDTL3:RefreshBarFrame(i)
						end,
					},
					height = {
						name = L["Height"],
						desc = L["Sets the height of the bars"],
						order = 102,
						type = "range",
						softMin = 1,
						softMax = 100,
						bigStep = 1,
						get = function(info, index)
								return frame["height"]
							end,
						set = function(info, val)
								frame["height"] = val
								CDTL3:RefreshAllBars()
								CDTL3:RefreshBarFrame(i)
						end,
					},
					spacer102 = {
						name = "\n\n",
						type = "description",
						order = 103,
					},
					fgTexture = {
						name = L["Foreground Texture"],
						desc = L["Selects the texture"],
						order = 104,
						type = "select",
						width = 0.7,
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return frame["bar"]["fgTexture"]
							end,
						set = function(info, val)
								frame["bar"]["fgTexture"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					fgTextureColor = {
						name = L["Color"],
						desc = L["Sets the texture color"],
						order = 105,
						type = "color",
						width = 0.4,
						hasAlpha = true,
						disabled  = function(info)
								-- Spell School Color is ignored without a combat log (Cooldown.lua
								-- GetBarFGColor), so it doesn't grey this out there
								if frame["bar"]["fgClassColor"] or (frame["bar"]["fgSchoolColor"] and not private.NoCombatLog()) then
									return true
								end
								
								return false
							end,
						get = function(info)
								local c = frame["bar"]["fgTextureColor"] or { r=0.77647, g=0.11765, b=0.28235, a=1 }
								if frame["bar"]["fgClassColor"] then
									-- before the character is known (first seconds after login) keep the stored colour
									c = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]] or c
								end

								local r = c["r"]
								local g = c["g"]
								local b = c["b"]
								local a = c["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								frame["bar"]["fgTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshAllBars()
							end,
					},
					fgClassColor = {
						name = L["Class Color"],
						desc = L["Set the texture color to your class color"],
						order = 107,
						type = "toggle",
						width = 0.5,
						get = function(info)
								return frame["bar"]["fgClassColor"]
							end,
						set = function(info, val)
								frame["bar"]["fgClassColor"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					spacer109 = {
						name = "",
						type = "description",
						order = 109,
					},
					bgTexture = {
						name = L["Background Texture"],
						desc = L["Sets the background texture"],
						order = 110,
						type = "select",
						width = 0.7,
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return frame["bar"]["bgTexture"]
							end,
						set = function(info, val)
								frame["bar"]["bgTexture"] = val
								CDTL3:RefreshAllBars(i)
							end,
					},
					bgTextureColor = {
						name = L["Color"],
						desc = L["Sets the background texture color"],
						order = 111,
						type = "color",
						width = 0.4,
						hasAlpha = true,
						disabled  = function(info)
								if frame["bar"]["bgClassColor"] or frame["bar"]["bgSchoolColor"] then
									return true
								end
								
								return false
							end,
						get = function(info)
								local c = frame["bar"]["bgTextureColor"]
								if frame["bar"]["bgClassColor"] then
									-- before the character is known (first seconds after login) keep the stored colour
									c = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]] or c
								end
						
								local r = c["r"]
								local g = c["g"]
								local b = c["b"]
								local a = c["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								frame["bar"]["bgTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshAllBars(i)
							end,
					},
					bgClassColor = {
						name = L["Class Color"],
						desc = L["Set the texture color to your class color"],
						order = 113,
						type = "toggle",
						width = 0.5,
						get = function(info)
								return frame["bar"]["bgClassColor"]
							end,
						set = function(info, val)
								frame["bar"]["bgClassColor"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					fgSchoolColor = {
						name = L["Spell School Color"],
						desc = L["Color each bar by its spell's school (fire, frost, etc). Schools are learned from the combat log as you cast; set the colors under Colors."],
						order = 108,
						type = "toggle",
						width = 0.7,
						hidden = private.NoCombatLog,
						get = function(info)
								return frame["bar"]["fgSchoolColor"]
							end,
						set = function(info, val)
								frame["bar"]["fgSchoolColor"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					dynamicHeader = {
						name = L["Dynamic Color"],
						type = "header",
						order = 114.1,
					},
					dynamicEnabled = {
						name = L["Enable Dynamic Color"],
						desc = L["As a cooldown approaches ready, the bar blends from the warning color into the ready color. Above the warning window the normal bar color applies."],
						order = 114.2,
						type = "toggle",
						width = 1,
						get = function(info)
								return frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["enabled"]
							end,
						set = function(info, val)
								frame["bar"]["dynamicColor"] = frame["bar"]["dynamicColor"] or {}
								frame["bar"]["dynamicColor"]["enabled"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					dynamicWarnTime = {
						name = L["Warning Window (sec)"],
						desc = L["How many seconds before ready the color blend begins"],
						order = 114.3,
						type = "range",
						softMin = 1,
						softMax = 30,
						bigStep = 0.5,
						disabled = function(info)
								return not ( frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["enabled"] )
							end,
						get = function(info)
								return ( frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["warnTime"] ) or 5
							end,
						set = function(info, val)
								frame["bar"]["dynamicColor"] = frame["bar"]["dynamicColor"] or {}
								frame["bar"]["dynamicColor"]["warnTime"] = val
							end,
					},
					dynamicWarnColor = {
						name = L["Warning Color"],
						desc = L["Bar color when the warning window begins"],
						order = 114.4,
						type = "color",
						width = 0.5,
						hasAlpha = true,
						disabled = function(info)
								return not ( frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["enabled"] )
							end,
						get = function(info)
								local c = ( frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["warnColor"] ) or { r = 1, g = 0.6, b = 0, a = 1 }
								return c["r"], c["g"], c["b"], c["a"]
							end,
						set = function(info, red, green, blue, alpha)
								frame["bar"]["dynamicColor"] = frame["bar"]["dynamicColor"] or {}
								frame["bar"]["dynamicColor"]["warnColor"] = { r = red, g = green, b = blue, a = alpha }
							end,
					},
					dynamicReadyColor = {
						name = L["Ready Color"],
						desc = L["Bar color the moment the cooldown is ready"],
						order = 114.5,
						type = "color",
						width = 0.5,
						hasAlpha = true,
						disabled = function(info)
								return not ( frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["enabled"] )
							end,
						get = function(info)
								local c = ( frame["bar"]["dynamicColor"] and frame["bar"]["dynamicColor"]["readyColor"] ) or { r = 0.2, g = 0.9, b = 0.2, a = 1 }
								return c["r"], c["g"], c["b"], c["a"]
							end,
						set = function(info, red, green, blue, alpha)
								frame["bar"]["dynamicColor"] = frame["bar"]["dynamicColor"] or {}
								frame["bar"]["dynamicColor"]["readyColor"] = { r = red, g = green, b = blue, a = alpha }
							end,
					},
					spacer115 = {
						name = "\n\n",
						type = "description",
						order = 115,
					},
					textHeader = {
						name = L["Bar Text"],
						type = "header",
						order = 200.1,
					},
					-- BAR TEXT 1
					bText1Text = private.GetTextText(frame["bar"]["text1"], 210, i, "BAR", false),
					bText1Enabled = private.GetTextEnabled(frame["bar"]["text1"], 210, i, "BAR"),
					bText1Edit = private.GetTextEdit(frame["bar"]["text1"], 210, i, "BAR"),
					bText1Font = private.GetTextFont(frame["bar"]["text1"], 210, i, "BAR"),
					bText1Outline = private.GetTextOutline(frame["bar"]["text1"], 210, i, "BAR"),
					bText1S1 = { name = "", type = "description", order = 210 + 4.3, hidden = function(info) return not frame["bar"]["text1"]["edit"] end, },
					bText1Size = private.GetTextSize(frame["bar"]["text1"], 210, i, "BAR"),
					bText1Color = private.GetTextColor(frame["bar"]["text1"], 210, i, "BAR"),
					bText1ShadowColor = private.GetTextShadowColor(frame["bar"]["text1"], 210, i, "BAR"),
					bText1S2 = { name = "", type = "description", order = 210 + 4.7, hidden = function(info) return not frame["bar"]["text1"]["edit"] end, },
					bText1ShadowXOffset = private.GetTextShadowXOffset(frame["bar"]["text1"], 210, i, "BAR"),
					bText1ShadowYOffset = private.GetTextShadowYOffset(frame["bar"]["text1"], 210, i, "BAR"),
					bText1S3 = { name = "", type = "description", order = 210 + 5.1, hidden = function(info) return not frame["bar"]["text1"]["edit"] end, },
					bText1Anchor = private.GetTextAnchor(frame["bar"]["text1"], 210, i, "BAR"),
					bText1Align = private.GetTextAlign(frame["bar"]["text1"], 210, i, "BAR"),
					bText1S4 = { name = "", type = "description", order = 210 + 5.4, hidden = function(info) return not frame["bar"]["text1"]["edit"] end, },
					bText1XOffset = private.GetTextXOffset(frame["bar"]["text1"], 210, i, "BAR"),
					bText1YOffset = private.GetTextYOffset(frame["bar"]["text1"], 210, i, "BAR"),
					bText1Footer = { name = "", type = "header", order = 210 + 9.8, hidden = function(info) return not frame["bar"]["text1"]["edit"] end, },
					-- BAR TEXT 2
					bText2S0 = { name = "\n", type = "description", order = 220, hidden = function(info) return not frame["bar"]["text2"]["used"] end, },
					bText2Header = { name = "", type = "header", order = 220 + 0.1, hidden = function(info) return not frame["bar"]["text2"]["edit"] end, },
					bText2Text = private.GetTextText(frame["bar"]["text2"], 220, i, "BAR", false),
					bText2Enabled = private.GetTextEnabled(frame["bar"]["text2"], 220, i, "BAR"),
					bText2Edit = private.GetTextEdit(frame["bar"]["text2"], 220, i, "BAR"),
					bText2Font = private.GetTextFont(frame["bar"]["text2"], 220, i, "BAR"),
					bText2Outline = private.GetTextOutline(frame["bar"]["text2"], 220, i, "BAR"),
					bText2S1 = { name = "", type = "description", order = 220 + 4.3, hidden = function(info) return not frame["bar"]["text2"]["edit"] end, },
					bText2Size = private.GetTextSize(frame["bar"]["text2"], 220, i, "BAR"),
					bText2Color = private.GetTextColor(frame["bar"]["text2"], 220, i, "BAR"),
					bText2ShadowColor = private.GetTextShadowColor(frame["bar"]["text2"], 220, i, "BAR"),
					bText2S2 = { name = "", type = "description", order = 220 + 4.7, hidden = function(info) return not frame["bar"]["text2"]["edit"] end, },
					bText2ShadowXOffset = private.GetTextShadowXOffset(frame["bar"]["text2"], 220, i, "BAR"),
					bText2ShadowYOffset = private.GetTextShadowYOffset(frame["bar"]["text2"], 220, i, "BAR"),
					bText2S3 = { name = "", type = "description", order = 220 + 5.1, hidden = function(info) return not frame["bar"]["text2"]["edit"] end, },
					bText2Anchor = private.GetTextAnchor(frame["bar"]["text2"], 220, i, "BAR"),
					bText2Align = private.GetTextAlign(frame["bar"]["text2"], 220, i, "BAR"),
					bText2S4 = { name = "", type = "description", order = 220 + 5.4, hidden = function(info) return not frame["bar"]["text2"]["edit"] end, },
					bText2XOffset = private.GetTextXOffset(frame["bar"]["text2"], 220, i, "BAR"),
					bText2YOffset = private.GetTextYOffset(frame["bar"]["text2"], 220, i, "BAR"),
					bText2Footer = { name = "", type = "header", order = 220 + 9.8, hidden = function(info) return not frame["bar"]["text2"]["edit"] end, },
					-- BAR TEXT 3
					bText3S0 = { name = "\n", type = "description", order = 230, hidden = function(info) return not frame["bar"]["text3"]["used"] end, },
					bText3Header = { name = "", type = "header", order = 230 + 0.1, hidden = function(info) return not frame["bar"]["text3"]["edit"] end, },
					bText3Text = private.GetTextText(frame["bar"]["text3"], 230, i, "BAR", false),
					bText3Enabled = private.GetTextEnabled(frame["bar"]["text3"], 230, i, "BAR"),
					bText3Edit = private.GetTextEdit(frame["bar"]["text3"], 230, i, "BAR"),
					bText3Font = private.GetTextFont(frame["bar"]["text3"], 230, i, "BAR"),
					bText3Outline = private.GetTextOutline(frame["bar"]["text3"], 230, i, "BAR"),
					bText3S1 = { name = "", type = "description", order = 230 + 4.3, hidden = function(info) return not frame["bar"]["text3"]["edit"] end, },
					bText3Size = private.GetTextSize(frame["bar"]["text3"], 230, i, "BAR"),
					bText3Color = private.GetTextColor(frame["bar"]["text3"], 230, i, "BAR"),
					bText3ShadowColor = private.GetTextShadowColor(frame["bar"]["text3"], 230, i, "BAR"),
					bText3S2 = { name = "", type = "description", order = 230 + 4.7, hidden = function(info) return not frame["bar"]["text3"]["edit"] end, },
					bText3ShadowXOffset = private.GetTextShadowXOffset(frame["bar"]["text3"], 230, i, "BAR"),
					bText3ShadowYOffset = private.GetTextShadowYOffset(frame["bar"]["text3"], 230, i, "BAR"),
					bText3S3 = { name = "", type = "description", order = 230 + 5.1, hidden = function(info) return not frame["bar"]["text3"]["edit"] end, },
					bText3Anchor = private.GetTextAnchor(frame["bar"]["text3"], 230, i, "BAR"),
					bText3Align = private.GetTextAlign(frame["bar"]["text3"], 230, i, "BAR"),
					bText3S4 = { name = "", type = "description", order = 230 + 5.4, hidden = function(info) return not frame["bar"]["text3"]["edit"] end, },
					bText3XOffset = private.GetTextXOffset(frame["bar"]["text3"], 230, i, "BAR"),
					bText3YOffset = private.GetTextYOffset(frame["bar"]["text3"], 230, i, "BAR"),
					bText3Footer = { name = "", type = "header", order = 230 + 9.8, hidden = function(info) return not frame["bar"]["text3"]["edit"] end, },
					spacer298 = {
						name = "\n",
						type = "description",
						order = 298,
					},
					textFooter = {
						name = "",
						type = "header",
						order = 299,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					iconEnabled = {
						name = L["Show icon"],
						desc = "",
						order = 301,
						type = "toggle",
						get = function(info, index)
								return frame["bar"]["iconEnabled"]
							end,
						set = function(info, val)
								frame["bar"]["iconEnabled"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					iconPosition = {
						name = L["Icon position"],
						desc = L["Which side of the bar should the icon appear"],
						order = 302,
						type = "select",
						values = {
								["LEFT"] = L["Left"],
								["RIGHT"] = L["Right"],
							},
						get = function(info, index)
								return frame["bar"]["iconPosition"]
							end,
						set = function(info, val)
								frame["bar"]["iconPosition"] = val
								CDTL3:RefreshAllBars()
							end,
					},
					spacer400 = {
						name = "\n\n",
						type = "description",
						order = 400,
					},
				}
			},
		}
	}
	
	private.AddBorderArgs(options.args.appearance.args, 400, function() return frame["border"] end, function() CDTL3:RefreshBarFrame(i) end)
	CDTL3:AddAnchorArgs(options.args.appearance.args, 115, function() return frame end, function() CDTL3:RefreshBarFrame(i) end, L["bar frame"])
	private.AddBorderArgs(options.args.bars.args, 400, function() return frame["bar"]["border"] end, function() CDTL3:RefreshAllBars() end)

	private.AddCopyArgs(options.args.general.args, "barFrames", i, L["Bar Frame"])
	private.AddShowArgs(options.args.general.args, function() return frame end, function() CDTL3:RefreshBarFrame(i) end)

	return options
end

private.GetFilterSet = function(t, o)
	local options = {
		name = function(info)
				if t == "customs" then
					return L["Custom"]
				end

				local tabNames = {
					spells = L["Spells"], items = L["Items"], buffs = L["Buffs"], debuffs = L["Debuffs"],
					offensives = L["Offensives"], petspells = L["Pet Spells"], runes = L["Runes"],
				}
				return tabNames[t] or t:gsub("^%l", string.upper)
			end,
		type = "group",
		order = o,
		hidden = function(info)
				if t == "runes" then
					if CDTL3.player["class"] ~= "DEATHKNIGHT" then
						return true
					end
				end

				return false
			end,
		args = {
			spacer100 = {
				name = function(info)
						if t == "offensives" and private.NoCombatLog() then
							return "\n\n|cffffd100"..L["Offensive debuffs are detected from the combat log, which this client doesn't give to addons, so nothing new will appear here."].."|r\n\n"..L["Select something to edit its settings"].."\n"
						end

						return "\n\n"..L["Select something to edit its settings"].."\n"
					end,
				type = "description",
				order = 100,
			},
			list = {
				name = function(info)
						local n = ""
						return n
					end,
				desc = function(info)
						local n = ""
						return n
					end,
				order = 101,
				type = "select",
				values = function(info)
						local list = {}
						if t == "items" then
							list = CDTL3:LoadFilterList(t, true)
						else
							list = CDTL3:LoadFilterList(t)
						end
						return list
					end,
				get = function(info)
						return CDTL3.currentFilter[t]
					end,
				set = function(info, val)
						local list = {}
						if t == "items" then
							list = CDTL3:LoadFilterList(t, true)
						else
							list = CDTL3:LoadFilterList(t)
						end

						CDTL3.currentFilter[t] = list[val]
						CDTL3.currentFilterHidden[t] = false
					end,
			},
			spacer110 = {
				--name = "*Spells will show up here once they have been detected at least once*\n\n\n",
				name = function(info)
					if t == "customs" then
						return L["*Custom cooldowns will appear here once saved*"].."\n\n\n"
					end

					return L["*Cooldowns will appear here once they have been detected at least once*"].."\n\n\n"
					end,
				type = "description",
				order = 110,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			triggerType = {
				name = L["Trigger Type"],
				desc = L["What will trigger the cooldown to begin, a spell or aura?"],
				order = 111,
				hidden = function(info)
						if t == "customs" then
							return CDTL3.currentFilterHidden[t]
						end

						return true
					end,
				type = "select",
				width = "half",
				values = function(info)
						local choices = {}
						choices["spell"] = L["Spell"]
						choices["aura"] = L["Aura"]
							
						return choices
					end,
				get = function(info)
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if CDTL3.custom["triggerType"] then
									return CDTL3.custom["triggerType"]
								end
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["customs"], t, false)
								if s then
									return s["triggerType"]
								end
							end
						end

						return ""
					end,
				set = function(info, val)
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								CDTL3.custom["triggerType"] = val
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["customs"], t, false)
								if s then
									s["triggerType"] = val
								end
							end
						end
					end,
			},
			triggerID = {
				name = L["Trigger ID"],
				desc = L["Entering a valid Spell/Aura ID here will populate the other fields"],
				type = "input",
				order = 112,
				hidden = function(info)
						if t == "customs" then
							return CDTL3.currentFilterHidden[t]
						end

						return true
					end,
				disabled = function ()
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if not CDTL3.custom["triggerType"] then
									return true
								end
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["customs"], "customs", false)
								if s then
									if s["triggerType"] == "" then
										return true
									end
								end 
							end
						end

						return false
					end,
				get = function(info)
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if CDTL3.custom["id"] then
									return CDTL3.custom["id"]
								end
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["customs"], "customs", false)
								if s then
									return tostring(s["id"])
								end
							end
						end

						return ""
					end,
				set = function(info, val)
						if CDTL3.currentFilter[t] == "<< Add New >>" then
							local spellName, icon, originalIcon = CDTL3:GetSpellInfo(val)

							-- Retail and Forever give "" (not nil) for an ID that isn't a spell
							if spellName and spellName ~= "" then
								CDTL3.custom["id"] = tonumber(val)
								CDTL3.custom["name"] = spellName
								CDTL3.custom["icon"] = icon
								CDTL3.custom["type"] = "customs"

								CDTL3.custom["bCD"] = 60000
								CDTL3.custom["setCustomCD"] = false
								CDTL3.custom["link"] = CDTL3:GetSpellLink(val)

								-- a custom the user is adding by hand is never ignored
								CDTL3:ApplyEntryDefaults(CDTL3.custom, "customs")
								CDTL3.custom["ignored"] = false

								CDTL3.customIsValid = true
							else
								CDTL3.custom = {}
								CDTL3.customIsValid = false
							end
						else
							-- Setup editing
						end
					end,
			},
			spacer113 = {
				name = "\n",
				type = "description",
				order = 113,
				hidden = function(info)
						if t == "customs" then
							return CDTL3.currentFilterHidden[t]
						end

						return true
					end,
			},
			itemTypePrefix = {
				name = function(info)
						local n = L["Item:"].."   "
						
						return n
					end,
				type = "description",
				order = 200,
				width = 0.2,
				hidden = function(info)
						if not CDTL3.currentFilterHidden[t] then
							if t == "items" then
								return false
							end
						end
						
						return true
					end,
			},
			itemName = {
				name = function(info)
						local n = ""
						if t == "items" then
							local specialCase = true
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if CDTL3.currentFilter[t] then
								if s and s["link"] then
									n = "  "..s["link"]
								else
									n = CDTL3.currentFilter[t]
								end
							end
						end
						
						return n
					end,
				type = "description",
				order = 201,
				width = 1.5,
				fontSize = "large",
				hidden = function(info)
						if not CDTL3.currentFilterHidden[t] then
							if t == "items" then
								return false
							end
						end
						
						return true
					end,
				image = function(info)
					local specialCase = false
					if t == "items" then
						specialCase = true
					end
					local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
					
					if s then
						return s["itemIcon"]
					else
						return 134400
					end
				end,
				imageWidth = 24,
				imageHeight = 24,
				imageCoords = {0.1,0.9,0.1,0.9},
			},
			spacer202 = {
				name = "",
				type = "description",
				order = 202,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			cdType = {
				name = function(info)
						local n = " "
						
						if t == "spells" or t == "items" or t == "petspells" then
							n = L["Spell:"].."   "
						elseif t == "buffs" or t == "debuffs" or t == "offensives" then
							n = L["Aura:"].."   "
						elseif t == "runes" then
							n = L["Rune:"].."   "
						elseif t == "customs" then
							n = L["Name:"].."   "
						end
						
						return n
					end,
				type = "description",
				order = 203,
				width = 0.2,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			cdName = {
				name = function(info)
						local n = " "
						
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if CDTL3.custom["name"] then
									n = CDTL3.custom["name"]
								else
									if CDTL3.customIsValid == false then
										n = L["Enter valid trigger ID"]
									else
										n = L["New Custom"]
									end
								end
							else
								n = CDTL3.currentFilter[t]
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if CDTL3.currentFilter[t] then
								if s then
									n = "  "..s["name"]
								else
									n = CDTL3.currentFilter[t]
								end
							end
						end
						
						return n
					end,
				type = "description",
				order = 205,
				width = 1.5,
				fontSize = "large",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				image = function(info)
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if CDTL3.custom["icon"] then
									return CDTL3.custom["icon"]
								else
									return 134400
								end
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, t == "items")
							
								if s then
									return s["icon"]
								else
									return 134400
								end
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["icon"]
							else
								return 134400
							end
						end
					end,
				imageWidth = 24,
				imageHeight = 24,
				imageCoords = {0.1,0.9,0.1,0.9},
			},
			spacer300 = {
				name = " \n",
				type = "description",
				order = 300,
				width = "full",
			},
			cooldownType = {
				name = function(info)
						local n = " "
						
						if t == "spells" or t == "items" or t == "petspells" or t == "customs" then
							n = L["Cooldown:"]
						elseif t == "buffs" or t == "debuffs" or t == "offensives" then
							n = L["Duration:"]
						elseif t == "runes" then
							n = L["Recharge:"]
						end
						
						return n
					end,
				type = "description",
				order = 301,
				width = 0.3,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			cooldownValue = {
				name = function(info)
						local n = " "

						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							n = 0
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								n =	n.."  "..string.format(L["%s sec"], s["bCD"] / 1000).."\n"
							end								
						end
						
						return n
					end,
				type = "description",
				order = 302,
				hidden = function(info)
						if t == "customs" then
							return true
						else
							if CDTL3.currentFilterHidden[t] then
								return true
							else
								local specialCase = false
								if t == "items" then
									specialCase = true
								end
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)

								if s then
									if s["setCustomCD"] ~= nil then
										return s["setCustomCD"]
									end
								end
							end
						end

						return false
					end,
				width = 1.5,
				fontSize = "large",
			},
			setNewCD = {
				name = " ",
				desc = L["Set the default cooldown value."],
				order = 303,
				hidden = function(info)
						if t == "customs" then
							return CDTL3.currentFilterHidden[t]
						end

						return true
					end,
				disabled = function ()
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if not CDTL3.customIsValid then
									return true
								end
							end
						end

						return false
					end,
				type = "input",
				get = function(info, index)
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if CDTL3.custom["bCD"] then
									return tostring(CDTL3.custom["bCD"] / 1000)
								else
									return "60"
								end
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["customs"], t, false)
								if s then
									return tostring(s["bCD"] / 1000)
								else
									return "0"
								end
							end
						end

						return "999"
					end,
				validate = private.ValidateSeconds,
				set = function(info, val)
						val = tonumber(val)
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								CDTL3.custom["bCD"] = val * 1000
							else
								CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "bCD", val * 1000)
								
								local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
								if s then
									s.data["bCD"] = val * 1000
								
									CDTL3:RefreshIcon(s)
								end
							end
						end
					end,
			},
			customCDTime = {
				name = "",
				desc = L["Set the value of the custom CD"],
				type = "input",
				order = 304,
				hidden = function(info)
						if t == "customs" then
							return true
						else
							if CDTL3.currentFilterHidden[t] then
								return true
							else
								local specialCase = false
								if t == "items" then
									specialCase = true
								end
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)

								if s then
									if s["setCustomCD"] ~= nil then
										return not s["setCustomCD"]
									else
										s["setCustomCD"] = false
										return true
									end
								else
									-- nothing real selected (e.g. "<< Select >>")
									return true
								end
							end
						end

						return false
					end,
				get = function(info)
						if t ~= "customs" then
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							if not s then
								return ""
							end

							if s["customCDTime"] ~= nil then
								return tostring(s["customCDTime"] / 1000)
							end

							return tostring(s["bCD"] / 1000)
						end

						return ""
					end,
				validate = private.ValidateSeconds,
				set = function(info, val)
						val = tonumber(val)
						CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "customCDTime", val * 1000)

						local e = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
						if e then
							e.data["customCDTime"] = val * 1000
							CDTL3:RefreshIcon(e)
							CDTL3:RefreshBar(e)
						end
					end,
			},
			setCustomCD = {
				name = L["Custom CD Time"],
				desc = L["Allows you to set a custom time for the cooldown.  This can be used for if a talent changes a cooldown time and the mod cannot detect it."],
				order = 305,
				hidden = function(info)
						if t == "customs" or CDTL3.currentFilterHidden[t] then
							return true
						end

						-- nothing real selected (e.g. "<< Select >>")
						return not CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, t == "items")
					end,
				type = "toggle",
				get = function(info, index)
						if t ~= "customs" then
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)

							return s and s["setCustomCD"] or false
						end

						return false
					end,
				set = function(info, val)
						local specialCase = false
						if t == "items" then
							specialCase = true
						end
						local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
						
						CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "setCustomCD", val)

						local e = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
						if e then
							e.data["setCustomCD"] = val
							CDTL3:RefreshIcon(e)
							CDTL3:RefreshBar(e)
						end
					end,
			},
			spacer400 = {
				name = " \n\n",
				type = "description",
				order = 400,
				width = "full",
			},
			clearSettings = {
				--name = "Clear Individual Settings",
				name = function(info)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							return L["Clear"]
						end

						return L["Clear Individual Settings"]
					end,
				desc = function(info)
						if t == "customs" then
							return L["Clear unsaved custom settings"]
						end

						local s = ""
						
						if CDTL3.currentFilter[t] then
							s = CDTL3.currentFilter[t]
						end
				
						return string.format(L["This will clear cooldown settings for %s"], s)
					end,
				-- an entry other characters use too asks with its own warning, then goes for everyone
				confirm = function(info)
						if not (t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>") then
							local entry = private.SelectedEntry(t)
							if entry and private.UsedByOthers(entry) then
								return string.format(L["Other characters on this profile use these settings for %s.\n\nClearing them resets them for every character on this profile."], tostring(CDTL3.currentFilter[t]))
							end
						end
						return true
					end,
				order = 401,
				type = "execute",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if not CDTL3.custom["triggerType"] then
									return true
								end
							else
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["customs"], t, false)
								if s then
									if s["triggerType"] == "" then
										return true
									end
								end 
							end
						end

						return false
					end,
				func = function(info)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom = {}
							CDTL3.customIsValid = false
						else
							-- only this character's entry (the one Filters lists) goes; one other
							-- characters use too was confirmed above and goes for all of them (only
							-- dropping this character from it let the next cast claim it back)
							local _, index = private.SelectedEntry(t)

							if index then
								CDTL3:ForgetSharedEntry(t, CDTL3.db.profile.tables[t][index])
								table.remove(CDTL3.db.profile.tables[t], index)

								-- back to this tab's own placeholder: the custom editor for
								-- Custom, otherwise "nothing selected" with the details hidden
								if t == "customs" then
									CDTL3.currentFilter[t] = "<< Add New >>"
									CDTL3.customIsValid = false
									CDTL3.currentFilterHidden[t] = false
								else
									CDTL3.currentFilter[t] = "<< Select >>"
									CDTL3.currentFilterHidden[t] = true
								end
							end
						end
					end,
			},
			saveCustom = {
				name = L["Save Custom"],
				desc = function(info)
						return L["Save current details as a custom cooldown"]
					end,
				confirm = true,
				order = 402,
				type = "execute",
				hidden = function(info)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							return false
						end

						return true
					end,
				disabled = function ()
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if not CDTL3.customIsValid then
									return true
								end
							end
						end

						return false
					end,
				func = function(info)
						-- duplicate check by the new custom's own name + trigger (the selection
						-- is always "<< Add New >>" here, so checking it never found anything)
						local s = CDTL3:GetCustomSpellSettings(CDTL3.custom["name"], CDTL3.custom["triggerType"])

						if not s then
							local name = CDTL3.custom["name"]			
							table.insert(CDTL3.db.profile.tables["customs"], CDTL3.custom)

							CDTL3.custom = {}
							CDTL3.customIsValid = false
							CDTL3.currentFilter[t] = name

							CDTL3:Print(string.format(L["CUSTOM: %s saved"], name))
						else
							CDTL3:Print(string.format(L["CUSTOM: %s already saved"], tostring(s["name"])))
						end
					end,
			},
			spacer500 = {
				name = " \n\n",
				type = "description",
				order = 500,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			enabled = {
				name = L["Enabled"],
				desc = L["Untick this to never show this as an icon/bar"],
				order = 501,
				type = "toggle",
				width = "half",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if not CDTL3.customIsValid then
									return true
								end
							end
						end

						return false
					end,
				get = function(info, index)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							-- an unticked box is false, not "not set yet" (that showed it ticked)
							if CDTL3.custom["enabled"] ~= nil then
								return CDTL3.custom["enabled"] and true or false
							else
								return CDTL3.db.profile.global["customs"]["showByDefault"]
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["enabled"]
							else
								return nil
							end
						end
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["enabled"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "enabled", val)
						
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["enabled"] = val
								
								CDTL3:RefreshIcon(s)
								CDTL3:RefreshBar(s)
							end
						end
					end,
			},
			highlight = {
				name = L["Highlight"],
				desc = L["Tick to apply highlighting to the icon"],
				order = 502,
				type = "toggle",
				width = "half",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
							if t == "customs" then
								if CDTL3.currentFilter[t] == "<< Add New >>" then
									if not CDTL3.customIsValid then
										return true
									end
								end
							end
	
							return false
						end,
				get = function(info, index)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							if CDTL3.custom["highlight"] then
								return CDTL3.custom["highlight"]
							else
								return false
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["highlight"]
							else
								return nil
							end
						end
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["highlight"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "highlight", val)
						
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["highlight"] = val
							
								CDTL3:RefreshIcon(s)
							end
						end
					end,
			},
			pinned = {
				name = L["Pinned"],
				desc = L["Tick to keep an icon in the ready frame until the cooldown is used again"],
				order = 503,
				type = "toggle",
				width = "half",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
							if t == "customs" then
								if CDTL3.currentFilter[t] == "<< Add New >>" then
									if not CDTL3.customIsValid then
										return true
									end
								end
							end
	
							return false
						end,
				get = function(info, index)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							if CDTL3.custom["pinned"] then
								return CDTL3.custom["pinned"]
							else
								return false
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["pinned"]
							else
								return nil
							end
						end
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["pinned"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "pinned", val)
						
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["pinned"] = val
							
								CDTL3:RefreshIcon(s)
							end
						end
					end,
			},
			ignored = {
				name = L["Ignored"],
				desc = L["Manually choose if something should be ignored or not.\nThis can be used in tandem with setting custom cooldown times to force misbehaving cooldowns to show correctly"],
				order = 504,
				type = "toggle",
				width = "half",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
							if t == "customs" then
								if CDTL3.currentFilter[t] == "<< Add New >>" then
									if not CDTL3.customIsValid then
										return true
									end
								end
							end
	
							return false
						end,
				get = function(info, index)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							if CDTL3.custom["ignored"] then
								return CDTL3.custom["ignored"]
							else
								return false
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["ignored"]
							else
								return nil
							end
						end
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["ignored"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "ignored", val)
						
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["ignored"] = val

								CDTL3:RefreshIcon(s)
							end

							-- Unticked on a buff/debuff that is up right now: show it at once
							if not val and (t == "buffs" or t == "debuffs") and CDTL3.db.profile.global[t]["enabled"] then
								local saved = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t)
								if saved and CDTL3:AuraExists("player", saved["name"]) then
									if s then
										CDTL3:SendToLane(s)
										CDTL3:SendToBarFrame(s)
									else
										CDTL3:CreateCooldown(CDTL3:GetUID(), t, saved)
									end
								end
							end
						end
					end,
			},
			spacer600 = {
				name = "\n\n" .. L["Select the frame the icon/bar will be shown\nIf the selected frame is not enabled, the icon/bar will not appear"] .. "\n\n",
				type = "description",
				order = 600,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			lane = {
				name = L["Lane"],
				desc = "",
				order = 601,
				type = "select",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
							if t == "customs" then
								if CDTL3.currentFilter[t] == "<< Add New >>" then
									if not CDTL3.customIsValid then
										return true
									end
								end
							end
	
							return false
						end,
				width = "half",
				values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
				get = function(info)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							if CDTL3.custom["lane"] then
								return CDTL3.custom["lane"]
							else
								return CDTL3.db.profile.global["customs"]["defaultLane"]
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["lane"]
							else
								return nil
							end
						end
						
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["lane"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "lane", tonumber(val))
						
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["lane"] = val
								
								-- a move, not a restart (see MoveToLane, Cooldown.lua)
								CDTL3:MoveToLane(s)
							end
						end
						
					end,
			},
			barFrame = {
				name = L["Bar Frame"],
				desc = "",
				order = 602,
				type = "select",
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
							if t == "customs" then
								if CDTL3.currentFilter[t] == "<< Add New >>" then
									if not CDTL3.customIsValid then
										return true
									end
								end
							end
	
							return false
						end,
				width = "half",
				values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
				get = function(info)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							if CDTL3.custom["barFrame"] then
								return CDTL3.custom["barFrame"]
							else
								return CDTL3.db.profile.global["customs"]["defaultBar"]
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["barFrame"]
							else
								return nil
							end
						end
						
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["barFrame"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "barFrame", tonumber(val))
						
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["barFrame"] = val
								
								CDTL3:SendToBarFrame(s)
							end
						end
						
					end,
			},
			readyFrame = {
				name = L["Ready Frame"],
				desc = "",
				order = 603,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
				disabled = function ()
						if t == "customs" then
							if CDTL3.currentFilter[t] == "<< Add New >>" then
								if not CDTL3.customIsValid then
									return true
								end
							end
						end

						return false
					end,
				type = "select",
				width = "half",
				values = { [0] = L["Hide"], [1] = "1", [2] = "2", [3] = "3" },
				get = function(info)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							if CDTL3.custom["readyFrame"] then
								return CDTL3.custom["readyFrame"]
							else
								return CDTL3.db.profile.global["customs"]["defaultReady"]
							end
						else
							local specialCase = false
							if t == "items" then
								specialCase = true
							end
							local s = CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, specialCase)
							
							if s then
								return s["readyFrame"]
							else
								return nil
							end
						end
						
					end,
				set = function(info, val)
						if t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>" then
							CDTL3.custom["readyFrame"] = val
						else
							CDTL3:SetSpellData(CDTL3.currentFilter[t], t, "readyFrame", tonumber(val))
						
							-- Just record it: the cooldown goes to its Ready frame when it finishes.
							-- (SendToReady here pulled a still-running icon off its lane and
							-- played the ready sound immediately.)
							local s = CDTL3:GetExistingCooldown(CDTL3.currentFilter[t], t)
							if s then
								s.data["readyFrame"] = val
							end
						end
						
					end,
			},			
		},
	}

	private.AddEntryColorArgs(options.args, t)
	private.AddEntryReadyArgs(options.args, t)
	CDTL3:AddEffectArgs(options.args, t, private.FilterEntry)
	CDTL3.IconFx:AddEntryArgs(options.args, t)

	-- Combat timers: tell the user if this buff gets an exact timer in combat
	if t == "buffs" then
		options.args["combatTimerNote"] = {
			name = function(info)
					local CT = CDTL3.CombatTimers
					local inBars = CT and CT:BuffInTrackedBars(CDTL3.currentFilter[t])
					if inBars then
						return "\n"..L["Exact in combat: this buff is in the Cooldown Manager's Tracked Bars."]
					end
					return "\n"..L["Estimated in combat. For an exact timer, add it to Tracked Bars in the Cooldown Manager (/cdm)."]
				end,
			type = "description",
			order = 703,
			width = "full",
			hidden = function(info)
					if CDTL3.currentFilterHidden[t] then
						return true
					end

					local CT = CDTL3.CombatTimers
					if not (CT and CT:Available()) then
						return true
					end

					return CT:BuffInTrackedBars(CDTL3.currentFilter[t]) == nil
				end,
		}
	end

	-- why the entry won't show (every tab); My spells and the spec rules (Spells); the Cooldown
	-- Manager's Tracked Bars (Buffs)
	private.AddEntryReasonArgs(options.args, t)
	if t == "spells" then
		private.AddSpellRuleArgs(options.args, t)
	elseif t == "buffs" then
		private.AddCooldownManagerArgs(options.args)
	end

	return options
end

-- WHY ISN'T IT SHOWING: a one-line reason under the entry's name, and Show anyway
private.ReasonEntry = function(t)
	if CDTL3.currentFilterHidden[t] or (t == "customs" and CDTL3.currentFilter[t] == "<< Add New >>") then
		return nil
	end

	return CDTL3:GetSpellSettings(CDTL3.currentFilter[t], t, t == "items")
end

private.ShowAnywayText = {
	unignore = L["Unticks Ignored for it"],
	enable = L["Ticks its Enabled box"],
	tick = L["Ticks it in My spells"],
	spec = L["Adds the spec you're in now to the specs it shows in"],
	type = L["Switches this whole type back on (Filters > Defaults)"],
	lane = L["Puts it on a lane: the type's Default Lane, or the first lane that's switched on"],
	laneOn = L["Switches its lane on"],
}

private.AddEntryReasonArgs = function(args, t)
	args["whyNotShowing"] = {
		name = function(info)
				local text = CDTL3:WhyNotShowing(private.ReasonEntry(t), t)
				return "|cffffd100" .. tostring(text or "") .. "|r"
			end,
		type = "description",
		order = 206,
		width = "full",
		hidden = function(info)
				return CDTL3:WhyNotShowing(private.ReasonEntry(t), t) == nil
			end,
	}
	args["showAnyway"] = {
		name = L["Show anyway"],
		desc = function(info)
				local _, fix = CDTL3:WhyNotShowing(private.ReasonEntry(t), t)
				return private.ShowAnywayText[fix or ""] or ""
			end,
		type = "execute",
		order = 207,
		hidden = function(info)
				local _, fix = CDTL3:WhyNotShowing(private.ReasonEntry(t), t)
				return fix == nil
			end,
		func = function(info)
				local s = private.ReasonEntry(t)
				local _, fix, n = CDTL3:WhyNotShowing(s, t)

				-- the same change the entry's own control makes (live icons included)
				if fix == "unignore" then
					args["ignored"].set(info, false)
				elseif fix == "enable" then
					args["enabled"].set(info, true)
				elseif fix == "lane" then
					args["lane"].set(info, n)
				elseif fix == "tick" then
					CDTL3:TickSpell(s["name"], true)
				elseif fix == "spec" then
					CDTL3:SetOnlyThisSpec(s, true)
				elseif fix == "type" then
					CDTL3.db.profile.global[t]["enabled"] = true
					for _, cd in pairs(CDTL3.cooldowns) do
						if cd.data["type"] == t then
							local saved = CDTL3:GetSpellSettings(cd.data["name"], t)
							cd.data["enabled"] = not (saved and saved["enabled"] == false)
						end
					end
				elseif fix == "laneOn" then
					CDTL3.db.profile.lanes["lane" .. n]["enabled"] = true
					CDTL3:CreateLanes()
					CDTL3:RefreshLane(n)
				end
			end,
	}
end

-- FILTERS > SPELLS: Hide spells I don't know, Show only the ticked spells, My spells, Only for this spec
private.AddSpellRuleArgs = function(args, t)
	args["hideUnknown"] = {
		name = L["Hide spells I don't know"],
		desc = L["Spells this character doesn't know right now (another spec's, or a talent you've swapped out) don't show; their settings are kept"],
		type = "toggle",
		order = 90,
		width = 1.5,
		get = function(info)
				return CDTL3.db.profile.global["spells"]["hideUnknown"] and true or false
			end,
		set = function(info, val)
				CDTL3:SetHideUnknownSpells(val)
			end,
	}
	args["onlyTicked"] = {
		name = L["Show only the ticked spells"],
		desc = L["Only the spells ticked in My spells (below) show; every other spell counts as ignored while this is on and keeps its settings. Just for this character."],
		type = "toggle",
		order = 91,
		width = 1.5,
		get = function(info)
				return CDTL3:OnlyTickedSpells()
			end,
		set = function(info, val)
				CDTL3:SetOnlyTickedSpells(val)
			end,
	}

	args["onlyThisSpec"] = {
		name = function(info)
				local s = private.ReasonEntry(t)
				if CDTL3:IsSpecLimited(s) then
					return string.format(L["Only for %s"], CDTL3:SpecNames(s["onlySpecs"]))
				end
				local _, specName = CDTL3:CurrentSpec()
				if specName then
					return string.format(L["Only for this spec (%s)"], tostring(specName))
				end
				return L["Only for this spec"]
			end,
		desc = L["Show this spell only in the specs named here; ticking adds the spec you're in now, unticking shows it in every spec"],
		type = "toggle",
		order = 505,
		width = 1.5,
		hidden = function(info)
				return not (CDTL3:HasSpecs() and private.ReasonEntry(t))
			end,
		disabled = function(info)
				return not CDTL3:IsSpecLimited(private.ReasonEntry(t)) and not CDTL3:CurrentSpec()
			end,
		get = function(info)
				return CDTL3:IsSpecLimited(private.ReasonEntry(t))
			end,
		set = function(info, val)
				CDTL3:SetOnlyThisSpec(private.ReasonEntry(t), val)
			end,
	}

	args["mySpells"] = {
		name = L["My spells"],
		type = "group",
		inline = true,
		order = 950,
		args = {
			intro = {
				name = L["Tick the spellbook spells you want to see. Ticking one sets it up before you've ever cast it. Only spells with a cooldown are listed."] .. "\n",
				type = "description",
				order = 1,
			},
			none = {
				name = L["|cffaaaaaaNo spells with a cooldown in your spellbook yet.|r"],
				type = "description",
				order = 2,
				hidden = function(info)
						return #CDTL3:MySpellsList() > 0
					end,
			},
			list = {
				name = "",
				desc = L["Ticked spells show and are never ignored; unticking keeps the spell's settings"],
				type = "multiselect",
				order = 3,
				values = function(info)
						local values = {}
						for _, e in ipairs(CDTL3:MySpellsList()) do
							values[e.key] = e.label
						end
						return values
					end,
				get = function(info, key)
						return CDTL3:IsSpellTicked(key)
					end,
				set = function(info, key, val)
						CDTL3:TickSpell(key, val)
					end,
			},
		},
	}
end

-- FILTERS > BUFFS: Pull from Cooldown Manager (Retail and Forever; hidden elsewhere)
private.NoCooldownManager = function()
	local CT = CDTL3.CombatTimers
	return not (CT and CT:Available() and CT.TrackedBarBuffs)
end

private.PullFromCooldownManager = function()
	local r = CDTL3:PullTrackedBuffs()
	if not r then
		CDTL3:Print(L["The Cooldown Manager isn't available on this client."])
		return
	end

	if r.tracked == 0 then
		CDTL3:Print(L["The Cooldown Manager's Tracked Bars have no buffs yet: add some there (/cdm), then pull again."])
	else
		CDTL3:Print(string.format(r.tracked == 1 and L["Pulled %d buff from the Cooldown Manager's Tracked Bars: %d new, %d already saved."] or L["Pulled %d buffs from the Cooldown Manager's Tracked Bars: %d new, %d already saved."],
				r.tracked, #r.made, #r.claimed))
	end
	if #r.notTracked > 0 then
		CDTL3:Print(string.format(L["Not in Tracked Bars, so estimated in combat: %s."], table.concat(r.notTracked, ", ")))
	end
	if not r.viewerOn then
		CDTL3:Print(L["The Cooldown Manager is switched off in the game's options; turn it on for exact buff timers in combat."])
	end
end

private.AddCooldownManagerArgs = function(args)
	args["pullCooldownManager"] = {
		name = L["Pull from Cooldown Manager"],
		desc = L["Makes a Buffs entry, on the Buffs default lane, for every buff in the Cooldown Manager's Tracked Bars, and lists your buffs that aren't there"],
		type = "execute",
		order = 90,
		width = 1.5,
		confirm = true,
		confirmText = L["Make an entry for every buff in the Cooldown Manager's Tracked Bars? Buffs you already have keep their settings but stop being ignored."],
		hidden = private.NoCooldownManager,
		func = function(info)
				private.PullFromCooldownManager()
			end,
	}
	args["notInTrackedBars"] = {
		name = function(info)
				local bars = CDTL3.CombatTimers:TrackedBarBuffs()
				local list = CDTL3:BuffsNotInTrackedBars(bars) or {}
				return string.format(L["|cffaaaaaaNot in Tracked Bars, so estimated in combat: %s|r"], table.concat(list, ", "))
			end,
		type = "description",
		order = 91,
		width = "full",
		hidden = function(info)
				if private.NoCooldownManager() then
					return true
				end
				local bars, viewerOn = CDTL3.CombatTimers:TrackedBarBuffs()
				local list = bars and viewerOn and CDTL3:BuffsNotInTrackedBars(bars)
				return not (list and #list > 0)
			end,
	}
end

private.GetCustomSet = function(t, o)

	local options = {
		name = L["Custom"],
		type = "group",
		order = o,
		childGroups  = "tab",
		args = {
			saved = private.GetFilterSet(t, 100),
			detected = {
				name = L["Detected"],
				type = "group",
				order = 200,
				args = {
					spacer100 = {
						name = function(info, index)
								local s = " \n\n"

								s = s..L["When detection is enabled, spell data will be kept for all spells cast by the player."].."\n"
								s = s..L["This will include many instances of spells cast by game systems that can mostly be ignored."].."\n"
								s = s..L["To save a spell as a custom trigger, just select the spell from the list and then hit the 'Save As Custom' button."].."\n"
								s = s.." \n"

								return s
							end,
						type = "description",
						order = 100,
						width = "full"
					},
					customDetection = {
						name = L["Enable Detection"],
						desc = L["Detect and record 'miscellaneous' spells"],
						order = 101,
						type = "toggle",
						--width = "half",
						get = function(info, index)
							return CDTL3.db.profile.global["customDetection"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["customDetection"] = val
							end,
					},
					clearAllDetected = {
						name = L["Clear Detected"],
						desc = function(info)
								return L["This will clear all detected 'miscellaneous' spells"]
							end,
						confirm = true,
						order = 102,
						type = "execute",
						func = function(info)
								for k, v in pairs(CDTL3.db.profile.tables["detected"]) do
									CDTL3.db.profile.tables["detected"][k] = nil
								end
								
								CDTL3.currentFilter["detected"] = "<< Select Detected >>"
							end
					},
					spacer200 = {
						--name = "\n\nSelect something to edit its settings\n",
						name = " \n\n" .. L["Select a detected spell to create a custom cooldown"] .. "\n",
						type = "description",
						order = 200,
					},
					list = {
						name = function(info)
								local n = ""
								return n
							end,
						desc = function(info)
								local n = ""
								return n
							end,
						order = 201,
						type = "select",
						values = function(info)
								local list = {}

								list = CDTL3:LoadDetectedList("detected")

								return list
							end,
						get = function(info)
								return CDTL3.currentFilter["detected"]
							end,
						set = function(info, val)
								local list = CDTL3:LoadDetectedList("detected")
		
								CDTL3.currentFilter["detected"] = list[val]
								CDTL3.currentFilterHidden["detected"] = false
							end,
					},
					spacer202 = {
						name = function(info)
								return L["*Miscellaneous spells that have been detected will appear here*"].."\n\n\n"
							end,
						type = "description",
						order = 202,
					},
					cdType = {
						name = function(info)
								local n = " "
								
								if t == "spells" or t == "items" or t == "petspells" then
									n = L["Spell:"].."   "
								elseif t == "buffs" or t == "debuffs" or t == "offensives" then
									n = L["Aura:"].."   "
								elseif t == "runes" then
									n = L["Rune:"].."   "
								elseif t == "customs" or t == "detected" then
									n = L["Name:"].."   "
								end
								
								return n
							end,
						type = "description",
						order = 203,
						width = 0.2,
					},
					cdName = {
						name = function(info)
								local n = " "
								
								if CDTL3.currentFilter["detected"] == "<< Select Detected >>" then
									n = L["Select a detected spell"]
								else
									local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["detected"], "detected", false)
									if s then
										n = "  "..s["name"]
									else
										n = CDTL3.currentFilter["detected"]
									end
								end
								
								return n
							end,
						type = "description",
						order = 204,
						width = 1.5,
						fontSize = "large",
						image = function(info)
								if CDTL3.currentFilter["detected"] ~= "<< Select Detected >>" then
									local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["detected"], "detected", false)
									
									if s then
										return s["icon"]
									end
								end

								return 134400
							end,
						imageWidth = 24,
						imageHeight = 24,
						imageCoords = {0.1,0.9,0.1,0.9},
					},
					spacer300 = {
						name =  " \n\n",
						type = "description",
						order = 300,
					},
					saveDetected = {
						name = L["Save As Custom"],
						desc = function(info)
								return L["This will save the detected spell as custom cooldown"]
							end,
						confirm = true,
						order = 301,
						disabled = function ()
								if CDTL3.currentFilter["detected"] == "<< Select Detected >>" then
									return true
								end
		
								return false
							end,
						type = "execute",
						func = function(info)
								local s = CDTL3:GetSpellSettings(CDTL3.currentFilter["detected"], "detected", false)
								if s then
									local existingData = CDTL3:GetSpellSettings(CDTL3.currentFilter["detected"], "customs", false)
									if existingData then
										--CDTL3:Print("CUSTOM_ALREADY_EXISTS: "..CDTL3.currentFilter["detected"])
									else
										local c = CDTL3:ApplyEntryDefaults(CDTL3:TableCopy(s), "customs")
										c["bCD"] = 60000
										c["type"] = "customs"
										c["triggerType"] = "spell"
										c["ignored"] = CDTL3:IgnoredByDefault("customs", c["bCD"])
										
										table.insert(CDTL3.db.profile.tables["customs"], c)
										CDTL3.currentFilter["customs"] = c["name"]
									end
								end
							end
					},
				},
			},
		},
	}

	return options
end

private.GetLaneSet = function(i)
	local frame = nil
	local lane = nil
	
	if i == 1 then
		lane = CDTL3.db.profile.lanes["lane1"]
	elseif i == 2 then
		lane = CDTL3.db.profile.lanes["lane2"]
	elseif i == 3 then
		lane = CDTL3.db.profile.lanes["lane3"]
	end
	
	local options = {
		name = function(info)
				return lane["name"]
			end,
		type = "group",
		order = 100,
		args = {
			general = {
				name = L["General"],
				type = "group",
				order = 100,
				args = {
					name = {
						name = L["Frame Name"],
						type = "input",
						order = 101,
						get = function(info)
								return lane["name"]
							end,
						set = function(info, val)
								lane["name"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					enabled = {
						name = L["Enabled"],
						desc = "",
						order = 102,
						type = "toggle",
						get = function(info, index)
								return lane["enabled"]
							end,
						set = function(info, val)
								lane["enabled"] = val
								
								if val then
									CDTL3:CreateLanes()
								end
								
								CDTL3:RefreshLane(i)
							end,
					},
					spacer103 = {
						name = "",
						type = "description",
						order = 103,
					},
					reversed = {
						name = L["Reversed"],
						desc = L["Selecting this will reverse icon travel direction from right-to-left, to left-to-right"],
						order = 104,
						type = "toggle",
						get = function(info, index)
								return lane["reversed"]
							end,
						set = function(info, val)
								lane["reversed"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					vertical = {
						name = L["Vertical"],
						desc = L["The frame will be vertical instead of horizontal"],
						order = 105,
						type = "toggle",
						get = function(info, index)
								return lane["vertical"]
							end,
						set = function(info, val)
								lane["vertical"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						order = 200,
					},
					mode = {
						name = L["Mode"],
						desc = L["How icons will progress along the lane"],
						order = 201,
						type = "select",
						values = {
								["LINEAR"] = L["Linear (%)"],
								["LINEAR_ABS"] = L["Linear (Time)"],
								["SPLIT"] = L["Split (%)"],
								["SPLIT_ABS"] = L["Split (Time)"],
							},
						get = function(info, index)
								return lane["mode"]["type"]
							end,
						set = function(info, val)
								lane["mode"]["type"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					longBuffs = {
						name = L["Long buffs scale"],
						desc = L["Sets this lane to Split (Time) over 60 minutes. The last 30 seconds, 30 seconds to 2 minutes and 2 to 10 minutes each get a quarter of the lane; 10 to 60 minutes share the last quarter. Hide Long Timers is turned off for it."],
						order = 201.5,
						type = "execute",
						func = function(info)
								lane["mode"]["type"] = "SPLIT_ABS"
								local sa = lane["mode"]["splitAbs"]
								sa["max"] = 3600
								sa["hideTimeSurplus"] = false
								sa["count"] = 3
								sa["s1v"] = 30
								sa["s1p"] = 0.25
								sa["s2v"] = 120
								sa["s2p"] = 0.5
								sa["s3v"] = 600
								sa["s3p"] = 0.75
								CDTL3:RefreshLane(i)
							end,
					},
					timeFormat = {
						name = L["Time Format"],
						desc = L["Select the format to display times"],
						order = 202,
						type = "select",
						hidden = function(info)
							local mode = lane["mode"]["type"]
							if mode == "LINEAR_ABS" or mode == "SPLIT_ABS" then
								return false
							end
							
							return true
						end,
						values = {
								["XhYmZs"] = "XhYmZs",
								["H:MM:SS"] = "H:MM:SS",
							},
						get = function(info, index)
								local mode = lane["mode"]["type"]
								if mode == "LINEAR_ABS" then
									return lane["mode"]["linearAbs"]["timeFormat"]
								elseif mode == "SPLIT_ABS" then
									return lane["mode"]["splitAbs"]["timeFormat"]
								end
								
								return ""
							end,
						set = function(info, val)
								local mode = lane["mode"]["type"]
								if mode == "LINEAR_ABS" then
									lane["mode"]["linearAbs"]["timeFormat"] = val
								elseif mode == "SPLIT_ABS" then
									lane["mode"]["splitAbs"]["timeFormat"] = val
								end
								CDTL3:RefreshLane(i)
							end,
					},
					spacer300 = {
						name = "",
						type = "description",
						order = 300,
					},
					maxTime = {
						name = L["Max Time"],
						desc = L["How many seconds the lane represents (up to 3600, an hour). Type a number in the box for an exact value."],
						order = 301,
						type = "range",
						-- hard limits, so the slider can reach and show every value
						min = 1,
						max = 3600,
						bigStep = 1,
						get = function(info, index)
								local mt = 0
								local mode = lane["mode"]["type"]
								
								if mode == "LINEAR" then
									mt = lane["mode"]["linear"]["max"]
								elseif mode == "LINEAR_ABS" then
									mt = lane["mode"]["linearAbs"]["max"]
								elseif mode == "SPLIT" then
									mt = lane["mode"]["split"]["max"]
								elseif mode == "SPLIT_ABS" then
									mt = lane["mode"]["splitAbs"]["max"]
								end

								return math.min(mt or 0, 3600)
							end,
						set = function(info, val)
								local mode = lane["mode"]["type"]
								
								if mode == "LINEAR" then
									lane["mode"]["linear"]["max"] = val
								elseif mode == "LINEAR_ABS" then
									lane["mode"]["linearAbs"]["max"] = val
								elseif mode == "SPLIT" then
									lane["mode"]["split"]["max"] = val
								elseif mode == "SPLIT_ABS" then
									lane["mode"]["splitAbs"]["max"] = val
								end
								
								CDTL3:RefreshLane(i)
						end,
					},
					hideLongTimers = {
						name = L["Hide Long Timers"],
						desc = L["Should icons with remaining cooldowns longer than the max time be hidden"],
						order = 302,
						type = "toggle",
						get = function(info, index)
								local mode = lane["mode"]["type"]
								
								if mode == "LINEAR" then
									return lane["mode"]["linear"]["hideTimeSurplus"]
								elseif mode == "LINEAR_ABS" then
									return lane["mode"]["linearAbs"]["hideTimeSurplus"]
								elseif mode == "SPLIT" then
									return lane["mode"]["split"]["hideTimeSurplus"]
								elseif mode == "SPLIT_ABS" then
									return lane["mode"]["splitAbs"]["hideTimeSurplus"]
								end
								
								return nil
							end,
						set = function(info, val)
								local mode = lane["mode"]["type"]
								
								if mode == "LINEAR" then
									lane["mode"]["linear"]["hideTimeSurplus"] = val
								elseif mode == "LINEAR_ABS" then
									lane["mode"]["linearAbs"]["hideTimeSurplus"] = val
								elseif mode == "SPLIT" then
									lane["mode"]["split"]["hideTimeSurplus"] = val
								elseif mode == "SPLIT_ABS" then
									lane["mode"]["splitAbs"]["hideTimeSurplus"] = val
								end
							end,
					},
					spacer400 = {
						name = "\n\n",
						type = "description",
						order = 400,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								return false
							end
							return true
						end,
					},
					sSplitCount = {
						name = L["Split Count"],
						desc = L["How many % splits appear on the lane"],
						order = 401,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								return false
							end
							return true
						end,
						min = 1,
						max = 3,
						step = 1,
						bigStep = 1,
						get = function(info, index)
								return CDTL3:SplitCount(lane["mode"]["split"])
							end,
						set = function(info, val)
								lane["mode"]["split"]["count"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer410 = {
						name = "\n\n",
						type = "description",
						order = 410,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								return false
							end
							return true
						end,
					},
					sSplit1Position = {
						name = L["Split 1 Position"],
						desc = L["What position should split 1 appear"],
						order = 411,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								return false
							end
							return true
						end,
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["mode"]["split"]["s1p"]
							end,
						set = function(info, val)
								lane["mode"]["split"]["s1p"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					sSplit1Value = {
						name = L["Split 1 Value"],
						desc = L["What percentage should split 1 occur"],
						order = 412,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								return false
							end
							return true
						end,
						min = 0,
						max = 100,
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["split"]["s1v"]
							end,
						set = function(info, val)
								lane["mode"]["split"]["s1v"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer420 = {
						name = "",
						type = "description",
						order = 420,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if CDTL3:SplitCount(lane["mode"]["split"]) >= 2 then
									return false
								end
							end
							return true
						end,
					},
					sSplit2Position = {
						name = L["Split 2 Position"],
						desc = L["What position should split 2 appear"],
						order = 421,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if CDTL3:SplitCount(lane["mode"]["split"]) >= 2 then
									return false
								end
							end
							return true
						end,
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["mode"]["split"]["s2p"]
							end,
						set = function(info, val)
								lane["mode"]["split"]["s2p"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					sSplit2Value = {
						name = L["Split 2 Value"],
						desc = L["What percentage should split 2 occur"],
						order = 422,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if CDTL3:SplitCount(lane["mode"]["split"]) >= 2 then
									return false
								end
							end
							return true
						end,
						min = 0,
						max = 100,
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["split"]["s2v"]
							end,
						set = function(info, val)
								lane["mode"]["split"]["s2v"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer430 = {
						name = "",
						type = "description",
						order = 430,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if CDTL3:SplitCount(lane["mode"]["split"]) >= 2 then
									return false
								end
							end
							return true
						end,
					},
					sSplit3Position = {
						name = L["Split 3 Position"],
						desc = L["What position should split 3 appear"],
						order = 431,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if CDTL3:SplitCount(lane["mode"]["split"]) >= 3 then
									return false
								end
							end
							return true
						end,
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["mode"]["split"]["s3p"]
							end,
						set = function(info, val)
								lane["mode"]["split"]["s3p"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					sSplit3Value = {
						name = L["Split 3 Value"],
						desc = L["What percentage should split 3 occur"],
						order = 432,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if CDTL3:SplitCount(lane["mode"]["split"]) >= 3 then
									return false
								end
							end
							return true
						end,
						min = 0,
						max = 100,
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["split"]["s3v"]
							end,
						set = function(info, val)
								lane["mode"]["split"]["s3v"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								return false
							end
							return true
						end,
					},
					saSplitCount = {
						name = L["Split Count"],
						desc = L["How many % splits appear on the lane"],
						order = 502,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								return false
							end
							return true
						end,
						min = 1,
						max = 3,
						step = 1,
						bigStep = 1,
						get = function(info, index)
								return CDTL3:SplitCount(lane["mode"]["splitAbs"])
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["count"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer510 = {
						name = "\n\n",
						type = "description",
						order = 510,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								return false
							end
							return true
						end,
					},
					saSplit1Position = {
						name = L["Split 1 Position"],
						desc = L["What position should splitAbs 1 appear"],
						order = 511,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								return false
							end
							return true
						end,
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["s1p"]
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["s1p"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					saSplit1Value = {
						name = L["Split 1 Value"],
						desc = L["How many seconds from the end split 1 sits at (up to 3600)."],
						order = 512,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								return false
							end
							return true
						end,
						min = 1,
						max = 3600,
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["s1v"]
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["s1v"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer520 = {
						name = "",
						type = "description",
						order = 520,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if CDTL3:SplitCount(lane["mode"]["splitAbs"]) >= 2 then
									return false
								end
							end
							return true
						end,
					},
					saSplit2Position = {
						name = L["Split 2 Position"],
						desc = L["What position should splitAbs 2 appear"],
						order = 521,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if CDTL3:SplitCount(lane["mode"]["splitAbs"]) >= 2 then
									return false
								end
							end
							return true
						end,
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["s2p"]
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["s2p"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					saSplit2Value = {
						name = L["Split 2 Value"],
						desc = L["How many seconds from the end split 2 sits at (up to 3600)."],
						order = 522,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if CDTL3:SplitCount(lane["mode"]["splitAbs"]) >= 2 then
									return false
								end
							end
							return true
						end,
						min = 1,
						max = 3600,
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["s2v"]
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["s2v"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer530 = {
						name = "",
						type = "description",
						order = 530,
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if CDTL3:SplitCount(lane["mode"]["splitAbs"]) >= 2 then
									return false
								end
							end
							return true
						end,
					},
					saSplit3Position = {
						name = L["Split 3 Position"],
						desc = L["What position should splitAbs 3 appear"],
						order = 531,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if CDTL3:SplitCount(lane["mode"]["splitAbs"]) >= 3 then
									return false
								end
							end
							return true
						end,
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["s3p"]
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["s3p"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					saSplit3Value = {
						name = L["Split 3 Value"],
						desc = L["How many seconds from the end split 3 sits at (up to 3600)."],
						order = 532,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if CDTL3:SplitCount(lane["mode"]["splitAbs"]) >= 3 then
									return false
								end
							end
							return true
						end,
						max = 3600,
						min = 1,
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["s3v"]
							end,
						set = function(info, val)
								lane["mode"]["splitAbs"]["s3v"] = val
								CDTL3:RefreshLane(i)
						end,
					},					
					spacer600 = {
						name = "\n\n",
						type = "description",
						order = 600,
					},
					overrideAutohide = {
						name = L["Override Autohide"],
						desc = function(info, index)
								local desc = L["This will override autohiding, and show the lane in the following circumstances:"].."\n\n"
									desc = desc..L["Player Health: while health is below max"].."\n"
									desc = desc..L["Class Power: while class power is below max (or above 0 in the case of rage)"].."\n"
									desc = desc..L["Energy Tick: while in stealth"].."\n"
								return desc
							end,
						order = 601,
						type = "toggle",
						get = function(info, index)
								return lane["tracking"]["overrideAutohide"]
							end,
						set = function(info, val)
								lane["tracking"]["overrideAutohide"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					pauseHidden = {
						name = L["Pause while hidden"],
						desc = L["While this lane is faded out, its icons stop sliding and updating their texts; timers, Ready and sounds keep running"],
						order = 601.5,
						type = "toggle",
						get = function(info, index)
								return lane["pauseHidden"]
							end,
						set = function(info, val)
								lane["pauseHidden"] = val
							end,
					},
					spacer602 = {
						name = "\n",
						type = "description",
						order = 602,
					},
					primaryTracking = {
						name = L["Primary Tracking"],
						desc = "",
						order = 603,
						type = "select",
						values = private.TrackingValues,
						get = function(info, index)
								return lane["tracking"]["primaryTracking"]
							end,
						set = function(info, val)
								lane["tracking"]["primaryTracking"] = val
							end,
					},
					primaryReversed = {
						name = L["Reverse"],
						desc = L["Reverse the direction of the primary tracking indicator"],
						order = 604,
						type = "toggle",
						get = function(info, index)
								return lane["tracking"]["primaryReversed"]
							end,
						set = function(info, val)
								lane["tracking"]["primaryReversed"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer610 = {
						name = "\n",
						type = "description",
						order = 610,
					},
					secondaryTracking = {
						name = L["Secondary Tracking"],
						desc = "",
						order = 611,
						type = "select",
						values = private.TrackingValues,
						get = function(info, index)
								return lane["tracking"]["secondaryTracking"]
							end,
						set = function(info, val)
								lane["tracking"]["secondaryTracking"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					secondaryReversed = {
						name = L["Reverse"],
						desc = L["Reverse the direction of the secondary tracking indicator"],
						order = 612,
						type = "toggle",
						get = function(info, index)
								return lane["tracking"]["secondaryReversed"]
							end,
						set = function(info, val)
								lane["tracking"]["secondaryReversed"] = val
							end,
					},
					spacer613 = {
						name = "\n",
						type = "description",
						order = 613,
					},
					stWidth = {
						name = L["ST Width"],
						desc = L["Set the width of the secondary tracker"],
						order = 614,
						type = "range",
						hidden = function(info)
							if lane["tracking"]["secondaryTracking"] ~= "NONE" then
								return false
							end
							return true
						end,
						max = 360,
						min = 1,
						bigStep = 1,
						get = function(info, index)
								return lane["tracking"]["stWidth"]
							end,
						set = function(info, val)
								lane["tracking"]["stWidth"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					stHeight = {
						name = L["ST Height"],
						desc = L["Set the height of the secondary tracker"],
						order = 615,
						type = "range",
						hidden = function(info)
							if lane["tracking"]["secondaryTracking"] ~= "NONE" then
								return false
							end
							return true
						end,
						max = 360,
						min = 1,
						bigStep = 1,
						get = function(info, index)
								return lane["tracking"]["stHeight"]
							end,
						set = function(info, val)
								lane["tracking"]["stHeight"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer616 = {
						name = "\n",
						type = "description",
						order = 616,
						hidden = function(info)
							if lane["tracking"]["secondaryTracking"] ~= "NONE" then
								return false
							end
							return true
						end,
					},
					stTexture = {
						name = L["ST Texture"],
						desc = L["Selects the ST texture"],
						order = 617,
						type = "select",
						hidden = function(info)
							if lane["tracking"]["secondaryTracking"] ~= "NONE" then
								return false
							end
							return true
						end,
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return lane["tracking"]["stTexture"]
							end,
						set = function(info, val)
								lane["tracking"]["stTexture"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					stTextureColor = {
						name = L["ST Color"],
						desc = L["Sets the ST texture color"],
						order = 618,
						type = "color",
						hidden = function(info)
							if lane["tracking"]["secondaryTracking"] ~= "NONE" then
								return false
							end
							return true
						end,
						hasAlpha = true,
						get = function(info)
								local r = lane["tracking"]["stTextureColor"]["r"]
								local g = lane["tracking"]["stTextureColor"]["g"]
								local b = lane["tracking"]["stTextureColor"]["b"]
								local a = lane["tracking"]["stTextureColor"]["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								lane["tracking"]["stTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshLane(i)
							end,
					},
				},
			},
			appearance = {
				name = L["Appearance"],
				type = "group",
				order = 200,
				args = {
					width = {
						name = L["Width"],
						desc = L["Sets the width for the lane"],
						order = 201,
						type = "range",
						min = 1,
						max = 1000,
						bigStep = 1,
						get = function(info, index)
								return lane["width"]
							end,
						set = function(info, val)
								lane["width"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					height = {
						name = L["Height"],
						desc = L["Sets the height for the lane"],
						order = 202,
						type = "range",
						softMin = 1,
						softMax = 600,
						bigStep = 1,
						get = function(info, index)
								return lane["height"]
							end,
						set = function(info, val)
								lane["height"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer300 = {
						name = "",
						type = "description",
						order = 300,
					},
					posX = {
						name = L["x Position"],
						desc = L["Sets the x position of the lane"],
						order = 301,
						type = "range",
						softMin = -500,
						softMax = 500,
						bigStep = 1,
						get = function(info, index)
								return lane["posX"]
							end,
						set = function(info, val)
								lane["posX"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					posY = {
						name = L["y Position"],
						desc = L["Sets the y position of the lane"],
						order = 302,
						type = "range",
						softMin = -500,
						softMax = 500,
						bigStep = 1,
						get = function(info, index)
								return lane["posY"]
							end,
						set = function(info, val)
								lane["posY"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer400 = {
						name = "",
						type = "description",
						order = 400,
					},
					relativeTo = {
						name = L["Anchor Point"],
						desc = L["The x/y position is relative to this point of the screen"],
						order = 401,
						type = "select",
						values = {
								["TOPLEFT"] = "TOPLEFT",
								["TOP"] = "TOP",
								["TOPRIGHT"] = "TOPRIGHT",
								["LEFT"] = "LEFT",
								["CENTER"] = "CENTER",
								["RIGHT"] = "RIGHT",
								["BOTTOMLEFT"] = "BOTTOMLEFT",
								["BOTTOM"] = "BOTTOM",
								["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							},
						get = function(info, index)
								return lane["relativeTo"]
							end,
						set = function(info, val)
								lane["relativeTo"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
					},
					fgTexture = {
						name = L["Foreground Texture"],
						desc = L["Selects the texture"],
						order = 501,
						type = "select",
						width = 0.7,
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return lane["fgTexture"]
							end,
						set = function(info, val)
								lane["fgTexture"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					fgTextureColor = {
						name = L["Color"],
						desc = L["Sets the texture color"],
						order = 502,
						type = "color",
						width = 0.4,
						hasAlpha = true,
						disabled  = function(info)
								return lane["fgClassColor"]
							end,
						get = function(info)
								local c = lane["fgTextureColor"] or { r=0.77647, g=0.11765, b=0.28235, a=1 }
								if lane["fgClassColor"] then
									-- before the character is known (first seconds after login) keep the stored colour
									c = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]] or c
								end

								local r = c["r"]
								local g = c["g"]
								local b = c["b"]
								local a = c["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								lane["fgTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshLane(i)
							end,
					},
					fgClassColor = {
						name = L["Class Color"],
						desc = L["Set the texture color to your class color"],
						order = 503,
						type = "toggle",
						width = 0.5,
						get = function(info)
								return lane["fgClassColor"]
							end,
						set = function(info, val)
								lane["fgClassColor"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer600 = {
						name = "",
						type = "description",
						order = 600,
					},
					bgTexture = {
						name = L["Background Texture"],
						desc = L["Sets the background texture"],
						order = 601,
						type = "select",
						width = 0.7,
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return lane["bgTexture"]
							end,
						set = function(info, val)
								lane["bgTexture"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					bgTextureColor = {
						name = L["Color"],
						desc = L["Sets the background texture color"],
						order = 602,
						type = "color",
						width = 0.4,
						hasAlpha = true,
						disabled  = function(info)
								return lane["bgClassColor"]
							end,
						get = function(info)
								local c = lane["bgTextureColor"]
								if lane["bgClassColor"] then
									-- before the character is known (first seconds after login) keep the stored colour
									c = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]] or c
								end
						
								local r = c["r"]
								local g = c["g"]
								local b = c["b"]
								local a = c["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								lane["bgTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshLane(i)
							end,
					},
					bgClassColor = {
						name = L["Class Color"],
						desc = L["Set the texture color to your class color"],
						order = 603,
						type = "toggle",
						width = 0.5,
						get = function(info)
								return lane["bgClassColor"]
							end,
						set = function(info, val)
								lane["bgClassColor"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					spacer700 = {
						name = "",
						type = "description",
						order = 700,
					},
					laneAlpha = {
						name = L["Lane Alpha"],
						desc = L["Set the alpha for the lane (this will reset custom text alpha settings, but they can be adjusted again after setting this)"],
						order = 701,
						type = "range",
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["alpha"]
							end,
						set = function(info, val)
								lane["alpha"] = val
								CDTL3:RefreshLane(i)
						end,
					},
					spacer702 = {
						name = "\n\n",
						type = "description",
						order = 702,
					},
				},
			},
			icons = {
				name = L["Icons"],
				type = "group",
				order = 300,
				args = {
					size = {
						name = L["Size"],
						desc = string.format(L["Sets the size of icons in lane %s"], i),
						order = 101,
						type = "range",
						softMin = 1,
						softMax = 128,
						bigStep = 1,
						get = function(info, index)
								return lane["icons"]["size"]
							end,
						set = function(info, val)
								lane["icons"]["size"] = val
								CDTL3:RefreshAllIcons()
						end,
					},
					spacer102 = {
						name = "\n",
						type = "description",
						order = 102,
					},
					iconAlpha = {
						name = L["Icon Transparency"],
						desc = L["Set the alpha for the icon (text alpha is set in text settings)"],
						order = 103,
						type = "range",
						min = 0,
						max = 1,
						get = function(info, index)
								return lane["icons"]["alpha"]
							end,
						set = function(info, val)
								lane["icons"]["alpha"] = val
								
								CDTL3:RefreshAllIcons()
						end,
					},
					spacer110 = {
						name = "\n",
						type = "description",
						order = 110,
					},
					yOffset = {
						name = L["Icon Offset"],
						desc = L["Offsets icons position on the lane from the center line"],
						order = 111,
						type = "range",
						softMin = -30,
						softMax = 30,
						bigStep = 1,
						get = function(info, index)
								return lane["iconOffset"]
							end,
						set = function(info, val)
								lane["iconOffset"] = val
								CDTL3:RefreshAllIcons()
						end,
					},
					spacer120 = {
						name = "\n\n",
						type = "description",
						order = 120,
					},
					textHeader = {
						name = L["Icon Text"],
						type = "header",
						order = 200.1,
					},
					spacer200 = {
						name = "\n",
						type = "description",
						order = 200.2,
					},
					-- ICON TEXT 1
					iText1Text = private.GetTextText(lane["icons"]["text1"], 210, i, "ICON", false),
					iText1Enabled = private.GetTextEnabled(lane["icons"]["text1"], 210, i, "ICON"),
					iText1Edit = private.GetTextEdit(lane["icons"]["text1"], 210, i, "ICON"),
					iText1Font = private.GetTextFont(lane["icons"]["text1"], 210, i, "ICON"),
					iText1Outline = private.GetTextOutline(lane["icons"]["text1"], 210, i, "ICON"),
					iText1S1 = { name = "", type = "description", order = 210 + 4.3, hidden = function(info) return not lane["icons"]["text1"]["edit"] end, },
					iText1Size = private.GetTextSize(lane["icons"]["text1"], 210, i, "ICON"),
					iText1Color = private.GetTextColor(lane["icons"]["text1"], 210, i, "ICON"),
					iText1ShadowColor = private.GetTextShadowColor(lane["icons"]["text1"], 210, i, "ICON"),
					iText1S2 = { name = "", type = "description", order = 210 + 4.7, hidden = function(info) return not lane["icons"]["text1"]["edit"] end, },
					iText1ShadowXOffset = private.GetTextShadowXOffset(lane["icons"]["text1"], 210, i, "ICON"),
					iText1ShadowYOffset = private.GetTextShadowYOffset(lane["icons"]["text1"], 210, i, "ICON"),
					iText1S3 = { name = "", type = "description", order = 210 + 5.1, hidden = function(info) return not lane["icons"]["text1"]["edit"] end, },
					iText1Anchor = private.GetTextAnchor(lane["icons"]["text1"], 210, i, "ICON"),
					iText1Align = private.GetTextAlign(lane["icons"]["text1"], 210, i, "ICON"),
					iText1S4 = { name = "", type = "description", order = 210 + 5.4, hidden = function(info) return not lane["icons"]["text1"]["edit"] end, },
					iText1XOffset = private.GetTextXOffset(lane["icons"]["text1"], 210, i, "ICON"),
					iText1YOffset = private.GetTextYOffset(lane["icons"]["text1"], 210, i, "ICON"),
					iText1Footer = { name = "", type = "header", order = 210 + 9.8, hidden = function(info) return not lane["icons"]["text1"]["edit"] end, },
					-- ICON TEXT 2
					iText2S0 = { name = "\n", type = "description", order = 220, hidden = function(info) return not lane["icons"]["text2"]["used"] end, },
					iText2Header = { name = "", type = "header", order = 220 + 0.1, hidden = function(info) return not lane["icons"]["text2"]["edit"] end, },
					iText2Text = private.GetTextText(lane["icons"]["text2"], 220, i, "ICON", false),
					iText2Enabled = private.GetTextEnabled(lane["icons"]["text2"], 220, i, "ICON"),
					iText2Edit = private.GetTextEdit(lane["icons"]["text2"], 220, i, "ICON"),
					iText2Font = private.GetTextFont(lane["icons"]["text2"], 220, i, "ICON"),
					iText2Outline = private.GetTextOutline(lane["icons"]["text2"], 220, i, "ICON"),
					iText2S1 = { name = "", type = "description", order = 220 + 4.3, hidden = function(info) return not lane["icons"]["text2"]["edit"] end, },
					iText2Size = private.GetTextSize(lane["icons"]["text2"], 220, i, "ICON"),
					iText2Color = private.GetTextColor(lane["icons"]["text2"], 220, i, "ICON"),
					iText2ShadowColor = private.GetTextShadowColor(lane["icons"]["text2"], 220, i, "ICON"),
					iText2S2 = { name = "", type = "description", order = 220 + 4.7, hidden = function(info) return not lane["icons"]["text2"]["edit"] end, },
					iText2ShadowXOffset = private.GetTextShadowXOffset(lane["icons"]["text2"], 220, i, "ICON"),
					iText2ShadowYOffset = private.GetTextShadowYOffset(lane["icons"]["text2"], 220, i, "ICON"),
					iText2S3 = { name = "", type = "description", order = 220 + 5.1, hidden = function(info) return not lane["icons"]["text2"]["edit"] end, },
					iText2Anchor = private.GetTextAnchor(lane["icons"]["text2"], 220, i, "ICON"),
					iText2Align = private.GetTextAlign(lane["icons"]["text2"], 220, i, "ICON"),
					iText2S4 = { name = "", type = "description", order = 220 + 5.4, hidden = function(info) return not lane["icons"]["text2"]["edit"] end, },
					iText2XOffset = private.GetTextXOffset(lane["icons"]["text2"], 220, i, "ICON"),
					iText2YOffset = private.GetTextYOffset(lane["icons"]["text2"], 220, i, "ICON"),
					iText2Footer = { name = "", type = "header", order = 220 + 9.8, hidden = function(info) return not lane["icons"]["text2"]["edit"] end, },
					-- ICON TEXT 3
					iText3S0 = { name = "\n", type = "description", order = 230, hidden = function(info) return not lane["icons"]["text3"]["used"] end, },
					iText3Header = { name = "", type = "header", order = 230 + 0.1, hidden = function(info) return not lane["icons"]["text3"]["edit"] end, },
					iText3Text = private.GetTextText(lane["icons"]["text3"], 230, i, "ICON", false),
					iText3Enabled = private.GetTextEnabled(lane["icons"]["text3"], 230, i, "ICON"),
					iText3Edit = private.GetTextEdit(lane["icons"]["text3"], 230, i, "ICON"),
					iText3Font = private.GetTextFont(lane["icons"]["text3"], 230, i, "ICON"),
					iText3Outline = private.GetTextOutline(lane["icons"]["text3"], 230, i, "ICON"),
					iText3S1 = { name = "", type = "description", order = 230 + 4.3, hidden = function(info) return not lane["icons"]["text3"]["edit"] end, },
					iText3Size = private.GetTextSize(lane["icons"]["text3"], 230, i, "ICON"),
					iText3Color = private.GetTextColor(lane["icons"]["text3"], 230, i, "ICON"),
					iText3ShadowColor = private.GetTextShadowColor(lane["icons"]["text3"], 230, i, "ICON"),
					iText3S2 = { name = "", type = "description", order = 230 + 4.7, hidden = function(info) return not lane["icons"]["text3"]["edit"] end, },
					iText3ShadowXOffset = private.GetTextShadowXOffset(lane["icons"]["text3"], 230, i, "ICON"),
					iText3ShadowYOffset = private.GetTextShadowYOffset(lane["icons"]["text3"], 230, i, "ICON"),
					iText3S3 = { name = "", type = "description", order = 230 + 5.1, hidden = function(info) return not lane["icons"]["text3"]["edit"] end, },
					iText3Anchor = private.GetTextAnchor(lane["icons"]["text3"], 230, i, "ICON"),
					iText3Align = private.GetTextAlign(lane["icons"]["text3"], 230, i, "ICON"),
					iText3S4 = { name = "", type = "description", order = 230 + 5.4, hidden = function(info) return not lane["icons"]["text3"]["edit"] end, },
					iText3XOffset = private.GetTextXOffset(lane["icons"]["text3"], 230, i, "ICON"),
					iText3YOffset = private.GetTextYOffset(lane["icons"]["text3"], 230, i, "ICON"),
					iText3Footer = { name = "", type = "header", order = 230 + 9.8, hidden = function(info) return not lane["icons"]["text3"]["edit"] end, },
					spacer288 = {
						name = "\n",
						type = "description",
						order = 288,
					},
					textFooter = {
						name = "",
						type = "header",
						order = 289,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					spacer400 = {
						name = "\n\n",
						type = "description",
						order = 400,
					},
					highlightStyle = {
						name = L["Highlight Style"],
						desc = L["How to highlight icons"],
						order = 401,
						type = "select",
						values = {
								["BORDER"] = L["Border"],
								["BORDER_FLASH"] = L["Border Flash"],
								["FLASH"] = L["Flash Icon"],
								["GLOW"] = L["Glow"],
							},
						get = function(info, index)
								return lane["icons"]["highlight"]["style"]
							end,
						set = function(info, val)
								lane["icons"]["highlight"]["style"] = val
								CDTL3:RefreshAllIcons()
							end,
					},
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
						hidden = function(info)
								if	lane["icons"]["highlight"]["style"] == "BORDER" or
									lane["icons"]["highlight"]["style"] == "BORDER_FLASH"
								then
									return false
								end
								
								return true
							end,
					},
					hlBorder = {
						name = "                    " .. L["Border Texture"],
						desc = L["Selects the border texture"],
						order = 501,
						hidden = function(info)
								if	lane["icons"]["highlight"]["style"] == "BORDER" or
									lane["icons"]["highlight"]["style"] == "BORDER_FLASH"
								then
									return false
								end
								
								return true
							end,
						type = "select",
						dialogControl = 'LSM30_Border',
						values = AceGUIWidgetLSMlists.border,
						get = function(info) return lane["icons"]["highlight"]["border"]["style"] end,
						set = function(info, val)
								lane["icons"]["highlight"]["border"]["style"] = val
								CDTL3:RefreshAllIcons()
							end,
					},
					hlBorderColor = {
						name = L["Color"],
						desc = L["Selects the border color"],
						order = 502,
						hidden = function(info)
								if	lane["icons"]["highlight"]["style"] == "BORDER" or
									lane["icons"]["highlight"]["style"] == "BORDER_FLASH"
								then
									return false
								end
								
								return true
							end,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local r = lane["icons"]["highlight"]["border"]["color"]["r"]
								local g = lane["icons"]["highlight"]["border"]["color"]["g"]
								local b = lane["icons"]["highlight"]["border"]["color"]["b"]
								local a = lane["icons"]["highlight"]["border"]["color"]["a"]
								
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								lane["icons"]["highlight"]["border"]["color"] = { r = red, g = green, b = blue, a = alpha }							
								CDTL3:RefreshAllIcons()
							end,
					},
					spacer510 = {
						name = "",
						type = "description",
						order = 510,
						hidden = function(info)
								if	lane["icons"]["highlight"]["style"] == "BORDER" or
									lane["icons"]["highlight"]["style"] == "BORDER_FLASH"
								then
									return false
								end
								
								return true
							end,
					},
					hlBorderSize = {
						name = L["Size"],
						desc = L["Sets the size of the border"],
						order = 511,
						hidden = function(info)
								if	lane["icons"]["highlight"]["style"] == "BORDER" or
									lane["icons"]["highlight"]["style"] == "BORDER_FLASH"
								then
									return false
								end
								
								return true
							end,
						type = "range",
						softMin = 1,
						softMax = 40,
						bigStep = 1,
						get = function(info) return lane["icons"]["highlight"]["border"]["size"] end,
						set = function(info, val)
								lane["icons"]["highlight"]["border"]["size"] = val
								CDTL3:RefreshAllIcons()
							end,
					},
					hlBorderPadding = {
						name = L["Padding"],
						desc = L["Sets the space between the border and the frame"],
						order = 511,
						hidden = function(info)
								if	lane["icons"]["highlight"]["style"] == "BORDER" or
									lane["icons"]["highlight"]["style"] == "BORDER_FLASH"
								then
									return false
								end
								
								return true
							end,
						type = "range",
						softMin = 0,
						softMax = 40,
						bigStep = 1,
						get = function(info) return lane["icons"]["highlight"]["border"]["padding"] end,
						set = function(info, val)
								lane["icons"]["highlight"]["border"]["padding"] = val
								CDTL3:RefreshAllIcons()
							end,
					},
				}
			},
			stacking = {
				name = L["Stacking"],
				type = "group",
				order = 400,
				args = {
					enabled = {
						name = L["Enabled"],
						desc = L["Enable icon stacking"],
						order = 101,
						type = "toggle",
						width = 0.5,
						get = function(info)
								return lane["stacking"]["enabled"]
							end,
						set = function(info, val)
								lane["stacking"]["enabled"] = val
							end,
					},
					raise = {
						name = L["Raise On Mouseover"],
						desc = L["Mousing over an icon will raise it to the top of its stack and make it easier to see"],
						order = 102,
						type = "toggle",
						get = function(info)
								return lane["stacking"]["raiseOnMouseOver"]
							end,
						set = function(info, val)
								lane["stacking"]["raiseOnMouseOver"] = val
							end,
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						order = 200,
					},
					style = {
						name = L["Stack Style"],
						desc = L["Select which direction new icons will grow in"],
						order = 201,
						type = "select",
						values = {
								["GROUPED"] = L["Grouped"],
								["OFFSET"] = L["Offset"],
							},
						get = function(info, index)
								return lane["stacking"]["style"]
							end,
						set = function(info, val)
								lane["stacking"]["style"] = val
							end,
					},
					grow = {
						name = L["Grow Direction"],
						desc = L["What direction should icon stacks grow"],
						order = 202,
						type = "select",
						values = {
								["UP"] = L["Up"],
								["DOWN"] = L["Down"],
								["CENTER"] = L["Center"],
							},
						get = function(info, index)
								return lane["stacking"]["grow"]
							end,
						set = function(info, val)
								lane["stacking"]["grow"] = val
							end,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					height = {
						name = L["Height"],
						desc = L["Sets the max height of the stack"],
						order = 301,
						type = "range",
						softMin = 0,
						softMax = 100,
						bigStep = 1,
						get = function(info, index)
								return lane["stacking"]["height"]
							end,
						set = function(info, val)
								lane["stacking"]["height"] = val
						end,
					},
				}
			},
			text = {
				name = L["Text"],
				type = "group",
				order = 500,
				args = {
					defaultHeader = {
						name = L["Default Text"],
						type = "header",
						order = 100,
					},
					-- DEFAULT TEXT 1
					dText1Text = private.GetTextText(lane["modeText"]["text1"], 210, i, "LANE", true),
					dText1Enabled = private.GetTextEnabled(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1Edit = private.GetTextEdit(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1Font = private.GetTextFont(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1Outline = private.GetTextOutline(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1S1 = { name = "", type = "description", order = 210 + 4.3, hidden = function(info) return not lane["modeText"]["text1"]["edit"] end, },
					dText1Size = private.GetTextSize(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1Color = private.GetTextColor(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1ShadowColor = private.GetTextShadowColor(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1S2 = { name = "", type = "description", order = 210 + 4.7, hidden = function(info) return not lane["modeText"]["text1"]["edit"] end, },
					dText1ShadowXOffset = private.GetTextShadowXOffset(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1ShadowYOffset = private.GetTextShadowYOffset(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1S3 = { name = "", type = "description", order = 210 + 5.1, hidden = function(info) return not lane["modeText"]["text1"]["edit"] end, },
					dText1Anchor = private.GetTextAnchor(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1Align = private.GetTextAlign(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1S4 = { name = "", type = "description", order = 210 + 5.4, hidden = function(info) return not lane["modeText"]["text1"]["edit"] end, },
					dText1XOffset = private.GetTextXOffset(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1YOffset = private.GetTextYOffset(lane["modeText"]["text1"], 210, i, "LANE"),
					dText1Footer = { name = "", type = "header", order = 210 + 9.8, hidden = function(info) return not lane["modeText"]["text1"]["edit"] end, },
					-- DEFAULT TEXT 2
					dText2S0 = { name = "\n", type = "description", order = 220, hidden = function(info) return not lane["modeText"]["text2"]["used"] end, },
					dText2Header = { name = "", type = "header", order = 220 + 0.1, hidden = function(info) return not lane["modeText"]["text2"]["edit"] end, },
					dText2Text = private.GetTextText(lane["modeText"]["text2"], 220, i, "LANE", true),
					dText2Enabled = private.GetTextEnabled(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2Edit = private.GetTextEdit(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2Font = private.GetTextFont(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2Outline = private.GetTextOutline(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2S1 = { name = "", type = "description", order = 220 + 4.3, hidden = function(info) return not lane["modeText"]["text2"]["edit"] end, },
					dText2Size = private.GetTextSize(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2Color = private.GetTextColor(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2ShadowColor = private.GetTextShadowColor(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2S2 = { name = "", type = "description", order = 220 + 4.7, hidden = function(info) return not lane["modeText"]["text2"]["edit"] end, },
					dText2ShadowXOffset = private.GetTextShadowXOffset(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2ShadowYOffset = private.GetTextShadowYOffset(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2S3 = { name = "", type = "description", order = 220 + 5.1, hidden = function(info) return not lane["modeText"]["text2"]["edit"] end, },
					dText2Anchor = private.GetTextAnchor(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2Align = private.GetTextAlign(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2S4 = { name = "", type = "description", order = 220 + 5.4, hidden = function(info) return not lane["modeText"]["text2"]["edit"] end, },
					dText2XOffset = private.GetTextXOffset(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2YOffset = private.GetTextYOffset(lane["modeText"]["text2"], 220, i, "LANE"),
					dText2Footer = { name = "", type = "header", order = 220 + 9.8, hidden = function(info) return not lane["modeText"]["text2"]["edit"] end, },
					-- DEFAULT TEXT 3
					dText3S0 = { name = "\n", type = "description", order = 230, hidden = function(info) return not lane["modeText"]["text3"]["used"] end, },
					dText3Header = { name = "", type = "header", order = 230 + 0.1, hidden = function(info) return not lane["modeText"]["text3"]["edit"] end, },
					dText3Text = private.GetTextText(lane["modeText"]["text3"], 230, i, "LANE", true),
					dText3Enabled = private.GetTextEnabled(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3Edit = private.GetTextEdit(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3Font = private.GetTextFont(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3Outline = private.GetTextOutline(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3S1 = { name = "", type = "description", order = 230 + 4.3, hidden = function(info) return not lane["modeText"]["text3"]["edit"] end, },
					dText3Size = private.GetTextSize(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3Color = private.GetTextColor(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3ShadowColor = private.GetTextShadowColor(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3S2 = { name = "", type = "description", order = 230 + 4.7, hidden = function(info) return not lane["modeText"]["text3"]["edit"] end, },
					dText3ShadowXOffset = private.GetTextShadowXOffset(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3ShadowYOffset = private.GetTextShadowYOffset(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3S3 = { name = "", type = "description", order = 230 + 5.1, hidden = function(info) return not lane["modeText"]["text3"]["edit"] end, },
					dText3Anchor = private.GetTextAnchor(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3Align = private.GetTextAlign(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3S4 = { name = "", type = "description", order = 230 + 5.4, hidden = function(info) return not lane["modeText"]["text3"]["edit"] end, },
					dText3XOffset = private.GetTextXOffset(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3YOffset = private.GetTextYOffset(lane["modeText"]["text3"], 230, i, "LANE"),
					dText3Footer = { name = "", type = "header", order = 230 + 9.8, hidden = function(info) return not lane["modeText"]["text3"]["edit"] end, },
					-- DEFAULT TEXT 4
					dText4S0 = { name = "\n", type = "description", order = 240, hidden = function(info) return not lane["modeText"]["text4"]["used"] end, },
					dText4Header = { name = "", type = "header", order = 240 + 0.1, hidden = function(info) return not lane["modeText"]["text4"]["edit"] end, },
					dText4Text = private.GetTextText(lane["modeText"]["text4"], 240, i, "LANE", true),
					dText4Enabled = private.GetTextEnabled(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4Edit = private.GetTextEdit(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4Font = private.GetTextFont(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4Outline = private.GetTextOutline(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4S1 = { name = "", type = "description", order = 240 + 4.3, hidden = function(info) return not lane["modeText"]["text4"]["edit"] end, },
					dText4Size = private.GetTextSize(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4Color = private.GetTextColor(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4ShadowColor = private.GetTextShadowColor(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4S2 = { name = "", type = "description", order = 240 + 4.7, hidden = function(info) return not lane["modeText"]["text4"]["edit"] end, },
					dText4ShadowXOffset = private.GetTextShadowXOffset(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4ShadowYOffset = private.GetTextShadowYOffset(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4S3 = { name = "", type = "description", order = 240 + 5.1, hidden = function(info) return not lane["modeText"]["text4"]["edit"] end, },
					dText4Anchor = private.GetTextAnchor(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4Align = private.GetTextAlign(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4S4 = { name = "", type = "description", order = 240 + 5.4, hidden = function(info) return not lane["modeText"]["text4"]["edit"] end, },
					dText4XOffset = private.GetTextXOffset(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4YOffset = private.GetTextYOffset(lane["modeText"]["text4"], 240, i, "LANE"),
					dText4Footer = { name = "", type = "header", order = 240 + 9.8, hidden = function(info) return not lane["modeText"]["text4"]["edit"] end, },
					-- DEFAULT TEXT 5
					dText5S0 = { name = "\n", type = "description", order = 250, hidden = function(info) return not lane["modeText"]["text5"]["used"] end, },
					dText5Header = { name = "", type = "header", order = 250 + 0.1, hidden = function(info) return not lane["modeText"]["text5"]["edit"] end, },
					dText5Text = private.GetTextText(lane["modeText"]["text5"], 250, i, "LANE", true),
					dText5Enabled = private.GetTextEnabled(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5Edit = private.GetTextEdit(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5Font = private.GetTextFont(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5Outline = private.GetTextOutline(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5S1 = { name = "", type = "description", order = 250 + 4.3, hidden = function(info) return not lane["modeText"]["text5"]["edit"] end, },
					dText5Size = private.GetTextSize(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5Color = private.GetTextColor(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5ShadowColor = private.GetTextShadowColor(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5S2 = { name = "", type = "description", order = 250 + 4.7, hidden = function(info) return not lane["modeText"]["text5"]["edit"] end, },
					dText5ShadowXOffset = private.GetTextShadowXOffset(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5ShadowYOffset = private.GetTextShadowYOffset(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5S3 = { name = "", type = "description", order = 250 + 5.1, hidden = function(info) return not lane["modeText"]["text5"]["edit"] end, },
					dText5Anchor = private.GetTextAnchor(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5Align = private.GetTextAlign(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5S4 = { name = "", type = "description", order = 250 + 5.4, hidden = function(info) return not lane["modeText"]["text5"]["edit"] end, },
					dText5XOffset = private.GetTextXOffset(lane["modeText"]["text5"], 250, i, "LANE"),
					dText5YOffset = private.GetTextYOffset(lane["modeText"]["text5"], 250, i, "LANE"),
					customHeader = {
						name = L["Custom Text"],
						type = "header",
						order = 300,
					},
					-- CUSTOM TEXT 1
					cText1S0 = { name = "\n", type = "description", order = 310, },
					cText1Text = private.GetTextText(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Enabled = private.GetTextEnabled(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Edit = private.GetTextEdit(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Font = private.GetTextFont(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Outline = private.GetTextOutline(lane["customText"]["text1"], 310, i, "LANE"),
					cText1S1 = { name = "", type = "description", order = 310 + 4.3, hidden = function(info) return not lane["customText"]["text1"]["edit"] end, },
					cText1Size = private.GetTextSize(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Color = private.GetTextColor(lane["customText"]["text1"], 310, i, "LANE"),
					cText1ShadowColor = private.GetTextShadowColor(lane["customText"]["text1"], 310, i, "LANE"),
					cText1S2 = { name = "", type = "description", order = 310 + 4.7, hidden = function(info) return not lane["customText"]["text1"]["edit"] end, },
					cText1ShadowXOffset = private.GetTextShadowXOffset(lane["customText"]["text1"], 310, i, "LANE"),
					cText1ShadowYOffset = private.GetTextShadowYOffset(lane["customText"]["text1"], 310, i, "LANE"),
					cText1S3 = { name = "", type = "description", order = 310 + 5.1, hidden = function(info) return not lane["customText"]["text1"]["edit"] end, },
					cText1Anchor = private.GetTextAnchor(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Align = private.GetTextAlign(lane["customText"]["text1"], 310, i, "LANE"),
					cText1S4 = { name = "", type = "description", order = 310 + 5.4, hidden = function(info) return not lane["customText"]["text1"]["edit"] end, },
					cText1XOffset = private.GetTextXOffset(lane["customText"]["text1"], 310, i, "LANE"),
					cText1YOffset = private.GetTextYOffset(lane["customText"]["text1"], 310, i, "LANE"),
					cText1Footer = { name = "", type = "header", order = 310 + 9.8, hidden = function(info) return not lane["customText"]["text1"]["edit"] end, },
					-- CUSTOM TEXT 2
					cText2S0 = { name = "\n", type = "description", order = 320, hidden = function(info) return not lane["customText"]["text2"]["used"] end, },
					cText2Header = { name = "", type = "header", order = 320 + 0.1, hidden = function(info) return not lane["customText"]["text2"]["edit"] end, },
					cText2Text = private.GetTextText(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Enabled = private.GetTextEnabled(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Edit = private.GetTextEdit(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Font = private.GetTextFont(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Outline = private.GetTextOutline(lane["customText"]["text2"], 320, i, "LANE"),
					cText2S1 = { name = "", type = "description", order = 320 + 4.3, hidden = function(info) return not lane["customText"]["text2"]["edit"] end, },
					cText2Size = private.GetTextSize(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Color = private.GetTextColor(lane["customText"]["text2"], 320, i, "LANE"),
					cText2ShadowColor = private.GetTextShadowColor(lane["customText"]["text2"], 320, i, "LANE"),
					cText2S2 = { name = "", type = "description", order = 320 + 4.7, hidden = function(info) return not lane["customText"]["text2"]["edit"] end, },
					cText2ShadowXOffset = private.GetTextShadowXOffset(lane["customText"]["text2"], 320, i, "LANE"),
					cText2ShadowYOffset = private.GetTextShadowYOffset(lane["customText"]["text2"], 320, i, "LANE"),
					cText2S3 = { name = "", type = "description", order = 320 + 5.1, hidden = function(info) return not lane["customText"]["text2"]["edit"] end, },
					cText2Anchor = private.GetTextAnchor(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Align = private.GetTextAlign(lane["customText"]["text2"], 320, i, "LANE"),
					cText2S4 = { name = "", type = "description", order = 320 + 5.4, hidden = function(info) return not lane["customText"]["text2"]["edit"] end, },
					cText2XOffset = private.GetTextXOffset(lane["customText"]["text2"], 320, i, "LANE"),
					cText2YOffset = private.GetTextYOffset(lane["customText"]["text2"], 320, i, "LANE"),
					cText2Footer = { name = "", type = "header", order = 320 + 9.8, hidden = function(info) return not lane["customText"]["text2"]["edit"] end, },
					-- CUSTOM TEXT 3
					cText3S0 = { name = "\n", type = "description", order = 330, hidden = function(info) return not lane["customText"]["text3"]["used"] end, },
					cText3Header = { name = "", type = "header", order = 330 + 0.1, hidden = function(info) return not lane["customText"]["text3"]["edit"] end, },
					cText3Text = private.GetTextText(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Enabled = private.GetTextEnabled(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Edit = private.GetTextEdit(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Font = private.GetTextFont(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Outline = private.GetTextOutline(lane["customText"]["text3"], 330, i, "LANE"),
					cText3S1 = { name = "", type = "description", order = 330 + 4.3, hidden = function(info) return not lane["customText"]["text3"]["edit"] end, },
					cText3Size = private.GetTextSize(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Color = private.GetTextColor(lane["customText"]["text3"], 330, i, "LANE"),
					cText3ShadowColor = private.GetTextShadowColor(lane["customText"]["text3"], 330, i, "LANE"),
					cText3S2 = { name = "", type = "description", order = 330 + 4.7, hidden = function(info) return not lane["customText"]["text3"]["edit"] end, },
					cText3ShadowXOffset = private.GetTextShadowXOffset(lane["customText"]["text3"], 330, i, "LANE"),
					cText3ShadowYOffset = private.GetTextShadowYOffset(lane["customText"]["text3"], 330, i, "LANE"),
					cText3S3 = { name = "", type = "description", order = 330 + 5.1, hidden = function(info) return not lane["customText"]["text3"]["edit"] end, },
					cText3Anchor = private.GetTextAnchor(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Align = private.GetTextAlign(lane["customText"]["text3"], 330, i, "LANE"),
					cText3S4 = { name = "", type = "description", order = 330 + 5.4, hidden = function(info) return not lane["customText"]["text3"]["edit"] end, },
					cText3XOffset = private.GetTextXOffset(lane["customText"]["text3"], 330, i, "LANE"),
					cText3YOffset = private.GetTextYOffset(lane["customText"]["text3"], 330, i, "LANE"),
					cText3Footer = { name = "", type = "header", order = 330 + 9.8, hidden = function(info) return not lane["customText"]["text3"]["edit"] end, },
					-- CUSTOM TEXT 4
					cText4S0 = { name = "\n", type = "description", order = 340, hidden = function(info) return not lane["customText"]["text4"]["used"] end, },
					cText4Header = { name = "", type = "header", order = 340 + 0.1, hidden = function(info) return not lane["customText"]["text4"]["edit"] end, },
					cText4Text = private.GetTextText(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Enabled = private.GetTextEnabled(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Edit = private.GetTextEdit(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Font = private.GetTextFont(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Outline = private.GetTextOutline(lane["customText"]["text4"], 340, i, "LANE"),
					cText4S1 = { name = "", type = "description", order = 340 + 4.3, hidden = function(info) return not lane["customText"]["text4"]["edit"] end, },
					cText4Size = private.GetTextSize(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Color = private.GetTextColor(lane["customText"]["text4"], 340, i, "LANE"),
					cText4ShadowColor = private.GetTextShadowColor(lane["customText"]["text4"], 340, i, "LANE"),
					cText4S2 = { name = "", type = "description", order = 340 + 4.7, hidden = function(info) return not lane["customText"]["text4"]["edit"] end, },
					cText4ShadowXOffset = private.GetTextShadowXOffset(lane["customText"]["text4"], 340, i, "LANE"),
					cText4ShadowYOffset = private.GetTextShadowYOffset(lane["customText"]["text4"], 340, i, "LANE"),
					cText4S3 = { name = "", type = "description", order = 340 + 5.1, hidden = function(info) return not lane["customText"]["text4"]["edit"] end, },
					cText4Anchor = private.GetTextAnchor(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Align = private.GetTextAlign(lane["customText"]["text4"], 340, i, "LANE"),
					cText4S4 = { name = "", type = "description", order = 340 + 5.4, hidden = function(info) return not lane["customText"]["text4"]["edit"] end, },
					cText4XOffset = private.GetTextXOffset(lane["customText"]["text4"], 340, i, "LANE"),
					cText4YOffset = private.GetTextYOffset(lane["customText"]["text4"], 340, i, "LANE"),
					cText4Footer = { name = "", type = "header", order = 340 + 9.8, hidden = function(info) return not lane["customText"]["text4"]["edit"] end, },
					-- CUSTOM TEXT 5
					cText5S0 = { name = "\n", type = "description", order = 350, hidden = function(info) return not lane["customText"]["text5"]["used"] end, },
					cText5Header = { name = "", type = "header", order = 350 + 0.1, hidden = function(info) return not lane["customText"]["text5"]["edit"] end, },
					cText5Text = private.GetTextText(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Enabled = private.GetTextEnabled(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Edit = private.GetTextEdit(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Font = private.GetTextFont(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Outline = private.GetTextOutline(lane["customText"]["text5"], 350, i, "LANE"),
					cText5S1 = { name = "", type = "description", order = 350 + 4.3, hidden = function(info) return not lane["customText"]["text5"]["edit"] end, },
					cText5Size = private.GetTextSize(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Color = private.GetTextColor(lane["customText"]["text5"], 350, i, "LANE"),
					cText5ShadowColor = private.GetTextShadowColor(lane["customText"]["text5"], 350, i, "LANE"),
					cText5S2 = { name = "", type = "description", order = 350 + 4.7, hidden = function(info) return not lane["customText"]["text5"]["edit"] end, },
					cText5ShadowXOffset = private.GetTextShadowXOffset(lane["customText"]["text5"], 350, i, "LANE"),
					cText5ShadowYOffset = private.GetTextShadowYOffset(lane["customText"]["text5"], 350, i, "LANE"),
					cText5S3 = { name = "", type = "description", order = 350 + 5.1, hidden = function(info) return not lane["customText"]["text5"]["edit"] end, },
					cText5Anchor = private.GetTextAnchor(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Align = private.GetTextAlign(lane["customText"]["text5"], 350, i, "LANE"),
					cText5S4 = { name = "", type = "description", order = 350 + 5.4, hidden = function(info) return not lane["customText"]["text5"]["edit"] end, },
					cText5XOffset = private.GetTextXOffset(lane["customText"]["text5"], 350, i, "LANE"),
					cText5YOffset = private.GetTextYOffset(lane["customText"]["text5"], 350, i, "LANE"),
					cText5Footer = { name = "", type = "header", order = 350 + 9.8, hidden = function(info) return not lane["customText"]["text5"]["edit"] end, },
				},
			},
		}
	}
	
	private.AddBorderArgs(options.args.appearance.args, 700, function() return lane["border"] end, function() CDTL3:RefreshLane(i) end, 703)
	CDTL3:AddAnchorArgs(options.args.appearance.args, 402, function() return lane end, function() CDTL3:RefreshLane(i) end, L["lane"])
	private.AddBorderArgs(options.args.icons.args, 300, function() return lane["icons"]["border"] end, function() CDTL3:RefreshAllIcons() end)

	private.AddCopyArgs(options.args.general.args, "lanes", i, L["Lane"])
	private.AddShowArgs(options.args.general.args, function() return lane end, function() CDTL3:RefreshLane(i) end)
	private.AddShareLaneArgs(options.args.general.args, i)
	CDTL3:AddCasterLaneArgs(options.args.general.args, i, lane)
	CDTL3.IconFx:AddLaneArgs(options.args, i)
	CDTL3:AddResourceBarArgs(options.args.general.args, i, lane)	-- ResourceBars.lua

	return options
end

private.GetReadySet = function(i)
	local ready = nil
	
	if i == 1 then
		ready = CDTL3.db.profile.ready["ready1"]
	elseif i == 2 then
		ready = CDTL3.db.profile.ready["ready2"]
	elseif i == 3 then
		ready = CDTL3.db.profile.ready["ready3"]
	end
	
	local options = {
		name = function(info)
				return ready["name"]
			end,
		type = "group",
		order = 100,
		args = {
			general = {
				name = L["General"],
				type = "group",
				order = 100,
				args = {
					name = {
						name = L["Frame Name"],
						type = "input",
						order = 101,
						get = function(info)
								return ready["name"]
							end,
						set = function(info, val)
								ready["name"] = val
								CDTL3:RefreshReady(i)
							end,
					},
					enabled = {
						name = L["Enabled"],
						desc = "",
						order = 102,
						type = "toggle",
						get = function(info, index)
								return ready["enabled"]
							end,
						set = function(info, val)
								ready["enabled"] = val
								
								if val then
									CDTL3:CreateReadyFrames()
								end
								
								CDTL3:RefreshReady(i)
							end,
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						order = 200,
					},
					grow = {
						name = L["Grow Direction"],
						desc = L["Select which direction new icons will grow in"],
						order = 201,
						type = "select",
						values = {
								["UP"] = "UP",
								["DOWN"] = "DOWN",
								["LEFT"] = "LEFT",
								["RIGHT"] = "RIGHT",
								["CENTER_H"] = "CENTER (H)",
								["CENTER_V"] = "CENTER (V)",
							},
						get = function(info, index)
								return ready["grow"]
							end,
						set = function(info, val)
								ready["grow"] = val
							end,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					nTime = {
						name = L["Normal Duration"],
						desc = L["How long an icon should stay in the ready frame"],
						order = 301,
						type = "range",
						softMin = 1,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return ready["nTime"]
							end,
						set = function(info, val)
								ready["nTime"] = val
						end,
					},
					nSound = {
						name = L["Normal Sound"],
						desc = L["Select which sound to play when an icon enters the frame"],
						order = 302,
						type = "select",
						width = "double",
						dialogControl = 'LSM30_Sound',
						values = AceGUIWidgetLSMlists.sound,
						get = function(info, index)
								return ready["nSound"]
							end,
						set = function(info, val)
								ready["nSound"] = val
								CDTL3:PlayPicked(val)
							end,
					},
					spacer400 = {
						name = "",
						type = "description",
						order = 400,
					},
					hTime = {
						name = L["Highlight Duration"],
						desc = L["How long a highlighted icon should stay in the ready frame"],
						order = 401,
						type = "range",
						softMin = 1,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return ready["hTime"]
							end,
						set = function(info, val)
								ready["hTime"] = val
						end,
					},
					hSound = {
						name = L["Highlight Sound"],
						desc = L["Select which sound to play when a highlighted icon enters the frame"],
						order = 402,
						type = "select",
						width = "double",
						dialogControl = 'LSM30_Sound',
						values = AceGUIWidgetLSMlists.sound,
						get = function(info, index)
								return ready["hSound"]
							end,
						set = function(info, val)
								ready["hSound"] = val
								CDTL3:PlayPicked(val)
							end,
					},
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
					},
					pTime = {
						name = L["Pinned Hide Time"],
						desc = L["How long the ready frame will stay visible after combat ends"],
						order = 501,
						type = "range",
						softMin = 1,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return ready["pTime"]
							end,
						set = function(info, val)
								ready["pTime"] = val
						end,
					},
					spacer600 = {
						name = "\n\n",
						type = "description",
						order = 600,
					},
					xPadding = {
						name = L["x Padding"],
						desc = L["Sets the x offset between growing icons"],
						order = 601,
						type = "range",
						softMin = -20,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return ready["icons"]["xPadding"]
							end,
						set = function(info, val)
								ready["icons"]["xPadding"] = val
						end,
					},
					yPadding = {
						name = L["y Padding"],
						desc = L["Sets the y offset between growing icons"],
						order = 602,
						type = "range",
						softMin = -20,
						softMax = 20,
						bigStep = 1,
						get = function(info, index)
								return ready["icons"]["yPadding"]
							end,
						set = function(info, val)
								ready["icons"]["yPadding"] = val
						end,
					},
				}
			},
			appearance = {
				name = L["Appearance"],
				type = "group",
				order = 200,
				args = {
					posX = {
						name = L["x Position"],
						desc = L["Sets the x position of the frame"],
						order = 111,
						type = "range",
						softMin = -500,
						softMax = 500,
						bigStep = 1,
						get = function(info, index)
								return ready["posX"]
							end,
						set = function(info, val)
								ready["posX"] = val
								CDTL3:RefreshReady(i)
							end,
					},
					posY = {
						name = L["y Position"],
						desc = L["Sets the y position of the frame"],
						order = 112,
						type = "range",
						softMin = -500,
						softMax = 500,
						bigStep = 1,
						get = function(info, index)
								return ready["posY"]
							end,
						set = function(info, val)
								ready["posY"] = val
								CDTL3:RefreshReady(i)
							end,
					},
					spacer113 = {
						name = "",
						type = "description",
						order = 113,
					},
					relativeTo = {
						name = L["Anchor Point"],
						desc = L["The x/y position is relative to this point of the screen"],
						order = 114,
						type = "select",
						values = {
								["TOPLEFT"] = "TOPLEFT",
								["TOP"] = "TOP",
								["TOPRIGHT"] = "TOPRIGHT",
								["LEFT"] = "LEFT",
								["CENTER"] = "CENTER",
								["RIGHT"] = "RIGHT",
								["BOTTOMLEFT"] = "BOTTOMLEFT",
								["BOTTOM"] = "BOTTOM",
								["BOTTOMRIGHT"] = "BOTTOMRIGHT",
							},
						get = function(info, index)
								return ready["relativeTo"]
							end,
						set = function(info, val)
								ready["relativeTo"] = val
								CDTL3:RefreshReady(i)
							end,
					},
					spacer200 = {
						name = "\n\n",
						type = "description",
						order = 200,
					},
					padding = {
						name = L["Padding"],
						desc = L["Sets the amount of padding in the frame"],
						order = 201,
						type = "range",
						softMin = 0,
						softMax = 40,
						bigStep = 1,
						get = function(info, index)
								return ready["padding"]
							end,
						set = function(info, val)
								ready["padding"] = val
								CDTL3:RefreshAllIcons()
								CDTL3:RefreshReady(i)
						end,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					bgTexture = {
						name = L["Background Texture"],
						desc = L["Sets the background texture"],
						order = 301,
						type = "select",
						dialogControl = 'LSM30_Statusbar',
						values = function() return CDTL3:GetBarTextureList() end,
						get = function(info, index)
								return ready["bgTexture"]
							end,
						set = function(info, val)
								ready["bgTexture"] = val
								CDTL3:RefreshReady(i)
							end,
					},
					bgTextureColor = {
						name = L["Color"],
						desc = L["Sets the background texture color"],
						order = 302,
						type = "color",
						hasAlpha = true,
						get = function(info)
								local r = ready["bgTextureColor"]["r"]
								local g = ready["bgTextureColor"]["g"]
								local b = ready["bgTextureColor"]["b"]
								local a = ready["bgTextureColor"]["a"]
								return r, g, b, a
							end,
						set = function(info, red, green, blue, alpha)
								ready["bgTextureColor"] = { r = red, g = green, b = blue, a = alpha }
								CDTL3:RefreshReady(i)
							end,
					},
					spacer400 = {
						name = "\n\n",
						type = "description",
						order = 400,
					},
				}
			},
			icons = {
				name = L["Icons"],
				type = "group",
				order = 300,
				args = {
					size = {
						name = L["Size"],
						desc = L["Sets the size of the frame, and icons in the ready frame"],
						order = 101,
						type = "range",
						softMin = 1,
						softMax = 128,
						bigStep = 1,
						get = function(info, index)
								return ready["icons"]["size"]
							end,
						set = function(info, val)
								ready["icons"]["size"] = val
								CDTL3:RefreshAllIcons()
								CDTL3:RefreshReady(i)
						end,
					},
					spacer102 = {
						name = "\n",
						type = "description",
						order = 102,
					},
					iconAlpha = {
						name = L["Icon Transparency"],
						desc = L["Set the alpha for the icon (text alpha is set in text settings)"],
						order = 103,
						type = "range",
						min = 0,
						max = 1,
						get = function(info, index)
								return ready["icons"]["alpha"]
							end,
						set = function(info, val)
								ready["icons"]["alpha"] = val
								
								CDTL3:RefreshAllIcons()
						end,
					},
					spacer104 = {
						name = "\n\n",
						type = "description",
						order = 104,
					},
					textHeader = {
						name = L["Icon Text"],
						type = "header",
						order = 200.1,
					},
					spacer200 = {
						name = "\n",
						type = "description",
						order = 200.2,
					},
					-- ICON TEXT 1
					iText1Text = private.GetTextText(ready["icons"]["text1"], 210, i, "ICON", false),
					iText1Enabled = private.GetTextEnabled(ready["icons"]["text1"], 210, i, "ICON"),
					iText1Edit = private.GetTextEdit(ready["icons"]["text1"], 210, i, "ICON"),
					iText1Font = private.GetTextFont(ready["icons"]["text1"], 210, i, "ICON"),
					iText1Outline = private.GetTextOutline(ready["icons"]["text1"], 210, i, "ICON"),
					iText1S1 = { name = "", type = "description", order = 210 + 4.3, hidden = function(info) return not ready["icons"]["text1"]["edit"] end, },
					iText1Size = private.GetTextSize(ready["icons"]["text1"], 210, i, "ICON"),
					iText1Color = private.GetTextColor(ready["icons"]["text1"], 210, i, "ICON"),
					iText1ShadowColor = private.GetTextShadowColor(ready["icons"]["text1"], 210, i, "ICON"),
					iText1S2 = { name = "", type = "description", order = 210 + 4.7, hidden = function(info) return not ready["icons"]["text1"]["edit"] end, },
					iText1ShadowXOffset = private.GetTextShadowXOffset(ready["icons"]["text1"], 210, i, "ICON"),
					iText1ShadowYOffset = private.GetTextShadowYOffset(ready["icons"]["text1"], 210, i, "ICON"),
					iText1S3 = { name = "", type = "description", order = 210 + 5.1, hidden = function(info) return not ready["icons"]["text1"]["edit"] end, },
					iText1Anchor = private.GetTextAnchor(ready["icons"]["text1"], 210, i, "ICON"),
					iText1Align = private.GetTextAlign(ready["icons"]["text1"], 210, i, "ICON"),
					iText1S4 = { name = "", type = "description", order = 210 + 5.4, hidden = function(info) return not ready["icons"]["text1"]["edit"] end, },
					iText1XOffset = private.GetTextXOffset(ready["icons"]["text1"], 210, i, "ICON"),
					iText1YOffset = private.GetTextYOffset(ready["icons"]["text1"], 210, i, "ICON"),
					iText1Footer = { name = "", type = "header", order = 210 + 9.8, hidden = function(info) return not ready["icons"]["text1"]["edit"] end, },
					-- ICON TEXT 2
					iText2S0 = { name = "\n", type = "description", order = 220, hidden = function(info) return not ready["icons"]["text2"]["used"] end, },
					iText2Header = { name = "", type = "header", order = 220 + 0.1, hidden = function(info) return not ready["icons"]["text2"]["edit"] end, },
					iText2Text = private.GetTextText(ready["icons"]["text2"], 220, i, "ICON", false),
					iText2Enabled = private.GetTextEnabled(ready["icons"]["text2"], 220, i, "ICON"),
					iText2Edit = private.GetTextEdit(ready["icons"]["text2"], 220, i, "ICON"),
					iText2Font = private.GetTextFont(ready["icons"]["text2"], 220, i, "ICON"),
					iText2Outline = private.GetTextOutline(ready["icons"]["text2"], 220, i, "ICON"),
					iText2S1 = { name = "", type = "description", order = 220 + 4.3, hidden = function(info) return not ready["icons"]["text2"]["edit"] end, },
					iText2Size = private.GetTextSize(ready["icons"]["text2"], 220, i, "ICON"),
					iText2Color = private.GetTextColor(ready["icons"]["text2"], 220, i, "ICON"),
					iText2ShadowColor = private.GetTextShadowColor(ready["icons"]["text2"], 220, i, "ICON"),
					iText2S2 = { name = "", type = "description", order = 220 + 4.7, hidden = function(info) return not ready["icons"]["text2"]["edit"] end, },
					iText2ShadowXOffset = private.GetTextShadowXOffset(ready["icons"]["text2"], 220, i, "ICON"),
					iText2ShadowYOffset = private.GetTextShadowYOffset(ready["icons"]["text2"], 220, i, "ICON"),
					iText2S3 = { name = "", type = "description", order = 220 + 5.1, hidden = function(info) return not ready["icons"]["text2"]["edit"] end, },
					iText2Anchor = private.GetTextAnchor(ready["icons"]["text2"], 220, i, "ICON"),
					iText2Align = private.GetTextAlign(ready["icons"]["text2"], 220, i, "ICON"),
					iText2S4 = { name = "", type = "description", order = 220 + 5.4, hidden = function(info) return not ready["icons"]["text2"]["edit"] end, },
					iText2XOffset = private.GetTextXOffset(ready["icons"]["text2"], 220, i, "ICON"),
					iText2YOffset = private.GetTextYOffset(ready["icons"]["text2"], 220, i, "ICON"),
					iText2Footer = { name = "", type = "header", order = 220 + 9.8, hidden = function(info) return not ready["icons"]["text2"]["edit"] end, },
					-- ICON TEXT 3
					iText3S0 = { name = "\n", type = "description", order = 230, hidden = function(info) return not ready["icons"]["text3"]["used"] end, },
					iText3Header = { name = "", type = "header", order = 230 + 0.1, hidden = function(info) return not ready["icons"]["text3"]["edit"] end, },
					iText3Text = private.GetTextText(ready["icons"]["text3"], 230, i, "ICON", false),
					iText3Enabled = private.GetTextEnabled(ready["icons"]["text3"], 230, i, "ICON"),
					iText3Edit = private.GetTextEdit(ready["icons"]["text3"], 230, i, "ICON"),
					iText3Font = private.GetTextFont(ready["icons"]["text3"], 230, i, "ICON"),
					iText3Outline = private.GetTextOutline(ready["icons"]["text3"], 230, i, "ICON"),
					iText3S1 = { name = "", type = "description", order = 230 + 4.3, hidden = function(info) return not ready["icons"]["text3"]["edit"] end, },
					iText3Size = private.GetTextSize(ready["icons"]["text3"], 230, i, "ICON"),
					iText3Color = private.GetTextColor(ready["icons"]["text3"], 230, i, "ICON"),
					iText3ShadowColor = private.GetTextShadowColor(ready["icons"]["text3"], 230, i, "ICON"),
					iText3S2 = { name = "", type = "description", order = 230 + 4.7, hidden = function(info) return not ready["icons"]["text3"]["edit"] end, },
					iText3ShadowXOffset = private.GetTextShadowXOffset(ready["icons"]["text3"], 230, i, "ICON"),
					iText3ShadowYOffset = private.GetTextShadowYOffset(ready["icons"]["text3"], 230, i, "ICON"),
					iText3S3 = { name = "", type = "description", order = 230 + 5.1, hidden = function(info) return not ready["icons"]["text3"]["edit"] end, },
					iText3Anchor = private.GetTextAnchor(ready["icons"]["text3"], 230, i, "ICON"),
					iText3Align = private.GetTextAlign(ready["icons"]["text3"], 230, i, "ICON"),
					iText3S4 = { name = "", type = "description", order = 230 + 5.4, hidden = function(info) return not ready["icons"]["text3"]["edit"] end, },
					iText3XOffset = private.GetTextXOffset(ready["icons"]["text3"], 230, i, "ICON"),
					iText3YOffset = private.GetTextYOffset(ready["icons"]["text3"], 230, i, "ICON"),
					iText3Footer = { name = "", type = "header", order = 230 + 9.8, hidden = function(info) return not ready["icons"]["text3"]["edit"] end, },
					spacer298 = {
						name = "\n",
						type = "description",
						order = 298,
					},
					textFooter = {
						name = "",
						type = "header",
						order = 299,
					},
					spacer300 = {
						name = "\n\n",
						type = "description",
						order = 300,
					},
					spacer400 = {
						name = "\n\n",
						type = "description",
						order = 400,
					},
					highlightStyle = {
						name = L["Highlight Style"],
						desc = L["How to highlight icons"],
						order = 401,
						type = "select",
						values = {
								["BORDER"] = L["Border"],
								["BORDER_FLASH"] = L["Border Flash"],
								["FLASH"] = L["Flash Icon"],
								["GLOW"] = L["Glow"],
							},
						get = function(info, index)
								return ready["icons"]["highlight"]["style"]
							end,
						set = function(info, val)
								ready["icons"]["highlight"]["style"] = val
								CDTL3:RefreshAllIcons(i)
							end,
					},
				}
			},
		}
	}
	
	private.AddBorderArgs(options.args.appearance.args, 400, function() return ready["border"] end, function() CDTL3:RefreshReady(i) end)
	CDTL3:AddAnchorArgs(options.args.appearance.args, 115, function() return ready end, function() CDTL3:RefreshReady(i) end, L["ready frame"])
	private.AddBorderArgs(options.args.icons.args, 300, function() return ready["icons"]["border"] end, function() CDTL3:RefreshAllIcons() end)

	private.AddCopyArgs(options.args.general.args, "ready", i, L["Ready Frame"])
	private.AddReadyTestArgs(options.args.general.args, ready)
	CDTL3:AddReadyBoardArgs(options.args.general.args, ready, i)	-- ReadyBoard.lua
	private.AddShowArgs(options.args.general.args, function() return ready end, function() CDTL3:RefreshReady(i) end)

	return options
end

private.GetTextText = function(s, o, i, r, d)
	local options = {
		name = function(info)
				return " "
			end,
		desc = function(info)
				if r == "LANE" then
					return CDTL3:GetCustomTextTagDescription()
				else
					return CDTL3:GetCustomIconTagDescription()
				end
			end,
		type = "input",
		order = o + 1,
		disabled = d,
		hidden = function(info)
				return not s["used"]
			end,
		get = function(info)
				return s["text"]
			end,
		set = function(info, val)
				s["text"] = val
				
				-- recompute both flags: they used to only ever switch on, so an edited
				-- text kept being redrawn from a tag family it no longer contains
				s["dtags"] = CDTL3:ScanForDynamicTags(val)
				s["ttags"] = CDTL3:ScanForTimeTags(val)
				
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextEnabled = function(s, o, i, r)
	local options = {
		name = L["Enabled"],
		desc = L["Show this text"],
		order = o + 2,
		type = "toggle",
		width = 0.5,
		hidden = function(info)
				return not s["used"]
			end,
		get = function(info)
				return s["enabled"]
			end,
		set = function(info, val)
				s["enabled"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextEdit = function(s, o, i, r)
	local options = {
		name = L["Edit"],
		desc = L["Edit this text"],
		order = o + 3,
		type = "toggle",
		width = 0.5,
		hidden = function(info)
				return not s["used"]
			end,
		get = function(info)
				return s["edit"]
			end,
		set = function(info, val)
				s["edit"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextFont = function(s, o, i, r)
	local options = {
		name = L["Font"],
		desc = L["Selects the font for text on the bars"],
		order = o + 4.1,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "select",
		dialogControl = 'LSM30_Font',
		values = AceGUIWidgetLSMlists.font,
		get = function(info) return s["font"] end,
		set = function(info, val)
				s["font"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextOutline = function(s, o, i, r)
	local options = {
		name = L["Outline"],
		desc = L["Sets the text outline"],
		order = o + 4.2,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "select",
		values = {
				["NONE"] = L["None"],
				["OUTLINE"] = L["Outline"],
				["THICKOUTLINE"] = L["Thick Outline"],
				["MONOCHROME"] = L["Monochrome"]
			},
		get = function(info) return s["outline"] end,
		set = function(info, val)
				s["outline"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextSize = function(s, o, i, r)
	local options = {
		name = L["Font Size"],
		desc = L["Sets the size of the font"],
		order = o + 4.4,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "range",
		softMin = 1,
		softMax = 64,
		bigStep = 1,
		get = function(info) return s["size"] end,
		set = function(info, val)
				s["size"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextColor = function(s, o, i, r)
	local options = {
		name = L["Color"],
		desc = L["Selects the font color"],
		order = o + 4.5,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "color",
		hasAlpha = true,
		get = function(info)
				local t = s["color"]
				
				local r = t["r"]
				local g = t["g"]
				local b = t["b"]
				local a = t["a"]
				return r, g, b, a
			end,
		set = function(info, red, green, blue, alpha)
				s["color"] = { r = red, g = green, b = blue, a = alpha }
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextShadowColor = function(s, o, i, r)
	local options = {
		name = L["Shadow Color"],
		desc = L["Selects the shadow color"],
		order = o + 4.6,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "color",
		hasAlpha = true,
		get = function(info)
				local t = s["shadColor"]
				
				local r = t["r"]
				local g = t["g"]
				local b = t["b"]
				local a = t["a"]
				return r, g, b, a
			end,
		set = function(info, red, green, blue, alpha)
				s["shadColor"] = { r = red, g = green, b = blue, a = alpha }
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextShadowXOffset = function(s, o, i, r)
	local options = {
		name = L["Shadow x Offset"],
		desc = L["Sets the text shadow x offset"],
		order = o + 4.8,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "range",
		softMin = -5,
		softMax = 5,
		bigStep = 1,
		get = function(info) return s["shadX"] end,
		set = function(info, val)
				s["shadX"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextShadowYOffset = function(s, o, i, r)
	local options = {
		name = L["Shadow y Offset"],
		desc = L["Sets the text shadow y offset"],
		order = o + 4.9,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "range",
		softMin = -5,
		softMax = 5,
		bigStep = 1,
		get = function(info) return s["shadY"] end,
		set = function(info, val)
				s["shadY"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextAnchor = function(s, o, i, r)
	local options = {
		name = L["Anchor"],
		desc = L["Sets the text anchor point"],
		order = o + 5.2,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "select",
		values = {
				["TOPLEFT"] = "TOPLEFT",
				["TOP"] = "TOP",
				["TOPRIGHT"] = "TOPRIGHT",
				["LEFT"] = "LEFT",
				["CENTER"] = "CENTER",
				["RIGHT"] = "RIGHT",
				["BOTTOMLEFT"] = "BOTTOMLEFT",
				["BOTTOM"] = "BOTTOM",
				["BOTTOMRIGHT"] = "BOTTOMRIGHT",
			},
		get = function(info) return s["anchor"] end,
		set = function(info, val)
				s["anchor"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextAlign = function(s, o, i, r)
	local options = {
		name = L["Align"],
		desc = L["Sets the text alignment"],
		order = o + 5.3,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "select",
		values = {
				["LEFT"] = "LEFT",
				["CENTER"] = "CENTER",
				["RIGHT"] = "RIGHT",
			},
		get = function(info) return s["align"] end,
		set = function(info, val)
				s["align"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextXOffset = function(s, o, i, r)
	local options = {
		name = L["x Offset"],
		desc = L["Sets text x offset"],
		order = o + 5.5,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "range",
		softMin = -5,
		softMax = 5,
		bigStep = 1,
		get = function(info) return s["offX"] end,
		set = function(info, val)
				s["offX"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end

private.GetTextYOffset = function(s, o, i, r)
	local options = {
		name = L["y Offset"],
		desc = L["Sets text y offset"],
		order = o + 5.6,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "range",
		softMin = -5,
		softMax = 5,
		bigStep = 1,
		get = function(info) return s["offY"] end,
		set = function(info, val)
				s["offY"] = val
				if r == "LANE" then
					CDTL3:RefreshLane(i)
				elseif r == "BAR" then
					CDTL3:RefreshAllBars()
				elseif r == "ICON" then
					CDTL3:RefreshAllIcons()
				end
			end,
	}
	
	return options
end
-- The complete settings tree for the standalone movable window: main options plus the
-- Lanes/Ready/Bar Frames/Filters/Profiles panels as tabs. Blizzard's Settings frame is
-- unmovable, so the standalone dialog is the primary config surface — the Blizzard
-- AddOns list gets only a launcher button (see OnInitialize).
function CDTL3:GetFullOptions()
	local options = CDTL3:GetMainOptions()

	local lanes = CDTL3:GetLaneOptions()
	local ready = CDTL3:GetReadyOptions()
	local barFrames = CDTL3:GetBarFrameOptions()
	local filters = CDTL3:GetFilterOptions()

	lanes.order = 2001
	ready.order = 2002
	barFrames.order = 2003
	filters.order = 2004

	options.args.lanes = lanes
	options.args.ready = ready
	options.args.barFrames = barFrames
	options.args.filters = filters

	if CDTL3.profile then
		CDTL3.profile.order = 2005
		private.ConfirmProfileWipes(CDTL3.profile)
		options.args.profiles = CDTL3.profile
	end

	-- the Fight Timeline tab (FightTimeline.lua)
	local fightTimeline = CDTL3:GetFightTimelineOptions()
	fightTimeline.order = 2006
	options.args.fightTimeline = fightTimeline

	private.AddMediaNotes(options)

	return options
end

-- Reset Profile and Copy From replace the whole profile, Filters lists included, for every
-- character on it, so they ask first (stock Ace3 asks only before Delete). AceDBOptions hands
-- every addon the same args table, so CDTL3 changes only its own copy of it.
private.ConfirmProfileWipes = function(profile)
	if profile.args == private.profileArgs then
		return
	end

	local args = {}
	for k, v in pairs(profile.args) do
		args[k] = v
	end

	local texts = {
		reset = L["Reset this profile to the default settings?\n\nEvery character on this profile loses its Filters lists: saved spells, items and auras, Customs and Custom CD Times."],
		copyfrom = L["Copy the chosen profile over this one?\n\nEvery character on this profile loses its Filters lists (saved spells, items and auras, Customs and Custom CD Times) and gets the chosen profile's instead."],
	}
	-- while sharing (Profiles.lua) the lists every character uses aren't touched
	local sharedTexts = {
		reset = L["Reset this profile to the default settings?\n\nSharing is on: the Filters lists all your characters share stay as they are. Only this profile's settings are reset."],
		copyfrom = L["Copy the chosen profile's settings over this one?\n\nSharing is on: the Filters lists all your characters share stay as they are. Only this profile's settings change."],
	}
	for key, text in pairs(texts) do
		if args[key] then
			local copy = {}
			for k, v in pairs(args[key]) do
				copy[k] = v
			end
			copy.confirm = function()
					return CDTL3:SharingEntries() and sharedTexts[key] or text
				end
			copy.confirmText = text
			args[key] = copy
		end
	end

	profile.args = args
	private.profileArgs = args
end

-- Plays a picked sound once for a Play sound button (even while Mute ready sounds is on)
private.PlayTestSound = function(sound)
	if sound and sound ~= "None" then
		PlaySoundFile(CDTL3.LSM:Fetch("sound", sound), "SFX")
	end
end

-- Per-entry ready alerts (Filters): its own Ready sound, Flash when ready and Say its name when
-- ready (where the client has text to speech). Off by default: the Ready frame's sounds as before.
-- Read when the cooldown reaches its Ready frame (private.ReadyAlert, Cooldown.lua).
private.AddEntryReadyArgs = function(args, t)
	local function hidden()
		return CDTL3.currentFilterHidden[t]
	end
	local function entry()
		return private.FilterEntry(t)
	end
	local function get(key)
		local s = entry()
		return s and s[key] or false
	end
	local function set(key, val)
		local s = entry()
		if s then
			s[key] = val
		end
	end
	-- the Ready frame this entry goes to (its Normal Sound is where an own sound starts)
	local function readyFrame(s)
		local n = s and tonumber(s["readyFrame"])
		return CDTL3.db.profile.ready["ready" .. ((n and n >= 1 and n <= 3) and n or 1)]
	end

	args["spacer750"] = {
		name = "\n",
		type = "description",
		order = 750,
		hidden = hidden,
	}
	args["ownSound"] = {
		name = L["Own ready sound"],
		desc = L["Play this sound when it's ready, instead of its Ready frame's Normal or Highlight Sound"],
		order = 751,
		type = "toggle",
		hidden = hidden,
		get = function(info) return get("ownSound") end,
		set = function(info, val)
				local s = entry()
				if s and val and not s["sound"] then
					s["sound"] = readyFrame(s)["nSound"]
				end
				set("ownSound", val)
			end,
	}
	args["sound"] = {
		name = L["Ready Sound"],
		desc = L["The sound this plays when it's ready"],
		order = 752,
		type = "select",
		width = "double",
		dialogControl = 'LSM30_Sound',
		values = AceGUIWidgetLSMlists.sound,
		hidden = function(info)
				return hidden() or not get("ownSound")
			end,
		get = function(info)
				local s = entry()
				return s and s["sound"] or "None"
			end,
		set = function(info, val)
			set("sound", val)
			CDTL3:PlayPicked(val)
		end,
	}
	args["soundTest"] = {
		name = L["Play sound"],
		desc = L["Plays the Ready Sound once, so you can hear it"],
		order = 752.1,
		type = "execute",
		width = "normal",
		hidden = function(info)
				return hidden() or not get("ownSound")
			end,
		func = function(info)
				local s = entry()
				private.PlayTestSound(s and s["sound"])
			end,
	}
	args["spacer753"] = {
		name = "",
		type = "description",
		order = 753,
		hidden = hidden,
	}
	args["readyFlash"] = {
		name = L["Flash when ready"],
		desc = L["Its icon flashes (the Flash Icon highlight) while it waits in the Ready frame"],
		order = 754,
		type = "toggle",
		hidden = hidden,
		get = function(info) return get("readyFlash") end,
		set = function(info, val)
				set("readyFlash", val)
				-- an icon waiting in its Ready frame right now flashes, or stops, at once
				local s = entry()
				if s and s ~= CDTL3.custom then
					local name = CDTL3.currentFilter[t]
					for _, cd in pairs(CDTL3.cooldowns) do
						if cd.data["type"] == t and (cd.data["name"] == name or cd.data["itemName"] == name) then
							local p = cd.icon:GetParent()
							local n = p and p:GetName()
							if n == "CDTL3_Ready_1_MF" or n == "CDTL3_Ready_2_MF" or n == "CDTL3_Ready_3_MF" then
								cd.data["readyLit"] = val and true or nil
								CDTL3:RefreshIcon(cd)
							end
						end
					end
				end
			end,
	}
	args["sayName"] = {
		name = L["Say its name when ready"],
		desc = L["The game's text to speech says its name when it's ready (voice, speed and volume from the game's Text to Speech options)"],
		order = 755,
		type = "toggle",
		width = 1.3,
		hidden = function(info)
				return hidden() or not CDTL3:CanSpeak()
			end,
		get = function(info) return get("sayName") end,
		set = function(info, val) set("sayName", val) end,
	}
end

-- Ready tab, above the Ready frames' tabs: one switch for every ready sound
private.AddReadySoundArgs = function(args)
	args["muteReadySounds"] = {
		name = L["Mute ready sounds"],
		desc = L["No sound when something is ready: the Ready frames' sounds, the spells' own Ready sounds and spoken names are all silenced"],
		order = 10,
		type = "toggle",
		width = "full",
		get = function(info) return CDTL3.db.profile.global["muteReadySounds"] end,
		set = function(info, val) CDTL3.db.profile.global["muteReadySounds"] = val end,
	}
end

-- Ready frame > General: a Play sound button beside each sound picker (it plays even while
-- Mute ready sounds is on, so a sound can still be picked)
private.AddReadyTestArgs = function(args, ready)
	local function play(key)
		local sound = ready[key]
		if sound and sound ~= "None" then
			PlaySoundFile(CDTL3.LSM:Fetch("sound", sound), "SFX")
		end
	end

	args["nSoundTest"] = {
		name = L["Play sound"],
		desc = L["Plays the Normal Sound once, so you can hear it"],
		order = 303,
		type = "execute",
		width = "normal",
		func = function(info) play("nSound") end,
	}
	args["hSoundTest"] = {
		name = L["Play sound"],
		desc = L["Plays the Highlight Sound once, so you can hear it"],
		order = 403,
		type = "execute",
		width = "normal",
		func = function(info) play("hSound") end,
	}
end

-- Show (each lane, bar frame and ready frame > General): when the frame shows, and Dim instead
-- of hide. Defaults follow Global > Hide out of combat, as before (CDTL3:ShowRuleHides, Helpers.lua).
private.SHOW_MODES = {
	["GLOBAL"] = L["Use the global setting"],
	["ALWAYS"] = L["Always"],
	["COMBAT"] = L["Only in combat"],
	["BOSS"] = L["Boss fights only"],
}

private.AddShowArgs = function(args, settings, refresh)
	args["showHeader"] = {
		name = "",
		type = "header",
		order = 850,
	}
	args["showMode"] = {
		name = L["Show"],
		desc = L["When this frame shows. Use the global setting follows Hide out of combat on the Global tab"],
		order = 851,
		type = "select",
		values = private.SHOW_MODES,
		sorting = { "GLOBAL", "ALWAYS", "COMBAT", "BOSS" },
		get = function(info) return settings()["showMode"] or "GLOBAL" end,
		set = function(info, val)
				settings()["showMode"] = val
				refresh()
			end,
	}
	args["dimInsteadOfHide"] = {
		name = L["Dim instead of hide"],
		desc = L["When Show would hide this frame, it stays faintly visible instead"],
		order = 852,
		type = "toggle",
		disabled = function(info) return settings()["showMode"] == "ALWAYS" end,
		get = function(info) return settings()["dimInsteadOfHide"] end,
		set = function(info, val)
				settings()["dimInsteadOfHide"] = val
				refresh()
			end,
	}
	args["dimAlpha"] = {
		name = L["Dimmed alpha"],
		desc = L["How visible the frame is while dimmed (0 is invisible, 1 is fully shown)"],
		order = 853,
		type = "range",
		min = 0,
		max = 1,
		step = 0.05,
		isPercent = true,
		hidden = function(info) return not settings()["dimInsteadOfHide"] end,
		get = function(info) return settings()["dimAlpha"] end,
		set = function(info, val)
				settings()["dimAlpha"] = val
				refresh()
			end,
	}
end

-- Global tab, first thing: Preview with sample icons, Stop preview while it runs (the test mode;
-- CDTL3:TogglePreview, CDTL3.lua)
private.AddPreviewArgs = function(args)
	args["preview"] = {
		name = function(info)
				return CDTL3.testing and L["Stop preview"] or L["Preview with sample icons"]
			end,
		desc = L["Fills the lanes, bar frames and ready frames with sample icons, so you can see them and move them while frames are unlocked. The Test Panel that opens changes the samples. Click again to stop."],
		order = 1,
		type = "execute",
		width = 1.4,
		func = function(info) CDTL3:TogglePreview() end,
	}
end
