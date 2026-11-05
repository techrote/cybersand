---
title: INV-004 Windows Rayon worker completion investigation
status: Current
document-kind: audit
scope: Worker-side ETW attribution for the unchanged Windows space_step workload
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-05-inv154-windows-thread-time.md, ../operations/profiling-observability-and-performance.md, ../architecture/simulation-tick-and-threading.md]
---

# INV-004 Windows Rayon worker completion investigation

## Question and retained inputs

The owner requests why Rapier's Rayon pool completes late. This continues the
[calling-thread investigation](2026-11-05-inv154-windows-thread-time.md), which
found actual waiting in `ThreadPool::install` during 169 long `space_step()`
intervals. It does not follow that the worker threads were also waiting, running
the solver, or runnable but descheduled. Those alternatives require worker-side
identity, scheduling and stack evidence.

Use the same existing Windows Server 2022 / EPYC 7763 / software-ANGLE workload,
not a new optimization benchmark: measurement run 42117551171 at
`8924c43a2deb22922515ce5a2dbc7891afd06a9a`, tree
`2ad19c2347906548087eb6e1bdbe99b799c93b1a`. The fixture retains the acrobat,
60-frame warmup, four four-second original/timed/timed/original arms and 60 FPS.
The three original ETLs and raw QPC timing rows remain immutable, with hashes,
runtime identities, exits, actual native participation and original profiler
perturbation in the preceding audit. This is a new analysis of those same trials,
not three additional independent Windows trials.

Intake diagnostic branch is `codex/inv154-windows-thread-time-20261105`, HEAD
`f6d53a422e05666621b3e87ef9a2761737c0c252`; tracked status is clean. Its real
root is `C:/Users/_/.codex/worktrees/rapier-thread-time-20261105/khybersand`.
Reuse this one scoped branch. Preserve #449 and all production branches, physics
settings, native/Rapier binaries and existing historical records.

## Attribution method

Identify Rayon workers by exact-matching Rapier/Rayon symbol frames, retaining
OS thread IDs, process/lifetime identity, names and start stacks where present.
Names alone do not prove which pool or work item a thread owns. Reconstruct
scheduled, ready and waiting intervals and CPU-sampled stacks against the same
long-step QPC windows. Preserve unknown coverage and lost-event counts. Record
readying emitter and target threads where ETW supplies them; do not equate the
readying emitter with a particular application job without supporting evidence.

Use pinned dependency source and wake/completion chains to qualify any critical
path claim. Ordinary sampling/context switches do not expose arbitrary Rayon
job IDs or mutex ownership. Separate measured computation, spinning, blocking,
ready delay and lifecycle time from inferences about cause. Extend recording
only if the existing traces leave a necessary worker-side observation missing.
No production optimization or changed thread/physics configuration is authorized.

## Exact dependency and lifecycle interpretation

Selected addon source is commit `172c66f5a88bf1164c2b8cf2d775ed889edefd75`.
`PhysicsWorld` owns a retained Rayon pool, initialized in `PhysicsWorld::new`;
`PhysicsWorld::step` installs work in that pool. On Windows the source derives
its requested count through `num_cpus::get_physical`, so the recorded two-core
host requests two workers per world. This is source configuration, not an
actual-created/participating count. Different worlds can own different pools.

The exact Cargo lock selects Rayon 1.12.0, crate SHA-256
`fb39b166781f92d482534ef4b4b1b2568f42613b53e5b6c160e24cfbfa30926d`,
and rayon-core 1.13.0, crate SHA-256
`22e18b0f0062d30d4230b2e85ff77fdfe4326feb054b9783a3460d8435c8ab91`.
Inspected archives match the lock checksums. `Registry::in_worker_cold` means
the caller is outside a Rayon pool: inject a stack job and wait for its latch.
It does not establish per-step pool/thread creation. Preserve the prior #234
cooperative BVH join patch and its exact runtime qualification.

## Worker-side observations: first retained trial

The first trace identifies four actual Rayon threads in Godot process 4728:
3264, 4556, 5484 and 5684. Their symbol-resolved worker-loop/start frames establish
identity; source configuration alone does not. The completion-signaling pair
5484/5684 exists about eleven seconds before the first long interval, so the
measured delays are not per-step thread startup. Other Rayon threads are retained
in the census rather than silently treated as belonging to the stepped world.

