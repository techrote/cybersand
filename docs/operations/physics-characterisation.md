---
title: Reproducible physics characterisation
status: Current
document-kind: runbook
scope: Opt-in physics measurement tooling, historical issue 9 baseline and current interaction regression routes
canonical-for: [physics-measurement-tooling, physics-baseline-procedure]
keywords: [powder, Mercury viscosity, barrel depth, masked source, contact impulse, diagnostic, fixture]
last-reviewed: 2026-09-13
related-documents: [physics-characterisation-plan.md, ../architecture/rigid-body-and-cellular-coupling.md, ../systems/materials-and-rule-kernels.md, ../audits/2026-09-09-physics-characterisation.md]
---

# Reproducible physics characterisation

## What is measured, and what remains a proposal?

**Current tooling:** issue #9 introduced deterministic fresh-world fixtures,
construction-only diagnostic variants and bounded counters. That checkpoint left
production behavior unchanged. Issue #10 subsequently implements the
[granular/player policy](../systems/granular-interaction-policy.md). Issue #11 now
uses that policy for bounded ordinary rectangle bearing while Rapier scene settings
remain unchanged. The
[dated report](../audits/2026-09-09-physics-characterisation.md) identifies actual
source/artifact/platform results. The [plan](physics-characterisation-plan.md)
still owns proposed soliding and broader physics investigations.

**Current within the issue #11 ordinary envelope:** 8x14 mass-1 barrels embed and
establish persistent yielding bearing within `0.5H + 1 cell` and at most one cell
late descent. Excavation removes that bearing. These are measured acceptance
limits, not hard simulation clamps; floor-supported rest still does not prove
granular equilibrium.

## How do I reproduce a run?

Work in `C:/kybersand/source`; keep raw files under
`C:/kybersand/validation/local/<date>-physics/`. Build the adapter with
`C:/kybersand/dev.cmd native-build` before Godot measurements. The Python runner
builds its own native CLI by default; `--skip-build` requires an identified,
source-matched executable. The installed Godot DLL is not rebuilt by `godot-test`.

```text
C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py native --group expanded --output C:/kybersand/validation/local/2026-09-09-physics/native-expanded
C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py native --group controls --output C:/kybersand/validation/local/2026-09-09-physics/native-controls
C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py godot --group controls --output C:/kybersand/validation/local/2026-09-09-physics/godot-controls-final
C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py godot --group expanded --output C:/kybersand/validation/local/2026-09-09-physics/godot-expanded
C:/kybersand/.local/python/Scripts/python.exe tools/physics/run.py godot --group finalists --seeds 20 --ticks 7200 --output C:/kybersand/validation/local/2026-09-09-physics/godot-creep
```

[run.py](../../tools/physics/run.py) records commands, fixture JSON, actual HEAD,
dirty status, source-file hashes, executable hashes and platform in each result
directory. New Godot batches also capture their own manifest. A seed is a
coordinate translation, **not a new engine random stream**. The checked-in
generator plus explicit configuration is the replay input; CYSD1 is not used.
All runs start with newly constructed authority. Do not edit sources between
batches; preserve each tested source snapshot if iterating.

Defaults are five seeds `0..4`, 1,800 completed ticks, `dt = 1/60 s`. Finalists
use seeds `0..19` and 7,200 ticks. The separate interpreted fallback defaults to
one seed/180 ticks, overridable with `--fallback-ticks`; it is a semantic reference
with no native Water-mass or rule-event parity claim. Timeouts are 180 seconds per
native CLI run, 300 for its build, and 3,600 per Godot batch. A failed run retains
its output; it must not be counted as completed evidence.

## What are the exact fixture geometries and schedules?

The generators are the executable specification. Coordinates are cells/pixels,
y increases downward, and rotations use radians.

