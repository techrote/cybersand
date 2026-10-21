---
title: GEN-004 hierarchical generation implementation and acceptance evidence
status: Current
document-kind: evidence
scope: Dated issue 191 source identities, semantic/raster controls, documentation checks and separately qualified runtime acceptance
canonical-for: [gen-004-hierarchical-generation-evidence]
last-reviewed: 2026-10-21
related-documents: [../systems/procedural-hierarchical-generation.md, ../systems/procedural-world-generation.md, ../systems/procedural-typed-spatial-fields.md, ../reference/validation-evidence.md, ../operations/local-build-and-validation.md]
---

# GEN-004 hierarchical generation — 2026-10-21

## Intake and evidence boundary

[Issue #191](https://github.com/techrote/cybersand/issues/191) owns GEN-004,
the second stage in the approved GEN-003–007 programme. Implementation starts
from main `ba19d3a2b2608ef0ffbe252b684561e45aeaa457`, tree
`e0bb20d9f10bae6729bd002fd0501c92bd02502a`, which merged the prerequisite
GEN-003 in [PR #195](https://github.com/techrote/cybersand/pull/195).

Intake inspected the repository guide, handover, roadmap, canonical generation
contracts, native interfaces, dependency pins and all eighteen materialized LFS
runtime entries. The active Git root is the source repository. Unrelated open
actor, scene, material and Water work retains its own scope.

The [hierarchical generation contract](../systems/procedural-hierarchical-generation.md)
first recorded canonical ownership and the semantic-to-raster boundary before
implementation. It owns current API semantics when source inspection is complete;
this dated audit owns executed controls and their limitations. No local check
substitutes for source-matched Linux/Windows runtime publication or exact-head
hosted acceptance.

## Documentation and retrieval baseline

Before adding the hierarchy contract to the current-answer corpus, the retained
frozen 32 questions returned **21 hit@1, 32 hit@5, MRR@5 0.7953**. The existing
89 supplementary questions returned **70 hit@1, 89 hit@5, MRR@5 0.8743**.
Both runs used the repository's unchanged heading-chunk/BM25 evaluator and a
95-document, 1,040-chunk corpus on Linux/Python. Commands:

```sh
python3 tools/docs/retrieval_eval.py --output /tmp/gen004-retrieval-baseline.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json --output /tmp/gen004-challenges-baseline.json
```

These measurements establish routing baselines, not answer correctness or a
claim about embedding-based retrieval. Existing question IDs and query wording
remain unchanged; new hierarchy questions are reported separately.

## Acceptance status at documentation preparation

The implementation is in progress. Native semantic/raster execution, adapter
execution, runtime publication and exact-head hosted gates have not yet been
recorded in this audit. Required skips, script errors or stale runtime manifests
will not be counted as passes. The implementation PR must record recoverable
source checkpoints and the final disposition before issue closure.

## Explicit scope limits

The planner builds a finite authored window of canonical regions. It does not
introduce a resident-world streaming manager, player-edit reconciliation or
unbounded neighbor discovery. Region plans and shared ports can be produced
without requesting the adjacent storage chunks. Structural routes are checked
against a declared geometric clearance profile; they do not establish trained
or scripted actor success, gravity-aware navigation or post-simulation stability.

Semantic depth projection remains GEN-005, the full authoring/quality editor
remains GEN-007, and persistent runtime streaming/reconciliation remains GEN-006.
