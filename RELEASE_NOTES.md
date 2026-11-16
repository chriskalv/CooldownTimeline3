Personal build of CDTL3 3.2.1 for WoW Forever: the released addon plus four local patches.

- **Seal switch** – casting a seal from the spellbook ends the other seals' timers (spell and buff) straight into the holding area, in any client language. A late proc of the old seal ends nothing and brings nothing back.
- **Hide while casting** – Global option, off by default: lanes, bar frames and ready frames fade while you cast or channel and come back when the cast ends, is interrupted or fails. It works on top of each frame's new *Show* setting, *Always* included, and dims frames set to *Dim instead of hide*.
- **Flight timers off by default** – the flight countdown no longer starts unless you switch it on: `/cdtl3`, *Global* tab, *Flight timers*. A profile that never touched the switch is off after this update; once switched on it stays on.
- **No automatic What's new** – the welcome and What's new window no longer opens by itself after an update or on a new profile. `/cdtl3 whatsnew` (or *Run* on the *Help* tab) still opens it; its question about the next login no longer does anything. A first install still gets the short tour.

The local patch *Seal as custom cooldown* is gone: CDTL3 does this itself since 3.0.13, with the same setting under *Filters > Spells* (untick *Ignored*, *Custom CD* 30, tick *Custom CD*).

Install the folder `CooldownTimeline3` from the zip into `Interface\AddOns`, or update through WoWUp.
