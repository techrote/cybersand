---
title: GEN-006 Windows desktop gameplay acceptance
status: Planned
document-kind: audit
scope: Human Windows 11 graphical input and persistence acceptance of Draft GEN-006 experimental streaming
last-reviewed: 2026-11-07
---

# Windows GEN-006 desktop playtest and evidence capture

The existing #486 prototype has passed hosted Linux/OpenGL visual tests and real Linux/Windows native-process persistence regression. Neither result proves human desktop gameplay/input feel or real Windows rendering.

This opt-in test runner uses installed Godot 4.7 and actual compiled CyberSand native World. It must not use --headless or a synthetic screenshot. It captures seven actual native-backed Godot viewport PNGs from the integrated graphical-qualification scene, checks native PID continuity, terrain on first frame, editing, camera movement, eviction/reload and Water visibility, then offers a separate two-session human Windows playtest.

## Command

From a Windows PowerShell terminal in a checkout of this Draft branch:

    powershell -ExecutionPolicy Bypass -File tools/experiments/gen006_windows_desktop_playtest.ps1 -GodotExe "C:\path\to\Godot_v4.7-stable_win64.exe"

If the real streaming-slice executable has already been compiled using the existing #486 native build instructions:

    powershell -ExecutionPolicy Bypass -File tools/experiments/gen006_windows_desktop_playtest.ps1 -GodotExe "C:\path\to\Godot.exe" -NativeExe "C:\path\to\streaming-slice.exe" -SkipBuild

Add -AutomatedOnly to capture real Windows framebuffer PNGs and original logs without prompting for human gameplay. Manual acceptance requires running without this switch.

Build prerequisites: MSVC x64 Build Tools and LLVM clang++, same as existing hosted Windows native CI. Godot 4.7 local desktop executable, a real Windows user session with graphics device and sufficient disk space. The script refuses an existing evidence root and does not overwrite prior screenshot evidence. It builds or uses actual native World, stages a minimal Godot test project and records source SHA/tree, compiler, executable SHA-256, OS/GPU identity, Godot version, graphical logs and per-PNG hashes in one new evidence directory.

## Human checklist (requires explicit verdict)

1. Inspect the first visible terrain frame. It must contain actual Strata cells, not an all-black sky.
2. Paint Wall, dig Empty, paint Water17; observe input latency and that native tick continuation remains responsive. No fake interactive surface.
3. Navigate camera to adjoining chunks and jump 24 chunks with Shift+arrows. Verify world-coordinate indicators, native persistent process identity and displayed eviction/restore receipts.
4. Return Home, verify edited state and explicit Empty intent persist. Unsupported surface-boundary situations must produce an understandable pin/refusal rather than a native process exit.
5. Exit the Godot window cleanly. Reopen against the same private save root and verify player edits and simulation state did not regenerate.
6. Record PASS/FAIL/HOLD and concrete observations. The script does not claim a human pass on its own.

## Acceptance boundary

The automated seven-frame test is **Windows desktop viewport execution**, not a substitute for the human gameplay decision. Further Native/GDExtension production CI, real shared-World selective dynamic eviction, cross-shard Water/physics, actor sidecar persistence, recipe reconciliation and crash-durable transaction safety are separately gated. Keep #486 and this test Draft, no merge into main or Ready transition. Original #496 five screenshots remain retained at Actions artifact 13556425122 and must not be overwritten by any new Windows run.
