---
title: PLAY-UI-004 accepted-main integration
status: Planned
document-kind: evidence
scope: Hash-checked normal integration of accepted lap/HUD source with the unchanged gamepad candidate; combined runtime qualification pending
canonical-for: []
last-reviewed: 2026-10-28
related-documents: [../systems/player-control-playground.md, 2026-10-28-play-ui004-gamepad-events.md, 2026-10-27-play-ui003-lifetime-review.md, 2026-10-27-play-ui003-exact-head-parse-failure.md, ../operations/local-build-and-validation.md]
---

# PLAY-UI-004 accepted-main integration — 2026-10-28

This is an integration checkpoint for [PR #286](https://github.com/techrote/cybersand/pull/286),
not a combined-source engine pass, hardware-gamepad qualification or completion
of #268. The existing branch is `play-268-gamepad-event-edges-20261028`.
Do not modify concurrently qualifying #284 or the separate #285 native/runtime
publication lane to consume this record.

## Parent identities and accepted prerequisite

- Gamepad candidate: `5187f71697c0131f3bad95db637887f78e3472c9`.
- Common ancestor: `c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59`.
- Accepted main: `69e340d390e3e563833e80659aa97fddc2922310`, the #280 merge.
- Accepted main tree: `63c6612fcaecdacad26452f7d15dfb118d410d9d`, identical
  to reviewed #280 head `8533876b` and tested checkout `eb84f71c`.

Live GitHub records show #280 merged after its exact-head
[Native 40600760721](https://github.com/techrote/cybersand/actions/runs/40600760721),
[Godot 40600760606](https://github.com/techrote/cybersand/actions/runs/40600760606),
[Docs 40600760603](https://github.com/techrote/cybersand/actions/runs/40600760603)
and [independent source review](https://github.com/techrote/cybersand/pull/280#issuecomment-6453690179)
completed. The original gamepad candidate's no-findings review remains scoped
to its own parent tree; neither parent's results qualify this new combination.

## Actual merge preparation and bounded source checks

The local environment could not resolve github.com for a full Git clone and
has no Godot executable. Connector source reads supplied the affected immutable
file contents. Before any merge, all six common/base/branch file versions below
were authenticated against their Git blob identities. Ordinary
`git merge-file -p branch base main` exited zero for both overlapping files,
without conflict markers or hand-selected conflict sides.

| File | Common-base blob | Gamepad blob | Accepted-main blob | Clean merged blob |
|---|---|---|---|---|
| `godot/main.tscn` | `38d1f6511d9fc88c02b7995a0dcf0d78ff8ac37b` | `24973ef09ea41b7c9a6e59e986e320ae25661c3e` | `02493029ed940fda21ea373e556ab417789e1b63` | `ba3be59daa9ee1a9f8d1b015c92e747675a8a986` |
| Player-control guide | `14c076092a903c78b9d96782684298cdf955e86e` | `a39a9394813fe2cc4c1e9949c68ebec3c6be61de` | `6d7300363dd73ec187aaf68dbc9b661946005054` | `59a9615c57d25a0b48160682bf692b42ce12190b` |

The merged scene retains exactly one `CourseTiming` label and one
`CourseGamepadEvents` node. All accepted main implementation and test paths
are inherited unchanged, including `main.gd`'s completed-step checkpoint hook,
lap model, class-cache entry and repaired minimal test scenes. The gamepad
adapter blob `11a21196225605c74cd1bf959de190f74c5186d9`, focused test blob
`5ec14f87485e1559e6d8c152884ddaa6d3f44678` and original candidate audit blob
`6ef8a56805b02088eb219995fb2606fffa34f9a3` are reused exactly.

After the clean merge, the canonical guide receives an explicit documentation
reconciliation: #280 is accepted, its exact parent receipts are recorded, and
its four-checkpoint lap/HUD is no longer listed as unimplemented. The gamepad
paragraph remains a candidate. The resulting guide blob is
`b803b838fe9e3ea058749e2b242e5ab7f84adda0`; this intentional prose change is
not claimed to be the byte-identical raw merge. Earlier audit records and all
swarm/specialist wording are retained.

Publication uses a two-parent commit and an expected-head-protected,
non-forced update of the existing branch. No history is rewritten. Relative
to accepted main the intended scope is the same five gamepad paths plus this
integration audit; no native, runtime, LFS, workflow or specialist fixture path
is added or modified.

## Rechecked parent evidence, not new execution

Five previously downloaded #280 ZIPs were rehashed locally and their focused
logs reread. All identities and recorded receipts remain parent-source-bound.

| Parent artifact | Artifact ID | Verified ZIP SHA-256 |
|---|---:|---|
| Windows | 12780073500 | `319ad397e0025c20c0949ddda701fefe3b646c0c4e11d98cbd91fb1091a2b398` |
| Linux shard 0 | 12778699577 | `51d1e4e4cfc773bbb2577d300085dea3a7143f0ff32c287c1948da2310a782d6` |
| Linux shard 1 | 12779890934 | `da90a0153ee2f663082a3d341c2a3bdd216ed802d47fc892187c18531fed8d05` |
| Linux shard 2 | 12779273989 | `ea0516e8ec5f72ce96c8161397e17343d8e9fb5ea2b2203be2facda7b5c3c952` |
| Linux shard 3 | 12780460648 | `342875080656e3c987d57e2b2bd561b05021f9ae3857a2a3571bc33513ea8759` |

Both platforms report cadence 41/0 (one actual physical visit and one
render-only negative control), lap model 1,373/0 (50 model-only cycles),
five-rig course 126/0, and Auto readback 15/0 (four slots, zero parallel phases).
These do not execute `test_play_ui004_gamepad_events.gd`, the fifty-real-host
lifecycle campaign, hardware-controller testing or a performance comparison.

## Required new-head gates

No local parser, Godot or C++ execution occurred in this integration pass.
The full repository checkers could not be executed in a source-only partial
materialization. Fresh exact-head Documentation/provenance and applicable
Native and complete Windows/Linux Godot/GDExtension CI remain mandatory.
Read back `PLAY_UI004_RESULT` and its actual ordered-button/poll-only-negative
checks, unchanged course/lap/liquid controls, process exits, diagnostic scans,
timeout/clean-checkout results and source/runtime identities. Obtain fresh
independent review of the combined scene and guide before merging.

The retained historical failures remain failures. No retry masking, omitted
case, relaxed assertion, timeout increase, CI-provider change or new Web test
is introduced. Native World ownership, main-thread Rapier, requested/applied
per-material solver receipts and validated construction-time policy admission
stay inherited. #271 swarms remain deferred; #265 remains closed. Broader
#268 configuration/focus/gamepad and #266/#269/#270 performance, lifecycle and
release gates are not closed by this integration.
