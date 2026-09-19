---
title: Testing, validation, and replay
status: Current
document-kind: guide
scope: Executable test selection and future gates; dated results and save format live in separate references
canonical-for: [test-inventory, test-selection, future-validation-gates]
last-reviewed: 2026-09-12
related-documents: [local-build-and-validation.md, ../reference/validation-evidence.md, ../reference/level-saves-and-replay.md]
---

# Testing, validation, and replay

## Which tests should a simulation change run?

**Current inventory:** [native/tests/test_world.cpp](../../native/tests/test_world.cpp)
contains 46 native tests at the coordinated issue #1/#2 checkpoint; [test_c_header.c](../../native/tests/test_c_header.c)
checks C11 header inclusion. The Godot directory has 16 `test_*.gd` runners at that checkpoint.
Counts identify this inspected source inventory, not a pass for a later revision.
[Build instructions](local-build-and-validation.md) give commands and timeouts;
[validation evidence](../reference/validation-evidence.md) gives dated results.

| Change | Focused executable coverage |
|---|---|
| Scheduler, storage, activity | Native geometry/non-overlap, signed/core/chunk crossings, stamps, repeat and one/four-worker parity, sleep/wake and capacity tests |
| Materials and Water | Native catalogue/radius, chemistry/state machines, Smoke lifetime/Fire exclusion, density exchange, conserved leveling/rest and one/four-worker fixtures |
| Explosion or optional fields | Native bounded event validation/queue/hash/parity, static-to-granular conversion and temperature allocation/movement |
| Immutable publication | Native slot capacity, dirty retention, deterministic patch order, lease concurrency/C lifetime; Godot native bridge and render-handoff fixtures |
| Presentation/material catalogue | Godot appearance LUT and presentation runners: catalogue rows, representative flair, HDR values, viewport/F3 behavior |
| Fallback cells/player | `test_cell_world.gd` has nine groups including Smoke, Water, body mask/sweep and vertical scan continuity; these are one runner |
| Rapier or coupling | Preflight, automatic drop-in, manual-step and `test_web_rapier.gd`; see [Rapier procedure](rapier-2d-migration-runbook.md) |
| Save, Web worker selection or benchmark | Demo-save, setup, Web worker parity, Auto and worker-benchmark runners; actual Web export must additionally execute in browser |

Use the test filenames in [godot/tests](../../godot/tests) for the exact current
inventory. No test name promises all combinations of materials, geometry or
platforms. Run the smallest relevant fixture while iterating, then the applicable
suite for the checkpoint. A source-backed correction may need a focused diagnostic
when an existing regression does not exercise the suspected path.

## What does equality establish?

