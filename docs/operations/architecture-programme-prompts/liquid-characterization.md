---
title: Architecture experiment: characterize FreeMass and CellularYield from retained evidence
status: Planned
document-kind: runbook
scope: Self-contained C work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-13
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture experiment: characterize FreeMass and CellularYield from retained evidence

## Identity and dependencies

**Programme status, 2026-09-11:** research completed at `cdb4c2a`;
[acceptance coverage](../../audits/2026-09-11-issue-15-coverage.md) supports
[G-C completion](../architecture-programme.md#g-c-staged-decision-2026-09-11).
No new measurement is required. The original experimental charter below is retained.

Issue: [#15](https://github.com/techrote/cybersand/issues/15).
Programme/workstream: C; [master programme](../architecture-programme.md).
Dependencies: Ready after programme/source intake; reuse #9/#10/#13 and current Water follow-up. No dependency on a wider Cell.

GitHub completion dependencies: None for the initial admitted stage.
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Produce an attributed comparison of present liquid behavior and the minimum new measurements needed to decide which changes deserve testing.

## Why this work exists

The two liquid paths bundle quantity, algorithm, mobility, special cases and sleep. Their similar appearance does not establish equivalent semantics or relative cost.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 now satisfies the support prerequisite only within its documented ordinary rectangle/load envelope; preserve high-energy/general-shape limits.

## Hypothesis / question

Which behavior belongs to partial mass, local redistribution, material-specific transport or the activity scheduler, and is any concrete deficit worth changing?

## Scope

Extract retained metrics first; map all 11 liquid descriptors and special paths; measure only missing sleep-versus-mobility and representative flow/rest/film questions. Classify beneficial specialization, accidental history and genuinely unresolved evidence. Produce per-material decisions, not a winning universal solver.

## Non-goals

No solver replacement, unification, Cell widening, history/velocity, new reaction tuning, barrel repair, broad #9 rerun or new physics backend. These are issue-local boundaries, not permanent prohibitions.

## Repository touchpoints

`native/src/world.cpp`: update_water, transfer_water, update_rule_kernel / flow_as_yielding_liquid, lateral_due, begin_tick/finish_tick; `native/include/cybersand/material.hpp`, `world.hpp`, `physics_diagnostics.hpp`; `native/bench/transport_characterisation.cpp`, `physics_characterisation.cpp`, `water_leveling.cpp`; `tools/physics/issue13.py`, `transport_report.py`, `water_leveling.py`; `godot/scripts/demo_worlds.gd`; existing Water and transport tests.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. Read dated #9/#10/#13 and September 10 Water evidence and record each metric as retained, insufficient or absent. Do not run the old matrices merely to recreate their reports.
2. Follow the current liquid dispatch, including Oil specialization and chemistry-before-motion ordering. Describe whole-cell count accounting separately from Water mass.
3. Register missing cases and primary metrics before instrumentation. Default sleep=3 versus legal quiet threshold >1,800; zero is rejected by World construction. Keep region inclusion fixed. Retain deterministic mobility failures without inventing a stress field.
4. Compare Water, a mobile whole-cell liquid, Paste/Slush and one protected Mercury control on closed basins/ledge/film/support-release cases. Isolate chemistry in separate observations, not hidden transport changes.
5. Produce the evidence/coverage matrix and admit or reject specific precision, memory, presentation or future quantity/yield questions. Keep generalization conditional on explicit quantity/reaction contracts.

## Controlled variables

Changes: Only bounded observation and the registered diagnostic quiet threshold in its own comparison. Production defaults stay unchanged.

Fixed: 4-byte Cell, current three-quarter Water relaxation, mass 8/delay 12/film 48, material/interaction profiles, geometry128/32/64/radius2, input/seeds, workers and fixture horizons. Vary sleep only within paired cases.

## Instrumentation

Reuse PhysicsDiagnostics and TickStats. Count lateral opportunities, mobility failures, successful moves/Water transfers, actual visited cells, active blocks, wake/sleep and late content writes; capture p50/p95/p99/max/total tick cost outside measurement scans. Distinguish scheduled blocks from exact visited-cell work. Observer-off semantic controls are required.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Extract #9/#10 ordered pair/confinement and #13 gallery/transport evidence. Reuse current water_leveling mirrored 48/96-wide basins and existing native film/rest tests. Add one closed yield/sleep test with support removal and wake/re-entry, only expanding if the result is ambiguous.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

A row for every native liquid identifies quantity, kernel exception, lateral mechanism, delay/adhesion, exchange/chemistry and evidence status. All requested behavior/performance dimensions have a retained result, new focused result or explicit gap. Sleep attribution is controlled, not asserted. Current controls remain exact; report source movement relative to historic Water samples. Deliver a neutral next-experiment/no-change recommendation.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

Coverage table with dated source/artifact references; selected raw fixture/timing outputs and observer neutrality; side-by-side normalized behavior table; sleep/late-work traces; gap register and G-C admission notes.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G-C can admit named state/behavior experiments. It does not authorize liquid unification, new generalized FreeMass or a new yield solver.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
