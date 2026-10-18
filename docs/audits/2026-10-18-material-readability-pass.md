---
title: Material readability and shader consistency pass
status: Current
document-kind: evidence
scope: 2026-10-18 baseline review, bounded palette/LUT/glow-control changes, paired rendered captures, tests and matched presentation cost; owner visual acceptance not claimed
canonical-for: []
last-reviewed: 2026-10-18
related-documents: [../systems/material-appearance-and-rendering.md, ../systems/themed-construction-materials.md, ../reference/product-intent-and-priorities.md, ../MATERIAL_LAB.md]
---

# Material readability and shader consistency pass — 2026-10-18

**Status:** an implemented, reviewable presentation candidate with paired
rendered evidence. Software correctness and measured temporal stillness are
established below; **observed visual improvement is the author's review, and the
owner's preference is not yet recorded.** No native, physics, RG8 wire-format,
reaction, scheduling or body-ownership source changed.

## Identities

| Item | Value |
|---|---|
| Base (`origin/main` at start) | `23227bc4d660b516306f111b7a7e4398208afa5d` |
| Baseline capture source | `cc9399653983cda9d663d047c974e2dc3f334eab` (base + behavior-neutral `presentation_time_override` + capture fixture) |
| Candidate | branch `mat/material-readability-shader-pass`; exact head in the PR |
| Native runtime (unchanged) | `cybersand_native.windows.x86_64.dll` SHA-256 `aeaa28ba2681ddd11f10fffd8ce8f96b5abf578fa65a20ec976074dc0860cd88` (matches `runtime-provenance.json`) |
| Godot | `4.7.stable.official.5b4e0cb0f` Windows x86_64 (official `Godot_v4.7-stable_win64.exe.zip`, SHA-256 `02a53122…bcd71`, release SHA-512 verified) |
| Renderer / GPU | `gl_compatibility`, OpenGL 3.3.0 NVIDIA 581.80, NVIDIA TITAN RTX, Windows 11 Pro 10.0.26300 |
| Reconciliation | PR #159 (MAT-001) merged to `main` as `ec05d72` during the pass and was merged into this branch (`38a3c62`); its Windows runtime `61e4ad3a0288c1479098a78c36f64efda6764beacbece917532751f4eb39ffe7` matches its provenance. Repeated after the merge: full Godot regressions, both graphical tests, the native Laboratory capture (RG8 at tick 90 byte-identical to the pre-merge runtime's, so the paired evidence stands) and live desktop/Web glow captures. |
| Parallel work | PR #159 (MAT-001, native reaction scheduling) and PR #148 (PENV-002, touches `main.gd`) were open; neither touches the shaders or LUT. Shader pairs use identical RG8 inputs, so no physics difference is attributed to shaders. |

## Apparatus

- [`capture_material_review.gd`](../../godot/tests/capture_material_review.gd)
  renders explicit RG8 inputs through the production palette, emission and
  glow-composite shaders in an HDR 2D viewport (as `main.gd` configures the root),
  320×180 logical view at 1920×1080 output, `main.tscn` background, and saves
  framebuffer readbacks. `--shader-root`/`--lut-script` render another
  revision's presentation sources through the same fixture; baseline sources
  were extracted with `git show cc93996:<path>`. Every image records RG8 SHA-256,
  camera, output size, glow, blend and `presentation_time_override`.
- Plates: all 81 rows (inventory, condition = native creation value, Molten Glass
  heat synthetic), matched liquid trays plus dry/wet construction pairs, large
  construction/metal/glass panels with corners and 1/2-cell partitions, emission
  and atmosphere against dark and light surroundings with condition sweeps, a
  previous/current transition strip, a synthetic street composition, and the
  native Materials Laboratory (`materials/contact-lab`, seed 0, 1 worker,
  Inspect, observers off; publications after ticks 89/90).
- [`analyse.py`](../../tools/material_review/analyse.py) reduces captures:
  per-region frame-to-frame luma change over 90 frames at 30 fps (1×, glow off),
  crossfade endpoint agreement on eligible pixels, labelled sheets, heatmaps and
  APNG clips. Derived images are named as enlarged/annotated; raw readbacks are
  unmodified.
- [`capture_controller_scene.gd`](../../godot/tests/capture_controller_scene.gd)
  drives the real `main.tscn` and `web_main.tscn` controllers (Web controller
  hosted natively, not in a browser) through Laboratory scenarios and the
  controllers' own `G` handling.
- REC-001/F10 recordings were not used as shader evidence (they omit the
  condition channel and the final shader/glow output).

