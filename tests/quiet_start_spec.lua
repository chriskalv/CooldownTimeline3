-- Scenarios for the two quiet-start patches on the real addon code (after quiet_start_env.lua,
-- the real LibStub, CallbackHandler and AceDB-3.0, the release's defaults, Flights.lua, Start.lua's
-- tour wrapper and CDTL3.lua's login, slash command and welcome window). One scenario per run.
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. SCENARIO .. ": " .. m end
local AceDB = LibStub("AceDB-3.0")
local FL = CDTL3.Flights
local P = FL.private
local CHAR = "Tester - Realm"

-- a session: the saved variables as the game loads them, OnInitialize, OnEnable
local function login()
	CDTL3:OnInitialize()
	CDTL3:OnEnable()
end
-- the game logs out: AceDB strips every value equal to its default from the saved variables
local function logout()
	AceDB.frame.scripts.OnEvent(AceDB.frame, "PLAYER_LOGOUT")
	for db in pairs(AceDB.db_registry) do AceDB.db_registry[db] = nil end
end
local function g() return CDTL3.db.profile.global end
local function welcomeMade()
	for _, n in ipairs(FRAMES_MADE) do if n == "CDTL3_Firstrun" then return true end end
	return false
end
local function welcomeShown() return _G["CDTL3_Firstrun"] ~= nil and _G["CDTL3_Firstrun"]:IsShown() end

local function event(e, ...) P.eventFrame.scripts.OnEvent(P.eventFrame, e, ...) end
local function tick(n)
	for _ = 1, n do
		local s = P.eventFrame.scripts.OnUpdate
		if s then s(P.eventFrame, 0.25) end
		NOW = NOW + 0.25
	end
end
-- open the taxi map, pick Ironforge, take off
local function fly()
	event("TAXIMAP_OPENED")
	TakeTaxiNode(2)
	event("PLAYER_CONTROL_LOST")
	ON_TAXI = true
	tick(4)
end
local function land()
	ON_TAXI = false
	event("PLAYER_CONTROL_GAINED")
	tick(4)
end

local S = {}

-- a fresh profile: flight timers off, a flight starts no timer; switched on they work and the
-- saved "on" outlives the new default across logout and login; switched off again nothing is saved
function S.flight_fresh()
	login()
	runTimers(30)
	check(g().flights.enabled == false, "default flights.enabled is false")
	check(FL:Enabled() == false, "FL:Enabled() is false on a fresh profile")
	check(g().flights.defaultLane == 1 and g().flights.defaultBar == 1 and g().flights.defaultReady == 1,
		"lane, bar frame and ready frame defaults unchanged")
	P.Store().routes[ROUTE_KEY] = 95
	fly()
	check(TAXI_TAKEN[1] == 2, "the game's TakeTaxiNode still runs")
	check(#CREATED == 0, "a flight starts no timer while off (" .. #CREATED .. ")")
	check(P.pending == nil and P.flight == nil, "nothing pending or in flight while off")
	check(P.eventFrame.scripts.OnUpdate == nil, "no ticker while off")
	check(CDTL3.db.char.flight == nil, "no flight saved for the character while off")
	land()
	check(not CDTL3.db.global.flightNoteShown, "no first-flight chat note while off")
	check(P.Store().routes[ROUTE_KEY] == 95, "learned flight times kept")

	FL:SetEnabled(true)
	check(g().flights.enabled == true and FL:Enabled() == true, "FL:SetEnabled(true) turns them on")
	fly()
	local f = CREATED[1]
	check(#CREATED == 1 and f and f.data.name == "Ironforge" and f.data.bCD == 95000 and f.data["type"] == "flights",
		"switched on, a flight starts its countdown")
	check(P.flight ~= nil and CDTL3.db.char.flight ~= nil, "the flight is tracked and saved")
	check(CDTL3.db.global.flightNoteShown == true, "the first-flight chat note runs once")
	NOW = NOW + 95
	land()
	check(P.flight == nil and f.data.currentCD == 0, "landing ends the countdown")

	logout()
	local saved = CDTL3DB.profiles and CDTL3DB.profiles.Default and CDTL3DB.profiles.Default.global
	check(saved and saved.flights and saved.flights.enabled == true, "logout keeps the switched-on value")
	login()
	check(FL:Enabled() == true, "after the next login flight timers are still on")
	FL:SetEnabled(false)
	check(FL:Enabled() == false, "FL:SetEnabled(false) turns them off")
	logout()
	saved = CDTL3DB.profiles and CDTL3DB.profiles.Default and CDTL3DB.profiles.Default.global
	check(not (saved and saved.flights and saved.flights.enabled ~= nil), "off equals the default: nothing saved")
	login()
	check(FL:Enabled() == false, "after the next login they stay off")
end

-- profiles saved by the release: one that never touched the switch follows the new default (off),
-- its other flight settings kept; one with a saved value keeps it
function S.flight_saved()
	CDTL3DB = {
		profileKeys = { [CHAR] = "Default" },
		profiles = {
			Default = { global = { firstRun = false, previousVersion = "3.2.1", flights = { defaultLane = 2 } } },
			On = { global = { firstRun = false, previousVersion = "3.2.1", flights = { enabled = true } } },
			Off = { global = { firstRun = false, previousVersion = "3.2.1", flights = { enabled = false } } },
		},
	}
	login()
	check(FL:Enabled() == false, "a profile that never touched the switch: off")
	check(g().flights.defaultLane == 2, "its saved lane is kept")
	CDTL3.db:SetProfile("On")
	check(FL:Enabled() == true, "a profile saved with the switch on stays on")
	CDTL3.db:SetProfile("Off")
	check(FL:Enabled() == false, "a profile saved with the switch off stays off")
end

-- a login in the air: with timers off the saved flight is dropped, with them on it resumes
function S.flight_resume()
	local saved = function() return { key = ROUTE_KEY, name = "Ironforge", duration = 95, serverStart = GetServerTime() - 20 } end
	CDTL3DB = { char = { [CHAR] = { flight = saved() } } }
	ON_TAXI = true
	login()
	event("PLAYER_ENTERING_WORLD", false, true)
	runTimers(5)
	check(#CREATED == 0, "off: a flight in progress shows no countdown after a reload")
	check(CDTL3.db.char.flight == nil, "off: the saved flight is dropped")
	FL:SetEnabled(true)
	CDTL3.db.char.flight = saved()
	event("PLAYER_ENTERING_WORLD", false, true)
	runTimers(5)
	check(#CREATED == 1 and CREATED[1].data.name == "Ironforge", "on: the countdown resumes after a reload")
end

-- a first install (no saved variables): the tour starts ten seconds after login, as in the release
function S.login_fresh_install()
	login()
	check(CDTL3.db.global.tourPending == true, "a first install has the tour pending")
	check(g().firstRun == true, "the new profile has firstRun")
	runTimers(9)
	check(#TOUR_STEPS == 0, "no tour before ten seconds")
	runTimers(2)
	check(#TOUR_STEPS == 1 and TOUR_STEPS[1] == 1 and PREVIEWS == 1, "the tour starts at step 1 with the preview")
	runTimers(600)
	check(#TOUR_STEPS == 1, "the tour starts once")
	check(not welcomeMade(), "no welcome window on a first install")
end

-- an existing install, this character's profile new (firstRun): no window
function S.login_new_profile()
	CDTL3DB = { profileKeys = { ["Other - Realm"] = "Other" },
		profiles = { Other = { global = { firstRun = false, previousVersion = "3.2.1" } } } }
	login()
	check(not CDTL3.db.global.tourPending, "no tour for an existing install")
	check(g().firstRun == true, "the profile has firstRun")
	runTimers(600)
	check(#TOUR_STEPS == 0, "no tour")
	check(not welcomeMade() and not welcomeShown(), "a profile's first run opens no window, after every timer ran")
	check(g().firstRun == true and g().previousVersion == 0, "firstRun and previousVersion untouched")
end

-- an update from a version before noticeVersion: no window
function S.login_old_version()
	CDTL3DB = { profileKeys = { [CHAR] = "Default" },
		profiles = { Default = { global = { firstRun = false, previousVersion = "3.1.1" } } } }
	login()
	check(CDTL3:IsNewerVersion() == true, "3.1.1 is older than noticeVersion (the release's rule)")
	runTimers(600)
	check(#TOUR_STEPS == 0, "no tour")
	check(not welcomeMade() and not welcomeShown(), "an update opens no window, after every timer ran")
	check(g().firstRun == false and g().previousVersion == "3.1.1", "firstRun and previousVersion untouched")
end

-- both reasons at once (firstRun and an old version): still no window
function S.login_both()
	CDTL3DB = { profileKeys = { [CHAR] = "Default" },
		profiles = { Default = { global = { firstRun = true, previousVersion = "3.0.9" } } } }
	login()
	runTimers(600)
	check(not welcomeMade(), "firstRun and an old version open no window")
end

-- /cdtl3 whatsnew opens the window on demand, again after closing; its No button works as before
function S.whatsnew()
	CDTL3DB = { profileKeys = { [CHAR] = "Default" },
		profiles = { Default = { global = { firstRun = false, previousVersion = "3.1.1" } } } }
	login()
	runTimers(600)
	check(not welcomeMade(), "nothing open before the command")
	CDTL3:ChatCommand("whatsnew")
	check(welcomeShown(), "/cdtl3 whatsnew opens the window")
	check(g().previousVersion == "3.1.1", "opening it changes nothing saved")
	_G["CDTL3_Firstrun"]:Hide()
	CDTL3:ChatCommand(" whatsnew ")
	local n = 0
	for _, name in ipairs(FRAMES_MADE) do if name == "CDTL3_Firstrun" then n = n + 1 end end
	check(welcomeShown() and n == 1, "opens again, the same window")
	_G["CDTL3_Firstrun_No"].scripts.OnClick()
	check(not welcomeShown() and g().previousVersion == CDTL3.version and g().firstRun == false, "No closes it and marks the version seen")
	CDTL3:ShowWhatsNew()
	check(welcomeShown(), "CDTL3:ShowWhatsNew() opens it too")
end

local run = S[SCENARIO]
if run then run() else check(false, "unknown scenario") end
