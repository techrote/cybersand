---
title: Native-resolution pixel scrolling implementation and qualification
status: Current
document-kind: evidence
scope: Camera quantization diagnosis, isolated stacked implementation, exact runtime identities and pending platform qualification
canonical-for: []
last-reviewed: 2026-11-13
related-documents: [../operations/native-pixel-scrolling.md, ../systems/material-appearance-and-rendering.md, ../reference/interfaces-and-message-contracts.md, ../operations/wb-art-paint-integrated-candidate.md]
---

# Native-resolution pixel scrolling — 13 November 2026

**Draft / HOLD.** This initial checkpoint records the implementation and its
qualification plan. It does not claim a completed camera runtime campaign,
delivered Windows build, human acceptance or merge authority. Resulting-source
execution must be recorded before changing those dispositions.

## Source and integration identity

| Item | Inspected identity |
| --- | --- |
| Repository | `techrote/cybersand` |
| Isolated branch | `codex/native-pixel-scrolling-20261113` |
| Stacked #564 base | `e63a7d4f7cea90a5900c91a917dbf10dee699aa7` |
| Accepted main inspected | `e0fb05b8e0500641f0f25c62c5fb7e721da02d6a`; merge of #562 |
| Initial implementation identity | Working-tree camera/rendering delta from the stacked base; the commit containing this record is the recoverable checkpoint |
| Main/#564 compatibility | Separate resulting-source merge/reconciliation check remains to be recorded |

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
| `godot/shaders/material_palette.gdshader` | Add fractional presentation origin before flooring the world sample; nearest source-cell centres and world-anchored appearance |
| Blacksite/Neon presentation shaders and overlay scripts | Use the same displayed origin without reintroducing camera floors |
| `godot/shaders/glow_composite.gdshader` | Reproject a world-aligned coarse glow source at final display resolution |

The camera state remains floating point. Only the final screen translation is
rounded, including the content offset and CanvasItem screen transform. The
rounded presentation is not written back into camera state. Zoom solves the
continuous world anchor before and after the change, avoiding cumulative drift;
the two displayed positions can differ by at most one physical pixel per axis
from their rounding phases away from clamped world bounds.

Picking maps the physical pointer pixel's centre through the inverse transform
before flooring the complete world coordinate. This addresses the same cell
sample as the material fragment, including fractional magnification. Agent
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

| Gate | Initial checkpoint disposition |
| --- | --- |
| Source diagnosis and focused implementation review | Recorded above; independent resulting-diff review still required |
| Headless coordinate and actual native editing fixture | Resulting-source execution to be recorded |
| Actual framebuffer slow-pan/zoom/resize and old-path negative control | Hosted graphical execution pending |
| Actual production glow/vapour alignment and guard coverage | Hosted graphical execution pending |
| Source-built Linux and Windows campaigns | Pending |
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
counted as graphical coverage. The existing Workbench workflow retains full
manual/agent, generation, cancellation, native and persistence regressions.

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
