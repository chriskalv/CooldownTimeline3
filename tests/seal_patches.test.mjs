// Tests for the local patch Seal switch: the real helper code cut from
// CooldownTimeline3/CDTL3.lua runs in fengari. The dropped patch Seal as custom cooldown is done by
// the release's private.CustomCDStart since 3.0.13: checked here that Cooldown.lua carries no local
// patch and uses it in both Custom CD branches; tests/seal_flow.test.mjs runs it.
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const require = createRequire(import.meta.url);
const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const NM = path.join(root, 'node_modules');
const { lua, lauxlib, lualib, to_luastring } = require(NM + '/fengari');

const ADDON = path.join(root, 'CooldownTimeline3') + path.sep;
const read = (f) => readFileSync(ADDON + f, 'utf8').replace(/\r\n/g, '\n');
let passed = 0, failed = 0;
const check = (ok, what) => { if (ok) passed++; else { failed++; console.error('FAIL: ' + what); } };

// Dropped patch Seal as custom cooldown: the release counts a Custom CD Time from the last cast (private.CustomCDStart)
const cooldown = read('Cooldown.lua');
check(!cooldown.includes('LOCAL PATCH'), 'Cooldown.lua: no local patch left (Seal as custom cooldown dropped)');
check(/private\.CustomCDStart = function\(d, start\)\n\tif not start or start == 0 then/.test(cooldown),
  'Cooldown.lua: private.CustomCDStart counts from the cast when the game reports no start');
check((cooldown.match(/duration = d\["baseCD"\]\n\s*start = private\.CustomCDStart\(d, start\)\n\s*end\n\s*d\["currentCD"\] = start \+ duration - GetTime\(\)/g) || []).length === 2,
  'Cooldown.lua: both Custom CD branches (on-aura-fade and plain spells) use private.CustomCDStart');

// Patch 2: real code from CDTL3.lua
const cdtl3 = read('CDTL3.lua');
const a = cdtl3.indexOf('local SEAL_IDS'), b = cdtl3.indexOf('function CDTL3:UNIT_SPELLCAST_SUCCEEDED');
check(a > 0 && b > a, 'CDTL3.lua: seal helpers found before the cast handler');
check(/if isKnown or isKnownOrOverridesKnown then\n(\s*--[^\n]*\n)*\s*CDTL3:EndOtherSealTimers\(spellName\)/.test(cdtl3),
  'CDTL3.lua: EndOtherSealTimers runs for known spells only');
check(/if isKnown or isKnownOrOverridesKnown or not CDTL3:IsSealName\(spellName\) then\n\s*RestartBuffFromCast\(spellName\)\n\s*end/.test(cdtl3),
  'CDTL3.lua: a seal proc restarts no buff (RestartBuffFromCast guarded)');

