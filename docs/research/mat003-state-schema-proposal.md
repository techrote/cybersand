---
title: MAT-003 semantic state-schema proposal
status: Planned
document-kind: design
scope: Proposed logical fields, capacity accounting, lifecycle and adoption gates; production carrier and persistence remain unchanged
canonical-for: [mat003-state-schema-proposal]
last-reviewed: 2026-10-23
related-documents: [mat003-continuation.md, mat-003prepass-state-inventory.md, mat-003prepass-epoch-consumers.md, mat-003prepass-gen006-handoff.md, ../decisions/ADR-015-material-state-schema-and-carrier-gates.md]
---

# MAT-003 semantic state-schema proposal

## Status and source boundary

**Planned:** this is a logical schema and decision proposal, not a production format or approved solver. [ADR-015](../decisions/ADR-015-material-state-schema-and-carrier-gates.md) owns the proposed shortlist and adoption decision; this document owns proposed field/lifecycle contracts. The [inventory](mat-003prepass-state-inventory.md) and material subsystem remain Current behavior authorities. No carrier, material catalogue, Water behavior, scheduler, user control or GEN-006 codec changes here. PR211/221 stay draft. No new timing is authorized.

Prepared from source checkpoint `a07983f369e1d83b7e927d9d74215f9c486fca3e`, whose production inputs remain unchanged from accepted prepass base `2b2a1dd64f16dc46d5e812b757de73f47df0fb2b`. The intake audit at `da5112c` and separate saved pressure prototype `7ef2aac` retain their historical identities. Required source files were compared against the accepted tree; this document does not turn the prototype into Current behavior.

## Proposed logical record

| Field or owner | Logical capacity and validation | Status and responsibility |
|---|---|---|
| Material identity | Preserve 16 storage bits losslessly; semantic admission uses the current byte enum/catalogue (IDs0–131 except10). IDs above that domain refuse through semantic APIs. | Current storage/domain distinction; catalogue widening requires a separate all-consumer proposal. |
| state_a | Preserve all16 bits for raw roundtrip; semantic setters retain material-specific limits, including current non-Water public refusal above255 and Water policy bounds. | Current storage requirement, not permission to enlarge mass/lifetime domains. |
| state_b | Preserve8 bits, including material-specific meanings and configured Water delay precision. | Current; Cloner/Rocket embedded IDs remain byte-domain constraints. |
| Update epoch | Separate scheduling/support stamp; E8 remains Current. E16 is the first wider candidate to evaluate, E24/E32 conditional. | Planned selection independent of material state, durability and physical carrier. |
| Material extension | Versioned typed extension whose width, unit, domain, default, initialization, mutation, transport and reset rules must be supplied by a future material/solver proposal. | Planned. No new authoritative field meaning assigned. |
| Temperature | Existing optional signed16 chunk-owned sidecar; logical default depends on recorded ambient configuration. | Current separate owner. Not silently folded into extension bits. |
| Activity/support/deadlines, ledgers, physics/discovery/history | Retain separate existing owners and their bounded lifetimes. | Current contracts; not an implicit per-cell payload. |

The schema is a logical tuple, not a native struct, enum expansion or serialization codec. Nonzero Empty state is significant. A material-only hash or occupancy rendering cannot establish record equivalence. High state_a boundary roundtrip and public semantic validity are distinct checks.

## Extension requirements and unresolved meaning

The saved pressure prototype uses16 formerly unassigned bits for flow/overfill or Empty-air state and separate World scratch/history. That establishes a concrete **candidate extension budget R16**, not a selected production solver or universal sixteen-bit payload. The inventory and GEN-006 handoff own its details and qualifications. No pressure unit, gas equation, conservation law, velocity vector, saturation policy or new Empty meaning is invented here.

Before assigning an extension, its owning proposal must specify material applicability; signedness, scale/unit and representable range; exact logical default; behavior on movement/swap/partial transfer/conversion/reinitialization; sleeping/interest/reentry effects; conservation/source/sink accounting; failure/refusal behavior; and schema/solver version identities. Unknown required extensions refuse admission rather than truncate or reinterpret. Optional reconstructible data needs a proof of reconstruction under recorded configuration. Unsupported authoritative data cannot be discarded just because its material is Empty.

R16 is an options-study input. A larger state requirement must justify its actual authoritative fields and access pattern, not allocate all C128 spare capacity by default. Future high-lane mutations were not timed by C128's neutral-zero campaign.

## Exact capacity accounting

The common material16 + state_a16 + state_b8 consumes40 bits. Remaining logical bits are C−40−E, before any new extension, independently of physical padding:

| Epoch | C64 | C72 | C80 | C128 |
|---|---:|---:|---:|---:|
| E8 |16|24|32|80|
| E16 |8|16|24|72|
| E24 |0|8|16|64|
| E32 |−8 (cannot fit)|0|8|56|

