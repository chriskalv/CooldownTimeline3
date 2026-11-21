--[[
	Cooldown Timeline 3 - Profiles tab extras: entries shared by all characters, the profile a new
	character starts on, and profiles by zone. Every one is off until the player turns it on.

	SHARED ENTRIES (db.global.shareEntries, off by default)
	"Share my Custom timers and spell settings with all my characters" keeps one account-wide set of
	Filters lists (db.global.sharedEntries.lists: spells, items, auras, Customs, with their settings
	and their characters) that every profile uses while it is on: they are the lists.
	  - One entry per name, as every lookup finds them (P.EntryKey): spell ranks are one entry.
	    Per-character marks (usedBy, pickedBy: every field ending in "By") are combined on every
	    merge, never dropped or overwritten.
	  - switching it on copies this profile's entries into the shared lists (this profile's settings
	    win where both hold an entry); another profile joins the first time it is used with sharing
	    on and adds only the entries the shared lists don't have (the shared settings win, and an
	    entry deleted while sharing stays deleted: sharedEntries.deleted).
	  - an import (All, Cooldown Data Only, into a new profile) writes the lists it carries into the
	    shared ones (P.ImportLists, from Helpers.lua's ApplyShare): its entry wins for each name it
	    has, the others stay. Copy From and Reset Profile change the profile's settings only.
	  - switching it off gives this profile exactly the shared lists; each other profile that took
	    part gets them the next time it is used.
	While sharing is on, profile.tables points at the shared lists (all code keeps reading
	CDTL3.db.profile.tables) and is pointed back at the profile's own lists before AceDB shuts the
	profile or the database down (OnProfileShutdown, OnDatabaseShutdown), so the saved file never
	holds the shared lists twice. RefreshConfig (wrapped below) points it again after a profile
	switch, Copy From, Reset Profile or an import.

	NEW CHARACTERS (db.global.newCharacterProfile: nil = the Default profile, as before; LAST; CHOSEN)
	A character with no profile yet is put on the last profile used (db.global.lastProfile: kept at
	login and on every switch, but never a zone profile) or on the chosen profile, just before AceDB
	picks one (OnInitialize, wrapped below). It uses that profile, as it used Default before.

	PROFILES BY ZONE (per character: db.char.zoneProfiles raid / dungeon / pvp / world; none set)
	At each loading screen the zone's profile is switched to. A zone's profile wins over spec profiles
	(LibDualSpec) while there: LibDualSpec's check asks GetDualSpecProfile(), which answers with the
	zone's profile first. Where a zone says None, spec profiles work as before, or else the profile in
	use before the first zone switch comes back. A profile picked by hand inside a zone stays.
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
local P = {}
CDTL3.Profiles = P

P.NONE = "<none>"

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

-- a list's entries in a steady order: numbered ones first, in order
local function Ordered(list)
	local nums, others = {}, {}
	for k in pairs(list) do
		if type(k) == "number" then
			table.insert(nums, k)
		else
			table.insert(others, tostring(k))
		end
	end
	table.sort(nums)
	table.sort(others)

	local out = {}
	for _, k in ipairs(nums) do
		table.insert(out, list[k])
	end
	for _, k in ipairs(others) do
		table.insert(out, list[k])
	end

	return out
end

------------------------------------------------------------------------ SHARED ENTRIES

-- What makes two saved entries the same one, as every lookup finds them: Customs by name and
-- trigger (GetCustomSpellSettings), items by item name, everything else by name (GetSpellSettings),
-- so the ranks of one spell (Era, TBC, Forever) are one entry
P.EntryKey = function(list, e)
	if list == "customs" then
		if e["name"] ~= nil then
			return "c:"..tostring(e["name"]).."|"..tostring(e["triggerType"])
		end
	elseif list == "items" and e["itemName"] ~= nil then
		return "i:"..tostring(e["itemName"])
	end

	if e["name"] ~= nil then
		return "n:"..tostring(e["name"])
	elseif e["id"] ~= nil then
		return "s:"..tostring(e["id"])
	end
end

-- a per-character mark: a list of the characters it holds (usedBy, pickedBy)
local function IsMark(k)
	return type(k) == "string" and k:sub(-2) == "By"
end

-- every character on either list, each once, in order
local function Owners(a, b)
	local out, seen = {}, {}
	for i = 1, 2 do
		local list = (i == 1) and a or b
		if type(list) == "table" then
			for _, guid in ipairs(list) do
				if not seen[guid] then
					seen[guid] = true
					table.insert(out, guid)
				end
			end
		end
	end

	return out
end

-- Copy source's entries into target, list by list, never removing an entry. An entry target
-- lacks is added (a copy), unless skip[list][key] (deleted while sharing). One both hold gets
-- the marks of both and, when sourceWins, source's settings in place of its own; otherwise
-- target's settings stay. Returns the number of entries added.
P.Merge = function(target, source, sourceWins, skip)
	if type(target) ~= "table" or type(source) ~= "table" or target == source then
		return 0
	end

	local added = 0
	for list, entries in pairs(source) do
		if type(entries) == "table" then
			local into = target[list]
			if type(into) ~= "table" then
				into = {}
				target[list] = into
			end

			if into ~= entries then
				local index = {}
				for _, e in pairs(into) do
					if type(e) == "table" then
						local key = P.EntryKey(list, e)
						if key then
							index[key] = e
						end
					end
				end

				for _, e in ipairs(Ordered(entries)) do
					if type(e) == "table" then
						local key = P.EntryKey(list, e)
						local have = key and index[key]
						if not have then
							if not (key and type(skip) == "table" and type(skip[list]) == "table" and skip[list][key]) then
								local copy = DeepCopy(e)
								table.insert(into, copy)
								if key then
									index[key] = copy
								end
								added = added + 1
							end
						elseif have ~= e then
							local marks = {}
							for _, side in ipairs({ have, e }) do
								for k, v in pairs(side) do
									if IsMark(k) and type(v) == "table" then
										marks[k] = Owners(have[k], e[k])
									end
								end
							end
							if sourceWins then
								for k in pairs(have) do
									if e[k] == nil then
										have[k] = nil
									end
								end
								for k, v in pairs(e) do
									have[k] = DeepCopy(v)
								end
							end
							for k, v in pairs(marks) do
								have[k] = v
							end
						end
					end
				end
			end
		end
	end

	return added
end

-- A profile's own lists never share a table with the shared lists (an import can leave one there):
-- the saved file would hold it twice
P.Unalias = function(own, lists)
	for list, entries in pairs(own) do
		if type(entries) == "table" and lists[list] == entries then
			own[list] = DeepCopy(entries)
		end
	end
end

P.Sharing = function()
	return CDTL3.db ~= nil and CDTL3.db.global["shareEntries"] == true
end

function CDTL3:SharingEntries()
	return P.Sharing()
end

-- The account-wide store (created only when sharing is switched on)
P.Store = function(create)
	local g = CDTL3.db.global
	local store = g["sharedEntries"]
	if type(store) ~= "table" then
		if not create then
			return nil
		end
		store = {}
		g["sharedEntries"] = store
	end
	if type(store["lists"]) ~= "table" then
		store["lists"] = {}
	end
	if type(store["joined"]) ~= "table" then
		store["joined"] = {}
	end
	if type(store["deleted"]) ~= "table" then
		store["deleted"] = {}
	end

	return store
end

-- Sharing off: a profile that took part gets exactly the shared lists (copies), so what was
-- deleted while sharing stays deleted
P.TakeShared = function(own, lists)
	for list, entries in pairs(lists) do
		own[list] = DeepCopy(entries)
	end
end

-- The shared lists are in use (attached to the profile in use)
local function Attached()
	local a, store = P.attached, P.Sharing() and P.Store(false)
	return store and a and a.lists == store["lists"] and a.profile == CDTL3.db:GetCurrentProfile() and a or nil
end

-- An import while sharing (Helpers.lua ApplyShare): before = profile.tables before the import,
-- lists = the Filters lists the string carries. Each joins the shared one, the string's entry
-- winning for every name it has (marks combined); the others stay; an empty list changes nothing.
-- profile.tables points at the shared lists again. False when not sharing (the import goes on
-- as before).
P.ImportLists = function(before, lists)
	local a = Attached()
	if not a or before ~= a.lists then
		return false
	end

	P.Merge(a.lists, lists, true)
	rawset(CDTL3.db.profile, "tables", a.lists)
	return true
end

-- An entry deleted while sharing (Filters: Delete, Clear Settings, Clear Quest Items) stays out
-- of the shared lists: a profile joining later doesn't bring it back
P.Forget = function(list, e)
	local a = Attached()
	local key = a and type(e) == "table" and P.EntryKey(list, e)
	if not key then
		return
	end

	local deleted = P.Store(false)["deleted"]
	if type(deleted[list]) ~= "table" then
		deleted[list] = {}
	end
	deleted[list][key] = true
end

function CDTL3:ForgetSharedEntry(list, e)
	P.Forget(list, e)
end

-- every list the profile defaults name (spells ... flights) exists in the shared lists
P.EnsureLists = function(lists)
	local d = CDTL3.db.defaults and CDTL3.db.defaults.profile and CDTL3.db.defaults.profile.tables
	for list in pairs(d or {}) do
		if type(lists[list]) ~= "table" then
			lists[list] = {}
		end
	end
end

-- { own = the profile's own lists, profile = its name, lists = the shared lists } while attached
P.attached = nil

-- Sharing on: point profile.tables at the shared lists. Sharing off: give a profile that took part
-- the shared lists. Runs at login and at the top of every RefreshConfig.
P.Attach = function()
	local db = CDTL3.db
	if not db then
		return
	end

	local profile = db.profile
	local name = db:GetCurrentProfile()
	local cur = rawget(profile, "tables")

	if not P.Sharing() then
		P.Detach()
		local store = P.Store(false)
		if store and store["joined"][name] then
			if type(cur) ~= "table" then
				cur = {}
				rawset(profile, "tables", cur)
			end
			P.TakeShared(cur, store["lists"])
			store["joined"][name] = nil
		end
		return
	end

	-- Store(true) always returns a table
	local store = P.Store(true) --[[@as table]]
	local lists = store["lists"]
	P.EnsureLists(lists)
	if cur == lists then
		return
	end
	if type(cur) ~= "table" then
		cur = {}
	end

	local a = P.attached
	if a and a.profile == name and a.lists == lists then
		-- this profile's lists were replaced while shared (Copy From, Reset Profile): they change
		-- its settings only; the shared lists and the profile's own stay as they were
		cur = a.own
	elseif not store["joined"][name] then
		-- the first use of this profile since sharing began: the entries the shared lists don't
		-- have join (not ones deleted while sharing); the others keep the shared settings
		P.Merge(lists, cur, false, store["deleted"])
	end
	store["joined"][name] = true

	P.Unalias(cur, lists)
	P.attached = { own = cur, profile = name, lists = lists }
	rawset(profile, "tables", lists)
end

-- Point profile.tables back at the profile's own lists (before a switch and before saving)
P.Detach = function()
	local a = P.attached
	P.attached = nil
	if not a then
		return
	end

	local profile = CDTL3.db and rawget(CDTL3.db, "profile")
	if profile and rawget(profile, "tables") == a.lists then
		rawset(profile, "tables", a.own)
	end
end

-- The option: switch sharing on or off
P.SetSharing = function(on)
	local db = CDTL3.db
	if on == P.Sharing() then
		return
	end

	local name = db:GetCurrentProfile()
	if on then
		-- Store(true) always returns a table
		local store = P.Store(true) --[[@as table]]
		local own = rawget(db.profile, "tables")
		if type(own) ~= "table" then
			own = {}
			rawset(db.profile, "tables", own)
		end
		P.EnsureLists(store["lists"])
		P.Merge(store["lists"], own, true)
		store["joined"][name] = true
		db.global["shareEntries"] = true
		CDTL3:RefreshConfig()
		CDTL3:Print(L["Your Custom timers and spell settings are now shared by all your characters: every profile uses the same Filters lists until you switch sharing off."])
	else
		P.Detach()
		db.global["shareEntries"] = false
		local store = P.Store(false)
		if store then
			local own = rawget(db.profile, "tables")
			if type(own) ~= "table" then
				own = {}
				rawset(db.profile, "tables", own)
			end
			P.TakeShared(own, store["lists"])
			store["joined"][name] = nil
		end
		CDTL3:RefreshConfig()
		CDTL3:Print(L["Sharing is off: this profile now has its own copy of your shared Custom timers and spell settings. Your other profiles get theirs the next time they are used."])
	end
end

------------------------------------------------------------------------ NEW CHARACTERS

-- Before AceDB picks this character's profile: a character with none yet starts on the last
-- profile used, or the chosen one, when that profile exists (otherwise Default, as before)
P.StartNewCharacter = function()
	local sv = _G["CDTL3DB"]
	if type(sv) ~= "table" or type(sv.global) ~= "table" then
		return
	end

	local g = sv.global
	local mode = g["newCharacterProfile"]
	if mode ~= "LAST" and mode ~= "CHOSEN" then
		return
	end

	local ok, charKey = pcall(function() return UnitName("player").." - "..GetRealmName() end)
	if not ok or type(charKey) ~= "string" then
		return
	end
	if type(sv.profileKeys) == "table" and sv.profileKeys[charKey] ~= nil then
		return
	end

	local name = (mode == "LAST") and g["lastProfile"] or g["newCharacterProfileName"]
	if type(name) == "string" and type(sv.profiles) == "table" and sv.profiles[name] ~= nil then
		sv.profileKeys = type(sv.profileKeys) == "table" and sv.profileKeys or {}
		sv.profileKeys[charKey] = name
		P.startedOn = name
	end
end

-- The profile in use, as "the last profile used" for new characters: never a zone profile
P.RememberProfile = function()
	local db = CDTL3.db
	local name = db and db:GetCurrentProfile()
	if not name or P.switching then
		return
	end

	local c = db.char
	if (c["zoneActive"] and c["zoneActive"] == name) or name == P.ZoneProfile() then
		return
	end

	db.global["lastProfile"] = name
end

------------------------------------------------------------------------ PROFILES BY ZONE

P.ZONES = {
	{ key = "raid", name = "Raids", desc = function() return "The profile to use in raids" end },
	{ key = "dungeon", name = "Dungeons", desc = function()
			if C_ChallengeMode then
				return "The profile to use in dungeons (Mythic+ included), delves and scenarios"
			end
			return "The profile to use in dungeons and scenarios"
		end },
	{ key = "pvp", name = "PvP", desc = function() return "The profile to use in battlegrounds and arenas" end },
	{ key = "world", name = "Open world", desc = function() return "The profile to use outside dungeons, raids and PvP" end },
}

P.ZoneKind = function()
	local ok, _, kind = pcall(IsInInstance)
	if not ok then
		return "world"
	end

	if kind == "raid" then
		return "raid"
	elseif kind == "party" or kind == "scenario" then
		return "dungeon"
	elseif kind == "pvp" or kind == "arena" then
		return "pvp"
	end

	return "world"
end

P.ZoneSettings = function(create)
	local c = CDTL3.db.char
	local z = c["zoneProfiles"]
	if type(z) ~= "table" then
		if not create then
			return nil
		end
		z = {}
		c["zoneProfiles"] = z
	end

	return z
end

P.ProfileExists = function(name)
	local db = CDTL3.db
	return type(name) == "string" and (name == db:GetCurrentProfile()
		or (type(db.sv.profiles) == "table" and db.sv.profiles[name] ~= nil))
end

-- The profile the zone you're in switches to, or nil (None, or a profile that's gone)
P.ZoneProfile = function()
	if not CDTL3.db then
		return nil
	end

	local z = P.ZoneSettings(false)
	local name = z and z[P.ZoneKind()]
	if name and P.ProfileExists(name) then
		return name
	end
end

-- The spec profile when spec profiles are on (no zone profile applies when this is asked)
P.SpecProfile = function()
	local db = CDTL3.db
	-- LibDualSpec adds these methods to the database, so the definitions don't list them
	---@diagnostic disable-next-line: undefined-field
	if type(db.IsDualSpecEnabled) ~= "function" or type(db.GetDualSpecProfile) ~= "function" then
		return nil
	end

	---@diagnostic disable-next-line: undefined-field
	local ok, on = pcall(db.IsDualSpecEnabled, db)
	if ok and on then
		---@diagnostic disable-next-line: undefined-field
		local ok2, name = pcall(db.GetDualSpecProfile, db)
		if ok2 then
			return name
		end
	end
end

P.Switch = function(name)
	P.switching = true
	local ok, err = pcall(CDTL3.db.SetProfile, CDTL3.db, name)
	P.switching = false
	if not ok then
		geterrorhandler()(err)
	end
end

-- Switch to the zone's profile, or back once a zone that switched leaves
P.ApplyZone = function()
	local db = CDTL3.db
	if not db then
		return
	end

	local c = db.char
	local cur = db:GetCurrentProfile()
	local want = P.ZoneProfile()

	if want then
		if not c["zoneActive"] then
			c["zoneReturn"] = cur
		end
		c["zoneActive"] = want
		if cur ~= want then
			P.Switch(want)
		end
	elseif c["zoneActive"] then
		local active = c["zoneActive"]
		local back = P.SpecProfile() or c["zoneReturn"]
		c["zoneActive"], c["zoneReturn"] = nil, nil
		-- a profile picked by hand while there stays
		if cur == active and back and back ~= cur and P.ProfileExists(back) then
			P.Switch(back)
		end
	end
end

P.events = CreateFrame("Frame")
P.events:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent(event)
	end
	P.ZoneChanged()
end)

