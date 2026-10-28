---
title: PLAY UI lap lifetime review and retained CI readback
status: Current
document-kind: evidence
scope: Exact 1c5b904d CI readback, source-discovered stale-lifetime defect, prospective lap-model fence correction and explicit remaining gameplay gates
canonical-for: []
last-reviewed: 2026-10-27
related-documents: [../systems/player-control-playground.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/local-build-and-validation.md]
---

# PLAY-UI-003 lifetime review — 2026-10-27

This is a dated evidence record, not completion of #268, #269 or #270.
The [player-control contract](../systems/player-control-playground.md) remains
canonical. The original course, five SetP rigs, native Auto owner and per-material
construction-time liquid-policy admission are unchanged by this correction.

## Repaired pre-correction CI actually executed

[PR #280](https://github.com/techrote/cybersand/pull/280) head
`1c5b904d4793769a93ffae9768987d825438b98b` was tested as prospective merge
`da4cfd311ec241317696fdebf0fefb857c27bc7e`, tree
`2372545aecadb346e2ea6ea3eef47866af333927`. All required workflows succeeded:
[Godot/GDExtension 40569418552](https://github.com/techrote/cybersand/actions/runs/40569418552),
[Native 40569418362](https://github.com/techrote/cybersand/actions/runs/40569418362),
and [Documentation 40569418225](https://github.com/techrote/cybersand/actions/runs/40569418225).
Draft-triggered skipped/cancelled runs are not execution receipts.

The downloaded Windows execution manifest binds that exact commit/tree,
reports all 162 applicable cases executed, status passed, and empty errors and
source-drift lists. Its per-log hashes matched the archived files. Actual
Windows and Linux results were 126 assertions / zero failures for the five-rig
course and 21 / zero for the original lap-model fixture. The repaired physical
keyboard harness reports 390 / zero on Windows and Linux shard 0; the repaired
sampled-rig harness reports 694 / zero in the Windows archive. These results
prove the earlier missing-label correction, not untested lifetime cases.

| Downloaded artifact | ID | ZIP SHA-256 |
|---|---|---|
| Windows execution | 12767127336 | `35b51838f3e4b93a45d395705e1730f0831cfeaae584b02f0d4536059d959846` |
| Linux shard 0 | 12765084482 | `fb492f330da6fb4e31db91dff720a9c7b3f18eac8cbe6c0eafffde1c887b9270` |
| Linux shard 1, lap model | 12766100011 | `0f0ac9d0bdd83f87b0778fc1d77192b89f5476a8634d0b73e27760ade5ed321b` |
| Linux shard 3, five-rig course | 12767005112 | `000b65935d77bb10f77562ac717f0b3cbde2ea607a94d0a67a96af8d49df9deb` |

Godot was `4.7.stable.official.5b4e0cb0f`. The Windows execution manifest records
native runtime SHA-256 `e3f17363d21260690682dfaa9e5e118253544c1b9b19e69e50c03af567712343`
and Rapier SHA-256 `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`.
The Linux identities record native `02ea0661d3a62e2ab346c3fe46f9f85b808c6a0099c639144f053dc70a5c3d46`
and Rapier `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

The failed predecessor remains [run 40544182583](https://github.com/techrote/cybersand/actions/runs/40544182583):
missing `Layout/CourseTiming` in two minimal harnesses and an import-generated
portable class-cache entry. Neither the failure artifacts nor diagnostic,
clean-checkout or timeout gates were rewritten or weakened.

## Source review finding despite green CI

The reviewed [lap model](../../godot/scripts/playable_course_lap.gd) treated
any different actor epoch or World generation as a new session, without first
checking ordering. At the pre-correction head, a bind to Acrobat epoch 8,
World 13 can be followed by a bind to epoch 7, World 12; the latter clears the
newer live lap and returns true. `clear_session()` also discarded the ordering
information. This counterexample was found by source inspection, not an
executed failing Godot run. The previous 21 checks never attempted a retired
identity after a newer bind or after clearing the session.

The desktop caller already checks its physical epoch; that does not justify
claiming the reusable tracker itself rejects retired lifetimes, nor does it
supply a monotonic World-generation fence. Preserve the caller's guards and
make the model's own boundary fail closed.

## Candidate correction and test scope

Code checkpoint `af0a14b862c84df0b7bb6485806ae9107e3c445d` changes only
[the model](../../godot/scripts/playable_course_lap.gd) and
[its focused fixture](../../godot/tests/test_play_ui003_lap_clock.gd), atop
pre-correction head `1c5b904d`. This record is added in a subsequent commit.

The candidate keeps actor, World, native-tick and physical-tick high-water
marks for one desktop tracker lifetime. Clearing displayed progress does not
retire those fences. Candidates are fully checked before mutation: an older
actor with a newer World, a newer actor with an older World, and a different
rig under the same actor epoch all refuse without changing accepted progress.
A legitimate World replacement may reset native tick zero; a legitimate actor
replacement may independently reset physical tick zero. A new desktop host
constructs a new tracker. Best times remain per-rig within the host lifetime.

The existing 21 checks remain. Fifty bounded model-only lifecycle cycles rotate
through all five mechanical rigs and exercise mixed/stale identities, unchanged
state on refusal, clear/rearm, duplicate/stale clocks, nonfinite poses, pause,
ordered completion and preserved bests. The intended total is 1,373 assertions;
that number is a source-derived prospective count, NOT a passing receipt.
The output explicitly distinguishes `model_lifecycle_cycles` from
`real_host_lifecycle_cycles=0`. This is not the separate fifty-real-host-cycle
stress campaign proposed under #269.

No native World calls, physics stepping, pool/default changes, solver hot-switch,
scientific/NPC fixture changes or CI routing changes are added. The eight-line
portable class-cache registration and two existing keyboard-harness repairs
remain untouched. Tests retain the runner's existing 180-second case bound.

## Validation and remaining blockers

Current-invocation work inspected immutable source objects, diffs, archived
runtime manifests and SHA-256/Git-blob identities. There was no local Godot
execution or full local repository checkout. New source-head Native,
Windows/Linux Godot, documentation/retrieval/provenance and clean-checkout
validation plus independent review are required. Earlier greens cover only
the pre-correction tree, never this candidate. The working branch remains
`play-268-course-lap-ticks-20261027`.

The desktop currently invokes `_update_playable_course_progress()` from
`_process`, not after every completed Rapier step. Separate model clocks alone
do not prove every checkpoint visit survives slow presentation. Physical-cadence
sampling and a real-host regression for a visit between render callbacks remain
an explicit review/acceptance gate; do not claim that defect is repaired here.

Broader #268 selectors/rules/focus/gamepad, #269 real-host lifecycle/slow-tick
stress, #266 representative worker participation/performance and #270 manual
feel/release acceptance remain open. #271 swarms remain deferred; #265 remains
closed as unnecessary. No additional World owner or Web promotion is proposed.

## Checkpoint-cadence correction after independent P1 review — source candidate

The [independent PR #280 review](https://github.com/techrote/cybersand/pull/280#discussion_r4394229403)
identified a production discrepancy after the 50-cycle model-only correction:
the separate physical-tick variable is insufficient if the main desktop reads
the pose only from `_process`. A real Rapier actor can enter and leave its next
gate between presentation callbacks. All three CI workflows passed the
**prior** lifetime-model head `f538132d72d8a0cc13d6ea87cbc58162ffe54749`
([Native](https://github.com/techrote/cybersand/actions/runs/40584710496),
[Godot](https://github.com/techrote/cybersand/actions/runs/40584711088),
[Docs](https://github.com/techrote/cybersand/actions/runs/40584710799)).
Those historical greens do **not** cover this physics-cadence correction.

The subsequent production patch is
[`cb4bfe706c2fdb56cdf9bd9cf4add1b57f5e2a85`](https://github.com/techrote/cybersand/commit/cb4bfe706c2fdb56cdf9bd9cf4add1b57f5e2a85).
It adds the only new observation callback immediately following the **actual**
`physical_actor_session.complete_step()`, and only if the session tick
advanced. It samples the completed main-thread Rapier pose and the last
**copied** native World publication. The original render callback still updates
the HUD and native elapsed tick, with duplicate physical ticks rejected by the
existing lap-model fence. It does not call a native tick, acquire a worker-owned
World handle, add a second World owner or update GUI nodes from the physics
handler. Paused/failed/pending terrain or actor replacement cannot cause a
completed Rapier step or bypass the original admission guards.

The [new real-host regression](../../godot/tests/test_play_ui003_physics_cadence.gd)
was added in `cdec805738e1459aaa5ad6609b490c9958a4edcd`
with a constant-reference refinement in `b12fc1e770d13f07b1806f5fffe2f51e72ea9774`.
It exercises the exact authored native course and real F5 `rapier/jetbarrel`
assembly using `main.tscn`, the existing asynchronous worker, the existing
main-thread Rapier bridge and original Godot keyboard/lease path. Both
automatic callbacks are then withheld. The fixture **test-only** translates
all real articulated Rapier bodies together via existing
`CyberRapierPhysicsBridge.reset_body()`, preserving relative offsets, and
completes real `_physics_process`/Rapier steps on the gate and outside it.
The pose and incremented Rapier manual-step/session ticks are checked after
completion. A test-only subclass overriding just
`_record_completed_playable_course_step` runs the otherwise identical
**negative control**: without the hook the later single render callback
cannot recover the transient visit. The positive arm checks gate credit
before rendering and checks HUD-only refresh, duplicate suppression, pause
and real host reset/actor-epoch refusal.

This is bounded **physical engine** execution once CI has actually run it,
not ordinary driving/fair racing. The authored gate is artificially reached
by the test apparatus, not a learned controller or human. The negative and
positive arms each use their own real native and Rapier lifetime, never two
simultaneous World owners. The original 50 **model-only** lifecycle cycles
and five-rig/liquid-policy construction receipt tests remain separate.
No specialist research/NPC fixtures, native cell/material laws, default
liquid family, solver construction-time refusal, Web ownership or
material swarms (#271) are changed; the unnecessary #265 owner stays closed.

**Qualification status:** the completed-step patch, new test and canonical
[Player control update](../systems/player-control-playground.md) were
published as source objects, not executed by this connector. Exact-head
Windows/Linux Godot native/GDExtension/Documentation and a fresh
independent review must read back this regression's
`PLAY_UI003_PHYSICS_RESULT` (including successful positive and no-hook
negative controls), `PLAY_COMP002_RESULT`, `PLAY_UI003_RESULT`, runtime
hashes, clean-checkout, test process exit and diagnostics before any merge.
Earlier historical tests remain unchanged. The separate #269 fifty-cycle
**real-host** failure/slow-tick campaign, #266 performance and #270 manual
release acceptance remain outstanding.
