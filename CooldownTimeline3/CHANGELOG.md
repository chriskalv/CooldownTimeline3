# CooldownTimeline 3

## v3.2.1

- You can take the tour again any time with `/cdtl3 tour`, and `/cdtl3 whatsnew` opens the What's new window with the changelog. Both are on the Help tab with a Run button

## v3.2.0

**Getting started**
- A What's new window pops up once after you update to 3.2.0, on every client, with a Take the tour button
- A three-step tour the first time you install it. It shows you the lane, the bars and the Ready frame with sample icons, then lets you lock everything in place or open the settings
- The Simple tab comes first: what to track, timeline width, icon size, the ready sound and a lock button
- Setups by role (Quick Style › Setup). Starter, Healer, Tank or DPS shows up on your own frames with sample icons first. Keep saves it, Undo puts your lanes back, and a setup you never kept gets undone the next time you log in
- Your own looks. Save the current look as a card, put it on everything or on one lane, bar frame or Ready frame, and share it as a string
- Help. The minimap tooltip shows if your frames are locked and if combat timers are on, and Alt-click opens a Help tab with every command
- An optional ~ in front of estimated times (Retail and WoW: Forever, Global › Mark estimated times with ~, off by default), so you can tell a time CDTL3 counts itself from one that follows the game's own timer

