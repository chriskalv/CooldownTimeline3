// Mutation probes: each mutates an addon file on disk, runs the suite (must fail), then
// restores the file with git checkout and checks the tree is clean again.
import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const M = [
  ['option ignored', 'Helpers.lua', 'or (gl["hideWhileCasting"] and CDTL3.casting)', 'or (false and CDTL3.casting)'],
  ['cast state ignored', 'Helpers.lua', 'or (gl["hideWhileCasting"] and CDTL3.casting)', 'or (gl["hideWhileCasting"])'],
  ['unlockFrames exception missing', 'Helpers.lua', '\t\t\tand not gl["unlockFrames"] and not gl["debugMode"] then', '\t\t\tand not gl["debugMode"] then'],
  ['ApplyCombatVisibility returns on hideWhileCasting', 'Helpers.lua', 'if not gl["hideOutOfCombat"] and not gl["hideWhileCasting"] then return end', 'if not gl["hideOutOfCombat"] then return end'],
  ['second read missing', 'CDTL3.lua', '\t\tC_Timer.After(0, RecheckCasting)', '\t\t-- no recheck'],
  ['INTERRUPTED not registered', 'CDTL3.lua', '\t"UNIT_SPELLCAST_INTERRUPTED",\r\n', ''],
  ['START does not force casting', 'CDTL3.lua', 'local casting = (started and true) or ReadPlayerCasting()', 'local casting = ReadPlayerCasting()'],
  ['read without pcall', 'CDTL3.lua', 'local ok, name = pcall(UnitCastingInfo, "player")', 'local ok, name = true, UnitCastingInfo("player")'],
  ['TurnOn does not seed the state', 'CDTL3.lua', '\tCDTL3:UpdateCastingState()\r\nend', '\t-- no seed\r\nend'],
  ['TurnOn seeds without applying', 'CDTL3.lua', '\tCDTL3:UpdateCastingState()\r\nend', '\tCDTL3.casting = ReadPlayerCasting()\r\nend'],
  ['no unit filter on START', 'CDTL3.lua', 'if unit ~= "player" then return end\t-- plain', 'if false then return end\t-- plain'],
  ['EMPOWER registered without pcall', 'CDTL3.lua', 'pcall(CDTL3.RegisterUnitEvents, CDTL3, event, "player")', 'CDTL3:RegisterUnitEvents(event, "player")'],
  ['TurnOff keeps a stale state', 'CDTL3.lua', '\t\tCDTL3.casting = false\r\n\t\tCDTL3:ApplyCombatVisibility()\r\n\tend\r\nend', '\tend\r\nend'],
  ['TurnOff clears without applying', 'CDTL3.lua', '\t\tCDTL3.casting = false\r\n\t\tCDTL3:ApplyCombatVisibility()\r\n\tend\r\nend', '\t\tCDTL3.casting = false\r\n\tend\r\nend'],
  ['stop events read at once (chain flash)', 'CDTL3.lua', '\tif C_Timer and C_Timer.After then\r\n\t\tC_Timer.After(0, RecheckCasting)', '\tCDTL3:UpdateCastingState()\r\n\tif C_Timer and C_Timer.After then\r\n\t\tC_Timer.After(0, RecheckCasting)'],
  ['hide rule does not stop a running fade-in', 'Helpers.lua', '\t\t\tf.animateIn:Stop()', '\t\t\t-- no stop'],
  ['visible path does not stop the hide fade-out', 'Helpers.lua', '\t\t\tf.animateOut:Stop()', '\t\t\t-- no stop'],
  ['hide fade-out not marked', 'Helpers.lua', '\t\t\t\t\tf.cdtl3HideFade = true', '\t\t\t\t\t-- unmarked'],
  ['ApplyCombatVisibility by list index', 'Helpers.lua', 'CDTL3:RefreshLane(f.number)\r\n\tend\r\n\tfor _, f in pairs(CDTL3.barFrames) do\r\n\t\tCDTL3:RefreshBarFrame(f.number)', 'CDTL3:RefreshLane(_)\r\n\tend\r\n\tfor _, f in pairs(CDTL3.barFrames) do\r\n\t\tCDTL3:RefreshBarFrame(_)'],
  ['default missing', 'CDTL3.lua', '\t\t\thideWhileCasting = false,\r\n', ''],
  ['option order wrong', 'Options.lua', 'order = 200.6,', 'order = 202,'],
];
let red = 0;
for (const [name, file, from, to] of M) {
  const p = path.join(root, 'CooldownTimeline3', file);
  const orig = readFileSync(p, 'utf8');
  const n = orig.split(from).length - 1;
  if (n !== 1) { console.log(`SETUP ${name}: ${n} matches`); process.exitCode = 1; continue; }
  writeFileSync(p, orig.replace(from, to));
  const r1 = spawnSync(process.execPath, [path.join(here, 'hide_casting.test.mjs')], { encoding: 'utf8' });
  const r2 = spawnSync(process.execPath, [path.join(here, 'timeline.mjs')], { encoding: 'utf8' });
  const r = { status: r1.status || r2.status, stdout: r1.stdout + r2.stdout + r2.stderr };
  execFileSync('git', ['-C', root, 'checkout', '--', path.join('CooldownTimeline3', file)]);
  const last = [r1.stdout, r2.stdout].map((o) => o.trim().split('\n').pop()).join(' / ');
  const first = (r.stdout.split('\n').find((l) => l.startsWith('FAIL')) || '').slice(0, 110);
  const isRed = r.status !== 0;
  if (isRed) red++;
  console.log(`${isRed ? 'RED  ' : 'GREEN'} ${name}: ${last} | ${first}`);
}
const st = execFileSync('git', ['-C', root, 'status', '--porcelain', '--', 'CooldownTimeline3']).toString();
console.log(`${red}/${M.length} red; addon tree ${st ? 'DIRTY' : 'clean'}`);
if (red !== M.length || st) process.exitCode = 1;
