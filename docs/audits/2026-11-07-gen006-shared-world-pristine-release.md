---
title: GEN-006 shared World first selective release (pristine Empty only)
status: Planned
document-kind: audit
scope: Opt-in native ownership primitive, no dynamic-chunk persistence or production promotion
last-reviewed: 2026-11-07
---

# First genuine shared-World chunk release

This is a bounded implementation, not proof of the full GEN-006 persistence milestone. It starts from accepted main. No existing engine call path or C ABI is changed.

## Native operation

World::release_pristine_empty_chunk(coord) removes and destroys one native resident chunk inside the SAME shared World. The enclosing World and all other chunks remain resident. Native chunk count and allocated cell/activity bytes fall, freeing capacity for another World::install_generated_chunk call.

The operation is deliberately restricted to a chunk admitted by install_generated_chunk with a full all-Empty payload, never edited or dirtied. Even a same-value external Empty edit invalidates the witness. The witness is deliberately NOT restored from whole-World checkpoints, so historic saved chunks fail closed.

Refuse: nonempty/active/dirty/thermal state, any resident neighbour in a one-chunk halo, failed or in-progress tick, transient actor ownership, pending explosions, pressure, IN, granular arrival witnesses, ballistic Water, settled discovery, or diagnostic physics. Clear the native fast chunk directory pointer before deletion and invalidate hard-surface publication.

This first safe case needs no per-chunk save because an unmodified Empty chunk has no edit intent or mutable content. It is NOT a codec for edited chunks, Water, external actors, multi-layer structures or active boundary effects.

## Executable acceptance

The native C++ test gen006_shared_world_pristine_release.cpp compiles the real production World and executes for configured 1/4 workers. It verifies: full two-chunk capacity, actual native memory reclaimed for a pristine Empty resident, stable other Wall chunk, capacity reusable for a third chunk, a real subsequent native tick, and refusal without mutation for no-op Empty edits, state edits, restored CYPS, adjacent residency, and discovery-enabled sidecars.

The dedicated GitHub-hosted Linux/Windows workflow checks exact PR head and source blob identities and retains original compiler/test evidence. No pass is claimed before actual jobs complete.

## Next production gate

Dynamic selective eviction requires native per-chunk physical/sidecar checkpointing, owner mutation-generation fencing, durable save/ACK, pending boundary/halo and event handling, externally owned bodies, and complete semantic bundle authority. Until independently implemented and accepted, those domains remain pinned. Retain Draft and do not merge this experimental first primitive into main without separate integration approval.
