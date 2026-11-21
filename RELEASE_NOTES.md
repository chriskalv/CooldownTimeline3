CDTL3 3.3.0: personal build on the CDTL3 release 3.3.0 for WoW Forever, the released addon plus five local patches.

New from the release, in one sentence: eight highlight effects with an Effect speed slider (Glow is now drawn by CDTL3 itself), a Finish effect per lane, Split lanes with up to five marks, a *Show and hide* tab for every lane, Ready frame and bar frame (Fade or Scale, length, plays, Bounce), Boss fights only through the game's current encounter call, and about 2,000 lines of copied code gone.

- **Seal switch** – casting a seal from the spellbook ends the other seals' timers (spell and buff) straight into the holding area, in any client language. A late proc of the old seal ends nothing and brings nothing back.
- **Hide while casting** – Global option, off by default: lanes, bar frames and ready frames fade while you cast or channel and come back when the cast ends, is interrupted or fails. It works on top of each frame's *Show* setting, *Always* included, and dims frames set to *Dim instead of hide*. With the new *Show and hide* tab the frames hide and come back with their own animation (Fade or Scale, any length, plays and Bounce); a cast that ends during the hide animation stops it, so no frame stays hidden or flickers.
- **Flight timers off by default** – the flight countdown no longer starts unless you switch it on: `/cdtl3`, *Global* tab, *Flight timers*. A profile that never touched the switch is off; once switched on it stays on.
- **No automatic What's new** – CDTL3 3.3.0 opens its new What's new window (with live samples of the effects) once for everyone after the update; this build doesn't, neither after an update nor on a new profile. `/cdtl3 whatsnew` (or *Run* on the *Help* tab) opens it, samples included; its question about the next login does nothing. A first install still gets the short tour.
- **Effect strip tolerates hidden geometry** – the effect strip (*Show effect on target*) on an icon that follows a combat timer no longer throws and breaks off that icon's update, but takes its width from the lane's icon size. CDTL3 3.3.0 leaves this place unchanged, so the patch stays. The new highlight and Finish effects read no frame sizes (they are sized from the settings), so they need no patch.

No patch was dropped this time: the release does none of the five itself.

Install the folder `CooldownTimeline3` from the zip into `Interface\AddOns`, or update through WoWUp.
