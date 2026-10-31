---
title: PLAY-LIFE-009 automatic same-owner pause and input qualification
status: Current
document-kind: audit
scope: Candidate headless native and Rapier behavior, not graphical startup, physical-device acceptance or accepted main
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/cybersand-codex-development-handover.md, ../reference/status-and-roadmap.md]
---

# PLAY-LIFE-009 automatic same-owner pause and input

## Authority and independent scope

The owner deferred Windows shader/compiler/cache/decomposition work pending major
shader reworks and requested continued PLAY engineering. The
[manual ownership registration](https://github.com/techrote/cybersand/issues/305#issuecomment-6538946653)
and [shader deferral](https://github.com/techrote/cybersand/issues/309#issuecomment-6538949034)
preserve all existing failures, acceptance contracts and merge holds.

[Draft PR #317](https://github.com/techrote/cybersand/pull/317) begins directly at
accepted main `0bf28d5760aed989a79386de03ef4fc6171fef42`, not held #308/#310. It
changes no production scene, shader, native code, physics/solver default, runtime
pin, scientific fixture or training input. #312 stays frozen, #316 remains draft,
and Scheduswarm remains paused. No mandatory production workflow is changed.

## Registered behavior contract

Five independent processes exercise the original authored course and actual
SetP rigs: stuntbuggy, trialsbike, acrobat, arcadelander and jetbarrel. Each uses
`main.tscn`, the existing exclusive `CyberSimulationWorker`, native World and
main-thread Rapier. Only OS focus is substituted in the positive path; keyboard
events are injected through production Input dispatch. Rendering and physical
devices are not qualified by this headless fixture.

The original Main `_process` and `_physics_process` run automatically. An observer
records the admitted command immediately before the real production Rapier step
and its resulting copied action, completed tick and bridge step afterward. No
manual `_physics_process`, bridge step or pose injection is used. The negative
phase suppresses only input publication while actual bodies keep ticking; that
phase must remain neutral and cannot qualify input application.

The positive sequence admits nonneutral input, populates real press/release
edges, toggles P, observes a new native paused publication, and then verifies at
least 350 milliseconds and eight automatic physics callbacks of quiescence.
Native tick, Rapier tick/step, body pose and lap tick remain unchanged; Main
callbacks continue. Worker/session/bridge/run/actor epoch/World generation remain
identical. Resume while the old movement key remains held must stay neutral and
require release-to-rearm. A still-in-lease pre-pause command is rejected with
`observation_not_issued`, not simply expiry. A fresh post-release command must
then reach a completed step and native ticks must resume. Shutdown must destroy
the actor session and join the worker.

Each operation is bounded at 15 seconds, each fixture at 150 seconds, each
external case at the existing 180 seconds, and import at 240 seconds. All five
first attempts are retained, even after a case fails. No automatic retry or
skipped-row success is permitted. Capture is bounded at 512 observations.

## Source and evidence contracts

The scoped [workflow](../../.github/workflows/play-life009.yml) executes actual
GitHub-hosted Windows Server 2022 and Ubuntu 24.04 on literal runner labels. It
checks out the exact PR head, uses the pinned official Godot
`4.7.stable.official.5b4e0cb0f` and authentic selected LFS native/Rapier runtimes,
and rejects production-path drift from its registered base. Full execution-input
hashes and runtime identities are checked before and after. Actual observations
must report `native-phased`, `Rapier2D` and the headless display server; fallback
or unmeasured graphical/physical qualification claims are refused.

The original process result is written before parsing and postflight. Original
logs, reports, source archive and SHA-256 inventory are retained. Source archive
creation disables LFS smudging; selected materialized runtime identities remain
separate. The earlier 584b archive performed LFS smudging and is preserved as-is,
not silently replaced with a smaller archive. No credentials, .git state or
generated cache contents are staged as repository source.

The [strict reducer](../../tools/play/life009_contract.py) recomputes identity,
clock, input, pause and teardown checks from original observations. Its
[adverse tests](../../tools/play/test_life009_contract.py) cover missing/duplicate
rigs and markers, silent input loss, false clock-only success, owner replacement,
paused drift, invalid old authority, held input, capture overflow, late deadlines,
failed cleanup and unsupported graphical qualification. Synthetic unit fixtures
are explicitly not engine evidence. Direct 30-second check-only parser controls
retain the original malformed helper and require the current helper to parse;
these controls do not execute gameplay or count toward five-rig coverage.

## Preserved first attempts and corrections

### Initial workflow policy failure

Source `5369c61efe06d4e0f062bc1d7186c680f68f6bbb`, tree
`a8fc6c6b9de8e7aa4b3f2f2d3f42f0ccf1ac8323`,
[run 41169533038](https://github.com/techrote/cybersand/actions/runs/41169533038),
attempt 1 failed the repository CI-provider policy before any engine execution.
The runner matrix was not permitted. Linux artifact 13029904722 is 1,321 bytes,
SHA-256 `0790fdb2b5688bad15a3d844ee88ad543c8a506737eeb5380af74d192cdd7a3d`;
Windows artifact 13029769957 is 1,334 bytes,
SHA-256 `8446543ab226499ee768b33389e0d9ac4d07e9c52a030d342964364121225f41`.
Source `584b9c35085e45a0ab911730965b3cc30474dfd0` replaced only that new workflow's
matrix routing with explicit Ubuntu and Windows jobs. The policy checker and
all behavior/timeout requirements remained unchanged.

### GDScript fixture parse failure

At source `584b9c35085e45a0ab911730965b3cc30474dfd0`,
[run 41169705947](https://github.com/techrote/cybersand/actions/runs/41169705947),
attempt 1 passed platform policy, verifier units, runtime authentication and
ordinary import, then all five wrappers failed to resolve the malformed shared
helper. No gameplay success is credited. Original artifacts are:

| OS | Artifact | Bytes | SHA-256 |
|---|---:|---:|---|
| Linux | 13031095186 | 146553524 | `91277e3c7b179252dc86f652a86399f775f65153dfd5628129ce16afe0722cfa` |
| Windows | 13030910521 | 146562433 | `81293ac0108060152f7692962b8705519bbee67e1bca313237fabc9047e20b8c` |

The correction uses named, bound predicates instead of ambiguous multiline
inline predicates. The next run's actual check-only negative control reports
`Expected closing ")" after call arguments` at original helper line 205; its
current helper parses successfully. This is an apparatus source correction,
not a production game fix.

### Actual engine success, original reducer rejection

Source `78d48b2a92650f139fc77c243f8df4edffc39643`, tree
`f8b5446c55e805913b2c31862ffeb12b1e51d488`,
[run 41170489097](https://github.com/techrote/cybersand/actions/runs/41170489097),
attempt 1 is still an original aggregate failure. Both parser controls behave
as expected and all five actual engine processes exit zero on each OS. However,
the Python reducer incorrectly assumed positive object identifiers and rejected
the genuine RefCounted worker/bridge identities. Godot's pinned
[ObjectID definition](https://github.com/godotengine/godot/blob/5b4e0cb0f/core/object/object_id.h)
reserves bit 63 for reference-counted objects and exposes signed int64 values to
Variant. A negative value is therefore not evidence of a replaced or invalid
owner. Current reduction preserves exact nonzero signed 64-bit identities;
it does not take absolute values or round through floating-point numbers.
A new adverse test accepts genuine large signed identities and rejects adjacent
identity substitution, zero, booleans, floats, strings and out-of-range values.

| OS | Actual assertions by rig order above | Engine process seconds | Original aggregate |
|---|---|---|---|
| Linux | 104, 104, 103, 103, 103; zero failures | 3.438–3.538 | FAIL, signed-ID verifier defect |
| Windows | 104, 103, 103, 103, 103; zero failures | 4.194–4.207 | FAIL, signed-ID verifier defect |

Each actual run records 21 paused callbacks, four completed steps in each of the
dropped-input, active, held-resume and fresh-input phases, same owner identities,
350ms or more of quiescence, fresh native progress, and successful teardown.
A corrected local reduction of these original engine records passes, but that
is explicitly derived readback, not a rewritten original campaign or a green
result attributed to 78d4.

Linux original artifact 13030767341 is 76,693,966 bytes, SHA-256
`5be903b60ccb4ee9a3dfcb5961f37a4d5d2205a995eeacb5dd63abb7fb186e37`.
Windows original artifact 13031081597 is 76,698,715 bytes, SHA-256
`b7af49b7ec8a39a6f3ebe5a0fa7d8864513dec04c5c7fa1840c78890fa1c3d02`.
Both archives, original report errors, parser logs and all fixture/process logs
remain byte-preserved. Source and runtime postflight fences passed.

## Current candidate and integration boundary

### Independent review correction before full qualification

The continuation independently reviewed all twelve files at source
`1686d449d979a47e0b6520c5f048716a128cf700`, the production input/physics/pause
paths and both original run41171088500 archives. ZIP sizes, SHA-256 and CRCs
match the original [PR qualification ledger](https://github.com/techrote/cybersand/pull/317):

| OS | Artifact | Bytes | SHA-256 |
|---|---:|---:|---|
| Linux | 13031426009 | 76699130 | `c580906f72daec6fe0d835ab6c73ebeda93829f2277934da4c7b9911547b49ef` |
| Windows | 13030558984 | 76702621 | `74956ea2080190ced05e6d6368e1afd66ac4c77f786b4af452641f6cfce96ca9` |

Original v1 readback passes at its own
source. The original parser logs on both hosts contain the registered failure
at line205, with exit1 and no timeout.

The reviewer nevertheless reproduced a real verifier false pass: offline
readback accepted an internally consistent original-parser exit0/no-error
record because it checked only current-parser success and log hashes. Execution
also accepted an unrelated generic parse error. The correction uses one shared
execution/readback verifier, authenticates the exact frozen source and both
process receipts/logs, and requires the precise expected diagnostic at line205,
exit1/failed status, the original30s deadline and no timeout/launch/capture/skip
failure. Current-parser success remains a separate positive control.

Fifteen focused methods, including the complete offline unexpected-success
counterexample, pass in normal and optimized Python. Controls also reject a
different diagnostic/location, extra script failures, late/interrupted runs,
changed source/receipts and a current-parser error hidden by a passing receipt.
The actual fixture now records and checks teardown against its own15s operation
limit. Result schema v2 requires that duration; historical v1 evidence remains
unchanged and is reduced with its original source. The150s fixture,180s process
and240s import limits are unchanged. These changes require new exact-head
execution; none of the historical515/0 results are relabelled as v2 runs.

Local Linux v2 smoke at1686 plus this explicit source delta passed104 assertions,
zero failures,1.770464s fixture and35,159us teardown on the pinned4.7 engine and
retained source-matched native/Rapier libraries. The first local launch failed
before gameplay because sandbox `user://` logging was unwritable; the corrected
launch uses an explicit writable `--log-file`. Its original crash remains failed,
and editor socket/config-location diagnostics are environmental evidence, not
clean import qualification. New hosted first attempts remain required. Current
documentation, all18 materialized runtime identities,15 verifier methods in
normal/-O Python, provider policy and whitespace checks pass locally; hosted
gates remain the integration authority.

### Historical signed-ID candidate boundary

At original source1686, the signed-ID correction changed only the reducer and
its tests; its GDScript behavior fixture was byte-identical to source78d4. Nine focused methods
with adversarial subcases pass locally in normal and optimized Python. The
[PR's source-pinned qualification ledger](https://github.com/techrote/cybersand/pull/317)
records the corrected head's new original Windows/Linux outcome, artifact
identities and remaining gates. No runtime result is attributed to a commit
that has not executed it.

This is a candidate-only validation slice. The accepted-main player guide,
architecture, ownership/physics APIs and ADRs do not change because production
behavior and acceptance are unchanged. This dated audit and the repository
front-door link provide the new candidate route; canonical accepted-state
handover/roadmap promotion remains part of guarded integration, not inferred
from a draft scoped workflow. The dependency order #268 → #269 → #270 → #263
is unchanged. #309 is deferred by the owner, not declared fixed or waived.

Before merging #317, obtain substantive review and every applicable exact-head
ordinary Native, Windows/Linux Godot and materialized-provenance gate required by
repository policy. Draft-skipped jobs are not successful executions. Preserve
these controls and run the original five-rig suite against any resulting tree.

This fixture does not close the complete graphical PACE input-tape requirement,
prove every actuator force or nonzero lap traversal, measure graphical FPS,
exercise physical controller disconnects or qualify actual OS focus/human feel.
The stopped GDScript worker-owner thread is observed; no independent OS trace
of every native pool thread is claimed. No #268/#269/#270/#263 closure or
#308/#310 integration follows from this candidate. Shader investigations remain
deferred and Scheduswarm remains paused.
