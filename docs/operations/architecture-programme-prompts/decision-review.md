---
title: Architecture decision: reconcile Cell, liquid and sparse-motion experiment evidence
status: Planned
document-kind: runbook
scope: Self-contained G work item in the architecture experimental programme; gated research, not production approval
canonical-for: []
last-reviewed: 2026-09-10
related-documents: [../architecture-programme.md, ../architecture-programme-source-ledger.md]
---

# Architecture decision: reconcile Cell, liquid and sparse-motion experiment evidence

## Identity and dependencies

Issue: [#14](https://github.com/techrote/cybersand/issues/14).
Programme/workstream: G; [master programme](../architecture-programme.md).
Dependencies: Staged reviews consume C/L/P/M/V; final disposition needs each admitted result plus B result or explicit no-go/defer. #12 relevant design evidence is consulted without making complete soliding a prerequisite.

GitHub completion dependencies: [#20](https://github.com/techrote/cybersand/issues/20), [#19](https://github.com/techrote/cybersand/issues/19)
Staged gate decisions and the complete master mirror: [#14](https://github.com/techrote/cybersand/issues/14). A gate entry may be recorded before #14 closes; its final-completion dependency is not a circular prerequisite.

This prompt is executable without the four original conversations.

## Objective

Record an explicit evidence-based architecture disposition and conditional follow-up scope, including retaining the baseline.

## Why this work exists

Measurements must not silently become policy, and no individual workstream can select another's representation/semantics.

## Relevant Current architecture and accepted decisions

Work in C:/kybersand/source; read C:/kybersand/AGENTS.md and source AGENTS.md and their required focused docs before changes. Use the pinned workspace toolchain and a separate codex/ experiment branch. Preserve the deliberately dirty Windows DLL, any user-loaded runtime and unrelated changes. Keep toolchains/builds/raw logs under C:/kybersand, not C:/cybersand. Programme intake is 8f4ffb96e03dc50cb43ab9c84de17ccb44c03774; remote main was ab4851e and lacked local #9/#10/#13/Water changes. Obtain the named source checkpoint from the active local repository and inspect actual HEAD/deltas rather than running an older remote as the control.

CURRENT: native cells are material 8/state_a 8/state_b 8/epoch 8; no generic vx/vy. Water alone uses fractional FreeMass, mass1..255 (Empty zero), state_b coherent-emission countdown 12, merge=max, pre-decrement suppression; film 48/255; current floor(3*imbalance/4) lateral relaxation and tolerance1. Other liquids generally move whole cells; Oil is specialized. Temperature is persistent optional chunk state. CURRENT POLICY: powder/powder density exchange excluded; Mercury period 30; sampled player support separate; #13 mixing/carrying opt-in, protected horizontal 2/cadence 1. Changing actual Water flux can change opt-in pickup even with the same profile hash.

ACCEPTED: ADR-001 native material authority; ADR-002 phased exclusive write domains; ADR-003 immutable snapshots; ADR-004 paused excluded regions/no catch-up; ADR-005 exact closed Water mass and stable equilibrium; ADR-007 independent main-thread Rapier body state and separate transient occupancy; ADR-008 explicit bounded approximation; ADR-009 pinned Rapier; ADR-010 quarantine failed ticks; ADR-011 versioned granular policy. Do not silently invalidate these. In particular no occupancy in persistent Cell, worker Godot/Rapier calls, silent material deletion, mutable snapshot views or global rollback claims. A discussion of relaxed numerical conservation is an OPEN proposal, not an amended ADR. #13's no-velocity restriction was ISSUE-SCOPED; this prompt's non-goals likewise do not create permanent policy.

Geometry is independently 128x128 storage,32x32 activity,64x64 scheduling core, maximum write radius2 (68x68 expanded domain). Native liquid operations are local; do not copy fallback long-range Water. Desktop pacing is asynchronous against main-thread Rapier; native Web waits synchronously, with optional internal workers. Fallback and serial have different semantics. Current rectangles lack general pixel membership. #11 is administratively closed but the intake source/evidence still documents missing bearing and barrier-aware ejection; preserve that unresolved distinction.

## Hypothesis / question

Which measured combination, if any, warrants changing Current policy, and which open questions require a smaller follow-up experiment?

## Scope

Maintain G-C/L/P/M/B/R gate decisions; review comparable evidence and limitations; issue final retain/defer/next-test/conditional-migration record. If future work is admitted, draft a precise separately authorized implementation issue/prompt and required ADR/compatibility changes.

## Non-goals

No code, production migration, automatic ADR revision, force-selection of an experimental favorite, new fracture backlog or treating issue closure as physics acceptance.

## Repository touchpoints

`docs/operations/architecture-programme.md`, `architecture-programme-source-ledger.md`, experiment prompts/evidence; ADR-001/002/003/004/005/007/008/009/010/011; current Water/material/flow/coupling contracts; status-and-roadmap, retrieval-corpus and relevant tests/compatibility paths named by experiments.
These are inspected existing files/symbols; proposed new modules must be named as new.

## Experimental or implementation strategy

1. For each gate, record input revisions, exact questions, accepted missing-data limits and admitted/held/rejected outcomes. An admitted experiment's negative result is evidence, not project failure.
2. Compare controlled variables: width-only must not spend state; state precision must not change solver; history storage must have identical semantics; rendering must preserve authority. Reject confounded claims rather than rank them.
3. Compare benefit, total active lifetime, memory/epoch tails and supported hardware. Reconcile inline/sidecar crossover with actual usage, not hypothetical ubiquitous features. Keep16-bit ID value separate.
4. Resolve conservation flexibility explicitly: exact baseline remains; any proposed bounded drift requires measured necessity, error accounting and an explicit ADR-005/008 revision. Never waive ownership losses.
5. Reconcile #12 overlap and closed-#11/source conflict before any support-dependent claim. Preserve main-thread Rapier, topology acknowledgement and near-rest alternatives. I's D0–D5 is not a mandatory ladder.
6. Record per-question retain baseline / defer / next experiment / selected conditional migration. Specify exact ABI/saves/profiles/render/hash, platform, rollback and documentation gates for any migration; no implementation in this issue.
7. Close only when every required/admitted branch has evidence or a reasoned disposition, even if the result is no architecture change.

## Controlled variables

Changes: Decision/status documentation only after evidence review.

Fixed: Existing production policies and source until a separate migration is explicitly authorized and validated. Dated evidence and original negative results remain intact.

## Instrumentation

Evidence completeness/comparability matrix; per-gate source identity and quantitative acceptance/flag results; unresolved platform/provenance/ownership register. No new physics timings or rerun campaign merely for review.

Register primary metrics, targets, run budget, capacities and rejection criteria before candidate code. Default behavior screen: five seeds/translations, 1/4 workers, 1800 ticks. Epoch work needs at least 2048 ticks. Use 7 interleaved baseline/candidate process pairs for timing, declared 120-tick steady warmup, and separate initial-settling/startup measurements. Avoid overlapping builds. Register any smaller/larger necessary sample before results; retain failures/outliers. Flag >15% paired p95 cost regression or >1ms extra epoch-clear excess for review; these are research screens, not accepted production limits. Missing counters/hardware produce explicit gaps. No requirement to rerun historical campaigns.

## Fixtures / benchmark scenarios

Use retained experiment reports and scoped regression outputs. Request only a focused missing check whose result could change the decision; no automatic replay of #9–#13 or all-platform campaigns.

## Preservation requirements

Preserve protected current behavior unless the registered experimental variable deliberately evaluates it. Keep Mercury/powder controls distinct from deliberately changed Water. Check exact nonreactive species and Water accounting; chemistry sources/sinks and finite-ROI outflow need separate ledgers. Preserve state/temperature transfer, bounded work, immutable handoff, failed-world and region contracts. Retain original control binaries/fixtures; fresh-world comparisons never reinterpret existing save bytes as a new layout. No universal flow field or new representation is implied merely by available state bits.

## Validation

Review retained correctness/determinism/conservation/behavior/performance outputs; run documentation/retrieval checks. Do not manufacture new runtime acceptance.

Reuse [#9](../../audits/2026-09-09-physics-characterisation.md), [#10](../../audits/2026-09-09-issue-10-granular-policy.md), [#13](../../audits/2026-09-09-issue-13-transport.md) and [current Water](../../audits/2026-09-10-water-leveling.md) evidence for baseline facts, not as freshly run candidate results. Build/test commands come from C:/kybersand/dev.cmd and docs/operations/local-build-and-validation.md. Run appropriate focused native/Godot tests; documentation changes require check_docs.py, check_m11_consistency.py, check_repository.py and tools/docs/retrieval_eval.py with output under validation/local, plus git diff --check. Preserve historical M11 hashes; intake has 16 published-provenance/LFS mismatches, not an all-green repository release.

## Acceptance criteria

Every question has a status with supporting/opposing evidence and limits. No winner is inferred from byte counts/visuals or issue closure. Gate and dependency graph reflect actual outcomes including no-go. Any recommended migration has explicit separate scope, ADR impact, compatibility, platform and rollback gates. Current source remains unchanged.

A sound negative result is successful completion. Do not optimise the experiment to make the proposed candidate win. Report positive, negative and ambiguous evidence. No-go at a conditional admission gate must state the supporting evidence, not merely skip work. All intended stages must have a result or explicit gate disposition; no production integration is silently included.

## Required evidence artefacts

Signed/dated-by-author decision notes (do not invent owner approval), comparison matrix, admitted/rejected alternatives, unresolved questions and exact conditional next-work prompt(s) if warranted.

Record dated source HEAD/local delta and artifact/tool/profile/worker/input identity, commands/timeouts, raw logs and scoped summary. Include control/candidate comparison, determinism/conservation, work/memory/performance, regression outcomes, decision notes and unresolved risks. Update canonical affected docs, roadmap, validation evidence and retrieval routes; retain historical failures and all unrelated source work.

## Decision unlocked

Only the named next experiment or separately scoped migration is enabled for subsequent authorization; this issue itself does not perform integration.

This issue establishes evidence for the programme gate. It does not approve migration merely because a candidate passes its screen.
