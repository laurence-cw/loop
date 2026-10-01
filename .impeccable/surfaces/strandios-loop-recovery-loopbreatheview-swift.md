---
version: 1
slug: "strandios-loop-recovery-loopbreatheview-swift"
primary_target: "StrandiOS/Loop/Recovery/LoopBreatheView.swift"
related_targets: []
---

# Loop Breathe

Scope: the breathing exercise (StrandiOS/Loop/Recovery/LoopBreatheView.swift). It is offered as a card on Recovery on Low days and as a quiet "Breathe" row at the foot of Recovery on any day. Visitor mode: Operate. It extends the established Loop world (DESIGN.md), so there is no concept roll.

Audience and job: a boy on a low day, two minutes, with his eyes optionally closed.

Brand book requirements:
- Recovery's strap buzz is the breathing exercise on low days.
- The orb breathes very slowly; during the breathing exercise it paces the breath instead.
- Glow is for in-between moments: onboarding, still learning, breathing.

Data and actions:
- Pace is Noop's own: `BiofeedbackPrefs.lockedPace`, else `ResonanceEngine.fallbackBpm` (5.5 per minute), with the inhale at 40% and the exhale at 60% (`BreathPacer.defaultInhaleFraction`), as in Noop's `resonanceStages()`. A session is a whole number of breaths, about two minutes.
- The buzz goes through Noop's own gated `AppModel.buzz(loops:gate: HapticPrefs.breathing)`, with loops from `BreathProtocolPlayer` (1 in, 2 out).
- Stopping calls Noop's own `stopHaptics()`, as Noop's BreathingView does.
- The "Strap buzz" switch is Noop's own `haptics.breathing` setting, which lived in the cut Automations screen. Loop writes it on the first visit so the switch and the strap agree.
- The screen is kept awake during the session with Noop's `ScreenIdle.keepAwake`.

Honest states:
- Strap not connected: "Strap buzz (connect your strap)" in Muted.
- Reduce Motion: no scaling; the words In and Out carry the pace.
- End: "Done. Nice and calm." with an "Again" button.

## Direction contract

THESIS: The orb becomes the breath. One Glow disc grows on the inhale and shrinks on the exhale, with a single word in it. It refuses Noop's dashboard trainer: presets, a resonance sweep, R-R statistics.

OWN-WORLD: inherited from DESIGN.md.
- Night ground, Glow orb (halo, face wash, and rim at 25%) at 260pt, scaling between 0.72 and 1.0.
- The word inside the orb is Expanded Regular, 28pt.
- The headline sentence is Regular and centred.
- The "1:57 left" countdown is Meta Muted.
- A Surface row carries the buzz Toggle with the Charged tint.
- The Text capsule button is pinned at the bottom.
- The inline title is "Breathe".

STORY: he reads one line, taps Start, follows the orb and the strap for two minutes, and sees "Done. Nice and calm."

FIRST VIEWPORT: inline title, then the headline, then the orb centred with "Ready" in it, then the buzz row and the Start button at the bottom.

FORM: an extension of the established world; no seed key. Motion: the orb scales with easeInOut over each half-breath, and Reduce Motion is respected.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