Native repeat and worker-count fixtures use `World::state_hash()` for their
selected inputs; settled Water uses `content_hash()` plus exact mass checks.
Neither hash covers the entire coupled game's future. Their omissions and timing
semantics belong to [determinism](../architecture/determinism-and-boundary-transfers.md#replay-state-coverage).
CYSD1 and browser benchmark hashes compare serialized level payloads; body restore
uses a numeric tolerance. [Level saves and replay](../reference/level-saves-and-replay.md)
owns the format and omitted continuation state. Complete replay persistence and
a selectable strict runtime policy remain **Planned**.

## Required future validation

These are **Planned gates**, not executed pass lists:

- Cross every cardinal/core/chunk boundary, negative coordinate and relevant
  corner with shifted/mirrored fixtures; cover every rule radius and conserved
  transfer, and perturb worker completion order deliberately.
- Extend the Current partial-failure, owner-stop and reset fixtures to additional
  failure sites/platforms; rollback and retry of a partial World are Rejected.
  See [tick ownership](../architecture/simulation-tick-and-threading.md).
- Extend phased region regressions to future fields/materials and platform gaps.
  Current leave/sleep/re-entry, unchanged/overlap/disjoint and failed-recovery
  fixtures enforce the declared pause/wake contract; no catch-up is promised.
- Exercise just below/at/above each work/storage/snapshot capacity and a 2x
  region; test safe reconfiguration success/failure once that interface exists.
- Extend rectangle/thin-floor proof to intended shapes, high speeds, rotations,
  body counts and callback costs. Existing Rapier results are bounded fixtures.
- Capture complete configuration/input identity and durable replay state before
  claiming exact resumed trajectories or serialized hash compatibility.
- Run current Linux sanitizers, intended native architectures and target browsers;
  measure visual output and process-wide allocations separately from source counters.

## Checkpoint evidence

Record source plus runtime artifact identity before tests. A retained DLL may
pass while differing from today's source. Preserve command, timeout, platform,
profile, worker count, inputs, exit status and raw output under a dated local
evidence directory; put a scoped summary in the evidence ledger. Keep historical
failure/inconclusive records. Checksum verification cannot replace execution,
and headless scene execution cannot establish browser or visual acceptance.
Use the [documentation checklist](documentation-maintenance.md#documentation-update-checklist)
to synchronize every affected contract after a behavior change.

## Issue #1 focused regression

`test_tick_failure_regression.gd` uses the rebuilt adapter with a construction core
capacity of one, checks event/no-event faults at one/four workers, starts the real
desktop owner thread, and invokes the Web controller on Windows. The shared
`CyberTickFailureProbe` runs through the Web controller in browser with
`?test=1&tickfault=1`; require `tick_failure_test.ok=true`. This opt-in test does not
run on normal play URLs. Native tests additionally cover failure after an executed
phase, C ABI results, conservation, repeat/parity and immutable lease retention.

## Issue #2 and combined regressions

The same runner now also tests actual adapter re-entry at one/four workers, a
desktop owner leave/re-entry sequence after drained ownership handoff, and Web
controller resume. Browser `?test=1&tickfault=1` requires both
`tick_failure_test.ok` and `interest_region_test.ok`; frame yields between probe
world replacements let threaded browser workers recycle. Native source fixtures
cover negative/core/chunk boundaries, previously sleeping blocks, overlap/disjoint
moves, unchanged/equivalent/coalesced regions, neighbor wake, custom straddling
geometry, conserved Water/Sand, retained temperature, 1/4/4 state-hash equality,
and event/no-event capacity failure during re-entry followed by clear.

## Which checks support the measured physics baseline?

**Current, 2026-09-09:** the [dated issue #9 report](../audits/2026-09-09-physics-characterisation.md)
records 49 native tests and 19 Godot runners on a freshly rebuilt Windows adapter.
The earlier 46/16 totals above remain the dated #1/#2 checkpoint. New tests cover
bounded observer/worker parity, viscosity isolation, masked-source contact,
stored Water under a body mask, invalid diagnostic reset, duplicate application
and hard-floor controls. The asynchronous smoke runner is only 120 ticks by
default; the separate evidence series uses five seeds and 1,800 completed ticks.

Run [tools/physics/verify.py](../../tools/physics/verify.py) on the complete raw
series to check conservation controls, completed budgets, floor censoring and
matching-profile state/trajectory equality. See the
[runbook](physics-characterisation.md) for experiment commands and bounds.
Existing F01/F02, save, render ownership and meaningful conservation checks remain
required. No trace here upgrades CYSD1 into full deterministic replay.

## Granular interaction regression

**Current:** `test_interaction_policy.gd` runs the shared native/fallback player,
Mercury and powder/Water pair probe. Rebuild the adapter before execution.
`test_interaction_async.gd` exercises the production desktop owner for standing,
walking and excavation. Native tests cover all nine powders, support/packing,
all powder and liquid pair classes, alternate paths, deadlines, sleep/re-entry,
failure recovery, conservation and worker parity. Both actual Web profiles run
the shared probe plus F01/F02 via `?test=1&interaction=1`; the fixture yields at
native world construction/replacement/teardown to service browser pthreads.
Use the [dated issue #10 audit](../audits/2026-09-09-issue-10-granular-policy.md)
for exact passes and retained limits; source presence alone is not acceptance.


## Issue #13 experiment checkpoint

`test_experiment_tower.gd` checks shared recipe construction, safe landings, plugs, invalid-replacement preservation, exact reset and desktop owner single-step. `tools/physics/issue13.py` rebuilds fresh references. See [tower procedure](experiment-tower.md) and [dated issue #13 results](../audits/2026-09-09-issue-13-transport.md).

`test_transport_profiles.gd` validates versioned resolution, bounds, provenance,
round-trip and rejected replacement. `test_transport_probe.gd` runs the shared
24-case profile/sampling probe on native Godot; Web's `?test=1&transport=1`
runs the same probe plus actual controller failure/interest checks. Use
`tools/physics/serve.py` for the local write-once result collector.
`transport_matrix.py`, `transport_knobs.py`, `transport_permeability.py` and
`transport_report.py` retain fixed inputs and separate corrected measurements
from historical failures. Each case has a 180-second timeout. See the runbook
for reuse/source-identity and depth sample-count qualifications.

`tools/physics/water_leveling.py <raw-output>` rebuilds a fixed 24-case basin
screen (two widths, three signed translations, mirrored releases, one/four
workers). It records front arrival, column-mass spread, tick cost and exact mass.
When an open Windows editor locks shadow DLLs, `tools/physics/isolated_godot.py
<fresh-raw-output>` copies the project without its cache/tilde libraries and runs
import plus all Godot fixtures there. Its manifest hashes the copied inputs;
the original editor session and tilde libraries are left intact. Retain failed
original imports separately. [Water follow-up](../audits/2026-09-10-water-leveling.md).


## Opt-in transport profiles

**Current:** the [profile contract](../systems/flow-transport-and-profiles.md)
owns schema, inheritance, units, immutable native tables and explicit owner restart.
The Tower applies validated profiles through restart. Actual powder falls and
lateral Water mass transport drive bounded optional mixing and grain pickup;
horizontal sampling and cadence are separate fixed experiments.
Ordinary gameplay keeps Baseline; chemistry cadence, compact cells and CYSD1
are unchanged. No unsynchronized live descriptor mutation is introduced.

## Issue #19 Water Feel Lab validation

**Current:** native tests cover policy range/refusal, mass3..8 arithmetic,
mass4/6/8 correspondence, coherence0..12, exact conservation, repeat/worker
parity and unchanged mass8/coherence12 state hash. Godot runners cover normalized
selection surfaces/provenance, all 35 recipes, deterministic reset/actions,
owner-boundary transaction/rejection, blind lifecycle, RG8 authority and eight
presentation-model groups. The rendered-pixel runner must execute non-headless
because headless scene success is not visual evidence.

Actual Web acceptance requires exported compatibility and threaded builds served
with cross-origin isolation, then
`node tools/web/run_browser_probe.mjs <url> <profile> <output-directory>`.
The opt-in URL is `?test=1&water=1`; normal URLs do not run the probe. Require
`ok=true`, 70 scenario cases, 110 actions, zero failures, invalid/presentation
preservation, and equal catalogue/default hashes across profiles. See the
[dated result](../audits/2026-09-12-issue-19-water-feel-lab.md).

## Issue 12 standalone contract checks

Run `make soliding-test` for the lifecycle model and discovery journal;
`make soliding-sanitize` adds ASan/UBSan builds. Native CI runs both, using its
explicit leak-detection setting. They supplement the existing World suite and do
not validate real Rapier handoff or platform adapters. On Windows use the pinned
LLVM-MinGW runtime directory on PATH; a missing runtime DLL is an environment
launch failure, not a passed test. The [measurement contract](soliding-measurement.md)
separately pins the ordinary-sleep control and retains failed attempts.
