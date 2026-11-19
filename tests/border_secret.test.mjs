// Regression tests for the release's border fix (CDTL3 3.2.2; until the personal build 3.2.1.1 the
// local patch Border frames tolerate hidden geometry did this) and the version of the personal build.
// Static: every backdrop in the addon is set through CDTL3:SetBorder, the icon border and highlight
// use it, nothing clears a backdrop and no frame given to SetBorder gets an OnUpdate script of its own
// (the fix's retry would replace it), and the version is the same in all TOC files, CDTL3.version and
// tools/release.mjs (a personal build's fourth part with LOCAL PATCH comments, a plain release
// version without them, see README "Versions"). Then the real CDTL3:SetBorder and its helpers from
// Helpers.lua run in fengari on the stub world of border_secret_env.lua (frames with anchors, secret
// numbers that throw on arithmetic, a backdrop mixin that computes with the size like Blizzard's);
// scenarios in border_secret_spec.lua. Last, the real CDTL3:LastSeenOlderThan with the version.
import { readdirSync, statSync } from 'node:fs';
import path from 'node:path';
import { ADDON, readAddon, readTest, pick, runLua, report } from './lua_harness.mjs';
import { readVersion } from '../tools/release.mjs';

const res = [];
const check = (c, m) => res.push((c ? 'ok   ' : 'FAIL ') + 'static: ' + m);
const helpers = readAddon('Helpers.lua');
const cooldown = readAddon('Cooldown.lua');
const cdtl3 = readAddon('CDTL3.lua');

