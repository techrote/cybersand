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


## Persistent Godot/native controller — implementation continuation

The opt-in Godot scene now launches **one long-lived native process** with
\`--serve WORLD_ROOT IPC_ROOT [1|4] [TICK_HZ]\` instead of invoking a new
\`--batch\` process for every click or key. That process owns one
\`StreamingSlice\` and its resident native Worlds for the entire scene lifetime.
Godot sends monotonically sequenced request files and receives atomic response
receipts plus the existing copied 64×64 RGBA frame. The process identity is
checked on every response; mutable native cell storage still never crosses the
process boundary.

The service runs native simulation continuously at 30 Hz by default even when
Godot sends no command. The Godot view refreshes the authoritative copied RGBA
frame at 10 Hz. Camera arrow input immediately changes signed chunk demand;
moving beyond the two-shard budget invokes the same save/destroy/reload LRU
path inside the **same native process**. Mouse Wall/dig/Water edits therefore
act on a persistent native World rather than a reconstructed process per input.
The service saves every resident shard on orderly shutdown.

\`tools/experiments/gen006_persistent_controller.py\` is the source-matched
acceptance fixture. It requires one stable native PID across requests, autonomous
tick advancement while idle, real camera-driven eviction/reload, restored edit
intent/Water17 state and an orderly shutdown receipt on both configured worker
counts. The existing cross-process persistence test remains separately valuable:
persistent interactive ownership and restart durability test different failure
boundaries.

This is a substantial playability improvement but deliberately remains an
**experimental IPC controller**. It is not production GDExtension ownership,
does not provide one shared native World across chunks, and still has no
cross-shard cellular transport, Rapier body persistence, async proposal
cancellation, multi-plane bundle transaction or recipe reconciliation. Those
remain follow-on GEN-006 production architecture work.


## Native unsupported-tick containment and player-edit continuity — 7 November 2026

**Candidate scope: opt-in experimental one-World-per-64x64-shard controller only.**
Independent real-process failure [#507](https://github.com/techrote/cybersand/pull/507)
showed that camera demand to the native surface chunk `(-2,1)` could overflow the
one-chunk simulation capacity, terminate the persistent native process and lose
a still-resident acknowledged Empty player edit in healthy chunk `(-2,2)`.
Original Ubuntu/Windows negative [run #42332574666](https://github.com/techrote/cybersand/actions/runs/42332574666)
remains preserved. The repair **does not** claim cross-shard transfer.

`StreamingSlice::simulate()` now creates a bounded, actual native CYPS physical
checkpoint **before each shard tick**, with a hard per-shard 2 MiB source cap.
Successful native ticks commit the conservative mutation generation. A tick
that throws or violates the one-chunk native domain rolls back the affected
World from the same pre-tick native checkpoint and marks only that resident
`simulation_pinned=1` with reason `GEN006_UNSUPPORTED_NATIVE_TICK`. This
explicitly refuses further simulation for that shard; its material, Water,
temperature, edit-intent, activity/deadline state and native tick index are
preserved rather than saving a partially failed World. Other healthy resident
shards continue ordinary native ticks, and a clean controller shutdown saves
the restored pinned shard alongside all surviving player edits.

The native service publishes an explicit `SIMULATION_PIN` diagnostic. The
`status` receipt includes `pinned=N`, per-chunk `pinned=0/1` and the
reason. The opt-in Godot HUD displays pin count and the affected chunk. Pins
are **volatile per residency**, not a silently new saved-state schema: an
evicted/reloaded unsupported shard may be probed, refused and pinned again.
There is no catch-up while pinned, and no validation of cross-shard physics
continuity. The snapshot-per-tick approach is deliberately bounded for this
**prototype** and incurs real serializer/restore overhead; it is not a
production-friendly 30 Hz transaction design.

The integrated `tools/experiments/gen006_surface_owner_containment.py`
converts #507's genuine expected-crash scenario into a **positive** native
owner-survival acceptance. It launches separate real native OS processes,
creates an explicit Empty tombstone, generates the known unsupported surface,
requires a visible pin with unchanged pre/post failure native physical hash
and native tick index, checks the original PID survives, confirms the safe
native World keeps ticking and proves clean quit/restart preserves the
tombstone. Both configured worker counts (1 and 4) run on hosted Ubuntu and
Windows, with exact native `World`/generator compilation, source receipts,
native stdout/stderr and original test evidence retained.

At the first repair checkpoint, [native run #42334885058](https://github.com/techrote/cybersand/actions/runs/42334885058)
passed on **Ubuntu 24.04 and Windows Server 2022**, including all four new
containment cases (configured workers 1/4 per platform). Both reported
`native_pid_survived=1 unsupported_surface_pinned=1
safe_native_ticks_continued=1 Empty_intent_restart=1`; the successful
regular streaming/restart/coordinate-binding tests are retained. The
source-matched [actual Godot OpenGL framebuffer run #42334885107](https://github.com/techrote/cybersand/actions/runs/42334885107)
also passed. These are bounded draft-source results; the full production
Native/GDExtension/physical desktop matrix remains skipped or unqualified.
Do not misreport four **configured** workers as four actually participating
native workers: the small existing fixture observes only one.

**Next architectural gate:** Replace the one-World-per-shard substrate with
a properly owned single native World that can selectively checkpoint, delete
and restore chunks while respecting cross-chunk mass, events and activity;
then switch the Godot demo adapter to that shared-World owner. The present
rollback/pin is a safe experimental refusal, not completion of general
GEN-006 streaming or replacement for approved source-owner admission.

## Acknowledged player edits survive abrupt process termination — 7 November 2026

**Opt-in one-native-World-per-shard demonstrator only.** Previous restart
acceptance exercised orderly `save_all()` and/or LRU eviction. A successful
`dig`/`wall`/`water` command previously could be acknowledged solely in RAM
and lost if the owner was killed before save or eviction. This is distinct
from the independently repaired surface-tick failure in #507.

Each player edit is now applied to a **privately restored real CYPS World**.
The candidate retains material, state, Water quantity, temperature, scheduler
state, monotonic mutation generation and explicit Empty/same-value intent.
The owner persists the candidate via the existing bounded file sync/replace,
then swaps it into the live resident and emits the receipt:

    GEN006_EDIT_DURABLE_ACK chunk=(X,Y) local=(X,Y) generation=N physical_hash=H native_tick=T file_published=1

Preparation and pre-publication failures retain the old live native World,
and cannot return the successful edit ACK. This remains a serialized single
owner and synchronous filesystem mechanism; it is not an async, multiwriter
or crash-proof transaction. A rename that succeeds followed by a directory
sync failure is still a commit-uncertainty boundary requiring future work.

The actual-native fixture `tools/experiments/gen006_durable_edit_ack.py`
drives two separate operating-system processes. Process one applies five
edits to signed chunk (-1,-3), including Empty intent and a native contained
Water17/temperature417, demands five monotonically increasing file-published
ACKs, and is then **killed without quit, save_all or resident eviction**.
Process two must reload the identical saved record with original edit intent,
Water17, temperature417, mutation generation and record SHA-256. The
`gen006-streaming-slice.yml` workflow runs the fixture with configured
native workers 1 and 4 on actual hosted Ubuntu and Windows. Check results
before claiming PASS; source creation alone is not execution.

**Limits:** Simulation proceeds after the last edit, and subsequent native
simulation-only changes are not automatically disk-committed each tick.
Hardware power loss, Windows directory durability, cross-shard mass, Rapier
actors, sidecars, historic MAT-AUTH import and a shared-World native API
remain unqualified. Per-click native clone/serialization + sync imposes
measurable cost; replace with a qualified batching/journaling policy before
production adoption. No production ABI, defaults or CYPS codec were changed.

## Nonblocking camera/edit Godot host — 7 November 2026

**Experimental opt-in prototype; not default game integration or a replacement
for the protected shared-native-World residency engine.** The first persistent
Godot scene synchronized every 10 Hz render request, camera move and paint
command with a blocking five-second native IPC wait on the Godot input/render
thread. A slow native checkpoint therefore froze interactive camera movement
and rendering, even though native simulation ran in a separate process.

The standalone `godot/tests/gen006_streaming_slice_demo.gd` now uses an
**actual per-frame asynchronous file-IPC state machine** for interactive play:
one explicitly sequenced native request in flight, a coalesced latest-demand
camera refresh, at most **16** ordered player commands, and native command
responses sampled without waiting on the input/render thread. Every queued
player edit carries the signed chunk coordinate of its input event and is
preceded by native owner `focus` before the edit; later camera motion cannot
silently paint a different chunk. Each render response is accepted for the
requested chunk only if it still matches the latest camera target. The HUD
shows copied-frame versus requested coordinates, BUSY/READY IPC state, queue
depth/backpressure, successful **native durable-edit ACK** count, request
latency and actual resident eviction/reload receipt counts.

**Correctness/failure boundaries:** A mouse edit while the requested camera
chunk is not yet rendered is visibly refused rather than painting a stale
frame's invisible destination. A full command queue visibly refuses new edits
(no false ACK). Only the exact native
`GEN006_EDIT_DURABLE_ACK` receipt counts as successful edit publication.
Timeout, mismatch, missing ACK or native disappearance is treated as an
ambiguous/failed outcome; the host never transparently replays an ambiguous
edit. On orderly scene exit, native pending responses and queued player edits
are drained within a bounded seven seconds before quit; an unresponsive owner
is explicitly diagnosed and fail-stopped rather than orphaned. This is not
hardware power-loss or arbitrary process-kill durability, and the separate
experimental Persistence & Throughput worker owns future storage optimization.

The existing `godot/tests/gen006_graphical_qualification.gd` retains its
deliberate synchronous deterministic fixture; this does **not** describe the
normal player-input execution path. A new isolated, **actual OpenGL** test
`godot/tests/gen006_async_input_qualification.gd` checks zero synchronous
native requests during rapid signed-coordinate arrow input, ordered
asynchronous Wall ACK, coalesced camera demands, refusal of a click on a
not-yet-rendered chunk, 1536-pixel movement through more than two genuinely
resident native Worlds, native eviction/reload, original native PID survival,
correct original-chunk edit intent on native readback, and a real framebuffer
PNG. `gen006-graphical-qualification.yml` builds the actual native
World/generator and executes both paths in independently started Godot 4.7
OpenGL/Xvfb processes, retaining original frame/source/runtime hashes.

**Execution provenance:** The first combined Actions
[run #42347311372](https://github.com/techrote/cybersand/actions/runs/42347311372)
passed its preexisting eight-frame real Godot workload but **FAILED** the new
second step due to the step-local GitHub Actions environment not inheriting
`GEN006_SLICE_EXECUTABLE`. No native/Godot correctness claim is made for that
failed step. The corrected, exact-head
[run #42347430238](https://github.com/techrote/cybersand/actions/runs/42347430238)
passed both real OpenGL tests: the asynchronous test reported one native PID,
82 microseconds for the input burst, a durable edit ACK, two actual native
evictions, one reload and an original 1280×800 PNG (SHA-256
`0b3872ef2a5cfb129333f7f5c669567ddbd64edc0842cf1c8fd066fcf423830d`).
Its [original evidence ZIP](https://github.com/techrote/cybersand/actions/runs/42347430238/artifacts/13563879166)
is preserved. **These results precede the later stale-frame/refusal and
bounded shutdown corrections**; those must receive their own final exact-head
qualification before claiming their execution succeeded. No assertion of four
actually participating native workers is made.

**Remaining limitations:** A single initial synchronous startup/render handshake
still runs before interactive control begins. The serial file transport is a
prototype and accepts at most one in-flight request; the cost of each native
checkpoint remains with the separate persistence lane. Continuous native
simulation may advance beyond the last acknowledged edit without a committed
simulation-only checkpoint. The demo still uses one real native World per
shard, not selective chunk eviction from the same shared World, nor
cross-boundary Water/actor/semantic sidecar persistence. Protected #512 was
not imported; its independently reproduced stale-incarnation ACK defect
remains an explicit integration blocker pending the Native Residency Engine
owner's corrected contract. Current production defaults, materials, ABI and
physics are unchanged.

## Slow native checkpoint/ACK — responsive live Godot extension (7 November 2026)

**Implementation, pending exact-head runtime qualification at source creation.**
The existing nonblocking host used one five-second deadline for both
deterministic synchronous QA and interactive persistent native requests. A
slow disk checkpoint could therefore turn a still-running native owner into a
terminal Godot error after five seconds, with an ambiguous player-edit
outcome. The native process may later complete the original request, but the
former Godot pump stopped reading it.

The **opt-in interactive** pump now distinguishes two deadlines: an
**observable 1.5-second soft warning** and an **explicit 30-second hard
deadline**. Until the hard deadline, it holds the same one sequenced
in-flight request, never acknowledges or automatically replays an edit,
preserves the ordered bounded player-action queue, and keeps Godot
camera/render input responsive. The HUD reports BUSY/SLOW/READY, host
request age, peak completed round-trip time, and total slow requests.
These are **host IPC elapsed times**, NOT native checkpoint, fsync,
worker throughput or durable-publication timings. These will be integrated
only from the separately qualified Persistence & Throughput contract.

An implementation-owned extension of the **actual compiled native plus
Godot 4.7 OpenGL** asynchronous test sends a second native Wall edit after
stopping the *specific private native child* using Linux SIGSTOP. For
6.2 seconds it requires an actual 1280x800 rendered framebuffer
(`09-slow-native-ack.png`), visible soft warning, unchanged native PID,
one in-flight request, **zero fabricated durable ACKs** and no fatal host
timeout. SIGCONT must permit the *original* in-flight request to finish,
deliver one native durable ACK with a measured >5s host round-trip, and
preserve the new player intent in the authoritative native World. The
existing shutdown/restart acceptance then verifies the separate final edit.
The test resumes the child before asserting a failure; it never kills or
modifies a shared native service.

**Boundaries:** synchronous initial launch/render and deterministic fixture
retain their existing five-second timeout; the experimental native
checkpoint algorithm, save format, material rules, ABI, shared-World
selective residency and default production behavior are unchanged.
A 30-second hard timeout is fail-stop with an explicitly UNKNOWN native
edit outcome; it must not be interpreted as rollback, recovery, or a
license to replay. Orderly shutdown remains bounded at seven seconds
with an UNKNOWN outcome on failure. Linux SIGSTOP is a deterministic
test-only fixture, not an actual Windows/desktop power-loss result.
The native Windows/Linux qualification and real Godot results must be
checked at this exact final HEAD before claiming success.

## Experimental native-backed continuous brush (7 November 2026)

The opt-in Godot demo now interpolates held-mouse Wall/dig/Water strokes across coalesced pointer events. Every cell is submitted separately through the existing single-owner native ACK queue. The maximum 16 pending player actions, signed-chunk binding, stale-frame refusal and original native durable ACK requirements remain unchanged. When queue admission fails, interpolation stops instead of silently skipping cells. The new actual-Godot/OpenGL acceptance tests one coalesced five-cell stroke, genuine native ACKs, signed World cell intent and restoration after a separate native process restart, preserving an original framebuffer PNG. Tests must pass on the exact resulting source before claiming qualification. This is a Draft, sharded-World-only Godot host feature; production Native, ABI, solver and default physics remain unchanged, and independent storage/residency owners retain their respective interfaces.


## Signed chunk x/y + Go UI (7 November 2026)

Opt-in Godot prototype adds a signed-chunk X/Y LineEdit pair and Go button,
also Enter-activated. Bounded signed integer validation accepts at most
±4096 chunks (±262144 native world pixels), rejects malformed/out-of-range
input before native IPC, and never silently clips. Each camera jump requests
one coalesced latest target; existing queued edits remain bound to their
original signed source chunk, with the same strict backpressure, stale-frame
refusal and real native durable acknowledgments. Arrow/Home navigation shares
the new camera transition helper and cancels a held mouse stroke. No protected
native/physics, MAT-AUTH source lock, storage, default, ABI or producer
branch was modified.

The new actual-native/Godot OpenGL regression exercises the real Go button,
three invalid-coordinate refusals, Wall editing, positive (22,2), next
(23,2), negative (-24,2), and return (-2,2). It requires stable native
PID, bounded resident Worlds, actual evictions/reload, authoritative
persistent Wall intent and three original framebuffer PNGs. This remains a
SHARDED native-World experimental capability, NOT in-place selective
shared-World eviction or cross-shard Water continuation. Final exact-head
Windows/Linux and Godot CI evidence must be checked before declaring PASS.
