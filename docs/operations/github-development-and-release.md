---
title: Private GitHub development and release
status: Current
scope: M11 import identity, repository layout, dependency pins, Linux and Windows builds, CI, release artifacts, and development conventions
keywords: [GitHub, private repository, Git LFS, CI, build, release, dependency pin]
related-documents: [../BUILD_ID.md, testing-validation-and-replay.md, ../../CONTRIBUTING.md, ../../third_party/native-toolchain.lock.json]
last-reviewed: 2026-08-28
implementation-state: The audited M11 source history is preserved; repository hygiene, LFS policy, dependency locks, consistency checks, and feasible GitHub Actions validation are Current.
---

# Private GitHub development and release

## Imported baseline

- Authoritative source commit: `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`.
- Render lifetime fix: parent commit `c644b235fbcb5e085802918c0d6cebec118b6405`.
- Build ID: `m11-audit-remediation-render-handoff-water-native-repro-2026-08-28`.
- Audited tag: `m11-audited` points to the authoritative source commit, before
  repository-hosting metadata was added.
- The focused historical commits are preserved. Migration does not squash or
  rewrite them, so hashes in the M11 evidence remain valid.

## Repository layout and ownership

| Path | Source-control policy |
|---|---|
| `native/` | Track all C/C++ source, headers, tests, benchmark, and provenance data. |
| `godot/` | Track project source, scenes, shaders, assets, tests, UIDs, extension descriptors, and the three portable `.godot` bootstrap records. |
| `godot/addons/godot-rapier2d/` | Track the exact v0.35.2 add-on, notices, and runtime binaries; binaries use Git LFS. |
| `godot/addons/cybersand_native/` | Track descriptors, notices, and the audited Linux/Windows x86_64 runtime binaries; binaries use Git LFS. |
| `docs/` | Track the RAG-optimized hierarchy, ADRs, current status, audit evidence, and operating procedures. |
| `tools/`, `.github/` | Track build, verification, CI, and repository automation. |
| `third_party/*.lock.json` | Track exact sources, revisions, hashes, licenses, runtime floors, and rebuild requirements. |

Do not track editor imports beyond the three documented portable bootstrap
files, native build directories, package environments, compiler caches, logs,
profiles, crash dumps, archives, setup-cache contents, downloaded editors, or
machine-specific configuration. `.gitignore` is the executable policy.

## Binary and external artifact policy

Runtime libraries needed to open the checked-out Godot project are kept in the
repository through Git LFS. This preserves drag-and-run behavior after
`git lfs pull` without turning future Git commits into large binary deltas.

The Godot editor, export templates, godot-cpp source/static libraries, SCons
wheel, LLVM-MinGW toolchain, compiler packages, and milestone ZIPs do not belong
in Git. Existing M11 setup-cache v2 remains a private offline recovery artifact.
For ordinary development, reconstruct those inputs from the URLs, versions, and
SHA-256 values in `third_party/native-toolchain.lock.json`; `godot-cpp` is fixed
to commit `101ae38034304346a46ea9ea84ae156d3e860496`.

Distributable game/editor bundles should be attached to a GitHub Release with a
SHA-256 sidecar produced from a clean tagged checkout. Do not put export output
or complete toolchains in source history. Export templates are currently absent
and unpinned, so export CI must remain disabled until an exact template package
is recorded.

## Exact dependencies

| Dependency | Pin |
|---|---|
| Godot editor/runtime | `4.7.stable.official.5b4e0cb0f` |
| Godot API | `4.7` |
| godot-cpp | `101ae38034304346a46ea9ea84ae156d3e860496` |
| Godot Rapier Physics 2D | official single-2D `v0.35.2`, release asset SHA-256 `73b46bfe2cfc40e3875f4f367478bbd2b1090f563eeef57f4fed3fc274aae1f0` |
| SCons | `4.10.1`, wheel SHA-256 `bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126` |
| Linux compiler/linker | GCC/G++ 13.3.0, GNU binutils 2.42 |
| Windows cross-toolchain | LLVM-MinGW 20260826, LLVM 23.1.0, UCRT; archive SHA-256 `cee8d2ce3da5145ce4dc882e70d0b0719a783d53a99752c60948fc0659975a65` |

The Linux bundle requires GLIBC 2.34 because of Rapier2D. The CyberSand
extension itself is capped at GLIBC 2.32, GLIBCXX 3.4.30, and CXXABI 1.3.9.

## Build paths

### Linux x86_64

1. Obtain the exact godot-cpp commit and SCons 4.10.1, or restore them from
   setup-cache v2.
2. Set `GODOT_CPP_ROOT` and `SCONS_PYTHON`.
3. Run `tools/build_pinned_godot_cpp.sh linux`.
4. Run `tools/build_native_extension.sh`.
5. Run `tools/check_linux_runtime_floor.sh` and the headless Godot suite.

The release path refuses source, compiler, linker, static-library, or output
hash drift. CI may set `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` only for a clearly
labelled validation build, never to claim bit-identical M11 reproduction.

### Windows x86_64 from Linux

1. Restore or verify LLVM-MinGW 20260826 and set `LLVM_MINGW_ROOT`.
2. Build the exact godot-cpp commit with
   `tools/build_pinned_godot_cpp.sh windows`.
3. Set `WINDOWS_CXX` and run `tools/build_native_extension_windows.sh`.
4. Validate PE32+ architecture/imports on Linux.
5. Launch the result with exact Godot 4.7 on Windows before describing it as
   runtime-validated. Cross-build structure alone is not Windows runtime proof.

## Continuous integration

GitHub Actions covers native compile/tests and sanitizers, Linux and Windows
x86_64 GDExtension validation builds, exact Godot headless regressions,
documentation/status/provenance checks, Git LFS integrity, and tagged runtime
artifact hashes. Each command is bounded with `timeout` and workflows have job
timeouts. Interactive GPU quality, Windows Godot runtime, PowerShell behavior,
exports, and LeakSanitizer on a compatible host remain outside the current
hosted matrix.

## Repository conventions

- `main` is the protected integration branch; use focused topic branches.
- Keep commits reviewable and pair behavior changes with tests and status docs.
- Never change a **Current**, **Approved design**, **Planned**,
  **Deferred / experimental**, or **Explicitly rejected** claim without checking
  its source evidence and related ADRs.
- Add a new ADR when changing authority, ownership, determinism, dependency
  selection, or a previously rejected boundary.
- Agents must inspect `docs/README.md`, `docs/BUILD_ID.md`, the relevant ADR,
  and current tests before editing a subsystem.
- Do not commit generated imports, test output, secrets, absolute paths, or a
  downloaded dependency that is not covered by its license and provenance lock.
- A release tag is annotated. Release notes list passed, failed, skipped,
  timed-out, and untested platform checks without broad crash-free claims.

The CyberSand project itself has no selected public license. Private development
may continue, but public release or third-party distribution requires an owner
licensing decision; see `LICENSE_STATUS.md`.
