---
name: Loop
description: Black with light. The day's cycle drawn as one ring, a word before every number.
colors:
  night: "#07070A"
  surface: "#121217"
  line: "#24242C"
  text: "#F2F2F5"
  muted: "#9A9AA6"
  signal: "#4A63FF"
  pulse: "#E0379A"
  charged: "#2EC4A6"
  steady: "#F2A93B"
  low: "#FF6A55"
  glow: "#7B45F0"
typography:
  hero:
    fontFamily: "SF Pro Expanded, system-ui"
    fontSize: "72px"
    fontWeight: 300
    lineHeight: 1
    fontFeature: "tnum"
  headline-number:
    fontFamily: "SF Pro Expanded, system-ui"
    fontSize: "40px"
    fontWeight: 300
    lineHeight: 1
    fontFeature: "tnum"
  title:
    fontFamily: "SF Pro Expanded, system-ui"
    fontSize: "28px"
    fontWeight: 300
  orb-word:
    fontFamily: "SF Pro Expanded, system-ui"
    fontSize: "22px"
    fontWeight: 400
  sentence:
    fontFamily: "SF Pro, system-ui"
    fontSize: "20px"
    fontWeight: 400
  row-value:
    fontFamily: "SF Pro Expanded, system-ui"
    fontSize: "20px"
    fontWeight: 400
    fontFeature: "tnum"
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "17px"
    fontWeight: 400
  meta:
    fontFamily: "SF Pro, system-ui"
    fontSize: "13px"
    fontWeight: 500
    fontFeature: "tnum"
rounded:
  card: "24px"
  capsule: "9999px"
spacing:
  xs: "8px"
  s: "16px"
  m: "24px"
  l: "32px"
  xl: "48px"
components:
  section-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.body}"
    rounded: "{rounded.card}"
    height: "72px"
  status-pill:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.muted}"
    typography: "{typography.meta}"
    rounded: "{rounded.capsule}"
    padding: "0 16px"
    height: "44px"
  status-pill-needs-help:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.meta}"
    rounded: "{rounded.capsule}"
    padding: "0 16px"
    height: "44px"
  button-primary:
    backgroundColor: "{colors.text}"
    textColor: "{colors.night}"
    rounded: "{rounded.capsule}"
    height: "50px"
  button-primary-inline:
    backgroundColor: "{colors.text}"
    textColor: "{colors.night}"
    rounded: "{rounded.capsule}"
    height: "44px"
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.card}"
  sheet:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    padding: "24px"
---

# Design System: Loop

Scope: this file describes Loop, the iPhone interface in `StrandiOS/Loop/`, and nothing else. Its tokens live in `StrandiOS/Loop/Design/LoopTheme.swift` (LoopColor, LoopSpace, LoopShape, LoopGlow, LoopMotion, LoopFont) and its words in `LoopVoice.swift`. The repository also has Noop's own design system in `Packages/StrandDesign` (StrandPalette, StrandFont). That is a different world and does not govern Loop. Don't mix the two: no StrandDesign token belongs on a Loop screen, and no Loop token belongs on a Noop screen. Values are iOS points, written as px in the frontmatter for tooling.

## Overview

**Creative North Star: "Black with Light"**

Loop is a near-black night with a few lit things on it. The light means something. Sleep is always blue, Activity is always magenta, and Recovery is the only thing that changes colour: teal, amber or coral, depending on what is left today. The signature is the loop drawn literally. Two round-capped arcs close a ring around a softly glowing orb. Sleep fills the left side from the bottom up, Activity spends the right side from the top down, and the orb holds the Recovery score and its word.

Density is low and glanceable. Each screen has one hero number, one plain sentence, and quiet supporting facts. Depth comes from tone and coloured light, not from shadows or borders. Surfaces are flat Surface cards on Night, and glow sits only behind the orb or bleeds in from a card's edge, light enough that you notice it on a second look. Type is SF Pro Expanded for numbers and headings and plain SF Pro for words. Every figure uses monospaced digits, and every number comes with a word.

**Key Characteristics:**
- Near-black Night ground with one flat Surface card family.
- Fixed meaning per colour: Signal is Sleep, Pulse is Activity, and only Recovery shifts between Charged, Steady and Low.
- The loop ring as the one hero: two 10pt round-capped arcs around a glowing orb.
- Glow at 15–25% opacity, only behind the orb or at a card's edge, one colour per card.
- SF Pro Expanded with monospaced digits for numbers; SF Pro for sentences.
- Motion that happens once and slowly: arcs fill once, the orb breathes, colour cross-fades.

