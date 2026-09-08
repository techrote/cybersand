---
title: Source checkpoint and recovery
status: Current
document-kind: guide
scope: Actual local Git roots, preserved baseline, recovery boundaries and source-versus-artifact identity
canonical-for: [source-identity, local-checkpoints, recovery-coverage]
last-reviewed: 2026-09-08
related-documents: [local-build-and-validation.md, ../reference/validation-evidence.md]
---

# Source checkpoint and recovery

## Which version is the working source?

**Current:** the active source is a real Git checkout. On 2026-09-08, upstream
`web-demo-m11` was read and its history recovered from
`https://github.com/techrote/cybersand.git`. Its tip matched the acquired base
`e2892c54d4bd91aac60971e81c748bd49fbe2adb`. Git metadata was attached without
checking files out over the working source.

All existing local source changes and the first documentation audit were then
committed as **`126175cfc4dd1fb8659212f62b9b517bac54d8c2`**, the pre-rewrite
checkpoint on `codex/rag-docs-foundation`. This commit descends from the original
upstream history. Later documentation
commits are identified by the checkout's current HEAD.

This checkpoint secures Git history and locally materialized LFS runtime bytes;
ignored tools and generated builds need separate recovery inputs. The owner
confirmed a USB backup, which was not inspected. A separate local capture was
restore/hash-tested for 740 files; neither that capture nor a Git commit establishes
all-platform recovery while required LFS payloads remain unresolved.

| Location | Version-control scope |
|---|---|
| `C:/kybersand/source` | Upstream-derived code, assets, runtime-library LFS pointers, tests, RAG documentation and source tooling |
| `C:/kybersand` | Separate local workspace repository for top-level guides and development wrappers; ignores `source/` and `.local/`; initial commit `b179dbb361681c3575b07b9d6b1769cc168747b1` |
| `C:/kybersand/SOURCE-CHECKPOINT.json` | Connects the workspace wrapper record to the source checkpoint |
| `C:/cybersand` | Functional deliverables; not the development repository |
| `C:/Godot47` | Local Godot 4.7 installation; outside both repositories |

Use `git -C source ...` from the workspace when you mean source history.
Both repositories now use the private `techrote/cybersand` GitHub repository:
source history is integrated into `main` (the original documentation branch was
merged through PR #5), and the independent
workspace history on `codex/workspace-docs`. The original rewrite made no remote
changes; the owner subsequently authorized this publication. The
[GitHub milestone record](../audits/2026-09-08-github-milestone.md) defines the
paired checkpoint tags, reconstruction procedure and remaining correctness issues.

## Which earlier identity statements are historical?

The [first documentation audit](../audits/2026-09-08-documentation-audit.md)
correctly found no source Git checkout at its intake. That record remains
unchanged; the checkpoint above supersedes its *current-state applicability*.
`SOURCE-PROVENANCE.json` identifies original acquired blobs, not current HEAD.
M11 `05ea45f...` and [BUILD_ID](../BUILD_ID.md) identify an older audited milestone.
Web `build-info.json` records the acquisition base and a generic declaration
that local setup changes exist. It contains no actual local-change hash manifest
and does not prove the export contains today's source or documentation commit.

## What is secured, and what is not established?

The owner confirmed a USB backup and instructed the agent not to inspect it.
Treat that as user-confirmed off-device coverage, not agent-tested USB recovery.
A local pre-rewrite capture verified 740 archived files against their restored
hashes. It includes working source,
materialized runtime libraries, workspace helpers and retained evidence;
generated builds/imports and `.local` toolchains are excluded.

The Git checkpoint and `git fsck --full` cover source history. Required Windows
runtime bytes were stored through Git LFS. Finalisation materialized and verified
all 18 required runtime payloads, resolving the earlier fourteen missing objects.
Git/LFS integrity does not itself prove platform runtime or full toolchain recovery.

Toolchains, export templates and machine-local configuration are separate
recovery inputs. Restore the exact pinned inputs described by
[local build and validation](local-build-and-validation.md). A Git bundle alone
does not include LFS objects or ignored tools.

## How should the next checkpoint be verified?

From the workspace:

```text
git -C source status --short --branch
git -C source rev-parse HEAD
git -C source log -1 --format=fuller
git -C source lfs ls-files
git -C source fsck --full
git status --short --branch
```

Record dirty paths, the source/working-file identity and tested runtime hashes.
Commit task changes locally after appropriate checks. Preserve unrelated edits;
never replace a dirty tree with an old archive to make a checksum pass. For an
actual recovery exercise, restore into a separate directory, materialize the
required LFS payloads, compare a manifest, and run tests against that restored
project. The [validation ledger](../reference/validation-evidence.md) distinguishes
existing evidence from newly executed recovery tests.

## Local issues #1/#2 implementation branch

The coordinated investigation started from clean source `bfac0bc` and workspace
`6a58311` on 2026-09-08, then created source branch `codex/issues-1-2`.
[Issue #1 evidence](../audits/2026-09-08-issue-1-failed-ticks.md) identifies source
deltas, commands and rebuilt artifacts. At that implementation checkpoint there
was no push authorization. The owner subsequently authorized finalisation:
[PR #6](https://github.com/techrote/cybersand/pull/6) publishes these commits and
the validated Windows LFS runtime with source-input provenance. See the
[publication reconciliation](../audits/2026-09-08-validation-reconciliation.md)
for later validation and the companion workspace checkpoint record for final tags.

Local issue #1 commit `0778845` plus browser fixture correction `061ad23` precede
the issue #2 implementation. Its [combined evidence](../audits/2026-09-08-issue-2-interest-regions.md)
records fingerprints and final acceptance. Read actual HEAD/status rather than
assuming this dated text is the latest branch state.
