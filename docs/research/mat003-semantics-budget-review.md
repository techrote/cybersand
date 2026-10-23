---
title: MAT-003 semantics and owner-budget review
status: Current
document-kind: reference
scope: Technical review disposition and unresolved owner choices for the Planned schema and ADR; no production or timing authority
canonical-for: [mat003-semantics-budget-review]
last-reviewed: 2026-10-23
related-documents: [../research/mat003-state-schema-proposal.md, ../decisions/ADR-015-material-state-schema-and-carrier-gates.md, ../operations/configuration-and-capacity-budgets.md, ../reference/configuration-reference.md]
---

# MAT-003 semantics and owner-budget review

## Disposition

**Technical review complete; production adoption blocked pending semantic and owner-budget decisions.** Review source is `d433dacd94a05ca9f674e9114445d0f5216a7e77`; native source and accepted experiment inputs remain unchanged. The schema and ADR remain Planned. This review endorses the preservation invariants and two-option shortlist for continued design; it grants no owner budget, material/solver acceptance, production migration or new timing authority. PR211/221 stay draft.

The completed [S2P](../audits/2026-10-23-s2p-results.md), [WCLEAR](../audits/2026-10-23-wclear-results.md) and [C128](../audits/2026-10-23-c128-results.md) reports support keeping optimized compact and DUAL64 as leading expansion options, with C64 viable when requirements fit. Native U128 has no established active advantage and a repeatable quiet clear-frame disadvantage against aligned in its registered campaign. These are separate datasets, not a combined layout ranking or a production budget proof.

## Semantics findings and resolutions

| Finding | Review disposition |
|---|---|
| Preserve material16/state_a16/state_b8 without silently widening the catalogue or public setter domains | Retain. Raw roundtrip and semantic validity are separate. Nonzero Empty and high boundary storage cannot be dropped through occupancy-only observation. |
| R16 derived from the saved pressure prototype | Retain only as an options-study budget. Water's flow8 and overfill8 coexist; Empty uses air16 instead, so sharing is material-dependent. World scratch/history and solver configuration remain outside this payload. No production physics meaning is accepted. |
| Extension interpretation lacked an explicit discriminator budget | Clarified: proposed default interpretation is fixed by material ID plus World material-state schema and solver/configuration identity. No free per-cell schema tag is assumed. Concurrent independent fields must be summed; mutually exclusive union arms need explicit applicability. Heterogeneous per-cell schemas would require a separate bounded discriminator/storage design. |
| Logical C72/E16/R16 fit could be mistaken for a tested mapping | Retain the fit, block implementation until a new map is specified. Forty base bits plus16epoch plus16extension exactly consume72 bits; any additional per-cell tag needs more space. Prototype40–55 overlaps experimental E1648–63. Neutral extension preservation does not qualify new authoritative field semantics. |
| Atomic refusal wording could imply rollback of failed World ticks | Corrected. Future external record admission must prevalidate/stage before publication. Current capacity failures during a running tick can leave mutations; failed-world quarantine is mandatory. No whole-tick rollback is promised. |
| Transport/conversion and rollback | Require explicit split/merge/rounding/conservation/default rules from the semantic owner. Do not add raw extension integers during mass transfer without a rule. Reverting to C64 is not a safe runtime fallback when fields do not fit; refuse or use an explicitly validated conversion/checkpoint. |
| Temperature, scheduling and continuation identities | Retain separate owners and logical defaults. Epoch width is neither a durable schema version nor a chunk incarnation. GEN-006 handoff remains canonical; no raw-struct save format is accepted. |

The absent semantic choice is concrete: which extension fields are actually needed now, with what applicability, range/unit, default, update frequency, transfer/conversion and pause/reentry behavior? R16 alone cannot answer that. Two-component signed16 momentum would need32 bits, not16; that is a different requirement, not a reinterpretation of the saved one-component prototype.

## Resident budget gap

The [standalone WorldConfig](../../native/include/cybersand/world.hpp) defaults to128-cell chunks, maximum_chunk_count4096, active_chunk_capacity4096 and active_core_capacity4096. The [capacity runbook](../operations/configuration-and-capacity-budgets.md) distinguishes construction limits, reservation hints and adapter overrides. These values are not owner acceptance of a particular material layout, frame time or RSS envelope.

4096 chunks ×128² cells =67,108,864 resident cells (8192² if arranged square). The maximum need not be a contiguous square. Derived cell-array costs at that default cap are:

| Carrier | Arrays at4096 chunks | Increase over C64 |
|---|---:|---:|
| C64 |512MiB|0|
| Compact C72 |576MiB|64MiB|
| Compact C80 |640MiB|128MiB|
| DUAL64/aligned |1024MiB|512MiB|

