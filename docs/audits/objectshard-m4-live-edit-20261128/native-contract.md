---
title: ObjectShard M4 live-edit native transaction contract and local review
status: Historical
document-kind: audit
scope: 28 November 2026 live-edit implementation and local native evidence; final hosted and package qualification are separate
last-reviewed: 2026-11-28
---

# Native structural transactions

This mission extends the existing exact-cell transaction boundary. Native C++
remains the sole material authority; the ordinary simulation worker remains its
exclusive caller. Main continues to install and acknowledge Rapier geometry.
No independent physics mutation path, renderer-owned material, or detached-body
addition/repair operation was introduced.

## One bounded owner transaction

The existing `object_shard_workbench_action` endpoint accepts an optional
`targets` array of **1–4,096 exact cell witnesses**. `target` is the first witness.
Each target retains its owner, generation, body incarnation, geometry revision,
applied physics revision, native pose serial, material revision, cell incarnation,
expected material/state/temperature, displayed position and publication identity.
Every witness is validated before any selection or mutation. Mixed owners,
malformed arrays, oversized requests, stale or foreign identities refuse.
Duplicates with different valid projected positions are permitted: every witness
must still identify the same current local cell. Deduplication uses that local
cell index, so an expanded/rotated visual cell cannot be debited twice.

A brush crossing owners is a sequence of independently reported owner
transactions, with fresh target acquisition before each transaction. **Whole
multi-owner gestures are not atomic.** Within one owner, material writes follow
complete preflight of exact post-edit shape capacity, cell storage and revision
counters. Expected capacity refusal leaves inventory, clocks and geometry intact.

Registry scratch storage holds the exclusion mask and exact post-edit shape
cover. After preflight, the selected cells are debited and that cover is reused
for one connectivity/mass/inertia/geometry publication. The batch does not loop
over the former single-cell geometry transaction. No eligible/selected cells
means no material revision, geometry reconstruction or wake request.

## Visible ownership and ordinary terrain

Foreground order is the highest visible owner ID, matching Workbench sprite
z-order. The native adapter repeats the displayed pixel-centre transform using
Godot value math and the acknowledged native pose. Every occupied carrier,
including Cargo and Product, occludes lower material. Only an eligible Structural
winner can be cut; an uncuttable visible carrier never authorizes cutting through
it. Native coordinator tests additionally prove that a Product in a real collider
hole protects deliberately seeded underlying ordinary terrain.

Terrain uses `domain="terrain"` and `terrain_cells`, also bounded to 1–4,096
coordinates. The native facade requires the exact displayed World revision and
native instance. The coordinator revalidates World cell payload/witnesses and
rejects protected physical occupancy or visible owned material before mutation.
World payload/topology witness generations have conservative aggregate headroom
preflight. Domains, first-target positions and all nested payload dictionaries
are validated before copying or debit.
All selected ordinary cells change under one exclusive command; the facade
advances its public revision once if actual material changed. The result returns
an exact deduplicated `terrain_changed_cells` list for authored-start recording.

## Selection and ignition

Optional `probability_ppm` (0–1,000,000), nonnegative `seed` and
`material_filter` (-1 or a valid material ID) select actual authoritative cells.
Integer-only hashing uses the seed and captured lattice coordinates; it does not
use session numbers, body creation order or the order of submitted targets.
Fragmentation preserves those captured coordinates. A repeated identical seed
therefore preserves its cell-selection pattern where the same material survives.

Ignition selects currently unburning structural Wood. Wood with a nonzero burn
countdown is left unchanged. This protection also applies to the retained
exact-cell and ordinary World ignition APIs. Ignition changes material state,
never collider topology, and returns zero removed cells/rebuilds.

## Physical and material accounting

Every actual erased material cell is added to `authored_destroyed` exactly once.
Complete skeleton deletion produces empty shapes and zero rigid mass, then waits
for the established physical retirement acknowledgement. Surviving cells retain
one owner. Geometry replacement preserves angular velocity and the velocity of
surviving material points by adjusting linear velocity for the centre-of-mass
shift. Material removal is an open system; this is not a claim of closed-system
momentum conservation. Changed structural geometry wakes a sleeper; no-op edits
leave it alone. Existing fragment-capacity deferral keeps disconnected inventory
in the parent compound rather than silently discarding it. A two-body capacity
fixture starts with 65 cells, cuts eight cells from the 64-cell primary body, and
retains its exact 56-cell two-island compound while capacity is full. Removing the
separate one-cell owner and servicing its normal semantic retirement permits the
physical split: two owners retain exactly 56 cells, with nine intentional deletions
and balanced inventory. Empty draining carriers release their storage slot during
the next semantic exchange after physical retirement, preserving the prior policy.

