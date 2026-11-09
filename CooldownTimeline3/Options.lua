--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}

-- Free-text seconds inputs: reject anything that isn't a positive number before the
-- setter runs (it used to do val * 1000 on raw text, which errors on "", "abc", "1,5")
private.ValidateSeconds = function(info, val)
	local n = tonumber(val)
	if n and n > 0 then
		return true
	end

	return "Enter a time in seconds, e.g. 30 or 1.5"
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

-- Border texture, colour, size and padding controls, added to args: texture and colour at
-- first, first+1 (default base+1), size and padding at base+11, base+12. border() returns
-- the live { style, color, size, padding } settings table.
private.AddBorderArgs = function(args, base, border, refresh, first)
	first = first or base + 1

	args["border"] = {
		name = "                    Border Texture",
		desc = "Selects the border texture",
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
		name = "Color",
		desc = "Selects the border color",
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
		name = "Size",
		desc = "Sets the size of the border",
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
		name = "Padding",
		desc = "Sets the space between the border and the frame",
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

private.AddSchoolColorArgs = function(args)
	args["spacer300"] = {
		name = "\n\nSpell School Colors\n|cffaaaaaaUsed by bar frames with Spell School Color ticked. Multi-school and not-yet-seen spells use Other.|r",
		type = "description",
		fontSize = "large",
		order = 300,
		hidden = private.NoCombatLog,
	}
	for n, school in ipairs(private.SCHOOLS) do
		args["school"..school] = {
			name = school,
			desc = "Set the "..school.." school color",
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
		name = "Quick Style",
		type = "group",
		order = 150,
		args = {
			intro = {
				name = "\nPick a style and apply it to every lane, bar frame and ready frame at once. Only looks change (textures, colours, borders, fonts); sizes, positions and what is tracked stay as they are. Fine-tune anything afterwards in the Lanes, Bar Frames and Ready tabs.\n",
				type = "description",
				fontSize = "medium",
				order = 100,
			},
			preset = {
				name = "Style",
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
				name = "Apply Style",
				desc = "Apply the selected style to every lane, bar frame and ready frame",
				order = 103,
				type = "execute",
				confirm = true,
				confirmText = "Apply this style to every lane, bar frame and ready frame? Your current textures, colours, borders and fonts will be replaced (export your profile first if you want to keep them).",
				func = function(info)
						CDTL3:ApplyPreset(private.selectedPreset)
					end,
			},
		},
	}
end

-- "Copy settings from" (each lane / bar frame / ready frame's General tab)
private.copySource = {}

private.AddCopyArgs = function(args, group, i, label)
	local id = group..i

	args["copyHeader"] = {
		name = "Copy Settings",
		type = "header",
		order = 900,
	}
	args["copyFrom"] = {
		name = "Copy From",
		desc = "Copy every setting from another "..label:lower().." to this one, except its name, position and whether it's enabled",
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
		name = "Copy",
		order = 902,
		type = "execute",
		confirm = true,
		confirmText = "Replace this "..label:lower().."'s settings with a copy?",
		disabled = function(info) return not private.copySource[id] end,
		func = function(info)
				CDTL3:CopyFrameSettings(group, private.copySource[id], i)
				private.copySource[id] = nil
			end,
	}
end

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
		name = "Own Bar Color",
		desc = "Give this entry's bar its own color instead of the bar frame's (class / school / frame color)",
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
		name = "Bar Color",
		desc = "This entry's bar color",
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
		swingNote = " (needs combat log)"
	end

	return {
		["NONE"] = "None",
		["GCD"] = "GCD",
		["HEALTH"] = "Health",
		["CLASS_POWER"] = "Class Power",
		["COMBO_POINTS"] = "Combo Points",
		["MANA_TICK"] = "Mana Tick",
		["ENERGY_TICK"] = "Energy Tick",
		["MH_SWING"] = "MH Swing"..swingNote,
		["OH_SWING"] = "OH Swing"..swingNote,
		["RANGE_SWING"] = "Ranged Auto-attack",
	}
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

function CDTL3:GetSpecialMessage()
	local message = ""
	--message = message.."\n"
	--message = message.."Profile import/exporting testing is still ongoing.\n"
	--message = message.."\n"
	--message = message.."While I havent seen any issues with this feature yet, I want to make sure it works ok, so please provide feedback where appropriate.\n"
	--message = message.."\n"
		
	return message
end

function CDTL3:GetMainOptions()
	local options = {
		name = "CDTL3",
		type = "group",
		childGroups  = "tab",
		args = {
			global = {
				name = "Global",
				type = "group",
				order = 100,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = "\nEnabled:\n",
						type = "description",
						order = 100,
					},
					enabledAlways = {
						name = "Always",
						desc = "If selected, CD/Duration detection will always be on",
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
						name = "In Group",
						desc = "If selected, CD/Duration detection will be enabled when in a party/raid",
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
						name = "In Instance",
						desc = "If selected, CD/Duration detection will be enabled when in an instance/raid/bg/arena",
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
						name = "Unlock Frames",
						desc = "Unlock frames to allow drag and drop movement",
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
						name = "Hide out of combat",
						desc = "Frames appear when you enter combat and fade when you leave it. Cooldown detection keeps running the whole time, so a cooldown started on the last pull is still tracked and shown on the next one. Unlock frames, Edit Mode and test mode always show the frames",
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
						name = "Auto-hide Frames",
						desc = "If selected frames will hide themselves when there is no active bar/icon in it",
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
						name = "Minimap button",
						desc = "Show the CDTL3 button on the minimap (also: /cdtl3 minimap). Account-wide.",
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
					enableTooltip = {
						name = "Enable tooltips",
						desc = "If selected mousing over icons will display a tooltip",
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
						name = "Detect Shared Spell Cooldowns",
						desc = "If selected the mod will attempt to detect other spells that share a cooldown as the initially cast spell and generate icons/bars for them",
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
						name = "Icon Zoom",
						desc = "Sets the zoom level of icons",
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
						name = "Tint Unusable Icons",
						desc = "If selected unusable icons (eg. not enough mana) will be desaturated/tinted",
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
						name = "Desaturate",
						desc = "If selected non usable icons will be desaturated instead of colored",
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
						name = "Not Usable Color",
						desc = "Select the tint color of non usable icons",
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
					spacer700 = {
						name = "\n\n",
						type = "description",
						order = 700,
					},
					openTestPanel = {
						name = function(info)
								return "Open Test Panel"
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
				name = "Colors",
				type = "group",
				order = 200,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = "\nClass Colors",
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
						name = "Death Knight",
						desc = "Set the Death Knight class color",
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
						name = "Demon Hunter",
						desc = "Set the Demon Hunter class color",
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
						name = "Druid",
						desc = "Set the Druid class color",
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
						name = "Evoker",
						desc = "Set the Evoker class color",
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
						name = "Hunter",
						desc = "Set the Hunter class color",
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
						name = "Mage",
						desc = "Set the Mage class color",
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
						name = "Monk",
						desc = "Set the Monk class color",
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
						name = "Paladin",
						desc = "Set the Paladin class color",
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
						name = "Priest",
						desc = "Set the Priest class color",
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
						name = "Rogue",
						desc = "Set the Rogue class color",
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
						name = "Shaman",
						desc = "Set the Shaman class color",
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
						name = "Warlock",
						desc = "Set the Warlock class color",
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
						name = "Warrior",
						desc = "Set the Warrior class color",
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
				name = "Import/Export",
				type = "group",
				order = 300,
				childGroups  = "tab",
				args = {
					spacer100 = {
						name = "\nExport",
						type = "description",
						fontSize = "large",
						order = 100,
						--width = "full",
					},
					exportMode = {
						name = "",
						desc = "What should be exported",
						order = 101,
						type = "select",
						values = {
								["ALL"] = "All Settings and Data",
								["CDDATA"] = "Cooldown Data Only",
								["SETTINGS"] = "CDTL3 Settings Only",
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
								local exportMode = CDTL3.db.profile.global["exportMode"]

								local table = {}

								if exportMode == "CDDATA" then
									table = CDTL3:TableCopy(CDTL3.db.profile.tables)
								else
									table = CDTL3:TableCopy(CDTL3.db.profile)

									if exportMode == "SETTINGS" then
										table.tables.spells = {}
										table.tables.petspells = {}
										table.tables.items = {}
										table.tables.buffs = {}
										table.tables.debuffs = {}
										table.tables.offensives = {}
										table.tables.runes = {}
										table.tables.customs = {}
										table.tables.detected = {}
									end
								end

								-- SERIALIZE
								local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")	
								local serialized = LibAceSerializer:Serialize(table)

								-- DEFLATE
								local LibDeflate = LibStub:GetLibrary("LibDeflate")
								local deflated = LibDeflate:CompressDeflate(serialized)
								local printable = LibDeflate:EncodeForPrint(deflated)

								return printable
							end,
						set = function(info, val)
								return nil
							end,
					},
					spacer300 = {
						name = "\nImport",
						type = "description",
						fontSize = "large",
						order = 300,
						--width = "full",
					},
					importMode = {
						name = "",
						desc = "What should be imported",
						order = 301,
						type = "select",
						values = {
								["ALL"] = "All Settings and Data",
								["CDDATA"] = "Cooldown Data Only",
								["SETTINGS"] = "CDTL3 Settings Only",
							},
						get = function(info, index)
								return CDTL3.db.profile.global["importMode"]
							end,
						set = function(info, val)
								CDTL3.db.profile.global["importMode"] = val
							end,
					},
					importbox = {
						name = "",
						type = "input",
						multiline = 10,
						order = 400,
						width = "full",
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
				name = "Changelog",
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
						name = "Issues & suggestions (GitHub; or comment on CurseForge)",
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

	return options
end

function CDTL3:GetFilterOptions()
	local options = {
		name = "Filters",
		type = "group",
		childGroups  = "tab",
		args = {
			defaults = {
				name = "Defaults",
				type = "group",
				order = 100,
				args = {
					spacer100 = {
						name = "\n\nSelect a type to edit its default settings\n",
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
									choices["SPELLS"] = "Spells"
									choices["ITEMS"] = "Items"
									choices["BUFFS"] = "Buffs"
									choices["DEBUFFS"] = "Debuffs"
									choices["OFFENSIVES"] = "Offensives"
									choices["PETSPELLS"] = "Pet Spells"
									choices["CUSTOMS"] = "Customs"

									--[[if CDTL3.db.profile.global["debugMode"] then
										choices["OTHER"] = "Other"
									end]]--
									
								if CDTL3.player["class"] == "DEATHKNIGHT" then
									choices["RUNES"] = "Runes"
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
						name = "Clear Settings",
						desc = function(info)
								return "This will clear this character's "..string.lower(CDTL3.currentFilter["default"]).." cooldown settings"
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
						name = "Clear Quest Items",
						desc = function(info)
								return "This will clear this character's saved settings of quest items"
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
									end
								end
								
								CDTL3.db.profile.tables["items"] = cleanTable
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
						name = "Enabled",
						desc = "If unselected cooldowns of this type will be ignored",
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
						name = "Player Only",
						desc = function(info)
								local default = string.lower(CDTL3.currentFilter["default"])
								return "If selected only "..default.." applied by the player will be tracked"
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
						name = "Show by Default",
						desc = "If unselected you will need to manually enable each newly detected cooldown in order for them to show as bars/icons",
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
						name = "Use Item Icon",
						desc = "If selected the displayed icon will be the item icon\nOtherwise the spell icon will be used instead",
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
						name = "Ignore Threshold",
						desc = "Any cooldown/duration longer than this will be disabled by default\n",
						order = 251,
						type = "range",
						softMin = 5,
						softMax = 1800,
						bigStep = 1,
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						get = function(info, index)
								local default = CDTL3.currentFilter["default"]
								return CDTL3.db.profile.global[string.lower(default)]["ignoreThreshold"]
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
						name = "Default Lane",
						desc = function(info)
								return "Set the default lane all new "..string.lower(CDTL3.currentFilter["default"]).." icons will use"
							end,
						order = 301,
						type = "select",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						values = { [0] = "Hide", [1] = "1", [2] = "2", [3] = "3" },
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
						name = "Set All",
						desc = function(info)
								return "This will override current settings, and set all of this character's "..string.lower(CDTL3.currentFilter["default"]).." cooldowns to the default value"
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
						name = "Default Bar",
						desc = function(info)
								return "Set the default bar frame all new "..string.lower(CDTL3.currentFilter["default"]).." will use"
							end,
						order = 311,
						type = "select",
						hidden = function(info)
								return CDTL3.currentFilterHidden["default"]
							end,
						width = "half",
						values = { [0] = "Hide", [1] = "1", [2] = "2", [3] = "3" },
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
						name = "Set All",
						desc = function(info)
								return "This will override current settings, and set all of this character's "..string.lower(CDTL3.currentFilter["default"]).." cooldowns to the default value"
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
						name = "Default Ready",
						desc = function(info)
								return "Set the default ready frame all new "..string.lower(CDTL3.currentFilter["default"]).." icons will use"
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
						values = { [0] = "Hide", [1] = "1", [2] = "2", [3] = "3" },
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
						name = "Set All",
						desc = function(info)
								return "This will override current settings, and set all of this character's "..string.lower(CDTL3.currentFilter["default"]).." cooldowns to the default value"
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
		name = "Lanes",
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
		name = "Ready",
		type = "group",
		childGroups  = "tab",
		args = {
			ready1 = private.GetReadySet(1),
			ready2 = private.GetReadySet(2),
			ready3 = private.GetReadySet(3),
		}
	}
	
	return options	
end

function CDTL3:GetBarFrameOptions()
	local options = {
		name = "Bar Frames",
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
				name = "General",
				type = "group",
				order = 100,
				args = {
					barFrameName = {
						name = "Frame Name",
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
						name = "Enabled",
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
						name = "Grow Direction",
						desc = "Select which direction new bars will grow in",
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
						name = "Transition bars",
						desc = "If enabled, bars will be hidden once its cooldown drops below the lane max time, and its icon has appeared",
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
						name = "Show Indicator",
						desc = "If enabled, the bar will have an indicator showing when it will transition",
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
						name = "Indicator Style",
						desc = "Select a style of indicator",
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
								["SHORTEN"] = "Shorten",
								["LINE"] = "Line",
								["REGION"] = "Region",
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
						name = "Indicator Texture",
						desc = "Selects the texture",
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
						name = "Indicator Color",
						desc = "Sets the texture color",
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
						name = "Indicator Line Width",
						desc = "Sets the width of the transition indicator line",
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
						name = "x Padding",
						desc = "Sets the x offset between growing bars",
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
						name = "y Padding",
						desc = "Sets the y offset between growing bars",
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
				name = "Appearance",
				type = "group",
				order = 200,
				args = {
					posX = {
						name = "x Position",
						desc = "Sets the x position of the frame",
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
						name = "y Position",
						desc = "Sets the y position of the frame",
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
						name = "Anchor Point",
						desc = "The x/y position is relative to this point of the screen",
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
						name = "Padding",
						desc = "Sets the amount of padding in the frame",
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
						name = "Background Texture",
						desc = "Sets the background texture",
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
						name = "Color",
						desc = "Sets the background texture color",
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
				name = "Bars",
				type = "group",
				order = 300,
				args = {
					width = {
						name = "Width",
						desc = "Sets the width of the bars",
						order = 101,
						type = "range",
						softMin = 1,
						softMax = 300,
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
						name = "Height",
						desc = "Sets the height of the bars",
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
						name = "Foreground Texture",
						desc = "Selects the texture",
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
						name = "Color",
						desc = "Sets the texture color",
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
						name = "Class Color",
						desc = "Set the texture color to your class color",
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
						name = "Background Texture",
						desc = "Sets the background texture",
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
						name = "Color",
						desc = "Sets the background texture color",
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
						name = "Class Color",
						desc = "Set the texture color to your class color",
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
						name = "Spell School Color",
						desc = "Color each bar by its spell's school (fire, frost, etc). Schools are learned from the combat log as you cast; set the colors under Colors.",
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
						name = "Dynamic Color",
						type = "header",
						order = 114.1,
					},
					dynamicEnabled = {
						name = "Enable Dynamic Color",
						desc = "As a cooldown approaches ready, the bar blends from the warning color into the ready color. Above the warning window the normal bar color applies.",
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
						name = "Warning Window (sec)",
						desc = "How many seconds before ready the color blend begins",
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
						name = "Warning Color",
						desc = "Bar color when the warning window begins",
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
						name = "Ready Color",
						desc = "Bar color the moment the cooldown is ready",
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
						name = "Bar Text",
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
						name = "Show icon",
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
						name = "Icon position",
						desc = "Which side of the bar should the icon appear",
						order = 302,
						type = "select",
						values = {
								["LEFT"] = "Left",
								["RIGHT"] = "Right",
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
	private.AddBorderArgs(options.args.bars.args, 400, function() return frame["bar"]["border"] end, function() CDTL3:RefreshAllBars() end)

	private.AddCopyArgs(options.args.general.args, "barFrames", i, "Bar Frame")

	return options
end

private.GetFilterSet = function(t, o)
	local options = {
		name = function(info)
				if t == "customs" then
					return "Custom"
				end

				return t:gsub("^%l", string.upper)
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
							return "\n\n|cffffd100Offensive debuffs are detected from the combat log, which this client doesn't give to addons, so nothing new will appear here.|r\n\nSelect something to edit its settings\n"
						end

						return "\n\nSelect something to edit its settings\n"
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
						return "*Custom cooldowns will appear here once saved*\n\n\n"
					end

					return "*Cooldowns will appear here once they have been detected at least once*\n\n\n"
					end,
				type = "description",
				order = 110,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			triggerType = {
				name = "Trigger Type",
				desc = "What will trigger the cooldown to begin, a spell or aura?",
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
						choices["spell"] = "Spell"
						choices["aura"] = "Aura"
							
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
				name = "Trigger ID",
				desc = "Entering a valid Spell/Aura ID here will populate the other fields",
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

							if spellName then
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
						local n = "Item:   "
						
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
							n = "Spell:   "
						elseif t == "buffs" or t == "debuffs" or t == "offensives" then
							n = "Aura:   "
						elseif t == "runes" then
							n = "Rune:   "
						elseif t == "customs" then
							n = "Name:   "
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
										n = "Enter valid trigger ID"
									else
										n = "New Custom"
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
							n = "Cooldown:"
						elseif t == "buffs" or t == "debuffs" or t == "offensives" then
							n = "Duration:"
						elseif t == "runes" then
							n = "Recharge:"
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
								n =	n.."  "..(s["bCD"] / 1000).." sec\n"
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
				desc = "Set the default cooldown value.",
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
				desc = "Set the value of the custom CD",
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
				name = "Custom CD Time",
				desc = "Allows you to set a custom time for the cooldown.  This can be used for if a talent changes a cooldown time and the mod cannot detect it.",
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
							return "Clear"
						end

						return "Clear Individual Settings"
					end,
				desc = function(info)
						if t == "customs" then
							return "Clear unsaved custom settings"
						end

						local s = ""
						
						if CDTL3.currentFilter[t] then
							s = CDTL3.currentFilter[t]
						end
				
						return "This will clear cooldown settings for "..s
					end,
				confirm = true,
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
							local s = ""
							
							if CDTL3.currentFilter[t] then
								s = CDTL3.currentFilter[t]
							end
							
							-- items are selected by item name in this tab
							local index = nil
							for k, spell in pairs(CDTL3.db.profile.tables[t]) do
								local n = (t == "items") and spell["itemName"] or spell["name"]
								if n == s then
									index = k
								end
							end
							
							if index then
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
				name = "Save Custom",
				desc = function(info)
						return "Save current details as a custom cooldown"
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

							CDTL3:Print("CUSTOM: "..name.." saved")
						else
							CDTL3:Print("CUSTOM: "..tostring(s["name"]).." already saved")
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
				name = "Enabled",
				desc = "Untick this to never show this as an icon/bar",
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
							if CDTL3.custom["enabled"] then
								return CDTL3.custom["enabled"]
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
				name = "Highlight",
				desc = "Tick to apply highlighting to the icon",
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
				name = "Pinned",
				desc = "Tick to keep an icon in the ready frame until the cooldown is used again",
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
				name = "Ignored",
				desc = "Manually choose if something should be ignored or not.\nThis can be used in tandem with setting custom cooldown times to force misbehaving cooldowns to show correctly",
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
						end
					end,
			},
			spacer600 = {
				name = "\n\nSelect the frame the icon/bar will be shown\nIf the selected frame is not enabled, the icon/bar will not appear\n\n",
				type = "description",
				order = 600,
				hidden = function(info)
						return CDTL3.currentFilterHidden[t]
					end,
			},
			lane = {
				name = "Lane",
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
				values = { [0] = "Hide", [1] = "1", [2] = "2", [3] = "3" },
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
				name = "Bar Frame",
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
				values = { [0] = "Hide", [1] = "1", [2] = "2", [3] = "3" },
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
				name = "Ready Frame",
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
				values = { [0] = "Hide", [1] = "1", [2] = "2", [3] = "3" },
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

	return options
end

private.GetCustomSet = function(t, o)

	local options = {
		name = "Custom",
		type = "group",
		order = o,
		childGroups  = "tab",
		args = {
			saved = private.GetFilterSet(t, 100),
			detected = {
				name = "Detected",
				type = "group",
				order = 200,
				args = {
					spacer100 = {
						name = function(info, index)
								local s = " \n\n"

								s = s.."When detection is enabled, spell data will be kept for all spells cast by the player.\n"
								s = s.."This will include many instances of spells cast by game systems that can mostly be ignored.\n"
								s = s.."To save a spell as a custom trigger, just select the spell from the list and then hit the 'Save As Custom' button.\n"
								s = s.." \n"

								return s
							end,
						type = "description",
						order = 100,
						width = "full"
					},
					customDetection = {
						name = "Enable Detection",
						desc = "Detect and record 'miscellaneous' spells",
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
						name = "Clear Detected",
						desc = function(info)
								return "This will clear all detected 'miscellaneous' spells"
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
						name = " \n\nSelect a detected spell to create a custom cooldown\n",
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
								return "*Miscellaneous spells that have been detected will appear here*\n\n\n"
							end,
						type = "description",
						order = 202,
					},
					cdType = {
						name = function(info)
								local n = " "
								
								if t == "spells" or t == "items" or t == "petspells" then
									n = "Spell:   "
								elseif t == "buffs" or t == "debuffs" or t == "offensives" then
									n = "Aura:   "
								elseif t == "runes" then
									n = "Rune:   "
								elseif t == "customs" or t == "detected" then
									n = "Name:   "
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
									n = "Select a detected spell"
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
						name = "Save As Custom",
						desc = function(info)
								return "This will save the detected spell as custom cooldown"
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
				name = "General",
				type = "group",
				order = 100,
				args = {
					name = {
						name = "Frame Name",
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
						name = "Enabled",
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
						name = "Reversed",
						desc = "Selecting this will reverse icon travel direction from right-to-left, to left-to-right",
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
						name = "Vertical",
						desc = "The frame will be vertical instead of horizontal",
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
						name = "Mode",
						desc = "How icons will progress along the lane",
						order = 201,
						type = "select",
						values = {
								["LINEAR"] = "Linear (%)",
								["LINEAR_ABS"] = "Linear (Time)",
								["SPLIT"] = "Split (%)",
								["SPLIT_ABS"] = "Split (Time)",
							},
						get = function(info, index)
								return lane["mode"]["type"]
							end,
						set = function(info, val)
								lane["mode"]["type"] = val
								CDTL3:RefreshLane(i)
							end,
					},
					timeFormat = {
						name = "Time Format",
						desc = "Select the format to display times",
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
						name = "Max Time",
						desc = "How many seconds the lane represents",
						order = 301,
						type = "range",
						softMin = 10,
						softMax = 180,
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
								
								return mt
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
						name = "Hide Long Timers",
						desc = "Should icons with remaining cooldowns longer than the max time be hidden",
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
						name = "Split Count",
						desc = "How many % splits appear on the lane",
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
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["split"]["count"]
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
						name = "Split 1 Position",
						desc = "What position should split 1 appear",
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
						name = "Split 1 Value",
						desc = "What percentage should split 1 occur",
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
								if lane["mode"]["split"]["count"] >= 2 then
									return false
								end
							end
							return true
						end,
					},
					sSplit2Position = {
						name = "Split 2 Position",
						desc = "What position should split 2 appear",
						order = 421,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if lane["mode"]["split"]["count"] >= 2 then
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
						name = "Split 2 Value",
						desc = "What percentage should split 2 occur",
						order = 422,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if lane["mode"]["split"]["count"] >= 2 then
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
								if lane["mode"]["split"]["count"] >= 2 then
									return false
								end
							end
							return true
						end,
					},
					sSplit3Position = {
						name = "Split 3 Position",
						desc = "What position should split 3 appear",
						order = 431,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if lane["mode"]["split"]["count"] >= 3 then
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
						name = "Split 3 Value",
						desc = "What percentage should split 3 occur",
						order = 432,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT" then
								if lane["mode"]["split"]["count"] >= 3 then
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
						name = "Split Count",
						desc = "How many % splits appear on the lane",
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
						bigStep = 1,
						get = function(info, index)
								return lane["mode"]["splitAbs"]["count"]
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
						name = "Split 1 Position",
						desc = "What position should splitAbs 1 appear",
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
						name = "Split 1 Value",
						desc = "What percentage should splitAbs 1 occur",
						order = 512,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								return false
							end
							return true
						end,
						min = 1,
						max = 360,
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
								if lane["mode"]["splitAbs"]["count"] >= 2 then
									return false
								end
							end
							return true
						end,
					},
					saSplit2Position = {
						name = "Split 2 Position",
						desc = "What position should splitAbs 2 appear",
						order = 521,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if lane["mode"]["splitAbs"]["count"] >= 2 then
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
						name = "Split 2 Value",
						desc = "What percentage should splitAbs 2 occur",
						order = 522,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if lane["mode"]["splitAbs"]["count"] >= 2 then
									return false
								end
							end
							return true
						end,
						min = 1,
						max = 360,
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
								if lane["mode"]["splitAbs"]["count"] >= 2 then
									return false
								end
							end
							return true
						end,
					},
					saSplit3Position = {
						name = "Split 3 Position",
						desc = "What position should splitAbs 3 appear",
						order = 531,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if lane["mode"]["splitAbs"]["count"] >= 3 then
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
						name = "Split 3 Value",
						desc = "What percentage should splitAbs 3 occur",
						order = 532,
						type = "range",
						hidden = function(info)
							if lane["mode"]["type"] == "SPLIT_ABS" then
								if lane["mode"]["splitAbs"]["count"] >= 3 then
									return false
								end
							end
							return true
						end,
						max = 360,
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
						name = "Override Autohide",
						desc = function(info, index)
								local desc = "This will override autohiding, and show the lane in the following circumstances:\n\n"
									desc = desc.."Player Health: while health is below max\n"
									desc = desc.."Class Power: while class power is below max (or above 0 in the case of rage)\n"
									desc = desc.."Energy Tick: while in stealth\n"
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
					spacer602 = {
						name = "\n",
						type = "description",
						order = 602,
					},
					primaryTracking = {
						name = "Primary Tracking",
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
						name = "Reverse",
						desc = "Reverse the direction of the primary tracking indicator",
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
						name = "Secondary Tracking",
						desc = "",
						order = 611,
						type = "select",
						values = private.TrackingValues,
						get = function(info, index)
								return lane["tracking"]["secondaryTracking"]
							end,
						set = function(info, val)
								lane["tracking"]["secondaryTracking"] = val
							end,
					},
					secondaryReversed = {
						name = "Reverse",
						desc = "Reverse the direction of the secondary tracking indicator",
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
						name = "ST Width",
						desc = "Set the width of the secondary tracker",
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
						name = "ST Height",
						desc = "Set the height of the secondary tracker",
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
						name = "ST Texture",
						desc = "Selects the ST texture",
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
						name = "ST Color",
						desc = "Sets the ST texture color",
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
				name = "Appearance",
				type = "group",
				order = 200,
				args = {
					width = {
						name = "Width",
						desc = "Sets the width for the lane",
						order = 201,
						type = "range",
						softMin = 1,
						softMax = 600,
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
						name = "Height",
						desc = "Sets the height for the lane",
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
						name = "x Position",
						desc = "Sets the x position of the lane",
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
						name = "y Position",
						desc = "Sets the y position of the lane",
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
						name = "Anchor Point",
						desc = "The x/y position is relative to this point of the screen",
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
						name = "Foreground Texture",
						desc = "Selects the texture",
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
						name = "Color",
						desc = "Sets the texture color",
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
						name = "Class Color",
						desc = "Set the texture color to your class color",
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
						name = "Background Texture",
						desc = "Sets the background texture",
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
						name = "Color",
						desc = "Sets the background texture color",
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
						name = "Class Color",
						desc = "Set the texture color to your class color",
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
						name = "Lane Alpha",
						desc = "Set the alpha for the lane (this will reset custom text alpha settings, but they can be adjusted again after setting this)",
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
				name = "Icons",
				type = "group",
				order = 300,
				args = {
					size = {
						name = "Size",
						desc = "Sets the size of icons in lane "..i,
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
						name = "Icon Transparency",
						desc = "Set the alpha for the icon (text alpha is set in text settings)",
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
						name = "Icon Offset",
						desc = "Offsets icons position on the lane from the center line",
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
						name = "Icon Text",
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
						name = "Highlight Style",
						desc = "How to highlight icons",
						order = 401,
						type = "select",
						values = {
								["BORDER"] = "Border",
								["BORDER_FLASH"] = "Border Flash",
								["FLASH"] = "Flash Icon",
								["GLOW"] = "Glow",
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
						name = "                    Border Texture",
						desc = "Selects the border texture",
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
						name = "Color",
						desc = "Selects the border color",
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
						name = "Size",
						desc = "Sets the size of the border",
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
						name = "Padding",
						desc = "Sets the space between the border and the frame",
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
				name = "Stacking",
				type = "group",
				order = 400,
				args = {
					enabled = {
						name = "Enabled",
						desc = "Enable icon stacking",
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
						name = "Raise On Mouseover",
						desc = "Mousing over an icon will raise it to the top of its stack and make it easier to see",
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
						name = "Stack Style",
						desc = "Select which direction new icons will grow in",
						order = 201,
						type = "select",
						values = {
								["GROUPED"] = "Grouped",
								["OFFSET"] = "Offset",
							},
						get = function(info, index)
								return lane["stacking"]["style"]
							end,
						set = function(info, val)
								lane["stacking"]["style"] = val
							end,
					},
					grow = {
						name = "Grow Direction",
						desc = "What direction should icon stacks grow",
						order = 202,
						type = "select",
						values = {
								["UP"] = "Up",
								["DOWN"] = "Down",
								["CENTER"] = "Center",
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
						name = "Height",
						desc = "Sets the max height of the stack",
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
				name = "Text",
				type = "group",
				order = 500,
				args = {
					defaultHeader = {
						name = "Default Text",
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
						name = "Custom Text",
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
	private.AddBorderArgs(options.args.icons.args, 300, function() return lane["icons"]["border"] end, function() CDTL3:RefreshAllIcons() end)

	private.AddCopyArgs(options.args.general.args, "lanes", i, "Lane")

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
				name = "General",
				type = "group",
				order = 100,
				args = {
					name = {
						name = "Frame Name",
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
						name = "Enabled",
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
						name = "Grow Direction",
						desc = "Select which direction new icons will grow in",
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
						name = "Normal Duration",
						desc = "How long an icon should stay in the ready frame",
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
						name = "Normal Sound",
						desc = "Select which sound to play when an icon enters the frame",
						order = 302,
						type = "select",
						dialogControl = 'LSM30_Sound',
						values = AceGUIWidgetLSMlists.sound,
						get = function(info, index)
								return ready["nSound"]
							end,
						set = function(info, val)
								ready["nSound"] = val
							end,
					},
					spacer400 = {
						name = "",
						type = "description",
						order = 400,
					},
					hTime = {
						name = "Highlight Duration",
						desc = "How long a highlighted icon should stay in the ready frame",
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
						name = "Highlight Sound",
						desc = "Select which sound to play when a highlighted icon enters the frame",
						order = 402,
						type = "select",
						dialogControl = 'LSM30_Sound',
						values = AceGUIWidgetLSMlists.sound,
						get = function(info, index)
								return ready["hSound"]
							end,
						set = function(info, val)
								ready["hSound"] = val
							end,
					},
					spacer500 = {
						name = "\n\n",
						type = "description",
						order = 500,
					},
					pTime = {
						name = "Pinned Hide Time",
						desc = "How long the ready frame will stay visible after combat ends",
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
						name = "x Padding",
						desc = "Sets the x offset between growing icons",
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
						name = "y Padding",
						desc = "Sets the y offset between growing icons",
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
				name = "Appearance",
				type = "group",
				order = 200,
				args = {
					posX = {
						name = "x Position",
						desc = "Sets the x position of the frame",
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
						name = "y Position",
						desc = "Sets the y position of the frame",
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
						name = "Anchor Point",
						desc = "The x/y position is relative to this point of the screen",
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
						name = "Padding",
						desc = "Sets the amount of padding in the frame",
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
						name = "Background Texture",
						desc = "Sets the background texture",
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
						name = "Color",
						desc = "Sets the background texture color",
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
				name = "Icons",
				type = "group",
				order = 300,
				args = {
					size = {
						name = "Size",
						desc = "Sets the size of the frame, and icons in the ready frame",
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
						name = "Icon Transparency",
						desc = "Set the alpha for the icon (text alpha is set in text settings)",
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
						name = "Icon Text",
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
						name = "Highlight Style",
						desc = "How to highlight icons",
						order = 401,
						type = "select",
						values = {
								["BORDER"] = "Border",
								["BORDER_FLASH"] = "Border Flash",
								["FLASH"] = "Flash Icon",
								["GLOW"] = "Glow",
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
	private.AddBorderArgs(options.args.icons.args, 300, function() return ready["icons"]["border"] end, function() CDTL3:RefreshAllIcons() end)

	private.AddCopyArgs(options.args.general.args, "ready", i, "Ready Frame")

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
		name = "Enabled",
		desc = "Show this text",
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
		name = "Edit",
		desc = "Edit this text",
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
		name = "Font",
		desc = "Selects the font for text on the bars",
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
		name = "Outline",
		desc = "Sets the text outline",
		order = o + 4.2,
		hidden = function(info)
				return not s["edit"]
			end,
		type = "select",
		values = {
				["NONE"] = "None",
				["OUTLINE"] = "Outline",
				["THICKOUTLINE"] = "Thick Outline",
				["MONOCHROME"] = "Monochrome"
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
		name = "Font Size",
		desc = "Sets the size of the font",
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
		name = "Color",
		desc = "Selects the font color",
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
		name = "Shadow Color",
		desc = "Selects the shadow color",
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
		name = "Shadow x Offset",
		desc = "Sets the text shadow x offset",
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
		name = "Shadow y Offset",
		desc = "Sets the text shadow y offset",
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
		name = "Anchor",
		desc = "Sets the text anchor point",
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
		name = "Align",
		desc = "Sets the text alignment",
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
		name = "x Offset",
		desc = "Sets text x offset",
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
		name = "y Offset",
		desc = "Sets text y offset",
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
		options.args.profiles = CDTL3.profile
	end

	return options
end