Full temperature adds128MiB at this population. Thus DUAL64 plus full temperature is1152MiB before scratch, activity, descriptors, events, discovery, allocator overhead, immutable snapshot owners and other Worlds. This is arithmetic, not an executed memory/RSS result. No new allocation or stress run was performed.

The largest qualified resident grid in these campaigns is2048² =256 chunks, only one-sixteenth of the standalone resident cap. Active512w4 uses16 resident chunks and its registered active pattern. Neither the4096² optional stress nor the4096-chunk default maximum has been timing-admitted here. Active-core capacity is independently measured in64² cores;4096 core slots do not imply all16384 cores of a4096-chunk fully active world fit. Sleeping/excluded residency can still incur full clear traversal. Do not extrapolate the measured frame maxima linearly or assume an interest rectangle bounds resident memory/clear work.

## Owner decision worksheet

No numeric release budget is approved by this review. The following are recommendations for the next owner decision, not new configuration defaults:

| Decision | Evidence-backed recommendation | Required owner input before adoption |
|---|---|---|
| Required material state | Start from preservation of current fields; approve named extension semantics before selecting a wider carrier. Keep R16 provisional. | Actual field list, simultaneous combinations, ranges/units/defaults and lifecycle/transfer rules. |
| Resident/active envelope | Begin the design comparison at the measured256-chunk resident envelope and active512w4 pattern; separately account for intended larger residency. This does not lower production caps. | Maximum resident chunks, active cores/work pattern, excluded/sleeping fraction, worker configurations and multi-World use. |
| Memory | Use per-carrier arrays plus explicit temperature/scratch/activity/snapshot/allocator components. DUAL64 needs a justified16-byte commitment. | Whole-application/World memory budget, simultaneous owner/lease count, optional-field density and headroom/refusal policy. |
| Tick and hitch | Separate normal tick, clear-inclusive tick and worst-observed versus required bound. Keep all spikes and non-clear stalls. | Target hardware/platform, normal-tick budget, allowed single-frame delay, observation percentile/level and load profile. Historical1ms review trigger and16.67ms/60fps are not approved budgets. |
| Epoch/horizon | Evaluate E16 first when a wider candidate is needed; choose it independently of carrier. | Target tick rate/horizon, acceptable maintenance frequency and hitch, chosen semantic capacity after epoch bits. |
| Durability/rollback | Follow semantic GEN-006 identities and refuse unsupported required state. | Version/conversion policy, rollback checkpoint and accepted export/refusal behavior. No implementation starts here. |

For illustration only, fresh E8 clears at256 and then every255 completed ticks; E16 at65536 and then every65535. At an assumed60 simulation ticks/s these are first clears at4.2667s/1092.2667s and later intervals4.25s/1092.25s. Actual simulation pacing is independent of render pacing;60 is not an approved target. Wider epochs reduce event frequency without proving a shorter event, and approved load envelopes must still fit memory and scheduling capacities.

## Review gates and next step

1. Owner supplies or explicitly approves the field/lifecycle specification and grouped residency/memory, latency/platform and horizon requirements above. Missing values remain Ambiguous; silence does not approve a budget.
2. Reconcile those requirements against the C−40−E capacity table and a concrete bit map. Choose the smallest fitting baseline/compact candidate or justify DUAL64; no automatic promotion or truncating fallback.
3. Review construction/preparation, bounded refusal/quarantine, snapshots, conversion and schema identities. Qualify changed authoritative fields and maps with meaningful boundary and lifecycle tests across intended platforms; existing neutral-zero timing cannot substitute.
4. Only after identifying a specific unanswered performance question may a separate timing registration/admission/owner-execution process be proposed. No new campaign is started by this review.

Current source, runtime identities and accepted raw evidence are unchanged. This review is a documentation checkpoint; the schema/ADR corrections and owner worksheet are recoverable through the existing draft PR221. It claims no new runtime validation or owner/product sign-off.

The [concrete owner offer](mat003-concrete-owner-offer.md) proposes R16-T1 semantics, a256-chunk residency envelope, memory sublimits and prospective native latency/platform gates for explicit review. Its values are Planned recommendations, not owner-approved requirements, measured compliance, production changes or new timing authority.

## Owner budget disposition — 2026-10-23

The owner has now accepted the [concrete offer budgets](mat003-concrete-owner-offer.md) as qualification targets, superseding earlier budget-pending statements only. R16-T1 remains conditional, and carrier/epoch mapping, solver behavior, implementation and timing are not approved. The [bounded correctness-only plan](mat003-correctness-only-plan.md) is prepared for review, not execution. Reference-machine identity and proof of target compliance remain outstanding; both PRs stay draft and Current production is unchanged.
