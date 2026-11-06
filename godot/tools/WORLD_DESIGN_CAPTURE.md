# World-design pack capture — experimental Godot tooling

**Status:** Experimental tooling; the original #457 and dependent Draft repair #462 are NOT production-admitted. Source parent: `tools/world-design-godot-capture-20261105` / `cff6c7f947147a250e5a5c3bb9d46b0df39b376c`, based on main `06522e300dcf91efbab0ac8f4f4370af72cf2029`. The original #454 oracle is pinned to `f68516b7e4faefb8c776a89169365a7e8dd55d37`; the repair's current read-only design snapshot is `e0da52a1d477606ac3ca737a9da2c9022cee4253`. Neither the design schema/art nor production renderer is changed.


## Dependent corrective Draft PR #462 — capture protocol and admission (6 November 2026)

This section describes the **repair implementation**, not permission to merge or a
claim of physical simulation/production qualification. Prior negative evidence is
retained in #457 and its original GitHub-hosted artifact archives. The independent
repair checks are in `godot/tests/world_design_capture_repair_campaign.py` and
`.github/workflows/world-design-capture-repair-qualification.yml`, with actual
Linux OpenGL/llvmpipe and Windows ANGLE outputs preserved as workflow artifacts.

- **R1 — fail closed transaction:** validate both directions of canonical
  pack/output containment, the CyberSand workspace root, existing-directory
  custody and every existing path component **before any output mutation**.
  Symlinks, Windows junctions and other reparse-point aliases in either path are
  rejected, including a nonexistent output child beneath a linked parent. A
  non-empty existing output is accepted only when it is an already-owned
  CyberSand capture root.
  Each attempt acquires an atomic sibling `.world-capture-claim` directory.
  Generated PNG/RG8/metadata remain in a unique sibling stage and never contain
  a success manifest. Publication moves the validated stage to an immutable
  `.world-capture-generations/<attempt>` directory inside the stable output
  root; the **only authoritative commit point** is the subsequent atomic
  replacement of root `capture-manifest.json`, whose entries point into that
  generation. The requested output directory and any previous generation are
  never renamed away. A malformed retry therefore leaves the previous committed
  manifest untouched. Hard-killed attempts retain their claim/transaction
  record; an operator may recover only by supplying the exact recorded
  `--recover-claim=<attempt-id>` after confirming the old process is dead.
  Fault-injected rollback failure retains both the non-authoritative generation
  and transaction record with `requires_recovery=true` rather than claiming
  restoration.
- **R2 — schema identity:** `schema_id` must equal
  `cybersand.world-feature-pack.proposal` and `schema_version` must be numeric
  one (Godot JSON parses integer JSON tokens as float values). Missing IDs,
  nonnumeric/unsupported versions and mixed `scene` / `combined_scene`
  placement structures fail rather than silently reinterpreting formats.
- **R3 — shader:** use existing `CyberPaletteShader.for_current_renderer()`.
  The selected full or ANGLE bounded-crossfade variant, raw source bytes,
  source-file binding, emission/composite/LUT script hashes, rendering method,
  driver, adapter and actual graphical Godot executable SHA-256 are recorded.
- **R4 — budgets:** `--max-working-mib=16..1024` (default 256) rejects estimated
  excessive combined RGB8 buffers, RG8 source/texture, tile+halo HDR viewport
  buffers, detail crops, staged and previous output duplication, before any
  output image allocation. Per-output physical pixels are capped at 16,777,216
  as well as existing native size and 32,768-pixel side limits. Large-width
  collections above 1,024 native cells remain supported; limits are
  conservative estimates rather than measured peak allocator usage.
- **N1 — smoke:** isolated input/output roots; two real graphical child captures,
  pixel/hash repeat, source isolation, structured manifest checks, shader
  detail variation, and a malformed same-destination second invocation.
- **R5 — provenance:** `source_revision` and `design_pack_revision` are retained
  for backward discovery but are explicitly caller-declared. `source_identity`
  distinguishes caller declaration from independently obtained clean Git HEAD
  and now verifies `godot/project.godot` as well as capture tools, scripts and
  shaders. `render_source_sha256` records the actual project configuration,
  palette-selector, LUT and shader bytes that can affect a capture.
  `design_revision_verified` is null for read-only exported packs outside a
  Git checkout; `pack_sha256` is the immutable content address. For policy
  requiring a checked-out exact source, use `--require-verified-source=on`,
  which fails if the declaration does not match a clean checkout **or if any
  verified renderer/configuration source is dirty**.

