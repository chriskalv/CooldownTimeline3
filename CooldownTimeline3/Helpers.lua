--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
local private = {}

-- NEW SAVED ENTRIES
-- Everything that discovers a spell/item/aura/rune for the first time builds its saved
-- entry here, so the per-type Filters -> Defaults and the ignore rule apply the same way
-- whichever event or scan found it.

-- Per-type defaults (lane, bar frame, ready frame, shown by default); owned by this character
function CDTL3:ApplyEntryDefaults(s, type)
	local d = CDTL3.db.profile.global[type]

	s["lane"] = d["defaultLane"]
	-- a kept starter setup (Start.lua) sends a new spell to the lane for its length
	if CDTL3.Start then
		s["lane"] = CDTL3.Start.NewEntryLane(s, type) or s["lane"]
	end
	s["barFrame"] = d["defaultBar"]
	s["readyFrame"] = d["defaultReady"]
	s["enabled"] = d["showByDefault"]
	s["highlight"] = false
	s["pinned"] = false
	s["usedBy"] = { CDTL3.player["guid"] }

	return s
end

-- New entries start ignored when the cooldown (ms) is GCD length (3s or less) or longer
-- than the type's Ignore Threshold
function CDTL3:IgnoredByDefault(type, bCD)
	local seconds = (tonumber(bCD) or 0) / 1000

	return not (seconds > 3 and seconds <= CDTL3.db.profile.global[type]["ignoreThreshold"])
end

-- Spells whose cooldown only starts when their effect ends (Nature's Swiftness, Presence of
-- Mind, Prowl, Feign Death, Divine Favor...): flagged `oaf` in Data.lua's spell lists. While
-- the effect is up the game reports the cooldown as not started, so without the flag the icon
-- goes straight to ready and nothing restarts it when the real cooldown begins. Looked up by
-- spell ID, then by name (other ranks share the flag). The second value is true when the
-- spell data lists the spell at all, so its flag (true or false) can win over a saved one.
function CDTL3:IsAuraFadeSpell(id, name)
	if not CDTL3.spellData then
		return nil, false
	end

	local known = (id and CDTL3:GetSpellData(id)) or (name and CDTL3:GetSpellData(0, name))
	return known and known["oaf"] or nil, known ~= nil
end

-- A new player or pet spell: charge recharge time when it has charges, else its base cooldown
function CDTL3:NewSpellEntry(spellID, spellName, icon, type)
	local _, maxCharges, _, cooldownDuration = CDTL3:GetSpellCharges(spellID)
	local cooldownMS = GetSpellBaseCooldown(spellID)
	if cooldownDuration ~= nil and cooldownDuration ~= 0 then
		cooldownMS = cooldownDuration * 1000
	end

	local s = CDTL3:ApplyEntryDefaults({
		id = spellID,
		name = spellName,
		type = type,
		icon = icon,
		bCD = cooldownMS,
		setCustomCD = false,
	}, type)

	if maxCharges and maxCharges ~= 0 then
		s["charges"] = maxCharges
	end

	s["oaf"] = CDTL3:IsAuraFadeSpell(spellID, spellName)
	s["link"] = CDTL3:GetSpellLink(spellID)
	s["ignored"] = CDTL3:IgnoredByDefault(type, s["bCD"])

	return s
end

-- A new item use-spell. icon is the spell's, itemIcon the item's (Filters -> Items ->
-- Use Item Icon picks between them); names/link fill in once the item is cached.
function CDTL3:NewItemEntry(spellName, spellID, itemId, bCD)
	local s = CDTL3:ApplyEntryDefaults({
		name = spellName,
		id = spellID,
		bCD = bCD,
		itemID = itemId,
	}, "items")

	local _, icon = CDTL3:GetSpellInfo(spellID)
	s["icon"] = icon

	local item = Item:CreateFromItemID(itemId)
	item:ContinueOnItemLoad(function()
		s["itemName"] = item:GetItemName()
		s["itemIcon"] = item:GetItemIcon()
		s["link"] = item:GetItemLink()
	end)

	return s
end

-- Save a new entry and start its icon unless it starts ignored or its type is switched off.
-- noIcon saves it without starting one (an entry made from the options before it's used).
-- Returns the new cooldown frame, if one was made.
function CDTL3:SaveNewEntry(s, type, noIcon)
	-- the combat log may already have told us the school (it can arrive before the cast event)
	s["school"] = s["school"] or (CDTL3.spellSchools and CDTL3.spellSchools[s["name"]])

	table.insert(CDTL3.db.profile.tables[type], s)

	if s["ignored"] then
		CDTL3:NoteAutoIgnore(s, type)
	end

	if not noIcon and not CDTL3:IsIgnored(s, type) and CDTL3.db.profile.global[type]["enabled"] then
		return CDTL3:CreateCooldown(CDTL3:GetUID(), type, s)
	end
end

-- Item IDs of everything the player carries: equipped slots 0-23, then bags 0-4
private.CarriedItemIDs = function()
	local ids = {}

	for slot = 0, 23 do
		local itemId = GetInventoryItemID("player", slot)
		if itemId then
			table.insert(ids, itemId)
		end
	end

	for bag = 0, 4 do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemId = C_Container.GetContainerItemID(bag, slot)
			if itemId then
				table.insert(ids, itemId)
			end
		end
	end

	return ids
end

function CDTL3:AddUsedBy(type, id, guid)
	for _, data in pairs(CDTL3.db.profile.tables[type]) do
		if data["id"] == id then
			table.insert(data["usedBy"], guid)
		end
	end
end

-- True while the game hides aura data from addons (retail-API clients: combat, encounters,
-- M+, PvP). False where the API doesn't exist (Classic). A second return of true means the
-- check itself errored; the first is false then.
function CDTL3:AurasAreSecret()
	local ok, secret = pcall(function()
		if C_Secrets and C_Secrets.ShouldAurasBeSecret then
			return C_Secrets.ShouldAurasBeSecret() and true or false
		end
		return false
	end)
	if not ok then
		return false, true
	end

	return secret
end

function CDTL3:AuraExists(unit, aura)
	-- 12.1 made aura data SECRET in combat/encounter/M+/PvP: the index accessor Lua-errors while
	-- auras are secret, and comparing/doing arithmetic on secret fields throws. So — same pattern
	-- as GetSpellCooldown/GetSpellCharges — the whole scan, name compare, and duration/expiry math
	-- happen INSIDE the pcall, and only clean numbers escape. Returns nil while auras are secret,
	-- with a second return of true meaning "unknown" (secret) rather than "not there".
	local ok, result = pcall(function()
		for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
			for i = 1, 40, 1 do
				local name, spellID, duration, icon, count, expirationTime = CDTL3:GetUnitAura(unit, i, filter)

				if not name then
					break	-- end of this filter's list
				end

				if aura == name then
					local s = {
						id = spellID,
						bCD = duration * 1000,
						name = name,
						type = (filter == "HELPFUL") and "buffs" or "debuffs",
						icon = icon,
						stacks = (count or 0) + 0,
						endTime = (expirationTime or 0) + 0,
					}

					return s
				end
			end
		end

		return nil
	end)

	if ok then
		if result then
			return result
		end

		-- Not found. While auras are secret the client can also just omit them, so
		-- "not found" only means "gone" when it says auras are readable.
		local aurasSecret, checkFailed = CDTL3:AurasAreSecret()
		if aurasSecret or checkFailed then
			return nil, true
		end

		return nil
	end

	-- the scan hit a secret value: can't tell whether the aura is there
	CDTL3:LogFailure("AuraExists", result)
	return nil, true
end

-- Boss fights only (Show): in a boss encounter (ENCOUNTER_START until ENCOUNTER_END), or while the
-- game says one is in progress or shows a boss unit frame. The checks run inside pcall: a value the
-- game hides would make the comparison throw, and that reads as "no boss".
function CDTL3:InBossFight()
	if CDTL3.inEncounter then
		return true
	end

	local ok, yes = pcall(function()
		-- every client has C_InstanceEncounter's call; the bare global is only Blizzard's deprecation
		-- copy of it, gone when a player turns the fallbacks off
		---@diagnostic disable-next-line: undefined-global
		local inEncounter = (C_InstanceEncounter and C_InstanceEncounter.IsEncounterInProgress) or IsEncounterInProgress
		if inEncounter and inEncounter() == true then
			return true
		end
		return UnitExists("boss1") == true
	end)
	return ok and yes or false
end

-- Does this frame's Show rule hide it right now? s = the lane / bar frame / ready frame settings
-- (nil: the global setting). Unlock, debug, test mode and flights are Autohide's to weigh.
function CDTL3:ShowRuleHides(s)
	local mode = s and s["showMode"] or "GLOBAL"
	if mode == "ALWAYS" then
		return false
	elseif mode == "COMBAT" then
		return not CDTL3.combat
	elseif mode == "BOSS" then
		return not CDTL3:InBossFight()
	end

	return CDTL3.db.profile.global["hideOutOfCombat"] and not CDTL3.combat or false
end

-- LOCAL PATCH (Zippy, 2026-11-15): Hide while casting. True while the option is on and the player
-- casts or channels (CDTL3.casting, CDTL3.lua). It lies over every frame's Show rule, Always
-- included; Autohide weighs it with the same exceptions and Dim instead of hide as the Show rule.
function CDTL3:CastRuleHides()
	return CDTL3.db.profile.global["hideWhileCasting"] and CDTL3.casting and true or false
end

-- Is any frame hidden by a Show rule that changes with combat or a boss fight?
private.AnyShowRule = function()
	local p = CDTL3.db.profile
	if p.global["hideOutOfCombat"] then
		return true
	end

	for _, group in ipairs({ { p.lanes, "lane" }, { p.barFrames, "frame" }, { p.ready, "ready" } }) do
		for i = 1, 3 do
			local s = group[1][group[2] .. i]
			if s and (s["showMode"] == "COMBAT" or s["showMode"] == "BOSS") then
				return true
			end
		end
	end

	return false
end

-- Boss fights only reacts the moment a boss is pulled or ends. Registered in pcalls: a client that
-- doesn't know an event refuses it and the others still register. A zone change clears the flag
-- (a fight still going after a /reload is caught by IsEncounterInProgress or boss1).
private.bossEventFrame = CreateFrame("Frame")
for _, e in ipairs({ "ENCOUNTER_START", "ENCOUNTER_END", "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_ENTERING_WORLD" }) do
	pcall(private.bossEventFrame.RegisterEvent, private.bossEventFrame, e)
end
private.bossEventFrame:SetScript("OnEvent", function(_, event)
	if event == "ENCOUNTER_START" then
		CDTL3.inEncounter = true
	elseif event == "ENCOUNTER_END" or event == "PLAYER_ENTERING_WORLD" then
		CDTL3.inEncounter = false
	end

	if CDTL3.db then
		CDTL3:ApplyCombatVisibility(true)
	end
end)

function CDTL3:Autohide(f, s)
	local fAlpha = 1
	if s then
		fAlpha = s["alpha"]
	end

	--CDTL3:Print(fAlpha)

	-- Hide out of combat / Show: a frame fades while its Show rule says so (CDTL3:ShowRuleHides),
	-- while detection keeps running (a cooldown started on the last pull is still tracked and shown
	-- on the next one). Unlock, Edit Mode (which unlocks the frames), debug and test mode all win
	-- over it. A flight in progress (Flights.lua) keeps the frames showing it, since nobody is in
	-- combat on a flight. Dim instead of hide holds the frame at its dim alpha instead (an empty
	-- frame still goes with Auto-hide Frames).
	local gl = CDTL3.db.profile.global
	-- LOCAL PATCH (Zippy, 2026-11-15): or Hide while casting (CDTL3:CastRuleHides), same exceptions
	if (CDTL3:ShowRuleHides(s) or CDTL3:CastRuleHides()) and not CDTL3.testing
			and not gl["unlockFrames"] and not gl["debugMode"]
			and not (CDTL3.Flights and CDTL3.Flights:Holds(f)) then
		if s and s["dimInsteadOfHide"] then
			local target = s["dimAlpha"] or 0.3
			if gl["autohide"] and not f.overrideAutohide and (f.childCount == 0 or f.forceHide) then
				target = 0
			end
			if f:GetAlpha() ~= target then
				-- set at once: a fade still running would finish at its own end alpha
				if f.animateOut and f.animateOut:IsPlaying() then
					f.animateOut:Stop()
				end
				if f.animateIn and f.animateIn:IsPlaying() then
					f.animateIn:Stop()
				end
				f:SetAlpha(target)
			end
			return
		end

		-- LOCAL PATCH (Zippy, 2026-11-09): Autohide only runs on frame updates and visibility
		-- edges, not every frame, so a fade-in still running (a cast right after the last one)
		-- would finish at full alpha and leave the frame visible. Stop it first.
		if f.animateIn and f.animateIn:IsPlaying() then
			f.animateIn:Stop()
		end
		if f:GetAlpha() ~= 0 then
			if f.animateOut then
				if not f.animateOut:IsPlaying() then
					f.animateOut:Play()
					f.cdtl3HideFade = true	-- LOCAL PATCH (Zippy, 2026-11-09): fade started by this rule
				end
			else
				f:SetAlpha(0)
			end
		end
		return
	end

	-- LOCAL PATCH (Zippy, 2026-11-09): the hide rule no longer applies (a cast ended within the
	-- hide animation, e.g. an early interrupt). Stop the fade-out it started, or it would finish at
	-- alpha 0 and nothing would show the frame again.
	-- LOCAL PATCH (Zippy, 2026-11-21): since 3.3.0 the hide animation is the frame's own (Show and
	-- hide tab: Fade or Scale, up to 3 s and 10 plays, Lanes.lua CDTL3:SetFadeAnimations); stopped,
	-- it leaves the frame at the alpha and scale it had before (no OnFinished), so the frame shows again.
	if f.cdtl3HideFade then
		f.cdtl3HideFade = nil
		if f.animateOut and f.animateOut:IsPlaying() then
			f.animateOut:Stop()
		end
	end

	if CDTL3.db.profile.global["autohide"] and not CDTL3.db.profile.global["unlockFrames"] and not CDTL3.db.profile.global["debugMode"] then
		if f.overrideAutohide then
			--f:SetAlpha(1)
			f:SetAlpha(fAlpha)
		else
			if f.childCount == 0 or f.forceHide then
			--if f.currentCount == 0 or f.forceHide then
				if f:GetAlpha() ~= 0 then
					if f.animateOut then
						if not f.animateOut:IsPlaying() then
							f.animateOut:Play()
						end
					else
						f:SetAlpha(0)
					end
				end
			else
				--if f:GetAlpha() ~= 1 then
				if f:GetAlpha() ~= fAlpha then
					--f:SetAlpha(1)

					if f.animateIn then
						if not f.animateIn:IsPlaying() then
							f.animateIn:Play()
						end
					else
						--f:SetAlpha(1)
						f:SetAlpha(fAlpha)
					end
				end
			end
		end
	else
		--if f:GetAlpha() ~= 1 then
		if f:GetAlpha() ~= fAlpha then
			--f:SetAlpha(1)
			f:SetAlpha(fAlpha)
		end
	end
