--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}
private.stackingPollRate = 5
private.dynamicTextPollRate = 10
private.timeTextPollRate = 2

function CDTL3:CreateLanes()
	local lane1Enabled = CDTL3.db.profile.lanes["lane1"]["enabled"]
	local lane2Enabled = CDTL3.db.profile.lanes["lane2"]["enabled"]
	local lane3Enabled = CDTL3.db.profile.lanes["lane3"]["enabled"]
	
	if lane1Enabled then
		if CDTL3_Lane_1 then
			CDTL3:RefreshLane(1)
		else
			private.CreateLane(1)
		end
	end
	
	if lane2Enabled then
		if CDTL3_Lane_2 then
			CDTL3:RefreshLane(2)
		else
			private.CreateLane(2)
		end
	end
	
	if lane3Enabled then
		if CDTL3_Lane_3 then
			CDTL3:RefreshLane(3)
		else
			private.CreateLane(3)
		end
	end
end

function CDTL3:RefreshLane(i)
	local f = nil
	local s = nil
	if i == 1 then
		f = CDTL3_Lane_1
		s = CDTL3.db.profile.lanes["lane1"]
	elseif i == 2 then
		f = CDTL3_Lane_2
		s = CDTL3.db.profile.lanes["lane2"]
	elseif i == 3 then
		f = CDTL3_Lane_3
		s = CDTL3.db.profile.lanes["lane3"]
	end
	
	if not f then
		return
	end
	
	f.name = s["name"]
	
	f:ClearAllPoints()
	f:SetPoint(s["relativeTo"], s["posX"], s["posY"])
	
	-- FOREGROUND
	f:SetMinMaxValues(0, 1)
	f:SetValue(1)
	f:SetReverseFill(s["tracking"]["primaryReversed"])
	CDTL3:SetBarTexture(f, s["fgTexture"])
	f:GetStatusBarTexture():SetHorizTile(false)
	f:GetStatusBarTexture():SetVertTile(false)
	
	local fgColor = s["fgTextureColor"] or { r=0.77647, g=0.11765, b=0.28235, a=1 }
	if CDTL3.player["class"] then
		if s["fgClassColor"] then
			fgColor = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]]
		end
	end

	f:SetStatusBarColor(
		fgColor["r"],
		fgColor["g"],
		fgColor["b"],
		fgColor["a"]
	)
	
	if s["vertical"] then
		f:SetOrientation("VERTICAL")
		f:SetSize(s["height"], s["width"])
		f.db:SetSize(s["height"], s["width"])
	else
		f:SetOrientation("HORIZONTAL")
		f:SetSize(s["width"], s["height"])
		f.db:SetSize(s["width"], s["height"])
	end
	
	-- BACKGROUND
	CDTL3:SetBarTexture(f.bg, s["bgTexture"])
	f.bg:SetAllPoints(true)
	--[[f.bg:SetVertexColor(
		s["bgTextureColor"]["r"],
		s["bgTextureColor"]["g"],
		s["bgTextureColor"]["b"],
		s["bgTextureColor"]["a"]
	)]]--
	
	local bgColor = s["bgTextureColor"]
	if CDTL3.player["class"] then
		if s["bgClassColor"] then
			bgColor = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]]
		end
	end
	
	f.bg:SetVertexColor(
		bgColor["r"],
		bgColor["g"],
		bgColor["b"],
		bgColor["a"]
	)
	
	-- SECONDARY TRACKING
	-- One marker per lane; LaneUpdate shows/hides it, so it must always exist.
	if not f.st then
		f.st = CreateFrame("Frame", f:GetName().."_ST", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f.st:SetParent(f)
		f.st.bg = f.st:CreateTexture(nil, "BACKGROUND")
	end

	if s["tracking"]["secondaryTracking"] ~= "NONE" then
		f.st:ClearAllPoints()
		f.st:SetSize(s["tracking"]["stWidth"], s["tracking"]["stHeight"])
		CDTL3:SetBarTexture(f.st.bg, s["tracking"]["stTexture"])
		f.st.bg:SetAllPoints(true)
		f.st.bg:SetVertexColor(
			s["tracking"]["stTextureColor"]["r"],
			s["tracking"]["stTextureColor"]["g"],
			s["tracking"]["stTextureColor"]["b"],
			s["tracking"]["stTextureColor"]["a"]
		)
	else
		f.st:Hide()
	end
	
	-- BORDER
	if s["border"]["style"] ~= "None" then
		if not f.bd then
			f.bd = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bd:SetParent(f)
		end
	
		CDTL3:SetBorder(f.bd, s["border"])
		f.bd:Show()
		f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
	else
		if f.bd then
			f.bd:Hide()
		end
	end
	
	-- TEXT
	private.SetModeText(f, s)
	private.RefreshText(f, s)
	private.UpdateText(f, s)
	
	-- ANIMATION
	-- Fade animations are created once per frame; only their alpha targets change on
	-- refresh (recreating them on every refresh leaked a pair of groups each time).
	if not f.animateIn then
		f.animateIn = f:CreateAnimationGroup()
		f.animateIn:SetLooping("NONE")
		f.animateIn:SetToFinalAlpha(true)
		f.animateIn.fade = f.animateIn:CreateAnimation("Alpha")
		f.animateIn.fade:SetDuration(0.3)
		f.animateIn.fade:SetSmoothing("OUT")
		f.animateIn.fade:SetOrder(1)
		
		f.animateOut = f:CreateAnimationGroup()
		f.animateOut:SetLooping("NONE")
		f.animateOut:SetToFinalAlpha(true)
		f.animateOut.fade = f.animateOut:CreateAnimation("Alpha")
		f.animateOut.fade:SetDuration(0.3)
		f.animateOut.fade:SetSmoothing("OUT")
		f.animateOut.fade:SetOrder(1)
	end
	
	f.animateIn.fade:SetFromAlpha(0)
	f.animateIn.fade:SetToAlpha(s["alpha"])
	f.animateOut.fade:SetFromAlpha(s["alpha"])
	f.animateOut.fade:SetToAlpha(0)
	
	-- DEBUG/UNLOCK
	f.db:ClearAllPoints()
	f.db:SetPoint("CENTER", 0, 0)
	f.db.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 12)
	f.db.text:ClearAllPoints()
	f.db.text:SetPoint("CENTER", 0, 0)
	f.db.text:SetText(f.name)
	f.db.bg:SetAllPoints(true)
	f.db.bg:SetColorTexture( 
		CDTL3.colors["db"]["r"],
		CDTL3.colors["db"]["g"],
		CDTL3.colors["db"]["b"],
		CDTL3.colors["db"]["a"]
	)
	
	if s["enabled"] then
		f:Show()
		CDTL3:Autohide(f, s)
	else
		f:Hide()
	end
	
	if CDTL3.db.profile.global["unlockFrames"] then
		CDTL3:FrameUnlock(f)
	else
		CDTL3:FrameLock(f)
	end
	
	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:DebugOn(f)
	else
		CDTL3:DebugOff(f)
	end
