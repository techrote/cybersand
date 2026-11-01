---
title: SOL281 current-main recovery and conservative displacement qualification
status: Current
document-kind: evidence
scope: Source selection, negative results, review and platform gates for the unmerged structural detachment increment
canonical-for: [sol281-current-main-evidence-20261101]
last-reviewed: 2026-11-01
related-documents: [../systems/solid-detachment.md, ../operations/soliding-programme.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# SOL-DETACH-001 current-main increment

## Source selection and unchanged streams

The branch `sol-detach-001-current-main` was created from accepted
`809fd30dfac0c5e127302997075be9c4b279e5aa`, tree
`863db60c767bf00a215b9e4064d6bccb71eb69ab`. Before its first implementation commit
it fast-forwarded to newly accepted `a8f08a67fea3c58f6df7473cbae1831334fcc04e`,
tree `4bfc2fbdda3704dfbf386235e54d2fe525ca32bc`, after PLAY shader #331 merged.
Production render-copy #344 and the accepted PLAY shader are retained.
Frozen #283 remains `254235ec4c3d58782bba44b478caca86bf57c856`; documentation-only
#282 remains `c087ca8569f1df394d67cdc4dbe1c6b46c2bcfb2`. Neither is modified.

The native kernel is selectively recovered from #283's ownership/shape/lifecycle
paths. The Godot session starts from the already compound-capable `41dc25ca`
checkpoint, retaining the later generation repairs without its unrelated render
arms. The native body protocol remains current main's 11/9 floats. No whole-stack
cherry-pick, radius experiment, coalescing or retained-baseline exemption is used.

At intake, PLAY #331/#332/#334, GCR #339/#341/#342/#343 and E #345 were independent
open streams. This branch neither edits their branches nor waits for GCR to
implement detachment. A later accepted GCR candidate needs separate integration
qualification; current-main contact behavior is the initial control. Reinspection
confirms #343 is still draft/unmerged at
`2aff460c60f36c0f209b67fe682d0f8b9e5e0f83`. Its owner preference for Y1 is retained,
but its registered technical failures and absent production promotion remain.
No GCR integration qualification is claimed by this branch.

## Preserved negative evidence and selected mechanism

The historical B=289 expansion remains **NO-GO**. The strict-route census's
8,084 classified events, including 7,892 without an empty/unmasked four-connected
route, remain attributed to their original source. They do not authorize matter
to travel through Sand or Water without relocating those intermediate parcels.

The subsequent [#336](https://github.com/techrote/cybersand/pull/336) and
[#338](https://github.com/techrote/cybersand/pull/338) chain investigations are also
retained. #338 source `8203d2d1bae2151c1a2d4909df5b08ab5b5012eb`, archived at
`61f0398e5a6d63432be681dc4a4d32da769f2b20`, recovered only two of 1,231 no-target
contacts (0.16247%); both were one-parcel adjacent moves, not demonstrated chains.
The source-pinned population SHA-256 is
`d3c8bfeb19355e7bf20518bb7d6afd4b03e1f3790644a09414c4d8ea0955d33c`.

Independent four-axis square/rectangle SAT additionally finds both historical
adjacent targets still overlap the actual rotated body: their maximum axis gaps
are approximately −0.491859 and −0.527756 cells. This stronger oracle does not
rewrite the original center-mask result. Eight intact captures are retained in
[`conservative_contacts.json`](../../godot/tests/fixtures/sol281/conservative_contacts.json)
alongside explicitly new analytical boundary fixtures.

The implemented candidate is therefore a **bounded local submechanism**:
at most four occupied Sand/Water parcels move one cardinal cell each into a
preflighted vacancy. Every destination square must fully clear all body proxies.
It replaces every direct ejection only in the opt-in detachment host. Blocked
contacts keep their matter. It is not claimed to solve packed-bed penetration,
replace GCR's bearing/force response or conserve calibrated mechanical energy.

## Independent review and repairs

The principal implementer integrated separate native-core, host and physical
review work. Significant findings resolved in source include:

- Populated source structures formerly refused every adjacent Sand/Water cell.
  Narrow ambient noncohesive contact admission now leaves those tuples native.
- Compound shape reservations could exceed the 64 proxy-ID interval. The native
  acknowledgement now rejects that interval before ownership transfer.
- A continuation after awaited mask priming could access a replacement session.
  It now checks exact generation/worker; lifecycle regression covers that await.
- The historical session duplicated cellular response reduction. Shared Rapier
  bridge helpers now own ordinary and compound response, including one weighted
  correction, ordinary correction-age/velocity policy and off-centre impulses.
- First-writer center masks could conceal foreign geometry at a source. Full
  source-square checks now refuse that ambiguity; destinations use full SAT too.
- Lazy thermal allocation in `move_cell` could occur after the first material
  write. The native chain preflights all thermal fields and resident chunks.
- Every accepted path coordinate remains reserved across repeated preparations
  of one compound sample, preventing intermediate parcels from moving twice.
- Numeric narrowing and exceptional replay setup fail closed; quarantined
  partial progress is distinct from a mutation-free refusal.
- Active-owner world replacement, failed-native publication and nonconsecutive
  compound sample replay were identified in the independent host review. All three are repaired and have focused actual-host regression controls;
  their final-source execution disposition is recorded with the hosted results.
- A quarantined transaction previously could reach a later healthy-only mask
  mutation and throw across the adapter. It now stops before further masks or
  forces; this exceptional path is source-reviewed, not directly fault-injected.

## Validation ledger

This section is updated with exact source-qualified host results before the
draft deliverable is finalized. The current entries below are implementation
iteration evidence; none substitutes for hosted Windows, graphical GPU or full
ready-for-review acceptance.

| Gate | Recorded state at initial implementation checkpoint |
|---|---|
| Native detachment | Linux GCC13: nine groups / 19,338 checks pass. |
| Shared native/material regressions | Existing 165 tests pass on the recovered source; original log retained. |
| Native displacement | Linux GCC13: six groups / 281 checks pass, including exact source-mask ownership. |
| Native ASan/UBSan | Both focused suites pass ASan/UBSan: 19,338 and 281 checks. |
| Deterministic replay | 17 cases / 292 checks each on workers 1 and 4; complete case results identical. Initial failed attempts retained. |
| Actual Linux Godot/Rapier | Fresh native runtime built; full focused host matrix pending. |
| Actual Windows Godot/Rapier | Source-matched hosted build/execution pending. |
| Graphical presentation / target GPU | Rendered dry/mixed visual smoke passed under Xvfb/llvmpipe; representative GPU pacing remains not tested. |
| Ready-PR full CI / merge | Deferred: the requested deliverable remains draft and requires owner approval to merge. |

The initial replay failure is preserved: no-op setters were mistakenly treated
as import refusal; an analytical Water coherence value 13 exceeded the default
maximum 12; and the replay's requested inclusion region had not yet been applied.
The corrected setup ticks the empty World once **before** importing any frozen
payload, uses valid new-fixture Water states, and verifies semantic readback.
Historical captured tuples remain unchanged. The malformed analytical fixture's
SHA-256 was `8c86e3d13d667b6b3f91dedd36e734bec00c4278c49c78e1f3c8d257456e64ca`.

Original iteration receipts, failure logs, source hashes and independent reports
are retained in [the prequalification inventory](sol281-20261101/prequalification/inventory.json).
They deliberately retain their original pre-commit source identity and do not
claim to be the later final-source hosted run.

The final [independent ownership review](sol281-20261101/review/host-review.md)
closes H1–H4 at source level and retains the initial findings. Actual hosted
execution and uninjected unexpected-exception coverage remain distinct.

### Preserved first hosted attempt

[Run 41329746261](https://github.com/techrote/cybersand/actions/runs/41329746261)
qualified source `c8c81a8b81677abd173de199a9d436f46de2268b`, tree
`214f927af0e9feeb65c664e981b32b7fbc15e39b`. Both pinned platform builds and all
three Linux host cohorts passed. All three Windows cohorts refused the checkout
before Godot or physics execution: `Checkout .gitattributes differs from Git`.
The evidence reducer failed and runtime publication was correctly skipped.
[Original reports, Windows job log and artifact-entry hashes](sol281-20261101/hosted/c8c81a8b81677abd173de199a9d436f46de2268b/first-attempt/inventory.json)
preserve this failed attempt without changing its source identity or raw bytes.

`core.autocrlf=false` alone retained Windows' native `core.eol` default, converting
automatic-text files to CRLF. The narrow repair sets `core.eol=lf` before checkout;
explicit committed `eol=crlf` files still use CRLF. A real-Git regression with the
repository's committed attributes reproduces the rejection and verifies the
repair. All nine qualification-reader tests pass. No attributes or validator
rules are relaxed. The corrected source requires a new complete platform run.

## Issue #281 gate disposition

The broader owner requirement remains open. Dispositions are explicit;
successful later host runs update only their corresponding rows.

| Acceptance gate | Disposition and practical boundary |
|---|---|
| Reconcile current main / preserve frozen archive | Passed by source inspection and narrow port; accepted R retained. |
| Genuine native tree, intact anchors, actual cut | Implemented; native tests pass; current-source actual-host qualification pending. |
| Bounded discovery / unknown and capacity refusal | Passed in focused native scope; global structural solver deferred. |
| Exact payload and exclusive native/aggregate ownership | Passed in native scope; asynchronous host failure matrix pending. |
| Exact compound holes / COM / inertia | Implemented and native geometry checked; host motion qualification pending. |
| Real falling, toppling, off-centre torque and rolling | Implemented through Rapier; current-source numerical host gates pending. |
| Conservative local Sand/Water displacement | Passed in bounded native/replay scope: four accepted boundary controls and thirteen mutation-free refusals; no dense-bed success claim. |
| Dense granular resistance / acceptable penetration | Not passed; inherited B0 contact response is not repaired by this submechanism. |
| Multiple contacts / stale samples / replacement / reset | Native and bridge cases implemented; full hosted matrix pending. |
| Actual Linux and Windows, workers 1 and 4 | Not yet tested for the complete source at this checkpoint. |
| Excavation beneath resting aggregate | Implemented native edit plus collision refresh; actual-host gate pending. |
| Safe rest/desoliding/repeat lifecycle | Inactive rollback only; transformed active restoration explicitly deferred. |
| Reactive Wood/bark / heterogeneous cohesion | Explicitly deferred; narrow inert eligibility only. |
| Fracture / inherited fragment motion / persistence | Explicitly deferred; unsupported aggregate saves refuse. |
| Normal gameplay and physical owner acceptance | Explicitly deferred; opt-in playable lab provided. |
| Representative GPU pacing and independent final review | Not tested / review in progress. |

## Rendered scene inspection

[Original visual receipt](sol281-20261101/graphical-smoke/visual-review.json) and
[complete source/runtime record](sol281-20261101/graphical-smoke/report.json) retain
actual rendered dry and mixed captures at local freeze `dd18bca6`, whose exact
tree is also preserved by remote implementation commit `83a12466`. This is
software OpenGL (Mesa 25.2.8 / llvmpipe LLVM 20.1.2), not representative GPU
frame-pacing acceptance. Both scenes exited successfully. The mixed captures
also visibly retain the dense penetration limitation.

![Actual anchored mixed fixture](sol281-20261101/graphical-smoke/mixed-anchored.png)

![Actual mixed fixture after 240 Rapier steps](sol281-20261101/graphical-smoke/mixed-tick240.png)

## Documentation change map

The runtime contract owns current capacities, controls and mechanism. The
soliding programme retains Track-A/Track-B separation; lifecycle and coupling
documents link the opt-in owner/response boundary. Interface/configuration,
build instructions, roadmap, handover, docs index and retrieval routing are
updated together. Historical evidence and dependency/runtime release locks
retain their original values. New runtime provenance must describe actual new
builds and qualified hosts rather than relabelling retained main binaries.
