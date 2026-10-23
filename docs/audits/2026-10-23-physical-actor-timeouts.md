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