-- a profile switch rebuilds every frame, so one due in combat waits for its end
P.ZoneChanged = function()
	if InCombatLockdown() then
		P.events:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end

	P.ApplyZone()
end

-- LibDualSpec's spec check asks GetDualSpecProfile() with no spec: a zone profile answers first.
-- Asked for a given spec (the Profiles tab's spec dropdowns), it answers as before.
P.HookSpecProfiles = function()
	local db = CDTL3.db
	local get = db and rawget(db, "GetDualSpecProfile")
	if type(get) ~= "function" or get == P.specHook then
		return
	end

	P.specHook = function(self, spec)
		if spec == nil then
			local zone = P.ZoneProfile()
			if zone then
				return zone
			end
		end
		return get(self, spec)
	end
	rawset(db, "GetDualSpecProfile", P.specHook)
end

P.ProfileDeleted = function(name)
	local db = CDTL3.db
	local store = P.Store(false)
	if store then
		store["joined"][name] = nil
	end
	if db.global["newCharacterProfileName"] == name then
		db.global["newCharacterProfileName"] = nil
	end
	if db.global["lastProfile"] == name then
		db.global["lastProfile"] = nil
	end
	local z = P.ZoneSettings(false)
	if z then
		for k, v in pairs(z) do
			if v == name then
				z[k] = nil
			end
		end
	end
end

------------------------------------------------------------------------ OPTIONS (Profiles tab)

P.ProfileList = function(withNone)
	local list = {}
	if withNone then
		list[P.NONE] = "None"
	end
	for _, name in ipairs((CDTL3.db:GetProfiles())) do
		list[name] = name
	end

	return list
end

P.ProfileSorting = function(withNone)
	local names = {}
	for _, name in ipairs((CDTL3.db:GetProfiles())) do
		table.insert(names, name)
	end
	table.sort(names)
	if withNone then
		table.insert(names, 1, P.NONE)
	end

	return names
end

P.Options = function()
	local args = {
		sharedHeader = {
			name = L["Shared by all your characters"],
			type = "header",
			order = 200,
		},
		shareEntries = {
			name = L["Share my Custom timers and spell settings with all my characters"],
			desc = L["One Filters list (spells, items, auras, Custom timers and their settings) for every character on this account; switching it off gives this profile a copy of it"],
			type = "toggle",
			width = "full",
			order = 201,
			get = function(info) return P.Sharing() end,
			set = function(info, val) P.SetSharing(val and true or false) end,
		},
		newHeader = {
			name = L["New characters"],
			type = "header",
			order = 210,
		},
		newCharacterProfile = {
			name = L["New characters start on"],
			desc = L["The profile a character uses the first time it logs in with CDTL3"],
			type = "select",
			order = 211,
			values = { DEFAULT = "The Default profile", LAST = "The last profile used", CHOSEN = "A profile I choose" },
			sorting = { "DEFAULT", "LAST", "CHOSEN" },
			get = function(info) return CDTL3.db.global["newCharacterProfile"] or "DEFAULT" end,
			set = function(info, val)
					CDTL3.db.global["newCharacterProfile"] = (val == "LAST" or val == "CHOSEN") and val or nil
				end,
		},
		newCharacterProfileName = {
			name = L["Profile for new characters"],
			desc = L["The profile new characters start on"],
			type = "select",
			order = 212,
			hidden = function(info) return CDTL3.db.global["newCharacterProfile"] ~= "CHOSEN" end,
			values = function() return P.ProfileList(false) end,
			sorting = function() return P.ProfileSorting(false) end,
			get = function(info) return CDTL3.db.global["newCharacterProfileName"] end,
			set = function(info, val) CDTL3.db.global["newCharacterProfileName"] = val end,
		},
		zoneHeader = {
			name = L["Profiles by zone"],
			type = "header",
			order = 220,
		},
		zoneDesc = {
			name = L["Switch profile when you enter a raid, a dungeon, PvP or the open world (this character only). While you are there the zone's profile wins over spec profiles; where it says None, spec profiles or the profile you picked work as before."] .. "\n",
			type = "description",
			order = 221,
		},
	}

	for n, zone in ipairs(P.ZONES) do
		args["zone_"..zone.key] = {
			name = zone.name,
			desc = zone.desc,
			type = "select",
			order = 221 + n,
			values = function() return P.ProfileList(true) end,
			sorting = function() return P.ProfileSorting(true) end,
			get = function(info)
					local z = P.ZoneSettings(false)
					return z and z[zone.key] or P.NONE
				end,
			set = function(info, val)
					local z = P.ZoneSettings(true)
					z[zone.key] = (val ~= P.NONE) and val or nil
					P.ZoneChanged()
				end,
		}
	end

	return args
end

------------------------------------------------------------------------ WIRING

-- After AceDB:New (OnInitialize): callbacks, the shared lists, the spec hook and the options
P.Setup = function()
	local db = CDTL3.db

	db.RegisterCallback(P, "OnProfileShutdown", function() P.Detach() end)
	db.RegisterCallback(P, "OnDatabaseShutdown", function() P.Detach() end)
	db.RegisterCallback(P, "OnProfileChanged", function() P.RememberProfile() end)
	db.RegisterCallback(P, "OnProfileDeleted", function(_, _, name) P.ProfileDeleted(name) end)

	P.Attach()
	P.HookSpecProfiles()
	P.RememberProfile()

	if CDTL3.profile then
		-- AceDBOptions' table takes a plugins field, which the definitions don't list
		---@diagnostic disable-next-line: inject-field
		CDTL3.profile.plugins = CDTL3.profile.plugins or {}
		CDTL3.profile.plugins["CDTL3"] = P.Options()
	end

	P.events:RegisterEvent("PLAYER_ENTERING_WORLD")

	if P.startedOn and P.startedOn == db:GetCurrentProfile() then
		CDTL3:Print(string.format(L["This character starts on the profile \"%s\" (Profiles tab: New characters start on)."], P.startedOn))
	end
end

local OnInitialize = CDTL3.OnInitialize
-- a deliberate wrapper around the original
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:OnInitialize(...)
	P.StartNewCharacter()
	OnInitialize(self, ...)
	P.Setup()
end

-- every profile switch, Copy From, Reset Profile and import ends in RefreshConfig: point the
-- Filters lists first (an error here is reported and the refresh still runs)
local RefreshConfig = CDTL3.RefreshConfig
-- a deliberate wrapper around the original
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:RefreshConfig(...)
	local ok, err = pcall(P.Attach)
	if not ok then
		geterrorhandler()(err)
	end
	P.HookSpecProfiles()
	return RefreshConfig(self, ...)
end