end

-- Re-apply visibility on combat edges so Hide-out-of-combat reacts instantly (frames must
-- appear the moment a pull starts) instead of waiting for the next update poll. The refresh
-- functions run every frame through CDTL3:Autohide, where the actual rule lives.
-- bossOnly (encounter events and loading screens): only the frames whose Show is Boss fights only.
function CDTL3:ApplyCombatVisibility(bossOnly)
	-- LOCAL PATCH (Zippy, 2026-11-15): also re-applied on cast edges for Hide while casting
	if not private.AnyShowRule() and not CDTL3.db.profile.global["hideWhileCasting"] then return end

	local p = CDTL3.db.profile
	local function wanted(group, key, n)
		if not bossOnly then
			return true
		end
		local s = p[group] and p[group][key .. n]
		return s and s["showMode"] == "BOSS" or false
	end

	-- by frame number: a lane or bar frame switched off at login was never created, so list
	-- positions don't match the numbers
	for _, f in pairs(CDTL3.lanes) do
		if wanted("lanes", "lane", f.number) then
			CDTL3:RefreshLane(f.number)
		end
	end
	for _, f in pairs(CDTL3.barFrames) do
		if wanted("barFrames", "frame", f.number) then
			CDTL3:RefreshBarFrame(f.number)
		end
	end
	for i = 1, 3 do
		if CDTL3:SlotFrame("ready", i) and wanted("ready", "ready", i) then
			CDTL3:RefreshReady(i)
		end
	end
end

-- Put a spell on its shared lockout (Paladin protections): lift a running cooldown to
-- lockoutTime, or start one (and save the entry if it is new)
local function LockOut(secondarySpellName, lockoutTime)
	local s = CDTL3:GetSpellSettings(secondarySpellName, "spells")
	if s then
		if not CDTL3:IsIgnored(s, "spells") then
			local ef = CDTL3:GetExistingCooldown(secondarySpellName, "spells")
			if ef then
				if ef.data["currentCD"] < lockoutTime then
					CDTL3:SendToLane(ef)
					CDTL3:SendToBarFrame(ef)

					ef.data["currentCD"] = lockoutTime
					ef.data["overrideCD"] = true
				end
			else
				if CDTL3.db.profile.global["spells"]["enabled"] then
					local f = CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)
					f.data["currentCD"] = lockoutTime
					f.data["overrideCD"] = true

					if CDTL3:IsUsedBy("spells", s["id"]) then
						--CDTL3:Print("USEDBY MATCH: "..s["id"])
					else
						--CDTL3:Print("NEW USEDBY: "..s["id"])
						CDTL3:AddUsedBy("spells", s["id"], CDTL3.player["guid"])
					end
				end
			end
		end
	else
		s = CDTL3:TableCopy(CDTL3:GetSpellData(0, secondarySpellName))
		if s then
			CDTL3:ApplyEntryDefaults(s, "spells")
			s["icon"] = select(2, CDTL3:GetSpellInfo(s["id"]))
			s["link"] = CDTL3:GetSpellLink(s["id"])
			s["ignored"] = CDTL3:IgnoredByDefault("spells", s["bCD"])

			local f = CDTL3:SaveNewEntry(s, "spells")
			if f then
				f.data["currentCD"] = lockoutTime
				f.data["overrideCD"] = true
			end
		end
	end
end

function CDTL3:CheckEdgeCases(spellName)
	-- VANISH SHOULD ALSO SPAWN A STEALTH ICON/BAR
	if spellName == "Vanish" then
		local s = CDTL3:GetSpellSettings("Stealth", "spells")
		if s then
			if not CDTL3:IsIgnored(s, "spells") then
				local ef = CDTL3:GetExistingCooldown("Stealth", "spells")
				if ef then
					CDTL3:SendToLane(ef)
					CDTL3:SendToBarFrame(ef)
				else
					if CDTL3.db.profile.global["spells"]["enabled"] then
						CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)

						if CDTL3:IsUsedBy("spells", s["id"]) then
							--CDTL3:Print("USEDBY MATCH: "..s["id"])
						else
							--CDTL3:Print("NEW USEDBY: "..s["id"])
							CDTL3:AddUsedBy("spells", s["id"], CDTL3.player["guid"])
						end
					end
				end
			end
		elseif CDTL3.tocversion < 40000 then
			-- built for the Classic lists; MoP/retail list Stealth since 3.0.12 but keep the old behaviour.
			-- A copy: the built-in spell data table itself must never become a saved entry (two
			-- profiles would share it, and one's Filters changes would land in the other's).
			s = CDTL3:TableCopy(CDTL3:GetSpellData(0, "Stealth"))
			if s then
				CDTL3:ApplyEntryDefaults(s, "spells")
				s["icon"] = select(2, CDTL3:GetSpellInfo(s["id"]))
				s["link"] = CDTL3:GetSpellLink(s["id"])
				s["ignored"] = CDTL3:IgnoredByDefault("spells", s["bCD"])

				CDTL3:SaveNewEntry(s, "spells")
			end
		end
	end

	-- SHADOWMELD
	if spellName == "Shadowmeld" then
		local s = CDTL3:GetSpellSettings("Shadowmeld", "spells")
		if s then
			if not CDTL3:IsIgnored(s, "spells") then
				local ef = CDTL3:GetExistingCooldown("Shadowmeld", "spells")
				if ef then
					CDTL3:SendToLane(ef)
					CDTL3:SendToBarFrame(ef)
				else
					if CDTL3.db.profile.global["spells"]["enabled"] then
						CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)

						if CDTL3:IsUsedBy("spells", s["id"]) then
							--CDTL3:Print("USEDBY MATCH: "..s["id"])
						else
							--CDTL3:Print("NEW USEDBY: "..s["id"])
							CDTL3:AddUsedBy("spells", s["id"], CDTL3.player["guid"])
						end
					end
				end
			end
		else
			s = CDTL3:TableCopy(CDTL3:GetSpellData(0, "Shadowmeld"))
			if s then
				CDTL3:ApplyEntryDefaults(s, "spells")
				s["icon"] = select(2, CDTL3:GetSpellInfo(s["id"]))
				s["link"] = CDTL3:GetSpellLink(s["id"])
				s["ignored"] = CDTL3:IgnoredByDefault("spells", s["bCD"])

				CDTL3:SaveNewEntry(s, "spells")
			end
		end
	end

	-- PALLY SPELL LOCKOUT: VARIOUS PROTECTIONS
	if	spellName == "Divine Protection" or
		spellName == "Divine Shield" or
		spellName == "Hand of Protection" or
		spellName == "Lay on Hands"
	then
		if CDTL3.db.profile.global["detectSharedCD"] then
			for i = 1, 5, 1 do
				local secondarySpellName = ""
				local lockoutTime = 0
				if i == 1 then
					secondarySpellName = "Divine Protection"
					lockoutTime = 120
				elseif i == 2 then
					secondarySpellName = "Divine Shield"
					lockoutTime = 120
				elseif i == 3 then
					secondarySpellName = "Hand of Protection"
					lockoutTime = 120
				elseif i == 4 then
					secondarySpellName = "Lay on Hands"
					lockoutTime = 120
				elseif i == 5 then
					secondarySpellName = "Avenging Wrath"
					lockoutTime = 30
				end

				if spellName ~= secondarySpellName then
					LockOut(secondarySpellName, lockoutTime)
				end
			end
		end
	end

	-- PALLY SPELL LOCKOUT: AVENGING WRATH
	if spellName == "Avenging Wrath" and CDTL3.db.profile.global["detectSharedCD"] then
		local lockoutTime = 30
		for i = 1, 4, 1 do
			local secondarySpellName = ""
			if i == 1 then
				secondarySpellName = "Divine Protection"
			elseif i == 2 then
				secondarySpellName = "Divine Shield"
			elseif i == 3 then
				secondarySpellName = "Hand of Protection"
			elseif i == 4 then
				secondarySpellName = "Lay on Hands"
			end

			LockOut(secondarySpellName, lockoutTime)
		end
	end
end

function CDTL3:CheckEngTinkerCases(spellName)
	if spellName == "Mind Amplification Dish" then
		return true, 1
	elseif spellName == "Flexweave Underlay" then
		return true, 15
	elseif spellName == "Springy Arachnoweave" then
		return true, 15
	elseif spellName == "Hand-Mounted Pyro Rocket" then
		return true, 10
	elseif spellName == "Hyperspeed Accelerators" then
		return true, 10
	elseif spellName == "Frag Belt" then
		return true, 6
	elseif spellName == "Personal Electromagnetic Pulse Generator" then
		return true, 6
	elseif spellName == "Nitro Boosts" then
		return true, 8
	end

	return false, nil
end

function CDTL3:Cleanup()
	-- Clean tables
	if CDTL3.db.profile.tables["other"] then
		--CDTL3:Print("CLEANING_TABLES: other")
		CDTL3.db.profile.tables["other"] = nil
	else
		--CDTL3:Print("CLEANING_TABLES: nil")
	end
end

