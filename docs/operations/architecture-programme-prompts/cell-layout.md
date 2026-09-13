---
title: Architecture experiment: isolate Cell layout, packing, sidecar and epoch costs
status: Planned
document-kind: runbook
scope: Self-contained L work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-13
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture experiment: isolate Cell layout, packing, sidecar and epoch costs

## Identity and dependencies

**Programme status, 2026-09-11:** research completed at `4726f8d`; #16 closed
as completed after [G-L reconciliation](../architecture-programme.md#g-l-staged-decision-2026-09-11).
The current4-byte layout is the baseline pending G-final, not a permanent
architectural selection. The original experimental charter below is retained.

Issue: [#16](https://github.com/techrote/cybersand/issues/16).
Programme/workstream: L; [master programme](../architecture-programme.md).
Dependencies: Ready after source intake; C can run independently. L evidence is prerequisite to P and M.

GitHub completion dependencies: None for the initial admitted stage.
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Measure raw representation cost and compatibility without adding behavior, separating stride, access packing, optional allocation and epoch clearing.

## Why this work exists

Extra state and solver gains can hide an 8-byte tax; sparse use does not make universal AoS bytes free. The owner explicitly proposed both 8/18/6 and 16/40/8.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 now satisfies the support prerequisite only within its documented ordinary rectangle/load envelope; preserve high-energy/general-shape limits.

## Hypothesis / question

What are the cost, correctness and capacity tradeoffs of 4-byte, packed 4-byte, 8-byte and optional-state layouts at equivalent semantics?

## Scope

Reversible experimental variants and minimal instrumentation: original 4 B; 8 B padded preserving legacy fields; packed8/16/8 control; 16/40/8 using only legacy semantic values; packed8/18/6 with extra bits unused; bounded optional SoA/sparse state controls. Inventory 16-bit ID value and compatibility costs; do not add materials.

## Non-goals

No extra velocity/history, precision change, liquid retuning, render widening, occupancy-in-Cell, catalogue expansion or default scheduler resize. 16/32-byte universal cells and 10/14/8 lossful migration are deferred unless a separate justified charter is recorded.

## Repository touchpoints

`native/src/world.cpp`: World::Chunk::Cell, scan_rect, begin_tick, cell movement/state writes, resident_cell_bytes, content_hash/state_hash; `native/include/cybersand/world.hpp`, `material.hpp`, `scheduler_geometry.hpp`; `native/bench/benchmark.cpp`; `native/tests/test_world.cpp`; `native/include/cybersand/c_api.h`; `godot/native_extension/cyber_native_cell_world.cpp`; `godot/scripts/transport_profiles.gd`; `godot/shaders/material_palette.gdshader`.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. Register semantic comparison records, exact variant mapping and per-stage instrumentation. Audit live state_a/state_b ranges before designing accessors. Keep temporary changes on an experiment branch or build-selected variant.
2. Measure original versus 8-byte padded stride first, confirm sizeof/alignment/array stride and representative generated accesses. Extra bytes remain unused. Do not optimize only the candidate or control.
3. Measure packed8/16/8 against original, then 16/40/8 versus padded8 to expose packing/ID access. Use masks/shifts and deterministic endian encoding, never compiler bitfields or raw-struct serialization.
4. Isolate packed8/18/6 epoch behavior versus packed8/16/8 with unchanged legacy state. Current zero is reserved: first clear at256 then every 255; comparable6-bit first 64 then 63. Instrument each clear including sleeping/region-excluded resident cells and test moved cells are never double-updated.
5. Evaluate sidecar ownership/access with an equivalent legacy-state mapping or clearly labeled neutral synthetic payload; separate absent, allocated-but-unread and actively accessed cases. Cover moves/swaps/splits/reactions/reclaim/saturation. Metadata and address lookup count in cost.
6. Inventory narrow material IDs through descriptors, C ABI, 81-entry profiles/81x81 pairs, RG8 and saves; distinguish capacity headroom from demand. Record 10/14/8 as a non-equivalent alternative unless every current state fits losslessly.
7. Report layout and epoch results separately. Only register a follow-on 64-square storage chunk comparison if profiling justifies it; keep core/activity/radius fixed and repeat both layouts. No default change.

## Controlled variables

Changes: One of stride, packing/ID access, epoch width, or optional-state access/allocation per staged comparison.

Fixed: All legacy material semantics and state precision, normalized initial state, solver order/cadence/profiles, occupancy representation, 128-square storage/32-square activity/64-square core/radius2, snapshots and tick/input schedules. Epoch differs only in its explicit stage.

## Instrumentation

p50/p95/p99/max/total tick and ns/visited cell; per-clear time/identity and ordinary-neighbor tick excess; actual stride/alignment; resident cells/sidecars/metadata/process memory; allocations/high-water/failures; work/event parity; worker scaling. PMU/cache/bandwidth where available, with unavailable counters stated. Verify instrumentation neutrality.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Existing dense/sparse native benchmark at512 and1024 extents with equal inputs, plus retained large sleeping allocation with small active patch. Extend epoch cases beyond2048 ticks, across wrap/seams/sleep/re-entry and prewritten destinations. Optional-state density0/1/5/15/50/100%, clustered/dispersed. Use current Water and reactive material states as correctness controls.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

Controlled variants complete with a lossless semantic comparator; width-only and packing-only variants match content/events/work, while epoch variants preserve behavior despite bookkeeping differences. No overflows/truncation or double updates. Exact clear timeline/tails and full footprint are retained. 16-bit ID need and compatibility cost are explicitly assessed. Report evidence, including negative/ambiguous outcomes, without selecting a production width.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

Variant definitions and source/build identity; semantic parity records; interleaved timing tables; memory/access/epoch graphs or tables; sparse-density crossover; allocator/PMU limits; ID/state compatibility inventory; G-L record.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G-L establishes representation cost and candidate experimental carriers. It does not approve 4-byte retention, an 8-byte migration, shortened epochs or larger IDs.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
