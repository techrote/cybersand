---
title: Testing, validation, and replay
status: Current
document-kind: guide
scope: Executable test selection and future gates; dated results and save format live in separate references
canonical-for: [test-inventory, test-selection, future-validation-gates]
last-reviewed: 2026-10-24
related-documents: [local-build-and-validation.md, ../reference/validation-evidence.md, ../reference/level-saves-and-replay.md]
---

# Testing, validation, and replay

The [completed local35-case plus import run](../audits/2026-10-25-lcb003-final-integration.md#complete-local-host-matrix-and-actual-web-result)
passes every actual process and the strict current003 result verifier on
functionale8f1d37b/DLL93d3ee3f. Separate [compat77/threaded76 actual Web tests](../audits/2026-10-25-lcb003-web-common-water.md)
qualify only the body-free6+4 functional apparatus/POST outcome. Rendered/manual
Web, body-bearing browser play, source-matched desktop publication and complete
programme acceptance remain separate; no test deadlines were weakened.

The [final application integration](../audits/2026-10-25-lcb003-final-integration.md)
retains every Water-IN and initial-capacity registration in the ordinary suite:
163 groups plus seven independently encoded receipt vectors pass locally.
Focused ASan/UBSan runs37 registered pressure/IN/Water/capacity groups plus the
retained head API group; they are not a full sanitizer/platform matrix. The
003 host profile requires import plus35 real cases with original finite budgets,
strict Water005 and actual structured body/native-family results. Exact-head
publication/browser/scientific gates remain separately required.

The subsequent [synchronous Water Feel body checkpoint](../audits/2026-10-25-lcb003-synchronous-water-reference-body.md)
at source45b6ed9d reuses verified unchanged native135/DLL79f35666 and passes
eight strict processes/656 assertions: new Water91, corrected PhysicsPit73,
WaterFeel72, import73, UI105, poses50, desktopWater75 and ordinary117. Each
uses its own180s timeout, complete source/project fences and strict exit/
error checks. Actual native readback verifies all threePF variants and FM;
the first label-only family coverage and other apparatus failures remain
preserved and are superseded only in their stated scope. No new DLL build
or final Wasm/release/Brine-contact/Water-IN acceptance is claimed. Before
arming003, integrate this new case plus the incoming strict Water005 proof
and final native/default sources into its still-unarmed publisher.

## Which tests should a simulation change run?

**Current inventory:** [native/tests/test_world.cpp](../../native/tests/test_world.cpp)
contains 46 native tests at the coordinated issue #1/#2 checkpoint; [test_c_header.c](../../native/tests/test_c_header.c)
checks C11 header inclusion. The Godot directory has 16 `test_*.gd` runners at that checkpoint.
Counts identify this inspected source inventory, not a pass for a later revision.
[Build instructions](local-build-and-validation.md) give commands and timeouts;
[validation evidence](../reference/validation-evidence.md) gives dated results.

| Change | Focused executable coverage |
|---|---|
| Semantic hierarchy and procedural routes | `make worldgen-test` / `worldgen-sanitize` include grammar ownership, identity, constraints, negative-region partitions, socket compatibility and final material clearance; `test_worldgen_grammar.gd` validates the copied Godot interface and declarative example. Source-matched Linux/Windows runtime and hosted acceptance remain separate. |
| Scheduler, storage, activity | Native geometry/non-overlap, signed/core/chunk crossings, stamps, repeat and one/four-worker parity, sleep/wake and capacity tests |
| Materials, Water and INT-000 interaction substrate | Native catalogue/radius, frozen pair-oracle equivalence, layer precedence/conflict validation, chemistry/state machines, Smoke lifetime/Fire exclusion, density exchange, generated schema-2 interaction fixtures, conserved leveling/rest and one/four-worker fixtures |
| Explosion or optional fields | Native bounded event validation/queue/hash/parity, static-to-granular conversion and temperature allocation/movement |
| Immutable publication | Native slot capacity, dirty retention, deterministic patch order, lease concurrency/C lifetime; Godot native bridge and render-handoff fixtures |
| Presentation/material catalogue | Godot appearance LUT and presentation runners: catalogue rows, representative flair, HDR values, viewport/F3 behavior |
| MAT-002 catalogue integration | `test_building_material_integration.gd`: all 51 new IDs through native construction and saves, metadata, fill/count diagnostics, four-face histogram stride and sampled-rig digging occlusion; native snapshot and exhaustive pair/transport regressions |
| Standalone physics CLI | `make physics-characterisation-test` / `physics-characterisation-sanitize`: actual executable admission and parsed sample accounting for all 51 building IDs in both layers, old controls and invalid wide inputs; [measurement-path contract](physics-characterisation.md#which-checks-guard-the-measurement-path) |
| Fallback cells/player | `test_cell_world.gd` has nine groups including Smoke, Water, body mask/sweep and vertical scan continuity; these are one runner |
| Rapier or coupling | Preflight, automatic drop-in, manual-step and `test_web_rapier.gd`; see [Rapier procedure](rapier-2d-migration-runbook.md) |
| Player movement and material fields | Native `player material field` groups plus binding, vehicle, acrobat planner/real-physics and seven-preset runtime/UI runners; [focused commands](local-build-and-validation.md#player-playground-checks) separate material conservation/admission from physical motion and input lifecycle |
| Save, Web worker selection or benchmark | Demo-save, setup, Web worker parity, Auto and worker-benchmark runners; actual Web export must additionally execute in browser |

Use the test filenames in [godot/tests](../../godot/tests) for the exact current
inventory. No test name promises all combinations of materials, geometry or
platforms. Run the smallest relevant fixture while iterating, then the applicable
suite for the checkpoint. A source-backed correction may need a focused diagnostic
when an existing regression does not exercise the suspected path.

## CI execution sharding

Linux hosted GDExtension validation may execute the current Godot suite as four
isolated shards after a single verified runtime build. Sharding is an execution
schedule only: automatic `test_*.gd` discovery, both explicit profile probes and
scene startup remain in the suite, every non-import case must occur exactly once
across the four shards, and every shard performs its own import preflight. A failed
shard fails the aggregate Linux gate while the remaining shards continue to retain
evidence.

The deterministic planner records the complete assignment and per-case timings.
Approximate weights are scheduling hints from dated CI evidence, not acceptance
limits. The initial migration checkpoint executed the unsharded suite against the same
source/runtime artifact and proved exact case coverage equivalence. The serial lane
is retained as an explicit opt-in diagnostic, while ordinary PR validation uses the
four isolated shards.

Every discovered `test_*_render.gd` case requires a display and executes with the
OpenGL compatibility renderer. Linux CI provides Xvfb and Mesa software rendering;
logic cases and import retain `--headless`. An explicit skip, missing display or
executable, timeout, nonzero exit, or engine/script error fails the applicable
case. An exit code of zero alone cannot satisfy the gate. Pixel assertions are
rendered-output evidence for the recorded software backend, not target-GPU
performance evidence.

`--keep-going` retains outcomes for all assigned cases after an ordinary test
failure; an import failure still stops that shard because the project could not
be prepared. `timings.json` records the executed command, display requirement,
skip/error details, completion state and aggregate status. The planner and runner
regressions execute child processes to check failure, timeout, skip and
continuation handling as well as exact discovery and assignment.

The separate GitHub-hosted Windows lane runs import and every applicable headless
case against the retained Windows DLL, after verifying the committed LFS bytes,
provenance and complete current native-input set. It uses the same discovery,
per-case timeouts and strict failure semantics, continues after individual case
failures, and records graphical cases as explicitly outside its scope. Its
`windows-execution.json` includes exact case coverage, tool/source/runtime
identities, commands, log hashes and drift/completion checks. The
[Windows execution procedure](local-build-and-validation.md#windows-retained-runtime-execution)
owns the job bounds and artifact route. This actual execution gate and the
separate Windows cross-build check must retain their distinct evidence scopes.

## Physical regression timeout diagnostics

**Current apparatus for #233:**
[`run_godot_regressions.py`](../../tools/ci/run_godot_regressions.py) keeps the
ordinary physical test limit at 180 seconds. A timeout always fails, including
when diagnostics fail or the process exits during evidence collection. Before
killing the process tree it retains the last 60 log lines and attempts bounded
process/thread evidence. Windows records process ancestry and individual thread
state/wait reasons without requiring a debugger. Linux records process/thread
wait channels and attempts a bounded GDB backtrace; missing debugger or ptrace
refusal is explicit evidence. Full logs remain alongside the bounded excerpt.
`seconds` excludes diagnostic/kill overhead, recorded separately as
`diagnostic_seconds`. Coarse fixture markers identify the last emitted phase,
rig/model and tick; they do not identify an exact blocked instruction.

**Current #234 guards:** the independent runner-side
[progress watchdog](../../tools/ci/physical_progress_watchdog.py) requests live
capture after 30 seconds without a new main-thread marker and fails at 45 seconds
idle. Capture runs independently, so a slow or failed debugger cannot extend that
failure deadline. The 180-second outer case limit remains authoritative for all
execution; startup before fixture instrumentation and engine shutdown after quit
remain covered. Both original `REGRESSION_PROGRESS` case/phase/rig/model/tick
records and coarse `CYBERSAND_PROGRESS` heartbeat records are retained. Only real
marker/sequence changes renew liveness; unrelated output or timestamps alone do
not. The heartbeat's cumulative `steps` is distinct from a fixture's physical tick.

A fixture-only [internal observer](../../godot/tests/helpers/physical_internal_watchdog.gd)
adds a 120-second whole-fixture deadline on a separate Godot thread. It uses
monotonic time and copied mutex-owned context, calls no scene-tree, World or
Rapier API, and emits sticky `ERROR: REGRESSION_WATCHDOG` on expiry. Completion
cannot turn an expired deadline into a pass. Stop polls for at most one second
and joins only an already-finished thread. It does not self-kill before evidence
capture; the external monitor bounds a permanently blocked main thread. Startup
before arming, process-wide runtime stalls and post-disarm engine shutdown remain
external-monitor responsibilities. The [actual-Godot blocked-main probe](../../tools/ci/test_physical_internal_watchdog.py)
checks independent expiry during a synchronous main-thread delay, sticky failure,
normal completion and clean join. The [#234 ledger](../audits/2026-10-24-issue-234-physical-hang-repair.md)
owns exact source/platform results, completed ordinary admission and fresh
qualification. No automatic retry
or required-test skip is admitted.

The ordinary GDExtension timing job retains actor/usable/flight observations and
per-platform median, nearest-rank p95, maximum and failure frequencies. Record
the checkout SHA in the artifacts as well as the workflow head SHA: ordinary PR
jobs can execute GitHub's synthetic merge checkout. Missing or ambiguous timing
must remain qualified. A passing rerun never replaces a preceding timeout.
For a `progress_watchdog` timeout, `seconds` is process elapsed time when 45 idle
seconds are detected, rather than a fixed 45-second duration. Compare it with
#233's 180-second full-deadline observations using that detection difference.
An internal guard error can produce an ordinary failed result rather than a
timeout; preserve both outcome classes.

The dispatch-only
[`physical-timeout-stress.yml`](../../.github/workflows/physical-timeout-stress.yml)
requires an immutable source SHA and uses GitHub-hosted Windows Server 2022 and
Ubuntu 24.04. For each platform it runs serial and three-process parallel modes,
with five batches of ten repetitions of `test_physical_actor_arena`,
`test_physical_actor_rigs` and `test_physical_usable_course`: 600 physical attempts
plus 20 import preflights. Each attempt has isolated writable user and temporary
state. Process parallelism does not select CyberSand's native worker count.
The independent reducer binds all batches to the declared source, workflow run
and attempt, checks runtime consistency, preflight and every expected repetition,
and retains failures, missing attempts and malformed evidence. A physical timeout
fails the stress gate and is still a valid diagnostic observation. An invalid
campaign must be preserved and corrected through a reviewed PR before a complete
new campaign; successful batches from different campaigns cannot be combined.

The [dated #233 audit](../audits/2026-10-24-issue-233-physical-regression-timeouts.md)
owns actual run IDs, historical failures, distributions and causal limitations.
**Current diagnostic disposition, 2026-10-24:** #233's deliverable is complete
after apparatus admission and the full source-bound campaign. Captured progress
and process/thread state establish intermittent roster stalls, while the causal
mechanism remains unclassified within that campaign because it captured no native
stack. Its Windows reproductions do not erase retained historical Linux failures.
The separate [PR #236 stack/paired record](../audits/2026-10-24-physical-actor-bvh-validation.md)
confirms the deferred-BVH receive/outer latch path and supports the cooperative
join selected in the merged #234 repair. Its 300-candidate comparison has its
own immutable scope. The integrated PR #236 head passed exact-head ordinary gates;
fresh standard campaign `40129364630` at merge source
`13b8e631f3e8fbaa2176ed41afc02c434b11e558` completed 600/600 physical passes,
0/600 timeouts, zero other failures and 20/20 import passes. All twelve
OS/mode/test strata passed 50/50; the independent hosted gate and raw readback
agree. Serial and parallel frequencies are both zero in this experiment;
parallel process load still changes timing, and native-worker count was not
varied. The registered workload qualifies the exact Windows/Linux x86_64
artifacts without proving absence of every possible hang or the precise
scheduler trigger. The [#234 audit](../audits/2026-10-24-issue-234-physical-hang-repair.md)
owns distributions, prior failures and limits; route actual issue disposition through
[#234](https://github.com/techrote/cybersand/issues/234) and
[#232](https://github.com/techrote/cybersand/issues/232).

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

## INT-000 intermaterial interaction validation

**Current:** `native/tests/test_world.cpp` retains a literal frozen copy of the
pre-migration 14-rule compact pair oracle and compares it against the versioned
resolver over every pair of IDs 0–80, both orientations and twelve
probability-boundary samples. Separate MAT-002 checks cover each new rule in both
roles across all 256 roll values and the derived partner prefilter across the
full 256×256 byte-ID domain. The same regression checks layer precedence/conflict
handling, explicit semantic family non-inheritance, and matching that is ordered,
symmetric or unordered with role-preserving effects. Specialized neighbourhood/
lifecycle mechanisms remain in their existing `world.cpp` kernels and are
represented/provenance-visible rather than duplicated.

`test_microscenarios.gd` validates the native interaction profile/workbench
provenance, rolling kinetic/contact baseline identity, deterministic repeat and
one/four-worker semantic parity for the generated proof fixtures.
`test_microscenario_materials_lab.gd` retains complete-definition GUI/headless
identity, declared observations, source/sink accounting and transactional invalid
replacement across every Materials Laboratory preset, including eventless INT-000
mechanism fixtures.

For retained batch evidence, run:

```text
python3 tools/interactions/batch.py --godot <godot> run --source-sha=<40-hex-sha> --workers=1,4 --output=<directory>
python3 tools/interactions/batch.py compare <baseline-manifest.json> <candidate-manifest.json> --output=<comparison.json>
```

The batch driver delegates fixture construction/execution to schema-2 Godot. It
fails on worker-semantic drift, preserves source/runtime/transport/Water/execution
baseline identity, reports explicit coverage gaps and lists stable-ID
rule/layer/pass fields changed between retained manifests. A comparison difference
is review evidence, not an automatic tuning decision. Windows cross-build success
is not Windows execution; browser/WebAssembly and target-GPU acceptance remain
separate unless a dated run records them.

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

The existing [controller regression](../../godot/tests/test_water_feel_controller.gd)
also exercises desktop Water exit receipt ordering: a previous rejection or
success must not acknowledge a newer reset, and a matching rejection must preserve
the blind session. The deterministic receipt control complements the live
desktop worker and synchronous Web-controller cases in that runner. Execute it
with the pinned Godot runtime using
`--headless --path godot --script res://tests/test_water_feel_controller.gd`;
the hosted case timeout is 180 seconds. Record script errors and nonzero exits
as failures. The [2026-10-22 correction evidence](../audits/2026-10-22-water-exit-acknowledgement.md)
preserves the Windows scheduling failure rather than treating a later rerun as
proof that no defect existed.

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
