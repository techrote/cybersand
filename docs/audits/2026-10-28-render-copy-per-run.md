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
