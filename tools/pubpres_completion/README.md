# CyberSand PUBPRES Completion Windows evaluation

Extract the source-bound Windows ZIP to a writable folder, then double-click
`Open Workbench.cmd`. The Workbench opens at the exact candidate commit with
Godot 4.7, Safe rendering, full material publication and continuation Off. The
included Godot, native and Rapier runtimes are used from this package. No
separate engine, Python, Git or redistributable installation is needed.

Choose **Save start [Ctrl+S]** to save the authored starting scene. Close the
window, open `Open Workbench.cmd` again and choose **Load start**. The launcher
reuses the same isolated profile under the sibling `Runs` directory. Keep that
directory to keep saved work and launch evidence. A package with a different
manifest starts a separate profile. Two windows cannot open the same profile
at once.

The delivered ZIP has a detached SHA-256 receipt. The launcher verifies the
manifest and every packaged file before launch, then verifies the copied
application source on each reopen. The official Windows Godot build, complete
native source input ledgers for M/I/D/C, checked Rapier provenance, compiler
dependency custody and signed Microsoft Visual C++ runtime provenance are all
included. Each project has its own native build. Do not move a binary between
projects.

The ordinary shortcut selects native OpenGL. For a separate ANGLE compatibility
session, call the packaged `Start-PUBPRES-Playability.ps1` with the supplied
manifest's full candidate commit, `-Action Open -OwnerProfile
-RenderingDriver opengl3_angle`. The profile is independent of native OpenGL.
The shortcut's `--hosted-smoke` option runs the bounded ANGLE startup probe.

The four source keys are M (accepted main), I (last physically measured
integration), D (preserved playability donor), and C (Completion candidate).
The manifest fixes every source commit and tree. The owner shortcut opens C.
For an independent source session, use the same PowerShell launcher with
`-Action Open -Source Main`, `-Source Integration`, or `-Source Donor`,
and the manifest's full candidate commit. That launcher prints the chosen
run directory. To reopen that specific run, supply `-ReopenRun` with its
path and omit `-OwnerProfile`.

An explicit reachable-staging candidate run uses blit with target retirement.
Physical NVIDIA acceptance remains HOLD. Hosted ANGLE results measure the
listed software-renderer setup. Follow `ACCEPTANCE.md` for the physical owner
run and use `Collect Results.cmd` to collect its evidence once Workbench has
closed.
