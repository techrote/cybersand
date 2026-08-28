---
title: Legacy Godot sandbox performance notes
status: Ambiguous
scope: Historical prototype optimizations, reported measurements, reference-repository observations, and future directions
keywords: [legacy performance, activity blocks, epoch mask, texture upload, reference repository]
related-documents: [operations/profiling-observability-and-performance.md, operations/troubleshooting.md, reference/status-and-roadmap.md]
last-reviewed: 2026-08-27
implementation-state: Historical GDScript notes are retained below; bundled Linux and Windows x86_64 builds use the native phased GDExtension and dirty RG8 RenderBridge. The latest focused Linux ~30k-cell airborne-shower run measured 4.14 ms/tick.
---

# Godot sandbox performance pass

## At a glance

- Purpose: preserve the optimization history of the GDScript proof.
- **Current**: activity blocks, epoch-style update tracking, and indexed texture rendering exist.
- **Current**: preferred native activity remains full-rate and uses sleeping, interest filtering, and four-phase multicore scheduling.
- **Ambiguous**: historical performance numbers were not revalidated during documentation work.
- **Current**: the Godot overlay reports native phase jobs, selected worker count, simulation time, and independent snapshot/upload time.
- **Current**: ordinary native-to-Godot render copies are dirty RG8 patches; the patched CPU image still receives one full RG8 GPU update.
- Non-goal: reference-repository ideas are not implementation evidence for this project.

## Search anchors

legacy performance pass, activity block optimization, texture upload, historical benchmark, external falling sand reference

## Related decisions

- [ADR-002](decisions/ADR-002-double-buffered-tile-jobs.md)
- [ADR-003](decisions/ADR-003-godot-bridge-and-immutable-snapshots.md)
- [ADR-008](decisions/ADR-008-bounded-approximate-fidelity.md)
- [Profiling specification](operations/profiling-observability-and-performance.md)

## Current native result

`CyberSimulationWorker` remains the asynchronous fixed-rate owner, but its
preferred world is `CyberNativeCellWorld`. The extension invokes the same
compact C++ World used by native fixtures and dispatches non-overlapping 64×64
cores through a persistent pool. The old GDScript WorkerThreadPool experiment
occupied several processors but improved wall time by only 1.01×, so it is
disabled; the packed serial script path remains a compatibility fallback.

The focused Godot 4.7 Linux x86_64 airborne-shower probe placed approximately
30,000 separated Sand cells and advanced 60 full-world ticks. With seven native
workers the latest run reported a 4.14 ms mean tick, 37,238 visited cells,
30,582 updates, and 105 scheduled jobs on the final tick; an immediately prior
run reported 3.80 ms. A separate dense native comparison
measured 27.11 ms with one worker and 7.96 ms with eight before the adapter was
wired. These are hosted-container observations, not minimum-hardware gates.

Primary material is therefore not sub-sampled in the Current native runtime.
`K` blends immutable display snapshots only. Probabilistic low-rate work remains
appropriate for slow reactions and distant secondary fields, but Rapier fluids
do not replace authoritative Water or falling-sand collision.

The original reference sandbox did two expensive jobs in GDScript every rendered
frame: it scanned the entire 320x180 world and rebuilt an RGBA image one pixel at
a time. That was useful as a readable prototype, but it was not a viable render
or simulation path.

The first performance pass made four targeted changes:

1. Cells remain a one-byte `PackedByteArray` of material identifiers.
2. The array is uploaded as a 320x180 `Image.FORMAT_R8` texture in one operation.
3. A CanvasItem shader maps material identifiers to colours on the GPU.
4. Each row tracked only its active horizontal span; settled rows went to sleep
   and were woken by nearby movement or painting.

The large-world proof replaces row spans with 16×16 activity blocks. Separated
areas on the same row no longer force simulation of the entire horizontal gap.
Each block also caches its movable-cell count, so a woken block containing only
empty space and immovable walls is rejected before its 256 cells are visited.

The next pass adds cell-level quiescence inside those blocks. Movable cells that
find no legal move for eight scheduled ticks become dormant. A dormant cell is
skipped before its sand, liquid, or gas rules execute, even if another part of
the same block remains active. This is particularly useful for the buried
interior of deep liquid reservoirs.