## Colors

A black-with-light palette: two neutrals for ground and surface, two text tones, and colour kept strictly for meaning.

### Primary
- **Signal Blue** (signal): Sleep, every time. Sleep's arc, moon symbol, row glow and score word. Only used as text at row-value size (20pt) or larger.
- **Pulse Magenta** (pulse): Activity, every time. Activity's arc, figure.walk symbol, row glow and score word.

### Secondary
- **Charged Teal** (charged): Recovery 67–100. The orb tint and glow, the Recovery word and the Recovery row.
- **Steady Amber** (steady): Recovery 34–66, used in the same places.
- **Low Coral** (low): Recovery 0–33, used in the same places.

### Tertiary
- **Glow Violet** (glow): in-between moments only, such as "Getting to know you" while the first nights calibrate (the orb tint plus a thin 4pt progress ring). One element per screen at most. Use it for strokes and fills, never text.

### Neutral
- **Night** (night): the app ground behind everything. It ignores the safe area.
- **Surface** (surface): cards, the status pill, the orb face and sheets.
- **Line** (line): empty arc tracks, and the orb tint when there is no data.
- **Text** (text): primary text and numbers, and the fill of the primary button.
- **Muted** (muted): secondary text, units such as "/100", "No data", and the status pill at rest.

### Named Rules
**The Only-Recovery-Changes Rule.** Recovery is the only thing in Loop that changes colour. Signal is always Sleep and Pulse is always Activity. Status, chrome and controls never borrow Charged, Steady or Low.

**The Word-Beside-Colour Rule.** A Recovery colour never appears without its word (Charged / Steady / Low). Colour alone never carries a state.

**The Large-Colour-Text Rule.** Coloured text only appears at row-value size (20pt Expanded Regular) or larger. Signal is 4.0:1 on Surface, so body-size text stays Text or Muted. Glow is never text.

## Typography

**Display Font:** SF Pro Expanded (system), with monospaced digits for numbers
**Body Font:** SF Pro (system)

**Character:** The wide, expanded face at a light weight makes the numbers feel like quiet, grown-up kit: confident without shouting. The owner chose this lighter cut over the brand book's original Bold/Semibold on 2026-10-01, because the heavy weights read as too bold and not grown up. Plain SF Pro keeps the sentences calm and readable. Every style follows Dynamic Type. The two fixed number sizes, the 72pt hero and the 22pt orb word, scale through @ScaledMetric and shrink to fit inside the orb.

### Hierarchy
- **Hero** (Expanded Light 300, 72pt, monospaced digits): the single Recovery score inside the orb, on Home and Recovery. Section screens with their own hero use the section-hero variant (see Sleep Ring). One hero per screen.
- **Headline number** (Expanded Light 300, 40pt, monospaced digits): a secondary big figure, such as the "2/4" nights count in the learning orb.
- **Title** (Expanded Light 300, 28pt, the title text style): screen and sheet titles.
- **Orb word** (Expanded Regular 400, 22pt, scaled, sentence case): the Recovery word directly under the hero, in the band colour.
- **Sentence** (Regular 400, 20pt, the title3 text style): the one sentence that greets him by name and says what today means. Centred and wrapping freely.
- **Row value** (Expanded Regular 400, 20pt, title3, monospaced digits): row values and score words, plus the arc-foot values.
- **Body** (Regular 400, 17pt): checklist lines and sheet text. Row titles use Body at Regular (`LoopFont.rowTitle`).
- **Inline title** (Expanded Regular 400, 17pt, `LoopFont.inlineTitle`): the small navigation-bar title that fades in once a section's page title scrolls away.
- **Meta** (Medium 500, 13pt, the footnote text style, monospaced digits, `LoopFont.meta`): status pill text, units, and second facts such as steps, a number under its range bar, and "Your normal 52–59".
- **Explainer** (Regular 400, 13pt, the footnote text style, `LoopFont.explainer`): the one-line "what this means" under a measure, plus honest-state lines such as "Learning your normal." Always Muted.

### Named Rules
**The Expanded-for-Numbers Rule.** Numbers and headings use SF Pro Expanded with monospaced digits. Sentences use SF Pro. Never set a sentence in Expanded.

