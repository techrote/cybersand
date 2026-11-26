---
title: World Art interactive viewer
status: Current
document-kind: guide
scope: Standalone Godot World Art inspection, navigation, comparison and export controls
canonical-for: [world-art-interactive-viewer]
last-reviewed: 2026-11-24
related-documents: [art-pipeline-unification.md, world-art-capture.md, world-art-evaluation.md]
---

# World Art interactive viewer

The standalone **Godot 4.7 World Art viewer** displays the included fifteen
collections and 120 reusable features through CyberSand's production RG8
material palette, appearance LUT, emission and glow shaders. It is an art
inspection tool with explicit synthetic material conditions. It does not run
the native simulation or require native extensions, Rapier, Git LFS binaries
or a C++ build. The [integration contract](art-pipeline-unification.md) owns
architecture, capacities and native compatibility boundaries. The standalone
pipeline is accepted source through [#685](https://github.com/techrote/cybersand/pull/685);
it remains separate from the in-scene [Workbench Art workflow](../operations/workbench-art.md).

## Open the Windows evaluation package

Extract the complete **CyberSand-World-Art-Windows.zip**, then double-click
**Open World Art.cmd**. **Open Gallery.cmd** opens the verified offline PNG
gallery. The qualified package includes Godot 4.7, Python and all artwork;
there is no installation or download during launch. See the
[Windows evaluation guide](world-art-evaluation.md) for the package inventory,
additional inputs, capture examples and verification commands.

## Launch one integrated checkout

From this repository root, with Python 3.10+ and the pinned Godot
`4.7.stable.official.5b4e0cb0f` desktop executable installed:

```powershell
python tools/world_art_preview_launcher.py --godot="C:\Godot_v4.7-stable_win64_console.exe" --rendering-driver=opengl3_angle
```

On Linux:

```bash
python3 tools/world_art_preview_launcher.py --godot=godot --rendering-driver=opengl3
```

In the examples, `godot` means that pinned executable; check `godot --version`
or supply its absolute path. Use your actual installed Godot path. The
owner-confirmed Windows example above
is not automatically installed by the source launcher. To locate Godot on PATH,
run `Get-Command godot, godot4 -ErrorAction SilentlyContinue` in PowerShell.
The launcher reports a missing executable before opening the viewer.

A fresh source checkout can omit all unrelated Git LFS runtimes:

```powershell
$env:GIT_LFS_SKIP_SMUDGE = "1"
git clone --depth 1 --single-branch --branch main https://github.com/techrote/cybersand.git cybersand-art
Remove-Item Env:\GIT_LFS_SKIP_SMUDGE
cd cybersand-art
python tools/world_art_preview_launcher.py --godot="C:\Godot_v4.7-stable_win64_console.exe" --rendering-driver=opengl3_angle
```

The included `docs/world-design` loads automatically. No historical donor
checkout or separate atlas branch is needed. Override it with
`--art-root=/absolute/collections` or `--pack=/absolute/working-copy/pack.json`.
The **World-design root** field and **Choose directory** select another
collection directory, which contains `<collection>/pack.json` subdirectories.

The launcher creates a temporary standalone project from the exact checked-out
viewer, adapter, shader and LUT bytes, imports its script classes and opens the
real Godot window. It deletes only that temporary project on exit. Source art
and requested captures remain outside the project. The displayed pack SHA-256
identifies the same byte snapshot that was parsed; externally supplied revision
text remains an attribution label rather than proof of a Git revision.

## Camera and inspection

| Action | Controls |
| --- | --- |
| Select a collection | Left list, Previous / Next |
| Select combined scene or reusable feature | Scene/feature and authored variant selectors |
| Fit all authored bounds | **F** / Fit |
| Fit width / fit height | **W** / Width, **H** / Height |
| One framebuffer pixel per source cell | **1** / 1:1 |
| Pointer-centred zoom | Mouse wheel over the viewport |
| Pan | Middle/right drag or arrow keys |
| Jump to another region | Click/drag the aspect-correct minimap |
| Reload a changed working copy | **R** / Reload |
| Pin the rendered baseline | **P** / Pin |
| Compare baseline/current | **B** / Show before / Show after |
| Play/pause presentation animation | **Space** / Play |
| Save visible viewport | **Ctrl+S** |

Fit-all letterboxes the complete source, including very tall/wide compositions.
Width and height deliberately clip the other axis where necessary. Manual pan
or zoom leaves automatic fitting; a selected fit mode follows window resizing.
The minimap uses native cell coordinates and does not allocate another
world-sized material texture. The inspector reports pointer cell coordinates,
material ID and its synthetic condition byte. Grid lines appear at 6× or higher.

Only the active RG8 scene/feature texture is held. Navigation updates camera
uniforms rather than rebuilding the entire map. JSON parsing, source geometry
construction and full-image exports remain synchronous operations and may pause
interaction temporarily on a large source; their status is visible. There is
no automatic file watcher: use Reload.

## Pin, edit, reload and compare

1. Open a writable **copy** of a pack and select the desired scene or feature.
2. Pin the actual rendered viewport. Its source bytes/hash, selection, native
   dimensions, camera and presentation settings are retained with the pixels.
3. Edit the working copy with an external editor or generator, then Reload.
   Invalid JSON or geometry leaves the last good view available and reports
   the error; the renderer never rewrites or repairs the source file itself.
4. Toggle Before/After to compare with the pinned framing and settings.
   Navigation or a viewport-size change can require a fresh pin for exact
   pixel alignment; the UI does not present a different source as that pin.
5. Save the visible image or detail. When Before is shown, these exports use
   its original framebuffer and full original provenance. Full/feature exports
   always render the current selected source and snapshot settings before work.

Pins are session-local framebuffer snapshots, not persistent revision history.
Full/feature exports share the unattended renderer's 512-cell tiled path with a
32-cell halo and original source-world coordinates. Export time and settings
remain bound to the image even when presentation animation is playing.

## Output and limits

Each export creates a unique directory under
`user://world-art-preview/captures/` containing its PNG, `metadata.json` and
`status.json`. Use `--export-root=/absolute/output` to choose a destination.
The isolated project is named **CyberSand World Art Preview**; on Windows its
default data directory is below
`%APPDATA%\Godot\app_userdata\CyberSand World Art Preview\`.

Existing images are never overwritten. Source directories and uncertain
symlink/junction aliases are refused as output locations. Partial output remains
incomplete on failure. Metadata records the actual source, dimensions, camera,
settings, source RG8 hash, renderer identity and PNG hash.

Art sources support up to **16,384 cells per axis / 16,777,216 cells total**.
Interactive full-image exports stop at **50,000,000 output pixels**. The pixel
cost is shown before export. For larger exports, use the same renderer through
[unattended capture with `--stream-large`](world-art-capture.md#optional-bounded-streamed-full-png-above-50-million-pixels),
with a **100,000,000-pixel / 65,536-per-output-axis** limit. There is no automatic
crop, distortion or source resizing to evade these limits.

The art adapter's dimensions do not change native World, gameplay, production
import or saved-world limits. Transparent/empty material cells reveal the
presentation background; PNG exports are the composited opaque framebuffer,
not an RGBA cutout of a native world.

## Qualification

The [viewer workflow](../../.github/workflows/world-art-preview.yml) checks out
the exact requested PR commit and exercises the actual application on Linux
X11/OpenGL/llvmpipe and Windows ANGLE. It covers all fifteen scenes and 120
features, reload and last-good recovery, comparison, navigation, source
integrity, production material/glow output, and PNG export. Headless adapter
contracts are distinct from real graphical framebuffer evidence.

```bash
python3 tools/world_art_preview_launcher.py --godot=godot --adapter-oracle
xvfb-run -a python3 tools/world_art_preview_launcher.py --godot=godot \
  --rendering-driver=opengl3 --export-root=/absolute/evidence/exports \
  --smoke-output=/absolute/evidence
```

Inspect retained PNGs as well as logs. Windows hosted ANGLE results do not imply
acceptance on the owner's physical NVIDIA GPU. The pipeline was merged in #685;
the [physical acceptance harness](world-art-evaluation.md#physical-windowsnvidia-acceptance-owner-hardware)
collects a separate owner result. For a new candidate, source qualification and
owner Ready/merge authority remain separate. Original donor records retain their
historical scope.
