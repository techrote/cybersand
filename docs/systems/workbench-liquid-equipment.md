---
title: Workbench liquid equipment — valve, drain, nozzle and pump
status: Current
document-kind: contract
scope: IN-TOOLS #361 shared-workbench liquid equipment (Draft PR branch); authored geometry, worker-owned device owner, native quantity accounting, controls, built-in liquid-lab apparatus, lifecycle and limits
canonical-for: [workbench-liquid-equipment, liquid-lab-apparatus]
last-reviewed: 2026-11-09
related-documents: [../architecture/in-tools-gameplay-admission.md, ../architecture/inertial-cellular-v1.md, ../architecture/ballistic-water-v1.md, actor-usables.md, ../audits/2026-11-09-in-tools-361-workbench-equipment.md]
---

# Workbench liquid equipment — valve, drain, nozzle and pump

## Status and boundary

**Current on the #361 Draft PR branch `feat/in-tools-361-workbench-equipment-20261109`,
not on accepted main until merged.** The equipment is opt-in: a starting setup
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
| Valve | `[x, y, width, height]`, ≤ 64 cells | Open erases the Hard wall gate cells; close refills them. A whole cell caught in the gate (whole-cell Water, other declared liquids, powders) is moved exactly to the nearest free unmasked cell outside the gate (radius ≤ 4). A partial Water cell cannot move without changing its quantity, so it is removed and booked as `trimmed_water`. Cells under a body mask wait. |
| Drain | `[x, y, width, height, cells per tick]`, ≤ 96 cells, rate 1–32 | Bounded sink for the declared liquid set (`usable_runtime.gd` `LIQUIDS`). Bottom row first. Every removed Water cell's exact native quantity (state plus PressureFlow overfill) is booked; masked cells are skipped. |
| Nozzle | `[x, y, angle°, speed cells/tick, emissions per tick]`, speed 0.5–6, rate 1–8 | Finite directed source. In a World built with ballistic Water it fires native ballistic parcels along the aim (real momentum, #406 owner). Otherwise it injects one whole Water cell at the muzzle **at rest** and the active solver moves it. |
| Pipe | `supply` (0–20000 cells) and `pump` (bool) | The nozzle draws only from the pipe. With the pump on, drained Water enters the pipe instead of leaving the World, so native Water + pipe is constant: a closed circulation loop. Without the pump the drain is a sink and the supply is finite. |

Inertial cellular flow, injected resting cells and ballistic parcels remain
three distinct mechanisms; the receipt states the nozzle mode explicitly.

## Ownership, lifetime and commands

- **Authored (persistent):** the optional Setup-v2 root key `equipment`
  `{version:1, valve, drain, nozzle, supply, pump}`, validated strictly by
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
- **Commands:** `configure {serial, config}`, `valve {serial, open}`,
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

Shared workbench, **Liquid equipment** rows: **Load liquid-lab**, **Valve [V]**,
**Drain [G]**, **Nozzle [H]**, **Aim − [J]** / **Aim + [K]** (10° steps),
**Speed**, **Rate**, **Stop all**, **Valve/Drain/Nozzle at X/Y** (authoring at the
entered position), **Supply cells**, **Pump drain → nozzle**, **Apply
supply/pump** and **Remove equipment**. The status line shows each device, the
drained/injected cells, pipe stock and the native Water total with its ledger
state; with the pump on it also shows the loop total. Overlay markers: valve
orange (shut) / green (open), drain blue, nozzle point and aim line. Typing
`liquid-lab` in the setup name and **Load start** also opens the apparatus while
no user file of that name exists.

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

## Limits and known gaps

- Measured leak rate through the 8-cell bottom valve is about 3 cells per tick
  (IN law unchanged); drainage therefore fills the pipe slowly at first.
- At rate 2 the spray registers native body contacts on the barrel but pushes it
  only ~0.5–0.7 cell in 240 ticks; raise **Rate** for a visible shove.
- Equipment is a shared-workbench feature. No physical-actor usable, generated
  (#542) map placement or agent (#531) integration exists yet; the authored block
  and command/receipt interface are the intended join points.
- The pre-implementation #361 source-admission lock (`in_tools_current_main_admission.py`)
  pins `simulation_worker.gd`; this implementation changes that one authority
  additively, so the lock reports drift by design. It was not repinned or weakened.