| Family | Construction and schedule |
|---|---|
| Native P1/P2 | `left=64+3*seed`, interface `y=96+(7*seed mod 20)`, upper layer 16 cells, lower layer 16/32/64, width 32 (one-cell viscosity control also available). Closed side walls, ceiling y=0 and floor immediately below the lower layer. Pure transport has no injected heat, explosion or input. |
| Native variants | Both orders of all nine powder materials; representative holes/slope/granular Stone/unsupported variants. Hole predicate `(17*x+31*y+13*seed) mod 11 == 0`; slope offsets `floor((x-left)/4)`. Saturated pores contain Water. Open-side bed has 16 empty columns on either side inside the containment box. |
| Native P5/P6 | Exclude at tick 120 and re-enter at tick 600; separate excavation opens eight floor cells at tick 600. Serial remains a distinct reference and ignores interest regions. Excavation counts are a finite ROI, so escaped material is not destruction evidence. |
| Godot P3/P4 | `left=96+3*seed`, surface `y=192+(7*seed mod 20)`, width 96, bed depth 384. Ceiling/side walls and deep hard floor; a separate one-cell hard-floor control is at the initial surface. Native simulation interest encloses the whole fixture. |
| Player | 8×14 sampled character, starting bottom 14 cells above the bed. Stand/fall, alternate horizontal input every 120 ticks, slope, side tower, one-cell film, enclosed spawn, interior-only obstruction and falling sheet. Enclosed and interior cases distinguish perimeter sampling from full-volume recovery. |
| Barrel | Independent fresh Rapier space, 8×14 baseline, mass 1, gravity scale .094, linear/angular damping .15/.35, friction .78, bounce 0 and cast-shape CCD. Drops 0/1/4/8 body heights; one-at-a-time mass, orientation and size variants. Fixed steps advance Rapier, copy a body sample, prepare cells, tick cells, then apply that sample's result. |
| Coupled P5/P6 | Excavate a 32-cell-wide column at tick 600; exclude at tick 120/re-enter at 600; seeds cross chunk/core/activity seams. A fixed ten-slot ring supplies sample delays 0/1/2/4/8/9. Duplicate delivery invokes the existing bridge deduplication. |

Deep beds put the floor more than 27 baseline body heights below the original
surface. Any body reaching `floor-1 cell` is explicitly **floor-censored**:
late creep becomes null, and pre-floor impulse totals are retained. The 120-second
baseline cannot establish long-term granular rest after reaching that floor.
The diagnostic contact-off candidate provides an uncensored long-duration case.

Depth uses `H=abs(cos(theta))*height+abs(sin(theta))*width` and
`max(0, centre_y+H/2-initial_surface_y)`. Local depth uses the median first occupied
cell in four columns outside each projected side, searching from surface-16 to
the floor. This intentionally separate, noisy surface estimator can include
ejected grains; it never replaces the original datum. Overlap samples rasterize
the rotated rectangle against **stored** materials. Player foot materials are
additional occupancy probes; snapshot overlap/contact lists are sampled at 1 Hz,
not an exhaustive collision trace. Peak depth is evaluated every completed step.

## What does the bounded instrumentation count?

[physics_diagnostics.hpp](../../native/include/cybersand/physics_diagnostics.hpp)
uses 256 fixed histogram slots per prepared phased job and 8,192 total slots per
observed World. Storage is allocated at construction only when enabled. Slots
aggregate integer counts; full tables drop observations and increment overflow.
They do not drop simulation work. Workers write only their job-local counters;
the coordinator merges after existing barriers. No random draws, new movement
ordering, per-cell locks or per-cell text output are introduced. Overflow must
be zero before interpreting totals as complete.

Keys encode `kind<<24 | source<<16 | target<<8 | direction`, with direction
`3*(sign(dy)+1)+sign(dx)+1`. Event kinds are:

| Kind | Meaning |
|---|---|
| 1 | Whole-cell movement into Empty, using stored source/target materials |
| 2 | Density-authorized swap, using actual stored material pair |
| 3 | Material-changing rule write; includes pair chemistry, birth/death and other kernel conversions, not transport or setup |
| 4 | Water transfer **mass units**, not whole-cell moves; target is Empty or Water |
| 5 | Rejected movement, stratified by attempted material pair and direction; no inferred unique opportunity count |
| 6 | Whole stored-cell relocation outside tick, used by body displacement |
| 7 | Body-contact attempt, with the kernel-visible source material; target 0 is a sentinel for body occupancy, not an Empty-cell movement |

**Historical issue #9 source nuance:** `update_cell` dispatched from the stored
cell, while `update_rule_kernel` read `get()`. A retained grain underneath a body could
run a powder kernel with Wall as its visible material. Wall-labelled contact
attempts can come from these masked grains. The dedicated native characterization
records three downward attempts/raw y=4800 from one retained Sand grain. This is
a baseline finding for #11, not a production fix or ordinary hard-terrain
collision. In coupled fixtures, a density decision can likewise use the proxy
while the swap counter records the actual stored pair. Pure unmasked P1/P2 fixtures
separate that effect from material density exchange. **Current issue #11:** rule
dispatch carries the authoritative stored source material explicitly and defers a
masked source to bounded overlap reconciliation; the regression retains the Sand
and occupancy mask without proxy-derived contact.

Per-material counts and Water mass are scanned outside ticks in a bounded ROI.
Water uses `stored_state_a`, including unresolved body overlap; ordinary
`liquid_mass()` hides masked cells and is unsuitable for this conservation probe.
Rule conversions are accounted separately; chemical consumption/production is
not claimed to conserve the Water material. Closed pure Water controls must
conserve stored mass exactly, even if the occupied-cell count changes.

