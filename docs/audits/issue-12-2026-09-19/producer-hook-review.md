---
title: Issue 12 current-World discovery producer review
status: Current
document-kind: evidence
scope: Dated source inspection of complete mutation/activity/inclusion hooks required before connecting the isolated discovery journal
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../../systems/settled-region-discovery.md, ../../architecture/soliding-lifecycle.md, ../../operations/soliding-measurement.md]
---

# Current-World producer completeness review

**Historical inspection, not by itself integration acceptance.** Reviewed current-main `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173`:
`native/src/world.cpp` Git blob `7df2777b3fa9a18c939f76eb9516a32ccbb60154`,
`native/include/cybersand/world.hpp` blob `602e17b97e45aef591d600f5616ff4a352071ab7`.
No runtime source was changed by this review. The isolated `SettledDiscovery`
journal is a viable consumer, but current World does not supply its required
complete invalidations/signals. A passing journal test is not evidence that an
unwired World produces those signals.

The later integrated implementation is assessed separately by the
[Stage-3 exit review](stage3-exit-review.md). This source audit remains the retained
matrix used for that review; its original baseline statements are not rewritten as
if production integration existed at `de332ea`.

## Hook matrix

All source symbols below belong to `native/src/world.cpp` unless named otherwise.
A producer must cover every row before marking a block's `witness_complete=true`.

