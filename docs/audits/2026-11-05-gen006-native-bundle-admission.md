---
title: GEN-006 native cross-chunk semantic bundle admission negative control
status: Planned
document-kind: audit
scope: Exact-current-main isolated native semantic partial-commit experiment, not a streaming or atomic-admission implementation
last-reviewed: 2026-11-05
related-documents: [../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md]
---

# GEN-006 #194 — native cross-chunk bundle partial-admission control

**EXPERIMENTAL / Draft / DO NOT MERGE.** Source inspected on 2026-11-05: accepted main `ba9cbc89029be88b812af59b19e5c59829bbcd90` tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. This branch only adds one independent native test, one GitHub-hosted Linux workflow, and this dated audit. No native production implementation, Godot, ABI, material catalogue, physics, defaults, serialization or owner-locked file changes.

## New discriminating question and preregistered controls

The native `World::install_generated_chunk` method (native/src/world.cpp, around lines 2680–2741 on inspected main, header lines 236–242) offers **strict single-chunk** admission, not an atomic multi-chunk transaction. Does a naive host implementation that walks a connected semantic feature in chunk order commit a partial feature before a later chunk is refused? Test the **real compiled World**, not a Python stand-in.

One two-cell Wall bridge joins chunk (-1,0) at world x=-1 to chunk (0,0) at world x=0, y=64, with 128x128 generated material buffers. The control uses a hard Wall because it does not change due to granular motion. Exact same material spans and coordinates for each cohort. Each scenario is an independent World.

1. Both chunks absent, capacity >=2: positive control installs two halves, checks seam, then compares three genuine native ticks and physical-state/quantity hashes with a separately constructed identical World.
2. East chunk pre-reserved but entirely Empty: public `stored_material` is Empty for both absent and resident-Empty east, yet the installer refuses the resident. Naively installing west first leaves a partial bridge; refusing east first and stopping avoids that particular partial result (order dependence). Never overwrite resident Empty or infer untouched from material ID.
3. One-chunk budget: west accepted, east `CapacityFull`, with west retained.
4. Later east invalid material: west accepted, east `InvalidPayload`, with west retained.

Run same test with **1 and 4 configured** World workers and report `TickStats.worker_threads_observed` rather than assuming 4 participants. Failure of an ordinary native per-chunk method to provide bundle atomicity is **expected by its contract**, not proof of a production native defect. No host-side transactional implementation is offered or approved by this fixture.

### Executable evidence

Workflow: `.github/workflows/gen006-native-bundle-admission.yml` on Ubuntu 24.04 / g++-13. Compile unmodified `world.cpp`, `material_rules.cpp`, `scheduler_geometry.cpp`, `settled_world_discovery.cpp` and only `native/tests/test_gen006_bundle_partial_admission.cpp`. Run probe with timeout. Capture full source SHA/tree, compiler, policy, compiler and original run logs on success **or failure**. The exact-head runner receipt, not this document, establishes a hosted pass; until then **execution is pending, not a pass**.

### Ownership, exclusions and decision

The previous GEN-006 slices are distinct: #415 durable ACK fault model, #422 native material-only rehydration/whole-World ticks, #426 native generator/session fence with actual producer thread, #435 selective state/actor refusal. The earlier GEN-006 standalone Python bundle oracle was nonnative; this test provides the missing actual native discrimination. These experiments are not one unified implementation. #230 proposed codec is not admitted. #398 historical sleeping-MoltenGlass import remains an independent owner decision. #190–193 are closed prerequisites; #194, #204, #352–354 remain open.

No actual streaming, bundle transaction, chunk eviction/reload, durable storage, Water/boundary continuation, atomically reserved capacity, Rapier/actor pins, Windows/Godot or recipe reconciliation is implemented/tested here. Whole-World CYPS remains separate from per-chunk checkpoint authority. A source-only check that both spans appear Empty cannot certify absence; the owner needs a side-effect-free live residency and resource reservation boundary.

**Recommended next decision:** Admit an explicit owner-scoped **bundle plan + all-or-none commit/refusal** contract with signed-coordinate/plane identities, resident Empty and actor pins, full capacity reservation, single owner/tick boundary, generation/session/recipe/mutation checks and no partial visible installation. Only after accepted architecture, authorize a separate native owner implementation and actual boundary/eviction fixture. Do not merge this diagnostic, treat its green CI as streaming acceptance, modify existing writer branches, or close parent issues. Record progress and stop.
