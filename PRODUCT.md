# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Two teenage brothers, around 13 and 15, each with his own iPhone (both on iOS 26 or newer) and his own WHOOP strap: one 4.0, one 5.0. Their activity is walking, PE, lunchtime football and maybe one gym session a week. They glance at the app for a few seconds in the morning and evening; they don't study it. Their parent (the owner) builds, installs and maintains the app and tests it on his own phone first.

## Product Purpose
Loop is a new iPhone interface for the open-source Noop app (github.com/ryanbr/noop; fork at github.com/laurence-cw/loop). It keeps Noop's Bluetooth, storage and scoring exactly as they are and replaces only the screens. Success: each boy understands in two seconds where he is in today's cycle (how charged he is, how he slept, how hard he's worked) and what that means for today.

## Positioning
The organising idea is the loop itself: sleep fills the tank, activity spends it, recovery shows what's left this morning, then round again. That cycle is the name, the structure and the story of every screen. Every number arrives with a plain word and a sentence first. It's serious like athletes' kit, with none of the jargon.

## Operating Context
- A few seconds at a time, first thing in the morning and in the evening, often one-handed.
- Everything stays on the phone. Noop has no server, account or cloud, and Loop adds none.
- Sideloaded builds signed with a free Apple ID expire every 7 days and are refreshed from the family iMac. TestFlight is planned once there's a paid developer account.
- A 5.0 strap bonds to one device at a time, and the official WHOOP app must be closed.

## Capabilities and Constraints
- **Three sections plus Home.** Recovery, Sleep, Activity. Each has three layers: a headline at a glance, detail one tap in, and depth for the curious.
- **Settings.** Sleep times (school nights and weekends), the strap, first name, age, a few notification switches, and an Advanced area.
- **Screen inventory.** Approved 2026-09-30 in `docs/loop/screen-inventory.md`. Most of Noop is cut from view: Trends, Coach, More, imports, Test Centre, Apple Health, Watch app, widgets, warnings and nudges. There is no terms screen.
- **Scores.** One scale, 0–100 everywhere (Effort included). Every score carries a word: Recovery Charged 67–100, Steady 34–66, Low 0–33; Sleep and Effort use Great / Good / OK / Low.
- **Reliability (owner's rule, 2026-10-01).** Loop shows the data it has. It flags something only when Noop itself detects a problem with that specific night: for sleep stages, Noop's sparse-motion, heart-rate-only and low-confidence staging gates. A doubtful night's stage names turn red (Low); the numbers stay. A general belief about a strap model is never shown, so there is no blanket "Not reliable on this strap yet". The 5.0 gives no blood oxygen. On a 5.0, the wake-up alarm depends on Noop's experimental "Protocol probes" switch.
- **Honest states.**
  - First nights (Noop calibrates over four, `Baselines.minNightsSeed`): "Getting to know you".
  - Missing days are shown as missing, never as zero or smoothed over.
  - A stale sync shows the last sync time plainly.
  - Scores are estimates; this is said once, in Settings.
- **Code rules.**
  - UI and design only. Never change `Packages/WhoopProtocol`, `WhoopStore` or `StrandAnalytics`.
  - Loop's code lives in new files, separate from Noop's.
  - The Xcode project is generated from `project.yml` with XcodeGen.
- **Licence.** Personal, non-commercial use only (PolyForm Noncommercial). Keep Noop's LICENSE and credits intact.
- **Open checks.** Bedtime buzz feasibility, the 5.0 alarm clock, step accuracy, the magenta/coral clash, and connection drops.

## Brand Commitments
- **Name.** Loop.
- **Voice.** A good coach: calm, direct, a bit dry, never preachy.
  - Answer first, numbers second.
  - Short sentences, under 12 words where possible.
  - One "!" per screen at most. No emoji.
  - UK English.
  - Never blame: a low day is information, not a telling-off.
  - Greet each boy by his first name.
- **Words on screen.** Loop's vocabulary replaces Noop's: Effort, not Strain; Heart variability, not HRV; Dream sleep, not REM; Your normal, not baseline. Never shown: HRV, ms, rpm, baseline, strain, synthesis, correlation, Pearson, n =.
- **Visual contract.** Binding, set by the owner's brand book:
  - Near-black "black with light". Section colours: Signal #4A63FF for Sleep, Pulse #E0379A for Activity. Recovery shifts between Charged #2EC4A6, Steady #F2A93B and Low #FF6A55. Glow #7B45F0 is for in-between moments.
  - SF Pro Expanded for big numbers and headings, SF Pro for everything else, with monospaced digits. Weights are light: Expanded Light for numbers and titles, Regular for words and values. The owner chose this on 2026-10-01 over the brand book's Bold/Semibold, which felt too heavy and not grown up. No uppercase spaced labels.
  - An 8pt grid, 24pt cards, 10pt rounded arcs.
  - Glow only at card edges or behind the orb, at 15–25% opacity.
  - Motion: arcs fill once, the orb breathes slowly, Reduce Motion is respected.
  - Icons: SF Symbols, one per section.
- **Never.**
  - Grids of equal tiles, or more than one hero number on a screen.
  - Purple gradients everywhere, glassy blur on every card, or glowing text.
  - Charts that invent data.
  - Weight, calories or anything about body size.
  - Streaks, badges or guilt.
  - Comparing the boys with each other or anyone else.
  - Beta or debug text on everyday screens.
  - Whoop's logo, name, fonts or layouts.

## Evidence on Hand
Real strap data from the boys' own WHOOP 4.0 and 5.0 once they're paired. There are no screenshots, testimonials or benchmarks, and none should be invented.

## Product Principles
1. Every screen has to answer "where am I in the loop today?". If it doesn't, it goes.
2. Words before numbers: a sentence and a word first, then the figure for the curious.
3. Honest over impressive. Gaps and estimates are named plainly. A night is flagged only when Noop actually detects a problem with it, never on a guess.
4. It informs, it doesn't nag. No streaks, guilt or warnings.
5. The strap should just work. When it doesn't, one line and one fix.

## Accessibility & Inclusion
No specific needs known. Standard practice: Dynamic Type through the system text styles, WCAG AA text contrast on Surface, and respect for Reduce Motion. Recovery state is always paired with a word, never colour alone.
