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