An unexpected commit failure enters quarantine and accounts its actual changed
prefix; the receipt exposes partial/uncertain completion. Expected refusal is
not relabelled as partial success. The worker and port retain their owner,
transport, publication, receipt and geometry-installation fences.

## Receipt and diagnostic fields

Batch receipts retain exact source targets and selection parameters and report
requested, unique, eligible, changed and removed cell counts, changed owner count,
geometry rebuild count and island counts before/after mutation. `target_ns` covers
witness validation, deduplication and selection. `mutation_ns` covers cell writes.
`geometry_ns` covers exact shape-capacity preflight plus the final connectivity,
mass and geometry computation; it is not solely a Rapier installation timer.
`native_edit_ns` sums these nonoverlapping native stages. Worker queue, owner
service, Main delivery, actual physics installation and presentation clocks are
separate measurements. At most one geometry rebuild occurs per changed owner
transaction; no-op and ignition receipts report zero.

## Local qualification

The local development extension uses explicit GCC 14.2 toolchain drift because
the execution host differs from the pinned hosted GCC 13.3 environment. It is
not a production publication. Its SHA-256 is
`3e80c5e8183e36f9b3f2c528bb8c862a74daa7ef07fcc5548b67d614aa5a504e`
(6,027,152 bytes). Final source-bound hosted runtimes remain a separate gate.

The six ordinary native suites initially passed **138,145 checks** with zero failures,
including new exact-cell equivalence, duplicate validation, same-owner atomicity,
shape-capacity refusal, full 4,096-cell removal, precise mass/COM/inertia, replay
identity, stale/foreign witnesses, no-op geometry, rotating/sleeping edits,
deterministic filtered erosion and combustion countdown preservation.
[The compact result](native-local-qualification.json) binds the source input
digest and actual binary identities. After the final boundary hardening and
capacity fixture, [all six native suites under ASan+UBSan](native-final-sanitizer-qualification.json)
passed **138,280 checks** with zero failures. The ordinary World sanitizer binary
passed **192 tests** in 482.88 seconds when [replayed unchanged](native-sanitizer-qualification.json)
after an inconclusive 300-second local timeout. Leak detection is disabled by the
retained sanitizer harness. The retained native matrix passed **74 registered
budgets** and **4,237,399 checks**; [its evidence](native-retained-budgets.json)
is scoped to the exact recorded pre-final-exception-readback native input.

The [actual Godot 4.7 facade test](native-facade-local-qualification.json) passes
**59 checks** on the final local runtime, including malformed/oversized/foreign/
stale inputs, strict domains, protected later targets with no prefix debit,
deduplicated terrain receipts, no-op filters and combustion countdown preservation.

Development failures are retained in the execution logs: the first mixed-material
test used the standalone Wood-only Lab discovery policy; the corrected fixture
uses an attached ordinary M4 World while retaining its 32-Wood/32-brick assertions.
The next compile exposed an explicit `RectI64` requirement for an optional World
region. Neither correction changes production behavior or weakens a regression. A later
capacity fixture initially retried before the established empty-carrier semantic
retirement opportunity; the corrected test performs that real native tick and
retains all material/ownership assertions.
The initial benchmark output also required an explicit stdout flush so unrelated
stderr diagnostics cannot interrupt a JSON record; the final measurements below
come from the corrected runner output.

## Matched native cost

Each workload starts with an identical 2,304-cell Wood owner in 2,500 storage
cells. Both paths include witness acquisition, native mutation and native geometry
acknowledgement; fixture creation is excluded. These are **local native-only**
measurements, without real Rapier installation, worker transport, rendering or
physical owner hardware. Three samples per workload produce the medians below.
Final material, shape digest, mass, COM and inertia agree exactly in all 15 pairs.

| Workload | Removed cells | Exact-cell path median | Batch median | Geometry rebuilds, single / batch |
| --- | ---: | ---: | ---: | ---: |
| Circle radius 1 | 5 | 2.704 ms | 0.558 ms | 5 / 1 |
| Circle radius 4 | 49 | 26.336 ms | 0.571 ms | 49 / 1 |
| Circle radius 8 | 197 | 104.176 ms | 0.619 ms | 197 / 1 |
| Circle radius 16 | 797 | 397.359 ms | 0.807 ms | 797 / 1 |
| Thin 48-cell slice | 48 | 25.755 ms | 0.562 ms | 48 / 1 |

[The individual records](native-batch-performance.json) retain all samples and
native stage counters. These demonstrate elimination of repeated native geometry
work for a matched cut. They do not establish Workbench input latency, seven-body
semantic throughput, hosted Windows performance or physical TITAN RTX frame rate.
