---
title: PLAY-LIFE-001 shared-host lifecycle candidate
status: Planned
document-kind: evidence
scope: Source-only fifty-lifecycle Windows/Linux candidate for the composable desktop Player Playground host
canonical-for: []
last-reviewed: 2026-10-27
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
