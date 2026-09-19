---
title: Local build and validation
status: Current
document-kind: guide
scope: Pinned source build entry points, Windows workspace wrappers, platform boundaries and freshness limits
canonical-for: [build-entry-points, dependency-pins, build-freshness]
last-reviewed: 2026-09-09
related-documents: [source-checkpoint-and-recovery.md, testing-validation-and-replay.md, web-threading.md]
---

# Local build and validation

## Which build inputs are required?

**Current:** build scripts and locks select the following inputs. A pin is a
requirement, not evidence that every platform artifact was built or tested.

| Input | Required identity and authoritative reference |
|---|---|
| Godot editor/runtime | `4.7.stable.official.5b4e0cb0f`; [runtime lock](../../third_party/godot-runtime.lock.json) |
| godot-cpp / API | `101ae38034304346a46ea9ea84ae156d3e860496` / `4.7`; [native lock](../../third_party/native-toolchain.lock.json) |
| SCons | `4.10.1`; [hash-pinned requirement](../../tools/requirements-build.txt) |
| Windows compiler | LLVM-MinGW 20260826, Clang 23.1.0, UCRT; native lock pins the Linux-host archive; local Windows ZIP is a distinct input |
| Linux compiler/linker | GCC/G++ 13.3.0 / binutils 2.42; native lock |
| Web compiler | Emscripten **4.0.20**, checked by [build_web.py](../../tools/build_web.py) |
| Rapier2D | Official single-precision 2D **v0.35.2**; [Rapier lock](../../godot/third_party/rapier2d.lock.json) |
| Web templates | Exact Godot 4.7 dlink templates: `web_dlink_nothreads_{debug,release}.zip` for compat, `web_dlink_{debug,release}.zip` for threaded |

Keep native and Web godot-cpp checkouts separate: generated bindings and archives
are target-specific. Python 3.12.14 was used locally; the workspace helper requires
Python 3.10+. Do not silently update pins while debugging a simulation change.

