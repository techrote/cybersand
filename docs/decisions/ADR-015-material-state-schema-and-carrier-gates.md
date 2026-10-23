---
title: ADR-015 MAT-003 semantic schema and carrier adoption gates
status: Approved design
document-kind: decision
scope: Accepted qualification budgets and conditional schema-first compact/DUAL64 shortlist; no production layout, epoch or solver adoption
canonical-for: [decision-mat003-schema-carrier-gates]
last-reviewed: 2026-10-23
related-documents: [../research/mat003-state-schema-proposal.md, ../research/mat003-continuation.md, ADR-002-double-buffered-tile-jobs.md, ../architecture/chunk-tile-and-buffer-model.md]
---

# ADR-015 MAT-003 semantic schema and carrier adoption gates

## Status and decision boundary

**Approved design for qualification budgets only; conditional schema and adoption decision.** The requested shortlist is optimized compact C72/C80 and DUAL64; this ADR proposes the criteria for choosing between them after semantic requirements are approved. It does not approve production implementation, a material-state schema, a new solver or timing execution. Production C64/E8 remains Current, ADR-002 scheduling ownership stays intact, PR211/221 stay draft. No accepted evidence or statistical definition changes.

## Evidence and why a decision is needed

All three campaigns were separately registered, owner-authorized and independently verified. Their full raw artifacts and review exceptions remain owned by their dated reports:

| Campaign | Exact evidence | Decision relevance and limitation |
|---|---|---|
| S2P | [39920964814](../audits/2026-10-23-s2p-results.md), execution2468353, registration95ed4767 | Optimized/original packed mean-tick ratios0.657751(C72)/0.663646(C80); optimized/C64 medians0.996224/1.008852 on active512w4. Strong implementation-sensitive packed penalty, not formal equivalence or universal cache causality. |
| WCLEAR | [39889832605](../audits/2026-10-23-wclear-results.md), execution4a0e9d2, registrationa207d988 | Quiet2048² event medians roughly2.39–2.51ms; maximum4.739428ms, all112 >1ms review-trigger pairs retained. Width changes frequency, not elimination of hitches; prepared-state/cache limits remain. |
| C128 | [39926130011](../audits/2026-10-23-c128-results.md), execution3080cae, registrationb52633a0 | Active U128/aligned0.991539, DUAL64/aligned1.002677; quiet1.234276/1.009461; direct active U128/DUAL641.005942. Neutral capacity only; quiet native difference concentrated in clear-inclusive frame. No high-state performance claim. |

Accepted S2A packed ratios near1.50 remain valid for their original implementation; later optimized results do not amend them. Do not merge these campaigns or derive a paired compact/C128 ranking. Native U128 size16/alignment16 and DUAL64 size16/alignment8 are tested target ABI facts, not atomicity or portability guarantees.

## Proposed decision

Define semantic requirements before allocating physical bits. The [state-schema proposal](../research/mat003-state-schema-proposal.md) owns logical field domains, extension-budget accounting, lifecycle and unresolved owner budgets. Preserve material16/state_a16/state_b8, nonzero Empty and separately owned temperature/continuation state. Raw storage width must not silently widen public material/mass domains.

Advance two expansion options: safe memcpy-based compact C72/C80 when the approved logical fields fit and the target platform/workload gates pass; explicit DUAL64 when required capacity or field-access simplicity justifies16-byte cells. Keep C64 as the unchanged baseline and a viable outcome if the requirements fit. Do not choose16 bytes merely because capacity exists. DUAL64 is the leading sixteen-byte option, not a selected production winner.

Retain native U128 as a research alternative, without default preference. Its exact active profile showed no established advantage over the registered controls, and quiet clearing had a repeatable disadvantage. That does not prohibit a separately justified future cross-lane schema/workload. Aligned C72/C80 and split remain retained controls/alternatives; split's second allocation/transfer surface needs an explicit benefit to justify adoption. Original byte-reconstruction packed code is not the preferred optimization baseline.

