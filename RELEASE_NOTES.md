Personal build of CDTL3 3.2.1 for WoW Forever: the released addon plus two local patches.

- **Seal switch** – casting a seal from the spellbook ends the other seals' timers (spell and buff) straight into the holding area, in any client language. A late proc of the old seal ends nothing and brings nothing back.
- **Hide while casting** – Global option, off by default: lanes, bar frames and ready frames fade while you cast or channel and come back when the cast ends, is interrupted or fails. It works on top of each frame's new *Show* setting, *Always* included, and dims frames set to *Dim instead of hide*.

The local patch *Seal as custom cooldown* is gone: CDTL3 does this itself since 3.0.13, with the same setting under *Filters > Spells* (untick *Ignored*, *Custom CD* 30, tick *Custom CD*).

Install the folder `CooldownTimeline3` from the zip into `Interface\AddOns`, or update through WoWUp.
