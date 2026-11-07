---
title: GEN-006 Windows desktop gameplay acceptance
status: Planned
document-kind: audit
scope: Human Windows 11 graphical input and persistence acceptance of Draft GEN-006 experimental streaming
last-reviewed: 2026-11-07
---

# Windows GEN-006 desktop playtest and evidence capture

## Executed Windows desktop checkpoint — 7 November 2026

**AUTOMATED WINDOWS DESKTOP ACCEPT — HUMAN PLAYTEST PENDING.** This qualifies
the existing #486 experimental streaming test scene, not a second game client.
GEN-006 tests demand loading, bounded residency, eviction/reload and saved edits;
the earlier GEN stages supply terrain generation. Production shared-World
streaming (#512), cross-shard physics, GDExtension integration, general power-loss
durability, recipe reconciliation and sidecars remain separately unqualified.

### Source, platform and original artifacts

Isolated branch `codex/gen006-real-desktop-20261107` starts at refreshed #486
`6f97e91093bdf4ddb109e21c3df13e90676eab6e`, tree
`dd62116919eb8925e47bbaa2bab6ba4a798753b1`, incorporating observed main
`81bbd5ff5cf366159e2b8a630609359c13560080`. #513 apparatus was brought forward
from `32ac4b097a7cae4ecdad1e8081a2f51c4efdae65`. The branch's final commit is
the recoverable repair checkpoint; per-run receipts record exact local script
hashes. Native source is unchanged, tree `19cad83fcc5eacb2620c2f099606b5d18a66501b`.

Actual local compilation: LLVM Clang 23.1.4 revision
`7a941dfb2877a0b8cf30323fefa85ad019e0b0f5`, installed MSVC x64 BuildTools,
C++20 `-O0`, one configured worker. Native executable SHA-256:
`b97ca26556e365dd658a51ed861ba321e625af2e88c6ffab51461de2d838b676`.
No claim of four participating workers. Windows 11 Pro build 26300; Godot
`4.7.stable.official.5b4e0cb0f`. Godot stdout selects **OpenGL 3.3.0 NVIDIA
581.80, Compatibility, NVIDIA TITAN RTX**. No headless/software substitution.
Godot console executable SHA-256:
`d8055fb8c7e7f5010d7439ec69be051554055dae55a265f8647bd7301c34161c`;
window executable SHA-256:
`b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`.

Raw evidence remains at `C:/Users/_/gen006-desktop-evidence-20261107/` on the
tested desktop; generated executables, logs, saves and archives stay outside Git.

| Evidence | Actual outcome |
|---|---|
| `run-01` | Original launcher compilation failure retained: PowerShell split unparenthesized command concatenations across array elements. |
| `run-02` | Fresh native build and NVIDIA graphical qualification exit 0; eight original framebuffer PNGs, hashes, compiler command/version, stdout/stderr and source receipt. |
| `run-02/session-a` | Real desktop Wall, Empty, 17-cell acknowledged Wall drag, Water, Right, Shift+Right, Home, Space, R, normal Alt+F4. Stable PID33044, 758 requests/2576 service ticks, stopped receipt and native cleanup. Explicit 16-pending-action overflow refusal; unsupported neighboring simulation visibly pinned. |
| `run-02/session-a/readback.*` | Independent native readback of copied save: Wall(9,50), Empty(31,11), stroke endpoints(26,44)/(42,44), all intent=1. Water placement intent(36,41) retained; that cell no longer contains static Water after simulation, so it is not a Water17 persistence witness. |
| `run-02/session-b` | Same saved world reopened, PID22664, exact edited RGBA checksum8050198371280564362. At about67s an empty response read caused sequence mismatch/input failure. Owner stayed alive, then explicit unconfirmed-outcome shutdown killed it. Original JSONL and failure screenshot retained. |
| `run-02/session-b2` | Diagnostic repeat: real Up, Shift+Left, Home, same saved world, PID51984, 892 requests/3092 ticks, normal exit/stopped receipt. No repeated spontaneous response failure over103s. |
| `locked-read-before` / `locked-read-after` | Real native durable Empty ACK held behind an exclusive Windows read handle. Old adapter reproduces empty sequence mismatch, Godot open error12. Repaired adapter renders12 frames with zero false ACK/replay, then consumes original ACK once after unlock, same native PID. Original spontaneous denial's responsible process remains unidentified. |
| `run-02/crash*` | Existing crash-after-ACK fixture PASS: two actual native processes, five ACKs, Water17/temperature417, Empty intent/generation5 recovered after kill without quit/save-all. |
| `run-03` | Repaired scene/launcher, authenticated unchanged native executable, fresh graphical exit0, eight newly hashed PNGs. Source receipt includes exact consumed scripts and local delta. |
| `run-03/session-c` | Repaired actual desktop scene: PID51236, about169s, 1464 requests/5057 ticks, new durable Wall(52,48), two evictions/two reloads, Home, normal exit/stopped receipt, no surviving owner or repeated response failure. |

### Measured behavior and repair

The evidence-only observer reads real monotonic frame intervals and existing
HUD/native counters; it injects no input/native mutations. Session C's168 samples:
native29.98 service ticks/s; median per-window frame p50/p95 **16.680/16.809ms**;
largest frame gap **62.173ms**. Sampled host IPC median/p95 **17.031/33.630ms**,
peak host round-trip **74.125ms**. These are instrumented host timings, not disk
ACK or input-to-photon latency; framebuffer capture adds overhead. Fast dragging
can saturate the bounded queue and explicitly refuses unsent edits.

Windows GPU Engine recorded **0.463% 3D** for actual Godot PID2228 in one sample;
whole-device utilization includes other open applications. Two-point memory:
Godot private236.8→236.6MB, native private1.20→1.72MB, native handles45→45.
This short sample does not establish leak/soak qualification. The occupied-cell
HUD retains the last survey during asynchronous navigation rather than updating
every frame. Require native ACKs when counting edits after focus changes.

Repairs are confined to the launcher and experimental test-scene transport:
parenthesized compiler command expressions; eight-frame hash manifest; retained
exit codes/script hashes/manual logs. The adapter opens a response once and
passes that handle to validation. Unreadable responses stay outstanding under
the existing1.5/30s limits; no mutation replay or false ACK. Bad sequences remain
fail-closed and their response is retained rather than deleted.

Focused Windows reproduction, after staging the demo and new qualification
script in the minimal project (25s parent watchdog;8s lock handshake):

```powershell
python tools/experiments/gen006_windows_response_read.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --exe <source-matched-native.exe> --project <minimal-project> --root <fresh-evidence-directory>
```

Docs/repository checks initially failed six absent companion-workspace routes.
Restoring only those test inputs from CI-pinned companion
`6a58311982941b75f46e22109a0829e5acb83c7e` resolves both. Docs, repository,
retained M11 integrity and retrieval evaluation pass; historical hashes unchanged.

Change map: native World, ownership, physics/materials, production interfaces/ABI,
serializer, generator/recipes, capacity/defaults and ADRs are unchanged. The
roadmap/handover route to this scoped audit, which remains outside default
retrieval. Neither #486 nor #513 is Ready/merged. Scripted desktop actions are
not a human verdict; a reopened visible saved-world session is provided for that.

## Original proposed procedure (retained)

The existing #486 prototype has passed hosted Linux/OpenGL visual tests and real Linux/Windows native-process persistence regression. Neither result proves human desktop gameplay/input feel or real Windows rendering.

This opt-in test runner uses installed Godot 4.7 and actual compiled CyberSand native World. It must not use --headless or a synthetic screenshot. It captures seven actual native-backed Godot viewport PNGs from the integrated graphical-qualification scene, checks native PID continuity, terrain on first frame, editing, camera movement, eviction/reload and Water visibility, then offers a separate two-session human Windows playtest.

## Command

From a Windows PowerShell terminal in a checkout of this Draft branch:

    powershell -ExecutionPolicy Bypass -File tools/experiments/gen006_windows_desktop_playtest.ps1 -GodotExe "C:\path\to\Godot_v4.7-stable_win64.exe"

If the real streaming-slice executable has already been compiled using the existing #486 native build instructions:

    powershell -ExecutionPolicy Bypass -File tools/experiments/gen006_windows_desktop_playtest.ps1 -GodotExe "C:\path\to\Godot.exe" -NativeExe "C:\path\to\streaming-slice.exe" -SkipBuild

Add -AutomatedOnly to capture real Windows framebuffer PNGs and original logs without prompting for human gameplay. Manual acceptance requires running without this switch.

The dedicated Windows CI also builds a source-attested portable experimental streaming-slice.exe. If using its artifact, extract the binary, then provide its absolute path using -NativeExe and add -SkipBuild. When running the packaged copy of the PowerShell runner outside the source tree, pass -RepositoryRoot with the absolute path of the matching CyberSand checkout. The artifact alone is not a standalone game or a substitute for the Godot source scene.

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
