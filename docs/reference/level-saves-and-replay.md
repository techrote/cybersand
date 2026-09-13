---
title: Level saves and exact replay
status: Current
document-kind: contract
scope: Current CYSD1 finite-level format, exclusive ownership, import failure and omitted continuation state
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-09-08
related-documents: [interfaces-and-message-contracts.md, ../architecture/determinism-and-boundary-transfers.md, validation-evidence.md]
---

# Level saves and exact replay

## Soliding persistence boundary

The isolated [ADR-012 Session](../decisions/ADR-012-bounded-soliding-ownership.md)
has no aggregate save schema. Its persistence admission query refuses while pending,
Aggregate, excluded or quarantined. It exposes no CYSD1 import/export method and
cannot be passed to the ordinary adapter export path. Thus no payload is silently
omitted or mask cleared by a save. Cells-only export integration is still Deferred;
whole-experiment teardown explicitly abandons the diagnostic world. Reversal is
payload conservation, not exact serialized continuation or replay.


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

The authoritative hot cell remains four bytes. Save bytes intentionally exclude
its update epoch and add temperature from the optional field; the five-byte
save layout is not the in-memory `Cell` ABI.

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
and legal material IDs (`0…80` except reserved `10`). It does not implement a
complete semantic schema for every material's two state bytes.

`CyberDemoBridge::import_level` validates and builds a replacement World and
render exchange before no-throw ownership swaps. Invalid codec/native payloads
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

## Which evidence applies?

`test_web_demo_setup.gd` covers construction, native rejection and exact level
payload restoration; `test_web_rapier.gd` exercises body/lifecycle restoration.
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
