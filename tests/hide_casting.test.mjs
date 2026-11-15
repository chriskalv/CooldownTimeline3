// Test runner for the Hide while casting patch: luaparse (Lua 5.1) over every Lua file of the
// addon, static checks of the default, the option and its locale entries, the real AceLocale with
// the addon's locale files, and the fengari spec on the extracted code (cast state from CDTL3.lua,
// the visibility rules from Helpers.lua).
import { createRequire } from 'node:module';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { here, ADDON, readAddon, readTest, pick, range } from './lua_harness.mjs';

const require = createRequire(import.meta.url);
const NM = path.join(here, '..', 'node_modules');
const luaparse = require(NM + '/luaparse');
const { lua, lauxlib, lualib, to_luastring } = require(NM + '/fengari');

let pass = 0, fail = 0;
const msgs = [];
const check = (c, m) => { if (c) pass++; else { fail++; msgs.push(m); } };

// every Lua file of the addon (libraries included) parses as Lua 5.1
const luaFiles = [];
const walkDir = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) walkDir(p);
    else if (name.endsWith('.lua')) luaFiles.push(p);
  }
};
walkDir(ADDON);
for (const p of luaFiles) {
  try { luaparse.parse(readFileSync(p, 'utf8'), { luaVersion: '5.1' }); check(true); }
  catch (e) { check(false, `luaparse ${path.relative(ADDON, p)}: ${e.message}`); }
}
check(luaFiles.length > 40, `addon Lua files found (${luaFiles.length})`);

const raw = { cdtl3: 'CDTL3.lua', helpers: 'Helpers.lua', options: 'Options.lua', enUS: 'Locales/enUS.lua' };
const src = {};
for (const [k, f] of Object.entries(raw)) {
  const s = readFileSync(path.join(ADDON, f), 'utf8');
  check(!/[^\r]\n/.test(s), `${f}: LF without CR`);
  src[k] = s.replace(/\r\n/g, '\n');
}
// the patch lines carry no local paths
for (const [k, s] of Object.entries(src)) {
  const patchLines = s.split('\n').filter((l, i, all) => /LOCAL PATCH/.test(l) || /LOCAL PATCH/.test(all[i - 1] || ''));
  check(!patchLines.some((l) => /\/tmp\/|\/home\/|scratchpad/i.test(l)), `${k}: local path near a patch marker`);
}

const ast = (s) => luaparse.parse(s, { luaVersion: '5.1', ranges: true });
function walk(node, fn) {
  if (!node || typeof node !== 'object') return;
  fn(node);
  for (const v of Object.values(node)) {
    if (Array.isArray(v)) v.forEach((c) => walk(c, fn));
    else if (v && typeof v === 'object' && v.type) walk(v, fn);
  }
}
const text = (s, n) => s.slice(n.range[0], n.range[1]);

// static: the default sits next to hideOutOfCombat in the global defaults
let defaultOk = false;
walk(ast(src.cdtl3), (n) => {
  if (n.type === 'TableConstructorExpression') {
    const keys = Object.fromEntries(n.fields.filter((f) => f.type === 'TableKeyString').map((f) => [f.key.name, f.value]));
    if (keys.hideOutOfCombat && keys.dynamicSpellDetection && keys.hideWhileCasting
        && keys.hideWhileCasting.type === 'BooleanLiteral' && keys.hideWhileCasting.value === false) defaultOk = true;
  }
});
check(defaultOk, 'default global.hideWhileCasting = false next to hideOutOfCombat missing');

let optionNode = null;
walk(ast(src.options), (n) => { if (n.type === 'TableKeyString' && n.key.name === 'hideWhileCasting') optionNode = n; });
check(!!optionNode, 'option hideWhileCasting missing');
const o = src.options;
const i1 = o.indexOf('hideOutOfCombat = {'), i2 = o.indexOf('hideWhileCasting = {'), i3 = o.indexOf('autohide = {', i1);
check(i1 > 0 && i1 < i2 && i2 < i3, 'option should sit between hideOutOfCombat and autohide');

// the option's texts are locale keys, each listed in enUS.lua like the release's own options
const DESC = "Frames fade while you cast or channel a spell with a cast time and reappear the moment the cast ends, is interrupted or fails. Instant spells don't count. It works on top of each frame's Show setting, Always included; a frame set to Dim instead of hide dims instead. Cooldown detection keeps running. Unlock frames, Edit Mode, test mode and flight timers always show the frames";
const optText = optionNode ? text(o, optionNode) : '';
check(optText.includes('name = L["Hide while casting"]'), 'option name is the locale key L["Hide while casting"]');
check(optText.includes(`desc = L["${DESC}"]`), 'option desc is the locale key of the description');
check(src.enUS.includes('L["Hide while casting"] = true\n'), 'enUS.lua lists "Hide while casting"');
check(src.enUS.includes(`L["${DESC}"] = true\n`), 'enUS.lua lists the description');

const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(chunk, name) {
  if (lauxlib.luaL_loadbuffer(L, to_luastring(chunk), null, to_luastring(name)) !== lua.LUA_OK
      || lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
    const e = lua.lua_tojsstring(L, -1);
    lua.lua_pop(L, 1);
    check(false, `${name}: ${e}`);
    return false;
  }
  lua.lua_pop(L, 1);
  return true;
}
run('unpack = unpack or table.unpack', 'compat');

