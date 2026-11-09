--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}

-- NEW SAVED ENTRIES
-- Everything that discovers a spell/item/aura/rune for the first time builds its saved
-- entry here, so the per-type Filters -> Defaults and the ignore rule apply the same way
-- whichever event or scan found it.

-- Per-type defaults (lane, bar frame, ready frame, shown by default); owned by this character
function CDTL3:ApplyEntryDefaults(s, type)
	local d = CDTL3.db.profile.global[type]

	s["lane"] = d["defaultLane"]
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
-- Returns the new cooldown frame, if one was made.
function CDTL3:SaveNewEntry(s, type)
	-- the combat log may already have told us the school (it can arrive before the cast event)
	s["school"] = s["school"] or (CDTL3.spellSchools and CDTL3.spellSchools[s["name"]])

	table.insert(CDTL3.db.profile.tables[type], s)

	if not s["ignored"] and CDTL3.db.profile.global[type]["enabled"] then
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
		local secretOK, aurasSecret = pcall(function()
			if C_Secrets and C_Secrets.ShouldAurasBeSecret then
				return C_Secrets.ShouldAurasBeSecret() and true or false
			end
			return false
		end)
		if not secretOK or aurasSecret then
			return nil, true
		end

		return nil
	end

	-- the scan hit a secret value: can't tell whether the aura is there
	return nil, true
end

function CDTL3:Autohide(f, s)
	local fAlpha = 1
	if s then
		fAlpha = s["alpha"]
	end

	--CDTL3:Print(fAlpha)

	-- Hide out of combat: every frame fades while you're out of combat, while detection keeps
	-- running (a cooldown started on the last pull is still tracked and shown on the next one).
	-- Unlock, Edit Mode (which unlocks the frames), debug and test mode all win over it.
	local gl = CDTL3.db.profile.global
	-- LOCAL PATCH (Zippy, 2026-11-09): Hide while casting fades the frames the same way while the player
	-- casts or channels (CDTL3.casting), with the same exceptions.
	local hideNow = (gl["hideOutOfCombat"] and not CDTL3.combat)
			or (gl["hideWhileCasting"] and CDTL3.casting)
	if hideNow and not CDTL3.testing
			and not gl["unlockFrames"] and not gl["debugMode"] then
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
	-- 0.3 s fade, e.g. an early interrupt). Stop the fade-out it started, or it would finish at
	-- alpha 0 and nothing would show the frame again.
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
function CDTL3:ApplyCombatVisibility()
	-- LOCAL PATCH (Zippy, 2026-11-09): also re-applied on cast edges for Hide while casting
	local gl = CDTL3.db.profile.global
	if not gl["hideOutOfCombat"] and not gl["hideWhileCasting"] then return end

	-- LOCAL PATCH (Zippy, 2026-11-09): refresh by frame number, not list index (the lists hold only
	-- created frames in creation order, see RefreshConfig)
	for _, f in pairs(CDTL3.lanes) do
		CDTL3:RefreshLane(f.number)
	end
	for _, f in pairs(CDTL3.barFrames) do
		CDTL3:RefreshBarFrame(f.number)
	end
	for i = 1, 3 do
		if _G["CDTL3_Ready_" .. i] then
			CDTL3:RefreshReady(i)
		end
	end
end

function CDTL3:CheckEdgeCases(spellName)
	-- VANISH SHOULD ALSO SPAWN A STEALTH ICON/BAR
	if spellName == "Vanish" then
		local s = CDTL3:GetSpellSettings("Stealth", "spells")
		if s then
			if not s["ignored"] then
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
			-- built for the Classic lists; MoP/retail list Stealth since 3.0.12 but keep the old behaviour
			s = CDTL3:GetSpellData(0, "Stealth")
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
			if not s["ignored"] then
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
			s = CDTL3:GetSpellData(0, "Shadowmeld")
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
					local s = CDTL3:GetSpellSettings(secondarySpellName, "spells")
					if s then
						if not s["ignored"] then
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
						s = CDTL3:GetSpellData(0, secondarySpellName)
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
			
			local s = CDTL3:GetSpellSettings(secondarySpellName, "spells")
			if s then
				if not s["ignored"] then
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
				s = CDTL3:GetSpellData(0, secondarySpellName)
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

function CDTL3:ConvertTime(raw, style)
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
			t = tonumber(string.format("%.0f", raw))
		else
			t = tonumber(string.format("%.1f", raw))
		end
	end
	
	return t
end