The fault-injection switches `--test-fail-publication=on`,
`--test-fail-rollback=on`, `--test-pause-before-publication-ms=N` and
`--test-pause-phase=framebuffer|validated|prepared|published-data` only work
with `CYBERSAND_CAPTURE_FAULT_INJECTION=1`; these are test-only knobs, never
production capture defaults. Qualification hard-kills a real Godot process in
all four windows. None of those pre-commit states contains authoritative
complete-success metadata. `--recover-claim=<attempt-id>` is not automatic:
it is an explicit stale-claim recovery action and archives the prior transaction
record rather than deleting it.

A fixed time repeats byte-identically on the same platform/rendering settings.
Alternate tile sizes may produce tiny off-seam GLES3 floating-point differences
without any boundary-band seams: the repair campaign retains exact differing
pixel coordinates, counts, bounding boxes and maximum channel deltas. It tests
horizontal **and** vertical joins at multiple tile sizes/scales in square, wide
and tall material-varied fixtures on Linux llvmpipe and Windows ANGLE, alongside
the historical Lumen comparison. The gate requires zero changed pixels within
32 physical pixels on each tested join and bounds off-join rounding to 5/255
per RGB channel affecting no more than 0.25% of pixels. This is *not* a
cross-platform byte-equality claim and does not relabel the historical strict
pixel mismatch as a parity pass.

Evidence must be source-pinned to the actual tested commit; the workflow
retains raw files with `SHA256SUMS.txt` recomputed **after** the runner's live
stdout log closes. Original failing runs are kept distinct from later corrected
runs. Full 15-collection/120-feature current-design graphical acceptance and
human reference comparison remain separate, subsequent activities.

## Command

Use an actual Godot 4 display-backed renderer in a checked-out source tree.
Keep PR #454's source separate and **read only**, for example by exporting
`docs/world-design` from its exact head. Do not cherry-pick it into this
tooling branch and do not edit the art-worker's pack files.

```sh
CYBERSAND_SOURCE_REVISION="$(git rev-parse HEAD)" godot --path godot \
  --script res://tools/capture_world_design_pack.gd -- \
  --pack=/absolute/read-only/design/world-design/lumen-fault/pack.json \
  --output=/absolute/captures/lumen-fault --mode=both \
  --scale=2 --time=1.37 --glow=on \
  --design-revision=f68516b7e4faefb8c776a89169365a7e8dd55d37
```

Options: `--mode=combined|individual|both` (default both),
`--scale=1..8` (integer, default 2), `--time=<nonnegative finite seconds>`
(default 1.37), `--glow=on|off` (default on), `--tile-cells=even 64..2048`
(default 512; viewport including halo must remain <=8192 physical pixels).
`--pack` is an explicit path and `--output` must be absolute.
`--design-revision` records the **caller-provided** design Git revision;
if absent it is marked unverified. Source SHA is recorded from the explicit
`CYBERSAND_SOURCE_REVISION` environment value, never inferred from unrelated
files or claimed by the tool without that value.

### Contract

1. For `scene`: apply declared `rectangles` OR `terrain_rectangles` in
   order, then all feature placements in order (`feature`, `x`, `y`,
   `variant`). For `combined_scene`, apply `feature_id`,
   `origin=[x,y]`, `variant` in order, with no implicit terrain. In
   particular, `baseline_y` is **metadata**, not a fill or erase operation.
2. Feature rectangles are `[x,y,width,height,native_material_id]`. Their
   local geometry is translated into whole native scene cells. Last stamp
   wins; explicit material ID 0 erases, whereas unassigned Empty cells do
   not erase any other region. Missing IDs, negative/excessive geometry,
   reserved ID 10, invalid variants and out-of-bounds placements **fail**.
3. Create **native** `Image.FORMAT_RG8` inputs, R=native material ID and
   G=synthetic presentation condition. Condition policy exactly follows the
   baseline `capture_material_review.gd` fixture: `3:255, 4:240,
   6:240, 11:32, 12:255, 15:1, 18:32, 22:180, 30:180, 34:12,
   37:120`, `36:200` as explicitly **synthetic** molten-glass heat,
   all others 0. This is not a measured native simulation state.
