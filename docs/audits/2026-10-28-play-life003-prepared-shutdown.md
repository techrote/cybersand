---
title: PLAY-LIFE-003 actual-host prepared reconstruction shutdown
status: Current
document-kind: evidence
scope: Accepted source-bound Windows/Linux prepared-construction cancellation, Main/Rapier retirement and owner destruction; slow native jobs and release acceptance remain open
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../systems/player-control-playground.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/liquid-prepared-setup-and-receipts.md, ../operations/local-build-and-validation.md, 2026-10-28-play-life002-solver-reconstruction.md]
---

# PLAY-LIFE-003 prepared reconstruction shutdown — 2026-10-28

## Accepted source and subsequent main verification — 2026-10-29

[PR #289](https://github.com/techrote/cybersand/pull/289) accepted source
`92e0bccaa5b491c4dd7ec2cfbb4fa6ef88edaea6` through guarded non-forced merge
`91778603db950a817b82fc6a4f75efee201f5044`. Its tree
`3e513ab8b38a5d1d8076b5a4156d234f8d8a068f` equals the reviewed source and
actual CI checkout `57ae8ef4b8facef4d793cbf0724bbd3c80392a0f`.
Exact-head attempt1 [Documentation](https://github.com/techrote/cybersand/actions/runs/40770376178),
[Native](https://github.com/techrote/cybersand/actions/runs/40770376210),
[Windows/Linux Godot](https://github.com/techrote/cybersand/actions/runs/40770376408)
and [distinct final source/execution review](https://github.com/techrote/cybersand/pull/289#pullrequestreview-5690658119)
passed before merge. Subsequent main push runs
[Docs40781959329](https://github.com/techrote/cybersand/actions/runs/40781959329),
[Native40781959243](https://github.com/techrote/cybersand/actions/runs/40781959243)
and [Godot40781959458](https://github.com/techrote/cybersand/actions/runs/40781959458)
also pass on that merge commit. Optional skipped jobs are not execution results.

The final ready-head Godot matrix passes Windows179 applicable cases plus
import and Linux191 unique cases plus four imports. Each OS observes
**150 LIFE003 assertions / zero failures**, eight completed Main callbacks
per rig, five stop fences/owner joins, ten graph retirements and five worker/
native-adapter destructions. Retained LIFE002335/0 and LIFE00150 real lifetimes/
1,165 assertions also pass. All eight retained ZIP digests were independently
verified, including Native164 tests in ordinary/TSan/ASan-UBSan variants.
Native ASan leak detection is disabled, so this supplies no general leak claim.

The [acceptance ledger](https://github.com/techrote/cybersand/issues/269#issuecomment-6482610414)
records artifact identities, source inputs and bounded limits. All847 CI
readback files are hash-verified in
`C:/Users/_/.codex/artifacts/play-life003-ci-2026-10-28`; combined ledger
SHA-256 `49f12baa901697adf151f9141ec2271f3e9b52514abb4da919ed5ff1297d63ad`.
Local proof/probe cohorts remain separately backed up in
`C:/Users/_/.codex/artifacts/play-life003-local-2026-10-28`.
Historical candidate/pending statements below retain their original source
scope. No slow native phase-job, OS thread-join trace, rendered pacing,
physical-device or human-feel qualification follows; #269/#270 remain open.

## Accepted-parent integration and clean Windows proof

Non-forced merge **`9782693c0d3d45add39d4b0a26e60e6a6410b214`**, tree
**`692b6fd4517c165d52ba6bf8889343736815b393`**, consumes accepted main
`37da3c6cf8f7893ce4ab57baa224ab2624f4306d` after #287 and #288 passed their
own exact-head checks, distinct final reviews and guarded merges. All six
LIFE003 test hashes remain exact corrected implementation `cd5f2ce5`; no
production/native/default/dependency/runtime path changes in the child.

A fresh **clean committed-source** Windows cohort executes `9782693c`, with
all 80 native inputs matching the unchanged published runtime and all six test
working files matching their exact Git blobs. Strict import plus five rig
processes pass **150/0**, 30 per rig; all exit 0 with no diagnostic error, skip,
timeout or retry. Eight actual Main callbacks per rig, five ordinary stop
fences/joins, ten Rapier graph retirements, five worker/adapter destructions and
five contended safety releases are observed. Actual shutdown keeps its 15,000 ms
safety bound; only the independent contention arm uses 25 ms. Import/case/
predicate bounds remain 240 s/180 s/15,000 ms.

Evidence root `C:/Users/_/.codex/tmp/play-life003-20261028/post-main-9782693c`;
collector `C:/tmp/run_play_life003_exact.py` records its own hash and reuses the
strict existing runner. Import takes 4.195 s; Acrobat/Buggy/Bike/Lander/Barrel
take 3.625/3.619/3.716/3.804/3.617 s. Native/Rapier/Godot identities remain those
recorded below. This later documentation append has no execution of its own;
final hosted Windows/Linux, Native/Docs and distinct final source/execution
reviews are tracked on [PR #289](https://github.com/techrote/cybersand/pull/289).
No earlier-head or local proof substitutes for those gates.

| Integrated-source evidence | SHA-256 |
|---|---|
| `identity.json` | `9fee5dfa550f61da6aa772c4fbb513af32212f931303780365311d607cb644f4` |
| `timings.json` | `cfdadb6f6adc01d811e03b178cc35ed3fdaeba2c0af1660a0ff357bcb8a7d333` |
| `results.json` | `3a370f72c10524acfa000a91eeb95c3d1fc21ad439cc9925d3e1119d328d87ba` |
| `import.log` | `ac8d3746b742352a044ba1f2c39fc77fc3e88efe3c6cd8c6ccfbc143afa36ecc` |
| `test_play_life003_acrobat.log` | `a093f01439a7d3db77c16dbbc421e3df31aa375727156e5cafdda874b8f9158a` |
| `test_play_life003_stuntbuggy.log` | `aa28b94df56d9455166b942c879bbeb86fa76caf6804dfc4fd1fe5a9fe709302` |
| `test_play_life003_trialsbike.log` | `c2c5c86f1b99b084dcf0c60a13aa5b6f2b4114477da47b9bb17da1acb18f03de` |
| `test_play_life003_arcadelander.log` | `4a5888dad7ac50b4e5f66f333e81455667e181b6c8af96c7c2df4f94abdf415b` |
| `test_play_life003_jetbarrel.log` | `a5b9352819922dca1e25c3cea93627d442ab565ca79345ce9426eccab7ccd287` |

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
Fresh local proof below supplies the corrected source's Windows execution;
renewed independent review and final hosted qualification remain required. The
API probe and earlier cohort are not relabeled as the corrected source's proof.

## Fresh Windows proof of the nonblocking safety revision

Clean committed source `cd5f2ce57b4676520dc69e8bf9ab2312d0aea77c` passed
strict import plus all five real hosts: **150 assertions / zero failures**,
30 per rig. The original actual-host stop/receipt/graph/WeakRef checks are
unchanged; each rig adds three contended-helper checks. All five show eight
Main callbacks, one ordinary stop fence/join, two graph retirements and worker/
adapter destruction. Each contended arm releases while main retains the mutex,
reports deadline expiration without observing the protected flag, and uses the
25 ms test budget. Observed arm times are 31/30/25/25/25 ms in
Acrobat/Buggy/Bike/Lander/Barrel order; no exact upper-time assertion is made.

The collector `C:/tmp/run_play_life003_exact.py` calls the same strict runner,
records a clean source/tree and all six exact Git-blob hashes, verifies all
80 native inputs and the unchanged runtime pins, and validates the raw result
markers. Evidence directory:
`C:/Users/_/.codex/tmp/play-life003-20261028/nonblocking-safety-cd5`.
Import takes 4.484 s; rig processes take 4.021/3.923/3.632/3.621/4.266 s.
All six processes exit 0, with no diagnostic error, skip, timeout or retry.
Import/case/predicate/ordinary-safety limits remain 240 s/180 s/15,000 ms/15,000 ms.

Only the shared helper's source hash changes:
`4e6c266008737a09b2718be9cc69d37fe066ea64432a9691225d39b9027ad526`;
the five wrapper hashes remain those in the original source table below.

| Corrected-source evidence | SHA-256 |
|---|---|
| `identity.json` | `69c71d7f386ad4620bf448e5f5bd9a632c37d20795f7826863e1470f533432db` |
| `timings.json` | `8d41387ada15e38608b26d6dab7f94493c24400f4bba42751dce745cbfb94359` |
| `results.json` | `3f4920b852b7e92a6a8ed0df7c564592bf9cab587a1d0581b6ac2291ba38f998` |
| `import.log` | `29e5c3ca9853eb98bd45e339fc2316fccbf942790019414161a53a21c2fb2d89` |
| `test_play_life003_acrobat.log` | `b5460f0d5748eaa499523089e9348bd473ff3f3439baaf67c33a92b170e1ac2d` |
| `test_play_life003_stuntbuggy.log` | `165a1a8737e4e6054e6cc851746294d8265c2f71e83b8a14f6a4ed43b717b0b7` |
| `test_play_life003_trialsbike.log` | `0d16daeb31d509d74fe6f97cbaa8e6fa6cebe84ad4a6f1109172239a77be60ec` |
| `test_play_life003_arcadelander.log` | `3901adbe125cb2f92adcdcb850271f34f20323bb79f425289d139b5ee0766b33` |
| `test_play_life003_jetbarrel.log` | `b736c65d7e7e0bc2ef9d0446025bf46b6de1d543f718ad76538ad63a872dba07` |

This is execution of clean `cd5f2ce5`, not a later documentation append or
accepted-parent integration. Generated import/UID files were cleaned after
execution; original evidence directories remain untouched. Linux and final
exact-head hosted checks/review are still required.

## Original candidate and retained local cohort

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
