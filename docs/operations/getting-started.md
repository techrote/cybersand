---
title: Getting started with CyberSand desktop
status: Current
document-kind: guide
scope: First launch from a source checkout or identified evaluator, desktop prerequisites and user navigation
canonical-for: [desktop-first-launch]
last-reviewed: 2026-11-24
related-documents: [workbench-first-session.md, local-build-and-validation.md, troubleshooting.md, showcase-guide.md]
---

# Getting started with CyberSand

The easiest place to begin is **Development workbench** in the feature launcher.
It opens the ordinary Shared Workbench: a native material canvas, painting tools,
actors, a generator and the Water, Materials and Art interfaces.

## Choose your installation route

| What you have | What to do |
| --- | --- |
| A complete source checkout | Materialize Git LFS, use the exact pinned Godot executable and verify the retained runtime. Follow the commands below. |
| A source-identified Windows evaluator | Extract the entire archive to a writable folder and use its supplied launcher, commonly **Open Workbench.cmd**. Keep its project, dependencies, licenses and manifests together. |
| Only source files or an incomplete ZIP | Obtain the missing runtime/dependencies or follow the [build guide](local-build-and-validation.md). A small Git LFS pointer is not a native library. |

An evaluator has its own source/runtime identity and scope. It may contain an
unmerged candidate. Read its manifest and accompanying evaluation record before
assuming it behaves like accepted main. This guide does not establish that any
particular old Actions artifact is still downloadable.

## Source checkout on Windows

Install Git with Git LFS and obtain **Godot 4.7.stable.official.5b4e0cb0f**, the
repository pin. A different 4.x executable is not interchangeable for this
workflow. From PowerShell:

```powershell
git clone https://github.com/techrote/cybersand.git
cd cybersand
git lfs install
git lfs pull
.\launch-desktop.cmd -Godot "C:\Tools\Godot\Godot_v4.7-stable_win64.exe"
```

Replace the Godot path with your installed pinned executable. The repository
launcher checks the exact Godot version, requires materialized native/Rapier
libraries, verifies the native DLL against its recorded SHA-256, and prints
checkout/runtime identity before starting the project. It does not rebuild
libraries or compare the checkout's native source inputs with the runtime's
build inputs. Run `python tools/ci/check_repository.py --require-materialized`
from the source root for that separate provenance check, particularly after
changing branches or source. The same launcher supports an identity-only check:

```powershell
.\launch-desktop.cmd -Godot "C:\Tools\Godot\Godot_v4.7-stable_win64.exe" -PrintIdentityOnly
```

The default search location is `C:\Godot47`; an explicit `-Godot` path or
`CYBERSAND_GODOT` override avoids dependence on a machine-specific installation.
Do not copy another branch's DLL over a failed check. Use the
[source/runtime build procedure](local-build-and-validation.md).

## Source checkout on Linux

Materialize LFS and use the pinned Linux Godot executable. With that executable
available as `godot`, from the repository root:

```sh
godot --version
python3 tools/ci/check_repository.py --require-materialized
godot --path godot
```

The version must match the pin above. The provenance checker and
[build guide](local-build-and-validation.md) distinguish missing files, stale
native inputs and a valid retained runtime. A native library built for another
platform is not a substitute. Launching directly is supported, but does not
perform all of the Windows wrapper's checks on your behalf.

To enter the Workbench directly after prerequisites are satisfied:

```sh
godot --path godot -- --workbench
```

## Your first screen

Choose **Development workbench — blank canvas, flyer fleet, materials and solver
controls**. Other launcher entries open their own sessions. In the Workbench:

| Control | Purpose |
| --- | --- |
| **Play / Pause [P]**, **Step [.]** | Run or pause; request one step while paused. |
| **New blank** | Replace the authored scene with a blank starting canvas. Save first. |
| **New from generator…** | Prepare a native preview; installation is a separate confirmation. |
| **Free camera / Follow selected / Overview** | Select the view; wheel zooms and middle-drag pans. |
| **Materials Lab…**, **Water Lab…**, **Art batches** | Open the corresponding authoring or inspection interface. |
| **Save start [Ctrl+S] / Load start** | Save and reconstruct an authored start using the adjacent name field. |
| **Menu [F2]** | Close this session and return to the launcher. |

Text fields keep keyboard focus. Click back in the canvas or use a visible
button if a shortcut appears inactive. Painting and actor shortcuts share keys
in different modes; the [painting guide](workbench-painting-and-history.md)
explains the paused editing context.

Continue with the [first Workbench session](workbench-first-session.md) for a
small experiment that you can save and reopen. Use the
[showcase guide](showcase-guide.md) to explore ready-made scenes.

## If launch fails

- **Git LFS pointer:** run `git lfs pull` in this checkout, then recheck identity.
- **Godot mismatch:** select the exact pinned executable, including its official
  revision. Do not suppress the version check.
- **Stale native inputs:** rebuild or obtain a qualified matching runtime through
  the build/release workflow. An import completing is not runtime qualification.
- **Incomplete evaluator:** extract all files again; keep bundled paths intact.
- **Graphics or input problem:** record platform, renderer, scaling, source and
  runtime identity, then follow [troubleshooting](troubleshooting.md).

Web and GDScript fallback have different constraints. The full Materials Lab
candidate compiler and ordinary desktop authoring path are not a promise of Web
parity.

## Source and verification scope

Entry labels and command-line routing come from
[`feature_launcher.gd`](../../godot/scripts/feature_launcher.gd). The checked
Windows launcher is [`launch_desktop.ps1`](../../tools/launch_desktop.ps1);
[`project.godot`](../../godot/project.godot) selects the feature launcher.
This guide's UI steps are source-checked; actual executed walkthroughs and
platform limitations are recorded in the documentation decision packet.