**The Word-and-Number Baseline Rule.** A score's word and its figure share one baseline at row-value size ("Steady 58"), with the word in the section's colour and the figure in Text.

**The One-Hero Rule.** Only one hero-size number per screen.

## Layout

Single column on an 8pt scale (8 / 16 / 24 / 32 / 48). Home's first viewport is the status pill 8pt below the safe area, then the ring group centred in the remaining height: the ring (max 320pt wide), its two arc-foot values 16pt below, and the sentence 48pt below those, inset 32pt from the sides. A Spacer of at least 48pt sits above and below the group. The hero area is at least one viewport tall, so the section rows always begin below the fold, 48pt down. Rows are spaced 16pt apart.

Arc-foot values sit side by side, each under its arc's outer foot. At large text sizes they stack, with Sleep left-aligned above Activity right-aligned (ViewThatFits). The hero area grows taller rather than letting large text spill into the rows. Inside a card, the symbol column is 24pt wide and items are 16pt apart. Sheets use 24pt padding and 24pt between groups.

Screen edges and card padding are 20pt. These are named exceptions to the 8pt scale that the brand book sets itself ("Screen edges: 20pt. Between cards: 16pt. Inside cards: 20pt."), so they are rules, not drift. Every other gap comes from the 8pt scale.

## Elevation & Depth

Loop has no drop shadows. Depth is tonal: Surface cards sit flat on Night, and lit things glow. Glow is coloured light at 15% or 25% opacity, in two places only. A card has one colour radiating from its leading edge (a 140pt radial at 15%). The orb has its tint as a blurred halo behind it, a radial wash across its face and a 1pt rim, each at 25%. The status pill and buttons have no glow.

### Shadow Vocabulary
- **Card edge glow** (radial gradient from the leading edge, section colour at 15% to clear over 140pt): the one colour per section row.
- **Orb halo** (circle 1.18× the orb diameter, tint at 25%, blur radius 0.16× diameter): only behind the orb.
- **Orb face wash** (radial gradient, tint at 25% to 0 over 0.55× diameter, over Surface) with **orb rim** (1pt stroke, tint at 25%).

### Named Rules
**The Light-Not-Shadow Rule.** Depth is coloured light at 15–25% opacity, never black shadows. It sits only behind the orb or at a card's edge, one colour per card.

**The Blur-Is-For-The-Orb Rule.** The orb halo is Loop's one blur. Cards are never frosted or glassy.

## Shapes

Soft and continuous. Cards use 24pt continuous corners. The status pill and buttons are full capsules. Arcs are 10pt strokes with round caps and a 16° gap at the top and bottom of the ring, so the two halves read as two. Empty tracks are drawn in Line beneath the coloured fill. The orb is a perfect circle at 58% of the ring's diameter. There are no borders on cards, and cards are never nested.

## Components

### Buttons
- **Shape:** full capsule.
- **Primary:** Text fill with Night label, Body Semibold, full width. 50pt tall in sheets, 44pt minimum inside a card.
- **States:** plain button style, with no hover or glow. One primary button per card or sheet.

### Status Pill
- **Style:** a Surface capsule, at least 44pt tall, 16pt horizontal padding, with an SF Symbol and Meta text 8pt apart.
- **At rest (synced / syncing):** Muted text and symbol, disabled, not tappable.
- **Needs help (can't find strap, Bluetooth off, no strap):** Text colour, with an exclamationmark.circle and a trailing chevron. Tapping opens the Find-my-strap sheet. A low battery (under 20%) adds a battery symbol and the percentage in Text.
- **Never** uses Recovery colours. State changes cross-fade.

### Cards / Containers
- **Corner Style:** continuous 24pt.
- **Background:** Surface on Night.
- **Shadow Strategy:** none. Card edge glow only (see Elevation & Depth).
- **Border:** none. Never nested.

### Section Row
A Surface card, at least 72pt tall. On the left is the section symbol (bolt.fill / moon.fill / figure.walk) in its colour, in a 24pt column. Then the title in Body Regular, with an optional second fact in Meta Muted beneath it. On the right is the word and number on one baseline at row-value size. The section colour glows in from the leading edge. Missing data shows "No data" in Muted, never zero. Combined into one accessibility element.

### Sheet
The Find-my-strap sheet uses a Surface ground at medium detent with 24pt padding. It has a Title, an optional Muted "Last synced" line, three checklist lines (a Muted SF Symbol in a 24pt column with Body Text) and one primary button at the foot.

### Section screen (Recovery, and Sleep / Activity to follow)
Pushed from Home with the system back button. The scroll view uses iOS 26's soft top scroll edge and a dark navigation bar, so the status bar stays light. The page title is Expanded Light, with the section's SF Symbol in its colour beside it. A small Expanded Regular title fades into the bar once the page title scrolls away. Measures render only after their data is read, then fade in, so a placeholder never reads "No data".

### Vital Card (range bar)
A Surface card with the section's leading glow, full width. The title sits in Muted Body, with the plain word beneath it at row-value size in Text ("Normal for you", "Higher than normal"). Below that is the range bar: a 6pt Line track, the normal band (baseline ± one sigma, Noop's |z| ≤ 1 rule) in Muted at 45%, and a 16pt Text dot with a 3pt Surface ring. The dot starts at the band's centre and eases to the value with LoopMotion.fill. Directly under the bar, 8pt below, the number sits at Meta Text on the left and "Your normal a–b" at Meta Muted on the right. The Explainer comes last.

