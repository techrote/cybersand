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

The original evaluator and five frozen fixture payloads remain unchanged. The
original 32-question payload now has the explicit `retrieval-questions-frozen32.json`
path. Accepted main subsequently added a 33rd CI question to the ordinary fixture;
that accepted 33-question file is retained byte-exact and reported separately.
Its dated packet target is not promoted into current retrieval. A separately
reviewed current CI case supplies an additive comparison. The predecessor's
projection runner can be recovered exactly without keeping its bulky outputs in
the current tree:

```sh
git show 20170bd6259498c3d2774ab274567febb043fc1d:docs/audits/2026-11-24-docs-renaissance/closure/retrieval/reproduce.py > /tmp/cybersand-reproduce-closure.py
GIT_LFS_SKIP_SMUDGE=1 git worktree add --detach /tmp/cybersand-predecessor-20170 20170bd6259498c3d2774ab274567febb043fc1d
python /tmp/cybersand-reproduce-closure.py --root /tmp/cybersand-predecessor-20170 --output /tmp/cybersand-retrieval-reproduction --stage all
```

Use fresh output/worktree paths. This reproduces accepted `00cdb02f`, original
recovery `ddd7c88f`, and delivered #774 with the original fixtures and helpers.
The original
runner reports real contexts and missing-manifest comparisons. Those are lexical
retrieval measurements; canonical recall is not answer correctness.

On a source-matched Ultima checkout, the paired current-corpus comparison is:

```sh
python tools/docs/evaluate_knowledge.py --root . --output /tmp/cybersand-ultima-paired --contexts
```

The command selects the explicit frozen 32, challenge 164, additive 36,
owner-intent six and historical ten suites. It writes both original lexical and
reference-adapter contexts. [Analysis and chronology](retrieval-analysis.md)
separate original historical results, the rejected v1 regression, the general v2
correction and the qualified source checkpoints. Compressed derived reports are
ordinary gzip JSON; [the record manifest](retrieval-record-manifest.json) binds
stored and expanded digests. Their full contexts reproduce from the recorded
source, corpus and helper identities.

## Independent execution and review records

| Record | What it establishes |
|---|---|
| [Historical reproduction](baseline-reproduction.json) | All 15 original source/suite combinations reproduced with unchanged expected records/scoring; compact per-query ranks and context identities retain failures as well as successes. |
| [Authority negative before](authority-negative-before.json) / [after](authority-negative-after.json) | Malformed metadata and current/historical selection controls, with original failure evidence. Later live-instance and cache destination challenges are also independently reviewed by A and lead. |
| [Cache destination negative](cache-path-negative-before.json) | Disposable reproduction of source clobber before the destination guard; final source includes refusal tests and independent reviewer checks. |
| [Consumer scope](consumer-scope.json) | Actual local adapter/index investigation and the absence of executed generative inference; this reference harness is not represented as a deployed RAG service. |
| [Semantic coverage](coverage-c.json) | C's 53 full-body reads: 46 current-corpus documents and seven navigation/explicit-history records, with individual source/authority review depth and limits. |
| [Accepted-main coverage additions](coverage-c-new-main.json) | Five further full reads after main advanced: two current CI runbooks, the dated CI packet, explicit owner guide and Goblin research/evidence packet. C's total is 58 full-body records, including 48 canonical current documents. |
| [Operations checks](operations-validation.json) | Copied quick commands passed 20 tests; deterministic Stage3b planning produced 168 fixtures/6,488 planned runs. The scientific campaign was not executed by these checks. |
| [Persistence review](review-persistence-by-c.json) | C independently inspected A's mechanism and executed the Linux public-save/fault matrix, including actual old/new payload values. |
| [Capture review](review-capture-by-c.json) | Independent execution of six real Linux controller/CLI cases: replacement, buffered write refusal, permission refusal, retry and truthful acknowledgements. |
| [Profile review](review-profile-by-c.json) | Independent source review and 16 real Linux public-caller cases across Worldgen, Material Lab, Transport and Water profile saves. |
| [Art storage review](review-art-storage-by-c.json) | Six independent actual Linux storage cases and 278 focused checks; export, new segment and append acknowledgements remain distinct. |
| [Storage originals](storage-cross-review-originals.zip) | Digest-indexed original C reports and logs from those disposable executions; no owner data or provider calls. |
| [Diagnostic storage review](review-diagnostic-storage-by-c.json) / [originals](diagnostic-cross-review-originals.zip) | Nine independent real Linux cases for three one-tick diagnostic CLIs; output storage and acknowledgements, not a new physics/controller campaign. |
| [Extended diagnostic/Goblin review](review-diagnostic-goblin-by-c.json) / [originals](diagnostic-goblin-cross-review-originals.zip) | Separate 12-case execution adds the guarded fixed Goblin writer and actual path/profile refusal controls. It is not a Goblin campaign or a replacement for the earlier nine-case receipt. |
| [Package guard review](review-package-by-c.json) | Synthetic contradictory profile receipt admitted before the review correction, refused afterward; 60 independent admission tests passed. |
| [Physics provenance correction](physics-provenance.json) | Before/after actual Linux measurement exposed Windows DLL pointer attribution; the fix selects materialized platform libraries, checks pinned version and detects drift. Ten focused tests and five one-tick cases passed; no new physics acceptance is inferred. |
| [Original physics evidence](physics-provenance-originals.zip) | Digest-indexed original manifests, inputs, outputs and logs for that bounded reproduction and metadata capture. |
| [Cross-reviews](cross-review-c.json) | C's source-grounded challenges of A/B/lead changes, separating source inspection, executed tests and outstanding graphical/physical acceptance. |
| [Candidate route readback](candidate-route-readback.json) | Actual GitHub lifecycle/head/base readbacks for #778–781 and #783; reported feature qualification is attributed, not promoted into accepted main. |
| [Accepted CI authority correction](accepted-ci-closure-correction.json) / [actual boundary probes](accepted-ci-closure-authority-probe.json) | The newly accepted dated packet's 12 current chunks were excluded; live-instance and persistent-cache controls removed stale authority while preserving its immutable original. |
| [Accepted Goblin boundary](goblin-authority-probe.json) / [structural check](goblin-authority-check-docs.json) | Optional #772 foundation distinguished from dated campaign/artifact evidence and unmerged #781. The existing exclusion remains consistent across manifest, fallback and direct ingestion. |
| [C findings](findings-c.json) | Stable source/authority/provenance findings and named independent reviews; additional runtime implementations remain attributed to their implementing lanes. |

