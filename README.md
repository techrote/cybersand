# Cyber Sand Engine

An initial, legally distinct foundation for a large-scale cellular-physics game
engine hosted by Godot 4. The eventual target is cyberpunk RPG and exploration
games spanning underground, urban, vehicle-interior, orbital, and vacuum
environments.

This milestone contains:

- A deterministic C++20 cellular simulation kernel.
- A byte-sized native material catalogue covering the complete attributed
  Sandspiel material set, with adapted executable bounded rule kernels.
- Forty-three additional construction materials for medieval/castle and
  chemical-factory/cyberpunk scenes; 41 are zero-radius inert hard surfaces,
  while Oak Timber and Thatch reuse the bounded combustible kernel.
- Sparse, signed-coordinate 128×128 chunks, 32×32 activity blocks, sleeping,
  dirty rectangles, explicit capacities, and interest-region preallocation.
- A Noita-inspired four-phase 64×64 in-place scheduler backed by a persistent
  native worker pool and deterministic one/multiworker replay.
- Conserved 8-bit Water mass with stable rest and render-only dithering.
- Directional density exchange plus lifetime-decaying Smoke that bubbles through
  opted-in denser media, thins faster in dense clouds, and cannot host Fire.
- Spatially staggered secondary-interaction lanes: transport remains full rate,
  while lifecycle, chemistry, thermal, and rare ignition work is spread across ticks.
- A normalized per-liquid viscosity index, with Water tuned for fast bounded
  dispersion independently of the retained paste/slush pressure yield.
- Four-byte hot cells plus optional per-chunk temperature fields.
- Bounded tick-boundary explosion events that remove a blast core and convert
  eligible static Wall into explicitly granular falling Stone.
- A preallocated native dirty-snapshot exchange with immutable consumer leases,
  deterministic patch order, retained dirty state under pressure, and C ABI access.
- A backwards-compatible C ABI plus a `godot-cpp` GDExtension that makes native
  World authoritative in bundled Linux and Windows x86_64 Godot builds.
- Native regression tests and a benchmark harness.
- A runnable Godot 4 material lab with a 1024×1024 world, independently
  adjustable shader viewport and simulation margins, native activity sleeping,
  conserved self-leveling Water, coherent-emission delay, optional adhesion,
  prototype Paste/Slush, Smoke density exchange, temporal snapshot smoothing,
  and live native scheduler counters.
- A minimum sampled-collision character with continuous jetpack thrust that
  remains separate from cell state.
- Three red 8×14 RigidBody2D test rectangles, pixel-derived Rapier static terrain,
  and a separate native transient obstacle field with bounded impact, pressure,
  swept displacement, and overlap results.
- Frame-budgeted, 64×64 chunk-owned Rapier terrain colliders, selectable 30/45/60 Hz
  interpolated texture publication, and distributed 0.5 Hz Fire checks keep
  visual flame motion at 60 Hz without burst-rebuilding world collision.
- Vendored Godot Rapier Physics 2D v0.35.2, selected as the sole rigid-body
  backend and advanced by an explicit main-thread manual-step bridge.
- A dedicated Godot simulation thread that owns cellular and character physics
  and publishes immutable snapshots to the render thread.
- A 64×256 palette atlas and unchanged four-texel material program whose
  reserved channel now selects bounded procedural masonry, grain, roofing,
  metal, wet-surface, glass, hazard, neon, and LED finishes on the GPU.
- Presentation-only moving bands on liquids and restrained glints on smooth
  manufactured metal; rough/hammered metals retain texture without sparkle.
- Forty-two GPU flair classes now include turbulent Smoke/Steam, collapsing
  bubble Foam, chemical bubbles, Mercury mirror bands, ice facets, organic
  fibres, charged-metal arcs, cloner circuitry, and layered flame/molten motion.
- Four-neighbour sampling of the existing RG8 texture adds directional bevels,
  liquid lips, and one-cell contact shadow without another world image/upload;
  a dual-radius HDR composite widens material glow entirely on the GPU.

