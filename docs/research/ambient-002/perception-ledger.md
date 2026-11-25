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
16-cell bins require 0.5 seconds cumulative dwell; the starting bin is eligible
under that same rule. They can be affected by small motion across a grid edge. Their nominal extent is not
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

## Complete baseline programme and independent hosted readback

Frozen source `83a3db6ffb207761df999abedac77eb1401604a8` completed the
registered 122 fresh World campaigns and 194 actual actor episodes locally:
178 subjects plus 16 real passive catalogue companions, at most eight actors
in any World. All 30-second, 120-second and 300-second horizons completed.
The programme advanced 273,600 native and Rapier steps, accepted 62,400 legal
commands, rejected none, and recorded no actor-center canvas incidents.
Whole-source/project/engine/runtime custody matched before and after.

The [complete local archive](evidence/local-83a-complete/README.md) preserves
all original process reports, consoles and execution receipts, complete
custody, aggregate, final runner receipt, reduced metrics and five figures.
Its 20,808,554-byte ZIP is retained as two consecutive byte parts because the
GitHub connector limits request bodies to 16 MiB. The reconstructed SHA-256
is `7cbe9d219568f911573a72b3e07a29bfd030e6de40cd07c889e88feb4ce9be7c`.
The earlier 19-case partial archive remains an explicitly incomplete checkpoint.
Local elapsed timings after approximately 03:20 UTC were contended by a
separate authorized targeted probe and are not clean performance estimates.

Hosted run 45536810257 also completed this same registered programme.
Artifact 14988238799 was downloaded once and verified against SHA-256
`996c30c61f2edc55cc51d6467652ceb5b128e4ac678809d35e1898214365a199`.
The independent [hosted audit and scientific readback](evidence/hosted-83a-independent/scientific-findings.md)
verified all 122 original receipt chains, 1,141 committed source inputs and
855 loaded project inputs. Re-running the frozen reducer and independent
reader produced byte-identical hosted summaries; the reader checked 2,910
metric values and 40 exact ablation groups. All 29 original Linux graphical
captures were hash-verified and visually inspected; the renderer was llvmpipe,
and physical-display acceptance remains false.

The two physical executions are not bit-identical: only 23,252 of 67,200
corresponding position samples and 44 of 194 complete actor traces match
exactly. Initial materials, complete initial poses, profiles and runtime
bytes do match. The largest corresponding-position difference is 118.99
cells. The audit retains every per-case comparison. Neither this variability
nor the second execution creates extra independent registered cases.

Retained negatives include weaker main-case exploration than held random,
negative paired memory effects on horizontal range, poor sustained baseline
Monowheel progress, lower grouping for some social treatments, and additional
sensor cost. Hosted eight-actor sensor elapsed time rises from 45.23 to
116.48 ms per simulated second, while production advance rises from 190.65
to 285.10 ms. These are elapsed invocation costs, not OS CPU utilization or
presentation acceptance. Positive evidence includes actual obstruction
withdrawals, differentiated editable catalogue mechanisms, and a sustained
flying home-seeking cycle. The report keeps these mechanisms separate from
claims of general superiority or entertainment.

The baseline exposed the steering-retention defect. Its original source,
plots and negative outcomes remain unchanged; the later finite-latch
candidate and its qualification have separate identities.

## Final registered source and independent science

Application `a7250e15495667b2fcf564cbed1eaa8dea217c45`, tree
`a038e6df65d58529f4c496c01f26c65975654fa6`, completed the full Linux/Windows
campaign in workflow `45540569052`. The final Linux primary programme retains
the same 122 registered fresh Worlds and 194 physical actor episodes: 178
subjects and sixteen passive companions. All 4,560 World-simulation seconds,
6,720 actor-simulation seconds and 273,600 native/physical steps completed.
There were 62,400 accepted commands, zero rejected commands and zero recorded
actor-center canvas incidents. This is not 194 independent treatment replicates.

The [final independent scientific findings](evidence/hosted-a725-independent/scientific-findings.md)
bind all 122 original report/console/process chains, 1,143 committed source
inputs, 855 loaded project inputs, and pinned engine/native/Rapier identities.
The frozen reducer and independent reader reproduced the hosted outputs
byte-for-byte; independent readback covered 2,910 metrics, 67,200 copied-peer
samples and forty exact ablation groups. Only the bounded steering-latch source
and its pure living-engine regression differ in loaded application inputs from
the hosted 83a baseline. Matched initial native bytes, full poses, geometry and
authored profiles agree across all 122 baseline/final cases.

