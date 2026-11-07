---
title: GEN-006 first native streaming vertical-slice prototype
status: Planned
document-kind: audit
scope: Isolated opt-in sharded native World demonstrator; not an admitted general sparse World storage design
last-reviewed: 2026-11-07
related-documents: [../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md]
---

# GEN-006: opt-in native streaming vertical slice — 7 November 2026

## Candidate and current boundary

Issue [#194](https://github.com/techrote/cybersand/issues/194). This Draft prototype was
initiated from accepted `main` commit `4c2c97323d862afdd3ec6730017127cc8e4ec05c`,
tree `8e970762a3678483a6fbb4c981005b0631315e1b`.
The exact tested candidate SHA/tree and hosted original evidence must be taken
from the implementation PR and `gen006-streaming-slice.yml` source receipts;
**source creation is not a claim of passing execution**.

The executable is `native/tests/gen006_streaming_slice.cpp`. Its purpose is to
move beyond negative-control research and exercise real generation, native
simulation and save/restore with actual native memory reclamation, without
taking protected `native/src/world.cpp` or sharing another worker's source.

### Architecture decision and substantial limitation

**EXPERIMENTAL, NOT PRODUCTION ADMISSIBLE.** A bounded serialized-owner
`StreamingSlice` holds at most two (configurable 1–4) **separate native
`World` instances**, each containing one physical 64×64 native chunk.
The owner uses the existing compiled `generation::Generator`, verifies its
receipt and performs real `World::install_generated_chunk` admission. On an
interest miss, it stages a new single-chunk World, saves the LRU World using
genuine `World::save_physical_state`, and destroys that World object.
A later demand restores the original native physical checkpoint using
`World::restore_physical_state`. This **really frees native World residency**;
it is not camera hiding or an interest-region filter.

This is **NOT** eviction of one chunk from the existing single shared World.
It does **NOT** simulate between neighboring chunks or serialize shared
actor/sidecar identities, boundary events, four-plane semantic features,
real Godot player/Rapier integration, cancellation or off-thread generation.
The owner restricts individual native Worlds to one chunk and explicitly
refuses simulation that exceeds that domain. The prototype's staged candidate
can briefly allocate one extra native World above the resident budget.
This is a temporary demonstration architecture, not a proposed replacement
for the shared-World native solver.

### Durability and scope

The `.g6s` opt-in record contains a magic/version, signed coordinates,
exact generator fingerprint, realm seed, conservative per-chunk mutation
generation, 4096-bit **explicit player edit-intent bitmap** (including
same-value and Empty edits), native CYPS bytes, strict bounded lengths and an
envelope checksum. The native decoder independently validates its CYPS
integrity. Unknown/changed recipes and malformed saved records refuse reload;
they never silently generate a replacement. The stored mutable native cell
state includes material/state/Water, thermal field, scheduler activity and
deadline metadata in the supported World checkpoint.

A synchronous single-owner filesystem publisher writes a same-directory
staging file, flushes and syncs file contents, replaces the per-chunk record
and on POSIX syncs its parent directory before destroying the resident World.
Win32 uses `MoveFileExW` with `MOVEFILE_WRITE_THROUGH`. **No** simulated
power-cut, Windows directory durability, concurrent writer, save root CAS,
disk exhaustion or network-share test has qualified these semantics. There
is no general storage migration/ABI contract and no durable cross-chunk
transaction. Temporarily unsupported domains must stay pinned in a future
shared-World implementation; this isolated prototype only ever allocates
its own native Worlds with no live actors or cross-chunk links.

### Build and run

From the repository root on Linux with GCC 13:

```sh
mkdir -p build/gen006-streaming-slice
g++-13 -std=c++20 -O0 -g0 -pthread -I native/include \
  native/src/world.cpp native/src/material_rules.cpp \
  native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp \
  native/src/world_generation.cpp native/src/generation_fields.cpp \
  native/src/generation_typed_fields.cpp native/src/generation_spatial.cpp \
  native/src/generation_grammar.cpp native/src/generation_planes.cpp \
  native/tests/gen006_streaming_slice.cpp -o build/gen006-streaming-slice/streaming-slice
build/gen006-streaming-slice/streaming-slice --self-test build/gen006-streaming-slice/test-1 1
build/gen006-streaming-slice/streaming-slice --self-test build/gen006-streaming-slice/test-4 4
build/gen006-streaming-slice/streaming-slice --interactive build/gen006-streaming-slice/world 1
```

Interactive commands: `focus CHUNK_X CHUNK_Y`,
`wall LOCAL_X LOCAL_Y`, `dig LOCAL_X LOCAL_Y`,
`water LOCAL_X LOCAL_Y MASS`, `tick N`, `status` and `quit`.
Move between `focus -1 -3`, `focus 0 -3` and `focus 24 -3`
to force eviction with a two-chunk cap. World pixel X at chunk 24 is 1536,
outside the old 1024-pixel finite view. The interactive command is **not**
a Godot scene, renderer or a representative speed benchmark.

The executable self-test uses a walled native Water17 container with
temperature417, an explicit Empty intent tombstone, four live ticks,
native checkpoint, genuine object destruction, disk reload, comparison
against uninterrupted physical hashes for three further ticks, and a
corrupted-file refusal before victim eviction. Both 1- and 4-configured
worker runs record **actual** worker observations separately; four configured
workers do not imply four workers execute. Execution and Windows portability
must be confirmed by the exact-source hosted workflow.

### Next required admission

Do not merge or promote this independent-World prototype as the production
streaming architecture. The next implementation milestone is one scoped
**selective eviction/restore API on the one shared native World**, including
unsupported-domain pins, atomic mutation-generation-fenced save ACK and
cross-boundary activity/transfer, approved by the protected-source owner.
Subsequently expose a genuine opt-in Godot camera/paint/tick UI. The prototype
provides a runnable workload and actual native restart witness for that
integration, rather than another invented model of World state.