The included Linux and Windows x86_64 builds use the native phased solver.
Other platforms retain the compact serial GDScript world as a compatibility
fallback; they require a platform build of `CyberNativeCellWorld` for
equivalent performance and Water behavior. See `docs/PERFORMANCE.md` for the
hot-path design.

## Build the native milestone

Requirements: GNU Make and a C++20 compiler.

```sh
make test
make benchmark
make shared
```

The m11 native release inputs are pinned in
`third_party/native-toolchain.lock.json`. The separate setup-cache v2 contains
the exact `godot-cpp` source archive and prebuilt Linux/Windows static libraries,
the SCons 4.10.1 wheel, and LLVM-MinGW 20260826. The tracked preparation script
reconstructs those tools offline and refuses checksum or revision drift.

To rebuild the included Linux GDExtension after building the pinned Godot 4.7
`godot-cpp` checkout:

```sh
GODOT_CPP_ROOT=/path/to/godot-cpp tools/build_native_extension.sh
```

To cross-build the included Windows x86_64 GDExtension with MinGW-w64 after
building the matching Windows `godot-cpp` static library:

```sh
GODOT_CPP_ROOT=/path/to/godot-cpp \
WINDOWS_CXX=/path/to/llvm-mingw/bin/x86_64-w64-mingw32-g++ \
tools/build_native_extension_windows.sh
```

`tools/build_pinned_godot_cpp.sh` gives the exact static-library commands, and
`tools/check_linux_runtime_floor.sh` verifies that the complete Linux bundle's
minimum glibc remains 2.34. This floor is imposed by the bundled Rapier2D
library; the CyberSand extension itself is built so it does not import the
newer `fmodf@GLIBC_2.38` symbol. The extension also requires a C++ runtime
providing `GLIBCXX_3.4.30` and `CXXABI_1.3.9`. See
`godot/native_extension/README.md` for the offline sequence and supported tool
versions.

The benchmark accepts optional arguments:

```sh
./build/benchmark [width] [height] [ticks] [chunk_size] [dense|sparse] [serial|phased] [workers] [preallocated|lazy]
```

For example:

```sh
./build/benchmark 1024 1024 120 128
./build/benchmark 2048 1024 120 128 sparse phased 4 preallocated
```

`preallocated` is the default and reports whether any chunk or optional-field
allocation escaped into the measured tick loop. The `buffered` enum value is
reserved for the comparison backend but is not implemented in this checkpoint.

## Run the Godot sandbox

1. Open `godot/project.godot` in Godot 4.7 stable. The audited M11 runtime used exact build `4.7.stable.official.5b4e0cb0f`; the add-on declares 4.7 minimum, but other builds are validation drift until tested.
2. Run the project.
3. Move with `A`/`D` and hold Space for jetpack thrust.
4. Pan with the arrow keys and press `F` to toggle follow/free camera mode.
5. Paint with the left mouse button and erase with the right mouse button.
6. Select prototype paint-tool slots with `1`–`6` (currently Sand, Water, Wall,
   Smoke, Paste, and Slush respectively), or use `Q`/`E` (Page Up/Page Down
   remain aliases) to cycle all 79 paintable materials. Use `Shift+Q`/`Shift+E`
   to jump between core/reactive, medieval, industrial, and luminous groups.
7. Press `C` to toggle coherent/calm emission. Normal emission preserves the
   fast spray/splash behavior. Coherent Water delays lateral spread for 12
   simulation ticks, then resumes ordinary flow so later edge falls still spray.
8. Press `T` to toggle the current Water surface-adhesion comparison. The native
   solver retains a small supported film by default; disabling it removes that
   threshold without changing gravity or density.
9. Press `V` to cycle the rendered logical viewport through 320×180, 480×270,
   640×360, and 960×540. Press `B` independently to cycle simulation margins
   through 0×0, 32×36, 128×128, and 256×256 pixels. The 1920×1080 game window
   aspect-fits the selected logical view; painting uses the same fitted rectangle.
