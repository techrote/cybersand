# CyberSand PUBPRES final Windows evaluator

**Draft / HOLD.** Extract the whole ZIP into a fresh writable folder, then
double-click **Open Workbench.cmd**. No installed Git, Python or Godot is needed.
The launcher verifies the exact package, independently built native DLL, Rapier,
Godot 4.7 and source files before opening the ordinary Workbench. Keep its console
available. A second process cannot use the same profile.

The default is candidate C, official Godot 4.7, Safe rendering, Full publication
with two ImageTextures, and same-frame continuation Off. No production defaults
or installed application are changed. Physical NVIDIA acceptance remains yours.

## Representative starts

The supplied commands open separate persistent profiles:

| Command | Authored start |
| --- | --- |
| Open Workbench.cmd | Ordinary Workbench and its normal authoring controls. |
| Open Wave 512.cmd | 512 square, Water basin, Needle flyer, Follow selected. |
| Open Wave 1024.cmd | 1024 square, Water basin, two flyers and two barrels. |
| Open Wave 2048.cmd | 2048 square, Water basin and flyer. |
| Open Mixed 2048.cmd | 2048 square, Water, Sand, four actors and obstacles. |

Representative scenes use the ordinary native Apply transaction and the current
gameplay Water options. They start paused so you can inspect the scene. Press
**Play / Pause [P]**, select the actor to pilot, and use the ordinary controls.
The startup receipt records the actual installed scene, native Wave readback,
material publisher, engine, source and graphics owner. The mixed start also
checks a Sand cell in the already uploaded native material image. It does not claim a
completed gameplay test.

**Save start [Ctrl+S]** stores authored material and actor setup. Close and reopen
the same command, then use **Load start** to restore it. This is an authored
start, not a checkpoint of evolved Water, actor velocity or the current live
simulation. Each source/engine/slot/scene combination keeps its own profile in
the sibling `Runs` directory. Package files remain immutable; modified source
or changed selectors refuse reopening rather than silently switching a run.

## Explicit engineering controls

Use PowerShell from the extracted folder. Replace `FULL_CANDIDATE_SHA` with the
40-character identity printed by the launcher or recorded in the manifest.

```powershell
# Retained adverse control only: three slots regressed hosted Windows playability.
# Separate profile; ordinary evaluation keeps the default two slots.
.\tools\pubpres_final_windows\Start-PUBPRES-Final.ps1 -PackageRoot . `
  -ExpectedCandidate FULL_CANDIDATE_SHA -Action Open -OwnerProfile `
  -FullImageSlots 3 -Scene wave512

# Historical EGL engine control, only if separately included and qualified.
# The standard evaluator omits this engine after ordinary Separate startup failed.
.\tools\pubpres_final_windows\Start-PUBPRES-Final.ps1 -PackageRoot . `
  -ExpectedCandidate FULL_CANDIDATE_SHA -Action Open -OwnerProfile `
  -Engine Egl -RenderThread Separate -RenderingDriver opengl3_angle -Scene wave512

# Optional frozen c90 predecessor, if its independently built runtime is included.
.\tools\pubpres_final_windows\Start-PUBPRES-Final.ps1 -PackageRoot . `
  -ExpectedCandidate FULL_CANDIDATE_SHA -Action Open -OwnerProfile -Source Donor
```

**Three slots are a retained negative control, not a recommended playability
treatment.** In the matched Windows two/three/three/two Wave512 cohort, completed
physics rates were 13.602/9.080/9.065/13.765 steps per second and maximum gaps
were 248.089/700.931/709.374/248.607 ms. The Wave2048 cohort was also adverse.
The exact current/previous image checks passed, so coherent image ownership
alone did not establish responsive progression. These results are retained in
[campaign 45436083078](https://github.com/techrote/cybersand/actions/runs/45436083078).
The ordinary evaluator continues to use Full two slots.

The historical recovered engine contains the source-exact EGL context-handoff
repair from #609, with a separate version and executable hash. The second
campaign reached ordinary Main and then failed Separate startup with the font
Image/CowData diagnostic. The standard evaluator therefore includes the official
engine only. Source-bound research on a separately identified font repair is
outside this evaluator; it cannot inherit qualification from the old engine.
Separate still synchronizes with Main each iteration. Hosted ANGLE results do
not establish physical NVIDIA performance or display scanout behavior.

## Evidence and practical acceptance

Use **Engine Lab → Measure while I fly** and **Trace poses: manual** only when
you want instrumentation. Ordinary play has no added continuous script observer
after startup. The launcher retains bounded process CPU/memory observations,
logs and exact startup receipts. FPS and fast upload calls are not physical-step
witnesses. Follow the concrete checks in `ACCEPTANCE.md` and record freezes even
when a displayed counter looks healthy.

Put your notes in `Runs/OWNER-ACCEPTANCE.md` and screenshots in `Runs/Screenshots`.
Close Workbench and double-click **Collect Results.cmd**. The new timestamped ZIP
and SHA-256 sidecar appear in `Runs/Reports`. Its index lists every captured file,
source/profile identity and explicit omissions. The collector bounds each file,
total bytes, file count and traversal; active/changing files are omitted with a
reason. It leaves original saves, profiles and package files intact.

## Reproducible assembly and qualification

Run on Windows with the exact candidate checkout and its freshly built Windows
native receipt directory. The official engine ZIP, signed VC stage and notices
use the same existing dependency pins as the predecessor evaluator.

```powershell
python tools/pubpres_final_windows/package_windows.py `
  --candidate-root . --candidate-sha $Sha --candidate-runtime $CandidateRuntime `
  --godot-zip $GodotZip --vc-runtime $VcStage --notices $GodotNotices `
  --output-dir $Payload --archive $Archive
# Optional: --donor-root $FrozenC90 --donor-runtime $DonorRuntime
# Historical research only: --patched-engine-archive $Original609EngineArtifact
# Including it keeps every mandatory engine startup test; the known failure
# is not waived. The qualified ordinary evaluator inventory omits this option.

powershell -NoProfile -ExecutionPolicy Bypass -File tools/pubpres_final_windows/Test-Evaluator.ps1 `
  -PackageRoot $Payload -ExpectedCandidate $Sha -ArtifactZip $Archive -Output $Evidence

python tools/pubpres_final_windows/qualify_installed.py `
  --package $Evidence/extracted --candidate $Sha --output $AuthoringEvidence

python tools/pubpres_final_windows/package_windows.py --verify `
  --candidate-sha $Sha --output-dir $Payload
```

The extracted-package suite invokes the shipped CMD, verifies reopen and every
representative scene, exercises available explicit controls, tests source/binary
refusal and the unchanged Windows Job owner, and checks the shipped collector's
archive against its index. The separate authoring suite performs actual native
painting/generation, Save and a fresh-process graphical reopen with complete
material digest comparison. Successful packaging and tests leave all acceptance
and promotion states at HOLD.
