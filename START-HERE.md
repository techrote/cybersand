# Working on CyberSand

Active development and testing: C:/kybersand
Functional deliverables: C:/cybersand
Editor: C:/Godot47/Godot_v4.7-stable_win64.exe

Double-click Open-Godot.cmd or the CyberSand WIP desktop shortcut to open the editable project. You can also import C:/kybersand/source/godot/project.godot in Godot's Project Manager.

Edit scenes and GDScript in Godot; F6 runs the current scene and F5 runs the native project. The Web demo scene is res://web_main.tscn. The desktop main scene retains the native sandbox. Changes are WIP until you choose to build and deliver them.

For C++ changes, stop the running game and close the editor before running dev.cmd native-build (Windows may lock the DLL). Reopen the editor afterward.

From C:/kybersand:
- dev.cmd doctor checks the toolchain.
- dev.cmd godot-test runs the Godot fixtures.
- dev.cmd web builds the Web export under source/build/web for testing.
- powershell -ExecutionPolicy Bypass -File .\Deliver-Web.ps1 verifies its manifest and copies the output to C:/cybersand/web.
- C:/cybersand/Preview-Web.cmd previews that deliverable at http://127.0.0.1:8001/.

The original Documents/ChatGPT/cybersand workspace is retained as a backup. Historical reports describe the old setup; use these locations for new work. Godot is self-contained: editor settings and templates are kept in C:/Godot47/editor_data. The source and native DLLs remain editable in C:/kybersand; do not edit the disposable source/build/web-project staging copy.


Historical relocation check, 2026-09-08 (before subsequent Auto/Rapier-Web work): Godot 4.7 version and executable hash match; all six dev.cmd doctor checks passed; project import succeeded and 11/11 Godot fixtures passed. Current Web delivery contains 15 manifest-verified files. Details are in validation/local/20260908-124518 and validation/local/20260908-124531.

Current source identity, incomplete commit/backup coverage, the later 15-fixture
Windows run, and Web artifact checks are in the
[documentation audit](source/docs/audits/2026-09-08-documentation-audit.md).
