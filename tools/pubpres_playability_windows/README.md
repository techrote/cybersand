# PUBPRES-PLAYABILITY-001 Windows evaluator

**Draft/HOLD.** This is a newly assembled source-matched evaluator. It contains
accepted `main` (M), the qualified PUBPRES integration reference (I), and this
experimental candidate (C), with a separately built native DLL for each exact
source. A hosted Windows software-renderer result does not establish physical
Windows/NVIDIA acceptance or a playable-progression improvement.

The package has no installer and does not use your ordinary CyberSand profile.
Keep the verified `Payload` directory pristine. The launcher makes a fresh
source copy and isolated profile under its sibling `Runs` directory. Only a
run's profile holds that run's authoring and save data. Retain it when testing
close/reopen.

## Exact artifact and verification

Use the full candidate Git SHA printed in the frozen owner handoff. Replace
`FULL_40_CHARACTER_CANDIDATE_SHA` below; do not substitute a branch name.

The inner package name is exactly:

```text
CyberSand-PUBPRES-PLAYABILITY-001-<first 12 candidate SHA characters>-Windows.zip
CyberSand-PUBPRES-PLAYABILITY-001-<first 12 candidate SHA characters>-Windows.zip.sha256
```

GitHub may wrap those two files inside an outer artifact ZIP with a different
name. The standalone launcher accepts either the outer artifact ZIP or the
exact inner ZIP. For an outer artifact it locates exactly one correctly named
inner package and its adjacent checksum, verifies them, then extracts into a
**new** destination. It refuses an old folder, an ambiguous nested package, a
renamed historical evaluator, unsafe ZIP paths and mismatched checksums.

Download `Start-PUBPRES-Playability.ps1` from the same frozen artifact, then run
Windows PowerShell 5.1 or newer:

```powershell
$sha = 'FULL_40_CHARACTER_CANDIDATE_SHA'
& .\Start-PUBPRES-Playability.ps1 `
  -ArtifactZip .\downloaded-github-artifact.zip `
  -Destination C:\CyberSand\PUBPRES-New-Evaluation `
  -ExpectedCandidate $sha -Action Verify
```

If the handoff supplies an independently recorded archive digest, add
`-ExpectedArchiveSha256 '<64 lowercase hex characters>'`. For a direct inner
ZIP, place its `.zip.sha256` sidecar beside it, or provide `-ChecksumFile`.

Verification checks every manifest-listed file and rejects extra files in
the payload. It checks each source's native compiled input set, build script,
build log, new build driver, source/tree identity, runtime bytes, shared
toolchain, retained Rapier source/binary provenance, Godot executable identities,
VC runtime/license receipt and registered observation overlay. The original
production-native receipt is preserved as explicitly historical data; it never
authenticates a newly built DLL. The new diagnostic native receipt says HOLD.

## Open the ordinary Workbench

```powershell
$payload = 'C:\CyberSand\PUBPRES-New-Evaluation\Payload'
$launcher = Join-Path $payload 'tools\pubpres_playability_windows\Start-PUBPRES-Playability.ps1'
& $launcher -PackageRoot $payload -ExpectedCandidate $sha `
  -Action Open -Source Candidate -StagingPools Eager -RenderThread Safe
```

The launcher opens the actual source Main scene and observes installed-World
readiness. It does not replace native simulation, physical callbacks, actor
commands, publication or camera code. The startup observer disconnects once
it records readiness. The launcher samples the actual GUI process's memory at
250 ms intervals with a finite record limit; that observation is not a gameplay
timing acceptance test.