Evaluate epoch width independently. E16 is the first wider candidate, not an approved default. E24/E32 need a declared horizon/capacity justification and independently qualified map/counter/restore semantics. Never preserve prototype bits40–55 beneath the experimental E16 field48–63: they overlap. A logically fitting C72-E16 R16 design is a new packing contract, not an already performance-qualified implementation.

## Alternatives and consequences

A speed-only production promotion is rejected: paired medians do not define memory, schema, portability or hitch budgets. Mandatory C128 is rejected as a default reservation: at2048² it costs64MiB of cell arrays against32MiB C64,36MiB compact72 or40MiB compact80, before other World allocations. Automatic native128 preference is rejected; DUAL64 supplies an explicit-lane fallback without a compiler scalar extension. A universal sealed-room pressure target, physics rewrite or GEN-006 raw-struct codec is outside scope.

The proposed shortlist preserves a compact route for modest state growth and a portable larger route for justified capacity. It costs an explicit schema review and potentially new qualification; it does not create new authority for current spare bits. Cross-platform performance, full new-World sanitizer coverage, future authoritative high-state mutations and exact carrier/epoch break-even remain open.

## Adoption, review and rollback gates

Owner decisions must name required fields, maximum resident/active populations, memory/snapshot envelopes, normal tick and clear-frame budgets, tick horizon and platforms. The numeric budgets are now accepted qualification targets as recorded below; required field semantics, reference-machine identity and demonstrated compliance remain unresolved. The schema proposal supplies invariants and test obligations. Adoption requires an explicit approved mapping, independent correctness and applicable runtime/platform validation, source-matched provenance, and a separately authorized implementation PR ready for review under repository merge policy. Evidence acceptance is not implementation acceptance.

Any changed packing, material semantics, high-state access, epoch width, compiler/target, workload or resident envelope triggers relevant requalification. A new timing campaign is a distinct future decision and is stopped here. Never selectively rerun/drop failures or retrofit old registrations. Preserve the recoverable prior production/runtime checkpoint; a future migration must specify semantic conversion, refusal and rollback before rollout, with no mixed-version reinterpretation or raw-byte saves. GEN-006's canonical semantic handoff remains separate and unchanged in implementation.

## Semantics and budget review disposition

The [technical review](../research/mat003-semantics-budget-review.md) retains this Planned shortlist and corrects record-admission versus failed-tick semantics. At that technical review, adoption was blocked because neither named extension semantics nor owner budget targets had been approved. The later owner disposition below accepts budget targets only; semantic/adoption gates remain blocked. Standalone4096-chunk limits are not performance acceptance and imply1GiB DUAL64 arrays before other allocations. A material/World-schema discriminator must be explicit, and rollback cannot silently truncate wider records to C64. Production and timing authority remain unchanged.

The [concrete owner offer](../research/mat003-concrete-owner-offer.md) supplies reviewable proposed semantics and numeric budgets. This ADR remains Planned until an explicit disposition; publication of suggested values does not approve a Water solver, implementation or new timing.

## Owner acceptance of qualification targets — 2026-10-23

The owner accepted the [concrete offer's budgets](../research/mat003-concrete-owner-offer.md) as qualification targets:256resident chunks/64active cores,512MiB aggregate cellular memory within2GiB application RSS,60Hz native simulation target, ordinary p95≤5ms/p99≤8ms and10ms observed-tick ceiling, Linux/Windows phase1 scope with reference-machine identity outstanding. The detailed sublimits, provisioning and finite-run interpretation in that document govern; this summary does not create different budgets.

R16-T1 and its proposed C72/E16 mapping remain conditional. No owner approval of Water overfill, field feedback, epoch/layout adoption, GEN-006 implementation or satisfied performance limits is inferred. The [bounded correctness-only plan](../research/mat003-correctness-only-plan.md) prepares a later review, without implementation or test execution authority. No new timing is authorized. Production and both draft PR states remain unchanged.
