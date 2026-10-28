---
title: PLAY-LIFE-001 shared-host lifecycle candidate
status: Planned
document-kind: evidence
scope: Source-only fifty-lifecycle Windows/Linux candidate for the composable desktop Player Playground host
canonical-for: []
last-reviewed: 2026-10-28
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rendering-and-gameplay-bridges.md, ../operations/local-build-and-validation.md]
---

# PLAY-LIFE-001 shared-host lifecycle candidate — 2026-10-27

This record covers a **stacked draft test candidate**, not an executed result or
completion of #269. The branch `play-269-shared-host-lifecycle-20261027` starts
from PLAY-UI-003 candidate `bbc93183c61e0d768e3c54bd2e0d4e9011f7d416`.
That dependency remains PR #280 and must first receive source-matched
Windows/Linux qualification and acceptance. Retargeting or merging this draft
before its base is accepted would obscure the tested source identity.

## Selected host and bounded first slice

The selected lifecycle subject is the existing composable desktop host:

- `main.tscn` and its existing `CyberSimulationWorker` exclusive native owner;
- main-thread `CyberPhysicalActorSession` and Rapier bridge;
- the exact authored `playground/player-course` MicroScenario;
- one human SetP mechanical actor at a time; and
- copied immutable native snapshots plus main-thread physical observations.

No dedicated player World owner, worker framework, per-rig worker, mutable World
read or cross-thread Godot/Rapier object is introduced. #265 remains closed as
unnecessary. Material swarms #271 remain deferred. Specialist scientific,
physical-characterisation, 4LY and NPC-training fixtures keep their own strict
admission and deterministic execution paths.

The source candidate adds one shared helper and five automatically discovered
wrappers:

| Wrapper | Real host cycles |
|---|---:|
| `test_play_life001_stuntbuggy.gd` | 10 |
| `test_play_life001_trialsbike.gd` | 10 |
| `test_play_life001_acrobat.gd` | 10 |
| `test_play_life001_arcadelander.gd` | 10 |
| `test_play_life001_jetbarrel.gd` | 10 |
| **Total per operating system** | **50** |

The common implementation is
[`play_life001_shared_host_case.gd`](../../godot/tests/play_life001_shared_host_case.gd).
Each wrapper is a separate ordinary regression process so one process is
bounded to ten lifetimes and retains the repository's existing 180-second case
limit. The source does not change CI timeouts, retry policy, sharding, error
filtering or provider routing.

## One lifecycle transaction

Each cycle constructs a fresh real desktop scene and checks:

1. the existing asynchronous worker Thread starts;
2. the authored course is admitted by the normal MicroScenario selector;
3. F5/SetP constructs the requested human mechanical rig;
4. actor epoch, native render-World generation and hard-terrain acknowledgement
   match before play;
5. native and Rapier clocks both advance while retaining independent owners;
6. a press and release submitted before another physics callback remain two
   ordered commands in the existing `submit_local` edge queue;
7. a test-only focus refusal uses the normal `actor_keyboard_allowed` boundary,
   cancels the current human generation, empties pending edges and requires
   neutral release before rearming;
8. pause prevents completed Rapier ticks and resume produces a fresh tick;
9. R/reset installs newer actor and native World lifetimes while retaining the
   same authored course and selected rig;
10. the prior Rapier session is retired, an earlier immutable snapshot remains
    unchanged and the lap session starts neutral; and
11. scene exit runs the production `_exit_tree`, joins the worker and retires
    the final main-thread Rapier session.

The helper records a `PLAY_LIFE001_CYCLE` row per completed cycle and a final
`PLAY_LIFE001_RESULT` containing requested/completed cycles, assertion and
failure counts, joined-worker and retired-session counts, wall duration and the
maximum individual-cycle duration. These timings are diagnostic observations,
not FPS, responsiveness or release thresholds. There are no retries or silent
skips.

## Explicit exclusions and preserved liquid policy

This first slice deliberately does **not** claim:

- delayed/native-stall UI responsiveness;
- fifty solver reconstructions;
- the separate supported-policy reconstruction and transactional-refusal case;
- close during pending terrain or pending prepared-owner commit;
- failure injection or quarantine recovery;
- hardware gamepad qualification;
- rendered frame pacing, parallel speedup, subjective handling or release
  readiness.

Those remain separate #269/#266/#270 gates. The candidate never changes native
material source, solver families, defaults, capacities or policy parsing. The
accepted construction-time per-material selection and prepared-World receipt
path—including Water `pressure_flow_v1`, requested-versus-applied readback and
unsupported-route refusal—remain exactly as inherited from #276 and the
five-rig regression. This draft neither hot-switches a live World nor rewrites
LCB/scientific reference fixtures.

## Qualification state

The source was published through the GitHub connector; no Godot process was run
locally and no pass count is asserted. The PR must remain draft while PR #280 is
unaccepted. After the dependency lands, the candidate requires:

- a non-forced integration/retarget to the exact accepted main;
- ready-for-review Documentation/provenance, Native and complete Windows/Linux
  Godot/GDExtension workflows;
