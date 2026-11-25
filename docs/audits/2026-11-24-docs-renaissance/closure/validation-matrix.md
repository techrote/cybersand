---
title: Final documentation qualification matrix
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Observed checks bound to their actual source; no runtime acceptance transfer
last-reviewed: 2026-11-25
---

# Final qualification matrix

Qualified source: `700c89c451903fac07188196a2f94b5c8997cb53`. Accepted implementation: `00cdb02f103265b6dc5224c68283e9a0c8cb449f`.

All 4,090 qualification inputs are bound by [source custody](source-custody.json), digest `a7323f8d3cf700ed6f65f4d0dc21bb531b5bfd05dcd58ba246baa1f46d980286`. Each check below names its actual source and receipt. An executed evaluation with misses is shown as executed, rather than called perfect. The full [machine-readable matrix](validation-matrix.json) includes exact commands and SHA-256 identities.

| Check | Observed status | Scope and receipt |
| --- | --- | --- |
| ci-provider | PASS | Existing CI provider/routing policy. [validation/delivered-source/ci-provider.json](validation/delivered-source/ci-provider.json) |
| ci-scheduling | PASS | 10 scheduling-policy tests. [validation/delivered-source/ci-scheduling.json](validation/delivered-source/ci-scheduling.json) |
| documentation | PASS | 151 current documents;8 navigation pages;280 canonical topics;3,523 local links;491 anchors;0 errors/warnings. [validation/delivered-source/documentation.json](validation/delivered-source/documentation.json) |
| historical-selection | PASS | 16 historical-isolation tests. [validation/delivered-source/historical-selection.json](validation/delivered-source/historical-selection.json) |
| history-integrity | PASS | 274 scope/582 ledger/308 closed-reference/98 findings/74 protected historical items. [validation/delivered-source/history-integrity.json](validation/delivered-source/history-integrity.json) |
| m11 | PASS | 18 records/28 source hashes against original05ea45 historical revision. [validation/delivered-source/m11.json](validation/delivered-source/m11.json) |
| repository | PASS | Source/dependency/pointer consistency;18 unmaterialized LFS runtime objects,0 materialized. No runtime acceptance. [validation/delivered-source/repository.json](validation/delivered-source/repository.json) |
| selection | PASS | 15 current-selection/authority tests. [validation/delivered-source/selection.json](validation/delivered-source/selection.json) |
| retrieval-frozen | EXECUTED | 18 top1;32/32 top5;MRR0.7302. Ranking misses are not hidden as a PASS. [retrieval/qualified-v2/candidate/frozen.json](retrieval/qualified-v2/candidate/frozen.json) |
| retrieval-challenges | EXECUTED | 126 top1;161/164 top5;MRR0.8575. Ranking misses are not hidden as a PASS. [retrieval/qualified-v2/candidate/challenges.json](retrieval/qualified-v2/candidate/challenges.json) |
| retrieval-renaissance | EXECUTED | 27 top1;35/36 top5;MRR0.8426. Ranking misses are not hidden as a PASS. [retrieval/qualified-v2/candidate/renaissance.json](retrieval/qualified-v2/candidate/renaissance.json) |
| retrieval-owner-intent | EXECUTED | 1 top1;4/6 top5;MRR0.3389. Ranking misses are not hidden as a PASS. [retrieval/qualified-v2/candidate/owner-intent.json](retrieval/qualified-v2/candidate/owner-intent.json) |
| retrieval-historical | EXECUTED | 7 top1;10/10 top5;MRR0.8033. Ranking misses are not hidden as a PASS. [retrieval/qualified-v2/candidate/historical.json](retrieval/qualified-v2/candidate/historical.json) |
| preservation-manifest | PASS | 82/82 exact original Git blobs/SHA-256;0 failures. [preservation-manifest.json](preservation-manifest.json) |
| inbound-link-reconciliation | PASS | 2,003 current inbound routes;0 unresolved within declared508/514 Markdown scan;8 superseded references retained. [inbound-link-reconciliation.json](inbound-link-reconciliation.json) |
| manifest-fallback-comparison | PASS | All four current suites identical across manifest/fallback. [retrieval/qualified-v2/candidate/manifest-fallback-comparison.json](retrieval/qualified-v2/candidate/manifest-fallback-comparison.json) |
| direct-ingestion | PASS | 151 current docs;31 default-excluded files;13 explicit historical docs/331 per-chunk envelopes. [retrieval/qualified-v2/candidate/direct-ingestion.json](retrieval/qualified-v2/candidate/direct-ingestion.json) |
| source-custody | PASS | 4,090 qualification inputs;1,137 protected runtime/dependency/policy files;0 unexpected drift;exact source700. [source-custody.json](source-custody.json) |
| answer-applicability-summary | REVIEWED WITH LIMITS | All36 reviewed;31 sufficient/5 partial/0 wrong-context;180 actual contexts. [retrieval/answer-applicability-summary.json](retrieval/answer-applicability-summary.json) |
| final-source-identity | PASS | 176 recovered composite claims;207 final claim/document identity pairs;0 errors/pending. [technical/final-source-identity.json](technical/final-source-identity.json) |
| whitespace | SCOPED PASS / ORIGINAL-BYTE EXCEPTIONS | Current documents/tooling clean. Full evidence diff retains original trailing whitespace/EOF diagnostics. [validation/whitespace-disposition.json](validation/whitespace-disposition.json) |
| hosted-original-documentation | PASS | Original docs run45482710814; published-runtime provenance skipped. [hosted-original/documentation-job-readback.json](hosted-original/documentation-job-readback.json) |
| hosted-source366-documentation | PASS | Fresh docs run45515022255; focused/current-history suites and allfive evaluations executed; provenance skipped. [hosted-source366/documentation-job-readback.json](hosted-source366/documentation-job-readback.json) |
| hosted-delivered-documentation | PASS | Final-source documentation job; actual recorded steps govern scope. [hosted-delivered/documentation-job-readback.json](hosted-delivered/documentation-job-readback.json) |
| hosted-delivered-ancillary | FAILURES RETAINED | Three Linux downloadHTTP403 failures and inherited Windows source guard refusal; separately scoped Windows successes. [hosted-delivered/ancillary-readback.json](hosted-delivered/ancillary-readback.json) |
| fresh-browser-and-Godot-GUI | BLOCKED / NOT RUN | Both supported browser routes failed before page load; no fresh Godot graphical execution. [product/browser-fallback-attempt-by-lead.json](product/browser-fallback-attempt-by-lead.json) |
| physical-Windows-NVIDIA | NOT RUN | No physical acceptance inferred from hosted runs, static images, counters or FPS. |
| external-retrieval-model-integration | NOT RUN | No external embedding/cache/index/agent integration or blind model-answer benchmark. |
| fresh-native-runtime-rebuild | NOT RUN | No unrelated local rebuild for a documentation/retrieval candidate; source/dependencies unchanged. |

## Interpretation

The applicable documentation, historical containment and source-pointer checks passed within their stated scopes. Exact originals retain original whitespace. Runtime failure and skipped/not-run rows remain visible; no runtime authority, guard, dependency or engine source was changed to turn them green.

The delivered evidence commit is joined to this tested source through the final publication receipt and PR conversation. Full input-map equality, not merely a short commit label, is the transfer condition. Source700 and the containing evidence commit are deliberately distinct identities.
