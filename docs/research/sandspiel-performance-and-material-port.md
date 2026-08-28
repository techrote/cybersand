---
title: Sandspiel performance study and material port ledger
status: Current
scope: Sandspiel source audit, portable performance techniques, rejected coupling, material inventory, Noita comparison, and reversible port sequence
keywords: [Sandspiel, Max Bittker, material port, compact cell, LTO, GPU fluid, Noita checkerboard, performance]
related-documents: [../systems/materials-and-rule-kernels.md, ../systems/water-design.md, ../decisions/ADR-002-double-buffered-tile-jobs.md, ../../THIRD_PARTY_NOTICES.md]
last-reviewed: 2026-08-27
implementation-state: The complete attributed catalogue now has adapted executable native kernels on the phased worker backend; exact Sandspiel Water polarity and GPU wind/pressure remain excluded.
---

# Sandspiel performance study and material port ledger

## At a glance

- Purpose: extract Sandspiel's portable performance lessons without adopting its finite-world or mutable-render coupling.
- **Current**: the native material identifier is one byte and preserves Sandspiel IDs 0–19, excluding unused slot 10.
- **Current**: a complete attributed interaction inventory exists at `native/data/material-packs/sandspiel-mit-reference.json`.
- **Current**: native update stamps use one-byte epochs, the active-chunk list is reused, and release builds request LTO.
- **Current**: Godot can shade all imported IDs and gives Water stable render-only tonal dithering.
- **Current**: all valid catalogue IDs execute through deterministic compact RuleKernel families with radius-one or radius-two writes.
- **Current**: conserved Water, stable dither, 32×32 activity, and the Noita-style four-phase worker scheduler are implemented natively.
- **Current**: event-driven collapse converts blast-adjacent static Wall into tagged granular Stone without scanning static terrain every tick.
- **Current**: packed material/condition bytes are copied only for deterministic dirty rectangles into reusable immutable snapshot slots.
- **Explicitly rejected**: pasting imported species functions into GDScript or copying Sandspiel's mutable Water polarity.
- **Deferred / experimental**: Sandspiel-style GPU wind/pressure remains outside authoritative terrain.

## Search anchors

why Sandspiel is fast, Sandspiel materials, copy lava oil fungus rocket, four byte cell, direct texture upload, GPU wind, Noita checkerboard, imported interaction status

## Audited source

The audit pins Sandspiel commit `dc77827b36adc5c04ea063515de4173ce28dbf2c` and covers:

- `crate/src/lib.rs`;
- `crate/src/species.rs`;
- `crate/src/utils.rs`;
- `crate/Cargo.toml`;
- `js/render.js`;
- `js/fluid.js` and its shader pipeline;
- `js/glsl/sand.glsl`;
- the project license and development article.

Sandspiel is MIT-licensed. The required notice is retained in [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md).

Primary references:

- [Making Sandspiel](https://maxbittker.com/making-sandspiel/)
- [Sandspiel repository](https://github.com/MaxBittker/sandspiel)
- [Material rules](https://github.com/MaxBittker/sandspiel/blob/master/crate/src/species.rs)
- [Native/WASM state and scan](https://github.com/MaxBittker/sandspiel/blob/master/crate/src/lib.rs)
- [Release optimization](https://github.com/MaxBittker/sandspiel/blob/master/crate/Cargo.toml)

## Why Sandspiel is fast

### Compact contiguous state

Sandspiel stores a cell as four bytes: one species byte, two generic state bytes, and one update-clock byte. Location is implicit in a dense array index. The main loop therefore touches compact contiguous memory with no per-cell object, pointer, allocation, node, or hash lookup.

Cyber Sand cannot use one dense array for the stored world, but it can preserve locality inside 128×128 storage chunks and compacted active work.

### Native hot rules with bounded access

Particle rules execute in optimized Rust/WASM. A `SandApi` permits only relative reads and writes within two cells. This centralizes bounds checks and prevents rule code from retaining world pointers or performing action at a distance.

Cyber Sand keeps the bounded-neighborhood concept: every descriptor declares a
radius no greater than two and geometry tests prove same-phase write domains do
not overlap. The current private dispatcher still operates through World methods;
a type-enforced standalone RuleContext remains a planned hardening step.

### Generation stamp

Sandspiel uses one byte per cell to prevent a moved particle from updating twice during one scan. Cyber Sand now uses the same compact epoch concept in the current native prototype. Wrap performs an explicit stamp clear; authoritative hashing includes the epoch because it can affect a future tick.

### Optimized release build

Sandspiel requests optimization level 3, LTO, and `wasm-opt -O4`. Its article reports a substantial gain after switching away from size-oriented optimization. Cyber Sand's GNU release build now requests `-O3 -flto`; MSVC release commands request `/O2 /GL /LTCG`.

### Packed rendering input

Sandspiel forms a JavaScript typed-array view over the four-byte WASM cell array and uploads it as an RGBA texture. This avoids per-cell color-object construction and intermediate packing.

Cyber Sand retains the principle—publish a GPU-ready compact representation—but not mutable sharing. RenderBridge must publish immutable dirty snapshots, and large worlds must upload dirty regions rather than the whole stored world.

### GPU field solver

Sandspiel runs wind/density/pressure passes on WebGL textures, including advection, curl, vorticity, divergence, repeated pressure iterations, and gradient subtraction. It uploads cell/burn data and reads velocity data back to CPU/WASM, using a pixel buffer and fence when available.

This can make a small visual field convincing, but readback and authority synchronization are significant. Cyber Sand therefore keeps GPU compute deferred for non-authoritative or latency-tolerant fields until CPU state, collision, replay, and field-coupling contracts exist.

## Scale caveat

Sandspiel's published canvas is 300×300, or 90,000 cells. Its main particle scan is serial and visits the dense grid; it does not provide the large sparse stored-world, camera interest, sleeping-tile, deterministic multicore, or immutable bridge architecture required here.

Its smoothness demonstrates the value of native compact data and bulk rendering. It does not establish that a full stored Cyber Sand world should be scanned or uploaded every tick.

## Adopted now

| Technique | Current change | Boundary preserved |
|---|---|---|
| One-byte material ID | `Material : uint8_t` | Material identity remains owned by native World/production WorldStorage |
| One-byte update epoch | fourth byte of `World::Chunk::Cell` | Stamp is simulation metadata, never render authority |
| Reused active traversal storage | `World::active_chunk_scratch_` | No new scheduler semantics claimed |
| O3 plus LTO | GNU/MSVC release flags | Portable builds retain explicit debug/test modes |
| Stable palette grain | Water shader hash and imported palette cases | Render-only; no wake, dirty, mass, or replay effect |
| Attributed material catalogue | Native JSON provenance/adaptation pack plus compiled kernels | JSON is not parsed in the hot path |
| Four-byte hot Cell | material, two generic state bytes, update epoch | Optional temperature remains a separate per-chunk field |
| Bounded rule kernels | RuleKernel dispatcher and per-descriptor radius | Same-phase geometry and worker-parity tests guard ownership |
| Conserved Water | 8-bit mass and exact pair transfers | Sandspiel polarity/history is excluded |
| Persistent worker pool | Four parity phases and barriers | No thread per tick/material and no cell locks |
| Packed dirty rendering | Two-byte material/condition snapshot patches | Immutable lease storage, never a mutable World view |
| Event-driven collapse | Bounded explosion queue and granular Stone tag | Static Wall has no routine update rule |

The final density/leveling 2026-08-27 hosted run measured 512×512 dense phased
ticks at 12.87 ms with one worker, 5.05 ms with four workers, and 3.74 ms with eight workers. Each
phased run produced identical state/content hashes and zero World-owned tick
allocations. These single-run observations are environment-specific, not
target-hardware promises or evidence that eight workers will win on other CPUs.
Normal, ASan+UBSan, and TSan suites passed.

## Not adopted

| Sandspiel choice | Cyber Sand disposition | Reason |
|---|---|---|
| One dense full-world array | **Explicitly rejected** for stored-world architecture | Stored scale, streaming, and interest-region requirements |
| Direct mutable simulation-buffer view for rendering | **Explicitly rejected** | Violates immutable RenderBridge ownership |
| Full texture upload every frame | **Explicitly rejected** as production policy | Upload cost must follow dirty visible snapshots |
| Browser/global random values in rule execution | **Explicitly rejected** | Breaks deterministic replay and worker-count parity |
| Exact Sandspiel Water polarity/opinion as native authority | **Explicitly rejected** | Mutates equivalent liquid state and risks shimmer/activity churn; native Water instead conserves fixed-point mass |
| Whole-state undo clones in the hot runtime | **Deferred / experimental** tooling | Memory cost scales with loaded state |
| GPU terrain/material authority | **Explicitly rejected** at present | Collision, gameplay query, save, and replay authority remain native CPU concerns |
| Full imported material catalogue pasted into GDScript | **Explicitly rejected** | Recreates the technical-debt failure described in Sandspiel's first JavaScript prototype |

The unsupported-platform GDScript fallback carries a compact Water flow
direction to prevent a discrete stream from reversing into its vacated cells.
That is not Sandspiel's exact polarity rule: stopped flow must still prove a
lower surface within a bounded look-ahead, level pools sleep, and production
native Water retains no direction/history state. Normalized viscosity now maps
Water to a 24-cell bounded serial dispersion ceiling; every intervening cell
must be Empty, and the separate pressure-yield setting remains available for
paste/slush behavior.

## Noita scheduler comparison

The supplied Noita description divides the world into 64×64 dirty regions and processes a four-phase cross/checker pattern so threads can mutate enlarged areas without locks. That is a credible lower-copy alternative.

ADR-002 has now been implemented for the leading path:

- 128×128 storage, 32×32 activity, and leading 64×64 scheduling geometry are independent;
- the default native backend uses four phases of exclusive in-place write domains;
- a persistent pool executes sufficiently populated phases while sparse phases stay sequential below a threshold;
- one/four-worker complete-material hashes match exactly;
- the buffered candidate remains reserved but unimplemented pending a demonstrated need.
- bounded explosion events now remove a blast core and selectively convert a two-cell Wall shell to granular Stone at a tick boundary;
- ordinary static Wall remains unscheduled, so collapse work is paid only when the event occurs.

The candidates may coexist only at an explicit backend or field boundary; unbounded mixed writes to one field/stage remain rejected.

## Material port ledger

All source materials are catalogued and have Current adapted executable rules.
“Adapted” means the interaction role is preserved within Cyber Sand's conserved
Water, deterministic random, compact state, activity, and bounded-write contracts;
it does not claim byte-identical Sandspiel evolution.

| ID | Material | Catalogue | Current executable rule | Planned production family |
|---:|---|---|---|---|
| 0 | Empty | **Current** | **Current** | static/empty |
| 1 | Wall | **Current** | **Current** | static solid |
| 2 | Sand | **Current** | **Current** | powder |
| 3 | Water | **Current** | **Current** | conserved 8-bit liquid mass |
| 4 | Gas / Smoke | **Current** | **Current** | rising gas |
| 5 | Cloner | **Current** | **Current** | capture/emitter |
| 6 | Fire | **Current** | **Current** | reaction + short-lived gas |
| 7 | Wood | **Current** | **Current** | combustible solid |
| 8 | Lava | **Current** | **Current** | hot liquid + reaction |
| 9 | Ice | **Current** | **Current** | phase solid |
| 11 | Plant | **Current** | **Current** | bounded organic growth |
| 12 | Acid | **Current** | **Current** | finite-strength corrosive liquid |
| 13 | Stone | **Current** | **Current** | collapsible solid |
| 14 | Dust | **Current** | **Current** | light powder + ignition |
| 15 | Mite | **Current** | **Current** | bounded cellular agent |
| 16 | Oil | **Current** | **Current** | combustible light liquid |
| 17 | Rocket | **Current** | **Current** | radius-two projectile/payload state machine |
| 18 | Fungus | **Current** | **Current** | bounded organic growth |
| 19 | Seed | **Current** | **Current** | powder + germination state machine |

Slot 10 remains invalid because the audited source leaves its former Sink value disabled.

## Reversible execution sequence

1. **Current** checkpoint — catalogue and compact layout
   - Preserve IDs, palette, provenance, and interaction ledger.
   - Compact update metadata and enable LTO.
   - Rollback: restore the previous material table, epoch vector, and build flags.

2. **Current** checkpoint — conserved Water reference
   - Freeze fixed-point format, conversion, bounded flux, stable rest, and hash fixtures.
   - Reintroduce Water interactions only with explicit mass effects.
   - Rollback: the earlier catalogue/layout source archive preserves the pre-mass native implementation; Godot remains isolated.

3. **Current**, partial checkpoint — MaterialRules execution
   - Deterministic random streams, declared radii, compact state, and phased exclusive writes are implemented.
   - A type-enforced context separated from private World methods remains **Planned**.

4. **Current** checkpoint — common movement families
   - Port Sand/Stone/Dust powders; Gas/Smoke; then Oil/Acid/Lava using shared liquid contracts.
   - Validate each family on one worker before multiple workers.

5. **Current** checkpoint — reaction and organic families
   - Port Fire/Wood/Ice, then Plant/Fungus/Seed, then Mite/Cloner/Rocket.
   - Each state byte/optional field must have serialization, replay, sleep, dirty, and boundary semantics.

6. **Optional field experiment**
   - Benchmark CPU coarse fields first.
   - GPU field work remains non-authoritative unless an ADR replaces ADR-006.

## Required validation source

The repository includes passing source coverage for:

- catalog completeness and reserved-ID validation;
- native deterministic replay, one/four-worker parity, sleeping, edges, RGBA copy, and both C API versions;
- every adapted material family and compact state machine;
- exact Water conservation/settling, optional fields, capacity failure, and preallocated allocation observations;
- dense and sparse native benchmark fixtures.

Before treating the adapted pack as production-complete, extend rather than conflate:

- a fuller pair/multi-neighbor interaction matrix;
- every-direction tile/chunk edge shifted and mirrored parity;
- explicit fixed-point accounting for every consuming/producing liquid reaction;
- bounded growth/agent high-water and long-duration stress assertions;
- current and 2× interest-region stress fixtures.

## Related decisions

- [ADR-001](../decisions/ADR-001-native-simulation-core.md)
- [ADR-002](../decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-005](../decisions/ADR-005-water-model.md)
- [ADR-006](../decisions/ADR-006-gpu-compute-deferral.md)