- readback of all five `PLAY_LIFE001_RESULT` records on each OS, establishing
  exactly 50 completed real-host lifetimes per OS and no diagnostic errors;
- source/runtime/artifact hashes, clean-checkout and ordinary timeout evidence;
- confirmation that existing five-rig, lap, liquid-policy, specialist physics
  and NPC/4LY suites remain green; and
- independent source and execution review before merge.

A failed or timed-out wrapper is evidence, not permission to retry, raise the
limit, reduce cycles or claim the other rigs qualified. Later adversarial and
slow-native slices must preserve the same source-matched discipline.

## Corrected dependency and predicate preparation — 2026-10-28

The earlier branch-origin statements above remain historical. Non-forced
merge `b5a5d8e5e702d408e66089f0e25e63f0f4cde3aa` incorporates corrected
PR #280 source `8533876b1a4df74cdf8a16c54f8f2201f66cb9de`, retaining the
lifecycle history and changing only the seven lifecycle paths relative to that
corrected base. The parent candidate now has an actual successful
[Windows/Linux Godot run 40600760606](https://github.com/techrote/cybersand/actions/runs/40600760606),
but its complete Native/merge acceptance is separate and was still outstanding
when this source checkpoint was prepared. Parent receipts are not execution
of these fifty new lifetimes.

The independent input-edge finding was addressed in `3383599072f4d8a0a0ffe1814a3a547325aa7193`:
the source checks an actual copied `primary=true` then `primary=false` queue
produced by `Input.parse_input_event` and the production Viewport event handler.
It no longer treats W/D command counts as queued button-edge evidence or uses
extra direct submissions that could mask a broken event route. Focus refusal
then clears the genuinely populated queue and advances its control generation.

Further source inspection found the lifecycle resume predicate still contained
the unparenthesized multiline inline-return pattern implicated in the parent's
[retained cadence-test parse failure](2026-10-27-play-ui003-exact-head-parse-failure.md).
This is a source finding, not an executed failure of the lifecycle candidate.
Code checkpoint `e8bbec46cfa570e8164c4250b355365a551c2020` extracts named
`clocks_advanced`, `physics_resumed` and `reset_installed` predicates with
explicitly parenthesized Boolean expressions. All five asynchronous wait sites
use named `Callable.bind` targets. The same scene, rig, tick/epoch thresholds,
assertions, focus/input/cancel semantics, ten-cycle count, wait timeouts and
teardown paths are retained. No production or CI file is changed.

The published commit diff was inspected. Local repository cloning failed
because the execution container could not resolve `github.com`; no local
Godot parse, import, native build or runtime pass is claimed. New exact-head
source review and the full execution gates above remain required after parent
acceptance. The original failed parent CI and earlier lifecycle drafts remain
preserved; no result is relabeled as a pass for the new source.

## Accepted parent and content-identical lifecycle integration — 2026-10-28

PR #280 is now **merged**, not pending: accepted main merge
`69e340d390e3e563833e80659aa97fddc2922310` has tree
`63c6612fcaecdacad26452f7d15dfb118d410d9d`, identical to reviewed
UI-003 source `8533876b1a4df74cdf8a16c54f8f2201f66cb9de`.
Its exact-head [Godot Windows/Linux 40600760606](https://github.com/techrote/cybersand/actions/runs/40600760606),
[Native 40600760721](https://github.com/techrote/cybersand/actions/runs/40600760721)
and [Documentation 40600760603](https://github.com/techrote/cybersand/actions/runs/40600760603)
all completed successfully. The Native run's head is exactly `8533876b`;
its 2026-10-28 01:27 UTC conclusion and prior failed revisions are retained.
The source-matched positive and render-only negative cadence results and the
model-only 50-lifetime result remain **parent-only** evidence, not proof of this
new real-host campaign.

This branch normally integrated accepted main with a **non-forced two-parent
merge commit** `f026e4c9075cc4fc26b916e0fc125a1aa26874af`, parents
`16934e59f201be2b7eec343cb192c04f16c39d14` (lifecycle work) and
`69e340d390e3e563833e80659aa97fddc2922310` (accepted main). The
merge retains the lifecycle tree `fa0f6ac17649203b4c3861c451a5e630797f3746`
without source modifications. The main-to-lifecycle file comparison is exactly
seven additive lifecycle paths: one audit, one shared test harness, five rig
wrappers; no production, solver, specialist fixture or workflow path changes.
PR #284 is retargeted from the old UI branch to `main`.

**Current classification:** ready candidate for independent exact-head review
and full qualified Windows/Linux actual-host execution; not accepted. Until
fresh `PLAY_LIFE001_RESULT` receipts establish ten of ten joined/retired
cycles for each of five rigs on each OS, no real-host fifty-cycle claim exists.
Separate slow/pending/fault and supported per-material policy-rebuild/refusal
stress remains open under #269. No timeout increase, retry, skip, source or
historical evidence rewrite is allowed.