### Sleep Ring (section hero)
On the Sleep screen, the hero is a 220pt Signal ring (10pt, round cap, Line track, no glow). It starts at the bottom and fills clockwise up the left, the way Home's Sleep arc fills the tank. Inside it, the duration sits in Expanded Light at 44pt (scaled). This is the section-screen variant of the hero: the 72pt hero rule is for the Recovery orb, which owns the most important number. Under it: "of Xh needed" in Meta Muted, and Noop's sleep-score word in Signal at 24pt Expanded Regular. That size is large text, so Signal's ~4.3:1 on Night passes. The duration uses a numeric content transition.

### Stages Bar
One 12pt bar split by each stage's share of the night, with 3pt gaps between segments. Light is Stage Light #8A96E8 (about 7:1 on Surface), deep is Signal #4A63FF, and dream is Stage Dream #C7CEFF, the palest. They are three tints of the Signal family, told apart by lightness and the gaps between them, and each is labelled in its own line. Each stage then gets its own line: a swatch, the name and Explainer, and its duration at row value. Stage minutes are rounded with largest-remainder, so they always add up to the night's total. When Noop doubts that night's staging (its sparse-motion, heart-rate-only or low-confidence gates), the three stage names turn Low and the numbers stay. That is the only reliability signal, and the accessibility hint says "This split may be off tonight." There is no blanket per-strap warning.

### Week Chart (sleep window)
Monday to Sunday. Each night is a 10pt Signal capsule running from bedtime (top) to wake (bottom), on faint 2pt Line guides. The axis covers the earliest bed to the latest wake, padded, and is never narrower than 9pm–9am. Two round-hour labels in Meta Muted are placed by the same scale as the bars. Day letters are in Meta: Text for days so far, Muted for days still to come. A past night with nothing recorded reads "No data" in Meta Muted; it is never drawn as zero. Future days are left empty. One sentence above the chart covers bedtime and wake-time steadiness, and only appears after three or more nights. It is never a telling-off.

### Effort Ring (Activity hero)
On the Activity screen, a 220pt Pulse ring (10pt, round cap, Line track, no glow) starts at the top and spends clockwise down the right, the way Home's Activity arc does. Inside it: the effort in Expanded Light at the 44pt section-hero size, with "/100" in Meta Muted. Under that, the score word in Pulse at 24pt Expanded Regular, then steps in Meta Muted. The word and steps lines are single-line and shrink to fit at large text sizes.

### Day Strip (effort through the day)
One bar per hour from 6am to midnight. Each bar is the effort that hour added, worked out from Noop's own StrainScorer: today's effort up to the end of the hour minus today's effort up to its start. Peaks (60% or more of the day's top hour) are full Pulse; the rest are Pulse at 45%. An hour with nothing recorded is a 3pt Line stub, never zero. Hours still to come are empty. A single 1pt Line baseline sits under the bars. "6am" and "12am" are pinned to the baseline's ends, and "12pm" and "6pm" sit on the bars' scale at 6/18 and 12/18, all in Meta Muted. One line above says when the day was busiest, or "No hour-by-hour record for today yet." when no heart rate has synced.

### Activity Row
Today's detected or recorded activities that have already started, as a quiet list rather than cards. Each row has the name in Body, then the start time and duration in Meta Muted. On the right, the score word in Pulse and the effort figure in Text share one baseline at row-value size ("Low 31"). Line hairlines go between rows only.