| Mutation or observation | Current path and retained facts | Required producer action / safe point |
|---|---|---|
| Direct material edit | `set` changes tuple, epoch, counts; calls `mark_cell_dirty` and `wake_cell_neighborhood`. `paint_disc` delegates to `set`. | At successful actual change, synchronously invalidate the block and declared halo dependents before another summary read. Same-value no-op needs no payload revision. Same-tick remove/restore must still invalidate. |
| Direct state/material conversion | `set_cell_state` delegates to `write_cell(..., nullptr)`; Water-zero becomes Empty, state widths/validations are policy-owned. | Hook `write_cell`'s no-effects path via `mark_cell_dirty`, preserving actual state_a/state_b; do not duplicate Water or reaction policy. |
| Direct heat, including Empty heat | `set_temperature` allocates optional storage if needed, writes temperature, calls dirty/wake. | Same mutation witness as material; do not drop Empty-but-hot payload. Ambient reservation-only storage changes do not change material tuples. |
| Cellular movement/swap | `move_cell` writes both tuples and carries/swaps temperature; no-effects path marks both blocks. `relocate_stored_cell` uses this path for body displacement. | Invalidate both endpoints and their dependency halos, including same-material/state-looking swaps where position matters. Do not sample between the paired writes. |
| Water quantity/coherence transfer | `transfer_water` directly changes source/destination material/state, then effects-record or direct dirty/wake; `mix_after_motion` may perform additional existing-rule writes. | Cover both endpoints and follow-on effects; preserve wide public state_a and exact Water integer quantities. No new motion/interaction semantics. |
| Reactions/material state progress | `update_rule_kernel` and `update_water` use `write_cell`, movement, transfer and keep-active helpers. | Existing write/effects paths cover tuple changes; keep-active/deadline rows below cover deliberate no-write progress. Do not reimplement reactions in discovery. |
| Worker tuple writes | `write_cell`, `move_cell`, `transfer_water` use per-job `JobEffects::record` instead of direct dirty marking. Each job has <=16 touched-chunk entries with conservative min/max rectangles. | Never append to the shared journal from workers. In deterministic `tick_phased` barrier reduction, `merge_job_effects` already visits affected blocks; invalidate there. Measure conservative rectangle false invalidations. Effects overflow must halt discovery with the failed World. |
| No-write activity | `keep_cell_active` sets active/changed_this_tick/quiet_ticks without render dirtiness; called from kernels, including worker scans. | Do not infer rest from render state. Sample these block flags only after barriers, or record job-local activity for owner reduction. A global shared queue call inside this helper would introduce a race. |
| Deferred interaction wake | `schedule_interaction_wake` sets/minimizes per-block `next_interaction_tick`, potentially from a worker; does not dirty cells. | Treat any retained deadline as pending work until its owner consumes it. Feed after the barrier. Sleeping plus future deadline is not complete settled evidence. |
| Wake deadline consumption | `begin_tick` checks due deadlines, wakes included blocks, then clears consumed deadline; excluded phased work retains the deadline. | Reuse this existing block metadata pass to feed signal changes after updates. Preserve serial/phased distinctions and no catch-up policy; no offscreen rest credit. |
| Ordinary sleep/wake | `finish_tick` changes active/quiet ticks; `wake_cell_neighborhood` wakes neighboring blocks only when the cell is on a block edge and skips empty chunks. | Feed final activity from the existing finish pass. Neighborhood wake is not a complete soliding halo invalidator: it skips source, non-edge dependents and empty resident chunks. Define independent bounded dependency coverage. |
| Transient mask add | `set_transient_obstacle` writes body_id, appends occupied index and only calls neighbor wake. | Explicit local occupancy/mutation witness for the source block plus relevant halo. A mask does not own material. Material dirty flags alone miss this change. |
| Mask clear/reconfigure | `clear_transient_obstacles` iterates occupied indices, clears each and wakes neighbors; `configure_transient_obstacles` clears then replaces/resizes the mask field. | Feed removed and added coverage before discarding old coordinates. Mask set+clear between observations must invalidate, even if final mask and cells match. Local revisions avoid Phase 0's unrelated global-mask false invalidations. |
| Body contact without material change | `try_move`/`transfer_water` may only record contact. `record_transient_contact` has per-body atomic totals, no region coordinates. | Occupancy/halo exclusion is a conservative first policy. A future contact-specific eligibility witness needs source/target blocks recorded per job; aggregate body totals cannot locate contact invalidation. No worker calls into Rapier. |
| Accepted deferred explosion | `queue_explosion` adds a bounded command without dirtying cells; `apply_pending_explosions` later writes through set/write_cell and clears commands. | Invalidate/mark pending at acceptance for the radius+2 affected region and dependent halo, not only when it executes. Preflight bounded mapping/counts; clear pending only after successful event drain. Radius is <=256 by World validation (default64), not an arbitrary world scan. |
| Exclusion request | `set_simulation_region` changes `selected_core_region_` immediately; `applied_core_region_` changes at tick entry. | Old summaries must become nonconsumable immediately when requested inclusion changes, before a tick. Require entire block and declared halo within both selected/applied coverage. Define a global inclusion epoch/fence or bounded invalidation protocol; deferred queue processing cannot leave stale eligible snapshots. |
| Re-entry application | `begin_tick` reuses a resident block metadata pass to wake newly included coverage; `finish_tick` only ages fully included straddling blocks for phased mode. | Revalidate from fresh included observations; do not reuse prior quiet age. Custom single-worker blocks can straddle cores. Serial is a separate reference, not parity with phased. |
| New resident chunk | `ensure_chunk` is used by direct edits, reservation and owner-side `prepare_write_domain` before workers. | Register observation blocks at creation, before any consumer sees them; attach bounded slot/handle metadata without exposing mutable cells. Full observer capacity may refuse coverage but must not truncate simulation or label absent tracking as Empty. |
| Reservation-only creation | `reserve_region` creates empty chunks; `reserve_temperature_region` may add ambient temperature arrays. | Register new blocks as unknown until full scan. Material/temperature reservation itself need not pretend a tuple changed. Existing chunks are not recreated. |
| Live policy toggle | `set_liquid_surface_adhesion_enabled` changes rule behavior without touching activity/dirty metadata. Other transport/precision policies are constructor-owned. | Version/invalidate semantic witnesses or explicitly refuse unsupported live policy changes while tracking. Rebuilding a World for profile/policy changes requires new observation identity. Do not change #26 controls. |
| Clear / replace / move | `World::clear` destroys chunks/events and resets completed/attempt tick to0; World move operations are defaulted. Adapter reset/configure and `CyberDemoBridge::install` replace Worlds with swaps. | Retire the old journal/incarnation before reset or replacement; never feed clock0 into an old journal or retain handles to moved storage. Give a replacement a fresh nonwrapping identity and re-register. Define whether moves transfer the observer with the World or explicitly forbid active tracking moves. |
| Failed tick | `World::tick` catches after worker draining, sets tick_failed_ and rethrows; partial writes/events/epoch changes are quarantined. | Halt all discovery publication in this catch/global owner failure path before any snapshot can be consumed. It is insufficient to enqueue per-block unhealthy signals and wait for their budgets. Keep prior immutable render leases valid; no rollback or in-place retry. |
| Render dirty consumption | `take_dirty_chunks` and `RenderSnapshotExchange::publish` clear chunk dirty flags after consumption; `begin_tick` clears changed_this_tick. | Discovery requires independent durable mutation/pending witnesses. Never use render acknowledgment as discovery acknowledgment or allow begin_tick to erase direct-edit ABA evidence. |
| Epoch wrap | `begin_tick` periodically rewrites every resident cell's epoch, without material/state/temperature change. | Epoch is scheduling metadata, excluded from DiscoveryCell. Do not trigger a second whole-world cell scan or claim this inherited baseline cost is new discovery work. Preserve the separate long-tail benchmark population. |