Thus R16+E8 can fit logically in C64; R16+E16 requires at least72 bits; R16+E24 at least80; R16+E32 at least88. These are arithmetic feasibility statements, not qualified layouts. C64 remains the baseline and must not be eliminated if requirements fit it. Optimized compact C72/C80 and DUAL64 remain the leading expansion options. C128 means128 total logical bits, not a128-bit epoch.

**No physical bit map is selected.** Current E8 uses epoch bits56–63 and spare bits40–55; the experimental E16 arrangement occupies48–63. Preserving the prototype's old bits40–55 while adding that E16 overlaps bits48–55. A proposed C72-E16 R16 map could use separate logical accessors over the remaining reserved/tail bits, or a newly defined contiguous map. Either changes the packing contract and needs independent qualification. Tested neutral tails are not a proven authoritative extension API. Never reinterpret old raw records under a new map without a versioned explicit conversion/refusal rule.

## Ownership and lifecycle invariants

**Planned adoption requirements:** native World retains exclusive authoritative cells; workers use its existing exclusive spatial domains and no Godot APIs. No per-cell physics object, lock, thread or hidden tick allocation is introduced. Compact access must remain defined memcpy/byte operations, with explicit endian semantics; DUAL64 uses explicit lanes and preserves unaffected bits. Whole-value movement/swap preserves all authoritative fields. Partial writes preserve unrelated fields. Material replacement applies the declared target schema defaults and conversion/ledger policy; it cannot silently reset source-owned history without an explicit rule. Current replacement semantics remain unchanged until an implementation is admitted.

Validate the complete incoming record before committing any field. Out-of-range IDs, extension values, incompatible schema, capacity exhaustion and invalid lifecycle state refuse atomically. Stage any required bounded sidecar allocation outside the prohibited tick path; a partial transfer cannot leave either cell changed after failed admission. Keep the failed-world quarantine, capacity outcomes, sleeping-region and interest pause/reentry contracts. Snapshot payloads stay immutable and independently owned; no mutable storage leaks to presentation.

Epoch clear resets scheduling stamps only, preserving material/state/extension/temperature and required scheduling/support behavior. Logical epoch width and counter arithmetic must agree; no signed overflow or accidental alias after rebase. Restore current-stamp predicates through a separately qualified method; raw epoch labels do not substitute for chunk incarnation, mutation version or durable identity.

## Physical budget and acceptance inputs

| Resident cells | C64 arrays | C72 compact | C80 compact | DUAL64/aligned arrays |
|---|---:|---:|---:|---:|
|512²|2MiB|2.25MiB|2.5MiB|4MiB|
|1024²|8MiB|9MiB|10MiB|16MiB|
|2048²|32MiB|36MiB|40MiB|64MiB|

At default128² chunks these are128/144/160/256KiB per cell array. Full temperature adds2 bytes per cell (8MiB at2048²), independently of other allocations. Scratch, activity, descriptors, immutable snapshots, allocator overhead and process RSS need separate accounting; do not double-count legacy component aggregates. No4096² admission follows from these calculations.

**Ambiguous, requiring owner/product decisions before adoption:** maximum resident population and active profile; dense/optional extension occupancy; memory and simultaneous-snapshot envelope; acceptable normal-tick cost; acceptable clear-frame hitch and pause policy; target tick horizon and platform matrix. No numeric release threshold is invented. The historical1ms review trigger is not an acceptance limit or frame-rate promise.

Use N+D/(2^E−1) only as a conditional steady model with carrier-specific measured N and incremental D. First clear is at2^E, later intervals2^E−1. E16's subsequent interval is257 times E8's, while the first-clear horizon ratio is256. Width reduces frequency, not the single hitch. WCLEAR's prepared-cache protocol and C128's naturally reached first-clear frame are separate datasets, not interchangeable D values. No carrier/epoch break-even has been established for the proposed R16 map.

## GEN-006 boundary and implementation gates

The [existing handoff](mat-003prepass-gen006-handoff.md) remains the canonical proposed durable contract. Persist semantic fields and required extension/schema/solver identity, not C++ objects, padding, raw U128 ABI or a copied scheduling epoch. Preserve nonzero Empty, temperature defaults, global clock/deadline phase and separately owned continuation state. Unknown required schema or unrepresentable legacy export refuses atomically; CYSD1 remains level reconstruction, not full continuation. This proposal implements no persistence/streaming or generator reconciliation.

Before production selection: reconcile actual source and field requirements; approve field semantics and owner budgets; define exact pack/unpack and reset/conversion contracts; qualify boundary values, unrelated-bit preservation, whole/partial updates, Water ledgers, temperature, granular support, lifecycle and failure atomicity across applicable workers; qualify epoch clear/rebase with resident/sleep/excluded chunks; complete meaningful sanitizers and intended platform matrix. Only then identify any unanswered performance question. Any new timing needs a separate frozen registration, independent admission and explicit owner execution authority. Existing neutral-zero evidence cannot qualify a changed high-state workload. No new timing campaign is started by this document.
