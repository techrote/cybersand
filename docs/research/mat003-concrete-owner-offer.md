---
title: MAT-003 concrete semantic profile and owner-budget offer
status: Planned
document-kind: design
scope: Concrete R16 semantics and bounded native rollout targets offered for owner review; no implementation, solver adoption or new timing authority
canonical-for: [mat003-concrete-owner-offer]
last-reviewed: 2026-10-23
related-documents: [mat003-state-schema-proposal.md, mat003-semantics-budget-review.md, mat003-continuation.md, ../decisions/ADR-015-material-state-schema-and-carrier-gates.md, ../operations/water-hybrid-pressure-extension-programme.md]
---

# MAT-003 concrete semantics and owner-budget offer

## Decision offered, not approved

Recommend approving the following as a **design target for subsequent qualification**, not as implemented behavior or satisfied release limits. All new field meanings and numeric limits here are Planned recommendations. Production C64/E8, existing adapter configurations, accepted evidence and draft PR211/221 stay unchanged. No new implementation or timing campaign starts here. Source intake is `4c928b35b58f02558f4e16a7ea5d63c21437c000`.

The offer has three parts: R16-T1 transport-state semantics; a256-chunk resident native envelope with a512MiB aggregate cellular-memory budget; and prospective latency gates on a pinned Linux/Windows reference platform. Do not infer approval from publication or from prior measured results.

## Proposed extension MAT003-R16-T1

Interpretation is selected by material ID plus one homogeneous World schema/solver identity, outside the cell payload. There is no per-cell version tag. Preserve material16/state_a16/state_b8 and separate temperature. In this profile only Water assigns the16 extension bits semantic meaning:

| Logical field | Proposed exact domain/default | Meaning |
|---|---|---|
| lateral_history | signed8, −127…127; default0; −128 invalid | Advected horizontal flow history in quanta of1/127 cell per selected native tick. It is a game transport predictor, not calibrated momentum or a general2D velocity. Positive means right in native coordinates. |
| overfill | unsigned8; default0, constrained to0…M | Additional authoritative Water amount above visible base fill; M is the admitted existing Water policy maximum (at most255). It is neither pressure nor a display-only surplus. |

All other materials, including Empty, require extension0 in this new profile. Existing nonzero Empty state_a/state_b/temperature remains preserved. Records bearing the saved prototype's Empty-air interpretation or another required schema refuse conversion into R16-T1; never erase them as if they were zero. This deliberately excludes trapped-air topology/history from the first profile. It does not claim that R16-T1 can resume the saved pressure prototype.

The signed-history scale is a proposed reuse of the prototype's interpretation; no temporal calibration follows. For the first semantic contract, treat it as passive advected history: a whole-cell displacement with signed horizontal delta dx sets history to clamp(127×dx,−127,127); no acceleration, pressure force or routing rule reads it yet. Introducing feedback, damping or a different update lane needs a separately reviewed solver rule. Vertical-only displacement gives0; stationary cells preserve history. Chunk/interest pauses produce no fabricated elapsed-time updates.

### Amount invariant and external admission

Let a be existing visible Water state_a, o overfill and T=a+o, computed in checked unsigned32 intermediates. For a nonempty Water record, require1≤T≤2M and canonical a=min(T,M), o=T−a. Thus base opens before overfill is retained; a<M with o>0 is noncanonical and refuses external admission. Water withT=0 becomes Empty through the declared conversion boundary. No value is silently clipped, wrapped or saturated. A request beyond2M refuses or leaves unaccepted amount with its source; it cannot discard surplus.

Existing policy, state_b/coherence and temperature retain their own domains. Default Water creation hasT=M, o=0, history0. This profile would extend total representable Water amount to2M; it therefore requires a separate authoritative solver/API/ledger change before implementation. The existing public setter is not silently reinterpreted as accepting overfill.

### Transfer, movement and conversion contract

A candidate transfer q must satisfy0<q≤Ts and q≤2M−Td before either record changes. Successful transfer sets source totalTs−q and destination totalTd+q, then canonicalizes both as above. This is equivalent to consuming source overfill before base and filling destination base before overfill. Empty destination startsTd=0 with history0. Preserve source history if it remains Water; destination history becomes truncation toward zero of (Td×hd+q×hs)/(Td+q), in checked signed32 intermediates, then validate its signed8 domain. This weighted history is explicitly not conserved momentum. A drained source becomes Empty with extension0 under this schema.

Whole-record relocation into Empty movesT and history; apply the displacement update above after relocation. Swap transports both full records and applies each Water record's own displacement update. Partial state setters preserve unrelated fields. Writes to base/overfill use a proposed total-amount API so they cannot create a noncanonical pair. Existing coherence and temperature movement rules remain unchanged unless separately revised by their owners.

