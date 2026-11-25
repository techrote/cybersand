---
title: Source checkpoint and recovery
status: Current
document-kind: guide
scope: Actual checkout identity, recoverable source and runtime custody; historical workspace locations are evidence only
canonical-for: [source-identity, local-checkpoints, recovery-coverage]
last-reviewed: 2026-11-24
related-documents: [local-build-and-validation.md, github-development-and-release.md, current-and-historical-validation.md, ../reference/validation-evidence.md]
---

# Source checkpoint and recovery

The working source is the Git checkout you actually inspect. Record its root,
HEAD/tree, branch and local changes before changing it. This repository is
`techrote/cybersand`; old companion-workspace paths and old candidate branches do
not identify today's working copy.

## Which version is the working source?

Run these from the intended checkout:

```bash
git rev-parse --show-toplevel
git status --short --branch
git rev-parse HEAD 'HEAD^{tree}'
git log -1 --format=fuller
git lfs ls-files
```

Resolve `main` from the actual upstream when current accepted source is needed.
Record the exact fetched commit; a branch name can move. Inspect remote URLs
locally without publishing embedded credentials. A PR head, GitHub synthetic merge
ref, accepted merge commit and native build source are distinct identities.
If testing a candidate, name the candidate's source and any local delta explicitly.

The historical companion workspace had a nested `source/` checkout and its own
independent Git history. In that layout `git -C source ...` addresses source and
plain `git ...` addresses the wrapper repository. A fresh clone of CyberSand
already has the source at its root; it does not need that old directory layout or
the companion's `dev.cmd`. Use the source repository's
[desktop launcher](../../launch-desktop.cmd) and [build guide](local-build-and-validation.md).

## Source, runtime and package custody

| Identity | Record | What it does not establish |
|---|---|---|
| Source | Commit, tree, branch, dirty paths and relevant file hashes | That a retained binary was built from these inputs. |
| Native runtime | Artifact SHA-256/size, platform, build source and `source_inputs` in the selected provenance manifest | That current GDScript/UI or every platform was executed. |
| LFS object | Committed pointer OID/size and materialized bytes | A pointer is not an executable; materialization is not runtime validation. |
| Dependency | Exact Godot, godot-cpp, Rapier and toolchain locks | That an arbitrary nearby version is interchangeable. |
| Test run | Executed source/local delta, command, fixture, artifact, platform, result and retained evidence | A pass for another source or for a skipped case. |
| Evaluator | Package hash, full source/runtime identity and tested shipped launcher | Owner GPU playfeel or a public release license. |

A runtime built at an earlier commit can remain valid after documentation changes
when its recorded inputs remain exact. Do not rewrite its build-source identity.
Native changes require the applicable source-matched build/publication path. Keep
test-only overlays and publication-only commits distinct from the source actually
compiled or executed. [Current provenance checks](current-and-historical-validation.md)
and the [release guide](github-development-and-release.md) define the gates.

## What a checkpoint preserves

A Git commit preserves tracked source and LFS pointers. A Git bundle preserves
Git objects, not LFS payloads, ignored toolchains, exports or owner saves. LFS
payloads must remain recoverable separately. Runtime/dependency locks and notices
must accompany legitimate redistribution or reconstruction.

The original September recovery recorded a user-confirmed USB backup and a
separately hash-tested local capture of 740 files. The USB was not inspected, and
the owner instructed that it not be searched. Those are dated facts, not proof
that the current checkout, current LFS objects or current toolchains are backed
up today. The [original recovery record](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/source-checkpoint-and-recovery.md#what-is-secured-and-what-is-not-established)
preserves its exact scope.

Do not commit generated imports beyond the repository's three portable bootstrap
files, native build output, toolchains, caches, archives, raw logs, credentials or
machine-local configuration. Follow [AGENTS.md](../../AGENTS.md) and the active
task's allowed evidence/artifact paths. Existing owner data is not disposable
test material.

## How should the next checkpoint be verified?

Preserve unrelated edits and make the task's own changes reviewable. Record the
actual source/local delta, selected runtime hashes and the feasible validation
results. Run `git diff --check` and inspect the intended write set before commit.
Do not replace a dirty working tree with an old archive to make hashes agree.

For an authorized recovery exercise, restore into a separate directory, materialize
the required LFS payloads, authenticate the input manifest and test the restored
project. `git fsck --full` checks Git object integrity; it is not an LFS
materialization, complete toolchain or platform execution test. A shallow clone
may need the relevant older Git objects before historical checks can run.

For publication, use the established branch/source lease and exact permitted
runtime/provenance write set. A newer branch tip invalidates an old lease; inspect
and reconcile it instead of force-updating another writer's work. A local checkpoint
is not owner merge approval. See
[publication and review](github-development-and-release.md).

## Which earlier identity statements are historical?

`SOURCE-PROVENANCE.json`, M11 `05ea45f...`, [BUILD_ID](../BUILD_ID.md) and earlier
Web build-info records name their own acquisition or release checkpoints. They do
not identify today's source by implication. Historical hashes remain immutable;
current implementation drift belongs in a separate current validation result.

The complete previous page, including original workspace/source histories and
October LCB publication/recovery sequences, is preserved at
[the frozen accepted-source revision](https://github.com/techrote/cybersand/blob/00cdb02f103265b6dc5224c68283e9a0c8cb449f/docs/operations/source-checkpoint-and-recovery.md)
and in the [preservation packet](../audits/2026-11-24-docs-renaissance/README.md).
Read those branch instructions only to recover their original evidence. The
[current handover](cybersand-codex-development-handover.md) and
[state register](../reference/status-and-roadmap.md) route current work.