**Lanes and icons** (all of these are off until you turn them on, under Lanes › (a lane) › Effects or per spell in Filters)
- Charge pips on spells with charges. The icon rides the recharge until every charge is back
- Buff alerts. The lane flashes when a buff lands or drops, with a sound (in combat on Retail and WoW: Forever, this works for buffs in the Cooldown Manager's Tracked Bars)
- A burst window shaded on the lane, with an optional Ready-by list of the cooldowns that will be back for it (with ticks on Classic clients; on Retail and WoW: Forever the list shows the timers)
- A refresh zone for DoTs on Classic Era, TBC and MoP, a pulse before a cooldown comes back (Filters › Warn before ready), and GCD waits that sit in the Ready frame so they don't look like a real cooldown
- A mana gauge at the Ready end of a lane, a lane bar that changes colour at a resource number when the lane tracks Class Power or Stagger (not in combat on Retail or WoW: Forever), and Brewmaster Stagger tracking

**Boards and groups**
- A Ready frame that keeps every cooldown you pin. Tick Pinned on a spell in Filters, then set the Ready frame's Mode to Stay until used. It's lit up when ready and dimmed with the time left while it cools
- A Fight Timeline (its own tab, off until you tick Enabled). It's a strip from the pull with a line for now and flags you can move (2, 3 and 5 minutes to start), showing where each pinned cooldown will be. On Retail and WoW: Forever the end times are estimates, marked with a ~
- A Caster lane for other players' cooldowns, with each caster's name under their icon. It's fed by the combat log on MoP, TBC and Classic Era, and by CooldownCollaborator on every client (on Retail and WoW: Forever the other player needs it too, since the game hides their casts)
- Group cooldowns from CooldownCollaborator show on your lanes: yours, and those of anyone in your group who runs it. They land on Lane 1, and Filters › Defaults › Group cooldowns moves them to another lane, bar frame and Ready frame, or turns them off. On MoP, TBC and Classic Era, CDTL3's own combat log raid cooldowns step aside while CooldownCollaborator is feeding them, so nothing shows twice
- Externals you gave (Filters › Spells › Show effect on target). A strip on your cooldown icon shows who you put it on and how long it has left. Exact on Classic clients, an estimate from your cast on Retail and WoW: Forever
- Burst pack (Filters › Defaults) sets up lust and Sated where your client has them, plus your trinkets and potion, on a Burst lane, with an optional Burst strip

**Filters**
- Filters tell you why a spell or buff isn't showing. Pick an entry and a line says what's hiding it (over the Ignore Threshold, longer than the lane's Max Time, its lane is switched off, and so on) with a Show anyway button. The first time a long cooldown gets ignored on its own, you get one line in chat about it
- My spells. Filters › Spells lists your spellbook's cooldowns with tick boxes, so you can pick spells before you've ever cast them, plus Show only the ticked spells
- Hide spells I don't know and Only for this spec. Spells you've talented out of leave the lane, and a spell can be kept to one spec (Retail and MoP)
- Pull from Cooldown Manager (Retail and WoW: Forever). One button in Filters › Buffs sets up every buff in the Cooldown Manager's Tracked Bars

**Sounds and showing**
- A ready sound per spell. Each one can have its own sound, flash when it's ready, and say its name out loud where the game has text to speech (in the voice you picked in the game's text to speech settings, or the first voice installed). The Ready tab gets Mute ready sounds
- You hear a sound as you pick it. Every sound menu plays your choice once, the menus are twice as wide so you can read the long names, and a Play sound button next to each one plays it again
- Blizzard sounds. A handful of the game's own alerts and chimes (raid warning, quest complete, level up, alarm clocks, bells and more) in a Blizzard sound menu right under every sound menu. Each one is checked to exist on every client
- Show per lane, bar frame and Ready frame: Always, Only in combat or Boss fights only, with Dim instead of hide. The default follows the Global tab's Hide out of combat, same as before
- Preview with sample icons. A button at the top of the Global tab (or Shift-click the minimap button) shows sample icons until you hit Stop preview
- Placing frames. Until your first lock, the "Frames unlocked" box tells you to drag the frames and then click Lock (and that Edit Mode can place them too). Your first flight tells you the countdown is CDTL3's and where to turn it off

**Placing and profiles**
- Anchor to. A lane, bar frame or Ready frame can follow the player frame, the Cooldown Manager or any frame by name, with an offset. Only CDTL3's own frames ever move
- Share my Custom timers and spell settings with all my characters (Profiles tab, off by default), New characters start on (the Default profile, the last one you used, or one you pick), and Profiles by zone (raids, dungeons, PvP, open world)

**Sharing**
- Share strings with a preview. An import tells you what's in it first ("3 lanes, 41 spells, made on 3.1.1 Retail"), warns you about spells your client doesn't have, and can go into a new profile. Imported spells show up in your Filters right away. Each lane has Copy this lane. Older strings still import
- Masque gets a group for each timer type (spells, items, buffs and so on) and keeps your current skin
- A missing font, bar texture or sound shows "(missing)" in its menu and uses CDTL3's own instead of going silent

**For bug reports and other addons**
- `/cdtl3 report` opens a bug report ready to copy, `/cdtl3 log` shows what failed quietly, `/cdtl3 perf` shows memory and frame counts, and `/cdtl3 help` lists every command
- Update rate (Global tab) and Pause while hidden (per lane) for slower machines. Timers and Ready stay on time either way
- Other addons can listen for a timer starting, coming ready and ending, read what's tracked, and add their own timers to the lanes. See [Extending CDTL3](https://github.com/Nelnamara/cdtl3-dev/blob/main/docs/EXTENDING.md)

**Fixes**
- Setup previews always show sample icons sized to the setup you picked, every time you pick one, and they keep going until you Keep or Undo. The preview's split marks fit inside its lanes too
- A lane no longer draws a split mark past its Max Time
- Importing a "Settings only" string as "All settings and data" no longer empties your Filters lists, and a damaged string gets refused before it can change anything
- Clearing a spell's settings, Reset Profile and Copy From now ask first when other characters on the profile use them, instead of quietly wiping them
- Cooldowns on a switched-off lane no longer lose their bar for the last 2 minutes
- An early reset (Cold Snap, Preparation, Readiness) now shows the Ready icon along with the sound, and a switched-off Ready frame doesn't play one
- Ready › Highlight Duration and Pinned Hide Time now do what they say
- The "Frames unlocked" box follows the lock when you switch profiles, and its Lock button always locks
- Custom › Add New: Enabled can be unticked, and a mistyped Trigger ID gets refused (Retail and WoW: Forever)
- In combat on Retail and WoW: Forever, the GCD marker shows, a Tracked Bars buff no longer jumps to Ready after Alt+Z, and a new trinket or potion no longer shows a frozen 16:40 bar
- Lanes: Secondary Tracking shows as soon as you turn it on, the secondary marker on vertical lanes moves along the lane, lane texts with live tags update, Override Autohide brings back an empty lane, every lane and bar frame comes back at the pull with Hide out of combat, and Split Count takes whole numbers
- Edit Mode sliders reach the same sizes as the options window. Lane width now goes to 1000 and bar width to 600 in both
- Grouped stacking does a lot less work and looks the same, and a lone icon in a short stack stays in the lane
- TBC Anniversary: flights that don't start from the flight map no longer count down under internal names
- Undo on a setup preview puts a buff you gained, or a spell you cast, during the preview back on its own lane, instead of leaving it on the preview's lane until a reload
- Bar frames: the little transition line stays inside its bar and only shows on a bar that will hand off to its lane. It used to sit way out to the right, over other frames, when the lane held more time than the whole cooldown
- Test mode no longer lists test cooldowns twice
- WoW: Forever: Haunt is gone from the built-in Warlock list, since Blizzard removed it from the class
- Classic clients read buffs and the combat log through Blizzard's current names, ahead of the old ones going away

## v3.1.1

**Flight timers (every client, on by default)**
- **A countdown to landing on every flight path** — take a flight and an icon named for where you're going counts down on lane 1 and bar frame 1, then goes to ready frame 1 with the ready sound as you land. It stays in view for the whole flight, past the lane's Max Time and with *Hide out of combat* on
- **Exact after one flight** — a route you have flown on any character counts down from your last real time. A route you haven't flown counts down from an estimate built from the game's route data, in dimmed text. If the countdown runs out first, the icon waits at the end of the lane until you land
- **Flights that don't start from the flight map** — the druids' flights out of Moonglade and quest flights started from a chat option get a countdown too: from the first flight when only one route leaves that spot, otherwise from the second
- **Picks up after a `/reload` or a logout** in mid-air
- **Settings** — the Global tab's *Flight timers* section turns them off, picks the lane, bar frame and ready frame, and forgets learned flight times

## v3.1.0

**Combat timers (Retail and WoW: Forever, experimental, on by default)**
- **Cooldowns keep moving in combat** — in combat the game hides cooldown timings from addons, so CDTL3 used to estimate them from your cast and the spell's base cooldown: talent and haste reductions were missed and icons could reach ready late. Spell icons now slide, bars drain and countdown text counts from the game's own timer, at the real length, and an icon goes to ready when the spell does
- **Exact buff timers in combat, for buffs in Tracked Bars** — add a buff to *Tracked Bars* in Blizzard's Cooldown Manager (`/cdm`) and CDTL3 follows Blizzard's own timer for it in combat: refreshes, buffs gained mid-fight and buffs that drop off all show at once. Split (Time) lanes keep their shape for these buffs. Every other buff still uses the estimate, now shown in dimmed text while it is one. In Filters, each buff says whether it gets the exact timer
- **Settings** — the Global tab has *Combat timers (experimental)* to turn this off and *Hide Blizzard's Tracked Bars* to make Blizzard's own bars invisible while they keep feeding CDTL3. `/cdtl3 combattimers` prints what's running; `/cdtl3 combattimers off` and `on` switch it. A window on the first login after updating explains this
- **Limits in combat** — item cooldowns keep the estimate (the game gives addons no timer for them); Grouped stacking leaves moving icons out, so they can overlap until combat ends; an icon text with more than the `[cd.time]` tag keeps the estimate. Spells with charges are the least tested part: please report anything odd

**Lanes**
- **Max Time and the Split (Time) values go up to an hour on the slider** — the Max Time slider stopped at 180 and the split values at 360, while a larger typed number was saved out of sight. Both sliders now reach every value they can hold, and Filters' *Ignore Threshold* slider reaches 7200
- **Long buffs scale** — a button next to the lane's Mode sets the lane up for 10 and 60 minute buffs: Split (Time) over an hour, with a quarter of the lane each for the last 30 seconds, 30 seconds to 2 minutes and 2 to 10 minutes

**Fixes**
- **Bar frames: unticking *Transition bars* brings hidden bars back** — a bar the option had hidden stayed hidden until a `/reload`, so unticking it looked like it did nothing
- **Unticking *Ignored* on a buff that's up shows it at once** — it used to wait for the buff to be applied again

## v3.0.13

**WoW: Forever**
- **Spell list updated for Forever's November changes** — Elemental Mastery is now **Lightning Mastery**, Totemic Projection is now **Totemic Call** with a 30-second cooldown, Lava Burst is gone from Shaman, and **Swift Judgement** is a normal cooldown again (it no longer waits for its effect to end). Checked against Forever's current game data, hotfixes included
- **Buffs you recast in combat restart** (Forever and Retail) — while the game hides buff details in combat, a recast went unseen and the icon kept counting down the old buff until combat ended. Recasting a buff you track now restarts it from its last known length. It's an estimate that corrects itself when combat ends; a buff whose length varies (Slice and Dice) or one refreshed by someone else still only updates then

**Fixes**
- **Custom CD Time works on spells without a cooldown** — with a Custom CD Time on a spell the game gives no cooldown (a Paladin seal on Forever, to time its 30 seconds), the icon vanished after the global cooldown, or at once in combat. It now counts the custom time from your last cast
- **Custom timers with trigger type Spell fire for spells you know** — they only fired for spells outside your spellbook, so a timer couldn't be tied to a seal or any other spell you have. They now fire for any spell you cast

## v3.0.12

**WoW: Forever launch**
- **Forever gets its own spell data** — Forever reads the Classic Era spell list, but its spells differ. The list is now corrected from Forever's own game data: spells and ranks Forever doesn't have are dropped, renamed spells use their Forever names, and cooldowns match Forever (Lay on Hands is 20 minutes). Forever's new **Swift Judgement** now starts its cooldown when used, and **Elemental Mastery**, which no longer does on Forever, is treated as a normal cooldown
- **Pet abilities and ranked spells count down in combat** (Forever and Retail) — while the game hides cooldown timings, pet abilities, and spells cast at a higher rank than the one CDTL3 first saw, kept resetting to just under their full cooldown. Their casts are now timed properly
- **"Cooldown starts when used" spells count from when the effect ends** (Forever and Retail, while timings are hidden) — a Stealth opener or a held Nature's Swiftness no longer shows ready early

**Fixes**
- **MoP Classic and Retail: "cooldown starts when used" spells work** — Nature's Swiftness, Presence of Mind, Stealth, Prowl, Feign Death, Misdirection, Tricks of the Trade and the rest went straight to "ready" because these clients had no spell list. They now have one, checked against each client's game data
- **Retail: no longer listed as out of date** — the retail TOC now declares 12.1.5
- **Items are no longer hidden by mistake** — an item could be saved as Ignored when its cooldown stayed hidden from addons until it ran out (Forever, Retail), or after a ready item was moved to another lane or the Ignore Threshold slider was dragged. If an item vanished that way, untick *Ignored* on it under Filters
- **Moving cooldowns keeps their timers** — the Ignore Threshold slider and the Filters lane picker no longer restart running timers or set off a burst of ready sounds
- **Filters bulk controls change only this character's entries** — the Ignore Threshold slider, *Set All*, *Clear Settings* and *Clear Quest Items* also changed other characters' entries, which the list doesn't show. Clearing an entry another character also uses now only removes it for you
- **Retail: options that need the combat log are hidden** — Blizzard closed the combat log to addons in 12.0, so enemy debuffs, melee swing timers and spell-school colors are hidden as on Forever
- **Spell School Color no longer greys out bars where the combat log is closed** — a profile imported with it on painted every bar grey with no visible way to turn it off
- **Minimap button: right-click toggles lock and unlock** — it could only lock
- **Spell list upkeep** — Classic Era Season of Discovery rune cooldowns corrected and a spell ID that doesn't exist removed; the Wrath Death Knight list no longer loads on MoP Classic and Retail, where its IDs and names are wrong

## v3.0.11

**Fixes**
- **Nature's Swiftness and the other "cooldown starts when used" spells now work on Classic Era, TBC Anniversary and WoW: Forever** — the 3.0.10 fix finds these spells in the addon's built-in spell lists, but those lists were only ever loaded on Cataclysm-and-newer clients, which have no lists of their own. On Classic Era, TBC Anniversary and Forever the fix had nothing to read, so Nature's Swiftness still went straight to "ready". The lists now load on every client
- **Shaman Nature's Swiftness** was missing from the Classic Era spell list, and Classic Era **Cold Blood** wasn't marked as starting its cooldown when used; both corrected, checked against the Classic Era game data
- **New `/cdtl3 oaf`** — prints the built-in spell list, every saved "cooldown starts when used" spell and the live state of any such cooldown, for troubleshooting

## v3.0.10

**New**
- **Hide out of combat** — Global tab toggle: every lane, bar frame and ready frame fades while you're out of combat and appears the moment a pull starts. Cooldown detection keeps running the whole time, so a cooldown started on the last pull is still tracked and shown on the next one. Unlock frames, Edit Mode and test mode always show the frames

**Fixes**
- **Nature's Swiftness (and other "cooldown starts when used" spells) now show their cooldown** — spells whose cooldown only begins once their effect is used up (Nature's Swiftness, Presence of Mind, Divine Favor, Combustion, Prowl, Feign Death and others) went straight to "ready" when cast and never showed the real cooldown once it started. The addon's special handling for these spells was only ever applied to Stealth and Shadowmeld; it now applies to every spell in its list, including ones you've already saved