Creation/injection/removal/conversion records the exact totalT in explicit source/sink ledgers. A closed transfer must conserve sum(T) exactly, including overfill. Conversion out of Water consumes allT under an explicit product/yield/sink rule; unsupported conversion refuses before commit instead of silently losing overfill. No new stoichiometric/thermal yield is invented here. This is a prerequisite for solver integration, not proof that current reaction rules already satisfy it.

Validate both participants and stage bounded needs before record publication. In-tick capacity failures retain Current failed-world quarantine; no whole-tick rollback is promised. Epoch clear preserves these semantic values. Unknown required schema, invalid values and lossy export refuse. No raw-struct GEN-006 codec or silent C64 rollback is proposed.

### Deliberate exclusions and programme authority

Do not assign Empty-air16, pocket IDs/volumes, pressure/head, two-component momentum, chemistry progress or solver history to this profile. The saved prototype's World-owned histories are not disposable caches. These require their respective semantic/topology owners and additional storage budgets.

This offer is storage/transport semantics for review, not an accepted head-transmission implementation. #45 remains conditional on corrected#49 controls and#95/WEX synthesis or its blocked/no-go disposition; #93 gas-region ownership is not duplicated. Approving this offer would not approve a pressure equation, air law, Water FreeMass/CellularYield unification, prototype integration or bypass of those programmes. If those owners choose a different representation, revise this profile before implementation.

## Proposed carrier and epoch starting point

Use **compact C72 + E16 + R16** as the first design candidate:40+16+16=72 logical bits. Proposed versioned map: material0–15, state_a16–31, state_b32–39, epoch40–55, extension56–71 (logical history8 followed by overfill8). This is a new experimental map for future qualification, not the current E8 map or the tested E16 map. In particular it must not reinterpret the prototype's old40–55 payload or experimental epoch48–63. Rejected sentinel−128 must be checked by semantic admission before raw encoding.

Keep compact C80 for justified additional fields and **DUAL64** as the leading larger-capacity fallback design option, with an explicit mapping for this same semantic schema. It is not an automatic runtime fallback. Require declared conversion/refusal before changing a running World's map. C128 additional bits remain zero until assigned by a new schema. Native U128 stays research-only in this offer.

E16 is a proposed starting epoch because natural-rollover correctness exists and it substantially reduces frequency. At the proposed60 simulation ticks/s, first rollover is1092.2667s and later intervals1092.25s, versus E8's4.2667s and4.25s. This is arithmetic, not a latency guarantee or measured long-run result. No E24/E32 adoption is proposed now. Neither new C72 mapping, authoritative R16 mutations nor its E16 performance has been qualified by the completed neutral-capacity campaigns.

## Proposed native operating envelope

These are proposed profile limits, not edits to WorldConfig or a claim that arbitrary contents inside the limits meet latency targets.

| Dimension | Offer for first rollout qualification |
|---|---|
| Published resident population | At most256 storage chunks of128² cells (4,194,304 cells), counting sleeping/excluded chunks and required write halos. Arbitrary arrangement must still satisfy prepared-neighbor requirements. |
| Active workload | At most64 scheduled64² cores per tick, with a primary workload matching active512w4. Other patterns/material mixtures require qualification even at the same count. |
| Scheduler provision | Propose active_core_capacity128 and active_chunk_capacity64 for preparation headroom; provision does not authorize routinely exceeding the64-core workload envelope. Validate exact required tasks/neighbor chunks before admission. |
| Workers | Four configured workers for performance qualification; one-worker correctness/control retained. No performance guarantee for the one-worker fallback or different thresholds. |
| Concurrent Worlds | Initially one simulated World. Any later multi-plane rollout partitions the same aggregate budgets, never multiplies them automatically; retained old/candidate owners also count. |
| Capacity outcome | Refuse preparation/residency admission before commit when possible. A current tick that already fails stays quarantined. No automatic eviction, lossy state discard, live cap reduction or invented GEN-006 streaming. |

The256-chunk population is the largest measured resident anchor, not a universal qualified scene. Standalone4096-chunk defaults are outside this proposed rollout envelope and remain unchanged. A4096² stress case is also outside it.

## Proposed memory envelopes

Aggregate **cellular-engine owned resident/temporary host memory ≤512MiB**, including retained old/candidate and snapshot leases. Proposed sublimits are additive ceilings with headroom, not measured current allocations:

