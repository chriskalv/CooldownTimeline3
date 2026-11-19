CDTL3 3.2.2: personal build on the CDTL3 release 3.2.2 for WoW Forever, the released addon plus five local patches.

- **Seal switch** – casting a seal from the spellbook ends the other seals' timers (spell and buff) straight into the holding area, in any client language. A late proc of the old seal ends nothing and brings nothing back.
- **Hide while casting** – Global option, off by default: lanes, bar frames and ready frames fade while you cast or channel and come back when the cast ends, is interrupted or fails. It works on top of each frame's new *Show* setting, *Always* included, and dims frames set to *Dim instead of hide*.
- **Flight timers off by default** – the flight countdown no longer starts unless you switch it on: `/cdtl3`, *Global* tab, *Flight timers*. A profile that never touched the switch is off after this update; once switched on it stays on.
- **No automatic What's new** – the welcome and What's new window no longer opens by itself after an update or on a new profile. `/cdtl3 whatsnew` (or *Run* on the *Help* tab) still opens it; its question about the next login no longer does anything. A first install still gets the short tour.
- **Effect strip tolerates hidden geometry** – the effect strip (*Show effect on target*) on an icon that follows a combat timer no longer throws and breaks off that icon's update, but takes its width from the lane's icon size. CDTL3 3.2.2 leaves this place unchanged, so the patch stays.

The local patch *Border frames tolerate hidden geometry* is gone: CDTL3 fixes the `secret number value` error of icon borders and highlights in combat itself since 3.2.2, in every case that can happen in the addon. New from the release: the *Border Texture* and *Warn before ready (seconds)* labels are no longer cut off in the settings.

Install the folder `CooldownTimeline3` from the zip into `Interface\AddOns`, or update through WoWUp.
