---
title: Native-resolution pixel scrolling implementation and qualification
status: Current
document-kind: evidence
scope: Camera quantization diagnosis, isolated stacked implementation, exact runtime identities and platform qualification
canonical-for: []
last-reviewed: 2026-11-13
related-documents: [../operations/native-pixel-scrolling.md, ../systems/material-appearance-and-rendering.md, ../reference/interfaces-and-message-contracts.md, ../operations/wb-art-paint-integrated-candidate.md]
---

# Native-resolution pixel scrolling — 13 November 2026

**Draft / HOLD; [PR #566](https://github.com/techrote/cybersand/pull/566).**
The complete source-camera gate passes on actual Linux OpenGL and Windows
ANGLE, including exact display-pixel pans, fractional zoom, fitted edges,
PAINT, partial Water, glow/vapour and legacy material preservation. The
source-matched installed campaign and Windows delivery are still running at
this checkpoint. Owner acceptance remains pending; no merge is authorized.

## Source and integration identity

| Item | Inspected identity |
| --- | --- |
| Repository | `techrote/cybersand` |
| Isolated branch | `codex/native-pixel-scrolling-20261113` |
| Stacked #564 base | `e63a7d4f7cea90a5900c91a917dbf10dee699aa7` |
| Accepted main inspected | `e0fb05b8e0500641f0f25c62c5fb7e721da02d6a`; merge of #562 |
| Initial implementation identity | `a1a896bb45753c820e1d6109df57de4e65be33af`, tree `f8aad8b10cd39d3cf65a7dd0fb8e1349217b08b0` |
| Physical sample shader source | `1755b2195e4d38c6030ae287ac2eb8e070da62ef`, tree `90373b770b5bb112a38b3322e5de6f5e70b85545` |
| Production camera source | `7758c34fa4dcc48462d934761f2a84938907ff81`, tree `38e981252433670a14a2ec935556c7ea9f0ce77b`; physical picking bounds and Tower label alignment |
| Qualified application/test source | `a8f2735796b5814c95edba857a0a8fa62250be42`, tree `8307a2155bce8665a082e7e01b0e0390dcf4d1e2`; production camera/shader bytes remain identical to the recorded sources |
| This registration checkpoint | Audit and per-file compatibility registration only; no application, test-fixture, native or packaging source changes |
| Main/#564 compatibility | Initial camera + main + latest #564 merges without production conflicts; headless successes and Materials Lab shader-guard refusal are recorded below |

The source tree is isolated from both upstream branches and preserves #564's
manual/agent history, selection-to-Focus mapping and conversation features.
The camera candidate does not alter native sources, material laws, procedural
generation, immutable publication ownership or authoring save formats.
The single new helper entry in the existing portable Godot class-cache
bootstrap is intentional; other generated imports and machine-local state are
not deliverable source.

## Original cause established from source

The main material image is already presented by a CanvasItem at final viewport
resolution. `project.godot` selects `canvas_items` stretch and nearest texture
filtering. The material world is not first rendered into a low-resolution
SubViewport and enlarged as a complete colour image.

The pinned Godot 4.7 runtime also reports `allow_hidpi = true`, both 2D
transform/vertex pixel-snap settings `false`, and canvas texture filter `0`
(nearest). Godot pixel snapping and native upload coordinates therefore do
not account for the whole-cell camera quantization found below.

Two independent whole-cell floors caused the visible stepping:

- `main.gd::update_shader_parameters` sent
  `Vector2(floori(camera_origin.x), floori(camera_origin.y))`, discarding the
  fractional part of the already-floating `camera_origin`.
- `material_palette.gdshader::fragment` calculated
  `view_pixel = floor(fitted_uv * view_size_px)` before adding the camera
  origin. Merely removing the host floor would still leave a view-relative
  cell raster and inconsistent world-anchored grain.

Editing and overlays repeated the integer camera assumption. Workbench follow
also ran in a child `_process` after Main had published this frame's terrain
parameters, allowing frame-order disagreement with later overlays or picking.
Native texture upload coordinates and simulation cell resolution did not need
to change. Existing follow easing is retained; additional easing is not the fix.

## Implemented design and source mapping

| Source | Responsibility |
| --- | --- |
| `godot/scripts/pixel_camera_transform.gd` | Continuous camera transforms, final-pixel presentation translation, inverse world mapping, physical sample centre and zoom anchor |
| `godot/scripts/main.gd` | One displayed origin for terrain, picking and overlays; bounds; follow before frame presentation; small guarded effect buffers |
| `godot/scripts/shared_workbench.gd` | Pointer-centred continuous zoom, drag remainder preservation, parent-ordered follow, no duplicate worker publication per view change |
| `godot/scripts/workbench_paint_editor_controller.gd` and overlay | Cell picking and preview alignment for manual editing at fractional origins |
| `godot/scripts/art_batch_panel.gd` | Fractional world mapping of the actual pixel crop supplied to agent observations |
| `godot/shaders/material_palette.gdshader` | Reconstruct the physical sample, subtract the exact screen phase, multiply the shared reciprocal, then floor; nearest source-cell centres and world-anchored appearance |
| Blacksite/Neon presentation shaders and overlay scripts | Use the same displayed origin without reintroducing camera floors |
| `godot/shaders/glow_composite.gdshader` | Reproject a world-aligned coarse glow source at final display resolution |

The camera state remains floating point. Only the final screen translation is
rounded, including the content offset and CanvasItem screen transform. The
rounded presentation is not written back into camera state. Zoom solves the
continuous world anchor before and after the change, avoiding cumulative drift;
that continuous anchor's displayed positions can differ by at most one
physical pixel per axis away from clamped world bounds. The world point
previously under the pointer can move by at most
`0.5 * (1 + new_scale / old_scale)` new pixels, or 1.5 per axis for a 2x zoom-in.

Picking and fragments subtract the same exact world-zero screen translation
from the physical pixel centre, then multiply the same precomputed reciprocal
scale. The exact screen phase is retained, never reconstructed from an inverse
camera float. This avoids cancellation at fractional-zoom cell ties. Native
fragment clipping also uses physical half-open content bounds; UV-space
comparisons can disagree at fractional fitted edges. Agent
capture metadata describes actual rounded crop edges with fractional world
coordinates. Native editing coordinates remain integers.

Glow stays on a fixed two-world-cell source grid, with five guard texels on
each side plus one far-edge texel. The guards cover its four-texel halo and
filter footprint while the composite translates at display resolution. Vapour
history remains world-grid aligned and gains one extra cell at the right and
bottom. Neither effect becomes a full-resolution simulation or colour buffer.

## Local runtime custody

The local diagnostic uses the cached **pinned hosted build** from
[run 43323028725](https://github.com/techrote/cybersand/actions/runs/43323028725),
attempt 1, source `86d704a259745621168e8bffb149b4d1aee2354b`.
Its native source and build-input scopes match the stacked base exactly; all
87 native input hashes also match the inspected source. This is source-identical
reuse for local iteration, not a new build attributed to the camera commit.

| Runtime | SHA-256 / tool identity |
| --- | --- |
| Linux native extension | `1de86fb8950113162be26796806f4e1aa7d17e443d428a7fa9bbf660afdb38ff` |
| Linux Rapier | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Godot 4.7 Linux executable | `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75` |
| Godot archive | `0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c` |
| Godot version | `4.7.stable.official.5b4e0cb0f` |
| Hosted native toolchain | GCC/G++ 13.3.0, GNU ld 2.42, SCons 4.10.1, godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496` |

The local identity receipt is retained under
`build/native-pixel-scrolling/local-runtime-identity.json`. Native and Rapier
materialization is local-only and is not a source change to commit. The scoped
hosted campaign independently rebuilds both target native runtimes.

Local graphical setup was attempted with a private, cookie-authenticated Xorg
dummy display and TCP disabled. The execution sandbox refused both local and
Unix listener creation; Xorg exited before rendering. No system configuration
or access control was changed. This failure is not a graphical test pass.

## Qualification ledger

| Gate | Current disposition |
| --- | --- |
| Source diagnosis and focused implementation review | Completed, including independent transform, shader/effect and framebuffer review |
| Headless coordinate and actual native editing fixture | Fourth hosted source on both platforms: 1,373 checks, 0 failures, including physical sample ties, follow, stationary hover and fractional-scale Main/PAINT edge picking |
| Actual framebuffer slow-pan/zoom/resize and old-path negative control | Fourth source on both backends: 150 checks, 0 failures; all four partial-Water and two actual PAINT cases complete |
| Actual production glow/vapour alignment and guard coverage | Fourth source on both backends: 66 checks, 0 failures; all 48 glow translations exact and negative controls have a robust byte margin |
| Legacy material, Water, production vapour and crossfade preservation | Fourth source: all four cases positively pass on actual GL and ANGLE, including 26 vapour and 1,274 crossfade assertions per platform |
| Source-built Linux and Windows native runtimes | Fourth pinned native builds passed; installed and accepted-regression campaign continues |
| Copied-installation camera and integrated authoring campaigns | Pending |
| Source-matched Windows package and checksum | Pending successful source/installed campaign |
| Retained-repository runtime provenance | HOLD inherited from #564; a newly built candidate does not publish or reattest the committed runtimes |
| Separate Palette backend gate | Remains independent of the scoped camera framebuffer cases |
| Representative hardware frame pacing and physical Windows scaling | Not established by initial source checks |
| Owner camera-feel acceptance | Pending; no merge authorized |

`test_native_pixel_camera.gd`, `test_native_pixel_scrolling_render.gd` and
`test_native_camera_effects_render.gd` own the focused assertions.
`tools/ci/run_workbench_qualification.py camera` requires each completion marker,
preserves original errors and hashes the actual executed source. Both graphical
cases also run explicitly on Windows ANGLE; Windows headless exclusion is not
counted as graphical coverage. After import, the runner collects every
independent coordinate, framebuffer, effects and material-preservation case;
any failure still fails the source gate and prevents packaging. Source graphics
logs/frames upload before the longer authoring campaign. A passing camera source
gate remains a prerequisite for the full manual/agent, generation, cancellation,
native and persistence regressions. Other Workbench branch behavior is unchanged.

## First hosted campaign and regression-driven corrections

[Run 43341584935](https://github.com/techrote/cybersand/actions/runs/43341584935)
executes the initial `a1a896bb` source. Both pinned native builds passed.
The Linux camera-coordinate fixture passed all 725 checks. The graphical
scrolling fixture completed 97 checks with 13 failures: integer 2x/4x/8x
scrolling passed, but fractional 2.5x and odd fitted-view checks failed.
The source camera gate stopped, so effects and installed/package stages were
not counted as passes. The independent Linux accepted agent, PAINT, Undo and
combined author/reopen regressions completed successfully.

The retained captures distinguish two faults. Adding an inverse camera float
to scaled UVs can round translated samples to opposite sides of a cell edge.
For a 240-cell view over 600 pixels, camera origins near 63.2 and 63.6 could
choose different world cells for pixel 349 and its translated pixel 348. The
revised implementation retains screen translations -158 and -159 and uses
identical subtract-then-multiply arithmetic for both samples. A realistic
600x320 framebuffer case now asserts that exact translation and its reverse.

Separately, a fitted rectangle `(6.5, 7.5, 160, 96)` in a 173x117 output lost
its leftmost content column and included its exclusive bottom edge through
UV comparison roundoff. The revised fragment reconstructs the physical sample
from **unclamped** fitted UVs before testing half-open screen bounds. The
oracle now checks letterbox pixels as well as all interior samples.

Initial logs and source-matched PNGs are retained in the run's evidence
artifacts; local copies are under `build/native-pixel-scrolling/initial-ci`.
These failures are retained as negative evidence, not retrospectively
relabeled as qualification.

## Second campaign and exact physical edge coverage

[Run 43344561560](https://github.com/techrote/cybersand/actions/runs/43344561560)
executes `1755b219`. Its pinned native builds succeeded. On both Linux GL and
Windows ANGLE the coordinate fixture passed 1,359 checks and the framebuffer
fixture completed 107 checks with only two failures, both from the odd fitted
rectangle's input setup. All integer and fractional pan cases passed, including
the realistic 600x320, 2.5x counterexample. No extra pixels leaked into the
letterbox.

The fixture incorrectly reconstructed physical content from normalized UVs:
in float32, `(7.5 / 117) * 117` becomes `7.500000476837158`. It sent that edge to
the shader while its independent oracle expected 7.5, so the new half-open rule
correctly excluded 160 pixel centres on the shifted top boundary. Production
Main already sends the original physical rectangle. The fixture now does the
same, asserts the uploaded origin/size exactly, and retains its strict interior
and outside-pixel oracles. The shader was not relaxed. The old runner stopped at
this failure, so effects and preservation cases were not executed in that run.
Both platforms completed all 36 accepted-regression invocations successfully,
including combined author/reopen at one and four workers. Package/installed
stages remained correctly blocked by the failed source camera gate.

Independent Godot review also reproduced a CPU-only edge discrepancy at a
1.5x display transform: a physical left edge/sample of 329.5 became
52.3333282471 after inversion, just outside the local fitted edge
52.3333435059. Picking now clips directly against the same physical half-open
rectangle as the shader. Pixel centres govern coverage even when a mouse pixel's
corner lies slightly outside the mathematical fit. Fourteen added helper and
mounted Main/PAINT assertions raise the local coordinate suite to 1,373/0.
Tower labels now receive the displayed origin after camera update.

The graphical fixture additionally renders the real PAINT fill geometry at a
2.5x half-pixel boundary and partial Water in coverage/oriented modes at 4x and
2.5x. The Water case verifies exact translated pixels and independent partial
coverage, including eight covered samples out of sixteen at 4x. These new
assertions are parsed locally; actual GL/ANGLE outcomes remain pending.

## Third campaign: preservation evidence and fixture completion

[Run 43347587610](https://github.com/techrote/cybersand/actions/runs/43347587610)
executes `7758c34f`. Both pinned native builds succeeded. All 551 executed
project-source hashes in each camera receipt match that source. Both platforms
pass 1,373 coordinate checks. Pan, exact letterbox coverage, the realistic
2.5x case and actual PAINT fill complete without assertion failures. The two
PAINT masks each cover exactly 195 expected pixels with zero mismatches; the
inverse-camera geometry's tiny half-pixel roundoff causes no raster defect on
either tested backend, so no additional overlay refactor was made.

The runner correctly rejects the framebuffer case despite its 114 completed
checks because the additional Water function logs a script error: an unset
shader override returns Nil, which cannot be assigned to its float variable.
The repaired fixture explicitly sets/restores its typed baseline Water mode
and requires all four Water and two PAINT records before completion. Its exact
pixel, orientation and partial-coverage oracles are unchanged.

The effects fixture records exact positive glow/vapour translations. However,
its custom neutral glow is too faint for robust retained-frame detection:
axial shifts differ by only 2/255, equal to the allowed translation tolerance.
Windows therefore fails three negative controls; Linux's nominal passes sit
on floating-point subtraction roundoff at that threshold. The repaired test
raises only its custom emission intensity from 2 to 16, retaining the same
positive and negative threshold. Each receipt now records the actual control
error and fixture intensity. Canonical material data is restored before timing.
The original failures remain retained; a complete rerun is required.

All four independent legacy preservation cases pass on both actual backends:
material presentation (including all 132 slots), partial Water, production
vapour history (26 assertions), and bounded crossfade (1,274 assertions with
the full material/condition/blend matrix). The early uploads retain these
receipts even though the overall source camera gate fails and downstream
packaging/authoring stages are correctly skipped. The shader source remains
`b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f`.

## Fourth campaign: complete source graphics qualification

[Run 43349229410](https://github.com/techrote/cybersand/actions/runs/43349229410)
executes application/test source
`a8f2735796b5814c95edba857a0a8fa62250be42`, tree
`8307a2155bce8665a082e7e01b0e0390dcf4d1e2`. Both pinned native builds and both
complete source-camera gates pass. Every one of the 551 executed project-source
hashes per platform matches that commit (raw or LF-normalized tracked bytes).
Neither camera log contains a script error. Each backend completes 1,373
coordinate/editing checks, 150 framebuffer checks and 66 effects checks, with
zero failures, followed by positive completion of all four preservation cases.

Independent capture review verifies all 18 framebuffer PNG hashes per platform
and compares their saved pixel bytes. At 4x the legacy control repeats three
fractional increments then jumps four pixels; the new path advances exactly
one display pixel at every increment. All four Water pairs, both PAINT phases
and the 600x320/2.5x counterexample translate exactly with zero differing
pixels after the expected one-pixel shift. Water covers 8/16 target samples
at 4x; at 2.5x, coverage mode covers 3/6 and oriented mode covers 2/6. Both
PAINT phases cover exactly the independently predicted 195 pixels. There is
no blur, uncovered viewport gap or extra fitted-edge pixel in these captures.

All 48 glow steps have zero translated-pixel error on both backends. The
retained-frame negative controls differ by 36/255 axially and 60/255
diagonally on Linux, and 32/255 and 59/255 on Windows, against the unchanged
2/255 tolerance. Vapour edge negatives differ by 98–108/255 while translated
history has zero error. These are sensitive controls, unlike the retained
third-campaign fixture. Material presentation covers all 132 slots; the
existing Water case positively confirms 2/4 samples at 2x and 8/16 at 4x;
vapour completes 26 assertions and crossfade completes 1,274 per platform.

| Source evidence | Verified artifact and SHA-256 |
| --- | --- |
| Linux OpenGL3 / llvmpipe LLVM 20.1.2 | `native-pixel-camera-linux-source-43349229410-1`, artifact `14003855729`; `573d89ca3d0e37b1602d255523fd58d5a6e36cf05d60c2a07fadf67165de3b16` |
| Windows ANGLE / Microsoft Basic Render Driver D3D11 | `native-pixel-camera-windows-source-43349229410-1`, artifact `14003168169`; `0e92c175d5fcdce9f2b4e9809260a5564f8b91daf68b8d782f46576a655fd5d7` |
| Linux native runtime | `1de86fb8950113162be26796806f4e1aa7d17e443d428a7fa9bbf660afdb38ff` |
| Windows native runtime | `c59ef6341e653151c389133cde051d5913051ab05c903207a0bc772968a2d6fb` |
| Windows Godot 4.7 executable | `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8` |

Linux executes the full `b8e5542d…` shader. Windows executes the existing
ANGLE bounded-crossfade variant
`6a1b5ea80bb034c41f93bb994e59791d25739c040b35caf2f24aa143cc12f52b`,
with receipts binding both variant and source file to the same `b8e5542d…`
production shader. The platform variant is not attributed to an unrelated
shader source. Download receipts, exact executed-source checks, original logs,
PNGs and the consolidated source-camera summary are retained under
`build/native-pixel-scrolling/fourth-ci` and the linked run's artifacts.

### Bounded frame-pacing observations

The palette comparison uses a 1280x960 output, 128x96-cell view, frozen
512x256 world, 12 warm-up frames and at most 60 frames/three seconds per arm,
with no per-frame readback. Its control replaces only the former coordinate
block in the otherwise identical shader. Native/legacy median ratios are
1.035 on Linux and 0.981 on Windows; p95 ratios are 1.077 and 0.985.

The production-effects A/B/A comparison uses 960x540, a 240x135-cell view,
eight warm-up frames and at most 30 frames/one second per arm. B changes only
the old glow grid/dimensions and UV layout; the current palette and guarded
vapour are identical. Canonical material data is restored before measurement.

| Software backend | A / B / A median milliseconds | Samples | Mean A median versus B |
| --- | --- | --- | --- |
| Linux llvmpipe | 57.774 / 57.466 / 58.403 | 18 / 18 / 17 | +0.6225 ms, +1.08% |
| Windows ANGLE | 109.724 / 107.822 / 108.291 | 10 / 10 / 10 | +1.1855 ms, +1.10% |

The effects median differences are comparable to repeated-A drift (+1.09%
Linux, -1.31% Windows). At these small sample counts, p95 is the maximum.
These short software-renderer observations bound this fixture's overhead;
they do not establish statistical equivalence, representative hardware frame
rates, full-game throughput or measured input latency. Owner hardware pacing
and physical Windows 125/150/200% scaling remain acceptance work.

## Protected palette source transition for review

The existing material-catalogue guard protects the presentation shader as a
non-identity consumer. This PR proposes one entry in its existing
`REVIEWED_TRANSITIONS` sequence, supported by the complete GL/ANGLE evidence
above. It does not reset the immutable compatibility lock or change the
baseline, material catalogue/capability identities, prior transitions or
guard rules. Owner acceptance remains pending with this Draft PR.

| Transition field | Exact value |
| --- | --- |
| Protected path | `godot/shaders/material_palette.gdshader` |
| Admitted source LF SHA-256 | `f686ca416b5b011751ddd5d38a24824742d01cb8d489b46710ee1f1fbb2a09c1` |
| Proposed source LF SHA-256 | `b8e5542dae2c36fd6fbef0170a7b537bce5c853fc10920174cefe13dbec78d4f` |
| Reachable source commit containing those exact new bytes | `1755b2195e4d38c6030ae287ac2eb8e070da62ef` |
| Committed evidence record | `docs/audits/2026-11-13-native-pixel-scrolling.md` |
| Tracking | Issue #353; Draft PR #566 |

The guard authenticates the source commit's ancestry and exact bytes, plus
this record from `HEAD`. Its normal resulting-source check and actual
standalone/mounted Materials Lab workflows follow the committed registration;
their results are appended below. A future accepted integration must retain
the source commit through a merge commit: squash/rebase would invalidate the
existing ancestry contract.

## Isolated compatibility with accepted Materials Lab

The initial camera source was merged locally with accepted main
`e0fb05b8e0500641f0f25c62c5fb7e721da02d6a` and latest #564
`6319ab1d94d85d01c9cdb44d973a92d224bfa9aa`. Production sources merged without
conflicts; six documentation conflicts were reconciled retaining both feature
sets. The latest #564 changes only its pilot UI fixture. Local merge
`5208acebbbcdd3fe82388840b3c89d241720d1a6` was followed by
`a8f0bae7e018e63916e2544525e7afbde94fffed`, which adds only the unchanged
#565 Lab integration fixture for execution.

All 88 native input hashes match the pinned #565 build at
`90719c72b9fcf90593fb7878354051ad601b47fd` from hosted run 43334477644.
The reused native extension SHA-256 is
`3a8b0b2cd04f09054426842f978e2421aad4016aae03dec91ed527ff50b953cd`;
Godot and Rapier identities match the table above. This is separate Linux
headless compatibility evidence, not a Windows build from the merged source.

The camera fixture (725), Art UI (62), native Lab catalogue (1,348), and full
combined author/reopen campaigns at 512x512 and 1024x1024 with one/four workers
(1,008) passed: **3,143 completed checks/assertions**. The larger campaigns
exercise the large Fill path. Documentation and historical M11 checks passed.

The standalone Lab UI and mounted Lab validation correctly refused the changed
protected palette shader. That is a real integration blocker: it requires a
reviewed per-file source transition, with final shader hash, reachable source
commit and preservation evidence. The immutable compatibility lock, catalogue
identity and existing transitions are not reset or weakened. The final shader
registration is now proposed above after complete graphical preservation
evidence; the resulting-source Lab rerun remains pending at this checkpoint.

## Documentation and unchanged contracts

The appearance contract owns sampling and effect alignment; interfaces own
private transform/API meanings; the configuration reference owns guard sizes;
the runbook owns controls, commands and acceptance. Documentation/retrieval
indexes, roadmap and the explicit corpus route these current candidate claims.
The additive camera retrieval questions do not rewrite frozen evaluation sets.
Five unchanged historical companion files were copied from the existing
workspace seed outside this source repository to satisfy the frozen questions'
six expected-fact source references. Their exact source/destination hashes are
recorded in `build/native-pixel-scrolling/companion-restoration.json`; the
historical provenance record still identifies `web-demo-m11` at `e2892c54`.

Native ownership/lifetimes, snapshot wire formats, physics invariants, existing
ADRs, material compatibility locks and historical runtime records are unchanged.
The retained runtime/provenance gates and separate Palette gate remain distinct
from the scoped camera campaign. Final qualification must append exact source,
commands, elapsed time, runtime hashes, workflow results and any limitations.