function CDTL3:GenerateTestCooldowns()
    local testingType = CDTL3.db.profile.global["testingType"]
    local testingNumber = CDTL3.db.profile.global["testingNumber"]
    local testingMinTime = CDTL3.db.profile.global["testingMinTime"]
    local testingMaxTime = CDTL3.db.profile.global["testingMaxTime"]
    local testingLoop = CDTL3.db.profile.global["testingLoop"]

    local timeRange = testingMaxTime - testingMinTime
    local increment = timeRange / (testingNumber - 1)

    local timeCurrent = testingMinTime
    for i = 1, testingNumber do
        if CDTL3.db.profile.global["debugMode"] then
            CDTL3:Print("TESTING: "..i.." of "..testingNumber.." ("..timeCurrent.."s)")
        end

        local data = CDTL3:GetTestTableData(testingType, timeCurrent, i)
        local newCD = CDTL3:CreateCooldown(CDTL3:GetUID(), "testing", data)
        table.insert(CDTL3.cooldowns, newCD)

        timeCurrent = timeCurrent + increment
    end
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
		local _, engClass, _, engRace, gender, name, server = GetPlayerInfoByGUID(playerGUID)
		
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
	local readableTimeLeft = t

	if t > 60 then
		readableTimeLeft = math.floor(t*math.pow(10,0)+0.5) / math.pow(10,0)
		
		local minutes = tostring(math.floor(readableTimeLeft / 60))
		local seconds = readableTimeLeft % 60
		
		if seconds >= 10 then
			seconds = tostring(seconds)
		elseif seconds > 0 then
			seconds = tostring("0"..seconds)
		else
			seconds = "00"
		end
		
		readableTimeLeft = minutes..":"..seconds
		
	elseif t > 10 then
		readableTimeLeft = tonumber(string.format("%.0f", readableTimeLeft))
	else
		readableTimeLeft = tonumber(string.format("%.1f", readableTimeLeft))
		if readableTimeLeft == math.floor(readableTimeLeft) then
			readableTimeLeft = readableTimeLeft..".0"
		end
	end
	
	return readableTimeLeft
end

function CDTL3:GetTestTableData(testType, bCD, number)
    local data = {}
    local testType = testType:lower()
    local nameType = testType:gsub("^%l", string.upper)
          nameType = nameType:sub(1, -2)

    local count = 0
    for _, e in pairs(CDTL3.icons["era"]) do
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
    data["testType"] = testType
    data["enabled"] = true
    data["pinned"] = false
    data["highlight"] = false
    data["ignored"] = false

	data["lane"] = CDTL3.db.profile.global[testType]["defaultLane"]
	data["barFrame"] = CDTL3.db.profile.global[testType]["defaultBar"]
	data["readyFrame"] = CDTL3.db.profile.global[testType]["defaultReady"]

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
			pcall(function()
				maxCharges = data["maxCharges"] + 0
			end)
			pcall(function()
				local cc, cs, cd = data["currentCharges"], data["cooldownStartTime"], data["cooldownDuration"]
				if cc + cs + cd >= 0 then
					currentCharges   = cc
					cooldownStart    = cs
					cooldownDuration = cd
				end
			end)
		end
	else
		currentCharges, maxCharges, cooldownStart, cooldownDuration = GetSpellCharges(id)
	end
	
	return currentCharges, maxCharges, cooldownStart, cooldownDuration
end

-- Item cooldowns can be SECRET on Midnight / WoW: Forever, like spell cooldowns. These
-- return real numbers, or nil when the values are secret so callers skip the refresh
-- and keep counting down from what they already have.
local function RealCooldown(start, duration, enabled)
	local ok = pcall(function()
		return start + duration >= 0
	end)

	if ok then
		return start, duration, enabled
	end
end

function CDTL3:GetItemCooldown(itemID)
	return RealCooldown(C_Container.GetItemCooldown(itemID))
end

function CDTL3:GetInventoryItemCooldown(slot)
	return RealCooldown(GetInventoryItemCooldown("player", slot))
end

function CDTL3:GetSpellCooldown(id)
	-- Midnight 12.x: data["startTime"] and data["duration"] are "secret" private values
	-- that cannot be compared or used in arithmetic from insecure addon code.
	-- Fix: wrap in anonymous pcall; on failure, fall back to event-tracked cast time
	-- + GetSpellBaseCooldown() (static spell data, not a runtime secret value).
	local start    = 0
	local duration = 0
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
				local ok = pcall(function()
					if data["duration"] and data["duration"] > 0 then
						start    = data["startTime"]
						duration = data["duration"]
					end
				end)

				-- isActive is also true during the global cooldown. When the timing is secret
				-- the fallback below would invent a ~1.6s cooldown for every spell on the GCD,
				-- so a spell that is only GCD-locked reports no cooldown. (isOnGCD is
				-- documented as never secret; checked inside a pcall anyway.)
				local gcdOK, onGCD = pcall(function()
					return data["isOnGCD"] == true
				end)

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
	for _, e in pairs(CDTL3.db.profile.tables[type]) do
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

	if CDTL3.retailAPI then
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
				local start, duration, enabled = CDTL3:GetSpellCooldown(spellID)
				if duration and duration > 1.5 then
					CDTL3:SendToLane(cd)
					CDTL3:SendToBarFrame(cd)
				end
			elseif cd.data and cd.data["currentCD"] then
				cd.data["currentCD"] = 0
			end
		end
	end
