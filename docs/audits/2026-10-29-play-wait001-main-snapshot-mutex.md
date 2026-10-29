---
title: PLAY-WAIT-001 source proposal for isolated Main snapshot mutex wait
status: Planned
document-kind: audit
canonical-for: []
last-reviewed: 2026-10-29
scope: Test-only Windows/Linux Godot pacing and snapshot-handoff attribution
related-documents: [../systems/player-control-playground.md, ../reference/validation-evidence.md, ../reference/status-and-roadmap.md, 2026-10-29-play-life005-native-failure-recovery.md]
---

# PLAY-WAIT-001 — snapshot-handoff lock-wait source proposal (29 October 2026)

## Purpose and ownership

This bounded **test-only candidate** extends the accepted shared desktop host
through the five real SetP mechanical actors and authored Player Playground
course. It supplies a measurement not isolated in PLAY-PACE-001: the
Main-side acquisition time for the mutex used by
`CyberSimulationWorker.take_latest_snapshot(after_serial)`.

The test adds only `godot/tests/play_wait001_snapshot_probe.gd`, the shared
`play_wait001_main_mutex_case.gd` and five tiny rig wrappers. It does not
change production `simulation_worker.gd`, `main.gd`, native C++, compiled
runtime binaries/LFS, defaults, per-material solver admission/refusal, or
Rapier ownership. The test replaces the unstarted worker instance before
Main's `_ready()` starts an exclusive worker. It does not replace a running
owner or access native World from the Main thread.

The probe duplicates the production mutex-acquisition, immutable-snapshot
pointer read and serial fence, inserting monotonic microsecond timestamps
immediately before lock, after acquisition, and before unlock. This is
**instrumented test-equivalent code**, not timing inside the exact
unmodified production method. The additional clock calls themselves can
change the critical-section duration slightly.

## Scope of emitted result

Each `PLAY_WAIT001_RESULT` record reports source/course/rig/worker/platform
identity, 120 completed native and Rapier ticks (as an assertion, not an
assumed result), actual Main callback counts, sampled new/retained snapshot
returns, raw mutex wait/critical-section timing, full Main process
interval/callback distributions, joined worker and retired Rapier session.
The first callback in a sampling window has no preceding measured callback;
its start-to-first-callback fragment is excluded from the interval sample.
Consequently `main_process_interval_usec.count == main_callbacks - 1`,
while mutex wait, critical-section and callback-duration sample counts
all equal `main_callbacks`. Sub-microsecond lock waits quantize to zero
at the microsecond clock resolution; a zero median is not proof of zero
contention.
No timing threshold is introduced. The reducer uses nearest-rank
p50/p95/p99, plus mean and maximum. Equal wait/critical-section/callback counts link each Main process callback
to one instrumented snapshot acquisition; complete process intervals have
one fewer sample by construction.

`snapshot_mutex_acquire_wait_usec` measures **only the short
`take_latest_snapshot` handoff lock**, not other Main accessors,
`set_frame_state`, collider construction, native-job waiting, or the full
`consume_worker_snapshot` callback. It is not a measure of all Main-side
mutex waits, interactive FPS, simultaneous native job claims or a
slow-native stress result. The static cached render packet is not treated
as a frame-latency measurement.

This suite does **not** hold native jobs, prove the stop-fence ordering
with outstanding phase claims, qualify physical keyboard/gamepad/focus,
show sustained representative rendered gameplay, or execute the human-feel
checklist. The positive/negative per-material construction receipts remain
under their separate accepted lifecycle fixtures; no default-only
hash is represented as a positive policy admission here.

## Exact-head acceptance plan

Baseline source: accepted main
`aac0feb65e2268b74975892ce1df81e04e1a7e40`; this record describes
the unexecuted source proposal, not a completed run.

- Require repository documentation/provenance and applicable Native plus
  Windows/Linux Godot on the **final literal candidate head**. Preserve
  failures and no automatic retry/skip masking.
- Archive five `PLAY_WAIT001_RESULT` records per operating system,
  complete test logs, original artifacts and exact source/runtime pins.
- Independently recompute raw distributions and sample correspondence;
  inspect Godot parser output and distinguish native-source runtime
  identity from GDScript-only test revision.
- Obtain independently performed source and final execution-data reviews, with the actual reviewer method and source receipts recorded, before
  considering merge. Never count draft path-filter skips as executed CI.

This is a normal-load **isolated snapshot-lock-wait baseline** preparing
for the separate #269 controlled native-phase barrier and #270 integrated
longer-duration, input/focus and manual feel qualifications. It cannot
close #266, #268, #269, #270 or #263.

## Preserved pre-correction Linux diagnostic (source `6e2e98f9`)

The first candidate source `6e2e98f91573cd9c168e34dd0e013cb0e481804d`
was executed on hosted Linux in Godot workflow
[40890602677](https://github.com/techrote/cybersand/actions/runs/40890602677),
shards `123527397073`, `123527397156`, `123527397272`, and
`123527397348`. All five mechanical rigs emitted 16 assertions, zero
failures, 120 completed native plus 120 Rapier ticks, successful worker
join and Rapier retirement, 290–291 callbacks and exactly as many
snapshot-handoff lock acquisitions. An independent raw-array reduction of
20 distributions across the five records found no aggregate discrepancies.
The observed isolated mutex-acquire wait p95 was 1 microsecond for each
rig; p99 ranged 26–168 microseconds. These are normal-load, hosted
headless numbers from **that earlier head only**.

Source review found the first `main_process_interval_usec` entry actually
measured from `begin_sample()` to the first callback rather than from one
callback to the next. Thus the earlier mean/low-tail interval statistics
must not be relabeled as strictly inter-callback measurements. This
source correction deliberately excludes that partial first interval and
asserts `callbacks - 1` interval samples. The earlier full CI matrix,
including Windows, was not complete at the first diagnostic readback.
A fresh full exact-head matrix and independent raw reduction are required
before accepting the corrected measurements. No gameplay FPS, native-job
barrier, solver admission or manual feel claim follows from this diagnostic.
