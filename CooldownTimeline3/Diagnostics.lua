--[[
	Cooldown Timeline 3 - diagnostics: the failure log (/cdtl3 log), the bug report (/cdtl3 report)
	and /cdtl3 perf.

	The log keeps what the hidden-value pcalls swallow (Helpers.lua's cooldown, charge, aura and item
	reads, CombatTimers.lua): the place and the error text, never a value. CDTL3:LogFailure runs inside
	update loops, so it prints nothing and makes no tables: a failure that repeats the newest line of
	its place only counts on that line.
]]--

local addonName = ... or "CooldownTimeline3"
local private = {}

private.LOG_SIZE = 200
private.REPORT_LOG_LINES = 20
private.REPORT_MAX_SETTINGS = 300
private.loadedAt = GetTime()
private.total = 0
private.counts = {}		-- place -> failures since login
private.seq = 0			-- lines made so far
private.lastSeq = {}	-- place -> seq of its newest line
-- the lines: a ring of LOG_SIZE slots (slot = seq % LOG_SIZE + 1) in parallel arrays
private.lSeq, private.lPlace, private.lErr = {}, {}, {}
private.lCount, private.lFirst, private.lLast = {}, {}, {}

private.TYPES = { "spells", "petspells", "items", "buffs", "debuffs", "offensives", "runes", "customs" }

-- HELPERS
-- a value the game hides from addons; when the check itself fails, treat it as hidden
local function IsSecret(v)
	if not issecretvalue then
		return false
	end
	local ok, secret = pcall(issecretvalue, v)
	return not ok or secret == true
end

local function Now()
	return time and time() or 0
end

local function Stamp(t)
	if date and t and t > 0 then
		return date("%H:%M:%S", t)
	end
	return "--:--:--"
end

