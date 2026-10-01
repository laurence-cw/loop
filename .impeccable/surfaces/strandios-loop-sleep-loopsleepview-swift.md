---
version: 1
slug: "strandios-loop-sleep-loopsleepview-swift"
primary_target: "StrandiOS/Loop/Sleep/LoopSleepView.swift"
related_targets: []
---

# Loop Sleep

Scope: the Sleep section screen (StrandiOS/Loop/Sleep), pushed from Home's Sleep row. Visitor mode: Operate. It extends the established Loop world (DESIGN.md), so there was no concept roll.

Audience and job: a boy checking how he slept and whether his nights are steady. Content follows the brand book's three layers:
- **Headline:** hours slept against hours needed, as one Signal ring with the duration in the middle, "of Xh needed" under it, and Noop's sleep score word.
- **One tap in:** stages (light, deep, dream) as one proportional bar plus one line each with its explainer; then time awake and sleep quality.
- **Deeper:** this week, Monday to Sunday. Each night is a floating bar from bedtime (top) to wake (bottom), with one sentence on bedtime consistency.

Data is read only. It comes from Noop's stored nightly rows and `SleepView.mainNightSpan`, Noop's main-night resolver. Need is Noop's rule: the imported need, else the recent mean, with a 7.5h floor.

Honest states:
- **5.0 strap:** stages show only "Not reliable on this strap yet."
- **No night:** "No sleep recorded last night. Was the strap off?"
- **Past night with nothing recorded:** labelled "no data".
- **Future days this week:** left empty.
- **Consistency:** needs 3 or more nights before it says anything.

Deferred:
- Wake-up alarm and bedtime buzz (Settings, step 4).
- Bedtime consistency over a longer span.

## Direction contract

THESIS: Sleep shows the tank filling. One blue ring fills towards the night's need, then the screen explains what the night was made of and whether the week is steady. It refuses the category default: a hypnogram wall of stage blocks and percentages.

OWN-WORLD: inherited from DESIGN.md.
- Night ground, with Surface cards glowing Signal from the leading edge.
- The Signal ring is 10pt with a round cap on a Line track, and has no glow (glow belongs to the Recovery orb).
- Stages use Signal at three opacities: light 35%, deep 100%, dream 65%.
- The week chart uses 10pt Signal capsules on faint 2pt Line guides.
- Light Expanded for the duration and the title.

STORY: he sees how close he got to his need and a word for the night. He learns what the night was made of. He sees whether his bedtimes are steady this week.

FIRST VIEWPORT: the system back button; the "Sleep" title with moon.fill in Signal; a 220pt ring centred with 48pt above and below; the headline sentence; then the Stages card begins.

FORM: an extension of the established world, with no seed key. Motion: the ring fills once with LoopMotion.fill; Reduce Motion respected. The section screen shell follows DESIGN.md's section screen pattern: soft top edge, a dark bar, an inline title that fades in, and the measures held until loaded.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
