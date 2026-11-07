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

## Implementation continuation — coordinate-safe native reload and process restart (7 November)

**Source checkpoint:** On the same Draft PR #486, reconciled the previous
prototype onto accepted main `3d953ed1c1f5bd0bcf582359d47863689b9e2310`
without replacing newly accepted native World, GDExtension or material changes.
Requalification applies to the final exact branch and GitHub-hosted merge source;
earlier run receipts do **not** qualify later edits.

### Restore identity correction (native owner-boundary)

Independent support PR #490 found that changing only the outer record coordinate
could relabel a valid inner native A checkpoint as B. The body checksum remained
valid; the previous restore accepted the one-chunk World without checking which
chunk was resident. This was **actually reproduced** on Windows/Linux in
[run #42320652643](https://github.com/techrote/cybersand/actions/runs/42320652643).

The builder now validates the requested coordinate against the decoded native
World before `focus()` commits any resident eviction. The first prototype
requires `maximum_chunk_count == 1`, `chunk_count() == 1` and a healthy World.
The existing `install_generated_chunk(c, Empty[4096])` preflight returns
`AlreadyResident` for correct B and `CapacityFull` for a different chunk.
These outcomes are read-only **under current native source implementation
and this exact one-chunk scope**. They are not a general-purpose native
residency API and must be replaced when a shared World selective-eviction
API is admitted. No native World source, C ABI, checkpoint format or simulation
policy changed.

The self-test now injects a relabelled A checkpoint under B's path,
requires `GEN006_RESTORED_CHUNK_COORDINATE` refusal with existing resident
hash and count unchanged, restores the intact B record successfully and
reconstitutes A's original Water17. Original CYPS-corruption refusal remains
a separate control. This is a deliberate correction to the prototype, not
proof of production-wide untrusted-save security.

### Actual independent operating-system process restart

`tools/experiments/gen006_cross_process_restart.py` runs **three separate
native executable processes** against one private save directory. The first
genuinely creates, simulates, paints Water17/temperature417, writes an explicit
Empty tombstone and exits through `save_all()`. The second process restores
the native World and verifies exact Water state, edit intent, physical hash,
completed tick index, then focuses a distant x=24 chunk to force actual
destruction, returns and reloads the source. A third process independently
restores the persisted state and compares all receipts.

The read-only `inspect LOCAL_X LOCAL_Y` command prints actual native cell
material, liquid mass, stored temperature and explicit edit-intent bit.
These values come from the native World; they are not Python model state.
The dedicated workflow runs this acceptance under one/four **configured**
workers on both Ubuntu and Windows with original process stdout/stderr in
the retained CI artifacts. Qualification status follows the exact-head
workflow; a four-worker setting is not proof of four active workers.

Run the local additional acceptance after building the existing native
executable (the directory must not exist before the run):

```sh
python3 tools/experiments/gen006_cross_process_restart.py \
  --exe build/gen006-streaming-slice/streaming-slice \
  --root build/gen006-streaming-slice/restart-probe \
  --logs build/gen006-streaming-slice/restart-logs --workers 1
```

**Unchanged HOLD:** This is still separate one-chunk Worlds, not selective
removal from the production shared World. Cross-chunk Water/halo/event transfer,
live Rapier and multi-plane bundle ownership are explicitly unsupported.
The synchronous record is not a qualified power-loss or multi-writer transaction.
Camera/player-driven Godot display and input are not yet integrated. The most
valuable next implementation step is an opt-in Godot host for the same native
cells while preserving these exact save/refusal controls, coordinated with
the production adapter owner; subsequently replace sharded Worlds with an
owner-admitted shared-World selective eviction transaction.

## First opt-in Godot visualization path — isolated executable handoff

The Draft branch now includes `godot/tests/gen006_streaming_slice_demo.tscn`
and its companion GDScript, **not linked from the ordinary feature launcher**.
This separate proof uses the existing real native `World::copy_rgba` renderer
to emit a 64×64×4 = 16,384-byte copied RGBA frame. The Godot host reads that
bounded byte array into an `ImageTexture` and draws it in a 640×640 viewport.
It never receives mutable native cells or shares any native memory.

Because a production GDExtension/world owner has not admitted the streaming
adapter, this first visualization uses a **synchronous subprocess**. The native
CLI's `--batch DIRECTORY COMMANDS_FILE [1|4]` reads a local command script;
the earlier interactive command remains supported. Godot writes the script
into a private save root and invokes the exact compiled native executable via
`OS.execute`. Each input action starts and closes a real native World session,
reloads the saved physical state, applies its action, exports the native RGBA
cells and saves resident chunks before returning. Mouse: left Wall, right
Empty/dig, middle Water17. Arrow keys change the signed chunk coordinate;
Shift+arrow jumps 24 chunks (1536 world pixels); Space ticks native simulation,
R reloads; Home returns to (-1,-3). Moving through a three-shard focus cycle
forces actual native eviction/reload, displayed in the receipt panel.

**Manual desktop launch** (after building the native command; ordinary gameplay
defaults are untouched):

```sh
export GEN006_SLICE_EXECUTABLE="$PWD/build/gen006-streaming-slice/streaming-slice"
# Optional: export GEN006_SLICE_ROOT="$PWD/build/gen006-streaming-slice/manual-save"
godot --path godot res://tests/gen006_streaming_slice_demo.tscn
```

The hosted smoke copies the scene/script into a minimal standalone Godot 4.7
project, downloads the exact pinned Godot binary/checksum from the repo's
Godot CI policy, and runs the same script headlessly with
`GEN006_SLICE_VERIFY=1`. It requires a real native frame and eviction/reload
receipt. **A headless image/scene acceptance is not an actual graphical desktop
playtest or proof of production shader rendering.** Manual interaction,
native-to-Godot frame latency and graphical capture qualification remain open.

**Major scope HOLD:** Restarting a synchronous process on every UI input is a
prototype bridge, not a production GDExtension streaming runtime. The
two-World budget applies inside each subprocess; the Godot host does not keep
a continuous native World across frames. Cross-shard Water transport, Rapier,
shared-World selective chunk deletion, async job fencing, power-cut recovery
and recipe reconciliation remain unimplemented. The next product-facing step
is an owner-coordinated live GDExtension/World controller, preserving the
no-default-change and explicit unsupported-domain refusal contracts.


## Actual Godot framebuffer qualification — preserved #496 evidence

Independent support PR #496 qualified this exact prototype through an actual
Godot 4.7 OpenGL compatibility framebuffer under Xvfb, rather than only the
earlier headless ImageTexture smoke. The source-matched run is
[Actions #42327654878](https://github.com/techrote/cybersand/actions/runs/42327654878),
stacked on #486 head `7d00e63e7f09f6dc9aeb8bd502c2dbc3a6ee4913`. The original downloadable artifact is
[gen006-actual-godot-viewport-42327654878-1 / #13556425122](https://github.com/techrote/cybersand/actions/runs/42327654878/artifacts/13556425122).
The integrated workflow retains subsequent framebuffer evidence for 90 days.

The five **original framebuffer PNGs** from that accepted run are identified
by these immutable SHA-256 receipts, recorded here so the original evidence is
not conflated with later reruns:

```text
bd3e2042afeca56b648d872caca8427e9242aaf3a1d022d6c2cc6ecfa8ea5be9  01-dug.png
2985ca19ecfbc3596699232ef4de4de1e10d302062461a8cdadb1d1fe2ea07f5  02-painted-wall.png
3e6ec7375d57d348bf89d5ad5a91843c6fb72071c6e6ce150ee574178bb5e5ac  03-distant-chunk.png
57c843e1d6995518876163e0534710fe5375b406b53441e845e3bddc72021198  04-reloaded-wall.png
b804e2d966c857ec72a018b770113285f599eed789a01d5c44b906dcd2c16aa5  05-water17.png
```

That run passed `GEN006_GODOT_GRAPHICAL_FRAME_PASS` with real native RGBA,
actual framebuffer readback, mouse dig/Wall/Water interaction, a 1536-pixel
camera jump, real shard eviction/reload and restored pixels. These screenshots
are prototype evidence only; they are not production renderer or human desktop
gameplay acceptance.