-- a line for the report or the log box; anything hidden is left out
local function Add(out, line)
	if type(line) ~= "string" or IsSecret(line) then
		line = "(hidden)"
	end
	out[#out + 1] = line
end

local function Plain(v)
	if IsSecret(v) then
		return "(hidden)"
	end
	local t = type(v)
	if t == "number" then
		if v == math.floor(v) then
			return tostring(v)
		end
		return (string.format("%.3f", v):gsub("0+$", ""))
	elseif t == "string" then
		return '"' .. v .. '"'
	end
	return tostring(v)
end

-- THE LOG
-- place: where the pcall sits ("GetSpellCooldown"); err: what the pcall returned. Only a string
-- error is kept, and only its text.
function CDTL3:LogFailure(place, err)
	if type(place) ~= "string" then
		place = "?"
	end
	if type(err) ~= "string" or IsSecret(err) then
		err = "(no error text)"
	end

	private.total = private.total + 1
	private.counts[place] = (private.counts[place] or 0) + 1

	local now = Now()
	local seq = private.lastSeq[place]
	if seq then
		local slot = seq % private.LOG_SIZE + 1
		if private.lSeq[slot] == seq and private.lErr[slot] == err then
			private.lCount[slot] = private.lCount[slot] + 1
			private.lLast[slot] = now
			return
		end
	end

	seq = private.seq + 1
	private.seq = seq
	local slot = seq % private.LOG_SIZE + 1
	private.lSeq[slot] = seq
	private.lPlace[slot] = place
	private.lErr[slot] = err
	private.lCount[slot] = 1
	private.lFirst[slot] = now
	private.lLast[slot] = now
	private.lastSeq[place] = seq
end

function CDTL3:FailureCount(place)
	if place then
		return private.counts[place] or 0
	end
	return private.total
end

-- "GetSpellCooldown 412, AuraExists 30", most first
private.CountsLine = function()
	local places = {}
	for place in pairs(private.counts) do
		places[#places + 1] = place
	end
	table.sort(places, function(a, b)
		if private.counts[a] ~= private.counts[b] then
			return private.counts[a] > private.counts[b]
		end
		return a < b
	end)
	for i, place in ipairs(places) do
		places[i] = place .. " " .. private.counts[place]
	end
	return table.concat(places, ", ")
end

private.FormatLine = function(slot)
	-- the error's file path is the addon's own folder: keep the file and line only
	local err = private.lErr[slot]:gsub("^[^:]-[/\\]AddOns[/\\][^/\\]+[/\\]", "")
	local line = Stamp(private.lFirst[slot]) .. "  " .. private.lPlace[slot] .. ": " .. err
	local n = private.lCount[slot]
	if n > 1 then
		line = line .. "  (x" .. n .. ", last at " .. Stamp(private.lLast[slot]) .. ")"
	end
	return line
end

-- the newest `max` lines (all of them without it), oldest first
function CDTL3:LogLines(max)
	local out = {}
	local first = math.max(1, private.seq - private.LOG_SIZE + 1)
	if max then
		first = math.max(first, private.seq - max + 1)
	end
	for seq = first, private.seq do
		local slot = seq % private.LOG_SIZE + 1
		if private.lSeq[slot] == seq then
			Add(out, private.FormatLine(slot))
		end
	end
	return out
end

function CDTL3:LogText()
	local out = {}
	if private.total == 0 then
		Add(out, "No failures logged since login.")
		return table.concat(out, "\n")
	end
	Add(out, "CDTL3 " .. CDTL3.version .. ": " .. private.total .. " failures since login (the last "
		.. private.LOG_SIZE .. " lines are kept; a repeat counts on its line)")
	Add(out, "By place: " .. private.CountsLine())
	Add(out, "")
	for _, line in ipairs(CDTL3:LogLines()) do
		Add(out, line)
	end
	return table.concat(out, "\n")
end

-- THE COPY BOX: an AceGUI window with one multi-line edit box, text selected for Ctrl+C
function CDTL3:ShowCopyBox(title, text)
	local AceGUI = LibStub("AceGUI-3.0")
	if private.box then
		private.box:Release()
		private.box = nil
	end

	-- AceGUI widgets carry methods the API definitions don't list
	local frame = AceGUI:Create("Frame") --[[@as table]]
	frame:SetTitle(title)
	frame:SetStatusText("Ctrl+C copies the selected text (Ctrl+A selects it all again)")
	frame:SetLayout("Fill")
	frame:SetWidth(720)
	frame:SetHeight(520)
	frame:SetCallback("OnClose", function(widget)
		if private.box == widget then
			private.box = nil
		end
		AceGUI:Release(widget)
	end)

	local box = AceGUI:Create("MultiLineEditBox") --[[@as table]]
	box:SetLabel("")
	box:DisableButton(true)
	box:SetFullWidth(true)
	box:SetFullHeight(true)
	box:SetText(text)
	frame:AddChild(box)
	box:SetFocus()
	box:HighlightText()

	private.box = frame
	private.boxText = text
	return frame
end

function CDTL3:ShowLog()
	CDTL3:ShowCopyBox("CDTL3 log", CDTL3:LogText())
end

-- THE REPORT
private.ClientName = function()
	local toc = CDTL3.tocversion or 0
	if CDTL3.isForever then
		return "WoW: Forever"
	elseif toc >= 110000 then
		return "Retail"
	elseif toc >= 50000 and toc < 60000 then
		return "Mists of Pandaria Classic"
	elseif toc >= 20000 and toc < 30000 then
		return "TBC Anniversary"
	elseif toc < 20000 then
		return "Classic Era"
	end
	return "interface " .. toc
end

private.MemoryLine = function()
	pcall(UpdateAddOnMemoryUsage)
	local get = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or GetAddOnMemoryUsage
	local ok, kb = false, nil
	if get then
		ok, kb = pcall(get, addonName)
	end
	local mine = (ok and type(kb) == "number" and not IsSecret(kb)) and string.format("%.0f KB", kb) or "unknown"
	local okAll, all = pcall(collectgarbage, "count")
	local total = (okAll and type(all) == "number") and string.format("%.0f KB", all) or "unknown"
	return "Memory: " .. mine .. " (CDTL3), " .. total .. " (every addon's Lua)"
end

-- runs one part of the report; a part that fails says so and the rest still comes out
private.Section = function(out, title, fn)
	Add(out, "")
	Add(out, "== " .. title .. " ==")
	local ok, err = pcall(fn, out)
	if not ok then
		Add(out, "(this part failed: " .. (type(err) == "string" and not IsSecret(err) and err or "error") .. ")")
		CDTL3:LogFailure("Report", err)
	end
end

private.ModeMax = function(s)
	local key = ({ LINEAR = "linear", LINEAR_ABS = "linearAbs", SPLIT = "split", SPLIT_ABS = "splitAbs" })[s["mode"]["type"]]
	return key and s["mode"][key] and s["mode"][key]["max"]
end

private.Lanes = function(out)
	local g = CDTL3.db.profile.global
	for i = 1, 3 do
		local s = CDTL3.db.profile.lanes["lane" .. i]
		local f = _G["CDTL3_Lane_" .. i]
		Add(out, string.format("Lane %d %s: %s, mode %s, Max Time %s s, primary tracking %s, secondary %s, alpha %s, pause while hidden %s",
			i, Plain(s["name"]), s["enabled"] and (f and "on" or "on (not created yet)") or "off",
			tostring(s["mode"]["type"]), Plain(private.ModeMax(s)), tostring(s["tracking"]["primaryTracking"]),
			tostring(s["tracking"]["secondaryTracking"]), Plain(s["alpha"]), s["pauseHidden"] and "on" or "off"))

		local defaults = {}
		for _, t in ipairs(private.TYPES) do
			if g[t] and g[t]["defaultLane"] == i then
				defaults[#defaults + 1] = t
			end
		end
		if g["flights"] and g["flights"]["defaultLane"] == i then
			defaults[#defaults + 1] = "flights"
		end
		local saved = 0
		for _, t in ipairs(private.TYPES) do
			for _, e in pairs(CDTL3.db.profile.tables[t] or {}) do
				if e["lane"] == i and not e["ignored"] and CDTL3:IsMyEntry(e) then
					saved = saved + 1
				end
			end
		end
		local live = 0
		if f then
			for _, cd in ipairs(CDTL3.cooldowns) do
				if cd.icon and cd.icon:GetParent() == f and cd.icon.valid then
					live = live + 1
				end
			end
		end
		Add(out, string.format("  default lane for: %s | your shown entries set to it: %d | icons on it now: %d",
			#defaults > 0 and table.concat(defaults, ", ") or "nothing", saved, live))
	end
end

-- every saved setting that differs from its default (AceDB keeps the defaults in the profile). Left
-- out: the entries (counted on their own), bookkeeping, and the lane scale labels the lane writes
-- from its mode (Lanes.lua SetModeText).
private.SKIP_SETTINGS = { ["tables"] = true, ["global.firstRun"] = true, ["global.previousVersion"] = true }
private.DERIVED = { text = true, pos = true, used = true }

private.Skip = function(p)
	if private.SKIP_SETTINGS[p] then
		return true
	end
	local field = p:match("^lanes%.lane%d+%.modeText%.text%d+%.(%a+)$")
	return field and private.DERIVED[field] or false
end

private.Diff = function(cur, def, path, out)
	local keys = {}
	for k in pairs(cur) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, k in ipairs(keys) do
		local p = path and (path .. "." .. tostring(k)) or tostring(k)
		if not private.Skip(p) then
			local v = cur[k]
			local d = nil
			if type(def) == "table" then
				d = def[k]	-- a false default must stay false, not turn into "no default"
			end
			if type(v) == "table" then
				private.Diff(v, d, p, out)
			elseif IsSecret(v) or v ~= d then
				out[#out + 1] = p .. " = " .. Plain(v) .. (d == nil and "" or ("  (default " .. Plain(d) .. ")"))
			end
		end
	end
end

private.Settings = function(out)
	-- a per-character profile is named "Name - Realm": a bug report keeps the name out
	local profile = CDTL3.db:GetCurrentProfile()
	if profile == CDTL3.db.keys.char then
		Add(out, "Profile: (this character's profile)")
	else
		Add(out, "Profile: " .. Plain(profile))
	end
	local lines = {}
	private.Diff(CDTL3.db.profile, CDTL3.db.defaults and CDTL3.db.defaults.profile or {}, nil, lines)
	if #lines == 0 then
		Add(out, "All settings are at their defaults.")
	end
	for i, line in ipairs(lines) do
		if i > private.REPORT_MAX_SETTINGS then
			Add(out, "... and " .. (#lines - private.REPORT_MAX_SETTINGS) .. " more")
			break
		end
		Add(out, line)
	end
end

private.Entries = function(out)
	for _, t in ipairs(private.TYPES) do
		local total, mine, ignored = 0, 0, 0
		for _, e in pairs(CDTL3.db.profile.tables[t] or {}) do
			total = total + 1
			if CDTL3:IsMyEntry(e) then
				mine = mine + 1
				if e["ignored"] then
					ignored = ignored + 1
				end
			end
		end
		Add(out, string.format("%s: %d saved, %d yours (%d of them ignored)", t, total, mine, ignored))
	end
	local detected = 0
	for _ in pairs(CDTL3.db.profile.tables["detected"] or {}) do
		detected = detected + 1
	end
	Add(out, "detected: " .. detected .. " | live cooldown frames: " .. #CDTL3.cooldowns)
end

function CDTL3:BuildReport()
	local out = {}
	local version, build, buildDate, toc = GetBuildInfo()
	Add(out, "CDTL3 report " .. (date and date("%Y-%m-%d %H:%M") or ""))
	Add(out, "CDTL3 version: " .. tostring(CDTL3.version))
	Add(out, string.format("Client: %s %s build %s (%s), interface %s, %s",
		private.ClientName(), tostring(version), tostring(build), tostring(buildDate), tostring(toc),
		tostring(GetLocale and GetLocale() or "?")))
	Add(out, "Issues: " .. tostring(CDTL3.supportlink))

	private.Section(out, "Combat timers", function(o)
		local CT = CDTL3.CombatTimers
		Add(o, CT and CT:StatusLine() or "Combat timers: not loaded")
	end)
	private.Section(out, "Auras (as /cdtl3 auras)", function(o)
		-- the report may be posted in public: the character's GUID is left out (only whether it's known)
		local guid = CDTL3.player and CDTL3.player["guid"]
		CDTL3:DiagnoseAuras(function(line)
			local s, e = nil, nil
			if type(guid) == "string" and type(line) == "string" and not IsSecret(line) then
				s, e = line:find(guid, 1, true)
			end
			if s then
				line = line:sub(1, s - 1) .. "(known)" .. line:sub(e + 1)
			end
			Add(o, line)
		end)
	end)
	private.Section(out, "Lanes", private.Lanes)
	private.Section(out, "Saved entries", private.Entries)
	private.Section(out, "Settings changed from the defaults", private.Settings)
	private.Section(out, "Recent log", function(o)
		if private.total == 0 then
			Add(o, "No failures logged since login.")
			return
		end
		Add(o, private.total .. " failures since login. By place: " .. private.CountsLine())
		for _, line in ipairs(CDTL3:LogLines(private.REPORT_LOG_LINES)) do
			Add(o, line)
		end
		Add(o, "(the whole log: /cdtl3 log)")
	end)
	private.Section(out, "Memory", function(o)
		Add(o, private.MemoryLine())
	end)
	Add(out, "")
	Add(out, "Paste this into an issue: " .. tostring(CDTL3.supportlink))
	return table.concat(out, "\n")
end

function CDTL3:ShowReport()
	CDTL3:ShowCopyBox("CDTL3 report", CDTL3:BuildReport())
end

-- /cdtl3 perf
private.RATE_NAMES = { [0] = "Full", [30] = "30 per second", [15] = "15 per second" }

private.ProfilingOn = function()
	local get = (C_CVar and C_CVar.GetCVarBool) or GetCVarBool
	if not get then
		return false
	end
	local ok, on = pcall(get, "scriptProfile")
	return ok and on == true
end

-- ms of CPU the frames in a list used (their own scripts), nil if the game can't say
private.FramesCPU = function(list)
	if not GetFrameCPUUsage then
		return nil
	end
	local ms = 0
	for _, f in pairs(list or {}) do
		local ok, v = pcall(GetFrameCPUUsage, f, false)
		if ok and type(v) == "number" then
			ms = ms + v
		end
	end
	return ms
end

function CDTL3:PerfLines()
	local out = {}
	local g = CDTL3.db.profile.global
	local rate = g["updateRate"] or 0
	local paused = {}
	for i = 1, 3 do
		if CDTL3.db.profile.lanes["lane" .. i]["pauseHidden"] then
			paused[#paused + 1] = tostring(i)
		end
	end
	local fps = GetFramerate and GetFramerate()
	Add(out, string.format("CDTL3 perf | update rate: %s | pause while hidden: %s | frame rate: %s",
		private.RATE_NAMES[rate] or (rate .. " per second"), #paused > 0 and ("lane " .. table.concat(paused, ", ")) or "off",
		type(fps) == "number" and string.format("%.0f fps", fps) or "unknown"))

	if private.ProfilingOn() and GetAddOnCPUUsage then
		pcall(UpdateAddOnCPUUsage)
		local ok, ms = pcall(GetAddOnCPUUsage, addonName)
		local secs = math.max(GetTime() - private.loadedAt, 1)
		if ok and type(ms) == "number" then
			Add(out, string.format("CPU: %.0f ms since the reload, about %.2f ms a second", ms, ms / secs))
		else
			Add(out, "CPU: the game didn't report it")
		end
		local cds, lanes = private.FramesCPU(CDTL3.cooldowns), private.FramesCPU(CDTL3.lanes)
		local bars, ready = private.FramesCPU(CDTL3.barFrames), private.FramesCPU(CDTL3.readyFrames)
		if cds then
			Add(out, string.format("  of it: cooldown frames %.0f ms, lanes %.0f ms, bar frames %.0f ms, ready frames %.0f ms",
				cds, lanes or 0, bars or 0, ready or 0))
		end
	else
		Add(out, "CPU: not measured. The game only times addons while its scriptProfile setting is on, and that slows "
			.. "every addon, so it's off by default. To measure: /console scriptProfile 1, /reload, play a while, "
			.. "/cdtl3 perf; then /console scriptProfile 0 and /reload.")
	end

	Add(out, private.MemoryLine())

	local onLanes, moving, inReady, bars, parked = 0, 0, 0, 0, 0
	for _, cd in ipairs(CDTL3.cooldowns) do
		local ip = cd.icon and cd.icon:GetParent()
		local name = ip and ip:GetName() or ""
		if CDTL3:SlotOfParent(name) == "lanes" then
			onLanes = onLanes + 1
			if cd.icon.valid then
				moving = moving + 1
			end
		elseif CDTL3:SlotOfParent(name) == "ready" then
			inReady = inReady + 1
		else
			parked = parked + 1
		end
		local bp = cd.bar and cd.bar:GetParent()
		if bp and CDTL3:SlotOfParent(bp:GetName()) == "barFrames" and cd.bar.valid then
			bars = bars + 1
		end
	end
	Add(out, string.format("Frames: %d cooldown frames (each runs its own OnUpdate): %d icons on lanes (%d shown), %d in Ready, %d parked; %d bars showing",
		#CDTL3.cooldowns, onLanes, moving, inReady, parked, bars))
	Add(out, string.format("  plus %d lanes, %d bar frames, %d ready frames and %d holders", #CDTL3.lanes, #CDTL3.barFrames,
		#CDTL3.readyFrames, #CDTL3.holders))
	return out
end

function CDTL3:PrintPerf()
	for _, line in ipairs(CDTL3:PerfLines()) do
		CDTL3:Print(line)
	end
end

-- for tools/tests only
CDTL3.DiagnosticsInternal = private
