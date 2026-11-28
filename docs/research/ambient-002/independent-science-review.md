---
title: AMBIENT-002 independent scientific review
status: Current
document-kind: evidence
scope: Source-bound independent preflights and complete 83a3 baseline readback; final-source and gameplay acceptance remain separate
last-reviewed: 2026-11-25
---

# Independent AMBIENT-002 scientific review

This record preserves the initial independent apparatus review and two local
integration episodes at source `9278de5757b29b9df40a089e11a4daef744990f7`, followed
by the complete local baseline at `83a3db6ffb207761df999abedac77eb1401604a8`.
The initial preflights did not qualify the full programme. The complete baseline
readback below is separately identified from the later nine-case recovery repair,
final-source qualification, graphical campaign and portable Windows evaluator.
The original post-run reader checkpoint is
`4dc10266053cac98d6a9bb445f05ca1ef2431f41`; the same reader bytes are bound into
the 83a3 source and never alter the actors whose traces they inspect.

The [original review receipt](evidence/reconstructed-science-review/receipt.json)
binds reviewed inputs, exact command output, raw-report digests, the official
engine and native/Rapier identities. The complete source/project custody
manifest and original test consoles are retained alongside it. An earlier
attempt correctly refused changing source bytes during checkout; that refusal
was not converted into a pass.

## Independent checks and their scope

Fresh execution verified **1,139 clean committed execution inputs** and **855
loaded-project inputs**, then independently ran the apparatus' ten synthetic
custody/reducer tests and the reader's nine separate boundary tests. All
**19 synthetic tests passed**. Synthetic inputs count as zero physical episodes.
The original materialized native/Rapier files matched retained provenance, and
the Linux Godot executable matched the official pinned SHA-256.

The reader separately recomputes movement, occupancy, stalls, home crossings and
selection changes from raw positions and commands. It checks copied peer
distances against simultaneous actual actor positions, compares each ablation's
authored profile against the exact permitted edits, and reports matched-seed
differences rather than unpaired cohort claims. Every post-run output binds the
original report, reducer summary and reader bytes by SHA-256.

The frozen registry declares **194 actual actor episodes in 122 fresh World
campaign clusters**. Sixteen passive companions support the sixteen descriptive
personality treatments, leaving **178 subject episodes**. Companion actors are
real physical actors, but are not additional personality replicates. Population
actors in the same World share a campaign cluster. Registry generation itself
executes zero actor episodes, and completed preflights stay outside the primary
194 count.

## Retained integration observations

The two 30-second source-9278 integration episodes each completed **1,800 native
and 1,800 Rapier ticks**, with **7,513 checks** and no failures. Independent
readback agreed with all **30 reduced metric values** and **600 copied peer
samples**. These are one Runner and one 4LY Trainer treatment under one seed,
not a replicated comparison between locomotion systems.

| Observed measure | Persistent Scavenger / Runner | Cautious Flyer / 4LY Trainer |
|---|---:|---:|
| Stable occupied bins | 3 horizontal bins | 18 two-dimensional bins |
| Horizontal range | 32.26 cells | 135.19 cells |
| Final displacement from start | 12.47 horizontal cells | 110.64 Euclidean cells |
| Centre path, including gait/bobbing | 197.61 cells | 314.51 cells |
| Active intervals with less than 0.25-cell progress | 111 / 246 (45.1%) | 2 / 270 (0.74%) |
| Selected neutral-intention time | 5.1 seconds | 2.9 seconds |
| Sampled physical drift during neutral intention | 10.40 cells | 6.58 cells |
| Recorded selection-label changes | 25 | 17 |
| Same selected module, changed recorded phase | 1 | 1 |

The Runner's much longer centre path than horizontal range is a useful negative
result: much physical movement was gait, bobbing or revisiting rather than new
territory. Nearly half of its active sampled intervals made little horizontal
progress. Neutral intention also did not imply physical stillness. The flying
actor travelled more widely in this treatment, but comparing these two
different bodies and profiles does not isolate the contribution of memory or
personality. Those questions require the matched ablations.

