---
title: Water design
document-kind: contract
canonical-for: [native-water-semantics, native-fallback-water-differences]
status: Current
scope: Current Water-family routing and player defaults; scoped FreeMass mechanics, quantity accounting, historical negative controls and fallback differences
last-reviewed: 2026-11-24
related-documents: [materials-and-rule-kernels.md, material-appearance-and-rendering.md, ../reference/level-saves-and-replay.md, ../operations/water-hybrid-pressure-extension-programme.md, ../decisions/ADR-005-water-model.md]
---

# Water design

**Current accepted source `00cdb02f`, checked 24 November 2026:** Water has
several admitted native laws. Fresh native sandbox and Shared Workbench sessions
use **Wave Flow with waterfall spill and ballistic release**. Plain C++
`WorldConfig` still selects the original FreeMass carrier with those overlays
disabled. Native Web, desktop comparison hosts and explicit saved setups must be
identified by their actual applied constructor/receipt; there is no universal
all-platform player preset implied by the word “Water”.

| Path | Material motion and state | Canonical contract |
|---|---|---|
| Original FreeMass | Pairwise fractional transfer; 255 units per full cell, coherence and film adhesion | The FreeMass sections below |
| CellularYield Water | Whole-cell movement with explicit fractional-input admission/normalization | [Family policy](../architecture/liquid-solver-family-policy.md) |
| PressureFlow | Pressure/head, visible quantity plus overfill, gas compartments; reference/cached/cached_dormant variants | [PressureFlow](../architecture/pressure-flow-v1.md) |
| InertialCellular | Whole-cell carriers with retained integer motion; optional signed-vertical extension is separate | [Inertial](../architecture/inertial-cellular-v1.md) |
| Wave Flow | Bulk strip passes, uint16 stored mass and retained face flux; no PressureFlow gas model | [Wave Flow](../architecture/wave-flow-v1.md) |
| Ballistic Water | Bounded native parcels that launch, fly and deposit exact Water quantity | [Ballistic Water](../architecture/ballistic-water-v1.md) |
| Desktop GDScript fallback | Discrete cell flow with different rules and limits | [Fallback section](#desktop-fallback-difference-and-historical-fixture) |

Source: [`WorldConfig`](../../native/include/cybersand/world.hpp),
[`select_gameplay_water`](../../godot/native_extension/cyber_native_cell_world.cpp),
[`LiquidSolverPolicy`](../../native/include/cybersand/liquid_solver_policy.hpp).
This page owns routing and the original FreeMass semantics. It does not collapse
all families into one material law or turn an old FreeMass failure into a current
Wave result. Runtime and physical acceptance remain source/platform-specific in
the [validation ledger](../reference/validation-evidence.md).

## Current native representation and flow

**Scope: original `freemass_v1`, without Wave.** The following 255-unit capacity,
local transfer and no-direction rules describe that path only. Wave can retain
overfill and face flux; IN and ballistic parcels carry their own motion.

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

## Deep-head limitation after issue #26

**Historical FreeMass comparator:** #26 did not change its original law. The
[2026-09-19 characterization](../audits/2026-09-19-issue-26-water-leveling.md)
adds true communicating-head controls and demonstrates a limitation that the older
flat-basin speed check did not exercise. With that exact FreeMass comparator, medium and deep
identical outlets have the same early discharge once their local outlet cells are
full; communicating pools can sleep with about a 16-cell level difference, and a
true unequal-head U-tube can sleep with about a 24-cell difference.

Two source-matched bounded candidates were rejected against thresholds frozen
before their implementation: a radius-2 head-scaled local drive and a radius-2
same-row lookahead. Both preserve exact mass and expected worker parity but fail the
registered bulk/head screens; the lookahead can keep bad communicating Water active
at very high cost without reducing the head difference. Rejected candidate
semantics are not retained in Current source.

The result narrows the missing mechanism: adjacent transfer strength cannot transmit
head through a saturated connected passage where there is no immediate destination
capacity. [Issue #45](https://github.com/techrote/cybersand/issues/45) owns the next
bounded head/pressure-transmission architecture experiment. It is distinct from #18
material-local directional history. #18 remains held until the bulk-head confound is
resolved.

## Post-#26 apparatus qualification

**Historical FreeMass comparator:** the referenced apparatus retained its law. The #26 negative result is valid for
the two exact radius-2 candidates tested, but the retained v1 experiment apparatus
has post-merge review limitations documented in
[the #26 review](../audits/2026-09-19-issue-26-post-merge-review.md).

In particular, v1 settling/equilibrium metrics can ignore dry expected columns,
unreached thresholds use a success-valued numeric zero, the historical fixture
named `unequal-head-u-tube` is actually a three-compartment communicating
geometry, and whole-run p95 mixes active and sleeping phases.

[#49](https://github.com/techrote/cybersand/issues/49) now supplies the
versioned correction: explicit wet coverage, categorical censoring, a clean
roofed-passage two-limb communicating-head fixture, fixture-appropriate contour
evidence, phase-separated timing and failure-retaining campaign accounting. See
the [frozen v2 registration](../audits/2026-09-20-issue-49-water-apparatus-v2-registration.md)
and [source-matched Current-Water baseline](../audits/2026-09-20-issue-49-water-apparatus-v2-baseline.md).

That source-matched FreeMass control does not reach
the preregistered half-life or <=1-cell target by tick 4800. Preserve all original
#26 artifacts as historical evidence; this corrected negative control does not
select a successor mechanism. The later [WEX-005 disposition](#wex-005-disposition-and-the-opt-in-lcb-lane-2026-10-23)
records #95's NARROW decision for #45; the old waiting instruction is not a new
requirement to repeat that decision.

## Hybrid / pressure extension after the 2026-09-20 owner clarification

**Historical FreeMass checkpoint:** the following result predates the later admitted families and Wave player profile. The
[Water hybrid/pressure extension programme](../operations/water-hybrid-pressure-extension-programme.md)
records a parallel investigation before a new head/pressure mechanism is selected.

The important distinction is that Current already has two different native liquid
motion/quantity families: Water's fractional conserved FreeMass path and the
generally whole-cell CellularYield-style path used by other liquids, with Oil
specialization. #15 retained that separation; no unification was selected.

The owner-observed deep-Water target is faster depth-dependent outward surge when a
deep body becomes unrestrained, while shallow Water already behaves reasonably.
A simple generic Rapier body entering Water can create a useful splash/wave, so
[#91](https://github.com/techrote/cybersand/issues/91) first freezes that generic
body↔Water baseline and its hard-floor failure. [#92](https://github.com/techrote/cybersand/issues/92)
may then test, only on a suitable generic #12 hybrid substrate, at most roughly
3-5 **segmented upper-volume** solided-Water sheet tiers. The candidate is not a
monolithic core or full-depth lamination and does not authorize production adoption.

#49's corrected successor apparatus/control is now available. #45 remains the
existing saturated-head architecture question, but a new pressure/head mechanism
is not assumed inevitable: [#95](https://github.com/techrote/cybersand/issues/95)
must synthesize the corrected #49 control and WEX evidence before #45 is instructed
to proceed, narrow, recharter, defer or no-go.

A communicating-head equal-level fixture must state its gas boundary assumption.
Shared/vented headspaces can legitimately use the same atmospheric boundary;
separately sealed headspaces generally cannot be assumed to converge to equal
levels. [WEX-003 research](../research/lumped-gas-region-pressure-bookkeeping.md)
finds a bounded lumped connected-gas model technically promising for optional
research and admits only a non-production #94 decompression proof. It remains a
surface/boundary-pressure model: it does not transmit head through saturated Water
or change Current Water semantics.

## WEX-005 disposition and the opt-in LCB lane (2026-10-23)

**Historical FreeMass checkpoint:** the following result predates the later admitted families and Wave player profile. The
[WEX-005 synthesis](../audits/2026-10-23-wex005-water-evidence-synthesis.md)
records #95's answers:

- **Deep release:** the slow-slope deficit is real and unresolved. On current
  `main` (#49 v2 rerun 39739371203), deep and medium outlets deliver
  byte-identical discharge, so depth above saturated outlet cells adds no drive.
  Water sheets (#92) were never tested. No surge fixture is registered yet.
- **#45: NARROW.** Bounded head-transmission research continues to its
  admission/design phase only, under a shared/vented atmosphere, with a separately
  registered surge fixture family. No mechanism is selected.
- **Boundary assumption of that FreeMass comparator:** it has no gas state; `Empty` acts as one
  shared atmosphere. Equal levels are a valid target only for vented/shared
  headspaces. Sealed headspaces settle at `Δh = (p_A − p_B)/(ρ·g)`, and
  vacuum/low-pressure boundaries have no Current target.
- #93 is research only, #94 is narrow-use, #18 stays held, and FreeMass and
  CellularYield stay separate.

The owner-approved **Liquid Comparison Build** (#200, gated by #213) adds an
opt-in, version-identified `pressure_flow_v1` family and later other experimental
families with Water as a common test material. The
[LCB-000 Gate A record](../audits/2026-10-23-lcb000-gate-a-water-pressure-admission.md)
bounds that lane: unchanged defaults, no hidden fallback, no production #45
selection, no new pressure-to-Rapier forces, and the Current fixtures and #49 v2
controls held fixed. The later native implementations are accepted: PressureFlow and its variants,
Water/Brine InertialCellular, and their ordinary prepared application paths are
mapped in the [family policy](../architecture/liquid-solver-family-policy.md).
Pressure Worlds add overfill, signed flow and World-owned gas compartments;
FreeMass `transfer_water` refuses there rather than silently acting as a fallback.
The native quantity ledger distinguishes visible, overfill and in-flight Water.
These additions do not select a generic #45 mechanism or accept every historical
#12 hybrid objective.

**Historical admission evidence:** LCB-000 Gates A–E passed and #213 closed on
24 October 2026. The [design checkpoint](../reference/status-and-roadmap.md#liquid-comparison-build-design-checkpoint--2026-10-23),
[policy foundation](../reference/status-and-roadmap.md#lcb-001-policy-foundation--2026-10-24)
and [bounded implementation decision](../reference/status-and-roadmap.md#lcb-001-pressure-reference--2026-10-24)
preserve the original permissions. Their “unmerged pressure branch” and
“inertial not implemented” descriptions were later superseded by accepted
source; they do not describe availability at `00cdb02f`. The initial admission
itself made no production-default, carrier, full-replay or general streaming
change. The later Wave gameplay profile is a separately identified transition.

## Coherent emission and surface adhesion

**Scope: the original FreeMass kernel.** Other families own their corresponding
coherence, saturation and film rules; the Wave guide documents its derived film
adhesion and spill behavior.

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
wake, and boundary crossings. Current native quantity ledgers additionally book explicit Water sources/sinks
from edits, generation, events, kernels and registered reactions, with overfill
and in-flight terms where enabled. That bookkeeping does not claim universal
physical mass conservation across all species or change legacy chemistry.

For the original FreeMass fixture, use `World::content_hash()` to observe rest: it includes material/state/
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

Wave exact physical save/restore is refused. A Workbench authored Save or
material-only Flatten reconstructs a starting layout, not Wave flux, in-flight
parcels, temperature or complete physical state. The [save contract](../reference/level-saves-and-replay.md)
separates these formats and current CYPS versions.

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

**Current:** bounded native Water source/sink accounting exists. **Planned:**
general application replay capture, broader source/mass-return interfaces, and
complete cross-family mirrored/edge acceptance. **Deferred:**
a general-purpose continuum fluid solver. `SimulationBackend::Buffered` is not
implemented; Wave's dedicated face-flux passes do not make that generic backend
available. Historical active-only buffered-flux proposals retain their own scope. **Rejected:** a competing liquid world, equivalent
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

## Current Water Feel Lab policy

**Current, experiment-only, 2026-09-12:** issue #19 adds an immutable World-creation
policy that emulates Water mass semantics from 3..8 bits and coherent emission
from 0..12 ticks in the existing superset carrier. Production/default Water remains
mass8/coherence12. The candidate setting is validated and applied only through a
fresh-world transaction at the desktop worker or Web main-thread owner boundary;
invalid application preserves the current World.

The policy, scenario/seed and provenance are normalized once for profile/config,
launch and panel selection. Four-level and oriented interface modes are derived
presentation and do not change mass, collision, waking or state hashes. The
[Water Feel Lab runbook](../operations/experiment-tower.md#current-19-water-feel-lab-extension)
and [dated evidence](../audits/2026-09-12-issue-19-water-feel-lab.md) own candidate
procedure and acceptance. This experiment neither repacks Cell nor allocates bits.
