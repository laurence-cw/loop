---
version: 1
slug: "strandios-loop-settings-loopsettingsview-swift"
primary_target: "StrandiOS/Loop/Settings/LoopSettingsView.swift"
related_targets: []
---

# Loop Settings

Scope: Settings, Advanced and About (StrandiOS/Loop/Settings), reached from a gear on Home. Visitor mode: Operate. This extends the established Loop world (DESIGN.md), so the world is inherited and there was no concept roll.

Audience and job: a boy (or his parent) changing something about once a month: his name, his date of birth, wake times, the bedtime reminder. The parent occasionally fixes something in Advanced.

Content follows the approved inventory (docs/loop/screen-inventory.md):
- **Settings** (must fit one screen without scrolling):
  - You: first name and date of birth.
  - Wake up: wake-up buzz, school-day time, weekend time, bedtime reminder, plus a footer showing the next buzz.
  - Strap: name, connection and battery.
  - Links to Advanced and About.
- **Advanced** (may scroll):
  - Find my strap.
  - Restart strap, only on a connected 5.0, as Noop gates it.
  - The WHOOP 5.0 switch (Noop's Protocol probes, which arms the 5.0 alarm).
  - Export or restore a backup.
  - Share the strap log.
  - Re-learn your normal.
  - Days until the app needs refreshing.
- **About**: the single "scores are estimates" note, Noop credits, licence and version.

Data: everything is written through Noop's own stores and calls:
- BehaviorStore for the alarm.
- WindDownNudge for the wake time and the per-day weekend override.
- `AppModel.applySmartAlarm` re-arms the strap after any change.
- ProfileStore for date of birth.
- DataBackup for backups.
- `Baselines.recalibrateRecoveryBaselines` for re-learning your normal.
- Loop's own `loop.firstName` for the name.

The next-buzz footer uses the same `AppModel.nextSmartAlarmDate` the strap is armed from, plus Noop's 5.0 gate, so the screen cannot disagree with the strap.

Advanced also has Disconnect, Rename strap (only on a connected 4.0, as Noop gates it), Steps calibration (Noop's sheet), Storage (Noop's screen), and spreadsheet (CSV) export.

Deferred: editing a night or adding a nap (inventory decision 5). Noop's editor is private to its Sleep screen, so Loop needs its own. It is a follow-up on the Sleep screen, not Settings.

Demo-data note: the simulator's date of birth (1 Oct 1996) comes from Noop's demo seeder, which Loop doesn't own. It isn't changed for screenshots; the owner sets each boy's real date on his phone.

Owner rules:
- Light type.
- No reliability caveats.
- Cut warnings and nudges: there are no battery or inactivity alerts.

## Direction contract

THESIS: Settings is a short, calm checklist in the platform's own grammar, never a developer console. It refuses Noop's thirty-card settings wall.

OWN-WORLD: inherited, translated into iOS grouped lists. Night ground; rows on Surface; system Toggles and compact DatePickers in dark appearance; Charged tint on switches; plain section headers and footers in Muted. Advanced and About use the same list grammar. No cards inside cards, no custom controls.

STORY: he opens it from the gear, sees his name and wake times, flips the buzz on, and sees exactly when the next buzz is.

FIRST VIEWPORT: the system back button with an inline "Settings" title, then You, Wake up (with its footer), Strap, and the Advanced/About links. All of it is visible on an iPhone 17 without scrolling.

FORM: an extension of the established world; no seed key. Motion: system only.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
