---
title: Legacy large-world and entity proof
status: Ambiguous
scope: Historical description of the finite Godot camera/entity/activity prototype and proposed native replacements
keywords: [legacy, large world proof, camera, panning, activity, LOD, entity]
related-documents: [systems/world-storage-and-interest-region.md, systems/activity-dirty-regions-and-waking.md, reference/status-and-roadmap.md]
last-reviewed: 2026-09-08
implementation-state: Historical finite GDScript proof only; native phased authority, finite 1024² adapters, rectangle occupancy, and level saves supersede earlier replacement plans. Sparse streaming remains Planned.
---

# Large-world and entity proof

**Historical proof description.** The 960×544 world, 16×16 activity, six-cell
Water budget, percentage-derived margins, and proposed replacements below are
retained milestone history. They are not current implementation requirements or
new validation results. Current native geometry is 128×128 storage, 32×32
activity, and 64×64 phased cores; finite adapters use 1024² levels and pixel-margin
presets. Consult [world storage](systems/world-storage-and-interest-region.md),
[current roadmap](reference/status-and-roadmap.md), and the
[2026-09-08 audit](audits/2026-09-08-documentation-audit.md). CYSD1 reconstructs
finite levels; sparse streaming and exact replay saves remain Planned.

## At a glance

- Purpose: preserve the rationale behind the current larger finite Godot proof.
- **Ambiguous**, historical: this proof separated a 320×180 view from a 960×544 finite world; the current material lab is 1024² with runtime view and margin presets.
- **Current**: character, camera, interest filtering, and rectangle rigid-body coupling remain integrated through Godot; cellular authority is native on bundled Linux and Windows x86_64 builds.
- **Current**, fallback only: adaptive activity cadence remains in GDScript.
- Non-goal: this legacy proof is not evidence for current level serialization, sparse streamed loading, or exact replay continuation.

## Search anchors

legacy large world, current camera panning, current entity proof, cadence LOD, planned native replacement

## Related decisions

- [ADR-004](decisions/ADR-004-interest-region-and-reconfiguration.md)
- [ADR-002](decisions/ADR-002-double-buffered-tile-jobs.md)
- [Current status](reference/status-and-roadmap.md)
- [Rigid-body coupling](architecture/rigid-body-and-cellular-coupling.md)

This proof expands the runnable Godot reference from a 320×180 simulation to a
960×544 world while retaining a 320×180 camera. It is an architectural test,
not a commitment to a finite world or a GDScript production simulator.

## Historical implemented separation

The proof has four independent layers:

1. `CyberCellWorld` owns material cells, deterministic updates, activity blocks,
   movable counts, and world-space occupancy queries.
2. `CyberSampledCharacter` owns position, velocity, walking, jetpack thrust,
   and swept sampled collision against the cell world.
3. `main.gd` owns input, the camera, fixed-step orchestration, image upload, and
   shader parameters.
4. `CyberSimulationWorker` exclusively owns the first two layers while running
   and publishes immutable `CyberSimulationSnapshot` objects to `main.gd`.

The character is never written into the cell array. The shader composites it
over the cellular texture. This keeps gameplay entities compatible with future
Godot or native rigid-body physics and avoids reserving material IDs for every
entity type.

Character interaction remains one-way: terrain and the new body mask block the
sampled character, but material does not see the character. Rigid-body
interaction is now two-way in the rectangle proof: three RigidBody2D transforms
project a separate mask and receive packed cellular observations without
turning bodies into material cells.

## Activity blocks

The GDScript reference groups cells into 16×16 activity blocks. Every block
stores a movable-cell count and double-buffered awake flag.

- Blocks containing no movable cells are skipped even when neighbouring changes
  wake them.
- A move wakes only the blocks intersecting its small neighbourhood.
- Painting wakes the edited neighbourhood.
- A block with no subsequent movement falls asleep.
- Within awake blocks, cells that fail to move for eight scheduled ticks become
  dormant and are rejected before material movement rules run.
- Every mutation wakes a one-cell boundary ring, including across activity-block
  boundaries, so changes propagate into dormant volumes without keeping their
  interiors hot.
- Only blocks intersecting the visible camera plus its simulation buffer update.
- Frozen off-screen blocks retain their awake state and resume when the window
  reaches them.
- When whole-world simulation is enabled for comparison, distant active blocks
  may update every second or fourth tick while retaining every original pixel.
- Under wake-up overload, excess eligible blocks are distributed across ticks
  with a soft target of 12, while the 3×3 neighbourhood around gameplay interest
  remains full cadence and every deferred block retains its wake flag.

The camera is 320×180 cells. Its buffer is derived from the view size: 10% per
horizontal side (32 cells) and 20% per vertical side (36 cells), giving a
384×252 target simulation rectangle away from world edges. The scheduler works
at 16×16 block granularity, so boundary blocks may add up to 15 cells beyond the
requested rectangle. Increasing the future camera size automatically increases
the buffer without changing scheduler constants.

