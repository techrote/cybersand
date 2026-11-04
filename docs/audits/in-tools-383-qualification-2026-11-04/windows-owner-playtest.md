# PR #383 — Windows owner playtest at frozen source

**All physical-input, rendered-window and owner-acceptance rows below are UNTESTED until the owner executes and records them.** This packet targets `73b10f9b800e72f358f22f470e57a4531002c168` / tree `31c5a9a4b986820985658d3ed2228ebe9008828a`. After integration reconciliation, regenerate the packet for the newly reviewed SHA and rerun the affected checks; never transplant the result.

## Preflight and launch

Use a new clean checkout, Git with Git LFS, Python, and the official Windows Godot 4.7 archive with both GUI and console executables extracted together. The full repository preflight also checks documentation links into the companion workspace. Mirror the existing `.github/workflows/documentation.yml` layout: clone **the same `techrote/cybersand` repository** at companion commit `6a58311982941b75f46e22109a0829e5acb83c7e` into the workspace root, and place the frozen implementation checkout in its `source` child. The companion commit ignores `/source/`; these are separate Git checkouts. A source-only clone without the pinned companion files can remain BLOCKED even when every runtime payload is present. The five companion input hashes used here are recorded in the adjacent `companion-inputs.json`.

For a new Windows workspace, the following setup preserves existing directories and stops on any failed Git command. It uses full history, canonical LF text and the existing LFS download/check commands. **These PowerShell setup instructions have been source-reviewed, not executed on Windows.** If you already have the exact clean nested layout, proceed to the packet command after verifying its two commits.

```powershell
$OwnerWorkspace = 'C:\src\cybersand-383-owner'
$OwnerSource = Join-Path $OwnerWorkspace 'source'
$OwnerRepository = 'https://github.com/techrote/cybersand.git'
$Companion = '6a58311982941b75f46e22109a0829e5acb83c7e'
$Expected = '73b10f9b800e72f358f22f470e57a4531002c168'
if (Test-Path -LiteralPath $OwnerWorkspace) { throw 'Choose a new workspace; preserve existing checkouts.' }
function Invoke-OwnerGit {
  param([string[]]$Arguments)
  & git @Arguments
  if ($LASTEXITCODE -ne 0) { throw "Git setup failed with exit $LASTEXITCODE; retain this attempt." }
}
Invoke-OwnerGit -Arguments @('clone', '--no-checkout', '--config', 'core.autocrlf=false', $OwnerRepository, $OwnerWorkspace)
Invoke-OwnerGit -Arguments @('-C', $OwnerWorkspace, 'fetch', 'origin', $Companion)
Invoke-OwnerGit -Arguments @('-C', $OwnerWorkspace, 'checkout', '--detach', $Companion)
Invoke-OwnerGit -Arguments @('clone', '--no-checkout', '--config', 'core.autocrlf=false', $OwnerRepository, $OwnerSource)
Invoke-OwnerGit -Arguments @('-C', $OwnerSource, 'fetch', 'origin', $Expected)
Invoke-OwnerGit -Arguments @('-C', $OwnerSource, 'lfs', 'install', '--local')
Invoke-OwnerGit -Arguments @('-C', $OwnerSource, 'checkout', '--detach', $Expected)
Invoke-OwnerGit -Arguments @('-C', $OwnerSource, 'lfs', 'pull')
Invoke-OwnerGit -Arguments @('-C', $OwnerSource, 'lfs', 'fsck')
```

Substitute only the local paths. All 18 required LFS payloads must be materialized. The existing packet generator verifies the exact head/tree, complete repository/runtime provenance and official engine archive; it refuses stale or missing dependencies. A blocked preflight remains BLOCKED, with its error retained.

```powershell
Set-Location 'C:\src\cybersand-383-owner\source'
$Expected = '73b10f9b800e72f358f22f470e57a4531002c168'
$Out = 'C:\CyberSand-evidence\PR383-owner-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
python tools/play/create_manual_packet.py --expected-sha $Expected `
  --godot 'C:\Godot47\Godot_v4.7-stable_win64.exe' `
  --godot-archive 'C:\Downloads\Godot_v4.7-stable_win64.exe.zip' `
  --output $Out