Cell mutations clear quiet ages in a one-cell boundary ring. That ring crosses
block boundaries and remains schedulable during the timeout, so removing a
support, opening a cavity, painting material, or moving a neighbouring cell
reactivates the affected edge. Activity then propagates inward only as actual
changes occur.

The material lab retains a full-resolution 1024×1024 material array but renders
one of four independently selected logical views in the shader. Camera movement
therefore changes a uniform and does not move cell memory, repack an image, or
alter simulation coordinates.

The scheduler hard-freezes activity blocks outside the camera and selected
per-side pixel margin. The default 320×180 view and 32×36 margin form a 384×252
target region. `V` changes only the logical view; `B` changes only the margin.
Blocks touching that rectangle run; other awake blocks preserve their flags and
resume when the camera approaches. This bounds expensive cell scans by the
view, not by the finite proof world's total dimensions.

The earlier 320×180 pass uploaded 57,600 material bytes instead of constructing
57,600 `Color` values in GDScript. The Current material lab receives only dirty
native RG8 patches during ordinary revisions and applies them to a persistent
CPU image. `ImageTexture.update()` still submits the complete 2,097,152-byte
1024×1024 RG8 image, so a true GPU subregion path is the next rendering
optimization.

The status line reports FPS, worker-step and cellular-simulation time, snapshot
copy time, texture-upload time, snapshot age, cells scanned, cells moved, processed/deferred
activity blocks, eligible blocks, adaptive stride, rigid-body observations, and
worker overruns. Measure these separately: low simulation
time with high copy/upload time points at the presentation boundary; high
scanned counts point at activity tracking; increasing overruns mean the worker
cannot sustain its 60 Hz target.

The status line now distinguishes cells that ran material rules from dormant
cells rejected inside otherwise-active blocks.

## Water surface churn

Destinations are write-once per tick so lateral Water cannot cascade through a
cell written earlier in the pass. A vertical move into Empty does not stamp its
vacated source: bottom-up movement may fill it from above in the same pass. The
older symmetric source/destination stamp was the cause of the visible
every-other-line stepping effect.

Write-once destinations alone still allowed holes to exchange positions between
ticks. The first correction gave Water a six-step lateral budget, but that
stopped a one-cell-per-column staircase and produced visible piles. Current
Water instead carries an explicit direction and a free-flow sentinel until
obstructed. A second broad-pile correction separates normalized viscosity from
resting yield: zero-viscosity Water may cross up to 24 contiguous Empty cells in
one serial update, while a 256-cell stopped-edge look-ahead can reactivate a
front that still has lower Water ahead. A level surface remains still. The old
finite budget, higher viscosity, and nonzero pressure yield now drive the
prototype Paste and Slush materials rather than Water.

The fast Water front also produced useful spray and a capillary-looking film on
connected slopes. Both are retained deliberately. `C` marks emitted liquid as
coherent/calm by using a spare bit in the existing flow-direction byte. That
state survives vertical and density motion, carries no free lateral budget, and
cannot pressure-spread until its vertical run reaches stable support. It then
levels at one lateral cell per update; viscosity remains a separate material
rate. Surface adhesion is also a separate per-material trait. `T` provides a
tick-boundary comparison override that stops unsupported lateral bridging while
leaving gravity and density exchange intact.

## Simulation window and LOD proof

By default, only buffered camera blocks run. `L` toggles between windowed and
whole-world simulation for comparison. `K` separately toggles temporal cadence
LOD; when whole-world simulation is selected, distant active blocks can be
deferred to every second or fourth tick. Material pixels remain full resolution
and are never merged.

Independent of distance LOD, a wake-up burst now derives an adaptive stride from
eligible blocks with a soft target of 12 processed blocks per worker tick. The
3×3 block neighbourhood around gameplay interest remains full-rate. A changing
coordinate/tick phase distributes other blocks and retains their active state.
Broad liquid-level discovery performs eight deep column samples across
exponential distance bands instead of deep-scanning every candidate column; it
still checks every traversed row cell before moving.

This is temporal LOD only. Spatially grouping many cells into one simulated
unit is postponed until mass, energy, pressure, and mixtures have conserved
aggregate representations. Otherwise expanding a coarse block back into pixels
would silently create or destroy state.