| Selector | Meaning | Default |
|---|---|---|
| `-Source Main` | Accepted-main source, its own native runtime and ordinary source policies | — |
| `-Source Integration` | Historical PUBPRES source with its registered blit/early/coherent/repaired policies | — |
| `-Source Candidate` | Current candidate with those same integration policies | Candidate |
| `-StagingPools Eager` | Existing eager staging-pool allocation | Eager |
| `-StagingPools Reachable` | Candidate only: omit provably unreachable atlas allocations at setup | Off |
| `-RenderThread Safe` | Existing Godot safe/inline rendering mode | Safe |
| `-RenderThread Separate` | Existing Godot separate rendering owner; experimental comparison | Off |
| `-SameFrameContinuation On` | Candidate/Safe only: one nonblocking continuation of a withheld real callback in its original process frame | Off |
| `-RenderingDriver opengl3` | Native Windows desktop OpenGL; use for owner NVIDIA comparison | opengl3 |
| `-RenderingDriver opengl3_angle` | ANGLE, available for hosted Windows qualification | — |

Reachable pools preserve logical texture identities, staging slot selection and
material histories. They save allocation on some padded/rectangular extents.
**They save no allocation on the original 2048×2048 or 2048×1024 workloads.**
That memory repair is not evidence of playable-progression recovery. Safe and
Separate comparisons must use identical workloads and source/runtime identities.

Development-01 at a707 has retained queued-pixel failures and Separate-renderer
crashes. Windows Separate/ANGLE fails during GLAD initialization before app
startup; Linux full-Workbench Separate fails in the pinned engine's Image upload
path. Safe reachable R8/two-slot queued history also has one current-plane
mismatch. These options remain unqualified. A successful ordinary Safe startup
does not resolve a failed history oracle or qualify Separate. Use the current
frozen handoff for the status of later repairs and their exact-source evidence.

The new manifest, owner-run and startup-receipt formats are explicitly v2;
the measured gameplay corpus is explicitly v3. Use each historical evaluator's
original launcher. This launcher refuses an old manifest instead of giving it
new selector meanings. To compare the continuation alone, open two new Candidate
runs with identical fixture, Water law, workers, camera, Eager pools and Safe
rendering, selecting `-SameFrameContinuation Off` and `On` respectively. The
launcher records the actual Main status, including its one-attempt, one-read,
zero-wait bounds. `-ReopenRun` retains the recorded policy; an explicit conflicting
selector is refused. Startup readback proves configuration, not physical gains.

For example, add `-SameFrameContinuation On` to the Candidate Open command above.
Keep ordinary runs OFF unless deliberately evaluating the experiment. The
package qualification exercises graphical Save and fresh-process native-material
reconstruction separately with OFF and ON; hosted results remain distinct from
the owner's physical Windows/NVIDIA exercise.

The rejected four-column Wave experiment is absent from this candidate. There
is no Wave-columns-On selector. An inherited request to enable it is refused.
The optional Wave stage probe remains off for ordinary owner sessions; the
registered measurement harness may enable it without changing the simulation
law. Candidate probe evidence must report one column slot and no experimental
column tiling. Missing probe fields in M/I are unavailable data.

## Save and reopen the same isolated session

The launcher prints a run path such as
`C:\CyberSand\PUBPRES-New-Evaluation\Runs\<timestamp-id>` before opening.
Use the ordinary Workbench controls for Apply, Undo, regenerate, Apply and Save
start. Close the Godot process normally, then reopen the **same run**:

```powershell
& $launcher -PackageRoot $payload -ExpectedCandidate $sha -Action Open `
  -ReopenRun 'C:\CyberSand\PUBPRES-New-Evaluation\Runs\<timestamp-id>'
