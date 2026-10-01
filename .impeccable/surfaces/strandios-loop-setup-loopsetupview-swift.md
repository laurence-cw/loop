---
version: 1
slug: "strandios-loop-setup-loopsetupview-swift"
primary_target: "StrandiOS/Loop/Setup/LoopSetupView.swift"
related_targets: []
---

# Loop Setup

Scope: the first-run flow (StrandiOS/Loop/Setup), shown by LoopRootView until `noop.onboarded`. Visitor mode: Operate. It extends the established Loop world (DESIGN.md), so there was no concept roll.

Audience and job: a boy (or his parent) setting up his phone once.

Brand book: "four screens, no more":
1. Welcome: one line, one button.
2. Bluetooth: a plain explainer before Apple's prompt ("Loop talks to your strap over Bluetooth. Nothing leaves your phone.").
3. Pair your strap: pick 4.0 or 5.0 from two pictures, then short steps for that strap. A 5.0 needs the official WHOOP app closed and the band tapped until its lights flash blue.
4. About you: first name, age (via date of birth) and school-night sleep times (via the school-day wake time).

Then straight to Home. No imports, no tour, and no terms screen (the owner removed it).

Data:
- Pairing uses Noop's own `AppModel.scan(model:)` and `LiveState.bonded`, exactly as Noop's onboarding ScanStep does, and sets Noop's `selectedWhoopModel`.
- The Bluetooth status is read-only, from `CBManager.authorization`. Noop creates its central at launch, so the system prompt may already have appeared, and the screen adapts. Loop doesn't touch BLE.
- About you writes `loop.firstName`, `ProfileStore.dateOfBirth`, and the school-day wake time through LoopWake. The buzz stays off.

Honest states:
- Bluetooth denied: an Open Settings button.
- Pairing not found after 15s: one line of checks and a retry.
- "Pair later" is always available.
- Done is disabled until a name is entered.

The strap pictures are drawn, generic shapes, never WHOOP artwork.

## Direction contract

THESIS: setup is the loop being introduced, not a wizard. Four calm screens, each with one line and one action, end on Home already greeting him by name. It refuses Noop's twelve-step tour.

OWN-WORLD: inherited.
- Night ground.
- Expanded Light title, with the line in sentence Regular Muted.
- One full-width Text-colour capsule button at the bottom.
- Progress as four dots: done in Muted, current wide in Text, the rest in Line.
- The welcome uses the Recovery orb in its learning state (Glow), the only Glow on that screen.
- Strap choices are Surface cards with drawn bands.
- About you is a single Surface card of rows with dark system controls.

STORY: he learns what Loop is in one line, allows Bluetooth, picks his strap and follows two or three steps, types his name, and lands on Home.

FIRST VIEWPORT (Welcome): the dots under the safe area; "Loop" title and line at the top left; the 180pt learning orb centred in the space; "Get started" at the bottom.

FORM: extension; no seed key. Motion: cross-fades between steps, with Reduce Motion respected.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