## Current upload limitation

The shader pans across the full world texture efficiently. Native publication
and CPU reconstruction are now dirty-region based, but a material change still
uploads the complete 1024×1024 RG8 array. This is acceptable for an architectural
proof, not the final large-world renderer. A renderer-specific subregion path or
chunked GPU texture ownership should consume the existing dirty rectangles.

## Reference implementation lessons

The Tembrica browser example describes a fixed-timestep simulation with adaptive
resolution. Its shipped JavaScript uses a compact byte grid, bottom-up alternating
scan order, a byte update mask, a capped fixed-step accumulator, one bulk canvas
upload, and resolution coarsening after sustained low frame rate. The useful lesson
is compact data and bounded work, not JavaScript-specific code or blind threading.

This sandbox adopts the compact grid, update epoch, fixed-step cap, bulk upload,
and sleeping work set. It does not resize the logical world automatically,
because changing material resolution during an RPG session affects gameplay and
save-state semantics. Dynamic resolution is better applied to visual effects,
coarse conserved fields, or selected low-priority simulation layers.

References:

- <https://tembrica.com/en/sand-game>
- <https://docs.godotengine.org/en/stable/classes/class_image.html>
- <https://docs.godotengine.org/en/4.5/classes/class_imagetexture.html>
- <https://docs.godotengine.org/en/stable/tutorials/shaders/your_first_shader/your_first_2d_shader.html>

## Dedicated simulation thread

The Godot scene now moves the complete cellular tick and sampled-character
collision controller onto one dedicated `Thread`. The worker exclusively owns
mutable simulation state. Main-thread painting becomes queued commands; input
and camera interest are small mutex-protected values; rendering consumes an
immutable typed snapshot. Godot's documented `Thread`, `Mutex`, and
`wait_to_finish()` lifecycle are used without touching scene nodes from the
worker.

This should stop a slow GDScript tick from directly stalling input and rendering
and should make the process use a simulation core in addition to the main/render
work. It does not make one tick faster. If a tick exceeds its 16.67 ms budget,
the worker continues at the rate it can sustain and increments the displayed
overrun counter while the renderer keeps the newest completed snapshot.

The remaining cost of an active revision is a dirty RG8 worker payload plus one
full-world main-thread GPU texture update. Settled water avoids both by ceasing
to revise the world. Native snapshot size and CPU reconstruction now scale with
dirty rectangles; GPU subregion submission is the remaining presentation-side
reduction.

References:

- <https://docs.godotengine.org/en/stable/classes/class_thread.html>
- <https://docs.godotengine.org/en/stable/classes/class_mutex.html>
- <https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-delay-usec>

## Native multicore cellular jobs

Splitting the current in-place cellular scan across several workers would still
introduce data races and nondeterministic cross-boundary movement.

This historical section has been superseded: the standalone native World now
implements a Noita-inspired four-phase in-place scheduler and persistent worker
pool. Active-only buffered transfers remain a fallback rather than the leading
implementation. See [ADR-002](decisions/ADR-002-double-buffered-tile-jobs.md).

The retained ownership requirements are:

1. compute each chunk's interior in parallel;
2. record cross-chunk transfers in per-job boundary buffers;
3. sort and resolve boundary transfers in a deterministic phase;
4. exchange activity/wake flags;
5. upload only dirty regions through the Godot bridge.

The next integration milestone is the GDExtension bridge, not another GDScript
thread. Thread count is not itself the goal; bounded gameplay work, frame time,
and predictable scaling are.

## x1e7 reference review

The transferable ideas from `x1e7/falling-sand-engine` are compact cell state,
cached material rules, a bounded fixed step, deduplicated active regions, and
camera/world separation. The proof already uses the first, third, and fifth;
its 16×16 wake flags provide the basis for a future native active queue.

The reference's whole-buffer update bookkeeping and finite presentation model
are not adopted. The longer-term engine still requires sparse signed chunks,
deterministic boundary staging, independent render regions, and state that can
remain frozen or coarsened far beyond the camera.

Reference: <https://github.com/x1e7/falling-sand-engine>
