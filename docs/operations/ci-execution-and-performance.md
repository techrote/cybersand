---
title: CI execution watchdogs and advisory performance
status: Current
document-kind: runbook
scope: Shared Godot, Python and native execution allowances, complete hosted budgets, retained failures and comparable performance history
canonical-for: [ci-execution-watchdogs, advisory-performance-history]
last-reviewed: 2026-10-31
related-documents: [github-development-and-release.md, profiling-observability-and-performance.md, testing-validation-and-replay.md, ../audits/2026-10-31-execution-watchdog-modernization.md]
---

# CI execution watchdogs and advisory performance

## Owner policy and acceptance boundary

The 2026-10-31 owner decision replaces historical short execution deadlines with
generous watchdogs. A slowdown is an observation to investigate. Assertions,
crashes, invalid simulation, incorrect rendering, unjoined processes and missing
source-bound evidence remain failures. Cold startup time, warmed gameplay
latency, simulation throughput, render submission and physical display cadence
are separate measurements. Larger watchdogs do not qualify poor gameplay feel.

The committed [policy JSON](../../godot/tests/support/ci_execution_policy.json)
is consumed by [GDScript](../../godot/tests/support/ci_execution_policy.gd),
[Python](../../tools/ci/execution_policy.py), native shell wrappers and PLAY
readers. The policy identity records its bytes, schema and effective scale.
`CYBERSAND_CI_WATCHDOG_SCALE` may enlarge local allowances; invalid, nonfinite,
boolean or shrinking values fail. Hosted workflows explicitly select scale 1,
and planners reject configurations above the supported hosted job limit.

| Workload | Initial hard watchdog | Interpretation |
|---|---:|---|
| Cold Main acknowledgement | 600 seconds | Maximum setup allowance, not a target |
| Ordinary or rendered case | 1,200 seconds | Complex fixtures receive the larger allowance below |
| Godot import | 1,200 seconds | Separate preflight on each isolated shard |
| Operation, independent readback, graceful teardown | 300 seconds | Shared operation clock includes dependent provenance reads |
| Complex fixture | 3,600 seconds | Inner fixture can report its own failure before its parent expires |
| Complex fixture process | 3,940 seconds | Fixture plus 300-second unwind, 30-second capture and 10-second forced cleanup |
| Native compile or substantial native command | 3,600 seconds | Command-specific aggregate arithmetic may extend this |
| Dependency preparation | 1,200 seconds | Separate from scientific sampling windows |
| Expensive hosted job starting point | 180 minutes | Derived parents extend when the complete child inventory requires it |

Fixed tick counts, sample windows, input pulses, sanitizer environments, solver
parameters, fixture geometry and adverse-control delays are scientific or
protocol inputs. They do not become watchdogs merely because they contain a
number. In particular, BUSY001's held native phase controls retain their original
protocol bounds and the scene smoke check retains its 180-frame count.

## Complete hosted parents

[The Godot planner](../../tools/ci/godot_job_plan.py) discovers every current
fixture and derives a complete matrix. It reserves each case's process allowance,
300 seconds for independent readback and 240 seconds for the complete sequential
diagnostic and cleanup path. The shared `godot_process_cleanup_seconds()` helper
includes up to three legacy snapshots and their process-tree retirement, closing
the independent capture owner, and retiring the engine tree. Import receives the
same cleanup reserve. Three shared metadata operations, setup/artifact allowance
and aggregate headroom are counted separately.
Historical elapsed-time weights only distribute work. They cannot shorten a
case or omit it. The current watchdog source contains 246 Linux cases, including
13 rendered cases, and 233 applicable Windows headless cases; the machine plan
is authoritative when source discovery changes.