-- A Split (%) or Split (Time) lane's Split Count (ss = mode.split or mode.splitAbs) as the
-- slider shows it: rounded to a whole number (nil if it isn't a number). Saves from before the
-- slider took whole numbers only can hold a fraction (1.5), which matched no count and left the
-- lane's positions broken.
function CDTL3:SplitCount(ss)
	local n = tonumber(ss["count"])
	return n and math.floor(n + 0.5)
end

-- The Split (Time) marks a lane draws and splits at (ss = mode.splitAbs): its Split Count's marks
-- that come before its Max Time. A mark at or past Max Time (a 3:00 lane still holding a 10m mark)
-- is left out, with any mark after it, so the lane splits as if only the marks inside it were set.
-- The saved values stay as they are: the sliders show every value the setting holds. nil when the
-- count isn't a number.
private.MARK_VALUES = { "s1v", "s2v", "s3v", "s4v", "s5v" }
function CDTL3:SplitAbsCount(ss)
	local n = CDTL3:SplitCount(ss)
	if not n then
		return nil
	end
	local max = tonumber(ss["max"])
	local used = 0
	for i = 1, math.min(n, #private.MARK_VALUES) do
		local v = tonumber(ss[private.MARK_VALUES[i]])
		if not v or (max and v >= max) then
			break
		end
		used = i
	end
	return used
end

function CDTL3:ConvertTime(raw, style)
	---@type string|number
	local t = ""

	if style == "XhYmZs" then
		local h = math.floor(raw / 3600)
		raw = raw % 3600
		local m = math.floor(raw / 60)
		raw = raw % 60
		local s = math.floor(raw / 1)
		raw = raw % 1

		if s > 0 then
			t = s.."s"
		end
		if m > 0 then
			t = m.."m"..t
		end
		if h > 0 then
			t = h.."h"..t
		end
	elseif style == "H:MM:SS" then
		local h = math.floor(raw / 3600)
		raw = raw % 3600
		local m = math.floor(raw / 60)
		raw = raw % 60
		local s = math.floor(raw / 1)
		raw = raw % 1

		if h > 0 then
			t = h..":"..string.format("%02d", m)..":"..string.format("%02d", s)
		else
			if m > 0 then
				t = m..":"..string.format("%02d", s)
			else
				t = s
			end
		end
	else
		if raw > 9.9 then
			t = tonumber(string.format("%.0f", raw)) --[[@as number]]
		else
			t = tonumber(string.format("%.1f", raw)) --[[@as number]]
		end
	end

	return t
end

function CDTL3:GenerateTestCooldowns()
    local testingType = CDTL3.db.profile.global["testingType"]
    local testingNumber = CDTL3.db.profile.global["testingNumber"]
    local testingMinTime = CDTL3.db.profile.global["testingMinTime"]
    local testingMaxTime = CDTL3.db.profile.global["testingMaxTime"]

    local timeRange = testingMaxTime - testingMinTime
    local increment = timeRange / (testingNumber - 1)

    local list = {}
    local timeCurrent = testingMinTime
    for i = 1, testingNumber do
        if CDTL3.db.profile.global["debugMode"] then
            CDTL3:Print("TESTING: "..i.." of "..testingNumber.." ("..timeCurrent.."s)")
        end

        list[i] = CDTL3:GetTestTableData(testingType, timeCurrent, i)

        timeCurrent = timeCurrent + increment
    end
    CDTL3:MakeTestCooldowns(list)
end

-- One test cooldown per entry of list (each from GetTestTableData). Test cooldowns parked in holding
-- (by Clear, or finished) are reused, so each Create doesn't add another set of frames that lives
-- until a /reload. sampleLoop marks a setup preview's samples (Start.lua), which start again at Ready
-- whatever the Test Panel's Loop says; any other test cooldown loses it. Returns the cooldowns.
function CDTL3:MakeTestCooldowns(list)
	local parked = {}
	for _, cd in ipairs(CDTL3.cooldowns) do
		if cd.data["type"] == "testing" and cd.icon:GetParent():GetName() == "CDTL3_Active_Icon_Holding"
			and cd.bar:GetParent():GetName() == "CDTL3_Bar_Holding" then
			table.insert(parked, cd)
		end
	end

	local made = {}
	for _, data in ipairs(list) do
		local cd = table.remove(parked, 1)
		if cd then
			cd.data["sampleLoop"] = data["sampleLoop"] or nil
			private.ReuseTestCooldown(cd, data)
		else
			-- CreateCooldown adds it to CDTL3.cooldowns
			cd = CDTL3:CreateCooldown(CDTL3:GetUID(), "testing", data)
			cd.data["sampleLoop"] = data["sampleLoop"] or nil
		end
		made[#made + 1] = cd
	end
	return made
end

-- Restart a parked test cooldown as the new one: the fields CreateCooldown takes from the
-- test data, then the lane and bar frame (SendToLane restarts the countdown, as for a recast)
private.ReuseTestCooldown = function(cd, data)
	local d = cd.data
	for _, k in ipairs({ "name", "icon", "enabled", "ignored", "highlight", "pinned", "lane", "barFrame", "readyFrame" }) do
		d[k] = data[k]
	end
	d["baseCD"] = data["bCD"] / 1000
	d["currentCD"] = d["baseCD"]
	d["overrideCD"] = false
	cd.icon.valid = d["enabled"]
	cd.bar.valid = d["enabled"]

	CDTL3:SendToLane(cd)
	CDTL3:SendToBarFrame(cd)
end

function CDTL3:GetAardvark(t)
	if t == "customs" then
		CDTL3.currentFilterHidden[t] = false
		return "<< Add New >>"
	elseif t == "detected" then
		CDTL3.currentFilterHidden[t] = false
		return "<< Select Detected >>"
	else
		-- the alphabetically first entry that belongs to this character
		local aardvark = nil
		for _, v in pairs(CDTL3.db.profile.tables[t]) do
			local n = (t == "items") and v["itemName"] or v["name"]
			if n and private.IsMine(v) and (not aardvark or n < aardvark) then
				aardvark = n
			end
		end

		if aardvark then
			CDTL3.currentFilterHidden[t] = false
			return aardvark
		end
	end

	return "<< Select >>"
end

function CDTL3:GetCharacterData()
	if CDTL3.player["class"] == nil then
		local playerGUID = UnitGUID("player")
		-- UnitGUID("player") is set once the character is in the world
		---@diagnostic disable-next-line: param-type-mismatch
		local _, engClass, _, engRace, _, name = GetPlayerInfoByGUID(playerGUID)

		if engClass ~= nil then
			CDTL3.player = {
				guid = playerGUID,
				name = name,
				race = engRace,
				class = engClass,
				classPower = CDTL3:GetPlayerPower(engClass),
			}

			-- every client: Data.lua's lists are Classic/TBC/Wrath-era content (Forever reads the
			-- Classic ones), and the aura-fade flag and the Vanish/Shadowmeld cases look up here
			CDTL3.spellData = CDTL3:GetAllSpellData(engClass, engRace)

			if CDTL3.db.profile.global["debugMode"] then
				CDTL3:Print("PLAYER: "..CDTL3.player["name"].." - "..CDTL3.player["race"].." - "..CDTL3.player["class"].." - "..CDTL3.player["classPower"])
			end
		end
	end
end

-- The new saved entry for the carried item whose use-spell is this spell ID, or nil
function CDTL3:GetItemSpell(id)
	for _, itemId in ipairs(private.CarriedItemIDs()) do
		local spellName, spellID = CDTL3.Compat.GetItemSpell(itemId)

		if spellID and spellID == id then
			return CDTL3:NewItemEntry(spellName, spellID, itemId, 0)
		end
	end

	return nil
end

function CDTL3:GetPlayerPower(class)
	if class == "ROGUE" then
		return Enum.PowerType.Energy
	elseif class == "DEATHKNIGHT" then
		return Enum.PowerType.RunicPower
	elseif class == "WARRIOR" then
		return Enum.PowerType.Rage
	elseif class == "DRUID" then
		local form = GetShapeshiftForm()
		if form == 1 then
			return Enum.PowerType.Rage
		elseif form == 3 then
			return Enum.PowerType.Energy
		else
			return Enum.PowerType.Mana
		end
	else
		return Enum.PowerType.Mana
	end
end

function CDTL3:GetReadableTime(t)
	---@type number|string
	local readableTimeLeft = t

	if t > 60 then
		readableTimeLeft = math.floor(t*math.pow(10,0)+0.5) / math.pow(10,0)

		local minutes = tostring(math.floor(readableTimeLeft / 60))
		local seconds = readableTimeLeft % 60

		local secondsText
		if seconds >= 10 then
			secondsText = tostring(seconds)
		elseif seconds > 0 then
			secondsText = tostring("0"..seconds)
		else
			secondsText = "00"
		end

		readableTimeLeft = minutes..":"..secondsText

	elseif t > 10 then
		readableTimeLeft = tonumber(string.format("%.0f", readableTimeLeft)) --[[@as number]]
	else
		readableTimeLeft = tonumber(string.format("%.1f", readableTimeLeft)) --[[@as number]]
		if readableTimeLeft == math.floor(readableTimeLeft) then
			readableTimeLeft = readableTimeLeft..".0"
		end
	end

	return readableTimeLeft
end

function CDTL3:GetTestTableData(testType, bCD, number)
    local data = {}
    local lowerType = testType:lower()
    local nameType = lowerType:gsub("^%l", string.upper)
          nameType = nameType:sub(1, -2)

    local count = 0
    for _ in pairs(CDTL3.icons["era"]) do
        count = count + 1
    end

    local randomIcon = 134400       -- Question mark icon
    if count > 0 then
        local random = math.random(1, count)

		if CDTL3.tocversion >= 110000 then
            randomIcon = CDTL3.icons["retail"][random]
        else
            randomIcon = CDTL3.icons["era"][random]
        end

        if randomIcon == nil then
            randomIcon = 134400     -- Question mark icon
        end
    end

    data["name"] = "Test "..nameType.." "..tostring(number)
    data["bCD"] = bCD * 1000
    data["icon"] = randomIcon
    data["stacks"] = 0
    data["type"] = "testing"
    data["testType"] = lowerType
    data["enabled"] = true
    data["pinned"] = false
    data["highlight"] = false
    data["ignored"] = false

	data["lane"] = CDTL3.db.profile.global[lowerType]["defaultLane"]
	data["barFrame"] = CDTL3.db.profile.global[lowerType]["defaultBar"]
	data["readyFrame"] = CDTL3.db.profile.global[lowerType]["defaultReady"]

    return data
end

function CDTL3:GetExistingCooldown(name, type, targetID)
	for _, e in pairs(CDTL3.cooldowns) do
		if e.data["type"] == type then
			-- items are named by their use-spell, but the Filters tab selects them by
			-- item name, so accept either for items
			if e.data["name"] == name or (type == "items" and e.data["itemName"] == name) then
				if targetID then
					if targetID == e.data["targetID"] then
						return e
					end
				else
					return e
				end
			end
		end
	end

	return nil
end

-- Thanks RoadBlock for this function
function CDTL3:GetSpellLink(id)
    local link = ""

	if CDTL3.retailAPI then
    	link = C_Spell.GetSpellLink(id)
	else
		-- Classic clients only: the old global (the C_Spell branch above handles the rest)
		---@diagnostic disable-next-line: undefined-field
		link = _G.GetSpellLink(id)
	end

    if link then
        if link:match("%a+:(%d+)") then
            return link
        else
            return format("|cff71d5ff|Hspell:%d|h[%s]|h|r",id,link)
        end
    end
end

function CDTL3:GetSpellInfo(id)
	local name = ""
	local icon = 134400				-- Question mark icon
	local originalIconID = 134400	-- Question mark icon

	if CDTL3.retailAPI then
		local data = C_Spell.GetSpellInfo(id)

		if data then
			name = data["name"]
			icon = data["iconID"]
			originalIconID = data["originalIconID"]
		end
	else
		local _
		-- Classic clients only (the other branch uses C_Spell)
		---@diagnostic disable-next-line: undefined-global
		name, _, icon, _, _, _, _, originalIconID = GetSpellInfo(id)
	end

	return name, icon, originalIconID
end

function CDTL3:GetSpellCharges(id)
	local currentCharges = 0
	local maxCharges = 0
	local cooldownDuration = 0
	local cooldownStart = 0

	if CDTL3.retailAPI then
    	local data = C_Spell.GetSpellCharges(id)

		if data then
			-- Midnight: these fields can be SECRET when execution is tainted. A bare
			-- read is fine, but callers compare them (~= 0, > 1), which throws on a
			-- secret value. Validate inside a pcall; keep them only if they're real
			-- numbers, else leave the 0 defaults so the caller's comparisons stay safe.
			-- maxCharges is documented as never secret; the timing fields can be. Each
			-- group is validated separately (the arithmetic throws on a secret value),
			-- so a charge spell still reports its charges while its timing is hidden.
			-- The start field is cooldownStartTime (not cooldownStart).
			local ok, err = pcall(function()
				maxCharges = data["maxCharges"] + 0
			end)
			if not ok then
				CDTL3:LogFailure("GetSpellCharges max", err)
			end
			ok, err = pcall(function()
				local cc, cs, cd = data["currentCharges"], data["cooldownStartTime"], data["cooldownDuration"]
				if cc + cs + cd >= 0 then
					currentCharges   = cc
					cooldownStart    = cs
					cooldownDuration = cd
				end
			end)
			if not ok then
				CDTL3:LogFailure("GetSpellCharges", err)
			end
		end
	else
		-- Classic clients only (the other branch uses C_Spell)
		---@diagnostic disable-next-line: undefined-global
		currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(id)
	end

	return currentCharges, maxCharges, cooldownStart, cooldownDuration
end

-- Item cooldowns can be SECRET on Midnight / WoW: Forever, like spell cooldowns. These
-- return real numbers, or nil when the values are secret so callers skip the refresh
-- and keep counting down from what they already have.
local function RealCooldown(place, start, duration, enabled)
	local ok, err = pcall(function()
		return start + duration >= 0
	end)

	if ok then
		return start, duration, enabled
	end
	CDTL3:LogFailure(place, err)
end

function CDTL3:GetItemCooldown(itemID)
	return RealCooldown("GetItemCooldown", C_Container.GetItemCooldown(itemID))
end

function CDTL3:GetInventoryItemCooldown(slot)
	return RealCooldown("GetInventoryItemCooldown", GetInventoryItemCooldown("player", slot))
end

function CDTL3:GetSpellCooldown(id)
	-- Midnight 12.x: data["startTime"] and data["duration"] are "secret" private values
	-- that cannot be compared or used in arithmetic from insecure addon code.
	-- Fix: wrap in anonymous pcall; on failure, fall back to event-tracked cast time
	-- + GetSpellBaseCooldown() (static spell data, not a runtime secret value).
	local start    = 0
	local duration = 0
	---@type boolean|number
	local enabled  = true

	if CDTL3.retailAPI then
		local data = C_Spell.GetSpellCooldown(id)

		if data then
			enabled = data["isEnabled"] ~= false

			if data["isActive"] then
				-- Attempt to read secret timing fields inside an anonymous pcall so
				-- the closure protects the access (pcall(f, arg) form evaluates args
				-- BEFORE entering pcall, which is why we need the wrapper function).
				-- Compare the secret value INSIDE the pcall so the throw is caught
				-- here. A bare read of a secret value does NOT error (ok stays true);
				-- only comparing/using it later does — which is why the old check at
				-- `duration == 0` outside the pcall threw "compare a secret number".
				local ok, err = pcall(function()
					if data["duration"] and data["duration"] > 0 then
						start    = data["startTime"]
						duration = data["duration"]
					end
				end)
				if not ok then
					CDTL3:LogFailure("GetSpellCooldown", err)
				end

				-- isActive is also true during the global cooldown. When the timing is secret
				-- the fallback below would invent a ~1.6s cooldown for every spell on the GCD,
				-- so a spell that is only GCD-locked reports no cooldown. (isOnGCD is
				-- documented as never secret; checked inside a pcall anyway.)
				local gcdOK, onGCD = pcall(function()
					return data["isOnGCD"] == true
				end)
				if not gcdOK then
					CDTL3:LogFailure("GetSpellCooldown isOnGCD", onGCD)
				end

				if (not ok or duration == 0) and gcdOK and onGCD then
					start, duration = 0, 0
				elseif not ok or duration == 0 then
					-- Midnight secret-value fallback:
					-- Use UNIT_SPELLCAST_SUCCEEDED cast-time tracking + GetSpellBaseCooldown.
					if not CDTL3.spellCastTimes then CDTL3.spellCastTimes = {} end
					if not CDTL3.spellBaseCDs   then CDTL3.spellBaseCDs   = {} end

					local castTime = CDTL3.spellCastTimes[id]
					local bcd      = CDTL3.spellBaseCDs[id]

					if not bcd then
						-- Try to read base CD now (static, non-secret)
						local ms = GetSpellBaseCooldown and GetSpellBaseCooldown(id)
						if ms and ms > 0 then
							bcd = ms / 1000
							CDTL3.spellBaseCDs[id] = bcd
						end
					end

					if castTime then
						start    = castTime
						duration = bcd or 1.6
					else
						-- No tracking data yet — signal on-CD with a safe estimate
						start    = GetTime() - 0.5
						duration = bcd or 1.6
					end
				end
			end
		end
	else
		start, duration, enabled = GetSpellCooldown(id)
	end

	return start, duration, enabled
end

function CDTL3:GetSpellSettings(name, type, specialCase, id)
	--CDTL3:Print("TYPECHECK: "..type)
	-- (no list for a timer type another addon registered, CDTL3:RegisterTimerType)
	for _, e in pairs(CDTL3.db.profile.tables[type] or {}) do
		if id then
			if e["id"] == id then
				return e
			end
		else
			if specialCase then
				if type == "items" then
					if e["itemName"] == name then
						return e
					end
				else
					if e["name"] == name then
						return e
					end
				end
			else
				if e["name"] == name then
					return e
				end
			end
		end
	end

	return nil
end

function CDTL3:GetCustomSpellSettings(name, triggerType)
	for _, e in pairs(CDTL3.db.profile.tables["customs"]) do
		if e["name"] == name then
			if e["triggerType"] == triggerType then
				return e
			end
		end
	end

	return nil
end

function CDTL3:GetUID()
	CDTL3.cdUID = CDTL3.cdUID + 1
	return CDTL3.cdUID
end

function CDTL3:GetUnitAura(unit, i, filter)
	--local name, spellID, duration, icon, count, expirationTime = CDTL3:GetUnitAura(unit, i, "HELPFUL")

	local name = ""
	local spellID = 0
	local duration = 0
	local icon = 0
	local count = 0
	local expirationTime = 0

	-- the Classic clients carry C_UnitAuras.GetAuraDataByIndex too; UnitAura is the fallback only
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
    	local data = C_UnitAuras.GetAuraDataByIndex(unit, i, filter)

		if not data then
			-- past the last aura: nil name, like UnitAura on Classic
			return nil
		end

		if data then
			name = data["name"]
			spellID = data["spellId"]
			duration = data["duration"]
			icon = data["icon"]
			count = data["applications"]
			expirationTime = data["expirationTime"]
		end
	else
		local _
		-- a fallback only: every current client has C_UnitAuras.GetAuraDataByIndex, and on the Classic
		-- clients UnitAura is Blizzard's deprecation copy of it
		---@diagnostic disable-next-line: undefined-global
		name, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitAura(unit, i, filter)
	end

	return name, spellID, duration, icon, count, expirationTime
end

function CDTL3:IsUsableSpell(id)
	local usable = true
	local noPower = false

	if CDTL3.retailAPI then
    	usable, noPower = C_Spell.IsSpellUsable(id)
	else
		-- Classic clients only (the other branch uses C_Spell)
		---@diagnostic disable-next-line: undefined-global
		usable, noPower = IsUsableSpell(id)
	end

	return usable, noPower
end

function CDTL3:IsUsedBy(type, id, specialCase)
	if CDTL3.player["class"] == nil then
		CDTL3:GetCharacterData()
	end

	for _, spell in pairs(CDTL3.db.profile.tables[type]) do
		if specialCase then
			if spell["itemID"] == id then
				for _, data in pairs(spell["usedBy"]) do
					if CDTL3.player["guid"] == data then
						return true
					end
				end
			end
		else
			if spell["id"] == id then
				for _, data in pairs(spell["usedBy"]) do
					if CDTL3.player["guid"] == data then
						return true
					end
				end
			end
		end
	end

	return false
end

function CDTL3:IsValidItem(itemID)
	local _, itemType, itemSubType, _, _, classID, subclassID = CDTL3.Compat.GetItemInfoInstant(itemID)

	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:Print("ITEM: "..itemType.."("..tostring(classID)..") - "..itemSubType.."("..tostring(subclassID)..")")
	end

	-- CONSUMABLE
	if classID == 0 then
		if
			subclassID == 0 or	-- Generic
			subclassID == 1 or	-- Potion
			subclassID == 2 	-- Elixir
		then
			return true
		end
	end

	-- WEAPON
	if classID == 2 then
		return true
	end

	-- ARMOR
	if classID == 4 then
		return true
	end

	-- TRADEGOODS
	if classID == 7 then
		if
			subclassID == 2		-- Explosives
		then
			return true
		end
	end

	-- QUEST
	if classID == 12 then
		return true
	end

	-- MISCELLANEOUS
	if classID == 15 then
		if
			subclassID == 4		-- Other
		then
			return true
		end
	end



	return false
end

-- Does this saved entry belong to the current character? (checks the entry itself;
-- IsUsedBy re-scans the whole table by id)
private.IsMine = function(data)
	if not CDTL3.player["guid"] then
		CDTL3:GetCharacterData()
	end

	local guid = CDTL3.player["guid"]
	if guid and data["usedBy"] then
		for _, g in pairs(data["usedBy"]) do
			if g == guid then
				return true
			end
		end
	end

	return false
end

-- The same test for the Filters bulk controls (Options.lua), which change only the entries
-- the Filters lists show: this character's
function CDTL3:IsMyEntry(data)
	return private.IsMine(data)
end

function CDTL3:LoadFilterList(type, specialCase)
	local list = {}

	if type == "customs" then
		list["<< Add New >>"] = "<< Add New >>"
	elseif type == "detected" then
		list["<< Select Detected >>"] = "<< Select Detected >>"
	else
		list["<< Select >>"] = "<< Select >>"
	end

	for _, data in pairs(CDTL3.db.profile.tables[type]) do
		-- items are listed by item name, which loads asynchronously and can still be nil
		local key = specialCase and data["itemName"] or data["name"]
		if key and private.IsMine(data) then
			list[key] = key
		end
	end

	return list
end

function CDTL3:LoadDetectedList()
	local list = {}

	list["<< Select Detected >>"] = "<< Select Detected >>"

	for _, data in pairs(CDTL3.db.profile.tables["detected"]) do
		--for _, guid in pairs(data["usedBy"]) do
			list[data["name"]] = data["name"]
		--end
	end

	return list
end

function CDTL3:OnTalentChanges()
	if CDTL3.db.profile.global["debugMode"] then
		if CDTL3.retailAPI then
			CDTL3:Print("RETAIL TALENT CHANGE")
		else
			CDTL3:Print("CLASSIC/ERA TALENT/RUNE CHANGE")
		end
	end

	for _, cd in pairs(CDTL3.cooldowns) do
		local spellID = cd.data and cd.data["id"]
		--local isKnown = IsSpellKnown(spellID, isPet)
		--local isKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown(spellID)

		-- Only spells and pet spells depend on talents / spec. Items, buffs, debuffs,
		-- offensives and customs aren't in the spellbook, so the "not known -> ready"
		-- reset below would wrongly end their timers.
		local cdType = cd.data and cd.data["type"]
		if spellID and (cdType == "spells" or cdType == "petspells") then
			local isPet = cdType == "petspells"

			local isKnown = CDTL3.Compat.IsSpellKnown(spellID, isPet)
			local isKnownOrOverridesKnown = CDTL3.Compat.IsSpellKnownOrOverridesKnown(spellID, isPet)

			if isKnown or isKnownOrOverridesKnown then
				--local start, duration, enabled, _ = GetSpellCooldown(spellID)
				local _, duration = CDTL3:GetSpellCooldown(spellID)
				if duration and duration > 1.5 then
					CDTL3:SendToLane(cd)
					CDTL3:SendToBarFrame(cd)
				end
			elseif cd.data and cd.data["currentCD"] then
				cd.data["currentCD"] = 0
			end
		end
	end

	-- Filters > Spells rules (Hide spells I don't know, Only for this spec): the spellbook changed
	CDTL3:ForgetSpellbook()
	CDTL3:ApplyEntryRules()
end

function CDTL3:RecycleOffensiveCD()
	for _, child in ipairs(CDTL3.cooldowns) do
		if child.data["type"] == "offensives" then
			if child.data["currentCD"] < 0 then
				return child
			end
		end
	end

	return nil
end

-- the base definition: Profiles.lua and Group.lua wrap it
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:RefreshConfig()
	-- Refresh every existing frame by its own number (the lists hold only frames that
	-- were created, in creation order, so the list index isn't the frame number), then
	-- create any frame that is enabled in this profile but didn't exist yet.
	for _, f in pairs(CDTL3.readyFrames) do
		CDTL3:RefreshReady(f.number)
	end
	CDTL3:CreateReadyFrames()

	for _, f in pairs(CDTL3.barFrames) do
		CDTL3:RefreshBarFrame(f.number)
	end
	CDTL3:CreateBarFrames()

	for _, f in pairs(CDTL3.lanes) do
		CDTL3:RefreshLane(f.number)
	end
	CDTL3:CreateLanes()

	CDTL3:RefreshAllIcons()
	CDTL3:RefreshAllBars()

	-- Re-register the FULL tree (not just the main table) so a profile switch never strips
	-- the Lanes/Ready/Bar Frames/Filters/Profiles tabs from the standalone window.
	LibStub("AceConfig-3.0"):RegisterOptionsTable("CDTL3", CDTL3:GetFullOptions())

	-- the "Frames currently unlocked" box follows this profile's lock state (a switch from an
	-- unlocked profile to a locked one left it up over locked frames)
	if CDTL3.db.profile.global["unlockFrames"] then
		CDTL3.unlockFrame:Show()
	elseif CDTL3.unlockFrame then
		CDTL3.unlockFrame:Hide()
	end

	CDTL3:ResetStaleFilters()

	CDTL3:Cleanup()
end

-- A Filters selection that no longer names one of this character's entries (after a profile
-- switch, an import, a reset or Clear Quest Items) goes back to its tab's placeholder, so the
-- tab's controls can't act on a gone entry or on another character's entry of the same name.
function CDTL3:ResetStaleFilters()
	if not CDTL3.currentFilter then
		return
	end

	for t, selected in pairs(CDTL3.currentFilter) do
		if t ~= "default" and CDTL3.db.profile.tables[t] then
			local list
			if t == "detected" then
				list = CDTL3:LoadDetectedList()
			else
				list = CDTL3:LoadFilterList(t, t == "items")
			end

			if not list[selected] then
				if t == "customs" then
					CDTL3.currentFilter[t] = "<< Add New >>"
					CDTL3.currentFilterHidden[t] = false
				elseif t == "detected" then
					CDTL3.currentFilter[t] = "<< Select Detected >>"
				else
					CDTL3.currentFilter[t] = "<< Select >>"
					CDTL3.currentFilterHidden[t] = true
				end
			end
		end
	end
end

-- FILTERS: WHY AN ENTRY ISN'T SHOWING, MY SPELLS, SPEC RULES, THE COOLDOWN MANAGER'S BUFFS
-- Everything new here is off until the player turns it on: no rule hides anything by default.

-- type names as the Filters tabs and the Defaults list show them
private.filterTabNames = { spells = L["Spells"], items = L["Items"], buffs = L["Buffs"], debuffs = L["Debuffs"],
	offensives = L["Offensives"], petspells = L["Pet Spells"], runes = L["Runes"], customs = L["Custom"] }
private.filterTypeNames = { spells = L["Spells"], items = L["Items"], buffs = L["Buffs"], debuffs = L["Debuffs"],
	offensives = L["Offensives"], petspells = L["Pet Spells"], runes = L["Runes"], customs = L["Customs"] }
private.filterAuraTypes = { buffs = true, debuffs = true, offensives = true }
private.filterLaneKeys = { "lane1", "lane2", "lane3" }

private.HasValue = function(list, value)
	if type(list) ~= "table" then
		return false
	end
	for _, v in pairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

private.RemoveValue = function(list, value)
	for i = #list, 1, -1 do
		if list[i] == value then
			table.remove(list, i)
		end
	end
end

-- 90 -> "90", 1.5 -> "1.5"
private.Seconds = function(n)
	if n == math.floor(n) then
		return string.format("%d", n)
	end
	return string.format("%.1f", n)
end

-- Why the ignore rule (IgnoredByDefault) ignores this entry: "its cooldown is 3 s or less", "its
-- 180 s cooldown is over the ... Ignore Threshold (120 s)", or nil when the rule wouldn't (then it
-- was ignored by hand). Saved lengths are plain numbers; callers still run this in a pcall.
private.AutoIgnoreText = function(s, kind)
	local isAura = private.filterAuraTypes[kind]
	local seconds = (tonumber(s["bCD"]) or 0) / 1000
	if seconds <= 3 then
		return isAura and L["its duration is 3 s or less"] or L["its cooldown is 3 s or less"]
	end

	local threshold = CDTL3.db.profile.global[kind] and CDTL3.db.profile.global[kind]["ignoreThreshold"]
	if threshold and seconds > threshold then
		return string.format(isAura and L["its %s s duration is over the %s Ignore Threshold (%s s)"] or L["its %s s cooldown is over the %s Ignore Threshold (%s s)"],
			private.Seconds(seconds), private.filterTypeNames[kind], private.Seconds(threshold))
	end
end

-- The first time a long cooldown is ignored for going over the Ignore Threshold (on this account),
-- chat says so, once. Spells of 3 s or less are skipped: those ignores are expected (Frostbolt, Fireball)
-- and would use up the note before the case it's for, a 3-minute defensive that vanished.
function CDTL3:NoteAutoIgnore(s, kind)
	local g = CDTL3.db and CDTL3.db.global
	-- cooldown kinds only: a long buff (Well Fed, a flask) must not use the note up
	if not g or g["autoIgnoreNoted"] or type(s) ~= "table" or not (kind == "spells" or kind == "petspells" or kind == "items") then
		return
	end
	if (tonumber(s["bCD"]) or 0) <= 3000 then
		return
	end

	local ok, why = pcall(private.AutoIgnoreText, s, kind)
	if not ok or not why then
		return
	end

	g["autoIgnoreNoted"] = true
	local name = tostring((kind == "items" and s["itemName"]) or s["name"] or "?")
	CDTL3:Print(string.format(L["%s won't show: CDTL3 ignored it because %s. To show it, type /cdtl3 filters, pick it on the %s tab and click Show anyway. (This note shows once.)"],
		name, why, private.filterTabNames[kind]))
end

-- Ignored as far as showing goes: the entry's own Ignored box, or a Filters > Spells rule
function CDTL3:IsIgnored(s, kind)
	if s and s["ignored"] then
		return true
	end

	return CDTL3:RuleHides(s, kind) ~= nil
end

-- Which Filters > Spells rule hides this spell, if any: "unticked" (Show only the ticked spells),
-- "spec" (Only for this spec) or "unknown" (Hide spells I don't know). Spells only.
function CDTL3:RuleHides(s, kind)
	if kind ~= "spells" or not s then
		return nil
	end

	if CDTL3:OnlyTickedSpells() and not CDTL3:IsTicked(s) then
		return "unticked"
	end

	if CDTL3:IsSpecLimited(s) then
		local spec = CDTL3:CurrentSpec()
		if spec and not private.HasValue(s["onlySpecs"], spec) then
			return "spec"
		end
	end

	local g = CDTL3.db.profile.global["spells"]
	if g and g["hideUnknown"] and not CDTL3:KnowsSpell(s) then
		return "unknown"
	end

	return nil
end

-- MY SPELLS (Filters > Spells): this character's ticks live on the entry (pickedBy, like usedBy);
-- Show only the ticked spells is per character too
function CDTL3:OnlyTickedSpells()
	local c = CDTL3.db and CDTL3.db.char
	return (c and c["onlyTickedSpells"]) and true or false
end

function CDTL3:SetOnlyTickedSpells(on)
	CDTL3.db.char["onlyTickedSpells"] = on and true or nil
	CDTL3:ApplyEntryRules()
end

function CDTL3:IsTicked(s)
	local guid = CDTL3.player["guid"]
	return guid ~= nil and private.HasValue(s["pickedBy"], guid)
end

-- The player's spellbook (this spec's tabs): every spell name, and the spells with a cooldown for
-- My spells (a later slot of the same name, a higher rank, wins). Cached until it changes.
private.Book = function()
	if private.book then
		return private.book
	end

	local book = { names = {}, byName = {}, list = {} }
	local function add(name, id, passive)
		if type(name) ~= "string" or name == "" or type(id) ~= "number" then
			return
		end
		book.names[name] = true
		if passive then
			return
		end

		local okCD, hasCD = pcall(function()
			local ms = GetSpellBaseCooldown and GetSpellBaseCooldown(id)
			if ms and ms > 0 then
				return true
			end
			local _, maxCharges, _, chargeCD = CDTL3:GetSpellCharges(id)
			return (maxCharges and maxCharges > 1 and chargeCD and chargeCD > 0) and true or false
		end)
		if okCD and hasCD then
			local _, icon = CDTL3:GetSpellInfo(id)
			local e = book.byName[name]
			if not e then
				e = {}
				book.byName[name] = e
				table.insert(book.list, e)
			end
			e.id, e.name, e.icon = id, name, icon
		end
	end

	pcall(function()
		if CDTL3.retailAPI then
			local bank = Enum.SpellBookSpellBank.Player
			for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
				local line = C_SpellBook.GetSpellBookSkillLineInfo(i)
				if line and not line.shouldHide and not (line.offSpecID and line.offSpecID ~= 0) then
					for j = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
						local itemType, id = C_SpellBook.GetSpellBookItemType(j, bank)
						if itemType == Enum.SpellBookItemType.Spell then
							local passive = C_SpellBook.IsSpellBookItemPassive and C_SpellBook.IsSpellBookItemPassive(j, bank)
							add(C_SpellBook.GetSpellBookItemName(j, bank), id, passive)
						end
					end
				end
			end
		else
			-- Classic clients only: the old spellbook calls (the other branch uses C_SpellBook)
			---@diagnostic disable-next-line: undefined-global
			for i = 1, GetNumSpellTabs() do
				---@diagnostic disable-next-line: undefined-global
				local _, _, offset, numSlots, _, offSpecID = GetSpellTabInfo(i)
				if not (offSpecID and offSpecID ~= 0) then
					for j = offset + 1, offset + numSlots do
						---@diagnostic disable-next-line: undefined-global
						local name, _, id = GetSpellBookItemName(j, BOOKTYPE_SPELL)
						---@diagnostic disable-next-line: undefined-global
						local kind = GetSpellBookItemInfo and GetSpellBookItemInfo(j, BOOKTYPE_SPELL)
						if kind == nil or kind == "SPELL" then
							---@diagnostic disable-next-line: undefined-global
							add(name, id, IsPassiveSpell and IsPassiveSpell(j, BOOKTYPE_SPELL))
						end
					end
				end
			end
		end
	end)

	table.sort(book.list, function(a, b) return a.name < b.name end)
	private.book = book
	return book
end

function CDTL3:ForgetSpellbook()
	private.book = nil
end

-- Does this character know the spell now? By its ID (or an override of it), else by name, since the
-- saved entry can hold another rank's ID
function CDTL3:KnowsSpell(s)
	local id = s["id"]
	if type(id) == "number" then
		local ok, known = pcall(function()
			return CDTL3.Compat.IsSpellKnown(id) or CDTL3.Compat.IsSpellKnownOrOverridesKnown(id)
		end)
		if ok and known then
			return true
		end
	end

	return s["name"] ~= nil and private.Book().names[s["name"]] == true
end

-- My spells' list: the spellbook's spells with a cooldown, plus any ticked one it no longer lists.
-- { key = name, label = icon and name }, sorted by name
function CDTL3:MySpellsList()
	local list, seen = {}, {}
	local function icon(i)
		return "|T" .. tostring(i or 134400) .. ":16:16:0:0:64:64:5:59:5:59|t "
	end

	for _, spell in ipairs(private.Book().list) do
		seen[spell.name] = true
		table.insert(list, { key = spell.name, label = icon(spell.icon) .. spell.name })
	end

	for _, s in pairs(CDTL3.db.profile.tables["spells"]) do
		if type(s["name"]) == "string" and not seen[s["name"]] and CDTL3:IsTicked(s) then
			seen[s["name"]] = true
			table.insert(list, { key = s["name"], label = icon(s["icon"]) .. s["name"] .. " |cff808080(not in your spellbook)|r" })
		end
	end

	table.sort(list, function(a, b) return a.key < b.key end)
	return list
end

function CDTL3:IsSpellTicked(name)
	local s = CDTL3:GetSpellSettings(name, "spells")
	return s ~= nil and CDTL3:IsTicked(s)
end

-- Tick (or untick) a spell in My spells. Ticking makes its entry before it's ever cast (or claims
-- the saved one for this character) and un-ignores it; unticking keeps the entry and its settings.
function CDTL3:TickSpell(name, on)
	if not CDTL3.player["guid"] then
		CDTL3:GetCharacterData()
	end
	local guid = CDTL3.player["guid"]
	if not guid or type(name) ~= "string" then
		return
	end

	local s = CDTL3:GetSpellSettings(name, "spells")
	if on then
		if not s then
			local spell = private.Book().byName[name]
			if not spell then
				return
			end
			s = CDTL3:NewSpellEntry(spell.id, name, spell.icon, "spells")
			s["ignored"] = false
			s["pickedBy"] = { guid }
			CDTL3:SaveNewEntry(s, "spells", true)
		else
			if not private.IsMine(s) then
				if type(s["usedBy"]) ~= "table" then
					s["usedBy"] = {}
				end
				table.insert(s["usedBy"], guid)
			end
			if type(s["pickedBy"]) ~= "table" then
				s["pickedBy"] = {}
			end
			if not private.HasValue(s["pickedBy"], guid) then
				table.insert(s["pickedBy"], guid)
			end
			if s["ignored"] then
				s["ignored"] = false
				local ef = CDTL3:GetExistingCooldown(s["name"], "spells")
				if ef then
					ef.data["ignored"] = false
					CDTL3:RefreshIcon(ef)
				end
			end
		end
	elseif s and type(s["pickedBy"]) == "table" then
		private.RemoveValue(s["pickedBy"], guid)
		if not next(s["pickedBy"]) then
			s["pickedBy"] = nil
		end
	end

	CDTL3:ApplyEntryRules()
