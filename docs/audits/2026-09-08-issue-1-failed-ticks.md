---
title: Issue 1 failed-tick investigation and Windows acceptance
status: Current
document-kind: evidence
scope: Dated F01 source diagnostics, selected failure policy and rebuilt Windows integration; browser acceptance recorded separately
canonical-for: []
last-reviewed: 2026-09-08
related-documents: [../reference/validation-evidence.md, ../decisions/ADR-010-failed-tick-quarantine.md, ../architecture/simulation-tick-and-threading.md]
---

# Issue #1 failed-tick investigation and acceptance

## Intake and reproducibility

On 2026-09-08, both current GitHub issues were read through the authenticated
connector: [#1](https://github.com/techrote/cybersand/issues/1) and
[#2](https://github.com/techrote/cybersand/issues/2) were open, each with zero
comments. No remote mutation was performed. The two repositories were clean:
workspace `6a58311982941b75f46e22109a0829e5acb83c7e` on `codex/workspace-docs`,
source `bfac0bcad85a19673a82126d45d688ddf4aed22a` on
`codex/rag-docs-foundation`. Implementation is on local `codex/issues-1-2`.
The documentation baseline comes from this source history, not GitHub main.
No concurrent issue #3 task was visible in the task inventory at intake.

The preserved foundation probes were copied unchanged into
`C:/kybersand/validation/local/20260908-issues-1-2/` and compiled against this
checkout with Clang 23.1.0, C++20 `-O0 -g3`, 60-second compile and 10-second run
limits. Commands/results are `baseline-{interest_probe,tick_failure_probe}-*.json`
and matching logs. Both reproduced their original observations. Baseline
`dev.cmd native-test` passed 39 tests in 15.728 seconds. This broad pass did not
cover the defects; the new issue #1 regression then failed on repeated stepping
mutating a failed world (`issue1-red.log`). Historical probes/audits remain intact.

## Shared lifecycle and distinct mechanisms

| Stage | Observed implementation and relevance |
|---|---|
| Begin tick | Increment attempted identity/compact epoch; periodic epoch clear; reset changed flags |
| Events | Apply accepted explosions in queue order, stamping edits with this epoch; drain completed batch |
| Planning | Gather active chunks then phased core candidates, checking capacity before deduplication |
| Execution | Prepare each phase's write domain, execute jobs, barrier, merge observations; later phase preparation can fail after earlier movement |
| Finalization | Age quiet activity only on a successful path; source before issue #2 ages excluded blocks too |
| Publication | Separate owner operation; before F01 it could expose a failed partial world |
| Failure cleanup | Originally cleared only in-progress; F01 additionally quarantines World and rejects continuation/publication |

**Evidence of separate causes:** failure reproduces without any interest region,
and the frozen re-entry probe reproduces with no failures or explosions.
SerialInPlace also partially advances before active-chunk failure while ignoring
interest filtering. Thus the defects are adjacent, not one shared root cause.
They interact through event-induced activity/capacity, region-dependent planning
and skipped activity finalization on failure. Combined acceptance belongs to the
subsequent issue #2 checkpoint; this record does not claim it already passed.

## Chosen contract and implementation

The owner delegated issue #1's policy choice to engineering judgement. The chosen
[ADR-010](../decisions/ADR-010-failed-tick-quarantine.md) quarantines any failed tick
until explicit clear/reset or validated replacement, with no rollback or replay.
Attempted and completed tick identity are distinct. Raw reads retain diagnostic
partial state; ordinary output/save is withheld. Accepted events are never
resubmitted to the failed World. Explicit recovery abandons old events/state.

Native guards cover stepping, cell/temperature/obstacle writes, reservation and
dirty/publication retirement. The C API exposes additive failed/completed/clear
operations. Adapter first-error telemetry and false return remain explicit;
failed repeats do not inflate failure count. Desktop checks the result, publishes
status around its previous valid snapshot, rejects emissions, and stays alive for
reset. Main-thread Rapier stops on observing failure. Web stops synchronously and
suppresses output/painting regardless of pause toggles. Prior character/Rapier
work is not rolled back. Reset/level candidates prepare before replacement.

## Executed checks and artifact scope

- `dev.cmd doctor`: Python 3.12.14, SCons 4.10.1, LLVM-MinGW 20260826/UCRT
  Clang 23.1.0, Godot `4.7.stable.official.5b4e0cb0f`, Emscripten 4.0.20.
  Logs: `validation/local/20260908-220654/`.
- Both native/Web godot-cpp checkouts were clean at
  `101ae38034304346a46ea9ea84ae156d3e860496`. Separate binding trees and all pins
  were preserved. Existing local toolchain-drift override was recorded, not added.
- `mingw32-make test CXX=clang++ CC=clang`, 120 seconds: **42/42 passed**,
  `issue1-native.json`, 16.032 seconds. Includes event/no-event failures in serial
  and phased modes, previous success, completed identity, rejected continuation,
  explicit clear, late-phase partial progress, Sand conservation, retained leases,
  deterministic repeated failure and one/four-worker equality within phased mode,
  plus C ABI recovery. Serial multiworker construction remains unsupported.
- `dev.cmd native-build`, 3600 seconds: Windows x64 release `-O3 -DNDEBUG` DLL
  rebuilt using the pinned bindings. `validation/local/20260908-221438/` records
  the first build; final artifact identity is linked below.
- `test_tick_failure_regression.gd`, 180 seconds: adapter real capacity failures
  with/without accepted events at 1/4 workers; actual desktop Thread status/reset;
  Web controller stepping/publication on Windows. **Passed**, 1.717 seconds,
  `issue1-godot-owners-final.json`. No mocked tick error was used.
- `dev.cmd godot-test`, 240-second import/180-second runner limits: **16/16
  runners passed**, `validation/local/20260908-221756/godot-fixtures.json`.
  Existing rendering, Water, body/Rapier, save, Auto and worker comparisons ran.

Final source/local-delta fingerprints, rebuilt DLL hash, commands and checks are
curated in [issue #1 evidence JSON](issue-1-2026-09-08-evidence.json). This includes
post-review focused reruns. Generated libraries/logs remain local and are not
source commits; rebuild from the source checkpoint and retained pinned inputs.

**Limits:** this checkpoint's Web-controller execution used Windows Godot, not
browser WASM. The shared opt-in `?test=1&tickfault=1` probe is prepared for the
combined rebuilt Web validation. No current Linux/macOS/WSL or sanitizer pass,
Firefox/Safari, complete replay, production performance or arbitrary failure-site
coverage is claimed. Historical M11 identities are preserved; remaining checker
mismatches are recorded in the evidence JSON rather than rewritten.

## Canonical documentation checklist

| Checklist area | Updated canonical route / disposition |
|---|---|
| Source/recovery identity | This dated intake, local evidence JSON, source-checkpoint link and local implementation commit |
| Tick ownership/lifetimes | Simulation-tick, data-ownership and rendering/gameplay bridge contracts |
| Interface/configuration | C/adapter failure state, snapshot status, emission admission, capacity setting and save-recovery contracts |
| Invariants | TIME-002 and CAP-004; no invented transactional guarantee |
| Decisions | New ADR-010; ADR-003 publication and ADR-004 failed-region boundary |
| Status/user controls | Roadmap F01, handover, owner-intent delegated judgement, Material Lab/troubleshooting |
| Storage/activity | Existing F02 defect preserved at this checkpoint; failed-region boundary specified without claiming its fix |
| Build/tests | Test-selection inventory and shared real-adapter probe; pins, CI and toolchains unchanged |
| Retrieval | Manifest/new ADR, index routes, Q06/C01 expected facts updated with query wording retained |
| Evidence/history | Preserved original probes and audits, added red/green and integration evidence; no historical hash edits |
| Checks | Documentation structure, lexical retrieval plus affected-answer review, historical M11 and diff checks in evidence JSON |