4. Render with the **existing** `material_palette.gdshader`,
   `material_appearance_lut.gd` material and program textures,
   `material_emission.gdshader`, and `glow_composite.gdshader`.
   The condition projection, stable water dither, structured details and
   growth appearance are enabled, using frozen time on both shader passes.
   Player/Rapier overlays are out of view. No native simulation tick runs.
5. All PNGs originate from **Godot SubViewport texture readback**.
   The render path tiles when needed; each tile uses the entire RG8
   world texture and a 32-native-cell halo so shader neighbour reads and
   post-composite glow are world-aligned across stitches. Only GPU-rendered
   pixels are copied/cropped with `Image.blit_rect`. The output dimensions
   equal **native scene dimensions multiplied by scale**, without cropping
   to a 1024-wide texture. If an output/device capacity prevents a complete
   image, the process fails rather than labelling a partial image complete.

### Output

For `--mode=both`:

- `combined.png`: full combined-scene framebuffer image.
- `features/<feature-id>.png`: each standalone feature in **base** variant
  (specific scene-selected variants appear in the combined image).
- `details/first-*.png`, `details/last-*.png`: lossless, native-resolution
  crops of the actual combined framebuffer image around the first/last
  placements; not separately simulated or upscaled.
- `inputs/combined.rg8`, `inputs/<feature-id>.rg8`: exact immutable
  renderer inputs, with cell dimensions, SHA-256 and geometry/variant
  attribution recorded in `capture-manifest.json`.
- `capture-manifest.json`: created **only after all requested captures
  succeed**. Records source, pack revision, actual pack SHA-256, input
  geometry+hashes, condition policy, graphics/OS identities, time, glow,
  scale, tiled dimensions, shader+LUT hashes, PNG paths/dimensions/bytes/hashes.
- `capture-status.json` and `WORLD_DESIGN_CAPTURE` structured log line:
  exit status 0 success; 2 malformed inputs/schema; 3 unavailable graphical
  renderer or shader/LUT; 4 failed framebuffer/readback; 5 I/O failure.
  An earlier complete manifest is invalidated before the next capture.

Use distinct output directories for separate packs and compare their
manifests. Bulk captured PNG/byte products belong in downloadable
GitHub Actions artifacts or durable outside-PR storage, not committed in
bulk to this code-only PR. A contact sheet may be generated separately but
must not be labelled the raw shader capture.

## Tests

```sh
# Geometric oracle/negative cases; executable without drawing.
godot --headless --path godot \
  --script res://tests/test_world_design_pack_adapter.gd
# Real framebuffer smoke; MUST be run with a display backed renderer.
xvfb-run -a godot --path godot \
  --script res://tests/capture_world_design_pack_smoke.gd
# All 15 full-width PR454 source packs, exact independent RG8 SHA-256 oracles.
godot --headless --path godot \
  --script res://tests/check_world_design_pack_oracle.gd -- \
  --packs=/absolute/read-only/PR454/docs/world-design \
  --design-revision=f68516b7e4faefb8c776a89169365a7e8dd55d37
# Existing applicable real material presentation check, same display constraint.
xvfb-run -a godot --path godot \
  --script res://tests/test_material_presentation_render.gd
# Existing sample shader capture (not a regression test).
xvfb-run -a godot --path godot \
  --script res://tests/capture_material_review.gd -- \
  --output=/absolute/captures/material-review --clip-frames=0
```

The first test checks an independently hand-enumerated RG8 byte oracle and
precomputed SHA-256, placement order, explicit Empty, condition bytes,
base/named variants, both scene families, >1024 width, and malformed cases.
The graphical smoke spawns the actual capture entry point twice, checks
successful output/manifests/PNG byte repeatability and masonry shader
pattern variation, and checks an invalid pack's nonzero exit. It returns 77
instead of a false green result if no renderer is available.
Do not substitute a headless graphical run or a synthetic CPU preview.

### Exact PR #454 geometry inspection (5 November 2026)

The original pack bytes were read from the exact PR head via the connected
GitHub repository. A separate JS validation of geometry, bounds, IDs and
selected variant dictionaries **passed for all 15**. This was a source-data
inspection, NOT a run of the new Godot adapter or shaders.