No home-return failure is established by these two episodes. Persistent
Scavenger has no authored homeward module and did not cross the forty-cell
departure threshold. Cautious Flyer's final exploration drive was **0.524701**,
above its effective homeward trigger of **0.365**, and no homeward intention was
selected. A zero geometric return count is retained as an observation; the
sustained treatments are more relevant to eventual return-home behaviour.

## What the recorded labels can establish

The raw field called `intention_transitions` counts changes in the recorded
selection label. A label can name an urgent reflex, a selected goal-bearing
module, a dominant continuous preference, or a list of blended contributors.
Changes in that list are not necessarily new behavioural commitments.

The two preflights had no blend-to-blend contributor-label changes. The Runner
had thirteen direct transitions between different goal-bearing module labels;
the flyer had one. Each also had one phase transition while the selected module
remained the same. The flyer spent 0.3 seconds in empty-blend intervals. These
distinctions make the timelines more informative than a single transition count.
The trace does not record `goal_key`, so renewed destinations within one module
cannot be counted as distinct goal instances. The independent reader explicitly
returns an unavailable goal-instance count rather than inventing one.

Stable territory is also a bounded approximation. Ground actors use sixteen-cell
horizontal bins and flying actors use a sixteen-by-sixteen grid. Half a second
of cumulative sampled occupancy makes a bin stable, including the starting bin.
A synthetic boundary case occupies two bins through only **0.02 cells** of
horizontal oscillation. Bin occupancy must therefore be read beside actual
range and displacement; bin count times bin width/area is not exact travelled
extent or automatic evidence of exploration.

## Design, cost and interpretation boundaries

Initial native material bytes, full copied actor-pose identities and authored
geometry match within registered groups. Memory, trait/drive and social
ablations retain the original corresponding profile except for their declared
changes. The no-traits treatment disables personality modifiers and accumulated
drives together, so it cannot identify each contribution separately. Legacy
versus stateful comparisons include their declared profile and sensor changes;
the coarse-only arm addresses the additional sensing configuration. Both a
rapid seeded random controller and a one-second held-heading random controller
use legal actions and the same command-renewal cadence.

The common outcome observer receives actual material samples and peer poses
without feeding its results into any controller. Material relocation and route
blocking use ordinary native painting. The peer-departure treatment uses real
actuator motion; whether the peer actually leaves sensory range is measured,
not stipulated. No actor teleports or abstract-agent substitution occur in this
apparatus. Eight remains the maximum instantiated logical population.

The obstruction proxy describes horizontal commanded movement near a copied
wall ray. Moving eight cells from a blocked-approach point within five seconds
is a measured recovery, not proof that the original attraction point became
reachable. Vertical flying obstruction is outside that particular proxy.
Connected peer groups describe actual centres within forty cells, and changing
membership is not proof of cooperation or a shared hidden plan.

All timing values are **elapsed call times** on the execution host. The
production session builds observations before starting its policy timer, so
sensor and decision-core/adapter durations are disjoint and both occur within
production advance. Adding the sensor time to production advance would double
count it. The independent outcome observer is separate evaluation overhead.
These timings are not CPU-utilization measurements, presentation frame times or
owner-hardware performance. For example, the Runner preflight averaged about
1.01 ms for decision/core adaptation and 4.91 ms for sensing, while the flyer
averaged about 0.53 ms and 2.11 ms respectively. Those differently configured
single-actor observations cannot establish population scaling; the registered
eight-actor workloads measure the supported population directly.

The earlier executor reset erased unpushed source and transient development
reports. Reconstructed inputs and fresh receipts have new identities. Earlier
interrupted or invalidly labelled reports remain recorded as lost development
evidence and are never retroactively upgraded to final qualification. The new
retained one-actor held-random preflight is bound to its own source
`c60737e93efc151e1765b09a1bf2e91deb2b58cc`; independent readback verified fifteen
metrics and the corrected count of twenty-nine horizontal stalled intervals.
It remains outside the primary programme.

