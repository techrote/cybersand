---
title: IN-TOOLS #361 workbench liquid equipment — implementation evidence
status: Current
document-kind: audit
scope: Dated local Windows and WSL Linux evidence for the #361 Draft-branch workbench liquid equipment; source/runtime identities, commands, results and explicit gaps
last-reviewed: 2026-11-09
related-documents: [../systems/workbench-liquid-equipment.md, ../architecture/in-tools-gameplay-admission.md, ../operations/in-tools-fixtures-and-playtest.md]
---

# IN-TOOLS #361 workbench liquid equipment — 2026-11-09

## Source and runtime identity

- Base: accepted `main` `1f82dac1cebc9b38a319153354e4bcc774289417`.
- Implementation commits: `fdea66bd` (equipment) and `7e20ec6e` (valve state
  reporting fix, below) on `feat/in-tools-361-workbench-equipment-20261109`.
  Every result in the table was re-run on `7e20ec6e` unless marked otherwise.
  Later commits on the branch are documentation only unless the PR records otherwise.
- No file under `native/` or `godot/native_extension/` changed, so the committed
  runtimes stay source-matched: `verify_retained_runtime` accepts the tree
  (runtime source commit `a953343e…`).
- Windows runtime `cybersand_native.windows.x86_64.dll`
  sha256 `64ec1a6b7b208136d02b302b952a9a1d48884d600cb009d4e4929952e365534e`.
- Linux runtime `libcybersand_native.linux.x86_64.so`
  sha256 `c848253ea7a249fb745ee6b439337940a4067d5cb08d9cf0cf460d837cf207b2`.
- Godot 4.7-stable official (Windows console build; Linux x86_64 build in WSL
  Ubuntu 24.04). Windows host: NVIDIA TITAN RTX via ANGLE for windowed captures.

## Predecessor disposition

