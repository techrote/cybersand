---
title: Physics: design and prototype reversible soliding for Rapier aggregates
status: Planned
document-kind: runbook
scope: Self-contained R work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-13
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Physics: design and prototype reversible soliding for Rapier aggregates

## Identity and dependencies

Issue: Existing [#12](https://github.com/techrote/cybersand/issues/12).
Programme/workstream: R; [master programme](../architecture-programme.md).
Dependencies: Existing #12 under #8. Candidate/design stage uses #9 findings and #10 policy. **#11 support prerequisite is satisfied within the documented ordinary rectangle/load envelope.** Dynamic implementation still requires a reviewed ownership ADR. M/B only block energetic reversal that needs their capability.

GitHub completion dependencies: None for the initial admitted stage.
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Execute existing #12 in bounded stages, establishing whether one coherent island can transfer ownership to a Rapier proxy and reverse safely without cementing loose material.

## Why this work exists

I proposed native material membership, exact-ish occupancy masks and simplified Rapier shapes. Existing #12 already owns that investigation; no duplicate body workstream is needed.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 now supplies only the documented ordinary rectangle/load support prerequisite; preserve its high-energy/general-shape limits.

## Hypothesis / question

Does a native-owned coherent representation solve a demonstrated case with safe topology/ownership handover, and what can remain cellular or a stationary proxy?

## Scope

Follow existing issue #12's candidate diagnostics, stationary proxy, reviewed ownership ADR and conditional one-island/one-barrel near-rest dynamic/reversal proof. This supplement reconciles the four investigations and does not silently broaden or replace its scope.

## Non-goals

No global unsupported=>dynamic rule, universal structural integrity, full fracture, arbitrary large body count, mandatory ballistic tier, automatic sleeping-body rebake, per-cell Rapier objects, replacement Rapier or claimed exact replay.

## Repository touchpoints

`native/src/world.cpp`, `native/include/cybersand/world.hpp`: cell state, activity, region/event boundaries; `godot/native_extension/cyber_native_cell_world.cpp`: parse_body_states, prepare_rigid_body_coupling, rasterize_body_sweep, reconcile_swept_overlaps, get_hard_surface_chunk_rectangles; `godot/scripts/rapier_physics_bridge.gd`: terrain budget/result application; `godot/scripts/simulation_worker.gd`, `web_demo_controller.gd`; `native/bench/physics_characterisation.cpp`, `godot/tests/test_physics_characterisation.gd`; `docs/operations/physics-characterisation-plan.md`.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. Re-read #12 and the current #11 repair evidence. Treat the ordinary rectangle/load support prerequisite as satisfied only in that measured scope; do not generalize it to soliding ownership or aggregate mechanics.
2. Use face-connected membership, actual mutation/rest evidence, material eligibility and bounded dirty ROI. Sleep/offscreen exclusion does not earn rest or cohesion. Screen existing proposed rest 0.5/2/5s, occupancy 0.8/0.9/0.98 and area 16/64/256 only as necessary; never automatically glue loose powder.
3. Stationary proxy retains native cells as the only material authority; excavation/reaction/support change invalidates it. Name one owner of each support/contact mode so colliders and impulses cannot double solve.
4. Before dynamics, review ADR describing native exact material/state membership, Rapier transform/velocity/collision proxy and separate transient occupancy. Use a small existing-capacity proof; registry>16, buckets and arbitrary contour decomposition need evidence, not automatic implementation. Document generation handles if slots are reused.
5. Preflight slots, membership, geometry, commands and destination budgets. Source cells remain owner while a revision-checked proposal is prepared. Coordinate stale static-terrain removal/rebuild, disabled dynamic creation and acknowledgement, then exclusive commit plus endpoint/pending mask activation; never expose a hole or let the body collide with its old terrain. Reservation/proxy mask is not a second material owner.
6. On cancellation/stale acknowledgement/capacity failure retain or restore the precommit source without double ownership; after commit retain native membership until a valid reversal commits. Define adapter compensation and quarantine explicitly; do not promise global tick rollback.
7. Reversal reserves placement/overflow first and retains the body if impossible. Preserve material IDs, all selected compact state, Water quantity where eligible and temperature. Use near-rest restriction/error policy unless a proven M/B carrier is selected. Parent-body motion can supply v+omega cross r with declared units; no universal cellular velocity prerequisite.
8. Test one island and barrel, rotated repeated transfers, support loss, seams, stale handles, cancellation and capacity saturation. Only after useful evidence propose later masks/fracture/torque work.

## Controlled variables

Changes: Only the currently admitted #12 stage; transition semantics are explicit and separate from Cell/liquid experiments.

Fixed: ADR-007 authority split, main-thread Rapier, #10 pair/player policy, scheduler radius/geometry, exact payload accounting, F01/F02 and current narrow render handoff. No automatic adoption of I's representation hierarchy.

## Instrumentation

Candidate churn/eligibility/mutation and ROI work; proxy invalidation latency; owner/membership/quantity census; pending command generations/acks; static/dynamic collision overlap/gap duration; geometry error, pool/scratch/queue high-water, material conservation and p50/p95/max stage cost. Keep source/artifact/platform/sample-age identities.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Existing P4/P5/P6 body, excavation, seams, stale samples, Water global accounting and failed-world probes. Add minimum one coherent island and one loose pile, repeated rotated promotion/near-rest demotion, no-capacity/stale-ack/cancel cases. Model the I slab/granular release/sleeping beam/excavation examples as CyberSand goals only if admitted; no external source retrieval.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Run meaningful focused correctness, deterministic repeat and one/four-worker tests; exact quantity accounting every tick where applicable; behavior and performance A/B. Use content_hash for rest and matching-tick state_hash only where schemas/ABI match. Compare normalized semantic records when width/epoch/ABI intentionally differs; current Windows/Wasm raw state hashes are not universally comparable. Check observer-off neutrality and relevant failure/region/capacity regressions. For changed adapter/render behavior rebuild and validate desktop async plus real Web compatibility/threaded profiles, recording unavailable targets rather than inferring acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

Existing #12 acceptance remains authoritative; this supplement requires stage admissions, no false rest/cohesion, singular material authority, no stale-terrain self-collision/hole at commit, conserved payload through repeated/saturated/refused reversal and bounded deterministic outcomes. #11 satisfies only the ordinary rectangle/load support prerequisite; all aggregate ownership and reversal gates remain. Negative feasibility or narrower stationary-only outcome is recorded for explicit scope review.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

Reviewed ADR, stage gate/eligibility table, exact ownership/quantity/capacity/failure fixtures, latency/geometry/performance and affected desktop/Web results, current-source support evidence or hold rationale; recommendation back to G.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

G-R admits only the next verified #12 stage. Energetic fracture, torque, registry expansion, general destruction and production soliding remain separate conditional work.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
