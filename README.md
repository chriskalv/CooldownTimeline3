# CooldownTimeline3 (personal build)

Zippy's personal build of **CDTL3 (CooldownTimeline3)** for WoW Forever: the released addon plus a few local patches. CDTL3 is by Nelnamara (with Vreenak and cliffclive before), CurseForge project 1570576, source `Nelnamara/cdtl3-dev`, and is *All Rights Reserved*. This repository is therefore private and only for Zippy's own installation; nothing from it is published.

## Layout

- `CooldownTimeline3/`: the addon folder. Copy it to `World of Warcraft\_forever_\Interface\AddOns\CooldownTimeline3\` (replace the files there).
- `tests/`: simulations of the patched code in Node with fengari (Lua in JavaScript); not part of the addon.
- `tools/fetch_release.mjs`: downloads a CDTL3 release zip from CurseForge (see below).
- `tools/release.mjs`, `RELEASE_NOTES.md`, `.github/workflows/release.yml`: the GitHub release for WoWUp (see below).
- Branch `upstream`: the unmodified CDTL3 releases, one commit per release. `main` is `upstream` plus the local patches.

| | |
|---|---|
| Upstream release | 3.2.1 |
| Personal build | 3.2.1.1 |
| Local patches | 5 |

## Local patches

Every changed place in the addon folder carries a comment `LOCAL PATCH (Zippy, <date>)`. Outside these places the addon folder is the release byte for byte.

1. **Seal switch** (`CDTL3.lua`, before and in `UNIT_SPELLCAST_SUCCEEDED`). Casting a seal from the spellbook ends the running timers of the other seals, their spell timers (a Custom CD Time) and their buff timers, straight to the holding area (no ready frame, no sound; other addons get `CDTL3_TimerEnded`). Seals are recognized in any client language: the client names the seven seals of WoW Forever (Seal of Fury included), and for spell timers their common start ("Seal of ", "Siegel de") also finds seals not in the list; buff timers end only under these names, so no other buff that starts like a seal is touched. A late proc of the old seal (its own spell ID, not in the spellbook) ends nothing and restarts no buff timer, so seal twisting is safe and an ended seal doesn't come back. Casting the old seal again restarts its timer.
2. **Hide while casting** (`CDTL3.lua`, `Helpers.lua`, `Options.lua`, `Locales/enUS.lua`). New option in the *Global* tab under *Hide out of combat*, off by default: while the player casts or channels a spell with a cast time, lanes, bar frames and ready frames fade, and they come back when the cast ends, is interrupted or fails. It lies over each frame's *Show* setting (*Use the global setting*, *Always*, *Only in combat*, *Boss fights only*): a frame that would show is hidden while casting, *Always* included. A frame with *Dim instead of hide* dims instead (the toggle can be ticked on an *Always* frame while the option is on). The release's exceptions apply as for *Show*: test mode and the preview, unlocked frames and Edit Mode, debug mode, and a flight timer in progress keep the frames showing. Includes two fixes in the fade handling that also help *Hide out of combat* and *Show*: a fade-in still running is stopped when frames must hide, and a fade-out started by the rule is stopped when the rule no longer applies.

3. **Flight timers off by default** (`CDTL3.lua`, profile defaults). The release's flight timers (a countdown to landing on every flight path) are now off unless switched on: *Global* tab > *Flight timers*. Only the default changed; the switch, the countdown and the learned flight times work as in the release. AceDB saves only values that differ from the default, so every profile that never touched the switch follows the new default and is off after the update; once switched on, it stays on across reloads and logins. A profile saved with the switch off stays off.
4. **No automatic What's new** (`CDTL3.lua`, `OnEnable`). The welcome and What's new window no longer opens by itself, neither after an update nor on a profile's first run. `/cdtl3 whatsnew` (or its *Run* button on the *Help* tab) still opens it on demand, with the release's text unchanged. So the window's question *Show this message next login/reload?* no longer means anything: *Yes* only closes it, and the window does not come back on login or reload. A first install (no saved variables) still gets the release's three-step tour ten seconds after login. `firstRun` and `previousVersion` are not touched by the patch; the window's buttons still set them.
5. **Border frames tolerate hidden geometry** (`Helpers.lua`, `CDTL3:SetBorder`). Fixes an error of the release: since 3.1.0 an icon that rides a combat timer hangs on the fill of a StatusBar fed with the game's hidden timer (`CombatTimers.lua`, `private.PlaceIcon`). Anchors pass the secrecy on, so the icon's border and highlight frames report a secret width and height (`GetWidth`/`GetHeight` are `SecretWhenAnchoringSecret`), and Blizzard's `BackdropTemplateMixin:SetupTextureCoordinates` throws when it divides them (`Backdrop.lua:226: attempt to perform arithmetic on local 'width' (a secret number value)`, from `OnSizeChanged` and from `SetBackdrop`). `CDTL3:SetBorder`, through which every backdrop of the addon is set, now gives the frame its own `SetupTextureCoordinates`: while `issecretvalue` says the width or height is secret it leaves the texture coordinates as they are and waits; they are worked out again on the next size change or, at the latest, on the first frame (a one-off `OnUpdate`) in which the size can be read again, so the border is right again after combat. Any other error still goes through, and a frame with a readable size is worked out exactly as in the release. On a client without `issecretvalue` nothing changes.

### Dropped patches

- **Seal as custom cooldown** (3.0.12 build): since 3.0.13 the release counts a Custom CD Time on a spell without a cooldown from the last cast (`private.CustomCDStart` in `Cooldown.lua`). The setting stays the same: *Filters > Spells > Seal of Command*: untick *Ignored*, *Custom CD* 30, tick *Custom CD*; the same for other seals. In WoW Forever Judgement does not consume the seal (Wowhead Forever, spell 20271), so a seal lasts exactly its 30 s unless recast.

## Installation through the addon manager

The addon is installed through WoWUp from the GitHub releases of this repository (`chriskalv/CooldownTimeline3`); the CurseForge copy is replaced by it. WoWUp reads the `release.json` in the BigWigs packager format next to the zip `CooldownTimeline3-<version>-forever.zip`; both are the assets of each release.

Releases come from the GitHub Actions workflow *Release* (`.github/workflows/release.yml`, started by hand under *Actions > Release > Run workflow* on `main`, or through the GitHub API). Inputs: `version` (must equal `## Version:` in `CooldownTimeline3/CooldownTimeline3.toc`) and `dry_run`. The workflow checks the version against the TOC and the existing tags, runs `npm ci` and `npm test`, builds both assets with `npm run release`, checks the zip (one root folder `CooldownTimeline3/`) and the `release.json` (version, file name, interface number from the TOC), takes the notes from `RELEASE_NOTES.md` (it stops when the file doesn't name the version) and keeps assets and notes as a workflow artifact. Without `dry_run` it then creates the tag `v<version>` on the tested commit and the release "CDTL3 <version> (Zippy build)" with both assets. Before a release, update `RELEASE_NOTES.md`; run the workflow with `dry_run` first.

