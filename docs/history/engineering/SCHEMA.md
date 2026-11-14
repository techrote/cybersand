---
title: Engineering archaeology record schema
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated M1 capture; no current instructions or execution permission
last-reviewed: 2026-11-14
---

# Record schema and maintenance

## Maintained sources and generated views

Two JSON files contain the maintained facts: [coverage.json](coverage.json) for individual items and [findings.json](findings.json) for reusable conclusions. Four family analyses carry reasoning, all twelve #571 dimensions and important chronology. A finding is stored once and linked from affected items. Generated views present the same findings by purpose. The distinct owner decision record stays outside the archive.

The JSON format is deliberately small and human-readable. It is not a new workflow engine, approval bot or required replacement for all existing project ledgers. The archive has no background worker, scheduler or GitHub write integration.

```bash
python3 tools/docs/engineering_history.py validate
python3 tools/docs/engineering_history.py render
python3 tools/docs/engineering_history.py check
```

`render` rewrites only generated historical views. Use it after intentional record edits, then inspect the diff. `check` verifies maintained structure, source references, scope and generated-view consistency; it does not establish semantic truth. Normal documentation CI invokes this structural check when the archive exists.

## Individual coverage records

Each item is keyed by its GitHub number and includes source URL/type, intake state, body SHA-256, timestamps, PR head/base identities where available, primary family, related items, findings, depth, confidence, limitations and explicit protection. The source index and portable evidence bundle retain the full intake response. `base-branch-at-intake` means a source branch relationship; it is never automatically translated into semantic adoption or a mandatory dependency.

Four separate text fields record proposed fates:

- `ticket_fate`: whether the historical obligation may later be consolidated, retained, superseded or retired.
- `idea_fate`: current relevance and potential, independent of the ticket.
- `code_fate`: adopted successor, selective donor, partial/unqualified implementation, rebuild candidate or no code.
- `evidence_fate`: preserved positive/negative observations, tests, methods and missing originals.

All records have `retirement_state: not-authorised`. The `protected` flag highlights active or paused integration/custody. A false flag grants no permission to touch a record or branch. The M1 authorisation permits only the capture branch and Draft/HOLD PR.

`assessment_state` describes the investigation, not GitHub state. `transfer.state: captured-for-review` means that findings and dispositions have reached inspectable records. It is **not** a certification that every original artifact was recovered, every line was independently checked or retirement is safe. Original custody is separately itemised. Closed records use `indexed-only`; selected cited claims can be studied without falsely promoting the whole item to a completed assessment.

## Depth and evidence limits

| Depth | Meaning in this capture |
|---|---|
| D1 | Source metadata/body indexed; no individual whole-item assessment claimed. Used for the closed-reference universe. |
| D2 | Substantive body, discussion/review, dependencies, corrected chronology and bounded diff/lineage assessment. No exhaustive implementation-path audit. |
| D3 | D2 plus selective actual source/test/current-successor inspection or retained explicit M0 pilot trace sufficient for the stated claim. Not a security audit, full diff certification or execution. |
| D4 | Original recorded observations independently re-read and reduced. Only #221 S2A and #533 performance have this new original-data readback; neither is fresh candidate execution. |

Descriptive suffixes retain the precise work performed. Historical test results are attributed to the original producer/reviewer and exact source/workload/platform where known. Source existence, reported execution, qualification, integration and owner acceptance are different states. Missing original evidence stays missing. A workflow conclusion is not an experimental verdict.

## Typed findings and provenance

Finding types are `salvage`, `negative`, `doctrine` and `opportunity`. Each carries a claim, rationale, scope, source URLs and identities where material, linked items, validity and a transfer receipt. Doctrine uses **still valid / superseded / contradicted / partially valid / unverified**. `validity_detail` preserves the more precise scope; a primary tag must not erase it.

A source SHA is a provenance anchor, not automatically the executed binary SHA. Additional identities and source URLs preserve historical/current comparisons. Family prose states which source was inspected, tested, adopted or rejected. Where a compound claim spans different revisions, do not infer one universal qualification identity from its primary SHA.

Each transfer connects **source claim or asset → separate fate → capture destination → verification method → remaining limitation**. The archive is the M1 destination. Proposed future use remains a proposal. Original artifacts have separate byte counts, SHA-256, run/artifact identity, expiry-at-capture, actual capture status and recovery location in [the evidence manifest](evidence/manifest.json).

## Authority and later updates

Every historical container, item, finding, Markdown document and retrieved chunk is non-authoritative. Current owner intent is separately sourced to the direct conversation and its authorised assistant transcription; a comment written by an assistant is not falsely represented as an owner-authored GitHub approval. Present implementation does not become permanent architecture by being observed.

Freeze significant reviewed captures. Add dated deltas instead of silently rewriting historical outcomes. Before M2 synthesis or M3 retirement, refresh main, active branches, material evidence and owner intent. Later canonical issue text, retirement batches, merge and documentation reconciliation need their own gates. Reuse the existing item/finding keys and regenerate views; do not hand-maintain six competing registries.
