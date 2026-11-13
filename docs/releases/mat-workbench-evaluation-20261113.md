---
title: Combined Materials Lab and Workbench Windows evaluation
status: Current
document-kind: evidence
scope: Acceptance instructions and exact identities for one standalone Windows evaluation prerelease
canonical-for: [mat-workbench-evaluation-20261113]
last-reviewed: 2026-11-13
related-documents: [../audits/2026-11-12-mat-auth-workbench-integration.md, ../operations/materials-lab-authoring.md, ../operations/wb-art-paint-integrated-candidate.md]
---

# CyberSand Materials Lab + Workbench evaluation

The combined application has passed its complete Linux and Windows source
campaigns, delivered Windows package tests, and the final Documentation, Native,
Godot and Palette workflows on the exact runtime publication commit below.
This prerelease provides the original tested standalone Windows evaluation and
a concise owner acceptance procedure. Approval to merge remains with the owner.

## Build identity and evidence

| Item | Exact identity |
| --- | --- |
| Application source | `fd1d66b18ac80f564f7078b8a0a902297895672f` |
| Source tree | `ab10a4880d81d0875f4a4b120df40f2adcb572d9` |
| Runtime publication child and release tag target | `266d43a33e9eefc3e93a9dce1aaab6e5267492b8` |
| Accepted main, including #562 and #563 | `63f8b1ba6559906fe85f3ad0269aa296e4141d67` |
| Included latest #564 Workbench | `00017c65da096c61585f026476ae1e62e1aea256` |
| Included reviewed native capability transition | `b432d52d0d9acaa22f93eeb8d1fad48c64b4c087` |
| Complete publisher and packaged execution | [43409148541, attempt 1, request 6](https://github.com/techrote/cybersand/actions/runs/43409148541) — all nine jobs passed |
| Exact-child Documentation | [43422869229, attempt 1](https://github.com/techrote/cybersand/actions/runs/43422869229) — passed |
| Exact-child Native | [43422872133, attempt 1](https://github.com/techrote/cybersand/actions/runs/43422872133) — passed |
| Exact-child Godot | [43422875891, attempt 1](https://github.com/techrote/cybersand/actions/runs/43422875891) — passed |
| Exact-child Palette | [43422879668, attempt 1](https://github.com/techrote/cybersand/actions/runs/43422879668) — passed |
| Delivered and published Windows native DLL SHA-256 | `83b656c2638fe31c9a8ab3700c4f8c353db56e996d37a276ddfa205e81c87c54` |
| Published Linux native library SHA-256 | `44c906356a98c84b09c01f6e83bcae2391a4c0e39c5c632431a4a3f4cc1578e9` |
| Evaluation ZIP | `CyberSand-MAT-Workbench-Windows-fd1d66b18ac8.zip` — 719,116,145 bytes |
| Evaluation ZIP SHA-256 | `29e444ac801c884b066bae8866cf4dff02b5bc4ccafea2aec97bf2ceef10dd0c` |
| Original checksum sidecar SHA-256 | `df592f14c80b0b5496a48c2714f29f49a6726bba7e6c0e74dca1bed4f5426b70` |

The release copies the independently reviewed Actions evaluation ZIP and its
original checksum byte for byte. It adds these acceptance notes. Full source
history, Godot, Python, Git, C++ tools and app-local runtime dependencies stay in
the bundle, so Materials Lab can perform its admitted native comparisons without
installing developer tools. This is a prerelease and does not become GitHub's
latest release. The original evaluation artifact is **14034308666**, with outer
Actions ZIP SHA-256
`37cec79cf55c0c6519cf316316d775205f6dd994078aea4e39499427256b577f`;
the downloadable application ZIP has the separate checksum in the table.

The first [release attempt](https://github.com/techrote/cybersand/actions/runs/43427514777)
stopped during read-only admission: GitHub rejected the Actions artifact request
media type with HTTP 415. It created no tag, release or assets. This separate
second publishing branch corrects that request header while preserving the
application, original package, qualification identities and first attempt.

## Open the application

Download the ZIP, its `.zip.sha256` sidecar and these notes from this release.
In PowerShell, run:

```powershell
Get-FileHash .\CyberSand-MAT-Workbench-Windows-fd1d66b18ac8.zip -Algorithm SHA256
```

Compare the complete hexadecimal value with the sidecar and the table above.
Extract the **entire** archive to a writable folder, then double-click
**Open Workbench.cmd**. The first launch imports the project. Keep `source` and
`dependencies` beside the launchers. **Open-Materials-Lab.cmd** opens the same
Materials Lab directly. The launchers impose neither of the private capture
frame-rate caps described below.

## Acceptance procedure

1. **Generate and install terrain.** Open **New from generator…**, then choose
   Profile **gen007-deepworks**, Seed
   **19301**, World X/Y **0/0**, and Size **1024 × 1024**. Click **Generate preview**,
   then **Install into workbench**. Confirm the profile list is populated and
   terrain, camera movement and material selection work. Keep the World paused
   during the history checks below.

2. **Check one manual and agent history.** First clear a small target patch around
   `(180, 40)` through `(203, 63)` using manual **Rectangle** and **Erase · 0**;
   this is the baseline. Agent writes support existing Empty and HardWall cells.
   Make a small manual **Metal · 28** mark outside the patch. Open **Art batches**,
   select **Direct JSON**, material **Hard wall (58)**, Focus X/Y/W/H
   **0/0/1024/1024**, **Protect** off, and enable **Rectangle** under Tools. Click
   **Draw** with these inclusive rectangle coordinates:

   ```json
   [{"shape":"rectangle","x0":180,"y0":40,"x1":203,"y1":63,"material":58}]
   ```

   Wait for completion, then make a second manual Metal mark elsewhere. Use the
   toolbar **Undo** three times: second mark, agent rectangle, first mark must
   disappear in that order, leaving the cleared baseline. **Redo** three times
   restores their chronology. Use the buttons so text-field focus cannot capture
   shortcuts. Wait for native completed/confirmed status after every manual
   gesture, Draw, Undo and Redo. Direct JSON needs no account or model credentials.

3. **Check cancellation and continued editing.** Draw
   `[{"shape":"rectangle","x0":0,"y0":0,"x1":1023,"y1":1023,"material":58}]`.
   Press **Stop** after progress shows changed cells and while work remains;
   wait for the current chunk's acknowledgment, then **Undo** its confirmed
   prefix. If it completes too quickly, undo and repeat with that rectangle
   duplicated in the same array. Leave the prefix undone for the Lab roundtrip.
   Live external models are optional; automated provider checks use local
   fixtures and do not imply a paid cloud inference session.

4. **Compare an isolated material edit.** Open **Materials Lab…**, search **sand**,
   and select **002 / sand**. Under **Inspect**, choose **Make editable copy**.
   Under **Edit copy**, set **Density (larger = heavier)** to **500** and **Base
   colour and transparency** to **#115bcbff** (RGBA 17, 91, 203, 255). In **Compare
   edits**, choose **Start above the other material**, Other material **003 water**,
   **Seed 2**, **Steps 120**, **Simulation threads 4**, then **Build + run comparison**.
   Confirm comparison complete, source unchanged PASS and both native check sets
   PASS; original Sand settles below Water while the blue edited candidate remains
   above. **Save World recipe…**, then **Import World recipe…**. Import restores the
   candidate and scenario and clears the old successful-test claim; run **Build +
   run comparison** again. Close Lab, confirm unchanged Workbench terrain, and
   **Redo/Undo** the retained cancelled prefix. Production Sand is unchanged.

5. **Check equipment and saved starts.** Enter **acceptance-generated** in the
   name field and use **Save start [Ctrl+S]** before changing Worlds. Click
   **Load liquid-lab** for the built-in reservoir, barrel, valve, drain and nozzle.
   Exercise **Valve 1 [V]**, **Drain [G]**, **Nozzle [H]** and **Play/Pause [P]**;
   pause and **Stop all**. Enter **acceptance-liquid** and **Save start [Ctrl+S]**.
   Exit completely, relaunch, enter **acceptance-liquid**, and click **Load start**; check authored
   geometry, actors, settings and closed devices, then continue painting and Undo.
   Enter **acceptance-generated** and **Load start** to open its regenerated
   verified preview; click **Install into workbench** to confirm installation.
   Confirm both saved Metal marks and the small Hard-wall rectangle remain while
   the undone long prefix stays absent. Keep built-in names intact.
   Saves preserve authored construction, not an evolved physics snapshot. Undo
   history is session-local; simulation and World replacement retire unsafe history.

## Qualification and limits

The current source campaign completed the original Materials Lab native and
graphical tests, all **37 Workbench stages**, and the new mounted Lab/Workbench
flows at **one and four workers** on both Linux and Windows. Each mounted author
and fresh-process reopen pair completed **102 and 37 assertions** respectively.
The catalogue inventory contains **231 tests**: Windows completed 228 with the
three registered POSIX-only fixture skips; separate actual Windows timeout,
cancellation and descendant-retirement controls passed. Shared manual/agent
Undo/Redo, generation, painting, equipment, simulation, isolated candidate
Worlds, cancellation and authored save/reopen were exercised together.

The standalone package passed its **four Lab, eleven delivered-combined and
twelve installed Workbench stages**, including fresh-process native readback,
continued editing, shared history and actual package-local compiler/module
loading. Independent readback verified all **21,421 payload file hashes**, the
**2,367-commit complete source history**, all **89 native and 841 build inputs**,
and equality with the original source and delivered-execution evidence. The
Windows source and delivered-execution artifacts are **14031179799** and
**14033834717** from the publisher run above. The saved agent Stop prefix is
intentionally timing-dependent; each actual authored prefix, saved setup and
freshly reopened native witness agreed exactly within its own process pair.

The final Godot campaign completed all **308 Linux cases across 23 shards** and
**287 Windows cases across 22 shards**, with all 45 imports and both source-owned
coverage reducers passing. Windows covers all 287 registered headless cases;
the 21 display-only cases ran on Linux. Dedicated Windows source, package and
Palette graphical campaigns provide their separately declared coverage. Each
platform retained 45 PLAY readbacks. The latest
Workbench liquid-edge fixture passed all 130 assertions on each OS, and the
graphical Art smoke passed its 38 checks. Independent review retained all 51
required original coverage/runtime artifacts, 1,345 files and 640 raw process logs.

The Native workflow completed all six families, its provider-policy control
and aggregate readback. All **192 core cases** passed in each of normal,
ASan/UBSan and TSan configurations: **576 core invocations**. It also completed
**154 physics-CLI invocations**, with zero reported failures or errors. The
source-owned independent reducer exactly matched the original aggregate across
eight original archives and 436 files; all recorded commands completed naturally
with exit code zero. The existing native sanitizer configuration uses
`ASAN_OPTIONS=detect_leaks=0:strict_string_checks=1` and halt-on-error UBSan;
LeakSanitizer coverage is not claimed.

The ordinary full Godot campaign separately rebuilt Windows DLL
`6aca0b9a0704adca1a5eb621db7d9ea7cdef0ad20ba7498adf7f8f925cb7a340`.
That full-file hash remains distinct from the delivered DLL in the table.
Independent PE comparison found exactly 13 differing bytes: six in the export
module's temporary output-name suffix and seven in its CodeView GUID. Every
other byte, including executable code, data, unwind tables and relocations,
agrees. This supports source-equivalent full Godot coverage; the dedicated
source and delivered package campaigns executed the actual delivered DLL.
No binary was modified to make the hashes match.

The Palette gate passed all **six cohorts and nineteen process cases**, including
exact sixteen-frame native full-atlas parity, actual GPU input controls,
per-backend base/blend/current/camera predicates at the existing **2/255**
tolerance, and actual cold/warm Main lifetimes and cache custody. Its deliberately
retained legacy cross-backend finished-image diagnostic still fails at **eleven
of 2,304 pixels in each midpoint/final frame**. Every diagnostic value is identical
to the accepted #563 [original reducer](https://github.com/techrote/cybersand/actions/runs/43342393818).
The contract and shader sources are unchanged from accepted main. The registered
[v3 acceptance contract](https://github.com/techrote/cybersand/blob/266d43a33e9eefc3e93a9dce1aaab6e5267492b8/docs/audits/2026-10-31-palette-shader-semantic-v3-registration.md)
keeps those historical diagnostic failures explicit; it introduces no tolerated
outlier count, pixel exclusions or changed threshold. This is not a claim of
identical finished pixels across different backends.

Earlier Windows failures remain in the
[integration audit](https://github.com/techrote/cybersand/blob/266d43a33e9eefc3e93a9dce1aaab6e5267492b8/docs/audits/2026-11-12-mat-auth-workbench-integration.md).
Same-host diagnostics established that the mounted combined capture at 5 FPS
starved native compiler work on the software renderer; that private combined
capture now uses 1 FPS. Application frame-rate defaults, native work and its
assertions remain unchanged.

The later request-4 failure occurred in the original Lab's initial Workbench
installation wait. Separate unchanged-source controls observed a 43–45 second
installation delay across two process frames, with most of that time in a cold
ANGLE frame and a palette shader cache appearing when it returned. Lowering this
Lab capture's frame rate did not shorten that stall. Request 5 aligned only the
initial Main acknowledgement with the existing 600-second cold-start policy;
request 6 retains that correction and the original Lab capture's 15 FPS. This
does not improve startup latency or establish ordinary-desktop performance.
Dedicated Lab graphical cases and the package’s four Lab smoke cases retain
their explicit 1200-second outer allowance; the source-derived generic headless UI allowance is 3940
seconds. Native compile/execute/service limits remain 180/60/300 seconds, and
the fixed tick counts and experiment windows remain unchanged.

The bundle preserves `source/LICENSE_STATUS.md`, `source/THIRD_PARTY_NOTICES.md`,
Godot notices and the bundled dependencies' own licenses. It does not introduce
a new license grant for CyberSand. Owner desktop acceptance and approval to merge
remain separate from this evaluation release. This publisher never merges main
or changes the feature branches.