end

-- SPECS (MoP Classic and Retail; not Forever, Era or TBC)
function CDTL3:HasSpecs()
	if CDTL3.tocversion < 50000 then
		return false
	end

	local SI = C_SpecializationInfo
	return ((SI and SI.GetSpecialization) or GetSpecialization) ~= nil
end

-- The spec you're in: its ID and name, or nil (no specs here, or none chosen yet)
function CDTL3:CurrentSpec()
	if not CDTL3:HasSpecs() then
		return nil
	end

	local ok, id, name = pcall(function()
		local SI = C_SpecializationInfo
		local getSpec = (SI and SI.GetSpecialization) or GetSpecialization
		local getInfo = (SI and SI.GetSpecializationInfo) or GetSpecializationInfo
		local index = getSpec()
		if type(index) ~= "number" or index < 1 or not getInfo then
			return nil
		end
		local specID, specName = getInfo(index)
		if type(specID) == "number" and specID > 0 then
			return specID, specName
		end
	end)
	if ok then
		return id, name
	end
end

private.SpecName = function(specID)
	local ok, name = pcall(function()
		local byID = (C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfoByID) or GetSpecializationInfoByID
		if byID then
			local _, n = byID(specID)
			return n
		end
	end)
	if ok and type(name) == "string" and name ~= "" then
		return name
	end
	return string.format(L["spec %s"], tostring(specID))