if ($LASTEXITCODE -ne 0) { throw 'Source/runtime preflight failed; retain the error and stop this attempt.' }
& (Join-Path $Out 'launch.ps1')
```

Do not change execution policy or weaken provenance to force the launch. The repository's launcher imports/runs the existing application and retains its console log. If new editor metadata makes a later preflight refuse a dirty checkout, retain the first attempt and prepare another fresh checkout at the same reviewed SHA. Do not erase the failed evidence or silently ignore generated source changes.

Expected Windows runtime identities at this SHA:

| Component | Identity |
|---|---|
| Godot version | `4.7.stable.official.5b4e0cb0f`; the generator authenticates both executable bytes against the pinned official archive |
| CyberSand DLL SHA-256 | `ee09f7ab485f817b5f58e767ddb26f2e430439bb3dd4f185019eda028f47199a` |
| CyberSand DLL size | 4,824,064 bytes |
| Native production source provenance | Build/source `a7ee10f251f647a16dec8a1d7f18c4f299100cba`; current 80 production inputs must still match |
| Rapier DLL SHA-256 | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |
| Rapier DLL size | 9,987,072 bytes |
| Rapier dependency | Godot addon v0.35.2 / rapier2d 0.35.1, recorded cooperative BVH backport |

The original runtime build's Windows execution is dependency provenance only; it does not qualify this PR's new GDScript.

## Enter the real PLAY/F5 route

Select **Play session — shared desktop course, five mechanical players and solver choices** in the launcher. Choose **Player Playground — authored course**, a physical player such as **Afterimage**, **Keyboard only** initially, **Free play — no lap timer**, and **Water: inertial**. Set rule radius **3** explicitly. Click **Build selected session**, wait for the applied owner/policy and terrain readiness, release held controls, and click **Play / resume**.

Open **F5**, choose **Liquid Drain**, select **Metered Water v1 — experimental**, set power **50%**, then **Equip only**. Release keys/buttons before rearming. The existing physical mount must be held; a loose/missing chassis is a refusal/precondition problem. The profile selector does not change solver policy. Do not use the separate Player playground scene, native-default-demo Liquids entry, #370 comparison host, or a new equipment framework.

Aim using the pointer and approach accessible Water without firing. Verify the actor/F5 status shows **Sink 0 Water units; allowance 8160** at the normal 8-bit Water setting, and hover for native generation, bit depth and policy. If the tooltip reports a different bit depth, use the displayed Q below and retain that fact. No synthetic screenshot or headless assertion can fill this observation.

## Physical checks and exact expectations

Capture a screen recording or timestamped screenshots plus the generated launch log. In a small result table record status, actual input device, source SHA, native generation/policy, sink before/after, allowance before/after, final UI outcome, observed recharge/cooldown behavior and evidence filenames. Do not mark a row PASS solely because the actor moved or the console exited zero.

| Row | Action | Required observation | Initial status |
|---|---|---|---|
| Mouse hold/release | Aim into unobstructed Water; hold left button for repeated pulses, then release. | Only verified accepted pulses advance Sink; allowance decreases by the same quantity. After an already committed pulse settles, release produces no new uncommitted pulse. Native liquid may continue transporting. | UNTESTED |
| Keyboard trigger | Repeat with M while keeping the pointer over the game view. | Same actual metered route and accounting as mouse; no burst after release. | UNTESTED |
| Precision | Release all inputs; right-click once on an accessible target. | One alternate pulse at 35% of selected power, still 0.85 accepted charge and 0.10 s cooldown. At 50% selected power, at most three full cells/765 Q255 units; smaller dose or explicit refusal is valid if reach/visibility admits fewer targets. | UNTESTED |
| Cooldown and recharge | Record visible charge immediately after a successful pulse, then release and wait; repeat a quick press during cooldown. | Each accepted activation costs 0.85 charge with 0.10 s cooldown; ordinary regeneration is 6 charge/s. No-effect/cooldown refusal adds no cost. The small 32-cell allowance alone does not establish empty-charge behavior; deterministic low/empty-charge tests remain separate. | UNTESTED |
| Empty/wrong material | Aim at Empty or a material other than the selected liquid. | No accepted effect/recoil, unchanged sink and allowance, explicit unavailable/refused/blocked outcome. Ordinary time may recharge charge or age an existing cooldown. | UNTESTED |
| Hard wall/body obstruction | Try an intake blocked by actual terrain or the actor/chassis. | No through-wall or masked-liquid removal; no sink/charge cost. Local `muzzle_blocked` may precede dispatch and therefore has no native receipt. Visual checks supplement, rather than replace, exact-coordinate automated controls. | UNTESTED |
| Focus loss | While M or mouse is held, switch to another window and return. | No new intake while unfocused; held input stays disarmed on return until released, then a fresh press can work. Record actual Windows focus behavior. | UNTESTED |
| Blocking F5 and pause | While held, open F5 and close it; separately press P to pause, then P to resume. | Pending intake is revoked. Sink freezes while paused; held input must be released before rearming. Panel operations themselves do not debit stock. | UNTESTED |
| Rapid press/release | Briefly tap and release between simulation updates. | No delayed phantom pulse after a retired intake. A pulse already committed before release remains a real accepted result. | UNTESTED |
| Deselection/reselection | Switch to another usable, then re-equip metered U10; switch Ordinary U10/metered profile off/on. | Same native generation retains its cumulative sink and allowance; selection does not refill the budget. | UNTESTED |
| Exhaustion | On a fresh Q255 IN World, remove eligible Water until allowance is zero. | Total metered sink reaches exactly 8160 and remains there; further requests refuse without phantom recoil or new debit. Fewer targets can require more pulses. | UNTESTED |
| Reset | Release inputs, use the ordinary R reset, wait for fresh applied owner, re-equip through F5. | A genuinely new native generation/World alone refreshes Sink 0 / allowance 8160; held/old commands must not revive. Record the generation change. | UNTESTED |
| Brine | Build the existing **Mixed Current Water + inertial Brine** preset with radius 3 and an actual physical owner. Equip **Metered Brine v1 — experimental**. | Stock starts at 32 Brine cells. Sink counts actual removed Brine cells, never Water units or Brine state_a; Water allowance remains independent. Missing reachable Brine is an unexecuted positive control, not a pass. | UNTESTED |
| Current/ordinary controls | Build Current FreeMass Water; exercise metered Water, then explicitly Ordinary U10. | Metered FreeMass uses actual fractional stored units. Ordinary U10 retains its existing removal and v1 behavior; it does not update the experimental sink. Do not infer its exact quantity from changed cell count. | UNTESTED |
| Controller and pacing | Select **Keyboard + standard gamepad**, move the player with the controller while using mouse/M equipment; unplug/reconnect and repeat neutral rearm. Record FPS/stalls and visible stock responsiveness. | Movement/control identity follows the existing selected controller; no stale held command after unplug/focus/reset. This source has no separate gamepad equipment-trigger mapping. Rendered pacing observations remain device/host-specific. | UNTESTED |

The exact permission identity is always `cumulative metered sink + remaining allowance = 32Q` Water units or `32` Brine cells within one actor slot/native generation. Here `Q = 2^mass_bits - 1`: Q7 gives 224 initial Water units; Q255 gives 8160. At 50% power, an accepted full IN Water pulse removes up to eight whole cells: 56 units at Q7 or 2040 at Q255. At 100%, the bound is sixteen cells: 112 or 4080. Do not require the maximum if the intake sees fewer eligible targets. On no-effect refusal, the sink increment is exactly zero. The precision control shortens reach as well as lowering target count.

The normal UI exposes sink/allowance, not a full authoritative whole-World source census. Therefore these human rows alone cannot claim `initial source - sink = final source` for the whole rendered world. That equation is independently measured by the native-backed controlled fixture below. Do not substitute visible/dithered Water pixels, or the 2112-cell automated tank's initial quantity, for the authored PLAY course's inventory. If actual physical-input whole-World closure is required, it remains a separately recorded observation gate until an owner-safe census is captured; do not read or mutate a running worker's World from the main thread.

## Separate Windows automated control

Run this in another exact-source clean checkout, retaining the result and logs separately from physical input. The normal Windows full regression route includes all three metered scripts and authenticates the retained DLL and official engine archive:

```powershell
python tools/ci/run_windows_godot_regressions.py `
  --godot-archive 'C:\Downloads\Godot_v4.7-stable_win64.exe.zip' `
  --expected-source-sha '73b10f9b800e72f358f22f470e57a4531002c168' `
  --output 'C:\CyberSand-evidence\PR383-Windows-full-NEW'
if ($LASTEXITCODE -ne 0) { throw 'Windows regression failed or incomplete; retain all output.' }
```

