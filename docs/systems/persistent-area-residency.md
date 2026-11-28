---
title: Persistent area native residency and write-behind
document-kind: contract
status: Current
canonical-for: [persistent-area-native-residency, persistent-area-cache-and-prefetch]
scope: Opt-in GEN-006 RAM cache, exclusive native ownership, bounded resources, asynchronous durability and predictive preparation
keywords: [GEN-006, HOT, WARM, COLD, residency, prefetch, durability, game time]
related-documents: [persistent-authored-areas.md, ../architecture/data-ownership-and-lifetimes.md, ../decisions/ADR-016-persistent-area-native-residency.md, ../operations/persistent-area-ramcache-evaluation.md, ../audits/2026-11-22-gen006-ramcache.md]
last-reviewed: 2026-11-27
---

# Persistent area native residency and write-behind

The opt-in RAM cache extends the [three-area contract](persistent-authored-areas.md).
It retains the same actor-free 512 × 512 Current/FreeMass native continuation domain and authored fixtures.
The [original campaign](../audits/2026-11-22-gen006-ramcache.md) records runtime and performance results. The [integration record](../audits/2026-11-27-persistent-area-world-integration.md) covers shared Workbench ownership.
Ordinary production defaults, native World limits and material/solver laws remain unchanged.

Resident travel, Save and normal exit wait for outstanding native edits. A collaborative Art turn can still own future work between native requests, as can an Architecture stage awaiting its receipt. Finish or Stop that work before changing areas. The ordinary Workbench retains its actor, Art and Architecture controls. The Persistent Areas profile refuses installation of an AMBIENT actor scene.

The persistent-area worker uses default material laws throughout resident handoff and fresh-process recovery.
Its Current scene audition control reports this limit before a law change can be queued.
The ordinary Workbench supports live audition. The persistent checkpoint format accepts the default material configuration.

## Independent state and authority

| Dimension | Authority |
| --- | --- |
| Active gameplay | Exactly one native World in the existing SimulationWorker adapter. |
| HOT inactive | Unique native ownership of an instantiated World plus its coupling/render bundle. It is not a byte buffer. |
| WARM | Complete validated CYPS2 bytes and authoring metadata in RAM; native reconstruction remains necessary. |
| COLD | Validated durable checkpoint referenced by the current/previous profile manifest. |
| Resident identity | Session, area, incarnation, runtime/source digests, native handle, resident/mutation generations, physics digest and completed tick. |
| Host companion | Worker-exclusive admitted MicroScenarioHost, original definition identity and matching actor-free Workbench sample/epoch. |
| Authoring | Original construction identity, current Setup, generated/Flatten baseline and camera envelope remain separate from dynamic World state. |
| Time | Main owns global completed frontier G and each area's accounted/native frontier; native receipts prove actual work. |
| Durability | The validated manifest ACK identifies the saved generation, independently of HOT/WARM status or later edits. |

`CyberPersistentAreaResidency` owns inactive `unique_ptr<PendingLiquidWorld>` bundles. Departure moves the
active World, Workbench coupling and RenderSnapshotExchange into a fenced resident entry. Activation moves
the target bundle into the same active adapter. No full World copy, CYPS decode, initial-source construction,
CYPS capture or full physical-state hash is required for an admitted zero-debt HOT transfer.
Published immutable render leases retain their own lifetime; freeing a resident does not invalidate a prior lease.

Main stages a one-use handoff ticket with exact serial, active generation, operation and target receipt.
The worker validates it and both native ownership receipts before the no-fail swap, restores the retained
host/sample epoch, invalidates derived presentation state and publishes a fresh ordinary Main acknowledgement.
Main serials identify activation; they do not counterfeit a new native Workbench body-sample session.
Old construction/continuation provenance remains unchanged; a separate resident observation describes current ownership.

No UI receives a mutable World/host/render pointer. Stale tickets, wrong identities, unsupported host dependencies,
double activation and stale receipt generations refuse. A changed area never silently reconstructs from its seed.

## Cache admission and eviction

`persistent_area_cache.gd` owns value metadata, LRU order, pins, dirty/durable fences and reservations;
it never owns a native pointer. Residency, dirty state, catch-up readiness and eviction eligibility are independent.
The configured admission budget is bounded to 8 GiB, with at most four reservations and bounded pins.
The native registry has a defensive 64-entry limit; the current product graph still has only three areas.

