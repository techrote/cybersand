# Dependency locks and provenance

Status: **Current** provenance map, reviewed 2026-09-08. Locks have different
checkpoint/platform scopes; their existence does not certify the reconstructed
local snapshot, a restored runtime, or an executed test. The
[current audit](../docs/audits/2026-09-08-documentation-audit.md) records observed
dependency/runtime hashes, LFS pointers and validation limits.

- [godot-runtime.lock.json](godot-runtime.lock.json) pins the historical M11 Linux editor and records its then-absent export templates. Exact Godot remains `4.7.stable.official.5b4e0cb0f`; local Windows tools are in `C:/Godot47`.
- [native-toolchain.lock.json](native-toolchain.lock.json) pins godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`, SCons 4.10.1, the **Linux-host** LLVM-MinGW archive, host compiler packages, historical cached libraries/output hashes, and Linux ABI floors. The Windows-host LLVM-MinGW ZIP is a distinct archive; local DLL/static-library bytes differ from historical outputs.
- [rapier2d.lock.json](../godot/third_party/rapier2d.lock.json) pins the official single-precision 2D v0.35.2 release asset and both Web WASM hashes. Its Linux activation note is historical; Windows/Chromium runs are scoped in the [runbook](../docs/operations/rapier-2d-migration-runbook.md).
- [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md) and add-on-local license files preserve attribution.

**Current local inputs:** the retained official Godot 4.7 export-template TPZ
and its four dlink debug/release threaded/no-thread ZIP members are available.
The TPZ SHA-256 is recorded in `C:/kybersand/LOCAL-DEV-SETUP-REPORT.md` and the
current audit evidence. Thus the historical lock's `absent-and-unpinned` field
is stale for local setup, but has not been replaced by a release export lock.
The builder requires Emscripten **4.0.20** while checked-in Web CI still requests
**4.0.11**; see [build/CI contradictions](../docs/operations/github-development-and-release.md).
Reconcile these implementation/lock issues in a future checkpoint; historical
hashes must not be rewritten to make a current build look like M11.

Downloaded archives and package caches are not source-controlled. Verify every
download before extraction. The private M11 setup-cache v2 was an optional
historical recovery artifact; its present completeness has not been verified.
Current offline development requires separate local tools/bindings/downloads
and restored runtime objects, not just these lock files. See
`C:/kybersand/docs/LOCAL_DEVELOPMENT.md`.
