# World Art Unattended Capture — real Godot PNGs + manifest, no GUI

**Experimental, independent presentation tooling (MAP-AUTO-01 / [#498](https://github.com/techrote/cybersand/issues/498)).** One command renders provisional world-design packs through the **production RG8 material palette, appearance LUT, emission and glow shaders in a real Godot 4.7 renderer** and writes PNG images plus a hash-bound JSON manifest. There is no mouse, keyboard or UI interaction, no SVG/Python rasterisation and no second renderer: it drives the same `world_art_render_rig.gd` and tiled full-export code as the interactive [World Art Preview](world-art-preview.md).

Downstream pipeline this enables: `Atlas source → unattended capture → PNG + manifest → visual critique → source edit → unattended recapture`. The API runner (#499), agent scheduling (#500) and four-native-plane rendering (#501) are separate work and are **not** part of this tool.

## Quick start (copy-paste)

Prerequisites: Python 3.10+, an installed **Godot 4.7 desktop executable** (never downloaded for you), and a **read-only checkout of the art source** (`docs/world-design/<collection>/pack.json`, see [the checkout guide](world-art-preview.md#efficient-fresh-checkout--one-small-clone-no-unnecessary-git-lfs-binaries)). Windows: prefer the `*_console.exe` build (its log is captured); the GUI build works but cannot stream its log.

One collection, default shots (`full`, `viewport`, `detail`):

~~~bash
python3 tools/world_art_preview_launcher.py --capture --godot=godot \
  --art-root=/abs/art-source/docs/world-design --collection=lumen-fault \
  --output-dir=/abs/captures/lumen-fault-before
~~~

All 15 collections (bounded batch, 1× full export):

~~~bash
python3 tools/world_art_preview_launcher.py --capture --godot=godot \
  --art-root=/abs/art-source/docs/world-design --scale=1 --output-dir=/abs/captures/atlas-all
~~~

Windows PowerShell (ANGLE):

~~~powershell
python tools/world_art_preview_launcher.py --capture --godot="C:\path\to\Godot_v4.7-stable_win64_console.exe" `
  --rendering-driver=opengl3_angle --art-root="C:\art-source\docs\world-design" `
  --collection=coral-telegraph --output-dir="C:\captures\coral-before"
~~~

Linux CI / headless server (needs X11 and OpenGL; Xvfb + llvmpipe is the supported path):

~~~bash
LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a --server-args='-screen 0 1920x1080x24 -nolisten tcp' \
  python3 tools/world_art_preview_launcher.py --capture --godot=godot --rendering-driver=opengl3 \
  --art-root=/abs/art-source/docs/world-design --output-dir=/abs/captures/ci
~~~

An external worker only needs the **exit code**, the last-line `WORLD_ART_CAPTURE_RESULT {json}` on stdout, and `batch-manifest.json`. A ready-made wrapper is [`examples/world-art-capture/capture_atlas.py`](../../examples/world-art-capture/capture_atlas.py); a GitHub Actions template is [`github-actions-example.yml`](../../examples/world-art-capture/github-actions-example.yml) (not an active workflow).

## Inputs

| Option | Meaning |
| --- | --- |
| `--pack PATH` (repeatable) | An exact `pack.json`, or a collection directory containing one. Works on a writable copy outside the art checkout. |
| `--art-root DIR` | Directory of collections. All discovered collections are captured in canonical atlas order, or select with `--collection NAME` (repeatable). |
| `--output-dir DIR` | **Required.** Must not exist or must be empty. Refused if it overlaps an art source directory or the `godot/` project. Earlier evidence is never overwritten. |
| `--godot PATH`, `--rendering-driver opengl3\|opengl3_angle`, `--display-driver` | Engine selection. The manifest records the driver Godot actually used; a mismatch fails the run. |
| `--timeout SECONDS` | Kill a stuck renderer (default 1800). |

## What gets rendered (shots)

`--shots` is a comma list of `full,viewport,detail` (default all three) or `none`. If you pass `--feature`, `--all-features` or `--all-variants` without `--shots`, only the feature shots are produced.

| Shot | Output | Controls |
| --- | --- | --- |
| `full` | Entire combined composition, tiled with a 32-cell halo (no right-edge cutoff), `native size × --scale` | `--scale 1..8` (default 2). Bounded to 50 M output pixels. |
| `viewport` | A framed camera view | `--resolution WxH` (default 1920x1080); `--framing fit` (whole map, same as the viewer's Fit) or `native` (1 px/cell); `--zoom Z [--center X,Y]`; or `--view X,Y,W,H` (fit this native-cell rectangle). |
| `detail` | A native-cell crop rendered at an exact zoom | `--crop X,Y,W,H` (default: centre half of the map), `--detail-zoom Z` (default: largest integer that fits `--resolution`). |
| feature | One reusable feature at a chosen authored variant | `--feature ID[:VARIANT]` (repeatable), `--all-features` (base variants), `--all-variants` (every variant); `--feature-scale 1..8` (default 4). |

Presentation settings apply to every shot: `--time SECONDS` (**fixed shader presentation time**, default `1.37`, the viewer's default — animated shaders are therefore repeatable), `--no-glow`, `--no-detail`, `--no-background`. Zoom is limited to 0.03–32 pixels per cell like the viewer. Out-of-range crops/zooms/resolutions fail instead of silently clamping. Feature IDs differ per collection, so use `--all-features` for batches.

## Output bundle

~~~text
<output-dir>/
  batch-manifest.json        status, art/viewer/renderer identity, per-job hashes, seal (manifest_sha256)
  godot-run.json             Godot runner report (display, driver, adapter, per-job status)
  godot-capture.log          combined Godot output (diagnostics)
  01-lumen-fault/
      manifest.json          per-job manifest: pack SHA-256, shots, camera, stats, renderer
      full.png  viewport.png  detail.png  feature-<id>[--<variant>].png
~~~

The manifest records: exact **input pack SHA-256** (and the pack's Git blob and whether it equals `HEAD`), the **art source Git revision** detected from the checkout (a mismatching `--design-revision` is rejected), the viewer's Git revision and the SHA-256 of every copied shader/tool file, the Godot version, renderer method/driver/adapter, the palette shader identity (source/variant hashes, source binding) plus appearance LUT hashes, the selected collection/feature/variant, the full camera (zoom, origin, visible native rectangle, whether the whole map is visible and which edges clip), resolution/crop/scale/time/glow/detail/background, output dimensions, PNG byte size and **PNG SHA-256**, the RG8 source hash, image statistics, the synthetic-condition notice and limitations, and an explicit `completed`/`failed` status. Manifests contain no timestamps or temporary paths, so identical inputs on the same renderer give byte-identical manifests.

The batch manifest is sealed: `manifest_sha256` covers its own content and lists every job manifest hash, which lists every PNG hash. A successful run requires: Godot exit 0, no shader/script errors in the log, every PNG decoded back from disk to the same pixels, independently validated PNG structure/CRC/dimensions/hash, the pack bytes unchanged since hashing, and the **art source unchanged** (a hash snapshot of the art directories plus `git status` before and after).

### Re-verify and compare

~~~bash
python3 tools/world_art_preview_launcher.py --verify-bundle /abs/captures/lumen-fault-before
python3 tools/world_art_preview_launcher.py --compare-bundles /abs/captures/before /abs/captures/after
~~~

`--verify-bundle` re-hashes every PNG and manifest and re-hashes the packs if they still exist (reporting source edits made after capture). `--compare-bundles` reports per collection/shot whether the framing was equivalent and whether the pack, the RG8 cells and the PNG changed. **Before/after recipe:** capture the unedited pack, edit a writable copy, capture again with the *identical* flags, then compare. Fit framing depends on the map size, so for pixel-aligned comparisons of resized maps pass an explicit `--view` or `--zoom/--center` and `--resolution`.

## Exit codes and failures

| Code | Meaning |
| --- | --- |
| 0 | Completed: images + manifest written and verified |
| 2 | Invalid arguments, missing/empty pack, unsafe output location |
| 3 | Godot executable missing, unusable or not 4.7 |
| 4 | Render failed: Godot error/timeout, invalid pack, unknown feature/variant, crop outside the map, blank framebuffer (override with `--allow-blank`), shader/script error in the log |
| 5 | Evidence invalid: PNG/manifest missing or inconsistent, renderer differs from the request |
| 6 | The read-only art source changed during capture |
| 7 | No graphical display (headless display server; run under X11/Xvfb or a desktop session) |

Failures print `WORLD_ART_ERROR <actionable message>` on stderr. When the output directory was created, `batch-manifest.json` is still written with `status: "failed"` and the failure list so nothing looks complete by accident.

## Limits

- Material conditions are **synthetic** creation-state bytes. Images show authored geometry through the production shaders; they are not simulation, pressure, Water, reaction, Rapier, traversal or worldgen evidence.
- Pixels legitimately differ between operating systems, drivers and GPUs (Linux llvmpipe vs Windows ANGLE vs a physical GPU). Compare source identity, geometry, completeness and renderer-specific invariants across platforms; hash equality is only expected for the same renderer. The tests assert repeatability on one renderer, not across them.
- A graphical display is mandatory; a headless run is rejected (exit 7), never reported as a visual capture.
- Presentation-only layering. This is not the four-native-plane (#501) render. The pack schema is provisional and is not a production import/save contract.
- Detail/viewport shots render the combined composition; feature shots are tiled exports of the feature alone.

## Qualification

[`tools/test_world_art_capture.py`](../../tools/test_world_art_capture.py) drives the real CLI and Godot renderer; with `WORLD_ART_REQUIRE_GRAPHICAL=1` a missing display/engine is a failure, not a skip. It covers: unattended flagship render with nonblank full+detail PNGs; a 15-collection batch; the 120-feature inventory and authored variants; wide-map framing and right-edge export; source/hash/dimension consistency; unchanged art checkout; fixed-time repeatability; before/after at equivalent framing; invalid pack, blank render, unknown feature, out-of-range crop, headless display, a corrupted production shader and tampered evidence; and the preserved interactive launcher.

~~~bash
export WORLD_ART_GODOT=/path/to/Godot_v4.7-stable_linux.x86_64
export WORLD_ART_ART_ROOT=/abs/art-source/docs/world-design
export WORLD_ART_RENDER_DRIVER=opengl3          # opengl3_angle on Windows
export WORLD_ART_REQUIRE_GRAPHICAL=1
export WORLD_ART_EVIDENCE_DIR=/abs/evidence
xvfb-run -a python3 tools/test_world_art_capture.py -v   # Linux; run directly on a Windows desktop
~~~

The [capture workflow](../../.github/workflows/world-art-capture.yml) runs this on GitHub-hosted Linux X11/Xvfb OpenGL/llvmpipe and Windows OpenGL ANGLE against the **current** art branch head and uploads PNGs, manifests and logs as artifacts. The interactive viewer keeps its own [GUI qualification workflow](../../.github/workflows/world-art-preview.yml).
