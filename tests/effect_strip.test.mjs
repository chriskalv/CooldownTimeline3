// Tests for the local patch Effect strip tolerates hidden geometry (2026-11-17). Static: the review
// of every geometry read in the addon's own files (README "Local patches"): a read that is added,
// moved to another file or removed turns this suite red, so the review is redone after merging a
// release. Then the real StripFor and CDTL3:EffectStripTick with the patch's helpers from Group.lua
// run in fengari on the stub world of border_secret_env.lua and effect_strip_env.lua (secret numbers
// that throw on arithmetic, setters that refuse a secret argument); scenarios in effect_strip_spec.lua.
import { readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { ADDON, readAddon, readTest, pick, runLua, report } from './lua_harness.mjs';

const res = [];
const check = (c, m) => res.push((c ? 'ok   ' : 'FAIL ') + 'static: ' + m);
const group = readAddon('Group.lua');
const cooldown = readAddon('Cooldown.lua');

// The geometry reads (secret at a frame with secret anchoring, SimpleScriptRegionAPIDocumentation.lua)
// in code, comments left out, per file, as reviewed on 2026-11-17. Group.lua's two GetWidth are the
// patch's own (private.IconWidth and the fill); everything else is listed in the review (README).
const REVIEWED = {
  'Anchors.lua': 'GetLeft 2, GetRect 1',
  'BarFrames.lua': 'GetPoint 1',
  'CDTL3.lua': 'GetCenter 1, GetSize 1, GetWidth 2',
  'CombatTimers.lua': 'GetCenter 1',
  // the release's guard private.IsMouseOver (defined and called twice) and its two reads, plus the
  // unguarded read in the ready frame, where RefreshIcon has anchored the icon to the frame again
  'Cooldown.lua': 'IsMouseOver 6',
  'FightTimeline.lua': 'GetPoint 1',
  'Group.lua': 'GetCenter 2, GetWidth 2',
  'Helpers.lua': 'GetHeight 1, GetWidth 1',
  'Holders.lua': 'GetHeight 2',
  'IconFx.lua': 'GetWidth 1',
  'Lanes.lua': 'GetCenter 4, GetPoint 1',
  'Ready.lua': 'GetPoint 1',
};
const READS = /\b(GetWidth|GetHeight|GetSize|GetLeft|GetRight|GetTop|GetBottom|GetCenter|GetRect|GetPoint|GetStringWidth|IsMouseOver)\b/g;
const files = [];
const walkDir = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) { if (name !== 'Libs') walkDir(p); }
    else if (name.endsWith('.lua')) files.push(path.relative(ADDON, p));
  }
};
walkDir(ADDON);
const found = {};
for (const f of files) {
  const code = readAddon(f).split('\n').map((l) => l.replace(/--.*$/, '')).join('\n');
  const counts = {};
  for (const m of code.matchAll(READS)) counts[m[1]] = (counts[m[1]] || 0) + 1;
  const keys = Object.keys(counts).sort();
  if (keys.length) found[f] = keys.map((k) => `${k} ${counts[k]}`).join(', ');
}
for (const f of new Set([...Object.keys(REVIEWED), ...Object.keys(found)])) {
  check(found[f] === REVIEWED[f], `${f}: geometry reads as reviewed (${found[f] || 'none'}; reviewed: ${REVIEWED[f] || 'none'})`);
}
check(/if CDTL3\.effectsLive then\n\t\tCDTL3:EffectStripTick\(f\)\n/.test(cooldown),
  'Cooldown.lua: IconUpdate calls EffectStripTick without a pcall (the guard is what keeps it from throwing)');

let chunks;
try {
  chunks = [
    ['border env', readTest('border_secret_env.lua')],
    ['env', readTest('effect_strip_env.lua')],
    ['Group.lua', `do local private = { effects = {} }\n${pick(group, ['private.ClassColor', 'private.EndEffect',
      'private.Hidden', 'private.IconWidth', 'local StripFor', 'local SetStripWidth', 'CDTL3:EffectStripTick'], 'Group.lua')}\nGROUP = private\nend`],
  ];
} catch (e) {
  check(false, e.message);
}
if (chunks) {
  try {
    res.push(...runLua([...chunks, ['spec', readTest('effect_strip_spec.lua')]]));
  } catch (e) {
    res.push('FAIL spec: ' + e.message);
  }
}
report('effect_strip', res);
