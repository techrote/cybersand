---
title: Ultima retrieval investigation, correction and checkpoint comparisons
status: Historical
document-kind: evidence
authority: historical-non-authoritative
retrieval: explicit-history-only
scope: Dated source-bound lexical and reference-adapter evidence; canonical recall, manual context review and model execution are distinct
canonical-for: []
last-reviewed: 2026-11-25
related-documents: [README.md]
---

# Retrieval investigation and checkpoint comparisons

The reference adapter improves primary-record routing and public canonical
recall, while preserving important negative results. It remains a local,
deterministic retrieval/source-following harness. No deployed external index,
embedding service or generative model was executed. Current acceptance and
final integration are governed by the mission's final report; the measurements
below belong to the explicitly named checkpoints.

## Original historical reproduction

[The compact reproduction](baseline-reproduction.json) retains all 744
per-question results from 15 source/suite combinations. The original fixtures,
expected records and scorer were used without relabelling misses.

| Frozen suite | Accepted `00cdb02f` top five | Recovery `ddd7c88f` top five | Delivered #774 top five | #774 top one / MRR@5 |
|---|---:|---:|---:|---:|
| 32 | 30/32 | 31/32 | 32/32 | 18 / 0.7302 |
| Challenge 164 | 162/164 | 161/164 | 161/164 | 126 / 0.8575 |
| Additive 36 | 28/36 | 32/36 | 35/36 | 27 / 0.8426 |
| Owner intent six | 4/6 | 4/6 | 4/6 | 1 / 0.3389 |
| Explicit history ten | 10/10 | 10/10 | 10/10 | 7 / 0.8033 |

The challenge MRR at recovery was 0.8606. These historical values use their
actual original corpora and policies. A comparison on a changed current corpus
is reported separately, even when it uses the unchanged lexical scorer.

## The rejected final-v1 regression and general correction

The first integrated v1 checkpoint was `162b80977f3ce615ec5f31237d3b9ac1c4548eab`.
It lost frozen Q01 from the top five: a newly truthful heading containing only
the ambiguous word “recover” received the full additive field bonus, displacing
the broader source-custody passage to rank six. The actual passages and term
contributions are preserved in [the counterexample](ranking-q01-counterexample.json).

C preregistered two general controls before executing them: remove the extra
field bonus entirely, or scale that existing bonus by the fraction of distinct
query terms matched in the chunk. The selected v2 scales only the additive
title/heading bonus. BM25, tokenizer, field coefficients, diversity selection,
authority rules and frozen labels are unchanged. It introduces no query aliases,
target paths or additional tuned constants. Method identity changes to
`source-bound-field-bm25-v2`, invalidating both cached and live v1 instances.

| Suite | v1 top five / MRR@5 | Full bonus rollback | Selected coverage scaling |
|---|---:|---:|---:|
| 32 | 31 / 0.8620 | 32 / 0.7484 | 32 / 0.8359 |
| Challenge 164 | 163 / 0.8833 | 161 / 0.8556 | 163 / 0.8766 |
| Additive 36 | 35 / 0.8639 | 35 / 0.8412 | 35 / 0.8653 |
| Owner intent six | 6 / 0.5139 | 4 / 0.3889 | 6 / 0.5139 |
| Explicit history ten | 10 / 0.8333 | 10 / 0.8250 | 10 / 0.8333 |
| C-authored development 20 | 18 / 0.7392 | 20 / 0.7683 | 18 / 0.7458 |

This is not uniform dominance. V2 loses MRR relative to v1 on the 32 and 164
suites. Removing the bonus entirely has better development recall. Coverage
scaling was selected because it repairs the public Q01 miss while retaining
the broader public challenge/owner-route gains. The development set is authored
by the implementer and is not a holdout.

The [preregistration](ranking-correction-preregistration.json),
[development inputs](ranking-development-v1.json),
[portable experiment](ranking-correction-experiment.py),
[all control results](ranking-correction-results.json.gz),
[original v1 checkpoint](retrieval-v1-162b8097.json.gz), and
[independent execution identity check](retrieval-v2-public-verification.json)
retain the full chronology. A independently executed all 268 public/development
v2 queries and reproduced their IDs, scores, context hashes and ranks. B reviewed
the general mechanism separately. Those mechanism checks used public/development
inputs only. A had separately reviewed sealed contexts before the code review;
that reviewer was not blind to the holdout. No held-out content or judgments were
disclosed to C.

The lead sealed 60 holdout questions before tuning. C never saw their content,
expected facts or results. The lead had already run the v1 holdout before
authorizing correction of the independently observed public Q01 failure. Later
holdout execution is therefore a second treatment, with the original treatment
and judgments retained. It must not be described as an untouched first blind run.

## Qualified v2 checkpoint before accepted-main drift