end

-- "Arcane, Fire" for an entry's onlySpecs
function CDTL3:SpecNames(specs)
	local names = {}
	for _, id in pairs(type(specs) == "table" and specs or {}) do
		table.insert(names, private.SpecName(id))
	end
	table.sort(names)
	return table.concat(names, ", ")
end

function CDTL3:IsSpecLimited(s)
	return type(s) == "table" and type(s["onlySpecs"]) == "table" and next(s["onlySpecs"]) ~= nil
end

-- Only for this spec: on adds the spec you're in to the specs the spell shows in; off shows it in
-- every spec again
function CDTL3:SetOnlyThisSpec(s, on)
	if not s then
		return
	end

	if on then
		local spec = CDTL3:CurrentSpec()
		if not spec then
			return
		end
		if type(s["onlySpecs"]) ~= "table" then
			s["onlySpecs"] = {}
		end
		if not private.HasValue(s["onlySpecs"], spec) then
			table.insert(s["onlySpecs"], spec)
		end
	else
		s["onlySpecs"] = nil
	end

	CDTL3:ApplyEntryRules()
end

function CDTL3:SetHideUnknownSpells(on)
	CDTL3.db.profile.global["spells"]["hideUnknown"] = on and true or false
	CDTL3:ApplyEntryRules()
end

-- Live icons follow the Filters > Spells rules at once: a spell a rule now hides leaves its lane,
-- bar frame and Ready frame; when one comes back, the login scan puts a running cooldown back.
function CDTL3:ApplyEntryRules()
	local rescan = false
	for _, f in pairs(CDTL3.cooldowns) do
		local d = f.data
		if d and d["type"] == "spells" and f.icon and f.bar then
			local s = CDTL3:GetSpellSettings(d["name"], "spells")
			if s and CDTL3:RuleHides(s, "spells") then
				f.ruleHeld = true
				CDTL3:SendToHolding(f)
				CDTL3:SendToBarHolding(f)
			elseif f.ruleHeld then
				f.ruleHeld = nil
				rescan = true
			end
		end
	end

	if rescan and CDTL3.player["class"] then
		CDTL3:ScanCurrentCooldowns(CDTL3.player["class"], CDTL3.player["race"])
	end
end

-- WHY ISN'T IT SHOWING (each Filters entry)
-- The lane an entry goes on when Show anyway takes it off Hide: its type's Default Lane, else the
-- first lane that's switched on, else lane 1
private.LaneToUse = function(kind)
	local lanes = CDTL3.db.profile.lanes
	local d = tonumber(CDTL3.db.profile.global[kind] and CDTL3.db.profile.global[kind]["defaultLane"])
	if d and private.filterLaneKeys[d] and lanes[private.filterLaneKeys[d]]["enabled"] then
		return d
	end
	for n, key in ipairs(private.filterLaneKeys) do
		if lanes[key]["enabled"] then
			return n
		end
	end
	return 1
end

-- a lane's Max Time and Hide Long Timers in its current mode
private.laneModeKeys = { LINEAR = "linear", LINEAR_ABS = "linearAbs", SPLIT = "split", SPLIT_ABS = "splitAbs" }
private.LaneMax = function(ls)
	local mode = ls["mode"]
	local m = mode and mode[private.laneModeKeys[mode["type"]] or ""]
	if m then
		return tonumber(m["max"]), m["hideTimeSurplus"] == true
	end
end

private.WhyNotShowing = function(s, kind)
	local g = CDTL3.db.profile.global
	local typeName = private.filterTypeNames[kind]

	if s["ignored"] then
		local why = private.AutoIgnoreText(s, kind)
		if why then
			return string.format(L["Ignored automatically: %s."], why), "unignore"
		end
		return L["Ignored by hand: the Ignored box below is ticked."], "unignore"
	end

	local rule = CDTL3:RuleHides(s, kind)
	if rule == "unticked" then
		return L["Hidden: it isn't ticked in My spells (below), and Show only the ticked spells is on."], "tick"
	elseif rule == "spec" then
		return string.format(L["Hidden: it's set to show only for %s (Only for this spec)."], CDTL3:SpecNames(s["onlySpecs"])), "spec"
	elseif rule == "unknown" then
		return L["Hidden: this character doesn't know it right now, and Hide spells I don't know is on (top of this tab)."]
	end

	if s["enabled"] == false then
		return L["Switched off: its Enabled box below is unticked."], "enable"
	end

	if g[kind] and g[kind]["enabled"] == false then
		return string.format(L["Switched off: all %s are off (Filters > Defaults, pick %s, Enabled)."], typeName, typeName), "type"
	end

	local lane = tonumber(s["lane"]) or 0
	local key = private.filterLaneKeys[lane]
	if not key then
		local text = L["Not on a lane: its Lane below is set to Hide."]
		local bar = tonumber(s["barFrame"])
		local bf = bar and CDTL3.db.profile.barFrames["frame" .. bar]
		if bf and bf["enabled"] then
			text = text .. " " .. string.format(L["(Its bar still shows in %s.)"], tostring(bf["name"]))
		end
		return text, "lane", private.LaneToUse(kind)
	end

	local ls = CDTL3.db.profile.lanes[key]
	local laneName = tostring(ls["name"])
	if not ls["enabled"] then
		return string.format(L["Not showing: %s is switched off (Lanes > %s > General > Enabled)."], laneName, laneName), "laneOn", lane
	end

	local max, hide = private.LaneMax(ls)
	local seconds = (tonumber(s["bCD"]) or 0) / 1000
	if s["setCustomCD"] and tonumber(s["customCDTime"]) then
		seconds = s["customCDTime"] / 1000
	end
	if hide and max and seconds > max then
		return string.format(L["Hidden until %s s are left: its %s s is longer than %s's Max Time and Hide Long Timers is on. To see it the whole time, raise Lanes > %s > General > Max Time to %d or untick Hide Long Timers there."],
			private.Seconds(max), private.Seconds(seconds), laneName, laneName, math.ceil(seconds))
	end

	return nil
end