end

private.RefreshText = function(f, s)
	-- MODE TEXT
	for i = 1, 10, 1 do
		local tSettings = nil
		local tObject = nil
	   
		local anchor = ""
		local align = ""
		local position = ""
		local xOffset = 0
	   
		if i == 1 then
			tSettings = s["modeText"]["text1"]
			tObject = f.t1
			
			if s["vertical"] then
				anchor = "BOTTOM"
				align = "CENTER"
				position = tSettings["pos"]
				xOffset = tSettings["offX"] + 5
				if s["reversed"] then
					anchor = "TOP"
					position = -position
					xOffset = -xOffset
				end
			else
				anchor = "LEFT"
				align = "LEFT"
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				if s["reversed"] then
					anchor = "RIGHT"
					align = "RIGHT"
					position = -position
					xOffset = -xOffset
				end
			end
		elseif i == 2 then
			tSettings = s["modeText"]["text2"]
			tObject = f.t2
			
			if s["vertical"] then
				anchor = "BOTTOM"
				align = tSettings["align"]
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				
				if s["reversed"] then
					anchor = "TOP"
					position = -position
				end
			else
				anchor = "LEFT"
				align = tSettings["align"]
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				
				if s["reversed"] then
					anchor = "RIGHT"
					position = -position
				end
			end
		elseif i == 3 then
			tSettings = s["modeText"]["text3"]
			tObject = f.t3
			
			if s["vertical"] then
				anchor = "BOTTOM"
				align = tSettings["align"]
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				
				if s["reversed"] then
					anchor = "TOP"
					position = -position
				end
			else
				anchor = "LEFT"
				align = tSettings["align"]
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				
				if s["reversed"] then
					anchor = "RIGHT"
					position = -position
				end
			end
		elseif i == 4 then
			tSettings = s["modeText"]["text4"]
			tObject = f.t4
			
			if s["vertical"] then
				anchor = "BOTTOM"
				align = tSettings["align"]
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				
				if s["reversed"] then
					anchor = "TOP"
					position = -position
				end
			else
				anchor = "LEFT"
				align = tSettings["align"]
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				
				if s["reversed"] then
					anchor = "RIGHT"
					position = -position
				end
			end
		elseif i == 5 then
			tSettings = s["modeText"]["text5"]
			tObject = f.t5
			
			if s["vertical"] then
				anchor = "BOTTOM"
				align = "CENTER"
				position = tSettings["pos"]
				xOffset = tSettings["offX"] - 5
				if s["reversed"] then
					anchor = "TOP"
					position = -position
					xOffset = -xOffset
				end
			else
				anchor = "LEFT"
				align = "RIGHT"
				position = tSettings["pos"]
				xOffset = tSettings["offX"]
				if s["reversed"] then
					anchor = "RIGHT"
					align = "LEFT"
					position = -position
					xOffset = -xOffset
				end
			end
		elseif i == 6 then
			tSettings = s["customText"]["text1"]
			tObject = f.c1
			
			anchor = tSettings["anchor"]
			align = tSettings["align"]
			position = tSettings["pos"]
			xOffset = tSettings["offX"]
		elseif i == 7 then
			tSettings = s["customText"]["text2"]
			tObject = f.c2
			
			anchor = tSettings["anchor"]
			align = tSettings["align"]
			position = tSettings["pos"]
			xOffset = tSettings["offX"]
		elseif i == 8 then
			tSettings = s["customText"]["text3"]
			tObject = f.c3
			
			anchor = tSettings["anchor"]
			align = tSettings["align"]
			position = tSettings["pos"]
			xOffset = tSettings["offX"]
		elseif i == 9 then
			tSettings = s["customText"]["text4"]
			tObject = f.c4
			
			anchor = tSettings["anchor"]
			align = tSettings["align"]
			position = tSettings["pos"]
			xOffset = tSettings["offX"]
		elseif i == 10 then
			tSettings = s["customText"]["text5"]
			tObject = f.c5
			
			anchor = tSettings["anchor"]
			align = tSettings["align"]
			position = tSettings["pos"]
			xOffset = tSettings["offX"]
		end
		
		tObject:ClearAllPoints()
		
		if s["vertical"] then
			tObject:SetPoint(
					align,
					f,
					anchor,
					tSettings["offY"],
					xOffset + (s["width"] * position)
				)
		else
			tObject:SetPoint(
					align,
					f,
					anchor,
					xOffset + (s["width"] * position),
					tSettings["offY"]
				)
		end
		
		local _outline = tSettings["outline"]
		if type(_outline) ~= "string" or _outline == "NONE" or _outline == "" then _outline = nil end
		local _fnt, _sz = CDTL3.LSM:Fetch("font", tSettings["font"]), tonumber(tSettings["size"]) or 0
		if _fnt and _sz > 0 then tObject:SetFont(_fnt, _sz, _outline) end
		tObject:SetTextColor(
				tSettings["color"]["r"],
				tSettings["color"]["g"],
				tSettings["color"]["b"],
				tSettings["color"]["a"]
			)
		tObject:SetShadowColor(
				tSettings["shadColor"]["r"],
				tSettings["shadColor"]["g"],
				tSettings["shadColor"]["b"],
				tSettings["shadColor"]["a"]
			)
		tObject:SetShadowOffset(tSettings["shadX"], tSettings["shadY"])
		tObject:SetNonSpaceWrap(false)
		
		tObject:SetText(CDTL3:ConvertAllTextTags(tSettings["text"], f))
		
		if tSettings["enabled"] == true and tSettings["used"] == true then
			tObject:SetAlpha(1)
		else
			tObject:SetAlpha(0)
		end
	end