The historical runtime lock still labels templates `absent-and-unpinned` although
the local Windows setup has exact templates. This is an unresolved release-lock
gap. The configured Web CI also disagrees with the builder; see
[release prerequisites](github-development-and-release.md#unresolved-ci-contradictions).

## Windows development commands

From `C:/kybersand`, the companion workspace provides `dev.cmd` / `tools/dev.py`.
Host paths, installation and environment overrides belong to
`C:/kybersand/docs/LOCAL_DEVELOPMENT.md`. Source-only clones do not contain these
wrappers; the repository-native scripts are listed below.

```powershell
.\dev.cmd doctor
.\dev.cmd native-bindings
.\dev.cmd native-build
.\dev.cmd native-test
.\dev.cmd godot-test
.\dev.cmd web
# Optional internally parallel Web profile:
.\dev.cmd web --profile threaded
```

`native-bindings` builds pinned Windows godot-cpp; `native-build` builds the
GDExtension. `native-test` compiles/runs the C header check and native tests;
`godot-test` imports the project then runs all `test_*.gd` runners. Godot tests
load the installed DLL: running them alone does **not** rebuild that DLL.
Record its hash and source identity with the result. The wrapper allows 240 s
for import, 180 s per Godot runner, and rejects Godot error output even with exit 0.

M11 output byte equality now requires `CYBERSAND_VERIFY_M11_OUTPUT=1`; current
builds keep compiler/source pin checks and identify their own tested outputs. See
[validation policies](current-and-historical-validation.md). The existing local
`CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` override bypasses some compiler/dirty-source
checks. It still
requires the exact godot-cpp revision. Inspect that checkout explicitly; a local
validation build with this override is not bit-identical M11 reproduction.

## Repository-native build and test commands

From the source root on a configured Linux host:

```sh
timeout 120 make test
timeout 300 make sanitize
timeout 300 make thread-sanitize
# GODOT_CPP_ROOT and SCONS_PYTHON identify the pinned dependencies:
timeout 3600 tools/build_pinned_godot_cpp.sh linux
timeout 3600 tools/build_native_extension.sh
timeout 60 tools/check_linux_runtime_floor.sh
```

These are executable entry points, **not current Linux pass claims**.
[Makefile](../../Makefile) defines Debug `-O0 -g3` tests, ASan+UBSan and TSan.
The default sanitizer target enables leak detection; the historical M11 run
disabled it after a hosted `/proc` limitation. Preserve that distinction.
Windows cross-builds use `build_pinned_godot_cpp.sh windows` and
[build_native_extension_windows.sh](../../tools/build_native_extension_windows.sh)
with `LLVM_MINGW_ROOT`/`WINDOWS_CXX`. PE/import inspection alone cannot prove a
Windows runtime launch.

## Web compile, export and execution are different checks

From source, with the SDK active and paths adapted to the host:

```text
python tools/build_web.py --cpp <web-godot-cpp> --compile-only
python tools/build_web.py --cpp <web-godot-cpp> --godot <godot> --templates <templates>
```

The default profile is compatibility. Add `--profile threaded` for pthreads.
Both normal profiles package Rapier; `--cellular-only` is a diagnostic option.
`--native-tests` requires a separate `--native-cpp` directory. `--compile-only`
returns before runtime tests/export even if `--native-tests` is present.

`--export-only` checks existing WASM structure, not freshness against source.
The workspace wrapper still supplies the acquisition base as `--source-commit`;
that export field is not current HEAD. Capture current source and artifact hashes
separately until the producer is repaired in an implementation checkpoint.
See [source identity](source-checkpoint-and-recovery.md).

Preview generated output through HTTP with WASM MIME and profile headers, then
run the actual browser fixture. Checksums/HTTP checks prove packaging; native
headless Godot proves native execution; only browser execution tests Web behavior.
The [Web guide](web-threading.md) owns hosting requirements, and the
[validation ledger](../reference/validation-evidence.md) owns dated outcomes.

## How is the physics baseline rebuilt?

Follow [physics characterization](physics-characterisation.md): rebuild the
native CLI and adapter before running the deterministic P1–P4 matrices, then
build/export both Web profiles and execute them in a real browser. Capture actual
HEAD/local file hashes separately from legacy export acquisition labels.
The [2026-09-09 report](../audits/2026-09-09-physics-characterisation.md) records
Windows/Web results and the unavailable Linux execution environment. Local
rebuilt artifacts are measured inputs, not automatically updated published LFS
runtime manifests; the current release gate remains separate from M11 integrity.

Issue #10 uses the [current acceptance commands](physics-characterisation.md#how-do-i-reproduce-issue-10-acceptance)
and [its own artifact audit](../audits/2026-09-09-issue-10-granular-policy.md).
Both native Web modules were rebuilt before final script exports. The shared
threaded probe must yield before replacing a newly constructed default world,
after replacement and after teardown so browser pthread startup/recycling can
finish before synchronous native joins. This fixture lifecycle requirement does
not change production native ownership or introduce asynchronous Web simulation.

## Issue17 native precision research

The separate codex/issue-17-state-precision worktree has an experimental native
mass interface and fixed wide Cell. Use its [registered driver](state-precision-experiment.md)
and [source/artifact evidence](../audits/2026-09-11-issue-17-state-precision.md),
not the workspace default DLL builder. No experimental DLL, Web module, save
migration or renderer was published. Core tests/timing do not certify those adapters.

## MicroScenario harness checks

The new `test_microscenarios.gd` and `test_microscenario_controllers.gd` are included
by the existing `tools/ci/run_godot_regressions.py` test discovery. Run them against
the pinned runtime, together with existing Tower, Water, failed-tick/region and
immutable render-handoff regressions when changing the harness.

The [MicroScenario runbook](microscenarios.md#headless-runs-from-the-same-definition)
describes the bounded native-only JSON runner. Its result is not a Windows or
browser run merely because it exercises the synchronous controller on Linux.
Use actual platform artifacts and retain their identities for platform acceptance.
