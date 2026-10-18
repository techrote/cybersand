---
title: GEN-001 procedural generation candidates and workbench evidence
status: Current
document-kind: evidence
scope: Three native chunk-generation candidates, theme and spatial authoring, trusted feature modules, fresh-chunk admission and bounded local validation for issue 163
canonical-for: [gen-001-procedural-generation-evidence]
last-reviewed: 2026-10-18
related-documents: [../systems/procedural-world-generation.md, ../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/interfaces-and-message-contracts.md, ../operations/local-build-and-validation.md, ../reference/status-and-roadmap.md]
---

# GEN-001 procedural generation — 2026-10-18

## Authority and source checkpoint

The owner requested procedural chunk-generation frameworks/engine candidates,
dynamic interconnected generation, theme subsets/supersets and blends, broad
brushstroke guidance, fine controls, hard overrides and an extensible module
system for structured computational/architectural features.
[Issue #163](https://github.com/techrote/cybersand/issues/163) owns this work on
`codex/worldgen-candidates`, starting from main
`ec05d7227885bda59bf72a5889b004296b9a07e5`.

The implementation uses a separate checkout. Concurrent actor and demo-scene
workspaces were inspected for ownership and left untouched. This checkpoint
changes native generation and additive chunk admission, a separate Godot preview
scene, build registration, focused tests and canonical documentation. It does
not change the ordinary main scene or select a Water/actor/physics successor.

The [generation contract](../systems/procedural-world-generation.md) owns Current
behavior and exact limits. This evidence establishes executable candidates and
an opt-in authoring preview. Production simulation residency, eviction,
persistence and recipe reconciliation remain separate Planned/Deferred work.

## What was built and why

All candidates share one immutable compiled recipe and bounded incremental job
interface. `strata` supplies warped organic terrain/caves; `flow_network` adds
canonical macrocell hubs and edge ports; `district_grammar` adds structured
rooms/floors and the same connective network. Global coordinates and canonical
edge ownership remove a dependency on neighbor-generation order. The shared
network is carved after modules so an ordinary structural instance cannot seal
it; final material overrides can deliberately do so.

Theme selections expand a validated DAG of groups and concrete palettes. Group
weights divide among eligible descendants, overlapping subsets add and normalize,
and exclusions remain effective under later brushes. World-coordinate polyline
strokes blend theme and typed parameter controls. Explicit routes and hard
rectangles provide stronger local constraints. Stable priority/ID ordering makes
array order irrelevant.

Prepared, versioned native module factories support dependency-ordered feature
instances. Built-ins provide an arcology, a precomputed spanning-tree vault and
an aqueduct. The runnable `service_ribs` example demonstrates a host-registered
factory. The module API is cooperative trusted C++, with owned immutable prepared
state; it is not an arbitrary-code sandbox or an OS dynamic-library loader.

The workbench owns one private generator job, advances at most 2,048 cells per
service/frame, queues at most 24 requests and retains at most 32 copied chunks.
Panning requests new chunks; accepted recipe edits replace the preview revision.
Controls include seed/candidate, theme weights/exclusions, all twelve parameters,
strokes, routes, exact material rectangles, module placement/parameters and full
JSON import/export. The new scene is explicitly launched and does not tick a World.

`World::install_generated_chunk` is the separate native integration primitive.
It admits only an absent storage chunk, validates the whole payload before writes
and preserves existing material initialization and wake/discovery semantics.
Any resident chunk, including empty/pre-reserved/excavated storage, is protected.
Callers must validate generator receipts and own World/reset lifetime; the raw
span installer itself is not a session-admission protocol.

## Independent review findings and repairs

The focused tests and review exposed issues during implementation. Their final
repairs are included in the source identities below:

| Finding | Repair and retained regression |
|---|---|
| Interpolated value noise biased weighted palette selection toward middle entries | Uniform hash over warped global patches; fallback selects only a positive eligible weight |
| Summing seven identical theme minima rounded a one-cell wall below one before rasterization | Blend from an eligible reference plus weighted differences, bounded by active endpoint extrema; identical minima remain exact |
| `a+(b-a)*1` lost an exact small hard target after a large starting value | Explicit interpolation endpoints; hard/full-strength `0.1` from `1,000,000` remains exact |
| A content-only hash did not bind a completed payload to its requested coordinate | Separate receipt binds coordinate, size, revision, fingerprint, content and logical charge; wrong-coordinate packets reject |
| A fallible error assignment could occur before discarding partial output | Clear cells/hashes first; use a pre-reserved, bounded diagnostic copy |
| The first diagnostic copy imported `std::string::_M_replace_cold`, requiring GLIBCXX 3.4.31 | Bounded `push_back` into reserved storage removes the import; final Linux floor is GLIBCXX 3.4.30 |
| Existing transient-mask subtraction could overflow for distant opposing signed coordinates | Compare lower bounds first, then use unsigned differences; installer endpoint/mask regressions run under UBSan |
| Existing Native/GDExtension ready-scope writers emitted literal `\\n`, preventing the output from equaling `true` | Emit a real LF; verify both true/false records. Required jobs can now run on `ready_for_review`; skipped runs do not establish acceptance |
| Source-freeze review found the tracked portable Godot class cache lacked the two new `class_name` records | Copy the two exact entries from the tested clean import; preserve the strict source-diff guard |
| UI completion admission initially omitted an explicit match to its in-flight coordinate | Reject missing/nonintegral/out-of-range coordinates and wrong completion slots before cache mutation |
| Repeated failed requests while panning could retain old refusal entries | Prune refusals to the bounded visible request set; exhausted-budget panning regression |

Two early test failures were fixture errors rather than engine defects: a vault
extent did not divide its room pitch, and an initial UI assertion expected a
recipe fingerprint to ignore revision. The corrected tests retain valid geometry
and the documented identity semantics. JSON integer/float normalization is also
tested explicitly.

## Exact local native and binding inputs

The initial source base plus these LF-normalized SHA-256 file identities defines
the changed native code tested locally. Final published runtime manifests retain
the complete source/build-input maps rather than treating this focused list as a
substitute for provenance.

| Input | SHA-256 |
|---|---|
| `native/include/cybersand/world_generation.hpp` | `363019e142620a4a7265e758bfb7c244bae71cfd27a12711ccef8523b07b59f4` |
| `native/src/world_generation.cpp` | `7053c12dffc6f102996aaf6e75bd5046b93fcaf8c17d45dfe76cd5663bc9d0f5` |
| `native/tests/test_world_generation.cpp` | `90ef4f4a61f4c1b2be7da5ebe8bcdd6b1befa7aca6fce8a8133d61a0e108d6a2` |
| `native/tests/test_world_generation_install.cpp` | `2467db8cd9edf42e19380198d8f516fe10b6d64d8cc495ab5b6469f93efda118` |
| `native/include/cybersand/world.hpp` | `6e0fbbae13ce016ea6e3bbafed5d2e8bc2819a6663295ab0ef0c3baf0f3851b5` |
| `native/src/world.cpp` | `bc36cdad3d55ddf29fd14db776e1536a4dafd673d3c142c7701b1de06112b499` |
| `godot/native_extension/cyber_world_generator.hpp` | `cd1afdf9692a33946a358665a534846eae526a0fa325f206b709e029c886385c` |
| `godot/native_extension/cyber_world_generator.cpp` | `b08094995efb23408e44958cb1abd1ae24cdf65204e76a8e812639205ed59ea8` |

## Executed local validation

Linux host: Ubuntu 24.04 x86-64, GCC/G++ 13.3.0, binutils 2.42. Generator tests
compile C++20 with `-Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror`.
The installer and pre-existing World sources retain their existing unrelated
conversion warnings; no new warning is suppressed.

| Command/check | Result and scope |
|---|---|
| `make build/test_world_generation`; `timeout 180 ./build/test_world_generation` | Pass: all three candidates, seed/order/partition determinism, signed seams, hierarchical weights/exclusions, broad/fine/hard controls, module DAG/clipping/failures, identity and bounds |
| `make build/test_world_generation_install`; focused executable with a 5m limit | Pass: eight installation groups; full prevalidation, residence protection, capacity/mask/endpoints, metadata/Water initialization, failed/in-tick refusal and twenty ticks equal a manually initialized reference |
| `timeout 300 make build/test_world_generation_sanitized`; `timeout 180 env ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1 UBSAN_OPTIONS=halt_on_error=1 ./build/test_world_generation_sanitized` | Pass on final ABI-corrected source; ASan and UBSan, leak detection explicitly disabled |
| Sanitized fresh-chunk installation executable | Pass: ASan/UBSan including the signed-mask arithmetic repair |
| `make build/tests`; `timeout 900 ./build/tests` | Pass: all 70 existing native World tests |
| `g++ -std=c++20 -O2 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Werror -Inative/include native/src/world_generation.cpp examples/worldgen/custom_module.cpp -o build/worldgen_custom_module`; `timeout 30 ./build/worldgen_custom_module` | Pass: separately registered `service_ribs` prepares and generates 16,384 accepted cells |
| `make build/worldgen_demo`; `timeout 90 ./build/worldgen_demo --output build/worldgen-preview.ppm` | Pass: native material-pixel comparison of three candidates; 36 chunks at seed 314159 |
| Three `examples/worldgen/*.json` profiles through the final native Godot adapter and workbench | Pass: 85 assertions, 16 specifically targeted incremental chunks, exact seam/gate/support witnesses and bounded visible-region completion; about 1.19s |
| Exact pinned Linux GDExtension build and `tools/check_linux_runtime_floor.sh` | Pass after the retained initial floor failure; no drift override |
| Exact pinned Windows GDExtension cross-build and PE inspection | Pass: PE32+ x86-64 DLL; Windows execution unavailable |
| Godot `--headless --script res://tests/test_worldgen_workbench.gd` | Pass on final Linux artifact: 138 assertions, zero failures, about 0.48s |
| Godot `--headless res://worldgen_workbench.tscn --quit-after 180` | Pass on same artifact: 180 frames, exit zero, no `ERROR`/`SCRIPT ERROR`, about 1.46s |
| `python3 tools/ci/check_ci_provider_policy.py`; `git diff --check` | Pass; active CI remains GitHub-hosted |

The connectivity oracle independently flood-fills generated material cells,
including a four-macrocell signed-coordinate fixture covered by a solid-metal
module. Restored Empty routes connect and reach all four fixture sides for Flow
and District. Chunk-size 32/64/128 partitions compare the same global region,
including authored brushes, routes, vault and final material override. These
checks establish the claimed generation contract, not player traversal.

The first LeakSanitizer attempt failed on the hosted `/proc`/ptrace environment.
ASan/UBSan were rerun with leak detection disabled and passed. Leak detection is
unverified. An initial sandboxed Godot editor import reported local TCP-listener
permission errors after asset/class import; final focused runtime executions
were clean. Missing-extension startup also parses and presents an explicit
unavailable status rather than synthesizing fake generation.

The native comparison's observed 553.035ms for 36 chunks is illustrative local
wall time only. It is not a frame budget, target-PC benchmark or algorithm
selection result. Module logical charges are conservative accounting units,
not measured instructions or a preemptive wall-time limit.

## Local rebuilt runtime identity

Both local artifacts were built from the same stable map of 35 native/binding
inputs and eight build inputs. Tool pins were unchanged: godot-cpp
`101ae38034304346a46ea9ea84ae156d3e860496`, SCons 4.10.1, and Windows
LLVM-MinGW 20260826 / Clang 23.1.0 with archive SHA-256
`cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65`.
Godot execution used `4.7.stable.official.5b4e0cb0f` and the pinned Rapier Linux
payload `147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.

| Local artifact | Bytes | SHA-256 | Qualification |
|---|---:|---|---|
| Linux x86-64 `.so` | 1,936,544 | `ebdf89429f31cf77e6e41818f643876d92f1b10d61e72ed826a5a3d704a48614` | Build, ABI floor, 138 Godot assertions and 180 headless scene frames |
| Windows x86-64 `.dll` | 2,412,032 | `75d75cc6c98169e598955045cc23f6714939be5b4c580abb5a1cd39a966fdb80` | Pinned cross-build and PE inspection only |

Final Linux bundle floor: GLIBC 2.34 (CyberSand extension 2.32), GLIBCXX 3.4.30,
CXXABI 1.3.9. Initial build/floor failure and final build ledgers were retained
during the task. Runtime publication must use actual rebuilt payloads and their
own hashes; it must not replace provenance with unbuilt source hashes.

The three recipe fixtures are in `examples/worldgen/`; the full contract explains
launch, JSON shape, ranges and extension hooks. The API is provisional schema/
algorithm version 1. Hard controls intentionally may sever connectivity. Custom
native factories must preserve thread safety, bound preparation and bump their
version when output changes.

## Repository gates and remaining qualification

The first source-only documentation check found five missing pinned companion
files (six references), matching the repository's two-checkout CI layout. The
authoritative companion revision is
`6a58311982941b75f46e22109a0829e5acb83c7e`; materialization and final documentation,
M11, retrieval and provenance results are recorded at the publication checkpoint.
Frozen retrieval questions and historical M11 hashes were not rewritten.

After exact companion materialization, local documentation validation passed with
79 canonical documents, eight navigation documents, 136 claims and zero errors or
warnings. Frozen retrieval retained 32/32 top-five hits, 23/32 top-one and MRR
0.849. The 40 supplementary questions retained 40/40 top-five, 27/40 top-one and
MRR 0.8113; new GEN01 ranks its canonical owner third and GEN02–GEN04 first.
Historical M11 validation passed all 18 records and 28 audited source hashes.
The pre-publication repository check correctly refused the old retained runtimes
for the changed native inputs; it was not bypassed.

At this initial evidence commit, GitHub-hosted runtime publication and exact-head
ready-for-review CI are still pending. The local build evidence above is not a
substitute for those gates. Windows runtime execution, Web/WASM execution,
interactive target-GPU/owner visual acceptance, production streaming/persistence,
full replay and comparative performance acceptance are not claimed.

The local build guide's obsolete active external-runner prose was reconciled to
the existing GitHub-hosted workflow and repository policy while adding GEN-001
commands. No provider policy or execution threshold was relaxed.


## Rendered workbench layout follow-up

An isolated Xvfb/software OpenGL render completed after the normal execution
review permitted the local display sockets unavailable in the first sandboxed
attempt. This used the same final local Linux extension
`ebdf89429f31cf77e6e41818f643876d92f1b10d61e72ed826a5a3d704a48614` and
hash-matched copies of all four workbench sources. The renderer was Godot 4.7
Compatibility, OpenGL 4.5, Mesa 25.2.8 / llvmpipe LLVM 20.1.2.

Seven actual captures were inspected: the three example worlds, Brushes, Modules,
scrolled fine controls and the Profile JSON dialog. The 1800 by 1012 main views
and 900 by 694 JSON view contain no observed clipping or overlapping controls.
Scrolling reaches all twelve fine parameters and both lower Apply/Regenerate
buttons; all five JSON actions fit. The graphical example run passed 88 assertions
and the panel run completed four captures, both with zero failures and no runtime
or script errors. The software driver's unsupported V-Sync-change warning remains
qualified. This establishes the inspected software-rendered layout, with no
Windows/browser or target-GPU performance claim.

The representative [Flow workbench image](../figures/worldgen-workbench.png) is
165,789 bytes, SHA-256
`5ba29a36df0bbf74f3c81d90e1abec4520dafd8a88613bdf24d2d3bfb80421d6`.
Temporary display processes were cleaned up; no generator/UI source changed.

## Guarded runtime publication

The frozen implementation source is
`b8a4fae53ee20d9e6d5cfec5f4e972df038491c1`, tree
`822976524584522441a1b5003b1ed408e5915f8c`. The temporary publisher is its
workflow-only immediate child
`6f8c8a38088bf829c236a0831cf9e5089b283fca`; its reviewed branch/parent/write-set
controls and explicit fail-on-UBSan behavior preserve the native runtime gates.
[Publication run 39107152476](https://github.com/techrote/cybersand/actions/runs/39107152476)
builds both platforms on GitHub-hosted Ubuntu 24.04 from 35 native/adapter inputs
and 27 build/validation inputs. Source, artifact and log hashes are verified before
publication. The allowed publication write set contains only the two LFS runtimes,
their two manifests and deletion of the temporary workflow.

Attempt 1 passed every Linux build/execution check: 70 core tests at 07:28:19 UTC,
optimized generation/installation at 07:28:46, ASan/UBSan at 07:30:06, the 138
workbench assertions at 07:30:18 and the 180-frame scene by 07:30:19. It also passed
the runtime floor, source-diff guard and the three existing native Godot smoke
cases. GitHub ArtifactService then repeatedly timed out on ListArtifacts /
CreateArtifact and the upload failed at 07:32:13. The guarded publication job
correctly remained skipped; no unverified runtime was pushed.

That unuploaded Linux candidate was 1,936,552 bytes with SHA-256
`cb74e86e4ca0131e0768d19de40b6f2071b7f8e8f3327a0268941905afbcdd1a`.
The successful Windows job uploaded its 2,412,032-byte cross-build candidate,
SHA-256 `3221acb9a91913675fcc466c82e18def19ee96c389a723925ca7bb48beec94d1`.
Those hosted identities are distinct from the earlier local artifacts and are
recorded separately. Failed jobs were retried on the unchanged trigger/source;
the successful Windows result was reused. The upload failure did not justify
source changes or relaxation of a validation gate.


### Successful publication checkpoint

Attempt 2 completed successfully at 07:45:42 UTC and published
`6d2597cf78f026fa291ce8fa0fef1452504b4a43`. The new runtime manifests bind the
frozen source/tree above and identical 35-file native plus 27-file build/validation
maps. Linux records its successful attempt 2; Windows retains its successful
attempt 1. The Linux binary was byte-identical across the two hosted attempts.

| Published runtime | Bytes | SHA-256 | Executed qualification |
|---|---:|---|---|
| Linux x86-64 | 1,936,552 | `cb74e86e4ca0131e0768d19de40b6f2071b7f8e8f3327a0268941905afbcdd1a` | Pinned build/floor, 70 core tests, focused native and hosted ASan/UBSan generation/install checks, import, three existing native Godot regressions, 138 workbench assertions and 180 headless scene frames |
| Windows x86-64 | 2,412,032 | `3221acb9a91913675fcc466c82e18def19ee96c389a723925ca7bb48beec94d1` | Pinned cross-build and PE inspection; execution not performed |

The publisher passed `check_repository.py --require-materialized`, `git lfs fsck`
and whitespace/source-diff guards before uploading both LFS objects and pushing
the verified descendant. Both published artifacts are actual rebuilt bytes.
The temporary workflow removed itself in the same narrow publication commit.
The prior stale-provenance refusal is resolved by those artifacts and manifests,
not by changing unbuilt hashes.

Build reports and gate logs are retained in run artifacts
`gen001-runtime-linux-39107152476`, `gen001-runtime-windows-39107152476` and
`gen001-publication-39107152476`. The normal merge gates remain separate from
this publisher. [PR #166](https://github.com/techrote/cybersand/pull/166) records the
final exact-head Documentation/provenance, Native, Linux/Windows GDExtension and
scoped Water-apparatus results; a skipped draft job does not count as a pass.


After materializing those published objects locally, the final repository gate
also passed with all 18 required runtime objects present; `git lfs fsck` and
whitespace checks passed. Final frozen retrieval remains 32/32 top-five and is
24/32 top-one, MRR 0.8646. Supplementary retrieval remains 40/40 top-five,
27/40 top-one, MRR 0.8113. Both question fixtures preserve all earlier questions.
The final evidence/screenshot changes contain no native, binding, script or
runtime-source-input mutation.

## Integration with the actor prototype checkpoint

Main advanced to ACT-001 checkpoint
`a532daa70140aac163e5501051fe5afa1bcf377f` during runtime publication. The ready
PR at `dc63cd2c1a33a341d493a357c08b7d3ac23dc9ce` was therefore merge-conflicted;
the absence of ready-event workflow runs was not passing or skipped validation.
The integration preserves both canonical subsystem sections, both sets of
supplementary retrieval questions and all actor scripts. The portable Godot class
cache retains the four actor types and both generation workbench types.

The incoming actor checkpoint changes none of the 35 native/adapter source-input
hashes and no native compilation script or dependency pin. The published runtime
bytes and source provenance remain current for compiled native code. Of the 27
recorded build/validation inputs, only the portable Godot class cache changes.
The publisher's actual source/tree and validation-input snapshots remain intact:
that earlier run did not execute the merged actor scripts. Combined Godot import
and regression evidence is recorded separately below and in the final PR gates.

The merged working tree passed the documentation gate (80 canonical documents,
138 claims, 1,368 links, 69 anchors; no errors/warnings), the repository gate with
all 18 runtimes materialized and the historical M11 gate (18 records, 28 hashes).
Frozen retrieval remains 32/32 top-five, 24/32 top-one, MRR 0.8646. The union of
43 supplementary questions achieves 43/43 top-five, 28/43 top-one, MRR 0.8012.
All prior question objects and the frozen question file remain unchanged.

A separate isolated Godot 4.7 copy of the combined scripts used the actual
published Linux runtime `cb74e86e4ca0131e0768d19de40b6f2071b7f8e8f3327a0268941905afbcdd1a`.
Its clean headless import passed. Actor prototypes passed 12,293 assertions,
actor sessions 626, actor integration 157 and the generation workbench 138,
each with zero failures. The workbench also completed 180 headless frames with
no script/runtime errors. The merged portable bootstrap cache contains 60 unique
class records; its input SHA-256 is
`f0449c5763e8496a26bc10fbd7f3ce79e8dd24454207940cb20414b62a0e9b4e`.
These checks qualify the combined script/bootstrap context on Linux, with no
additional Windows/Web, graphical layout or target-PC performance claim.
