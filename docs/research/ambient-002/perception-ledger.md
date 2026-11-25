---
title: AMBIENT-002 embodied perception and physical experiment ledger
status: In progress
document-kind: research
scope: B lane implementation, bounded local observations, physical campaign registration and retained limits
last-reviewed: 2026-11-25
related-documents: [mission-ledger.md, ../../systems/ambient-actors.md, ../ambient-001/perception-ledger.md]
---

# AMBIENT-002 embodied perception and physical experiment ledger

## Checkpoint: source candidate, execution pending

The lane starts from predecessor branch head
d0af9b6015c27417fddd67f79afdcf656a609571. The qualified AMBIENT-001
application f4f94631d61d492554627949497e727b26043ccb and its evaluator are
untouched. The local executor became unavailable during intake, before edits.
The implementation is therefore constructed as immutable Git objects through
the repository connector. No local execution or graphical pass is claimed.

The lead owns final integration into a new Draft/HOLD successor and source-bound
hosted qualification. This document records candidate source contracts; only
dated receipts may upgrade an execution claim.

## Implemented candidate observation changes

V1 profiles retain the four-cell material lattice. V2 profiles opt into
spacing_cells (requested coarse resolution 1–4), near_radius_cells (0–16),
and refine_boundaries. All material reads share one 4,096-site cap per decision.
A dense near-field disk finds thin cells that the old lattice misses. A bounded
5-by-5 patch around each observed material and four immediate neighbors refine
the nearest sample and a local estimated boundary normal/tangent.

When the requested coarse radius/resolution would exceed the cap, the effective
spacing is explicitly increased. The algorithm keeps spatially uniform coarse
coverage instead of silently truncating toward a raster corner. It reports
requested/effective resolution, actual reads, refinement/near-field reads,
coverage completeness, and unavailable/stale/incomplete states. Remote thin
features between coarse sites can still be missed. A material boundary is local
evidence and supplies no passage or global reachability proof.

The physical rig offers two optional ground or eight optional two-axis terrain
rays, with at most 32 cells of clearance measured from a conservative attached
hull extent. These are separate from the existing motor sensing allowance.
A canvas-clipped empty ray is unknown, never certified free space. These center
rays are not a swept-volume planner. Ground alternatives remain horizontal.

Peer sensing accepts copied owner observations with the same run, epoch and
physical tick. It examines at most 32 candidates and returns the nearest seven,
retaining the authoritative eight-actor host limit. The larger input budget is
an explicit future compatibility seam, not permission to instantiate more
actors. Copied velocities have their own availability. Authored tags produce
affinity -1/0/+1, with avoidance winning a conflicting preference. Invalid,
stale, disappeared and truncated candidates make coverage incomplete.

## Integration interface

The session calls Perception.settings(profile) and supplies the result under
context.perception. An empty dictionary selects the unchanged V1 sampler.
Perception.wants_navigation(profile) recognizes enabled steer_obstacles and
withdraw_obstruction; only these modules request the optional terrain fan.

PhysicalActorRig.ambient_navigation_observation(32.0, canvas_extent, vertical)
returns navigation.directions containing direction, available, hit,
clearance_cells, maximum_distance_cells, normal and bounded source geometry.
The session passes this copied dictionary, validated regions, authored relations
and the World generation to observe. A new World generation is exposed to the
memory owner; unavailable identity remains -1 rather than an invented generation.

Material target boundary is a copied dictionary with available, position,
normal, tangent, checked_neighbors and source. boundary_normal and
boundary_tangent aliases are supplied only when observed. Generic enabled
module material_id/radius parameters now register sensing requests without
depending on a closed list of module names.

## Registered qualification

The new test_ambient2_spatial.gd contains:

- Thin near-field detection and an explicitly retained remote-thin-feature miss.
- Complete local absence versus incomplete sampled non-observation.
- Fresh/stale/unavailable publication handling and generation replacement.
- Budget coarsening, malformed setting refusal and generic module requests.
- Peer tags, affinity conflicts, disappearance, stale identity, velocity absence,
  copy isolation, nearest selection and a finite future candidate seam.
