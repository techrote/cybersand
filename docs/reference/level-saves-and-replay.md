---
title: Level saves and exact replay
status: Current
document-kind: contract
scope: CYSD1 finite-level format, ownership and omitted continuation state; accepted main LCB CYPS2 exact accounting/continuation, explicit historical CYPS1 refusal and remaining application replay gaps
canonical-for: [cysd1-level-format, save-import-export, replay-persistence]
last-reviewed: 2026-10-25
related-documents: [interfaces-and-message-contracts.md, ../architecture/pressure-flow-v1.md, ../architecture/determinism-and-boundary-transfers.md, validation-evidence.md]
---

# Level saves and exact replay

The later [synchronous Water Feel body route](../architecture/liquid-prepared-setup-and-receipts.md#synchronous-supported-body-water-feel)
reconstructs its accepted original recipe/policy/normalization on Restart. A
generic import of identical native tuples retires its native generation and
cannot acquire Water recipe/transport origin from the UI label. This adds no
save schema or policy persistence; moving-body imports and separately restored
host masks remain unsupported work.

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
policy: this original API reconstructs every liquid's default family (LCB NC-10),
whatever the live World's policy. Invalid codec/native payloads
leave the active World intact. The Web controller rejects a Physics Pit save
when Rapier is unavailable before native import. This guarantee concerns the
checked import paths; it is not a general transaction guarantee for simulation
ticks or arbitrary later scene allocation failures.

**Current bounded unmerged #202 source:** the normal synchronous application's
liquid panel can explicitly arm the next ordinary body-free import with a copied
policy, normalization opt-in and geometry in Exploratory mode. The separate
`prepare_liquid_level` API preserves thermal tuples and stages native World,
sampled player, metadata-derived execution and qualified host observation before
the final commit. Refusal retains the prior World/player/receipt/record. The
[prepared import contract](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-level-import-and-retained-restart)
owns those bounds and unsupported body/Tower/showcase routes. Restart retains the
accepted in-memory payload and selection; CYSD1 serialization is unchanged and
unarmed import still uses Current defaults. No full replay or browser/release
qualification follows from this opt-in reconstruction.
The follow-up preflight explicitly refuses unsupported inherited interaction,
diagnostic-law or independent transport settings rather than replacing them
with preparation defaults. The accepted private Baseline may restart only with
matching native component/generation/receipt identity. Unarmed legacy import
continues to preserve its inherited configuration. Optional enabled preparation
telemetry is observational and remains qualified separately.

The later [four authored ordinary-demo route](../architecture/liquid-prepared-setup-and-receipts.md#explicit-ordinary-synchronous-demo-rebuilding)
keeps its accepted recipe separate from an imported level even when both carry
the same demo label. Only an actual curated constructor and matching native
generation supply authored identity. An accepted import restarts its copied
payload/metadata; an accepted curated demo restarts its copied authored recipe.
Neither in-memory request is persisted by CYSD1. Quarantined prepared Restart
currently refuses; explicit Current construction or unarmed import is recovery.

The later authored Physics Pit route also retains its own original recipe/body
poses and selection privately for Restart. This does not admit a saved physical
level for family conversion: an imported same-label three-body graph has no
authored source-generation identity, and its direct experimental apply refuses.

## What continuation state is missing?

CYSD1 omits tick/epoch, scheduler activity and sleep state, queued explosions and
future input ordering, complete WorldConfig/interest state, render leases,
transient body masks, and Rapier solver/contact caches. Import resets character
grounded state and reconstructs physics bodies. Body metadata round-trips are
checked with `1e-5` tolerance; exact floating-point trajectory replay is not claimed.

**Planned:** versioned general sparse-world persistence, replay input capture,
complete state/configuration identity, migration, I/O pressure policy and an
explicit strict-mode implementation. Do not infer those contracts from CYSD1.

## How does CYPS2 differ from CYSD1?

**Current on main through accepted PR #246 (`ec58d919`, 2026-10-25).**
`World::save_physical_state()`/`restore_physical_state()` and the bridge's
`export_physical_state`/`import_physical_state` write and read **CYPS2**
(`kPhysicalStateFormatVersion` 2), an exact tick-boundary continuation for LCB
comparison Worlds. Its canonical description is the
[pressure persistence contract](../architecture/pressure-flow-v1.md#persistence-cyps-v2)
and [shared native setup/accounting contract](../architecture/liquid-prepared-setup-and-receipts.md).

| | CYSD1 | CYPS2 |
|---|---|---|
| Purpose | finite level exchange | exact continuation of a comparison World |
| Liquid policy | not stored; import always reconstructs on default families (NC-10) | policy envelope stored and re-admitted by the running build |
| Clock, epochs, regions, pending events, activity blocks | omitted | stored |
| Pressure sidecars and gas table | n/a (lossy; never a continuation) | stored |
| Shared quantity accounting and construction binding | omitted | exact source/sink and rule totals, visible+overfill, separate material cell counts, prepared/normalization identities |
| Integrity | codec checksum and native validation | SHA-256 of the body, then range and invariant checks |
| Failure | live World intact | `invalid_argument`/`LiquidPolicyRefused`; live World intact ("running world preserved") |
| Continuation | none claimed | bit-identical physical and state hash, including at another worker count |

CYPS omits execution settings (workers, capacities come from the caller),
host-owned transient body masks and Rapier state, and requires settled discovery
to be disabled. It is not general sparse-world persistence, replay input capture
or full application replay. The owner-requested native codec freeze does not
freeze production Cell/global ABI or those missing host contracts; CYSD1 is
unchanged. Historical CYPS1 belongs to the #245 source/artifact evidence and is
explicitly refused by this decoder. A valid digest does not excuse inconsistent
accounting: restore validates closure, roles, quanta and actual stored authority.

The native prepared builder can normalize final setup tuples only with explicit
opt-in and a bound receipt. It cannot normalize a live World. Godot's normal
level import still reconstructs defaults; native candidate CYSD1 ingress
preflights nonzero fractional W-CY Water and returns `normalization_required`
rather than silently rounding. The old Godot dictionary run getter is not the
typed native receipt and provides no full host-replay proof.

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
