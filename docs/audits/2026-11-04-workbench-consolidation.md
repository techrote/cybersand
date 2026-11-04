---
title: WORKBENCH-001 consolidation evidence
status: Current
document-kind: audit
scope: Development application control inventory and executable qualification
canonical-for: [workbench-consolidation-evidence]
last-reviewed: 2026-11-04
related-documents: [../systems/player-control-playground.md]
---

# WORKBENCH-001 consolidation

## Intake control inventory

Reference code is the owner-reviewed 52f19b51 fleet, with the identical runtime at PR #389 head 38d3059e. This is the checklist taken before implementation, not an execution result.

| Surface | Behavior to retain on the shared desktop owner |
| --- | --- |
| Fleet | Midge, Needle, Kestrel, Afterglow, Surveyor, Cartographer, Observatory and five-piece Scooper. JSON validation and explicit reload. |
| Pilot | Craft-specific Space/W, WASD, Q/E/S, C, Shift boost and Ctrl brake. Kestrel S dispenses Gunpowder. Cancel held input on focus and ownership transitions. |
| Handling | Independent mass/inertia 0.01–64, force/torque limit multipliers 0–64, boost 1–8, response budget 5–80 with RFT fixed at 20. Display actual values. |
| Response | LA, events off, RFT and selective arrivals. New workbench default is selective arrivals. |
| Spawn | Reset selected, set or capture authoritative position, Defaults and atomic authoring reload. |
| Brush | Sand, Dust, Rust, Stone, Seed, Salt, Sodium, Gunpowder, Coal, Water, hard wall and erase. Radius 2–24. |
| Emission | Fire toggle, per-craft nozzle admission, fixed-position powder source with B Burst, bounded Stream, inserted/blocked counts. |
| Workspace | Pause, acknowledged Step, reset, follow/overview, aspect-correct pointing and collapsed Details. New canvas supplies independent placements, pan/zoom and named authored starts. |

The source base is 751edc0b495dc85484ad5509a7c95f863651c76b, tree b0d42a256285e6049a6d3bdd1613d7ecd89f43c6. It already incorporates PR #390. Intake found a clean isolated worktree, materialized libraries and a passing git lfs fsck. PR #392 remains a separate historical attempt.

## Executed checkpoint

The integrated code is `5c241d8ef520a67c4d37cfdbf814496344102056`, tree
`4719dd35bdb141bab4e8af9900389d17f4b162ab`. Native source
`a1e209199a4876e0e85cf7da1e6017e1fae97d80`, tree
`2d9cd4b785f387543abb6acdf4183548d227a400`, produced both local libraries.
The project retained main's godot-cpp `101ae38034304346a46ea9ea84ae156d3e860496`,
Godot 4.7.stable.official.5b4e0cb0f, and its Rapier 2D 0.35.2 plugin / 0.35.1 core.
The runtime manifests cover all 83 production-native inputs and identify the
actual compiler and static libraries. Linux used GCC 13.3.0 / binutils 2.42 on
WSL Ubuntu 24.04. Windows used LLVM-MinGW 20260826 UCRT / Clang 23.1.0.

| Materialized artifact | SHA-256 |
|---|---|
| Windows native DLL | a4b1a526597980a1a015036afbf565f5b729c74e6a83127eb0ae6cbf13e74c05 |
| Linux native SO | 51b335897593dabd0dad165e19f2f15bfef8fd24799b1934224a7855b2131d96 |
| Windows Godot editor | b2ca888d5115a6cedee564764a2ee494a625f2ec2edbabd010fe33c9a88a6bf8 |
| Linux Godot editor | f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75 |
| Windows Rapier DLL | b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7 |
| Linux Rapier SO | 566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a |

## Acceptance and limitations