-- One line on why a Filters entry won't show, and what Show anyway does: "unignore", "tick", "spec",
-- "enable", "type", "lane" (onto lane n), "laneOn" (switch lane n on), or nil when the line says which
-- setting to change instead (Max Time, Hide spells I don't know). nil when nothing stops it.
function CDTL3:WhyNotShowing(s, kind)
	if type(s) ~= "table" or not private.filterTabNames[kind] then
		return nil
	end

	local ok, text, fix, n = pcall(private.WhyNotShowing, s, kind)
	if ok then
		return text, fix, n
	end
end

-- THE COOLDOWN MANAGER'S TRACKED BARS (Filters > Buffs, Retail and Forever)
-- Saved buffs of this character that aren't in Tracked Bars (estimated in combat), sorted
function CDTL3:BuffsNotInTrackedBars(bars)
	if not bars then
		local CT = CDTL3.CombatTimers
		bars = CT and CT.TrackedBarBuffs and CT:TrackedBarBuffs()
		if not bars then
			return nil
		end
	end

	local tracked = {}
	for _, bar in ipairs(bars) do
		for _, n in ipairs(bar.names) do
			tracked[n] = true
		end
	end

	local list = {}
	for _, e in pairs(CDTL3.db.profile.tables["buffs"]) do
		if type(e["name"]) == "string" and not e["ignored"] and private.IsMine(e) and not tracked[e["name"]] then
			table.insert(list, e["name"])
		end
	end
	table.sort(list)
	return list
end

-- Pull from Cooldown Manager: one Buffs entry for every Tracked Bars buff, made before it's ever seen
-- (with Filters > Defaults' lane, bar frame and Ready frame) or claimed for this character, and not
-- ignored. A buff on you now shows at once. Returns what it did, or nil where there's no Cooldown Manager.
function CDTL3:PullTrackedBuffs()
	local CT = CDTL3.CombatTimers
	local bars
	---@type boolean?
	local viewerOn = false
	if CT and CT.TrackedBarBuffs then
		bars, viewerOn = CT:TrackedBarBuffs()
	end
	if not bars then
		return nil
	end

	if not CDTL3.player["guid"] then
		CDTL3:GetCharacterData()
	end
	local guid = CDTL3.player["guid"]
	local result = { made = {}, claimed = {}, tracked = #bars, viewerOn = viewerOn }

	for _, bar in ipairs(bars) do
		local s = nil
		for _, n in ipairs(bar.names) do
			s = s or CDTL3:GetSpellSettings(n, "buffs")
		end

		if s then
			if guid and not private.IsMine(s) then
				if type(s["usedBy"]) ~= "table" then
					s["usedBy"] = {}
				end
				table.insert(s["usedBy"], guid)
			end
			if s["ignored"] then
				s["ignored"] = false
				local ef = CDTL3:GetExistingCooldown(s["name"], "buffs")
				if ef then
					ef.data["ignored"] = false
					CDTL3:RefreshIcon(ef)
				end
			end
			table.insert(result.claimed, s["name"])
		else
			local _, icon = CDTL3:GetSpellInfo(bar.spellID)
			s = CDTL3:ApplyEntryDefaults({
				id = bar.spellID,
				name = bar.name,
				type = "buffs",
				icon = icon,
				bCD = 0,
				setCustomCD = false,
				cdmPulled = true,	-- learns its length the first time it's seen (OnPlayerAuraApplied)
			}, "buffs")
			s["link"] = CDTL3:GetSpellLink(bar.spellID)
			s["ignored"] = false

			-- on you now and readable: its length is known already
			local up = CDTL3:AuraExists("player", bar.name)
			if up and (up["bCD"] or 0) > 0 then
				s["bCD"] = up["bCD"]
			end

			CDTL3:SaveNewEntry(s, "buffs", true)
			table.insert(result.made, s["name"])
		end

		-- on you right now: show it at once, as unticking Ignored does
		if CDTL3.db.profile.global["buffs"]["enabled"] and (s["bCD"] or 0) > 0
				and not CDTL3:GetExistingCooldown(s["name"], "buffs") and CDTL3:AuraExists("player", s["name"]) then
			CDTL3:CreateCooldown(CDTL3:GetUID(), "buffs", s)
		end
	end

	result.notTracked = CDTL3:BuffsNotInTrackedBars(bars) or {}
	return result
end

-- the highlight effects' animation groups (Cooldown.lua), each made once per icon
local HIGHLIGHT_GROUPS = { "agGlow", "agBorderPulse", "agPulse", "agIconPulse", "agBounce", "agShake", "agScale" }

function CDTL3:RemoveHighlights(f, s)
	if not f.hl then
		return
	end

	for i = 1, #HIGHLIGHT_GROUPS do
		local g = f.hl[HIGHLIGHT_GROUPS[i]]
		if g then
			g:Stop()
		end
	end

	-- the glow and the plain edge (Cooldown.lua), when made
	if f.hl.glow then
		f.hl.glow:Hide()
	end
	if f.hl.edge then
		CDTL3.IconFx.RingShow(f.hl.edge, false)
	end
	if f.hl.roundEdge then
		f.hl.roundEdge:Hide()
	end
	f.hl:SetBackdropBorderColor(
		s["icons"]["highlight"]["border"]["color"]["r"],
		s["icons"]["highlight"]["border"]["color"]["g"],
		s["icons"]["highlight"]["border"]["color"]["b"],
		0
	)
	f.hl.tx:SetColorTexture( 1, 1, 1, 0 )
end

function CDTL3:ScanSharedSpellCooldown(initialName, initialDuration)
	local sd = CDTL3:GetAllSpellData(CDTL3.player["class"], CDTL3.player["race"])

	-- SPELLS
	for _, spell in pairs(sd) do
		if spell["name"] ~= initialName then
			--local start, duration, enabled, _ = GetSpellCooldown(spell["id"])
			local _, duration = CDTL3:GetSpellCooldown(spell["id"])
			local difference = math.abs(initialDuration - duration)

			if difference < 0.2 then
				if duration > 1.5 then
					local ef = CDTL3:GetExistingCooldown(spell["name"], "spells")
					if ef then
						CDTL3:SendToLane(ef)
						CDTL3:SendToBarFrame(ef)
					else
						local s = CDTL3:GetSpellSettings(spell["name"], "spells")
						if s then
							if not CDTL3:IsIgnored(s, "spells") then
								if CDTL3.db.profile.global["spells"]["enabled"] then
									CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)
								end

								if not CDTL3:IsUsedBy("spells", spell["id"]) then
									CDTL3:AddUsedBy("spells", spell["id"], CDTL3.player["guid"])
								end
							end
						else
							local _, icon = CDTL3:GetSpellInfo(spell["id"])

							local entry = CDTL3:ApplyEntryDefaults({
								id = spell["id"],
								bCD = duration * 1000,	-- bCD is milliseconds everywhere else
								name = spell["name"],
								type = "spells",
								icon = icon,
							}, "spells")
							entry["link"] = CDTL3:GetSpellLink(spell["id"])
							entry["ignored"] = CDTL3:IgnoredByDefault("spells", entry["bCD"])

							CDTL3:SaveNewEntry(entry, "spells")
						end
					end
				end
			end
		end
	end
end

-- A known spell with a saved entry: put it on its lane and bar frame, or start a cooldown for it,
-- unless it is ignored
function CDTL3:ShowKnownSpell(s, spellName)
	if not CDTL3:IsIgnored(s, "spells") then
		local ef = CDTL3:GetExistingCooldown(s["name"], "spells")
		if ef then
			CDTL3:SendToLane(ef)
			CDTL3:SendToBarFrame(ef)
			CDTL3:CheckEdgeCases(spellName)
		else
			if CDTL3.db.profile.global["spells"]["enabled"] then
				CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)
				CDTL3:CheckEdgeCases(spellName)

				if CDTL3:IsUsedBy("spells", s["id"]) then
					--CDTL3:Print("USEDBY MATCH: "..s["id"])
				else
					CDTL3:AddUsedBy("spells", s["id"], CDTL3.player["guid"])
				end
			end
		end
	end
end

-- One spellbook spell: if it is cooling down, show it (saving a new entry when it has none)
local function ScanSpell(spellName, spellID)
	local _, duration = CDTL3:GetSpellCooldown(spellID)

	if duration > 1.5 then
		if CDTL3.db.profile.global["debugMode"] then
			CDTL3:Print("COOLINGDOWN: "..tostring(spellName).." - "..spellID)
		end

		local s = CDTL3:GetSpellSettings(spellName, "spells")
		if s then
			CDTL3:ShowKnownSpell(s, spellName)
		else
			local infoName, icon = CDTL3:GetSpellInfo(spellID)
			s = CDTL3:NewSpellEntry(spellID, infoName, icon, "spells")
			if CDTL3:SaveNewEntry(s, "spells") then
				CDTL3:CheckEdgeCases(infoName)
			end
		end
	end
end

function CDTL3:ScanCurrentCooldowns(class, race)
	-- SPELLS
	if CDTL3.retailAPI then
		for i = 1, C_SpellBook.GetNumSpellBookSkillLines() do
			local skillLineInfo = C_SpellBook.GetSpellBookSkillLineInfo(i)
			local offset, numSlots = skillLineInfo.itemIndexOffset, skillLineInfo.numSpellBookItems

			--local j = 1
			for j = offset + 1, offset + numSlots do
			--for j = offset + 1, numSlots do
				local spellName = C_SpellBook.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)
				local spellID = select(2,C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player))

				ScanSpell(spellName, spellID)
			end
		end
	else
		-- Classic clients only: the old spellbook calls (the other branch uses C_SpellBook)
		---@diagnostic disable-next-line: undefined-global
		for i = 1, GetNumSpellTabs() do
			---@diagnostic disable-next-line: undefined-global
			local offset, numSlots = select(3, GetSpellTabInfo(i))
			for j = offset + 1, offset + numSlots do
				---@diagnostic disable-next-line: undefined-global
				local spellName, _, spellID = GetSpellBookItemName(j, BOOKTYPE_SPELL)
				if spellID then
					ScanSpell(spellName, spellID)
				end
			end
		end
	end

	-- PET SPELLS
	--[[local numSpells, petToken = C_SpellBook.HasPetSpells()  -- nil if pet does not have spellbook, 'petToken' will usually be "PET"
	for i=1, numSpells do
		local petSpellName, petSubType = C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Pet)
		local spellID = select(2,C_SpellBook.GetSpellBookItemType(i, Enum.SpellBookSpellBank.Pet))
		print("petSpellName", petSpellName)  --like "Dash"
		print("petSubType", petSubType) -- like "Basic Ability" or "Pet Stance"
		print("spellID", spellId)
	end]]--

	-- ITEMS (equipped, then bags)
	for _, itemId in ipairs(private.CarriedItemIDs()) do
		local spellName, spellID = CDTL3.Compat.GetItemSpell(itemId)

		if spellName and CDTL3:IsValidItem(itemId) then
			local _, duration = CDTL3:GetItemCooldown(itemId)

			if duration and duration > 1.5 and not CDTL3:GetExistingCooldown(spellName, "items") then
				local s = CDTL3:GetSpellSettings(spellName, "items")
				if s then
					if not s["ignored"] then
						if CDTL3.db.profile.global["items"]["enabled"] then
							CDTL3:CreateCooldown(CDTL3:GetUID(),"items" , s)
						end

						if not CDTL3:IsUsedBy("items", s["id"]) then
							CDTL3:AddUsedBy("items", s["id"], CDTL3.player["guid"])
						end
					end
				else
					s = CDTL3:NewItemEntry(spellName, spellID, itemId, duration * 1000)
					s["ignored"] = CDTL3:IgnoredByDefault("items", s["bCD"])

					CDTL3:SaveNewEntry(s, "items")
				end
			end
		end
	end
end

-- BORDERS AND HIDDEN SIZES (GitHub issue 9). Blizzard's BackdropTemplate works out a border's edge
-- tiling from the frame's own size (Backdrop.lua SetupTextureCoordinates), on SetBackdrop and on every
-- size change. In combat a spell icon rides the game's timer bar (CombatTimers.lua), and the game hides
-- the size of anything hanging on that bar (GetWidth is "SecretWhenAnchoringSecret"), still for a moment
-- after it leaves: from 3.1.0 a bordered icon threw "attempt to perform arithmetic on local 'width'".
-- So a border keeps its backdrop table while its settings stay the same (SetBackdrop then does nothing),
-- and where sizes can be hidden each border frame gets its own SetupTextureCoordinates: it waits while
-- the size is hidden and tiles on the first frame the size reads plain.
private.AnchoringHidden = function(f)
	if f:IsAnchoringSecret() then
		return true
	end
	return false
end

private.SizeHidden = function(f)
	local ok, hidden = pcall(private.AnchoringHidden, f)
	return not ok or hidden
end

-- OnUpdate of a border that waits: tiles it on the first frame its size reads plain
private.RetileWhenPlain = function(f)
	if private.SizeHidden(f) then
		return
	end
	f.cdtl3Retile = nil
	f:SetScript("OnUpdate", nil)
	BackdropTemplateMixin.SetupTextureCoordinates(f)
end

private.BorderTexCoords = function(f)
	if private.SizeHidden(f) then
		if not f.cdtl3Retile then
			f.cdtl3Retile = true
			f:SetScript("OnUpdate", private.RetileWhenPlain)
		end
		return
	end
	if f.cdtl3Retile then
		f.cdtl3Retile = nil
		f:SetScript("OnUpdate", nil)
	end
	BackdropTemplateMixin.SetupTextureCoordinates(f)
end

function CDTL3:SetBorder(f, s)
	local inset = s["inset"]
	local padding = s["padding"]

	-- only clients that can hide a size have IsAnchoringSecret (Retail, Forever)
	if f.IsAnchoringSecret and BackdropTemplateMixin and BackdropTemplateMixin.SetupTextureCoordinates then
		f.SetupTextureCoordinates = private.BorderTexCoords
	end

	local bgFile = CDTL3.LSM:Fetch("background", "None")
	local edgeFile = CDTL3.LSM:Fetch("border", s["style"])
	local b = f.cdtl3Backdrop
	if not (b and b.bgFile == bgFile and b.edgeFile == edgeFile and b.edgeSize == s["size"] and b.insets.left == inset) then
		b = {
			bgFile = bgFile,
			edgeFile = edgeFile,
			tile = false,
			tileSize = 0,
			edgeSize = s["size"],
			insets = { left = inset, right = inset, top = inset, bottom = inset }
		}
		f.cdtl3Backdrop = b
	end
	f:SetBackdrop(b)
	f:SetBackdropBorderColor(
		s["color"]["r"],
		s["color"]["g"],
		s["color"]["b"],
		s["color"]["a"]
	)
	f:SetPoint("TOPLEFT", f:GetParent(), "TOPLEFT", -padding, padding)
	f:SetPoint("BOTTOMRIGHT", f:GetParent(), "BOTTOMRIGHT", padding, -padding)
