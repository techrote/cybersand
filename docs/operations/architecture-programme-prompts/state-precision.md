---
title: Architecture experiment: measure liquid state precision at fixed layout and semantics
status: Planned
document-kind: runbook
scope: Self-contained P work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture experiment: measure liquid state precision at fixed layout and semantics

## Identity and dependencies

**Programme status, 2026-09-11:** C/G-C and L/G-L are complete; #17 is unblocked
but not started. See the [staged review](../architecture-programme.md#g-c-staged-decision-2026-09-11).
Use one controlled experimental carrier. No production Cell-width selection or
migration follows from this prerequisite update; the experiment below is unchanged.

Issue: [#17](https://github.com/techrote/cybersand/issues/17).
Programme/workstream: P; [master programme](../architecture-programme.md).
Dependencies: Requires completed C evidence and G-L equivalent-layout evidence, now satisfied. Use reference 8-bit mass if another result remains ambiguous.

GitHub completion dependencies: [#15](https://github.com/techrote/cybersand/issues/15), [#16](https://github.com/techrote/cybersand/issues/16)
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Quantify what mass and auxiliary precision buy, independently from Cell width and solver/motion changes.

## Why this work exists

Fractional rendering may need fewer levels than stable mass transport. Higher precision can prolong low-value activity; fewer mass bits might instead lose films or stall transfers.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 is administratively closed but the intake source/evidence still documents missing bearing and barrier-aware ejection; preserve that unresolved distinction.

## Hypothesis / question

Which of 4/6/8/10 mass bits and a separately packed coherent-delay field preserve useful liquid behavior and at what total-work cost?

## Scope

One fixed experimental layout, current FreeMass algorithm parameterized by quantity scale, precision-aware diagnostics and separately isolated4-bit versus 8-bit Water coherent-delay packing. Map useful local-state budgets without allocating generic fields to other materials.

## Non-goals

No Cell-size bake-off, solver unification, true yield or velocity, generalized reaction accounting, permanent precision selection or visual-only justification. Three/twelve-bit endpoints only if needed to locate an observed failure boundary.

## Repository touchpoints

`native/src/world.cpp`: liquid_mass, transfer_water, update_water, write_cell, coherent state merges, transport hooks; `native/include/cybersand/material.hpp`; `native/bench/water_leveling.cpp`, `transport_characterisation.cpp`; `tools/physics/water_leveling.py`, `transport_report.py`; `native/tests/test_world.cpp`; `godot/native_extension/cyber_native_cell_world.cpp`: emit_disc.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. Consume C/L and register one layout and fixed control algorithm. If layout is not selected for production, that is acceptable; all arms use the same carrier.
2. Define Mmax=2^b-1, physical fill=m/Mmax, input quantization and integer ledger. Use common exactly representable initial conditions where practical (full cells/representable fractions); otherwise log initial rounding separately from runtime drift.
3. Preserve physical film 48/255 and rest tolerance1/255 as closely as each integer lattice permits, documenting rounding. Preserve12 elapsed ticks of coherence and viscosity rate; normalize optional pickup/disturbance thresholds if an interaction arm is admitted.
4. Run the mass4/6/8/10 screen with unchanged three-quarter redistribution. Quantization creates zero-transfer/stall edge cases: record them, do not silently add minimum transfers or new sleep logic.
5. In a distinct second screen compare normalized tolerance to literal-one-unit tolerance at each scale; do not mix their conclusions. Test original versus4-bit Water delay independently with mass 8 and identical max-on-merge/pre-decrement semantics.
6. Only after isolated results assemble candidate18/40-bit budgets that retain every necessary state, including coherence or an explicitly registered replacement. Existing16-bit examples in the conversation were sketches, not permission to drop delay.
7. Record useful precision, costs and unresolved tradeoffs; preserve an exact8-bit oracle.

## Controlled variables

Changes: Mass precision/quantization only in first screen; tolerance policy only in second; coherent-delay physical packing only in third.

Fixed: One layout/epoch scheme, current local flow algorithm, no direction state, descriptors, fixture geometry, gravity, normalized initial volume, physical thresholds where representable,12-tick delay and current supported-film semantics. Other material states stay unchanged.

## Instrumentation

Exact integer quantity per arm every tick, normalized physical totals and initial error; rest/column spread/front/discharge; film lifetime/residue count; visited/active-cell work, transfers, wake/sleep, p50/p95/p99/max/total time. Record meaningful mass-bit changes without claiming byte-bandwidth savings inside a fixed 8-byte carrier.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Reuse current mirrored/signed48/96 basins, closed rest, supported slope film, ledge/drop/spray, boundary/worker parity and coherent emission/merge tests. Minimal new low-quantity opposing/adjacent pairs expose stalls and one-unit rounding. Reacting liquids are observations only unless a source/sink model is explicitly added in separate work.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

All four main precisions have normalized behavior/cost and exact integer accounting results. Initial quantization is separate from drift; threshold policies are separate. Delay12 is bit-equivalent at 4 versus 8 bits, and other material state cannot truncate. Report film/rest/front losses as results, not repaired semantics hidden in a precision benchmark.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

Registered scaling/rounding rules; precision and delay tables; per-tick quantity/rest/work outputs; matched images/frozen states where useful; input/runtime manifests; G-P state-budget recommendations.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G-P chooses an experimental precision budget for M or retains mass 8. It does not choose a Cell width or authorize approximate production conservation.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
