---
title: Workbench solver changes at canvas edges and desktop physics throughput
status: Current
document-kind: audit
scope: Draft 394 edge inventory transfer, graphical host pacing, native parity and platform evidence
canonical-for: [workbench-edge-and-pacing-evidence]
last-reviewed: 2026-11-04
related-documents: [../systems/player-control-playground.md, ../architecture/simulation-tick-and-threading.md, 2026-11-04-workbench-live-editing.md]
---

# Workbench solver changes at canvas edges and desktop physics throughput

On 4 November 2026, a normal Water solver edit on the previous owner package reproduced the reported “Retained material inventory extends outside the starting-setup canvas” refusal. The finite starting recipe had been compared with the entire native inventory after live transport. Painting wholly inside the canvas and letting the material move was sufficient. The original refusals were preserved for a 512-cell left edge and the normal 2048-cell bottom edge.

## Implementation and identity

This is a follow-up to the [pilot, reset and live-editing build](2026-11-04-workbench-live-editing.md) on Draft #394. Intake was `4ed46ff2aedd9f50a3819259bebb16a92baa2c91`. Both x86-64 libraries were rebuilt from native source `1ca90de5181953f9ebd95ef19c920d8dee7e17e2`, tree `f63396f72d857388f69fd96c12d732ae15e2a74f`. The Windows SHA-256 is `ba06c7d4243589ab76aca99549a22fb626067a1bf3631c5f8c2c94d57ade4b21`. The Linux SHA-256 is `5d6db4d393f42a1bcfd9e9351f20a6fd0967b5e9d57e8ca570c94d55ee22bce2`. Both 83-file source manifests match the native commit. Toolchains, build scripts, Godot 4.7, godot-cpp 101ae380 and Rapier 0.35.2 pins are recorded in the desktop runtime manifests.

A retained edit now copies evolved cells, even beyond the editable canvas, into the replacement owner's reserved chunks. Water uses the same target rounding rule inside and outside the canvas. The conversion receipt identifies per-material retained and clipped cell counts, quantities, overfill, trapped gas, motion and exterior temperature loss. A compartment keeps its gas when at least one label survives. A live solver edit no longer recompiles the starting paint history. File limits still apply when a starting setup is saved or restored. Genuine construction or runtime failure stays observable.

## Desktop pacing

In the previous host, the main thread tested a native completion acknowledgement last copied by the renderer. With three bodies and 16 radius-20 Sand/Dust stamps, 150 of 300 physics callbacks skipped a step even though the worker had already finished. The workbench now uses one immutable worker publication for both the acknowledgement and the corresponding body result. The main-thread Rapier, epoch, sample and exactly-once result checks remain in force. While rendering is held, the physics owner also waits for the current native hard-surface revision and completes its bounded collider installation before stepping. Tests paint and erase terrain and check the actual Rapier shape count at the first subsequent step.

Windows graphical control on a Ryzen 5 5600X (6 cores, 12 logical CPUs), 60-Hz physics, VSync, 1280 × 720, 2048 × 2048 workbench, one Scooper, one Needle and one passive barrel. Five-second intervals count completed native ticks. Whole-machine CPU is process kernel plus user time divided by elapsed time and logical CPU count. The density, spatial distribution, renderer and sampling interval matter.

| Scene | Before, native ticks/s | After the ACK change, native ticks/s | Whole-machine CPU before → after |
|---|---:|---:|---:|
| Bodies only | 29.2 | 59.2 | 2.41% → 2.39% |
| Bodies and 16 distributed powder stamps | 30.0 | 57.8 | 3.57% → 6.77% |
| Bodies and 96 contiguous powder stamps | — | 45.8 | 11.65% after |

The 96-stamp run rendered 59.94 frames/s and recorded a mean native tick of 5.20 ms. On the 16-stamp run six workers claimed phase jobs. These observations were made on the intake native library to isolate the host change. The final packaged-code graphical rerun with 16 stamps completed 296 native ticks and 295 Rapier steps over 300 physics callbacks in 5.003 seconds, at 59.96 rendered frames/s. The native tick test and the OS meter measure different quantities.

