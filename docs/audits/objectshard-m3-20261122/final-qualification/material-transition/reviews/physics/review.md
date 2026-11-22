# Independent review: inherited ObjectShard Fire transition

**Disposition: no semantic or guard-integrity blocker found.** The ordinary append-only per-file transition is substantively supported. Runtime evidence remains attributed to `e034f2294663e0485cfb9adcc8ada46a6e977cee`; the published guard-only descendant is `73018218092e79fbe935aa60890e33bd9f4859ac`, tree `ede95a3ad7102f4059f8b425167c7fa6c1948663`.

## Exact delta and ordinary World behavior

The prior admitted World source is `5afe5643097c543f7d8a6840ced9afac58dd053e`, LF SHA256 `bc24ccd2e7457f61c75abdc13d20c2ccd82863fdf427f0c13ccaa1a05ad9d214`. The first further edit is `c06550371ac5448642bff7e4ecb64fe9cd1df728`, LF SHA256 `5bb8ccded21bb73077ea86086d6fb25b9cbca67bda84013e67fa87d96b1c8cd1`. The same bytes remain in qualified 001R, M3 and the guard descendant. Both required ancestry relations were checked against Git.

The entire protected `world.cpp` delta is one additional short-circuit condition around the existing Fire ignition attempt:

```cpp
if (slow_interaction_due(10U) && (object_shard_mutations_ == nullptr ||
    !object_shard_mutations_->external_fire_claimed(x, y, tick_index_))) {
```

For an ordinary World, the private journal pointer remains null. The new disjunction is true without a claim query, so the original condition, deterministic sample and ignition call remain identical. Fire lifetime and drift follow the conditional unchanged. The World header, shared lifecycle header and other 26 protected consumers are unchanged from the preceding admitted source. The change does not establish zero execution-cost overhead or binary identity.

The enabled ObjectShard path intentionally differs. A recorded contact can claim a selected Fire source opportunity for shard-owned Wood; the following native tick must not spend that same opportunity again on World material. The guard skips the existing sampled `ignite()` call, which normally supports Dust, Seed, Gunpowder and other combustible targets. This is not restricted to World Wood, and it does not suppress Fire lifetime or movement. Actual shard burning still occurs in the subsequent chemistry stage, not during motion contact capture.

## Claim authority and lifetime

The coordinator owns a fixed-size token array and keys it to `completed_tick + 1`. It preserves the source cadence anchor and claimed bit through mechanical relocation. Newly captured claims are rolled back on refused motion. Authored replacement clears a source token; same-Fire state edits retain it.

A read-only span over that storage is lent to the mutation journal only around the synchronous `World::tick`. The query checks exact tick, nonempty span, coordinate inside watched bounds and the high claim bit. The span is cleared on normal completion and in the exception handler; reset clears tokens/tick and replaces the World. No competing ordinary World path enables this private journal, and the supported coordinator constructs a serial, one-worker World.

No concrete lifetime, aliasing or ordinary-default behavior defect was found in this seam. This is a review of the supported fixed-owner synchronous contract, not a general concurrent World attachment claim.

## Existing exact-source regressions

The fresh final Linux native campaign used ASan/UBSan and completed naturally. All 128 native/test inputs match the published guard descendant. Its 121 native compilation/build-contract inputs, 51 Lab inputs and 19 qualification-tool inputs are also unchanged; `compatibility.py` is absent from each set.

| Retained suite | Result | Relevant coverage |
|---|---:|---|
| External Fire | 3,683 checks / 0 failures | Historical contact, repeated motion with no extra clock, no off-opportunity ignition, stale targets, relocated-source single use, World duplicate-ignition refusal, source lifetime/transport, reset, refused-motion rollback and pending Water extinction |
| Chemistry | 4,472 checks / 0 failures | Unchanged 16 frozen oracle records from original source, with 2,964 observations including initial states; tuples, timing, temperatures, accounting and physical-state hashes |
| Ordinary World | 192 test cases / 0 failures | Unfiltered complete Makefile `TEST_SOURCES` inventory |

The chemistry fixtures cover sealed Wood countdown, emitted products, Water extinction, Fire expiry, crowded Smoke, pair precedence, negative coordinates and epoch wrap in serial and phased modes. The frozen oracle source is unchanged from the previously admitted source. These are current-source executions, not a relabeling of older M2 runs. The extra four independently regenerated M2 fixtures described in the older transition remain historical evidence; they were not newly rerun here.

The dedicated duplicate-opportunity regression uses World Wood. The shared guard's suppression of other supported ignition targets follows from the one conditional, rather than a new per-target adversarial campaign. The oracle fixtures use one worker and are not exhaustive over all states or schedules. LeakSanitizer was disabled; no ThreadSanitizer or physical Windows-owner claim is made.

This combination of direct null-journal equivalence, unchanged frozen oracles, targeted external-Fire tests and broad ordinary-World regressions is sufficient for the narrow transition. No additional native/runtime run is warranted solely by the guard/tool descendant.

## Guard integrity and publication boundary

AST comparison confirms the published tool has exactly one additional `REVIEWED_TRANSITIONS` append and no other executable change. The entry chains the authenticated old hash to the exact `c06550371` bytes, names the committed audit, and correctly uses issue 281 / PR 741. A read-only invocation of the published guard passes with 54 authenticated transition entries.

All 12 identity inputs, the other 26 protected files and the frozen lock remain byte-identical to the preceding admitted source. Catalogue digest `82b5ab9a6e87ae817072390105052f8a5ac6d0ee22b3301cd973efdfc7fdbad3` and capability digest `33c608f875e3d8b5730f1d3b81a54dbeff9579b433e061535610a8bfa276e237` are preserved. Baseline, normalization, ancestry, exact-target, record-content, generated-route and refusal logic remain unchanged.

The mechanism requires a protected non-identity path; an ordered from/to chain; source bytes authenticated at a full retained ancestor commit; a committed Markdown record naming the path, both hashes and commit; and working bytes equal to the final target. The runtime/source ancestor must survive a future merge. The new entry/record must also be carried to the earliest dependency head that needs it before any separately authorized mergedown.

Two prose refinements are present in the working audit for the next documentation commit: a contact has **claimed** the opportunity before actual burning, and the query checks **watched coordinate bounds** rather than a fresh residency lookup. Their exact hash is bound in `review.json`; they are distinguished from the published 730 record and alter no transition fact.

Ordinary workflow negative-control CI remains a separate result, owned by the parent/C reviewer. This review changes no gate, product source, identity, runtime artifact or permission. Production native-provenance failures, runtime publication, Ready/merge/default promotion and physical owner acceptance remain separate boundaries.
