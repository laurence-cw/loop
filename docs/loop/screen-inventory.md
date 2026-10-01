# Loop: screen and settings inventory (for approval)

Every screen and setting in Noop's iPhone app (scheme `NOOPiOS`), sorted into the brand book's four buckets. Nothing in the app changes until this is approved.

- **Keep**: a boy needs it at least once a month.
- **Keep, reskinned**: needed, but Noop's version is cluttered. Loop rebuilds it.
- **Advanced**: only needed to fix something. One tap deeper in Settings.
- **Cut**: Mac-only, developer-facing or off-brief. Hidden from Loop. The code stays in place, so upstream fixes still merge.

"Cut" never deletes anything. Loop simply doesn't show that screen. Where a cut setting changes how data is scored, Loop pins it to a fixed value (noted as **Pinned**) instead of exposing it.

Items marked **⚑** need a decision from you. They're listed at the end.

---

## Keep, reskinned: the core of Loop

| Noop screen / setting | Where it is in Noop | Loop plan |
|---|---|---|
| Today (Liquid Today, and classic Today) | Tab 0 · `Strand/Liquid/LiquidTodayView.swift`, `Strand/Screens/TodayView.swift` | Replaced by Loop **Home**: recovery orb, sleep and activity arcs, one sentence, status pill |
| Recovery (Charge) ring, drivers and "What shaped your Charge" | Today hero, `CoupledView.swift` | **Recovery** section: score + word → heart variability and resting HR range bars → breathing and temperature "normal / a bit off" |
| Sleep | Tab 2 · `Strand/Screens/SleepView.swift` | **Sleep** section: hours vs needed → stages, awake, quality → bedtime/wake consistency |
| Effort (Strain), steps, Deep Timeline | Today, `FullDayChartView.swift` | **Activity** section: steps + effort → effort through the day, detected workouts → the week |
| Workouts list and workout detail | `WorkoutsView.swift`, `WorkoutDetailView.swift` | Shown inside Activity as "detected workouts". The standalone list is not kept |
| Metric detail (history of one number) | `MetricExplorerView.swift` (`MetricDetailView`) | Becomes the "deeper" week views inside each section |
| Breathe | `Strand/Screens/BreathingView.swift` | Kept as the **low-recovery breathing exercise** (strap buzz paces it; the orb breathes with it) |
| Interval Timer | `Strand/Screens/IntervalTimerView.swift` | Kept as an **Activity** strap-buzz tool |
| Alarms: strap wake-up buzz, wake time, weekdays | `Strand/Screens/SmartAlarmView.swift` | **Wake-up alarm** plus **school-night / weekend sleep times** in Settings |
| Wind-down reminder + per-day wake times | `SmartAlarmView.swift` | Becomes the "bedtime nudge" (phone notification). ⚑ See decision 4 |
| Onboarding wizard (12 steps) | `Strand/Onboarding/OnboardingWizard.swift` | Cut to the brand book's **four screens**: Welcome, Bluetooth, Pair (4.0 or 5.0), About you |
| Add-a-device wizard | `Strand/Screens/AddDeviceWizard.swift` | Reused inside Loop's "Pair your strap" step, showing **only WHOOP 4.0 and 5.0** |
| Devices sheet: status, battery, sync | `Strand/Screens/DevicesView.swift` | Becomes the **status pill** (Syncing / Synced 7:42am / Can't find your strap) plus the "Find my strap" help card |
| Terms acknowledgement (clickwrap) | `Strand/App/TermsGateView.swift` | ⚑ See decision 1 |
| Live heart rate (Live Body Console) | More → Live · `Strand/Screens/LiveView.swift` | Hidden tap on the heart icon, as the brand book says. Stripped of its debug panels |
| HR-zone coaching buzz | Automations → Haptic coaching | Kept as the Activity **heart-rate zone buzz** switch |
| Notification switches: wrist alerts master, battery alerts, wind-down | Automations, Alarms | A few plain switches under **Notifications** in Settings. No thresholds |
| About: disclaimer, "Built on" credits, project link | Settings → About | Loop's About, with the single "these are estimates" note. Noop's credits and licence notice stay intact |

## Keep: Settings, as-is but restyled

| Setting | Where it is in Noop | Notes |
|---|---|---|
| Date of birth (gives age for Effort) | Settings → Profile | Asked in onboarding; editable in Settings |
| Wake-up alarm on/off | Alarms | – |
| Sleep times (school nights / weekends) | Alarms → wake time + per-day overrides | Noop stores one wake time plus per-weekday overrides; Loop presents that as "school nights" and "weekends" |
| Strap battery and pairing | Settings → Strap, Devices | Battery shows in the pill only below 20% |
| First name | **Doesn't exist in Noop** | ⚑ See decision 2 |

## Advanced (one tap deeper, clearly labelled)

| Item | Where it is in Noop | Notes |
|---|---|---|
| Re-scan / Disconnect strap | Settings → Strap | Normally automatic; here as a manual fallback |
| Restart strap | Devices → ⋯ | Reversible, already confirmation-gated in Noop |
| Rename strap (4.0 only) | Settings → Strap | – |
| Strap clock / firmware status | Diagnostics readouts | Shown read-only |
| **5.0 experimental switch** ("Protocol probes") | Test Centre → 5/MG protocol diagnostics | Important: **Noop only arms the wake-up alarm on a 5.0 when this switch is on** |
| Export data (.noopbak backup, CSV) | Settings → Backup & restore | – |
| Restore from backup | Settings → Backup & restore, Backup & Sync | Useful when a phone is replaced |
| Recalibrate recovery baseline | Settings → Advanced → Recovery | Rarely needed |
| Steps calibration | Settings → Profile → Step calibration / Steps estimate | Relates to the open "step accuracy" check |
| Share strap log / report a problem | Settings → Strap log, Test Centre → Report a bug | ⚑ See decision 6 |
| Storage clean-up | Settings → About → Storage | – |
| Sideload expiry date | Settings → About → Diagnostics | Also drives Loop's "needs refreshing" note |
| Edit a night's sleep times / add a nap | Sleep → edit sheet | ⚑ See decision 5 |
| "Resync history" | **Doesn't exist in Noop** | Noop has "Stop sync" only. ⚑ See decision 7 |
| "Reset app" | **Doesn't exist in Noop** | ⚑ See decision 7 |

## Cut

**Tabs and whole screens**

| Item | Where it is in Noop | Why |
|---|---|---|
| Trends tab, weekly digest, Trends PDF report | Tab 1 · `TrendsView.swift`, `TrendsReportView.swift` | Brand book cuts Trends |
| AI Coach tab, Coach settings, Coach launcher, morning brief | Tab 3 · `CoachView.swift`, `CoachSettingsView.swift` | Brand book cuts AI Coach. **Pinned**: Coach off |
| More tab (the whole menu) | Tab 4 · `RootTabView.swift` | Replaced by Loop's three sections + Settings |
| Explore, Compare, Intelligence, "What Moves You" insights | More → Insights | Brand book cuts these |
| Journal, Mind, caffeine log, self-experiments | More → Insights (`InsightsView.swift`) | Off-brief |
| Stress screen and stress widget | More → Body, widgets | Brand book cuts Stress |
| Health Monitor (Fitness Age, Vitality, illness banner) | More → Health | Off-brief; its useful parts (resting HR, temperature) move into Recovery |
| Lab Book (blood tests, body markers) | More → Body | Off-brief |
| Rhythm (experimental heart-rhythm view) | More → Body | Off-brief, medical-sounding |
| Cycle tracker / cycle awareness | Health, Automations | Not relevant; already hidden for male profiles |
| Hydration tracking | Settings → Features | Off-brief. **Pinned**: off |
| Lift Log, lift sessions, programs | More → Body | Off-brief (one gym session a week doesn't need a program editor) |
| Manual workout entry, "Start workout" picker, live workout screen | Workouts, Live | ⚑ See decision 3 |
| Live Sessions (beta) | Today, Settings → Experimental | Beta. **Pinned**: off |
| Your Data, Fused (multi-source merge) | More → Data | One strap per phone; nothing to fuse |
| Apple Health | More → Data | Brand book cuts it; also unavailable on free signing |
| Data Sources (all imports: WHOOP CSV, Apple Health, Mi Band, nutrition, lifting, GPX/FIT, Oura/Fitbit/Garmin) | More → Data | Brand book cuts imports |
| Broadcast heart rate (phone or strap) | Data Sources, Test Centre | Developer feature |
| Mi Band screen, NOOP Limitations grid | More → Data | Off-brief / developer-facing |
| Shortcuts Export, Siri & Shortcuts | More | Brand book cuts Shortcuts |
| Automations: double-tap actions, wear/presence Shortcuts | More → Automations | Brand book cuts Automations |
| Inactivity reminder | Automations | ⚑ See decision 8 |
| Stress check-ins, strain-target nudge, illness early warning | Automations | "Loop informs, it doesn't nag". ⚑ Illness: see decision 8 |
| Test Centre (all test modes, raw-data collector, R22/ECG/Oura writes, experimental algorithms) | More → Test Centre | Developer-facing. The one 5.0 switch moves to Advanced |
| Device probes (battery, body-location, feature-flag, config, ECG) | Devices → ⋯ | Reverse-engineering tools |
| Multi-strap switcher, compare straps, removed devices | Devices | One strap per phone; also avoids comparing the boys |
| Pairing types: HR straps, gym equipment, Oura, Amazfit, Mi Band, Garmin | Add-a-device wizard | Brand book cuts Oura/Polar; 4.0 and 5.0 only |
| Power saving screen | More → App | Developer-level trade-offs. **Pinned**: Noop defaults |
| What's New, How NOOP works, How your scores work | Settings → About, auto sheet | Replaced by Loop's one-line explainers |
| Update checker ("Check for updates", daily check) | Settings → About | Brand book cuts it. **Pinned**: off |
| Updates inbox | Classic Today bell | Goes with classic Today |
| Streak card | Settings | "No streaks" |
| About Apple Watch data / Apple Watch setup | Settings → About | Brand book cuts the Watch app |
| Apple Watch app and complications | `NOOPWatch/`, `NOOPWatchComplications/` | Cut. ⚑ Also dropping it from the build: see decision 9 |
| Widgets: NOOP, Coach Brief, Heart Rate, Stress | `StrandiOSWidgets/` | ⚑ See decision 10 |
| Live Activities: live HR, lift session, sync progress | Settings → Live notifications | ⚑ See decision 10 |
| Customize Today / Customize Sleep | Sheets | Loop has one fixed layout |
| Quick Actions menu ("+") and Home Screen quick actions | Today, app icon | Off-brief |

**Settings that go (and their pinned values)**

| Setting | Where it is in Noop | Loop value |
|---|---|---|
| Profile photo | Settings → Profile | Not shown |
| **Weight, height, waist** | Settings → Profile | **Never shown** ("nothing about body size"). ⚑ See decision 11 |
| Sex | Settings → Profile | ⚑ See decision 11 |
| Max heart rate, custom HR zones | Settings → Profile | Auto (age-based) |
| Day cycle (main sleep / midnight) | Settings → Profile | Noop default (main sleep) |
| Units: body, distance, temperature | Settings → Units | **Pinned**: metric, km, °C (UK) |
| Skin temperature display | Settings → Units | **Pinned**: "vs your normal" |
| **Effort scale** | Settings → Units | **Pinned: 0-100**, as the brand book requires. Noop already supports this, so no scoring change |
| Exponential Effort (Banister) | Settings → Units | Noop default (off) |
| Language, clock format | Settings → Appearance | English; clock follows the phone |
| Theme, accent, chart colours, presets, backgrounds, card transparency, app icon, sky effects, sleep chart style, trend chart style | Settings → Appearance | Replaced by Loop's fixed look |
| Reduce motion in NOOP | Settings → Appearance | Loop follows the phone's Reduce Motion setting instead |
| Hide bar when scrolling | Settings → Appearance | Not needed |
| Auto-detect workouts | Settings → Features | **Pinned: on** (Activity depends on detected workouts) |
| Journal reminder, keep screen on during workout | Settings → Features | Off |
| Keep screen on while syncing | Settings → Sync | Noop default |
| Continuous HRV capture, overnight only, HRV window | Settings → Advanced → HRV | Noop defaults |
| Liquid Today, Blood Oxygen, Oura all-day HR | Settings → Experimental | Off / not shown (Loop replaces Today; no blood oxygen) |
| Sleep staging V2, motion-aware wake | Settings → Experimental | Noop defaults (V2 on) |
| Export raw sensor data (CSV) | Settings → Experimental → Diagnostics | Developer tool |

---

## Decisions for you

1. **Terms screen.** Noop shows a terms checkbox before anything else. The brand book wants four onboarding screens. **I suggest** keeping it, restyled in Loop's look, as a short step before Welcome, since it's Noop's terms and the licence asks that its notices stay intact. The alternative is to accept it once on each phone yourself before handing it over.
2. **First name.** Noop has no name field. Loop would store it in its own setting, separate from Noop's data, and use it only in greetings. **I suggest** yes.
3. **Starting a workout by hand.** The brand book only mentions detected workouts. Noop can also start and record a workout manually (for PE or football). **I suggest** cutting it and relying on auto-detection.
4. **Bedtime buzz.** Noop's wind-down reminder is a phone notification, not a strap buzz. A strap buzz at bedtime is still an open check. **I suggest** keeping the phone notification for now, labelled "Bedtime reminder", and revisiting after the check.
5. **Fixing a wrong night.** If the strap gets bedtime wrong, Noop lets you edit a night or add a nap. **I suggest** keeping it in Advanced.
6. **Strap log / report a problem.** Useful to you when chasing connection drops, but developer-ish. **I suggest** keeping it in Advanced as "Share strap log".
7. **Resync history and Reset app.** Neither exists in Noop. Building them would touch storage, which the rules forbid. **I suggest** leaving both out. "Restore from backup" and "Restart strap" cover the realistic cases.
8. **Nudges.** Noop can warn about sitting too long and about early illness signs from temperature. **I suggest** cutting the inactivity nudge (it nags) and cutting the illness warning. The temperature line in Recovery ("a big jump can mean you're coming down with something") covers it calmly.
9. **Apple Watch app in the build.** It's cut from Loop, but Noop still bundles it inside the iPhone app, which is what caused tonight's signing trouble. Removing it means one change to `project.yml`. **I suggest** yes, in the first build step.
10. **Widgets and Live Activities.** Not in the brand book. **I suggest** cutting them all for now. A single Loop widget (the recovery orb) could come later.
11. **Weight, height and sex.** Hidden from screens, as the brand book requires. Noop may use them in some scores. Before building, I'll confirm in the code whether Recovery, Sleep or Effort depend on them. If only cut features (calories, VO₂max) use them, they stay hidden with Noop's defaults. If a kept score needs one, I'll come back to you.

---

## Approved (30 Sep 2026)

1. **Terms screen: removed.** Loop is for the two boys only; the welcome screen is restyled instead. Noop's LICENSE and copyright notices stay intact in the repo and in About.
2. **First name: added,** stored in Loop's own setting, and used to greet each boy by name.
3. **Apple Watch app: removed from the build** (`project.yml`).
4. **Warnings and nudges: cut,** including the inactivity reminder and the illness warning.
5. to 11. **Suggestions accepted as written above.**
