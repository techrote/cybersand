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

## Extended implementation: G6KC1 lossless static chunk checkpoint and durable CAS

The next (still opt-in, still Draft) implementation introduces a separate
native per-chunk G6KC1 envelope and three real native operations.

1. capture_chunk_checkpoint(coord) stages immutable bytes with signed
   coordinates, geometry, backend, ambient temperature, 64-bit mutation
   generation, source completed-tick serial, exact cell values/registers
   and epochs, inactive activity-block quiet counters, render dirtiness,
   hard-surface invalidation words and optional temperature arrays.
   The body is bounded with versioning and SHA-256 integrity. It is read-only.
2. The exclusive durable storage owner fsyncs a same-directory temporary
   file, atomically publishes it and (on POSIX) fsyncs the directory,
   then reads back the complete record and verifies exact bytes.
   Only then may it construct a bound ChunkDurableAck. Native
   evict_durable_checkpoint verifies the ACK coordinate, generation,
   source tick and digest, then recaptures the current native chunk and
   demands exact byte equality before deleting the live authority.
   No new edit, simulation tick, changed source or missing ACK may pass.
   The host owns the filesystem durability assertion: native cannot
   independently establish that a caller actually invoked fsync.
3. restore_chunk_checkpoint(expected, bytes) validates the SHA-256 envelope,
   coordinates, schema, dimensions, material domain and quantities into a
   private chunk candidate before admitting it into the same World. It
   restores all admitted cell, temperature and quiet-block bits and the
   mutation generation. The global World tick is never rewound or
   walltime-caught-up. Native Wall cell-count accounting is updated on
   removal/re-admission so whole-World CYPS validation stays coherent.

### Explicit supported domain

Lossless within this bounded domain: isolated static Wall/Empty chunks,
including edited nonempty Walls, same-value player Empty edit-intent
tracked in an explicit per-cell opt-in bitmask AND mutation generation, exact native cell state/epochs, optional
stored temperatures and fully inactive activity metadata with no pending
future deadlines. An original checkpoint can be read by a new process's
fresh World and restored without reconstructing terrain. Other resident
native chunks remain alive within the same original World.

Pinned/refused: moving/reactive Sand or Water, all other non-Wall/Empty
materials, neighbouring chunks within a one-chunk halo, active or scheduled
blocks, pending events, pressure/inertial/ballistic/granular sidecars,
settled discovery, transient bodies/actors, construction-bound quantity
histories, semantic multi-plane/fixture authority and reconfiguration.
This is NOT universal dynamic-chunk continuation, cross-shard transport,
production GDExtension admission or a safe generic save codec.

### Executable acceptance and source gates

The new native test gen006_chunk_checkpoint_transaction.cpp uses the real
CyberSand World on hosted Windows/Linux with configured workers 1 and 4.
It performs actual durable file publication, generation/tick staleness and
no-ACK refusal, checksum tampering, coordinate mismatch, edited Wall and
temperature restoration, same-World other-resident continuity, native
quantity-ledger validation, cold restart and unsupported dynamic-domain
refusal. Report actual observed workers, not merely configured workers.

The material-catalogue compatibility test protects reviewed world.cpp LF
bytes. This new source transition is intentionally NOT repinned by the
implementation. An independent admission of that protected source and
exact-head full Native/Godot qualification is required before Ready or
merge. Native scoped test passes cannot override that gate.

The per-cell GEN-006 edit-intent mask is opt-in via gen006_track_edit_intent=false by default. It is allocated only under this experimental flag and serialized in G6KC1; old whole-World CYPS has no mask, so a restored historical World cannot silently claim admission into this checkpoint domain. Query gen006_player_edit_intent_at() to verify exact Empty tombstone coordinates after native restart.



## Real native Sand boundary negative control

A Windows/Linux real-native experiment found the important boundary blocker
for expanding G6KC1 beyond static Wall/Empty. A Sand sample inside a complete
64x64 Wall perimeter caused the native solver to claim a neighbouring chunk
before it became checkpoint-eligible (Windows witness: NeighbourPinned at
completed tick 52, two resident chunks). The apparently sealed *material*
perimeter does not itself prove isolated native scheduling/ownership.

The strengthened test now insists that every attempted Sand checkpoint
refuses **without changing physical hash, owned bytes or chunk count**, and
verifies actual native neighbour admission. It cannot be promoted to a
single-chunk lossless state transaction. The next dynamic milestone must
implement an owner-admitted **multi-chunk/halo bundle checkpoint** with
quantity and pending-work transfer, not bypass the refusal or fake stability.

Only Wall/Empty + opt-in exact edit intent + inactive activity blocks and
temperature are currently checkpoint-eligible.


## Cross-process and byte-identical final acceptance

The static transaction now asserts that re-capturing the original native
World immediately after eviction+restore yields the **exact same entire G6KC1
byte sequence and SHA-256 digest**, not merely the same displayed materials.

The hosted Windows and Linux workflow then launches the native transaction
executable **a second time** in --reopen mode for each worker configuration.
That independent OS process reads the file published by the first process,
validates its SHA-256 and restores Wall state, temperature417, both precise
Empty tombstones and quantity accounting into a new native World. Full
new-process custody remains test-only; production host save scheduling,
multiwriter power-cut resolution and dynamic-state bundles are still separate.


## Signed-coordinate G6KC1 restore preflight — 7 November 2026 (Draft)

This bounded extension protects the existing opt-in static G6KC1 path;
it does **not** expand the supported material or sidecar domain.
Before any directory lookup or allocation, chunk capture and restore now
apply the **same** signed cell-origin multiplication limits and
maximum-rule-radius endpoint preflight as
`World::install_generated_chunk`. A checkpoint with a correctly recomputed
SHA-256 is still refused if its chunk coordinates would overflow native
cell/rule arithmetic. Invalid attempts must not alter resident count,
allocated cell bytes or physical hash. The finite chunk-directory mirror
in this path also avoids signed-subtraction overflow.

The test publishes a real native World G6KC1 record, rewrites *both* its
signed chunk-coordinate fields and SHA-256 using
`tools/experiments/gen006_chunk_signed_extent_qa.py`, and executes
`native/tests/gen006_chunk_checkpoint_transaction.cpp --extent` in fresh
native processes. It checks twelve rehashed cases per worker setting:
eight out-of-domain multiplication/rule-radius endpoints refused without
state mutation, and four just-inside-boundary coordinates restored with
Wall/temperature417/precise Empty intent intact. Both Windows and Linux
workflows run worker settings 1 and 4; their exact-head runtime results
must be checked separately and are not presumed passed here.

**Still blocked:** The independently reproduced stale-residency ACK ABA
scenario in Draft #514 is **not** repaired by coordinate preflight.
Unique native admission-incarnation fencing across remove/re-admit and
`World::clear()` requires controlled changes to protected source/headers,
to be reconciled with concurrently active physics and MAT-AUTH source
ownership. Do not merge, mark Ready, repin compatibility without owner
review or promote the static experiment to dynamic streaming.
