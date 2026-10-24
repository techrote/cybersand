---
title: Level saves and exact replay
status: Current
document-kind: contract
scope: Current CYSD1 finite-level format, exclusive ownership, import failure and omitted continuation state; how the experimental LCB CYPS v1 continuation differs
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-10-24
related-documents: [interfaces-and-message-contracts.md, ../architecture/pressure-flow-v1.md, ../architecture/determinism-and-boundary-transfers.md, validation-evidence.md]
---

# Level saves and exact replay

## Does an identical save reproduce the next tick?

**Current: no such guarantee.** CYSD1 restores a fixed demo level and selected
metadata. Identical re-export proves equality of what the format stores. It
does not prove that cells, characters or Rapier will follow the original future
trajectory: tick/epoch/activity, complete simulation configuration, pending
authoritative events/commands and Rapier contact caches are omitted. Complete
durable replay and a selectable strict runtime policy are
**Planned** implementations of the **Approved** exact-validation requirement.

The native fixture hashes are also incomplete replay identities. Their precise
coverage belongs to [determinism](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage).

## What is stored in CYSD1?

Source: [CyberDemoSaveCodec](../../godot/scripts/demo_save_codec.gd),
[demo::copy_level/reconstruct](../../native/include/cybersand/demo_snapshot.hpp)
and [CyberDemoBridge](../../godot/native_extension/cyber_demo_bridge.hpp).

| Component | Current contract |
|---|---|
| World extent | Exactly 1024×1024, row-major; not arbitrary signed sparse storage |
| Per-cell payload | Material ID, `state_a`, `state_b`, and signed temperature encoded as little-endian 16 bits: five bytes per cell, 5,242,880 bytes total |
| Header | 56 bytes: magic `CYSD1`, format/compression flags, dimensions, metadata/raw/compressed lengths, SHA-256 digest |
| Integrity | Digest covers the first 24 header bytes plus JSON metadata and compressed world bytes |
| Compression/text | DEFLATE binary payload; Base64 portable text |
| Limits | Metadata ≤16,384 bytes; binary ≤8 MiB; text ≤12 MiB |
| Metadata | Demo ID, player position/velocity, selected material, quality, coherent emission, adhesion and glow options |
| Body records | At most three Physics Pit bodies: position, angle, linear/angular velocity, sleeping flag |
| Local slot | `user://web_demo_slot_1.cys`; browser storage is origin/profile dependent |

