// Tests for local patches 1 and 2 (seal as custom CD, seal switch). Patch 2 runs the real
// helper code cut from CooldownTimeline3/CDTL3.lua in fengari; patch 1 checks that the patched
// lines are in Cooldown.lua and runs the same rule as a small replica.
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const NM = new URL('../node_modules', import.meta.url).pathname;
const { lua, lauxlib, lualib, to_luastring } = require(NM + '/fengari');

const ADDON = new URL('../CooldownTimeline3/', import.meta.url).pathname;
const read = (f) => readFileSync(ADDON + f, 'utf8').replace(/\r\n/g, '\n');
let passed = 0, failed = 0;
const check = (ok, what) => { if (ok) passed++; else { failed++; console.error('FAIL: ' + what); } };

// Patch 1: the custom CD of a spell without a cooldown counts from the player's own cast
const cooldown = read('Cooldown.lua');
check(/if start == 0 and CDTL3\.spellCastTimes and CDTL3\.spellCastTimes\[d\["id"\]\] then\n\s*start = CDTL3\.spellCastTimes\[d\["id"\]\]/.test(cooldown),
  'Cooldown.lua: patch 1 is in the custom CD branch');

// Patch 2: real code from CDTL3.lua
const cdtl3 = read('CDTL3.lua');
const a = cdtl3.indexOf('local SEAL_IDS'), b = cdtl3.indexOf('function CDTL3:UNIT_SPELLCAST_SUCCEEDED');
check(a > 0 && b > a, 'CDTL3.lua: seal helpers found before the cast handler');
check(/if isKnown or isKnownOrOverridesKnown then\n(\s*--[^\n]*\n)*\s*CDTL3:EndOtherSealTimers\(spellName\)/.test(cdtl3),
  'CDTL3.lua: EndOtherSealTimers runs for known spells only');

const lua_src = `
local results = {}
local function rec(k, v) results[#results + 1] = k .. "=" .. tostring(v) end
local function setup(names)
  NAMES = names
  C_Spell = { GetSpellName = function(id) return NAMES[id] end }
  CDTL3 = { cooldowns = {}, held = {} }
  function CDTL3:SendToHolding(f) self.held[#self.held + 1] = f.data.name end
  function CDTL3:SendToBarHolding(f) end
  assert(load(HELPER))()
end
local function frame(name, cd)
  local f = { data = { type = "spells", name = name, currentCD = cd } }
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
  rec(lang .. ".seal", CDTL3:IsSealName(names[20375]))
  rec(lang .. ".judgement", CDTL3:IsSealName("Judgement"))
  rec(lang .. ".newseal", CDTL3:IsSealName(names.fury))
  CDTL3:EndOtherSealTimers(names[20154])
  rec(lang .. ".soc", soc.data.currentCD); rec(lang .. ".sotc", sotc.data.currentCD); rec(lang .. ".judge", judge.data.currentCD)
  rec(lang .. ".held", #CDTL3.held)
  soc.data.currentCD = 20; CDTL3.held = {}
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
    check(r[lang + '.held'] === '2', lang + ': ended seal timers go to the holding area (no ready frame)');
    check(r[lang + '.recast'] === '20' && r[lang + '.recastheld'] === '0', lang + ': recasting the same seal ends nothing');
    check(r[lang + '.afterjudgement'] === '20', lang + ': casting Judgement ends no seal timer');
  }
  check(r['empty.untouched'] === '12', 'without seal names from the client nothing is ended');
}
console.log(`seal_patches: ${passed} passed, ${failed} failed`);
process.exitCode = failed ? 1 : 0;
