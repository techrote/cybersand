---
title: MAT-003 authorized Windows correctness attempt — incomplete
status: Current
document-kind: audit
scope: Exact authorized152-case attempt stopped on second process; retained raw failure and independent verification; no timing
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [2026-10-23-mat003-windows-execution-admission.md, 2026-10-23-mat003-warning-fix-build.md]
---

# Authorized attempt and registered stop

Owner explicitly authorized registration SHA-256 `6d5011004ad4fbde2b26348db44483cb4fc4942ad6b71d8caf18347ce5ae09b0`. The declared two-field derivation produced execution authority SHA-256 `3abc186278c27277b8b69f185237e9415583c7f9e9e4720add494a1130231dee`: execution boolean true and exact human authorization reference; all other fields identical. Prechecks confirmed exact source/tool/platform/monitor/binary/generated/build identities, no prior attempt, and more than36GiB free capacity. An exclusive attempt marker was written before execution. Source remains6e85fe6; no source correction, retry or warning suppression occurred.

The registered collector attempted storage-000 then small-001, sequentially. Storage exited0. Small World exited1 with34bytes stderr, `maximum chunk capacity exhausted`, and no watchdog stop. It retained partial checkpoints, operations, tick/work/ledger receipts and transitions. The collector stopped immediately, wrote status incomplete and a complete raw inventory, and did not launch the remaining150 processes. One completed process is not a completed152-case matrix or correctness acceptance. Build artifacts remain admitted as build artifacts; this failure does not retrospectively erase their source-bound admission.

The user's timing question is a separate prospective decision. This correctness registration explicitly excludes tick timing and uses instrumented binaries plus semantic checks. Its watchdog/resource durations cannot be promoted into performance evidence. New formal timing needs its own frozen workload/order/statistics, qualified observer-off binaries, independent admission and explicit execution authority. The correctness failure must be dispositioned first; no timing was started or inferred from this authorization.

Independent raw readback, exact failure extent and durable archive identities are recorded below. All prior failed/preflight/build archives remain unchanged. R16-T1 stays conditional, production/accepted campaign evidence unchanged and PR211/221 draft. Linux remains outside this Windows attempt. Publication is documentation-only with [skip ci].

## Independent failure verification and retention

Independent reviewer refused full correctness qualification. It checked all785 inventory entries/786 retained files, unchanged prior751-file build inventory and all32 binary seals, exact two-field authority derivation and the first two ordered case directories. It independently decoded all65536 K64-E8 normal storage operations with exact schedule, continuity and bit oracle:38532 accepted operations, meaningful copy/swap/clear/replacement and accepted one-hot coverage16/16/8/8/16. This is scoped partial storage evidence, not acceptance of the matrix or other arms.

Small-001 retained293 completed tick receipts; the next attempted tick294 failed under the four-resident-chunk capacity guard. Checkpoints through257 and all emitted receipts/transitions remain retained. The exact failed coordinate is not recorded, so none is asserted. No initial-setup failure, physics defect or intrinsic carrier penalty is inferred. The frozen reader ran once with pinned Python and registered external output:15 negative rejection fixtures plus decoder cross-check passed, then the reader refused incomplete/changed campaign. No verifier rerun or data repair occurred. The external independent review JSON SHA-256 is22ee04b3b9a4e503cc0f5a8c71639b5096b2263cf9b318b5fcc728c2aa618b06.

The [compact summary](mat003-correctness-2026-10-23/windows-correctness-attempt-summary.json) retains result/inventory/authority/review seals and the complete durable ZIP path/length/hash. The ZIP contains every retained source/binary/build/case artifact, execution controls, frozen-reader negative fixtures, outputs and independent review. Packaging validates each entry hash and CRC; raw binaries/logs stay outside Git. Earlier preflight, refused build and admitted build ZIPs remain unchanged.

Documentation/current-repository/historical M11/diff checks passed; frozen32 retrieval remains21 rank1/32 top5/MRR0.7937 and supplementary MATSCHEMA10 ranks1. These maintenance checks are not runtime acceptance. New question preserves all prior128 objects/frozen32; prior lexical C09 limitation remains. Next gate is a separately reviewed capacity/fixture disposition and fresh source/registration/admission/authority if a replacement is proposed; this failed attempt must never be silently resumed. No correction or new campaign is authorized by this audit.
