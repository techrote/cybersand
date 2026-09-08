---
title: Private GitHub development and release
status: Current
scope: Current local source/build provenance, historical M11 release identity, repository policy and unresolved CI/release prerequisites
keywords: [GitHub, private repository, Git LFS, CI, build, release, dependency pin]
related-documents: [../BUILD_ID.md, testing-validation-and-replay.md, ../../CONTRIBUTING.md, ../../third_party/native-toolchain.lock.json]
last-reviewed: 2026-09-08
implementation-state: This local source is a reconstructed blob snapshot with edits and no Git history. Build scripts and historical locks exist; remote privacy, branch protection, committed backup and current CI success are not verified.
---

# Private GitHub development and release

## Current workspace and historical baseline

**Current local identity:** develop in `C:/kybersand`; `source/` has no `.git`.
`SOURCE-PROVENANCE.json` records acquisition from `web-demo-m11` base
`e2892c54d4bd91aac60971e81c748bd49fbe2adb`; later local edits are not that commit.
The retained older Documents workspace has an unborn Git branch, not committed
source history. Inspect the [2026-09-08 audit](../audits/2026-09-08-documentation-audit.md)
for changed-file, backup and remaining LFS-pointer evidence. Never infer a clean
checkout, saved checkpoint or successful remote backup from the provenance ID.

The following identities belong to the **historical audited M11** records:

- Audited source commit: `05ea45fda7bdd7b0150eb86c4922c202e89e08f4`.
- Render lifetime fix: parent commit `c644b235fbcb5e085802918c0d6cebec118b6405`.
- Build ID: `m11-audit-remediation-render-handoff-water-native-repro-2026-08-28`.
- Audited tag: `m11-audited` points to the authoritative source commit, before
  repository-hosting metadata was added.
- The migration report records preserved history; that history is not available
  in this local source directory. [Historical reports](../audits/m11/README.md)
  preserve the reported results and hashes without certifying current source.

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

The repository's intended runtime-library policy uses Git LFS. In an actual Git
checkout, restore and verify LFS objects before claiming drag-and-run readiness.
This snapshot has restored local Windows/Web binaries and remaining other-platform
pointers; `git lfs pull` cannot restore them from a source directory without Git.

The Godot editor, export templates, godot-cpp source/static libraries, SCons
wheel, LLVM-MinGW toolchain, compiler packages, and milestone ZIPs do not belong
in Git. Existing M11 setup-cache v2 remains a private offline recovery artifact.
For ordinary development, reconstruct those inputs from the URLs, versions, and
SHA-256 values in `third_party/native-toolchain.lock.json`; `godot-cpp` is fixed
to commit `101ae38034304346a46ea9ea84ae156d3e860496`.

Distributable game/editor bundles should be attached to a GitHub Release with a
SHA-256 sidecar produced from a clean tagged checkout. Do not put export output
or complete toolchains in source history. **Current local builds** use retained
official Godot 4.7 dlink templates and recorded SHA-256 in the 2026-09-07 setup
report (`C:/kybersand/LOCAL-DEV-SETUP-REPORT.md`). The historical
[runtime lock](../../third_party/godot-runtime.lock.json) still says
`absent-and-unpinned`; it has not become a current export/release provenance lock.
Reconciling that lock and a release validation matrix is **Planned**, outside
this documentation-only audit.

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
| Local Windows-host toolchain | Same release/compiler, Windows ZIP SHA-256 `ae601f4e0f72bbdf441ad2df8bb16f037e2e9251559ea6b37b4057aef39c06c3`; distinct from the Linux-host cross-toolchain archive |
| Local Web compiler | Emscripten **4.0.20**, checked by [build_web.py](../../tools/build_web.py) |

The Linux bundle requires GLIBC 2.34 because of Rapier2D. The CyberSand
extension itself is capped at GLIBC 2.32, GLIBCXX 3.4.30, and CXXABI 1.3.9.

## Build paths

### Active Windows workspace

From `C:/kybersand`, use `dev.cmd doctor`, `native-bindings`, `native-build`,
`native-test`, `godot-test`, then `web` (compatibility) or `web --profile threaded`.
Detailed commands and local path setup are in `C:/kybersand/docs/LOCAL_DEVELOPMENT.md`;
Godot is at `C:/Godot47`. Use separate native/Web generated godot-cpp bindings.
The explicit local `CYBERSAND_ALLOW_TOOLCHAIN_DRIFT=1` permits known output/archive
hash differences; it does not attest to a historical reproducible release.
Web defaults include pinned Rapier2D; `--cellular-only` is an explicit low-level
diagnostic option. See [Web threading](web-threading.md) and the
[Rapier runbook](rapier-2d-migration-runbook.md).

The Linux instructions below describe checked-in scripts and historical build
requirements, not a Linux build executed in this Windows audit.

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

## Continuous integration: configured coverage and unresolved drift

Checked-in GitHub Actions workflows configure native compile/tests and sanitizers, Linux and Windows
x86_64 GDExtension validation builds, exact Godot headless regressions,
documentation/status/provenance checks, Git LFS integrity, and tagged runtime
artifact hashes. Each command is bounded with `timeout` and workflows have job
timeouts. Interactive GPU quality, Windows Godot runtime, PowerShell behavior,
exports, and LeakSanitizer on a compatible host remain outside the current
hosted matrix. Workflow presence is not evidence of execution or a passing remote
run; no current remote CI result was inspected in this audit.

**Unresolved source configuration contradiction:**
[web-toolchain.yml](../../.github/workflows/web-toolchain.yml) prepares Emscripten
4.0.11 and [web-demo.yml](../../.github/workflows/web-demo.yml) restores a fixed
4.0.11 artifact/run, while the current Web builder requires 4.0.20. The workflow
also passes `--compile-only --native-tests` without the now-required separate
`--native-cpp`, so the builder rejects the invocation during argument validation.
Even with that argument supplied, compile-only returns after library compilation
and before runtime fixtures/export. Repair and execute the workflow in a separately
authorized implementation checkpoint before relying on it. Artifact retention,
remote availability and branch protection remain unverified.

## Repository conventions

- `main` is the intended integration branch in historical guidance; verify actual remote protection and branch identity before relying on it. Use focused topic branches in a real checkout.
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