Final main stateful active-stall medians are 8.37% for Runner and 8.05% for
Monowheel. The matched held-random and scripted controls still explore farther
than these ground profiles. Paired stateful-minus-memory-off horizontal-range
medians are only +0.313, +0.074 and 0.000 cells for Runner, wheel and flyer;
subtracting cohort medians would falsely suggest a typical large flyer gain.
The sealed-goal and blocked-route conditions show useful physical withdrawals,
but no proof of global reachability. In the final blocked-route traces, the
remembered failures were last seen at 12.6 seconds, before the new wall at
15 seconds; later withdrawal reuses those failures rather than proving that
the particular new obstruction was learned.

Final eight-actor production sensor elapsed time is 102.381 ms per simulated
second versus 38.090 for the matched legacy comparison; complete production
advance is 242.979 versus 158.524 ms. These are actual embodied workloads in
512-by-256 headless fixtures, not OS CPU accounting or presentation acceptance.
The one/four/eight-actor and per-rig costs, social counterexamples, mixed long
episodes, all sixteen descriptive catalogue observations and actual neutral-input
drift remain in the final tables and original traces.

## Actual native thin-patch proof

The [one-step native diagnostic](evidence/native-thin-a725/README.md) runs the
unchanged final application under complete before/after source/runtime custody.
It admits one actual 4LY Trainer, completes one native and one Rapier step, and
queries only the production owner's copied numeric material publication and
public admitted pose. It adds zero behavioral episodes.

A whole Oil cell sits outside the copied hull, with independently verified
2.521293640137-cell separating-axis clearance. Identical pose/publication/scope
queries miss it with the 489-read coarse arm and observe it with the 677-read
near-eight/adaptive arm. A far one-cell Water patch remains unobserved under
both, explicitly in incomplete coverage. The warm repeated owner-call medians
are 884 and 1,216 microseconds; they exclude progression, publication copy and
the verification scan, and are separate from actual production decision cost.
The original nine-member archive, full publication bytes, process console,
custody and exact external diagnostic sources remain retained. Specialist A's
independent scan/SAT/sample-union readback corroborates these results without
another engine run.

## Complete final artifact preservation and closing review

The [complete original Linux artifact](evidence/hosted-a725-complete/README.md)
retains all 42,774,281 original ZIP bytes from artifact `14990266435`, including
all 719 entries and the 119,644,773-byte aggregate physical report. Its SHA-256 is
`eac23768f3b18dc95a35554328f700daa8a81fa9920bab39fa7148aca1958e30`.
Five consecutive raw byte parts, a size/hash/offset manifest and a streaming
reconstruction helper are uploaded as immutable Git blobs. No ZIP member was
regenerated or recompressed. The aggregate SHA-256 remains
`090394a0a0f7e7a876481c935fcd2245691bf38a30f24f3c602dd5cd92c5b894`.

A later executor reset erased the first downloaded copy and its locally split
parts before upload completed. The same original GitHub artifact was recovered,
its outer size/hash verified again, and all five earlier recorded Git blob
identities reproduced exactly. No lost commit is claimed and no simulation was
re-executed. All thirteen previously uploaded final-science files and the full
native-thin diagnostic were already safe remotely and were restored byte-exactly.

The [scoped packet readback](evidence/b-final-packet-review.json) records the
exact reviewed packet hash, accepted quantitative groups and two corrected
measurement descriptions: the starting bin must earn its dwell, and an
eight-cell recovery tests displacement from the obstruction-entry point rather
than direction away from a wall. The packet preserves the substantial
23,252-of-67,200 equal-position/44-of-194 equal-trace host-variability negative.
Windows/extraction qualification and the later graphical section retain their
separate specialist receipts.

## Sustained ordinary Workbench observation

