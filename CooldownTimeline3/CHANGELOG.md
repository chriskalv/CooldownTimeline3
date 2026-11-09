# CooldownTimeline 3

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
