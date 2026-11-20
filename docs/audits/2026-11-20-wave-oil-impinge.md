---
title: Water waves under a floating Oil slick
status: Current
document-kind: audit
scope: Saved impingement tank, Wave Water and Oil motion, conservation and Windows evaluation
last-reviewed: 2026-11-20
related-documents: [../architecture/wave-flow-v1.md, ../operations/workbench-water-lab.md, 2026-11-19-wave-oil-lava.md]
---

# Water waves under a floating Oil slick

The owner supplied a 2048² Workbench start in which falling Water and Oil collect between a wall and a shelf. On the published #679 build at `04a2c36b8`, all 111 Water–Oil contact heights in the measured basin section (columns 56 through 166) were identical at ticks 600, 900, 1,200 and 1,500. The highest and lowest contacts differed by 11 cells. The solver could store excess Water beneath the Oil while the displayed boundary stayed fixed. [Original saved start](wave-oil-impinge-2026-11-20/setup-oil-impinge.json) · [Wave law](../architecture/wave-flow-v1.md#oil-floating-on-wave-water)

## Same saved tank, before and after

The Workbench loaded the unmodified saved start (SHA-256 `1fef170c458ea3928706a05d67295ff1da7ecf5923b498b990bde32b9b6b4ed2`) into a separate user directory. Both Windows runs used six workers, two Wave rounds, full-face spill, ballistic release and fall speed 3. At tick 1,500 the driver added a radius-nine Water brush at (75, 68). A matched control repeated each run without the brush. The range below is the vertical distance between the highest and lowest Water contacts along the same 111 adjacent columns in the deep pool. The thin film on the rising right shelf is outside the gauge. [Replay driver](wave-oil-impinge-2026-11-20/workbench-impinge-replay.gd) · [Analysis](wave-oil-impinge-2026-11-20/contact-metrics.py)

| Observed on the same canvas | Previous build | Mobile slick |
|---|---:|---:|
| Contact height range at tick 1,500 | 11 cells | 1 cell |
| Standard deviation of contact height at tick 1,500 | 2.35 cells | 0.40 cells |
| Grid cells holding the same 1,244,400 Water units at tick 1,500 | 3,518 | 4,917 |
| Far-side probes responding to the fresh wave after 120 ticks (columns 127–146, compared with their undisturbed controls) | 0 of 20 | 19 of 20 |
| Largest far-side displacement at that time | 0 cells | 6 cells |
| Water thrown during the first 32 ticks after the brush | 16,141 units | 13,170 units |
| Contact height range at tick 2,100 after the brush | 9 cells | 2 cells |

All 1,935 Oil cells remained accounted for. The fixed tank produced no new spray from ticks 600 to 1,500. The undisturbed run continued a small slosh, reaching a four-cell range at tick 1,560 and returning to a one-cell range at 1,800 and 2,100. The real OpenGL screenshots and the headless material planes agreed at the captured ticks. [Before](wave-oil-impinge-2026-11-20/before.json) · [Before control](wave-oil-impinge-2026-11-20/before-control.json) · [After](wave-oil-impinge-2026-11-20/after.json) · [After control](wave-oil-impinge-2026-11-20/after-control.json) · [Workbench comparison](wave-oil-impinge-2026-11-20/oil-impinge-workbench.png)

## Native change and boundaries

Commit `45a2eba2b765113dd35ba31a0e62d83c36b57d1a` lets floating Oil follow incoming and receding Water in a bounded owner pass. The movement takes its volume from the contact cell. This preserves the Wave settings that the owner playtested. In a controlled tank with a four-cell Oil layer and a 16-cell Water step, the far wall rose 13 cells by tick 40. It remained at its initial height through 600 ticks on the previous code. Both new regressions failed on that code. All 47 native spill tests passed on the fix under WSL Ubuntu 24.04 and GCC 13.3. The two tests exercise an arriving and receding wave, worker parity, inventories, tagged warm Oil, masks, a rigid cap and paused-core re-entry.

An independent check filled a shaft with 65,535 units of warm Water under tagged Oil. Layers 1, 4 and 64 cells deep rose 33 rows in 33 ticks with identical results at one and six workers. All tags, temperatures and Water units survived. A 65-cell layer deferred. On descent, 32 Water units joined the 255 below when their temperatures matched. With different temperatures both cells retained their own quantities and temperatures.

The Windows DLL was built using `C:/Users/_/lcb-local-toolchain/rebuild_and_test.sh`, LLVM-MinGW 20260826 / Clang 23.1.0 and Godot 4.7. Native input fingerprint `33dc2b4acacf457a5a1ac1892f2f0bfae7c6a5209188dc38e6c9ade13f4bfaff`. DLL SHA-256 `229e9701816675adecadfe10ee612ad72e61f8d226aa4406c9c2beb33dbde03a`. The editor import and all three focused tests (`test_wave_flow.gd`, `test_workbench_wave_spill.gd`, `test_workbench_failure_containment.gd`) completed with zero Godot error lines.

## Live playback on the owner's desktop

The Workbench Play button ran the actual tank on a Ryzen 5 5600X and TITAN RTX with Godot 4.7/OpenGL, in a 1920×1080 window on a 59.95 Hz display with VSync. The four runs were previous, fixed, fixed, previous. Each timed 12 seconds from the initial impact, six seconds after tick 900 and nine seconds after adding Water at tick 1,500. The driver collected frame-post-draw timestamps and published Wave ticks in memory. All single-stepping, material captures, image readback and file writes occurred outside the timed windows. The first pair kept keyboard focus throughout. The repeat pair included unfocused playback. [Timing driver](wave-oil-impinge-2026-11-20/workbench-playback-timing.gd) · [Per-run focus, frame intervals, and simulation update statistics](wave-oil-impinge-2026-11-20/playback-timing.json)

| Both repetitions, all timed phases | Previous | Fixed |
|---|---:|---:|
| Rendered FPS | 59.97 | 59.96 |
| Simulation ticks per second | 59.87 | 59.89 |
| 95th / 99th percentile frame time | 16.74 / 16.79 ms | 16.76 / 16.82 ms |
| Slowest rendered frame | 19.81 ms | 18.03 ms |
| Fresh-wave frames repeating a published tick | 0.19% | 2.60% |

The fixed build delivered all 3,240 measured frames in under 25 ms. Some redraws used the previous Water snapshot before a later update caught up. During the fresh wave the longest interval between distinct published ticks was about 33.4 ms on each build. The refresh cap limits what these results establish about faster displays. The owner reported that live playback looked smooth and approved finishing and merging the feature.

The local Windows playtest ZIP for source `fba68d162a165303302541a124869592360cfa9a` has SHA-256 `bbbc6d358c7ea14d32e5c5dc2db8a2600f4f65ddae7fcb31bc4930a1c18eed00`. All 952 payload file hashes matched after extraction. The supplied Oil canvas, the original Waterwall and ramp maps, and the earlier Oil tank are included. The delivered `Open Workbench.cmd` started Godot 4.7 in isolated user data with zero error lines and installed a byte-identical Oil impingement setup. The launcher preserves an existing named save.