**Historical issue #9 accounting limit:** the barrel could eject Water across a thin hard
floor, outside the crop. Set `conservation=true` on a native fixture to scan four
bounded 512×512 quadrants before/after the run and report global Water mass plus
Water below the floor. The five-seed control conserves global mass exactly and
matches the ordinary fixture's state/trajectory; the cropped deficit is below
the floor. `find_ejection_target` validates the empty endpoint without a path
barrier test. This is body displacement, distinct from liquid density exchange
and Rapier body tunnelling. **Current issue #11:** bounded half-cell path checks
reject intervening hard terrain and other body masks; unavailable routes retain
the complete source payload and report unresolved overlap.

## Which variants are isolated from production defaults?

`WorldConfig.physics_diagnostics` is immutable construction configuration:
`enabled=false`, `disable_powder_exchange_targets=false`,
`mercury_viscosity=-1` (use descriptor). The target switch denies exchange into
any powder, including gas/liquid interactions; it is a causal control, not a
recommended global policy. The viscosity override changes the existing lateral
gate only. Values are never written into shared material descriptors.

The adapter's explicit `diagnostic_reset(options)` constructs an empty World and
can select `workers`, `serial`, `telemetry`, `exchange_off`, `viscosity`,
`displacement`, `boundary`, `contact`, `cap`, and `density_limit`. Issue #10 adds
`support_cells` and `mercury_period` construction settings; see the
[policy bounds](../systems/granular-interaction-policy.md). Defaults are the
production values `.18/.19/.025/3/1.6`; gain bounds are 0..16, cap positive,
density limit at least .05. Mercury accepts -1 or 0..255; workers 1..32 (compat Web
requires one). A normal demo reset restores diagnostic options/gains to defaults.
The density-limit override affects displacement/boundary terms; native contact
density still has its own fixed 50..1600 clamp. It is not a global density change.

### Does Mercury viscosity slow measured downward penetration through packed Sand?

**Historical issue #9 measurement, 2026-09-09:** viscosity 96/160/224/248 produces identical confined
vertical state hashes and 32-tick breakthrough through the 32-cell Sand bed.
The one-cell-column control removes lateral-flow ambiguity. The exchange veto
prevents that penetration, but is not an approved pair permeability rule.
Use the [dated source/artifact evidence](../audits/2026-09-09-physics-characterisation.md)
for seed budgets and platform scope. **Current issue #10:** the independent
30-tick lane gives 960-tick canonical breakthrough; see the
[versioned policy](../systems/granular-interaction-policy.md) and its fresh evidence.

### Does a barrel stopped at the bottom prove half-depth granular support?

No. Measure from the pre-impact surface and separately from the deformed local
surface. A barrel reaching the deep hard floor has a censored creep result;
floor-supported rest does not prove granular bearing. The measured contact-off
candidate avoids ordinary baseline descent but still exceeds the provisional
half-depth impact gate. Its 20-seed creep, drop and excavation results belong to
the [dated report](../audits/2026-09-09-physics-characterisation.md), not a promised
production support invariant.

### What do the snapshot and body rows contain?

`diagnostic_fill_rect` is allowed only on a healthy diagnostic fixture. It writes
bounded in-world rectangles through normal cell-state operations. Setup is
executed outside assertions so release Web builds construct the same fixture.
`diagnostic_snapshot` returns copied value data for at most 512×768 cells plus
counts, hash, completed/attempted ticks, activity/chunk/core usage and optional
histogram. These APIs require the ordinary exclusive World owner.

`diagnostic_body_metrics` returns at most 16 rows: body ID, sample serial,
displacement x/y, boundary x/y, pixel-contact x/y, accumulated capped x/y,
pre-final-cap x/y, intermediate-cap count, final-cap flag, displaced count,
unresolved count and 324 boundary-contact bins (world-axis N/E/S/W × 81 materials).
Issue #11 appends raw bearing x/y and accepted support-sample count to that
diagnostic row.
The ordinary nine-float result ABI is unchanged. Bridge `enable_diagnostics()`
allocates six application values per body: age, accepted impulse x/y, duplicate,
stale and received flags. Arrays reset per application; the fixture aggregates
them outside kernels. Displaced/unresolved totals count repeated observations,
not distinct cells.

## How are platforms, timing and visual evidence separated?

Native CLI serial/phased runs, Godot native manual stepping, interpreted fallback,
desktop asynchronous ownership and real Web compat/threaded are separate series.
The test-only [async owner subclass](../../godot/tests/physics_async_worker.gd)
uses the production worker loop and stores at most `(ticks+1)*12` scalar values.
Only its owner reads native observations; the main thread reads the retained
trace after join. Rapier stays main-thread owned. Actual completed cellular and
Rapier ticks/sample ages are reported independently.

