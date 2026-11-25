---
title: Ultima retrieval and immutable predecessor custody
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated retrieval implementation, independent comparison and compact evidence custody; no current execution authority
canonical-for: []
last-reviewed: 2026-11-25
related-documents: []
---

# Retrieval and predecessor custody

This packet records new Ultima work. Its results are distinct from the
[full predecessor evidence](https://github.com/techrote/cybersand/tree/20170bd6259498c3d2774ab274567febb043fc1d/docs/audits/2026-11-24-docs-renaissance),
which remains intact at immutable commit `20170bd6259498c3d2774ab274567febb043fc1d`.
The predecessor's reports, intermediate runs, unsuccessful attempts and complete
contexts have not been rewritten or removed from that lineage.

## Custody and checkout cost

The predecessor packet contains **697 files including its manifest**, totaling
**170,042,123 working-tree bytes**. There are 615 unique Git blobs totaling
132,220,277 bytes. A fresh pack of all objects reachable from the predecessor
but not accepted main measured **12,928,232 bytes**; Git already compresses the
repeated evidence substantially. This is a reproducible transfer estimate, not a
GitHub storage bill or complete clone size.

The compact main-based successor retains all **82 byte-preserved originals**,
`assets-b.json`, and `closure/preservation-manifest.json`: **84 files / 2,122,985
bytes**. The other **613 files / 167,919,138 bytes** remain available through the
immutable predecessor. Removing these from a child of #774 would not remove
historical Git objects; the compact branch instead starts at accepted main and
carries the reviewed current docs/tooling plus corrections. The full predecessor
branch remains untouched. This improves ordinary checkout/review burden, not
historical repository storage already retained by GitHub.

[The custody manifest](predecessor-custody.json) maps every predecessor file to
its Git blob, SHA-256, exact size, classification, disposition, immutable URL and
reason. [Measurements](evidence-measurement.json) record the observed costs.
The new audit's own small manifests and implementation are additional bytes and
must be counted separately in the integrated delivery measurement.

Verify immutable source data, all retained copies and all 82 originals against
accepted main:

```sh
python tools/docs/evidence_custody.py --verify --compact
```

The Git objects must be available locally. In a fresh checkout, fetch the
preserved predecessor branch without checking it out or running its content:

```sh
git fetch origin docs/docs-renaissance-001
```

Reconstruct one omitted file into a new disposable output path:

```sh
python tools/docs/evidence_custody.py --extract docs/audits/2026-11-24-docs-renaissance/closure/FINAL-REPORT.md --output /tmp/predecessor-final-report.md
```

The tool verifies bytes before writing and refuses to overwrite an existing
output. It performs no network request, deletion, Git rewrite or automatic
checkout. Remote accessibility is a separately recorded readback, not inferred
from local object availability.

## Reproduce the unchanged lexical baselines

The original evaluator and five fixtures remain unchanged. The predecessor's
projection runner can be recovered exactly without keeping its bulky outputs in
the current tree:

```sh
git show 20170bd6259498c3d2774ab274567febb043fc1d:docs/audits/2026-11-24-docs-renaissance/closure/retrieval/reproduce.py > /tmp/cybersand-reproduce-closure.py
python /tmp/cybersand-reproduce-closure.py --root . --output /tmp/cybersand-retrieval-reproduction --stage all
```

This reproduces accepted `00cdb02f`, original recovery `ddd7c88f`, and the current
working corpus. To reproduce delivered #774 itself after Ultima corrections,
run the same command against a detached disposable #774 worktree. The original
runner reports real contexts and missing-manifest comparisons. Those are lexical
retrieval measurements; canonical recall is not answer correctness.

## Independent execution and review records

| Record | What it establishes |
|---|---|
| [Historical reproduction](baseline-reproduction.json) | All 15 original source/suite combinations reproduced with unchanged expected records/scoring; compact per-query ranks and context identities retain failures as well as successes. |
| [Authority negative before](authority-negative-before.json) / [after](authority-negative-after.json) | Malformed metadata and current/historical selection controls, with original failure evidence. Later live-instance and cache destination challenges are also independently reviewed by A and lead. |
| [Cache destination negative](cache-path-negative-before.json) | Disposable reproduction of source clobber before the destination guard; final source includes refusal tests and independent reviewer checks. |
| [Consumer scope](consumer-scope.json) | Actual local adapter/index investigation and the absence of executed generative inference; this reference harness is not represented as a deployed RAG service. |
| [Semantic coverage](coverage-c.json) | C's 53 full-body reads: 46 current-corpus documents and seven navigation/explicit-history records, with individual source/authority review depth and limits. |
| [Operations checks](operations-validation.json) | Copied quick commands passed 20 tests; deterministic Stage3b planning produced 168 fixtures/6,488 planned runs. The scientific campaign was not executed by these checks. |
| [Persistence review](review-persistence-by-c.json) | C independently inspected A's mechanism and executed the Linux public-save/fault matrix, including actual old/new payload values. |
| [Capture review](review-capture-by-c.json) | Independent execution of six real Linux controller/CLI cases: replacement, buffered write refusal, permission refusal, retry and truthful acknowledgements. |
| [Physics provenance correction](physics-provenance.json) | Before/after actual Linux measurement exposed Windows DLL pointer attribution; the fix selects materialized platform libraries, checks pinned version and detects drift. Ten focused tests and five one-tick cases passed; no new physics acceptance is inferred. |
| [Original physics evidence](physics-provenance-originals.zip) | Digest-indexed original manifests, inputs, outputs and logs for that bounded reproduction and metadata capture. |
| [Cross-reviews](cross-review-c.json) | C's source-grounded challenges of A/B/lead changes, separating source inspection, executed tests and outstanding graphical/physical acceptance. |
| [Candidate route readback](candidate-route-readback.json) | Actual GitHub lifecycle/head/base readbacks for #778–781 and #783; reported feature qualification is attributed, not promoted into accepted main. |

The proposed retrieval method was frozen before the lead's sealed holdout was
exposed to its evaluator. C has not read that holdout. Integrated five-suite
comparisons and final actual-context reviews are published against the final
source checkpoint separately; these interim coverage receipts do not attach an
earlier score or GUI observation to a changed source.