The lead sealed its holdout before method tuning. C has never read the questions,
expected facts or results. The lead had already executed the v1 holdout when an
independently visible frozen-suite Q01 failure led to the disclosed v2 correction.
That later evaluation is therefore a second treatment, not a fresh completely
blind experiment. Original treatment outputs and judgments remain retained.
Final accepted-main integration and any subsequent source-matched evaluations
are separate checkpoints; these records never attach an earlier score or GUI
observation to a changed source.

## Closure recovery after the scratch reset

The earlier sections retain their original checkpoint scope. The environment
reset on 26 November removed unpublished scratch outputs. The
[recovery inventory](closure-recovery-custody.json) distinguishes published
historical/v1/v2 records from missing final e487 context/comparison receipts.
The original held-out payload is unavailable: its retained seal and chronology
cannot reproduce that evaluation. No replacement is represented as the original.
The unpublished comparison-checker experiment was never shipped and is not a
validation dependency of the delivered retriever.

The fresh closure pass reconciled accepted main `67c1413a` without changing the
frozen method, original evaluator or fixtures. [Authority and custody review](closure-main-authority-review.json)
records the 155-document corpus, four explicit AMBIENT evidence routes, two
historical acquisition notes, six verified remote original identities, and
69 passing isolation/selection/cache tests. The original six records were
already excluded by the v4 selector; this correction makes metadata and
reader routes consistent, rather than claiming a newly reproduced answer leak.

[Acquisition review](closure-lfs-independent-review.json) records 37 independent
local tests of the reconciled source-bound LFS and runtime-transport helpers.
[Launcher admission review](closure-launcher-independent-review.json) records
nine local controls and review of the shipped batch invocation. Windows batch
and graphics execution still require their actual hosted gate; neither receipt
claims physical owner acceptance or recovery of the live LFS service.

[Current-main causal admission review](closure-causal-v4-independent-review.json)
retains 21 independent controls of the new v4 registration. Its 13 source paths
and causal fixture match accepted main; both older registrations remain pinned.
The registration still declares the six planned cases unexecuted and does not
claim runtime/gameplay qualification. [Product authority review](closure-product-authority-review.json)
binds C's independent review of the AMBIENT current-status and evaluator routes.

[Final workflow wiring review](closure-workflow-scope-review.json) records the
literal 18-object acquisition and actual Windows launcher gate, with hosted
execution still pending at review. [TempToPC source readback](closure-temptopc-host-boundary.json)
inspects the reusable infrastructure instructions without creating a machine or
accessing credentials; it does not establish an available connected owner host.
