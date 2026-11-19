-- Scenarios for the border fix of the release 3.2.2 on the real CDTL3:SetBorder and its helpers from
-- Helpers.lua (after border_secret_env.lua). Until 3.2.1.1 the local patch Border frames tolerate
-- hidden geometry did this; since 3.2.2 the release does it itself, and these scenarios (the patch's
-- cases plus changed settings, several frames and an unreadable answer) stay as a regression test of
-- the personal build. HELPERS (the release's private functions) comes from border_secret.test.mjs.
-- The stub engine sends OnSizeChanged whenever a frame's size or the secrecy of its anchors changes,
-- as the game does.
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. m end
local STYLE = { style = "CDTL3 Pixel", color = { r = 1, g = 0.8, b = 0, a = 1 }, size = 1, padding = 0, inset = 0 }
local WIDE = { style = "CDTL3 Shadow", color = { r = 0, g = 0, b = 0, a = 1 }, size = 2, padding = 0, inset = 0 }
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end
local function expected(w, edge) return math.max(0, (w / edge) * 0.65 - 2 - 0.0625) end
local function right(f, w, edge)
	edge = edge or 1
	return f.coords and near(f.coords.x, expected(w, edge)) and near(f.coords.y, expected(w, edge))
end

-- a lane, an icon on it and the icon's border frame, as RefreshIcon makes them (Cooldown.lua:
-- CreateFrame on UIParent with BackdropTemplate, SetParent(icon), CDTL3:SetBorder)
local n = 0
local function iconWithBorder()
	n = n + 1
	local lane = CreateFrame("Frame", "Lane" .. n, UIParent)
	lane:SetSize(300, 30)
	lane:SetPoint("CENTER")
	local ic = CreateFrame("Frame", "Icon" .. n, lane, "BackdropTemplate")
	ic:SetSize(30, 30)
	ic:SetPoint("CENTER", 0, 0)
	local bd = CreateFrame("Frame", ic:GetName() .. "_BD", UIParent, "BackdropTemplate")
	bd:SetParent(ic)
	return lane, ic, bd