## Native parallelism

The [fixed-work probe](workbench-391/pool_throughput.gd) drives the real native adapter with the workbench policy and 2048² candidate while removing renderer and Rapier pacing. Twelve 14 × 144 columns contain the same Sand/Dust or Water under both worker requests. For powder, warm up 10 ticks and time 180. For Water, warm up 2 and time 12. Run fresh Godot processes with `--headless --path godot --script <absolute-path-to-pool_throughput.gd>`. Set `WORKBENCH_POOL_REQUEST=1` for one worker or `0` for Auto. For the Water variant set `WORKBENCH_POOL_WATER` to `freemass_v1` or `pressure_flow_v1`. Both use the reference variant. Quantities, moves, visits and the terminal physical hash serve as controls.

On the intake Windows binary the two powder one-worker runs took 618–634 ms. The two Auto runs with six workers took 282–328 ms, using 19.4–19.8% whole-machine CPU. All four produced 4,301,262 moves, 4,160 jobs, 4,354,560 visits and the same hash `3b44afcc200f59a9`. FreeMass took 72.5 ms with one worker and 29.6 ms with six, hash `0c522c337d362048`. PressureFlow reference took 689/694 ms (one/six) and 712/657 ms on repeat. In the latter run the six-worker process spent 439 ms preparing heads and 187 ms on gas.

The workbench now dispatches complete independent vertical pressure columns to its existing pool. All workers join before the serial row repair and ordered wake pass. Ordinary hosts retain their existing execution policy. The native parity fixture ran four worlds (one/six workers, dispatch off/on) through 42 ticks including separated chunks, lidded Water, moving masks and sealed gas, with identical per-cell heads, quantities, wakes, CYPS2 state and physical hashes. It exercised 10,902 unknown-head repairs and 13 pressure wakes.



| Same fixed work on the rebuilt Windows DLL | One worker | Auto (six workers) | Terminal physical hash |
|---|---:|---:|---|
| Sand/Dust, 180 ticks | 626–643 ms | 274–336 ms | `3b44afcc200f59a9` |
| Water FreeMass, 12 ticks | 80.0 ms | 27.4 ms | `0c522c337d362048` |
| Water PressureFlow reference, 12 ticks | 697.8 ms | 494.7 ms | `2648cfa1886c3b31` |

On the rebuilt DLL the six-worker powder process used 17.6–22.8% of whole-machine CPU. On the pressure run six workers used 15.3%. The head pass fell from 451.8 to 279.7 ms (one versus six). Gas still took 175–179 ms in either case. All configurations produced the same 286,594 pressure moves and 216 phased material jobs. The phase participation readout covers the cell-update phases. It does not instrument the separate pressure column pass.

## Qualification

The actual Godot UI test paints wholly within the canvas, plays for at least 22 native ticks, pauses, opens Details, chooses the solver and clicks Apply. It inspects the policy and receipt returned by the owner. Both desktop runtimes retained 88,740 Water units on the 512 left edge, including 5,291 beyond the visible edge, and 112,455 on the 2048 bottom edge. Both also retained and identified bottom-edge Dust. Changing the pilot afterward preserved the same pressure policy and exterior inventory. After an actual pressure tick, the same controls switched back to FreeMass. On the 512 edge, Windows retained all 21 exterior Water cells and 5,291 visible exterior units. Total Water changed from 88,740 to 88,623, exactly matching 117 discarded pressure overfill units. Linux discarded 120 overfill units and retained the same exterior Water. Both kept all 112,455 Water units and the exterior Dust at the 2048 edge. The graphical Windows test passed 74/74 and Linux headless 70/70. A second failure found during this run was a stale preset label after **New canvas**. The picker now selects the actual staged policy after replacement, including custom policy envelopes.

The pressure setup capacity test still identifies a genuine 1,025th enclosed pocket in the native halo. An isolated source-only chunk beyond the receiver's reservation tests explicit clipping of Brine, Water, inertial state, temperature and pressure/gas sidecars. The actual edge reproductions used ordinary receiving reservations and reported zero clipped Water.