```text
<godot> --path godot --script res://tests/capture_material_review.gd -- --output=<dir> [--shader-root=<dir> --lut-script=<file>] --clip-frames=90
python tools/material_review/analyse.py <candidate-dir> --compare <baseline-dir>
<godot> --path godot --script res://tests/capture_controller_scene.gd -- --output=<dir> --controller=desktop|web --scenario=materials/fire-gunpowder
```

## Ranked baseline review

| Rank | Material / scene | Visible symptom | Source cause | Correction | Tradeoff |
|---|---|---|---|---|---|
| 1 | Oil, Paste, Slush, Brine, Cement, Wet Asphalt, Wet Cobblestone | Slush and Brine nearly identical; Paste/Cement carry Water's bright diagonal streak and sparkle; Wet Asphalt reads as a black void | One shared flair 13; flow speed `0.045 + id mod 5 × 0.012` | Split by family (below); Oil unchanged | Paste/Cement are now nearly still; Slush trades streaks for granules |
| 2 | Glass, Chemical Glass, Dark Glass, Ice; Wet Asphalt/Cobblestone | Still scenery crawls: sheen lines step one pixel every ~2 s; wet surfaces twinkle like stars | `TIME` in sheen phase; time-swept sparkle on near-black base | Sheens and wet film fixed in world space | Glazing no longer shows any motion |
| 3 | Any crossfaded transition | At `snapshot_blend` 0, 800 of 4,150 eligible pixels differ from the previous snapshot alone (max 13/255) | Old-side relief sampled `current_world_texture` | Relief reads the evaluated snapshot | None measured; same four reads |
| 4 | Web glow `G` / level restore | Overlay and source updates stayed on while the flag said off | Web flipped only `glow_enabled` | Shared idempotent `set_glow_enabled` | None |
| 5 (not changed) | Fire at high lifetime, Molten Glass, Spark, LED | Hot cores clip to a flat colour block at the 1080p output | Emission added into the palette colour exceeds 1 | Deferred; see limits | — |

Smoke/Steam/Foam fade as intended with condition; low-condition Smoke is very
faint on dark and light surroundings, which matches its lifetime curve and was
left unchanged. Manufactured metal glints are sparse (≤0.2% of panel pixels
change per frame) and rough/hammered metals are matte; both left unchanged.

## Changes retained

- **Wet/liquid families** ([palette](../../godot/shaders/material_palette.gdshader),
  [LUT](../../godot/scripts/material_appearance_lut.gd)): `FLAIR_OIL` (13) keeps
  Oil's arithmetic (rate now the named `OIL_WAVE_RATE = 0.045 + 1.0 * 0.012`,
  the same expression the base evaluated for ID 16); captured Oil pixels were
  identical at every sampled time on the tested GPU; `FLAIR_PASTE` (43) for Paste/Cement, Cement settle
  scaled by cure remaining; `FLAIR_SLUSH` (44); Brine → `FLAIR_WATER` with fixed
  salt motes; `FLAIR_WET_SURFACE` (45) for Wet Asphalt/Cobblestone.
- **Still glazing**: Glass/Chemical/Dark Glass and Ice sheen geometry unchanged at
  t = 0 but time-independent.
- **Snapshot-coherent relief** and **glow setter** as ranked above.
- `presentation_time_override` (default −1 = engine `TIME`) on palette and
  emission shaders.

Every other inventory swatch is byte-identical between baseline and candidate
at t = 0 (only IDs 20, 21, 24, 30, 60, 61 differ).

## Measured outcomes

Per-frame changing fraction (pixels whose luma changes >2.5/255 between
consecutive 30 fps frames, glow off), baseline → candidate:

| Region | Baseline | Candidate |
|---|---|---|
| Glass / Chemical Glass / Dark Glass / Ice panels | 0.047 / 0.040 / 0.047 / 0.049 | 0 / 0 / 0 / 0 |
| Wet Asphalt / Wet Cobblestone slabs | 0.005 / 0.005 | 0 / 0 |
| Oil tray (approved wave) | 0.002 | 0.002 (identical) |
| Steel Plate / Painted Steel (approved glints) | 0.001 / 0.002 | unchanged |
| Whole construction plate | 0.0033 | 0.00014 |
| Whole street composition | 0.0019 | 0.0007 |

Crossfade endpoint (eligible pixels, blend 0 vs previous snapshot alone): max
error 0.051 → 0.000. Same-ID and unsupported pairs: exact in both.