end

private.CalcStacking = function(f, s, count)
	local baseLevel = 5
	local levelMultiplier = 5

	if count >= 2 and s["stacking"]["enabled"] then
		local style = s["stacking"]["style"]
		
		if style == "GROUPED" then
			local height = s["stacking"]["height"]
			local grow = s["stacking"]["grow"]
			local iconSize = s["icons"]["size"]
			
			table.sort(f.validChildren, function(a, b)
				local aX, aY = a:GetCenter()
				local bX, bY = b:GetCenter()
				
				if s["vertical"] then
					if aY == bY then
						return a.uid < b.uid
					end
					
					return aY < bY
				else
					if aX == bX then
						return a.uid < b.uid
					end
				
					return aX < bX
				end
			end)
			
			local indicies = {}
			local currentIndex = 1
			
			for k, iconA in pairs(f.validChildren) do
				if k == 1 then
					table.insert(indicies, currentIndex)
				end
				
				if k + 1 <= count then
					local iconB = f.validChildren[k + 1]
					local aX, aY = iconA:GetCenter()
					local bX, bY = iconB:GetCenter()
					
					local distance = 0
					if s["vertical"] then
						distance = math.abs(aY - bY)
					else
						distance = math.abs(aX - bX)
					end
					
					if distance <= iconSize then
						table.insert(indicies, currentIndex)
					else
						currentIndex = currentIndex + 1
						table.insert(indicies, currentIndex)
					end
				end
				
				for i = 1, currentIndex, 1 do
					local currentStack = {}
					local stackCount = 0
					-- Count how many we have in the i'nth stack
					for k, v in pairs(indicies) do
						if v == i then
							stackCount = stackCount + 1
							table.insert(currentStack, f.validChildren[k])
						end
					end
					
					table.sort(currentStack, function(a, b)
							if a.currentCD == b.currentCD then
								return a.uid < b.uid
							end
					
							return a.currentCD > b.currentCD
						end)
					
					-- Then set the correct data for the i'nth stack
					for k, icon in pairs(currentStack) do
						icon.stack = i
						local iconOffset = 0
						local stackOffset = 0
						if iconSize * stackCount > height then
							local maxHeight = height - iconSize
							iconOffset = (maxHeight / (stackCount - 1)) * (k - 1)
							
							stackOffset = maxHeight / 2
						else
							iconOffset = iconSize * (k - 1)
							stackOffset = (iconSize * (stackCount - 1)) / 2
						end
						
						if grow == "DOWN" then
							iconOffset = -iconOffset
						elseif grow == "CENTER" then
							if stackCount == 1 then
								iconOffset = 0
							else
								iconOffset = iconOffset - stackOffset
							end
						end
						
						icon.sOffset = iconOffset
						
						local levelMultiplier = 5
						local baseLevel = k * levelMultiplier
						
						icon:SetFrameLevel(baseLevel)
						if icon.bd then
							icon.bd:SetFrameLevel(baseLevel + 1)
						end
						if icon.hl then
							icon.hl:SetFrameLevel(baseLevel + 2)
						end
					end
				end
			end
		elseif style == "OFFSET" then
			table.sort(f.validChildren, function(a, b)
				if a.currentCD == b.currentCD then
					return a.uid < b.uid
				end
				
				return a.currentCD > b.currentCD
			end)
			
			local offset = s["stacking"]["height"] / (count - 1)
			local height = s["stacking"]["height"]
			local grow = s["stacking"]["grow"]
			
			for k, child in ipairs(f.validChildren) do
				local o = (offset * k) - offset
				
				if grow == "DOWN" then
					o = -o
				elseif grow == "CENTER" then
					o = o - (height / 2)
				end
				
				child.sOffset = o
				
				child:SetFrameLevel(baseLevel * k)
				if child.bd then
					child.bd:SetFrameLevel(baseLevel * k + 1)
				end
				if child.hl then
					child.hl:SetFrameLevel(baseLevel * k + 2)
				end
			end
			
		elseif style == "STAGGERED" then
			
		else
			table.sort(f.validChildren, function(a, b)
				if a.currentCD == b.currentCD then
					return a.uid < b.uid
				end
				return a.currentCD > b.currentCD
			end)
		
			for k, child in ipairs(f.validChildren) do
				child:SetFrameLevel(baseLevel * k)
				if child.bd then
					child.bd:SetFrameLevel(baseLevel * k + 1)
				end
				if child.hl then
					child.hl:SetFrameLevel(baseLevel * k + 2)
				end
			end
		end
	else
		for k, child in ipairs(f.validChildren) do
			child.stack = 1
			child.sOffset = 0
			child:SetFrameLevel(baseLevel * k)
			
			if child.bd then
				child.bd:SetFrameLevel(baseLevel * k + 1)
			end
			if child.hl then
				child.hl:SetFrameLevel(baseLevel * k + 2)
			end
		end
	end
