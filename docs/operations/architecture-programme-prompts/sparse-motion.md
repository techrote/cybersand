---
title: Architecture experiment: gate and test bounded sparse ballistic material transfer
status: Planned
document-kind: runbook
scope: Self-contained B work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture experiment: gate and test bounded sparse ballistic material transfer

## Identity and dependencies

Issue: [#20](https://github.com/techrote/cybersand/issues/20).
Programme/workstream: B; [master programme](../architecture-programme.md).
Dependencies: Implementation blocked by C/L/P/M evidence and G-B admission. Design/admission can inspect I's recovered proposal and existing #12. Do not require arbitrary generated bodies; use current rectangle values only.

GitHub completion dependencies: [#18](https://github.com/techrote/cybersand/issues/18)
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Produce either a justified no-go or one bounded proof that sparse event-driven motion plus safe reinsertion solves a named unmet high-speed requirement.

## Why this work exists

I recommended ballistic material before coherent detachment because continuous travel need not enlarge cellular worker writes. Later Water/Bytes evidence may meet the actual need more cheaply; that must be tested first.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 is administratively closed but the intake source/evidence still documents missing bearing and barrier-aware ejection; preserve that unresolved distinction.

## Hypothesis / question

Does a sparse promoted representation justify its ownership, sweep, lifecycle and memory cost versus local history/current transport for a defined event?

## Scope

Admission and reviewed transfer charter first. If admitted, one nonreactive material, one bounded event emitter, a fixed native pool, continuous/fixed-point positions and velocities, swept grid/barrier/rectangle-mask collision, and bounded near-rest reinsertion. Preserve material/state and temperature where applicable; add Water only as a separately admitted fractional-ledger case.

## Non-goals

No production ballistic migration, unlimited particle objects, automatic fallback for every overlap, arbitrary coherent bodies, registry expansion, full DamageEvent/destruction framework, general reactions, fracture, torque or new physics backend.

## Repository touchpoints

`native/include/cybersand/world.hpp`, `native/src/world.cpp`: serialized explosion/event boundary, cell transfer, activity and failed state; `native/include/cybersand/physics_diagnostics.hpp`, `c_api.h`; `godot/native_extension/cyber_native_cell_world.cpp`: prepare_rigid_body_coupling / rasterization/reconciliation; `godot/scripts/rapier_physics_bridge.gd`; `native/bench/physics_characterisation.cpp`, `godot/tests/test_physics_characterisation.gd`, `tools/physics/water-accounting.json`. Any new ballistic module is proposed, not an existing file.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. At G-B register the event, why local M/current motion cannot satisfy it, measurable target and bounded costs. Without that evidence close no-go successfully. Do not claim I's recommendation is authorization for an unconditional production system.
2. Review a singular-owner contract: cells own before promotion; reserved slots own nothing; after revision/capacity checks at exclusive boundary commit extraction and transfer authority to pool. Failed admission leaves cell intact. During flight pool owns payload; reinsertion reserves a legal destination and commits once. Failed placement retains particle/pending owner and reports deferral, never expires material away.
3. Start with research budgets of 256 pool slots, 64 promotion attempts/tick,64 grid crossings/particle/tick and 8-cell reinsertion search; register exact deterministic behavior when a budget is hit. These are experiment limits, not accepted production constants. No unbounded per-tick allocation or global sparse-world scan.
4. Use event-provided motion with declared units (cell pixels/s, fixed 60Hz step) and deterministic slot/event ordering. Swept collision must check intervening hard cells; reaching traversal budget defers travel, not skips barriers. Reuse immutable rectangle occupancy; central reaction impulses may remain disabled and must be labeled.
5. Test saturation, stale source revision, cancel, reinsertion full, region exit, failure quarantine and repeated promote/demote. Keep compact material payload/temperature and quantity ledger exact; motion rounding/loss is a separate account.
6. Compare matched controls and sparse/dense event load. Do not turn all no-destination cases into silent deletion or unlimited particles. Report continue/no-go with cost and uncovered production cases.

## Controlled variables

Changes: Explicit sparse representation/motion and transfer semantics; comparison is a feature experiment, not raw Cell-width measurement.

Fixed: Current underlying Cell/layout control, liquid/powder policies, scheduler geometry, main-thread Rapier, source event inputs, bounded occupancy and no full-world scan. No semantic changes to cells not promoted.

## Instrumentation

Ownership census before/after every transfer, material/state/temperature/quantity totals, pending/refused counts and reasons; event/handle determinism; trajectory/range/swept barrier results; motion quantization; pool/queue/scratch high-water, work per tick, allocations and p50/p95/p99/max/total cost. Include baseline plus whole-system promotion/lookup/render costs.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

One event ejects selected nonreactive grains horizontally/diagonally into hard thin barriers and the current rectangle mask; low/high load and pool saturation, near-rest return, entirely full return region, negative/core/chunk seams and offscreen pause/re-entry. Reuse known barrier ejection fixture as a separate current defect control, not a candidate success target by relabeling.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

Admission is justified or no-go explicitly recorded. If code is admitted, every material unit has exactly one owner throughout; repeated/saturated/failed transitions never lose/duplicate payload or tunnel through untested path. Declared budgets bound work and deferred motion is visible. Repeat/worker parity holds for native decisions; any adapter use has desktop/Web timing evidence. Quantify benefit/cost and do not approve production automatically.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

G-B admission/no-go record, reviewed transfer state table with capacity/failure paths, exact fixture ledger and trajectory comparisons, resource/performance results, source/artifact identity and limitations, recommendation for G and #12 energetic reversal.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G can reject/defer sparse motion or scope later production work. #12 may consume proven motion transfer only if selected; near-rest soliding remains independently possible.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