Draft PR #480 (`22abca9b`, 46 ahead / 215 behind main, conflicting, last commit
2026-11-06) was not merged, rebased or transplanted. Its independent review
(2026-11-07) found a stale-runtime Windows gate and a CI scheduling-policy
failure; both came from its native/GDExtension edits and new workflows. This
implementation needs neither: it reuses accepted main's worker-owned source
pattern (#508), the ballistic owner (#406), the shared workbench (#394) and the
native quantity ledger. #379/#383/#404 remain read-only history.

The 2026-11-07 [admission lock](../architecture/in-tools-gameplay-admission.md)
pins 13 authority blobs. This implementation changes exactly one of them,
`godot/scripts/simulation_worker.gd` (additive: one bounded command queue, a
reset at World commit, one `before_tick` call and one receipt copy). The lock
checker therefore reports drift by design. It was neither repinned nor
weakened; renewing or retiring that pre-implementation registration is left to
the integration owner. Its causal fixture was executed directly instead (below).

## Commands and results

All runs used `godot --headless --path godot -s res://tests/<case>.gd` with a
400 s process timeout unless noted, on the implementation tree above.

| Case | Platform / workers | Result |
|---|---|---|
| `test_workbench_liquid_equipment.gd` (ballistic) | Windows headless, request 4 | 84 checks, 0 failures; peak 4 observed task claimants |
| same, `LIQUID_EQUIPMENT_WORKERS=1` | Windows headless, request 1 | 84 / 0; peak 1 claimant |
| same, `LIQUID_EQUIPMENT_BALLISTIC=0` (resting-cell nozzle) | Windows headless, request 4 | 82 / 0 (ballistic-only checks skipped by design) |
| same, windowed `--rendering-driver opengl3_angle`, frame capture | Windows windowed, request 4 | 83 / 0 on `fdea66bd` (frames in the PR). One earlier windowed launch failed before equipment code ran: the initial blank-canvas install reported "Controlled liquid replacement retired before commit"; it did not recur in three later windowed runs and is recorded as an unexplained flake |
| same | WSL Linux headless, request 1 and 4 | 84 / 0 each; peak 1 and 4 observed claimants. On `fdea66bd` the 4-worker run exposed the valve-state defect below |
| `test_liquid_desktop_default_host.gd` (unchanged #361 causal fixture) | Windows headless (`fdea66bd`) | 86 assertions, 0 failures, natural exit 0 |
| 14 existing workbench regressions (`spray_rearm`, `canvas`, `input`, `live_liquid_edit`, `failure_recovery`, `fleet_session`, `pilot_ui`, `physics_play`, `liquid_edges`, `boundary_retention`, `retained_pressure`, `hard_placement`, `desktop_interest`, `lcb_salvage`) | Windows headless (`fdea66bd`) | all exit 0, 0 failures |

## Defect found and repaired

On `fdea66bd` a valve command applied between ticks on a frame without a new
body sample (no device step that frame), so the receipt briefly reported
`closed` before the gate was refilled. The Linux 4-worker run observed
`closed_cells = 0` at that moment. `7e20ec6e` reports `opening`/`closing` until
the next device step and the regression now requires all 32 gate cells refilled.
No World mutation or quantity was affected; only the reported state was early.

## Physical observations (Windows, request 4, ballistic)

Native census via the read-only `observe` command (`water_experiment_observation`);
quantities via the native ledger `water_spray.water`. Water unit = 255 per cell.

- Start: reservoir 10 800 Water cells (2 754 000 units), ledger closed, every
  device closed, pipe 150 cells; Water assigned `inertial_cellular_v1`, radius 3.
- Leak, 240 ticks with the 8 × 4 bottom valve open: all 32 gate cells opened;
  reservoir 10 800 → 10 072 cells, basin 709 cells; native total unchanged.
  Frames show a rising vacant-cell column above the outlet, a surface dimple and
  a droplet stream — the qualitative #361 target. These are vacant cells and
  displacement, not a gas-pressure model.
- Close: 32 gate cells refilled, 10–14 caught whole cells moved exactly, 0 units
  trimmed; no reservoir change in the following 90 ticks; basin kept spreading
  (714 → 723 cells) — residual lateral runout after closure.
- Drain, 200 ticks at 16 cells/tick: 25–28 whole cells drained, pipe = 150 cells
  + drained exactly, native total fell by exactly the drained quantity.
- Nozzle, 240 ticks at −141°, 5.5 cells/tick, rate 2: 175–178 emissions, every
  one a native ballistic parcel; 54 native body contacts on the barrel (pushed
  0.5–0.7 cell), loop total (native Water incl. in-flight + pipe) constant at
  10 950 cells throughout. Resting-cell mode injected 160 cells at the muzzle.
- Stop closes every device and moves no further Water; Restore start rebuilds a
  full sealed reservoir, closed devices and the authored supply, and keeps the
  live-tuned aim; Save/read-back of the block is identical; New blank removes it.
- Refusals: older-serial commands, out-of-range tune, malformed configure and an
  unknown command at the queue all refuse without changing state.
- Headless request 1 and request 4 produced identical leak census
  (10 072 / 709 cells). This is an observation, not a parity proof: device
  timing follows the wall-clock-paced Rapier sample stream.
- Native tick (participation sampler): mean 1.2–1.9 ms, p95 2.7–4.5 ms (Windows and
  WSL Linux, 1 and 4 workers) on this
  512 × 512 apparatus. Owner-thread CPU and frame pacing were not separately
  measured.

## Retained frames

Actual windowed Godot workbench frames from the `fdea66bd` windowed run
(the window was resized by hand during capture, so the framing differs):

- [Leak with the bottom valve open](../images/in-tools-361/liquid-lab-leak.png):
  cavity column above the outlet, surface dimple, droplet stream and basin mound.
- [Pumped nozzle striking the barrel](../images/in-tools-361/liquid-lab-nozzle.png):
  status line shows the closed native ledger and constant loop total.


## Second round: pressure families, reservoir-lab and pacing — 2026-11-09

Source `cfe2ba54` (after `004d3c2e`; tests and equipment scripts only, still no
native/GDExtension change). Every row below ran on exactly that tree.

| Case | Platform / workers | Result |
|---|---|---|
| liquid-lab, `Water: inertial` | Windows request 4 and 1; WSL Linux request 1 and 4 | 103/0 each |
| liquid-lab, `Water: pressure reference` / `cached` / `dormant` | Windows request 4 | 102/0 each |
| liquid-lab, `Water: whole-cell` | Windows request 4 | 103/0 |
| liquid-lab, `Current defaults` (FreeMass) | Windows request 4 | 101/0 |
| `test_workbench_reservoir_lab.gd` (pressure reference) | Windows request 4; WSL Linux request 4 | 81/0 each |

Per-family liquid-lab observations (240 ticks after opening the 8 × 4 bottom
valve; Windows request 4):

| Water family | Reservoir after leak (of 10 800) | Trim on close (units; 255 = one cell) | Drained cells | Native tick mean |
|---|---|---|---|---|
| inertial | 10 072 | 0 | 25 | 1.43 ms |
| whole-cell (CellularYield) | 8 990 | 0 | 825 | 1.81 ms |
| Current (FreeMass) | 8 968 | 1 889 | 753 | 2.31 ms |
| pressure reference / cached / dormant | 8 648–8 660 | 226 | 575–578 | 5.6–6.0 ms |

Findings and repairs in this round:

- **Flooded gates.** Under whole-cell and Current Water the basin floods up to
  the floor valve, so a closing gate found no free cell within four cells and
  waited forever. A caught liquid cell is now passed up to its free surface.
- **Pressurized cells.** Under PressureFlow every deep cell carries overfill, so
  closing a valve trimmed every caught cell (≈ 52 cells per close in the
  connected tanks). A full cell now moves and only its overfill is trimmed
  (connected-tank close 13 327 → 3 525 units; liquid-lab close 4 756 → 226).
- **Underwater inlet.** No public native call adds PressureFlow overfill at depth.
  The inlet tops up a partial cell or adds a cell at the free surface. Stacking on
  its own column made a spire; at the owner's request this is now speed-based:
  slow inlets spread over the surface (exact pool gain asserted), fast inlets
  (≥ 3 cells/tick) raise a fountain column (asserted: 6 cells above the surface
  box after 90 ticks at speed 4).
- **Pipe capacity.** A 2-cell headroom pipe stopped the drain exactly at capacity
  (31 `pipe_full` events) with native Water + pipe unchanged.
- **Counting.** A half-submerged muzzle can place a resting cell; the receipt now
  reports `cell_emissions`, and every other emission is asserted to be a native
  ballistic parcel.

reservoir-lab (pressure reference, Windows request 4):

- Connected tanks: 1 038 cells crossed in 150 ticks; closing mid-flow held both
  sides exactly for 90 ticks; after reopening the tanks reached 2 946 vs 2 950 cells.
- Cascade: the low valve raised bin 2 from 3 328 to 4 959 cells while bin 3 stayed
  dry; opening the high valve then spilled 1 198 cells into bin 3.
- Sealed tank: the drain removed 2 441 cells in 240 ticks with the vent shut and
  2 004 cells in the next 240 with it open. **No vacuum hold-up was observed**:
  the drain removes cells directly, which PressureFlow's gas model does not resist.
- Submerged inlet: 480 cells piped into the pool; the pool gained exactly that
  quantity; native Water + pipe constant throughout.

Pacing (windowed Windows, ANGLE, NVIDIA, request 4, liquid-lab with inertial and
pressure reference): frame interval mean 17.0 ms, p95 17.3–17.4 ms (60 Hz), with
isolated spikes up to 174–191 ms during World installs and observations. The
sampled `TIME_PROCESS` monitor and worker step field include test bookkeeping and
idle waits, so they are retained in the logs but are not claimed as CPU cost.

Frames: [cascade with high valve open](../images/in-tools-361/reservoir-lab-cascade.png),
[fast inlet fountain](../images/in-tools-361/reservoir-lab-fountain.png).

## Explicit gaps

- Hosted Native/GDExtension/Water CI is suppressed while Draft; no hosted pass is claimed.
- A true underwater pressure point (adding PressureFlow overfill at depth) needs a new native call.
- No sanitizer run: no native source changed.
- Human feel acceptance, physical-actor usable, #542 generated-map placement and
  #531 agent use are not done.
- Leak and drain rates are modest at the default geometry (see the system page).