Cadence reduction is temporal simulation LOD, not destructive spatial
downsampling. It demonstrates that simulation detail and render detail can be
independent. Actual coarse spatial simulation should wait until conserved
quantities such as mass, temperature, pressure, and mixture composition have
aggregate forms.

## Liquid surface stability

Movement destinations are now write-once within a simulation tick. A cell
vacated by lateral movement cannot be reused by another lateral move until the
next tick. A vertically vacated Empty source deliberately remains available to
the cell above in the bottom-up pass; stamping it previously manufactured
alternating empty rows. Stable surface
cells subsequently age into local dormancy; a new neighbouring flow, terrain
edit, or material displacement wakes them again.

The next liquid pass retains the visually sparse pixel distribution but gives
each falling or freshly painted water cell six cells of lateral travel budget.
Horizontal moves spend that budget. Once exhausted, a cell can spread sideways
only if a six-cell local column comparison finds the source meaningfully deeper
than the destination. Equal-height holes therefore stop exchanging positions
and the existing eight-tick quiescence can finally put the surface to sleep.

## Camera and coordinates

Camera movement changes a shader uniform only. It does not shift cell memory,
entities, or world coordinates. The shader converts each 320×180 view pixel to
an absolute world cell and samples the 960×544 R8 material texture.

The finite array will eventually be replaced by native sparse chunks addressed
with signed 64-bit coordinates. The camera and character APIs already use world
coordinates, so the replacement need not change their semantics.

## Lessons adopted from FallingSandSurvival

The reference project separates a loaded region, simulated region, collision
mesh region, and camera; caches chunks independently; uses compact contiguous
world arrays; schedules separated chunks through a worker pool; builds terrain
collision meshes separately from cellular state; and keeps ordinary entities
outside the primary material grid.

Those are useful architectural directions. This project does not adopt its
full-world visited-mask clears, direct shared-memory cross-chunk writes, mutable
loaded-buffer coordinates, or per-cell material object layout.

References:

- <https://github.com/PieKing1215/FallingSandSurvival>
- <https://github.com/PieKing1215/FallingSandSurvival/blob/dev/FallingSandSurvival/world.cpp>
- <https://github.com/PieKing1215/FallingSandSurvival/blob/dev/FallingSandSurvival/Chunk.cpp>

## Lessons retained from x1e7/falling-sand-engine

The smaller reference reinforces several choices already compatible with this
project: compact numeric cell state, a fixed simulation step, deduplicated
activity regions, cached material behaviour, and separation between world and
camera coordinates. The new camera-window scheduler applies the bounded-work
principle without copying its implementation.

This project does not adopt a finite viewport as the world model, clear a
world-sized moved mask every tick, repaint the entire visible image cell by
cell, or depend on unfinished shared-memory threading. The current byte epoch,
shader camera, independent entity controller, and future deterministic chunk
jobs remain intact.

Reference: <https://github.com/x1e7/falling-sand-engine>

## Hexagonal grouping

A hex grid is not used for the visible material cells. It would require either
non-square texel reconstruction or an irregular mapping between stored cells,
rendered pixels, collision samples, and tools. Six neighbours also increase the
minimum interaction reads compared with the current four cardinal plus selected
diagonal movement rules.

Hexagonal topology remains plausible for coarse fields where isotropy matters:

- pressure and atmosphere;
- low-frequency heat transport;
- long-range electrical potential;
- coarse navigation or influence fields.

Those fields should access neighbours through a topology interface so square,
hexagonal, and room-graph representations can be compared without changing the
pixel material grid.

## Compute shaders

The cellular and rendering simulations are now separate enough to add compute
work later, but direct in-place GPU sand movement is not the first target. It
would complicate determinism, readback, save-state inspection, CPU collision
queries, and conflicting writes.

The safer compute order is:

1. lighting, colour variation, normals, and visual-only effects;
2. heat diffusion and coarse pressure using ping-pong buffers;
3. optional far-field gas or liquid relaxation;
4. only then, an experimental fully GPU-resident material solver.

PhysX is not a direct model for this problem: GPU rigid-body broadphase and
constraint solving differ from millions of cells competing to write adjacent
grid locations. Godot's `RenderingDevice` compute API is the relevant future
integration point.

## Historical proposed technical replacements

1. Move 16×16 activity metadata into each native chunk.
2. Replace the proof's full block-flag scan with a deduplicated active-block
   queue or compact bitset once the native scheduler owns activity.
3. Return camera-sized material-ID regions from the GDExtension rather than
   uploading the complete finite reference world.
4. Add per-chunk render textures and upload only dirty spans.
5. Generate collision contours asynchronously for static terrain consumers.
6. Replace Current rectangular occupancy with generalized collider rasterization,
   bounded sweep/substep coverage, and explicit particle/overflow outcomes.
7. Replace cadence-only LOD with conserved coarse state for far chunks.
8. Stage boundary transfers before native multicore scheduling.