end
-- the highlight frame (Cooldown.lua: SetBorder, then one point on the icon's centre and a size)
local function highlight(ic, style)
	local hl = CreateFrame("Frame", ic:GetName() .. "_HL", UIParent, "BackdropTemplate")
	hl:SetParent(ic)
	CDTL3:SetBorder(hl, style or STYLE)
	hl:ClearAllPoints()
	hl:SetPoint("CENTER", 0, 0)
	hl:SetSize(30, 30)
	return hl
end
-- PlaceIcon (CombatTimers.lua): the icon hangs on the fill of a StatusBar with a hidden value
local function ride(ic)
	local fill = CreateFrame("Frame", nil, ic:GetParent())
	fill.secretMark = true
	ic:ClearAllPoints()
	ic:SetPoint("LEFT", fill, "RIGHT", 0, 0)
end
-- after combat IconUpdate places it the normal way again
local function land(ic)
	ic:ClearAllPoints()
	ic:SetPoint("LEFT", ic:GetParent(), "LEFT", 0, 0)
end
local function try(fn, ...) local ok, err = pcall(fn, ...); return ok, tostring(err) end

-- 0. the stub world throws like the game: Blizzard's computation on a border in a riding icon's chain
do
	local _, ic, bd = iconWithBorder()
	bd.backdropInfo = { edgeFile = "x", edgeSize = 1 }
	bd:SetPoint("TOPLEFT", ic, "TOPLEFT", 0, 0)
	bd:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT", 0, 0)
	local ok, err = try(ride, ic)
	check(not ok and err:find("secret number value", 1, true), "control: without the guard a riding icon's border throws (" .. err .. ")")
	land(ic)
end

-- 1. an ordinary border: worked out as before the fix; the same settings set no new backdrop
do
	local _, ic, bd = iconWithBorder()
	local runs = COORDS_RUNS
	local ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	check(ok, "ordinary: SetBorder runs (" .. err .. ")")
	check(COORDS_RUNS >= runs + 2 and right(bd, 30), "ordinary: SetBackdrop and then OnSizeChanged (the two points) work out the coordinates")
	check(bd.borderColor and bd.borderColor[1] == 1 and #bd.points == 2 and bd.points[1].rel == ic, "ordinary: colour and the two points on the icon")
	check(bd:GetScript("OnUpdate") == nil, "ordinary: no retry on the frame")
	runs = COORDS_RUNS
	ic:SetSize(40, 40)
	check(COORDS_RUNS == runs + 1 and right(bd, 40), "ordinary: OnSizeChanged works them out again (OnBackdropSizeChanged)")
	local info = bd.backdropInfo
	runs = COORDS_RUNS
	CDTL3:SetBorder(bd, STYLE)
	check(bd.backdropInfo == info and COORDS_RUNS == runs and right(bd, 40), "ordinary: a second SetBorder with the same settings keeps the backdrop table (SetBackdrop does nothing)")
	check(bd.SetupTextureCoordinates == HELPERS.BorderTexCoords, "ordinary: the frame's SetupTextureCoordinates goes through the guard")
end

-- 2. the border of a riding icon: no error from OnSizeChanged or SetBorder; right again after combat
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	local before = bd.coords
	local ok, err = try(ride, ic)
	check(ok, "riding: OnSizeChanged in the hidden chain throws nothing (" .. err .. ")")
	check(issecretvalue(bd:GetWidth()) and issecretvalue(bd:GetHeight()), "riding: the border's width and height are secret")
	check(bd.coords == before, "riding: the coordinates are left as they were")
	check(bd:GetScript("OnUpdate") == HELPERS.RetileWhenPlain, "riding: a retry waits for a readable size")
	ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	check(ok, "riding: SetBorder throws nothing (" .. err .. ")")
	check(bd.backdropInfo and bd.backdropInfo.edgeFile and bd.borderColor and #bd.points == 2, "riding: SetBorder still sets backdrop, colour and points")
	ok, err = try(function() for _ = 1, 5 do bd:Tick() end end)
	check(ok and bd.coords == before and bd:GetScript("OnUpdate") == HELPERS.RetileWhenPlain, "riding: the retry waits while the size is secret (" .. err .. ")")
	ic.w, ic.h = 36, 36	-- a new size while hidden (no OnSizeChanged for it reaches a readable frame)
	land(ic)
	check(right(bd, 36), "after combat: the border is worked out from the current size")
	check(bd:GetScript("OnUpdate") == nil, "after combat: the readable OnSizeChanged ends the waiting retry")
	local after = COORDS_RUNS
	bd:Tick()
	check(COORDS_RUNS == after, "after combat: nothing runs every frame any more")
	ic:SetSize(30, 30)
	check(COORDS_RUNS == after + 1 and right(bd, 30), "after combat: OnSizeChanged works as before")
end

-- 3. the retry alone: no OnSizeChanged when the size becomes readable (same size, the engine stays quiet)
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	ride(ic)
	bd.coords = nil	-- e.g. the backdrop was set again while hidden
	bd.layoutKey = nil
	-- land without an engine pass: the anchors are readable again, but no OnSizeChanged comes
	ic.points = { { point = "LEFT", rel = ic:GetParent() } }
	bd.layoutKey = "30x30"
	check(not issecretvalue(bd:GetWidth()) and bd.coords == nil, "retry: the size is readable and nothing has worked out the border yet")
	bd:Tick()
	check(right(bd, 30) and bd:GetScript("OnUpdate") == nil, "retry: the first readable frame works out the border and ends the retry")
end

-- 4. the highlight frame
do
	local _, ic, _ = iconWithBorder()
	local hl = highlight(ic)
	check(right(hl, 30), "highlight: worked out as before")
	local ok, err = try(ride, ic)
	check(ok and issecretvalue(hl:GetWidth()), "highlight: in the hidden chain no error (" .. err .. ")")
	ok, err = try(CDTL3.SetBorder, CDTL3, hl, STYLE)
	check(ok, "highlight: SetBorder in the hidden chain throws nothing (" .. err .. ")")
	ok, err = try(hl.SetSize, hl, 30, 30)
	check(ok, "highlight: SetSize in the hidden chain throws nothing (" .. err .. ")")
	land(ic)
	hl:Tick()
	check(right(hl, 30) and hl:GetScript("OnUpdate") == nil, "highlight: right again after combat")
end

-- 5. the guard swallows nothing else: an error that has nothing to do with a secret size goes up
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	bd.backdropInfo.edgeSize = "wide"	-- a broken setting, readable size
	local ok, err = try(ic.SetSize, ic, 32, 32)
	check(not ok and not err:find("secret", 1, true), "other errors: a broken edge size still throws (" .. err .. ")")
	bd.backdropInfo.edgeSize = 1
end

-- 6. changed settings set a new backdrop, readable or hidden
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	local info = bd.backdropInfo
	local runs = COORDS_RUNS
	CDTL3:SetBorder(bd, WIDE)
	check(bd.backdropInfo ~= info and bd.backdropInfo.edgeSize == 2 and bd.backdropInfo.edgeFile == "Media\\border\\CDTL3 Shadow",
		"changed settings: a new backdrop with the new style and edge size")
	check(COORDS_RUNS > runs and right(bd, 30, 2), "changed settings: worked out with the new edge size")
	local size3 = { style = "CDTL3 Shadow", color = WIDE.color, size = 3, padding = 0, inset = 0 }
	info = bd.backdropInfo
	CDTL3:SetBorder(bd, size3)
	check(bd.backdropInfo ~= info and bd.backdropInfo.edgeSize == 3 and right(bd, 30, 3), "changed settings: a new edge size alone sets a new backdrop and works it out")
	local style = { style = "CDTL3 Pixel", color = WIDE.color, size = 3, padding = 0, inset = 0 }
	info = bd.backdropInfo
	CDTL3:SetBorder(bd, style)
	check(bd.backdropInfo ~= info and bd.backdropInfo.edgeFile == "Media\\border\\CDTL3 Pixel", "changed settings: a new style alone sets a new backdrop")
	local inset = { style = "CDTL3 Pixel", color = WIDE.color, size = 3, padding = 0, inset = 1 }
	info = bd.backdropInfo
	CDTL3:SetBorder(bd, inset)
	check(bd.backdropInfo ~= info and bd.backdropInfo.insets.left == 1 and bd.backdropInfo.insets.bottom == 1, "changed settings: a new inset alone sets a new backdrop")
	ride(ic)
	info = bd.backdropInfo
	local before = bd.coords
	local ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	check(ok and bd.backdropInfo ~= info and bd.backdropInfo.edgeSize == 1, "changed settings while riding: the new backdrop is set and nothing throws (" .. err .. ")")
	check(bd.coords == before and bd:GetScript("OnUpdate") == HELPERS.RetileWhenPlain, "changed settings while riding: the coordinates wait for a readable size")
	land(ic)
	check(right(bd, 30, 1) and bd:GetScript("OnUpdate") == nil, "changed settings while riding: right with the new edge size after combat")
end

-- 7. several frames: two riding icons with border and highlight each; each waits and ends on its own
do
	local _, ic1, bd1 = iconWithBorder()
	CDTL3:SetBorder(bd1, STYLE)
	local hl1 = highlight(ic1)
	local _, ic2, bd2 = iconWithBorder()
	CDTL3:SetBorder(bd2, STYLE)
	local hl2 = highlight(ic2)
	local ok, err = try(function() ride(ic1); ride(ic2) end)
	check(ok, "several frames: two riding icons throw nothing (" .. err .. ")")
	local waiting = function(f) return f:GetScript("OnUpdate") == HELPERS.RetileWhenPlain end
	check(waiting(bd1) and waiting(hl1) and waiting(bd2) and waiting(hl2), "several frames: all four wait")
	ic1.w, ic1.h = 34, 34
	land(ic1)
	check(right(bd1, 34) and not waiting(bd1) and not waiting(hl1), "several frames: the landed icon's frames are worked out and stop waiting")
	check(waiting(bd2) and waiting(hl2) and issecretvalue(bd2:GetWidth()), "several frames: the other icon's frames still wait")
	ok, err = try(function() for _ = 1, 3 do bd2:Tick(); hl2:Tick() end end)
	check(ok and waiting(bd2), "several frames: the waiting ones throw nothing (" .. err .. ")")
	land(ic2)
	check(right(bd2, 30) and right(hl2, 30) and not waiting(bd2) and not waiting(hl2), "several frames: the second icon is right after it lands")
end

-- 8. the timer ends: the icon goes to a Ready frame (anchored to a readable frame) and is right there
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	ride(ic)
	local ready = CreateFrame("Frame", "Ready" .. n, UIParent)
	ready:SetSize(200, 40)
	ready:SetPoint("CENTER")
	local ok, err = try(function()
		ic:SetParent(ready)
		ic:ClearAllPoints()
		ic:SetPoint("LEFT", ready, "LEFT", 0, 0)
	end)
	check(ok and right(bd, 30) and bd:GetScript("OnUpdate") == nil, "timer end: in the Ready frame the border is worked out and no retry is left (" .. err .. ")")
end

-- 9. an answer of IsAnchoringSecret that cannot be tested counts as hidden; nothing throws
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	local before = bd.coords
	bd.answerSecret = true
	local ok, err = try(ic.SetSize, ic, 33, 33)
	check(ok and bd.coords == before and bd:GetScript("OnUpdate") == HELPERS.RetileWhenPlain, "unreadable answer: counts as hidden, no error (" .. err .. ")")
	bd.answerSecret = nil
	bd:Tick()
	check(right(bd, 33) and bd:GetScript("OnUpdate") == nil, "unreadable answer: worked out once the answer reads plain")
end

-- 10. a client without IsAnchoringSecret (no hidden sizes): the frame keeps the mixin's function
do
	local _, _, bd = iconWithBorder()
	local isa = REGION.IsAnchoringSecret
	REGION.IsAnchoringSecret = nil
	local ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	REGION.IsAnchoringSecret = isa
	check(ok and bd.SetupTextureCoordinates == BackdropTemplateMixin.SetupTextureCoordinates,
		"no hidden sizes on this client: SetupTextureCoordinates stays the mixin's (" .. err .. ")")
	check(right(bd, 30), "no hidden sizes on this client: the border is worked out as before")
end