```

Reopening verifies the run's application/native/World source against the
pristine package, not against a mutable self-reported file list. Explicit
selectors must agree with the original run. It preserves that run's profile;
it does not copy an unrelated ordinary profile. Package or source corruption
fails before launch. Godot-generated import cache and script UID companions
are not a source of native authority. Committed `.import` descriptors remain
fully hashed source-derived metadata. The exporter selects canonical LF for
unspecified text endings even for historical M/I sources, while explicit Git
attributes still apply. Candidate checkouts also pin `*.import` to LF. This
prevents a legitimate Godot import from rewriting Windows CRLF descriptors;
reopening still rejects any descriptor edit or forged run-local hash. The
pristine payload is never rewritten to accept an imported run.

Retain `run.json`, each `launches` directory, `ready-*.json`, process logs and
the profile containing the saved state. A readiness receipt binds the observed
PID, executable, source scripts, native/Rapier DLLs, requested render owner and
effective staging policy. It only proves successful installed-World startup.
It does not claim GPU scanout timing, loaded-module attestation or saved native
material-plane equivalence.

## Registered measurements

Ordinary launch/verification needs no Python or Git. The more detailed matched
campaign uses Python 3.11 or newer and the packaged v2 apparatus, which retains
raw failures and timing receipts. Use a new output directory outside `Payload`:

```powershell
python "$payload\tools\pubpres_playability\run_campaign.py" `
  --archive-manifest "$payload\PUBPRES-PLAYABILITY-MANIFEST.json" `
  --expected-candidate $sha `
  --main "$payload\sources\M" `
  --integration "$payload\sources\I" `
  --candidate "$payload\sources\C" `
  --engine "$payload\Godot_v4.7-stable_win64.exe" `
  --campaign "$payload\tools\pubpres_playability\campaign.json" `
  --output C:\CyberSand\PUBPRES-Measurements-Safe `
  --render-thread safe --driver opengl3
```

Check the packaged runner's `--help` for registered case/filter switches; use
the frozen case IDs and selectors in the owner handoff. Repeat the matched
campaign with `--render-thread separate` and a new output directory. Do not
edit `campaign.json` in the pristine package to obtain a preferred outcome.
The archived-source mode uses the verified exact package manifest; it never
invents a Git HEAD for an exported project.

The historical Wave comparison explicitly uses its registered one-round law,
without spill or ballistic transport. Current owner Wave defaults are a
separate workload. The old integration cannot execute all current owner-default
native features; its explicit capability failure is retained rather than
silently substituted. Keep small/large canvases, Free/Follow camera, other
Water families, negative cases, timeout/cancel cases and source-order controls.
GPU API time alone is insufficient. Use completed physical steps, frame gaps,
snapshot/publication age, render freshness and process memory together.

## Owner decision record

Record the actual Windows build, NVIDIA GPU and driver, display refresh rate,
window dimensions, source SHA, pool/render selectors and workload for each run.
Retain before/after screenshots made by the actual native renderer. Exercise
movement/contact, native workers, stationary and moving camera, pause/resume,
painting, authoring, Apply/Undo, Save start, close/reopen and the actual native
material-plane comparison. Retain failed child, cancellation/timeout, stale
folder, changed source and corrupted evidence results.

The package's startup observer is deliberately narrower than these exercises.
The owner's physical NVIDIA result and application transactions remain HOLD
until their actual evidence is recorded and reviewed. Do not promote a default
or mark a PR Ready based on successful ZIP verification or hosted WARP runs.

## Build and package qualification

The scoped Windows workflow builds M, I and C independently with
`tools/pubpres_playability_build/build_runtime.py`. Assemble only after freezing
the candidate source and observation policy:

```text
python tools/pubpres_playability_windows/package_windows.py
  --candidate-root <C checkout> --candidate-sha <C full SHA>
  --main-root <M checkout> --main-sha <M full SHA>
  --integration-root <I checkout> --integration-sha <I full SHA>
  --candidate-runtime <C new build dir>
  --main-runtime <M new build dir> --integration-runtime <I new build dir>
  --godot-zip <official Godot4.7 Windows ZIP>
  --vc-runtime <verified VC stage> --notices <official notices>
  --output-dir <new payload directory>
  --archive <exact source-bound evaluator ZIP filename>
```

The builder must run on actual Windows, using the pinned Godot4.7 binaries and
source-matched native receipts. Pure metadata unit tests are available on any
platform; they use synthetic PE headers and are explicitly not Windows/runtime
qualification. Run `Test-Package.ps1` on the actual new pristine Windows payload
to retain negative verification and process-failure evidence. Actual graphical
Safe/Separate material tests and pristine-package startup must also run there.
Local headless parsing alone cannot qualify graphics.
