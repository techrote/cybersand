---
title: Architecture experiment: compare compact liquid flow memory inline and in sidecars
status: Planned
document-kind: runbook
scope: Self-contained M work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture experiment: compare compact liquid flow memory inline and in sidecars

## Identity and dependencies

Issue: [#18](https://github.com/techrote/cybersand/issues/18).
Programme/workstream: M; [master programme](../architecture-programme.md).
Dependencies: Blocked by C, L/G-L and P/G-P. Must register a concrete directional-persistence target; if no useful target is justified, close with no-go evidence.

GitHub completion dependencies: [#17](https://github.com/techrote/cybersand/issues/17)
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Determine whether a minimal material-local decaying flow history adds useful motion, and whether inline or sparse storage is appropriate for the same semantics.

## Why this work exists

Current native horizontal transfer has no persistent momentum. Neither wider cells nor transition proposals prove that every cell needs vx/vy.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 is administratively closed but the intake source/evidence still documents missing bearing and barrier-aware ejection; preserve that unresolved distinction.

## Hypothesis / question

Can quantized direction/strength/age improve a specified jet or spray behavior while retaining bounded writes, mass accounting and stable equilibrium?

## Scope

No-history control; one minimal direction/strength/age history candidate for Water, then one representative whole-cell liquid using the same declared history intent. Separate the semantic comparison from the inline-versus-sidecar comparison. Limited body/event input values are permitted only in fixtures with named units.

## Non-goals

No universal velocity field, pressure solver, ballistic pool, unification, fracture, new Rapier coupling production path or mandatory history for every material. Full quantized vx/vy requires a separate admitted experiment; issue-local scope is not a permanent ban.

## Repository touchpoints

`native/src/world.cpp`: update_water, transfer_water, try_move, move/state paths, update_rule_kernel, activity effects and hashes; `native/include/cybersand/world.hpp`, `transport_policy.hpp`; `native/bench/transport_characterisation.cpp`; `native/tests/test_world.cpp`; `godot/scripts/transport_probe.gd`; existing optional temperature ownership as a sidecar precedent.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. Register behavior target and minimal bits/units: for example direction 3, strength 4, age 3, with explicitly preserved mass/delay fields. Choose values from P, not because a40-bit budget exists.
2. Specify history creation from actual transferred quantity/motion; split/merge weighting, competing directions, clipping, decay, source-empty reset, destination moves/swaps/reaction conversion, sleep/re-entry and field reclamation. Call decaying bias a gameplay approximation, not conserved momentum.
3. On one fixed layout compare no history versus history, with radius1 liquid writes and catalogue maximum2 unchanged. History must decay rather than impose a permanent travel-budget equilibrium forbidden by ADR-005.
4. At identical history semantics and precision compare inline versus bounded optional block/chunk SoA or sparse indices; carry state correctly through moves/merges and retain source on capacity failure. Count all bookkeeping and wake work.
5. Compare on Water, then a representative whole-cell liquid in its own controlled arm. Preserve each path's intended rest/heap behavior and trait semantics; no claimed universal winner.
6. Publish successful/negative motion and storage crossover results. Identify separately whether any high-speed event need remains for B. If a candidate cannot regain equilibrium, report rejection instead of raising a timeout to hide it.

## Controlled variables

Changes: First presence of declared local history; then storage placement only, with identical history semantics. Per-material path is a separate comparison.

Fixed: Selected precision and delay from P (or8-bit reference), width/access from L for semantic phase, geometry/epoch/input/order, protected #10/#13 policies and exact Water mass. No long-range movement, copied descriptor fields or persistent render-orientation field.

## Instrumentation

Registered directional COM/range/jet reach and decay time, mirror asymmetry, split/merge history error, exact mass/species/temperature, content rest and work, density/time occupancy of history, inline/sidecar memory, lookup/transfer cost, p50/p95/p99/max/total tick and lifetime allocations.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Matched left/right horizontal injection, vertical fall over ledge, opposing streams and fractional split/merge; closed basin/rest/film, support loss and narrow barrier/seams. Reuse transport Mercury/powder/player preservation cases and sidecar density sweep from L at selected densities. New fixtures only for missing direction and history transfer paths.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

A concrete behavior benefit target was declared before candidates, and met/missed/ambiguous is reported. History is material-local with complete transfer/decay semantics and bounded lifetime. Exact mass and ordinary protected references remain correct. Inline/sidecar comparison uses identical semantics; negative/no-go is a complete outcome. Any residual high-speed need for B is explicit.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

History bit/semantic table, fixture inputs/traces, target comparison and visual pairs, ownership/capacity tests, exact-state worker checks, density/time crossover and total cost, G-M admit/retain/defer note.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G-M can retain no history, recommend a bounded history carrier, or admit a distinct B question. It does not approve universal vx/vy or production liquid changes.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
