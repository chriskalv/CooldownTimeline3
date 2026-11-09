// Test runner for the Hide while casting patch: luaparse (Lua 5.1) over the changed addon
// files, static checks of default and option, and the fengari spec on the extracted code.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
const NM = '/home/user/squareminimapbuttons/node_modules';
const luaparse = require(NM + '/luaparse');
const { lua, lauxlib, lualib, to_luastring } = require(NM + '/fengari');

const here = path.dirname(fileURLToPath(import.meta.url));
const addon = path.join(here, '..', 'CooldownTimeline3');
const read = (f) => readFileSync(path.join(addon, f), 'utf8');
let pass = 0, fail = 0;
const msgs = [];
const check = (c, m) => { if (c) pass++; else { fail++; msgs.push(m); } };

const src = { cdtl3: read('CDTL3.lua'), helpers: read('Helpers.lua'), options: read('Options.lua') };
const asts = {};
for (const [k, s] of Object.entries(src)) {
  try { asts[k] = luaparse.parse(s, { luaVersion: '5.1', ranges: true, locations: true }); check(true); }
  catch (e) { check(false, `luaparse ${k}: ${e.message}`); }
  check(!/[^\r]\n/.test(s), `${k}: LF without CR`);
  check(!/\/tmp|\/home|scratchpad|Opus|Sonnet|Fable|Claude/i.test(s), `${k}: forbidden path or model name`);
}
for (const f of ['Cooldown.lua', 'BarFrames.lua', 'Lanes.lua', 'Ready.lua']) {
  try { luaparse.parse(read(f), { luaVersion: '5.1' }); } catch (e) { check(false, `luaparse ${f}: ${e.message}`); }
}
if (fail) { report(); }

function fnName(st) {
  if (st.type !== 'FunctionDeclaration' || !st.identifier) return null;
  const id = st.identifier;
  if (id.type === 'MemberExpression') return `${id.base.name}${id.indexer}${id.identifier.name}`;
  return id.name;
}
const text = (s, st) => s.slice(st.range[0], st.range[1]);
function pickFns(key, names) {
  const out = [];
  for (const n of names) {
    const st = asts[key].body.find((b) => fnName(b) === n);
    check(!!st, `function ${n} not found`);
    if (st) out.push(text(src[key], st));
  }
  return out;
}
function walk(node, fn, parent) {
  if (!node || typeof node !== 'object') return;
  fn(node, parent);
  for (const v of Object.values(node)) {
    if (Array.isArray(v)) v.forEach((c) => walk(c, fn, node));
    else if (v && typeof v === 'object' && v.type) walk(v, fn, node);
  }
}

// static: default and option
let defaultOk = false, optionNode = null;
walk(asts.cdtl3, (n) => {
  if (n.type === 'TableConstructorExpression') {
    const keys = Object.fromEntries(n.fields.filter((f) => f.type === 'TableKeyString').map((f) => [f.key.name, f.value]));
    if (keys.hideOutOfCombat && keys.hideWhileCasting && keys.hideWhileCasting.type === 'BooleanLiteral' && keys.hideWhileCasting.value === false) defaultOk = true;
  }
});
check(defaultOk, 'default global.hideWhileCasting = false next to hideOutOfCombat missing');
walk(asts.options, (n) => {
  if (n.type === 'TableKeyString' && n.key.name === 'hideWhileCasting') optionNode = n;
});
check(!!optionNode, 'option hideWhileCasting missing');

// extract code
const s = src.cdtl3;
const startMark = s.indexOf('-- LOCAL PATCH (Zippy, 2026-11-09): Hide while casting. CDTL3.casting follows');
const endMark = s.indexOf('function CDTL3:PLAYER_REGEN_DISABLED()');
check(startMark > 0 && endMark > startMark, 'cast-state block not found');
const frameStmts = asts.cdtl3.body.filter((b) => /^CDTL3\.unitEventFrame/.test(text(s, b))).map((b) => text(s, b));
check(frameStmts.length === 2, 'unitEventFrame statements not found');
const code = [
  ...frameStmts,
  ...pickFns('cdtl3', ['CDTL3:RegisterUnitEvents']),
  s.slice(startMark, endMark),
  ...pickFns('cdtl3', ['CDTL3:TurnOn', 'CDTL3:TurnOff']),
  ...pickFns('helpers', ['CDTL3:Autohide', 'CDTL3:ApplyCombatVisibility']),
].join('\n');

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
  return true;
}
// Lua 5.1 globals the addon code may use
run('unpack = unpack or table.unpack', 'compat');
run(readFileSync(path.join(here, 'hide_casting_env.lua'), 'utf8'), 'env');
run(code, 'addon');

// option: evaluate the table entry and exercise get/set
if (optionNode) {
  const optSrc = 'return {' + text(src.options, optionNode) + '}';
  if (run(`OPT = (function() ${optSrc} end)().hideWhileCasting
    REFRESHED = 0
    function CDTL3:RefreshConfig() REFRESHED = REFRESHED + 1 end
    return nil`, 'option')) {
    run(`
      local o = OPT
      assert(o.name == "Hide while casting", "name")
      assert(o.desc == "Frames fade while you cast or channel a spell with a cast time and reappear the moment the cast ends, is interrupted or fails. Instant spells don't count. Cooldown detection keeps running. Unlock frames, Edit Mode and test mode always show the frames", "desc")
      assert(o.order == 200.6 and o.type == "toggle" and o.width == "full", "order/type/width")
      o.set(nil, true)
      assert(CDTL3.db.profile.global.hideWhileCasting == true and REFRESHED == 1, "set true")
      assert(o.get(nil) == true, "get")
      o.set(nil, false)
      assert(CDTL3.db.profile.global.hideWhileCasting == false and REFRESHED == 2, "set false")
      return nil`, 'option-check') && check(true);
  }
  // placed right below "Hide out of combat"
  const optText = src.options;
  const i1 = optText.indexOf('hideOutOfCombat = {'), i2 = optText.indexOf('hideWhileCasting = {'), i3 = optText.indexOf('autohide = {');
  check(i1 > 0 && i1 < i2 && i2 < i3, 'option should sit between hideOutOfCombat and autohide');
}

// spec
if (lauxlib.luaL_loadbuffer(L, to_luastring(readFileSync(path.join(here, 'hide_casting_spec.lua'), 'utf8')), null, to_luastring('spec')) !== lua.LUA_OK
    || lua.lua_pcall(L, 0, 1, 0) !== lua.LUA_OK) {
  check(false, 'spec: ' + lua.lua_tojsstring(L, -1));
} else {
  lua.lua_getfield(L, -1, to_luastring('pass')); pass += lua.lua_tointeger(L, -1); lua.lua_pop(L, 1);
  lua.lua_getfield(L, -1, to_luastring('fail')); const f = lua.lua_tointeger(L, -1); fail += f; lua.lua_pop(L, 1);
  lua.lua_getfield(L, -1, to_luastring('msgs'));
  for (let i = 1; i <= f; i++) { lua.lua_rawgeti(L, -1, i); msgs.push(lua.lua_tojsstring(L, -1)); lua.lua_pop(L, 1); }
}
report();

function report() {
  for (const m of msgs.slice(0, 15)) console.log('FAIL ' + m);
  if (msgs.length > 15) console.log(`... ${msgs.length - 15} more`);
  console.log(`hide_casting: ${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
}
