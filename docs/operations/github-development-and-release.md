---
title: Repository development and release
status: Current
document-kind: guide
scope: Local repository policy and unresolved remote CI and release prerequisites
canonical-for: [repository-policy, ci-contradictions, release-prerequisites]
last-reviewed: 2026-09-24
related-documents: [source-checkpoint-and-recovery.md, local-build-and-validation.md, documentation-maintenance.md, ../audits/2026-09-19-runner-routing-weekend-benchmark.md]
---

# Repository development and release

## Current checkout and repository policy

The active source now has upstream-derived history and a local checkpoint branch.
Use [source checkpoint and recovery](source-checkpoint-and-recovery.md) for exact
identities, companion workspace scope and dirty-state inspection. No push or
publication was performed by the documentation rewrite itself. The subsequent
owner-authorized [GitHub milestone](../audits/2026-09-08-github-milestone.md) recorded
that `techrote/cybersand` was private at that historical checkpoint and published
both local histories. Current GitHub repository metadata inspected on 2026-09-24
reports the repository as **public**. Branch protection is not established; dated
CI outcomes are recorded in the
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
Moving a PR to ready-for-review is the final-validation transition. Native and
GDExtension each run a small `ready validation scope` job on that transition:
policy/docs-only changes stop there, while implementation/source changes continue
into the existing expensive matrix. This explicit scope gate is required because
GitHub may create `ready_for_review` workflow runs even when all changed files
match `paths-ignore`.

For behavior or runtime changes, record the exact-head Documentation/provenance
result and every applicable Native, GDExtension/Godot and scoped apparatus result
before merge. Do not use a skipped draft or policy-only scope result as behavior
evidence. Source-sensitive runtime provenance remains a hard gate: a changed
runtime input requires a source-matched rebuild and provenance update rather than
a hand-edited hash.

## Recovery closure checkpoint — 2026-09-24

The [final recovery audit](../audits/2026-09-24-cybersand-recovery-audit.md)
records REC-001 through REC-008, including the transient artifact 403 incident,
#65 reclamation/sanitizer/runtime recovery, #94/PR #105 reconstruction and the
REC-007 provider/cost guardrails. The stable pre-REC-008 baseline is
`0405cdfe35a855e8287215a71d1165e3107fd1d6`; its Documentation/provenance
push run `35751825085` passed.

The recovery programme does not authorize a return to historical provider routing.
Old provider/recovery branches are inventoried in the dated audit. They are not
active policy, and REC-008 deletes none of them.

## Main-branch protection: exact owner action

Remote inspection on 2026-09-24 reports `main.protected=false` and no repository
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


## Isolated Water inertial runtime publication

### Water and Brine publication ownership

The Water publisher owns its exact branch `codex/lcb005-water-inertial`, Water
request/schema, workflow, artifact prefix and concurrency group. The Brine
publisher retains its separate branch/profile/request and artifact namespace.
Water privately loads the 005/001 engine; it changes no shared imported profile
or runner state and never pushes the Brine branch. Source-matched runtimes must
come from the Water workflow's exact source and lease. The Water request is
committed as sequence2 at source `aa8af247` after reviewed native repairs; its
publication is complete. The first sequence1/source4b record remains historical.
This does not imply another request or an active Brine publication.

### Actual publication and remaining final-head gates

The later [main #249 refresh](../audits/2026-10-25-water-inertial-publication.md#main-flight-lease-refresh-and-native-binary-reuse--2026-10-25)
retains all76 native inputs and published artifacts. The existing
[GDScript-only reuse rule](local-build-and-validation.md#physical-usable-validation)
permits those libraries with fresh acceptance of the changed Flight scripts;
the original491 build/test ledger remains evidence only for source4b. Its two
Godot changes do not alone require sequence2 or a rewritten manifest. Fresh
final-head required gates remain necessary after incorporating accepted main.

**Current source-matched sequence2 on `codex/lcb005-water-inertial`:**
reviewed activity publication, contiguous storage and pool-constructor retirement
repairs receive request-only sourceaa8af247 and actual run40220697738. All six
jobs pass; each target OS passes15 strict processes/642 policy assertions and
the actual Water-IN proof. Runtime-only bot03cccd8f has sole parentaa8 and exactly
four pointer/manifest paths. Independent reviewd2da3ffd and Root acceptance6352fdaf
verify native76/build491 sourceaa8, all18 LFS objects, actual floor, source lease
and unchanged process deadlines. The [dated ledger](../audits/2026-10-25-water-inertial-publication.md#actual-sequence2-windowslinux-publication--2026-10-25)
preserves all failures, prior sequence1 and registration ambiguity. A later
publication-audit metadata overlay is separately disclosed; native input drift
must remain zero and current repository provenance must pass. Bot03 approval-held
follow-ups contain no jobs, and are not final-head greens. Full final ready-head
Documentation/provenance, Native, Godot/scoped apparatus and review remain
separate from this scoped publication; no further sequence or bypass follows
from that approval hold alone.

**Historical source-matched sequence1 on `codex/lcb005-water-inertial`:** the
separate Water profile privately loads005/001, retains import plus14 processes,
all deadlines and strict policy/Brine/pressure sections, and requires the actual
Water motion/whole-cell/coherence/refusal/CYPS proof. Artifact prefix remains
`lcb005-water-inertial-runtime`. The [dated publication/preparation ledger](../audits/2026-10-25-water-inertial-publication.md)
preserves the unarmed24a checkpoint, failed apparatus iterations and local-only
composite proof, then records actual source4b588279/run40166210470/botC9e52b52.
Both OSes pass15 processes/642 policy assertions and receive independent
artifact/source/LFS/floor review `b15ea7cb` with no actionable bounded finding.

The new Water request was added only after independent profile review and final
owner/source-freeze coordination. The older Brine request cannot arm it.
Admission binds exact schema/material/scope/sequence, source and branch before
build or append. Only the four runtime/manifest paths may be appended with a
single exact source parent and atomic Water-branch lease. No competing source/doc
push changed the lease before the four-path publication append; the resulting
commit contains only those four paths.
Parent #250 is now accepted on main atdc915f2b; its historical publications keep
their source identity. No new request sequence is part of this docs checkpoint.

Five bot-C9 PR follow-ups are approval-held before any jobs; approving them is
not a test green. A maintainer must approve applicable actual final-head runs.
The ready PR still requires full Documentation including runtime provenance,
Native/sanitizer/worker, Windows/Linux Godot and scoped49 gates plus final review.
Draft skips, scoped publication and old-head approvals cannot replace them.
Common-Water scientific, normal-host/Web/manual and #203 packaging remain separate.
