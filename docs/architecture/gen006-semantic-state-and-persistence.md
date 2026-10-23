---
title: GEN-006 semantic state and persistence handoff
status: Planned
document-kind: design
scope: MAT-003PREPASS D proposal for versioned native cell continuation, durable mutations, identities, lifecycle and schema compatibility; no streaming implementation
canonical-for: [gen006-durable-semantic-state, gen006-chunk-lifecycle-fencing, gen006-mutation-reconciliation-contract]
last-reviewed: 2026-10-23
related-documents: [data-ownership-and-lifetimes.md, chunk-tile-and-buffer-model.md, ../systems/world-storage-and-interest-region.md, ../systems/activity-dirty-regions-and-waking.md, ../systems/materials-and-rule-kernels.md, ../systems/procedural-semantic-planes.md, ../reference/level-saves-and-replay.md, ../operations/mat003prepass-gen006-state-handoff.md, ../decisions/ADR-004-interest-region-and-reconfiguration.md, ../decisions/ADR-010-failed-tick-quarantine.md]
keywords: [MAT-003PREPASS, GEN-006, durable state, mutation intent, tombstone, sidecar, eviction, reload, epoch, recipe]
---

# GEN-006 semantic-state and persistence handoff (proposal, not runtime capability)

**Status — Planned proposal.** Consumer [GEN-006 #194](https://github.com/techrote/cybersand/issues/194); source [MAT-003PREPASS #204](https://github.com/techrote/cybersand/issues/204). Inspected `main` at `1f9336388f11be39abaae340a781a5eef52115d4` (2026-10-23). This design is independent of PR #221's experimental carrier and does **not** approve C64/C72/C80/C128, implement sparse saves, enable eviction, migrate storage or claim resumed replay. The [execution/evidence handoff](../operations/mat003prepass-gen006-state-handoff.md) owns the test fixture and outstanding gates.

**Current:** `World::Chunk::Cell` aliases the 8-byte, 8-aligned [PrecisionStorage](../../native/include/cybersand/precision_storage.hpp): material **16 stored bits** with `Material : uint8_t`, `state_a : uint16`, `state_b : uint8`, 16 unassigned bits and an 8-bit scheduler epoch. `state_b`'s Water accessor is masked by the configured coherence precision. Source comments calling it a four-byte cell are stale, not authoritative. Optional temperature is a separate chunk-owned int16 array. The five-byte CYSD1 cell serialization is a different finite-level format, **not** a continuation snapshot; see [CYSD1](../reference/level-saves-and-replay.md).

## Semantic schema and independently versioned identities

**Proposed** `cybersand.semantic.chunk` major 1, minor 0; it is a *logical record*, **not a frozen wire ABI**. A future canonical encoder must define byte order, ordering, strict lengths, digest, atomic publication, quotas and migration separately. Experimental `CSG6X1` under [tools/experiments](../../tools/experiments/mat003_gen006_codec_fixture.py) demonstrates rejection logic only and must never be loaded by a production save path.

| Identity (required) | Proposed authority and compatibility test |
|---|---|
| World UUID and world revision | Stable saved-world lineage and atomic checkpoint/reconciliation revision; a new ephemeral **session** identity fences jobs after reset or process restart |
| Chunk coordinate, plane, geometry | Signed int64 `(chunk_x,chunk_y)`, plane enum (`play/scripted/effects/background`), chunk side and scheduling geometry; validate multiplication/limits before allocating |
| Material catalogue ID | Immutable digest of explicit ID↔stable material key, valid/reserved status, descriptor/default table; IDs 0–131 except 10 presently valid; numeric width alone gives no expanded catalogue |
| Solver and policy ID | Hash of effective per-material kernel, FreeMass vs CellularYield, Water mass/coherence/rest settings, transport/interaction versions, deterministic cadence, RNG semantics, ambient and relevant WorldConfig—not merely a kernel name or binary hash |
| Per-material state-schema ID | Names, units, signedness, allowed values, defaults, transitions and migration function for `state_a`, `state_b`, quantity semantics and optional fields; a material ID is not a state schema |
| Recipe/plan ID | Normalized canonical seed, GEN-001–005 algorithm/schema versions, modules+versioned parameters, typed field graph, grammar/semantic-region, plane policies and feature/link/fixture plan |
| Baseline ID | Digest over recipe/plan identity, exact signed region/chunk/plane, canonical generated contents and feature ownership. Retain historical executable inputs **or** immutable old baseline payload, not only its hash |
| Snapshot/checkpoint revision | Monotonic durable `mutation_generation` and committed snapshot ID plus content digest; never infer either from cell epoch, `state_hash`, recipe revision or worker task ID |

Example logical *envelope* (field names illustrative until GEN-006 fixes a codec):

```json
{
  "format": "cybersand.semantic.chunk",
  "schema": {"major": 1, "minor": 0},
  "world_id": "stable-world-uuid",
  "chunk": {"x": -1, "y": 0, "plane": "play", "side": 128},
  "identities": {"catalogue": "sha256:...", "solver": "sha256:...", "state_schema": "sha256:...", "recipe": "sha256:...", "baseline": "sha256:..."},
  "revision": {"mutation_generation": 42, "checkpoint_id": "sha256:..."},
  "baseline": {"reconstruction_ref": "immutable-versioned-input-or-stored-data", "content_digest": "sha256:..."},
  "intent": [{"cell": 17, "operation_id": "edit-uuid", "generation": 41, "kind": "explicit_empty", "origin": "player"}],
  "cells": [{"index": 17, "material_key": "empty", "state_schema": "empty-v1", "state_a": 0, "state_b": 0}],
  "sidecars": [{"field": "temperature", "schema": "signed-celsius-tenths-i16-v1", "values": [{"index": 19, "value": 420}]}],
  "continuation_ref": "versioned-owner-checkpoint-with-clock-activity-events-and-feature-lifecycles"
}
```

Do not confuse the illustrative temperature unit/name with a proven physical heat solver; the [current ambient integer policy](../../native/include/cybersand/world.hpp) must be frozen as a declared value/scale before implementing migration. Missing optional fields mean **versioned defaults**, not uninitialized memory. A future byte-level codec must distinguish unknown *optional* skippable extensions from unknown *required* semantic extensions (refuse), preserve deterministic index ordering, reject duplicate indexes, and carry integrity checks across every authoritative segment.

## Current field-by-field inventory and disposition

`P` = must persist or preserve via journal/checkpoint for the declared continuation scope; `R` = reconstruct only from authenticated inputs and an explicit deterministic procedure; `U` = unsupported for chunk eviction until owner pins/restricts the region. These are **design classifications**, not a claim the current serializer handles them.

| Field and actual owner | Source/current semantics | Proposed treatment |
|---|---|---|
| `Cell.material` — World/chunk | `Material : uint8_t`; 16-bit carrier slot; Empty 0, reserved invalid 10, catalogue through 131 | **P** as validated stable key/ID bound to catalogue digest; baseline cells **R** only with exact old baseline |
| `state_a` — World/chunk | uint16 accessor; Water 1..policy maximum (default 255) is conserved *FreeMass* quantity; non-Water external setter permits at most 255; other kernels use lifetime, energy, cure, strength, cooling, flight, heading, etc. | **P** full semantic integer with material-specific schema and validation; no generic mass inference for CellularYield |
| `state_b` — World/chunk | uint8 accessor; Water coherent delay (default up to 12), Stone brace/falling flag, combustible/Oil/Coal burn, Metal charge, Cloner captured material ID, Rocket payload, Seed stage flag | **P** value with type/domain; validate embedded IDs against referenced catalogue |
| Quantity/volume | Water quantity is `state_a` and `liquid_mass`; whole-cell movers carry an occupied cell; `non_empty_cell_count` is metadata | **P** Water amount once, in typed state; **R** nonempty counts from cells. No second independently mutable quantity source |
| Optional temperatures | `Chunk::temperatures`: allocated int16 vector, otherwise `WorldConfig::ambient_temperature`; carried with moves/swaps | **P** nonambient values + ambient policy identity; **R** absent-as-default only after compatibility check |
| Epoch in every Cell; `World::update_epoch_` | 8-bit visited/write marker; wraps with resident-wide clear; used by double-update suppression **and** `granular_support_at` recent-write predicate | **R** physical epoch by controlled rebase, **P** the logical *touched-in-most-recent-completed-tick* discriminator needed for support parity, or refuse exact continuation |
| `tick_index_`, `completed_tick_index_`, failed status | Attempted vs successful clock; failed tick quarantines partially changed World | **P** healthy completed tick, deterministic global cadence/clock; **U** export/eviction of failed or in-progress tick (never label partial state resumable) |
| `Chunk::ActivityBlock` active, quiet ticks, next interaction tick | 32-cell blocks by default; earliest due tick serves Mercury and compact-pair/Ice/transport wakes; excluded blocks retain deadlines | **P** activity, quiet and **absolute due tick** under frozen no-catch-up policy; **R** transient `changed_this_tick` only at safe completed-tick barrier |
| Chunk active, quiet, dirty rect/count | Chunk active/quiet scheduling summary; `dirty` + min/max are render-publication state, not persistence-acknowledged dirtiness | **P** scheduling summary if not proved derivable; **R** nonempty count and render dirty bounds after publication/reset; **new P** separate serialization-dirty/generation, never reset on render ack |
| Pending explosions (`World::pending_explosions_`) | Ordered center, radius, collapse strength; applied at next tick, can cross chunk boundaries | **P** ordered owner event queue and dedupe receipt globally, **U** local eviction when dependent destinations/event footprint cannot be retained/atomically transferred |
| Cross-cell motion/reaction writes | `move_cell` copies state and temperature; partial `transfer_water` conserves amount; reaction writes may affect both source and target | **P** atomic write-set/provenance for both source and destination, including Empty departures and destination arrivals, with boundary durability/pins |
| `simulation_region_`, selected/applied core coverage | Requested coverage latched outside tick; applied at healthy tick entry, phased-only pause/re-entry; serial ignores interest | **P** owner region policy and selected/applied coverage in world continuation; **R** block coverage only when versioned geometry matches; no elapsed-time catch-up |
| Mutable policy/config | `WorldConfig`, interaction, transport, Water policy, adhesion and mixing/carrying behavior; affects future evolution | **P** effective semantic config/identities; refuse incompatible solver/policy or migrate explicitly |
| `hard_surface_revision_` | Runtime change counter/physics invalidation observation | **R** safe new incarnation/invalidation upon restore unless a consumer requires exact counter continuity (then **P**); do not mistake it for mutation generation |
| `JobEffects`, active scratch, worker phase tasks | Local job effects merged after barrier, bounded temporary arrays; pool generation counter indexes tasks | **R** after drained safe barrier; **U** mid-flight snapshot of worker execution |
| Transient occupancy, Rapier actors, contacts | Separate main-thread body authority/obstacle mask, no per-cell body IDs | **U** until separate full owner serializer; pin all dependent regions and disclose why. Rebuild masks from correctly restored bodies, not from cells |
| Physical usable projectiles/processors | Separate bounded actor/equipment and usable-runtime lifecycle/stock/cooldowns | **U** unless separate owner domain commits its versioned state atomically with affected cells; no silent reconstruction |
| GEN-005 fixtures/links/actors | Canonical feature/plane/fixture/link IDs, revision, finite source schedules and cleanup; background frozen | **P** fixture emission/consumption, cleanup, link activation and deletion lifecycle **plus** old plan; **U** affected bundles until entire cross-plane owner transaction exists |
| Soliding/settled discovery observation | Opt-in coordinator reports activity/discovery and incarnation; observational caches are not cells | **R** only under a separately reviewed full rescan/invalidation/no-unsafe-skip procedure; pin if a future optimizer makes state authoritative |
| Render textures, dither, snapshot leases, workbench preview caches | Copied presentation/diagnostics; do not own simulation state | **R** from committed state and render invalidation; do not serialize borrowed leases |

**Per-material state semantics (source check required for every new material):** `Water` mass/coherence; `Smoke/Gas, Fire, Steam, Foam, Spark` lifetime/decay; `Wood` and other Combustible materials, `Coal/Oil` burn; `Metal` charge; `Cement` cure; `MoltenGlass` cooling; `Acid` remaining strength; `Plant/Fungus` energy plus burning; `Mite` heading; `Rocket` flight/payload; `Seed` stage/germination; `Cloner` captured ID; `Stone` falling/brace flag. Ordinary Sand, inert construction solids, YieldingLiquid, Ice and Lava must still preserve both registers and temperature, even when default/unused in a particular kernel. [Actual kernel dispatch](../../native/src/world.cpp), [descriptor table](../../native/include/cybersand/material.hpp) and [material documentation](../systems/materials-and-rule-kernels.md) own exact transitions. Unknown/reserved IDs, state-carried references, incompatible non-Water >255 values or unsupported prospective fields refuse. Future pressure/momentum per-material liquid modes and granular impulse are **Planned**, not current cell fields; each requires a qualified schema/sidecar contract rather than taking carrier spare bits for granted.

## Ownership and lifecycle transactions

| Transition | Exclusive actor | Preconditions, fences and atomic outcome |
|---|---|---|
| Absent → requested/generating | GEN-006 coordinator | Reserve bounded job/cache/plan budget and issue immutable receipt: world/session, chunk+plane, recipe/baseline, expected durable mutation generation, target incarnation, unique job ID |
| Proposed → ready | Worker | Produce immutable material/diagnostic payload only; never World/Godot/Rapier writes. Cancel is advisory |
| Ready → admitted | Native World owner | Healthy, between ticks, capacity and bundle complete; recheck **all** receipt dimensions at actual commit; fresh installer only for truly absent chunks. Loaded mutated chunks need new validated owner restore transaction, not `install_generated_chunk` |
| Admitted → dirty | World owner | Increment durable **mutation generation** for authoritative writes, including equal-to-baseline edits and cross-chunk events; journal old/new intent and resulting state; serialization dirtiness independent of render dirty |
| Dirty → snapshot/saving | World owner → I/O writer | Drain phase jobs, capture immutable data + event/boundary bundle at completed tick; lease snapshot; save generation N cannot clear dirtiness after newer N+1 |
| Saving → durably clean/evictable | I/O writer → World owner | Check checksum, fsync/staging and atomic manifest publication; verify live mutation generation and incarnation at ACK; retain prior valid checkpoint on failures |
| Evictable → absent | World owner | No actor/fixture/boundary pins or live snapshot leases, no pending coupled work, complete durable coverage, no newer mutations. Retire incarnation/worker receipts |
| Absent → reloading → admitted | World owner | Resolve exact baseline history; verify catalogue/solver/schema; reconstruct cells/sidecars/intents/events; rebase scheduler safely; allocate *new incarnation*, validate atomic bundle, then publish/wake |
| Old recipe → preview → reconciled | Immutable worker preview; owner commit | Three-way `old baseline / new baseline / retained mutation intent and live state`; preserve same-value edits, Empty tombstones and removed features. Commit after mutation-generation recheck; conflict receipt or refusal rather than overwrite |

**Proposed owner state machine:** `ABSENT → REQUESTED → GENERATING → READY → ADMITTED_CLEAN ↔ ADMITTED_DIRTY → SNAPSHOTTING → SAVING → DURABLE_EVICTABLE → ABSENT`, with explicit `PINNED`, `REFUSED` and `QUARANTINED` outcomes. A failed save/invalid history may return to a pinned live resident but **never** discard the only changed copy. Old async results may release their buffers but cannot mutate authority.

**Four distinct generations / identities:** (1) **scheduler epoch**: short wraparound current-tick write/visit marker, reconstructed on reentry; (2) **durable mutation generation**: monotonic per authoritative world/chunk/bundle commit, serially compared at save/reconcile; (3) **chunk incarnation**: non-reused live residency identity, minted on every restore/reset/evict and required on every async receipt; (4) **async job ID**: one-use request instance, never durable authority or a substitute for the other three. Additionally a **world/session ID** fences reset and process restart. Numeric equality across categories is meaningless.

## Migration, default initialization and refusal

**Proposed fail-closed order:** read bounded envelope and digest → validate format/major/minor + required features → validate signed coordinates, chunk side, plane and immutable plan boundary → resolve/verify catalogue, per-material schema, solver/config, recipe and historical baseline → preflight sidecar and event capacities → validate sorted unique cell indexes, state bounds, values and cross-boundary/feature consistency → build complete replacement *off to the side* → owner fence/recheck newest generation/incarnation → atomically publish. Every refusal preserves current live/durable authority.

- Same major/minor with absent *optional* field: initialize its declared semantic default **before** material admission (e.g. temperature = stored ambient); unknown required field, unsupported version or ambiguous unit conversion: **REFUSE_INCOMPATIBLE_SCHEMA**.
- Material ID/key absent from catalogue or state-carried material reference unknown: **REFUSE_UNKNOWN_MATERIAL**. Explicit migration must map old→new IDs and embedded references without loss, with new catalogue revision and independent fixture.
- Old baseline only represented by digest, or recipe/module version irretrievable: **REFUSE_BASELINE_UNAVAILABLE**; keep dirty chunk pinned / retain last known durable snapshot; never regenerate edited content with the latest recipe.
- Optional sidecar: typed `(field_id,schema,owner chunk+plane,index)` with defaults, allocation quota, move/swap/split/merge/reaction reset policy, checksum and no orphan pointers. Unknown *required* sidecar, over-capacity, truncated payload or incompatible schema: **REFUSE_SIDECAR**; no silent truncation, numerical coercion or data loss. Absence is valid only for explicitly optional fields.
- Invalid lengths/digest/duplicate index or mutation ID with different payload: **REFUSE_CORRUPT** or **REFUSE_DUPLICATE_CONFLICT**; a previously committed identical operation ID+digest is an idempotent no-op.
- Snapshot/save from old `mutation_generation`, recipe, incarnation or session; delayed job/preview: **REFUSE_STALE_RESULT**. Accepted cancellation alone is not a fence.
- Changed solver semantics or deadline units without a registered converter and fixed-tick qualification: **REFUSE_UNSUPPORTED_MIGRATION**. Unsupported actor/physical usable/pending interplane state **pins** the chunk; capacity exhaustion returns an explicit refusal/backpressure state, never eviction by guesswork.

Durable publication **proposal:** immutable content-addressed segment(s), full checksum/length validation, write+sync, atomic manifest pointer update with generation compare, recovery picks last complete validated commit; retain operation IDs over the retry window. Storage atomicity, file APIs, resource budgets and crash tests are **GEN-006 implementation decisions**; the fixture only checks local record contracts.

## Scheduler epoch rebasing and support equivalence

**Current source:** `begin_tick` increments `update_epoch_`, clears *all resident cell epochs* on 8-bit wrap, then starts at 1. An unchanged cell is eligible when `cell.epoch != update_epoch_`. External writes, movement, partial Water transfer and explosion writes mark the current epoch; `granular_support_at` treats recently touched granular cells as not bearing weight, also consulting paused-active blocks outside interest. The native global `tick_index_` and earliest interaction deadlines govern other behavior.

**Proposed safe restore at a healthy completed-tick boundary:**
1. Capture completed tick, effective config/solver identity, selected **and applied** region coverage, block active/quiet/deadline, ordered pending events and per-cell **touched-in-last-completed-tick** bit (or exact last-write tick), not just material/state.
2. Under exclusive owner and drained tasks, install full logical state with validated defaults. Assign any safe new physical epoch `E` (not zero-wrap sentinel). Encode last-tick touched cells as `E`, others as a distinct value, so immediate sampled support agrees. Restore global cadence/tick index before any query/physics sampling; respect sleeping/excluded block state and pending absolute deadlines. Do **not** advance due work for time spent unloaded.
3. Before the next successful tick, `begin_tick` moves epoch to `E+1` (or clears all on wrap), so every cell is eligible under the new selected schedule; future writes mark that tick. Never partially resume a phase, import current-epoch bytes from another packing, or equate epoch width with a save schema.
4. Verify both **immediate post-reload support query** and **fixed-input, fixed-tick uninterrupted-vs-restored continuation**, including pause/reentry, Mercury/pair deadlines, Water conservation and signed seams. If exact policy needs inaccessible time-sensitive data, **pin/refuse** rather than claim equality.

The present World API has **no such rebasing/restore facility**; this is a required GEN-006 implementation acceptance gate. A cold reload of only material/state/temperature cannot satisfy it.

## Abstract storage compatibility (no selection)

Semantic `v1` stores field values + identities, **never** `sizeof(Cell)`, raw masked words, padding or physical bit order. All candidates can in principle encode the same supported semantic domain if their accessors/sidecars are lossless and capacity is validated; runtime qualification is **not** implied.

| Experimental arm/family | Logical bits / suggested epoch | Physical stride possibilities | Extra data and persistence compatibility |
|---|---|---|---|
| C64-E8 | 64 / epoch8 | 8-byte current control | 16 unused carrier bits; canonical v1 independent of those bits |
| C64-E16 / E24 | 64 / epoch16 or 24 | 8-byte candidate | 8 / 0 unassigned bits; rebased epoch is not serialized |
| C72-E8/E16/E32 | 72 / epoch8, 16 or 32 | Packed 9, safe-memcpy 9, aligned 16, or 8+1 sidecar | +8 total logical bits vs C64, no guaranteed physical 9-byte stride |
| C80-E8/E16/E32 | 80 / epoch8, 16 or 32 | Packed 10, safe-memcpy 10, aligned 16, or 8+2 sidecar | +16 total logical bits vs C64; validate separate optional-field ownership |
| C128 native-u128 / dual64 | 128 / experiment-dependent | Typically 16-byte candidate (ABI measured per platform) | Capacity only; does not make wide material IDs or future physics state automatically valid |
| 64-logical padded/stride controls | 64 / controlled | 16-byte physical control | Distinguish stride cost from semantic bits; same v1 record |

Epoch/access layout qualification, cost, platform and experimental evidence stay with [#204](https://github.com/techrote/cybersand/issues/204), [#16](https://github.com/techrote/cybersand/issues/16), PRs [#211](https://github.com/techrote/cybersand/pull/211) and [#221](https://github.com/techrote/cybersand/pull/221), and the [handoff ledger](../operations/mat003prepass-gen006-state-handoff.md); this table is architectural compatibility only, not an accepted carrier/performance ranking.