end

-- Player health/power (and some stats) can be SECRET on Midnight 12.x / WoW: Forever:
-- comparing or doing arithmetic on them throws. A StatusBar still accepts them, so the
-- HEALTH / CLASS_POWER / COMBO_POINTS trackers hand back (0, current, max) for the
-- caller to feed the bar directly. f:GetValue() is then secret too: BarValueDiffers
-- returns nil ("unknown") instead of throwing.
private.BarValueDiffers = function(f, v)
	local ok, differs = pcall(function()
		return f:GetValue() ~= v
	end)

	if ok then
		return differs
	end
end

private.SetAutohideOverride = function(f, differs)
	if differs then
		f.overrideAutohide = true
		f.forceShow = true
	elseif differs == false then
		f.overrideAutohide = false
	end
end

-- current/max as a 0-1 fraction (0 when current is 0); nil if either is secret
private.Fraction = function(current, max)
	local ok, fraction = pcall(function()
		if current ~= 0 then
			return current / max
		end
		return 0
	end)

	if ok then
		return fraction
	end
end

-- The tick / swing timers are shared (CDTL3.tracking) but CalcTracking runs per lane and
-- per primary/secondary slot, so advance each timer at most once per frame. GetTime() is
-- constant within a frame.
private.advancedAt = {}
private.FrameElapsed = function(key, elapsed)
	local now = GetTime()
	if private.advancedAt[key] == now then
		return 0
	end
	private.advancedAt[key] = now
	return elapsed
