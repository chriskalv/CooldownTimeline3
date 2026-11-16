// Mutation probes for the five local patches and the version of the personal build (and two for the release's Custom CD start, which the
// seal tests also cover): each probe breaks one line of an addon file on disk, runs every
// simulation (at least one must exit red), then restores the file with git checkout. At the end
// the addon folder must be clean again. Strings are written with LF; they are matched against
// the CRLF files of the release.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const SUITES = ['seal_patches.test.mjs', 'seal_flow.test.mjs', 'hide_casting.test.mjs', 'quiet_start.test.mjs', 'border_secret.test.mjs', 'timeline.mjs'];

const M = [
  // Seal switch (CDTL3.lua)
  ['seal', 'EndOtherSealTimers not called', 'CDTL3.lua', '\t\t\tCDTL3:EndOtherSealTimers(spellName)\n', ''],
  ['seal', 'a seal proc restarts the seal buff', 'CDTL3.lua', 'if isKnown or isKnownOrOverridesKnown or not CDTL3:IsSealName(spellName) then', 'if true then'],
  ['seal', 'a seal from the spellbook restarts no buff', 'CDTL3.lua', 'if isKnown or isKnownOrOverridesKnown or not CDTL3:IsSealName(spellName) then', 'if not CDTL3:IsSealName(spellName) then'],
  ['seal', 'only spell timers end', 'CDTL3.lua', 'or (t == "buffs" and sealNames[d["name"]])) then', 'or false) then'],
  ['seal', 'any buff that starts like a seal ends', 'CDTL3.lua', '(t == "buffs" and sealNames[d["name"]])', '(t == "buffs" and CDTL3:IsSealName(d["name"]))'],
  ['seal', 'spell timers end only by the listed names', 'CDTL3.lua', '(t == "spells" and CDTL3:IsSealName(d["name"]))', '(t == "spells" and sealNames[d["name"]])'],
  ['seal', 'Seal of Fury missing from the seal list', 'CDTL3.lua', '20166, 20164, 1311649 }', '20166, 20164 }'],
  ['seal', 'recasting a seal ends its own timer', 'CDTL3.lua', 'and d["name"] ~= castName and d["currentCD"]', 'and d["currentCD"]'],
  ['seal', 'held timers are ended again', 'CDTL3.lua', 'd["currentCD"] and d["currentCD"] >= 0\n', 'd["currentCD"]\n'],
  ['seal', 'old timer keeps its time', 'CDTL3.lua', '\t\t\td["currentCD"] = -1\n\t\t\tCDTL3:SendToHolding(f)', '\t\t\tCDTL3:SendToHolding(f)'],
  ['seal', 'old timer left on its lane (Ready, sound)', 'CDTL3.lua', '\t\t\td["currentCD"] = -1\n\t\t\tCDTL3:SendToHolding(f)\n\t\t\tCDTL3:SendToBarHolding(f)\n', '\t\t\td["currentCD"] = -1\n'],
  ['seal', 'bar left on its bar frame', 'CDTL3.lua', '\t\t\tCDTL3:SendToBarHolding(f)\n\t\t\tif f.pubLive then', '\t\t\tif f.pubLive then'],
  ['seal', 'no TimerEnded for other addons', 'CDTL3.lua', '\t\t\t\tCDTL3:FireTimer("CDTL3_TimerEnded", f)\n', ''],
  ['seal', 'common seal name start not used', 'CDTL3.lua', '#sealPrefix < 4 then', '#sealPrefix < 40 then'],
  ['seal', 'any spell name counts as a seal', 'CDTL3.lua', '\tif sealNames[name] then\n\t\treturn true\n\tend\n', '\tdo\n\t\treturn true\n\tend\n'],

  // the release's own Custom CD start (private.CustomCDStart, 3.0.13), which replaced the patch Seal as custom cooldown:
  // the seal tests stay as fallback tests against it
  ['release', 'CustomCDStart ignores the cast time', 'Cooldown.lua', '\t\tif castTime then\n\t\t\treturn castTime', '\t\tif false then\n\t\t\treturn castTime'],
  ['release', 'plain spells without CustomCDStart', 'Cooldown.lua', '\t\t\t\t\t\t\t\t\tstart = private.CustomCDStart(d, start)\n\t\t\t\t\t\t\t\tend\n\t\t\t\t\t\t\t\td["currentCD"] = start + duration - GetTime()\n\n\t\t\t\t\t\t\t\tCDTL3.IconFx:PollCharges(f)', '\t\t\t\t\t\t\t\tend\n\t\t\t\t\t\t\t\td["currentCD"] = start + duration - GetTime()\n\n\t\t\t\t\t\t\t\tCDTL3.IconFx:PollCharges(f)'],

  // Hide while casting (Helpers.lua, CDTL3.lua, Options.lua, Locales/enUS.lua)
  ['cast', 'cast rule ignored by Autohide', 'Helpers.lua', 'if (CDTL3:ShowRuleHides(s) or CDTL3:CastRuleHides()) and', 'if (CDTL3:ShowRuleHides(s)) and'],
  ['cast', 'cast rule ignores the option', 'Helpers.lua', 'return CDTL3.db.profile.global["hideWhileCasting"] and CDTL3.casting and true or false', 'return CDTL3.casting and true or false'],
  ['cast', 'cast rule ignores the cast state', 'Helpers.lua', 'return CDTL3.db.profile.global["hideWhileCasting"] and CDTL3.casting and true or false', 'return CDTL3.db.profile.global["hideWhileCasting"] and true or false'],
  ['cast', 'cast rule skips Show Always', 'Helpers.lua', 'if (CDTL3:ShowRuleHides(s) or CDTL3:CastRuleHides()) and', 'if (CDTL3:ShowRuleHides(s) or (CDTL3:CastRuleHides() and not (s and s["showMode"] == "ALWAYS"))) and'],
  ['cast', 'cast rule never dims', 'Helpers.lua', '\t\tif s and s["dimInsteadOfHide"] then\n\t\t\tlocal target', '\t\tif s and s["dimInsteadOfHide"] and not CDTL3:CastRuleHides() then\n\t\t\tlocal target'],
  ['cast', 'ApplyCombatVisibility returns on hideWhileCasting', 'Helpers.lua', 'if not private.AnyShowRule() and not CDTL3.db.profile.global["hideWhileCasting"] then return end', 'if not private.AnyShowRule() then return end'],
  ['cast', 'hide rule does not stop a running fade-in', 'Helpers.lua', '\t\tif f.animateIn and f.animateIn:IsPlaying() then\n\t\t\tf.animateIn:Stop()\n\t\tend\n\t\tif f:GetAlpha() ~= 0 then', '\t\tif f:GetAlpha() ~= 0 then'],
  ['cast', 'visible path does not stop the hide fade-out', 'Helpers.lua', 'f.cdtl3HideFade = nil\n\t\tif f.animateOut and f.animateOut:IsPlaying() then', 'f.cdtl3HideFade = nil\n\t\tif false then'],
  ['cast', 'hide fade mark never cleared', 'Helpers.lua', '\t\tf.cdtl3HideFade = nil\n\t\tif f.animateOut and f.animateOut:IsPlaying() then', '\t\tif f.animateOut and f.animateOut:IsPlaying() then'],
  ['cast', 'hide fade-out not marked', 'Helpers.lua', '\t\t\t\t\tf.cdtl3HideFade = true', '\t\t\t\t\t-- unmarked'],
  ['cast', 'second read missing', 'CDTL3.lua', '\t\tC_Timer.After(0, RecheckCasting)', '\t\t-- no recheck'],
  ['cast', 'INTERRUPTED not registered', 'CDTL3.lua', '\t"UNIT_SPELLCAST_INTERRUPTED",\n', ''],
  ['cast', 'START does not force casting', 'CDTL3.lua', 'local casting = (started and true) or ReadPlayerCasting()', 'local casting = ReadPlayerCasting()'],
  ['cast', 'read without pcall', 'CDTL3.lua', 'local ok, name = pcall(UnitCastingInfo, "player")', 'local ok, name = true, UnitCastingInfo("player")'],
  ['cast', 'TurnOn does not seed the state', 'CDTL3.lua', '\tCDTL3:UpdateCastingState()\nend', '\t-- no seed\nend'],
  ['cast', 'TurnOn registers no cast events', 'CDTL3.lua', '\t\tCDTL3:RegisterCastEvents()\n', ''],
  ['cast', 'no unit filter on START', 'CDTL3.lua', 'if unit ~= "player" then return end\t-- plain', 'if false then return end\t-- plain'],
  ['cast', 'EMPOWER registered without pcall', 'CDTL3.lua', 'pcall(CDTL3.RegisterUnitEvents, CDTL3, event, "player")', 'CDTL3:RegisterUnitEvents(event, "player")'],
  ['cast', 'TurnOff keeps a stale state', 'CDTL3.lua', '\t\tCDTL3.casting = false\n\t\tCDTL3:ApplyCombatVisibility()\n\tend\nend', '\tend\nend'],
  ['cast', 'TurnOff clears without applying', 'CDTL3.lua', '\t\tCDTL3.casting = false\n\t\tCDTL3:ApplyCombatVisibility()\n\tend\nend', '\t\tCDTL3.casting = false\n\tend\nend'],
  ['cast', 'stop events read at once (chain flash)', 'CDTL3.lua', '\tif C_Timer and C_Timer.After then\n\t\tC_Timer.After(0, RecheckCasting)', '\tCDTL3:UpdateCastingState()\n\tif C_Timer and C_Timer.After then\n\t\tC_Timer.After(0, RecheckCasting)'],
  ['cast', 'default missing', 'CDTL3.lua', '\t\t\thideWhileCasting = false,\n', ''],
  ['cast', 'option order wrong', 'Options.lua', 'order = 200.6,', 'order = 202,'],
  ['cast', 'option name not a locale key', 'Options.lua', 'name = L["Hide while casting"],', 'name = "Hide while casting",'],
  ['cast', 'dim toggle stays disabled for Always', 'Options.lua', 'return settings()["showMode"] == "ALWAYS" and not CDTL3.db.profile.global["hideWhileCasting"]', 'return settings()["showMode"] == "ALWAYS"'],
  ['cast', 'locale entry missing', 'Locales/enUS.lua', 'L["Hide while casting"] = true\n', ''],
  // Flight timers off by default (CDTL3.lua; Flights.lua is the release's)
  ['flight', 'default back to on', 'CDTL3.lua', '\t\t\t\tenabled = false,\n\t\t\t\tdefaultLane = 1,\n\t\t\t\tdefaultReady = 1,\n\t\t\t\tdefaultBar = 1,\n\t\t\t},\n\t\t},', '\t\t\t\tenabled = true,\n\t\t\t\tdefaultLane = 1,\n\t\t\t\tdefaultReady = 1,\n\t\t\t\tdefaultBar = 1,\n\t\t\t},\n\t\t},'],
  ['flight', 'default missing', 'CDTL3.lua', '\t\t\t\tenabled = false,\n\t\t\t\tdefaultLane = 1,\n\t\t\t\tdefaultReady = 1,\n\t\t\t\tdefaultBar = 1,\n\t\t\t},\n\t\t},', '\t\t\t\tdefaultLane = 1,\n\t\t\t\tdefaultReady = 1,\n\t\t\t\tdefaultBar = 1,\n\t\t\t},\n\t\t},'],
  ['flight', 'a taxi map pick ignores the switch', 'Flights.lua', 'private.OnTakeTaxiNode = function(slot)\n\tif not FL:Enabled() then', 'private.OnTakeTaxiNode = function(slot)\n\tif false then'],
  ['flight', 'a resumed flight ignores the switch', 'Flights.lua', 'if not (UnitOnTaxi and UnitOnTaxi("player")) or not FL:Enabled() then', 'if not (UnitOnTaxi and UnitOnTaxi("player")) then'],

  // No automatic What's new (CDTL3.lua)
  ['news', 'automatic open restored', 'CDTL3.lua', "\t-- LOCAL PATCH (Zippy, 2026-11-16): no automatic What's new: the welcome window no longer opens\n\t-- by itself after an update or on a profile's first run; /cdtl3 whatsnew still opens it\n", '\telseif CDTL3.db.profile.global["firstRun"] or notice then\n\t\tC_Timer.After(10, function()\n\t\t\tprivate.CreateFirstRunFrame()\n\t\tend)\n'],
  ['news', 'opens on a profile\'s first run', 'CDTL3.lua', "\t-- LOCAL PATCH (Zippy, 2026-11-16): no automatic What's new: the welcome window no longer opens\n", '\telseif CDTL3.db.profile.global["firstRun"] then\n\t\tC_Timer.After(10, function() CDTL3:ShowWhatsNew() end)\n'],
  ['news', 'opens after an update', 'CDTL3.lua', "\t-- LOCAL PATCH (Zippy, 2026-11-16): no automatic What's new: the welcome window no longer opens\n", '\telseif notice then\n\t\tC_Timer.After(30, function() CDTL3:ShowWhatsNew() end)\n'],
  ['news', 'ShowWhatsNew opens nothing', 'CDTL3.lua', '\treturn private.CreateFirstRunFrame()\n', '\treturn nil\n'],
  ['news', '/cdtl3 whatsnew removed', 'CDTL3.lua', '\telseif input:trim() == "whatsnew" then\n\t\tCDTL3:ShowWhatsNew()\n', ''],
  ['news', 'first-install tour dropped too', 'CDTL3.lua', '\t\t\tCDTL3.Start:StartTour()\n', ''],

  // Border frames tolerate hidden geometry (Helpers.lua)
  ['border', 'guard not installed', 'Helpers.lua', '\t\tf.SetupTextureCoordinates = private.BorderCoords\n', ''],
  ['border', 'guard always on', 'Helpers.lua', '\treturn issecretvalue(f:GetWidth()) or issecretvalue(f:GetHeight())\n', '\treturn true\n'],
  ['border', 'guard never on', 'Helpers.lua', '\treturn issecretvalue(f:GetWidth()) or issecretvalue(f:GetHeight())\n', '\treturn false\n'],
  ['border', 'guard swallows every error (pcall)', 'Helpers.lua', '\tf.cdtl3SetupCoords(f)\n', '\tpcall(f.cdtl3SetupCoords, f)\n'],
  ['border', 'installed again on every SetBorder', 'Helpers.lua', 'if issecretvalue and f.SetupTextureCoordinates and not f.cdtl3SetupCoords then', 'if issecretvalue and f.SetupTextureCoordinates then'],
  ['border', 'installed on a client without secrets', 'Helpers.lua', 'if issecretvalue and f.SetupTextureCoordinates and not f.cdtl3SetupCoords then', 'if f.SetupTextureCoordinates and not f.cdtl3SetupCoords then'],
  ['border', 'no retry after a skip', 'Helpers.lua', '\t\t\tf:SetScript("OnUpdate", private.BorderCoordsRetry)\n', '\t\t\t-- no retry\n'],
  ['border', 'retry replaces another OnUpdate', 'Helpers.lua', '\t\tif not f:GetScript("OnUpdate") then\n', '\t\tif true then\n'],
  ['border', 'retry never ends', 'Helpers.lua', '\tf:SetScript("OnUpdate", nil)\n\tif f.backdropInfo then', '\tif f.backdropInfo then'],
  ['border', 'retry works out a cleared border', 'Helpers.lua', '\tif f.backdropInfo then\n\t\tf:SetupTextureCoordinates()\n', '\tif true then\n\t\tf:SetupTextureCoordinates()\n'],

  // Version of the personal build (all TOC files and CDTL3.lua)
  ['version', 'one TOC keeps the release version', 'CooldownTimeline3_Mists.toc', '## Version: 3.2.1.1\n', '## Version: 3.2.1\n'],
  ['version', 'main TOC with another version', 'CooldownTimeline3.toc', '## Version: 3.2.1.1\n', '## Version: 3.2.1.2\n'],
  ['version', 'CDTL3.version keeps the release version', 'CDTL3.lua', 'CDTL3.version = "3.2.1.1"', 'CDTL3.version = "3.2.1"'],
  ['version', 'TOC version comment missing', 'CooldownTimeline3_TBC.toc', '# LOCAL PATCH (Zippy, 2026-11-16): personal build 3.2.1.1', '## X-Note: personal build 3.2.1.1'],
];

