---
title: Repository development and release
status: Current
document-kind: guide
scope: Local repository policy and unresolved remote CI and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-09-22
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


## Current CI provider and draft gating

**Current configuration, 2026-09-22:** routine active workflows use literal
GitHub-hosted runner labels. The previous external-provider routing experiment is
historical evidence only; it is not current policy. The retained
[weekend runner benchmark](../audits/2026-09-19-runner-routing-weekend-benchmark.md)
must not be read as authorization to restore its provider configuration.

[check_ci_provider_policy.py](../../tools/ci/check_ci_provider_policy.py) enforces
the active configuration boundary. It rejects:

- `.circleci/config.yml`;
- Avrea, Sengi or CircleCI routing tokens in active GitHub workflows;
- `*_RUNNER` variable indirection;
- any `runs-on` value that is not a literal GitHub-hosted
  `ubuntu-*`, `windows-*` or `macos-*` label.

The Documentation/provenance workflow runs this cheap check and its focused unit
tests even while a PR is draft. Historical documents are deliberately outside the
checker's scan scope.

Draft PRs suppress the expensive Native, GDExtension/Godot and scoped Water jobs.
Moving a PR to ready-for-review is the final-validation transition. For behavior or
runtime changes, record the exact-head Documentation/provenance result and every
applicable Native, GDExtension/Godot and scoped apparatus result before merge.
Do not use a skipped draft run as final evidence. Source-sensitive runtime
provenance remains a hard gate: a changed runtime input requires a source-matched
rebuild and provenance update rather than a hand-edited hash.

## Main-branch protection: exact owner action

Remote inspection on 2026-09-22 reports `main.protected=false` and no repository
rulesets. The repository GitHub App does not have administration permission to
read or change the protection endpoint, so automation must not claim this control
was installed.

The repository owner should apply this exact minimal rule in **Settings → Rules →
Rulesets** (or the equivalent branch-protection UI):

1. Create an active branch ruleset targeting the default branch `main`.
2. Require changes to reach `main` through a pull request. A solo repository may
   use zero mandatory approving reviews; the purpose here is to prevent direct
   source pushes, not to invent a second human reviewer.
3. Block force pushes and branch deletion.
4. Require the universal check **`Documentation and provenance / consistency`**.
   It has no path filter and therefore does not deadlock workflow-only changes.
5. Do **not** globally require the Native, GDExtension or Issue49 job names yet.
   Native/GDExtension intentionally suppress workflow-only/draft work, while
   Issue49 is path-scoped; making those names unconditional required checks can
   leave unrelated PRs permanently pending.
6. For implementation/behavior PRs, the procedural final gate remains the
   exact-head Native `native` job, GDExtension `windows x86_64` plus aggregate
   `linux x86_64` job, and any applicable path-scoped apparatus workflow.
7. Keep only repository-owner/administrator emergency bypass. Any bypass is an
   incident/recovery action and must be recorded; it is not the normal merge path.
8. After saving the rule, verify the branch page reports `main` protected and
   that a direct non-PR push is rejected.

A future owner-approved CI migration may revise both this section and the
machine-checkable provider policy in one focused change. Merely editing a stale
branch or runner variable is not sufficient authority.

The multidimensional completion, active-implementation ownership and validation
premise controls are separately owned by the
[development-claims remediation programme](development-claims-remediation-programme.md);
this CI/provider rule does not duplicate that schema.

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