| Capability | Executed observation |
|---|---|
| Fleet and independent physical identity | Eight actual JSON rigs in a single shared Rapier space, bounded ninth refusal, separate mass, inertia, gravity, actuator caps, budgets, multiple proxies and command leases. The retirement fixture passes 70 checks per OS, including reordered, stale and duplicate results. The standalone fixture emits a teardown diagnostic for four ObjectDB instances and three script resources. The shared-host cases did not emit it. |
| Input and emission | 24 controls checks on each OS. Actual Kestrel S Gunpowder with simultaneous thrust, Shift boost, Ctrl brake, side jets and thruster Fire. Midge's obstructed nozzle refused and its open nozzle inserted material. Focus, pilot changes, pause and reset retire held commands. Gamepad evidence covers sampled buttons/axes. Physical-device and owner feel remain untested. |
| World response and liquids | Native prepared readback for LA-SA, LA, events off, RFT with fixed budget 20 and a wrong-budget refusal. Water FreeMass, CellularYield, all three PressureFlow variants and InertialCellular installed on the large canvas. Brine CY and IN installed per material. IN uses radius 3. Source-native admission supplies the choices for other liquids. Capacity and malformed setup refusals retain the old session. |
| Bearing and moving grains | Kestrel landed at y235.916 in separate Sand/Dust cases with grains overhead, beneath and to both sides. The worker delivered measured linear and angular responses during burial and powered departure. The source accounts for actual insertions/blocks. These cases qualify the tested conditions only. |
| U Scooper and passive barrel | 13 Sand cells lifted roughly 12.87 cells, then 10 remained inside the displayed cavity after 60.62 cells horizontal travel. Eight remained in the cavity and five lay below the floor after tipping about 1.21 radians. A separately configured powered Scooper made contact with the real barrel for 144 samples and lifted it 9.14 cells. A second independently configured flyer remained in the same session. |
| Presentation | The material upload, native mask sample and displayed polygons now share a revision, generation, epoch and instance identity. Main still reads the actual Rapier pose for control and spawn capture. The final physics/display cases passed 72 checks on each OS and the graphical Linux carry case passed 38. |
| Finite canvas and interest | The default is a paused blank 2048 × 2048 native domain. Three separated bodies at budgets 20/40/20 returned 5/1/1 proxies. With the camera at the origin, the source near (1566,1314) and both remote bodies continued to interact with active cells. Leaving the finite extent paused both owners and a fresh placement recovered. Overview pointing mapped to the correct distant cell. |
| Named starts | Separate author and reopen processes verified distant hard/Water paint, native family, nondefault body mass/inertia/budget, source origin, three real bodies and a neutral paused load. Wrong policy and corrupt JSON preserved the installed setup. Starting recipes intentionally omit subsequent evolution. A retained rebuild with 254 units of evolved PF overfill refused on both OSes; it left the original generation, inventory and next healthy tick intact. |

[Compact platform results and raw-log digests](workbench-391/results.json) ·
[Graphical Scooper carry with independent barrel](workbench-391/scooper-carry.png).

## Execution and cost

From the source worktree, launch with `Godot_v4.7-stable_win64.exe --path godot -- --workbench`.
F2 opens the feature menu. The local package is produced by
`python tools/package_workbench_review.py --engine <Godot4.7.exe> --output <new-directory>`.
Run **Open Workbench.cmd** inside that directory. It includes the actual engine,
project and materialized LFS libraries, and a source/tree/hash manifest.

Godot cases use `--headless --path godot --script res://tests/test_workbench_canvas.gd -- --workbench`
with a 180-second per-process limit. Set `CYBERSAND_WORKBENCH_TEST_NAME` to an unused
name, then run a separate process with `CYBERSAND_WORKBENCH_REOPEN=1`.
For graphical readback omit `--headless` and set `CYBERSAND_WORKBENCH_CAPTURE` to
a new PNG path. Run `test_workbench_physics_play.gd`, `test_workbench_input.gd`,
`test_workbench_fleet_session.gd`, `test_workbench_desktop_interest.gd`,
`test_workbench_retained_pressure.gd` and `test_workbench_hard_placement.gd` through
the same editor. Raw process logs and phase receipts remain local under `build/wb`.
Windows used an NVIDIA TITAN RTX. Linux graphical execution used WSL X11/Mesa
llvmpipe and fell back to dummy audio. Neither measures native Linux GPU performance.

The desktop World has an exclusive coordinator and uses the native phased C++
pool for material work. A 2048² shared session with Scooper, Needle, a barrel
and 60 separated Sand/Dust stamps used Auto on a 12-logical-processor host.
Six configured native participants claimed jobs at tick 19 on both OSes.
The four phases scheduled 90, 90, 61 and 62 jobs. This counter measures
distinct claimants in a phase. Rapier's desktop binaries also include Cargo
`parallel`; its manual step and scene objects are main-thread owned. The
native World counter does not measure internal Rapier thread participation.

