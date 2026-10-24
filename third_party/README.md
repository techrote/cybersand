# Dependency locks and provenance

**Current reference, reviewed 2026-10-24.** Each lock has a checkpoint/platform
scope; its existence does not certify a current artifact or passing build.
[Build instructions](../docs/operations/local-build-and-validation.md) own exact
tool selection and [evidence](../docs/reference/validation-evidence.md) owns observed results.

| Record | Scope |
|---|---|
| [godot-runtime.lock.json](godot-runtime.lock.json) | Historical M11 Linux editor; then-absent templates. Local Windows templates now exist, but current export lock reconciliation remains open |
| [native-toolchain.lock.json](native-toolchain.lock.json) | Exact godot-cpp, SCons, Linux-host toolchain archive, compiler packages, historical library/output hashes and Linux ABI floors |
| [Rapier lock](../godot/third_party/rapier2d.lock.json) | Original single-2D v0.35.2 release/Web identities plus selected Windows/Linux x86_64 cooperative-BVH backport manifests |
| [Rapier backport build lock](rapier-bvh-build.lock.json) | Immutable build-time candidate inputs: exact addon/crate/Cargo.lock, Rust, features, patch and original/patched join hashes; subsequent selection is in the runtime lock |
| [Third-party notices](../THIRD_PARTY_NOTICES.md) | Attribution and redistribution notices, supplemented by add-on-local licenses |

The local Windows-host LLVM-MinGW ZIP is distinct from the lock's Linux-host
cross-toolchain archive. Local DLL/static-library hashes differ from historical
outputs. Do not overwrite old hashes to manufacture reproducibility.
The [release guide](../docs/operations/github-development-and-release.md) records
Web CI 4.0.11 versus builder4.0.20 and template/provenance gaps.

Downloaded tools and caches are outside Git. Required runtime libraries use LFS;
remaining pointers are not usable binaries. [Source identity](../docs/operations/source-checkpoint-and-recovery.md)
records checkpoint/recovery scope. Verify exact payloads and retain notices before
using or distributing rebuilt dependencies.

The 2026-10-24 [backport evidence](../docs/audits/2026-10-24-physical-actor-bvh-validation.md)
records the live blocking receive, deterministic control and complete same-host
paired qualification. The selected desktop manifests include original build
records and source-input hashes; other platforms retain upstream release bytes.
The addon MIT license and Rapier Apache-2.0 notices remain in the vendored addon.