end

-- Items are saved under their use-spell name AND item name; the item ID is the one key
-- that is always present on both the saved entry and the live cooldown.
function CDTL3:SetItemData(itemID, k, v)
	for _, e in pairs(CDTL3.db.profile.tables["items"]) do
		if e["itemID"] == itemID then
			e[k] = v
		end
	end
end

function CDTL3:SetSpellData(name, type, k, v)
	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:Print("DATASAVE: "..name.." - "..type.." - "..k..":"..tostring(v))
	end

	for _, e in pairs(CDTL3.db.profile.tables[type]) do
		if type == "items" then
			if e["itemName"] == name then
				e[k] = v
			end
		else
			if e["name"] == name then
				e[k] = v
			end
		end
	end
end

function CDTL3:ToggleDebug()
	local debugMode = CDTL3.db.profile.global["debugMode"]

	if debugMode then
		CDTL3.db.profile.global["debugMode"] = false
		CDTL3.debugFrame:Hide()

		for _, f in pairs(CDTL3.holders) do
			f:SetAlpha(0)
			f:Hide()
		end

		for _, f in pairs(CDTL3.lanes) do
			private.DebugOff(f)
		end

		for _, f in pairs(CDTL3.barFrames) do
			private.DebugOff(f)
		end

		for _, f in pairs(CDTL3.readyFrames) do
			private.DebugOff(f)
		end

		for _, f in pairs(CDTL3.cooldowns) do
			private.DebugOff(f.bar)
			private.DebugOff(f.icon)
		end

		CDTL3:Print(L["Debug Mode Disabled"])
	else
		CDTL3.db.profile.global["debugMode"] = true
		CDTL3.debugFrame:Show()

		-- holders are created hidden when debug is off, so alpha alone never showed them
		for _, f in pairs(CDTL3.holders) do
			f:SetAlpha(1)
			f:Show()
		end

		for _, f in pairs(CDTL3.lanes) do
			private.DebugOn(f)
		end

		for _, f in pairs(CDTL3.barFrames) do
			private.DebugOn(f)
		end

		for _, f in pairs(CDTL3.readyFrames) do
			private.DebugOn(f)
		end

		for _, f in pairs(CDTL3.cooldowns) do
			private.DebugOff(f.bar)
			private.DebugOff(f.icon)
		end

		CDTL3:Print(L["Debug Mode Enabled"])
	end
end

-- quiet: no chat line and no unlock popup (Edit Mode shows/hides the frames itself)
-- the base definition: Group.lua wraps it
---@diagnostic disable-next-line: duplicate-set-field
function CDTL3:ToggleFrameLock(quiet)
	local unlockFrames = CDTL3.db.profile.global["unlockFrames"]

	-- Guard: unlockFrame may be nil if OnEnable errored before CreateUnlockFrame ran.
	if not CDTL3.unlockFrame then
		CDTL3:Print(L["CDTL3: unlockFrame not ready — try reloading the UI."])
		return
	end

	if unlockFrames then
		CDTL3.db.profile.global["unlockFrames"] = false
		CDTL3.db.global.lockedOnce = true	-- the unlock box drops its how-to wording from now on
		CDTL3.unlockFrame:Hide()

		for _, f in pairs(CDTL3.lanes) do
			private.FrameLock(f)
			CDTL3:RefreshLane(f.number)
		end

		for _, f in pairs(CDTL3.barFrames) do
			private.FrameLock(f)
			CDTL3:RefreshBarFrame(f.number)
		end

		for _, f in pairs(CDTL3.readyFrames) do
			private.FrameLock(f)
			CDTL3:RefreshReady(f.number)
		end

		if not quiet then
			CDTL3:Print(L["Frames Locked"])
		end
	else
		CDTL3.db.profile.global["unlockFrames"] = true
		if not quiet then
			CDTL3.unlockFrame:Show()
		end

		for _, f in pairs(CDTL3.lanes) do
			private.FrameUnlock(f)
			CDTL3:RefreshLane(f.number)
		end

		for _, f in pairs(CDTL3.barFrames) do
			private.FrameUnlock(f)
			CDTL3:RefreshBarFrame(f.number)
		end

		for _, f in pairs(CDTL3.readyFrames) do
			private.FrameUnlock(f)
			CDTL3:RefreshReady(f.number)
		end

		if not quiet then
			CDTL3:Print(L["Frames Unlocked"])
		end
	end
end

function CDTL3:FrameLock(f)
	private.FrameLock(f)
end

function CDTL3:FrameUnlock(f)
	private.FrameUnlock(f)
end

function CDTL3:DebugOn(f)
	private.DebugOn(f)
end

function CDTL3:DebugOff(f)
	private.DebugOff(f)
end

function CDTL3:TableCopy(orig)
    local orig_type = type(orig)
    local copy

    if orig_type == 'table' then
		copy = {}

		for orig_key, orig_value in next, orig, nil do
			copy[CDTL3:TableCopy(orig_key)] = CDTL3:TableCopy(orig_value)
		end

		setmetatable(copy, CDTL3:TableCopy(getmetatable(orig)))
    else
        copy = orig
    end

    return copy
end

-- Import a string made by the Import/Export tab (or a lane's Copy this lane). Every stage is
-- checked and the data's shape is validated BEFORE anything is written, so a bad string changes nothing.
-- Imported data is copied INTO AceDB's existing profile tables: replacing the
-- CDTL3.db.profile reference only changed the in-memory view, so the import was lost on
-- /reload. Defaults are re-applied afterwards for keys an older export doesn't have.
local IMPORT_TABLE_TYPES = { "spells", "petspells", "items", "buffs", "debuffs", "offensives", "runes", "customs", "detected" }
local IMPORT_SETTINGS_KEYS = { "global", "lanes", "barFrames", "ready", "holders" }
local IMPORT_LIST_NAMES = { spells = "Spells", petspells = "Pet Spells", items = "Items", buffs = "Buffs", debuffs = "Debuffs",
	offensives = "Offensives", runes = "Runes", customs = "Custom", detected = "Detected" }
-- saved as the version text ("3.1.1") although its default is the number 0
local IMPORT_ANY_SCALAR = { previousVersion = true }
-- fields of a saved Filters entry that are read without a type check
local IMPORT_ENTRY_FIELDS = { usedBy = "table", color = "table", bCD = "number", customCDTime = "number" }

-- Does value have the shape of its defaults? Where the defaults hold a table it must be a table
-- (checked key by key, all the way down), where they hold a number it must be one too, where
-- they hold text a number will also do (a lane's mark texts are saved as ConvertTime gives
-- them: a number under H:MM:SS for marks under a minute), and where they hold true/false
-- anything but a table will do (it is only ever tested). Keys the defaults don't name (Edit
-- Mode layouts, the Filters entries) pass here.
local function FitsDefaults(value, default, key)
	if type(default) == "table" then
		if type(value) ~= "table" then
			return false
		end
		for k, v in pairs(value) do
			if default[k] ~= nil and not FitsDefaults(v, default[k], k) then
				return false
			end
		end
		return true
	end

	if IMPORT_ANY_SCALAR[key] or type(default) == "boolean" then
		return type(value) ~= "table"
	end

	if type(default) == "string" then
		return type(value) == "string" or type(value) == "number"
	end

	return type(value) == type(default)
end

-- Every Filters list is a table of entries (some code loops over all of them), every entry is
-- a table, and the entry fields read without a check have the right type
local function FitsFilterLists(tables)
	for _, list in pairs(tables) do
		if type(list) ~= "table" then
			return false
		end
		for _, entry in pairs(list) do
			if type(entry) ~= "table" then
				return false
			end
			for field, kind in pairs(IMPORT_ENTRY_FIELDS) do
				if entry[field] ~= nil and type(entry[field]) ~= kind then
					return false
				end
			end
		end
	end

	return true
end

local function ReplaceContents(target, source)
	for k in pairs(target) do
		target[k] = nil
	end
	for k, v in pairs(source) do
		target[k] = v
	end
end

-- SHARE STRINGS (feature panel card 34)
-- Exports start with "!CDTL3:2!" and wrap what they carry with where it was made:
-- { kind = ALL / SETTINGS / CDDATA / LANE, client, toc, version, data [, lane] }. A string
-- without the header is an older export (the data itself) and imports exactly as before.
-- The Import box shows CDTL3:ImportPreview's text with Accept / Cancel before ImportHandler
-- writes anything.
local SHARE_HEADER, SHARE_FORMAT = "!CDTL3:2!", 2
local SHARE_KINDS = { ALL = "All Settings and Data", SETTINGS = "CDTL3 Settings Only", CDDATA = "Cooldown Data Only", LANE = "One lane", LOOK = "A saved look" }
local SHARE_CLIENTS = { Retail = "Retail", Forever = "WoW: Forever", Mists = "MoP Classic", TBC = "TBC Anniversary", Era = "Classic Era" }
-- lane settings a lane string leaves out: where the lane sits belongs to the player's own screen
local SHARE_LANE_SKIP = { enabled = true, posX = true, posY = true, relativeTo = true, editMode = true }
local SHARE_LIST_WORDS = {
	spells = { "spell", "spells" }, petspells = { "pet spell", "pet spells" }, items = { "item", "items" },
	buffs = { "buff", "buffs" }, debuffs = { "debuff", "debuffs" }, offensives = { "offensive", "offensives" },
	runes = { "rune", "runes" }, customs = { "custom timer", "custom timers" }, detected = { "detected spell", "detected spells" },
}
-- the Filters lists whose entries are spell IDs, which another client may not have
local SHARE_SPELL_LISTS = { "spells", "petspells", "buffs", "debuffs", "offensives" }

local function ShareClient()
	if CDTL3.isForever then
		return "Forever"
	end
	local toc = CDTL3.tocversion or 0
	if toc >= 110000 then
		return "Retail"
	elseif toc >= 50000 then
		return "Mists"
	elseif toc >= 20000 then
		return "TBC"
	end
	return "Era"
end

local function EncodeShare(t)
	local LibDeflate = LibStub:GetLibrary("LibDeflate")
	local serialized = LibStub:GetLibrary("AceSerializer-3.0"):Serialize(t)
	return LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(serialized))
end

-- DEFLATE + SERIALIZE back (any stage can fail on a truncated / mistyped string)
local function DecodeShare(text)
	local LibDeflate = LibStub:GetLibrary("LibDeflate")
	local ok, unprintable = pcall(LibDeflate.DecodeForPrint, LibDeflate, text)
	if not ok or not unprintable then
		return nil
	end
	local inflated
	ok, inflated = pcall(LibDeflate.DecompressDeflate, LibDeflate, unprintable)
	if not ok or not inflated then
		return nil
	end
	local success, data = LibStub:GetLibrary("AceSerializer-3.0"):Deserialize(inflated)
	if not success or type(data) ~= "table" then
		return nil
	end
	return data
end

-- What an export carries: Cooldown Data Only = the Filters lists, CDTL3 Settings Only = the
-- profile with every Filters list emptied, All Settings and Data = the whole profile, a lane =
-- every value of that lane (defaults included, so it fits any lane) except where it sits
local function ExportData(mode, lane)
	if mode == "LANE" then
		local values = CDTL3:GetFrameSettings("lanes", lane) or {}
		for k in pairs(SHARE_LANE_SKIP) do
			values[k] = nil
		end
		return values
	elseif mode == "CDDATA" then
		return CDTL3:TableCopy(CDTL3.db.profile.tables)
	end

	local t = CDTL3:TableCopy(CDTL3.db.profile)
	if mode == "SETTINGS" then
		t.tables = t.tables or {}
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			t.tables[key] = {}
		end
	end
	return t
end

-- The text for the Export box (mode = ALL, SETTINGS or CDDATA) or a lane's Copy this lane box
-- (mode = LANE, lane = 1-3)
function CDTL3:ExportString(mode, lane, look)
	if mode ~= "LANE" and mode ~= "CDDATA" and mode ~= "SETTINGS" and mode ~= "LOOK" then
		mode = "ALL"
	end
	local wrapper = { kind = mode, client = ShareClient(), toc = CDTL3.tocversion, version = CDTL3.version,
		data = mode == "LOOK" and CDTL3:TableCopy(look or {}) or ExportData(mode, lane) }
	if mode == "LANE" then
		wrapper.lane = lane
	end

	return SHARE_HEADER..EncodeShare(wrapper)
end

-- A pasted string -> { data, meta } (meta is nil for an older string), or nil and what's wrong
local function ReadShare(importString)
	local text = tostring(importString or ""):gsub("^%s+", "")
	if text:sub(1, 7) ~= "!CDTL3:" then
		local data = DecodeShare(text)
		if not data then
			return nil, L["All data (was invalid import string)"]
		end
		return { data = data }
	end

	local fmt, body = text:match("^!CDTL3:(%d+)!(.*)$")
	if not fmt then
		return nil, L["All data (was invalid import string)"]
	end
	if tonumber(fmt) > SHARE_FORMAT then
		return nil, L["All data (made by a newer CDTL3: update CDTL3, then import it)"]
	end
	local wrapper = DecodeShare(body)
	if not wrapper or type(wrapper.data) ~= "table" or not SHARE_KINDS[wrapper.kind] then
		return nil, L["All data (was invalid import string)"]
	end
	if wrapper.kind == "LANE" and not (wrapper.lane == 1 or wrapper.lane == 2 or wrapper.lane == 3) then
		return nil, L["Lane settings (was invalid import string)"]
	end

	local version = wrapper.version
	return { data = wrapper.data, meta = {
		kind = wrapper.kind,
		lane = wrapper.lane,
		client = type(wrapper.client) == "string" and wrapper.client or nil,
		version = (type(version) == "string" or type(version) == "number") and tostring(version) or nil,
	} }
end

-- A pasted look string (Quick Style > Import a look) -> the look, or nil and what's wrong
function CDTL3:ReadLookString(text)
	local plan = ReadShare(text)
	if not plan or not plan.meta or plan.meta.kind ~= "LOOK" then
		return nil, L["That isn't a CDTL3 look string."]
	end
	local look = CDTL3:CleanLook(plan.data)
	if not look then
		return nil, L["That look string is damaged."]
	end
	return look