### Week Bars (effort / steps)
Two charts, Monday to Sunday, each with a single series and its title in Body. Bars sit on a 64pt plot. Today is full Pulse, and past days are Pulse at 55%. A past day with nothing recorded reads "No data" in Meta Muted. Days still to come are empty, with Muted day letters. No figure for today is repeated in the chart headers.

### List Screens (Settings, Advanced, About)
These use iOS inset-grouped lists in the platform's own grammar, never custom cards or controls. Rows are Surface on a Night ground; the system controls are dark. Switches and links take the Charged tint. The title is the Inline title in a principal toolbar item. Section headers are Regular Muted Body in sentence case (`LoopListHeader`), and footers are system footnote. The shared modifier is `loopListChrome(title:)`. Settings must fit one iPhone screen; Advanced and About may scroll. Times in footers use the phone's own clock format (`Date.formatted(time: .shortened)`), so they match the time pickers. Any line that states when something will happen (next buzz, bedtime reminder) is resolved from the same function that schedules it, on one clock.

### Setup Screens
Four steps: Welcome, Bluetooth, Pair your strap, About you. Each has an Expanded Light title, one Regular Muted line, scrolling content, and the primary Text capsule (50pt) pinned at the bottom with a soft bottom scroll edge. Progress is four dots (done Muted, current wide Text, ahead Line), with a 44pt back chevron on steps 2–4 plus an edge swipe. The welcome shows the numberless Glow orb, the only Glow on that screen. Strap choices are Surface cards with generic drawn bands labelled "4.0" / "5.0" (never WHOOP's lettering or artwork); tapping a card is the action. Pairing has one line per state (choosing, ready, looking, "Found it. Connecting…", connected). About you is a single Surface card of rows: name, age (a menu, written through Noop's `dateOfBirth(forAge:)`), and school-day wake-up. Done stays disabled until name and age are set.

### Check Row
For the "Normal / A bit off" measures. Not a card: a title in Body on the left, the word at row-value size on the right on the same baseline, and the Explainer beneath. Line hairlines go between rows only, never after the last one.

### Loop Ring (signature)
Two arcs around the Recovery orb. Sleep (Signal) runs bottom to top on the left, filled by hours slept against hours needed. Activity (Pulse) runs top to bottom on the right, filled by Effort out of 100. A nil value draws only the Line track. The orb shows the hero score with the band word under it. If the score is carried over, it adds "From last night" in Meta Muted. While learning, the orb shows a Glow tint, a 4pt progress ring, and "n/4" with "nights". With no data it shows "No score" in Muted. The ring is one accessibility element with a full spoken summary.

**Motion:** arcs fill once with a 0.8s ease-out and ease to later values. The orb breathes to 1.5% scale over a 4s cycle. Recovery colour cross-fades over 0.6s ease-in-out. Reduce Motion freezes the breath and the fills. The hero number uses a numeric content transition.

## Do's and Don'ts

### Do:
- **Do** take every colour, size and duration from `LoopTheme.swift`, and only from there.
- **Do** pair every score with its word: Charged / Steady / Low for Recovery, Great / Good / OK / Low for Sleep and Effort.
- **Do** keep one hero number per screen. The Recovery orb's score is 72pt Expanded Light with monospaced digits; a section screen's own hero (such as the Sleep ring's duration) is the smaller section-hero variant.
- **Do** mark each section with its one SF Symbol: bolt.fill for Recovery, moon.fill for Sleep, figure.walk for Activity.
- **Do** keep glow at 15% (card edge) or 25% (orb), one colour per card.
- **Do** show missing data as "No data" or "No score" in Muted, never as zero.
- **Do** respect Reduce Motion: freeze the orb breath and arc fills.
- **Do** keep touch targets at least 44pt tall.

### Don't:
- **Don't** use StrandDesign tokens (StrandPalette, StrandFont) on Loop screens.
- **Don't** give Charged, Steady or Low to anything but Recovery, including the status pill.
- **Don't** build grids of equal tiles or rows of three equal rings.
- **Don't** put gradients on text or buttons, or frost cards with blur.
- **Don't** make text glow, or set Glow Violet as text.
- **Don't** add borders to cards or nest cards.
- **Don't** use black drop shadows.
- **Don't** add uppercase tracked eyebrow labels above values. A section is marked by its SF Symbol.
