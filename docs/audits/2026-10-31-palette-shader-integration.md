---
title: Palette shader integration review and local rendering evidence
status: Current
document-kind: audit
scope: Selected PR 326 shader source, source-bound backend variants and isolated local rendering evidence; hosted and physical qualification remain separate
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/material-appearance-and-rendering.md, ../architecture/rendering-and-gameplay-bridges.md, ../operations/local-build-and-validation.md, ../operations/current-and-historical-validation.md]
---

# Palette shader integration — 2026-10-31

## Source review and dependency boundary

The integration starts from accepted main
`adaaa37ae35ffcdaa961b80353be3a23b805c0cc`, tree
`ad800ebd5c876f6d1ecd080a6dc3f02918b21870`. It selects the palette source from
Claude PR #326, head `1afe20c0b2abbffaf3e41ac1e1588b862274c52c`, whose earlier
shader ancestor is PR #310 at `dc324f7a9e27835a7efade57b6b7f1efd6c3ef82`.
Neither branch is merged wholesale. The unrelated #308 recovery implementation
is not a shader dependency; the accepted Main lifecycle, input and UI fixes
remain the integration base. Historical #312/#316 observations and the original
Claude branch are preserved.

The selected #310 dependency hoists repeated ordinary-material flair into one
dispatch and avoids a third full outside-view finish. The #326 shader then makes
`apply_neighbour_relief`, `apply_building_finish`, `apply_material_flair` and
`apply_structured_fill` single-exit, with one shared burn tail in the building
and structured functions. Its native OpenGL path still finishes both current
and previous materials. Its bounded variant finishes only the current side;
the outgoing side uses the same material lookup and condition programme, without
the previous material's full neighbourhood, geometry and flair finish.

The imported shader is byte-identical to PR #326. Review traced the conditions,
assignment order, early exits and burn flags in all four rewritten functions.
A retained independent source-control check canonicalizes their continuation
graphs against #310 after accounting for shared burn/detail-edge returns and
no-op assignments. It obtains matching graphs for all four functions (24, 364,
464 and 311 nodes respectively). That check is supplementary source review,
not a shader compiler or numerical-equivalence proof. Actual native framebuffer
comparison supplies the separate rendered evidence below.

| Shader input | SHA-256 |
|---|---|
| Accepted main | `3d9ee3b04ce6eee03490ad2c4af1f487f208e9ff0db31e6d514127633c2e0fef` |
| Selected full shader | `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1` |
| Bounded variant, one leading define | `7e5650cb807825e8febebd402dcba262d0df10baf02d478ee3c30f99ca3d460d` |

## Backend selection and custody

`CyberPaletteShader` selects the bounded variant only for the rendering driver
`opengl3_angle`. Main and each depth material surface use this selector. Other
drivers receive the original source resource. The selected Shader carries its
source resource as metadata; selecting it again resolves that source first.
This retains #326's correction for recreated Main scenes that share their
material resource and otherwise accumulate duplicate preprocessor defines.

Integration review also hardened the cache. It keeps one current variant per
source resource, checks its actual code against the current source plus exactly
one define, and replaces it after a source edit or independent mutation of the
selected variant. Equal bytes belonging to two different source resources do
not steal each other's source identity. This cache does not retain a new entry
for every revision of one edited source. The provenance helper reports the
source resource path, in-memory source hash, original file hash, selected code
hash and explicit variant name; both source-code and file bindings are visible.
These bindings describe bytes, not successful compilation.

The compiler-cost guard fixture verifies all four single exits, the two common
burn tails, bounded/full call counts, native resource identity, shared selected
resource, repeated selection, reverse selection, source edits, mutated cache
entries and independent equal-code resources. Its final run records 27
assertions and zero failures, including source-file binding. It does not invoke
Windows FXC or establish absence of FXC diagnostics on another machine.

The only additional Main source line selects the renderer's shader at `_ready`.
No native source, physics rule or binary is changed. Water integration's two
operation waits use the shared CI execution policy helper supplied by the
separate watchdog integration. The shader package does not import PR #326's
60-second startup gate or change generic runners and workflows.