The 30-, 120- and 300-second episodes support finite observations under their
registered conditions. They do not establish indefinite stability or universal
behavioural superiority. Interesting activity still requires ordinary Workbench
viewing alongside these measurements. Headless traces and hosted rendering do
not establish physical NVIDIA playfeel acceptance.

## Complete local baseline and independent agreement

The source-83a3 local programme completed **122 fresh Worlds and 194 actual
actor episodes**, comprising 178 subjects and 16 passive companion actors.
Its runner completed with exit zero and unchanged final source/runtime custody.
The independent reader accepted the complete registry, checked **2,910 numeric
movement values**, verified **67,200 copied peer samples**, and checked **40
matched ablation groups** against their exact permitted profile edits. All
checks passed. The [independent receipt](evidence/full83a3-independent/receipt.json)
binds the raw report, reducer summary, reader and full JSON/Markdown readback.

The raw report SHA-256 is
`e9d31cfd40ba881753294a2e6ff546722312ec3c61fa16802c6d3c6d8b1a6d5b`;
the reducer summary is
`abacd5f372f45f04e86cde6ff8030478a7103fd4fa128497c94bb9bc5afc0959`;
the independently verified frozen reader is
`c2e0608aff1eebd6a656ace312b6ff41f2fba4d1f0940c2a5219dddb9d55801f`.
No actor centre was recorded outside the canvas in this programme. These are
finite observed episodes, not a proof against every future lifecycle or motion
failure. Local timings overlap other work and are not a clean performance
comparison. Hosted repetitions retain their own source and execution identities.

## What the matched comparisons do and do not show

Stateful profiles are more expressive, but these baseline treatments do not
establish that they explore more territory than their comparators. In the main
three-seed matched treatments, the median paired stateful-minus-memory-disabled
horizontal range is **-12.15 cells for Runner, -4.27 for Monowheel and -4.42 for
4LY Trainer**. The corresponding occupied-bin differences are zero, zero and
minus one. Memory changes decisions and supports historical interests and
failure learning; it does not automatically maximize exploration.

| Main treatment: median across three seeds | Runner X range | Monowheel X range | 4LY X range |
|---|---:|---:|---:|
| Original AMBIENT profile | 35.93 | 34.36 | 52.22 |
| One-second held legal random steering | 65.00 | 63.05 | 84.54 |
| Simple scripted controller | 62.69 | 72.43 | 56.38 |
| New stateful profile, before latch repair | 32.26 | 38.16 | 70.27 |
| Same new profile with memory disabled | 44.40 | 42.43 | 75.03 |

These are per-arm medians. The complete readback separately reports median
paired differences; subtracting two arm medians need not produce the same
number. Each rig has only three independent World pairs per main comparison.
The no-traits treatment jointly disables personality modifiers and drives, so
it establishes a combined configuration effect without isolating either one.
The coarse-only treatment changes near sampling and refinement, not its common
outcome observer. Rapid random steering and one-second held random steering
are both retained because actuator inertia can disadvantage rapid reversals.

