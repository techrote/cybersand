---
title: AMBIENT-002 independent scientific review
status: Current
document-kind: evidence
scope: Source-bound independent apparatus and preflight interpretation; not full campaign or gameplay acceptance
last-reviewed: 2026-11-25
---

# Independent AMBIENT-002 scientific review

This checkpoint independently reviews the physical apparatus and two local
integration episodes at source `9278de5757b29b9df40a089e11a4daef744990f7`.
It does not claim completion of the primary 194-actor programme, the graphical
campaign or the portable Windows evaluator. The post-run reader has its own
source identity, `4dc10266053cac98d6a9bb445f05ca1ef2431f41`, and does not alter
the actors whose traces it reads.

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
