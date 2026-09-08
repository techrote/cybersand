---
title: Sandspiel performance study and material port ledger
document-kind: reference
canonical-for: [sandspiel-attribution-and-port-status, imported-material-ids]
status: Current
scope: Current CyberSand adaptation inventory plus explicitly historical upstream study and hosted performance observations
last-reviewed: 2026-09-08
related-documents: [../systems/materials-and-rule-kernels.md, ../systems/water-design.md, ../reference/validation-evidence.md, ../../THIRD_PARTY_NOTICES.md]
---

# Sandspiel performance study and material port ledger

**Current:** CyberSand preserves Sandspiel IDs 0–19 except invalid slot 10 and
implements adapted native behavior for each valid entry, including inert
Empty/Wall. “Adapted” does not mean byte-identical upstream evolution. Native
Water uses CyberSand conserved mass; upstream Water polarity and GPU wind/
pressure feedback were not ported as authority.

Current sources are [material descriptors](../../native/include/cybersand/material.hpp),
[World kernels](../../native/src/world.cpp), and the
[JSON attribution/interaction inventory](../../native/data/material-packs/sandspiel-mit-reference.json).
The [checkpoint](../operations/source-checkpoint-and-recovery.md) identifies the
local source; the [evidence ledger](../reference/validation-evidence.md) owns
dated current-platform execution claims. Historical material below is retained
research context, not fresh upstream verification or current-machine performance.

## Attribution and imported IDs

The retained study pins Max Bittker's Sandspiel commit
`dc77827b36adc5c04ea063515de4173ce28dbf2c`. MIT attribution is retained in
[THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) and the JSON ledger:
Copyright (c) 2018 Max Bittker.

| ID | Material | Current CyberSand adaptation |
|---:|---|---|
| 0 | Empty | Empty/static destination |
| 1 | Wall | Inert hard boundary |
| 2 | Sand | Powder/density movement |
| 3 | Water | CyberSand conserved 8-bit pairwise mass |
| 4 | Gas / Smoke | Rising discrete material, bounded decay |
| 5 | Cloner | Capture and initialized emission |
| 6 | Fire | Short-lived motion and sampled ignition |
| 7 | Wood | Combustible solid |
| 8 | Lava | Moving hot material and contact reactions |
| 9 | Ice | Phase-solid rules |
| 11 | Plant | Bounded organic growth |
| 12 | Acid | Finite-strength corrosive liquid |
| 13 | Stone | Brace-aware/collapsed granular states |
| 14 | Dust | Powder and ignition |
| 15 | Mite | Bounded cellular agent |
| 16 | Oil | Combustible yielding liquid |
| 17 | Rocket | Radius-two payload/projectile state machine |
| 18 | Fungus | Bounded organic growth |
| 19 | Seed | Powder/germination state machine |

Slot 10 remains invalid. IDs 20–37 are in the
[reactive material contract](../systems/materials-and-rule-kernels.md);
project-authored IDs 38–80 are in the
[construction catalogue](../systems/themed-construction-materials.md).
The JSON records provenance and adaptation intent; runtime does not parse it
in the hot path. Its prose describing bundled Linux execution is not evidence
that this workspace's unresolved Linux LFS payload runs.

## Current adoption boundaries

CyberSand uses four-byte hot cells, byte update epochs with explicit wrap clear,
reused active traversal storage, release optimization/LTO flags, compiled
descriptors, and bounded kernel families. The native four-phase worker scheduler,
sparse chunks, activity, and immutable dirty publication are CyberSand contracts;
their current details belong in [architecture](../architecture/chunk-tile-and-buffer-model.md)
and [material kernels](../systems/materials-and-rule-kernels.md).

**Rejected:** mutable simulation-buffer views for rendering, browser/global
randomness as authoritative input, importing all species into GDScript, and
Sandspiel's exact Water polarity as native state. The GDScript fallback's
directed discrete Water is a distinct model; it is not the native semantic oracle.

A full stored-world array/upload is **Rejected as production architecture**.
Current Godot still performs full finite RG8 GPU updates after dirty CPU
reconstruction; that implementation limitation is not erased by the decision.
**Deferred:** whole-state undo clones as tooling and GPU wind/pressure experiments.
[ADR-006](../decisions/ADR-006-gpu-compute-deferral.md) owns GPU authority limits.

## Historical upstream study

The recorded study covered `crate/src/lib.rs`, `species.rs`, `utils.rs`,
`Cargo.toml`, `js/render.js`, `js/fluid.js`, `js/glsl/sand.glsl`, license,
and the development article. Retained primary references are
[Making Sandspiel](https://maxbittker.com/making-sandspiel/),
[pinned rules](https://github.com/MaxBittker/sandspiel/blob/dc77827b36adc5c04ea063515de4173ce28dbf2c/crate/src/species.rs),
[pinned state/scan](https://github.com/MaxBittker/sandspiel/blob/dc77827b36adc5c04ea063515de4173ce28dbf2c/crate/src/lib.rs),
and [pinned release settings](https://github.com/MaxBittker/sandspiel/blob/dc77827b36adc5c04ea063515de4173ce28dbf2c/crate/Cargo.toml).

The study reported compact four-byte dense cells, native Rust/WASM rules with
radius-two access, one-byte update clocks, optimization level 3/LTO/
`wasm-opt -O4`, and typed-array texture upload from WASM memory. It also
described a 300×300 (90,000-cell) serial dense scan. These observations motivated
compact native state and bulk rendering; they do not prove large sparse-world
scalability.

The recorded WebGL field pipeline used advection, curl/vorticity, divergence,
pressure iterations and gradient subtraction, with cell/burn upload and velocity
readback (pixel buffer/fence when available). CyberSand has not adopted this
feedback as terrain authority.

The supplied historical Noita comparison mentioned 64×64 dirty regions and a
four-phase cross/checker pattern, but recorded no exact primary source. Treat
that as design context, not independently verified Noita implementation evidence.

## Historical 2026-08-27 hosted benchmark record

The original hosted timing/hash/allocation/sanitizer paragraph is preserved
verbatim in the [historical performance archive](../audits/2026-09-08-performance-history.md#sandspiel-study-hosted-benchmark-record).
It is excluded from ordinary Current-behavior retrieval. Its revision/host
coverage and missing raw evidence must not be silently upgraded to current
acceptance or a universal worker recommendation.

## Remaining acceptance work

**Current fixture inventory:** catalogue/reserved IDs, material families, compact
state, Water conservation/rest, optional fields, capacity, snapshots, C APIs,
and selected worker/boundary comparisons in
[native tests](../../native/tests/test_world.cpp). Presence is not execution.

**Planned:** full pair/multi-neighbor coverage, shifted/mirrored every-direction
edges, explicit mass source/sink accounting for reactions, long growth/agent
capacity stress, and representative current/2× interest fixtures. External pack
schema/generation and a type-enforced rule context remain unimplemented. Current
rollback identity comes from the checkpoint record, not historical prose naming
archives whose availability was never established.
