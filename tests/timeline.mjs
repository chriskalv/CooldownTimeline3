// Timeline harness: extracts the real addon code (read-only), optionally applies an
// in-memory mutation, runs env + addon code + matrix + spec in fengari.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const require = createRequire(import.meta.url);
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const NM = path.join(root, 'node_modules');
const luaparse = require(NM + '/luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(NM + '/fengari');

const ADDON = path.join(root, 'CooldownTimeline3') + path.sep;
const HERE = here + path.sep;

export function extract(srcs) {
  const out = [];
  const pick = (src, names) => {
    const ast = luaparse.parse(src, { luaVersion: '5.1', ranges: true });
    for (const st of ast.body) {
      if (st.type === 'FunctionDeclaration' && st.identifier && st.identifier.type === 'MemberExpression') {
        const n = st.identifier.identifier.name;
        if (names.includes(n)) out.push(src.slice(st.range[0], st.range[1]));
      }
    }
  };
  const c = srcs.cdtl3;
  const a = c.indexOf('local function ReadPlayerCasting');
  const b = c.indexOf('function CDTL3:PLAYER_REGEN_DISABLED');
  if (a < 0 || b < 0) throw new Error('cast block not found');
  const ue0 = c.indexOf('CDTL3.unitEventFrame = CreateFrame');
  const ue1 = c.indexOf('end)', ue0) + 4;
  out.push(c.slice(ue0, ue1));
  pick(c, ['RegisterUnitEvents', 'TurnOn', 'TurnOff', 'PLAYER_REGEN_DISABLED', 'PLAYER_REGEN_ENABLED']);
  pick(srcs.helpers, ['Autohide', 'ApplyCombatVisibility']);
  // cast block holds locals: keep it in one chunk together with the rest
  return c.slice(a, b) + '\n' + out.join('\n');
}

export function load() {
  return {
    cdtl3: readFileSync(ADDON + 'CDTL3.lua', 'utf8'),
    helpers: readFileSync(ADDON + 'Helpers.lua', 'utf8'),
  };
}

export function runLua(code) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const chunks = [
    ['env', readFileSync(HERE + 'timeline_env.lua', 'utf8')],
  ];
  const all = [...chunks, ['addon', code], ['matrix', readFileSync(HERE + 'timeline_matrix.lua', 'utf8').replace(/^/, 'RESULTS = {}\n')],
    ['spec_prefix', 'local M = RESULTS'], ['spec', readFileSync(HERE + 'timeline_spec.lua', 'utf8').replace('RESULTS = {}', 'RESULTS = RESULTS or {}')]];
  // env must define unitEventFrame before addon code runs: addon chunk creates it
  for (const [name, src] of all) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring(name)) !== 0 || lua.lua_pcall(L, 0, 0, 0) !== 0) {
      throw new Error(name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    }
  }
  lua.lua_getglobal(L, to_luastring('RESULTS'));
  const res = [];
  const n = lua.lua_rawlen(L, -1);
  for (let i = 1; i <= n; i++) { lua.lua_rawgeti(L, -1, i); res.push(to_jsstring(lua.lua_tostring(L, -1))); lua.lua_pop(L, 1); }
  return res;
}

if (process.argv[1] && process.argv[1].endsWith('timeline.mjs')) {
  const res = runLua(extract(load()));
  const fails = res.filter((r) => r.startsWith('FAIL'));
  const verbose = process.argv.includes('-v');
  for (const r of (verbose ? res : fails)) console.log(r);
  console.log(`timeline: ${res.length - fails.length} passed, ${fails.length} failed`);
  process.exitCode = fails.length ? 1 : 0;
}
