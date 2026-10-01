---
version: 1
slug: "strandios-loop-activity-loopactivityview-swift"
primary_target: "StrandiOS/Loop/Activity/LoopActivityView.swift"
related_targets: []
---

# Loop Activity

Scope: the Activity section screen (StrandiOS/Loop/Activity), pushed from Home's Activity row. Visitor mode: Operate. An extension inside the established Loop world (DESIGN.md), so the world is inherited and there was no concept roll.

Audience and job: a boy checking how much he's moved today and where the effort came from. Content follows the brand book's three layers:
- **Headline:** effort 0–100 with its word, and steps.
- **One tap in:** effort through the day, 6am to midnight, as an hourly bar strip with peaks standing out, plus today's detected or recorded activities.
- **Deeper:** effort and steps across the week, Monday to Sunday, as two charts with one series each.

Data is read only. Each hourly bar is the effort that hour added, worked out from Noop's own StrainScorer: the same parameters as Home's live effort, asked cumulatively, so the bar is effort(up to the end of the hour) minus effort(up to its start). Activities are Noop's WorkoutRows with Noop's display names. The week view reads Noop's stored daily strain and steps, with today matching Home.

Honest states:
- An hour with nothing recorded shows a grey stub, never a zero.
- Hours still to come are empty.
- A past day with nothing recorded reads "No data".
- No activities: "None picked up yet today."
- No reliability caveats (the owner's rule).

Deferred:
- Interval timer and heart-rate zone buzz (strap tools, a later step).

## Direction contract

THESIS: Activity shows the tank being spent. One magenta ring spends down from the top the way Home's Activity arc does, then the day's shape shows where the effort went. It refuses the category default of a calorie-and-distance tile grid.

OWN-WORLD: inherited from DESIGN.md.
- Night ground, with Surface cards glowing Pulse from the leading edge.
- The Pulse ring is 10pt, round cap, on a Line track, with no glow.
- Hourly bars: Pulse, with peaks (60% or more of the day's top hour) at full colour and the rest at 45%.
- Week bars: today at full Pulse, past days at 55%.
- Light Expanded for the effort number and the title.

STORY: he sees today's effort and steps and a line on what drove it, then when in the day it happened and which activity, then how today compares with the rest of the week.

FIRST VIEWPORT: system back button; the "Activity" title with figure.walk in Pulse; a 220pt ring centred with 48pt above and below; the headline sentence; then the "Through the day" card begins.

FORM: an extension of the established world; no seed key. Motion: the ring fills once and the hourly bars grow once with LoopMotion.fill, and Reduce Motion is respected. The section-screen shell follows DESIGN.md.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
