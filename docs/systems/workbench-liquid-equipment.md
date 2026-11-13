---
title: Workbench liquid equipment — valves, drain, nozzle and pump
status: Current
document-kind: contract
scope: IN-TOOLS #361 shared-workbench liquid equipment (accepted main); authored geometry, worker-owned device owner, native quantity accounting, controls, built-in liquid-lab and reservoir-lab starts, lifecycle and limits
canonical-for: [workbench-liquid-equipment, liquid-lab-apparatus, reservoir-lab-apparatus]
last-reviewed: 2026-11-12
related-documents: [../architecture/in-tools-gameplay-admission.md, ../architecture/inertial-cellular-v1.md, ../architecture/ballistic-water-v1.md, actor-usables.md, ../audits/2026-11-09-in-tools-361-workbench-equipment.md]
---

# Workbench liquid equipment — valves, drain, nozzle and pump

## Status and boundary

**Current on accepted main after [PR #553](https://github.com/techrote/cybersand/pull/553)
merged on 2026-11-12 at `d8588716becb0dc42019faf23f721378d8adc84a`.** The equipment is opt-in: a starting setup
without an `equipment` block, every Current default, the U10 `liquid_drain`
usable, the Water family selection and all native laws are unchanged. No
native C++ or GDExtension source changed, so the committed Windows/Linux
runtimes remain source-matched. Dated evidence lives in the
[2026-11-09 audit](../audits/2026-11-09-in-tools-361-workbench-equipment.md).

The equipment adds **no solver, law, velocity edit or second equipment
framework**. Every change to the World goes through the native World's
ordinary booked external-edit path (`emit_disc`) or the existing #406
ballistic owner (`inject_water_parcel`), so the native quantity ledger
remains the authority and closes by itself.

## Devices

| Device | Authored as | Operation |
|---|---|---|
| Valves | up to 8 non-overlapping `[x, y, width, height]`, ≤ 64 cells each | Open erases a gate's Hard wall cells; close refills them. A whole cell caught in a gate (whole-cell Water, other declared liquids, powders) is moved exactly to the nearest free unmasked cell outside every gate (radius ≤ 4); in a flooded gate a liquid cell is instead passed up to its free surface, so the level rises by its volume. A partial Water cell (FreeMass/PressureFlow) cannot move without changing its quantity, so it is removed and booked as `trimmed_water`. Cells under a body mask wait. |
| Drain | `[x, y, width, height, cells per tick]`, ≤ 96 cells, rate 1–32 | Bounded sink for the declared liquid set (`usable_runtime.gd` `LIQUIDS`). Bottom row first. Every removed Water cell's exact native quantity (state plus PressureFlow overfill) is booked; masked cells are skipped. |
| Nozzle | `[x, y, angle°, speed cells/tick, emissions per tick]`, speed 0.5–6, rate 1–8 | Finite directed source. In a World built with ballistic Water and with a dry muzzle it fires native ballistic parcels along the aim (real momentum, #406 owner). Otherwise it injects one whole Water cell at the muzzle **at rest** and the active solver moves it. **Under Water** it tops up a partial cell, or places the new cell on the free surface above (climb ≤ 64 rows, then the lowest open spot within a spread set by nozzle speed): exact volume and a rising level, but no local pressure jet. Speed ≤ 1 spreads over 6 columns; faster spreads less, and from 3 cells/tick it stacks a rising fountain column on the muzzle (owner-requested effect). |
| Pipe | `supply` (0–20000 cells), `pump` (bool), `pipe_capacity` (1–20000 cells, ≥ supply) | The nozzle draws only from the pipe. With the pump on, drained Water enters the pipe instead of leaving the World, so native Water + pipe is constant: a closed circulation loop. A full pipe stops the drain (`pipe_full`); it never deletes the excess. Without the pump the drain is a sink and the supply is finite. |

Inertial cellular flow, injected resting cells and ballistic parcels remain
three distinct mechanisms; the receipt states the nozzle mode explicitly.

## Ownership, lifetime and commands

- **Authored (persistent):** the optional Setup-v2 root key `equipment`
  `{version:1, valves, drain, nozzle, supply, pump, pipe_capacity}`, validated strictly by
  [`workbench_liquid_equipment.gd`](../../godot/scripts/workbench_liquid_equipment.gd)
  and [`workbench_setup.gd`](../../godot/scripts/workbench_setup.gd). Unknown
  keys, fractional or out-of-canvas geometry and unbounded rates refuse; nothing
  is clipped. A setup without the key keeps exactly its Setup-v2 bytes; an older
  build refuses (never silently drops) a file that has it. Save named start keeps
  the block, including live aim/speed/rate tuning.
- **Transient (never saved):** open/closed state, pipe stock, ledgers and
  observations.
- **Owner:** the simulation worker alone runs the device owner between ticks,
  after the workbench body mask is installed and before `simulation_tick`.
  The main thread queues copied commands through
  `Main.workbench_equipment()` → `CyberSimulationWorker.queue_workbench_equipment()`
  (bounded to 16 queued commands).
- **Commands:** `configure {serial, config}`, `valve {serial, index, open}` (index −1 = every valve),
  `drain {serial, open}`, `nozzle {serial, on}`, `tune {serial, angle, speed, rate}`,
  `stop {serial}` and read-only `observe {observation, regions}` (≤ 4 labelled
  rectangles ≤ 256 × 256, native `water_experiment_observation`). A configure
  carries a strictly newer serial; every other mutating command must carry the
  current serial, so commands from an older configuration or replaced World
  refuse (`stale_configuration`). Refusals never mutate the World and are
  counted in the receipt.
- **World replacement:** an accepted replacement (Restore start, Load, liquid
  policy change, actor edits, New blank) discards queued commands and resets the
  owner; the workbench re-sends the authored block on install, so every device
  restarts closed with the authored supply. Pause freezes the devices; the
  failed-World quarantine is unchanged.
- **Readback:** `lab_context.workbench_equipment` (copied receipt per snapshot)
  plus the existing `lab_context.water_spray.water` native ledger
  (`total` = visible + overfill + ballistic in flight; `expected` = baseline +
  Σproduced − Σconsumed). The same commands and receipt are the stable
  interface a future #531 agent client can use; no agent protocol was added.

## Desktop controls

Shared workbench, **Liquid equipment** rows: **Valve n/N [V]** toggles the
selected valve, **◀ [** / **▶ ]** choose the valve, **All valves**, **Drain [G]**,
**Nozzle [H]**, **Aim − [J]** / **Aim + [K]** (10° steps), **Speed**, **Rate**,
**Stop all**, **Load liquid-lab**, **Load reservoir-lab**, **Valve/Drain/Nozzle at
X/Y** (a valve is added, up to eight; drain and nozzle are replaced), **Supply
cells**, **Pump drain → nozzle**, **Apply supply/pump** and **Remove equipment**.
The status line shows every valve (`O` open, `·` shut, `o`/`c` changing, the
selected one bracketed), drained/injected cells, underwater injections, pipe
stock/capacity and the native Water total with its ledger state; with the pump
on it also shows the loop total. Overlay markers: valves orange (shut) / green
(open), the selected valve thicker, drain blue, nozzle point and aim line.
Typing `liquid-lab` or `reservoir-lab` in the setup name and **Load start**
also opens the built-in start while no user file of that name exists.

## Built-in liquid-lab apparatus

512 × 512, one 480 × 270 view: an elevated reservoir (120 × 90 Water cells)
with a closed 8 × 4 **bottom valve**; a basin with a bottom drain beside the
outlet; a ledge carrying a passive barrel (Rapier body); a pumped nozzle on the
dry floor beyond a lip, aimed at −141° / 5.5 cells per tick so the spray strikes
the barrel and lands back in the basin. Loading it asks the native validator for
the existing opt-in **Water: inertial** preset (radius 3) and enables ballistic
Water for that World. Either can be refused; the start then keeps the policy it
was given and the nozzle uses resting cells. No global default changes.

A bottom valve was chosen over a side valve: inertial Water gates
horizontal-only moves by coherence, so a 4 × 10 slot in a 4-cell side wall
leaked only about one cell per tick (measured). The bottom opening shows the
reported #361 behaviour — a rising cavity/bubble column above the outlet and a
surface dimple — as vacant-cell displacement, not as a gas-pressure model.

## Built-in reservoir-lab playground

512 × 512, one 480 × 270 view, requesting the existing opt-in **Water: pressure
reference** preset (any preset can be chosen in code/tests). Six valves:

- **A connected tanks:** a full tank and an empty tank share a wall with valve 1
  at its foot. Opening it lets the levels approach each other; closing mid-flow
  freezes both.
- **B cascade:** three bins (full, half, empty) share walls; each shared wall has
  a low valve (2, 4) and a high valve (3, 5). Low valves equalize; a high valve
  passes Water only once it stands above the gate.
- **C sealed tank:** an elevated closed tank with an air pocket, the drain in its
  floor and a vent valve (6) in its lid.
- **D pool:** the nozzle sits submerged near the pool floor, aimed up; with the
  pump on, the sealed tank's drained Water is piped into the pool and raises it.

It is a manually operated starting point: valves, drain and inlet are moved,
added or removed with the ordinary X/Y authoring controls and saved with the start.

## Limits and known gaps

- Measured leak rate through the liquid-lab's 8-cell bottom valve is about
  3 cells per tick under inertial Water (law unchanged); FreeMass, whole-cell and
  pressure Water drain it noticeably faster (see the dated evidence).
- The underwater inlet adds volume, not pressure: there is no public native call
  that adds PressureFlow overfill at depth, so a true pressure point/jet needs a
  separate native API.
- At rate 2 the spray registers native body contacts on the barrel but pushes it
  only ~0.5–0.7 cell in 240 ticks; raise **Rate** for a visible shove.
- Equipment is a shared-workbench feature. No physical-actor usable, generated
  (#542) map placement or agent (#531) integration exists yet; the authored block
  and command/receipt interface are the intended join points.
- The pre-implementation #361 source-admission lock (`in_tools_current_main_admission.py`)
  pins `simulation_worker.gd`; this implementation changes that one authority
  additively, so the lock reports drift by design. It was not repinned or weakened.