end

-- a cooldown-data export is the tables map itself; a full/settings export nests it
local function ShareTables(data)
	return type(data.tables) == "table" and data.tables or data
end

-- Is the string usable in this import mode? nil when it is, else what's wrong. Checks only:
-- nothing is written, so a bad string changes nothing.
local function CheckShare(plan, mode)
	-- the registered defaults always have a profile table
	local data, defaults = plan.data, CDTL3.db.defaults.profile --[[@as table]]

	if plan.meta and plan.meta.kind == "LOOK" then
		return L["That is a saved look: paste it under Quick Style > Import a look."]
	end

	if plan.meta and plan.meta.kind == "LANE" then
		if not FitsDefaults(data, defaults.lanes["lane"..plan.meta.lane]) then
			return L["Lane settings (malformed)"]
		end
		return nil
	end

	if mode == "ALL" then
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			if type(data[key]) ~= "table" then
				return L["All data (not a full CDTL3 export)"]
			end
		end
		if not FitsDefaults(data, defaults) or (data.tables ~= nil and not FitsFilterLists(data.tables)) then
			return L["All data (malformed)"]
		end

	elseif mode == "SETTINGS" then
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			if type(data[key]) ~= "table" then
				return L["Settings data (not a CDTL3 settings export)"]
			end
		end
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			if not FitsDefaults(data[key], defaults[key], key) then
				return L["Settings data (malformed)"]
			end
		end

	elseif mode == "CDDATA" then
		local tables = ShareTables(data)
		if not FitsFilterLists(tables) then
			return L["Cooldown data (malformed)"]
		end
		local found = 0
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			if type(tables[key]) == "table" and next(tables[key]) then
				found = found + 1
			end
		end
		if found == 0 then
			-- e.g. a "Settings Only" export, whose cooldown lists are deliberately empty
			return L["Cooldown data (the string contains no cooldown data)"]
		end
	end

	return nil
end

-- Every entry an import brings in is this character's too, kept for its other characters, so
-- it is listed in this character's Filters at once instead of after its first cast or trigger
local function ClaimEntries(list)
	if not CDTL3.player["guid"] then
		CDTL3:GetCharacterData()
	end
	local guid = CDTL3.player["guid"]
	if not guid or type(list) ~= "table" then
		return
	end

	for _, entry in pairs(list) do
		if type(entry) == "table" then
			if type(entry["usedBy"]) ~= "table" then
				entry["usedBy"] = {}
			end
			local mine = false
			for _, g in pairs(entry["usedBy"]) do
				if g == guid then
					mine = true
				end
			end
			if not mine then
				table.insert(entry["usedBy"], guid)
			end
		end
	end
end

-- Write a checked string into the current profile
local function ApplyShare(plan, mode)
	local profile, data = CDTL3.db.profile, plan.data

	if plan.meta and plan.meta.kind == "LANE" then
		CDTL3:WriteFrameSettings("lanes", plan.meta.lane, data)

	elseif mode == "ALL" then
		-- keep this profile's import/export choices, and each of its Filters lists the string
		-- leaves empty: a "Settings Only" export empties them all, and importing one this way
		-- wiped every character's spells, Customs and Custom CD Times on the profile
		local exportMode, keepImportMode = profile.global["exportMode"], profile.global["importMode"]
		local own = profile.tables
		ReplaceContents(profile, data)
		profile.global["exportMode"], profile.global["importMode"] = exportMode, keepImportMode

		if type(profile.tables) ~= "table" then
			profile.tables = {}
		end
		local carried, kept, lists = 0, {}, {}
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			local theirs = profile.tables[key]
			if type(theirs) == "table" and next(theirs) then
				carried = carried + 1
				ClaimEntries(theirs)
				lists[key] = theirs
			elseif type(own) == "table" and type(own[key]) == "table" and next(own[key]) then
				profile.tables[key] = own[key]
				table.insert(kept, IMPORT_LIST_NAMES[key])
			end
		end
		-- while sharing, the lists it carries go into the shared ones (Profiles.lua)
		if CDTL3.Profiles then
			CDTL3.Profiles.ImportLists(own, lists)
		end
		-- while sharing, the lists that stay are the ones all your characters share
		local sharing = CDTL3.Profiles and CDTL3.Profiles.Sharing()
		if carried == 0 then
			CDTL3:Print(sharing and L["This string has no Filters lists (a Settings Only export leaves them empty): its settings were imported and the shared Filters lists were kept."] or L["This string has no Filters lists (a Settings Only export leaves them empty): its settings were imported and this profile's own Filters lists were kept."])
		elseif #kept > 0 then
			CDTL3:Print(string.format(sharing and L["Imported. The shared %s Filters lists were kept: the string's were empty."] or L["Imported. This profile's own %s Filters lists were kept: the string's were empty."], table.concat(kept, ", ")))
		end

	elseif mode == "SETTINGS" then
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			profile[key] = data[key]
		end

	elseif mode == "CDDATA" then
		local tables, lists = ShareTables(data), {}
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			if type(tables[key]) == "table" then
				ClaimEntries(tables[key])
				lists[key] = tables[key]
			end
		end
		-- while sharing they go into the shared lists (Profiles.lua); otherwise each replaces this profile's
		if not (CDTL3.Profiles and CDTL3.Profiles.ImportLists(profile.tables, lists)) then
			for key, list in pairs(lists) do
				profile.tables[key] = list
			end
		end
	end
end

-- "Import into a new profile": Imported, Imported 2, ...
local function NewProfileName()
	local taken = {}
	for _, name in ipairs((CDTL3.db:GetProfiles())) do
		taken[name] = true
	end
	local name, n = "Imported", 1
	while taken[name] do
		n = n + 1
		name = "Imported "..n
	end
	return name
end

local function IntoNewProfile()
	return CDTL3.db.global and CDTL3.db.global["importNewProfile"] == true
end

local function Plural(n, words)
	return n.." "..(n == 1 and words[1] or words[2])
end

-- text from someone else's string, shown as plain text (no colour codes or links)
local function Plain(s, max)
	s = tostring(s or ""):gsub("%c", " ")
	if max and #s > max then
		s = s:sub(1, max).."..."
	end
	return (s:gsub("|", "||"))
end

-- True when this client has no spell with that ID (spell data, not the spellbook: another
-- class's spells exist, another game's may not)
local function SpellMissing(id)
	if type(id) ~= "number" or id <= 0 then
		return false
	end
	local ok, name = pcall(CDTL3.GetSpellInfo, CDTL3, id)
	return ok and (name == nil or name == "")
end

local function CountEntries(t)
	local n = 0
	for _ in pairs(t) do
		n = n + 1
	end
	return n
end

-- "All Settings and Data: 3 lanes, 41 spells, 6 buffs, made on 3.1.1 Retail.", then warnings
-- (another client, spells this client doesn't have) and where it goes
local function PreviewText(plan, mode)
	local data, meta = plan.data, plan.meta
	local kind = meta and meta.kind
	-- the registered defaults always have a profile table
	local defaults = CDTL3.db.defaults.profile --[[@as table]]
	local lines, parts = {}, {}
	local lists, carries

	if kind == "LANE" then
		parts[1] = "settings for lane "..meta.lane..' ("'..Plain(data.name, 40)..'")'
	else
		if (mode == "ALL" or mode == "SETTINGS") and type(data.lanes) == "table" then
			local on = 0
			for n = 1, 3 do
				local lane, default = data.lanes["lane"..n], defaults.lanes["lane"..n]
				local enabled
				if type(lane) == "table" then
					enabled = lane.enabled
				end
				if enabled == nil and default then
					enabled = default.enabled
				end
				if enabled then
					on = on + 1
				end
			end
			parts[#parts + 1] = Plural(on, { "lane", "lanes" })
		end
		if mode == "ALL" then
			lists = type(data.tables) == "table" and data.tables or nil
		elseif mode == "CDDATA" then
			lists = ShareTables(data)
		end
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			local n = lists and type(lists[key]) == "table" and CountEntries(lists[key]) or 0
			if n > 0 then
				parts[#parts + 1] = Plural(n, SHARE_LIST_WORDS[key])
				carries = true
			end
		end
	end
	-- while sharing, the lists it carries go into the ones every character uses (Profiles.lua)
	local shared = carries and CDTL3:SharingEntries()
	local sharedLine = "Sharing is on, so the Filters lists all your characters share change: each entry in the string replaces the one of the same name, and the others stay."

	local made
	if meta then
		made = "made on "..(meta.version and Plain(meta.version, 12) or "an unknown version").." "..(SHARE_CLIENTS[meta.client] or Plain(meta.client or "?", 20))
	else
		made = "made on an older CDTL3 (the string doesn't say which version or game)"
	end
	local what = kind == "LANE" and SHARE_KINDS.LANE or SHARE_KINDS[mode] or "Import"
	lines[1] = what..": "..(#parts > 0 and table.concat(parts, ", ")..", " or "")..made.."."

	local here = ShareClient()
	if meta and meta.client and meta.client ~= here then
		lines[#lines + 1] = "|cffff9900Made on "..(SHARE_CLIENTS[meta.client] or Plain(meta.client, 20)).." and this is "..SHARE_CLIENTS[here]..": spells, textures and fonts can differ.|r"
	end

	if lists then
		local names = {}
		for _, key in ipairs(SHARE_SPELL_LISTS) do
			if type(lists[key]) == "table" then
				for _, entry in pairs(lists[key]) do
					if type(entry) == "table" and SpellMissing(entry["id"]) then
						names[#names + 1] = Plain(entry["name"] or ("spell "..tostring(entry["id"])), 30)
					end
				end
			end
		end
		if #names > 0 then
			table.sort(names)
			local shown = {}
			for i = 1, math.min(#names, 8) do
				shown[i] = names[i]
			end
			local more = #names > #shown and (" and "..(#names - #shown).." more") or ""
			lines[#lines + 1] = "|cffff9900"..Plural(#names, { "spell", "spells" }).." in it "..(#names == 1 and "isn't" or "aren't")
				.." in this client: "..table.concat(shown, ", ")..more..". They are imported but can't show here.|r"
		end
	end

	local current = Plain(CDTL3.db:GetCurrentProfile(), 40)
	if IntoNewProfile() then
		lines[#lines + 1] = "Goes into a new profile, "..NewProfileName()..". This profile ("..current..") stays as it is."
		if shared then
			lines[#lines + 1] = sharedLine
		end
	elseif kind == "LANE" then
		lines[#lines + 1] = "Replaces lane "..meta.lane.."'s settings in this profile ("..current.."), except its name, position and whether it's on."
	elseif mode == "SETTINGS" then
		lines[#lines + 1] = "Replaces this profile's settings ("..current.."). Its Filters lists stay."
	elseif mode == "CDDATA" then
		lines[#lines + 1] = shared and sharedLine.." Settings stay."
			or "Replaces the Filters lists the string has in this profile ("..current.."). Settings stay."
	elseif shared then
		lines[#lines + 1] = "Replaces this profile's settings ("..current..")."
		lines[#lines + 1] = sharedLine
	else
		lines[#lines + 1] = "Replaces this profile's settings and the Filters lists the string has ("..current..")."
	end
	lines[#lines + 1] = "Import it?"

	return table.concat(lines, "\n\n")
end

-- The Import box asks first: the preview text for its Accept / Cancel box, or false when the
-- string can't be imported (then the import prints why and writes nothing). Never errors, so
-- the Import box can't skip the question.
function CDTL3:ImportPreview(importString)
	local ok, text = pcall(function()
		local mode = CDTL3.db.profile.global["importMode"]
		local plan = ReadShare(importString)
		if not plan or CheckShare(plan, mode) then
			return false
		end
		return PreviewText(plan, mode)
	end)
	if not ok then
		return L["Import this string?"]
	end

	return text
end

function CDTL3:ImportHandler(importString)
	local function Fail(what)
		CDTL3:Print(L["There was an error importing the data!"])
		CDTL3:Print("  -"..what)
		return nil
	end

	local plan, why = ReadShare(importString)
	if not plan then
		return Fail(why)
	end
	local mode = CDTL3.db.profile.global["importMode"]
	why = CheckShare(plan, mode)
	if why then
		local kind = plan.meta and plan.meta.kind
		if kind == "LOOK" then
			-- one clear line: where a look string goes
			CDTL3:Print(why)
			return nil
		end
		Fail(why)
		if kind and kind ~= "LANE" and kind ~= mode then
			CDTL3:Print(string.format(L["  This string is a \"%s\" export: pick that under Import and paste it again."], SHARE_KINDS[kind]))
		end
		return nil
	end

	-- Import into a new profile: made only now that the string checked out; it gets the
	-- import/export choices of the profile the player was on
	local from, newName = CDTL3.db:GetCurrentProfile(), nil
	if IntoNewProfile() then
		local g = CDTL3.db.profile.global
		local exportMode, importMode = g["exportMode"], g["importMode"]
		newName = NewProfileName()
		CDTL3.db:SetProfile(newName)
		CDTL3.db.profile.global["exportMode"], CDTL3.db.profile.global["importMode"] = exportMode, importMode
	end

	ApplyShare(plan, mode)

	-- re-apply defaults for anything an older export lacks, then rebuild everything
	CDTL3.db:RegisterDefaults(CDTL3.db.defaults)
	CDTL3:RefreshConfig()

	if newName then
		CDTL3:Print(string.format(L["Imported into a new profile, %s. %s is unchanged: switch back on the Profiles tab."], newName, from))
	end

	return nil
end

private.DebugOff = function(f)
	f.db:Hide()

	if CDTL3.db.profile.global["unlockFrames"] then
		private.FrameUnlock(f)
	end
end

private.DebugOn = function(f)
	f.db.text:SetText(f:GetName())
	f.db:Show()
end

private.FrameLock = function(f)
	f:SetMovable(false)
	f:EnableMouse(false)

	f.db.text:SetText(f.name)

	f.db:Hide()

	if CDTL3.db.profile.global["debugMode"] then
		private.DebugOn(f)
	end
end

private.FrameUnlock = function(f)
	f:SetMovable(true)
	f:EnableMouse(true)

	f.db.text:SetText(f.name)

	f.db:Show()
end