// the real AceLocale with the addon's enUS (default, silent) and deDE files, on a German client:
// the new keys fall back to English, a key nobody lists returns itself without an error
run(`LOCALE_ERRORS = {}
  function geterrorhandler() return function(e) LOCALE_ERRORS[#LOCALE_ERRORS + 1] = e end end
  function GetLocale() return "deDE" end`, 'locale-env');
run(readAddon('Libs/LibStub/LibStub.lua'), 'LibStub');
run(readAddon('Libs/AceLocale-3.0/AceLocale-3.0.lua'), 'AceLocale');
run(readAddon('Locales/enUS.lua'), 'enUS');
run(readAddon('Locales/deDE.lua'), 'deDE');
run(`local L = LibStub("AceLocale-3.0"):GetLocale("CDTL3")
  assert(L["Hide while casting"] == "Hide while casting", "name falls back to English")
  assert(L["Hide out of combat"] ~= nil, "release key")
  local ok, v = pcall(function() return L["A key nobody lists"] end)
  assert(ok and v == "A key nobody lists" and #LOCALE_ERRORS == 0, "missing key without an error")
  ADDON_L = L
  return nil`, 'locale-check') && check(true);

// the extracted addon code
const c = src.cdtl3, h = src.helpers;
let code = '';
try {
  code = [
    pick(c, ['CDTL3.unitEventFrame'], 'CDTL3.lua'),
    range(c, 'CDTL3.unitEventFrame:SetScript', 'function CDTL3:RegisterUnitEvents', 'CDTL3.lua'),
    pick(c, ['CDTL3:RegisterUnitEvents'], 'CDTL3.lua'),
    range(c, '-- LOCAL PATCH (Zippy, 2026-11-09): Hide while casting. CDTL3.casting follows', 'function CDTL3:PLAYER_REGEN_DISABLED()', 'CDTL3.lua'),
    pick(c, ['CDTL3:TurnOn', 'CDTL3:TurnOff', 'CDTL3:PLAYER_REGEN_DISABLED', 'CDTL3:PLAYER_REGEN_ENABLED'], 'CDTL3.lua'),
    'do local private = {}',
    pick(h, ['CDTL3:InBossFight', 'CDTL3:ShowRuleHides', 'CDTL3:CastRuleHides', 'private.AnyShowRule',
      'CDTL3:Autohide', 'CDTL3:ApplyCombatVisibility'], 'Helpers.lua'),
    'end',
  ].join('\n');
  check(true);
} catch (e) { check(false, e.message); }
run(readTest('hide_casting_env.lua'), 'env');
run(code, 'addon');

// the option entry: get/set; the Show tab's Dim instead of hide toggle opens for Always frames
// while Hide while casting is on
if (optionNode) {
  run(`local L = ADDON_L
    OPT = (function() return {${optText}} end)().hideWhileCasting
    REFRESHED = 0
    function CDTL3:RefreshConfig() REFRESHED = REFRESHED + 1 end
    local o = OPT
    assert(o.name == "Hide while casting", "name")
    assert(o.desc == ${JSON.stringify(DESC)}, "desc")
    assert(o.order == 200.6 and o.type == "toggle" and o.width == "full", "order/type/width")
    o.set(nil, true)
    assert(CDTL3.db.profile.global.hideWhileCasting == true and REFRESHED == 1, "set true")
    assert(o.get(nil) == true, "get")
    o.set(nil, false)
    assert(CDTL3.db.profile.global.hideWhileCasting == false and REFRESHED == 2, "set false")
    return nil`, 'option-check') && check(true);
}
try {
  const showArgs = pick(o, ['private.AddShowArgs'], 'Options.lua');
  run(`local L = ADDON_L
    local private = {}
    ${showArgs}
    local s = { showMode = "ALWAYS" }
    local args = {}
    private.AddShowArgs(args, function() return s end, function() end)
    local gl = CDTL3.db.profile.global
    local dis = args.dimInsteadOfHide.disabled
    gl.hideWhileCasting = false
    assert(dis() == true, "Always without Hide while casting: dim disabled")
    gl.hideWhileCasting = true
    assert(dis() == false, "Always with Hide while casting: dim enabled")
    s.showMode = "COMBAT"; gl.hideWhileCasting = false
    assert(dis() == false, "Only in combat: dim enabled")
    return nil`, 'dim-toggle') && check(true);
} catch (e) { check(false, e.message); }

// spec
if (lauxlib.luaL_loadbuffer(L, to_luastring(readTest('hide_casting_spec.lua')), null, to_luastring('spec')) !== lua.LUA_OK
    || lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
  check(false, 'spec: ' + lua.lua_tojsstring(L, -1));
} else {
  lua.lua_getfield(L, -1, to_luastring('pass')); pass += lua.lua_tointeger(L, -1); lua.lua_pop(L, 1);
  lua.lua_getfield(L, -1, to_luastring('fail')); const f = lua.lua_tointeger(L, -1); fail += f; lua.lua_pop(L, 1);
  lua.lua_getfield(L, -1, to_luastring('msgs'));
  for (let i = 1; i <= f; i++) { lua.lua_rawgeti(L, -1, i); msgs.push(lua.lua_tojsstring(L, -1)); lua.lua_pop(L, 1); }
}

for (const m of msgs.slice(0, 15)) console.log('FAIL ' + m);
if (msgs.length > 15) console.log(`... ${msgs.length - 15} more`);
console.log(`hide_casting: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