- Actual Rapier wall, free direction, two/eight-ray and canvas-clipping checks.
- Separate 1/4/8-query population cost microbenchmarks for V1 and V2 sampling.

The microbenchmark counts logical sensor queries, not physically instantiated
actors. It must not be used to claim larger actor capacity. The physical campaign
will independently identify at least 100 actual actor episodes across matched
baseline, stateful, memory, drive/personality and social ablations; register
initial-state equality and actual native/Rapier completion before reducing it.
Thirty-second, two-minute and sustained horizons are separate arms. Negative
behavioural findings remain results, not fixture failures to optimize away.

Report environment: CYBERSAND_AMBIENT2_SPATIAL_REPORT.
Terminal completion marker: AMBIENT2_SPATIAL.
Run with the pinned Godot and source-matched native/Rapier runtime.

## First actual Linux spatial execution

The executor recovered. The first parser attempt correctly failed on two new
fixture variables whose Dictionary return values needed explicit annotations;
it established no completed cases. After those fixture repairs and a reviewed
zero-weight sensor-request optimization, the source-hashed run completed **2,644
checks with zero failures**, including actual Rapier terrain queries. The
[compact receipt](evidence/spatial-first-linux.json) retains tested file hashes,
runtime identity, command, watchdog and the explicitly named local delta. It is
not the final integrated committed-source qualification.

The hosted query microbenchmark measured approximately 0.40–0.42 ms per legacy
observation and 1.17 ms per adaptive observation at radius50, near8, refinement
enabled. Adaptive sampling read about 1.42 times as many unique sites and used
about 2.8 times the wall time. At eight actors and ten decisions per second this
is approximately 94 ms of elapsed sensor-call time per simulated second, before policy
or physics. V2 remains explicit opt-in; this is a material cost tradeoff, not a
performance win or physical display acceptance. The all-actor physical campaign
must measure progression separately.

## Initial physical campaign registration and smoke at 2e5f4676

The new `test_ambient2_episodes.gd` runs the production physical session with a
fresh native World and Rapier World2D per campaign. Its initial registry contained
95 campaigns and 137 actual actor episodes, with at most eight actors live:

| Hypothesis family | Actual actor episodes | Controls and scope |
|---|---:|---|
| Main embodied comparison | 63 | Seven arms, three rig families, three seeds, 30 seconds each: legacy personality, legal seeded random, accepted scripted, stateful, memory disabled, personality/drives disabled, and coarse sensing |
| Local social activity | 32 | Four actors, four controls, two seeds, 30 seconds: legacy, stateful, social modules disabled, random |
| Adverse material and route | 12 | Sealed attractive material, moved material, newly blocked route; stateful/memory-disabled, two seeds, 30 seconds |
| Actual departing peers | 8 | Two actual actors, stateful/social-disabled, two seeds; one peer moves through legal actuators after half the horizon |
| Existing supported capacity | 16 | Eight real Runner actors in a native courtyard, two seeds, 30 seconds |
| Sustained episodes | 6 | Stateful/memory-disabled: Runner and Trainer for 120 seconds; Monowheel for 300 seconds |

Matched groups compare exact initial native publication bytes, complete physical
actor poses, velocities, resource states and geometry before advancing. A common
independent Oil/Water observer covers radius50 with the same sampling settings
for every control. Causal ablations retain the base profile and material request
scope. Legacy/new system comparisons intentionally retain their documented
profile/sensor differences; the coarse-only arm exposes that sensing difference.
Random and ambient share authored seed values but use declared different stream
mixing. No cross-platform physical bit determinism is claimed.

