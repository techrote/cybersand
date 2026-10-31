---
title: PACE004 original hosted d08 campaign and performance observations
status: Current
document-kind: audit
scope: Source-specific independent 72-case readback and advisory software-renderer measurements; provider aggregate and later source acceptance remain separate
canonical-for: []
last-reviewed: 2026-10-31
related-documents: [../systems/player-control-playground.md, ../operations/ci-execution-and-performance.md, 2026-10-31-play-pace004-policy-successor.md]
---

# PACE004 original hosted d08 campaign

The unchanged complete-suite reader independently passes all **72 cases** from
[run 41247752557, attempt 1](https://github.com/techrote/cybersand/actions/runs/41247752557).
This records exact source `d08e61013c2fefbf6238d50174b81655e80f1eb8`, tree
`9b95e643d756f531db045e28272fa86bdeb97665`, and protected reviewed baseline
`02454f3aa6a6130d375727d1aa28113772f658e4`. Neither source is relabelled as
the later composed candidate `4f3decc242633fb621d76b7529ef87b420dbd87a`.

At this checkpoint the provider's final `complete_inventory` job
`124683215348` remains queued. All 36 case jobs and the plan job have completed
successfully, but the workflow is not yet a terminal provider pass. Ordinary
Native/Godot gates and the later candidate's fresh qualification remain separate.

## Evidence custody and independent checks

The 36 original case ZIPs total 2,822,725,441 bytes. Their provider sizes,
SHA-256 digests, member inventories and CRCs are authenticated. Fresh extraction
and the unchanged source-owned readers establish the exact union of 30 headless
and six graphical cases on each platform. Every hosted per-shard reduction equals
the corresponding independent result. All **888 original extracted files**
remain byte-identical through the complete readback. The independent record's
SHA-256 is
`45e8286e394e57a145dc989776d1868bd7c408ddcbcb6785376b54846d6ae5c6`.

An initial separate extraction acquired unregistered transfer fragments that
were absent from its authenticated ZIP. The original inventory refusal and that
extraction are retained. The successful complete readback used fresh extraction
in one process; it did not exclude extra files or weaken the sealed inventory.
Completed temporary duplicate extractions were later reclaimed only after their
entire contents were proven reconstructible from the preserved original ZIPs.

The [machine-readable performance record](play-pace004-2026-10-31/hosted-d08e6101-performance.json)
is 390,040 bytes, SHA-256
`68623a1b7740101090a73b57fed3d9793b95aa49f5e9c4d9cbee0a2792b90bc0`.
Its independent numerical derivation reads ZIP members directly, joins all 72
fixture footers to their original logs and sealed process/cleanup records,
and recomputes rates and distributions from raw observations. Root separately
checks all case counts, identities and retained metrics, plus each graphical
draw rate and p95 interval. Root's performance-review receipt has SHA-256
`b077c7588ff217718195bb0267a76d26f0c9ff789e835024c8721334c8bc764e`.

| Observed inventory | Total across both platforms |
| --- | ---: |
| Natural process completions | 72 |
| Headless / graphical cases | 60 / 12 |
| Assertions / assertion failures | 7,684 / 0 |
| Individually accounted input events | 2,880 |
| Pressed events | 1,440 |
| Pressed events with recorded applied outcome | 1,008 |
| Recorded hardware/backend cohorts | 14 |

All cases report four logical CPUs. Physical CPU models vary. Input totals are
not all applied presses: each 40-event tape retains its applied, cancelled and
refused outcomes. The older #320 totals of 60 cases, 6,244 assertions, 2,400
events and 840 admitted nonneutral presses were also totals across both platforms,
not per-platform counts.

## Actual graphical measurements

Rates use the actual retained approximately 15-second measurement interval.
Draw/s means software draw submissions. Every `displayed_fps` value is null.
Input latency joins admission to a later completed physical application across
the complete tape, including lifecycle/reset sections; it excludes physical
device delivery and display scanout. Each case has only 29 applied samples, so
its p95 is not a population tail guarantee.

Linux uses native OpenGL with llvmpipe LLVM 20.1.2. Windows uses ANGLE and
Microsoft Basic Render Driver, reporting D3D11 driver 10.0.20348.5756.
These are separate software-renderer and hardware cohorts.

| Platform / CPU | Rig | Workers | Policy | Native Hz | Rapier Hz | Draw/s | Draw interval p95 ms | Input p95 / max ms |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Linux / EPYC 7763 | Acrobat | 1 | Current | 60.046 | 59.913 | 19.438 | 54.448 | 51.879 / 52.920 |
| Linux / EPYC 9V74 | Acrobat | Auto | Current | 60.012 | 60.012 | 26.480 | 39.934 | 38.589 / 39.318 |
| Linux / Xeon 8573C | Jet Barrel | 1 | Current | 60.043 | 60.043 | 24.257 | 43.867 | 40.893 / 40.985 |
| Linux / EPYC 7763 | Jet Barrel | Auto | Current | 60.024 | 59.957 | 20.473 | 51.063 | 48.486 / 49.231 |
| Linux / EPYC 9V74 | Jet Barrel | 1 | Pressure | 47.350 | 59.936 | 21.977 | 49.233 | 46.421 / 46.514 |
| Linux / Xeon 8573C | Jet Barrel | Auto | Pressure | 47.153 | 60.007 | 20.180 | 53.013 | 48.979 / 49.320 |
| Windows / EPYC 9V74 | Acrobat | 1 | Current | 56.247 | 59.630 | 8.822 | 119.506 | 26.129 / 117.797 |
| Windows / EPYC 7763 | Acrobat | Auto | Current | 55.946 | 57.531 | 7.200 | 143.232 | 18.263 / 146.087 |
| Windows / EPYC 9V74 | Jet Barrel | 1 | Current | 57.815 | 59.603 | 9.073 | 112.579 | 95.139 / 120.580 |
| Windows / EPYC 9V74 | Jet Barrel | Auto | Current | 57.167 | 59.624 | 9.030 | 112.611 | 98.321 / 118.862 |
| Windows / EPYC 7763 | Jet Barrel | 1 | Pressure | 22.954 | 53.363 | 6.670 | 159.938 | 132.175 / 181.092 |
| Windows / EPYC 9V74 | Jet Barrel | Auto | Pressure | 29.249 | 59.557 | 8.206 | 128.578 | 117.067 / 118.349 |

The Windows software submission rates and pressure throughput are substantial
observed limitations despite functional completion. They do not establish a
physical GPU/display result, causal worker-mode improvement or acceptable human
playability. Auto reserves capacity four, while every Windows graphical case
observes at most one task-claiming participant per native dispatch. Capacity and
actual participation remain distinct.

Windows pressure snapshot-publication age p95 is 112.061 ms for one worker and
86.726 ms for Auto; those cases have zero maximum render revision lag. The older
retained render-buffer timestamps are recorded separately and do not by
themselves prove a stale simulation image. Construction acknowledgement ranges
from 2.657 to 46.244 seconds on Windows and 6.476 to 12.804 seconds on Linux.
Cache state is unrecorded, so these are not cold/warm or compiler-only timings.

## Active versus idle observations

Only six of sixteen pairs match all recorded source, configuration, runtime,
CPU and backend identities. The other ten differ in CPU model and have no
comparison ratios. Even matched pairs are single observations from separate
hosted jobs; same-machine identity, cache, CPU clock, contention and randomized
replication are unestablished.

Four matched Current-policy Auto pairs on platform-specific EPYC 7763 cohorts
retain approximately 60 native and Rapier completions per second. Their native
tick medians increase from approximately 0.038–0.040 ms while idle to 2.331–5.440 ms
under the registered brush load. Mean task participation rises from approximately
1.01 to 2.91–3.71. This observes actual extra work and participation; it is not a
performance comparison between code versions.

| Matched Windows headless pressure pair, EPYC 9V74 / one worker | Native Hz active / idle | Native median ms active / idle | Rapier Hz active / idle |
| --- | ---: | ---: | ---: |
| Acrobat | 37.266 / 49.726 | 24.6900 / 17.4407 | 59.999 / 59.991 |
| Jet Barrel | 37.393 / 50.514 | 24.5424 / 17.3858 | 59.989 / 59.977 |

The active arms have approximately 25.1% and 26.0% fewer native completions per
second than their matched idle observations; Rapier remains approximately 60 Hz.
All sixteen actual brush-load arms retain active-tick fraction 1.0. All sixteen
idle controls retain their required rejection of the active-work predicate.
Brush-command admission remains distinct from individual native application.

## Acceptance limits

This evidence does not supply a synchronous-reference arm, physical keyboard or
gamepad, OS focus/modal/disconnection coverage, physical scanout, human feel or
a repair of the separately reproduced Windows shutdown exception. All 51 manual
entries remain untested. The generous execution watchdogs permitted diagnostic
completion; they do not convert the measured responsiveness limitations into
playability acceptance. Later-source and provider terminal qualification must
be recorded independently through #334 and the live coordination ledger.
