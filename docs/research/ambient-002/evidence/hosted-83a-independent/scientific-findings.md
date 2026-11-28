# AMBIENT-002 baseline 83a: independent perception and physical readback

This document qualifies the frozen baseline before the finite steering-latch correction. It preserves both successful mechanisms and poor outcomes. It does not transfer qualification to a later application commit. All numerical tables below use the hosted Linux execution unless explicitly marked local.

## Evidence and scope

Application source: `83a3db6ffb207761df999abedac77eb1401604a8`; tree `9037dc374a782d60df116e1731a05abacb54a6cf`. The [hosted original artifact](https://github.com/techrote/cybersand/actions/runs/45536810257/artifacts/14988238799) has SHA-256 `996c30c61f2edc55cc51d6467652ceb5b128e4ac678809d35e1898214365a199`. The independent local original archive is preserved in [two verified byte parts](../local-83a-complete/README.md).

Each execution completed 122 fresh World campaigns and 194 actual actor episodes, including 178 subjects and 16 auxiliary passive catalogue companions. The registration covers eight main controls/ablations, social and social-disabled populations, sealed/moving/blocked goals, actual departing peers, matched eight-actor capacity controls, six sustained episodes and all 16 editable presets. The programme contains 4,560 World simulation seconds and 6,720 actor simulation seconds. The largest simultaneous population is 8. No abstract agents contribute to these counts.

The independent custody audit verified all 122 original report/console/execution receipt chains and terminal/source identities, 1,141 committed source inputs, 855 loaded project inputs, official pinned Godot bytes and native/Rapier provenance. Re-running the frozen reducer and separate independent reviewer on the hosted originals produced byte-identical summaries. The independent reader checked 2,910 metric values and 40 exact ablation-group configurations. Exact hashes and per-case comparisons are in `artifact-verification.json` and `receipt-chain-and-repeat.json`.

## Re-execution variability

Only 23,252 of 67,200 corresponding position samples were bit-equal between local and hosted execution. Exactly 44 of 194 complete actor traces were equal. The maximum corresponding-position difference was 118.9871706506662 cells; 6,220 selection labels and 3,591 phases differed. Initial material publications, complete initial pose hashes, geometry and authored profiles matched in every case. This is observed variation across hosts with the same pinned Linux binaries; it is not a cross-platform determinism guarantee or evidence of altered initial conditions. The seeded procedural choices remain explicit inputs, while embodied feedback can diverge.

Population cases are especially sensitive: none of the 32 four-actor social, 32 eight-actor capacity or 8 departing-peer actor traces were exactly equal across hosts. The main cohort retained 37 exact traces out of 72. Conclusions below use within-execution matched cases; local and hosted copies are not added as 194 extra independent experimental conditions.

## Exploration controls and retained negatives

The eight main arms each have three separately initialized seeds per rig. The legacy/new comparison changes the profile and controller observation scope, so it is a whole-system comparison. Within-new ablations retain the initial authored profile and declared scope. `no_traits` disables personality modifiers and drives together; it cannot isolate each trait independently. `random_hold` retains a seeded heading for one second while legally renewing commands every six physical ticks, avoiding the inertia confound of only comparing against 10 Hz jitter.

| Rig | Legacy X range | 1 Hz held random | Scripted | Stateful | Memory off | Traits/drives off | Coarse only |
|---|---:|---:|---:|---:|---:|---:|---:|
| runner | 35.60 | 65.18 | 63.73 | 31.99 | 42.80 | 33.02 | 50.39 |
| monowheel | 34.36 | 63.05 | 96.79 | 38.16 | 42.43 | 41.27 | 43.36 |
| 4ly_trainer | 52.22 | 84.54 | 56.38 | 70.27 | 75.03 | 116.56 | 72.57 |

Values are median horizontal ranges in native cells over 30 seconds. Stateful profiles do not generally explore more than smoother random or scripted controls. Median paired stateful-minus-memory-off range differences are −10.81 cells for Runner, −4.27 for Monowheel and −3.55 for Trainer. Remembered interests can anchor behavior; a memory feature is not automatically an exploration improvement. Baseline ground steering also chatters near obstacles, so additional selected-label transitions can indicate a defect rather than richer activity. The integrator tested a narrow finite steering latch separately and must qualify that later source independently.

The longer trials retain negative outcomes: the 300-second stateful Monowheel occupies 3 stable horizontal bins, spans 40.18 cells and stalls in 68.3% of active sampled intervals. Its memory-disabled counterpart spans 49.91 cells and stalls in 52.3%. These figures count horizontal progress, excluding vertical gait. A long center-path length must not be relabelled exploration.

Bounded memory does have physical function in adverse cases. Both hosted sealed-goal seeds record 8 actual internal failure events and 6.8 seconds of selected withdrawal. Both blocked-route seeds record 5 failures and 9.1 seconds of selected withdrawal. Moving-material seeds record 0 failure events and 0 withdrawal selection. These are the internal memory counters and selected modules; the separate wall-proxy entry count is not a count of distinct failed attempts. Retiring from a barrier does not make the original sealed target reachable.

The 120-second stateful Trainer selects home-seeking for 26.2 seconds and completes 2 sampled geometric departure/return cycles, with 183.32 cells of horizontal range and 35 stable two-dimensional bins. Its memory-disabled counterpart completes 1 cycle. The ground scavenger has no home module and no qualifying 40-cell departure, so its zero home-return count is not failure. Independent intent/drive review is required to distinguish a requested homeward action from an accidental geometric return.

## Perception coverage and measured cost

The frozen spatial suite passed 2,644 checks, including actual owned Rapier ray observations and copied raw material-ID contracts. The controlled thin-feature case places a one-cell material at (33, 32) next to observation center (32.5, 32.5): the legacy four-cell lattice misses it, while the dense eight-cell near field reports center (33.5, 32.5). A one-cell feature at (73, 32), 41 cells away, remains missed when it lies between coarse sites; coverage is explicitly incomplete. Boundary refinement starts from an observed match and cannot discover an arbitrary missed distant island. These are copied-publication contract fixtures, not additional physical actor episodes.

Every adaptive material query has a 4,096 unique-cell read cap. Requested dense spacing that exceeds the cap is uniformly coarsened with an explicit resolution-limited flag. Unobserved incomplete coverage, exact observed absence, stale data and unavailable data have different semantics. Optional actual terrain observations spend 2 horizontal rays for ground actors or 8 compass rays for flying actors, at most 32 surface-relative cells. A ray is local center-line clearance; it is neither a swept-hull certificate nor a global route. Ground ledge avoidance remains a separate supported observation/reflex.

The hosted radius 50 copied-publication microbenchmark measured 489 reads and 0.262 ms wall time per legacy query, versus 697 reads and 0.771 ms per adaptive query at logical population 1. That is 42.5% more reads and 2.94 times the measured query invocation time. At logical population 8 the averages were 492.25 versus 696.75 reads and 0.263 versus 0.781 ms. These logical loops instantiate no actors; they are not population capacity evidence.

Actual physical main episodes give the more useful comparison below. Coarse-only retains the new profile and observation scope while disabling the dense near field and boundary refinement.

| Rig | New sensor ms/decision | Coarse-only sensor ms/decision | New decision-core/adapter ms/decision |
|---|---:|---:|---:|
| runner | 1.480 | 1.215 | 0.353 |
| monowheel | 1.419 | 1.151 | 0.344 |
| 4ly_trainer | 1.314 | 1.064 | 0.332 |

The additional near/refinement observation costs about 0.25–0.27 ms per decision in this workload. It does not produce a universal gain in explored range; the thin-feature contract improvement and its bounded cost are the supported reasons for the configurable mechanism. Sensor and decision timers are disjoint elapsed invocation durations, both inside production advance. They are not operating-system CPU utilization. Independent outcome sensing is evaluation overhead.

## Populations and collective activity

At four actual actors, stateful grouped-actor fractions are 96.92% and 89.08% for seeds 605 and 1701, versus 81.08% and 64.00% with social modules disabled. However, jitter-random reaches 90.17% and 100.00% while travelling little. A 40-cell connected proximity group is not evidence of friendship, shared intent or entertainment. The archived formation counter includes groups already present at time zero and exact membership-set changes; the later candidate adds explicit initial-component fields without rewriting these originals.

At eight actual actors, stateful proximity fractions are 87.33% and 74.83%, below the legacy control values 91.54% and 85.17%; several mixed-profile inhabitants range more widely. In the actual departing-peer cases, stateful fractions are 24.00% and 18.67%, below 35.33% and 42.33% with social modules disabled. The departing peer really moves through legal actuators; this is an observed range-loss test, not a fabricated disappearance. Keep these counterexamples. Actors in one World share interactions and do not constitute independent statistical replicates.

| Eight-actor workload | Legacy median | Stateful median |
|---|---:|---:|
| Sensor elapsed ms/simulated second | 45.231 | 116.476 |
| Production advance elapsed ms/simulated second | 190.654 | 285.102 |
| Native elapsed ms/tick | 0.168 | 0.176 |
| Rapier elapsed ms/tick | 1.451 | 1.499 |

The matched eight-actor sensor workload is about 2.58 times legacy and production advance about 1.50 times legacy. These are bounded costs, not zero-cost intelligence. One/four/eight workload layouts and profile mixtures differ, so their medians do not establish asymptotic scaling. Same-tick decisions may produce bursts. The 512 × 256 headless physical corpus does not establish 60 FPS presentation in larger ordinary scenes. The authoritative host limit remains 8; the 32 candidate/nearest 7 peer-copy seam is not a capacity increase.

## Editable catalogue observations

Each row is one 30-second descriptive subject with a real passive compatible companion, under matched geometry within locomotion. These are ordinary editable profiles, not bespoke actor controllers. The table describes this condition; it is not a replicated personality ranking.

| Profile | X range | Intentional neutral seconds | Two most selected module labels (seconds) |
|---|---:|---:|---|
| oil_moth | 35.20 | 0.0 | seek_material(21.3); escape_obstruction(8.7) |
| shy_crawler | 34.52 | 2.6 | wander(22.7); avoid_material(2.8) |
| curious_surveyor | 54.78 | 6.2 | wander(22.6); seek_material(3.7) |
| idle_mechanic | 49.40 | 12.8 | wander(14.4); rest(12.7) |
| drifting_flyer | 52.22 | 1.6 | wander(25.0); maintain_altitude(2.2) |
| social_roamer | 26.15 | 0.1 | follow_actor(15.6); wander(14.4) |
| restless_explorer | 65.79 | 2.9 | explore_unfamiliar(14.8); withdraw_obstruction(9.1) |
| territorial_watcher | 35.97 | 14.1 | observe_actor(17.9); wander(10.0) |
| social_drifter | 33.01 | 6.3 | wander(11.6); regroup(8.3) |
| timid_follower | 17.89 | 15.5 | observe_actor(14.1); wander(9.2) |
| persistent_scavenger | 31.99 | 5.1 | explore_unfamiliar(18.3); investigate_material(8.3) |
| routine_patrol | 22.67 | 1.4 | patrol_route(19.0); avoid_material(9.6) |
| independent_wanderer | 44.64 | 0.1 | exploration_destination(18.0); avoid_material(7.5) |
| cautious_flyer | 147.72 | 3.1 | explore_unfamiliar(19.2); investigate_material(4.8) |
| boundary_grazer | 100.36 | 3.2 | exploration_destination(13.2); follow_material_boundary(7.4) |
| homebody_keeper | 36.19 | 8.9 | exploration_destination(9.5); seek_home_drive(7.1) |

The catalogue shows distinct activity levels and selected mechanisms: resting, observing peers, patrolling, following a material boundary, revisiting interests and seeking home are visible in the raw decision timelines. High transition counts in social profiles also include arbitration churn; the legacy `intention_transitions` field counts selection-label changes, not distinct temporary-goal instances. No `goal_key` was recorded, so same-module new-goal counts cannot be reconstructed. A neutral intention does not guarantee physical stillness; momentum and gait drift are retained in the raw data.

## Ordinary Workbench graphical review

All 29 original Linux PNGs were hash-verified and visually inspected, covering the five preserved examples, six new native environments, four authoring tabs and overlays. The scenes are legible side elevations; flood-yard water visibly changes between authored and playing states. Actual actor poses and material/pose publication identities are recorded in the capture report. Crowded courtyard labels overlap at Overview scale, and actors are small in the larger scenes; Focus and zoom are useful for observing individuals.

The six new playing snapshots reach 121 native/physical ticks, roughly 2 seconds. They establish initial mounted rendering and progression, not sustained entertainment. The renderer is llvmpipe through X11/OpenGL compatibility, and physical-display acceptance is explicitly false. The question of whether the settlements remain interesting during a long ordinary play session needs the later sustained observer/owner evaluation. This audit does not claim NVIDIA playfeel acceptance.

## Evidence boundaries

Physical trajectories, internal commitments, memory counters and native material samples substantiate meaningful stateful mechanisms. They do not justify a universal claim of better exploration, navigation, sociability or entertainment. Stable ground bins use horizontal 16-cell intervals and ignore vertical gait; flight uses 16 × 16 bins, with 0.5 seconds cumulative dwell. The starting bin counts, and grid-edge oscillation can populate adjacent bins. Pair bins with actual range and displacement. Material-distance outcomes refer to observed sampled sites, not exhaustive nearest materials. Homeward intention and geometric home proximity require separate interpretation.

The full baseline is retained because it exposed a concrete steering-retention defect and the limits of several attractive summary metrics. The subsequent finite-latch candidate, its physical comparison and its full qualification must keep their own exact source identities. No prior evaluator is changed by this documentation checkpoint.