10. Press `L` to compare the selected interest window with whole-world
    simulation, `K` to toggle temporal snapshot smoothing, `H` to cycle render
    publication through 30/45/60 Hz, `F3` to hide/show debug statistics, `G` to
    disable/enable material glow, `P` to pause, and `R` to reset.

Three red rectangles fall from above the character spawn after start/reset. They
use ordinary Godot `RigidBody2D` nodes backed by the vendored Rapier2D v0.35.2
PhysicsServer. The sandbox disables automatic space stepping, applies the newest
cellular response, advances Rapier once, batch-reads active transforms, flushes
once, and copies body state to the cellular worker. Wall pixels are merged into
static Rapier rectangles, so hard contact is solved once; fluid/particle samples
still provide bounded two-way forces. The worker receives no live Node or RID.

Paint slots and material IDs are separate namespaces. The current UI mapping is
`1→Sand (ID 2)`, `2→Water (ID 3)`, `3→Wall (ID 1)`, `4→Smoke (ID 4)`,
`5→Paste (ID 20)`, and `6→Slush (ID 21)`. Changing a key/slot mapping does not
change simulation identity. Painting is retained as a test/gameplay emitter;
equipment, enemies, and fixed or dynamic spawners can enqueue the same generic
material-emission command without using a paint slot.

The complete manual material list, interaction expectations, and controls are
in `docs/MATERIAL_LAB.md`. The construction IDs, visual grammar, performance
cost, and scene recipes are indexed in
`docs/systems/themed-construction-materials.md`.

The focused Godot interaction regression can be run separately:

```sh
godot --headless --path godot --script res://tests/test_cell_world.gd
godot --headless --path godot --script res://tests/test_material_appearance_lut.gd
```

The smaller Rapier migration checks are:

```sh
godot --headless --path godot --script res://tests/test_rapier_backend_preflight.gd
godot --headless --path godot --script res://tests/test_rapier_drop_in.gd
godot --headless --path godot --script res://tests/test_rapier_manual_step.gd
```

The focused native Fire presentation check is:

```sh
godot --headless --path godot --script res://tests/test_native_fire_presentation_regression.gd
```

The focused render publication checks are:

```sh
godot --headless --path godot --script res://tests/test_native_render_bridge_regression.gd
godot --headless --path godot --script res://tests/test_render_patch_handoff_regression.gd
```

## Important boundaries

- No Godot node, tile, or physics object is created per material cell.
- Gameplay code will communicate with the native simulation in bulk.
- Native render consumers lease copied material/state patches; they never retain
  a pointer into mutable World storage.
- Cellular physics uses fixed ticks and deterministic integer operations.
- Ordinary characters and vehicles remain separate entities. The Current
  rectangle proof projects RigidBody2D transforms into a cellular obstacle mask
  and returns approximate forces/corrections without sharing live Godot objects.
- Rapier2D is the sole runtime rigid-body backend. Explicit space stepping and
  batch active-transform extraction are current; generalized shapes, torque,
  and selective CCD/substeps remain planned.
- Strict deterministic replay remains a validation mode. Gameplay may use
  explicit bounded temporal/probabilistic fidelity policies to protect frame rate.
- Full-resolution simulation is local; macro space travel and distant worlds
  use a separate scale.

See `docs/ARCHITECTURE.md`, `docs/LARGE_WORLD_PROOF.md`, `docs/PERFORMANCE.md`,
`docs/STATUS.md`, and `docs/NEXT_MILESTONE.md` for the working design, measured
baseline, and immediate implementation sequence.

The implemented backend migration and remaining platform work are specified in
`docs/operations/rapier-2d-migration-runbook.md` and
`docs/decisions/ADR-009-rapier-2d-rigid-body-backend.md`.

The Sandspiel source audit and precise material-port status are documented in
`docs/research/sandspiel-performance-and-material-port.md`. See
`THIRD_PARTY_NOTICES.md` for attribution.
