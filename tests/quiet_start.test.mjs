// Tests for the two quiet-start patches of 2026-11-16: Flight timers off by default and no
// automatic What's new. Static checks on the luaparse trees (the default, every call of the welcome
// window across the addon), then scenarios in fengari on the real LibStub, CallbackHandler and
// AceDB-3.0 with the release's defaults, the whole Flights.lua, Start.lua's first-install tour and
// CDTL3.lua's OnEnable, /cdtl3 and welcome window. Stub world: quiet_start_env.lua, scenarios:
// quiet_start_spec.lua (one fresh Lua state each).
import { readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { ADDON, luaparse, readAddon, readTest, pick, range, runLua, report } from './lua_harness.mjs';

const LKEY = 'local L = setmetatable({}, { __index = function(_, k) return k end })';
const res = [];
const check = (c, m) => res.push((c ? 'ok   ' : 'FAIL ') + 'static: ' + m);

const cdtl3 = readAddon('CDTL3.lua');
const start = readAddon('Start.lua');

function walk(node, fn, parents = []) {
  if (!node || typeof node !== 'object') return;
  fn(node, parents);
  const next = [...parents, node];
  for (const v of Object.values(node)) {
    if (Array.isArray(v)) v.forEach((c) => walk(c, fn, next));
    else if (v && typeof v === 'object' && v.type) walk(v, fn, next);
  }
}

// the flights defaults: enabled = false next to the lane, bar frame and ready frame defaults
let flightsDefault = null;
walk(luaparse.parse(cdtl3, { luaVersion: '5.1' }), (n) => {
  if (n.type === 'TableKeyString' && n.key.name === 'flights' && n.value.type === 'TableConstructorExpression') {
    const keys = Object.fromEntries(n.value.fields.filter((f) => f.type === 'TableKeyString').map((f) => [f.key.name, f.value]));
    if (keys.defaultLane) flightsDefault = keys;
  }
});
check(flightsDefault && flightsDefault.enabled && flightsDefault.enabled.type === 'BooleanLiteral'
  && flightsDefault.enabled.value === false, 'defaults: flights.enabled = false');

// every call of the welcome window in the addon's own files (libraries left out): the window is
// made only by CDTL3:ShowWhatsNew, which only /cdtl3 whatsnew calls
const files = [];
const walkDir = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) { if (name !== 'Libs') walkDir(p); }
    else if (name.endsWith('.lua')) files.push(p);
  }
};
walkDir(ADDON);
const calls = { CreateFirstRunFrame: [], ShowWhatsNew: [] };
const fnName = (f) => {
  const id = f.identifier;
  if (!id) return '(anonymous)';
  if (id.type === 'MemberExpression') return `${id.base.name}${id.indexer}${id.identifier.name}`;
  return id.name;
};
for (const p of files) {
  const rel = path.relative(ADDON, p);
  const ast = luaparse.parse(readAddon(rel), { luaVersion: '5.1' });
  walk(ast, (n, parents) => {
    if (n.type !== 'CallExpression' && n.type !== 'StringCallExpression' && n.type !== 'TableCallExpression') return;
    const b = n.base;
    const name = b.type === 'MemberExpression' ? b.identifier.name : b.type === 'Identifier' ? b.name : null;
    if (!calls[name]) return;
    // the outermost named function the call sits in, or an assignment like private.X = function
    let where = '(main chunk)';
    for (const q of parents) {
      if (q.type === 'FunctionDeclaration' && q.identifier) { where = fnName(q); break; }
      if (q.type === 'AssignmentStatement' && q.variables[0].type === 'MemberExpression') {
        const v = q.variables[0]; where = `${v.base.name}.${v.identifier.name}`; break;
      }
    }
    calls[name].push(`${rel}:${where}`);
  });
}
check(calls.CreateFirstRunFrame.length === 1 && calls.CreateFirstRunFrame[0] === 'CDTL3.lua:CDTL3:ShowWhatsNew',
  `the welcome window is made only in CDTL3:ShowWhatsNew (${calls.CreateFirstRunFrame.join(', ')})`);
check(calls.ShowWhatsNew.length === 1 && calls.ShowWhatsNew[0] === 'CDTL3.lua:CDTL3:ChatCommand',
  `CDTL3:ShowWhatsNew is called only by /cdtl3 (${calls.ShowWhatsNew.join(', ')})`);

// the login still starts the first-install tour and nothing else on a timer of its own
const onEnable = pick(cdtl3, ['CDTL3:OnEnable'], 'CDTL3.lua');
check(onEnable.includes('CDTL3.Start:StartTour()'), 'OnEnable still starts the tour');

const SCENARIOS = ['flight_fresh', 'flight_saved', 'flight_resume', 'login_fresh_install', 'login_new_profile',
  'login_old_version', 'login_both', 'whatsnew'];
let chunks;
try {
  chunks = [
    ['env', readTest('quiet_start_env.lua')],
    ['LibStub', readAddon('Libs/LibStub/LibStub.lua')],
    ['CallbackHandler', readAddon('Libs/CallbackHandler-1.0/CallbackHandler-1.0.lua')],
    ['AceDB', readAddon('Libs/AceDB-3.0/AceDB-3.0.lua')],
    ['locale', 'LoadLocaleStub()'],
    ['defaults', `do ${LKEY}\n${pick(cdtl3, ['local WithOverrides', 'local HIGHLIGHT', 'local ICON_TEXT', 'local MODE_TEXT',
      'local ShowAnim', 'local HideAnim', 'local FRAME_BACK', 'local laneDefaults', 'local barFrameDefaults',
      'local readyDefaults', 'local NO_MODE_TEXT', 'local defaults'], 'CDTL3.lua')}\nDEFAULTS = defaults\nend`],
    ['Flights.lua', readAddon('Flights.lua')],
    ['Start.lua', `do local S = CDTL3.Start\nlocal private = { TourSteps = function() return {} end }\n${LKEY}\n${range(start,
      '-- Players who already have CDTL3 keep the welcome window', 'function S:TourDue()', 'Start.lua')}\n${pick(start,
      ['S:TourDue', 'S:StartTour'], 'Start.lua')}\nend`],
    ['CDTL3.lua', `do local private = { CreateUnlockFrame = function() end, CreateDebugFrame = function() end }\n${LKEY}\n${pick(cdtl3, [
      'CDTL3.version', 'CDTL3.noticeVersion', 'CDTL3.supportlink', 'CDTL3:OnEnable', 'CDTL3:ChatCommand',
      'CDTL3:ShowWhatsNew', 'private.CreateFirstRunFrame', 'CDTL3:LastSeenOlderThan', 'CDTL3:IsNewerVersion',
    ], 'CDTL3.lua')}\n${range(cdtl3, "-- The samples at the top of the What's new window", 'private.CreateFirstRunFrame = function', 'CDTL3.lua')}\nend`],
  ];
} catch (e) {
  check(false, e.message);
}
if (chunks) {
  for (const s of SCENARIOS) {
    try {
      res.push(...runLua([...chunks, ['scenario', `SCENARIO = ${JSON.stringify(s)}`], ['spec', readTest('quiet_start_spec.lua')]]));
    } catch (e) {
      res.push(`FAIL ${s}: ${e.message}`);
    }
  }
}
report('quiet_start', res);