The five save bytes encode logical material/state values and temperature from the
optional field; they exclude the update epoch. Current authoritative cells use
the [eight-byte storage carrier](../architecture/chunk-tile-and-buffer-model.md#what-is-stored-per-cell-and-per-chunk).
CYSD1's five-byte save layout is separate from the in-memory `Cell` ABI.

## May saving run concurrently with a tick?

**Current: no.** Call construction/export/import at a safe boundary with exclusive
World ownership. `copy_level(World&, ...)` clears transient obstacles so temperature
sampling reads stored cells. The caller must rebuild the body projection before
the next cellular tick. Export is therefore not a concurrent const query, even
though it does not change saved material bytes.

The Web controller performs these operations on its synchronous owner. A future
asynchronous save service needs an explicit capture/handoff contract; borrowing
mutable World storage from a writer is **Rejected**.

## What does import validate, and what stays intact on failure?

The codec checks lengths, header/version fields, checksum, decompression and
bounded metadata types/ranges. Native validation checks exact payload length
and legal material IDs (`0…131` except reserved `10`). Selected-material metadata
accepts paintable IDs through `CyberCellWorld.LAST_MATERIAL`; Empty remains an
invalid selection. Constructor IDs are range-checked before narrowing, so a wide
integer cannot wrap into a valid material. Validation does not implement a
complete semantic schema for every material's two state bytes.

The MAT-002 catalogue extension changes the accepted IDs, not the CYSD1 header or
five-byte cell encoding. Existing levels remain readable. Older runtimes whose
catalogue ends at 80 reject levels containing the new materials; they do not gain
support from the unchanged format version alone.

`CyberDemoBridge::import_level` validates and builds a replacement World and
render exchange before no-throw ownership swaps. CYSD1 stores no liquid solver
policy: an import always reconstructs on every liquid's default family (LCB NC-10),
whatever the live World's policy. Invalid codec/native payloads
leave the active World intact. The Web controller rejects a Physics Pit save
when Rapier is unavailable before native import. This guarantee concerns the
checked import paths; it is not a general transaction guarantee for simulation
ticks or arbitrary later scene allocation failures.

## What continuation state is missing?

CYSD1 omits tick/epoch, scheduler activity and sleep state, queued explosions and
future input ordering, complete WorldConfig/interest state, render leases,
transient body masks, and Rapier solver/contact caches. Import resets character
grounded state and reconstructs physics bodies. Body metadata round-trips are
checked with `1e-5` tolerance; exact floating-point trajectory replay is not claimed.

**Planned:** versioned general sparse-world persistence, replay input capture,
complete state/configuration identity, migration, I/O pressure policy and an
explicit strict-mode implementation. Do not infer those contracts from CYSD1.

## How does CYPS v1 differ from CYSD1?

**Current on branch `claude/lcb001-pressure-reference` (unmerged), experimental.**
`World::save_physical_state()`/`restore_physical_state()` and the bridge's
`export_physical_state`/`import_physical_state` write and read **CYPS v1**
(`kPhysicalStateFormatVersion` 1), an exact tick-boundary continuation for LCB
comparison Worlds. Its canonical description is the
[pressure reference persistence contract](../architecture/pressure-flow-v1.md#persistence-cyps-v1).

| | CYSD1 | CYPS v1 |
|---|---|---|
| Purpose | finite level exchange | exact continuation of a comparison World |
| Liquid policy | not stored; import always reconstructs on default families (NC-10) | policy envelope stored and re-admitted by the running build |
| Clock, epochs, regions, pending events, activity blocks | omitted | stored |
| Pressure sidecars and gas table | n/a (lossy; never a continuation) | stored |
| Integrity | codec checksum and native validation | SHA-256 of the body, then range and invariant checks |
| Failure | live World intact | `invalid_argument`/`LiquidPolicyRefused`; live World intact ("running world preserved") |
| Continuation | none claimed | bit-identical physical and state hash, including at another worker count |

CYPS omits execution settings (workers, capacities come from the caller),
host-owned transient body masks and Rapier state, and requires settled discovery
to be disabled. It is not general sparse-world persistence, replay input capture
or a frozen schema, and CYSD1 is unchanged.

## Which evidence applies?

`test_web_demo_setup.gd` covers construction, native rejection and exact level
payload restoration; `test_web_rapier.gd` exercises body/lifecycle restoration.
The native snapshot regression and
[`test_building_material_integration.gd`](../../godot/tests/test_building_material_integration.gd)
cover all 51 MAT-002 additions, selected-material metadata, exact cell-state and
temperature restoration, invalid IDs and preservation of the active world after
rejection. See the [MAT-002 review](../audits/2026-10-19-mat002-review-and-validation.md)
for the source and runtime scope of that evidence.
See the [validation ledger](validation-evidence.md) for the dated Windows and
Chromium runs. Headless execution of a Web scene is Windows runtime evidence;
it does not rerun the exported WASM in a browser.

## Can a failed world be saved or recovered?

**Current:** ordinary Godot level export rejects a quarantined World; it must not
label partial tick state as a valid level. Raw serialized native reads remain
diagnostic. A previously saved, validated level or explicit fresh level/reset can
replace the failed World. Invalid replacement leaves the fault and partial state
intact. Successful replacement clears pending events/failure/tick identity and
uses the latest requested region; it does not resume the failed attempt or replay
accepted events. See [failure policy](../decisions/ADR-010-failed-tick-quarantine.md).

## MicroScenario observations are not replay saves

**Current MS-000:** JSON captures retain a versioned setup definition, bounded
scheduled actions/observations, profile and artifact identities, and completed tick.
They explicitly say `replay_complete=false`: neither that JSON nor current native
hashes contain a complete resumed input/world/owner state. Loading the definition
creates a fresh world; it does not resume the captured tick. Organic user actions
and reaction/outflow ledgers are not fabricated. Generic controlled scenarios
refuse ordinary CYSD1 level import/export while active. See the
[capture contract](../operations/microscenarios.md#capture-provenance-and-limits).
