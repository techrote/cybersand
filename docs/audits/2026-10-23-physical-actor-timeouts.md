---
title: Physical actor intermittent timeout investigation
status: Current
document-kind: audit
scope: Physical actor Godot hang evidence, runner diagnostics and repeated hosted experiments
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../operations/local-build-and-validation.md, ../systems/physical-actor-rigs.md, ../architecture/simulation-tick-and-threading.md]
---

# Physical actor intermittent timeout investigation

The subsequent [break handover](2026-10-23-physical-actor-timeout-handover.md)
records completed hosted campaigns and gate results observed at 20:22:47 UTC,
including Windows timeout frequencies and valid second-campaign minidumps.
Earlier queued/in-progress observations below are retained historical checkpoints.
The root cause and a repaired zero-timeout campaign remain unresolved.

## Intake and recoverable source

Investigation starts from fetched main `1f9336388f11be39abaae340a781a5eef52115d4`
on `codex/physical-actor-timeouts`, in a separate managed worktree at
`C:/Users/_/.codex/worktrees/physical-actor-hangs/khybersand`. The original
`C:/khybersand` material branch and its dirty native sources/DLL remain untouched.
No LCB (#215/#217/#226) or MAT-003PREPASS work is selected. Godot remains pinned
to `4.7.stable.official.5b4e0cb0f`, Rapier to 0.35.2, and required runtime LFS
objects are materialized separately. Native source and retained DLL are unchanged
by the diagnostic checkpoint. The branch commits are the recoverable checkpoints;
per-run manifests record exact source and runtime hashes.

## Historical failure evidence

- [Run 39879178132](https://github.com/techrote/cybersand/actions/runs/39879178132):
  Windows arena and Linux shard 1 usable course exceeded their 180-second limits.
- [Run 39978072686 attempt 1](https://github.com/techrote/cybersand/actions/runs/39978072686/attempts/1):
  Windows job `120497827241` timed out on physical actor rigs after the Godot and
  Rapier banners, with no fixture output. The subsequent attempt passed. The old
  runner prints child output only after process completion, so CI line timestamps
  are not timestamps of the child's last actual progress.

These selected incidents are not an unbiased frequency estimate. A successful
rerun does not identify or repair the hang.

## Blocking-path inspection

| Path | Ownership and possible blocking point |
|---|---|
| Arena/course configure | Instantiate native World, `diagnostic_reset(workers=1)`, author layout, construct isolated viewport/session/space/rigs, install terrain |
| Arena/course tick | Synchronous masks, actuation, usable work, native tick, terrain installation, Rapier `space_step`/`space_flush_queries`, copied observations |
| Rig fixture | No cellular World or pacing worker: actual Rapier setup, bounded synchronous step loops, teardown followed by `await process_frame` |
| Teardown | Bridge shutdown, free joints/bodies/space and release World; arena/course have no session acknowledgement wait |
| Quit | SceneTree quit and extension/engine teardown after final fixture result |
| Desktop comparison | Async owner joins/reset admission exist in desktop integration, but these three fixtures do not use that owner |

All loops in the three fixture scripts have explicit tick bounds. Stack/phase
capture must distinguish engine/extension waits from slow progress before choosing
a fix. **Planned:** identify the root cause from captured evidence, add a focused
fix and fast internal watchdog, then repeat the full hosted scope.

## Diagnostic checkpoint and validation

Shared runner diagnostics capture the live process at 150 seconds and retain the
180-second case deadline. Import retains its existing 240-second bound. Profiling
cases retain their pre-existing bounds. No retry, skip or flaky-test exception is
introduced. Windows captures wrapper/child thread states and attempts normal
minidumps; Linux captures `/proc` and attempts bounded all-thread GDB stacks.
Missing/failed capture is recorded without replacing the test result.

The fixture-only progress helper brackets setup, tick batches, teardown/frame
waits and quit. No production physics configuration or behavior is changed.
The manual stress campaign requires 50 independent runs of each suspect test on
each OS. Every experiment result persists, and missing trials fail aggregation.

Initial Python runner and Windows harness tests: 15 + 15 passed locally. Local
fixture smoke testing caught an instrumentation indentation error in the rig
fixture; those early runs are invalid as hang-frequency evidence. They remain in
ignored local logs and are not counted as a baseline campaign. Hosted baseline,
root cause, after-fix campaign and final exact-head gates remain **Planned**.

## Documentation change map

The build/validation guide owns invocation and diagnostics; this audit owns dated
evidence. Existing corpus ownership and public controls are unchanged. Native
ownership/lifetimes, interfaces, capacities, ADRs and physics defaults have no
semantic change at this diagnostic checkpoint. Roadmap/retrieval routing must
preserve the investigation's unresolved status until a causal result is captured.

## Local scheduling experiment (before a root-cause fix)

The [curated local summary](physical-actor-timeouts-2026-10-23/local-stress-summary.json)
records **50/50 passes per suspect test**, with **0/50 timeouts** for each,
on local Windows 11 x86_64, Ryzen 5 5600X (6 physical / 12 logical CPUs).
Five isolated copies of the imported project each ran ten independent trials;
each Python/Godot tree inherited a distinct two-logical-CPU affinity mask.
The arena/course native owner remains one worker; Rapier's own worker count is
not overridden by this affinity experiment. This is a scheduling experiment,
not a claim to emulate the exact hosted machine.

Fixture source bytes match `e7580113202b5e1897a95bd1708c11741308e2d8`.
The only uncommitted harness change at launch concerned Windows dump capture;
no fixture, production script, native source or runtime bytes differed. The
summary retains fixture/helper and runtime SHA-256 identities. Local Godot's
engine and console hashes also match the separately hash-verified official ZIP
used by the full Windows gate.

Command: `python build/local_campaign.py`, an ignored local orchestration script
that copies the Godot project five times, applies Windows process affinity and
invokes `stress_physical_actors.py --iterations 10` for each copy. Raw logs,
individual `stress.json` records and the orchestration script remain under
`build/local-batch-*`, `build/local-project-*` and `build/local_campaign.py` in
the isolated worktree. All case deadlines stayed at 180 seconds. These are
independent experiments, not retries of a failed test. Earlier smoke runs with
the caught instrumentation parse error are excluded explicitly.

| Test | Passes / trials | Timeouts | Elapsed range (seconds) |
|---|---:|---:|---:|
| physical actor arena | 50 / 50 | 0 | 15.717–21.662 |
| physical actor rigs | 50 / 50 | 0 | 25.244–29.903 |
| physical usable course | 50 / 50 | 0 | 15.292–20.061 |

**Unresolved:** this sample did not reproduce the intermittent hang. It does not
identify a root cause or establish a before/after repair.

## Hosted campaign registration

[Run 40009601466](https://github.com/techrote/cybersand/actions/runs/40009601466)
was dispatched from exact source `e7580113202b5e1897a95bd1708c11741308e2d8`.
A new workflow file cannot be dispatched by name until registered on default
main (the initial API request returned 404 without creating a run). The existing
GDExtension workflow therefore exposes an explicit `physical_actor_stress=true`
manual option and calls the branch-local stress workflow. Ordinary draft/ready
validation routing is preserved. At the 19:25 UTC observation all campaign
execution jobs remained queued without an assigned runner; no hosted trial or
frequency result is claimed. The separately requested full local Windows suite
is still in progress at this checkpoint.

## Full local Windows baseline and watchdog integration

Source `77c8b0e` (resolve the full SHA in the
[curated full-suite manifest](physical-actor-timeouts-2026-10-23/full-windows-baseline.json))
passed import plus **121/121** applicable Windows headless cases, including both
profiles and scene startup. No error, skip or timeout occurred. The twelve
rendered cases remain explicitly outside that Windows lane and require Linux
software-display execution. Command:

```text
python tools/ci/run_windows_godot_regressions.py --godot-archive build/godot-windows.zip --expected-source-sha <full 77c8b0e SHA> --output build/full-windows-baseline-head
```

The helper verified the official archive SHA-512, native source input manifest,
committed runtime LFS hashes and tested-input stability before declaring a pass.
Raw logs and `windows-execution.json` remain in the named ignored output directory.
An initial invocation using a shortened SHA was rejected before any test; it is
not included in execution counts. Hosted Documentation/provenance at this source
passed in [run 40010519054](https://github.com/techrote/cybersand/actions/runs/40010519054).
That result does not attest a subsequent watchdog source checkpoint.

**Current guard, separate from causal repair:** the runner-side progress watchdog
captures a live stalled process at 30 idle seconds and fails it at 45 idle seconds,
while preserving the original outer deadline. It reads fixture-only markers from
outside Godot, so a synchronous native/Rapier call or main-loop stall cannot prevent
it from running. Startup without a marker and a stuck quit are also bounded.
Real marker changes renew liveness; unrelated stdout does not. Timeout kind and
capture failures are recorded explicitly. Native physics, runtime dependencies,
assertions, actor control and user-facing behavior remain unchanged.

Python validation now includes 48 tests: shared runner (15), Windows harness (15),
live snapshot (3), real-child monitor (6), watchdog boundaries (4) and stress
aggregation (5). They cover live pre-kill capture, capture failure, frozen engine
surrogates, unrelated-output rejection, continuing progress, the outer deadline,
missing/duplicate trials and mixed source/runtime rejection. A successful guard
is not a root-cause fix. Ordinary suite and manual stress concurrency groups are
separate so one manual mode cannot cancel the other mode's evidence run.