External observer `2eea3dbb921058db418fbb243b4abc493cddbdb9` completed
workflow `45544614719` against unchanged application a725. Three ordinary
Workbench Worlds contain eight, six and eight actual inhabitants in Common
Ground, Pipe Orchard and Foundry Row. Each completes 3,601 native and physical
ticks, approximately 60.0167 simulated seconds, with 61 retained samples and
actual rendered PNGs. These observations are separate from the primary 194.
Artifact `14992866806` is 66,483,275 bytes, SHA-256
`907f8bcdd11ef4c7150dc252844ec8545a0a7a46e66abf41ff10e889ad868cef`.

The [independent copied-physics readback](evidence/graphical-watch-independent/physical-readback.json)
retains every selected actor's sampled position/intent/peer/material trace and
all twenty-two actors' range/displacement summaries. Sample counts are not exact
phase durations or distinct-goal counts. All 1,342 current copied poses agree
with the capture report's current-pose records, while displayed actor-frame
identities can lag one tick; those are deliberately separate observations.

Common Ground's Social Drifter has a sampled 145.82-cell horizontal range and
73.98-cell net horizontal displacement. Positive-affinity copied peers expand
from actor 2 to actors 2/3/4. Actual forty-cell proximity components repeatedly
change membership; 75% of post-start actor snapshots lie in a component of at
least two. The real Follow frames show approaching, watching and separating
bodies. This is legible local social activity, without a matched ablation
or evidence of cooperation, persistent leadership or faction causality.

Pipe Orchard's scavenger spans only 45.25 horizontal cells despite 417.63 cells
of summed one-second horizontal travel. Fourteen supported failure events and
repeated investigation/revisit/withdraw snapshots accompany visible returns to
the cabinet. The pattern is understandable but repetitive, and not successful
entry into an unreachable attraction. Its material identity comes from copied
Oil observations, never inferred from frame colors.

Foundry Row's flyer spans 115.42 horizontal and 38.74 vertical cells. It explores,
is constrained near a beam, selects home seeking, then home_rest before resuming
exploration. The homeward interval is physically visible, but the body settles
about 16.49 cells from the authored target. Specialist A verifies the scene's
20-cell arrival criterion versus the core's 16-cell recharge criterion; the
exploration drive actually declines during sampled home_rest. This is a retained
arrival/recharge inconsistency, not a successful replenishment claim.

All three observations use llvmpipe with actual 1920-by-1080 frames. Whole-run
elapsed times are 660.633–675.928 seconds; the last Play-relative sample is at
634.475–649.399 wall seconds. The earlier two-second final Linux captures take
14.368220–17.065526 seconds for 120 physical and 119 copied native ticks, with
per-scene median rendering callbacks of 117.192–139.010 ms. Initialization,
capture overhead, native material evolution and software rendering prevent
these from being isolated policy costs or owner-hardware playfeel acceptance.
Sampled timelapses are assembled from real PNGs, not continuous-video or FPS
evidence. The material/actor labels and diagnostic overlay can overlap even in
Follow view; the original frames and these limitations remain available.

## Coherent home rest: exact final-source requalification

The actual Foundry negative above motivated one shared-rule correction. The
engine now uses the exact selected, enabled, positive-weight home module's
validated arrival radius only while its admitted phase is `home_rest`, with
current copied physical containment still required. Ordinary neutral rest
retains sixteen cells. Drive rates, physical laws, rigs, sampling, scenes and
profiles are unchanged. The prior-intent integration rule across observation
gaps remains explicitly documented; it does not prove continuous rest during
unobserved time.

B independently reviewed the exact engine/test source and the separate one-word
editor-help correction. The [focused original readback](evidence/b-home-recharge-focused-readback.json)
verifies actual Linux 648 living and 895 predecessor core checks, and the old
a725 engine failing exactly five new recharge assertions under the identical
new test fixture. These focused tests add no physical episode count. The
preserved old failure was not overwritten or relabeled.

Application `50c6df89528dc9ecdc5316d8c67abf203e192254`, tree
`d9740be7cafb8ac7b7d6eee4a16219989745fd95`, completed full run
`45552786466` on Linux and Windows. B independently read Linux artifact
`14995028842`: 42,796,506 bytes, SHA-256
`e96d284ac7e44eea93ff9269461166a09cc40b8a352893cb43dc9975c24bf9ac`.
All 719 original members pass CRC. The full Linux 24-case campaign has 15,349
checks and zero failures. Original logs, process receipts, unique completion
markers and parsed reports agree. All 29 graphical capture hashes and their
copied material/displayed-actor identity contracts agree.

