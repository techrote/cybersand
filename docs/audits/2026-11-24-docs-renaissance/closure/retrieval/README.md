---
title: Closure retrieval evidence index
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Navigation for newly produced retrieval and independent evidence qualification
last-reviewed: 2026-11-25
---

# Retrieval evidence index

Start with the [Specialist C handover](specialist-c-handover.md). This directory
contains fresh closure work; original recovered receipts remain in the parent
audit's `retrieval/` directory and are never relabelled new executions.

| Entry | Purpose |
|---|---|
| [Final candidate execution receipts](qualified-v2/candidate/execution-receipts.json) | Actual final projection commands, statuses and scope. |
| [Per-query comparison](rank-comparison.json) | Every baseline/recovery/final rank and exact fixture/report identity. |
| [Recovered-result reproduction](recovered-result-reproduction.json) | Ten exact original result comparisons, including full saved contexts. |
| [All36 independent answer audit](answer-applicability-summary.json) | 31 sufficient, five partial; all180 passage identities checked. |
| [A answers](answer-a-review.md), [B answers](answer-b-review.md), [lead answers](answer-lead-review.json) | Complete bounded answers, omitted facts and source/scope reasoning. |
| [Focused regression/history review](regression-context-review-c.json) | Eight actual-context cases, including primary-owner misses and historical abstention. |
| [Manifest/fallback equivalence](qualified-v2/candidate/manifest-fallback-comparison.json) | Identical151-document current corpus and rankings across four suites. |
| [Direct ingestion](qualified-v2/candidate/direct-ingestion.json) | Current151, excluded31 and explicit historical13 document results. |
| [Negative controls before correction](negative-controls-before.json) | Genuine reproduced authority/metadata defects. |
| [Focused checks after correction](focused-validation.json) | Tests and recorded helper input hashes. |
| [Independent evidence review](review-evidence-methodology.json) | Original389, preserved82, inventory547, claims176 and source/review identity checks. |
| [Independent source checkpoint binding](review-source-custody-by-c.json) | Git input map plus final corpus/helper byte binding. |
| [Independent hosted equivalence](review-hosted-equivalence-by-c.json) | All five final hosted reports and context files match the qualified local inputs and results. |

## Raw final reports and contexts

| Fixture | Machine report | Actual retrieved text |
|---|---|---|
| Frozen32 | [JSON](qualified-v2/candidate/frozen.json) | [Contexts](qualified-v2/candidate/frozen.contexts.md) |
| Challenge164 | [JSON](qualified-v2/candidate/challenges.json) | [Contexts](qualified-v2/candidate/challenges.contexts.md) |
| Additive36 | [JSON](qualified-v2/candidate/renaissance.json) | [Contexts](qualified-v2/candidate/renaissance.contexts.md) |
| Owner6 | [JSON](qualified-v2/candidate/owner-intent.json) | [Contexts](qualified-v2/candidate/owner-intent.contexts.md) |
| Historical10 | [JSON](qualified-v2/candidate/historical.json) | [Contexts](qualified-v2/candidate/historical.contexts.md) |

`baseline/` and `recovery/` are exact-source independent reproductions.
`candidate/`, `final/candidate/` and `qualified/candidate/` are retained intermediate closure projections,
including contexts that exposed defects. Despite its earlier directory name,
`final/candidate/` and `qualified/candidate/` are **superseded** by `qualified-v2/candidate/`.
The `answer-*-delivered-input.json` packets are the final reviewer inputs; their
delta records identify changed passages without transferring quality from scores.

The [projection runner](reproduce.py), [answer integrator](integrate-answer-reviews.py.txt)
and [independent custody checker](review-evidence-methodology.py.txt) provide
reproducible machine verification. The human source/applicability judgments remain
explicit specialist reviews, not outputs inferred by those scripts.