Cache reuse accepts an authoring envelope only after its native receipt or complete checkpoint matches
the admitted session, area, incarnation, source and physics identity. It bounds the complete envelope before
encoding, requires the original definition to remain in the validator's normalized JSON type domain, and
checks every canonical definition field against the already admitted source SHA-256. This includes all
geometry and transport fields; no source is projected, normalized again, truncated or reconstructed.
Store/native/worker validators remain authoritative for initial construction and persisted-state admission.
Cache reuse encodes the bounded authoring envelope once for memory accounting and identity, retaining
Setup, camera, generated starts and Flatten planes separately from native continuation. Packed-array or
numeric type aliases cannot impersonate an admitted normalized definition with the same JSON spelling.

Accounted use includes actual native container capacities, conservative growth allowance, warm payloads,
authoring envelopes and reserved preparation work. OS stacks, allocator overhead, Godot scene/UI objects,
presentation textures/GPU allocations and RSS
are measured separately. The budget is not a strict process working-set guarantee. The existing 128-chunk
native configuration remains unchanged. Private cold prefetch reserves three native growth bounds plus 64 MiB:
bootstrap adapter, authored candidate and restored World may coexist during construction. Ordinary cold
preparation on an already accounted adapter reserves two growth bounds plus 64 MiB.

Active/in-flight entries are pinned. Only an acknowledged active HOT receipt may use the mandatory-active
exception if the user shrinks below its cost; inactive HOT/WARM results still require valid admission.
Dirty entries cannot be discarded without a sufficiently new authoritative replacement. HOT → WARM captures
full continuation before releasing native ownership. WARM → COLD requires adequate durable state. Clean
direct HOT → COLD release is allowed. LRU and a 90% low-water target limit churn. Failed admission refuses
speculation or takes the explicit conservative durable fallback; it never truncates state.

Essential capture/encoding/publication has a separate single bounded 360 MiB working reservation. It blocks
new speculative reservations, shrinks to the bounded immutable batch requirement after capture, and survives
until the writer completion is reconciled. Memory pressure and a failed write cannot release the only dirty copy.

## Asynchronous persistence and explicit Save

Strict durability remains the experimental profile default. Deferred mode is an explicit session setting with
a visible RAM-only loss notice. Deferred HOT travel can complete after source retention and ownership ACK,
without forcing synchronous checkpoint publication. Capture takes an exclusive bounded owner boundary;
its interruption is measured rather than described as free or concurrent with native mutation.

`persistent_area_writeback.gd` gives immutable copied values to one I/O Thread. Bounded metadata sizing and
detachment happen on the caller and are timed. Checkpoint preparation, semantic validation, hashing and
OS-backed publication happen on the I/O owner. One in-flight batch and one coalesced metadata-only next request
bound the queue. Live Objects and oversized/unknown values refuse before thread transfer.

The existing immutable CYPA/current/previous manifest transaction remains authoritative. A detached capture
fence identifies its exact snapshot; later gameplay does not make that older snapshot the latest RAM state.
An ACK only advances the corresponding durable record. Newer mutations and global-clock changes remain dirty.
Explicit Save all captures all relevant dirty areas and the matching clock, waits for a positive durable ACK,
and reports success only for that boundary. Normal exit attempts Save and reports refusal rather than dropping RAM.

Before publication, a process crash recovers the last valid durable manifest and may lose RAM-only work.
After publication but before ACK, a fresh process validates the manifest to discover the committed generation.
Uncertain publication quarantines the operation. Repeated/stale writes cannot move manifest generations backward.
Runtime/schema incompatibility and corrupt/missing checkpoints refuse without seed regeneration.

Synchronous retained-state publication carries a bounded identity record through storage and native-release
acknowledgements. Retry validates the intended snapshot or its previous acknowledged manifest against the
retained native owner, complete capture/authoring identities and accounted clock. It does not reconstruct the
active World or repeat completed ticks. Reopening storage performs real filesystem validation; this recovery
path is separate from the zero-filesystem-I/O guarantee for an ordinary qualified deferred HOT transition.

