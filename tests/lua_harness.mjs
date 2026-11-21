// Shared helpers for the simulations: read the real addon files, cut named top-level statements
// out of them (luaparse, Lua 5.1) and run chunks in fengari. Nothing here writes to the addon.
import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
export const here = path.dirname(fileURLToPath(import.meta.url));
export const root = path.join(here, '..');
const NM = path.join(root, 'node_modules');
export const luaparse = require(NM + '/luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require(NM + '/fengari');

export const ADDON = path.join(root, 'CooldownTimeline3');

// an addon file, line endings as LF
export function readAddon(file) {
  return readFileSync(path.join(ADDON, file), 'utf8').replace(/\r\n/g, '\n');
}

export function readTest(file) {
  return readFileSync(path.join(here, file), 'utf8');
}

// the name of a top-level statement: "CDTL3:Name", "local Name", "private.Name" or null
function statementName(st) {
  if (st.type === 'FunctionDeclaration' && st.identifier) {
    const id = st.identifier;
    if (id.type === 'MemberExpression') return `${id.base.name}${id.indexer}${id.identifier.name}`;
    return (st.isLocal ? 'local ' : '') + id.name;
  }
  if (st.type === 'AssignmentStatement' && st.variables.length === 1) {
    const v = st.variables[0];
    if (v.type === 'MemberExpression' && v.base.type === 'Identifier') return `${v.base.name}.${v.identifier.name}`;
  }
  if (st.type === 'LocalStatement' && st.variables.length === 1) return 'local ' + st.variables[0].name;
  return null;
}

// The source of the named top-level statements of src, in the order given. Throws if a name is
// missing or found twice, so a test fails when the addon code moves or changes shape.
export function pick(src, names, what = 'source') {
  const ast = luaparse.parse(src, { luaVersion: '5.1', ranges: true });
  const found = new Map();
  for (const st of ast.body) {
    const n = statementName(st);
    if (n && names.includes(n)) {
      if (found.has(n)) throw new Error(`${what}: ${n} found twice`);
      found.set(n, src.slice(st.range[0], st.range[1]));
    }
  }
  return names.map((n) => {
    if (!found.has(n)) throw new Error(`${what}: ${n} not found`);
    return found.get(n);
  }).join('\n\n');
}

// src from the line holding `from` up to (not including) the line holding `to`
export function range(src, from, to, what = 'source') {
  const a = src.indexOf(from);
  const b = src.indexOf(to, a + 1);
  if (a < 0 || b < 0) throw new Error(`${what}: range ${JSON.stringify(from)} .. ${JSON.stringify(to)} not found`);
  return src.slice(src.lastIndexOf('\n', a) + 1, src.lastIndexOf('\n', b) + 1);
}

// Runs [name, source] chunks in one fresh state and returns the strings of the global RESULTS
// table. A chunk that fails to load or run throws with its name.
export function runLua(chunks) {
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const all = [['compat', 'unpack = unpack or table.unpack\nRESULTS = {}'], ...chunks];
  for (const [name, src] of all) {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring(name)) !== lua.LUA_OK
        || lua.lua_pcall(L, 0, 0, 0) !== lua.LUA_OK) {
      throw new Error(name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    }
  }
  lua.lua_getglobal(L, to_luastring('RESULTS'));
  const res = [];
  const n = lua.lua_rawlen(L, -1);
  for (let i = 1; i <= n; i++) {
    lua.lua_rawgeti(L, -1, i);
    res.push(to_jsstring(lua.lua_tostring(L, -1)));
    lua.lua_pop(L, 1);
  }
  return res;
}

// Prints the failures (all lines with -v) and sets the exit code; returns the number of failures.
export function report(label, res) {
  const fails = res.filter((r) => r.startsWith('FAIL'));
  for (const r of (process.argv.includes('-v') ? res : fails.slice(0, 25))) console.log(r);
  if (!process.argv.includes('-v') && fails.length > 25) console.log(`... ${fails.length - 25} more`);
  console.log(`${label}: ${res.length - fails.length} passed, ${fails.length} failed`);
  if (fails.length || res.length === 0) process.exitCode = 1;
  return fails.length;
}

// CDTL3.lua's slot table and its lookups (CDTL3:SlotSettings, SlotFrame, SlotOfParent, SlotParent;
// since 3.3.0 the lane, bar frame and ready frame code finds its frames through them)
export function slots(cdtl3) {
  return range(cdtl3, '-- Lane, bar frame and ready frame 1 to 3 by number', 'CDTL3.version = ', 'CDTL3.lua');
}