## Positive bounded-crossfade regression

`test_palette_crossfade_render.gd` adds a real rendered expectation for the
changed outgoing endpoint. It independently constructs flat primary/secondary/
white palette rows and a registered non-neutral value/tint/emission programme.
A CPU oracle calculates the outgoing base colour without extracting or calling
the production helper. A separate minimal reference shader renders that oracle
into the same framebuffer format.

All 132 outgoing ID slots are exercised against a different temporally smoothed
incoming material, at conditions 0, 128 and 255 and blends 0, 0.5 and 1. The
zero endpoint must match the independent base/programme reference. The midpoint
must match its linear mixture with the separately rendered fully finished
current frame. The one endpoint must match that current frame. Each row also
checks a camera translation by (3, 2) cells. The existing material render suite
retains its native full-previous endpoint, same-ID, unsupported-pair and final
endpoint checks; on ANGLE it refers to this positive variant-specific oracle.

The fixed tolerance is 2/255 across RGBA. The final local rendered run completes
1,216 assertions with zero failures and retains all nine PNG and native RGBAF
frames. Maximum observed error is 0.0003662109375 at a midpoint; both endpoints
and every camera comparison are exact in this fixture. A separately retained
negative changes the selected test variant to use the incoming condition for
the outgoing colour. It fails 528 assertions out of 1,216 and exits 1. The
production shader was not changed for this negative.

The fixture intentionally selects the bounded source even on native OpenGL,
and records the actual backend separately. Its Linux result proves those pixels
on the local native-GL compiler. It is not relabelled an ANGLE/FXC result. A
headless skip supplies no rendered qualification. The ordinary suffix-based
Linux discovery includes this fixture; Windows qualification must explicitly
run it on the actual `opengl3_angle` driver and require the result marker,
complete rows and retained pixels.

## Native atlas and explicit variant difference

The original `play_pace003_palette_atlas.gd` and strict
`compare_pace003_palette_atlas.py` are retained from the shader proposal. The
atlas renders 16 frames over 132 material slots, phase/condition/time cases,
crossfade endpoints/midpoint and structured-detail controls. The comparator
retains native framebuffer byte equality, its fixed PNG tolerance, finite/size
checks and distributed material-coverage controls. Its eight adverse/control
self-tests pass. Its rules are not loosened for the bounded approximation.

Accepted-main versus selected-full atlases are byte-exact in all 16 native
framebuffers, with all PNG pixels exact, in both the initial comparison and
the separately controlled cold-cache comparison. This is local isolated shader
evidence; it does not establish Main construction, input, lifecycle or PACE003.

The separate selected-full versus bounded diagnostic correctly fails that
strict comparator: 14 of 16 PNG frames and 13 of 16 native frames are exact.
Frames 12 and 13 are the intentionally changed outgoing/midpoint crossfades;
maximum raw alpha difference is 0.6297607421875. Frame 14, blend 1, has eight
raw pixels with differences at most 0.00048828125, with identical PNG pixels
and none outside 2/255. This small endpoint precision difference is retained,
not called byte parity. Other 13 native frames are exact. The independent
bounded-crossfade oracle above qualifies the registered approximation instead
of turning this failed equivalence comparison into a pass.

## Actual local cohort and cache controls

The local cohort is a Linux container with Mesa 25.2.8 llvmpipe (LLVM 20.1.2,
256 bits), OpenGL 4.5, X11/Xvfb, `LP_NUM_THREADS=2`, and `GALLIVM_PERF=nopt`.
The recorded host exposes nine CPUs. Godot is the pinned official
`4.7.stable.official.5b4e0cb0f`; executable SHA-256 is
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The materialized retained native library hashes to
`496bf3df06be2c6bf47b2e5e4ea525ed4d969c3a34cf1a97d71e4668cdc250e6`,
and the Rapier library to
`566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a`.

