# CyberSand Windows Workbench evaluator

Extract the entire evaluator ZIP to a new writable folder and double-click **Open Workbench.cmd**. The first launch imports the project, starts the Workbench and prints the application, engine, native runtime, renderer and active policy. Godot, Rapier and the native tools are included.

| Open | Starting scene |
| --- | --- |
| Open Workbench.cmd | Ordinary Workbench and authoring controls |
| Open Wave 512.cmd | Small Water world with a Needle flyer |
| Open Wave 1024.cmd | Medium Water world with two flyers and two barrels |
| Open Wave 2048.cmd | Large Water world with a Needle flyer |
| Open Mixed 2048.cmd | Large Water and Sand world with four actors and obstacles |

**Compare playability.** Open Wave 512 and press **P** to run. Pilot the flyer into and out of Water, pick a visible part, drag it, and switch between Free and Follow camera. Paint across its path, zoom, pause, step and resume. Repeat for five minutes in Wave 2048 or Mixed 2048. Watch for a missing or lagging body, a pick landing on a different part, or a simulation freeze while rendering continues.

Use the same scene with **Stock Safe Fallback** in the filename to compare the official engine with the recovery switches off. **Open Stock Safe Fallback.cmd** opens the ordinary fallback Workbench. If this build includes the separate **Bounded Experimental** launchers, they exercise the atomic Separate4 engine. Each scene and mode keeps its own profile. The packaged selection and rationale are in [selection.json](tools/pubpres_recovery_windows/selection.json).

**Save and reopen.** Use **Save start** to store the authored materials and actors. Close the window normally, reopen the same command, and choose **Load start**. The save represents the authored starting state. Each command keeps writable data in the sibling `Runs` folder.

**Record the result.** The first launch creates `Runs/OWNER-ACCEPTANCE.md`. Record the scene, mode, duration and shortest reproduction for any problem. Close Workbench and run **Collect Results.cmd**. The ZIP and checksum appear in `Runs/Reports`. The report index identifies any omitted files.

The [physical acceptance checklist](ACCEPTANCE.md) covers the remaining Windows 11/NVIDIA evaluation. Hosted graphical checks exercise the software adapter. The package manifest binds the shipped files and runtimes, and [the correctness receipt](qualification/recovery-correctness.json) identifies the Windows application gates.
