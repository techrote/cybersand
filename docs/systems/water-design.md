---
title: Water design
document-kind: contract
canonical-for: [native-water-semantics, native-fallback-water-differences]
status: Current
scope: Native conserved Water, coherent emission and adhesion, rest/hash fixtures, fallback differences, and future reaction accounting
last-reviewed: 2026-09-10
related-documents: [materials-and-rule-kernels.md, material-appearance-and-rendering.md, ../reference/level-saves-and-replay.md, ../decisions/ADR-005-water-model.md]
---

# Water design

**Current:** native Water uses bounded pairwise transfers of 8-bit conserved
mass. Native desktop and both Web profiles use this model. The desktop GDScript
fallback uses a different discrete flow model. Closed pure-Water fixtures
demonstrate conservation and stable rest; they do not prove conserved mass for
every material reaction or exact save/replay continuation.

Source identity is in the [checkpoint](../operations/source-checkpoint-and-recovery.md);
dated fixture executions are in the [evidence ledger](../reference/validation-evidence.md).
[ADR-005](../decisions/ADR-005-water-model.md) owns the solver decision and rejected alternatives.

## Current native representation and flow

[World::update_water and transfer_water](../../native/src/world.cpp) own the rules;
[MaterialRules](../../native/include/cybersand/material.hpp) supplies immutable
descriptors.

| Value | Meaning |
|---|---|
| Material ID 3, `state_a` 1–255 | Water with that many fixed-point mass units |
| Empty | Zero Water mass |
| `state_b` | Remaining coherent-emission lateral delay |
| Viscosity | Dimensionless gameplay rate; Water uses 0, the fastest setting |
| Lateral rest tolerance | No lateral transfer when source mass is at most target mass + 1 |
| Lateral relaxation | Request three quarters of the positive mass difference, rounded down |

Painting ordinary Water initializes a full 255-unit cell. Gravity attempts down,
then both diagonals in deterministic order. It merges into Water or moves/swaps
whole cell state into a permitted destination; directional density exchange lets
Water move through lighter accepting media. Lateral equalization requests three
quarters of the positive mass difference, scaled by viscosity. This crosses the
pair midpoint but contracts its imbalance; the one-unit rest tolerance remains.
A transfer is capped by the
requested amount, source mass, and destination capacity. Zero remaining source
mass converts the source to Empty.

Water has no persistent native lateral direction or travel budget. Transfers
stay inside the phase-owned bounded write domain and mark source/destination
activity and render dirtiness. Viscosity does not expand the kernel radius.

## Faster sideways flow and profile identity

The [2026-09-10 owner-requested leveling change](../audits/2026-09-10-water-leveling.md)
replaces half-difference requests. It speeds fronts and basin leveling without
extra lateral candidates or a new field. This intentionally changes Water's
historical #13 samples and can increase optional grain pickup, whose disturbance
measure is actual transferred mass. Profile schema/values remain v1; source and
artifact identity must accompany their hashes. Mercury and powder-only references
remain exact. General gameplay still has optional mixing/carrying disabled.

## Coherent emission and surface adhesion

Coherent/calm emission is a command flag on Water, not a second material ID.
[CyberNativeCellWorld::emit_disc](../../godot/native_extension/cyber_native_cell_world.cpp)
initializes a 12-tick countdown. It travels with mass; merging takes the larger
delay. The current update decrements it but uses its pre-decrement value to
suppress that update's lateral equalization. Gravity and density exchange still
operate. Later edge falls regain ordinary spray after the delay expires.

Adhesion is independent of viscosity and emission mode. When enabled, remaining
Water mass at or below 48/255 skips lateral spreading if the cell below is neither
Empty nor Water. Gravity was already attempted. Disabling adhesion removes that
supported-film threshold; it does not select a different gravity solver.

**Approved owner intent:** preserve fast fronts, airborne spray, and supported
slope film as useful behavior. Paste/Slush intentionally retain heap-capable
whole-cell yield. Per-material native adhesion traits remain **Planned**.

<a id="conservation-stable-rest-and-the-correct-hash"></a>

## How should I diagnose a shimmering pool?

**Current diagnostic:** compare exact Water mass, `World::content_hash()`, and
dirty/activity observations before treating shimmer as a fluid bug. If authority
is stable while the pool visibly changes, inspect its shader, presentation-time
animation, and render-only dither. If a closed pure-Water fixture loses mass or
continues changing cell content after its rest criterion, investigate simulation
transfers, conversions, or waking. Appearance alone cannot decide which path failed.
Water coverage dither derives from stable world coordinates and mass; it cannot
mutate authoritative cells or wake the simulation.

