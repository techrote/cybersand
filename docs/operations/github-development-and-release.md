---
title: Repository development and release
status: Current
document-kind: guide
scope: Local repository policy and unresolved remote CI and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-09-08
related-documents: [source-checkpoint-and-recovery.md, local-build-and-validation.md, documentation-maintenance.md]
---

# Repository development and release

## Current checkout and repository policy

The active source now has upstream-derived history and a local checkpoint branch.
Use [source checkpoint and recovery](source-checkpoint-and-recovery.md) for exact
identities, companion workspace scope and dirty-state inspection. No push or
publication was performed by the documentation rewrite. Remote privacy, branch
protection and current CI results have not been verified; intended historical
integration branch names do not establish today's remote policy.

Track source, tests, docs, locks, notices and required runtime libraries. Runtime
binaries use [.gitattributes](../../.gitattributes) and Git LFS; a pointer is not a
usable library. Fourteen other-platform pointers remain locally unresolved.
Ignore generated imports beyond the three portable bootstrap records, builds,
exports, tools, caches, logs and local configuration. See [.gitignore](../../.gitignore),
[CONTRIBUTING](../../CONTRIBUTING.md) and [dependency provenance](../../third_party/README.md).
Do not change historical release hashes to accept a local rebuild.

## Unresolved CI contradictions

**Current inspected configuration, not a remote execution result:**

| Conflict | Source evidence | Required next checkpoint |
|---|---|---|
| Web CI chooses Emscripten 4.0.11; builder requires 4.0.20 | [web-toolchain.yml](../../.github/workflows/web-toolchain.yml), [web-demo.yml](../../.github/workflows/web-demo.yml), [build_web.py](../../tools/build_web.py) | Align pinned toolchain and artifact producer/consumer, then execute CI |
| Workflow passes `--native-tests` without separate `--native-cpp` | Same builder argument validation and Web workflow | Supply isolated native bindings; confirm intended host support |
| `--compile-only --native-tests` does not run runtime fixtures/export | Builder returns after compilation before those stages | Choose explicit coverage and test that the workflow actually executes it |
| Runtime lock says templates absent; local export uses exact retained templates | [runtime lock](../../third_party/godot-runtime.lock.json) and local setup report | Create current export provenance; preserve historical lock scope |
| Wrapper export `source_commit` remains acquisition base | Companion `C:/kybersand/tools/dev.py::web_command`; builder's `--source-commit` | Bind builds to actual HEAD plus local changes and artifact hashes |

These changes are **Planned**, outside the documentation rewrite. Workflow
presence is not a passing CI run. The existing workflows configure useful native,
sanitizer, extension and consistency checks, but their actual current outcomes
must be read before a release claim.

## Release gates

Use a clean, identified tagged source checkpoint, materialize required LFS objects,
verify [exact build inputs](local-build-and-validation.md), build each supported
artifact, and execute the appropriate native/browser/visual matrix. Record
source-to-binary identity and SHA-256 sidecars. Cross-build format checks are
separate from running Windows Godot; Linux M11 tests are historical evidence.
List failed, timed-out, skipped and unavailable checks beside passes.

Distribution additionally needs the owner's project licensing decision:
[LICENSE_STATUS.md](../../LICENSE_STATUS.md) states no selected public license.
Keep third-party notices and exact Rapier/godot-cpp provenance in every bundle.
Use the [documentation checklist](documentation-maintenance.md) before tagging;
publication itself requires an authorized release task.