end

function CDTL3:RecycleOffensiveCD()
	for k, child in ipairs(CDTL3.cooldowns) do
		if child.data["type"] == "offensives" then
			if child.data["currentCD"] < 0 then
				return child
			end
		end
	end
	
	return nil
end

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
	
	if CDTL3.db.profile.global["unlockFrames"] then
		CDTL3.unlockFrame:Show()
	end

	CDTL3:Cleanup()
end

function CDTL3:RemoveHighlights(f, s)
	if f.hl.agBorderPulse then
		f.hl.agBorderPulse:Stop()
	end
	
	if f.hl.agPulse then
		f.hl.agPulse:Stop()
	end
	
	if ActionButton_HideOverlayGlow then
		ActionButton_HideOverlayGlow(f)
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
			local start, duration, enabled = CDTL3:GetSpellCooldown(spell["id"])
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
							if not s["ignored"] then
								if CDTL3.db.profile.global["spells"]["enabled"] then
									CDTL3:CreateCooldown(CDTL3:GetUID(),"spells" , s)
								end
								
								if not CDTL3:IsUsedBy("spells", spell["id"]) then
									CDTL3:AddUsedBy("spells", spell["id"], CDTL3.player["guid"])
								end
							end
						else
							local spellName, icon, originalIcon = CDTL3:GetSpellInfo(spell["id"])
							
							local s = CDTL3:ApplyEntryDefaults({
								id = spell["id"],
								bCD = duration * 1000,	-- bCD is milliseconds everywhere else
								name = spell["name"],
								type = "spells",
								icon = icon,
							}, "spells")
							s["link"] = CDTL3:GetSpellLink(spell["id"])
							s["ignored"] = CDTL3:IgnoredByDefault("spells", s["bCD"])

							CDTL3:SaveNewEntry(s, "spells")
						end
					end
				end
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
				local spellName, subName = C_SpellBook.GetSpellBookItemName(j, Enum.SpellBookSpellBank.Player)
				local spellID = select(2,C_SpellBook.GetSpellBookItemType(j, Enum.SpellBookSpellBank.Player))

				local start, duration, enabled = CDTL3:GetSpellCooldown(spellID)

				if duration > 1.5 then
					if CDTL3.db.profile.global["debugMode"] then
						CDTL3:Print("COOLINGDOWN: "..tostring(spellName).." - "..spellID)
					end

					local s = CDTL3:GetSpellSettings(spellName, "spells")
					if s then
						if not s["ignored"] then
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
					else
						local spellName, icon = CDTL3:GetSpellInfo(spellID)
						s = CDTL3:NewSpellEntry(spellID, spellName, icon, "spells")
						if CDTL3:SaveNewEntry(s, "spells") then
							CDTL3:CheckEdgeCases(spellName)
						end
					end
				end
			end
		end
	else
		for i = 1, GetNumSpellTabs() do
			local offset, numSlots = select(3, GetSpellTabInfo(i))
			for j = offset + 1, offset + numSlots do
				local spellName, _, spellID = GetSpellBookItemName(j, BOOKTYPE_SPELL)
				if spellID then
					local start, duration, enabled = CDTL3:GetSpellCooldown(spellID)

					if duration > 1.5 then
						if CDTL3.db.profile.global["debugMode"] then
							CDTL3:Print("COOLINGDOWN: "..tostring(spellName).." - "..spellID)
						end

						local s = CDTL3:GetSpellSettings(spellName, "spells")
						if s then
							if not s["ignored"] then
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
						else
							local spellName, icon = CDTL3:GetSpellInfo(spellID)
							s = CDTL3:NewSpellEntry(spellID, spellName, icon, "spells")
							if CDTL3:SaveNewEntry(s, "spells") then
								CDTL3:CheckEdgeCases(spellName)
							end
						end
					end
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
			local start, duration, enabled = CDTL3:GetItemCooldown(itemId)

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

