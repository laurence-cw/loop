---
version: 1
slug: "strandios-loop-recovery-looprecoveryview-swift"
primary_target: "StrandiOS/Loop/Recovery/LoopRecoveryView.swift"
related_targets: []
---

# Loop Recovery

Scope: the Recovery section screen (StrandiOS/Loop/Recovery), pushed from Home's ring or Recovery row. Visitor mode: Operate. An extension inside the established Loop world (DESIGN.md), so the world is inherited and there was no concept roll.

Audience and job: a boy checking why he's Charged, Steady or Low today. Content follows the brand book's three layers:
- **Headline:** the orb (score and word) plus the band's one line.
- **One tap in:** Heart variability and Resting heart rate, each on a "normal for you" range bar with a plain word first and the number small underneath.
- **Deeper:** Breathing rate and Temperature as Normal / A bit off, each with its one-line explainer.

Data is read only, through Noop's stored nightly values (with Noop's prior-night carry) and Noop's own baseline fold (normal = baseline ± one sigma, Noop's |z| ≤ 1 rule), computed over nights before today.

Honest states:
- **5.0 strap:** heart variability and breathing show only "Not reliable on this strap yet." (no word, no number, no explainer).
- **No baseline yet:** "Learning your normal."
- **No value:** "No data".
- **Carried score:** the headline adds "That's last night's score."

Deferred: the low-day breathing exercise (the brand book's strap buzz for Recovery). It arrives with the Breathing screen, step 6 of the build order.

## Direction contract

THESIS: Recovery explains the orb. It shows the orb again, then says why in the body's own terms, each measure set against his own normal. It refuses the category default of a grid of vital tiles with raw numbers.

OWN-WORLD: inherited from DESIGN.md. Night ground; Surface cards with the Recovery band colour glowing from the leading edge, one colour per card. Range bar: a Line-colour track, the normal band in Muted at 45%, a Text-colour dot with a Surface ring. Light Expanded type for the title and number; Regular for words.

STORY: he sees the score and word, reads one line about today, then sees which body signals sit inside or outside his normal. The curious can read the numbers and the explainers.

FIRST VIEWPORT: the system back button, the "Recovery" title (Expanded Light), the 200pt orb centred with 48pt above and below, the band line (sentence, Regular), then the Heart variability card starting below. Cards are 16pt apart; the deeper rows start 48pt below the cards and are divided by Line hairlines, not carded.

FORM: an extension of the established world; no seed key. Motion: the range-bar dot eases in with LoopMotion.fill; the orb breathes as on Home; Reduce Motion is respected.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