| Collection | Scene shape | Native dimensions | Features | Feature rectangles | Terrain rectangles |
|---|---|---:|---:|---:|---:|
| Lumen Fault | scene.rectangles | 640×256 | 8 | 115 | 15 |
| Chalkbone Coast | scene.rectangles | 768×256 | 8 | 135 | 19 |
| Carved Ice Choir | scene.terrain_rectangles | 800×320 | 8 | 151 | 15 |
| Ashroot Nursery | scene.terrain_rectangles | 960×330 | 8 | 165 | 7 |
| Emberglass Fumaroles | scene.terrain_rectangles | 1056×238 | 8 | 182 | 138 |
| Silt Clockworks | scene.terrain_rectangles | 1184×264 | 8 | 325 | 450 |
| Signal Orchard | scene.terrain_rectangles | 1220×296 | 8 | 366 | 12 |
| Dust Meridian | scene.terrain_rectangles | 1320×280 | 8 | 194 | 12 |
| Cathedral of Capacitors | combined_scene | 1240×278 | 8 | 280 | 0 |
| Mirror Marsh | combined_scene | 1320×308 | 8 | 306 | 0 |
| Drowned Observatory | combined_scene | 1320×280 | 8 | 553 | 0 |
| Ironroot Necropolis | combined_scene | 1270×310 | 8 | 905 | 0 |
| Tectonic Archive | combined_scene | 1360×316 | 8 | 474 | 0 |
| Coral Telegraph | combined_scene | 1370×324 | 8 | 1424 | 0 |
| Fallow Carnival | combined_scene | 1420×226 | 8 | 976 | 0 |

All packs contain eight placements. A combined scene wider than 1024 is
ordinary in this set and requires full-width or tiled shader readback.
The native material sample checks excluded reserved ID 10.

**Additional executed source-data check:** An independent in-memory RG8
reconstruction processed all 15 exact-source packs, applied their terrain
and placed feature rectangles and variant swaps in order, and computed
SHA-256 on each complete RG8 array: **15/15 completed, 0 coordinate
or conversion errors, 9,874,024 combined RG8 bytes**. Independently
calculated expected RG8 hashes, dimensions and source Git blob IDs
are retained in
`godot/tools/world_design_pack_expected_rg8_20261105.json`.
The separate `check_world_design_pack_oracle.gd` program compares the **real
Godot adapter** against all 15 independent expected arrays once Godot
and the exact PR454 read-only source export are available. This checksum
generation did **not** execute Godot and cannot establish shader correctness.

### Qualification and art-worker handoff

**Existing evidence:** external source-pack shape inspection and a
second full-geometry, independent expected-RG8/SHA-256 reconstruction
have executed in this author's environment. The environment had an Xvfb display but
`command -v godot` reported no Godot binary. Consequently there are
**no actual adapter PNGs, no Godot test exits, no cross-GPU/Windows
qualification, and no verified full-pack engine-capture claim** in this
checkpoint. This is an actionable, material blocker; it must not be hidden
by draft-state CI skips.

Before any adoption: an independent owner must run the two new executable
tests, obtain real Godot captures for at least Lumen Fault, Emberglass
Fumaroles, Cathedral of Capacitors and Coral Telegraph, check exact
shader/pack revisions and pixel/provenance hashes, then try all 15 combined
and 120 standalone renders. Validate tile seam equality (including glow),
shader pattern and emission evidence under Vulkan/ANGLE as applicable,
native/static material identity and reproducible fixed-time results. Run
the applicable repository Docs/retrieval/native-scope checks and preserve
their original exit statuses. Do not treat this synthetic presentation
as native World/physics validation or as a change to engine design authority.

**For the three currently paused art workers:** after the user independently
reactivates them, use a read-only source export for each owned pack, run this
tool `--mode=both`, preserve manifest+raw PNGs as review artifacts, and
compare human-visible output against all five canonical gallery references.
Edit ONLY your owned art directories on #454; never modify shared shaders or
this adapter opportunistically. Continue to treat the quality target as
unaccepted until human review. This documentation **does not restart** any
scheduled worker or the Scheduswarm dispatcher.

**STOP:** Keep the tooling PR Draft, do not merge, mark Ready, or assert
production acceptance.
