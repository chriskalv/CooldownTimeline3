-- Scenarios for the local patch Effect strip tolerates hidden geometry on the real StripFor,
-- CDTL3:EffectStripTick and the patch's helpers from Group.lua (after border_secret_env.lua and
-- effect_strip_env.lua). GROUP (Group.lua's private table) comes from effect_strip.test.mjs.
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. m end
local function try(fn, ...) local ok, err = pcall(fn, ...); return ok, tostring(err) end
local function calls() local c = CALLS; CALLS = {}; return table.concat(c, " ") end

-- a spell timer on lane `lane` whose icon is `width` wide (RefreshIcon: SetSize from the lane, here
-- a different width so the source shows), with a running effect: 10 s long, 5 s left (frac 0.5)
local n = 0
local function timer(lane, width)
	n = n + 1
	local laneFrame = CreateFrame("Frame", "Lane" .. n, UIParent)
	laneFrame:SetSize(300, 30)
	laneFrame:SetPoint("CENTER")
	local ic = CreateFrame("Frame", "Icon" .. n, laneFrame)
	ic:SetSize(width, width)
	ic:SetPoint("CENTER", 0, 0)
	local name = "Spell" .. n
	local f = { icon = ic, data = { type = "spells", name = name, lane = lane } }
	GROUP.effects[name] = { active = true, len = 10, untilT = NOW + 5, name = "Tank", class = "WARRIOR", estimated = false }
	CDTL3.cooldowns[#CDTL3.cooldowns + 1] = f
	CDTL3.effectsLive = true
	CALLS = {}
	return f, ic
end
-- PlaceIcon (CombatTimers.lua): the icon hangs on the fill of a StatusBar with a hidden value
local function ride(ic)
	local fill = CreateFrame("Frame", nil, ic:GetParent())
	fill.secretMark = true
	ic:ClearAllPoints()
	ic:SetPoint("LEFT", fill, "RIGHT", 0, 0)
	CALLS = {}
end
-- after combat IconUpdate places it the normal way again
local function land(ic)
	ic:ClearAllPoints()
	ic:SetPoint("LEFT", ic:GetParent(), "LEFT", 0, 0)
	CALLS = {}
end
local function tick(f) return try(CDTL3.EffectStripTick, CDTL3, f) end
-- a scenario that breaks off (a nil strip after an error) fails once and leaves the others running
local function scenario(n, fn)
	local saveNow = NOW
	local ok, err = pcall(fn)
	NOW = saveNow
	issecretvalue = ISSECRETVALUE
	if not ok then
		check(false, "scenario " .. n .. " broke off (" .. tostring(err) .. ")")
	end
end

-- 0. the stub world throws like the game: the release's lines on a riding icon
scenario("0", function()
	local f, ic = timer(1, 30)
	ride(ic)
	local st = CreateFrame("Frame", nil, ic)
	local ok, err = try(function() st:SetSize(ic:GetWidth(), 4) end)
	check(not ok and err:find("secret value passed", 1, true), "control: SetSize(ic:GetWidth(), 4) of a riding icon throws (" .. err .. ")")
	st:SetPoint("BOTTOMLEFT", ic, "TOPLEFT", 0, 2)
	ok, err = try(function() return st:GetWidth() * 0.5 end)
	check(not ok and err:find("secret number value", 1, true), "control: the strip's width times frac throws (" .. err .. ")")
	check(GROUP.Hidden(ic:GetWidth()) and not GROUP.Hidden(30) and not GROUP.Hidden(nil), "Hidden: true for a secret, false for a number and nil")
end)

-- 1. a readable icon: the same calls and values as the release
--    (StripFor: SetSize(ic:GetWidth(), 4); first tick: SetWidth(ic:GetWidth()); fill: st:GetWidth() * frac)
scenario("1", function()
	local f, ic = timer(2, 30)
	local ok, err = tick(f)
	check(ok, "readable: the first tick runs (" .. err .. ")")
	check(calls() == "?:SetSize(30,4) ?:SetWidth(30) ?:SetWidth(15)", "readable: SetSize(30,4), SetWidth(30), fill 15 as in the release")
	local st = ic.cdtl3Strip
	check(st and st.shown and st.name.text == "Tank" and st.time.text == "5.0" and st.fill.w == 15, "readable: strip shown, name, time and fill as in the release")
	NOW = NOW + 1
	tick(f)
	check(calls() == "?:SetWidth(12)", "readable: the next tick only sets the fill (12 = 30 * 0.4)")
	st:SetWidth(50)	-- the strip's own width changed: the release reads it back every tick
	CALLS = {}
	tick(f)
	check(calls() == "?:SetWidth(20)", "readable: the fill follows the strip's width as read (20 = 50 * 0.4)")
	GROUP.effects[f.data.name].untilT = NOW + 0.00001
	tick(f)
	check(calls() == "?:SetWidth(0.1)", "readable: the fill keeps its minimum of 0.1")
	GROUP.effects[f.data.name].untilT = NOW + 50
	tick(f)
	check(calls() == "?:SetWidth(50)", "readable: frac is held at 1")
	NOW = NOW - 1
end)

-- 2. an icon that already rides when its first effect starts: no error, the lane's icon size
scenario("2", function()
	local f, ic = timer(2, 30)
	ride(ic)
	check(GROUP.Hidden(ic:GetWidth()), "riding: the icon's width is secret")
	local ok, err = tick(f)
	check(ok, "riding: StripFor and the first tick throw nothing (" .. err .. ")")
	local st = ic.cdtl3Strip
	check(st and GROUP.Hidden(st:GetWidth()), "riding: the strip's width is secret too")
	check(calls() == "?:SetSize(40,4) ?:SetWidth(40) ?:SetWidth(20)", "riding: strip and fill from lane 2's icon size (40, fill 20)")
	check(st.shown and st.name.text == "Tank" and st.time.text == "5.0", "riding: strip shown with name and time")
	NOW = NOW + 2
	ok, err = tick(f)
	check(ok and calls() == "?:SetWidth(12)", "riding: the next tick fills from the strip's last width (12 = 40 * 0.3) (" .. err .. ")")
	NOW = NOW - 2
	land(ic)
	tick(f)
	check(calls() == "?:SetWidth(20)", "after combat: the fill reads the strip's width again (20)")
end)

-- 3. an icon that starts riding after its strip was made: the strip's width from before
scenario("3", function()
	local f, ic = timer(3, 30)
	tick(f)
	ride(ic)
	NOW = NOW + 1
	local ok, err = tick(f)
	check(ok and calls() == "?:SetWidth(12)", "strip made before: the fill uses the strip's width from before (12 = 30 * 0.4) (" .. err .. ")")
	ic.cdtl3Strip.named = nil	-- a new effect (StartEffect): name and width are drawn again
	ok, err = tick(f)
	check(ok and calls() == "?:SetWidth(44) ?:SetWidth(17.6)", "strip made before: a new effect while riding takes lane 3's icon size (44) (" .. err .. ")")
	NOW = NOW - 1
end)

-- 4. no readable source (no icon size in the lane settings): the width is skipped, nothing else, and
--    tried again every tick until there is one
scenario("4", function()
	local saved = CDTL3.db.profile.lanes.lane1.icons.size
	CDTL3.db.profile.lanes.lane1.icons.size = nil
	local f, ic = timer(1, 30)
	ride(ic)
	local ok, err = tick(f)
	local st = ic.cdtl3Strip
	check(ok, "no source: no error (" .. err .. ")")
	check(calls() == "?:SetHeight(4)" and st.h == 4 and st.cdtl3Width == nil, "no source: only the height is set, no width, no fill")
	check(st.shown and st.name.text == "Tank" and st.time.text == "5.0", "no source: strip, name and time still drawn")
	ok, err = tick(f)
	check(ok and calls() == "" and st.cdtl3Width == nil, "no source: the next tick tries again and sets nothing (" .. err .. ")")
	CDTL3.db.profile.lanes.lane1.icons.size = saved
	ok, err = tick(f)
	check(ok and calls() == "?:SetWidth(36) ?:SetWidth(18)", "no source: once a source is there, the next tick of the same effect sets the width (36) and the fill (18) (" .. err .. ")")
	NOW = NOW + 1
	tick(f)
	check(calls() == "?:SetWidth(14.4)", "no source: the width set then is remembered for the fill (14.4 = 36 * 0.4)")
	st.named = nil	-- a new effect: the width is drawn again
	tick(f)
	check(calls() == "?:SetWidth(36) ?:SetWidth(14.4)", "no source: a new effect sets the width again (36)")
	NOW = NOW - 1
end)

-- 5. which lane's settings: lane 0 and anything else count as lane 1, as in RefreshIcon
scenario("5", function()
	for _, c in ipairs({ { 0, 36 }, { 1, 36 }, { 3, 44 }, { 7, 36 } }) do
		local f, ic = timer(c[1], 30)
		ride(ic)
		check(GROUP.IconWidth(f) == c[2], "lane " .. c[1] .. ": a riding icon's width is the lane's icon size " .. c[2])
	end
	local f = timer(2, 30)
	check(GROUP.IconWidth(f) == 30, "IconWidth: a readable icon width is used as it is")
end)

-- 6. the guard swallows nothing else: an error that has nothing to do with a secret goes up
scenario("6", function()
	local f, ic = timer(1, 30)
	ic.GetWidth = function() error("broken frame") end
	local ok, err = tick(f)
	check(not ok and err:find("broken frame", 1, true), "other errors: a failing GetWidth still throws (" .. err .. ")")
	local f2, ic2 = timer(1, 30)
	tick(f2)
	ic2.cdtl3Strip.GetWidth = function() error("broken strip") end
	ok, err = tick(f2)
	check(not ok and err:find("broken strip", 1, true), "other errors: a failing strip width still throws (" .. err .. ")")
	local f3, ic3 = timer(2, 30)
	ride(ic3)
	CDTL3.db.profile.lanes.lane2 = nil
	CDTL3.db.profile.lanes = setmetatable(CDTL3.db.profile.lanes, { __index = function() error("broken profile") end })
	ok, err = tick(f3)
	CDTL3.db.profile.lanes = setmetatable(CDTL3.db.profile.lanes, nil)
	CDTL3.db.profile.lanes.lane2 = { icons = { size = 40 } }
	check(not ok and err:find("broken profile", 1, true), "other errors: a failing settings read still throws (" .. err .. ")")
end)

-- 7. a client without secret values (no issecretvalue): as in the release
scenario("7", function()
	issecretvalue = nil
	local f, ic = timer(3, 30)
	local ok, err = tick(f)
	issecretvalue = ISSECRETVALUE
	check(ok and calls() == "?:SetSize(30,4) ?:SetWidth(30) ?:SetWidth(15)", "no secrets on this client: the release's calls (" .. err .. ")")
end)
