---
title: Unified World Art pipeline
status: Current
document-kind: contract
scope: Standalone World Art renderer ownership, art capacity, source provenance and native compatibility boundaries
canonical-for: [world-art-pipeline, world-art-capacity-and-compatibility]
last-reviewed: 2026-11-20
related-documents: [world-art-preview.md, world-art-capture.md, world-art-evaluation.md]
---

# ART-PIPELINE-UNIFICATION-001 — integrated World Art Preview and unattended capture

**Status: Draft / HOLD. Not native gameplay, not an importer, not Ready to merge.**

This branch contains the same **15 original world-design collections** (120 reusable
authored features) as the source atlas, plus one production-shader-backed
**Godot 4.7 RG8 presentation renderer** consumed by the interactive viewer,
the tiled full-composition exporter, and the unattended PNG/manifest runner.
The art checkout may be external or the `docs/world-design` directory in
this integrated repository. It is never rewritten by the renderer.

## Donor ownership and provenance

| Source | Role | Treatment |
| --- | --- | --- |
| [#454](https://github.com/techrote/cybersand/pull/454) | 15-collection art atlas, 120 features | Its original `docs/world-design` tree imported unchanged from `c4aab63eed538a25687c66d368b0801d2d2e04d0`, subtree `7f599357050472d0af7a31494c7b530bbc798073`. |
| [#457](https://github.com/techrote/cybersand/pull/457) | Read-only world-design-to-RG8 capture adapter | The shared adapter in #487/#506 is the authoritative maintained successor; do not introduce a second pack parser. |
| [#478](https://github.com/techrote/cybersand/pull/478), [#479](https://github.com/techrote/cybersand/pull/479) | Historical publication/recovery, PID-namespace and no-clobber adversaries | Security requirements examined; this integrated unattended path uses an exclusive no-clobber claim and refuses to steal or overwrite retained jobs. **Not a claim of byte-for-byte import or equivalent recovery implementation.** |
| [#487](https://github.com/techrote/cybersand/pull/487) | Interactive scene, original RG8 shader rig, camera, pin/compare | Shared renderer retained. |
| [#506](https://github.com/techrote/cybersand/pull/506) | Unattended real-Godot PNG/manifest runner and common tiled renderer | Source imported from `7b960b5eac5b7a4ed159ade97b1093a1b623ac19`, extended in this PR. |
| [#536](https://github.com/techrote/cybersand/pull/536) | Research automation and agent runner | Read-only coordination; no worker API, workstream, or production agent replaced. |

No production shader, native material ID, `World` storage, Rapier system or
Shared Workbench gameplay path is modified by this integration. It does not
implicitly promote any donor Draft PR or its experimental feature.

## Single entry point

For a portable owner build, use the [Windows evaluation package](world-art-evaluation.md):
Godot, Python, all fifteen scenes, 120 features and the verified offline gallery
are bundled. The source-checkout commands below remain available.


Prerequisites: Python 3.10+, an installed **Godot 4.7 desktop** executable,
and a graphical desktop or X11/Xvfb software GL renderer. No native extension,
CUDA, LFS download or second CyberSand checkout is required.

From the integrated repository root:

```powershell
python tools/world_art_preview_launcher.py --godot="C:\Godot_v4.7-stable_win64_console.exe" --rendering-driver=opengl3_angle
```

```bash
python3 tools/world_art_preview_launcher.py --godot=godot --rendering-driver=opengl3
```

To use an external work-in-progress atlas, pass `--art-root=/absolute/path/docs/world-design`
or a single `--pack=/absolute/path/pack.json`. The interactive viewer
defaults to the **integrated** `docs/world-design` when omitted.

Capture is deliberately explicit about input and output locations:

```bash
python3 tools/world_art_preview_launcher.py --capture --godot=godot \
  --art-root="$PWD/docs/world-design" --output-dir=/tmp/world-art-shot-001 \
  --shots=full,viewport,detail --scale=1 --framing=fit
```

A single `--pack` on writable scratch art permits before/after iteration
while the canonical source is protected. Both viewer and unattended capture
use `godot/tools/world_art_render_rig.gd` and
`godot/tools/world_art_full_export.gd`; they do **not** replace Godot
shader output with HTML, SVG or CPU material-colour estimates.

## Navigation of large / asymmetric work

- **Fit [F]** keeps all authored bounds visible, letterboxing instead of cropping.
- **Width [W]** and **Height [H]** fit that axis and intentionally expose
  clipping of the other axis; keep the selected fit policy on window resize.
- **1:1 [1]** is one framebuffer pixel per authored material cell.
- Cursor-centred wheel zoom, middle/right drag pan, arrow-key pan and the
  aspect-correct corner minimap all operate in the same native cell coordinates.
- A minimap click/drag centres the real shader camera; the minimap is
  procedural navigation geometry and does not allocate a second full-world
  material texture.
- `--framing fit|width|height|native` exposes the same policies in capture.
  The manifest contains the actual camera origin, world-space viewport,
  native dimensions, visible region and every clipped edge.
- The visible viewport and detail export are genuine Godot
  framebuffer readbacks. Full/feature exports are 512-native-cell tiled with
  a 32-cell shader halo, retaining authored far edges.

## Compatibility contract (independent limits)

This tooling accepts any **positive, non-square or non-power-of-two** pack
size provided `width <= 16384`, `height <= 16384` and
`width × height <= 16,777,216`. That is the read-only **art adapter**
contract, **not** a change in playable native World size. There is no
native simulation allocation, native save-file compatibility claim,
water/pressure solver, entity simulation or collision correctness claim.

The normal full PNG path uses a bounded Godot output image with **at most
50,000,000 output pixels**, from a source image of at most 16,777,216 native
cells. At a larger output scale, `--capture --stream-large` explicitly enables
a second **bounded 100,000,000-output-pixel, 65,536-pixel-per-axis** path.
Godot draws the **same RG8 production material shaders** in halo-overdrawn
tiles and writes source-hashed RGB8 framebuffer bytes. Python only
assembles those exact bytes into a standards-compliant RGB PNG using
scanline compression; it does not recolour, rasterise or alter geometry.
The final PNG is revalidated before any manifest is marked complete.

Export scale is explicit. Exports above the selected budget **fail** with a
diagnostic, retaining incomplete evidence but never a false completed
capture. There is no silent clipping, source downsampling or unbounded
full-image allocation. The interactive viewer retains its 50M
`Save full` image bound and displays the pixel cost; to produce an
over-50M whole-map PNG use the unattended CLI with `--stream-large`.
Viewport/detail captures work independently of the full-image budget.

| Native input | Native cells | Full 1× | Full 2× ordinary | Full 2× `--stream-large` |
| --- | ---: | --- | --- | --- |
| 512×512 | 262,144 | Yes | Yes | Yes |
| 1024×1024 | 1,048,576 | Yes | Yes | Yes |
| 2048×1024 | 2,097,152 | Yes | Yes | Yes |
| 1024×2048 | 2,097,152 | Yes | Yes | Yes |
| 4096×1024 | 4,194,304 | Yes | Yes | Yes |
| 1024×4096 | 4,194,304 | Yes | Yes | Yes |
| 512×8192 | 4,194,304 | Yes | Yes | Yes |
| 8192×512 | 4,194,304 | Yes | Yes | Yes |
| 2048×8192 | 16,777,216 | Yes | **Refused: 67,108,864 pixels** | **Yes: streamed** |
| 16384×1024 | 16,777,216 | Yes | **Refused: 67,108,864 pixels** | **Yes: streamed** |

The JSON evidence states `previewable`, `full_exportable`,
`full_export_mode: framebuffer|streamed|refused`,
`requested_output_pixels`, reason when rejected, and
`native_playable: "not-qualified-by-art-pipeline"`. Requests above
100M output pixels or 65,536 pixels per streamed axis remain refused.
**Art preview support does not grant native gameplay admission**.

## Capture publication and provenance

- A newly created, empty destination is reserved with an **exclusive**
  directory claim before evidence writes. A second writer cannot silently
  occupy the same output; existing images are never overwritten.
- Claims left by a terminated process are retained and treated as
  uncertain. There is **no automatic stale-owner takeover** and no
  undocumented PID-based recovery that might evict a live owner.
- A failed capture has explicit failed status, stderr diagnostics and
  retained incomplete bundle. A successful publication writes PNGs,
  source/renderer/camera/hash identities and a canonical SHA-256-sealed
  `batch-manifest.json`.
- Source input SHA-256 is checked before and after rendering. The source
  tree and git status are examined to detect writes. The validator rejects
  damaged or mismatching PNG chunks, changed source bytes, incomplete
  manifests and missing shots.
- The renderer identity includes the actual Godot version, OS, display,
  graphics driver, palette program/LUT identity and source shader hashes.
  Do not equate rendered bytes between llvmpipe and ANGLE; compare
  source-matched geometry, coverage, completeness and per-renderer invariants.

## Qualification required before promotion

1. Run unit and contract tests via `python -m unittest tools.test_world_art_capture.UnitTests -v`.
2. Run real Godot 4.7 GUI compile/import and the interactive 15-collection /
   120-feature pin/compare/shader/source-reload smoke.
3. Run unattended capture matrix, including genuinely tall/wide 512×8192
   and 8192×512 worlds with authored far-edge material strips and
   manifest camera/clipping assertions; qualify source-hashed 67M-pixel
   1024×4096 at 4× through the real-Godot streamed-PNG test.
4. Inspect output PNGs and source identities. Repeat the graphical suite on
   Linux X11/Xvfb/llvmpipe and Windows Godot ANGLE using the **integrated
   repository source**, not a stale #454 checkout.
5. Require clean exact-HEAD CI results and an independent review; document
   failures, unresolved constraints and any owner Windows observation.

**Do not merge / mark Ready / enable auto-merge before owner approval.**


## Finisher repairs and evidence ownership

The final finisher repairs luminous-edge emission outside authored bounds,
interactive source-path aliases, complete pinned/export provenance, crop integer
overflow, delayed output claim races, invalid PNG structures and disagreement
between a gallery's batch summary and its verified child manifests. Production
shader files, native material IDs, physics and source artwork remain unchanged.

The exact-source graphical workflows and their downloadable artifacts are
recorded in [PR #685](https://github.com/techrote/cybersand/pull/685). Every final
workflow explicitly checks out the requested source SHA. The earlier d8516761
evidence actually ran merge commit 5adf9224; their complete source trees were
identical. That historical proof does not qualify the subsequent repairs.

`tools/world_art_evaluation_package.py` builds one portable Windows evaluator
from committed source, pinned official runtimes and independently revalidated
Godot capture bundles. The original scene/feature gallery is regenerated by
`examples/world-art-capture/build_gallery.py`; the package entry page links it
and the large/framing/compare evidence. The package smoke executes the shipped
launchers with a restricted PATH and verifies a fresh capture before publication.

Final technical qualification and an independent reviewer verdict are required
before owner acceptance. Physical Windows/NVIDIA visual acceptance remains an
owner observation, separate from software-rendered Linux/Windows CI.