Linux native core 165/165, pressure-capacity 52/52 and selective arrival 196/196 passed. The focused boundary/quantity/IN cases passed both normally and under ASan/UBSan. GCC 13 ThreadSanitizer passed the same pressure-head parity fixture (827,303 checks). The first sanitizer process ended at startup without a test result. The retry ran under `setarch x86_64 -R` on WSL with `TSAN_OPTIONS=halt_on_error=1:verbosity=1`. Normal and sanitized execution used bounded timeouts (180 s for the parity test, 900 s for the full core). Raw local logs are under `build/wb`. The full core log is `build/wb/edge-native/core-checked.log`, raw-byte SHA-256 `f7c8e941a5715c36310973c63f7699e3476ce7174716ec409a484704e4e49d7f`. The original citation omitted the filename; recursive cleanup verification found the matching nested log and confirmed 165/165. The [cleanup record](2026-11-04-workbench394-cleanup.md) supplies a fresh, separately identified core run.

Godot 4.7 Windows and WSL Linux both passed the desktop interest and held-render, pilot controls, live liquid conversion, retained pressure, failed-owner recovery, liquid physical transaction, canvas, physics play, async physics/interaction ownership, REM-002, REM-003, hard placement, fleet session and input fixtures. Run a fixture using `--headless --path godot --max-fps 120 --script res://tests/test_<name>.gd` with a 180 s bound. The independent cleanup review reproduced the fleet test's 70 assertions with exit 0 followed by an ObjectDB/resource teardown error; that historical fleet execution is not a clean diagnostic-gate pass. Its fix and fresh results are in the [cleanup record](2026-11-04-workbench394-cleanup.md). Windows also exercised the controls graphically on a TITAN RTX. Run the [graphical pacing probe](workbench-391/desktop_pacing.gd) without `--headless`, with `--resolution 1280x720 --max-fps 120`, and `WORKBENCH_PACE_STAMPS=0`, `16` or `96`.

The unchanged MAT protected-source checker still reports a transition on `native/src/world.cpp` (canonical LF SHA-256 `a47955f79ed5fbc8bc0ca8e2892ed4eb0ddbd728b841bc08ccee14a4c239e4a7`). The current LF digests of the other previously reported protected inputs are world_pressure.inc `a1dd5c486dad16f114cce3b38d292407edb91e5bbaf03d0193dcc4ecd7338e62`, world_inertial.inc `8a5d3680e96ca47a3f496be5a8b953084d2c6d2e0bd723c3214b87bdbc3580b5`. Existing historical locks are preserved. Documentation, repository/materialized runtime identity, M11 integrity and whitespace gates pass. The frozen retrieval set retrieves 32/32 canonical owners in its top five, PLAY retrieves 11/11 and the challenge set retrieves 156/157, with the existing LCB03 miss. General timing on other machines, Web performance, human play acceptance and MAT promotion remain open.

## Owner review package

The package uses source `7cd89575249d79704b5c070f9e5644c5795c704b`, tree `4ac9e97e9923a70574cd91c40299748745e30af2`, with the application host frozen at `055925f1ec6e7fc7c777d3ed7dfdbdd9e8039459`. The Windows Godot executable SHA-256 is `b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8`. The full materialized LFS identities are in the generated review manifest (SHA-256 `c4c233429da78bab5d517f5294f507b543f8baf651e1bd77b9f3ba82f6695ebf`). The package’s own engine passed the graphical edge test (70 checks without the four optional screen-capture assertions), the held-render physics and terrain regression, and the pilot/reset test (45 checks). The independent reviewer gave **GO for owner review** at this package source after examining the pressure parity, both edge directions, sidecar-only loss reporting, changed-terrain fences and graphical throughput.

The Windows entry is `build/Open Workbench.cmd` in the workbench-retry worktree, pointing to `build/workbench-owner-review-7cd89575/Open Workbench.cmd`. Source restart is `Godot.exe --path godot -- --workbench`. A running process must be restarted to load the rebuilt library and host.