// every SetBackdrop call in the addon's own files (libraries left out) is the one in CDTL3:SetBorder
const files = [];
const walkDir = (dir) => {
  for (const name of readdirSync(dir)) {
    const p = path.join(dir, name);
    if (statSync(p).isDirectory()) { if (name !== 'Libs') walkDir(p); }
    else if (name.endsWith('.lua')) files.push(path.relative(ADDON, p));
  }
};
walkDir(ADDON);
const backdropCalls = files.flatMap((f) => (readAddon(f).match(/:SetBackdrop\(/g) || []).map(() => f));
check(backdropCalls.length === 1 && backdropCalls[0] === 'Helpers.lua', `SetBackdrop only in Helpers.lua (${backdropCalls.join(', ')})`);
let setBorder = '';
try { setBorder = pick(helpers, ['CDTL3:SetBorder'], 'Helpers.lua'); } catch (e) { check(false, e.message); }
check(setBorder.includes('f:SetBackdrop(b)'), 'the SetBackdrop call is in CDTL3:SetBorder');
check(/f\.SetupTextureCoordinates = private\.BorderTexCoords\n[^]*f:SetBackdrop\(b\)/.test(setBorder),
  'SetBorder routes the texture coordinates through the guard before it sets the backdrop');
check(!/LOCAL PATCH/.test(setBorder), 'CDTL3:SetBorder is the release\'s again (no local patch left in it)');
// the two cases the local patch also guarded and the release's retry does not (a cleared backdrop, an
// OnUpdate script of the frame's own) cannot happen in the addon: nothing clears a backdrop, and the
// frames given to SetBorder (f.bd, f.mf.bd, f.hl and the welcome window's local border) get no script
const clears = files.filter((f) => /ClearBackdrop|SetBackdrop\(\s*nil/.test(readAddon(f)));
check(clears.length === 0, `no backdrop is cleared (${clears.join(', ')})`);
const targets = files.flatMap((f) => [...readAddon(f).matchAll(/CDTL3:SetBorder\(([^,]+),/g)].map((m) => m[1].trim()));
check(targets.length >= 8 && targets.every((t) => ['f', 'f.bd', 'f.mf.bd', 'f.hl', 'border'].includes(t)),
  `SetBorder is given only f.bd, f.mf.bd, f.hl or a local border (${[...new Set(targets)].join(', ')})`);
const scripted = files.filter((f) => /(\.bd|\.hl|\bborder):(SetScript|HookScript)\(\s*"OnUpdate"/.test(readAddon(f)));
check(scripted.length === 0, `no border frame gets an OnUpdate script of its own (${scripted.join(', ')})`);
check(cooldown.includes('CDTL3:SetBorder(f.bd, s["icons"]["border"])') && cooldown.includes('CDTL3:SetBorder(f.hl, s["icons"]["highlight"]["border"])'),
  'Cooldown.lua: icon border and highlight are set through CDTL3:SetBorder');

// the version: the same in all six TOC files and CDTL3.version. A personal build has four parts and
// LOCAL PATCH comments at every version line; a release's own version (three parts, after merging
// upstream) has none (README "Versions"), so the next release does not turn this suite red.
const tocs = readdirSync(ADDON).filter((n) => n.endsWith('.toc')).sort();
check(tocs.length === 6, `six TOC files (${tocs.join(', ')})`);
const tocInfo = tocs.map((t) => {
  const lines = readAddon(t).split('\n').map((l) => l.replace(/\r$/, ''));
  const vs = lines.filter((l) => /^##\s*Version\s*:/.test(l));
  const i = lines.findIndex((l) => /^##\s*Version\s*:/.test(l));
  check(vs.length === 1, `${t}: one ## Version: line`);
  check(!lines.some((l) => /^\s+#/.test(l)), `${t}: no comment with whitespace before the # (the client would take it for a file name)`);
  return { t, v: (vs[0] || '').replace(/^##\s*Version\s*:\s*/, '').trim(),
    commented: i > 0 && /^# LOCAL PATCH \(Zippy, \d{4}-\d{2}-\d{2}\): /.test(lines[i - 1]) };
});
const versions = tocInfo.map((x) => x.v);
const version = versions[0] || '';
const luaVersion = (/\r?\nCDTL3\.version = "([^"]*)"\r?\n/.exec(cdtl3) || [])[1];
const luaCommented = /-- LOCAL PATCH \(Zippy, \d{4}-\d{2}-\d{2}\)[^\n]*\n(--[^\n]*\n)*CDTL3\.version = /.test(cdtl3.replace(/\r/g, ''));
const personal = /^\d+\.\d+\.\d+\.\d+$/.test(version);
check(personal || /^\d+\.\d+(\.\d+)?$/.test(version), `the version is a release version or a personal build with a fourth part (${version})`);
check(versions.every((v) => v === version), `the same version in every TOC (${versions.join(', ')})`);
check(luaVersion === version, `CDTL3.version equals the TOC version (${luaVersion})`);
for (const x of tocInfo) {
  check(x.commented === personal, personal ? `${x.t}: the line before the version is a "# LOCAL PATCH" comment`
    : `${x.t}: no LOCAL PATCH comment left at the release's version line`);
}
check(luaCommented === personal, personal ? 'CDTL3.version carries a LOCAL PATCH comment' : 'no LOCAL PATCH comment left at the release\'s CDTL3.version');
const base = personal ? version.split('.').slice(0, 3).join('.') : version;
const nextRelease = base.split('.').map((n, i, a) => (i === a.length - 1 ? String(Number(n) + 1) : n)).join('.');
let built = '';
try { built = readVersion(ADDON); } catch (e) { built = e.message; }
check(built === versions[0], `tools/release.mjs reads the same version (${built})`);

let chunks;
try {
  chunks = [
    ['env', readTest('border_secret_env.lua')],
    ['Helpers.lua', `do local private = {}\n${pick(helpers, ['private.AnchoringHidden', 'private.SizeHidden',
      'private.RetileWhenPlain', 'private.BorderTexCoords', 'CDTL3:SetBorder'], 'Helpers.lua')}\nHELPERS = private\nend`],
  ];
} catch (e) {
  check(false, e.message);
}
if (chunks) {
  try {
    res.push(...runLua([...chunks, ['spec', readTest('border_secret_spec.lua')]]));
  } catch (e) {
    res.push('FAIL spec: ' + e.message);
  }
}

// the welcome window's version rule with the current version (four parts for a personal build) (CDTL3:LastSeenOlderThan, the release's)
try {
  res.push(...runLua([
    ['CDTL3.lua', `CDTL3 = { db = { profile = { global = {} } } }\n${pick(cdtl3, ['CDTL3.version', 'CDTL3.noticeVersion', 'CDTL3:LastSeenOlderThan'], 'CDTL3.lua')}`],
    ['spec', `
local function check(c, m) RESULTS[#RESULTS + 1] = (c and "ok   " or "FAIL ") .. "version rule: " .. m end
local function seen(v) CDTL3.db.profile.global.previousVersion = v end
seen(CDTL3.version)
check(not CDTL3:LastSeenOlderThan(CDTL3.noticeVersion) and not CDTL3:LastSeenOlderThan("3.1"), "the personal build counts as seen for the notice and the 3.1 block")
check(not CDTL3:LastSeenOlderThan(CDTL3.version), "the own version is not older than itself")
${personal ? `seen("${base}")
check(CDTL3:LastSeenOlderThan(CDTL3.version), "the release ${base} is older than the personal build")
seen(CDTL3.version)
check(not CDTL3:LastSeenOlderThan("${base}"), "the personal build is not older than its release ${base}")` : ''}
seen(CDTL3.version)
check(CDTL3:LastSeenOlderThan("${nextRelease}"), "the next release ${nextRelease} is newer than ${version}")
`],
  ]));
} catch (e) {
  res.push('FAIL version rule: ' + e.message);
}
report('border_secret', res);
