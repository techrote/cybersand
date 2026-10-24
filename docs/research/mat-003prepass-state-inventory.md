---
title: MAT-003PREPASS source-bound material and continuation-state inventory
status: Current
document-kind: reference
scope: Initial production-source inventory at da5112c plus separately identified saved Water prototype at 7ef2aac; not a qualification or production migration
canonical-for: [mat003-prepass-state-inventory]
keywords: [MAT-003PREPASS, state_a, state_b, material catalogue, epoch, continuation, 64-bit, 72-bit, 80-bit]
last-reviewed: 2026-10-22
related-documents: [mat-003prepass-gen006-handoff.md, mat-003prepass-epoch-consumers.md, ../systems/materials-and-rule-kernels.md, ../architecture/chunk-tile-and-buffer-model.md, ../reference/level-saves-and-replay.md]
---

# MAT-003PREPASS state inventory

## Source identity and status

**Current inspected source:** `da5112c066416346d6fe3984d4161cd162611e50`,
the intake revision of [#204](https://github.com/techrote/cybersand/issues/204).
This is the initial source audit for an isolated prepass. It reports inspected
contracts and gaps; it does not establish full-engine carrier equivalence,
performance, continuation, or a production layout winner. Newer source must be
reconciled explicitly before reusing these findings.

**Separately inspected saved experiment:** branch
`claude/water-pressure-prototype` at
`7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09`. Its archived patches and readable
source copies establish concrete additional state requirements described below.
They are not applied to this checkout and are not Current production behavior.
Any newer owner-local changes beyond that saved revision remain unavailable;
the saved prototype must not be conflated with that remaining source gap.

The [material contract](../systems/materials-and-rule-kernels.md),
[storage contract](../architecture/chunk-tile-and-buffer-model.md),
[activity contract](../systems/activity-dirty-regions-and-waking.md) and
[save contract](../reference/level-saves-and-replay.md) remain the Current owners.
The companion [GEN-006 handoff](mat-003prepass-gen006-handoff.md) is a **Planned**
proposal. Historical #16/#17 experiments and #14/G-final retain their dispositions.

## Actual carrier capacity and narrower semantic domains

[`PrecisionStorage`](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/include/cybersand/precision_storage.hpp#L22-L49)
is one `uint64_t`, with enforced size/alignment 8/8 bytes. `World::Chunk::Cell`
aliases it. The nearby four-byte comment in `world.cpp` is stale; it is not the
ABI. Bit positions below are least significant first, independent of memory
byte order.

| Field | Carrier bits / accessor | Current supported semantics |
|---|---|---|
| Material | 0–15 / `Material` | `Material : uint8_t`; 132 descriptor slots, valid IDs 0–131 except 10. `Gas` aliases Smoke at 4. No 65,536-material API exists. |
| `state_a` | 16–31 / `uint16_t` | Public World setter rejects non-Water values above 255. Runtime Water policy accepts mass widths 3–8; current valid mass is at most 255. Full 16-bit storage still needs independent raw roundtrip tests. |
| `state_b` | 32–39 / `uint8_t` | Material-specific byte; the carrier's Water accessor also obeys compile-time `CYBERSAND_DELAY_BITS`. Default build uses all eight bits. |
| Unassigned in assessed production | 40–55 / no semantic accessor | No production solver meaning. Reinitialization through `for_material` clears these bits. The separately saved pressure prototype consumes all 16 bits. |
| Update epoch | 56–63 / `uint8_t` | Same-tick write/scheduling/support bookkeeping, coordinated with `World::update_epoch_`. |

Sources: [`Material` and descriptors](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/include/cybersand/material.hpp#L14-L225),
[`set_cell_state`](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L1693-L1712),
[`WaterExperimentPolicy`](../../native/include/cybersand/water_experiment_policy.hpp).
Compile-time precision-experiment settings and runtime policy are separate
inputs; a future arm must record both and must not silently change either.

Preserving material16 + state_a16 + state_b8 consumes 40 bits. Epoch16 fits in
64 bits with eight free bits; epoch24 fits with none; epoch32 needs at least
72 bits. Adding eight/sixteen **total bits** means 72/80 logical bits. Physical
padding and sidecar allocations are separate measured costs.

## Per-material compact state

The table covers every current kernel and the catalogue families sharing it.
Initialization comes from `material.hpp`; the concrete reads/writes are in
[`World::update_rule_kernel`](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L2727-L3459)
and [`update_water`](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L2649-L2725).
Counts are dimensionless game quantities or selected-update opportunities,
not seconds, kilograms, degrees or calibrated energy.

| Material / kernel | `state_a`: default and use | `state_b`: default and use | Mutation / conversion detail |
|---|---|---|---|
| Water / FreeMass | Policy maximum; positive conserved integer fill up to that maximum | 0; coherence countdown, admitted range 0–configured coherence, at most 12 | Partial transfer adds/subtracts exact fill; zero source becomes Empty. Destination takes max coherence. Countdown suppresses source-time lateral spray, not gravity. |
| Smoke / Gas | 240; lifetime, zero reinitializes to descriptor default on its decay lane | 0; no separate intrinsic meaning | Eight-tick coordinate lane decrements by one or two depending on neighboring Smoke; expiry becomes Empty. Whole-cell movement preserves current tuple. |
| Steam | 180; lifetime | 0; no stored phase quantity in this baseline | Decrements each admitted update; expiry creates **full** policy-maximum Water. |
| Foam | 120; lifetime | 0 | Decrements each admitted update; expiry becomes Empty. |
| Fire | 240; lifetime; some reactions/emissions use smaller values | 0 | Decrements each admitted update; expiry initializes Smoke. Ignition sampling has its own 120-tick lane. |
| Wood, OakTimber, Thatch; MAT-002 IDs 81–97 / Combustible | 0; preserved while burning, no intrinsic fuel-mass interpretation | 0; burn countdown, set by ignition duration | Selected two-tick lane decrements; Water extinguishes by setting b=0; expiry becomes Empty. Burning emits Fire at bounded opportunities. |
| Oil | 0; preserved during burn | 0; burn countdown, ordinary ignition sets 64 | Selected lifecycle lane decrements/extinguishes; expiry becomes Empty. Whole-cell specialized flow remains separate from Water. |
| Coal | 0; preserved during burn | 0; ignition sets 160 | Selected lifecycle lane decrements; Water/Brine extinguish; expiry becomes Dust. |
| Metal | 0 | 0; charge countdown | Charge propagates at half magnitude to an uncharged Metal neighbor, decrements on its lane, and can convert Water to Steam(90,0). |
| [Spark](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L3065-L3091) | [12](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/include/cybersand/material.hpp#L309-L310); lifetime | 0 | Charges an adjacent Metal to 24 and consumes itself, or consumes itself after a successful ignition sample with duration 48. Otherwise decrements each admitted update, drifts, and expires to Empty. |
| Cement | 180; cure remaining | 0 | Selected lane decrements by 1/2/4 from contact conditions; expiry becomes Concrete(0,0). Whole-cell liquid motion retains remaining cure. |
| MoltenGlass | 180; cooling remaining | 0 | Four-tick thermal lane refreshes to 180 near hot material or decrements; zero becomes Glass. No independent physical heat quantity. |
| Lava | 0; no intrinsic counter in this baseline | 0 | Whole-cell yielding motion and contact ignition/melting; pair rules initialize products. No cumulative coolant/quench field here. |
| Ice | 0; no phase quantity field in this baseline | 0 | Hot-neighbor melting creates full Water; freezing writes Ice(0,0). Eligibility/cadence resides outside these state fields. |
| Acid | 255; corrosion strength | 0 | Eligible corrosion subtracts 24 and removes the target; exhausted Acid becomes Empty. |
| Plant, Fungus | 32; bounded growth energy | 0; burn countdown when ignited, typically 48 | A growth step divides energy minus one between parent/child. Burning delegates to Combustible. Consumed Water/timber are reaction inputs, not conserved species. |
| Mite | 1; heading uses 255 for left and other admitted values for right | 0; copied during movement/feeding | Turns select 1/255. Feeding writes a Mite at the target and Empty at source. |
| Rocket | 0; unlaunched, then direction code 1–8 | Sand ID; captured payload material ID | Hot material/temperature launches it; moves two cells, leaves initialized payload, or becomes Fire. Payload validation excludes Empty/Wall/Cloner/Rocket. |
| Cloner | 0; preserved, no intrinsic use | 0; captured material ID | Captures a valid neighboring ID other than Empty/Wall/Cloner; emits initialized material into Empty. State-carried IDs remain byte-sized. |
| Seed | 0; germination sets stage 8, then counts down | 0; germinated flag becomes 1 | Selected contact lane produces Plant children; final stage becomes Plant(16,0). |
| Stone | 0 | 0 for brace-aware Stone; explosion writes 1 for granular Stone | b=0 can be braced by two upper Stone neighbors; nonzero bypasses that brace. The flag is authoritative behavior, not a visual mark. |
| Sand, Salt, Sodium, Rust / Sand | 0; no intrinsic counter | 0 | Whole-cell gravity/exchange; applicable pair chemistry is separate. |
| Dust | 0 | 0 | Whole-cell fall; hot contact can initialize Fire(40,0). |
| Gunpowder | 0 | 0 | Whole-cell fall; eligible hot contact initializes Fire(64,0). |
| Paste, Slush, Brine, ToxicSludge, Mercury / YieldingLiquid | 0; no intrinsic mass fraction | 0 | Whole-cell CellularYield motion, viscosity and pair rules. Mercury eligibility uses block deadlines/global tick, not a compact per-cell clock. |
| Empty, Wall, Concrete, Glass; other IDs 38–80; MAT-002 IDs 98–131 / None | 0 | 0 | No intrinsic kernel; registered pair reactions can convert these as another admitted material's target. Values admitted by diagnostics can persist; “unused by kernel” is not evidence they may be silently dropped in a comparison. |

All 17 MAT-002 combustible additions (PinePlanks through MossWall, IDs 81–97)
share the existing Combustible kernel. The remaining 34 additions use None;
25 have registered pair reactions and nine have no authored pair rule. Their
names do not imply new state fields. The versioned pair table is
[`int.current-behaviour` v2](../../native/include/cybersand/interaction_rules.hpp),
with schema 1. This is a rule-profile identity, not a complete material-state
schema or a serializer version.

### Reaction-progress and validation gaps

Current compact pairs resolve products and probability on the four-tick contact
lane. They do **not** accumulate per-cell reaction progress. Both product records
are initialized from descriptors (Water uses policy maximum), even when a product
retains its input material ID. Thus “preserve Water role” in an interaction
description does not promise preservation of partial fill or coherence. Persistent
contacts retain a block deadline through MAT-001; that preserves opportunities,
not fractional chemistry progress.

The checked source lacks the phase-quantity/cumulative-quench semantics described
by open [WAT-002 PR #162](https://github.com/techrote/cybersand/pull/162).
Steam/Ice roundtrips and charged Metal are therefore reactive source/sink cases;
they must not be included in a closed pure-Water conservation claim. Preserve
their actual outputs in equivalence tests instead of silently importing another
branch's proposed behavior.

`set_cell_state` validates Water policy and a generic non-Water byte limit, not
every material's meaningful states. For example Rocket uses `flight - 1` as a
Moore-neighbor index; its meaningful launch domain is 1–8. A future persistence
validator must reject unsupported state combinations before construction rather
than assuming that any byte accepted by the generic setter is safe for every
kernel. This audit does not patch that existing boundary.

## Cell mutation, ownership and temperature

Native World owns cells and optional fields. The exclusive external owner calls
public APIs; native jobs mutate only their prepared domains. The following are
separate operations, not interchangeable “copy a cell” semantics:

| Operation | Current cell and field behavior | Consequence for future extra payload |
|---|---|---|
| `set` | Same material is a no-op. A different material reinitializes compact state, stamps current epoch, wakes/marks dirty; it does not reset the existing coordinate temperature. | Same-value edit intent needs a separate mutation log if it must survive regeneration. |
| `write_cell` / `set_cell_state` | Identical material/a/b is a no-op; otherwise creates `for_material`, writes supplied a/b and stamps current epoch. Non-semantic spare bits are reset. | An extension needs explicit reset/preserve rules; relying on spare bits surviving this path is wrong. |
| `move_cell`, including swap | Copies the entire carrier to destination, swaps or initializes Empty at source; stamps **both** endpoints. Temperature follows whole-cell movement/swap; a vacated nonswap source becomes ambient. | Sidecar ownership must move/swap with the logical cell, after destination capacity preflight. |
| `transfer_water` | Adjusts fill at both endpoints, max-merges coherence, stamps both; zero source becomes Empty. Temperature arrays are not transported or mass-mixed by this path. | A new quantity needs a separately defined split/merge law; copying whole-cell behavior here would change Current semantics. |
| Material conversion / reaction | Kernel/pair supplies product identity and compact values; coordinate temperature generally remains as stored. | Product-specific extension reset/transfer must be specified before admission. |
| `set_temperature` | Optional chunk-owned `vector<int16_t>`; absence resolves to `ambient_temperature` (default 200). Nonambient writes allocate/activate/dirty through World. | Allocation presence and logical values are different; logical default may reconstruct only under recorded ambient configuration. |

Sources: [`set`/`write_cell`](../../native/src/world.cpp),
[`move_cell` lines 2323–2416](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L2323-L2416),
[`transfer_water` lines 2482–2575](https://github.com/techrote/cybersand/blob/da5112c066416346d6fe3984d4161cd162611e50/native/src/world.cpp#L2482-L2575).
Temperature has signed 16-bit range; this source does not supply a general heat
diffusion equation or calibrated temperature unit. Rocket checks ambient + 400.
Transient occupancy masks affect normal queries; raw state comparisons must use
stored accessors and a declared mask/temperature observation boundary.

## Continuation state outside the cell carrier

Density below means structural scope, not measured occupancy. Current allocations
must be measured separately from these logical requirements.

| State | Owner, lifetime and density | Authority / continuation treatment |
|---|---|---|
| Immutable descriptors and policies | Catalogue/WorldConfig; whole World lifetime, shared by all cells | Authoritative behavior identity: catalogue/rules, Water precision/coherence/rest policy, transport/interaction settings, adhesion, geometry and capacity policy. |
| Temperature | Optional dense array per allocated chunk, persists until chunk/World retirement | Authoritative values; absence means recorded ambient. Hash/save paths include resolved values. |
| Cell epoch / World counter | One stamp per cell, one counter per World; wraps with resident clears | Scheduling **and support** state. `granular_support_at` compares stamp to current epoch except at fresh tick zero. It cannot be discarded without a phase/rebase argument. |
| Attempted/completed ticks and failure latch | World lifetime; `uint64_t` ticks and failure flag | Global tick drives deterministic random streams, phase order and cadence. Failed partial worlds cannot be valid continuation captures. |
| Activity and interaction deadlines | Per chunk/block; active/changed flags, `uint32_t` quiet ticks, `uint64_t` earliest deadline | Determines ordinary scheduling and deferred Mercury/lateral/reaction opportunities. Preserve or prove reconstruction, including sleeping/excluded blocks. |
| Requested/applied interest coverage | World; latched requested region plus applied core coverage | Pause/re-entry semantics; newly included blocks wake once, no elapsed-time catch-up. Serial ignores this filtering. |
| Pending explosions | Bounded ordered World queue | Authoritative accepted future work, applied at tick entry. Order, payload and exactly-once application matter. |
| Job effects / prepared halos | Tick-local bounded jobs and coordinator | In-place work, not durable transfer queues. Capture only after jobs finish; partial tick is unsupported. General cross-boundary pending transfers are Planned, not Current. |
| Settled discovery and mutation witnesses | Optional World-owned observer/index subsystem | Distinct incarnation/mutation/deadline identities; inspect this subsystem before serializing it. Derived caches may be retired only under their explicit lifecycle contract. |
| Generation recipes/proposals/caches | Immutable compiled generator and preview owner | Original material proposals can reconstruct only with exact recipe, seed, algorithm/module versions, canonical coordinates and baseline availability. Preview cache is not live cell authority. |
| Semantic fixtures and interlayer links | `CyberSemanticPlaneRuntime`; feature/fixture/link states, retired revisions, issued observations and receipts | Fired/cleaned/active/retired counts, event-rate tick/count and consumed observation identities govern future writes. Regeneration alone does not reconstruct them. |
| Deepworks emitters | `CyberDeepworksRuntime`; `_fired`, script enable, event application/write counts | Finite sources are keyed to their target plane's tick and repeat count; resetting counts would duplicate sources. |
| Independent depth clocks and queued commands | `CyberDepthLayerRuntime`; four Worlds, layer ticks/rates, accumulators, queue, generation | Background remains frozen; other planes pause independently. Explicit routes only; no automatic mass/event transfer from pixel overlap. |
| Body/actor commands and occupancy | Separate owner/session, leased observations and transient projection | Outside cell-only continuation. Reconstruct masks from matched authoritative bodies at the next safe boundary or pin affected chunks. Rapier contact-state replay is unqualified. |
| Render dirty regions, snapshots and visual condition | World publication state plus immutable leased/copy-owned buffers | Presentation projection can be regenerated, but outstanding leases/acknowledgements must retire safely. Render serials are not cell epochs or durable mutation versions. |

Sources: [`world.hpp`](../../native/include/cybersand/world.hpp),
[`World::Chunk` and `begin_tick`](../../native/src/world.cpp),
[`semantic_plane_runtime.gd`](../../godot/scripts/depth/semantic_plane_runtime.gd),
[`deepworks_runtime.gd`](../../godot/scripts/exhibition/deepworks_runtime.gd),
[`depth_layer_runtime.gd`](../../godot/scripts/depth/depth_layer_runtime.gd),
[ownership](../architecture/data-ownership-and-lifetimes.md).
At fresh counter zero the first epoch clear is tick 256; subsequent clears are
255 ticks apart. Every allocated chunk participates, including sleepers and
interest-excluded residents. This is not a world/session identifier. The separate
[epoch consumer audit](mat-003prepass-epoch-consumers.md) supplies the source-site
inventory and required consumer-specific lifecycle tests.

## Hashes, snapshots and adapters

`World::state_hash` includes counter and per-cell epochs, selected configuration,
pending explosions, activity and compact values. It also uses native integer
widths in its mixer and omits some future-affecting owner inputs. It is neither a
cross-representation semantic oracle nor a complete durable replay identity.
`content_hash` excludes tick/scheduler state and skips an Empty cell at ambient
temperature even if its compact a/b state is nonzero. A full comparison must
therefore retain explicit records for **all** declared coordinates using
material-u16, a-u16, b-u8 and signed-temperature-i16, with scheduling/support
predicates compared separately. Do not reuse historical #16's byte-only a
comparison or use a digest to replace lossless difference reporting.

[`demo_snapshot.hpp`](../../native/include/cybersand/demo_snapshot.hpp) copies
material/a/b into three bytes plus temperature LE16: CYSD1 is five bytes per
cell and narrows the u16 a accessor. Current supported runtime mass3–8 fits that
byte, but this is no guarantee for a future high-a state. The C API accepts a
u16 material argument then validates the current byte catalogue; descriptor
initial-state fields remain bytes. Godot emission/diagnostic paths, cloned and
Rocket-carried IDs, transport schema-1's fixed 81-entry domain, rendering RG8,
palette/appearance tables and fallback constants all require review before a
wider ID catalogue. The fallback is a different simulation implementation.

[`material_appearance.hpp`](../../native/include/cybersand/material_appearance.hpp)
projects a or b into a byte visual-condition channel (normalized Water fill,
lifetimes, burn, charge, cure and flight as selected per material). This is
derived presentation, not a lossless saved state. Relief/parallax and visual
wet surfaces do not create extra authoritative pressure, moisture or Z fields.

## Available saved pressure prototype: a separate state contract

The [pinned experiment README](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/README.md#L1-L29)
is the provenance manifest: its reconstruction starts at `620826f`, applies
`patches/perf-vs-620826f.diff`, then `patches/prototype-v5-vs-perf.diff`.
`src/water_proto.hpp` and `src/water_proto_b.inc` are readable copies of new
prototype files. This audit inspected those copies and the v5 patch; it did not
apply, compile or run them, reconcile their older base with `da5112c`, or import
the README's measurements. The README's dated addenda supersede older entries.
In particular, the v5 prepass writes persistent Empty-cell air state; the earlier
description of a read-only prepass no longer describes all its effects.

| Saved v5 field | Exact carrier/type and semantic domain | Ownership and lifetime |
|---|---|---|
| Water lateral flow | Bits 40–47, `int8_t`; normal kernel clamps to −127…127. The experiment scales 127 to one cell/tick; it is one horizontal component, not a general two-dimensional velocity. | Per-Water history across ticks. `proto_move` blends destination flow by transported mass; its rounding rule is part of the behavior. |
| Water overfill | Bits 48–55, `uint8_t`, 0–255 additional mass above visible `state_a`; total mass is a+overfill, at most 510 under maximum=255. | Per-Water authoritative quantity. Transfer consumes source overfill first, fills destination base before overfill, and normalizes overfill into a when base capacity opens. It cannot be dropped as render-only surplus. |
| Enclosed Empty air amount | Bits 40–55, unsigned 16-bit read; same physical bits as Water's two fields. Stores a pocket's equivalent atmospheric volume in cells, redundantly in its resident Empty cells. Default `WAMAX=24576` vents larger stored amounts/pockets; zero is no stored amount. | Persistent solver state associated with the current enclosed-air topology. It is not a material ID, density, durable pocket identity, or ordinary per-cell additive mass. The prepass rewrites membership's cells each tick. |
| Head, run length, gradient, material/mass snapshot, pocket labels and offsets | World-owned scratch vectors (`int32_t`, `uint16_t`, `uint8_t`) over a bounding box plus radius-2 halo; heads/offsets use integer Water-mass units. | Recomputed prepass inputs for a tick, not additional cell bits. Default full-height mode extends the active columns through occupied resident chunks. Reconstruction requires equivalent coverage, obstacles and input state at the same phase. |
| Previous pocket offset and smooth volume | World-owned vectors of `(uint32 air_amount, int32 previous_value)` pairs: `proto_air_offset_last_` and `proto_air_last_`. | Cross-tick history. Offset changes affect waking with default `WAWAKE=1`; previous volume affects damping if `WAD>0` (default 0). These are not proven disposable caches. |
| Prototype policy | Process-static environment-derived `Params`, including mode, acceleration/drag, pressure cap, air/quantization/wake/full-height switches | Solver identity, not cell payload. `atoi` parsing does not establish a validated admission domain for arbitrary settings; record exact effective values before a future comparison. |

Sources: [carrier masks and World members in the saved patch](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/patches/prototype-v5-vs-perf.diff#L1197-L1256),
[transfer and normalization](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/src/water_proto_b.inc#L600-L729),
[flow clamp/flux](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/src/water_proto_b.inc#L875-L956),
[air-state writes and histories](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/src/water_proto_b.inc#L388-L542),
and [parameters/blending](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/src/water_proto.hpp#L5-L69).

The actual v5 air code selects the amount held by the most pocket cells (ties
choose the larger amount), then apportions an amount claimed by multiple pockets
by volume. It does not implement the nearby older comment's general sum of
merged amounts. Both that claim grouping and the history lookup use **amount as
key**, so distinct pockets with equal amounts do not have independent identities.
Pressure uses `P_atm * (A * maximum - smooth_volume) / smooth_volume`, quantizes
down by `WAQ` and clamps to 0…`P_atm`; `P_atm=WATM*maximum`, with defaults 512
rows and quantum 16 mass units. This is the inspected experimental algorithm,
not a validated physical model or durable topology contract.

Empty state therefore needs explicit lifecycle treatment: a Water move into an
Empty destination overwrites its air tag; a newly vacated source initialized by
`for_material(Empty)` has zero tag. The prepass only writes an air tag when the
chunk/cell already exists. It does not allocate a missing air-cell record there.
For Water, the coherence-decrement path explicitly restores flow and overfill
after `write_cell` reconstructs the carrier; this local exception does not prove
all conversion, edit or phase-change paths preserve the intended quantities.
`proto_move` always stamps the source but stamps its recipient conditionally,
allowing same-tick relay into existing Water. A future epoch arm must preserve
that experimental rule separately from Current production transfer semantics.
See [coherence restoration](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/src/water_proto_b.inc#L776-L783)
and the transfer/air-write sources above.

**Layout collision:** the registered E16 placement at bits 48–63 consumes all
eight current prototype overfill bits and the upper eight air-amount bits. E24 at
40–63 consumes both Water fields and all air bits. Keeping material16+a16+b8,
the prototype's 16-bit payload, and epoch16 requires **72 logical bits** (or an
explicitly changed/sidecar representation); epoch32 with the same payload needs
88. C64E16 cannot preserve all those widths inline. This makes 72-bit capacity a
required question but selects no payload meaning, remapping, padding or production
winner. Even a larger carrier cannot reuse the old masks with an overlapping
epoch: an integration must version and remap the fields. Primary neutral-payload
arms remain neutral; they do not become a pressure-solver equivalence test.

The saved [prototype limitations](https://github.com/techrote/cybersand/blob/7ef2aacfef3aef1fe9f26b6b85b4a5a083ba3a09/tools/experiments/water_pressure_prototype/README.md#L119-L138)
explicitly leave serial/diagnostic/transport and Godot/save/C API paths
unqualified and identify `content_hash`'s omission of spare bits. Consequently
the production semantic tuple alone is insufficient for this solver: an oracle
would also need flow, overfill, Empty air state and relevant history/scheduling
observations. Base reconciliation, Empty-only chunk reclamation, reset and
move/swap behavior, pocket split/merge identity, settings bounds, scratch capacity,
capture phase and continuation remain an explicit unknown register. Newer
owner-local WIP is an additional source gap, not a reason to ignore this available
saved evidence.

## Prospective requirements and unknowns

**Planned requirement worksheet:** these are candidate ownership/budget questions,
not extra fields or selected physical units in the assessed source.

| Prospective field / behavior | Initial budget question and ownership | Disposition at this checkpoint |
|---|---|---|
| Pressure/head, overfill and trapped air | Saved v5 uses per-tick head scratch, 8-bit Water overfill and 16-bit Empty air state sharing Water's spare region. Define admitted ranges, saturation, conservation and topology before integration. | Concrete saved prototype above, absent from assessed production. Its continuation, old-base reconciliation and any newer owner-local deltas remain unqualified. |
| Liquid momentum | Saved v5 has one signed8 horizontal flow component. A future two-component signed16 design would require **32 bits**, already more than the requested 8/16 extra bits. | The saved one-component algorithm is evidence; the two-component budget is a separate example, not its selected requirement. Evaluate optional storage and reconstruction separately. |
| Multiple liquid modes | Stable material/solver-policy ID and version usually belong to catalogue/World configuration; a cell-local override would need explicit admission and persistence. | Preserve Water FreeMass versus CellularYield. No universal solver or mode count is implemented here. |
| Granular momentum / ballistic continuation | Whole-grain momentum may need two components and subcell remainder/flight phase, with explicit settle/contact/move/swap/reset rules. | A separate optional moving subset is a candidate; no generic velocity or ballistic system added. |
| Reaction progress / physical heat | Per reaction/material authoritative extent, units and reset/stoichiometry; optional field density depends on actual chemistry/thermal model. | Current counters are game lifetimes/strengths. More bits alone do not supply conservation or physical kinetics. |
| Material identity expansion | Catalogue+schema migration and adapters, state-carried IDs, rendering and persistence all need coherent widths. | No expansion implied by the storage mask. Retain existing IDs and rules. |
| Streaming continuation | Exact baseline plus edit intent, lifecycle state, optional fields, clocks and pending accepted work | Proposed handoff only. No eviction/reload or GEN-006 acceptance is established. |

Measured occupancy, saved-prototype integration/continuation, newer local WIP,
per-material semantic validators, complete external-owner continuation and full
engine epoch equivalence remain open. The isolated neutral payload establishes
representational capacity only; it must not be relabeled pressure, momentum, or
useful physics evidence.