Across the 57 long caller windows, completion workers 5484 and 5684 respectively
spend 3,724.000 and 3,725.554 ms ready to run, but only 3.904 and 4.228 ms
scheduled. The first 72.208 ms window contains about 72.010 ms of ready time on
worker 5684, followed by about 139.6 microseconds of scheduler residency and a
caller wake. These measurements concern the critical completion threads, not an
average diluted by idle helpers.

Caller-target ReadyThread stacks resolve to `RtlpWakeByAddress`, Rayon's latch
`set`, and execution of a `StackJob<PhysicsWorld::step>`. ETLX header identity,
the current CSwitch CPU context and the resolved stack agree on the completion
threads. Raw ReadyThread common-header IDs alone are unavailable (-1), so they
are not used as unconditional emitter attribution. Preserve raw-versus-derived
identity semantics and missing/unknown evidence explicitly.

The first trace has zero lost events and no unknown coverage. The pool's delay
is predominantly ready-but-not-scheduled time on these completion workers;
determining which threads occupy the CPUs is the next bounded attribution step.

## All three retained traces: critical worker and CPU competition

**Finding:** the critical Rayon completion worker is runnable but receives
almost no guest CPU time while higher-priority WARP-associated software-rendering
threads occupy the processors. This explains the retained cohort's long pool
completion wall intervals. The caller waits on Rayon; the completing worker
waits to be scheduled. This is a measured same-process scheduling chain, not
an inference from the separate local hardware-GPU run.

| Retained trial | Godot PID / caller TID | Critical completion workers | Long events | WARP-associated logical-CPU residency |
|---|---|---|---:|---:|
| 02 | 4728 / 5692 | 5484, 5684 | 57 | 95.833% |
| 04 | 1952 / 7348 | 4028, 6240 | 56 | 95.599% |
| 06 | 5872 / 7872 | 2120, 5268 | 56 | 95.604% |

For all 169 events, match the caller's longest actual waiting segment to the
ReadyThread ending it, its resolved `WakeByAddress` stack inside the Rayon
`StackJob<ThreadPool::install<PhysicsWorld::step>>`, and the emitting worker's
CSwitch history. During that exact caller wait, the responsible worker is
**Ready at least 99.6025%**, median 99.8459%. Scheduled residency is at most
0.3975%; critical-worker waiting/unknown time is zero. Dominant caller waits
last 40.4255–78.3929 ms. Workers exist 10.754–11.206 seconds before the first
long event. Recurring pool startup is excluded by source and observed lifetime.

Across all four logical processors, identified WARP-associated threads account
for **42.819300 of 44.753324 CPU-seconds (95.6785%)** of scheduler residency
during the same long windows. Every individual window has at least **93.8152%**
WARP-associated thread residency. The per-CPU slices cover all windows exactly,
within floating-point rounding. Those threads belong to the same Godot process
as the blocked caller. Captured CPU stacks contain repeated `d3d10warp` ancestry
with Windows `TppWorkpExecuteCallback` / `TppWorkerThread` roots.