function CDTL3:SetBorder(f, s)
	local inset = s["inset"]
	local padding = s["padding"]

	f:SetBackdrop({
		bgFile = CDTL3.LSM:Fetch("background", "None"),
		edgeFile = CDTL3.LSM:Fetch("border", s["style"]),
		tile = false,
		tileSize = 0,
		edgeSize = s["size"],
		insets = { left = inset, right = inset, top = inset, bottom = inset }
	})
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
		
		CDTL3:Print("Debug Mode Disabled")
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
		
		CDTL3:Print("Debug Mode Enabled")
	end
end

-- quiet: no chat line and no unlock popup (Edit Mode shows/hides the frames itself)
function CDTL3:ToggleFrameLock(quiet)
	local unlockFrames = CDTL3.db.profile.global["unlockFrames"]

	-- Guard: unlockFrame may be nil if OnEnable errored before CreateUnlockFrame ran.
	if not CDTL3.unlockFrame then
		CDTL3:Print("CDTL3: unlockFrame not ready — try reloading the UI.")
		return
	end
	
	if unlockFrames then
		CDTL3.db.profile.global["unlockFrames"] = false
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
			CDTL3:Print("Frames Locked")
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
			CDTL3:Print("Frames Unlocked")
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

-- Import a string made by the Import/Export tab. Every stage is checked and the data's
-- shape is validated BEFORE anything is written, so a bad string changes nothing.
-- Imported data is copied INTO AceDB's existing profile tables: replacing the
-- CDTL3.db.profile reference only changed the in-memory view, so the import was lost on
-- /reload. Defaults are re-applied afterwards for keys an older export doesn't have.
local IMPORT_TABLE_TYPES = { "spells", "petspells", "items", "buffs", "debuffs", "offensives", "runes", "customs", "detected" }
local IMPORT_SETTINGS_KEYS = { "global", "lanes", "barFrames", "ready", "holders" }

local function ReplaceContents(target, source)
	for k in pairs(target) do
		target[k] = nil
	end
	for k, v in pairs(source) do
		target[k] = v
	end
end

function CDTL3:ImportHandler(importString)
	local function Fail(what)
		CDTL3:Print("There was an error importing the data!")
		CDTL3:Print("  -"..what)
		return nil
	end

	-- DEFLATE + SERIALIZE (any stage can fail on a truncated / mistyped string)
	local LibDeflate = LibStub:GetLibrary("LibDeflate")
	local LibAceSerializer = LibStub:GetLibrary("AceSerializer-3.0")

	local ok, unprintable = pcall(LibDeflate.DecodeForPrint, LibDeflate, importString or "")
	if not ok or not unprintable then
		return Fail("All data (was invalid import string)")
	end
	local inflated
	ok, inflated = pcall(LibDeflate.DecompressDeflate, LibDeflate, unprintable)
	if not ok or not inflated then
		return Fail("All data (was invalid import string)")
	end
	local success, data = LibAceSerializer:Deserialize(inflated)
	if not success or type(data) ~= "table" then
		return Fail("All data (was invalid import string)")
	end

	local profile = CDTL3.db.profile
	local importMode = CDTL3.db.profile.global["importMode"]

	if importMode == "ALL" then
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			if type(data[key]) ~= "table" then
				return Fail("All data (not a full CDTL3 export)")
			end
		end
		-- keep this profile's import/export choices
		local exportMode, keepImportMode = profile.global["exportMode"], profile.global["importMode"]
		ReplaceContents(profile, data)
		profile.global["exportMode"], profile.global["importMode"] = exportMode, keepImportMode

	elseif importMode == "SETTINGS" then
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			if type(data[key]) ~= "table" then
				return Fail("Settings data (not a CDTL3 settings export)")
			end
		end
		for _, key in ipairs(IMPORT_SETTINGS_KEYS) do
			profile[key] = data[key]
		end

	elseif importMode == "CDDATA" then
		-- a cooldown-data export is the tables map itself; a full/settings export nests it
		local tables = type(data.tables) == "table" and data.tables or data
		local found = 0
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			if tables[key] ~= nil and type(tables[key]) ~= "table" then
				return Fail("Cooldown data (malformed)")
			end
			if type(tables[key]) == "table" and next(tables[key]) then
				found = found + 1
			end
		end
		if found == 0 then
			-- e.g. a "Settings Only" export, whose cooldown lists are deliberately empty
			return Fail("Cooldown data (the string contains no cooldown data)")
		end
		for _, key in ipairs(IMPORT_TABLE_TYPES) do
			if type(tables[key]) == "table" then
				profile.tables[key] = tables[key]
			end
		end
	end

	-- re-apply defaults for anything an older export lacks, then rebuild everything
	CDTL3.db:RegisterDefaults(CDTL3.db.defaults)
	CDTL3:RefreshConfig()

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