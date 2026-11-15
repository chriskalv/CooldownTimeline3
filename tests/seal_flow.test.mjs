// Seal flow on the real addon code: the cast handler (UNIT_SPELLCAST_SUCCEEDED with the local
// patch Seal switch), the aura handler, the cooldown poll with the release's private.CustomCDStart
// (which replaced the patch Seal as custom cooldown) and the whole combat timers module, run in
// fengari on the stub world of seal_flow_env.lua. Scenarios: seal_flow_spec.lua.
import { readAddon, readTest, pick, range, runLua, report } from './lua_harness.mjs';

const LKEY = 'local L = setmetatable({}, { __index = function(_, k) return k end })';
const helpers = readAddon('Helpers.lua');
const cooldown = readAddon('Cooldown.lua');
const cdtl3 = readAddon('CDTL3.lua');

let res;
try {
  const chunks = [
    ['env', readTest('seal_flow_env.lua')],
    ['Helpers.lua', `do local private = {}\n${LKEY}\n${pick(helpers, [
      'CDTL3:GetSpellCooldown', 'CDTL3:GetSpellSettings', 'CDTL3:GetCustomSpellSettings',
      'CDTL3:GetExistingCooldown', 'CDTL3:AurasAreSecret', 'CDTL3:AuraExists', 'CDTL3:GetUnitAura',
    ], 'Helpers.lua')}\nend`],
    ['Cooldown.lua', `do local private = {}\nprivate.itemNoCooldownWindow = 2\nprivate.IconUpdate = ICON_UPDATE\nprivate.BarUpdate = function() end\n${pick(cooldown, [
      'private.CustomCDStart', 'private.CooldownUpdate', 'private.ShowHide', 'CDTL3:SendToBarFrame', 'CDTL3:SendToBarHolding',
      'CDTL3:SendToHolding', 'CDTL3:SendToLane',
    ], 'Cooldown.lua')}\nCOOLDOWN_UPDATE = private.CooldownUpdate\nCUSTOM_CD_START = private.CustomCDStart\nend`],
    ['CDTL3.lua', `do local private = {}\n${LKEY}\n${pick(cdtl3, [
      'local CheckCustomSpellTrigger', 'local RestartBuffFromCast', 'local AuraKey',
      'CDTL3:OnPlayerAuraApplied', 'CDTL3:UNIT_AURA', 'CDTL3:PLAYER_REGEN_DISABLED', 'CDTL3:PLAYER_REGEN_ENABLED',
    ], 'CDTL3.lua')}\n${range(cdtl3, 'local SEAL_IDS', 'function CDTL3:UNIT_SPELLCAST_SUCCEEDED', 'CDTL3.lua')}\n${pick(cdtl3, ['CDTL3:UNIT_SPELLCAST_SUCCEEDED'], 'CDTL3.lua')}\nend`],
    ['CombatTimers.lua', readAddon('CombatTimers.lua')],
    ['spec', readTest('seal_flow_spec.lua')],
  ];
  res = runLua(chunks);
} catch (e) {
  res = ['FAIL ' + e.message];
}
report('seal_flow', res);