## Safe coordinator sequence and boundedness

The initial World integration should remain opt-in, native-only, read-only and
cells-owned. The serialized World owner may feed direct edits before/after ticks.
For phased simulation, preflight registration occurs in `prepare_write_domain`,
then workers run without journal access; each existing ordered barrier reduction
feeds effects; final activity/deadline signals are available after `finish_tick`.
Publish/advance only after successful tick completion and after all immediate
owner mutations relevant to that observation have been fed. No new consumer may
read World concurrently with a native worker or the desktop exclusive owner.

`begin_tick` and `finish_tick` already traverse resident chunk/block metadata.
A first integration can piggyback signal updates on those passes without adding
a full-world **cell** scan, but the extra O(resident blocks) signal comparisons
are real producer overhead and must be counted. This does not make the entire
producer change-proportional. A later sparse signal stream is a separate measured
optimization. Existing effect-rectangle reduction can enqueue only changed blocks;
registration can follow deterministic chunk creation. Do not let unordered_map
iteration or worker completion timing define candidate/queue arbitration.

Current World accepts activity sizes1..1024 and chunk sizes8..1024. The journal's
default maximum1024 cells covers 32x32 tiles, not every valid World activity
block. Before integration, select and test an explicit supported geometry or a
bounded sub-tiling scheme, including partial edge blocks and negative coordinates.
Registering an oversized block must refuse visibly; silently capping its scan
would publish false uniformity. Map lookup, halo invalidation and chunk-creation
work need separate bounded counters/capacity outcomes; `advance(budget)` alone
does not bound all producer work.

World's public `get` reports transient occupancy as Wall, and `temperature`
reports ambient beneath a mask. Exact DiscoveryCell sampling must use
`stored_material`, stored states and a stored-temperature owner read, or enforce
fully unoccupied coverage for the whole scan. No mutable World reference may
escape. A mixed/blocked snapshot's `uniform` field is not a full payload.
`content_hash()` skips ambient Empty cells even if their stored state is nonzero;
exact hidden-state/heat tests therefore need direct tuple comparisons or an
appropriately scoped state hash, not content-hash equality alone.
World supports wide signed coordinates, but its helper arithmetic is not a proof
for arbitrary INT64 endpoints plus a halo: separately preflight registration,
chunk origins, source reads and halo expansion; test near both ends before
claiming the journal's endpoint tests establish World support.

## Concrete integration acceptance before witness_complete

1. Direct set/state/heat ABA before a tick and between bounded scans; source/dest
   movement, Water/coherence and reactions; render consumption between edits.
2. Phased workers1/4 produce matching summaries/revisions under a declared order;
   TSAN/sanitizers where available; no worker queue mutation; local effect rectangle
   over-invalidation is quantified rather than hidden.
3. Mask add/remove/reconfigure ABA, block-edge/halo/body-contact cases, blocked
   source heat and local support removal; unrelated far masks do not reset all
   quiet blocks unless explicitly retained as a measured conservative limitation.
4. Pending explosion before tick, deferred exchange deadline while asleep,
   no-write active material, partial inclusion and re-entry, requested-versus-applied
   window changes, reset/replacement and actual failed tick at/after a partial scan.
5. Configuration/slot exhaustion, oversized/custom blocks, unavailable coverage,
   signed coordinates and bounded producer budgets; feature-disabled exact control
   plus ordinary-sleep timings and unchanged material/work results.

This matrix identifies dependency-ready integration work, not permission to omit
any hook to gain apparent progress. If an initial wrapper cannot prove a row,
its affected blocks must remain witness-incomplete or tracking must explicitly
halt/refuse. Cross-block regions, stationary acceleration and ownership transfer
remain beyond this producer integration.