`transfer_water` conserves exact integer mass for each Water pair. A closed
pure-Water fixture must preserve the exact total every tick, including sleep,
wake, and boundary crossings. Consuming/producing reactions are a separate
accounting problem; no general conserved reaction-mass model is implemented.

Use `World::content_hash()` to observe rest: it includes material/state/
temperature at meaningful coordinates and excludes tick/epoch/activity.
`state_hash()` includes advancing tick and update epoch plus additional
scheduler state, so it is expected to change during otherwise resting ticks.
Compare state hashes at matching ticks/configurations for supported fixture
parity; neither hash is a complete replay checkpoint.

[Native tests](../../native/tests/test_world.cpp) provide explicit bounds:

- `test_conserved_water_levels_and_sleeps`: four-worker phased fixture,
  48×255 initial mass, at most 2,000 ticks to reach 40 unchanged content hashes,
  then 40 further mass/rest checks and zero active chunks.
- `test_water_surface_column_mass_is_level`: settled column-mass difference
  at most 8/255 of a cell.
- `test_water_conserves_across_storage_boundaries`: exact boundary conservation.

These are fixture bounds, not universal settling-time guarantees. Additional
mirrored, shifted, mixed-material, and every-direction edge cases remain needed.

## Rendering and saves

`World::copy_rgba` derives stable coverage from world coordinates and mass.
The Godot native path instead publishes RG8 material/condition bytes and derives
coverage in the palette shader. Both are presentation-only: dither cannot change
mass, collision, dirty authority, or waking. Animated presentation does not imply
moving Water. The [appearance contract](material-appearance-and-rendering.md)
owns texture/upload details.

CYSD1 preserves the encoded Water state bytes for a finite level. It omits
scheduler and external-input state, so byte-identical re-export does not prove
the same next tick. See [level saves and replay](../reference/level-saves-and-replay.md).

## Desktop fallback difference and historical fixture

[CyberCellWorld](../../godot/scripts/cell_world.gd) moves discrete full material
cells, retaining flow direction, bounded viscosity-scaled dispersion (Water's
ceiling is 24 cells), intervening-path checks, and stopped-edge pressure
look-ahead. Its six-cell yielding budget is for Slush, not native Water. Vacancy
reuse and write-once destination rules here must not be described as native
pairwise mass mechanics.

Historical 2026-08-27 Godot 4.7 evidence recorded the wide basin failing after
360 ticks with occupied heights 9–22, while Smoke, small Water, and body-coupling
assertions passed. That is the pre-correction result, preserved rather than
asserted as today's failure. The retained
[fallback fixture](../../godot/tests/test_cell_world.gd) requires a height
difference at most two after 360 ticks; later dated executions are in the ledger.

## Planned and deferred changes

**Planned:** explicit source/sink reaction accounting, mass-return commands,
general replay capture, and complete mirrored/edge acceptance. **Deferred:**
a general fluid solver. Active-only buffered flux is a retained **Planned**
candidate only if measured bias or a future field justifies it; no buffered
solver is selectable today. **Rejected:** a competing liquid world, equivalent
swaps to animate rest, or finite travel history as free Water equilibrium.


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## What does G-C say about the remaining Water residual?

[Completed characterization](../operations/liquid-characterization.md#does-keeping-water-awake-fix-residual-leveling-or-films)
finds identical Water trajectories under quiet3/4096, with active96-wide residual
and stable narrow basin/film. [G-C](../operations/architecture-programme.md#g-c-staged-decision-2026-09-11)
admits a fixed-carrier precision diagnostic, not a precision cause, expected lower-bit
winner or changed conservation/defaults. No P implementation is included here.

## Isolated Issue17 experiment branch

The [precision registration](../operations/state-precision-experiment.md) defines
a native-only experimental build on codex/issue-17-state-precision. That branch
uses a fixed wide carrier and uint16 native mass access for all precision arms.
Production semantics described above remain the reference; compact adapters,
render projection and saves are not precision-aware migration paths.

## What did G-P learn about useful Water precision?

[Completed precision evidence](../audits/2026-09-11-issue-17-state-precision.md)
finds exact per-arm accounting, but mass4/6 lose levelness and ledge discharge;
tiny requested1/255 and2/255 droplets vanish at initial quantization, not at runtime.
Mass10 modestly improves narrow residuals and extends activity without resolving
the wide finite-horizon residual. [G-P](../operations/architecture-programme.md#g-p-staged-decision-2026-09-11)
retains mass8 as the reference, with exact Water-only delay4 as a research budget.
Films survive all four precisions. Literal tolerance changes are reported separately.
This is native experiment evidence; production Water, rendering and saves remain
unchanged. No flow-history target or production migration is established.