| Component class | Ceiling |
|---|---:|
| Published cell arrays (allows DUAL64) |64MiB|
| Temperature arrays |8MiB|
| Solver and worker scratch |256MiB|
| Activity, descriptors, event/discovery structures and associated host overhead |32MiB|
| Immutable snapshot payloads |24MiB|
| Transient staging/candidate allocations |64MiB|
| Uncommitted allocator/headroom allowance |64MiB|
| Total |512MiB|

At256 chunks, compact72 arrays are36MiB, compact80 are40MiB and DUAL64 are64MiB. Smaller arrays do not automatically authorize more residency or a larger extension. Full temperature is8MiB. Three complete2048² RG8 payloads account for24MiB; propose at most3 concurrent payload leases and256 patches per slot for this profile, with patch metadata in the overhead class. These differ from current finite-adapter1024²/64-patch values and need explicit future configuration validation; they are not changed here. Snapshot values are projections, not copies of native cell carriers.

The aggregate allowance applies across classes and owners simultaneously. A64MiB staging allowance does not permit an entire second512MiB World. If old+candidate construction cannot fit, preparation refuses or a separately designed replacement protocol is required. Count shared components once and allocator/RSS effects explicitly; no hidden heap category is excused by a zero chunk-allocation counter.

Propose **whole native application peak RSS ≤2GiB** for this single-World MAT profile, with the512MiB engine envelope included, not added. GPU/device allocations need a separately recorded platform budget and are not hidden in the host limit. This does not retroactively replace GEN-007's separate4GiB scene qualification envelope or qualify all Godot scenes. Largest observed campaign RSS (~281.57MiB WCLEAR, ~91.73MiB C128) shows bounded apparatus feasibility, not compliance of the engine breakdown or a rendered application with these ceilings.

## Proposed latency and platform targets

| Quantity | Prospective review/qualification target |
|---|---|
| Simulation pacing |60 completed native ticks/s target, independently paced from rendering; no fabricated catch-up. No60fps rendering guarantee. |
| Ordinary active tick (exclude identified clear events only for this diagnostic category) |Per-process p95≤5ms and p99≤8ms on the registered target profile. Retain/report all samples, full-process mean and maxima. |
| Clear-inclusive frame at maximum proposed residency |Observed maximum≤10ms in the future declared qualification matrix, reported separately from ordinary ticks and full means. |
| Any observed tick>10ms |Release review/failure for this proposed profile; retain the observation, investigate, and require a separately reviewed correction/disposition. No selective replacement or outlier trimming. |
| Evidence meaning |Finite-run observed gates, never a mathematical worst-case bound or permission to hide OS stalls. Specify replicate counts/order and all gates before future execution. |

These are **new suggested thresholds**, not retrospective acceptance tests on the completed campaigns. S2P's optimized/C64 active means are roughly3.2ms in its paired contrasts; C128's active maximum7.08ms and quiet maximum8.35ms motivate an8–10ms frame guard with limited margin. WCLEAR maxima and the historical1ms review trigger are separate evidence/diagnostic concepts. None proves the proposed R16/E16 profile meets these targets; the quiet C128 event alone consumes much of the proposed10ms ceiling.

Phase1 targets: native Linux x86-64 with the established GCC13.3/ld2.42 reference and Windows x86-64 with the repository-pinned native toolchain/Godot dependencies. Four configured workers; strict field/lifecycle correctness on both platforms. Linux hosted results are the existing performance reference, not Windows or target-hardware acceptance. Before any release qualification, record one owner reference machine's CPU model, physical/logical cores, RAM, OS and power policy and freeze the exact source/compiler/runtime identities. Owner machine identity is still needed; no hardware purchase or unmeasured minimum specification is implied.

Web/Wasm, macOS, mobile, reduced-memory profiles and multi-World rendering remain separate rollout qualification, not removal of existing support. Do not grant them the native budget or assume unsigned128 availability. One-worker serial/phased cases remain required correctness checks; performance envelopes for them need their own profile.

## What owner approval would mean

Owner may approve/revise separately: (A) R16-T1 proposed semantics and its deferred-air/solver boundary; (B)256-resident/64-active-core and512MiB/2GiB memory envelopes; (C) E16 starting map and60Hz/5ms-p95/8ms-p99/10ms-observed targets on the two native platforms. Reference-machine identity remains an explicit prerequisite. Budget approval does not approve source code, a Water solver, a save format, production promotion or any new timing registration. If R16-T1 is not the desired feature, retain current semantics and revise fields before choosing a carrier.

After review, update the schema/ADR decision status deliberately, reconcile programme ownership, define meaningful correctness fixtures and sanitizers, and identify only the unanswered performance questions. No implementation or campaign is started by this document. PR211/221 remain draft; all accepted raw evidence and Current production are unchanged.