## v3.0.9

**Minimap button**
- **Can now be hidden** — Global tab → *Minimap button*, or `/cdtl3 minimap` (account-wide). For anyone decluttering the new Forever minimap
- **Rides the rim of any minimap size** — the orbit radius was fixed for the old small minimap, leaving the button floating inside the larger Forever minimap; it now follows the minimap's live size and re-anchors when the minimap is resized or rescaled

## v3.0.8

**New**
- **Edit Mode support** (LibEditMode) — lanes, bar frames and ready frames appear in Edit Mode with quick size sliders and a shortcut to their full settings; positions are saved per Edit Mode layout and follow layout switches. Classic Era keeps `/cdtl3 unlock`
- **Quick Style** — one-click looks for every lane, bar frame and ready frame: CDTL3 Classic, Minimal, Blizzard Modern, Class Colours. Minimal and Modern also make icon highlighting visible (the shipped highlight border is "None")
- **Copy settings** — each lane, bar frame and ready frame can copy every setting from another (name, position and enabled state are kept)
- **Per-spell bar colors** — Filters → any entry → *Own Bar Color*; wins over school, class and frame colors
- **Spell School Color actually works** — schools were never recorded and had no pickers, so every bar was grey. They're now learned from your casts (combat log) with a picker per school under Colors; hidden where the combat log is closed
- **Modern Blizzard bar textures** — unit-frame health/power bars (including grey, tintable versions) and cast bars, offered only where the client has them
- **Per-spec profiles** (LibDualSpec) — Profiles → *Enable spec profiles*

