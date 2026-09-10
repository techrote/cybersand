---
title: Architecture experiment: reconstruct fractional liquid interfaces without changing simulation
status: Planned
document-kind: runbook
scope: Self-contained V work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture experiment: reconstruct fractional liquid interfaces without changing simulation

## Identity and dependencies

Issue: [#19](https://github.com/techrote/cybersand/issues/19).
Programme/workstream: V; [master programme](../architecture-programme.md).
Dependencies: Blocked by C's mass/presentation case definitions. Independent of L/P/M production selection; optional history-assisted presentation may follow M evidence separately.

GitHub completion dependencies: [#15](https://github.com/techrote/cybersand/issues/15)
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Compare current appearance with oriented fractional coverage on identical authoritative frames, including directionally ambiguous cases.

## Why this work exists

Water already stores fractional amount. Bottom-fill everywhere fails underfaces and side boundaries; a larger simulation Cell is not required to evaluate presentation.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 is administratively closed but the intake source/evidence still documents missing bearing and barrier-aware ejection; preserve that unresolved distinction.

## Hypothesis / question

Does local mass-gradient reconstruction improve visible surfaces and droplets enough to justify its rendering and snapshot cost?

## Scope

Current dither/binary comparison, fractional coverage and local 3x3 gradient/interface reconstruction on frozen frames; gravity/centered-droplet fallback for ambiguous topology. Optional transient flux or a narrow field derived from useful M history is a second separately measured stage.

## Non-goals

No change to material/mass/activity/collision, authoritative orientation, universal velocity, full-Cell GPU upload, connected-component centroid classifier, body rendering system or production renderer replacement.

## Repository touchpoints

`godot/shaders/material_palette.gdshader`; `native/src/world.cpp`: copy_rgba and render copy paths; `native/include/cybersand/render_snapshot.hpp`, `native/src/render_snapshot.cpp`; `godot/native_extension/cyber_native_cell_world.cpp`; `godot/scripts/simulation_worker.gd`; `godot/tests/test_native_render_bridge_regression.gd`, `test_render_patch_handoff_regression.gd`; `docs/systems/material-appearance-and-rendering.md`.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. Register frozen mass/material frames from current 8-bit Water and visual metrics at 1x and 4x display scale. Establish what RG8 condition currently encodes before exposing any new data.
2. Implement a selectable experimental presentation path using normalized fill and a local gradient; choose interface offset to approximate area. Test top/underside/vertical/diagonal boundaries and adjacent continuity. Do not mutate mass to smooth normals.
3. Define deterministic fallback for weak gradients: gravity for settled surfaces, centered droplet for isolated tiny cells, with declared visibility/area compromises. Avoid centroid classification.
4. Hold simulation frames and input fixed across render modes. Measure added CPU snapshot copy, bytes/upload and shader/GPU time separately; do not infer GPU savings from smaller dirty patches since current GPU upload is full RG8.
5. Only if topology ambiguity remains material, register optional transient flux/historical-direction input. Keep flux disposable and nonauthoritative; stored M history must first justify itself for simulation. Bound publication and consumer lag; no mutable reads.
6. Retain actual screenshots/video and numerical area/temporal comparisons. Recommend continue/retain without changing production defaults.

## Controlled variables

Changes: Presentation reconstruction only; optional narrow flux publication in a separate stage.

Fixed: All material/state/temperature, tick/input/profile, collision/activity/epoch and simulation hash. Same frozen frames, viewport and display scale per pair. Compact immutable handoff preserved.

## Instrumentation

Per-cell and aggregate rendered coverage error versus normalized mass on synthetic frames, boundary discontinuity/orientation failure count, frame-to-frame flicker on fixed/known sequences, CPU copy and snapshot bytes/high-water, actual upload size and render timing where measurable. Authoritative content/hash and activity equality across display options.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Synthetic top/underside/left/right/diagonal interfaces, U-shaped cavity,1-cell jet, isolated 64/255 and tiny droplets, supported slope films, adjacent unlike materials; current basin/ledge frames. Check1x/4x scales, delayed render consumer and publication failure/retained dirty patches. Do not require the unavailable W images.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

Identical authoritative input produces identical authority/activity in every mode. All orientation and ambiguous cases are shown, including negative visuals; area/visibility compromises are quantified. Immutable payload regressions pass; actual native desktop and both Web presentation paths have scoped visual/cost evidence if proposed for those targets. No wider Cell inference is drawn.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

Frozen frames and source identity; screenshot/video pairs, coverage/artifact table, timing/bytes with GPU gaps, hash/activity equality, immutable-handoff checks and G-V presentation recommendation.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G may admit an independent render migration. Presentation success cannot approve wider Cells, persistent history or altered mass semantics.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
