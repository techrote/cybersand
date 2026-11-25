---
title: Independent native evidence reduction at source 2743
status: Planned
document-kind: audit
scope: Derived-index arithmetic review and separate original-cell/PNG verification
last-reviewed: 2026-11-25
---

# Independent native evidence reduction

This record concerns frozen source
`2743f89a0df6f6afcf7484e859c10790d521e74b`, tree
`56687bcaa8eb58fbdf1bbeb673d74a40dcc9b634`, and durable evidence commit
[`39a7a1fb72b9c694f442963ca6852499e2f56eee`](https://github.com/techrote/cybersand/commit/39a7a1fb72b9c694f442963ca6852499e2f56eee).
It does not qualify a later source automatically. Draft/HOLD remains in force.

## Completed derived-index review

The native specialist independently fetched the campaign summary, native scene
summary and derived receipt index from the immutable GitHub evidence commit.
A JavaScript reduction in the orchestration environment produced
**813 checks, zero failures**. The actual returned report is retained as
[metadata-review-stdout.json](metadata-review-stdout.json).
[metadata-review.mjs](metadata-review.mjs) preserves the reduction logic with a
Node filesystem input wrapper for replay:

~~~text
node metadata-review.mjs PATH_TO_FETCHED_EVIDENCE_DIRECTORY
~~~

The three inputs are `summary.json`, `creative-native-summary.json` and
`full-displayed-2743-receipt-review-index.json` from the evidence directory.
The script only reads them and writes its report to standard output.

The review reconciles all nine scene identities, 18 original receipt-file
identities, native backends/statuses, counters, source continuity, source
revision increments, stage boundaries, preview counts/hashes, fixed-proposal
ablation records and explicitly matched timing intervals.

| Observation | Derived-index result |
| --- | --- |
| Native scenes / separately approved stages | 9 / 25 |
| Actual changed cells in each arm | 184,396 |
| Checked cells in each arm | 188,617 |
| Staged / direct native chunks | 66 / 60 |
| Summed matched executor intervals | 9.100183 s staged / 7.657192 s direct |
| Broad staged wall intervals | 25.711573 s; includes verification/images |
| Whole native process | 97.817519 s |
| Largest recorded context build | 107.814 ms at 262,144 captured cells |
| Largest recorded preview poll | 16.456 ms |

The recorded host is Linux 6.18.57 x86_64, nine logical CPUs, with an empty
processor-name field. The engine is pinned Godot
`4.7.stable.official.5b4e0cb0f`; the original campaign retains executable/native/
Rapier digests. No processor model, physical GPU or owner-hardware performance
is inferred.

Fixed arm order and different native stage boundaries remain limitations.
These are observed execution costs; they are not a causal speed, retrieval,
genuine-model creativity or actor-traversal result.

**This first reduction uses a derived index. It does not independently read
the original cell arrays or PNG bytes.** The index retains every receipt field
except exact readback arrays, with their count and canonical JSON SHA-256.
Its file identities are checked against the original campaign, but its
canonical row hashes still require original-array verification.

## Narrow original-evidence verifier

[`tools/ci/verify_art_creative_native_evidence.py`](../../../../tools/ci/verify_art_creative_native_evidence.py)
is a separate standard-library, read-only verifier. It imports neither Art's
rasterizer nor the fixture generator and does not create a World or issue HTTP.
It can read the original directory or lossless archive without extracting it.

The full original archive is Git blob
`bc0d76c86d468514440ca70a36073f18de15d744`, 3,138,987 bytes, SHA-256
`18941756cc3073aa317ea7c99dc7986ead497488d0e949c978289ff1eb0f90a1`.
The verifier checks that compressed identity when supplied, original file
checksums, PNG chunk CRCs and bounded decoded material bytes, explicit int32
material-plane hashes, every exact cell before/after row, receipt source
continuity and counters, every staged after-plane, and the translated direct
control's final plane.

The optional review-index check uses exactly the producer's documented
encoding: `json.dumps(readback, separators=(',', ':'), ensure_ascii=False)`
encoded as UTF-8. It verifies that no other receipt field was altered.

~~~text
python tools/ci/verify_art_creative_native_evidence.py ORIGINAL_ARCHIVE.tar.gz --expected-source 2743f89a0df6f6afcf7484e859c10790d521e74b --archive-sha256 18941756cc3073aa317ea7c99dc7986ead497488d0e949c978289ff1eb0f90a1 --review-index full-displayed-2743-receipt-review-index.json
~~~

The specialist's executor is unavailable. The lead will execute this authored
script verbatim against the retained originals and preserve complete stdout and
script/input hashes. **At this documentation checkpoint that raw replay is
pending; no passing result is asserted.**

The native before/after PNGs are explicit material diagnostics. Rendered
Workbench screenshots are checksum-bound but never decoded into guessed
materials. Direct replay uses the fixture's declared matched translated
baseline and must reproduce the actual final native capture hash. These
remaining interpretation limits appear in the verifier report.