Default smoke executes 13 actual actors across nine fresh campaigns for two
seconds each. The initial integrated-source local smoke completed **5,091 checks,
zero failures**, all 13 command/physical horizons, and the applicable initial
state comparisons. This run used integrated c814fe1d plus the uncommitted harness
and is an implementation checkpoint, not final source qualification. Its first
attempt failed parsing one inferred Boolean variable; after explicit typing the
complete run passed. Set `CYBERSAND_AMBIENT2_EPISODES_MODE=full` for the registered
long campaign, `CYBERSAND_AMBIENT2_EPISODES_REPORT` for the checkpointed JSON;
completion terminal is `AMBIENT2_EPISODES`.

Every report separates native ticks, actual Rapier ticks, completed simulation
time, real parts/masks, native-step and physics-step cost, production policy
stage cost, per-actor policy/sensor cost, and independent observer overhead.
The trajectory records retain actual body path and drift during neutral commands.
The analyzer treats ground exploration as horizontal territory with dwell, so
vertical gait movement alone cannot inflate explored area. Physical peer range
loss is measured; a requested departing command is not proof the peer escaped.

## Expanded frozen registration

Independent review added a one-second held-random control, matched eight-actor
legacy comparisons, and a descriptive subject from each of sixteen ordinary
editable presets. The registry now has **122 fresh World campaigns and 194 actual
actor episodes**: 178 subjects and sixteen explicitly auxiliary passive
companions. At most eight actors are instantiated at once. Registered totals
are 6,720 actor-simulation seconds and 4,560 World-simulation seconds; these
remain planned horizons until execution completes.

| Hypothesis family | Campaign clusters | Actor episodes |
|---|---:|---:|
| Eight main controls, three rigs, three seeds, 30 seconds | 72 | 72 |
| Four-actor social controls, two seeds, 30 seconds | 8 | 32 |
| Three adverse environments, two controls and two seeds | 12 | 12 |
| Actual peer departure, two controls and two seeds | 4 | 8 |
| Eight-actor legacy/stateful populations, two seeds | 4 | 32 |
| Two-minute Runner/Trainer and five-minute Monowheel | 6 | 6 |
| Sixteen catalogue subjects with actual passive companions | 16 | 32 |

Both random controls renew legal commands every six physical ticks. random
resamples at 10 Hz; random_hold retains each seeded heading for one second.
The latter prevents gains from smoother steering being interpreted as general
intelligence. Catalogue subjects share geometry, initial state and seed within
locomotion. Their companions are embodied auxiliary observations, not additional
treatment replicates. One descriptive sample per personality cannot establish
robust superiority or entertainment value.

## Executor reset and evidence loss

The executor disconnected and its temporary filesystem was replaced before the
expanded full campaign began. Work was recovered from durable remote checkpoint
35187eda and retained code, first in 50c8bd1a (apparatus) and 3ed2467b (runner,
reducer and synthetic tests). Reconstructed files have new identities. They are
not asserted byte-identical to lost local c9d24c71. No missing raw evidence has
been recreated. Root published the recovered implementation at
6244b075ca16b3714fd8e1b971ed7624c1c83008.

The following observations were reported before reset, but their local raw files
are unavailable. They are **reported-only development observations**, excluded
from final committed-source physical qualification:

- Initial smoke reportedly passed 5,091 checks with local harness changes after
  one parse failure. Its original console and JSON were lost.
- A single-process full attempt reportedly exited 137 after three completed
  30-second campaigns. Its partial report was lost. Memory pressure was plausible
  but not established as the cause; no full pass was claimed.
- An isolated stateful development shard reportedly passed 7,513 checks with local
  changes. Its original report was lost.
- A catalogue social attempt used a padded nonexistent SHA beginning 8572b67a.
  It was identity-invalid before its loss and never qualified.
- Held-random preflight at lost local c9d24c71 reportedly passed 7,812 checks,
  1,800 native/Rapier ticks and 300 commands, with 30 correctly held windows and
  matching raw/reduced horizontal stall counts of 29. Its report and plots were
  lost; they do not substitute for a fresh source-bound run.

