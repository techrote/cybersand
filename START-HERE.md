# Working on CyberSand

**Current workspace guide, reviewed 2026-09-08.** Development and testing:
`C:/kybersand`. Functional deliverables: `C:/cybersand`. Editor:
`C:/Godot47/Godot_v4.7-stable_win64.exe`.

Double-click `Open-Godot.cmd`, or import `source/godot/project.godot` in Godot.
F6 runs the current scene; F5 runs the desktop project. The Web scene is
`res://web_main.tscn`. Edit `source/godot`, not disposable `source/build/web-project`.
For C++ changes, stop the game and close the editor before `dev.cmd native-build`
so Windows can replace the DLL, then reopen it.

From `C:/kybersand`:

- `dev.cmd doctor` checks the configured tools.
- `dev.cmd native-test` compiles/runs native regressions.
- `dev.cmd godot-test` runs Godot fixtures against the installed native library.
- `dev.cmd web` builds the compatibility export in `source/build/web`.
- `0Preview.cmd` starts a local preview; use an explicit directory when selecting a profile.

Delivery is a separate action: when authorized, `Deliver-Web.ps1` verifies the
export manifest and copies to `C:/cybersand/web`; `C:/cybersand/Preview-Web.cmd`
previews that deliverable at port 8001. A manifest check alone does not prove a
fresh build or browser execution. This documentation task made no delivery.

[Source checkpoints](source/docs/operations/source-checkpoint-and-recovery.md)
identify committed work; [local development](docs/LOCAL_DEVELOPMENT.md) provides
setup commands; [evidence](source/docs/reference/validation-evidence.md) records
dated tests. The original setup report remains historical.

Historical relocation check, 2026-09-08 before later Auto/Rapier Web work: six
doctor checks, import and 11 Godot runners passed; that delivery had 15 manifest
files. Records: `validation/local/20260908-124518` and `20260908-124531`.
Those are not today's inventory or fresh acceptance claims.