These threads run predominantly at observed dynamic switch-in priorities 12
and 13: 42.037366 CPU-seconds of their residency, with another 0.781934 at 10.
Critical Rayon switch-ins are 444 at priority 10 and 17 at 13. These are observed
scheduler priorities, not a claim about which API set or boosted them. Microsoft's
[scheduling contract](https://learn.microsoft.com/en-us/windows/win32/procthread/scheduling-priorities)
selects ready threads by priority; its
[WARP guide](https://learn.microsoft.com/en-us/windows/win32/direct3darticles/directx-warp)
identifies WARP as CPU software rasterization. The priority difference and
processor occupancy corroborate the directly observed worker ready delays.

The uncapped corroborating sample result is **42,613 / 44,594 noninterrupt
samples (95.5577%)** with WARP ancestry. A further 143 samples have ISR/DPC flags;
116 of those contain WARP ancestry and are excluded from this noninterrupt
numerator. The bounded 20,000-row capture retains all eligible rows in each
trace: 14,870 / 15,155 / 14,568, with truncation false. Profile events from
threads outside the selected competitor set remain in the denominator.

## Completion-latch phases and limits

There are 330 verified caller wake signals across 169 windows. A wake stack may
contain an explicit latch-set frame or its inlined code in the exact PhysicsWorld
job. Requiring only the explicit frame drops relevant notifications. The source
sets the completion flag and notifies while holding a mutex; a caller can wake
and then block again reacquiring that mutex while the notifying worker is
descheduled. Multiple notifications do not establish multiple physics jobs.

Caller blocking stacks contain 169 initial condition-variable waits totaling
10,175.5949 ms and 161 mutex-reacquisition waits totaling 992.6750 ms. The longest
wait is the condition-variable phase in 155 events and mutex reacquisition in
14. Both show critical-worker ready delay. Last scheduled residency before
release of the dominant wait is 9.0–178.7 microseconds. This is not an exact
job-entry or full solver CPU-duration measurement; job entry remains unobserved.

Four identified workers overlap measurement in each process. Additional workers
created during shutdown are retained in the census and explicitly excluded by
observed lifetime. The broader reconstruction retains 13.2 microseconds of
unknown off-CPU time in trial 04, outside the critical spans. No state anomaly
intersects a long window; no unknown value becomes assumed ready/waiting time.
Only 27 worker CPU samples occur in these windows, so the samples are not a
detailed solver profile. ETW loss and truncation are zero in all three traces.

WARP-associated thread residency does not prove every instruction executed a
known WARP function. Many sampled leaves are unmapped while captured callers
include `d3d10warp`; no particular shader is attributed. ISR/DPC samples remain
separate. Guest scheduler residency can include interrupt or VM-host interruption;
this study does not isolate hypervisor effects or establish a general hardware-GPU
result. No priority, pool-size, renderer, shader, gameplay or physics change is
selected. No new gameplay run was needed: the existing traces contain the relevant
worker, completion-wake and competing-processor evidence.

## Reproduction and validation checkpoint

Use .NET 10 and the exact TraceEvent 3.2.8 package, matching Rapier PDB, three
ETLs and raw timing files already retained by the caller investigation:

```text
python tools/performance/analyze_rapier_thread_states.py --traces <original-trial-parent> --symbols <matching-PDB-directory> --output <new-analysis-directory> --workers
python tools/performance/verify_rapier_worker_trace.py <new-analysis-directory> --self-test
python tools/performance/rapier_thread_competitors/synthesize.py <new-analysis-directory> --output <new-analysis-directory>/cpu-competition-summary.json
```

The wrapper builds both exact-version offline projects and limits each worker
and competitor replay to 180 seconds. It preserves process exits and copied
source/assembly identities. The verifier checks immutable ETL hashes, raw timing
identity, complete critical-state/CPU coverage, resolved job/waker/CPU agreement,
loss and sample caps. Five adversarial mutations reject a missing completion,
unknown critical state, lost events, CPU coverage loss and truncated sample rows.
Independent read-only review and a separate replay reproduce the critical-worker
and processor-residency results. The original gameplay fixture/source guards and
all six preceding game-process exits remain the earlier measured identities.

Retain apparatus failures: an interrupted broad-symbol census and a locked-assembly
build attempt are recorded, including the explicit gap that the initial local
processing log was superseded before preservation. Early matching that required
an explicit latch-set frame missed an inlined final notification; corrected
job/wake matching preserves both. The original competitor reader capped selected
samples at 15,000 and truncated trial 04; a fresh bounded 20,000-row replay records
eligible/retained counts and a truncation flag, separates ISR/DPC samples and
retains the earlier outputs. An initial verification adapter expected a different
row-kind name and failed closed; it now reads the actual caller `switch_out`
records without weakening the identity/coverage checks.

Changes are confined to offline diagnostic tools, their GitHub-hosted replay and
documentation. Production ownership/lifetime, native/Rapier inputs, interfaces,
physics configuration, user controls and ADR-009 remain unchanged. Canonical
profiling interpretation, roadmap, validation ledger, handover and index route
to this dated audit. The corpus manifest and all previous frozen/challenge/caller
question fixtures remain unchanged; two worker questions are evaluated separately.
Generated traces, ETLX, source downloads, NuGet/build output and machine-local
symbol caches are uncommitted. Local records are under
`build/rapier-worker-publication`, `build/rapier-worker-trace` and
`build/rapier-worker-source`; hosted receipts are published on #449.

The final local checkpoint passes both .NET builds, three complete worker and
competitor replays, five adversarial worker-verification cases, six retained
caller-measurement regressions, original source-equivalence guards, documentation,
repository/runtime provenance, M11 integrity, provider and scheduling policy,
Python compilation and whitespace checks. Frozen retrieval remains 19/32 hit@1,
32/32 hit@5, MRR 0.7536. The independent worker fixture is 2/2 at rank one; manual
source review confirms cohort, persistent-pool, completion-identity and two-wake
qualifiers. These checks do not grant production acceptance or merge authority.
