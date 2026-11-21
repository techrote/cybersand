---
title: World Art Windows evaluation
status: Current
document-kind: guide
scope: Portable owner evaluation of the standalone World Art viewer, capture tools and verified gallery
canonical-for: [world-art-windows-evaluation]
last-reviewed: 2026-11-20
related-documents: [art-pipeline-unification.md, world-art-preview.md, world-art-capture.md]
---

# World Art Windows evaluation

Extract the complete `CyberSand-World-Art-Windows.zip` into a writable folder.
Open **Open World Art.cmd** to inspect the fifteen included art collections,
or **Open Gallery.cmd** for the offline scene and feature gallery. Keep the
extracted files together. Opening a launcher inside the ZIP is unsupported.

The package includes the pinned official Godot 4.7 Windows runtime and the
standalone presentation project. The complete CI package also includes Python
3.12 and its standard library for unattended capture. No installation, Git,
native CyberSand extension, Rapier runtime or C++ build is needed. Nothing is
downloaded when launching the viewer or capturing artwork.

## Inspecting the artwork

Choose a collection in the left sidebar. The scene selector offers its combined
composition and reusable features, with authored variants where present.

| Task | Control |
| --- | --- |
| Fit every authored cell | **F** or Fit |
| Fit width or height | **W** / **H** |
| One screen pixel per source cell | **1** |
| Zoom around the pointer | Mouse wheel over the image |
| Pan | Middle/right drag or arrow keys |
| Jump to a region | Click/drag the aspect-correct minimap |
| Reload an edited working copy | **R** or Reload |
| Pin the current framebuffer | **P** or Pin |
| Compare the pin with the current view | **B** or Show before / Show after |
| Save the visible viewport | **Ctrl+S** |

For before/after work, make a separate writable copy of `pack.json`. Pin the
original view, edit that copy, reload and toggle the comparison. Failed parsing
retains the last good view. The original source packs in the package are the
qualification reference; keep those unchanged when evaluating source identity.

To inspect additional artwork, use **Choose directory** or the world-design
root field. A directory contains one subdirectory per collection, each with
`pack.json`. These are provisional World Art JSON packs, not native CyberSand
save files. The package does not convert arbitrary images, native saves or
other import formats into art packs.

For a single external pack, open PowerShell in the extracted package folder:

```powershell
.\dependencies\python\python.exe -B .\tools\world_art_preview_launcher.py `
  --godot .\Godot_v4.7-stable_win64_console.exe --rendering-driver opengl3_angle `
  --pack "C:\MyArt\working-copy\pack.json"
```

## Gallery and evidence

**Gallery.html** links the 45 scene images (full, viewport and detail for each
of fifteen collections), all 120 reusable feature images, extremely tall and
wide examples, the 67,108,864-pixel streamed capture, ten input dimensions and
before/after framing examples. All PNG pixels come from the real Godot RG8
production material shaders. The gallery builder only indexes verified images.

The extreme-size images are deliberately simple qualification fixtures that
make missing edges, incorrect framing and material-coordinate defects visible.
The fifteen original collections provide the artistic acceptance samples.
Open a PNG at its original resolution when inspecting boundaries or far edges.

`world-art-evaluation.json` records the exact source commit, every included
file's SHA-256, engine pins, bundled Python identity and capture-manifest
identities. `evidence/` retains each original sealed capture manifest, PNG and
Windows test report. Their original source paths describe the machine where
capture occurred; copied artwork is mapped by collection and its unchanged
pack SHA-256. Paths need not exist on the evaluation computer.

The exact JSON source for temporary large-canvas, framing and comparison
fixtures is retained under `evidence/source-inputs/`. Its manifest binds each
copied pack to the corresponding capture's input SHA-256. The gallery links
these packs so they can be opened in the viewer with the single-pack command.

The package contains only positive, independently validated capture bundles.
Failed-case diagnostics remain in the full Actions qualification artifact.
The Windows package smoke receipt is a separate Actions artifact: it records
executing the packaged viewer launcher and bundled Python capture with a
restricted PATH, including a verified fresh Godot framebuffer capture.

## Unattended capture

In PowerShell, this example uses the package's ordinary capture launcher and
creates a fresh output directory containing a full PNG, viewport, detail,
source/renderer hashes and sealed manifests:

```powershell
& '.\Capture example.cmd' 'C:\ArtCaptures\lumen-first'
```

Choose a new directory for each run. Existing images and directories with
retained publication claims are refused. After an interruption, retain the
incomplete output for diagnosis and retry into a new directory; the tool does
not take over an uncertain writer's output. To stop an unattended process,
press **Ctrl+C** in its terminal. Incomplete work is not valid publication.