Coordinate this full run with the integration owner; do not dispatch competing hosted matrices. This local command does not mark the PR ready. The independently scoped standalone native run requires a compatible installed C++20 compiler; it is not covered merely by a generic Native check:

```powershell
python tools/lcb/run_metered_drain_native.py --cxx 'g++' `
  --output-dir 'C:\CyberSand-evidence\PR383-Windows-native-NEW'
if ($LASTEXITCODE -ne 0) { throw 'Windows native qualification failed or incomplete; retain all output.' }
python -m unittest discover -s tools/lcb -p test_metered_drain_native.py -v
if ($LASTEXITCODE -ne 0) { throw 'Parser/custody regression failed.' }
```

The `NEW` output directories must not already exist. Compiler absence is BLOCKED; Linux or cross-compiled executable creation is not Windows execution. The runtime suite's controlled 312-cell full Water inventory starts at 2184 units/Q7 or 79560/Q255; a 16-cell full pulse removes 112/4080. Fractional FreeMass Q255 begins at 19656 and removes 1008 (16 × 63); Brine begins at 312 and removes 16 cells. Main's separate controlled 2112-cell tank starts at 538560 Water units or 2112 Brine cells. IN two eight-cell pulses give sink4080 / final534480, and one fresh reset pulse gives sink2040 / final536520. Native transport, body/wall controls and every recorded tick remain part of the executable assertions. FreeMass and ordinary Main totals vary with asynchronous source state; use each new packet's actual observations rather than historical 1561/1572 values.

Keep genuine failed runs, incomplete packets, runtime errors, skipped controls and source mismatches. Report headless execution, rendered manual operation and physical devices in separate rows. This procedure authorizes no ready-state transition, merge, issue closure, valve/nozzle implementation or overwrite of another workstream.
