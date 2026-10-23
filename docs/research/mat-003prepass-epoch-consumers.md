---
title: MAT-003PREPASS epoch consumer inventory
status: Current
document-kind: reference
scope: Source inspection at da5112c of native update epochs, indirect support consumers and separate fallback bookkeeping; isolated S1 World evidence is separately qualified
canonical-for: [mat003-epoch-consumer-inventory]
last-reviewed: 2026-10-22
related-documents: [../architecture/chunk-tile-and-buffer-model.md, ../architecture/data-ownership-and-lifetimes.md, ../systems/activity-dirty-regions-and-waking.md, ../systems/granular-interaction-policy.md, ../reference/level-saves-and-replay.md, ../operations/cell-layout-experiment.md]
---

# MAT-003PREPASS epoch consumer inventory

## Source and evidence boundary

**2026-10-23 continuation:** [WCLEAR-001](mat003-continuation.md#wclear-001-exact-proposal-and-correctness-boundary) prepares actual wide clear events with the equality-predicate audit below, explicit natural/prepared labels and separate observer/off qualification. Its timing remains unadmitted; accepted S2A E8 clear inclusion and E16 no-clear horizon remain unchanged.

**Current source inspection, 2026-10-22:** this inventory is bound to
`da5112c066416346d6fe3984d4161cd162611e50`, the planning and execution baseline
for [issue #204](https://github.com/techrote/cybersand/issues/204). It describes
checked-in consumers and derives their required tests; it reports no new World
runtime, performance, platform or production acceptance.

The isolated storage prototypes have a separate
[S0 registration](../../tools/experiments/mat003_prepass/registration.json).
Their synthetic counter/clear exercises do not qualify a widened native World.
The [S1 checkpoint](../audits/2026-10-22-mat003-world-correctness.md) separately
records the real native World adapter, exact per-tick records and observed scope.
Its registered Linux normal/sanitized matrix and independent readback passed.
Natural E16 coverage is one phased worker and 256 resident cells; four-worker
ordinary execution and large forced clears are separate coverage. The broader
gates below remain Planned unless that report explicitly qualifies their tested
subset. Preserve the
unmodified production control and all existing physics.

Search coverage was `epoch`, `update_epoch_`, `epoch_value`, `set_epoch`,
`PrecisionStorage`, raw carrier writes and indirect support calls across native
source/headers/tests/benchmarks, the native Godot extension, script fallback and
experiment tools. All direct native cell-stamp consumers are in
[`World`](../../native/src/world.cpp). Other names containing epoch are kept
separate below; lexical similarity does not establish common authority.

## Native representation and counter

**Current:** [`PrecisionStorage`](../../native/include/cybersand/precision_storage.hpp)
uses a `uint64_t` word and enforces size/alignment 8/8 bytes. Its current map is:

| Field | Bit offset | Width | Accessor or owner |
|---|---:|---:|---|
| Material storage | 0 | 16 | Accessor returns the byte-underlying `Material` enum |
| `state_a` | 16 | 16 | `uint16_t` accessor/setter; valid material semantics remain separately constrained |
| `state_b` | 32 | 8 | `uint8_t` accessor/setter; Water delay mask is separately parameterized |
| Unassigned | 40 | 16 | No production field |
| Update epoch | 56 | 8 | `uint8_t` accessor/setter and an eight-bit mask |

[`World::update_epoch_`](../../native/include/cybersand/world.hpp) is independently
`uint8_t`, initialized to zero. `World::begin_tick` explicitly casts its increment
back to `uint8_t`; zero triggers an all-resident cell-stamp clear and a restart at
one. Widening only the carrier therefore does not widen the executable lifecycle.
The declaration, increment/narrowing, mask, accessor, setter and every consumer
must agree before an engine candidate is valid.

From a fresh zero counter, the source implies first clear at tick 256, then every
255 ticks: `256, 511, 766, 1021, 1276, 1531, 1786, 2041` in 2,048 uninterrupted
ticks. The equivalent proposed 16-bit lifecycle would first clear at 65,536 and
again at 131,071. These are arithmetic expectations, not observations of a
16-bit World. Zero remains reserved for unprocessed/reset stamps.

## Direct native consumer inventory

**Current source:** line locators below refer to the inspected baseline, not to
future experimental edits. The authoritative implementation is
[`native/src/world.cpp`](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp).

| Consumer | Baseline location | Meaning and widening obligation |
|---|---|---|
| `World::Chunk` construction | 229-240 | `Cell` aliases `PrecisionStorage`; new arrays are filled with `for_material(Empty)`, whose word/stamp starts zero. New storage must be eligible at the correct first tick without inventing a current-epoch stamp. |
| `granular_support_at` stability predicate | 1336-1359 | Hard surfaces are stable; an eligible grain is stable only at tick zero or when its stamp differs from the current epoch. Active excluded work is rejected separately. This is externally observable support, not disposable hash bookkeeping. |
| `write_cell` | 1493-1512 | Same material/a/b returns without writing or stamping. Actual state/conversion writes replace the cell, write both state fields, then stamp current epoch. Preserve no-op, conversion and reset behavior. |
| Public `set` | 1671-1685 | Same-material edits return unchanged. Actual replacement initializes material state, handles Water mass, then stamps. External edits between ticks affect immediate support and next-tick eligibility. |
| `clear` | 2289-2314 | Retires discovery, clears chunks/events/scratch and failed status, resets both tick indices and epoch to zero, then initializes a new discovery incarnation. No retained stamp may leak into the replacement world. |
| `move_cell` | 2378-2385 | Destination receives the complete source carrier. Source receives displaced destination on swap or fresh Empty on move. Both endpoints are stamped; temperature follows the separately implemented movement policy. |
| `exchange_permitted` | 2420-2443 | After permeability/cadence checks, the target must not have participated in the current epoch. This enforces a shared once-per-lane rule for grain/liquid exchanges. |
| `transfer_water` | 2530-2539 | Partial/full transfer stamps both endpoints, merges coherence with maximum, and resets exhausted source to Empty. Do not lose full `state_a` mass precision or change the transfer ledger. |
| `mix_after_motion` | 2595 | Rejects an already-stamped grain before pickup/carrying. A wider counter must preserve flow eligibility, not merely the main scan result. |
| `update_cell` entry guard | 3502-3505 | Missing storage or current stamp suppresses work. Transient obstacle and rule checks remain independently authoritative. |
| `update_cell` post-kernel test | 3515-3519 | An unchanged source schedules its pending reaction wake only if its stamp still differs. Epoch decisions can change future activity/deadline work even when present-tick material output looks identical. |
| `begin_tick` increment/clear | 3524-3535 | Increments global tick and byte epoch, clears every allocated chunk on overflow, restarts one. Sleeping and interest-excluded resident chunks are included. Clear changes stamps only. |
| Tick-boundary events | 3596-3601; `apply_pending_explosions` at 2235 | Events run after clearing and change-flag reset. Their calls to `set`/`write_cell` stamp new material so its ordinary material rule starts on the following tick. |
| Serial scan | 3685 | Checks current stamp before rule eligibility and before incrementing `visited_cells`. Preserve serial semantics separately from phased ordering. |
| Phased single-chunk fast scan | 3768 | Same suppression predicate on the optimized indexing path. An experiment must not qualify only the slower general path. |
| Phased cross-chunk general scan | 3789 | Same suppression across signed storage seams and general geometry. Test both addressing paths. |
| `state_hash` global record | 4192 | Includes `update_epoch_`, along with tick, failed state, regions, configuration, pending events and activity metadata. Raw equality is representation dependent. |
| `state_hash` per-cell record | 4273 | Includes each cell stamp as well as material, full accessor state and temperature. Semantic parity needs an independent epoch-free record plus explicit scheduling/support assertions. |

All direct production carrier assignments and field setters inspected in World
are in construction, `write_cell`, `set`, `move_cell` and `transfer_water`.
Reaction kernels reach the same stamped write helpers; there is no separate
production reaction epoch width to change. Temperature and activity deadlines
have their own storage and are not spare epoch bits.

## Indirect adapters, snapshots and identities

**Current:** no native C/Godot binding exposes a raw per-cell update epoch, but
bindings do expose its effects. In
[`cyber_native_cell_world.cpp`](../../godot/native_extension/cyber_native_cell_world.cpp):

| Caller | Baseline location | Observable dependency |
|---|---|---|
| `accumulate_granular_bearing` | 725-773, query at 736 | Support sample count drives body bearing impulse and bounded correction. |
| `character_box_collides` | 843-864, query at 860 | Sampled feet, side and head collision decisions include granular stability. |
| `character_disturb_granular` | 865-919, query at 907 | Disturbance eligibility checks stored granular support before relocating material. |
| Diagnostic/hash dictionaries | 1610-1611, 1638 | Publish content/state hashes, so raw hash differences must be classified. |
| Fresh/reset/diagnostic World installation | 244, 263-310, 1400-1404 | Builds a candidate World then replaces ownership; a new zero-counter lifetime must not inherit old scheduling/support state. |

The [C API](../../native/src/c_api.cpp) delegates tick, clear and state/content
hash operations to World. Its legacy tick wrapper catches errors and returns an
empty result; a test must explicitly check failure/status and progress rather
than accepting exit zero or empty statistics as a completed tick.

[`hash_integer`](../../native/src/world.cpp), line 71, hashes `sizeof(Integer)`
bytes. Changing a counter/accessor type from eight to sixteen bits therefore
changes raw `state_hash` encoding even when the numeric epoch is below 256.
Do not repair comparison failures by narrowing the candidate hash input; use
the registered independent semantic record and preserve same-schema hash checks.

[`demo_snapshot.hpp`](../../native/include/cybersand/demo_snapshot.hpp) explicitly
omits tick epoch and scheduler queues from CYSD1. `reconstruct` creates a fresh
World, then writes material/state/temperature into it. Native bridge
[`import_level`](../../godot/native_extension/cyber_demo_bridge.hpp) installs that
candidate. This is a finite-level reconstruction, not continuation restoration.
Its tick-zero granular-support exception and first-update behavior must not be
silently promoted to GEN-006 reload semantics. CYSD1's byte `state_a` record is
also narrower than the current carrier accessor.

**Current distinct authorities:**
[`SettledWorldDiscoveryCoordinator`](../../native/include/cybersand/settled_world_discovery.hpp)
has `world_incarnation`, revisions, deadlines and separate requested/applied
inclusion epochs. The [physical actor session](../../godot/scripts/physical_actor_session.gd)
and [simulation snapshot](../../godot/scripts/simulation_snapshot.gd) also have
session/body epochs. None is the per-cell update stamp. GEN-006 world/session,
chunk incarnation, mutation and stale-job/save/reconcile receipts must remain
separate identities.

## Script fallback is a separate lifecycle

**Current fallback source:** [`cell_world.gd`](../../godot/scripts/cell_world.gd)
stores stamps in a `PackedByteArray updated_at` (line 290), with an integer
counter initialized/reset to **one** (319, 395). `simulation_tick` increments it,
clears the stamp array above 255 and restarts one (1096-1099). Consequently its
first clear from that fresh state is tick **255**, not the native first tick 256.
This is a source-derived distinction, not a newly executed fallback result.

| Fallback consumer | Baseline location | Meaning |
|---|---|---|
| Body material relocation | 948-949 | Stamps both moved endpoints. |
| Ordinary scan and Smoke dissipation | 1261, 1283 | Suppresses already-touched cells; dissipation stamps a write. |
| `try_move` destination guard | 1412 | Refuses reuse of a destination touched in this tick. |
| `try_move` endpoint stamps | 1443-1444 | Always stamps destination, but stamps source only for swap or same-row move. A vertical Empty vacancy remains available. This differs from native `move_cell`. |
| Material replacement | 1547 | Stamps the changed coordinate. |
| Sparse free-flight lookahead | 1722-1723 | Both route cells must be untouched. |
| Lateral liquid dispersion | 1840 | Chooses an untouched candidate along its allowed route. |
| Coherent-liquid diagonal decision | 1943 | Rejects an already-touched below cell. |

The fallback has its own flow fields, finite geometry and rules. Preserve it as
an explicitly separate compatibility surface. Do not copy its conditional
source stamping into native experiments or treat native/fallback trajectory
agreement as an existing contract. Native Web profiles compile native World;
they do not become this script fallback merely because the platform is Web.

## Lifecycle and measurement traps

**Current source and inherited evidence limits:**

- The stamp means a write/move occurred in the current epoch; it is not a count
  of attempted visits. No-op writes must keep their present behavior. The
  post-kernel pending-wake test makes this distinction observable later.
- `granular_support_at` reads the most recently completed tick, exempts tick
  zero, rejects paused active grains outside selected coverage, and permits
  sleeping support. Resetting every stamp on reload without a phase-aware rule
  can change support even if the next ordinary scan looks correct.
- A clear touches every allocated carrier, without changing material state or
  publishing a discovery mutation. It must preserve optional temperature,
  neutral tail payload and unrelated bits in an experimental representation.
- `World::tick` quarantines partial cell/event/epoch/metadata progress on failure
  (4149-4157); `clear` or replacement is required before continuing. A failed
  rollover attempt is not a successful natural tick or recoverable continuation.
- Global `tick_index_` drives deterministic direction, scan order, temporal
  reaction lanes and permeability deadlines. Forced counter seeding must state
  whether global time is held or advanced; it is not a natural 131,080-tick run.
- Historical [`soliding_baseline.cpp`](../../native/bench/soliding_baseline.cpp)
  and [`stage3_cost.cpp`](../../native/bench/stage3_cost.cpp) classify clears with
  `tick > 1 && (tick - 1) % 255 == 0`. The
  [ordinary-sleep reducer](../../tools/experiments/summarize_soliding_baseline.py)
  checks the same expression. Preserve these dated controls. A wide-epoch
  apparatus needs explicit observed clear records and a versioned period.
- Historical [#16's comparator](../operations/cell-layout-experiment.md#semantic-and-memory-records)
  encoded byte `state_a`; it cannot be reused unchanged for the current
  sixteen-bit accessor. Keep nonzero Empty state and resolved temperature.
- `visited_cells` counts after stamp/rule filters, not all inspected addresses.
  Ordinary quiet worlds can have zero visits with metadata/clear cost. Report
  those costs directly; never divide by zero or infer absence of scans.
- A configured four-worker fixture can remain below dispatch threshold. Existing
  compact fixtures alone do not establish concurrent carrier access. Record
  actual dispatch or use a separately registered threshold-one fixture.
- `resident_cell_bytes()` includes cells, optional temperature and activity
  capacities. Do not add the aggregate to its own components. Actual padding,
  descriptors, sidecar allocation, scratch and process memory remain separate.

## Planned full-World qualification gates

These gates define the next engine experiment; **none is satisfied by this
source inventory or by S0 storage-only tests**. Exact layouts, source/tool hashes,
capacities, fixture inputs, workers, process limits and stop rules must be
registered before those runs. Correctness precedes candidate timing.

| Planned gate | Required fixture/observation |
|---|---|
| Control bridge and ordinary schedule | Preserve the actual unmodified C64-E8 control; compare it with the abstraction-matched control and each admitted representation for 2,048 equal ticks. Canonical records retain `material16/state_a16/state_b8/temperature16`, independent of padding/epoch. Retain work/events, Water mass and nonreactive species totals. |
| Natural real E16 rollover | A fresh widened World runs at least 131,080 uninterrupted ticks. Observe clear ticks 65,536 and 131,071 and subsequent behavior; ordinary E8 has 514 clears over that horizon. Assert no missed/double updates and equal support/transport/pending-wake decisions at registered samples. |
| Large resident boundary stress | Forced boundaries at 512 squared, 1024 squared and 2048 squared resident scales include sleeping and excluded sentinels. Record seeding and global-time/RNG assumptions. Verify exact clear membership and unchanged non-epoch fields. |
| Mutation and movement | Signed 64/128-cell seams, serial and both phased scan paths, move, swap, partial/full Water transfer, reaction reset, neighbor-only reaction and prewritten explosion destinations. Check one intended lifetime decrement/move and exact conservation/ledgers. |
| Support and interaction | New/moved/transformed grain, settled grain, hard surface, active excluded grain and sleeping grain; sample before/after ticks and wraps. Include native predicates and adapter collision/bearing/disturbance readbacks when executable. |
| Sleep and interest re-entry | Pause across at least a full stamp period, retain pending deadlines, then re-enter. Prove no stale-stamp alias, no missed first update, and no elapsed-time catch-up. |
| New storage and ownership replacement | Newly admitted chunks at nonzero epoch, fresh/reconstructed World, complete clear, replacement and failed-world quarantine. Do not relabel CYSD1 reconstruction as production continuation. |
| Discovery separation | Clear-only maintenance does not increment material mutation/revision or masquerade as inclusion/world incarnation. Preserve separate generation receipts across reset and re-entry. |
| Worker and platform coverage | One/four-worker comparisons include actual dispatch and ownership barriers. Sanitizers, native ABI and executable Wasm boundaries are distinct reported outcomes; unavailable targets remain gaps. |
| Hash/snapshot compatibility | Same-schema raw hashes remain checked; cross-representation semantic records and scheduling/support assertions are independent. Explicitly classify every omitted bookkeeping field rather than weakening the comparator after a mismatch. |

Existing [`test_world.cpp`](../../native/tests/test_world.cpp) supplies useful
granular support, Mercury lanes, Water mass/coherence, signed movement, interest
transition, failed-tick recovery and CYSD1 cases. It does not currently provide
the new real 16-bit World lifecycle. The
[`no_write_activity_deadline_and_epoch_wrap` test](../../native/tests/test_settled_world_discovery.cpp)
runs 260 ordinary ticks to check that current byte-epoch maintenance leaves a
discovery revision unchanged; those 260 ticks would no longer reach rollover in
a widened candidate. Keep its original control and add a genuinely appropriate
wide-epoch gate.

**Next action:** separately register S2 performance feasibility and paired
measurements after the bounded S1 correctness pass. S1's
direct native support and transport probes do not execute Godot bearing/collision
adapters; discovery-enabled epoch maintenance and live continuation remain gaps.
Do not choose a production representation, persistence migration, lazy epoch
scheme or solver from carrier byte counts or primitive-counter success.
