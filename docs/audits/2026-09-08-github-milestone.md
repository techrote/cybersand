---
title: GitHub documentation correctness milestone
status: Current
document-kind: evidence
scope: Publication definition and reconstruction of the audited documentation baseline; not blanket simulation or release acceptance
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [2026-09-08-structural-documentation-audit.md, 2026-09-08-retrieval-evaluation.md, ../operations/source-checkpoint-and-recovery.md, ../reference/status-and-roadmap.md]
---

# GitHub documentation correctness milestone

The owner authorized publication after the local documentation audit. The
destination `techrote/cybersand` was verified private with push access. Source
and companion workspace histories are published on separate branches of that
repository; the existing `main` and `web-demo-m11` branches are preserved.

## What this checkpoint marks

- Existing implementation secured in upstream-derived history at `126175c`.
- Structural rewrite and complete dated evaluation retained at `38f0ce4`.
- Forty-seven canonical documents with explicit scope/status/evidence and
  unique ownership; historical records preserved separately.
- The frozen lexical development set improved from 27/32 to 32/32 canonical
  retrieval at five and from 19/32 to 32/32 sufficient context. The
  [evaluation report](2026-09-08-retrieval-evaluation.md) owns the original
  corpus hashes and model-review limitations; it is not an embedding or held-out test.
- Publication bookkeeping updates only source identity/navigation and workspace
  guidance. The paired tags below include that follow-up; original audit/evaluation
  records remain unchanged. No solver, dependency or CI-workflow fixes are included.

This is a **documentation correctness baseline**, not a stable game release or
a claim that all physics is correct. Historical M11 consistency retains seven
hash mismatches. Failed ticks and interest re-entry have reproduced defects;
complete replay, generalized body physics and broader platform acceptance remain open.

Publication checks are recorded in [the follow-up evidence](2026-09-08-github-milestone-checks.json):
47 documents/684 local links pass structural checks; retrieval remains 23/32 at
one and 32/32 at five (MRR 0.8385). Only Q01's top-five text/order changed after
the publication wording update; its required identity/recovery facts remain
present. The other 31 question contexts are unchanged from the reviewed evaluation.
All 18 LFS objects are available remotely, and the four locally materialized
Windows/Web payloads were downloaded and verified by size/SHA-256. Remote object
availability does not establish other-platform runtime behavior.

## Named recovery points

| Scope | Published branch | Annotated checkpoint tag |
|---|---|---|
| Source, runtime-library LFS pointers, tests and RAG docs | `codex/rag-docs-foundation` | `docs-correctness-2026-09-08` |
| Companion workspace guides, development wrappers and source pin | `codex/workspace-docs` | `workspace-docs-correctness-2026-09-08` |

The [GitHub prerelease](https://github.com/techrote/cybersand/releases/tag/docs-correctness-2026-09-08)
provides the shared entry point and exact commits. Verify remote tag targets;
the presence of this document alone is not proof of a completed push.
`SOURCE-CHECKPOINT.json` in the workspace records its paired source commit.
Git tags are named pointers, not enforced immutability: do not move these tags
to later work. Use a new dated checkpoint instead.

## Reconstruct the paired checkout

Use a new destination, leaving existing working files intact:

```text
git clone --branch workspace-docs-correctness-2026-09-08 https://github.com/techrote/cybersand.git kybersand-checkpoint
git clone --branch docs-correctness-2026-09-08 https://github.com/techrote/cybersand.git kybersand-checkpoint/source
git -C kybersand-checkpoint/source lfs pull
git -C kybersand-checkpoint/source rev-parse HEAD
```

Tag checkouts are detached; create a new branch before implementation. Compare
the source HEAD to the workspace's `SOURCE-CHECKPOINT.json`. GitHub's default
source archive is not the paired workspace or a toolchain package; normal Git
clone plus LFS is the supported reconstruction route. Configure the ignored local
tools using the workspace build guide and exact source pins. Downloaded tools,
generated exports and raw local test logs are outside this publication; curated
evidence and diagnostic source are tracked. The user-confirmed USB backup was
not inspected. Other-platform libraries remaining as local pointers do not prove
those platforms were runtime-tested.

## Open correctness work

- [F01: failed-tick recovery](https://github.com/techrote/cybersand/issues/1): choose
  safe stop/retry/transaction semantics and align desktop/Web handling.
- [F02: region re-entry](https://github.com/techrote/cybersand/issues/2): define and
  test wake/catch-up behavior for excluded sleeping cells.
- [F08: CI and provenance](https://github.com/techrote/cybersand/issues/3): align
  toolchain and actual runtime coverage, export identity and new documentation CI.

These issues remain open after the documentation milestone. Continue the
[foundational roadmap](../reference/status-and-roadmap.md) with bounded,
source-backed implementation checkpoints and synchronized documentation.
