---
title: MAT-003 correctness apparatus implementation review — held
status: Current
document-kind: audit
scope: Unexecuted partial apparatus source and independent review blockers; no qualification or timing acceptance
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../research/mat003-correctness-only-plan.md, 2026-10-23-mat003-mapping-oracle-review.md]
---

# Implementation and held review

Owner authorized isolated apparatus implementation against the reviewed eight-arm maps and independent oracle, with a stop before qualification execution or timing. Source intake is `1bbbec9580f9a3e9e6a6f9136503f873ede0f254` on the managed `codex/mat003-continuation` branch. The existing uncommitted storage files were retained and extended in `tools/experiments/mat003_correctness`. No accepted inputs, production source, dependencies, workflows or configuration changed; the preexisting WCLEAR registration status marker is untouched. Both PR211/221 remain draft. R16-T1 remains conditional and is not implemented.

Implemented source supplies the eight raw map contracts, canonical bytes, safe memcpy compact head, independent logical encode/decode/operation model, generated World-only adapter/overlay, partial friend exporter and real-tick driver, matrix description, storage stream and chained independent storage reader. These are **partial unexecuted implementation**, not a completed correctness apparatus or source-qualified build. The directory README explicitly inventories the gaps; `readback.completion` refuses completion unconditionally until full World readback is implemented. No collector-summary pass can bypass it.

## Independent source-review disposition: incomplete / held

Independent read-only review found that exact map offsets match the reviewed tables, but identified blocking omissions:

- Storage schedule lacks the required complete one-hot, ordered-pair, copy/swap/replacement and raw-unused-bit coverage; the independent oracle operation model is not a full semantic admission or World transition oracle.
- World fixtures do not yet exercise nonzero neutral payload/unused-lane transport, complete high-state/temperature/ledger transitions, or the256-operation refusal/lifecycle suite. A raw setter is not the complete checked external admission transaction.
- Endpoint export still depends on S1's normalized common snapshot and does not fully inventory/export/independently decode configuration and parallel scratch/continuation owners. Duplicating cell data in common and canonical streams needs reconciliation with reviewed output bounds. Discovery/transient owners are required null, not silently omitted.
- A sealed compiler/collector with resource and output enforcement, independent full-matrix readback and negative-verifier fixtures is not implemented. The152-case matrix alone cannot establish completion.

Early source defects were corrected without execution: the missing precision-storage include, bytewise-only compact head (now memcpy with endian fallback), resident extra checkpoints beyond B/P/Q/R (removed), arbitrary storage prestate acceptance (now per-slot replay chain), and unchecked suite/epoch selection. These local fixes do not resolve the larger blockers. The review is retained as a failed completion assessment, not independent apparatus admission.

No compile, import of apparatus modules, candidate binary, qualification process, campaign or timing was executed. File-writing helper scripts and documentation checks are maintenance operations only. No runtime result, sanitizer success or platform compatibility is claimed. The reviewed document contract remains authoritative and unchanged; implementation gaps do not relax it. Further implementation is still needed within the existing authorization; execution remains separately held.

## Documentation checkpoint

Change routing: the canonical plan/maps/oracle contract is unchanged. New isolated source has no production include/build routes; native ownership, scheduler behavior, Water semantics, defaults, GEN-006 and user controls are unaffected. This record retains the failed review and recovery checkpoint rather than declaring completion. The consolidated report links this disposition. Repository documentation/historical integrity and diff checks are maintenance verification, not apparatus execution; offline retrieval retains its separate lexical limitations. Commit uses the CI skip directive so publication does not start automatic qualification. Both PRs stay draft and no manual workflow is dispatched.