By hand, the same release is:

```
npm run release
gh release create v<version> dist/CooldownTimeline3-<version>-forever.zip dist/release.json \
  --title "CDTL3 <version> (Zippy build)" --notes-file RELEASE_NOTES.md
```

WoWUp then offers the release for the Forever installation.

## Versions

The personal build carries the release's version plus a fourth part: `3.2.1.1` is the first personal build on the release 3.2.1, the next one between the same releases would be `3.2.1.2`. The version stands in `## Version:` of all six TOC files and in `CDTL3.version` (`CDTL3.lua`), each with a `LOCAL PATCH` comment (in the TOC files a line `# ...` directly above, which the client reads as a comment); the release workflow takes the version from `CooldownTimeline3.toc`, and the tag is `v<version>`. With a new CDTL3 release its own version lines apply again (merging `upstream` brings them back; drop the fourth part and its comments), and a later personal build on it counts from `.1` again. The tests and mutation probes follow this rule instead of a fixed version: they ask for the same version everywhere, with `LOCAL PATCH` comments exactly when it has a fourth part, so `npm test` stays green after the merge with the release's version lines. CDTL3 compares versions part by part with any number of parts (`CDTL3:LastSeenOlderThan`), so `3.2.1.1` counts as newer than 3.2.1 and older than 3.2.2.

## Updating to a new CDTL3 release