To capture every original collection and feature in one new bundle:

```powershell
.\dependencies\python\python.exe -B .\tools\world_art_preview_launcher.py `
  --godot .\Godot_v4.7-stable_win64_console.exe --rendering-driver opengl3_angle `
  --capture --art-root .\docs\world-design --shots full,viewport,detail `
  --all-features --scale 1 --output-dir 'C:\ArtCaptures\complete-atlas'
.\dependencies\python\python.exe -B .\examples\world-art-capture\build_gallery.py `
  --bundle 'C:\ArtCaptures\complete-atlas'
```

The extracted package is intentionally not a Git checkout. Fresh captures
still record actual input-file and renderer hashes. A caller-supplied revision
label is identified as caller-supplied, rather than being presented as a Git
verification. The package manifest supplies the delivered commit's file ledger.

Godot's display-less headless backend cannot produce the graphical evidence.
Unattended capture needs a graphical display; Windows ANGLE and Linux
X11/Xvfb with OpenGL are the qualified CI routes. Pixel equality across GPUs
or operating systems is not assumed. Fixed time and unchanged rendering
configuration support repeatability on the same renderer.

## Capacity and compatibility

The read-only art adapter accepts positive dimensions up to **16,384 cells per
axis** and **16,777,216 cells total**, including 1024×4096, 512×8192, 8192×512,
2048×8192 and 16384×1024. Ordinary full PNG export is bounded to **50,000,000
output pixels**. The interactive viewer uses that ordinary bound.

For a larger whole-map image, explicitly select the same renderer's streamed
capture path. The limit is **100,000,000 output pixels**, at most **65,536 per
output axis**. Godot renders original shader pixels in tiles; Python streams
those exact RGB bytes into PNG scanlines. There is no silent resizing or crop.

```powershell
.\dependencies\python\python.exe -B .\tools\world_art_preview_launcher.py `
  --godot .\Godot_v4.7-stable_win64_console.exe --rendering-driver opengl3_angle `
  --capture --pack 'C:\MyArt\1024x4096\pack.json' --shots full `
  --scale 4 --stream-large --output-dir 'C:\ArtCaptures\tall-4x'
```

This produces 4096×16384 pixels when the source pack is 1024×4096. Over-budget
requests fail with an explanation. Preview limits do not increase native World
simulation or save/import limits, and static images do not qualify physics,
Rapier, traversal, Water behaviour or gameplay performance. Material conditions
are explicit synthetic creation-state fixtures.

## Verification and rebuilding

To check delivered file integrity after extraction:

```powershell
.\dependencies\python\python.exe -B .\tools\world_art_evaluation_package.py verify --package .
```

Runtime-generated `godot/.godot/` cache files are excluded from the source
ledger. Other changes, missing files and added files fail verification. A
self-sealed file ledger verifies consistency; the trusted Actions run and exact
commit provide publication provenance. It is not a digital signature.

The reusable builder is `tools/world_art_evaluation_package.py`. Run it from a
clean checkout at the intended commit, after that checkout's Windows graphical
capture suite. Supply the verified official Godot executable directory,
copyright/license notices and the current capture-evidence directory. The
builder rejects stale renderer hashes, incomplete corpus coverage, failed test
results and source bytes differing from the specified committed source.

```powershell
python tools/world_art_evaluation_package.py build --source-sha (git rev-parse HEAD) `
  --engine-dir 'C:\Build\godot-4.7' --engine-notices 'C:\Build\godot-notices' `
  --python-root (python -c 'import sys; print(sys.base_prefix)') `
  --capture-evidence '.\build\world-art-capture-windows' --output 'C:\Build\World-Art-Evaluation'
python tools/world_art_evaluation_package.py smoke --package 'C:\Build\World-Art-Evaluation' `
  --report 'C:\Build\World-Art-Package-Smoke'
python tools/world_art_evaluation_package.py archive --package 'C:\Build\World-Art-Evaluation' `
  --output 'C:\Build\CyberSand-World-Art-Windows.zip'
```

The builder also permits omitting `--python-root` for a smaller package with
the same Godot viewer and gallery. Such a package explicitly requires Python
3.10 or later for capture and verification; install Python 3.12 with
`winget install --exact --id Python.Python.3.12`, then replace the bundled
Python command in examples with `py -3.12`. The CI owner-evaluation ZIP bundles
Python and requires its real Windows smoke to pass before publication.

This remains a **Draft/HOLD evaluation candidate**. Windows hosted ANGLE
qualification uses the runner's rendering adapter. Acceptance on the owner's
physical Windows/NVIDIA GPU remains a separate observation and is not inferred
from software-rendered CI. The package grants no Ready, merge or release action.
