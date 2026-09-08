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
The workspace repository has no remote. No push or publication was performed.

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
runtime bytes were stored locally through Git LFS. Fourteen other-platform
runtime files remain unresolved pointers. Do not call Linux or all-platform
restoration complete merely because Git objects are healthy.

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