The complete source at `67245ba5456956c86c6360e7cf54258f15068feb`, tree
`7bcc1791eb206fad6a00859b05c45a1c540dcc18`, produced the following paired results.
Both methods used the same current corpus and original frozen payloads.

| Suite | Original top 1 / 3 / 5 | Original MRR@5 | V2 top 1 / 3 / 5 | V2 MRR@5 |
|---|---:|---:|---:|---:|
| 32 | 19 / 27 / 32 | 0.7458 | 23 / 29 / 32 | 0.8359 |
| Challenge 164 | 124 / 156 / 161 | 0.8553 | 129 / 160 / 163 | 0.8766 |
| Additive 36 | 27 / 33 / 35 | 0.8426 | 29 / 32 / 35 | 0.8653 |
| Owner intent six | 1 / 3 / 3 | 0.3056 | 1 / 5 / 6 | 0.5139 |
| Explicit history ten | 7 / 9 / 10 | 0.8033 | 7 / 10 / 10 | 0.8333 |

[The complete compact record](retrieval-v2-67245ba5.json.gz) contains per-question
ranks, ranked passage hashes, authority, direct primary routes, timings, source
identity and corpus cost. There were 151 current documents and 1,789 chunks:
2,975,483 source bytes and 4,788,340 serialized chunk bytes. Current-query medians
were approximately 380–423 ms, with observed suite p95 up to 595 ms; explicit
history queries had a median around 28 ms. This is local measurement, not a
service-level promise. Checking live source freshness on every current query
costs more than the original evaluator's in-memory batch lookup.

At this checkpoint C06 and USABLE02 reached rank five, while OI01/OI04 reached
their primary record at rank two. LCB01 remained a canonical-page miss despite
useful current catalogue/status passages. DR36 also remained a canonical-page
miss, but its actual coupling and primary owner-intent passages supported a
useful refusal to invent the unresolved future design. EXPLORE layout was rank
three and contextually sufficient; ranking loss is retained rather than hidden.

## Actual context applicability

A and B reviewed the actual supplied v2 passages independently of the retrieval
implementer. On all 36 additive questions at the 67245 checkpoint they found
**33 sufficient / three partial / zero wholly wrong contexts** and no wrong
authority. “Zero wholly wrong” is a question-level judgment; it does not assert
that all 180 passages were equally useful. No model-generated answer was scored.

DR04 lacked the C-header/cheap-check commands in its initial five passages;
DR08 lacked the complete Wave/ballistic distinction; DR20 needed the current
equipment-successor status route. Explicit human-selected `read_source` calls
supplied those missing facts. After those separately recorded follow-ups all 36
were sufficient or supported appropriate abstention. The DR04/DR08 full-source
reads alone supplied 141,873 bytes, a meaningful context cost. These routes were
not selected automatically by a model. The adapter's boolean empty-context
abstention flag is not an owner-decision reasoner.

See B's [actual 24-question review](../product/context-applicability-67245ba5.json)
and A's [actual 12-question review](../technical/context-applicability-v2-67245ba5.json).
Earlier v1 judgments remain separate. Final source changes require new passage
identity comparisons and review of changed content.

## Authority, cache and accepted-main reconciliation

The shared selection policy now rejects missing required source metadata,
ambiguous or unsupported authority declarations,
duplicate/malformed keys, scalar/list ambiguity, unsupported kinds and explicit
navigation-only sources. Current/fallback/direct paths share the same admission
boundary. A long-lived adapter refuses queries after source status, content,
manifest or method changes; persistent caches rebuild from current source and
remove superseded chunks. Cache destinations cannot overwrite repository source,
linked worktrees, Git metadata or their symlink aliases. External corrupt caches
still rebuild. These are tested local reference-consumer contracts, not claims
about inaccessible external services.

Accepted main advanced after the 67245 checkpoint. The owner-acceptance guide
from #758 remains an explicit manual route; it does not enter default current
retrieval merely because the tooling merged. The accepted CI closure at `5e29b111`
introduced a dated audit packet marked Current and admitted 12 misleading chunks.
Its ordinary path now holds a concise navigation-only custody wrapper with 11
retained anchors. Full original bytes remain in immutable accepted Git. Actual
live-instance and stale-cache controls demonstrate removal from current answers.

The original frozen 32 bytes have SHA-256
`21f22c828f89e422722527cbdff0132d7871815783ed8a25a101f4f8fbfbee3f`.
Accepted main's additive 33 file is retained unchanged at SHA-256
`e056df8e611a01efa341835d5d958391fd64b0295e17bbd7b221b7a5f783dae7`.
Its dated canonical target remains visible as a historical evaluation limitation.
A separately reviewed corrected CI case is additive. Structural checks validate
the frozen 32 and corrected current CI routes without exempting any canonical
admission rule. A independently passed all 17 selection tests after this migration.

Later accepted-main and runtime integration measurements belong in an explicitly
new source-bound record. They must preserve the above checkpoints, negative
results, original fixtures and review chronology.
