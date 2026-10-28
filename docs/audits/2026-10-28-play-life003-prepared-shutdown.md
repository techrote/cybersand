---
title: PLAY-LIFE-003 actual-host prepared reconstruction shutdown
status: Planned
document-kind: evidence
scope: Source-bound local Windows cancellation, Main/Rapier retirement and owner destruction at the prepared precommit boundary; hosted Linux and final acceptance pending
canonical-for: []
last-reviewed: 2026-10-28
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/local-build-and-validation.md, 2026-10-28-play-life002-solver-reconstruction.md]
---

# PLAY-LIFE-003 prepared reconstruction shutdown — 2026-10-28

## Post-review safety-helper correction

A follow-up review at source `2421c5a2` found a P2 apparatus boundedness gap:
blocking `_mutex.lock()` could prevent the helper from checking its deadline
under a mutex-retention regression. The outer 180 s case guard still applied;
the retained 135/0 successful cohort below remains valid, but does not exercise
that failure path. No production behavior is changed by this correction.

The helper now uses Boolean `Mutex.try_lock()`, reads/unlocks only on success,
and rechecks its deadline after failed acquisition. Godot 4.7 returns Boolean,
not `Error`: a distinct reviewer verified the
[versioned API](https://raw.githubusercontent.com/godotengine/godot/4.7-stable/doc/classes/Mutex.xml)
and exact pinned runtime. Its outside-checkout probe made fourteen unsuccessful
nonblocking attempts while main retained the mutex, released at 25 ms and joined
without acquiring it. Probe root `C:/tmp/play-life003-mutex-api-20261028`;
script SHA-256 `e2e2656341c592710bb6c56bfcc6bbe42ae603f997ee8427131544ddbd0b4e6b`,
log `8ad6bc356a8c854364d629e1061567b05815b03d390afd71c88c6241842c85a7`.

A new adversarial arm holds the actual joined worker's mutex on main, uses a
25 ms test-only helper budget, and requires semaphore release while that mutex
is still held with `deadline_expired=true` / `stop_observed=false`. It always
unlocks before joining, even after the existing 15,000 ms predicate fails.
The actual pending-construction shutdown retains its 15,000 ms safety budget;
process/import bounds are unchanged. This adds three assertions per rig.
Fresh source-bound actual-host execution and renewed independent review remain
required; the API probe and earlier cohort are not relabeled as that proof.

This bounded #269 successor adds tests while #287/#288 await final hosted
acceptance. It does not change production source, native workers, solvers,
defaults, actors, dependencies, CI policy or any accepted fixture. #270 remains
open. The implementation is recoverable as `2290048621bc5524bda8df18603fbe1ce0799b88`,
branch `codex/play-life003-prepared-shutdown`, source root
`C:/Users/_/.codex/worktrees/play-pending-prepare-20261028/khybersand`.

## Actual ownership and claim boundary

The six new test paths are
`godot/tests/play_life003_prepared_shutdown_case.gd` plus five four-line
`test_play_life003_<rig>.gd` wrappers. They extend the accepted LIFE001
apparatus and use the actual `main.tscn`, `CyberSimulationWorker` and selected
main-thread Rapier SetP graph, not a model World or a second scheduler.

For each rig the normal liquid panel requests supported Water
`pressure_flow_v1/reference` reconstruction. The existing
`_controlled_liquid_prepare_barrier` holds the exclusive owner after native
preparation and physical-candidate readiness, immediately before its commit
fence. At least seven completed actual Main callbacks must progress while the previous
accepted actor/World/policy/receipt remains unchanged. This is main callback
progress under a held preparation, not rendered FPS or a slow native tick.

Main then exits on the main thread. A test helper thread reads only the
mutex-protected owner stop flag, releasing the semaphore after that fence. Its
15,000 ms unconditional safety release prevents an earlier failure from
stranding Main; using that safety deadline is a test failure. The helper never
reads a native World, scene or Rapier object. The actual accepted/staged Rapier
sessions, bodies and staged private viewport must retire, Main must free, and
the exclusive Godot pacing thread must join.

Only after the confirmed join may the test inspect the adapter: applied native
generation/policy/receipt must remain unchanged, pending publication/readiness
must be empty, the prepared native token must be retired and the immutable old
snapshot must remain intact. After clearing test Callables and dropping all
retained worker/adapter references, both WeakRefs must expire.

This qualifies **pending construction cancellation and actual-host teardown at
the precommit boundary**. It does not hold native simulation phase jobs, inject
a slow `World::tick`, observe an OS native-thread join trace, prove simultaneous
pool execution or qualify failure quarantine recovery, populated stale commands,
physical gamepad, rendered pacing or human feel. Adapter destruction plus the
source destructor contract is distinct from an independently observed native
pool join trace. No live solver hot swap or new default is introduced.

## Exact local Windows execution

The executed source is checkout
`0a17fd97b6192eb581c80b48f78aef93ee79637b` plus six new uncommitted test files.
Their hashes below match committed implementation `22900486` exactly. This
is not execution of the later audit/documentation tree. All 80 published native
input hashes match exact checkout blobs.

Host: Windows 11 `10.0.26300`, AMD64 Family 25 Model 33 Stepping 0;
Python 3.12.10; Godot `4.7.stable.official.5b4e0cb0f`. Retained native DLL:
`e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb`,
4,825,088 bytes. Rapier DLL:
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`,
9,987,072 bytes. Runtime objects were materialized from their exact LFS pins;
no runtime/provenance file changed in Git.

The driver uses the existing strict
`tools/ci/run_godot_regressions.py::run_case` for import and all five wrappers:

```text
C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path <source>/godot --editor --quit
C:/Godot47/Godot_v4.7-stable_win64_console.exe --headless --path <source>/godot --script res://tests/test_play_life003_<rig>.gd
```

Import retains 240 s; each case retains 180 s; predicates and the helper safety
release retain 15,000 ms. No retries, skips, increased timeout or relaxed error
scanner is used. The final source cohort is `final-whitespace`:

| Process | Seconds | Assertions / failures |
|---|---:|---:|
| Import | 4.296 | n/a |
| Acrobat | 3.620 | 27 / 0 |
| Stunt buggy | 3.618 | 27 / 0 |
| Trials bike | 3.619 | 27 / 0 |
| Arcade lander | 3.715 | 27 / 0 |
| Jet barrel | 3.529 | 27 / 0 |

All six processes exit 0 with zero diagnostic errors, skips or timeouts.
Total **135/0**, five held prepared operations, eight Main callbacks per rig,
five observed stop fences, five owner joins, ten accepted/staged Rapier graph
retirements, five worker destructions and five native adapter destructions.
Prepared token is 1; applied native session and World generations remain 3
on each rig. These five hosts are separate from LIFE001's fifty-host campaign
and LIFE002's successful reconstruction/refusal cohort.

## Retained source and evidence identities

Evidence root: `C:/Users/_/.codex/tmp/play-life003-20261028/final-whitespace`.
Complete commands, process IDs, bounds, exit/diagnostic/skip/timeout fields and
raw `PLAY_LIFE003_RESULT` rows remain there.

| Source under `godot/tests/` | SHA-256 |
|---|---|
| `play_life003_prepared_shutdown_case.gd` | `c5ba2ec904c38925b7f83c5206466b742294570ac19d3c68f28507fba116dfd6` |
| `test_play_life003_acrobat.gd` | `9fcc5b8569df4e4f2f1323da667f07b66ec0f3832b4d227a7597972b62d32a92` |
| `test_play_life003_arcadelander.gd` | `5a3e759ea4c2420c024a21fc8314a0b510174894b3283d5ffa0d8dcaa90e768c` |
| `test_play_life003_jetbarrel.gd` | `86aa7c0d203a94c0704eb55d06bd78ceae4f4c2e85f205ea3acfcfe1792ea79c` |
| `test_play_life003_stuntbuggy.gd` | `78ef88b3a2cfe7edba5a26fc2c802126263524f9e9e07fb022e335f4bf2096e9` |
| `test_play_life003_trialsbike.gd` | `34ea2999c7dab9227956592d278785ee39ade3d9dda6c6dc39c1d5f58ae02e77` |

| Evidence | SHA-256 |
|---|---|
| `identity.json` | `1fe43ae0f02e9762f7d6b12f98709ef86f21c4c6ac75b01dfc695a7df9a959cd` |
| `timings.json` | `aff802152819e6ae83d55832b6ba0b9d5826f43e444012a9c479da20cb553b38` |
| `import.log` | `8c0a07c84db58235454f32ecfb9b1d914c0797d8dc8eade2c911a6976989cc99` |
| `test_play_life003_acrobat.log` | `0aecb80c14f7b935f5a68964536a4866e4f4609985480227668adcb5691d39ec` |
| `test_play_life003_arcadelander.log` | `65490754468daadb1ba3b9d6f57df6ef005151cb143f3a9a3f34a429c82f4cc1` |
| `test_play_life003_jetbarrel.log` | `7c4c3533d4878db8c93926fb91151ddc111d2735ad76ecaa0196fa843028fb42` |
| `test_play_life003_stuntbuggy.log` | `dd4be53348059b19dfc13f7ce5d81d2034c55c09b86d74c8734f202bf94cade3` |
| `test_play_life003_trialsbike.log` | `f30029727d03115f6784c37299829d76ecde08a81dd14a95e53579351bb706de` |

Prior cohorts are retained unchanged. `initial` passed import/Acrobat 26/0
before defensive failure-path additions. `defensive-five-rig` passed 135/0;
staging then detected an extra EOF blank line in each new source file. Only
those blank lines were removed, followed by the distinct complete final-source
cohort above. No failing runtime cohort is hidden or relabeled. Generated
import/UID changes were cleaned only from this fresh managed worktree after
execution; the six implementation files remain unchanged.

## Documentation and acceptance map

The player contract owns the test's current source behavior and explicit
qualification limits; roadmap/index and a separate additive PLAY retrieval
question route readers there. Production ownership/lifetime, interfaces,
capacities, ADRs, user controls and solver capability/default policy are
unchanged. Existing strict runner discovery automatically includes the five
wrappers; no CI workflow or test runner is modified.

The five pinned companion files were copied outside the source root from the
same `6a58311982941b75f46e22109a0829e5acb83c7e` companion checkpoint used by
the other PLAY managed worktrees. No checker, historical hash or source file
was changed to repair that layout. Local documentation/repository checks pass
with zero errors (115 documents, 228 canonical claims); historical M11 passes
18 records/28 hashes. Frozen lexical retrieval remains 32/32 at five, 19/32 at
one, MRR 0.7589; the separate four-question PLAY set scores 4/4 at one. Diff
whitespace checks pass. These structural/lexical results are not runtime proof.
Distinct source and local-evidence review, accepted-parent integration, fresh exact-head hosted
Windows/Linux execution and final artifact review remain publication/merge
gates. Local Windows success does not satisfy them. #266/#268/#269/#270 remain
open, #265 remains closed and #271 deferred.
