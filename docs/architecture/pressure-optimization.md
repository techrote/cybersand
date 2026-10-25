---
title: Bounded pressure cache and Water motion certificates
status: Current
document-kind: design
scope: Accepted-main LCB-002 cached and cached_dormant implementation — derived head and sealed-component caches, conservative motion certificates, execution identity, source-qualified cost and remaining product/platform boundaries
canonical-for: [pressure-optimization, pressure-motion-certificates]
last-reviewed: 2026-10-25
related-documents: [pressure-flow-v1.md, liquid-solver-family-policy.md, liquid-state-transition-matrix.md, liquid-prepared-setup-and-receipts.md, ../reference/configuration-reference.md, ../reference/invariants.md, ../audits/2026-10-25-lcb002-pressure-variants.md]
---

# Bounded pressure cache and Water motion certificates

## Source and admission boundary

**Accepted on main through [PR #253](https://github.com/techrote/cybersand/pull/253)**
at merge66051129, with the moving-mask gas correction, source-matched runtimes,
full exact-head gates and independent review. Accepted Brine union #250 later
merges as dc915f2b with the same pressure law. The branch checkpoints below
retain their historical source, cost/failure and then-pending acceptance scope;
they do not constitute new full-host/Web or universal speedup evidence.

**Historical checkpoint on `codex/lcb002-pressure-variants`; Windows/Linux
scoped publication passed, while full ready-PR acceptance was then pending.**
[Publication run `40152121412`](https://github.com/techrote/cybersand/actions/runs/40152121412)
executed import plus all13 required cases on each target OS; the
[dated publication record](../audits/2026-10-25-lcb002-pressure-variants.md#source-matched-windowslinux-publication--2026-10-25)
binds source `8354e3a6`, bot append `d726bf34`, exact payloads and strict coverage.
This branch extends the accepted #246 native
contract. Water admits `pressure_flow_v1` variants `reference` (0), `cached` (1)
and `cached_dormant` (2), with the same physical parameters, material stages,
gas identity and Water quantity law. Other material/family compatibility remains
source-derived; unsupported requests refuse before session replacement.

The production Water default remains `freemass_v1`. A cache miss or incomplete
derived result executes the complete admitted pressure reference operator.
Reference capacity failure retains the failed-World quarantine contract. These
variants never substitute FreeMass, a default material kernel or GDScript.
The [pressure reference](pressure-flow-v1.md) owns the physical law; this page
owns the additional derived execution mechanisms and observations.

| Piece | Source owner |
|---|---|
| Requested budgets, execution version, counters and copied status | [`pressure_optimization.hpp`](../../native/include/cybersand/pressure_optimization.hpp) |
| Sparse index, dirty closure, certificate invalidation/proof, extension identity | [`world_pressure_cache.inc`](../../native/src/world_pressure_cache.inc) |
| Preallocated index/component state | [`world_pressure_cache_state.inc`](../../native/src/world_pressure_cache_state.inc) |
| Sealed-component discovery reuse | [`world_pressure_gas_cache.inc`](../../native/src/world_pressure_gas_cache.inc) |
| Reference preparation and shared authority reducer | [`world_pressure.inc`](../../native/src/world_pressure.inc) |
| Native acceptance | [`test_pressure_optimization.inc`](../../native/tests/test_pressure_optimization.inc), [`test_pressure_gas_cache.inc`](../../native/tests/test_pressure_gas_cache.inc), [`test_pressure_variants_acceptance.inc`](../../native/tests/test_pressure_variants_acceptance.inc) |
| Copied Godot observations | [`pressure_optimization_inspection.inc`](../../godot/native_extension/pressure_optimization_inspection.inc) |
| Total-cost apparatus | [`lcb_pressure_optimization.cpp`](../../native/bench/lcb_pressure_optimization.cpp), [`pressure_optimization_cost.py`](../../tools/lcb/pressure_optimization_cost.py) |

## Derived heads and conservative fallback

The owner indexes resident chunk coordinates into sparse column and row groups.
It marks affected columns and repairs their complete vertical closure, including
foreign-liquid boundary loads. A changed base head dirties the corresponding row
closure. Final heads use the reference interpolation and feed the same motion
kernel. Required wake scans still run every tick, including cache reuse ticks.

Dirty group queues and bitmaps have admitted capacities. An incomplete index or
insufficient repair budget selects a complete reference preparation before
publishing a partial head answer. The snapshot distinguishes cold, pending,
ready, reference-capacity fallback and reference-budget fallback. Those statuses
describe derived execution, not a different physical solver.

## Sealed gas discovery reuse

The cache reuses only the BFS discovery of a proven unchanged, sealed positive-ID
component at its actual first reference seed. Global resident seed census/order,
union/identity reduction, ancestry/history and final relabelling remain the
reference operations. This implementation therefore retains global work; it is
not an O(affected-region) claim for the complete gas operator.

Each cached member is an 8-byte chunk-slot/cell-index pair. Component bounds plus
one chunk and a preallocated dirty-chunk queue conservatively revoke membership
when labels are erased, components join or paused resident chunks change. The
component/dirty-chunk proof has its own pair budget. Missing or stale members,
or a dirty BFS reaching an assumed clean component, request one complete
uncached restart **before** authoritative gas reduction. Successful fallback
uses an explicit flag rather than an exception as control flow.

A whole-operator fixed point requires both table/topology and final gas labels
to be unchanged, with no discovery allocations. This includes final sanitation
of unvisited labels whose compartment retired beneath a body mask; reference,
cached and dormant variants share that authority repair. Still-live masked
labels remain intact. The [repair evidence](../audits/2026-10-25-pressure-moving-mask-gas-retirement.md)
retains the six-arm failing control and pending acceptance. Equal compartment amounts alone
do not establish that fixed point. Gas resolution revokes all Water motion
certificates because a remote volume/gauge change can alter a local gradient.

## Motion certificates preserve ordinary obligations

`cached_dormant` can skip only the pressure motion stage of a Water update.
Chemistry, material lifecycle, WaterUpdate events, other liquids and ordinary
scheduler ownership continue. This confers no generic region/chunk skip authority.

A fresh proof requires full Water, zero cohesion, zero flow and zero overfill;
the relevant prepared head; closed down/diagonal/lateral destinations; and a
gradient inside the reference start dead band. Any body mask within the 5×5
stencil declines the certificate. Failed gravity and diagonal probes can report
stationary body contacts and signed impulses even when the Water pixels do not
move. Pixel stability or zero rounded transport is therefore insufficient.

Pending explosion obligations and non-unit Water cadence decline the shortcut.
An actual same-job mutation touching the stencil immediately takes ordinary
motion, rather than proving against a pre-tick head after local writes. Owner
barriers revoke neighbouring certificates for producer edits and head changes.
Reconstruction never restores cached certificates as authority.

**Execution version 3** retains the earlier bounded proof retry law. A cold
or invalidated stencil first takes one eligible ordinary visit. A failed complete
proof defers eight further eligible visits before retrying. Only the exact valid
tag can skip motion; countdown bytes transition directly to cold, never to valid.
Changed inputs restart warmup. These constants control derived work, not physics,
rest tolerance or simulation cadence.

Execution3 also admits the whole certificate layer. Unusable heads/index disable
it without stamping certificate arrays. Cached1 allocates no unused certificate
buffer. While disabled/cold, producer or gas invalidation marks contents cold in
constant time; reactivation performs one bounded, charged cold reset before any
certificate read. Actual Water material calls in a preceding tick are required
before cold activation, so an already sleeping zero-visit World does not pay
periodic full-resident resets.

Each eight-eligible-tick trial charges one work credit per invalidated certificate
cell (including cold reset),40 per complete proof attempt and one per valid reuse;
each actually saved motion call supplies eight credits. A positive-cost zero-saving or
credit-deficit window suspends the layer for32 eligible head ticks. All ordinary
motion, body probes, material/cadence work continues while suspended. Uncertain
arithmetic conservatively declines admission. These are fixed deterministic
**work-budget weights**, not measured nanoseconds or a proof of wall-clock
break-even on every machine. Final total-cost measurements remain required;
slower outcomes stay visible.

## Capacity, storage and identity

| `WorldConfig::pressure_optimization` field | Default | Outcome when incomplete |
|---|---:|---|
| `index_chunk_capacity` | 4096 | Complete reference preparation |
| `head_repair_cell_budget` | 4,194,304 | Complete reference preparation |
| `gas_member_capacity` | 1,048,576 | Complete gas discovery |
| `gas_invalidation_pair_budget` | 4,194,304 | Complete gas discovery |

Scratch is reserved at admitted construction/preparation boundaries. There are
no per-cell locks or atomics. The seven per-job counters occupy 56 bytes per
admitted job slot in pressure Worlds; 4096 slots use 229,376 bytes. An additional
pointer in each common job record is excluded from that56-byte worker record
and from `common_counter_bytes` (which reports the owner counter object only).
The benchmark does not expose a separate common-job pointer-capacity field;
this overhead is included in process RSS. Derived storage and owner counter
bytes are reported independently. Declared capacities exclude
allocator overhead, shared engine storage and process RSS; they are not a
complete World memory figure. C64-E8 and the default Cell carrier remain intact.

The native optimization identity retains encoding version 1 and its domain,
then hashes six little-endian u64 words: **execution version 3**, variant 1/2,
and the four requested budgets in table order. This distinguishes execution
semantics from the pressure physical parameters. Reference has no optimization
extension identity. Cache contents, timing counters and certificates are derived,
not serialized physical authority; save/restore rebuilds them conservatively.

The full physical hash still distinguishes the applied family/variant policy.
Requested optimization budgets and their execution identity are bound separately
by native receipt/readback, not added to physical authority: changing only a
budget changes the extension digest while leaving the physical hash equal.
Named comparison projections separately support pressure-variant equivalence
at the same tick and static-content observations across ticks. Neither is a
replacement for the complete continuation hash or an authorization to skip work.

## Readback and measurement

`World::prepared_pressure_head(x,y)` copies one existing derived slot, with
`FamilyUnavailable`, `NonResident`, `NoHead`, `Unresolved` or `Prepared` status.
`copy_pressure_head_chunk_coordinates(span)` copies the actual resident roster
without allocation; insufficient output capacity leaves the span untouched and
returns the required count. Consumers can sort the copied values and cover chunks
made resident by gas discovery as well as authored/preallocated regions.
A valid zero head is distinct from no head. Numeric Water mass units are meaningful
only for `Prepared`; unresolved interpolation sentinels retain their explicit
status. The value is from the last pre-kernel preparation and can be stale after
transport or host writes, or unprepared after restore. The getter allocates and
prepares nothing and grants no freshness or skip authority.

The exclusive native adapter owner can call `inspect_pressure_optimization()`
for copied status, actual optimization identity, requested budgets, observed
capacities and53 cumulative work counters. The separate `certificate_admission`
dictionary exposes the actual enabled/cold state, trial/suspension, fixed weights
and current/last window charge/credit. Certificate buffer capacity is explicit;
cached/reference arms report zero. Schema 1 encodes all unsigned budgets,
capacities and counters as **decimal strings**, preserving the entire native u64
range instead of narrowing through Godot's signed integer. Status/version fields
are small integers. Counter differences describe a measured interval; attempts
count complete local proofs, while declines also include warmup/backoff and
mandatory-obligation deferrals.

`get_liquid_comparison_hash(1 or 2)` returns a 16-digit hexadecimal projection.
Unknown IDs or an unavailable World return an empty string. Readback exposes
neither mutable World storage nor certificate authority. The owner must serialize
these calls with simulation as with the existing pressure inspections.

The total-cost apparatus uses one immutable optimized binary for all three arms,
rotates order across five replicates at workers 1/4, and times complete ticks.
Constructor/setup, host edits and verification are separate intervals. It retains
cold initialization, warm repair/validation, disturbed continuation, explicit
capacity/budget fallback, allocation counters, declared memory and process RSS.
Actual task-claiming participants are reported independently of configured workers.

Six registered profiles cover awake stationary Water, ordinary sleeping Water,
two sealed rooms with a local edit, remote gas plus moving native masks, continuous
topology churn and four explicit fallback subcases. Every raw replicate and
slower result is retained. Old execution1 measurements remain tied to their
source and cannot be reattested as execution3 performance. Execution2 correctness and
fixture qualification likewise keep their earlier source identity. Numerical prepared-head
discrepancy and declared-region net Water boundary balance are separate observations;
neither should be inferred merely from equal projections or work counts.

## Acceptance and remaining application work

The [dated branch evidence](../audits/2026-10-25-lcb002-pressure-variants.md) owns
executed test, campaign and runtime identities, preserved failures and missing
gates. Native tests include remote heads/drains, sparse negative-coordinate
seams and interest changes, narrow/broad communicating basins, incoming momentum,
gas venting into an already certified target, cadence/chemistry/conversion,
pending events, reconstruction and moving/rotating native masks.

Native mask parity does not establish actual Rapier rotation/displacement or
full application constructor support. Those host/platform checks remain #202
and integrated #203 work. The full ready-PR Documentation/provenance, Native,
Windows/Linux Godot and applicable Water apparatus gates remain required before
this branch merges. Current defaults and earlier pressure characterization
retain their original source/artifact qualifications.