1. Get the release zip: `npm run fetch` downloads the newest release to `dist/` and prints its SHA-256 (`npm run fetch -- --list` shows all releases, `-- --version 3.0.11` picks one, `-- --unpack` also unpacks it to `dist/<version>/`). The CurseForge project page refuses automated requests, so the script reads the file list from the widget API `api.cfwidget.com/1570576` and loads the file from the CDN `edge.forgecdn.net`; behind an HTTPS proxy it restarts itself with `NODE_USE_ENV_PROXY=1`. On branch `upstream`, replace `CooldownTimeline3/` with the folder from the zip and commit it as "CDTL3 <version> as released", citing the SHA-256; one commit per release.
2. Merge `upstream` into `main`. Conflicts can only come up at the `LOCAL PATCH` places. At the version lines (six TOC files and `CDTL3.version` in `CDTL3.lua`) take the release's version and drop the fourth part and its `LOCAL PATCH` comments (see *Versions*). Read the release's `CooldownTimeline3/CHANGELOG.md`; if the release does what a local patch does, drop that patch.
3. `npm install`, then `npm test` and `npm run mutations`. The simulations read the real addon code, so they fail if a patched or tested function moved or changed.
4. Update `RELEASE_NOTES.md` and this README, run the *Release* workflow (dry run, then the real run), update through WoWUp (or copy `CooldownTimeline3/` into the game) and `/reload`.

## Tests

```
npm install
npm test
npm run mutations
```

`npm test` runs:

- `tests/fetch_release.test.mjs`: file choice and CDN URL of the fetch script, offline.
- `tests/seal_patches.test.mjs`: the helpers of *Seal switch* (seal names in English and German, which timers end, buffs only under the listed seal names, holding, `CDTL3_TimerEnded`), and that the release's `private.CustomCDStart` replaced *Seal as custom cooldown*.
- `tests/seal_flow.test.mjs`: the real cast handler, aura handler, cooldown poll and combat timers on a simulated client with hidden values in combat. Seal of Command with Custom CD 30 counts 30 s from the own cast, after the GCD and in combat, and a recast restarts it. A seal switch, in and out of combat, with combat timers on and off and with the seals' buffs tracked or not, ends the old seal without Ready, and nothing brings it back (a late proc, the cooldown poll, the combat timers, aura events, the end of combat); cast again, it restarts.
- `tests/hide_casting.test.mjs`: every Lua file of the addon parses as Lua 5.1; default, option and its locale keys (through the real AceLocale, a missing key gives no error); the cast state from the cast events; and the visibility rule over Show mode, *Dim instead of hide*, *Hide out of combat*, *Hide while casting*, combat, boss fight, casting and every exception.
- `tests/quiet_start.test.mjs`: *Flight timers off by default* and *No automatic What's new* on the real AceDB-3.0 (defaults, saved variables, logout cleanup), the whole `Flights.lua`, the release's first-install tour from `Start.lua` and `CDTL3.lua`'s login, `/cdtl3` and welcome window. A fresh profile has flight timers off and a flight starts no timer, nor resumes after a reload; switched on with `FL:SetEnabled(true)` a flight counts down and the value survives logout and login; profiles saved by the release follow the new default unless they saved a value. A login with `firstRun`, with a version older than the release's notice version or both opens no window, also after every timer ran; `/cdtl3 whatsnew` opens it; the tour of a first install starts as in the release. Statically: the default, and that only `/cdtl3 whatsnew` (through `CDTL3:ShowWhatsNew`; the *Run* button on the *Help* tab sends the same command) makes the window.
- `tests/border_secret.test.mjs`: *Border frames tolerate hidden geometry* on the real `CDTL3:SetBorder` and its helpers, with a stub engine whose anchors pass secrecy on (an icon riding a StatusBar fill), secret numbers that throw on arithmetic and a backdrop mixin that computes with the size like Blizzard's. Without the guard the riding icon's border throws (control); with it, neither `OnSizeChanged` nor `SetBorder` throws for the border or the highlight, the coordinates stay as they were while hidden and are right again from the current size after combat, through `OnSizeChanged` or the one-off retry, which then ends; an ordinary border is worked out as in the release; an error that has nothing to do with a hidden size still throws; a cleared border and another `OnUpdate` script are left alone; a client without `issecretvalue` keeps Blizzard's function. Statically: every `SetBackdrop` of the addon is the one in `CDTL3:SetBorder`, and the icon border and highlight use it. The version: the same in all six TOC files, in `CDTL3.version` and as read by `tools/release.mjs`; a personal build (four parts) has a `# LOCAL PATCH` comment line above every TOC version line and a comment at `CDTL3.version`, a release version has none; `CDTL3:LastSeenOlderThan` counts the personal build as newer than its release and older than the next one (both derived from the version).
- `tests/timeline.mjs`: *Hide while casting* over time with the 0.3 s fade animations: casts, interrupts, chained casts, the Show modes, dim, flights, the fade times, and that an Auto-hide fade-out after an early interrupt runs once.

`npm run mutations` breaks the five patches, the version (and the release's `private.CustomCDStart`) in 67 ways on disk (the version probes are derived from the current version) and expects every break to turn a test red; it restores the addon files with git afterwards.
