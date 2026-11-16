-- Scenarios for the local patch Border frames tolerate hidden geometry on the real CDTL3:SetBorder
-- and its helpers from Helpers.lua (after border_secret_env.lua). HELPERS (the patch's private
-- functions) comes from border_secret.test.mjs. The stub engine sends OnSizeChanged whenever a
-- frame's size or the secrecy of its anchors changes, as the game does.
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. m end
local STYLE = { style = "CDTL3 Pixel", color = { r = 1, g = 0.8, b = 0, a = 1 }, size = 1, padding = 0, inset = 0 }
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-9 end
local function expected(w, edge) return math.max(0, (w / edge) * 0.65 - 2 - 0.0625) end
local function right(f, w) return f.coords and near(f.coords.x, expected(w, 1)) and near(f.coords.y, expected(w, 1)) end

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

-- 1. an ordinary border: worked out as in the release
do
	local _, ic, bd = iconWithBorder()
	local runs = COORDS_RUNS
	local ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	check(ok, "ordinary: SetBorder runs (" .. err .. ")")
	check(COORDS_RUNS >= runs + 2 and right(bd, 30), "ordinary: SetBackdrop and then OnSizeChanged (the two points) work out the coordinates")
	check(bd.borderColor and bd.borderColor[1] == 1 and #bd.points == 2 and bd.points[1].rel == ic, "ordinary: colour and the two points on the icon as in the release")
	check(bd:GetScript("OnUpdate") == nil, "ordinary: no retry on the frame")
	runs = COORDS_RUNS
	ic:SetSize(40, 40)
	check(COORDS_RUNS == runs + 1 and right(bd, 40), "ordinary: OnSizeChanged works them out again (OnBackdropSizeChanged)")
	runs = COORDS_RUNS
	CDTL3:SetBorder(bd, STYLE)
	check(COORDS_RUNS == runs + 1 and right(bd, 40), "ordinary: a second SetBorder works them out again (SetBackdrop)")
	check(bd.SetupTextureCoordinates == HELPERS.BorderCoords and bd.cdtl3SetupCoords == BackdropTemplateMixin.SetupTextureCoordinates,
		"ordinary: the frame's SetupTextureCoordinates goes through the guard, the mixin's is kept")
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
	check(bd:GetScript("OnUpdate") == HELPERS.BorderCoordsRetry, "riding: a retry waits for a readable size")
	ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	check(ok, "riding: SetBorder throws nothing (" .. err .. ")")
	check(bd.backdropInfo and bd.backdropInfo.edgeFile and bd.borderColor and #bd.points == 2, "riding: SetBorder still sets backdrop, colour and points")
	ok, err = try(function() for _ = 1, 5 do bd:Tick() end end)
	check(ok and bd.coords == before and bd:GetScript("OnUpdate") == HELPERS.BorderCoordsRetry, "riding: the retry waits while the size is secret (" .. err .. ")")
	ic.w, ic.h = 36, 36	-- a new size while hidden (no OnSizeChanged for it reaches a readable frame)
	land(ic)
	check(right(bd, 36), "after combat: the border is worked out from the current size")
	local runs = COORDS_RUNS
	bd:Tick()
	check(bd:GetScript("OnUpdate") == nil and right(bd, 36), "after combat: the retry runs once more and goes")
	local after = COORDS_RUNS
	bd:Tick()
	check(COORDS_RUNS == after, "after combat: nothing runs every frame any more")
	ic:SetSize(30, 30)
	check(COORDS_RUNS == after + 1 and right(bd, 30), "after combat: OnSizeChanged works as in the release")
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

-- 4. the highlight frame (Cooldown.lua: SetBorder, then one point on the icon's centre and a size)
do
	local _, ic, _ = iconWithBorder()
	local hl = CreateFrame("Frame", ic:GetName() .. "_HL", UIParent, "BackdropTemplate")
	hl:SetParent(ic)
	CDTL3:SetBorder(hl, STYLE)
	hl:ClearAllPoints()
	hl:SetPoint("CENTER", 0, 0)
	hl:SetSize(30, 30)
	check(right(hl, 30), "highlight: worked out as in the release")
	local ok, err = try(ride, ic)
	check(ok and issecretvalue(hl:GetWidth()), "highlight: in the hidden chain no error (" .. err .. ")")
	ok, err = try(CDTL3.SetBorder, CDTL3, hl, STYLE)
	check(ok, "highlight: SetBorder in the hidden chain throws nothing (" .. err .. ")")
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

-- 6. a cleared border is not worked out by a waiting retry; another OnUpdate is not replaced
do
	local _, ic, bd = iconWithBorder()
	CDTL3:SetBorder(bd, STYLE)
	ride(ic)
	bd:SetBackdrop(nil)
	land(ic)
	local ok, err = try(bd.Tick, bd)
	check(ok and bd:GetScript("OnUpdate") == nil, "cleared: the retry ends without a backdrop (" .. err .. ")")

	local _, ic2, bd2 = iconWithBorder()
	CDTL3:SetBorder(bd2, STYLE)
	local own = function() end
	bd2:SetScript("OnUpdate", own)
	ok, err = try(ride, ic2)
	check(ok and bd2:GetScript("OnUpdate") == own, "own OnUpdate: kept, and no error (" .. err .. ")")
	land(ic2)
	check(right(bd2, 30), "own OnUpdate: OnSizeChanged mends the border after combat")
end

-- 7. a client without secret values (no issecretvalue): the frame keeps the mixin's function
do
	local _, _, bd = iconWithBorder()
	issecretvalue = nil
	local ok, err = try(CDTL3.SetBorder, CDTL3, bd, STYLE)
	issecretvalue = ISSECRETVALUE
	check(ok and bd.SetupTextureCoordinates == BackdropTemplateMixin.SetupTextureCoordinates and bd.cdtl3SetupCoords == nil,
		"no secrets on this client: SetupTextureCoordinates stays the mixin's (" .. err .. ")")
	check(right(bd, 30), "no secrets on this client: the border is worked out as in the release")
end
