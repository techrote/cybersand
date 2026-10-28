---
title: PLAY-AUTO-003 supplementary local six-worker reference measurements
status: Current
document-kind: evidence
scope: Exact-source local Windows 1/2/4/6/Auto repeat campaign with actual six-worker task participation; no Linux-six, gameplay or release qualification
canonical-for: []
last-reviewed: 2026-10-28
related-documents: [../architecture/simulation-tick-and-threading.md, ../operations/local-build-and-validation.md, 2026-10-27-play-auto002-worker-matrix-candidate.md, 2026-10-28-play-auto002-publisher-retirement.md]
---

# PLAY-AUTO-003 local six-worker reference measurements — 2026-10-28

The accepted #285 hosted Windows/Linux campaigns ran on four logical CPUs:
explicit six and Auto resolved to four. This supplementary local Windows
campaign exercises actual six-worker and Auto-six participation on a 12-logical-
processor machine, using the unchanged persistent runner, reference fixtures
and retained source-matched runtime. No workload, native source, worker policy,
default, scheduler or instrumentation was changed.

This evidence branch retains the raw report without altering #288's ready
head or restarting its hosted checks. It is not a source acceptance or release
promotion. #266/#270 remain open; Linux actual-six coverage is still absent.

## Source, runtime, machine and command

Executed clean source: **`f667f25879af231ebe4ed546a308f971f33a0278`**, tree
**`bdfd1f1dbb1a2b00b56fee99230a914f3ed15f37`**, branch
`codex/play-auto002-publisher-retirement`. This is the #288 candidate, not a
claim that the cleanup was accepted when measured. All **80 native inputs**
and **14 scoped campaign/apparatus inputs** are recorded in the report and
match those exact Git blobs. The native source is unchanged from accepted #285.

Runtime mode is `verified-retained-manifest`, with actual build source
`d7e35aa3897ffa0bde422ece98226c551588040e`; no fresh-build assertion was used.
Native DLL SHA-256 is
`e66b9b04b546b09cb4feea204373faf12a7248abf1701da88fc6ecf87b666ecb`,
4,825,088 bytes. Rapier DLL is
`b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7`,
9,987,072 bytes. Godot is `4.7.stable.official.5b4e0cb0f`; Python 3.12.10.

Host: Windows 11 `10.0.26300`, AMD Ryzen 5 5600X. The engine reports twelve
logical processors; `Get-CimInstance Win32_Processor` separately reports six
physical cores/twelve logical processors. Launcher affinity is `0xfff`,
priority class 32. Child affinity/priority and frequency were not directly
measured; external load was uncontrolled. This is neither an exclusive-host
experiment nor a controlled comparison with either hosted OS or machine.

```text
python tools/play/run_auto_campaign.py --godot C:/Godot47/Godot_v4.7-stable_win64_console.exe --output C:/Users/_/.codex/tmp/play-auto003-local6-20261028
```

Execution ran from 20:08:11 to 20:10:30 UTC on 2026-10-28. Import took 6.541 s
under its 240 s bound. Each fresh process retained the 180 s bound. Import
contains the existing generated-UID cache warnings; the unchanged strict error
scanner passes with no diagnostic error. No retry, skip, timeout or source
drift occurred. Generated import/UID changes were cleaned only after completion;
no implementation or runtime/provenance path changed during execution.

## Repeated results and counterexamples

The fixed campaign completed **50 fresh processes**, five cyclically balanced
repeats of requests 1/2/4/6/Auto at 480/960 cells per side. Every row uses
60 warm-up and 120 measured ticks: **3,000 warm-up / 6,000 measured ticks**.
Each policy/size summary pools 600 measured ticks from five processes; adjacent
ticks are not 600 independent experiments.

Configured capacities resolve to **1/2/4/6/6**. Forty rows observe multiple
task-claiming native workers. All twenty explicit-six/Auto rows observe six.
This is measured task participation, not an exported created-thread census or
a measurement of overlapping execution, CPU utilization or scheduler residency.
Successful pool creation has its existing source contract; no new OS-thread
creation/join tracing is introduced.