The corrected complete plan uses 77 Linux and 75 Windows shards. Linux execution
allows 276 minutes and Windows 263 minutes within a 360-minute parent, with 70 minutes reserved
for setup and artifacts and 10 minutes of additional headroom. These generous
maxima are not expected runtime or a performance claim. The full suite no longer
promises that dozens of one-hour child allowances fit inside a short four-shard
parent. [GitHub's hosted job limit](https://docs.github.com/en/actions/reference/limits)
is six hours; the planner fails if its policy would exceed it.

The six Native families retain the exact original 20 commands and scientific
inputs. [Their planner](../../tools/ci/native_execution_policy.py) derives
180/350/180/333/284/223-minute parents for TSan, normal, ASan, worldgen,
soliding-normal and soliding-ASan respectively. The physics CLI inventory still
contains all 154 original invocations, each with a 300-second operation budget;
a bounded eight-process dispatch preserves arguments and output identity while
all assertions run in their original order on the main test thread. The source
inventory and family receipts remain required by the stable `native` gate.

All independent matrices use `fail-fast: false`, and new commits do not cancel
original attempts. Required aggregate jobs run after an admitted matrix or scope
classifier failure. A skipped job is not accepted as a successful behavioral gate.
The retired optional four-shard serial-migration job is replaced by mandatory
[Linux coverage verification](../../tools/ci/verify_linux_godot_shards.py) on every
admitted run. It checks the complete original inventory, source/tree, runtime,
policy, run/attempt, real rendered commands, natural completion, unchanged raw
logs and required independent PLAY readbacks. The existing Windows coverage
reader derives its complete plan from the same source.

## Original failures and process ownership

[The native command owner](../../tools/ci/run_timed_command.py) writes an initial
incomplete receipt before launch, retains file-backed output and records the
original final exit. Linux child-subreaper ownership and process creation
identities include rapidly detached descendants. A zero root exit with a live
child is a teardown failure. Forced cleanup is scoped to owned identities;
namespace mismatch fails closed instead of treating unrelated host PIDs as ours.
Windows diagnostic fixtures use their separate strict Job owner.

Godot process diagnostics retain partial logs, actual exit codes, the last real
application/worker/physics marker, process/thread activity and available stack or
dump evidence. Early capture after prolonged inactivity is diagnostic; the
complex fixture's generous failure clock is independent. Diagnostic failure or a
process exiting during capture cannot convert an expired case into a pass.
Original failed artifacts remain unchanged when a later corrected source runs.

The adverse controls include correct fast execution, actual 16-second success
beyond the former operation limit, an actual assertion after 16 seconds, nonzero
subprocess exits, no-progress hangs, successful parent exit with surviving
children, rapid detached children and preservation of the first attempt.
Dedicated Windows controls separately exercise actual 20-second success and a
20-second delayed exit 19. These are harness controls, not game qualification.

## Timing records and comparable history

[Execution telemetry](../../tools/ci/execution_telemetry.py) writes
`execution-performance-v1` JSONL alongside original evidence. Records identify
commit/tree, tracked delta, fixture and source definition, policy, runner and
CPU characteristics, OS, material inventory, solver/world definition and result.
Existing structured Godot/native markers retain construction, stepping, worker,
Rapier, input, snapshot, pause/reset/recovery and shutdown metrics where those
fixtures expose them. Whole-process elapsed time is distinct from nested phase
fields. Completed hosted-job wall times come from GitHub job timestamps and are
bound to original observations by a hashed runner identity. Queue delay is
excluded; unfinished collector jobs have no invented final duration. CPU seconds and peak RSS are explicitly direct-process observations;
unavailable process counters remain unavailable. No direct GPU or physical
presentation timing is inferred from elapsed time.

Renderer, driver, selected shader and cache state are retained when actually
reported. Missing compiler/cache details remain `unknown`; headless/native work
uses explicit `not-applicable` renderer fields. Shader-specific cold/warm runs
must supply their actual provenance before any comparable shader baseline exists.
Raw logs remain the complete record, including information a compact reduction
does not expose.

[The history collector](../../tools/ci/performance_history.py) reads current
JSONL and up to ten eligible completed default-branch artifact bundles. Each
workflow publishes one consolidated `execution-performance-*` artifact for
90 days and a compact Actions summary. Authenticated run/source/attempt custody,
bounded archive reads and safe signed redirects protect history attribution.
Unavailable or expired history is recorded, not replaced with invented values.

A baseline requires at least three distinct comparable successful runs. Failed,
watchdog and incomplete rows remain in the retained current dataset but are not
successful baseline samples. Like-for-like cohorts include platform, hosted
runner/CPU, fixture/configuration, renderer/compiler and cache state. Historical
Avrea measurements remain a separate hardware cohort. Missing required identity
makes a row incomparable.

The rolling median produces advisory warnings at 1.5 times baseline, prominent
warnings at 2 times, and cumulative-drift advice after five successive increases
reaching 1.2 times the starting value. These ratios never fail correctness.
Source, fixture and shader changes are reported separately; a possible introducing
commit is named only when direct-parent evidence supports that inference. A
small artifact window may contain fewer than three distinct runs, so the first
qualified runs intentionally report insufficient history.

## Reproducing the apparatus checks

```sh
python3 tools/ci/test_execution_policy.py
python3 tools/ci/test_execution_telemetry.py
python3 tools/ci/test_godot_job_plan.py
python3 tools/ci/test_verify_linux_godot_shards.py
python3 tools/ci/test_performance_history.py
python3 tools/ci/test_native_watchdogs.py
python3 tools/ci/test_native_shards.py
python3 tools/ci/godot_job_plan.py --output build/execution-plan.json
python3 tools/ci/performance_history.py --current build --output build/performance-summary --no-history
```

Process-ownership controls require a consistent Linux PID namespace. The shared
sandbox's host `/proc` may not match its visible PIDs; that environment is an
explicit unsupported ownership observation, not permission to weaken cleanup.
Full original Native and Windows/Linux Godot CI, source-matched independent
review, guarded merge and post-merge evidence remain required for acceptance.