The v2 cache comparison gives each shader arm separate, initially empty
`XDG_DATA_HOME`, `XDG_CACHE_HOME` and `XDG_CONFIG_HOME` directories. A second
process reuses that arm's directories for its warm observation. All six
processes exit 0 and retain all 16 frames. The fixture hash is
`62b7cc08f31ea01cf9674d9e0e57dd4c76a951358aa6349263eeb010e7341b1d`.

| Input | Cache | Process wall seconds | First request-to-readback seconds |
|---|---|---:|---:|
| Accepted main | Cold | 39.440 | 36.717 |
| Accepted main | Warm | 10.025 | 7.502 |
| Selected full | Cold | 7.289 | 4.667 |
| Selected full | Warm | 4.528 | 2.038 |
| Selected bounded | Cold | 4.979 | 2.160 |
| Selected bounded | Warm | 3.524 | 1.030 |

These are single local samples, including process work or render request,
compilation when needed, upload, draw and readback. They are not compiler-only
times, FXC measurements, displayed FPS, physical-GPU claims or hosted runner
budgets. A first v1 experiment reset cache directories but shared Godot's data
directory between atlas arms; its timings are preserved but are not used as
matched cold-cache evidence. Its framebuffer comparison remains valid.

The original full material presentation fixture reports successful actual
pixels for all 132 slots, conditions, anchoring, crossfade, invalid bounds,
growth blockers, vapour and single-cell fireworks. The original vapour pipeline
reports 26 assertions, zero failures. Water integration reports 24 policy cases
and 70 scenario/build/reset/action/authority checks. The separately completed
Water pixel run confirms half coverage at 2x and 4x plus the oriented right
edge. None of those checks changes its visual tolerance.

## Preserved failures, reproduction and outstanding scope

The first local launch encountered unmaterialized LFS pointers and an unwritable
default XDG data directory. A later sandbox editor import logged denied socket
creation despite exit 0. Those attempts are retained as environment failures;
the materialized runtime, writable XDG directories and allowed local display
were used for completed runs. The original v1 Water rendering invocation also
exited 0 but ended before renderer identity and its success marker. Final
log review classifies it as incomplete. One separately retained second attempt
on the same source completes its actual-pixel marker; the original invocation
is not rewritten as a pass. The bounded negative and failed full-vs-bounded
comparison are retained with their original failures.

The evidence bundle retains explicit source inputs, runtime hashes, commands,
process results, raw framebuffers, PNGs, source-control checks, original failed
or incomplete logs and a SHA-256 manifest. Evidence is outside Git, as required
for logs, caches and generated images; the committed fixtures are the reusable
apparatus. Local runs use a 1,200-second external guard, with the final Water
integration using the shared 300-second operation policy.

Focused reproduction after pinned runtime/materialized-library preparation:

```text
<godot> --headless --path godot --script res://tests/test_palette_shader_compile_bounds.gd
<godot> --path godot --rendering-method gl_compatibility --rendering-driver opengl3 --display-driver x11 --audio-driver Dummy --script res://tests/test_palette_crossfade_render.gd
python tools/play/compare_pace003_palette_atlas.py --self-test
```

Set `CYBERSAND_PALETTE_CROSSFADE_OUTPUT` to an isolated artifact directory to
retain raw/PNG output, and explicitly declare the known cache state with
`CYBERSAND_SHADER_CACHE_STATE`. For the native atlas set
`CYBERSAND_ATLAS_SHADER`, `CYBERSAND_ATLAS_OUTPUT` and the actual source identity
in `CYBERSAND_SOURCE_REVISION`; compare two complete directories using the
unchanged comparator and `--output`. A caller must check completion markers
and artifacts, not only process exit status.

Hosted native/ANGLE validation must bind the final integration checkout and
runtime, retain compiler diagnostics and cold/warm identities, run the positive
bounded oracle on actual ANGLE, and exercise Main recreation plus the original
rendering suites. This local audit does not claim that work has happened.
Physical input, real monitor presentation, natural traversal and human feel
remain separate qualification rows. Earlier local Windows compiler timing and
prior hosted results on other PR #326 revisions are historical observations,
not universal performance claims or final-head acceptance.