Files: [`baseline/`](material-readability-2026-10-18/baseline) and
[`candidate/`](material-readability-2026-10-18/candidate) hold raw readbacks,
`temporal.json`/`transition.json`, labelled inventories, heatmaps and cropped
APNG clips; [`derived/`](material-readability-2026-10-18/derived) holds paired
sheets; [`controller/`](material-readability-2026-10-18/controller) holds live
controller frames. The full local captures (≈110 MB each, all plates, 90-frame
clips and pans) were not committed; they are reproducible with the commands above.

## Validation

All runs on the platform in [Identities](#identities), 2026-10-18.

| Check | Mode | Result |
|---|---|---|
| `tools/ci/run_godot_regressions.py` (import + 54 cases, one shard) at `3d3967c` | headless | Passed |
| `test_material_appearance_lut`, `test_water_presentation_model`, `test_native_render_bridge_regression`, `test_render_patch_handoff_regression`, `test_material_glow_control`, `test_microscenario_controllers` | headless | Passed |
| `test_water_presentation_render` (issue #19 coverage/orientation) | graphical | Passed (coverage 2/4 at 2×, 8/16 at 4×, oriented edge) |
| `test_material_presentation_render` (new) | graphical | Passed; against the baseline palette it fails the still-scenery and blend-0 endpoint assertions |
| `test_material_glow_control` (new) | headless | Passed (30 assertions); with the old Web `G` handler it fails overlay/update agreement |
| Live controllers, `materials/fire-gunpowder` | graphical | Desktop and natively hosted Web: glow on adds light to 12–14k pixels, never darkens; on→off→on returns the identical frame |
| R8 fallback presentation (`--fallback-r8`) | graphical | Renders; without the condition channel Cement shows as cured |
| `check_docs.py`, `check_repository.py` | — | Same 6 missing companion-workspace sources as clean `main`; no new errors |
| `check_m11_consistency.py` | — | No errors (a review fix briefly edited the retained historical `docs/BUILD_ID.md`; that edit was reverted because M11 records are immutable) |
| `retrieval_eval.py` | — | 32/32 canonical hit@k, MRR 0.833 |

**Matched cost** ([`cost.json`](material-readability-2026-10-18/cost.json),
[`measure_material_presentation_cost.gd`](../../godot/tests/measure_material_presentation_cost.gd)):
`RenderingServer.viewport_get_measured_render_time_gpu` for the 1920×1080 world
viewport and 160×90 glow source, identical 1024² RG8 input, camera, view and
`snapshot_blend` 0.5, baseline/candidate interleaved in 6 blocks × 300 frames
after warm-up, vsync off.

| Scene / glow | World GPU median ms (base → cand) | p95 | Glow source median |
|---|---|---|---|
| Mixed / off | 0.095 → 0.101 | 0.135 → 0.140 | — |
| Mixed / on | 0.141 → 0.148 | 0.143 → 0.149 | 0.065 → 0.064 |
| Effects / off | 0.133 → 0.135 | 0.135 → 0.136 | — |
| Effects / on | 0.181 → 0.183 | 0.182 → 0.184 | 0.064 → 0.065 |

The candidate costs about 5% (≈6 µs) more world-pass GPU time in the mixed scene
and about 1% in the effect scene on this GPU; application frame time
(wall time between `frame_post_draw`, not GPU time) was unchanged within noise.
Texture reads per fragment are unchanged. Other GPUs were not measured.

## Owner-requested detail pass (same day)

After reviewing the build, the owner asked for much more detailed material
effects "with lots of flare", taking Acid and Smoke as the minimum level. The
palette gained arithmetic value noise, a three-octave sum, a heat ramp and
world-lattice pixel particles, and these finishes:

- Fire: rising flame tongues on a heat ramp driven by remaining lifetime (hot
  cores keep structure instead of clipping), flicking sparks.
- Lava / molten glass: drifting crust plates, glowing seams, bubbling pops;
  molten glass heat follows its condition byte.
- Smoke (billows, lit rims, soot), Steam (rising plumes, condensation glints),
  Foam (small bubbles, speculars, popping), Acid/Sludge (fizz layer, froth),
  Mercury (warped reflection, moving speculars), Water (caustic net, rising
  micro-bubbles), Oil (thin-film iridescence on the retained wave), Slush
  (twinkling crystals), Spark (crackling core), neon (striated tubes with flowing
  plasma, rebuilt from hue so they no longer clip), LED shimmer, charged-metal
  arc sparks, bioluminescent Fungus, rare powder glints.
- Burn progress now shows ember cracks on Wood/Oak/Thatch, glowing Coal grains and
  surface flames on burning Oil.
- Empty cells show embers rising above hot/burning sources and fumes above Acid
  and Toxic Sludge. A particle candidate reads at most three cells below it;
  other Empty pixels add arithmetic only.
- Still scenery stays time-independent but gained static detail: brick chips and
  grime, concrete hairline cracks, plate scratches, ice fractures and frozen
  bubbles.

Oil therefore no longer matches the baseline pixels; its wave geometry and rate
are unchanged and an iridescent film rides on it. Representative 1080p readbacks
are in [`detail/`](material-readability-2026-10-18/detail). All focused and
graphical tests above were re-run and pass.

Matched GPU cost versus the pre-detail candidate
([`cost-detail-pass.json`](material-readability-2026-10-18/cost-detail-pass.json),
same method): world pass median 0.101 → 0.144 ms (mixed, glow off),
0.147 → 0.192 ms (mixed, glow on), 0.135 → 0.420 ms (all-emitter effect scene,
glow off; p95 0.676 ms), 0.182 → 0.468 ms (effects, glow on). This is within
budget on the TITAN RTX but roughly triples the worst case. Weaker GPUs and
browser/WebAssembly are unmeasured and may need a quality tier.

### Volume, edge and contact pass (second owner iteration)

The owner asked for more again. `material_colour` now gathers the four
neighbour IDs once (from the snapshot being shaded) and shares them between a new
`apply_volume_and_contact` stage and the structural relief:

- Liquids shade by depth (three extra reads straight up, liquid pixels only):
  Water/Brine deepen toward navy, other liquids darken, molten materials get
  hotter; exposed surfaces show animated froth or, for molten, a dark skin with
  flaring bursts.
- Smoke, Steam, Foam and Fire thin or cool at their boundaries.
- Contact effects: molten material flashes against Water/Brine/Slush/Ice,
  water boils beside lava or above fire, Acid/Sludge fizz where they touch
  solids, Fire flares against fuels.
- Emitters rim-light adjacent solids and powders in their own colour; Empty
  cells get soft ambient occlusion from neighbouring solids.
- Burning timber/thatch now chars dark with larger glowing ember veins.

A synthetic `reactions` plate was added to the fixture
([before](material-readability-2026-10-18/detail/reactions_before_volume_pass_t1.37_glow.png),
[after](material-readability-2026-10-18/detail/reactions_volume_pass_t1.37_glow.png)).
All focused and graphical tests pass.

Matched GPU cost versus the detail pass
([`cost-volume-pass.json`](material-readability-2026-10-18/cost-volume-pass.json)):
world pass median 0.145 → 0.195 ms (mixed, glow off), 0.192 → 0.242 ms (mixed, glow
on), 0.421 → 0.593 ms (effect scene, glow off; p95 0.888 ms), 0.469 → 0.641 ms
(effects, glow on). Relative to the original baseline the effect scene world pass
is about 4.4× (0.133 → 0.593 ms). It stays under 1 ms on the TITAN RTX at
1080p, but weaker GPUs and browser/WebAssembly are unmeasured; a quality tier is
the obvious mitigation if they fall short.

### Shape-aware construction fills (third owner iteration)

The owner asked for generative, space-filling fills on static materials. For
Steel/Copper Pipe, Hazard Stripe, Insulation, Cable Bundle, Oak Timber,
Corrugated Steel, Stained Glass, the three neon colours, Red/Industrial Brick,
Ceramic Tile and Reinforced Concrete, `region_extent` measures how far the
pixel's own material continues in each direction. It uses reads at 2, 3, 5 and
8 cells after the shared neighbour, at most 16 extra reads, and only for these
materials. `apply_structured_fill` then derives orientation, cross-section and
edges:

- pipes: cylinder shading, flanges with bolts, junction couplings, copper patina
- hazard: diagonal stripes with a dark trim; strips of five cells or fewer become chevrons
- insulation: quilted batts with stitched seams and foil on exposed faces
- cables: individual round cables with ties and travelling fibre-optic pulses
- timber: planks along the run with staggered joints and nails; burn still applies
- corrugation: ridges follow the sheet's run
- stained glass: jittered-Voronoi leaded panes with a lead border
- neon: a white core centred in the tube in either orientation
- brick: a soldier course and quoins at edges
- tile: bullnose edge trim
- reinforced concrete: tie holes and exposed rebar at broken edges

A run that reaches the 8-cell probe counts as long, so large panels keep one
orientation (per-material default). Steam puffs leak from some pipe runs into
the Empty cells above. Everything except cable pulses, neon plasma and the leaks
is time-independent; the presentation test asserts stillness and cross-section
shading for horizontal and vertical pipes. A synthetic `shapes` plate shows
the result ([before](material-readability-2026-10-18/detail/shapes_before_structured_pass_t1.37_glow.png),
[after](material-readability-2026-10-18/detail/shapes_structured_pass_t1.37_glow.png)).

Matched GPU cost versus the volume pass
([`cost-structure-pass.json`](material-readability-2026-10-18/cost-structure-pass.json)):
world pass median 0.195 → 0.276 ms (mixed scene, which is dense in these
materials, glow off) and 0.242 → 0.323 ms (glow on); the effect scene was
unchanged within noise (0.594 → 0.571 ms).

### Shape-aware fills for every static material (fourth owner iteration)

The owner asked for the same treatment on essentially every static material.
`uses_structured_fill` now covers Wall, Cloner, Wood, Ice, Metal, Concrete,
Glass and IDs 38–80. Shared helpers add open-air detection and hashed drip runs
hanging from top edges. Each material's fill:

| Material | Fill |
|---|---|
| Wall, Concrete, Metal | Block and formwork seams, lit caps, drips, machined edges |
| Limestone, Sandstone, Granite | Ashlar with cap course, quoins and drips; sandstone bedding; granite flecks |
| Cobblestone, Mossy Cobblestone | Polished tops; moss on open tops (Mossy also in joints) |
| Lime Plaster | Spalling that reveals brick, more near edges |
| Wattle and Daub | Half-timbered posts, rails and braces |
| Thatch | Ridge binding and a ragged eave fringe (fringe cells become transparent) |
| Terracotta Tile, Slate | Ridge caps, eave shadow, lichen |
| Wrought Iron | Balusters with collars and finials when thin; riveted plate when wide |
| Lead Sheet | Standing seams and white bloom |
| Bronze, Copper, Verdigris Copper | Patina runs |
| Packed Earth | Strata and a grassy top |
| Asphalt | Tar-sealed cracks |
| Wet Asphalt, Wet Cobblestone | A fixed puddle sheen on top |
| Steel Plate, Painted Steel | Rivet rows and grime gradient; painted steel chips and rust runs |
| Rusted Steel | Bleed runs and perforated edges |
| Steel Grating, Chainlink | Frames and posts |
| Glass, Dark Glass | Frames and mullions; dark glass shows faint reflected lit windows |
| Chemical Glass | A tank with a fill line and rising bubbles |
| Ice | Frosted tops and icicles carved into open undersides |
| Rubber | A moving conveyor when thin; tread plate when wide |
| LED White | A bezelled generative scrolling display; its LUT emission is halved so the bloom does not wash it out |
| Cloner | Truchet circuit traces with pulses |

A `structured_detail` uniform (default 1) disables these fills and their reads
as a future quality-tier hook; no controller exposes it yet. The still-scenery
assertion now lists Slate instead of the animated Chemical Glass tank. A
synthetic `statics` plate shows every material as a block, bar and strip
([before](material-readability-2026-10-18/detail/statics_before_annotated_t1.37_glow.png),
[after](material-readability-2026-10-18/detail/statics_pass_annotated_t1.37_glow.png)).

Matched GPU cost versus the previous structured pass
([`cost-statics-pass.json`](material-readability-2026-10-18/cost-statics-pass.json)):
world pass median 0.276 → 0.375 ms (mixed, glow off; p95 0.715 ms) and
0.571 → 0.815 ms (effect scene, glow off; p95 1.926 ms). The cumulative effect
scene is about 6× the original baseline. It is still a fraction of a 16.7 ms
frame on the TITAN RTX, but a user-facing quality tier is recommended before
weaker GPUs or browser/WebAssembly ship.

## Limits and owner decisions

- Visual acceptance is the author's; the owner has not reviewed the new
  Paste/Cement, Slush, Brine and wet-construction finishes or the removal of
  glass/ice sheen motion.
- Hot-core clipping (rank 5) and Smoke/Steam opacity are recorded but unchanged.
- The emission pass still reads only the latest snapshot; halos are not
  crossfaded. Doubling emission sampling for structural symmetry was not done.
- Real browser/WebAssembly rendering, Linux and other GPUs were not exercised;
  the Web controller ran natively on Windows. The GDScript fallback (R8, no
  condition channel) was not separately smoke-tested.
- Pixel tests use tolerance on one GPU/driver; they assert invariants, not taste.
