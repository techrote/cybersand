---
title: CyberSand documentation
status: Current
document-kind: navigation
scope: Entry routes and authority rules for the focused documentation hierarchy
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [reference/retrieval-index.md, reference/status-and-roadmap.md, operations/documentation-maintenance.md]
---

# CyberSand documentation

## Choose a reading route

| Need | Start here |
|---|---|
| Begin development | [Handover](operations/cybersand-codex-development-handover.md), [actual source identity](operations/source-checkpoint-and-recovery.md), [roadmap](reference/status-and-roadmap.md) |
| Understand the engine | [Architecture overview](architecture/overview.md), then its focused ownership/threading/coupling links |
| Answer one technical question | [Retrieval index](reference/retrieval-index.md) |
| Change a material | [Rule kernels](systems/materials-and-rule-kernels.md), [Water](systems/water-design.md), [material lab](MATERIAL_LAB.md) |
| Build or validate | [Build guide](operations/local-build-and-validation.md), [test selection](operations/testing-validation-and-replay.md), [dated evidence](reference/validation-evidence.md) |
| Understand intent | [Product priorities](reference/product-intent-and-priorities.md), [principles](architecture/principles-and-non-goals.md), [ADRs](decisions) |
| Maintain these docs | [Documentation and retrieval contract](operations/documentation-maintenance.md) |

## Authority and status

Executable source defines **Current** behavior. An **Approved** requirement may
still be partly implemented. **Planned** means future work; **Deferred** means
deliberately postponed; **Rejected** means intentionally declined. Frontmatter
`Approved design` is the compatibility alias for Approved. Label claims individually
when a page mixes implemented behavior and target design.

Runtime claims need dated source/artifact/platform evidence. Historical M11 hashes,
an acquisition base, a compiled library, a headless fixture, an HTTP checksum check
and a browser run prove different things. [Evidence](reference/validation-evidence.md)
and [source identity](operations/source-checkpoint-and-recovery.md) explain the limits.

## Hierarchy and retrieval

- `architecture/`: ownership, lifecycle, scheduler, determinism and coupling contracts.
- `systems/`: storage, activity, materials, Water and appearance behavior.
- `decisions/`: accepted choices, rationale, rejected alternatives and implementation gaps.
- `operations/`: building, testing, profiling, troubleshooting and checkpoint procedures.
- `reference/`: API/defaults/invariants, saves, status, evidence, glossary and owner intent.
- `research/`: attributed upstream behavior and adaptation scope.
- `audits/`: immutable dated results and explicitly superseded historical records.

Each canonical page declares its scope, status, review date and unique topic ownership.
The [corpus manifest](reference/retrieval-corpus.json) selects ordinary retrieval;
navigation and historical pages are explicitly excluded. Carry page metadata and
heading ancestry with each chunk. Link the canonical contract instead of copying
its detailed facts into multiple pages. Evaluate retrieval using the
[frozen questions](reference/retrieval-questions.json) and semantic sufficiency review.

## Historical routes

The [structural rewrite audit](audits/2026-09-08-structural-documentation-audit.md)
and [retrieval evaluation](audits/2026-09-08-retrieval-evaluation.md) record this
documentation checkpoint, its measured limits and recommended next work.
The local [issue #1 implementation evidence](audits/2026-09-08-issue-1-failed-ticks.md)
records the failed-tick policy and platform-scoped acceptance.
The subsequent [GitHub milestone](audits/2026-09-08-github-milestone.md) records
the paired source/workspace publication and open correctness follow-ups.

[M11 audit records](audits/m11/README.md), [BUILD_ID](BUILD_ID.md),
[first September documentation audit](audits/2026-09-08-documentation-audit.md),
and [pre-rewrite handover/checkpoint records](audits/pre-rag-rewrite-2026-09-08/README.md)
retain their original scope. Legacy milestone overview/status/performance files
remain historical routes, not current contract owners. Consult them explicitly for
a historical question; do not merge their claims into the current answer.

The [coordinated issue #2 acceptance](audits/2026-09-08-issue-2-interest-regions.md)
records pause/re-entry, independent causes and combined failure/recovery validation.
