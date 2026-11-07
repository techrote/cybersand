# CyberSand World Art Preview — interactive Godot 4.7 workbench

**Experimental, independent presentation tool.** Open the native Godot window to inspect provisional world-design art through the **production RG8 material palette, appearance LUT, emission and glow shaders**. No CyberSand native simulation, native extension, Rapier actor or save format is required. Synthetic initial conditions are explicit, not measurements of physical state.

## Launch from a fresh checkout

Obtain both the preview branch and the separate **read-only art source**. Do not merge #454 into main or modify the original export. From a parent directory with Git and Godot 4.7 installed:

~~~bash
git clone https://github.com/techrote/cybersand.git cybersand-preview
git -C cybersand-preview switch --track origin/tools/world-art-interactive-preview-20261107
git clone --no-checkout https://github.com/techrote/cybersand.git art-source
git -C art-source checkout 05632d52e8bfb6ac302da1158653505ae203fbf6
cd cybersand-preview
python3 tools/world_art_preview_launcher.py --godot=godot --art-root="$(cd ../art-source/docs/world-design && pwd)" --design-revision=05632d52e8bfb6ac302da1158653505ae203fbf6
~~~

On Windows, change the final line in PowerShell to the following, using your installed Godot 4.7 console executable:

~~~powershell
python tools/world_art_preview_launcher.py --godot="C:\Tools\Godot_v4.7-stable_win64_console.exe" --rendering-driver=opengl3_angle "--art-root=$((Resolve-Path ..\art-source\docs\world-design).Path)" --design-revision=05632d52e8bfb6ac302da1158653505ae203fbf6
~~~

Alternatively give an individual file with --pack=/absolute/path/pack.json rather than --art-root. You can paste a directory into the **World-design root** field, press Enter, or use **Choose directory**. The folder should contain lumen-fault/pack.json, coral-telegraph/pack.json, etc. The window lists the 15 known collections in their logical order; additional collection folders with pack files are discovered automatically.

The small Python launcher constructs a **temporary, standalone Godot 4.7 project** by copying exact shader/LUT/preview script bytes from the checked-out repository, then invokes the real Godot desktop scene. The temporary project contains **no native/GDExtension or Rapier plugin**, so no CyberSand simulation library needs to be installed or loaded. Its compiled shaders are source-bound to the copied production files. The temporary project is deleted when Godot exits, but screenshots remain in the configured user-data/output directory. The tool does **not** import #454 art into this branch or start Scheduswarm. Revision text is caller-provided attribution; the displayed SHA-256 validates actual pack bytes.

## Camera and inspection

| Action | Controls |
| --- | --- |
| Change collection | Left list or Previous / Next |
| Show combined map | Combined composition in Scene/feature |
| Show a reusable feature | Scene/feature selector, then authored variant |
| Smooth cursor-centred zoom | Mouse wheel over central viewport |
| Pan | Hold middle or right button and drag |
| Fit whole image | **F** / Fit |
| Native pixel zoom | **1** / 1:1 |
| Reset presentation and camera | Reset |
| Reload modified JSON | **R** / Reload |
| Pin currently displayed framebuffer | **P** / Pin |
| Toggle captured original/current | **B** / Show before / Show after |
| Play or pause presentation animation | **Space** / Play |
| Save visible framebuffer | **Ctrl+S** / Save visible viewport |

The centre is an actual Godot SubViewport running existing shaders: **not** an SVG, flat CPU illustration or old screenshot. It keeps one loaded RG8 backing texture and updates camera/uniforms on navigation. Wide scenes render beyond 1,024 cells without a right-edge cutoff. The optional grid appears at 6× zoom or greater. The inspector shows pointer cell coordinates, authentic material ID and **synthetic** condition byte.

The right sidebar controls glow, animated presentation time, structured material quality, background decoration, grid and 1×/2× full-export scale. These controls do not edit the source map or the physical simulation.

## Artist edit, reload, compare and export