**Audit and restructure** — the code was audited end to end (it has passed through three maintainers) and the duplicated parts consolidated:
- Import now really applies (it replaced the profile table AceDB doesn't save) and validates the string before touching anything
- Filters fixes: Set All, Clear Individual Settings and Save Custom; items matched by item name; time inputs validated; Ignore Threshold applied once
- Power text tags work for every class; "highlighted" tags read the right setting; class color pickers update live; lanes 2/3 got the time-format default lane 1 had
- Every newly discovered spell, item, buff, rune and custom is built by one set of helpers (13 copies had drifted apart — e.g. the Ignore Threshold was inclusive in some and not others)
- Lanes, bar frames and ready frames are each declared once in the defaults (about 1,150 duplicated lines removed); border options are generated from one function
- Unit events are registered for you and your pet only, so raids no longer wake the addon for every member
- Options that depend on the combat log (enemy debuffs, melee swing, school colors) say so or hide where it's closed
- Dead code removed throughout

**WoW: Forever and compatibility**
- **World of Warcraft: Forever support** — Forever reports a vanilla-era interface number (`16001`) but runs the modern Midnight-era API, so the old version check sent it down the Classic code paths and called functions Forever doesn't have (`GetSpellInfo`, `GetSpellCooldown`, `UnitAura`, the old spellbook API). CDTL3 now detects Forever by its interface number and uses the retail API paths while keeping the vanilla-era spell data. Ships a `_Camelot` TOC (the Forever client doesn't fall back to `_Mainline`) plus a plain `CooldownTimeline3.toc` fallback
- **Combat log registration can't break detection** — it's only registered where the client provides it, and a refusal no longer aborts registering the other cooldown events. The combat log is closed to addons on Forever
- **Updated the bundled Ace3 libraries to r1403** — the old copy called globals newer clients removed (`SetDesaturation`) and passed a boolean as tooltip alpha, which errored in the options window on Forever and will on WoW 12.1.5
- **Item/spellbook lookups ready for 12.1.5** — `GetItemSpell`/`GetItemInfoInstant` (removed in 12.1.5) and `IsSpellKnown`/`IsSpellKnownOrOverridesKnown` (deprecation-only since 11.2) now go through wrappers that use `C_Item`/`C_SpellBook` when the old globals are gone; the action-button glow highlight falls back to the border highlight where the glow API is missing
- **Buff/debuff detection without the combat log** — buffs and debuffs on you (and custom aura triggers) were only discovered through the combat log, which Forever closes to addons, so e.g. Mark of the Wild never appeared under Buffs. They're now also picked up from `UNIT_AURA`: newly added auras, recasts of a buff you already have (an aura *update*), and buffs already on you at login, `/reload` or zoning (a *full* update). Auras that are secret (in combat, encounters, M+, PvP) are skipped. Debuffs you apply to enemies and the swing timer still need the combat log
- **Secret-value hardening for lanes, items and auras** — on Forever (and Midnight while restricted) player health/power, attack speed, item cooldowns and even the `UNIT_AURA` payload can be secret. Lane HEALTH / CLASS_POWER / COMBO_POINTS tracking now feeds secret values straight to the status bar (which accepts them) instead of dividing them; swing timers show a full bar, the mana/energy tick estimate pauses, item cooldowns keep counting down from their last readable value, and text tags show `?` when a value is secret
- **Fixed detected buffs/debuffs missing from the Filters list** — a buff seen at login, before the character was known, was saved without an owner and never listed for anyone (Mark of the Wild showed `yours=false` in `/cdtl3 auras`). Saved entries are now claimed for your character whenever the aura is seen again, and the login scan waits until the character is known
- **Fixed the debug frame's Options button** — it still used `Settings.OpenToCategory("CDTL3")`, which errors on Midnight and Forever; it now opens the CDTL3 window like `/cdtl3`
- **New `/cdtl3 auras`** — prints every buff/debuff on you as CDTL3 sees it (or that it's hidden/secret), whether it's saved, ignored and assigned to you, plus whether aura events are arriving — for troubleshooting buff detection
- **Fixed an options error in Filters** — with `<< Select >>` (no entry) chosen in a Filters list, the Custom CD Time fields looked up settings that don't exist and errored (`Options.lua: attempt to index local 's'`); they now stay hidden until a real entry is selected
- **Fixed buffs/debuffs recording spell ID 0 on Classic clients** — a typo in the Classic aura reader dropped the spell ID
- TOCs bumped: MoP Classic `50504`, TBC Anniversary `20506`, Classic Era `11509`
