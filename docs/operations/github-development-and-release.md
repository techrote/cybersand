---
title: Repository development and release
status: Current
document-kind: guide
scope: Local repository policy and unresolved remote CI and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-09-19
related-documents: [source-checkpoint-and-recovery.md, local-build-and-validation.md, documentation-maintenance.md, ../audits/2026-09-19-runner-routing-weekend-benchmark.md]
---

# Repository development and release

## Current checkout and repository policy

The active source now has upstream-derived history and a local checkpoint branch.
Use [source checkpoint and recovery](source-checkpoint-and-recovery.md) for exact
identities, companion workspace scope and dirty-state inspection. No push or
publication was performed by the documentation rewrite itself. The subsequent
owner-authorized [GitHub milestone](../audits/2026-09-08-github-milestone.md) verified
that `techrote/cybersand` is private and published both local histories. Branch
protection is not established; dated CI outcomes are recorded in the
[publication reconciliation](../audits/2026-09-08-validation-reconciliation.md). Intended historical
integration branch names do not establish today's remote policy.

Track source, tests, docs, locks, notices and required runtime libraries. Runtime
binaries use [.gitattributes](../../.gitattributes) and Git LFS; a pointer is not a
usable library. Finalisation materialized and verified all 18 required local
runtime payloads; their platform execution scope still requires dated evidence.
Ignore generated imports beyond the three portable bootstrap records, builds,
exports, tools, caches, logs and local configuration. See [.gitignore](../../.gitignore),
[CONTRIBUTING](../../CONTRIBUTING.md) and [dependency provenance](../../third_party/README.md).
Do not change historical release hashes to accept a local rebuild.


## Current runner routing and temporary measurement

**Current configuration, 2026-09-19:** source d6a616e routes sustained Linux
GDExtension, Native and Web workloads through Sengi while retaining Avrea for
Windows, regression fan-out and short latency-sensitive gates. Per-job runner
variables remain explicit overrides, including Avrea wide-runner use when a
workload benefits from 16/32 vCPUs.

A temporary, non-gating [weekend runner benchmark](../audits/2026-09-19-runner-routing-weekend-benchmark.md)
compares GitHub ubuntu-slim 1-vCPU and Avrea 1-vCPU on representative micro,
documentation, regression and SCons build classes. It records acquisition,
workload and wall-time evidence rather than selecting a runner from each
invocation's current contents. The active benchmark window ends
2026-09-21 05:00 UTC; the workflow has an explicit deadline and scheduled
self-disable. Until the retained evidence is reduced, this experiment does not
change required CI or the existing Sengi routing for sustained work.

## Unresolved CI contradictions

**Current inspected configuration, not a remote execution result:**

| Conflict | Source evidence | Required next checkpoint |
|---|---|---|
| Web CI chooses Emscripten 4.0.11; builder requires 4.0.20 | [web-toolchain.yml](../../.github/workflows/web-toolchain.yml), [web-demo.yml](../../.github/workflows/web-demo.yml), [build_web.py](../../tools/build_web.py) | Align pinned toolchain and artifact producer/consumer, then execute CI |
| Workflow passes `--native-tests` without separate `--native-cpp` | Same builder argument validation and Web workflow | Supply isolated native bindings; confirm intended host support |
| `--compile-only --native-tests` does not run runtime fixtures/export | Builder returns after compilation before those stages | Choose explicit coverage and test that the workflow actually executes it |
| Runtime lock says templates absent; local export uses exact retained templates | [runtime lock](../../third_party/godot-runtime.lock.json) and local setup report | Create current export provenance; preserve historical lock scope |
| Wrapper export `source_commit` remains acquisition base | Companion `C:/kybersand/tools/dev.py::web_command`; builder's `--source-commit` | Bind builds to actual HEAD plus local changes and artifact hashes |

These Web changes remain **Planned**, tracked by issue #3. Current source/runtime
identity, retained historical integrity and fresh Linux Godot CI are now
[separate validation gates](current-and-historical-validation.md). This resolves
the M11/current gate conflict without changing historical hashes. Native and
sanitizer execution is recorded in the [dated reconciliation](../audits/2026-09-08-validation-reconciliation.md);
workflow presence alone is never a pass.

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