```text
Godot_v4.7-stable_win64_console.exe --headless --path C:/kybersand/source/godot --script res://tests/test_physics_async.gd -- C:/kybersand/validation/local/2026-09-09-physics/desktop-async-final 1800 5
```

Rebuild Web modules with `dev.cmd web` and `dev.cmd web --profile threaded`.
After script-only changes, re-export those identified modules. Serve each export
with [serve.py](../../tools/physics/serve.py), which binds loopback, supplies
isolation headers and accepts one result of at most 8 MiB into the named output
directory. Open `?test=1&physics=1` in an actual browser: five seeds each of P1,
P2, player/Dust, barrel/Sand and hard-floor control. The DOM exposes completion;
the optional local collector preserves full results and browser identity.
`ok` means execution/construction/control checks completed; issue #11 fixture
assertions separately enforce its documented ordinary envelope. The probe leaves the menu visible and does
not constitute gameplay visual acceptance.

Tick times include the native adapter call. Coupling timings cover pre-tick
Rapier step, sample packing and overlap/pressure preparation (player stepping in
P3); result application and snapshot analysis are outside this timing interval.
Report p50/p95/max with that scope. These development runs can overlap other test
processes; their timings are observations, not a production frame-time budget.
No new torque or substep model is implemented. Current permeability and player
settings, and the support predicate consumed by rectangle bearing, belong to the
versioned granular policy.

[analyse.py](../../tools/physics/analyse.py) produces per-run CSVs and standard
Matplotlib PNGs from raw data. Overlays show stored cells, the projected rectangle,
overlap pixels and world-axis inward face-normal directions. Arrows indicate
geometry, not reconstructed force magnitude or live contact positions. They are
rendered evidence from recorded simulation states, distinct from a gameplay
screenshot or video acceptance pass.

## Which checks guard the measurement path?

Run `dev.cmd native-test` and `dev.cmd godot-test` after a fresh native build.
Coverage includes exact native cell/state and histogram parity, diagnostics
enabled/disabled comparisons, Mercury confined vertical controls, explicit
histogram overflow, masked-source characterization, stored Water under masks,
invalid-reset preservation, exact coupled trajectories with one/four workers,
duplicate suppression and hard-floor control. Existing failed-tick quarantine,
region re-entry, conservation and render ownership fixtures remain required.
Use the [dated report](../audits/2026-09-09-physics-characterisation.md) for actual
passes and remaining platform/fixture gaps; do not reuse earlier test totals.

[platforms.py](../../tools/physics/platforms.py) reduces the actual browser/async
JSON and copies their captured runtime identities into the curated output.
It expects `runtime-checkpoint/manifest.json`, `desktop-async-final/provenance/manifest.json`
and the named raw platform result folders. The
[Water accounting JSON](../../tools/physics/water-accounting.json) is directly
accepted by `test_physics_characterisation.gd`; construct its output directory,
capture a fresh manifest and pass those two paths after Godot's `--` separator.

Run [verify.py](../../tools/physics/verify.py) against the complete named raw
series before publishing reduced results. [capture.py](../../tools/physics/capture.py)
retains source deltas, new fixture files, dependencies and artifact hashes before
standalone/async/browser runs. The async CLI and trace allocator reject horizons
outside 1..7,200 ticks and the CLI rejects seed counts outside 1..20. Construct
the output directory before invoking Godot directly. Generator/default budgets
remain distinct from production worker, terrain and gameplay queue capacities.

## How do I reproduce issue #10 acceptance?

Build the current DLL with `dev.cmd native-build`. Rebuild/run the native expanded
matrix with `tools/physics/run.py native --group expanded --output <raw>/native-expanded`.
Then run `tools/physics/issue10.py permeability --output <raw>/permeability`,
`issue10.py pairs --output <raw>/pairs` and `issue10.py player --output <raw>/player`.
The first two require the identified source-matched CLI from the expanded build;
player requires the identified rebuilt adapter. New batch manifests identify each
input snapshot. Keep `<raw>` below `C:/kybersand/validation/local/`.

`test_interaction_policy.gd` covers both adapters. `test_interaction_async.gd`
records the production desktop player owner; passing an output filename retains
its fixed trace. Both Web profiles expose `?test=1&interaction=1`, executing the
shared player/Mercury/Water/powder probe plus F01/F02 in the actual browser.
Serve final exports with `serve.py` and retain each result in a separate output
folder. `analyse_issue10.py <raw> <curated>` checks/reduces the complete named
series; the [dated issue #10 evidence](../audits/2026-09-09-issue-10-granular-policy.md)
records the exact scope, version decision, failures and publication limits.
Use `--browser-suffix` and `--async-result` to select separately retained final
reruns, rather than overwriting earlier browser or owner traces. Final acceptance
also verifies invalid construction options preserve authority and ordinary demo
reset restores the compiled support/permeability defaults.
