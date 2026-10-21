---
title: Player playground PR 189 integration and completion checkpoint
status: Current
document-kind: evidence
scope: Original-head hosted results, integration with GEN-003 main, fast-tap course timing correction and pending combined-source runtime and final acceptance gates
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

**Checkpoint disposition: PENDING.** Local combined-source native tests and
desktop builds have passed. Source-matched hosted runtime publication, focused
correction validation and final exact-head hosted gates must be recorded below
before this record can establish merge acceptance.

## Source identities

| Identity | Value |
|---|---|
| Repository and PR | `techrote/cybersand`, PR #189 |
| Feature branch | `feat/player-control-playground` |
| Original implementation base | `4f3685b71366218e82e7c2188e4ecdf27553f4cf` |
| Original PR head with completed hosted checks | `6663d8e25f4743d58863bf0538232e7c77c08f77` |
| Current main integrated for completion | `ba19d3a2b2608ef0ffbe252b684561e45aeaa457`, including GEN-003 / PR #195 |
| Recoverable integration checkpoint | `e7deae705af513bfb2793182f16f482b3430584f`, tree `b0758376e74ef8030277ad66337f01fd6d0f6cc2`; identical integration tree to local checkpoint `1caccf09d09148d97f16ec4a2bdd13a8a756477b` |
| Final reviewed and tested PR head | PENDING |
| Final merge and landed-main verification | PENDING |

The integration preserves both the player material-field API and GEN-003 typed
spatial generation, including their native sources, bindings, tests and canonical
documentation routes. The two original branches had different native inputs.
Neither branch's retained runtime alone represents the combined tree; both
desktop binaries required a combined-source rebuild. Local build results are
recorded below; hosted publication and current manifests remain pending.
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
results are separate from the pending source-matched hosted publication. All
**42 native input SHA-256 hashes** were rechecked against the local prebuild
snapshot and remain unchanged.

| Local check | Completed result |
|---|---|
| Full native World behavioral suite | **84/84 tests passed**, including the six player material-field groups |
| Native generation suite | All **seven executables passed**: world generation, fresh-chunk installation, scalar fields, modifiers, typed fields, typed integration and spatial operators; typed-field execution reported **14,162 assertions** |
| Linux combined-source extension build | Passed with pinned GCC 13.3.0, GNU binutils 2.42, godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` and SCons 4.10.1 |
| Linux ABI floor | Passed: bundle GLIBC 2.34; CyberSand GLIBC 2.32 / GLIBCXX 3.4.30 / CXXABI 1.3.9; Rapier GLIBC 2.34 |
| Windows combined-source extension cross-build | Passed with pinned LLVM-MinGW 20260826 UCRT; actual execution of this combined Windows binary remains pending |
| Publisher guard regression | `python3 tools/ci/test_player_runtime_publication.py`: **15 tests passed** |
| Independent publisher portability review | The same 15 tests passed under emulated Windows default CRLF and Git `core.autocrlf=true`; target-OS refusal and all ten required headless cases were independently checked |
| Current documentation and CI-provider policy | Passed on the current checkout; documentation lint covers 96 documents |
| Historical M11 integrity | Passed for all 18 retained records; historical identities were not rewritten |

| Local artifact | SHA-256 |
|---|---|
| Linux `libcybersand_native.linux.x86_64.so` | `47ee8025ad74d4ad16d9e87419b84abd3159f4023842a9947b788e3c54eb5f35` |
| Windows `cybersand_native.windows.x86_64.dll` | `aa2d4a7a90e06b740d576e3b7f035bcbb5ed23dc5b1d550eb8a55612050b867e` |

Both local build outputs were retained separately under
`validation/local-runtimes`. These hashes identify the local builds and do not
pre-claim the bytes or execution results of a later hosted rebuild. Neither a
successful cross-build nor publisher guard tests constitute actual Windows
gameplay execution. Hosted LFS/runtime-manifest publication remains pending.

## Combined runtime and final validation

The local preflight results above do not substitute for final source/artifact
and hosted execution evidence. Entries remain pending where that evidence is
not yet available; record full commit IDs, artifact hashes, commands, timeouts
and hosted run/job URLs with the completed results.

| Required completion evidence | Result |
|---|---|
| Combined-source Linux runtime build, native-input manifest and ABI floor | Local build and ABI floor PASSED; hosted runtime/manifests PENDING |
| Combined-source Windows runtime build and native-input manifest | Local cross-build PASSED; hosted runtime/manifests and actual combined-runtime Windows execution PENDING |
| Native player-field regression and applicable integration checks | Local 84/84 World tests and all seven generation executables PASSED; final hosted ordinary/sanitized gates remain separate |
| Scoped publisher guard and portability regressions | 15 tests PASSED normally and under independent Windows CRLF / `core.autocrlf=true` emulation |
| Fast-tap timer and player runtime/course regressions | PENDING |
| Documentation, retrieval, current provenance and historical M11 checks | PENDING |
| Final-head Documentation/provenance | PENDING |
| Final-head Native ordinary/sanitized execution | PENDING |
| Final-head Linux build, four Godot shards and aggregate gate | PENDING |
| Final-head Windows build and actual Windows headless execution | PENDING |
| Final-head Water apparatus v2 | PENDING |
| Merge and landed-main verification | PENDING |

The current [release policy](../operations/github-development-and-release.md)
requires the applicable exact-head gates before merging an implementation PR.
Source-sensitive provenance is required even when prior behavior tests passed.

## Qualification boundaries

The original-head hosted results improve the platform evidence beyond the
initial local cross-build checkpoint. Final combined-source acceptance remains
pending above. Human feel on the target PC, complete timed-course routes,
physical gamepad/window interaction, target-GPU performance and new browser or
WebAssembly execution remain separate qualifications. Conservative rectangular
native wheel masks, bounded local material selection and the existing generic
granular/Water/soliding programme boundaries are unchanged.