Previously committed compact spatial receipts and hosted workflow evidence are
distinct durable sources and remain available. No absent physical trajectory is
inferred from them. Recovery freshly reran all ten synthetic reducer/custody
tests successfully; those tests are explicitly not physical actor episodes.

## Isolated execution and independent reduction

tools/ambient/run_episodes.py obtains the source-generated registry and executes
each World in a fresh pinned Godot process. It requires actual git HEAD, clean
committed execution inputs, the existing evaluator's complete source and loaded
project manifests, pinned official engine identity, and retained native/Rapier
provenance. Complete custody is checked at start/end; observed source/runtime
bytes are rechecked around every shard. There is no local-delta qualification mode.

Original reports, consoles and execution receipts are retained per attempt.
Resume requires their hashes, original aggregate receipt hashes, matching
terminal fields, exact registered identity and completed native/Rapier horizons.
Registry generation executes zero physical episodes. Complete remains false
until every registered campaign has joined.

tools/ambient/analyze_episodes.py validates source inventory, exact registration,
actor rosters, native/physics ticks and command budgets before reducing actual
traces. Ground stall and home distance use horizontal progress; flight uses two
dimensions. Physical path retains gait and neutral-command drift. Occupied
16-cell bins require 0.5 seconds cumulative dwell, include the starting bin and
can be affected by small motion across a grid edge. Their nominal extent is not
exact traversed area; x-range and displacement must accompany it.

The production source builds the environment before timing the decision core
and adapter. Sensor and decision costs are disjoint and both included within
production advance; the independent outcome observer is evaluation overhead.
Actual one/four/eight-actor workload costs retain their identities. Profiles and
layouts differ between some cohorts, so mixed population medians are not
controlled asymptotic scaling evidence.

Outputs include source-bound JSON, actor and trajectory CSVs, full-canvas
trajectory maps, intention timelines and sixteen catalogue subject maps.
Forty-cell connected peer groups are descriptive spatial components, not a
human sociability or believability score. Actual ordinary Workbench graphical
inspection and physical Windows/NVIDIA owner acceptance remain separate.

## Canonical integration preflights at 9278de57

Fresh execution at canonical published source
9278de5757b29b9df40a089e11a4daef744990f7 completed two 30-second stateful
integration shards: Runner/persistent_scavenger and 4LY/cautious_flyer. Each
completed 7,513 checks, 1,800 actual native/Rapier steps and 300 admitted
commands. Full source/project/engine/runtime custody agreed before and after.
These two local episodes are outside the primary hosted 194-episode programme.

The [archive manifest](evidence/canonical-9278-local/archive-manifest.json) binds
losslessly compressed original reports and full custody, original process logs
and receipts, the exact local driver, and reduced metrics. No original is
replaced with a reconstruction or assigned a different source identity.

The Runner covered a 32.26-cell horizontal range and three stable occupancy
bins, selected five module labels with 25 label changes, and stalled in 45.1%
of active sampled intervals. Its total center path was 197.61 cells, illustrating
why center path alone is not exploration. The flyer covered a 135.19-cell
horizontal range and eighteen stable two-dimensional bins, with seventeen
selected-label changes and 0.74% active stalls. Neither returned home during
these short horizons. No comparative superiority follows from two integration
examples without their matched controls.

The exported intention_transitions metric counts changes of the selected label,
including changes in a blended label. It does not identify new goal instances
within the same module. Material distance metrics refer to actual observed
sample sites; finite coarse coverage cannot prove the absence of thinner
material patches between sites. These limits also apply to the final reduction.

The Runner's 5.1 seconds of neutral intention still contained 10.40 cells of
sampled physical drift; the flyer's 2.9 seconds contained 6.58 cells. Neutral
intent is therefore visibly distinct from guaranteed stillness. The recorded
policy/sensor/physics timers are elapsed invocation time, not OS CPU-accounting
utilization. The full matched hosted programme remains the scientific authority.