The [final scientific readback](evidence/hosted-50c6-independent/scientific-findings.md)
uniquely joins all 122 physical process receipts to the 194-actor aggregate,
checks 2,910 independently recomputed metrics, 67,200 copied-peer samples and 40
exact ablation groups, and reproduces both hosted analysis outputs byte for
byte. The original raw aggregate is 119,622,604 bytes, SHA-256
`1cfb085b65c9fbf295294fbf5360d7d8f0ac78f9b95039c384fe416bdc889137`;
summary SHA-256 is
`298cc3977a5c318ab8530e983a05ce9c298f17a105a5690fd4bb3018b1938a91`.
All 1,143 qualified source and 855 loaded project inputs agree across actual
headless, graphical and physical receipts. Relative to a725, only the three
approved Godot files differ; the separate qualification-request source marker
is explicitly pinned too. B's local mutable checkout was used only for
SHA-pinned Python analysis, never represented as a clean runtime qualification.

The [old-to-new tables](evidence/hosted-50c6-independent/old-to-new-comparison.md)
retain unchanged main-policy medians, paired memory/trait/perception contrasts,
adverse cases, social/grouping outcomes and catalogue physical/selection
summaries. The two 120-second flying trajectories differ. Stateful now reaches
193.009 horizontal cells/38 stable bins, 1.35% active stalls and one 16-cell
geometric return; memory-disabled reaches 168.660/36 bins, 1.01% stalls and two
returns. The old two-versus-one return comparison reverses, so it is not retained as
a memory advantage. Both new flyers have two accepted twenty-cell home-rest windows,
each gaining approximately 0.36 drive over four seconds. Their fixed sixteen-cell
crossings occur later under exploration or material investigation. Those
geometric counts are deliberately distinct from intentional home arrival/rest.
The blocked-route failure records still last occur at 12.6 seconds, before the
new wall at 15 seconds; later withdrawal does not demonstrate new-wall learning.

In this a725/50c6 pair of source-specific executions, 66,213/67,200 copied positions and
191/194 complete trace records match. Only the two long-flyer position traces
change; Homebody Keeper has a drive-only trace difference. This does not erase
the earlier same-source host-variability negative or promise bit determinism.
Eight-actor stateful production sensor/core/advance costs are 116.613/30.797/
285.319 milliseconds per simulation second; native/Rapier calls are 0.181/1.476
milliseconds per physical tick. These are actual elapsed-call costs, with
sensor/core nested in advance. Hosted timing differences are not isolated
causal performance changes or owner display acceptance.

External observer `52900f9d8ead1f6d0b3c4ae6fbdc1e0ac049ce4b` repeated only
Foundry at the new frozen application in run 45552888360. The [independent B
physical readback](evidence/graphical-watch-50c6-independent/physical-readback.json)
confirms identical copied initial states for all eight actors and exact actor 7
positions at all 53 requested seconds 0–52. Its 49–52 sampled path remains
0.00420945 cells. At 48–51 the actor remains inside the authored 20-cell arrival
and outside the separate 16-cell metric while exploration drive rises
0.324055→0.594055; the old trace declined. Later divergence is described without
attributing every future difference to recharge. The direct inspected evidence
is the new contact sheet and original frame 50, alongside all numeric samples;
C independently preserves all 61 images and the entire distinct observation
artifact. This is separate qualitative evidence, not additional registered
physical-treatment credit.

B directly inspected all five final scientific figures, which preserve the
full 512×256 canvas, honest short ground extents, exact selected-module labels,
and the near-stationary random social control. The complete final Linux
original artifact is now [durably retained in five raw byte parts](evidence/hosted-50c6-complete/README.md)
with an actually executed reconstruction verifier. The compact 49-member
original-custody/analysis archive is 1,875,766 bytes, SHA-256
`3e7c4004182fc539259b9b575527eb0b5490bde651a1ad82fa11b262eb8fe606`.
All source-specific earlier evaluators, local/hosted raw campaigns, thin-patch
proof, curiosity supplement and adverse findings remain preserved. Thin-patch
and curiosity execution remain attributed to a725, not relabeled as 50c6. B
performed no new engine execution during this final artifact audit. The
qualified population limit remains eight and successor disposition Draft/HOLD.