let red = 0;
const perPatch = {};
for (const [patch, name, file, from, to] of M) {
  const p = path.join(root, 'CooldownTimeline3', file);
  const orig = readFileSync(p, 'utf8');
  const nl = orig.includes('\r\n') ? '\r\n' : '\n';
  const f = from.replace(/\n/g, nl), t = to.replace(/\n/g, nl);
  const n = orig.split(f).length - 1;
  perPatch[patch] = perPatch[patch] || { probes: 0, red: 0 };
  perPatch[patch].probes++;
  if (n !== 1) { console.log(`SETUP ${patch} ${name}: ${n} matches`); process.exitCode = 1; continue; }
  writeFileSync(p, orig.replace(f, t));
  const runs = SUITES.map((s) => spawnSync(process.execPath, [path.join(here, s)], { encoding: 'utf8' }));
  execFileSync('git', ['-C', root, 'checkout', '--', path.join('CooldownTimeline3', file)]);
  const redSuites = SUITES.filter((s, i) => runs[i].status !== 0);
  const out = runs.map((r) => r.stdout + r.stderr).join('\n');
  const first = (out.split('\n').find((l) => l.startsWith('FAIL')) || '').slice(0, 110);
  const isRed = redSuites.length > 0;
  if (isRed) { red++; perPatch[patch].red++; }
  console.log(`${isRed ? 'RED  ' : 'GREEN'} ${patch} ${name}: ${redSuites.join(', ') || '-'} | ${first}`);
}
const st = execFileSync('git', ['-C', root, 'status', '--porcelain', '--', 'CooldownTimeline3']).toString();
for (const [patch, c] of Object.entries(perPatch)) console.log(`${patch}: ${c.red}/${c.probes} red`);
console.log(`${red}/${M.length} red; addon tree ${st ? 'DIRTY' : 'clean'}`);
if (red !== M.length || st || perPatch.seal.probes < 6 || perPatch.cast.probes < 6
    || perPatch.flight.probes < 3 || perPatch.news.probes < 3 || perPatch.border.probes < 6
    || perPatch.version.probes < 3) process.exitCode = 1;