1. Select an art collection and inspect the composition.
2. Click **Pin** to retain the **actual rendered viewport pixels**, source SHA, camera, scale and presentation settings. Pinning does not regenerate the old source later.
3. Edit a **writable copy** of pack.json using your generator or editor. Keep the original #454 checkout read-only; select your working copy with --pack.
4. Click **Reload**. Parsing, geometry validation and RG8 creation must all succeed before replacing the last good image. Invalid JSON or geometry retains the previous rendering and displays an error. Successful reload preserves camera and presentation settings.
5. Use **Show before / Show after** to toggle the captured baseline and newly rendered view. The camera, time, zoom and material-detail settings restore to those of the pinned image for alignment. After window resize the baseline screenshot is rescaled, so pin again for native pixel-for-pixel comparison.
6. Export visible viewport, **full combined composition**, selected feature or central detail crop. All images are **actual Godot framebuffer readbacks**.

The selected feature export uses its authored variant. **Save full composition** always uses the combined scene and its authored placements/variants. Large full exports use 512-native-cell tiles with 32-native-cell halo overdraw and source-world coordinates. Crops originate from the current framebuffer. Exports are bounded to 50 million output pixels and fail visibly rather than silently clip.

## Output and provenance

Default export location:

~~~text
user://world-art-preview/captures/<timestamp>-<kind>-<random>/
    viewport.png | combined.png | feature.png | detail.png
    metadata.json
    status.json
~~~

The isolated Godot project is named **CyberSand World Art Preview**; its user-data directory is typically under %APPDATA%\Godot\app_userdata\CyberSand World Art Preview\ on Windows or ~/.local/share/godot/app_userdata/CyberSand World Art Preview/ on Linux.

Override with --export-root=/absolute/output/folder. Every click creates a **new** directory and never overwrites earlier captures. Status initially says incomplete; only a successful PNG and metadata write marks it complete. Partial output stays visible on error. Output inside the source pack's directory is refused. The app never rewrites, renames or deletes source art. No locks, leases, PID checks or capture recovery are used.

Metadata includes actual input SHA-256, caller-supplied art revision, feature/variant, native/output dimensions, PNG SHA-256, RG8 provenance, renderer/OS/driver identity, ANGLE shader selection, camera and presentation settings, and any pinned baseline identity. The status bar and console show saved paths.

## Limits and tests

Material conditions are **synthetic native-material creation-state bytes** following the established adapter fixture. A preview is not evidence of physical stability, pressure, Water behaviour, material reactions, Rapier collisions, traversal, worldgen runtime or gameplay performance. The provisional pack format is not a production import/save contract.

Only the active composition/feature texture is held, not all 15 maps. JSON parsing, geometry construction and large exports may briefly block the UI; an operation status is displayed, but these tasks are not threaded. File watching is not included: use explicit Reload. Pinning is per session and per viewport, not persistent revision history.

The dedicated [GUI evidence workflow](../../.github/workflows/world-art-preview.yml) checks #454 at exact source revision on Linux OpenGL/llvmpipe and Windows ANGLE. The smoke covers 15 combined collections, 120 feature identities and variants, camera inputs, actual source edit/reload, last-good retention, before/after, actual glow/time pixel changes and PNG export. The adapted RG8 geometry/condition oracle is a separate focused test.

~~~bash
python3 tools/world_art_preview_launcher.py --godot=godot --adapter-oracle
xvfb-run -a python3 tools/world_art_preview_launcher.py --godot=godot \
  --rendering-driver=opengl3 --art-root=/absolute/art-source/docs/world-design \
  --design-revision=05632d52e8bfb6ac302da1158653505ae203fbf6 \
  --export-root=/absolute/evidence/exports --smoke-output=/absolute/evidence
~~~

Inspect the original retained screenshots and logs before claiming graphical qualification. This tool does not alter production gameplay, renderer shaders, native material authority or Scheduswarm.
