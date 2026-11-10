# CooldownTimeline3 (personal build)

Zippy's personal build of **CDTL3 (CooldownTimeline3)** for WoW Forever: the released addon plus a few local patches. CDTL3 is by Nelnamara (with Vreenak and cliffclive before), CurseForge project 1570576, source `Nelnamara/cdtl3-dev`, and is *All Rights Reserved*. This repository is therefore private and only for Zippy's own installation; nothing from it is published.

## Layout

- `CooldownTimeline3/`: the addon folder. Copy it to `World of Warcraft\_forever_\Interface\AddOns\CooldownTimeline3\` (replace the files there).
- `tests/`: simulations of the patched code in Node with fengari (Lua in JavaScript); not part of the addon.
- `tools/fetch_release.mjs`: downloads a CDTL3 release zip from CurseForge (see below).
- Branch `upstream`: the unmodified CDTL3 releases, one commit per release. `main` is `upstream` plus the local patches.

| | |
|---|---|
| Upstream release | 3.0.12 |
| Local patches | 3 |

## Local patches

Every changed place in the addon folder carries a comment `LOCAL PATCH (Zippy, <date>)`.

1. **Seal as custom cooldown** (`Cooldown.lua`, spell update). A custom CD was added to the start the game reports for the spell's cooldown; a spell without a cooldown of its own (a Paladin seal) reports 0 once the GCD is over, and at once in combat, so its icon vanished. Now the custom time counts from the player's own cast in that case. In WoW Forever Judgement does not consume the seal (Wowhead Forever, spell 20271), so a seal lasts exactly its 30 s unless recast. Use: *Filters > Spells > Seal of Command*: untick *Ignored*, *Custom CD* 30, tick *Custom CD*; the same for other seals. Requested from the author as a feature on 2026-11-08.
2. **Seal switch** (`CDTL3.lua`, before and in `UNIT_SPELLCAST_SUCCEEDED`). Casting a seal from the spellbook ends the running timers of the other seals, straight to the holding area (no ready frame, no sound). Seals are recognized in any client language: the client names six known seals, and their common start ("Seal of ", "Siegel de") also finds seals not in the list. A late proc of the old seal (its own spell ID, not in the spellbook) ends nothing, so seal twisting is safe.
3. **Hide while casting** (`CDTL3.lua`, `Helpers.lua`, `Options.lua`). New option in the *Global* tab under *Hide out of combat*, off by default: frames fade while the player casts or channels a spell with a cast time and come back when the cast ends, is interrupted or fails. Includes two fixes in the fade handling that also help *Hide out of combat*: a fade-in still running is stopped when frames must hide, and a fade-out started by the rule is stopped when the rule no longer applies. Lanes and bar frames are refreshed by their number.

## Installation through the addon manager

The addon is installed through WoWUp from the GitHub releases of this repository (`chriskalv/CooldownTimeline3`); the CurseForge copy is replaced by it. WoWUp reads the `release.json` in the BigWigs packager format that `npm run release` next to the zip writes, together with the zip `CooldownTimeline3-<version>-forever.zip`.

```
npm run release
gh release create v<version> dist/CooldownTimeline3-<version>-forever.zip dist/release.json \
  --title "CDTL3 <version> (Zippy build)" --notes "<changes>"
```

`gh` uploads both assets; WoWUp then offers the release for the Forever installation.

## Updating to a new CDTL3 release

1. Get the release zip: `npm run fetch` downloads the newest release to `dist/` and prints its SHA-256 (`npm run fetch -- --list` shows all releases, `-- --version 3.0.11` picks one, `-- --unpack` also unpacks it to `dist/<version>/`). The CurseForge project page refuses automated requests, so the script reads the file list from the widget API `api.cfwidget.com/1570576` and loads the file from the CDN `edge.forgecdn.net`; behind an HTTPS proxy it restarts itself with `NODE_USE_ENV_PROXY=1`. On branch `upstream`, replace `CooldownTimeline3/` with the folder from the zip and commit it as "CDTL3 <version> as released", citing the SHA-256.
2. Merge `upstream` into `main`. Conflicts can only come up at the `LOCAL PATCH` places. If the release fixes something a local patch does, drop that patch.
3. `npm install`, then `npm test` (and `npm run mutations` after changes to a patch). The simulations read the real addon code, so they fail if a patched function moved or changed.
4. `npm run release`, publish the release as above, update through WoWUp (or copy `CooldownTimeline3/` into the game) and `/reload`.

## Tests

```
npm install
npm test
npm run mutations
```

`npm test` runs `tests/fetch_release.test.mjs` (file choice and CDN URL of the fetch script, offline), `tests/seal_patches.test.mjs` (patches 1 and 2), `tests/hide_casting.test.mjs` (patch 3: option, events, cast state, the visibility rule) and `tests/timeline.mjs` (patch 3 with 0.3 s fade animations over time). `npm run mutations` breaks patch 3 in a few ways on disk and expects every break to turn a test red; it restores the addon files with git afterwards.