| Side | Request | Native mean ms | p50 ms | p95 ms | p99 ms | Maximum task participants |
|---:|---|---:|---:|---:|---:|---:|
| 480 | 1 | 10.521262 | 10.5892 | 12.2266 | 13.1141 | 1 |
| 480 | 2 | 5.896284 | 5.9304 | 6.9004 | 7.4368 | 2 |
| 480 | 4 | 3.616724 | 3.6047 | 4.4782 | 4.9848 | 4 |
| 480 | 6 | 3.336554 | 3.2047 | 4.9394 | 7.4358 | 6 |
| 480 | Auto | 3.065623 | 3.0657 | 3.8169 | 4.2403 | 6 |
| 960 | 1 | 42.762843 | 41.8258 | 52.1691 | 64.8823 | 1 |
| 960 | 2 | 21.926161 | 21.5914 | 25.4172 | 34.3567 | 2 |
| 960 | 4 | 11.594379 | 11.5388 | 13.2382 | 14.1595 | 4 |
| 960 | 6 | 9.143747 | 8.9201 | 10.7371 | 16.0164 | 6 |
| 960 | Auto | 9.052718 | 8.9585 | 10.9027 | 11.8912 | 6 |

Mean paired serial/Auto native-time ratios are 3.433113 at 480 and 4.726616 at
960, pairing within repeat/size. They are descriptive reference observations,
not causal gameplay speedup or statistically controlled platform conclusions.
No multiworker repeat is slower than serial in this campaign. Counterexamples
to Auto always beating the equal-capacity explicit six are retained: Auto is
slower at 480 repeat 4 and 960 repeats 0/2. Explicit-six pooled p99 also exceeds
four-worker p99 at both sizes despite its lower mean. Do not erase those tails.

All counts retain the same terminal level hashes as the hosted campaign:
480 `a649a5ee5282ab93658ecf0456eee4e2a8293a376c73df85b1c30f4c8a68b2c6`;
960 `5fa8a0f5bf67e8abcd83d470b2a624c188515973335e271369b6773a439beff3`.
Level equality is the registered native fixture comparison, not full replay or
native/Rapier equivalence. Actual gameplay still needs its own scheduling,
snapshot-age, main-wait and rendered timing evidence. No human feel follows.

## Retention, review and promotion limits

[Complete raw report](play-auto003-2026-10-28/windows-local6-campaign.json),
SHA-256 **`846235bb1c50a1808fd2ccc71f8a621fe79ffef9620a40257dd361d8285b43d8`**,
673,719 bytes. Its original Windows CRLF bytes are preserved by one exact-path
`.gitattributes` rule; prior reports and attributes remain unchanged. It includes
all tick/participant/phase/frame arrays, per-process results, machine conditions,
timing summaries and all 51 log hashes. Complete logs remain in
`C:/Users/_/.codex/tmp/play-auto003-local6-20261028`; logs/build output are not
committed. The later evidence commit is not a fresh execution source identity.

The persistent `verify_directory` validates the report, all 51 logs and raw row
markers. A distinct read-only agent independently matched the 80/14 input
ledgers, raw report/log hashes, all rows, summaries and counterexamples. Its
dated verdict is recorded on #266 after this branch is published. This supplies
supplementary **local Windows** evidence only, with no hosted Linux-six pass.

The canonical threading/build contracts already own this unchanged apparatus
and claim distinctions. This evidence-only delta introduces no production,
ownership/lifetime, interface, capacity, ADR, solver, user-control or retrieval
policy change. Repository/docs/M11 and diff checks remain required for the
evidence commit; no earlier CI is transferred to this new tree. Any later merge
must satisfy applicable exact-head CI and review. #288's final source remains
untouched; #265 stays closed and #271 deferred.
