---
title: Documentation retrieval and authority assessment
status: Current
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated DOCS-RENAISSANCE-001 corpus, ranking and answer-applicability evidence; not ordinary current instructions
last-reviewed: 2026-11-24
---

# Retrieval and authority assessment

**Scope: final-frozen-corpus-2026-11-24.** The documentation programme repairs a demonstrated fallback-selection defect and source/authority contradictions. It separately measures corpus containment, ranked source selection and the applicability of actual retrieved passages. This is documentation qualification; the candidate remains Draft/HOLD.

## Reproducible baseline and method

The before corpus is accepted source `00cdb02f103265b6dc5224c68283e9a0c8cb449f`, evaluated with its original helper. The source was recovered through an immutable Git archive; committed runtime pointer bytes and image/source identities were checked before use. The exact companion dependency supplied the five original external source references. The large working snapshot was removed only after preserving outputs, contexts, helper bytes and hashes to relieve disk pressure. [The baseline receipt](retrieval/baseline-source-receipt.json) records that procedure.

The existing apparatus uses heading chunks, a 420-word body cap, no overlap and BM25 (`k1=1.2`, `b=0.75`) with top five results. It has no embeddings, stemming, query expansion or reranker. Existing frozen question files and expected destinations are unchanged. The new [36-question v1 set](../../reference/retrieval-questions-docs-renaissance-v1.json) adds current onboarding, authoring, material/solver, ownership, persistence, active-candidate and authority challenges. Expected missing future decisions require abstention. Every raw report retains questions, scored passages, document bytes/hashes, source paths and evaluator identity.

## Corpus inclusion and authority containment

| Mode | Before documents / chunks | After documents / chunks |
|---|---:|---:|
| Default manifest | 145 / 1941 | 151 / 1784 |
| Missing-manifest fallback | 171 / 2284 | 151 / 1784 |
| Explicit historical | 13 / 331 | 13 / 331 |

The original fallback admitted 31 extra current-path packets/navigation files and omitted 5 selected documents. The extras comprise 27 already-excluded execution/research packets and four navigation entry points; omissions are Materials Lab and four World Art tool guides. This defect existed independently of the historical directory exclusion. The exact path sets are in [the machine assessment](retrieval-assessment.json).

The repair preserves the explicit manifest and existing authority vocabulary. `retrieval: explicit-only` records selection on the 27 already-excluded current-path packets; it does not change their status, authority or prose. Default manifest admission, fallback discovery and direct chunking all reject that selector and navigation. Authority validates before selection, so excluding a malformed historical declaration cannot launder it. The fallback now discovers `docs/tools/` and `docs/MATERIAL_LAB.md`.

Final manifest/fallback document identities agree: **True**. Their actual ranked results agree: **True**. Default results admit no `docs/history/` or `docs/audits/` paths. Explicit historical retrieval retains 13 documents/331 chunks with byte-identical source identities and an authority warning on every saved hit.

Independent lead review caught a first implementation defect: applying the new current selector to existing `retrieval: explicit-history-only` envelopes rejected real historical documents. The repair validates the new selector only in current mode; old history remains unchanged. The original 16 historical regressions and 12 new current-selection regressions preserve this boundary, including actual missing-manifest selection and direct-ingestion bypass attempts. The policy identity advances from `historical-isolation-v1` to `historical-isolation-v2`. There is no persistent cache in this evaluator; external importers must rebuild older caches and retain each chunk’s authority envelope.

## Ranked source selection

| Question suite | Questions | Before top 1 / top 5 | After top 1 / top 5 | Before → after MRR@5 |
|---|---:|---:|---:|---:|
| Frozen current questions | 32 | 19 / 30 | 18 / 31 | 0.7292 → 0.7146 |
| Owner-intent questions | 6 | 4 / 4 | 1 / 4 | 0.6667 → 0.3389 |
| Frozen challenge questions | 164 | 127 / 162 | 127 / 161 | 0.8655 → 0.8606 |
| New renaissance v1 questions | 36 | 22 / 28 | 24 / 32 | 0.6829 → 0.7593 |
| New v1, missing-manifest fallback | 36 | 19 / 26 | 24 / 32 | 0.6111 → 0.7593 |
| Owner intent, missing-manifest fallback | 6 | 4 / 4 | 1 / 4 | 0.6667 → 0.3389 |
| Explicit historical questions | 10 | 7 / 10 | 7 / 10 | 0.8033 → 0.8033 |

These counts are recomputed observations, not a universal improvement claim. The new current-workflow suite improves while some older primary-destination rankings regress. The six owner questions still miss the original decision record for some questions; a relevant current synthesis can support the answer while leaving that primary-record miss unresolved. No expected destination, stale expected fact, ranking weight or frozen fixture was changed to obtain a better score. The 164-question challenge file retains earlier source-era premises; a canonical hit to such a premise cannot certify today’s answer.

