---
title: Per-run full-frame render copy identity and timing
status: Current
document-kind: evidence
scope: Stateless native refactor of World::copy_render_cells to one chunk lookup per row run, with byte-identity proof against the replaced per-cell loop and reported (not asserted) local Windows timings; hosted Linux/sanitizer gates and end-to-end exchange latency remain separate
canonical-for: []
last-reviewed: 2026-10-29
related-documents: [../architecture/rendering-and-gameplay-bridges.md, ../operations/profiling-observability-and-performance.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# Per-run full-frame render copy — 2026-10-28

## What changed and what did not

**Current source:** [World::copy_render_cells](../../native/src/world.cpp)
walks each destination row in chunk-aligned runs. It resolves the run's chunk
with one `address` plus one hashed `find_chunk`, then reads material and
compact state directly from that chunk's cells. Before this change it called
`stored_material`, `stored_state_a` and `stored_state_b` for every cell: three
hashed chunk lookups per cell. The run pattern is the one
[World::copy_material_cells](../../native/src/world.cpp) already used.

Output bytes are unchanged. A non-resident chunk still emits `Material::Empty`
and `project_visual_state(Empty, 0, 0, policy)`; resident cells still emit the
material byte and `project_visual_state(material, state_a, state_b, policy)`
with the World's Water experiment policy. Validation, stride handling, padding
bytes and the RG8 wire layout are unchanged. No World state, dirty metadata,
snapshot exchange, worker mode, default, C ABI or GDScript consumer changed.

The body is a port of candidate R (`World::copy_render_cells_by_run`) from
SOL281 [PR #283](https://github.com/techrote/cybersand/pull/283) at commit
`85c45720`. That PR's preregistered A/B (comment 6482124010, result comment
6482758201, scoped run 40780899379) identified the per-cell copy as the cost
behind the forced-full refresh lock-in and selected a stateful partial-ACK
candidate under its registered rule; R was carried forward as the strongest
stateless default-on candidate. This change ports only that function body to
`main`. It does not merge PR #283 or touch its experimental worker modes.

## Identity proof

`test_render_copy_per_run_identity` in
[native/tests/test_world.cpp](../../native/tests/test_world.cpp) keeps the
replaced per-cell loop as a test-only oracle
(`copy_render_cells_per_cell_oracle`, using the public `stored_*` accessors)
and requires byte equality of the whole destination buffer, padding included:

- two Worlds: chunk 128 with the default Water policy, and chunk 32 with a
  5-bit Water policy so `normalized_mass` is non-trivial;
- a deterministic mixed fixture over `{-200, -64, 400, 300}` (signed chunk
  seams) using Empty, Water, Smoke, Fire, Lava, Steam, Sand, Oil, OakTimber,
  Thatch, NeonCyan and Wall with explicit `set_cell_state` values; states that
  throw as out-of-domain fall back to `set`. The fixture must contain
  fractional Water condition bytes and more than 32 distinct material/state pairs;
- nine regions: the filled area, a surrounding area with non-resident chunks,
  tiny seam regions (3×2, 2×2 positive and origin corners, 1×1), a single
  non-resident column, a mid-chunk start/end span and a zero-width region;
- each region at a tight stride and a padded stride (+6 bytes), with every
  padding byte asserted untouched (sentinel `0xAB`);
- a full 1024×1024 frame at `{-512, -512}` whose bottom quarter is non-resident.

The same test, compiled against `main`'s unmodified `world.cpp`, also passes:
the oracle matches the previous production function byte for byte.

## Local evidence

| Item | Identity |
|---|---|
| Base | `main` `91778603db950a817b82fc6a4f75efee201f5044` (tree `3e513ab8`) |
| Changed sources at test time | `native/src/world.cpp` sha256 `122c5e43…6177`, `native/tests/test_world.cpp` sha256 `f7327425…a959` |
| Host | Windows 11 Pro 10.0.26300, x86_64, AMD Ryzen 5 5600X |
| MSVC | VS 2022 Build Tools 14.38.33130 |
| LLVM-MinGW | 20260826, clang 23.1.0 |
| GDExtension inputs | godot-cpp `101ae380`, Godot 4.7.stable.official.5b4e0cb0f |

Results (each command run locally, outputs outside the worktree):

1. `build_windows_msvc.bat` from a VS x64 developer environment (`/Od /Zi`
   tests, `/O2 /GL` benchmark and `cybersand.dll`): 165 tests passed, including
   `render copy per-run identity`; benchmark and shared library built.
2. Clang `-Wall -Wextra -Wpedantic -Wconversion -Wshadow -fsyntax-only` on both
   changed files: no warning in the changed ranges. The same twelve test sources
   built with LLVM-MinGW clang `-O3 -DNDEBUG -static`: 165 tests passed (49 s).
3. Windows GDExtension via `tools/build_native_extension_windows.sh` with the
   pinned LLVM-MinGW and godot-cpp, written to a scratch output (not the LFS
   runtime path): DLL sha256 `26b9541b45f788304fed3554d2d112e89d2b41637cb9ab6d3e9d051685eaeac1`.
   Against a scratch copy of `godot/` with that DLL, after a 12 s import
   (rc 0), [test_render_world_generation](../../godot/tests/test_render_world_generation.gd)
   passed 23 assertions with 0 failures (4 s, includes a native
   `request_render_full_refresh` publication) and
   [test_render_patch_handoff_regression](../../godot/tests/test_render_patch_handoff_regression.gd)
   passed (2 s). Rapier LFS payloads were not materialized in this worktree,
   so the Rapier extension failed to load; neither test depends on it.

### Reported timings (not asserted)

Median of five 1024×1024 copies inside the identity test, three process runs
each; same fixture, same host, single thread. "Before" compiles the identical
test against `main`'s `world.cpp`, so it times the replaced production function.

| Compiler | Before: per-cell `copy_render_cells` | After: per-run `copy_render_cells` | Test oracle (cross-TU per-cell) |
|---|---|---|---|
| MSVC `/O2` | 46.6 / 45.9 / 45.6 ms | 5.15 / 6.28 / 5.10 ms | 47.5–48.8 ms |
| LLVM-MinGW clang `-O3` | 23.6 / 23.6 / 23.6 ms | 4.77 / 4.64 / 4.67 ms | 30.5–32.2 ms |

On this host the per-run copy is about 9× faster under MSVC and 5× faster under
the clang that builds the Windows GDExtension.

These are isolated copy timings on one local machine. They do not re-measure
the desktop worker's forced-full exchange p95; PR #283's registered A/B owns the
end-to-end Linux (30.2 → 1.5 ms) and Windows (22.0 → 1.9 ms) candidate R result
in its own measurement window.

## Documentation checks

`check_m11_consistency.py` passes (18 records, 28 source hashes). The retrieval
evaluation runs to completion. `check_docs.py` reports six Q01/Q04/Q28/Q29/Q30
missing expected-fact sources outside the repository root; an unmodified `main`
`91778603` checkout reports the same six locally. `check_repository.py` reports
those six plus Windows and Linux Godot runtime manifests that require a rebuild
for `native/src/world.cpp`, the expected result of a native source change
without runtime publication.

## Gaps

- Linux GCC `make test`, ASan/UBSan and hosted GDExtension/Godot gates did not
  run locally; draft-PR CI suppresses Native/GDExtension execution. They are
  required exact-head gates before this leaves draft.
- Runtime binaries were not republished; the LFS GDExtension payloads are
  unchanged, so shipped runtimes keep the per-cell copy until a separate
  publication. Until then the runtime source-input check stays stale for
  `native/src/world.cpp`, which blocks merge.
- Web was not built or run.

## Hosted source-matched qualification — 2026-10-29

**Execution identity and scope.** The review candidate [PR #290](https://github.com/techrote/cybersand/pull/290)
has executable head `f041aac3f2574e5524b807f8c2efdc27bee241e0`
on base `main` `91778603db950a817b82fc6a4f75efee201f5044`.
The two independent scoped CI lanes forked that head without changing
**any** executable file, test, or existing build configuration:

- `verify/render-copy-per-run-20261029`, commit
  `e743aa664cdf91eabcc19bd394454ccd263ccc67`,
  adds only `.github/workflows/render-copy-290-targeted.yml`.
  [Run 40792599185](https://github.com/techrote/cybersand/actions/runs/40792599185)
  preserves the exact Git archive, executes Linux GCC13 native and
  ASan/UBSan suites, and Windows Server 2022 MSVC native test/build.
- `verify/render-copy-per-run-godot-20261029`, commit
  `e64f20a8cfce415edf10b9b258940d5f07640f03`,
  differs from the PR head only in
  `.github/workflows/render-copy-290-godot.yml`.
  [Run 40793815067](https://github.com/techrote/cybersand/actions/runs/40793815067)
  **passed its three jobs**: Linux source-matched GDExtension
  build and actual Godot 4.7/Rapier 0.35.2 execution; pinned
  LLVM-MinGW Windows GDExtension build; actual Windows Server 2022
  Godot 4.7/Rapier execution with the newly built Windows DLL.

The Linux and Windows actual-host cases each pass
`test_render_world_generation.gd` (**23 assertions, zero failures**) and
`test_render_patch_handoff_regression.gd` (pass).
Both Linux and Windows import logs were inspected, with no
`SCRIPT ERROR` or failed extension-load diagnostics.
The tests exercise render publication and reset/ACK handoff under the
existing native-owner architecture, not interactive GPU pacing or
physics motion for the structural-detachment experiment.

The separate Windows MSVC hosted native build/test job in run 40792599185
also **passed 165 tests**, including `render copy per-run identity`,
and built the ordinary native shared library and benchmark. Its
hosted MSVC version is 19.44.35229; its `/Od` timings are not
directly comparable to the original local `/O2` benchmark.
The Linux GCC13 native suite has passed its ordinary test step,
but its separate sanitizer step is **still in progress at the
time of this checkpoint**. A green native pipeline or sanitizer result
must not be inferred until the job and artifacts complete.

### Current verified artifact identities

| Artifact from exact workflow | GitHub artifact ID | ZIP SHA-256 |
|---|---:|---|
| Native lane Git source archive | `12862088140` | `66ab0ad9ea87e86b8ab837de72a17631427269b54bef7f7a39a2e88a7a2b6b3c` |
| Windows Server 2022 MSVC native build/tests | `12863135825` | `da5b5b943765f13522f4c62e39165f3ebc03cc5fc8f7955141f4e318b23f5e26` |
| Linux actual Godot/GDExtension execution | `12862947234` | `d54cf5d09d39e618f1bdcd58692ab4a168cdd7d4784155262274e846f8e5e46a` |
| Windows pinned LLVM-MinGW DLL build | `12862583002` | `f5741f997eff16718a1209a85eaa3b3ad721f3789aa4685bb4d3404533bf48f6` |
| Windows actual Godot/GDExtension execution | `12862887663` | `25a96228c323749386dec25669a12854dc530fa544ea54c6fe9aa0369924e260` |

All five downloaded ZIP hashes and ZIP CRC checks pass. The
source archive has Git tree
`366615ccf206a37475976ada75cf2a94cf4a26c2`,
and its Git blobs for `native/src/world.cpp`
(`185d00a677fc61f4c12803a83abab221a95101bb`) and
`native/tests/test_world.cpp`
(`78ae6db2e3c10389706c48c66d9b448fa69def91`)
match those fetched from the PR branch exactly.
The source archive contains both source files with SHA-256
`122c5e43002953add091baa431aca19688c6d384e721993dc6b9af6e8f686177`
and
`f7327425f415d4c33aeb4b5eb1afa0203f208b621a3795c7a93033f3ee2ba959`.

Linux GDExtension SHA-256:
`1e28831c3782647202dabb49b9b0e3356fa68320cb15373b6bcf0fefb63c6a50`;
Windows build DLL SHA-256:
`b5b9161eff985eca4f0d2fa270a57c6a037698924d03813acc815181b53ec57e`.
The Windows execution job verifies that exact DLL digest and the
pinned Rapier runtime. Neither DLL is a published LFS runtime.

### Retained qualification-harness negatives

The first isolated Godot workflow (run `40793006181`) and the
subsequent reductions (`40793601940`, `40793628314`) were rejected by
Actions validation **before launching jobs**, due use of
an unavailable job-level `runner.temp` expression. Run
`40793754926` launched, but the Windows build failed before
compilation because the configured SCons executable differed from
the newly created venv location. Those are test-harness setup
failures, **not** passing runtime work or demonstrated native-code
failures. The corrected workflow and source-matched
run `40793815067` remain separately identified.

### Remaining publication and acceptance gates

- **No production/runtime publication.** The checked-in Linux and
  Windows CyberSand LFS GDExtension objects and their
  `runtime-provenance*.json` source-input manifests still describe
  the previous `native/src/world.cpp`. The strict repository
  provenance checker must continue to reject publication until
  corresponding source-matched binaries, manifest hashes and
  required host evidence are published through the repository's
  reviewed runtime process. Do not hand-edit historical hashes.
- Draft-PR Native/GDExtension ready-for-review full matrices remain
  intentionally skipped, not passes. The narrow workflow jobs
  above are additive qualification evidence, not a waiver of
  full exact-final-head checks, independent review, release or Web.
- The resident/nonresident byte-identity suite does not measure
  full real desktop GPU upload, worker backpressure, interactive
  FPS or broad production pacing. Earlier local performance
  measurements retain their original single-host scope.
- This is a **stateless copy optimization**; it does not alter
  cell contents, physics interaction, liquid construction policy,
  full/dirty snapshot exchange or main-thread Rapier ownership.
  It does not qualify PR #283's separate stateful render/physics
  experiments, reactive Wood, fracture, desoliding or #281 completion.

## Review-driven INT64 endpoint correction — 2026-10-29

The [independent code review](https://github.com/techrote/cybersand/pull/290#pullrequestreview-5691486464)
reproduced a **P2 byte-identity regression** in executable source `f041aac3`:
`World::copy_render_cells` formed `region.x + region.width` as an
exclusive signed endpoint, overflowing when a valid region's last
*included* cell was at `INT64_MAX`. The original per-cell
implementation copied `{INT64_MAX, 0, 1, 1}` successfully; the
per-run implementation overflowed and, with recovering UBSan, left
the destination's sentinel bytes unchanged. Related 128-cell and
zero-height probes also failed. This review is filed through the
author's GitHub account and is **not independent human approval**.

### Corrected executable source and test

- [Source fix `1769d6f77011ac51f6e47f0f60cd0be4e1cac307`](https://github.com/techrote/cybersand/commit/1769d6f77011ac51f6e47f0f60cd0be4e1cac307):
  after existing layout preflight, zero extents return without
  computing absolute coordinates; nonempty regions validate
  representability of their *last included* x/y; the traversal
  uses `processed < region.width` and advances only the remaining
  cell **count**, never a potentially unrepresentable exclusive x.
  Invalid positive extents throw `std::overflow_error` before
  modifying destination bytes.
- [Executable+test source `60915dc86631271ea8661377a3458149adda9361`](https://github.com/techrote/cybersand/commit/60915dc86631271ea8661377a3458149adda9361):
  the existing byte-exact per-cell oracle additionally compares
  twelve positive/negative 64-bit boundary and zero-extent
  rectangles, twice per region (tight and +6-byte padded stride)
  and on chunk sizes 128 and 32. Two unrepresentable x/y endpoint
  regions must refuse by `overflow_error` **without modifying
  destination sentinels**.

These changes touch only `native/src/world.cpp` and
`native/tests/test_world.cpp`. No liquid/material policy, World
mutation, render-exchange protocol, native-worker/Godot ownership,
ABI, Rapier or published runtime files were changed.

### Retained failed sanitizer attempt

[Earlier full-sanitizer run `40792599185`](https://github.com/techrote/cybersand/actions/runs/40792599185)
**FAILED** against older executable `f041aac3`, not the corrected
source. The ordinary Linux GCC13 native suite first passed
**165/165** and the full ASan/UBSan binary built successfully;
the all-test sanitizer execution then exhausted its explicitly
bounded **18-minute** command window, exit status **124**.
The original archived
[Linux artifact](https://github.com/techrote/cybersand/actions/runs/40792599185)
has ID `12863827441`, ZIP SHA-256
`4ea00fee1f03231843c32459035388350de4e89b5adf475fdb9b105ca5c25f42`
and valid CRCs. Its `sanitized.txt` contains **146 `[pass]`**
test lines, zero explicit UBSan/ASan reports, then stops in
LCB-002 basin diagnostics. It is a timeout, **not a completed
sanitizer green** and **not evidence that the INT64 bug is absent**.
Earlier Windows/host successes retain their original source.

### Archived corrected-source identities and supplementary probe

The new [source archive from run `40796751009`](https://github.com/techrote/cybersand/actions/runs/40796751009)
was independently materialized and verified:
ZIP artifact `12863903343` SHA-256
`e31cbc9fb7afac6e3af4fd563405cb4ff18902bf4b53cb1755e57a5551ac8e45`,
ZIP CRC pass, inner Git tar SHA-256
`fa62e4e47e7bf6f42533acef31fe8884d8b676ab00135b9fb951b40ba328ad61`.
The native `world.cpp` Git blob
`a6afd8cad4264ac2eca0362d14711158e3606760` and
`test_world.cpp` Git blob
`5613d2166c71fa49fd2b8f65e8caa93857b5d65f`
match the corresponding PR source.
Their file SHA-256 values are respectively
`b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1`
and
`cfb54f5cc58388f1581bd367d3a19a7ff3d260583028980606c6b0e6fda7a69d`.

An additional **independent local native source** probe compiled
these exact archived files with Debian GCC 14.2.0,
`-O0 -g1 -fsanitize=undefined -fno-omit-frame-pointer`, and
`UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`.
All twelve valid rectangles × two padding modes × two chunk sizes
and two explicit invalid-region refusal checks per chunk passed
with no reported UBSan errors. This scratch probe has SHA-256
`9abe54bb70b71ec1fd4294510f4ab01de77931e9edcd54fe195ca91504f6f3a6`;
it is supplemental to, **not** a replacement for, hosted CI.

### Corrected-source host validation and remaining gates

[Linux/Windows source-matched Godot run `40796772252`](https://github.com/techrote/cybersand/actions/runs/40796772252)
**passed all three jobs** (Linux native GDExtension build/host,
pinned Windows GDExtension build, Windows Server 2022 actual
Godot/Rapier host). Both hosts reported
`test_render_world_generation.gd` **23/0** and
`test_render_patch_handoff_regression.gd` **pass**, using Godot
`4.7.stable.official.5b4e0cb0f` and Rapier2D `0.35.2`.

The three independently rehashed artifacts, all with valid ZIP CRCs:
- Linux host artifact `12864820692`, ZIP SHA-256
  `9038b29ff81292c233b90d50e7df8d5886d8da87982277795a987c8459d3157f`;
  recorded Linux GDExtension SHA-256
  `0f60213c7fc3f9a1b1d7ad5143fdb22d453a452cddefd3fe4d7a7cb4d7b6cf45`
  (the binary itself is **not retained** in this host ZIP).
- Windows build artifact `12864098143`, ZIP SHA-256
  `776e3730026be74b44224e0c680952320f9c505072f1840e5712416486f29f22`;
  retained compiled DLL SHA-256
  `6b044fb6bba96d5053251c98125e5f4f0391e0e55ddb66da93e91f4495a89cdd`,
  equal to its manifest.
- Windows execution artifact `12864666382`, ZIP SHA-256
  `6205ed1c5ff9e52bd07db5b93e2b04186aacbb106eaf58373133f0c896e2c3c1`.
  The host verifies the exact built DLL before executing tests.

The separate corrected-source Linux GCC13 ordinary suite,
focused ASan/UBSan tests and Windows MSVC native suite are
[run `40796751009`](https://github.com/techrote/cybersand/actions/runs/40796751009);
**their final results remain pending in this dated checkpoint**,
not inferred from the older source. That workflow tests the
affected render and C API paths with focused sanitizer processes;
it does **not** relabel or substitute for the separate full native
ready-PR matrix. The original end-to-end runtime publication
and Web/interactive frame-rate remain outside this scope.

**Merge still blocked:** original Linux/Windows committed LFS
GDExtension binaries and runtime source-input manifests remain
stale for `native/src/world.cpp`. No binary was promoted and
none of the original runtime provenance hashes was rewritten.
The PR remains draft pending exact-head complete native/full
sanitizer, reviewed runtime publication, formal final-head
GDExtension/Godot/Docs and applicable controls, and independent
acceptance review. This patch does not address PR #283's
independent physical-ejection B=289 NO-GO.

## Final corrected-source scoped results — 2026-10-29

The earlier in-progress statements above retain their exact readback times.
The corrected-source [native run `40796751009`](https://github.com/techrote/cybersand/actions/runs/40796751009)
subsequently **completed with all three jobs SUCCESS**:
source archive/integrity, Linux GCC13 native plus focused sanitizer,
and Windows Server 2022 MSVC native.

| Scope on corrected executable `60915dc` | Observed result |
|---|---|
| Linux GCC13 ordinary native | **165/165** tests pass |
| Linux GCC13 ASan+UBSan `render` filter | **3/3** tests pass; `render copy per-run identity` included |
| Linux GCC13 ASan+UBSan `C API and RGBA` | **1/1** test passes |
| Windows Server 2022 MSVC ordinary native | **165/165** tests pass and benchmark/shared DLL builds finish |
| Linux + Windows exact Godot 4.7 native render hosts | **23/23 render-generation assertions**, patch-handoff pass per OS, three jobs success |
| Full all-test ASan/UBSan | **Not qualified**; old run `40792599185` timed out at 18 minutes |

The real Linux sanitizer job compiled against the **corrected source**
with `-O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined`
and the pinned GCC13 compiler. Its focused `render` and
`C API and RGBA` executions exit successfully with **no
ASan/UBSan error reports**. There is no inference that all
165 tests have been executed under sanitizers. The separate
unsanitized Linux suite does run all 165.

The new independently materialized Linux native artifact
`12864787443` has ZIP SHA-256
`9e4c581e0a82b9b8dd263ed9f175f04b648b87c60708dce036edbcd9c73e41f6`
and passes ZIP CRC inspection. Its `tests.txt` ends
`165 tests passed`; `sanitized-render.txt` ends
`3 tests passed`; `sanitized-capi.txt` ends
`1 tests passed`. The Windows native artifact
`12865140333` has ZIP SHA-256
`ff428f371ff59ac68a3a76ca0a78a96aa889f264c94353d78d4d0e762f7c4841`,
passes CRC inspection, and its MSVC test/build log contains
165 passing test groups and successful final library build.
Its **debug** 1024×1024 fixture reports
290.923 ms per-cell oracle versus 22.9137 ms per-run,
which is **not** a production `/O2` or interactive GPU
performance acceptance number. The sanitizer render test's
per-cell timing is dominated by instrumentation.

An additional isolated GCC14 UBSan probe against the same
archived native source exercised the public C ABI in addition
to the boundary World tests: `cybersand_world_copy_render_cells`
successfully copied the valid `INT64_MAX` last-cell request
and refused unrepresentable x and y requests with zero buffer
mutation. Its expanded source SHA-256 is
`f6c8162445422ea472f41d020342ceb8894ddd459aff0aaaf9573a622cc6a0f0`
and output SHA-256 is
`5f838940140456287687d0fe396e744d59f9a22e0980f14a539da2a4c290b9b2`.
This is scratch supplemental proof, not a committed CI fixture.

The [machine-readable final receipt](2026-10-29-render-copy-int64-qualification-receipt.json)
records each executed-source SHA, both workflow-only verification
heads, ZIP digests, scope, reviewed original failure and
not-qualified gates. The test/production-source delta from
`60915dc` to this documentation update remains documentation
and evidence only.

**Disposition:** the reproduced `INT64_MAX` source regression has
a corrected implementation with source-matched Linux/Windows
runtime and focused sanitizer evidence. It is **not a merge
admission**. The PR remains draft; checked-in LFS GDExtension
objects and manifests still describe the pre-PR native source,
the all-test sanitizer/ready-PR matrices and independent
acceptance review are open, and no Web/interactive frame
performance is claimed. PR #283's B=289 physical ejection
candidate remains NO-GO.

## Independent all-165-case sanitizer coverage — 2026-10-29

The previous [full single-process sanitizer attempt
40792599185](https://github.com/techrote/cybersand/actions/runs/40792599185)
**remains failed** (18-minute timeout after 146 passing groups).
The corrected-source [focused 3+1 sanitizer pass
40796751009](https://github.com/techrote/cybersand/actions/runs/40796751009)
is unaffected. To address the unexecuted 165-case coverage without
silently extending the repository's normal release timeouts, a
**separate, source-frozen verification-only** implementation was
built on branch `verify/render-copy290-sanitizer-shards-20261029`.
It adds only `.github/workflows/render-copy-290-sanitizer-shards.yml`
and `tools/ci/render_copy_290_sanitizer_shard.py` relative to the
existing documentation head `16087b2a`. The executable source remains
`60915dc86631271ea8661377a3458149adda9361` (tree
`dc370ee4e957ce34e752ff665afef0ed9e325326`) with
unchanged `world.cpp` and `test_world.cpp` Git blobs.

### Execution and evidence

[All-test run 40800942455](https://github.com/techrote/cybersand/actions/runs/40800942455)
on verification head `1e39d8833588298f051ff820fd16a5c3f1af6f33`
**passed all six jobs**: compiled the pinned Ubuntu 24.04 GCC13
combined ASan+UBSan binary once; ran four deterministic index
shards on that **identical binary SHA-256
`8d50798344cc6bdb058cabb7e7ea78da9a2b96959058eaba711aaf9d4a5af1dc`**;
and independently reduced all shards against the registered
165-test C++ table. The test registry has 165 unique labels,
SHA-256 `2f48aa7ecb97054395a2893f1c282fe127e7d278dd2bf5e0c8a9ee222b2cad85`.

| Shard | Separate test processes | Successful tests | Sum of test wall times |
|---|---:|---:|---:|
| 0 | 42 | 42 | 76.855 s |
| 1 | 41 | 41 | 292.973 s |
| 2 | 41 | 41 | 313.056 s |
| 3 | 41 | 41 | 198.879 s |
| **Total** | **165** | **165** | **881.762 s** |

Every requested registered label passed, with no sanitizer report in
the retained raw outputs. These runs use `ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1:halt_on_error=1`
and `UBSAN_OPTIONS=halt_on_error=1:print_stacktrace=1`.
The source, binary and all test-output hashes were compared
independently: **6/6 ZIP SHA-256 and ZIP CRC checks pass; 165/165
raw stdout SHA-256 values match their records; all four shard
manifests refer to the same compiled binary**. The build ZIP
contains that 110,637,016-byte binary. The separately archived
test logs and a reproducible source/coverage reducer are retained
by Actions for 30 days.

[Machine-readable receipt](2026-10-29-render-copy-sanitizer-matrix-receipt.json)
binds the six artifact IDs and complete SHA-256 values, frozen
source/tree/blobs, original negative, and exact coverage limits.
The initial [verification run
40800824035](https://github.com/techrote/cybersand/actions/runs/40800824035)
failed **before compiling**, because the initial guard allowed
only the two new verifier files but overlooked the three
already inherited documentation/evidence files. This was corrected
to an exact, five-file allowlist; the failed attempt remains
an explicit test-harness negative.

**Scope:** All 165 test *functions* were executed successfully
under combined ASan/UBSan in **individually isolated processes**,
not one original suite process. This does **not** establish that
the original 165-test single-process order or lifetime/cross-test
interactions pass; the normal full Native, TSan, entire Godot,
source-matched LFS publication and ready-PR gates are still open.
No code, ABI, material/liquid policy, snapshot ACK, native-worker
authority, Rapier ownership or default changed in the verifier.

### Publication input delta — independent source-archive comparison

Both committed Windows and Linux `runtime-provenance*.json` records
were compared **file by file** against the exact previously archived
corrected-source Git tar (ZIP `e31cbc9f...`, inner tar
`fa62e4e4...`). The two platforms agree:

- Of **80** native `source_inputs`, exactly **one** differs:
  `native/src/world.cpp`, recorded
  `b4ab1dbf2277eb3213d827f00ddd1dbb3e1294b27e312062cb877b83ee083728`,
  current
  `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1`.
- Of **549** historical `build_inputs`, **six** no longer match
  the current source archive: `.gitattributes`,
  `native/tests/test_world.cpp`, and four deliberately retired
  PLAY-AUTO-002 publisher paths (workflow, request, publisher
  script, test script). The old ledger is **historical**, not
  a template to silently reuse or edit in place.

The current platform binaries and manifests remain **unpublished
and source-stale**. The [unarmed, review-only new-publisher
admission protocol](https://github.com/techrote/cybersand/pull/290#issuecomment-6485477234)
requires an explicit frozen request, complete dual-host execution,
new accurate source/build ledgers and guarded four-path LFS
append before the final exact-head acceptance matrix. No
request was armed and no binary or provenance file was changed.