const lua_src = `
local results = {}
local function rec(k, v) results[#results + 1] = k .. "=" .. tostring(v) end
local function setup(names)
  NAMES = names
  C_Spell = { GetSpellName = function(id) return NAMES[id] end }
  CDTL3 = { cooldowns = {}, held = {}, barHeld = {}, ended = {} }
  function CDTL3:SendToHolding(f) self.held[#self.held + 1] = f.data.name end
  function CDTL3:SendToBarHolding(f) self.barHeld[#self.barHeld + 1] = f.data.name end
  function CDTL3:FireTimer(msg, f) self.ended[#self.ended + 1] = msg .. ":" .. f.data.name end
  assert(load(HELPER))()
end
local function frame(name, cd, kind)
  local f = { data = { type = kind or "spells", name = name, currentCD = cd }, pubLive = true }
  table.insert(CDTL3.cooldowns, f)
  return f
end
for lang, names in pairs({
  en = { [20154] = "Seal of Righteousness", [20375] = "Seal of Command", [20305] = "Seal of the Crusader",
         [20165] = "Seal of Light", [20166] = "Seal of Wisdom", [20164] = "Seal of Justice", fury = "Seal of Fury" },
  de = { [20154] = "Siegel der Rechtschaffenheit", [20375] = "Siegel des Befehls", [20305] = "Siegel des Kreuzfahrers",
         [20165] = "Siegel des Lichts", [20166] = "Siegel der Weisheit", [20164] = "Siegel der Gerechtigkeit", fury = "Siegel des Zorns" },
}) do
  setup(names)
  local soc, sotc, judge = frame(names[20375], 12), frame(names[20305], 25), frame("Judgement", 5)
  local socBuff, socCustom = frame(names[20375], 12, "buffs"), frame(names[20375], 12, "customs")
  rec(lang .. ".seal", CDTL3:IsSealName(names[20375]))
  rec(lang .. ".judgement", CDTL3:IsSealName("Judgement"))
  rec(lang .. ".newseal", CDTL3:IsSealName(names.fury))
  CDTL3:EndOtherSealTimers(names[20154])
  rec(lang .. ".soc", soc.data.currentCD); rec(lang .. ".sotc", sotc.data.currentCD); rec(lang .. ".judge", judge.data.currentCD)
  rec(lang .. ".held", #CDTL3.held); rec(lang .. ".barheld", #CDTL3.barHeld); rec(lang .. ".ended", #CDTL3.ended)
  rec(lang .. ".buff", socBuff.data.currentCD); rec(lang .. ".custom", socCustom.data.currentCD)
  rec(lang .. ".live", tostring(soc.pubLive))
  soc.data.currentCD = 20; socBuff.data.currentCD = 20; CDTL3.held = {}
  CDTL3:EndOtherSealTimers(names[20375])
  rec(lang .. ".recast", soc.data.currentCD); rec(lang .. ".recastheld", #CDTL3.held)
  CDTL3:EndOtherSealTimers("Judgement")
  rec(lang .. ".afterjudgement", soc.data.currentCD)
end
setup({})
local f = frame("Seal of Command", 12)
CDTL3:EndOtherSealTimers("Seal of Righteousness")
rec("empty.untouched", f.data.currentCD)
RESULT = table.concat(results, ";")
`;
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
lua.lua_pushstring(L, to_luastring(cdtl3.slice(a, b))); lua.lua_setglobal(L, to_luastring('HELPER'));
if (lauxlib.luaL_dostring(L, to_luastring(lua_src)) !== 0) { failed++; console.error('FAIL: ' + lua.lua_tojsstring(L, -1)); }
else {
  lua.lua_getglobal(L, to_luastring('RESULT'));
  const r = Object.fromEntries(lua.lua_tojsstring(L, -1).split(';').map((kv) => kv.split('=')));
  for (const lang of ['en', 'de']) {
    check(r[lang + '.seal'] === 'true', lang + ': a known seal is a seal');
    check(r[lang + '.judgement'] === 'false', lang + ': Judgement is no seal');
    check(r[lang + '.newseal'] === 'true', lang + ': a seal outside the list is found by the common name start');
    check(r[lang + '.soc'] === '-1' && r[lang + '.sotc'] === '-1', lang + ': casting another seal ends both seal timers');
    check(r[lang + '.judge'] === '5', lang + ': the Judgement timer is untouched');
    check(r[lang + '.held'] === '3' && r[lang + '.barheld'] === '3', lang + ': ended seal timers (two spells, one buff) go to the holding areas (no ready frame)');
    check(r[lang + '.ended'] === '3' && r[lang + '.live'] === 'nil', lang + ': other addons hear each ended timer once');
    check(r[lang + '.buff'] === '-1', lang + ': the old seal\'s buff timer ends too');
    check(r[lang + '.custom'] === '12', lang + ': a custom timer named like a seal is left alone');
    check(r[lang + '.recast'] === '20' && r[lang + '.recastheld'] === '0', lang + ': recasting the same seal ends nothing');
    check(r[lang + '.afterjudgement'] === '20', lang + ': casting Judgement ends no seal timer');
  }
  check(r['empty.untouched'] === '12', 'without seal names from the client nothing is ended');
}
console.log(`seal_patches: ${passed} passed, ${failed} failed`);
process.exitCode = failed ? 1 : 0;
