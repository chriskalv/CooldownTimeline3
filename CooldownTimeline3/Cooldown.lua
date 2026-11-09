--[[
	Cooldown Timeline, Vreenak (US-Remulos)
	https://www.curseforge.com/wow/addons/cooldown-timeline
]]--

local private = {}
private.dynamicTextPollRate = 10
private.timeTextPollRate = 2
-- seconds after an item's use in which a readable 0 cooldown read means "no cooldown"
private.itemNoCooldownWindow = 2

function CDTL3:CreateCooldown(UID, cdType, cdData)
	local fName = "CDTL3_CD_"..UID
	local f = CreateFrame("Frame", fName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	
	f.updateCount = 0

	-- the spell data's flag wins whenever it lists the spell (a flag saved by an older build
	-- can be stale, e.g. Forever's Elemental Mastery); otherwise keep the saved one
	local oaf = cdData["oaf"]
	if cdType == "spells" or cdType == "petspells" then
		local dataOaf, dataKnows = CDTL3:IsAuraFadeSpell(cdData["id"], cdData["name"])
		if dataKnows then
			oaf = dataOaf
		end
	end

	f.data = {
		uid = UID,
		id = cdData["id"],
		type = cdType,
		name = cdData["name"],
		rank = cdData["rank"],
		desc = cdData["desc"],
		icon = cdData["icon"],
		oaf = oaf or nil,
		stacks = 0,
		
		targetID = cdData["targetID"],
		targetName = cdData["targetName"],
		
		itemID = cdData["itemID"],
		itemName = cdData["itemName"],
		
		link = cdData["link"],
		
		enabled = cdData["enabled"],
		ignored = cdData["ignored"],
		highlight = cdData["highlight"],
		pinned = cdData["pinned"],
		
		lane = cdData["lane"],
		barFrame = cdData["barFrame"],
		readyFrame = cdData["readyFrame"],
		
		baseCD = cdData["bCD"] / 1000,
		currentCD = cdData["bCD"] / 1000,
		endTime = cdData["endTime"],
		overrideCD = false,
	}

	if cdData["charges"] then
		f.data["charges"] = cdData["charges"]
	end
	
	if cdData["school"] then
		f.data["school"] = cdData["school"]
	end

	if cdData["customColor"] then
		f.data["customColor"] = cdData["customColor"]
		f.data["color"] = cdData["color"]
	end
	
	if cdData["runeIndex"] then
		f.data["runeIndex"] = cdData["runeIndex"]
	end
	
	if cdType == "runes" then
		f.data["runeGraceTime"] = 0
	end

	if cdData["setCustomCD"] then
		f.data["setCustomCD"] = cdData["setCustomCD"]

		if cdData["customCDTime"] then
			f.data["customCDTime"] = cdData["customCDTime"]
			f.data["baseCD"] = f.data["customCDTime"] / 1000
		end
	end

	if cdType == "items" then
		if cdData["itemIcon"] then
			f.data["itemIcon"] = cdData["itemIcon"]
		else
			local spellName, icon, originalIcon = CDTL3:GetSpellInfo(f.data["id"])
			f.data["icon"] = icon
			
			local item = Item:CreateFromItemID(f.data["itemID"])
			item:ContinueOnItemLoad(function()
				f.data["itemIcon"] = item:GetItemIcon()
				
				CDTL3:SetItemData(f.data["itemID"], "icon", f.data["icon"])
				CDTL3:SetItemData(f.data["itemID"], "itemIcon", f.data["itemIcon"])
			end)
		end
	end
	
	if cdData["trigger"] then
		f.data["trigger"] = cdData["trigger"]
	end
	
	-- ON UPDATE
	f:HookScript("OnUpdate", function(self, elapsed)
		private.CooldownUpdate(self, elapsed)
	end)
	
	f.icon = CDTL3:CreateIcon(fName, f)

	-- Create bar BEFORE SendToLane so a RefreshIcon/LSM error in SendToLane
	-- cannot leave f.bar nil and cause 1000x CooldownUpdate crashes.
	f.bar = CDTL3:CreateBar(fName, f)

	CDTL3:SendToLane(f)
	CDTL3:SendToBarFrame(f)
	
	table.insert(CDTL3.cooldowns, f)
	
	return f
end

function CDTL3:CreateIcon(fName, cd)
	local frameName = fName.."_Icon"
	local f = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)

	f.uid = cd.data["uid"]
	f.valid = cd.data["enabled"]
	f.readyTime = 0
	f.yOffset = 0
	f.sOffset = 0
	f.currentCD = 0

	f.tx = f:CreateTexture()
	
	f.db = CreateFrame("Frame", frameName.."_DB", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.db:SetParent(f)
	f.db.bg = f.db:CreateTexture(nil, "BACKGROUND")
	f.db.text = f.db:CreateFontString(nil,"ARTWORK")
	if not CDTL3.db.profile.global["unlockFrames"] then
		f.db:Hide()
	end
	
	f:SetFrameLevel(20)
	return f
end

function CDTL3:CreateBar(fName, cd)
	local frameName = fName.."_Bar"
	local f = CreateFrame("Frame", frameName, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	
	f.valid = cd.data["enabled"]
	
	f.bar = CreateFrame("StatusBar", frameName.."_BA", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.bar:SetParent(f)
	f.bar.transitionThreshold = 0
	f.bar.bg = f:CreateTexture(nil, "BACKGROUND")
	
	f.icon = CreateFrame("Frame", frameName.."_IC", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.icon:SetParent(f)
	f.icon.tx = f.icon:CreateTexture(nil, "BACKGROUND")
	
	f.db = CreateFrame("Frame", frameName.."_DB", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f.db:SetParent(f)
	f.db.bg = f.db:CreateTexture(nil, "BACKGROUND")
	f.db.text = f.db:CreateFontString(nil,"ARTWORK")
	if not CDTL3.db.profile.global["unlockFrames"] then
		f.db:Hide()
	end
	
	f:SetFrameLevel(20)
	return f
end

function CDTL3:RefreshAllBars()
	for _, cd in pairs(CDTL3.cooldowns) do
		CDTL3:RefreshBar(cd)
	end
end

function CDTL3:RefreshAllIcons()
	for _, cd in pairs(CDTL3.cooldowns) do
		CDTL3:RefreshIcon(cd)
	end
end

function CDTL3:RefreshBar(cd)
	local f = cd.bar
	local s = nil
	local p = f:GetParent():GetName()
	
	if p == "CDTL3_BarFrame_1_MF" or p == "CDTL3_BarFrame_2_MF" or p == "CDTL3_BarFrame_3_MF" then
		if cd.data["barFrame"] == 0 or cd.data["barFrame"] == 1 then
			s = CDTL3.db.profile.barFrames["frame1"]
		elseif cd.data["barFrame"] == 2 then
			s = CDTL3.db.profile.barFrames["frame2"]
		elseif cd.data["barFrame"] == 3 then
			s = CDTL3.db.profile.barFrames["frame3"]
		end
	else
		s = CDTL3.db.profile.barFrames["frame1"]
	end
		
	f:ClearAllPoints()
	f:SetPoint("CENTER", 0, 0)
	f:SetWidth(s["width"])
	f:SetHeight(s["height"])
	
	-- ICON
	local barWidth = s["width"]
	local iconOffset = 0
	if s["bar"]["iconEnabled"] then
		if not f.icon then
			f.icon = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.icon:SetParent(f)
		end
		
		barWidth = barWidth - s["height"]
		iconOffset = s["height"]
			
		if s["bar"]["iconPosition"] == "RIGHT" then
			iconOffset = -s["height"]
		end
		
		f.icon:ClearAllPoints()
		f.icon:SetPoint(s["bar"]["iconPosition"], 0, 0)
		f.icon:SetWidth(s["height"])
		f.icon:SetHeight(s["height"])
		
		f.icon.tx:SetAllPoints(f.icon)
		
		local icon = cd.data["icon"]
		f.icon.tx:SetTexture(icon)
		
		local zoom = CDTL3.db.profile.global["zoom"]
		local tl = zoom - 1
		local br = 1 - (zoom - 1)
		f.icon.tx:SetTexCoord(tl, br, tl, br)
		
		if CDTL3.Masque then
			-- Kill masque for this icon(button)
			CDTL3.masqueGroup = CDTL3.Masque:Group("CDTL3")
			CDTL3.masqueGroup:RemoveButton(f.icon)
			
			-- Reapply masque
			CDTL3.masqueGroup:AddButton(f.icon, { Icon = f.icon.tx })
		end
		
		f.icon:Show()
	else
		if f.icon then
			barWidth = s["width"]
			iconOffset = 0
			
			f.icon:ClearAllPoints()
			f.icon:SetPoint(s["bar"]["iconPosition"], 0, 0)
			f.icon:SetWidth(s["height"])
			f.icon:SetHeight(s["height"])
			
			f.icon:Hide()
		end
	end
	
	-- BAR	
	f.bar:ClearAllPoints()
	f.bar:SetPoint(s["bar"]["iconPosition"], iconOffset, 0)
	f.bar:SetSize(barWidth, s["height"])
	
	-- FOREGROUND
	f.bar:SetMinMaxValues(0, 1)
	f.bar:SetValue(0.5)
	CDTL3:SetBarTexture(f.bar, s["bar"]["fgTexture"])
	f.bar:GetStatusBarTexture():SetHorizTile(false)
	f.bar:GetStatusBarTexture():SetVertTile(false)
	--[[f.bar:SetStatusBarColor(
		s["bar"]["fgTextureColor"]["r"],
		s["bar"]["fgTextureColor"]["g"],
		s["bar"]["fgTextureColor"]["b"],
		s["bar"]["fgTextureColor"]["a"]
	)]]--
	
	local fgColor = private.GetBarFGColor(s, cd.data)

	f.bar:SetStatusBarColor(
		fgColor["r"],
		fgColor["g"],
		fgColor["b"],
		fgColor["a"]
	)
	
	-- BACKGROUND
	CDTL3:SetBarTexture(f.bar.bg, s["bar"]["bgTexture"])
	f.bar.bg:SetAllPoints(true)
	--[[f.bar.bg:SetVertexColor(
		s["bar"]["bgTextureColor"]["r"],
		s["bar"]["bgTextureColor"]["g"],
		s["bar"]["bgTextureColor"]["b"],
		s["bar"]["bgTextureColor"]["a"]
	)]]--
	
	local bgColor = s["bar"]["bgTextureColor"]
	if CDTL3.player["class"] then
		if s["bar"]["bgClassColor"] then
			bgColor = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]]
		end
	end
	
	f.bar.bg:SetVertexColor(
		bgColor["r"],
		bgColor["g"],
		bgColor["b"],
		bgColor["a"]
	)
		
	-- TEXT
	if s["bar"]["text1"]["enabled"] or s["bar"]["text2"]["enabled"] or s["bar"]["text3"]["enabled"] then
		if not f.txt then
			f.txt = CreateFrame("Frame", f:GetName().."_TEXT", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.txt:SetParent(f)
			f.txt.bg = f.txt:CreateTexture(nil, "BACKGROUND")
		end
		
		-- TEXT1
		if s["bar"]["text1"]["enabled"] then
			if not f.txt.text1 then
				f.txt.text1 = f.txt:CreateFontString(nil, "ARTWORK")
			end
			
			local ts = s["bar"]["text1"]
			local t = f.txt.text1
			t:ClearAllPoints()
			t:SetPoint(
					ts["align"],
					f,
					ts["anchor"],
					ts["offX"],
					ts["offY"]
				)
			local _ol = ts["outline"]
			if type(_ol) ~= "string" or _ol == "NONE" or _ol == "" then _ol = nil end
			local _fnt, _sz = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
			if _fnt and _sz > 0 then t:SetFont(_fnt, _sz, _ol) end
			t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
			t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
			t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
			t:SetShadowOffset(ts["shadX"], ts["shadY"])
			t:SetNonSpaceWrap(false)
			t:Show()
		else
			if f.txt.text1 then
				f.txt.text1:Hide()
			end
		end
		-- TEXT2
		if s["bar"]["text2"]["enabled"] then
			if not f.txt.text2 then
				f.txt.text2 = f.txt:CreateFontString(nil, "ARTWORK")
			end
			
			local t = f.txt.text2
			local ts = s["bar"]["text2"]
			t:ClearAllPoints()
			t:SetPoint(
					ts["align"],
					f,
					ts["anchor"],
					ts["offX"],
					ts["offY"]
				)
			local _ol = ts["outline"]
			if type(_ol) ~= "string" or _ol == "NONE" or _ol == "" then _ol = nil end
			local _fnt, _sz = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
			if _fnt and _sz > 0 then t:SetFont(_fnt, _sz, _ol) end
			t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
			t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
			t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
			t:SetShadowOffset(ts["shadX"], ts["shadY"])
			t:SetNonSpaceWrap(false)
			t:Show()
		else
			if f.txt.text2 then
				f.txt.text2:Hide()
			end
		end
		-- TEXT3
		if s["bar"]["text3"]["enabled"] then
			if not f.txt.text3 then
				f.txt.text3 = f.txt:CreateFontString(nil, "ARTWORK")
			end
			
			local t = f.txt.text3
			local ts = s["bar"]["text3"]
			t:ClearAllPoints()
			t:SetPoint(
					ts["align"],
					f,
					ts["anchor"],
					ts["offX"],
					ts["offY"]
				)
			local _ol = ts["outline"]
			if type(_ol) ~= "string" or _ol == "NONE" or _ol == "" then _ol = nil end
			local _fnt, _sz = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
			if _fnt and _sz > 0 then t:SetFont(_fnt, _sz, _ol) end
			t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
			t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
			t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
			t:SetShadowOffset(ts["shadX"], ts["shadY"])
			t:SetNonSpaceWrap(false)
			t:Show()
		else
			if f.txt.text3 then
				f.txt.text3:Hide()
			end
		end
	elseif f.txt then
		-- all texts off: f.txt only exists if one was enabled before
		if f.txt.text1 then
			f.txt.text1:Hide()
		end
		
		if f.txt.text2 then
			f.txt.text2:Hide()
		end
		
		if f.txt.text3 then
			f.txt.text3:Hide()
		end
	end
	
	-- TRANSITION
	if s["transition"]["showTI"] then
		if not f.bar.ti then
			f.bar.ti = CreateFrame("Frame", f:GetName().."_TI", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bar.ti:SetParent(f.bar)
			f.bar.ti.bg = f.bar.ti:CreateTexture(nil, "BACKGROUND")
		end
		
		private.CalcTransitionIndicator(cd, s)
		f.bar.ti:Show()
		if f.txt then
			f.txt:SetFrameLevel(f.bar.ti:GetFrameLevel() + 1)
		end
	else
		if f.bar.ti then
			f.bar.ti:Hide()
		end
		
		private.CalcTransitionIndicator(cd, s)
	end	
	
	-- BORDER
	if s["bar"]["border"]["style"] ~= "None" then
		if not f.bd then
			f.bd = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bd:SetParent(f)
		end
		
		CDTL3:SetBorder(f.bd, s["bar"]["border"])
		f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
		f.bd:Show()
	else
		if f.bd then
			f.bd:Hide()
		end
	end
	
	-- DEBUG/UNLOCK
	f.db:ClearAllPoints()
	f.db:SetPoint("CENTER", 0, 0)
	f.db.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 10)
	f.db.text:ClearAllPoints()
	f.db.text:SetPoint("CENTER", 0, 0)
	f.db.text:SetText(cd.data["uid"].."_B\n"..cd.data["name"])
	f.db:SetSize(s["width"], s["height"])
	f.db.bg:SetAllPoints(true)
	f.db.bg:SetColorTexture( 0.1, 0.1, 0.1, 0.5 )
	
	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:DebugOn(f)
	else
		CDTL3:DebugOff(f)
	end
end

function CDTL3:RefreshIcon(cd)
	local f = cd.icon
	local s = CDTL3.db.profile.lanes["lane1"]
	local p = f:GetParent():GetName()
	
	if p == "CDTL3_Lane_1" or p == "CDTL3_Lane_2" or p == "CDTL3_Lane_3" then
		if cd.data["lane"] == 0 or cd.data["lane"] == 1 then
			s = CDTL3.db.profile.lanes["lane1"]
		elseif cd.data["lane"] == 2 then
			s = CDTL3.db.profile.lanes["lane2"]
		elseif cd.data["lane"] == 3 then
			s = CDTL3.db.profile.lanes["lane3"]
		end
	elseif p == "CDTL3_Ready_1_MF" or p == "CDTL3_Ready_2_MF" or p == "CDTL3_Ready_3_MF" then
		if cd.data["readyFrame"] == 0 or cd.data["readyFrame"] == 1 then
			s = CDTL3.db.profile.ready["ready1"]
		elseif cd.data["readyFrame"] == 2 then
			s = CDTL3.db.profile.ready["ready2"]
		elseif cd.data["readyFrame"] == 3 then
			s = CDTL3.db.profile.ready["ready3"]
		end
	end

	if cd.data["setCustomCD"] then
		if cd.data["customCDTime"] then
			cd.data["baseCD"] = cd.data["customCDTime"] / 1000
		else
			local specialCase = false
			if cd.data["type"] == "items" then
				specialCase = true
			end
			local cds = CDTL3:GetSpellSettings(cd.data["name"], cd.data["type"], specialCase)
			if cds then
				cd.data["baseCD"] = cds["bCD"] / 1000
			end
		end
	else
		if cd.data["type"] ~= "testing" then
			local specialCase = false
			if cd.data["type"] == "items" then
				specialCase = true
			end

			local cds = CDTL3:GetSpellSettings(cd.data["name"], cd.data["type"], specialCase)
			if cds then
				cd.data["baseCD"] = cds["bCD"] / 1000
			end
		end
	end
	
	f.yOffset = s["iconOffset"]
	
	f:ClearAllPoints()
	f:SetPoint("CENTER", 0, 0)
	f:SetSize(s["icons"]["size"], s["icons"]["size"])
	
	-- Set the icon texture
	local icon = cd.data["icon"]
	if cd.data["type"] == "items" then
		if CDTL3.db.profile.global[cd.data["type"]]["useItemIcon"] then
			icon = cd.data["itemIcon"]
		end
	end
	f.tx:SetAllPoints()
	f.tx:SetTexture(icon)
	f.tx:SetAlpha(s["icons"]["alpha"])
	
	-- Set the icon texture zoom
	local zoom = CDTL3.db.profile.global["zoom"]
	local tl = zoom - 1
	local br = 1 - (zoom - 1)
	f.tx:SetTexCoord(tl, br, tl, br)
	
	if CDTL3.Masque then
		-- Kill masque for this icon(button)
		CDTL3.masqueGroup = CDTL3.Masque:Group("CDTL3")
		CDTL3.masqueGroup:RemoveButton(f)
		
		-- Reapply masque
		CDTL3.masqueGroup:AddButton(f, { Icon = f.tx })	
	end
	
	-- TEXT
	if s["icons"]["text1"]["enabled"] or s["icons"]["text2"]["enabled"] or s["icons"]["text3"]["enabled"] then
		if not f.txt then
			f.txt = CreateFrame("Frame", f:GetName().."_TEXT", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.txt:SetParent(f)
			f.txt.bg = f.txt:CreateTexture(nil, "BACKGROUND")
		end
		
		-- TEXT1
		if s["icons"]["text1"]["enabled"] then
			if not f.txt.text1 then
				f.txt.text1 = f.txt:CreateFontString(nil, "ARTWORK")
			end
			
			local ts = s["icons"]["text1"]
			local t = f.txt.text1
			t:ClearAllPoints()
			t:SetPoint(
					ts["align"],
					f,
					ts["anchor"],
					ts["offX"],
					ts["offY"]
				)
			local _ol = ts["outline"]
			if type(_ol) ~= "string" or _ol == "NONE" or _ol == "" then _ol = nil end
			local _fnt, _sz = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
			if _fnt and _sz > 0 then t:SetFont(_fnt, _sz, _ol) end
			t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
			t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
			t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
			t:SetShadowOffset(ts["shadX"], ts["shadY"])
			t:SetNonSpaceWrap(false)
			t:Show()
		else
			if f.txt.text1 then
				f.txt.text1:Hide()
			end
		end
		-- TEXT2
		if s["icons"]["text2"]["enabled"] then
			if not f.txt.text2 then
				f.txt.text2 = f.txt:CreateFontString(nil, "ARTWORK")
			end
			
			local t = f.txt.text2
			local ts = s["icons"]["text2"]
			t:ClearAllPoints()
			t:SetPoint(
					ts["align"],
					f,
					ts["anchor"],
					ts["offX"],
					ts["offY"]
				)
			local _ol = ts["outline"]
			if type(_ol) ~= "string" or _ol == "NONE" or _ol == "" then _ol = nil end
			local _fnt, _sz = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
			if _fnt and _sz > 0 then t:SetFont(_fnt, _sz, _ol) end
			t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
			t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
			t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
			t:SetShadowOffset(ts["shadX"], ts["shadY"])
			t:SetNonSpaceWrap(false)
			t:Show()
		else
			if f.txt.text2 then
				f.txt.text2:Hide()
			end
		end
		-- TEXT3
		if s["icons"]["text3"]["enabled"] then
			if not f.txt.text3 then
				f.txt.text3 = f.txt:CreateFontString(nil, "ARTWORK")
			end
			
			local t = f.txt.text3
			local ts = s["icons"]["text3"]
			t:ClearAllPoints()
			t:SetPoint(
					ts["align"],
					f,
					ts["anchor"],
					ts["offX"],
					ts["offY"]
				)
			local _ol = ts["outline"]
			if type(_ol) ~= "string" or _ol == "NONE" or _ol == "" then _ol = nil end
			local _fnt, _sz = CDTL3.LSM:Fetch("font", ts["font"]), tonumber(ts["size"]) or 0
			if _fnt and _sz > 0 then t:SetFont(_fnt, _sz, _ol) end
			t:SetText(CDTL3:ConvertAllTextTags(ts["text"], cd))
			t:SetTextColor(
					ts["color"]["r"],
					ts["color"]["g"],
					ts["color"]["b"],
					ts["color"]["a"]
				)
			t:SetShadowColor(
					ts["shadColor"]["r"],
					ts["shadColor"]["g"],
					ts["shadColor"]["b"],
					ts["shadColor"]["a"]
				)
			t:SetShadowOffset(ts["shadX"], ts["shadY"])
			t:SetNonSpaceWrap(false)
			t:Show()
		else
			if f.txt.text3 then
				f.txt.text3:Hide()
			end
		end
	else
		if f.txt then
			if f.txt.text1 then
				f.txt.text1:Hide()
			end
			
			if f.txt.text2 then
				f.txt.text2:Hide()
			end
			
			if f.txt.text3 then
				f.txt.text3:Hide()
			end
		end
	end
	
	-- BORDER
	if s["icons"]["border"]["style"] ~= "None" then
		if not f.bd then
			f.bd = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
			f.bd:SetParent(f)
		end
		
		CDTL3:SetBorder(f.bd, s["icons"]["border"])
		f.bd:SetFrameLevel(f:GetFrameLevel() + 1)
		f.bd:Show()
	else
		if f.bd then
			f.bd:Hide()
		end
	end
		
	-- HIGHLIGHT BORDER
	if cd.data["highlight"] then
		if s["icons"]["highlight"]["border"]["style"] ~= "None" then
			if not f.hl then
				f.hl = CreateFrame("Frame", f:GetName().."_BD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
				f.hl:SetParent(f)
				f.hl.tx = f.hl:CreateTexture()
			end
			
			CDTL3:SetBorder(f.hl, s["icons"]["highlight"]["border"])
			f.hl:ClearAllPoints()
			f.hl:SetPoint("CENTER", 0, 0)
			f.hl:SetSize(s["icons"]["size"], s["icons"]["size"])
			f.hl.tx:SetAllPoints(true)
			f.hl.tx:SetColorTexture( 1, 1, 1, 0.5 )
			-- fixed offset above the icon (border is +1); incrementing climbed on every refresh
			f.hl:SetFrameLevel(f:GetFrameLevel() + 2)

			CDTL3:RemoveHighlights(f, s)
			
			local style = s["icons"]["highlight"]["style"]
			-- The action-button glow isn't available on every client (e.g. Forever):
			-- fall back to the plain border highlight there.
			if style == "GLOW" and ActionButton_ShowOverlayGlow then
				ActionButton_ShowOverlayGlow(f)
			elseif style == "BORDER" or style == "GLOW" then
				f.hl:SetBackdropBorderColor(
					s["icons"]["highlight"]["border"]["color"]["r"],
					s["icons"]["highlight"]["border"]["color"]["g"],
					s["icons"]["highlight"]["border"]["color"]["b"],
					s["icons"]["highlight"]["border"]["color"]["a"]
				)
			elseif style == "BORDER_FLASH" then
				f.hl:SetBackdropBorderColor(
					s["icons"]["highlight"]["border"]["color"]["r"],
					s["icons"]["highlight"]["border"]["color"]["g"],
					s["icons"]["highlight"]["border"]["color"]["b"],
					s["icons"]["highlight"]["border"]["color"]["a"]
				)
				
				-- created once and reused (a new group per refresh leaked)
				if not f.hl.agBorderPulse then
					f.hl.agBorderPulse = f.hl:CreateAnimationGroup()
					f.hl.agBorderPulse:SetLooping("BOUNCE")
					f.hl.agBorderPulse:SetToFinalAlpha(true)
					
					local borderPulse = f.hl.agBorderPulse:CreateAnimation("Alpha")
					borderPulse:SetFromAlpha(0.2)
					borderPulse:SetToAlpha(1)
					borderPulse:SetDuration(0.5)
					borderPulse:SetOrder(1)
				end
				
				f.hl.agBorderPulse:Play()			
			elseif style == "FLASH" then
				f.hl:ClearAllPoints()
				f.hl:SetPoint("CENTER", 0, 0)
				f.hl:SetSize(s["icons"]["size"], s["icons"]["size"])
				f.hl.tx:SetColorTexture( 1, 1, 1, 1 )
				
				-- created once and reused (a new group per refresh leaked)
				if not f.hl.agPulse then
					f.hl.agPulse = f.hl:CreateAnimationGroup()
					f.hl.agPulse:SetLooping("BOUNCE")
					f.hl.agPulse:SetToFinalAlpha(true)
					
					local borderPulse = f.hl.agPulse:CreateAnimation("Alpha")
					borderPulse:SetFromAlpha(0.2)
					borderPulse:SetToAlpha(1)
					borderPulse:SetDuration(0.5)
					borderPulse:SetOrder(1)
				end
				
				f.hl.agPulse:Play()
			else
				CDTL3:RemoveHighlights(f, s)
			end
			
			f.hl:Show()
		else
			if f.hl then
				f.hl:Hide()
			end
		end
	else
		if f.hl then
			f.hl:Hide()
		end
	end
	
	f:EnableMouse(false)
	
	-- DEBUG/UNLOCK
	f.db:ClearAllPoints()
	f.db:SetPoint("CENTER", 0, 0)
	f.db.text:SetFont(CDTL3.LSM:Fetch("font", "Fira Sans Condensed"), 10)
	f.db.text:ClearAllPoints()
	f.db.text:SetPoint("CENTER", 0, 0)
	f.db.text:SetText(cd.data["uid"].."_B\n"..cd.data["name"])
	f.db:SetSize(s["icons"]["size"], s["icons"]["size"])
	f.db.bg:SetAllPoints(true)
	f.db.bg:SetColorTexture( 0.1, 0.1, 0.1, 0.5 )
	
	if CDTL3.db.profile.global["debugMode"] then
		CDTL3:DebugOn(f)
	else
		CDTL3:DebugOff(f)
	end
end

-- Spell schools only come from the combat log. Where it isn't available (CDTL3:NoCombatLog,
-- which Options.lua also uses to hide the Spell School Color toggle there) the saved setting
-- is ignored, so a profile imported from another client can't paint every bar "Other" with
-- no visible way to turn it off. The setting itself is left as saved.

-- Resolves the foreground color for a bar: the entry's own color (Filters) -> school ->
-- class -> the bar frame's color. Shared by RefreshBar and the dynamic-color restore.
private.GetBarFGColor = function(s, d)
	local fgColor = s["bar"]["fgTextureColor"] or { r = 0.77647, g = 0.11765, b = 0.28235, a = 1 }
	if d and d["customColor"] and d["color"] then
		fgColor = d["color"]
	elseif s["bar"]["fgSchoolColor"] and not CDTL3:NoCombatLog() then
		local schoolColor = CDTL3.db.profile.global["schoolColors"]["Other"]
		if d and d["school"] then
			schoolColor = CDTL3.db.profile.global["schoolColors"][d["school"]] or schoolColor
		end

		fgColor = schoolColor
	elseif CDTL3.player["class"] then
		if s["bar"]["fgClassColor"] then
			fgColor = CDTL3.db.profile.global["classColors"][CDTL3.player["class"]]
		end
	end

	return fgColor
end

-- Dynamic ready-state color: below the warn threshold the bar blends warnColor -> readyColor
-- as the cooldown approaches ready; above it (or when disabled) the configured color applies
private.UpdateBarDynamicColor = function(ba, s, d)
	if not ( s and s["bar"] ) then return end
	local dyn = s["bar"]["dynamicColor"]
	if dyn and dyn["enabled"] then
		local remaining = d["currentCD"]
		local warnT = dyn["warnTime"] or 5

		if remaining <= warnT and warnT > 0 then
			local t = 1 - (remaining / warnT)
			if t < 0 then t = 0 elseif t > 1 then t = 1 end

			local c1 = dyn["warnColor"] or { r = 1, g = 0.6, b = 0, a = 1 }
			local c2 = dyn["readyColor"] or { r = 0.2, g = 0.9, b = 0.2, a = 1 }

			ba.bar:SetStatusBarColor(
				c1["r"] + (c2["r"] - c1["r"]) * t,
				c1["g"] + (c2["g"] - c1["g"]) * t,
				c1["b"] + (c2["b"] - c1["b"]) * t,
				(c1["a"] or 1) + ((c2["a"] or 1) - (c1["a"] or 1)) * t
			)
			ba.dynTinted = true
			return
		end
	end

	if ba.dynTinted then
		ba.dynTinted = false
		local fgColor = private.GetBarFGColor(s, d)
		ba.bar:SetStatusBarColor(fgColor["r"], fgColor["g"], fgColor["b"], fgColor["a"])
	end
end

private.BarUpdate = function(f, elapsed)
	local d = f.data
	local ba = f.bar
	ba.currentCD = d["currentCD"]
	
	local p = ba:GetParent():GetName()
	if p == "CDTL3_BarFrame_1_MF" or p == "CDTL3_BarFrame_2_MF" or p == "CDTL3_BarFrame_3_MF" then
		if d["currentCD"] > 0 then
			local s = nil
			if d["barFrame"] == 1 then
				s = CDTL3.db.profile.barFrames["frame1"]
			elseif d["barFrame"] == 2 then
				s = CDTL3.db.profile.barFrames["frame2"]
			elseif d["barFrame"] == 3 then
				s = CDTL3.db.profile.barFrames["frame3"]
			end
			
			local pBase = d["baseCD"]
			local pCurrent = d["currentCD"]
			
			if d["lane"] == 0 then
				-- For now, do nothing
			else
				if s["transition"]["hideTransitioned"] then
					--CDTL3:Print(tostring(d["currentCD"]).." - "..tostring(ba.transitionThreshold))
					if d["currentCD"] > ba.transitionThreshold then
						if not ba.valid then
							ba.valid = true
							ba:GetParent().triggerUpdate = true
						end
						
						if s["transition"]["style"] == "SHORTEN" then
							pBase = pBase - ba.transitionThreshold
							pCurrent = pCurrent - ba.transitionThreshold
						end
					else
						if ba.valid then
							ba.valid = false
							ba:GetParent().triggerUpdate = true
						end
					end
				end
			end
			
			local iconPercent = private.CalcLinearPosition(pCurrent, pBase)
			ba.bar:SetValue(iconPercent)

			private.UpdateBarDynamicColor(ba, s, d)

			if ba:GetAlpha() ~= 0 and ba.txt then
				private.UpdateText(f, ba.txt.text1, s["bar"]["text1"], s["bar"]["text1"]["text"])
				private.UpdateText(f, ba.txt.text2, s["bar"]["text2"], s["bar"]["text2"]["text"])
				private.UpdateText(f, ba.txt.text3, s["bar"]["text3"], s["bar"]["text3"]["text"])
			end
		else
			CDTL3:SendToBarHolding(f)
		end
	end
end

private.CalcLinearPosition = function(current, total, s)
	local p = 1

	if current < total then
		p = current / total
	end
	
	return p
end

private.CalcSplitPosition = function(current, total, s)
	local p = 1
	local max = 100
	local value = (current / total) * 100
	
	local ss = nil
	if s["mode"]["type"] == "SPLIT" then
		ss = s["mode"]["split"]
		if total > ss["max"] then
			total = ss["max"]
		end
	elseif s["mode"]["type"] == "SPLIT_ABS" then
		ss = s["mode"]["splitAbs"]
		max = ss["max"]
		value = current
		total = ss["max"]
	end
	
	local splits = ss["count"]
	
	if current < total then
		if splits == 1 then
			local s1v = ss["s1v"]
			local s1p = ss["s1p"]
			
			if value > s1v then
				local rPercent = max - s1v
				local rSize = 1 - s1p
				local cPercent = value - s1v
				local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			else
				local rPercent = s1v
				local rSize = s1p
				local cPercent = value - s1v
				local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			end
		elseif splits == 2 then
			local s1v = ss["s1v"]
			local s1p = ss["s1p"]
			local s2v = ss["s2v"]
			local s2p = ss["s2p"]
			
			if value > s2v then
				local rPercent = max - s2v
				local rSize = 1 - s2p
				local cPercent = value - s2v
				local aPercent = cPercent / rPercent
				p = s2p + (rSize * aPercent)
			elseif value > s1v then
				local rPercent = s2v - s1v
				local rSize = s2p - s1p
				local cPercent = value - s1v
				local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			else
				local rPercent = s1v
				local rSize = s1p
				local cPercent = value - s1v
				local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			end
		elseif splits == 3 then
			local s1v = ss["s1v"]
			local s1p = ss["s1p"]
			local s2v = ss["s2v"]
			local s2p = ss["s2p"]
			local s3v = ss["s3v"]
			local s3p = ss["s3p"]
			
			if value > s3v then
				local rPercent = max - s3v
				local rSize = 1 - s3p
				local cPercent = value - s3v
				local aPercent = cPercent / rPercent
				p = s3p + (rSize * aPercent)
			elseif value > s2v then
				local rPercent = s3v - s2v
				local rSize = s3p - s2p
				local cPercent = value - s2v
				local aPercent = cPercent / rPercent
				p = s2p + (rSize * aPercent)
			elseif value > s1v then
				local rPercent = s2v - s1v
				local rSize = s2p - s1p
				local cPercent = value - s1v
				local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			else
				local rPercent = s1v
				local rSize = s1p
				local cPercent = value - s1v
				local aPercent = cPercent / rPercent
				p = s1p + (rSize * aPercent)
			end
		end
	end
	
	return p
end

private.CalcTransitionIndicator = function(f, s)
	local ls = nil
	if f.data["lane"] == 1 then
		ls = CDTL3.db.profile.lanes["lane1"]
	elseif f.data["lane"] == 2 then
		ls = CDTL3.db.profile.lanes["lane2"]
	elseif f.data["lane"] == 3 then
		ls = CDTL3.db.profile.lanes["lane3"]
	end
	
	if ls then
		local mode = ls["mode"]["type"]
		
		local ms = nil
		if mode == "LINEAR" then
			ms = ls["mode"]["linear"]
		elseif mode == "LINEAR_ABS" then
			ms = ls["mode"]["linearAbs"]
		elseif mode == "SPLIT" then
			ms = ls["mode"]["split"]
		elseif mode == "SPLIT_ABS" then
			ms = ls["mode"]["splitAbs"]
		end
		
		f.bar.transitionThreshold = ms["max"]
		
		-- INDICATIOR
		local position = 0
		local width = s["transition"]["width"]
		if s["transition"]["showTI"] then
			local style = s["transition"]["style"]
			
			if style == "SHORTEN" then
				f.bar.bar.ti:SetAlpha(0)
			else
				if style == "LINE" then
					local bWidth = s["width"] - width
					if s["bar"]["iconEnabled"] then
						bWidth = bWidth - s["height"]
					end
					
					--position = (ms["max"] / f.data["baseCD"]) * bWidth
					position = f.data["baseCD"] > 0 and (ms["max"] / f.data["baseCD"]) * bWidth or bWidth
				elseif style == "REGION" then
					-- same zero guard as LINE: a not-yet-learned cooldown (baseCD 0) spans the bar
					local percent = f.data["baseCD"] > 0 and ms["max"] / f.data["baseCD"] or 1
					
					local bWidth = s["width"] - width
					if s["bar"]["iconEnabled"] then
						bWidth = bWidth - s["height"]
					end
					
					width = bWidth * percent
					position = percent / 2
				end
				
				if f.bar.bar.ti then
					f.bar.bar.ti:SetAlpha(1)
				end
			end
		else
			if f.bar.bar.ti then
				f.bar.bar.ti:SetAlpha(0)
			end
		end
		
		if f.bar.bar.ti then		
			f.bar.bar.ti:ClearAllPoints()
			f.bar.bar.ti:SetPoint("LEFT", position, 0)
			f.bar.bar.ti:SetSize(width, s["height"])
			CDTL3:SetBarTexture(f.bar.bar.ti.bg, s["transition"]["texture"])
			f.bar.bar.ti.bg:SetAllPoints(true)
			f.bar.bar.ti.bg:SetVertexColor(
				s["transition"]["textureColor"]["r"],
				s["transition"]["textureColor"]["g"],
				s["transition"]["textureColor"]["b"],
				s["transition"]["textureColor"]["a"]
			)
		end
	else
		if f.bar.bar.ti then
			f.bar.bar.ti:SetAlpha(0)
		end
		
		f.bar.transitionThreshold = 10000000
	end
end

private.CooldownUpdate = function(f, elapsed)
	local d = f.data
	local ic = f.icon
	local ba = f.bar

	-- Guard: f.bar (ba) can be nil if CreateCooldown was interrupted before
	-- the bar was created.  Skip this tick rather than throwing 1000+ errors.
	if not ic or not ba then return end

	local icVisible = ic:IsVisible()
	local baVisible = ba:IsVisible()
	
	if icVisible or baVisible then
		-- SPELLS
		if d["type"] == "spells" or d["type"] == "petspells" then
			if d["oaf"] then
				-- On-aura-fade spells (e.g. Stealth) hold their cooldown while the aura is up,
				-- during a channel, or while the game reports the cooldown disabled. Checked on
				-- the 50-frame poll and cached: the aura scan is too costly for every frame,
				-- and the countdown re-syncs from the game on the same poll, so nothing drifts.
				-- enabled is a boolean on retail-API clients and 0/1 on Classic.
				if f.updateCount == 0 or f.updateCount % 50 == 0 or d["oafHeld"] == nil then
					local auraUp = CDTL3:AuraExists("player", d["name"])
					local channelOK, channeling = pcall(function()
						return UnitChannelInfo("player") and true or false
					end)
					local _, _, enabled = CDTL3:GetSpellCooldown(d["id"])
					-- the game's own hold: the effect is up, or the cooldown is reported not started
					local gameHeld = (auraUp or enabled == 0 or enabled == false) and true or false

					-- The cooldown really starts when the game's hold ends, not at the cast. Record
					-- that as the spell's start for GetSpellCooldown's secret-value fallback
					-- (Helpers.lua), which counts from the cast time it finds here: a Stealth
					-- opener after 20s of stealth showed Ready with 10s left. Readable timing still
					-- wins, since the fallback only runs while it's secret. A channel alone doesn't
					-- count, so channelling mid-cooldown doesn't restart it.
					if d["oafGameHeld"] and not gameHeld then
						if not CDTL3.spellCastTimes then CDTL3.spellCastTimes = {} end
						CDTL3.spellCastTimes[d["id"]] = GetTime()
					end

					d["oafGameHeld"] = gameHeld
					d["oafHeld"] = (gameHeld or (channelOK and channeling)) and true or false
				end

				if not d["oafHeld"] then
					if d["currentCD"] >= 0 then
						d["currentCD"] = d["currentCD"] - elapsed
					
					
						if not d["overrideCD"] then
							if f.updateCount == 0 or f.updateCount % 50 == 0 then
								if d["setCustomCD"] then
									if d["customCDTime"] then
										d["baseCD"] = d["customCDTime"] / 1000
									end
								end


								--local start, duration, enabled, _ = GetSpellCooldown(d["id"])
								local start, duration, enabled = CDTL3:GetSpellCooldown(d["id"])
								-- Manual override wins: the live Midnight duration is the talent-blind base
								-- CD, so when a custom CD is set, drive the countdown from that instead.
								if d["setCustomCD"] and d["customCDTime"] then
									d["baseCD"] = d["customCDTime"] / 1000
									duration = d["baseCD"]
								end
								d["currentCD"] = start + duration - GetTime()
							end
						end
					end
				end
			else
				if d["currentCD"] >= 0 then
					d["currentCD"] = d["currentCD"] - elapsed

					if not d["overrideCD"] then
						if f.updateCount == 0 or f.updateCount % 50 == 0 then
							if d["setCustomCD"] then
								if d["customCDTime"] then
									d["baseCD"] = d["customCDTime"] / 1000
								end
							end

							--local start, duration, enabled, _ = GetSpellCooldown(d["id"])
							--local start, duration, enabled = CDTL3:GetSpellCooldown(d["id"])
							--d["currentCD"] = start + duration - GetTime()

							--if d["charges"] ~= 0 then
								--local currentCharges, maxCharges, cooldownStart, cooldownDuration = CDTL3:GetSpellCharges(d["id"])

								--if currentCharges < maxCharges then
									--CDTL3:Print("CHARGES")
								--end
							--else
								--CDTL3:Print("NO CHARGES")


								local start, duration, enabled = CDTL3:GetSpellCooldown(d["id"])
								-- Manual override wins: Midnight's live duration is the talent-blind base
								-- CD, so when a custom CD is set, drive the countdown from that instead.
								if d["setCustomCD"] and d["customCDTime"] then
									d["baseCD"] = d["customCDTime"] / 1000
									duration = d["baseCD"]
									-- LOCAL PATCH (Zippy, 2026-11-09): a spell without a cooldown of its own
									-- (a Paladin seal) reports start 0 once the GCD is over, and at once in
									-- combat; count the custom time from the player's own cast instead.
									if start == 0 and CDTL3.spellCastTimes and CDTL3.spellCastTimes[d["id"]] then
										start = CDTL3.spellCastTimes[d["id"]]
									end
								end
								d["currentCD"] = start + duration - GetTime()

								--if d["name"] == "Primal Rage" or d["name"] == "Implosive Trap" then
									--CDTL3:Print(d["name"].." - "..d["currentCD"].." : "..tostring(duration))
								--end
							--end
							
							if f.updateCount == 0 and CDTL3.db.profile.global["detectSharedCD"] then
								CDTL3:ScanSharedSpellCooldown(d["name"], d["currentCD"])
							end
						end
					end
				end
			end
			
		-- ITEMS
		elseif d["type"] == "items" then
			if f.updateCount % 50 == 0 then
				-- An item saved without a cooldown yet (bCD 0) learns it, and whether it's
				-- ignored, while it's counting down: from any positive, readable read, and from
				-- a readable 0 only right after its use (see below). nil (secret) teaches
				-- nothing. A ready item waits for its next use.
				if d["baseCD"] == 0 and d["currentCD"] >= 0 then
					d["currentCD"] = 1000
					
					-- nil while the item cooldown is secret: decide nothing yet, retry next poll
					local duration = nil
					local tinker, slot = CDTL3:CheckEngTinkerCases(d["name"])
					if tinker then
						local _, spellID = CDTL3.Compat.GetItemSpell(d["itemID"])
						if spellID == d["id"] then
							local _
							_, duration = CDTL3:GetInventoryItemCooldown(slot)
						end
					else
						local _
						_, duration = CDTL3:GetItemCooldown(d["itemID"])
					end
					
					-- A 0 read means "no cooldown" (food, drink: saved as ignored) only when it's
					-- taken within a moment of the use, which the use handler records as the
					-- cast time: a real cooldown would already show. A later 0, e.g. the first
					-- readable read after a cooldown that stayed secret until it ran out (WoW:
					-- Forever, in combat), teaches nothing: it used to hide the item for good.
					local usedAt = CDTL3.spellCastTimes and CDTL3.spellCastTimes[d["id"]]
					local justUsed = usedAt and GetTime() - usedAt <= private.itemNoCooldownWindow

					if duration and (duration > 0 or justUsed) then
						d["baseCD"] = duration
						CDTL3:SetItemData(d["itemID"], "bCD", duration * 1000)
						
						if d["baseCD"] > 3 and d["baseCD"] <= CDTL3.db.profile.global["items"]["ignoreThreshold"] then
							d["ignored"] = false
							CDTL3:SetItemData(d["itemID"], "ignored", false)
						else
							d["ignored"] = true
							CDTL3:SetItemData(d["itemID"], "ignored", true)
							
							CDTL3:SendToHolding(f)
							CDTL3:SendToBarHolding(f)
						end
					end
				end
			end
			
			d["currentCD"] = d["currentCD"] - elapsed
			if d["currentCD"] >= 0 then
				if f.updateCount % 50 == 0 then
					local tinker, slot = CDTL3:CheckEngTinkerCases(d["name"])
					if tinker then
						local _, spellID = CDTL3.Compat.GetItemSpell(d["itemID"])
						if spellID == d["id"] then
							--local start, duration, enabled = GetInventoryItemCooldown("player", slot)
							--d["baseCD"] = duration
							--d["currentCD"] = start + duration - GetTime()

							local start, duration, enabled = CDTL3:GetInventoryItemCooldown(slot)
							if start and duration then
								-- a 0 read means ready: it ends the countdown but doesn't unlearn the cooldown
								if duration > 0 then
									d["baseCD"] = duration
								end
								d["currentCD"] = start + duration - GetTime()
							end
						end
					else
						local start, duration, enabled = CDTL3:GetItemCooldown(d["itemID"])
						if duration and start then
							if duration > 0 then
								d["baseCD"] = duration
							end
							d["currentCD"] = start + duration - GetTime()
						end
					end
				end
			end
			
		-- AURAS
		elseif d["type"] == "buffs" or d["type"] == "debuffs" then
			if f.updateCount == 0 or f.updateCount % 50 == 0 then
				local s, unknown = CDTL3:AuraExists("player", d["name"])
				if s then
					d["currentCD"] = s["endTime"] - GetTime()
					d["stacks"] = s["stacks"]
				elseif unknown then
					-- Auras are secret (combat, encounters, M+, PvP): keep counting down from
					-- the last known expiry instead of dropping the icon. Re-read once
					-- readable; PLAYER_REGEN_ENABLED also rescans for recasts made meanwhile.
					if d["currentCD"] >= 0 then
						d["currentCD"] = d["currentCD"] - elapsed
					end
				else
					d["currentCD"] = -1
				end
			else
				if d["currentCD"] >= 0 then
					d["currentCD"] = d["currentCD"] - elapsed
				end
			end
			
		-- OFFENSIVES
		elseif d["type"] == "offensives" then
			if f.updateCount == 0 or f.updateCount % 50 == 0 then
				if d["baseCD"] == 0 then
					local s = CDTL3:AuraExists("target", d["name"])
					if s then
						d["baseCD"] = s["bCD"] / 1000
						d["currentCD"] = s["endTime"] - GetTime()
						d["stacks"] = s["stacks"]
						
						CDTL3:SetSpellData(d["name"], "offensives", "bCD", s["bCD"])
						
						-- the live cooldown's flag (d), not the throwaway aura table, decides visibility
						if d["baseCD"] > 3 and d["baseCD"] <= CDTL3.db.profile.global["offensives"]["ignoreThreshold"] then
							d["ignored"] = false
							CDTL3:SetSpellData(d["name"], "offensives", "ignored", false)
						else
							d["ignored"] = true
							CDTL3:SetSpellData(d["name"], "offensives", "ignored", true)
							
							CDTL3:SendToHolding(f)
							CDTL3:SendToBarHolding(f)
						end
					end
				end
			end

			-- count down every frame (the poll used to skip it once every 50 frames)
			if d["currentCD"] >= 0 then
				d["currentCD"] = d["currentCD"] - elapsed
			end
		
		-- CUSTOMS
		elseif d["type"] == "customs" then
			d["currentCD"] = d["currentCD"] - elapsed

		-- RUNES
		elseif d["type"] == "runes" then
			d["currentCD"] = d["currentCD"] - elapsed
		
		-- TEST/UTILITY
		elseif d["type"] == "testing" or d["type"] == "spacer" then
			d["currentCD"] = d["currentCD"] - elapsed
		end
		
		if icVisible then
			private.IconUpdate(f, elapsed)
		end
		
		if baVisible then
			private.BarUpdate(f, elapsed)
		end
	end
	
	f.updateCount = f.updateCount + 1
	
	if f.updateCount > 12000 then
		f.updateCount = 1
	end
	
	private.ShowHide(f)
end

private.IconUpdate = function(f, elapsed)
	local d = f.data
	local ic = f.icon
	ic.currentCD = d["currentCD"]
	ic.pinned = d["pinned"]
	
	local p = ic:GetParent():GetName()
	if p == "CDTL3_Lane_1" or p == "CDTL3_Lane_2" or p == "CDTL3_Lane_3" then
		if d["currentCD"] > 0 then
			local s = nil
			if d["lane"] == 1 then
				s = CDTL3.db.profile.lanes["lane1"]
			elseif d["lane"] == 2 then
				s = CDTL3.db.profile.lanes["lane2"]
			elseif d["lane"] == 3 then
				s = CDTL3.db.profile.lanes["lane3"]
			end
			
			local iconPercent = 1
			local mode = s["mode"]["type"]
			local max = nil
			local hideTimeSurplus = nil
			
			if mode == "LINEAR" then
				max = s["mode"]["linear"]["max"]
				hideTimeSurplus = s["mode"]["linear"]["hideTimeSurplus"]
				
				local baseCD = d["baseCD"]
				if d["baseCD"] > max then
					baseCD = max
				end
				
				iconPercent = private.CalcLinearPosition(d["currentCD"], baseCD, s)
			elseif mode == "LINEAR_ABS" then
				max = s["mode"]["linearAbs"]["max"]
				hideTimeSurplus = s["mode"]["linearAbs"]["hideTimeSurplus"]
				iconPercent = private.CalcLinearPosition(d["currentCD"], max, s)
			elseif mode == "SPLIT" then
				max = s["mode"]["split"]["max"]
				hideTimeSurplus = s["mode"]["split"]["hideTimeSurplus"]
				
				local baseCD = d["baseCD"]
				if d["baseCD"] > max then
					baseCD = max
				end
				
				iconPercent = private.CalcSplitPosition(d["currentCD"], baseCD, s)
			elseif mode == "SPLIT_ABS" then
				max = s["mode"]["splitAbs"]["max"]
				hideTimeSurplus = s["mode"]["splitAbs"]["hideTimeSurplus"]
				
				iconPercent = private.CalcSplitPosition(d["currentCD"], d["baseCD"], s)
			end
			
			if d["currentCD"] > max then
				if hideTimeSurplus == true then
					if ic.valid then
						ic.valid = false
						ic:GetParent().triggerUpdate = true
					end
				else
					if not ic.valid then
						ic.valid = true
						ic:GetParent().triggerUpdate = true
					end
				end
			else
				if not ic.valid then
					ic.valid = true
					ic:GetParent().triggerUpdate = true
				end
			end
			
			local iconPosition = (s["width"] - s["icons"]["size"]) * iconPercent
			
			local anchor = "LEFT"
			if s["vertical"] then
				if s["reversed"] then
					anchor = "TOP"
					iconPosition = -iconPosition
				else
					anchor = "BOTTOM"
				end
				
				ic:ClearAllPoints()
				ic:SetPoint(anchor, ic.yOffset + ic.sOffset, iconPosition)
			else
				if s["reversed"] then
					anchor = "RIGHT"
					iconPosition = -iconPosition
				end
				
				ic:ClearAllPoints()
				ic:SetPoint(anchor, iconPosition, ic.yOffset + ic.sOffset)
				ic:SetPoint(anchor, iconPosition, ic.yOffset + ic.sOffset)
			end
			
			if ic:GetAlpha() ~= 0 then
				if ic.txt then
					private.UpdateText(f, ic.txt.text1, s["icons"]["text1"], s["icons"]["text1"]["text"])
					private.UpdateText(f, ic.txt.text2, s["icons"]["text2"], s["icons"]["text2"]["text"])
					private.UpdateText(f, ic.txt.text3, s["icons"]["text3"], s["icons"]["text3"]["text"])
				end
			end
			
			if CDTL3.db.profile.global["enableTooltip"] then	
				if ic:IsMouseOver() then
					-- build the tooltip once per hover, not every frame
					if d.link and not (GameTooltip:IsOwned(ic) and GameTooltip:IsShown()) then
						GameTooltip_SetDefaultAnchor(GameTooltip, ic)
						GameTooltip:SetHyperlink(d.link)
						GameTooltip:Show()
					end	
				else	
					if GameTooltip:IsOwned(ic) then	
						GameTooltip:Hide()	
					end	
				end	
			end	
			
			if s["stacking"]["raiseOnMouseOver"] then	
				if ic:IsMouseOver() then	
					ic:SetFrameStrata("HIGH")	
				else
					ic:SetFrameStrata("MEDIUM")	
				end	
			end
		else
			if d["type"] == "spacer" then
				
			elseif d["type"] == "test" then
				
			else
				CDTL3:SendToReady(f)
			end
		end
	elseif p == "CDTL3_Ready_1_MF" or p == "CDTL3_Ready_2_MF" or p == "CDTL3_Ready_3_MF" then
		if ic.readyTime > 0 then
			if not f.data["pinned"] then
				ic.readyTime = ic.readyTime - elapsed
			end
			
			if CDTL3.db.profile.global["enableTooltip"] then	
				if ic:IsMouseOver() then
					-- build the tooltip once per hover, not every frame
					if d.link and not (GameTooltip:IsOwned(ic) and GameTooltip:IsShown()) then
						GameTooltip_SetDefaultAnchor(GameTooltip, ic)
						GameTooltip:SetHyperlink(d.link)
						GameTooltip:Show()
					end	
				else	
					if GameTooltip:IsOwned(ic) then	
						GameTooltip:Hide()	
					end	
				end
			end
		else
			if d["type"] == "testing" then
				if CDTL3.db.profile.global["testingLoop"] then
					CDTL3:SendToLane(f)
					CDTL3:SendToBarFrame(f)
				else
					CDTL3:SendToHolding(f)
				end
			else
				CDTL3:SendToHolding(f)
			end
		end
	else
		-- Do Nothing
	end
	
	if CDTL3.db.profile.global["notUsableTint"] then
		if f.data["type"] == "spells" or f.data["type"] == "petspells" then
			local usable, noPower = CDTL3:IsUsableSpell(f.data["id"])
			if noPower then
				if CDTL3.db.profile.global["notUsableDesaturate"] then
					ic.tx:SetDesaturated(1)
				else
					ic.tx:SetDesaturated(nil)
					ic.tx:SetVertexColor(
						CDTL3.db.profile.global["notUsableColor"]["r"],
						CDTL3.db.profile.global["notUsableColor"]["g"],
						CDTL3.db.profile.global["notUsableColor"]["b"],
						CDTL3.db.profile.global["notUsableColor"]["a"]
					)
				end
			else
				ic.tx:SetDesaturated(nil)
				ic.tx:SetVertexColor(1, 1, 1, 1)
			end
		end
	end
end

function CDTL3:SendToBarFrame(f)
	local ba = f.bar
	
	if f.data["barFrame"] == 1 then
		if CDTL3_BarFrame_1_MF then
			ba:GetParent().triggerUpdate = true
			ba:SetParent(CDTL3_BarFrame_1_MF)
			CDTL3_BarFrame_1_MF.triggerUpdate = true		
		else
			CDTL3:SendToBarHolding(f)
		end
	elseif f.data["barFrame"] == 2 then
		if CDTL3_BarFrame_2_MF then
			ba:GetParent().triggerUpdate = true
			ba:SetParent(CDTL3_BarFrame_2_MF)
			CDTL3_BarFrame_2_MF.triggerUpdate = true
		else
			CDTL3:SendToBarHolding(f)
		end
	elseif f.data["barFrame"] == 3 then
		if CDTL3_BarFrame_3_MF then
			ba:GetParent().triggerUpdate = true
			ba:SetParent(CDTL3_BarFrame_3_MF)
			CDTL3_BarFrame_3_MF.triggerUpdate = true
		else
			CDTL3:SendToBarHolding(f)
		end
	else
		CDTL3:SendToBarHolding(f)
	end
	
	CDTL3:RefreshBar(f)
end

function CDTL3:SendToBarHolding(f)
	local ba = f.bar
	
	if f.data["type"] == "offensives" then
		ba:GetParent().triggerUpdate = true
		ba:SetParent(CDTL3_Offensive_Bar_Holding)
	else
		ba:GetParent().triggerUpdate = true
		ba:SetParent(CDTL3_Bar_Holding)
	end
	
	CDTL3:RefreshBar(f)
end

function CDTL3:SendToHolding(f)	
	local ic = f.icon
	
	if f.data["type"] == "offensives" then
		ic:GetParent().triggerUpdate = true
		ic:SetParent(CDTL3_Offensive_Icon_Holding)
		f.data["overrideCD"] = false
	else
		ic:GetParent().triggerUpdate = true
		ic:SetParent(CDTL3_Active_Icon_Holding)
		f.data["overrideCD"] = false
		--ic:Hide()
	end
	
	if GameTooltip:IsOwned(ic) then	
		GameTooltip:Hide()	
	end
	
	CDTL3:RefreshIcon(f)
end

function CDTL3:SendToLane(f)
	local ic = f.icon
	
	if f.data["lane"] == 1 then
		if CDTL3_Lane_1 then
			ic:GetParent().triggerUpdate = true
			ic:SetParent(CDTL3_Lane_1)
			CDTL3_Lane_1.triggerUpdate = true
		else
			CDTL3:SendToHolding(f)
		end
	elseif f.data["lane"] == 2 then
		if CDTL3_Lane_2 then
			ic:GetParent().triggerUpdate = true
			ic:SetParent(CDTL3_Lane_2)
			CDTL3_Lane_2.triggerUpdate = true
		else
			CDTL3:SendToHolding(f)
		end
	elseif f.data["lane"] == 3 then
		if CDTL3_Lane_3 then
			ic:GetParent().triggerUpdate = true
			ic:SetParent(CDTL3_Lane_3)
			CDTL3_Lane_3.triggerUpdate = true
		else
			CDTL3:SendToHolding(f)
		end
	else
		CDTL3:SendToHolding(f)
	end
	
	CDTL3:RefreshIcon(f)
	
	-- restart the poll counter so the next update re-syncs with the game immediately
	f.updateCount = 0
	f.data["currentCD"] = f.data["baseCD"]
end

-- Move a cooldown to its (newly set) lane without restarting it. SendToLane restarts the
-- countdown, which is right for a cast but not for a settings change: on a finished icon it
-- restarted custom timers at full length, played a ready sound per icon, and made a ready
-- item read 0 and unlearn its cooldown. An icon still counting down moves and keeps its
-- remaining time; a finished one stays put and uses the new lane from its next use.
function CDTL3:MoveToLane(f)
	local remaining = f.data["currentCD"]
	if remaining and remaining > 0 then
		CDTL3:SendToLane(f)
		f.data["currentCD"] = remaining
	end
end

function CDTL3:SendToReady(f)
	local ic = f.icon
	local s = nil
	
	if f.data["readyFrame"] == 1 then
		if CDTL3_Ready_1_MF then
			ic:GetParent().triggerUpdate = true
			ic:SetParent(CDTL3_Ready_1_MF)
			s = CDTL3.db.profile.ready["ready1"]
			ic.readyTime = s["nTime"]
			
			if f.data["highlight"] then
				if s["hSound"] ~= "None" then
					PlaySoundFile(CDTL3.LSM:Fetch("sound", s["hSound"]), "SFX")
				end
			else
				if s["nSound"] ~= "None" then
					PlaySoundFile(CDTL3.LSM:Fetch("sound", s["nSound"]), "SFX")
				end
			end
			
			CDTL3_Ready_1.combatTimer = 0
			CDTL3_Ready_1_MF.triggerUpdate = true
			f.data["overrideCD"] = false
		else
			CDTL3:SendToHolding(f)
		end		
	elseif f.data["readyFrame"] == 2 then
		if CDTL3_Ready_2_MF then
			ic:GetParent().triggerUpdate = true
			ic:SetParent(CDTL3_Ready_2_MF)
			s = CDTL3.db.profile.ready["ready2"]
			ic.readyTime = s["nTime"]
			
			if f.data["highlight"] then
				if s["hSound"] ~= "None" then
					PlaySoundFile(CDTL3.LSM:Fetch("sound", s["hSound"]), "SFX")
				end
			else
				if s["nSound"] ~= "None" then
					PlaySoundFile(CDTL3.LSM:Fetch("sound", s["nSound"]), "SFX")
				end
			end
			
			CDTL3_Ready_2.combatTimer = 0
			CDTL3_Ready_2_MF.triggerUpdate = true
			f.data["overrideCD"] = false
		else
			CDTL3:SendToHolding(f)
		end
	elseif f.data["readyFrame"] == 3 then
		if CDTL3_Ready_3_MF then
			ic:GetParent().triggerUpdate = true
			ic:SetParent(CDTL3_Ready_3_MF)
			s = CDTL3.db.profile.ready["ready3"]
			ic.readyTime = s["nTime"]
			
			if f.data["highlight"] then
				if s["hSound"] ~= "None" then
					PlaySoundFile(CDTL3.LSM:Fetch("sound", s["hSound"]), "SFX")
				end
			else
				if s["nSound"] ~= "None" then
					PlaySoundFile(CDTL3.LSM:Fetch("sound", s["nSound"]), "SFX")
				end
			end
			
			CDTL3_Ready_3.combatTimer = 0
			CDTL3_Ready_3_MF.triggerUpdate = true
			f.data["overrideCD"] = false
		else
			CDTL3:SendToHolding(f)
		end
	else
		CDTL3:SendToHolding(f)
	end
	
	CDTL3:RefreshIcon(f)
end

private.ShowHide = function(f)
	if f.data["ignored"] then
		f.icon.valid = false
		f.bar.valid = false

		if CDTL3.db.profile.global["debugMode"] then
			f.bar:SetAlpha(0.35)
			f.icon:SetAlpha(0.35)
		else
			f.bar:SetAlpha(0)
			f.icon:SetAlpha(0)
		end
	else
		if f.data["enabled"] then
			-- ICONS
			if f.icon.valid then
				f.icon:SetAlpha(1)
			else
				if CDTL3.db.profile.global["debugMode"] then
					f.icon:SetAlpha(0.35)
				else
					f.icon:SetAlpha(0)
				end
			end
			-- BARS
			if f.bar.valid then
				f.bar:SetAlpha(1)
			else
				if CDTL3.db.profile.global["debugMode"] then
					f.bar:SetAlpha(0.35)
				else
					f.bar:SetAlpha(0)
				end
			end
		else
			f.icon.valid = false
			f.bar.valid = false
			
			if CDTL3.db.profile.global["debugMode"] then
				f.bar:SetAlpha(0.35)
				f.icon:SetAlpha(0.35)
			else
				f.bar:SetAlpha(0)
				f.icon:SetAlpha(0)
			end
		end
	end
end

private.UpdateText = function(f, tf, s, iString)
	if s["enabled"] then
		-- dynamic tags poll at their rate, time tags faster in the last 10s; whenever
		-- either is due the whole text is converted (all tag families in one pass)
		local due = false
		if s["dtags"] and f.updateCount % private.dynamicTextPollRate == 0 then
			due = true
		end
		
		if s["ttags"] then
			local timeRate = private.timeTextPollRate
			if f.data["currentCD"] > 10 then
				timeRate = timeRate * 3
			end
			if f.updateCount % timeRate == 0 then
				due = true
			end
		end
		
		if due then
			tf:SetText(CDTL3:ConvertAllTextTags(s["text"], f))
		end
	end
end