The raw before/after reports and exact fixture hashes are linked in [the machine assessment](retrieval-assessment.json). Remaining new-suite top-five misses: DR09, DR15, DR31, DR36.

## Actual answer applicability and independent review

Specialist A independently inspected eight actual top-five contexts; Specialist B inspected eleven. Each wrote a bounded answer from the saved text and then checked it against accepted source. They did not substitute ideal passages or invoke an external model. Both authored some source documentation; cross-lane source reviews independently check those corrections. This is an agent/editor audit of retained contexts, not a blind production model benchmark or a claim of physical human evaluation.

The first pass contained **14 sufficient, four partial and one wrong-context result across 19 questions**. DR06 ranked a nominal canonical destination first while omitting the current eight-byte storage fact and surfacing old four-byte controls. This directly demonstrates why destination rank is insufficient. Actual-context review also exposed an obsolete overnight branch instruction, old ballistic restrictions and a transient invalid launcher example. Their failed contexts remain unchanged as evidence.

After the targeted content repairs, the independently reviewed saved snapshots contain **16 sufficient, three partial and zero wrong-context results**. DR02 still lacks the exact godot-cpp pin in its top five; DR08 lacks complete Wave/ballistic detail; DR31 supports historical nonauthority but lacks the complete canonical source/lease procedure. Those answers must withhold the missing details. DR15 supports the negative authored-save answer even though its canonical save page misses the top five. A separate seven-context owner/challenge review found two sufficient and five partial answers, preserving old expected facts and unresolved details.

These numbers belong to the named hashed snapshots. The final run directory carries explicit text/order delta evidence and any new reviewer acknowledgements; earlier files named “final” or “frozen” retain their original time-bounded meaning. Do not apply an earlier rating to changed passages without that review. [A’s retained review](retrieval/answer-a-frozen-review.json), [B’s retained review](retrieval/answer-b-final-review.json) and [the separate owner/challenge audit](retrieval/answer-a-regression-review-v1.json) provide actual bounded answers and cautions.

## Final frozen context audit

The final frozen corpus contains 151 documents and 1784 chunks. The source-byte stability receipt and all four manifest/fallback comparisons are retained in [the final execution receipt](retrieval/final-freeze/execution-receipts.json).

Final independent A/B applicability ratings across 19 saved questions: **16 sufficient, 3 partial, 0 wrong-context**. These ratings apply to the exact final inputs, using fresh reading where passage text/order changed and explicit equality verification where a prior answer was transferred. They do not claim a production answer model passed.

[Final A review](retrieval/final-freeze/answer-a-review.json) and [final B review](retrieval/final-freeze/answer-b-review.json) retain the bounded answers, actual inputs and missing-detail qualifications. A freshly read all75 passages across its main and extra samples; B freshly read30 changed passages and independently compared the25 unchanged passages before transferring prior answers. The final seven owner/challenge contexts yield **three sufficient and four partial** answers; USABLE02 now includes the identity/cancellation contract. Primary owner-record ranking misses and source-era LCB fixture premises remain explicitly qualified.

A separate [ten-question context-only packet](retrieval/final-freeze/blind-context-only-input-v1.json) contains exactly 50 actual final passages, including explicit historical retrieval. It omits expected facts, destinations, source answers and prior verdicts. The lead runs and source-grades that exercise separately; its eventual results must not be relabelled as the A/B audit.

## Negative controls and remaining limits

The versioned question set deliberately challenges LFS-pointer startup, permanent four-byte/sidecar doctrine, a blanket ban on upward Water motion, unmerged live Materials Lab audition, `queued=true` as completion, Stop as rollback, Save as exact coupled continuation, pending SWARM/RAMCACHE/Strata integration, obsolete Art conversation restoration, provenance hash editing, automatic Ready/merge, advisory CI as a waiver and historical “Approved” text as current permission. The final raw contexts and canonical ranks are retained for each control; independent answer judgments are a separate field, never manufactured from rank.

A correct current answer can require abstention: the owner-intent record does not authorize engine work or historical retirement, and documentation does not choose the next unresolved destructible-architecture design. External retrieval services, caches and production model behavior remain outside the tested apparatus. Runtime, evaluator and physical owner acceptance remain separate programme responsibilities.

The merge-review recommendation remains **Draft/HOLD**. The bounded #592 current-documentation and selection defect work is implemented and reviewable; residual ranking/applicability gaps and the inventory’s three deferred operator/research pages remain explicit follow-up work. No engine changes, historical retirement or retriever redesign is implied.