With 16 dispersed stamps and three bodies, Windows and Linux each published
27 samples over seven seconds, with all six participants observed each time.
They reached ticks 159 and 209 respectively. In the heavier Windows follow-up,
60 dispersed stamps reached the retained 1024-active-scheduling-core limit
after tick 19; the World entered failure quarantine. The canvas admits distant
authoring but does not guarantee an arbitrary amount of simultaneously active
material. Raw receipts and their hashes are listed in the platform results.

The 2048 native adapter probe prepared in 404 ms on Windows and 696 ms on Linux.
Selective-arrival history used 42,467,328 bytes; native mask and adapter sweep lists
each reserved 4,194,304 slots at construction. The idle graphical Windows review
process sampled about 431 MiB resident and 469 MiB peak after opening the blank
canvas. These observations include editor/graphics state. Empty ticks and
a few-body material test do not establish a universal frame rate or scalability claim.

## Gates and retained failures

Linux GCC native core passed 165/165, the targeted arrival/sweep suite passed
196 checks in regular and ASan/UBSan runs and pressure preparation passed
50 checks. Actual native adapter, async ownership, prepared physical transaction,
REM-002/003, Water-body negative/control, brush ownership, render handoff
and fixed-interest regressions ran on Windows and Linux. Documentation,
materialized repository provenance, Git LFS, M11 historical integrity and
whitespace were checked separately. Retrieval found 32/32 frozen routes,
156/157 challenge routes and 11/11 scoped PLAY routes in the top five.
LCB03 is the inherited challenge miss; the new workbench question ranked first.

Earlier runs are retained locally. They exposed initial strict scenario-key
rejection, an inherited render patch extending above the finite canvas, a
1024-cell PressureFlow census limit, a null live-only radius in preflight and
JSON float/integer identity mismatch on restart. Fixed probes also discriminate
hard-hull intersection, loss of live Water overfill, repeated paint after
movement, refused Step at the finite edge and retirement of unaffected body motion.
A carry test comparing asynchronously sampled live poses with material pixels
reported zero grains in the visible cavity on one Windows run. The bound
display and repeated census above retain real leakage; there is no welded cargo
or perfect-seal claim. The accepted reference's historical scientific failures
remain separate. Owner human review, Web, hardware gamepad and hosted runtime
matrices are unqualified.

**Independent verdict for the integrated code:** GO for owner review of the
Draft at 5c241d8e. NO-GO for promotion or merge while MAT protected-source
admission remains open. The unchanged 27-input checker refuses three source
differences. World.cpp's final canonical digest is
`905b03645b8bca86e66727b4c9846c3c1bf4939ac57c5c69c69564dfe85198f2`;
the two other protected paths are world_inertial.inc and world_pressure.inc,
which now supply contact coordinates. The narrow admission request is on the
[#391 owner record](https://github.com/techrote/cybersand/issues/391#issuecomment-6640737890).
The historical lock and canonical ledger have not been changed.

## Review package and process verification

The source-matched Windows package is identified by its `review-manifest.json`
at code 5c241d8e. Its packaged engine passed a fresh-process readback (23/23
headless checks) and its ordinary launcher opened a responsive workbench window.
Windows and Linux at this code each passed 83/83 checks while authoring. Windows
passed 24/24 in a separate NVIDIA graphical reopen. The final Linux headless
reopen passed 23/23; the first X11/llvmpipe graphical repeat at this code
hit the 180-second limit. A four-raster-thread repeat also timed out. A separate 1280 × 720 traced diagnostic entered Main after 7.859 seconds but did not reach the installed-canvas observation before the same timeout. The earlier X11 author/reopen passed 83/83 and 24/24
before display alignment, and the final rendered Scooper fixture passed 38/38.
The results retain separate logs for each run and do not convert a timeout into
a successful receipt. See the [portable participation probe](workbench-391/participation_probe.gd)
for the seven-second material-pool workload. Execute it with `--headless --path
godot --script ../docs/audits/workbench-391/participation_probe.gd`.

The automatic Draft consistency job stopped at the protected World.cpp hash, as observed locally. Its [job log](https://github.com/techrote/cybersand/actions/runs/41905953051/job/126840533067) retains the refusal. The packaged Windows application and the independent review verdict refer to the unchanged 5c241d8e application tree.
