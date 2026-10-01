---
version: 1
slug: "strandios-loop-home-loophomeview-swift"
primary_target: "StrandiOS/Loop/Home/LoopHomeView.swift"
related_targets: []
---

# Loop Home

Scope: the Home screen of the Loop iPhone app (StrandiOS/Loop). Visitor mode: Operate. It's a glance surface, a few seconds morning and evening.

Audience and job: each boy (13 and 15) wants to know, in two seconds, how charged he is today and what that means. Content: today's recovery score and word, last night's sleep against need, today's effort and steps, sync status. Constraints: the brand book in PRODUCT.md is binding (palette, SF Pro Expanded, 8pt grid, glow rules, motion, voice, Never list). Data is read only through Noop's existing models. Below the fold: three section rows (Recovery, Sleep, Activity), a choice the owner confirmed.

Direction: pinned by the owner's brand book, so no concept roll. The build is code-led, because there's no image generation. Memorable moment: the loop drawn literally.

## Direction contract

THESIS: Home is the loop drawn literally. Two arcs close a ring around the recovery orb. Sleep's blue arc fills up the left side; Activity's magenta arc spends down the right. The orb in the centre glows the colour of what's left. It refuses the category default of a row of three equal rings or a tile grid of metrics.

OWN-WORLD: a Night #07070A ground; one Surface #121217 card family (radius 24, no borders, never nested); a Line #24242C empty track under 10pt round-capped arcs. Glow sits only behind the orb and at card edges, at 15–25% opacity, one colour per card. SF Pro Expanded with monospaced digits for numbers, SF Pro for words. SF Symbols (moon, figure.walk, bolt) at regular weight. No gradients on text or buttons, no blur cards.

STORY: he sees the word (Charged / Steady / Low) at heading size under the score; one sentence greets him by name and says what today means. The arcs show how full sleep got him and how much he's spent. Going one layer deeper by tapping a row or the ring is **deferred**: it arrives with the Recovery, Sleep and Activity section screens, the next build step. Until then, rows and ring are not tappable.

FIRST VIEWPORT: a small status pill centred under the safe area. Then the loop ring, around 300pt wide and centred: the orb is about 58% of the ring's diameter, with the 72pt score inside it and the Recovery word directly under it at about 22pt Expanded Semibold in the band colour. Sleep arc on the left (bottom to top), Activity arc on the right (top to bottom), a 16° gap at top and bottom. Under each arc's outer foot sits its value, marked by its section's SF Symbol (moon / figure.walk); there are no uppercase eyebrow labels. 48pt of space, then the one sentence at 20pt medium, centred, wrapping freely (two lines at default size). Ring, values and sentence form one group, centred in the space under the pill. No other element above the fold. The status pill uses Muted / Text with SF Symbols only, never Recovery's colours.

FORM: brief-pinned by the owner's brand book; no seed key (the roll was skipped because a pinned direction beats it). Signature interaction: on open, the arcs draw once in 0.8s ease-out; the orb breathes at 1–2% scale every 4 seconds; Recovery colour cross-fades on change; Reduce Motion freezes both.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