end

private.CalcTracking = function(f, s, t, elapsed)	
	local position = 0

	if t == "GCD" then
		local start, duration, enabled = CDTL3:GetSpellCooldown(8921)	-- Spell ID for Moonfire, but any spell without a cooldown can be used
		local cooldownMS, gcdMS = GetSpellBaseCooldown(8921)			-- Spell ID for Moonfire, but any spell without a cooldown can be used
		
		local timeLeft = (start + duration) - GetTime()
		position = ( timeLeft / (gcdMS / 1000))
		
	elseif t == "HEALTH" then
		local hpMax = UnitHealthMax("player")
		local hpCurrent = UnitHealth("player")
		
		position = private.Fraction(hpCurrent, hpMax)
		
		if s["tracking"]["overrideAutohide"] then
			if not f.forceShow then
				private.SetAutohideOverride(f, private.BarValueDiffers(f, 1))
			end
		end

		if not position then
			return 0, hpCurrent, hpMax
		end
		
	elseif t == "CLASS_POWER" then
		if CDTL3.player["class"] ~= nil then
			if CDTL3.player["class"] == "DRUID" then
				CDTL3.player["classPower"] = CDTL3:GetPlayerPower("DRUID")
			end
		end
		
		local pType = CDTL3.player["classPower"]
		local pMax = UnitPowerMax("player", pType)
		local pCurrent = UnitPower("player", pType)
		
		if pType then
			position = private.Fraction(pCurrent, pMax)
		end
		
		if s["tracking"]["overrideAutohide"] then
			if not f.forceShow then
				if pType == Enum.PowerType.Rage then
					private.SetAutohideOverride(f, private.BarValueDiffers(f, 0))
				else
					private.SetAutohideOverride(f, private.BarValueDiffers(f, 1))
				end
			end
		end

		if not position then
			return 0, pCurrent, pMax
		end
	
	elseif t == "COMBO_POINTS" then
		local cpMax = UnitPowerMax("player", Enum.PowerType.ComboPoints)
		local cpCurrent = UnitPower("player", Enum.PowerType.ComboPoints)
		
		position = private.Fraction(cpCurrent, cpMax)

		if not position then
			return 0, cpCurrent, cpMax
		end
	
	elseif t == "MANA_TICK" then
		local interval = 2
		if CDTL3.tracking["fsr"] then
			interval = 5
		end
		
		local tickTime = GetTime() - CDTL3.tracking["manaTime"]
		local percent = tickTime / interval
		position = percent
	
	elseif t == "ENERGY_TICK" then
		CDTL3.tracking["energyTimeCount"] = CDTL3.tracking["energyTimeCount"] + private.FrameElapsed("energy", elapsed)
		
		if CDTL3.tracking["energyTimeCount"] >= 2 then
			CDTL3.tracking["energyTimeCount"] = 0 + (CDTL3.tracking["energyTimeCount"] - 2)
		end
		
		local percent = CDTL3.tracking["energyTimeCount"] / 2
		position = percent
		
		if s["tracking"]["overrideAutohide"] then
			if not f.forceShow then
				if CDTL3:AuraExists("player", "Stealth") then
					f.overrideAutohide = true
					f.forceShow = true
				else
					f.overrideAutohide = false
				end
			end
		end
		
	elseif t == "MH_SWING" then
		local mhSpeed, _ = UnitAttackSpeed("player")
			
		if CDTL3.tracking["mhSwingTime"] < 0 then
			position = 1
		else
			CDTL3.tracking["mhSwingTime"] = CDTL3.tracking["mhSwingTime"] - private.FrameElapsed("mhSwing", elapsed)
			
			position = private.Fraction(CDTL3.tracking["mhSwingTime"], mhSpeed) or 1
		end
		
	elseif t == "OH_SWING" then
		local _, ohSpeed = UnitAttackSpeed("player")
			
		if CDTL3.tracking["ohSwingTime"] < 0 then
			position = 1
		else
			CDTL3.tracking["ohSwingTime"] = CDTL3.tracking["ohSwingTime"] - private.FrameElapsed("ohSwing", elapsed)
			
			position = private.Fraction(CDTL3.tracking["ohSwingTime"], ohSpeed) or 1
		end
		
	elseif t == "RANGE_SWING" then
		local rSwingTime, _, _, _, _, _ = UnitRangedDamage("player");
			
		if CDTL3.tracking["rSwingTime"] < 0 then
			position = 1
		else
			CDTL3.tracking["rSwingTime"] = CDTL3.tracking["rSwingTime"] - private.FrameElapsed("rSwing", elapsed)
			
			position = private.Fraction(CDTL3.tracking["rSwingTime"], rSwingTime) or 1
		end
	end
	
	return position
