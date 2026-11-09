local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. m end
local g = CDTL3.db.profile.global
for _, hoc in ipairs({ false, true }) do for _, hwc in ipairs({ false, true }) do
for _, combat in ipairs({ false, true }) do for _, casting in ipairs({ false, true }) do
for _, exc in ipairs({ "none", "testing", "unlock", "debug" }) do
	g.hideOutOfCombat, g.hideWhileCasting, g.autohide = hoc, hwc, false
	g.unlockFrames, g.debugMode = exc == "unlock", exc == "debug"
	CDTL3.testing = exc == "testing"
	CDTL3.combat, CDTL3.casting = combat, casting
	local hide = exc == "none" and ((hoc and not combat) or (hwc and casting))
	local p = FRAMES[3]; p.base = 1; p.last = nil
	CDTL3:Autohide(p, { alpha = 1 })
	local a = FRAMES[1]; a.base = 1; a.last = nil; a.animateOut.playing = false; a.animateOut.plays = 0; a.animateIn.plays = 0
	CDTL3:Autohide(a, { alpha = 1 })
	local tag = string.format("matrix hoc=%s hwc=%s combat=%s casting=%s exc=%s", tostring(hoc), tostring(hwc), tostring(combat), tostring(casting), exc)
	check((p.base == 0) == hide, tag .. " plain alpha " .. p.base)
	check((a.animateOut.plays == 1) == hide, tag .. " animateOut plays " .. a.animateOut.plays)
	p.base = 0; CDTL3:Autohide(p, { alpha = 1 })
	check((p.base == 0) == hide, tag .. " from 0: alpha " .. p.base)
	REFRESHES = 0
	CDTL3:ApplyCombatVisibility()
	check((REFRESHES > 0) == (hoc or hwc), tag .. " apply refreshes " .. REFRESHES)
end end end end end
CDTL3.testing = false; g.unlockFrames = false; g.debugMode = false
