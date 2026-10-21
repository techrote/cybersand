---
title: Player playground PR 189 integration and completion checkpoint
status: Current
document-kind: evidence
scope: Original-head hosted results, GEN-003 integration, measured combined-source local validation, scoped runtime publication and final-head acceptance routing
canonical-for: []
last-reviewed: 2026-10-21
related-documents: [2026-10-20-player-control-playground.md, ../systems/player-control-playground.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# Player playground PR #189 completion checkpoint — 2026-10-21

The owner requested completion of
[PR #189](https://github.com/techrote/cybersand/pull/189). Its original implementation
and local validation remain preserved in the
[2026-10-20 audit](2026-10-20-player-control-playground.md). This record adds the
subsequent hosted results, current-main integration and completion work; earlier
passes do not certify the new combined source.

**Local preflight and scoped hosted runtime publication passed.** Combined-source
native tests, desktop builds and the strict Linux player/launcher suite passed.
Both published runtimes passed the ten focused cases on their actual target OS,
as recorded below. This documentation checkpoint precedes final
ready-for-review acceptance: the [PR description](https://github.com/techrote/cybersand/pull/189)
and [Checks](https://github.com/techrote/cybersand/pull/189/checks) record the exact
final PR head, required hosted outcomes, merge identity and landed-main result.
Local results and scoped runtime publication do not establish those final outcomes.

## Source identities

| Identity | Value |
|---|---|
| Repository and PR | `techrote/cybersand`, PR #189 |
| Feature branch | `feat/player-control-playground` |
| Original implementation base | `4f3685b71366218e82e7c2188e4ecdf27553f4cf` |
| Original PR head with completed hosted checks | `6663d8e25f4743d58863bf0538232e7c77c08f77` |
| Current main integrated for completion | `ba19d3a2b2608ef0ffbe252b684561e45aeaa457`, including GEN-003 / PR #195 |
| Recoverable integration checkpoint | `e7deae705af513bfb2793182f16f482b3430584f`, tree `b0758376e74ef8030277ad66337f01fd6d0f6cc2`; identical integration tree to local checkpoint `1caccf09d09148d97f16ec4a2bdd13a8a756477b` |
| Published implementation and publisher source | `72961e2c809313123b4fa93b4e2fd4c23045df38`, tree `8ac5894a9e883311adbc718ed788c05448084437` |
| Verified runtime publication | `1690cfb22643a0bcdbea19838238d35635f08146`, tree `4d49589a6f6294c5a1466c74d657c469d0471e7c`; sole parent is the built implementation source |
| Strict local player-suite checkout | `634c5ba6e14703e7b5f42fdbb452dc16e8e9735a`, with the exact same tree as published source `72961e2` |
| Final reviewed and tested PR head | Recorded as a full SHA in the [PR #189 description](https://github.com/techrote/cybersand/pull/189), with required results in its [Checks](https://github.com/techrote/cybersand/pull/189/checks) |
| Final merge and landed-main verification | Recorded in PR #189's merge event and final completion update after acceptance |

The integration preserves both the player material-field API and GEN-003 typed
spatial generation, including their native sources, bindings, tests and canonical
documentation routes. The two original branches had different native inputs.
Neither branch's retained runtime alone represents the combined tree; both
desktop binaries required a combined-source rebuild. Local build results are
recorded below; the hosted publication row owns the current manifest/artifact
disposition.
The GEN-003 build scripts retain their added typed/spatial compilation units and
Linux ABI-floor treatment. Dependency pins and historical M11 identities remain
unchanged.

## Original-head hosted evidence

The following completed workflows are associated with original PR head
`6663d8e25f4743d58863bf0538232e7c77c08f77`. They establish the scope of that
checkpoint and remain separate from final post-integration acceptance.

| Gate | Hosted result and evidence |
|---|---|
| Documentation and provenance | Passed, [run 39495144329](https://github.com/techrote/cybersand/actions/runs/39495144329) |
| Native C++ validation | Passed, [run 39495144589](https://github.com/techrote/cybersand/actions/runs/39495144589), [job 118878174997](https://github.com/techrote/cybersand/actions/runs/39495144589/job/118878174997); ordinary behavior, ASan/UBSan, TSan and the retained native apparatus completed |
| Linux extension and Godot regression | Passed, [run 39495144355](https://github.com/techrote/cybersand/actions/runs/39495144355); Linux build, all four regression shards and aggregate `linux x86_64` gate completed |
| Windows extension build | Passed, [job 118878171847](https://github.com/techrote/cybersand/actions/runs/39495144355/job/118878171847) |
| Actual Windows headless execution | Passed **107/107 applicable cases**, [job 118878171752](https://github.com/techrote/cybersand/actions/runs/39495144355/job/118878171752) |
| Water apparatus v2 | Passed, [run 39495144293](https://github.com/techrote/cybersand/actions/runs/39495144293), [job 118878171422](https://github.com/techrote/cybersand/actions/runs/39495144293/job/118878171422) |

The Windows job used actual Windows with Godot
`4.7.stable.official.5b4e0cb0f`, Rapier `0.35.2` and the retained source-matched
DLL. Its log explicitly executes all six new player scripts: acrobat state,
acrobat physics, material field, course traversal, integrated runtime and vehicle
controls. This supplies Windows headless execution evidence for the original
head; it does not imply physical gamepad, interactive window or target-PC feel
qualification.

Workflow review confirmed that `run_godot_regressions.py` discovers all
`test_*.gd` cases. Linux shards and the Windows headless wrapper consume that
discovery; Windows excludes only graphical cases owned by the Linux rendered
test lane. Native player-field groups participate in the complete ordinary,
ASan/UBSan and TSan World suites. The skipped optional serial-equivalence lane
is not substituted for a required regression result.

## Completion correction: admitted quick taps start course timing

Review found that a complete button press and release between physics ticks
could enqueue movement while the next sampled action was already neutral.
Movement correctly survived, but the scene started its lap clock only from the
fixed-tick sample. A fast jump tap could therefore produce physical motion
before timing began.

Both event-edge and fixed-tick submission now use the same scene helper. An
accepted active action starts the lap; refused actions do not. Elapsed time
still advances only when the runtime advances a simulation tick. The focused
real-scene regression checks neutral settling, press/release before the fixed
tick, physical jump execution, counting the first movement tick and continued
counting while coasting with neutral input. Existing cancellation, rearm,
pause and reset tests remain in the same runner.

The focused build guide now lists the course traversal script as well as the
other five new player runners. Full hosted discovery already included it.

## Scoped runtime publication

The combined-source LFS binaries are published through the separate
[player runtime workflow](../../.github/workflows/player-runtime-publication.yml)
and [verification helper](../../tools/ci/player_runtime_publication.py). This
completion helper leaves the existing GEN-003 publisher unchanged. Its only
trigger is an implementation-input push to `feat/player-control-playground` in
`techrote/cybersand`; runtime/manifests and documentation are excluded from the
trigger to avoid recursive publication.

GitHub-hosted Linux builds both targets with the existing pinned dependencies.
Actual Linux and Windows jobs then execute import, all six player regressions
and four legacy/typed worldgen checks against the exact built artifact. Native
and build/test inputs are bound to canonical Git blob hashes. A valid receipt
requires the complete case list, positive assertion summaries, the all-seven
player runtime scope, no errors or skips, matching logs and the pinned engine
and Rapier identities. This focused execution does not replace full PR CI.

The publication job has the sole write permission. It rechecks the repository,
feature branch, workflow identity and unchanged source head; both platform
bundles must have identical source/build ledgers. Its allowed write set is
limited to the two native LFS binaries and their two manifests. Both manifests
must change, and both staged LFS pointers must match the verified bytes even
when a deterministic rebuild leaves a binary unchanged. A single-parent commit
and an exact expected-head lease permit only an append to the built source and
refuse concurrent branch changes. The helper's focused adversarial tests cover
wrong source/context, omitted or narrowed execution, errors/skips, log changes,
unexpected publication paths, mismatched pointers and unchanged binary bytes.

## Local combined-source preflight

The native inputs tested and built here match the integration source at
`e7deae705af513bfb2793182f16f482b3430584f`. Subsequent control, publication-helper
and documentation changes do not alter those native inputs. These local
results are separate from source-matched hosted publication. All
**42 native input SHA-256 hashes** were rechecked against the local prebuild
snapshot and remain unchanged.

| Local check | Completed result |
|---|---|
| Full native World behavioral suite | **84/84 tests passed**, including the six player material-field groups |
| Native generation suite | All **seven executables passed**: world generation, fresh-chunk installation, scalar fields, modifiers, typed fields, typed integration and spatial operators; typed-field execution reported **14,162 assertions** |
| Linux combined-source extension build | Passed with pinned GCC 13.3.0, GNU binutils 2.42, godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1 |
| Linux ABI floor | Passed: bundle GLIBC 2.34; CyberSand GLIBC 2.32 / GLIBCXX 3.4.30 / CXXABI 1.3.9; Rapier GLIBC 2.34 |
| Windows combined-source extension cross-build | Passed with pinned LLVM-MinGW 20260826 UCRT; this local cross-build result establishes no Windows execution |
| Publisher guard regression | `python3 tools/ci/test_player_runtime_publication.py`: **15 tests passed** |
| Independent publisher portability review | The same 15 tests passed under emulated Windows default CRLF and Git `core.autocrlf=true`; target-OS refusal and all ten required headless cases were independently checked |
| Current documentation and CI-provider policy | Passed on the current checkout; documentation lint covers 96 documents |
| Historical M11 integrity | Passed for all 18 retained records; historical identities were not rewritten |

The native commands below ran from the source root with GCC 13.3.0. Their
per-command JSON receipts record exit code 0 and measured duration:

| Command | Timeout | Duration | Result |
|---|---|---|---|
| `make -j2 build/tests` | 15 minutes | 11.023 s | World test executable built |
| `./build/tests` | 15 minutes | 247.874 s | 84/84 tests passed |
| `make -j2 worldgen-test` | 15 minutes | 202.202 s | All seven generation executables passed |

The executable `build/tests` has SHA-256
`13e295cab7c1a32639f4b4abb5ba2f646569969e94143fc814051754eda5b8f6`.
The exact launched commands use the `timeout 15m` prefix. Their logs and timing
receipts are `native-world-build.{log,json}`, `native-world-test.{log,json}` and
`native-worldgen-test.{log,json}` under the local `pr189-validation` directory.

| Local artifact | SHA-256 |
|---|---|
| Linux `libcybersand_native.linux.x86_64.so` | `47ee8025ad74d4ad16d9e87419b84abd3159f4023842a9947b788e3c54eb5f35` |
| Windows `cybersand_native.windows.x86_64.dll` | `aa2d4a7a90e06b740d576e3b7f035bcbb5ed23dc5b1d550eb8a55612050b867e` |

Both local build outputs were retained separately under
`/workspace/scratch/eb5bbaa104f4/pr189-validation/local-runtimes`. These hashes identify the local builds and do not
pre-claim the bytes or execution results of a later hosted rebuild. Neither a
successful cross-build nor publisher guard tests constitute actual Windows
gameplay execution. Hosted LFS/runtime-manifest publication has its separate
disposition below.

## Strict Linux player and launcher execution

The completed focused suite ran against local source
`634c5ba6e14703e7b5f42fdbb452dc16e8e9735a`, whose tree exactly matches published
source `72961e2c809313123b4fa93b4e2fd4c23045df38`. It used Godot
`4.7.stable.official.5b4e0cb0f`, the local Linux runtime with SHA-256
`47ee8025ad74d4ad16d9e87419b84abd3159f4023842a9947b788e3c54eb5f35`, and pinned
Rapier SHA-256 `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.

**Result: 3,982 assertions passed, zero errors and zero skips**, plus successful
import and the explicit player launch/return route. The integrated runtime
summary explicitly records `scope=all-seven-native-and-Rapier`; its 1,329
assertions include the admitted quick-tap timer regression.

| Invocation after `godot --headless --path godot` | Timeout | Duration | Passed assertions/result |
|---|---|---|---|
| `--editor --quit` | 240 s | 5.323 s | Import passed |
| `--script res://tests/test_player_acrobat.gd` | 180 s | 0.316 s | 304 |
| `--script res://tests/test_player_acrobat_physics.gd` | 180 s | 1.173 s | 36 |
| `--script res://tests/test_player_material_field.gd` | 180 s | 0.567 s | 56 |
| `--script res://tests/test_player_playground_course.gd` | 180 s | 5.349 s | 1,446 |
| `--script res://tests/test_player_playground_runtime.gd` | 180 s | 8.719 s | 1,329; all seven presets |
| `--script res://tests/test_player_vehicle_controls.gd` | 180 s | 1.118 s | 79 |
| `--script res://tests/test_feature_launcher.gd` | 180 s | 8.506 s | 39 |
| `--script res://tests/test_actor_rig_integration.gd` | 180 s | 5.492 s | 693 |
| `--script res://tests/test_feature_launch_arguments.gd -- --player-playground --player=acrobat` | 180 s | 3.489 s | Explicit launch and return passed |

Here `godot` denotes the pinned executable
`/workspace/scratch/eb5bbaa104f4/pr189-tools/godot/Godot_v4.7-stable_linux.x86_64`;
the actual `--path` was
`/workspace/scratch/eb5bbaa104f4/cybersand-pr189/godot`. The shared strict runner
enforced the process timeouts, rejected nonzero exits, engine/script errors and
skip output, and retained each command, duration and assertion summary.
Its measured process durations sum to 40.052 s. Evidence is retained under
`/workspace/scratch/eb5bbaa104f4/pr189-validation/player-local`: `identity.json`,
`timings.json`, `runner.log` and the individual process logs.

### Preserved initial sandbox refusal

The first import attempt, on local checkpoint `fbba87d4d3338d83f7f05a91b8f475bd908c1ea7`,
could not create Godot's local listener inside the restricted execution sandbox.
It reported `_sock == -1` and `ERR_CANT_CREATE`; although Godot returned exit
code 0 after 6.505 s, the strict runner correctly classified the import as failed
and did not run the fixtures. That attempt remains under
`player-local/attempt-sandbox` and is excluded from the successful totals.
After the required execution permission was supplied, the unchanged runtime
and gameplay fixtures passed the import and full focused run above. No test
error filter was relaxed and no gameplay change was made for the sandbox failure.

## Combined runtime and final validation

The scoped publisher runs against implementation source
`72961e2c809313123b4fa93b4e2fd4c23045df38` in
[run 39556052782](https://github.com/techrote/cybersand/actions/runs/39556052782).
All four jobs passed. Publication commit
`1690cfb22643a0bcdbea19838238d35635f08146` has the built source as its sole parent
and changes only the two native LFS binaries and their two provenance manifests.
Both manifests bind the same 42 native inputs and 346 build/test inputs to the
implementation source. Their build/source identities remain intact in the later
documentation-only checkpoint.

| Required completion evidence | Result |
|---|---|
| Combined-source Linux runtime build, native-input manifest and ABI floor | PASSED: [Linux job 119075958429](https://github.com/techrote/cybersand/actions/runs/39556052782/job/119075958429); import and all ten focused cases, 4,076 assertions, zero errors/skips; ABI floor passed |
| Combined-source Windows runtime build and native-input manifest | PASSED: [cross-build job 119075958063](https://github.com/techrote/cybersand/actions/runs/39556052782/job/119075958063) and [actual Windows execution job 119078011105](https://github.com/techrote/cybersand/actions/runs/39556052782/job/119078011105); import and all ten focused cases, 4,105 assertions, zero errors/skips |
| Native player-field regression and applicable integration checks | Local 84/84 World tests and all seven generation executables PASSED; final hosted ordinary/sanitized gates remain separate |
| Scoped publisher guard and portability regressions | 15 tests PASSED normally and under independent Windows CRLF / `core.autocrlf=true` emulation |
| Fast-tap timer and player runtime/course regressions | Strict Linux focused run PASSED: 3,982 assertions, import and explicit route return; zero errors/skips |
| Local documentation, retrieval and historical M11 checks | 96-document lint, provider policy and 18-record M11 integrity PASSED; frozen retrieval 21/32 hit@1, 32/32 hit@5, MRR 0.7953; supplementary retrieval 75/94 hit@1, 94/94 hit@5, MRR 0.8775 |
| Published runtime materialization and current provenance | Clean publication-based checkout PASSED `python3 tools/ci/check_repository.py --require-materialized` and `git lfs fsck`; all 18 required runtime files materialized, zero identity errors |

| Published artifact | Size | SHA-256 |
|---|---|---|
| Linux `libcybersand_native.linux.x86_64.so` | 2,480,992 bytes | `7e8d32f39a478323dfc2fd757c54f8dc834d1ebed2873222677da48e67a13bae` |
| Windows `cybersand_native.windows.x86_64.dll` | 2,974,208 bytes | `50fb6f2b29a5207ad3d87804fdb1cf5231ee0669106b4fcb189bdde633754305` |

The runtime/validation artifacts are `player-runtime-linux-39556052782` (artifact
ID `12325912627`) and `player-runtime-windows-39556052782` (artifact ID
`12326255871`). Their `validation.json` SHA-256 hashes are respectively
`bf63df3bfacca0b8f664d38a265608cad34a421b0b85e8f62b317d8fdabbee5a` and
`a296089a12db06fb66acd9e2e58a4ce308a48b1284e7667f97409c04a37bef39`.
The [publication job](https://github.com/techrote/cybersand/actions/runs/39556052782/job/119078920153)
verified both complete receipts, staged LFS identities and the unchanged source
head before uploading the two LFS objects and fast-forwarding the feature branch.
Both platforms emitted the integrated runtime's
`scope=all-seven-native-and-Rapier` marker with 1,329 assertions. Course assertion
totals differ by platform because that fixture counts checks during actual
physics traversal: Linux reported 1,446 and Windows 1,475, both with zero failures.

The final acceptance record is the [PR #189 description](https://github.com/techrote/cybersand/pull/189)
and [Checks tab](https://github.com/techrote/cybersand/pull/189/checks). They must
identify the full final head SHA and link its required job outcomes after the
runtime publication and this documentation checkpoint. This avoids changing
the tested head merely to insert that same head's completed CI results into a
new documentation commit. The required final dispositions are:

| Final gate | Evidence required in PR #189 |
|---|---|
| Documentation/provenance | Successful current-source and materialized-runtime checks at the final head |
| Native validation | Successful ordinary, applicable sanitizer and retained apparatus execution at the final head |
| Linux/Godot | Successful build, all four regression shards and aggregate gate at the final head |
| Windows | Successful extension build and actual headless execution at the final head |
| Water apparatus v2 | Successful applicable apparatus run at the final head |
| Merge and landed main | Merge commit identity and confirmation that main contains the final tested tree; post-merge workflow status is recorded separately |

The current [release policy](../operations/github-development-and-release.md)
requires the applicable exact-head gates before merging an implementation PR.
Source-sensitive provenance is required even when prior behavior tests passed.

## Qualification boundaries

The original-head hosted results improve the platform evidence beyond the
initial local cross-build checkpoint. Combined-source local and hosted results
retain their distinct identities; final acceptance follows the PR record above.
Human feel on the target PC, complete timed-course routes,
physical gamepad/window interaction, target-GPU performance and new browser or
WebAssembly execution remain separate qualifications. Conservative rectangular
native wheel masks, bounded local material selection and the existing generic
granular/Water/soliding programme boundaries are unchanged.