end

private.CreateLane = function(laneNumber)	
	local frameName = "CDTL3_Lane_"..laneNumber
	local f = CreateFrame("StatusBar", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	
	f.number = laneNumber
	f.updateCount = 0
	f.childCount = 0
	f.validChildren = {}
	f.overrideAutohide = false
	
	f.currentCount = 0
	f.previousCount = 0
	f.triggerUpdate = false

	f.bg = f:CreateTexture(nil, "BACKGROUND")
	--f.st = CreateFrame("Frame", frameName.."_ST", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
	--f.st:SetParent(f)
	--f.st.bg = f.st:CreateTexture(nil, "BACKGROUND")
	
	
	--f.bd = CreateFrame("Frame", frameName.."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	--f.bd:SetParent(f)
	
	f.db = CreateFrame("Frame", frameName.."_DB", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.db:SetParent(f)
	f.db.bg = f.db:CreateTexture(nil, "BACKGROUND")
	f.db.text = f.db:CreateFontString(nil,"ARTWORK")
	
	-- MODE TEXT
	f.t1 = f:CreateFontString(nil,"ARTWORK")
	f.t2 = f:CreateFontString(nil,"ARTWORK")
	f.t3 = f:CreateFontString(nil,"ARTWORK")
	f.t4 = f:CreateFontString(nil,"ARTWORK")
	f.t5 = f:CreateFontString(nil,"ARTWORK")
	
	f.c1 = f:CreateFontString(nil,"ARTWORK")
	f.c2 = f:CreateFontString(nil,"ARTWORK")
	f.c3 = f:CreateFontString(nil,"ARTWORK")
	f.c4 = f:CreateFontString(nil,"ARTWORK")
	f.c5 = f:CreateFontString(nil,"ARTWORK")
	
	-- ON UPDATE
	f:HookScript("OnUpdate", function(self, elapsed)
		private.LaneUpdate(self, elapsed)
	end)
	
	-- DRAG AND DROP MOVEMENT
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	
	CDTL3:RefreshLane(laneNumber)
	table.insert(CDTL3.lanes, f)
end

private.LaneUpdate = function(f, elapsed)
	local s = nil
	if f.number == 1 then
		s = CDTL3.db.profile.lanes["lane1"]
	elseif f.number == 2 then
		s = CDTL3.db.profile.lanes["lane2"]
	elseif f.number == 3 then
		s = CDTL3.db.profile.lanes["lane3"]
	end
	
	f.forceShow = false
	
	-- UPDATE
	if f.triggerUpdate then
		local children = { f:GetChildren() }
		f.validChildren = {}
		local count = 0
		for _, child in ipairs(children) do
			if child.valid then
				count = count + 1
				table.insert(f.validChildren, child)
			end
		end
		
		f.childCount = count
		
		if s["enabled"] then
			CDTL3:Autohide(f, s)
		else
			f:SetAlpha(0)
		end
		
		-- TEXT UPDATE
		private.UpdateText(f, s)
		
		f.triggerUpdate = false
	end
	
	-- TEXT UPDATE
	--private.UpdateText(f, s)
	
	if f:GetAlpha() ~= 0 then
		-- TEXT UPDATE
		--private.UpdateText(f, s)
	
		-- STACKING CALC
		if f.updateCount % private.stackingPollRate == 0 then
			private.CalcStacking(f, s, f.childCount)
		end
	
		-- PRIMARY TRACKING
		if s["tracking"]["primaryTracking"] ~= "NONE" then
			local tValue, secretCurrent, secretMax = private.CalcTracking(f, s, s["tracking"]["primaryTracking"], elapsed)
			if secretCurrent then
				f:SetMinMaxValues(0, secretMax)
				f:SetValue(secretCurrent)
				f.secretRange = true
			else
				if f.secretRange then
					f:SetMinMaxValues(0, 1)
					f.secretRange = false
				end
				f:SetValue(tValue)
			end
		else
			-- tracking switched off: undo a secret health/power range, or the lane stays empty
			if f.secretRange then
				f:SetMinMaxValues(0, 1)
				f.secretRange = false
			end
			f:SetValue(1)
		end
		
		-- SECONDARY TRACKING
		if s["tracking"]["secondaryTracking"] ~= "NONE" then
			local tValue, secretCurrent = private.CalcTracking(f, s, s["tracking"]["secondaryTracking"], elapsed)
			
			-- the marker is positioned by arithmetic, so it can't follow a secret value
			if not secretCurrent and tValue < 1 and tValue > 0 then
				local tPosition = (s["width"] - s["tracking"]["stWidth"]) * tValue
				
				f.st:ClearAllPoints()

				local anchor = "LEFT"
				if s["tracking"]["secondaryReversed"] then
					anchor = "RIGHT"
					tPosition = -tPosition
				end
				
				f.st:SetPoint(anchor, tPosition, 0)
				f.st:Show()
			else
				f.st:Hide()
			end
		else
			f.st:Hide()
		end
		
		-- FRAME (UN)LOCKING
		if CDTL3.db.profile.global["unlockFrames"] then
			local _, _, relativeTo, xOfs, yOfs = f:GetPoint()
			
			s["relativeTo"] = relativeTo
			s["posX"] = xOfs
			s["posY"] = yOfs
		end
	end
	
	-- UPDATE COUNT
	f.updateCount = f.updateCount + 1
	if f.updateCount > 12000 then
		f.updateCount = 1
	end
end

private.SetModeText = function(f, s)
	local st = s["modeText"]
	local mode = s["mode"]["type"]
	local tFormat = ""
	
	if mode == "LINEAR" then
		st["text1"]["text"] = "Ready"
		st["text1"]["pos"] = 0
		st["text1"]["used"] = true
		st["text1"]["align"] = "LEFT"
		st["text1"]["offX"] = 5
		
		st["text2"]["text"] = "25%"
		st["text2"]["pos"] = 0.25
		st["text2"]["used"] = true
		
		st["text3"]["text"] = "50%"
		st["text3"]["pos"] = 0.5
		st["text3"]["used"] = true
		
		st["text4"]["text"] = "75%"
		st["text4"]["pos"] = 0.75
		st["text4"]["used"] = true
		
		st["text5"]["text"] = "100%"
		st["text5"]["pos"] = 1
		st["text5"]["used"] = true
		st["text5"]["align"] = "RIGHT"
		st["text5"]["offX"] = -5
		
	elseif mode == "LINEAR_ABS" then
		local max = s["mode"]["linearAbs"]["max"]
		tFormat = s["mode"]["linearAbs"]["timeFormat"]
		
		st["text1"]["text"] = "Ready"
		st["text1"]["pos"] = 0
		st["text1"]["used"] = true
		
		st["text2"]["text"] = CDTL3:ConvertTime(max * 0.25, tFormat)
		st["text2"]["pos"] = 0.25
		st["text2"]["used"] = true
		
		st["text3"]["text"] = CDTL3:ConvertTime(max * 0.5, tFormat)
		st["text3"]["pos"] = 0.5
		st["text3"]["used"] = true
		
		st["text4"]["text"] = CDTL3:ConvertTime(max * 0.75, tFormat)
		st["text4"]["pos"] = 0.75
		st["text4"]["used"] = true
		
		st["text5"]["text"] = CDTL3:ConvertTime(max, tFormat)
		st["text5"]["pos"] = 1
		st["text5"]["used"] = true
	elseif mode == "SPLIT" then
		st["text1"]["text"] = "Ready"
		st["text2"]["text"] = s["mode"]["split"]["s1v"].."%"
		st["text2"]["pos"] = s["mode"]["split"]["s1p"]
		st["text3"]["text"] = s["mode"]["split"]["s2v"].."%"
		st["text3"]["pos"] = s["mode"]["split"]["s2p"]
		st["text4"]["text"] = s["mode"]["split"]["s3v"].."%"
		st["text4"]["pos"] = s["mode"]["split"]["s3p"]
		st["text5"]["text"] = "100%"
		
		if s["mode"]["split"]["count"] == 1 then
			st["text2"]["used"] = true
			st["text3"]["used"] = false
			st["text4"]["used"] = false
		elseif s["mode"]["split"]["count"] == 2 then
			st["text2"]["used"] = true
			st["text3"]["used"] = true
			st["text4"]["used"] = false
		elseif s["mode"]["split"]["count"] == 3 then
			st["text2"]["used"] = true
			st["text3"]["used"] = true
			st["text4"]["used"] = true
		end
	elseif mode == "SPLIT_ABS" then
		local max = s["mode"]["splitAbs"]["max"]
		tFormat = s["mode"]["splitAbs"]["timeFormat"]
		
		st["text1"]["text"] = "Ready"
		st["text2"]["text"] = CDTL3:ConvertTime(s["mode"]["splitAbs"]["s1v"], tFormat)
		st["text2"]["pos"] = s["mode"]["splitAbs"]["s1p"]
		st["text3"]["text"] = CDTL3:ConvertTime(s["mode"]["splitAbs"]["s2v"], tFormat)
		st["text3"]["pos"] = s["mode"]["splitAbs"]["s2p"]
		st["text4"]["text"] = CDTL3:ConvertTime(s["mode"]["splitAbs"]["s3v"], tFormat)
		st["text4"]["pos"] = s["mode"]["splitAbs"]["s3p"]
		st["text5"]["text"] = CDTL3:ConvertTime(max, tFormat)
		
		if s["mode"]["splitAbs"]["count"] == 1 then
			st["text2"]["used"] = true
			st["text3"]["used"] = false
			st["text4"]["used"] = false
		elseif s["mode"]["splitAbs"]["count"] == 2 then
			st["text2"]["used"] = true
			st["text3"]["used"] = true
			st["text4"]["used"] = false
		elseif s["mode"]["splitAbs"]["count"] == 3 then
			st["text2"]["used"] = true
			st["text3"]["used"] = true
			st["text4"]["used"] = true
		end
	end
end

private.UpdateText = function(f, s)
	for i = 1, 5, 1 do
		local tSettings = nil
		local tObject = nil
		
		if i == 1 then
			tSettings = s["customText"]["text1"]
			tObject = f.c1
		elseif i == 2 then
			tSettings = s["customText"]["text2"]
			tObject = f.c2
		elseif i == 3 then
			tSettings = s["customText"]["text3"]
			tObject = f.c3
		elseif i == 4 then
			tSettings = s["customText"]["text4"]
			tObject = f.c4
		elseif i == 5 then
			tSettings = s["customText"]["text5"]
			tObject = f.c5
		end
		
		if tSettings["enabled"] then
			-- whenever a tag family is due, convert the whole text in one pass
			if (tSettings["dtags"] and f.updateCount % private.dynamicTextPollRate == 0)
				or (tSettings["ttags"] and f.updateCount % private.timeTextPollRate == 0) then
				tObject:SetText(CDTL3:ConvertAllTextTags(tSettings["text"], f))
			end
		end
	end
end