The baseline ground stateful profiles stall in 45.1% and 40.1% of active sampled
intervals at their median. The 300-second Monowheel stateful episode reaches
68.3%. Independent investigation found a one-decision obstacle-maneuver latch
defect, retained its original reports, and then qualified the narrow repair in
[nine matched cases](recovery-negative-review.md#subsequent-matched-repair-review).
That repair's positive results do not erase these original negatives or relabel
the baseline's memory and personality comparisons as final-source results.

## Actual remembered withdrawal and home cycles

In the sealed-goal baseline, each of the two seeds records eight internal
failure events and selects finite withdrawals with actual leftward movement of
roughly 44–47 cells for its completed intervals. Memory-disabled controls cannot
record those memories. The blocked-route treatment also shows real withdrawal,
but its retained failure stamps precede the new wall painted at fifteen seconds;
it is not proof of learning that newly painted wall. The source-941b repair
retains the sealed-goal failure counts and actual withdrawal, while the two
blocked-route movement traces remain unchanged.

The 120-second Cautious Flyer baseline gives a directly observable drive/home
cycle. At **44.3 seconds**, exploration drive **0.364987** crosses its effective
homeward threshold of **0.365**, and a homeward intention is selected while the
actor is **152.34 cells** from home. It reaches its twenty-cell arrival band at
60.2 seconds and selects neutral home-rest phases. A later phase from 72.4 to
76.5 seconds, within roughly two cells of home, raises the drive from 0.071323
to 0.440323. Another near-home phase raises it from 0.347983 to 0.716983. The
trajectory contains two forty-to-sixteen-cell geometric home-return crossings.
The memory-disabled version also returns once; homeward behaviour is not
exclusive to spatial memory.

The twenty-cell arrival band differs from the sixteen-cell drive-recharge
distance. Its first selected home-rest phase begins about 19.59 cells away and
the drive continues declining until the actor later rests closer. A home-rest
label therefore does not itself prove drive recovery, resource recovery or
physical stillness. Persistent Scavenger has no authored homeward module; its
zero sustained return count does not indicate a failed homeward attempt.

## Editable personalities under one descriptive condition

Each catalogue subject ran for thirty seconds with one actual passive compatible
companion. These sixteen cases demonstrate editable compositions under one
condition; they are not replicated rankings or guarantees for arbitrary scenes.
The observations below belong to source 83a3, before the narrowed latch repair.

| Profile | Observed tendency in the catalogue treatment |
|---|---|
| Oil Moth | Oil attraction dominates for 21.4 seconds; obstruction escape occupies 8.6 seconds. |
| Shy Crawler | Wanders with material avoidance interruptions; returns near its initial horizontal position. |
| Curious Surveyor | Mixes wandering, material attraction, avoidance and timed rest across 54.58 cells of horizontal range. |
| Idle Mechanic | Selects rest for 12.6 seconds, while still accumulating physical drift and 49.43 cells of total horizontal range. |
| Drifting Flyer | Wanders for 25 seconds with altitude and material responses; occupies nine stable two-dimensional bins. |
| Social Roamer | Alternates dominant following and wandering preferences; high label churn is not evidence of many new goals. |
| Restless Explorer | Explores, records obstruction failures and withdraws; reaches 65.30 cells of horizontal range. |
| Territorial Watcher | Watches its companion for 12.7 seconds and ends only 1.29 horizontal cells from its start. |
| Social Drifter | Spends 9.1 seconds regrouping and 6.3 watching, interspersed with wandering; frequent labels include continuous-preference changes. |
| Timid Follower | Watches for 16.7 seconds, with short distance corrections and following; traverses a smaller 18.10-cell horizontal range. |
| Persistent Scavenger | Alternates novel-patch investigation, unfamiliar-space goals and remembered interests; this treatment exposes the pre-repair steering defect. |
| Routine Patrol | Selects its route for 18.9 seconds and material avoidance for 10.3; full waypoint-route completion is not established by the trace. |
| Independent Wanderer | Selects temporary destinations for 17.2 seconds with material avoidance; no peer pursuit is required. |
| Cautious Flyer | Ranges across 147.72 horizontal cells and eighteen stable two-dimensional bins while mixing exploration and investigation. |
| Boundary Grazer | Selects observed material-boundary following for 7.6 seconds, plus temporary destinations and historical revisits. |
| Homebody Keeper | Selects home-rest for 7.1 seconds alongside short exploration, observation and material investigation. |

Social Drifter's 126 selection-label changes include only three direct changes
between different goal-bearing modules. Timid Follower has 37 approach/watch
phase changes while the same peer-observation module remains selected. These
are useful signs of local correction or chatter, not automatic evidence of
interesting long-lived intentions. Goal-instance identity is absent from the
trace and remains explicitly unavailable. The user-visible entertainment
question requires watching the ordinary authored environments alongside the
trajectory and timeline evidence.