In cached strict mode, successful validation and budgeted admission of a complete WARM candidate also admits
its verified accounted native interval, without an intervening asynchronous boundary. A publication failure
keeps that WARM authority and the source HOT World. Strict destination activation still waits for durability.
Retry plans from the retained native tick, so it cannot repeat completed candidate work. An abandoned preparation
reservation retires only after candidate discard and native owner release have actually acknowledged.
Cache-disabled restoration preserves the original private-candidate atomicity contract; its empty disabled
metadata ledger may be reinitialized after successful restoration, without clearing enabled resident authority.

## Predictive preparation and game-time admission

`persistent_area_connectivity.gd` declares the A/B/C graph, authored exit regions and directional priorities.
Explicit destination intent has priority; camera approach/motion and recent/adjacent areas provide weaker signals.
The metadata is not a square-grid residency assumption and does not pretend a persistent player actor exists.

One private preparation Thread receives only bounded copied authoring, capsule, identity and reservation values.
It owns a separate adapter/host, validates ordinary construction and full native continuation, and can execute
bounded legitimate catch-up while the active World continues on its existing worker. The worker joins it before
importing unique ownership. The UI receives copied receipt/timing values. A prepared destination remains inactive
until fresh Main admission. No speculative World publishes as active automatically.

Inactive HOT stepping uses the existing owner between active turns: at most two ticks/5 ms per speculative slice.
Private cold preparation admits at most 32 ticks/100 ms. Both check between indivisible ticks. Active authoring,
explicit travel, Save, essential durability and resource pressure take priority. A cancelled private candidate
can be discarded; a committed HOT slice returns its actual fresh receipt. Cancellation cannot erase executed ticks.

For completed global time G and area-accounted frontier A, debt is G − A. A background plan snapshots a bounded
legitimate target at or below observed G and fences that area's native/accounted generation. Unrelated active G
increases do not invalidate useful work. Completion credits only the actual delta once; changed target state or
replay refuses. Prefetch never increases G or credits unexecuted ticks. Partial progress/new debt remain visible.
Simulate Ahead pays debt before crediting actual future active ticks. No coarse time-skipping was added.

Foreground resident advancement retains its original canonical clock, bounded debt/future plan, admitted
prefix and exact pending native token outside the coroutine. Each successful slice admits the complete
native/cache receipt and its accounted prefix together, with no asynchronous boundary between them.
After an owner timeout, Retry consumes only that original request's proven contiguous interval. It does not
reclassify debt as ordinary active time or repeat work. The recovery record remains until native release
acknowledges, including cancellation followed by a second release timeout. Unexecuted requested future time
remains unfulfilled. Save, exit and another recovery operation refuse an unresolved interval.

## Failure and review boundary

Pending native/Main handoffs are retained through ownership and lease-retirement acknowledgement. Recovery must
reconcile the exact transaction and resident authority; loading older durable state over newer dirty RAM is not
a valid generic Retry. Failed preparation retains the old World. Late/incompatible completions refuse.

An actually failed active tick remains quarantined. The explicit recovery planner can preserve healthy inactive
captures while retaining the failed area's prior durable record. Recovery time is bounded by observed time and
captured native work. Omitted RAM-only time is reported; partial rescue is not Save all. It neither certifies a
partial failed tick nor silently resets/discards the failed active World.

A known terminal failure during active resident advancement can retire its pending request only after an
exact failed receipt identifies the same native owner, original start tick and actual successful prefix.
Only that prefix is accounted; the failing tick is never credited. Native release must acknowledge before
the request guard clears. The active World stays quarantined, allowing the existing explicit healthy-area
rescue and disclosed recovery close. Ambiguous outcomes and failed inactive targets remain pinned; this
narrow active-failure rule does not admit a general failed-World continuation or inactive rescue path.

`run_persistent_area_ramcache_qualification.py` extends donor gates with actual native residency, value-boundary,
clock/replay, write-behind death/reopen, Main cache/prefetch, memory and controlled cold/HOT/WARM tests. The isolated
publisher retains pinned inputs, target-OS execution, exact custody, original logs and four-path runtime publication
under a branch lease. Local diagnostic builds remain separate. Physical NVIDIA playfeel, larger canvases,
actor/Rapier persistence, cross-area flux, selective chunks and recipe reconciliation remain future admissions.
This does not complete GEN-006 #194.
