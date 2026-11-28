# Retained physical-gap and Main-publication interval audit

**Draft/HOLD. The measured publication call occupies a large part of the
Windows wait after native completion, but removing that call has no established
counterfactual speedup. Linux has a comparable small-canvas wait outside those
calls.** This distinction matters when choosing the next scheduling experiment.

The [compact interval evidence](development02-causal-intervals.json) retains all
32 original graphical arms from
[run 45436083078](https://github.com/techrote/cybersand/actions/runs/45436083078):
source D/C/C/D and slots 2/3/3/2 on both registered workloads and both platforms.
The original failed workflow, adverse three-slot results and complete corrected
read-only replays remain unchanged. This is supplemental analysis of retained
traces, not another workload execution or a replacement acceptance gate.

## What the clocks establish

For each consecutive pair of genuinely completed Rapier steps, the new
[stdlib interval reader](../../../tools/pubpres_final/causal_intervals.py) joins
the next step's independent native observation by exact World generation,
native tick and completed body sample. It then retains these four clocks:

1. Previous actual physical completion.
2. The existing native result-capture entry observed independently by the
   qualification subclass, an upper bound on native completion.
3. Start of the real callback that successfully completes the next step.
4. The next actual physical completion.

The three adjacent differences sum to that physical gap. All 32 retained arms
have 143 correctly ordered intervals in the common first-144-step window.
Every measured completion in these continuation-off arms has execution kind
`physics_callback`; none of these interval labels hides a deferred continuation.
The reader preserves any missing or nonordered internal boundary explicitly,
with its original clocks and known physical gap, instead of moving a boundary
or silently dropping it from the tail inventory.

Main publication intervals are the actual `consume_render_snapshot` entry and
return around a transaction that changes the accepted uploaded serial. The
reader unions overlapping, duplicate and adjacent intervals before intersecting
them with each physical-gap partition. An overlap therefore counts once. It
measures elapsed Main transaction occupancy, including waits and descheduling;
it is neither CPU utilization nor an identified driver/GPU operation.

The post-native interval does **not** certify every physical prerequisite was
already installed. It can contain physical-packet delivery, terrain installation
and Main scheduling. The independently observed matching native completion is a
specific boundary, not permission to bypass any of those dependencies.

## Source comparison: where the inter-step time occurred

The following ranges cover all four original D/C/C/D processes independently;
percentages are ratios of summed durations within each process, not averages of
percentiles. The full packet retains each arm and its p50/p95/p99/max.

| Platform and registered workload | Previous physical completion to native observation | Native observation to successful callback | Successful callback to physical completion | Publication overlap as a share of the post-native/pre-callback interval |
| --- | ---: | ---: | ---: | ---: |
| Windows Wave512 reference | 5.4–9.2% | 87.4–91.4% | 1.2–3.4% | 64.7–72.4% |
| Windows current-Wave2048 | 39.5–48.4% | 49.4–57.7% | 1.3–2.8% | 67.6–75.5% |
| Linux Wave512 reference | 4.7–5.1% | 94.0–94.4% | 0.8–1.0% | 0.035–0.121% |
| Linux current-Wave2048 | 63.2–65.1% | 33.4–35.6% | 1.2–1.6% | 0–0.120% |

Windows used AMD EPYC 9V74 and Microsoft Basic Render Driver through ANGLE.
Linux used Intel Xeon 6975P-C and llvmpipe. These platform contrasts are
descriptive; they are not a controlled attribution to an API or driver because
the hosts, operating systems and renderers differ. Within each platform, the
registered source controls and physical trajectory checks remain as recorded.

Two concrete Windows intervals illustrate the boundary placement. These are
the longest intervals in the first candidate process of each source cohort;
the complete all-arm statistics remain the decision evidence.

| First C process | Physical gap | Previous completion to native observation | Post-native to callback | Callback to completion | Unioned publication overlap in the post-native interval | Recorded solver elapsed |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Wave512, step 50 | 253.256 ms | 7.102 ms | 244.987 ms | 1.167 ms | 233.854 ms | 0.126 ms |
| Current-Wave2048, step 109 | 769.683 ms | 25.213 ms | 740.836 ms | 3.634 ms | 733.463 ms | 0.599 ms |

In the corresponding first Linux C processes, the longest Wave512 gap was
90.312 ms, including 85.201 ms after native observation and **zero** publication
overlap in that interval. The longest current-Wave2048 gap was 244.052 ms,
including 155.103 ms before native observation and 88.066 ms after it, again
with zero publication overlap. A short upload function therefore does not
establish prompt access to a successful physics callback.

## Native computation and worker dispatch remain distinct unknowns

Every original causal sidecar in these 32 captures contains only its identity
record with `enabled=false`. The base observer retains native completion and a
matching native profiler duration, but **does not retain native start**.
`worker_snapshot.start_usec` is the entry to snapshot publication and must not
be relabeled as native start.

The compact evidence separately joins the reported `native_tick_ms` to healthy
packets for each exact World/tick/body-sample/terrain identity. It also retains
the difference between source native completion and the independent observation.
It does not subtract the profiler duration from a different clock to invent a
dispatch or wake interval. Consequently, the first partition includes worker
admission/wakeup, native calculation and other owner work whose individual
timeline contributions cannot be recovered from this capture.

The common window contains 144 completed physical steps and 143 complete gaps.
It excludes the capture edges before the first and after the last completion.
Threshold inventories at 100/250/500/1000 ms are inherited descriptive reporting
thresholds, not owner-approved playability budgets.

## What this permits us to test

The Windows traces justify measuring a presentation policy that can remove an
entire unnecessary accepted Full-image transaction while preserving native,
terrain and physical authority. They do not establish that the removed duration
would become available physics time: rendering, synchronization or other work
can retain or move the wait. Material and submitted-pose age can also worsen.

The recovered [Full/Target negative](historical-evidence.md) remains a direct
warning against selecting by publication-call time. Target substantially reduced
its submission-call duration without a repeatable complete-gameplay gain.
Likewise, the [three-slot negative](development02-windows-independent-decision.md)
retains correct histories while showing worse Windows physical progression.
Neither result is reclassified by this interval audit.

Any completion-count or age-bounded policy therefore still needs matched real
Rapier rates and gap tails, first input-admission latency, submitted physical
pose/Follow freshness, material age, CPU cost, ordinary painting and all existing
ownership/history gates. The new same-executable renderer-owner comparison is
also separate: repairing font Image ownership enables startup testing and makes
no claim to remove Godot's Main/render rendezvous.

## Reproduction and evidence custody

Run the reader against the retained graphical payload directories:

```sh
python3 tools/pubpres_final/causal_intervals.py \
  --input <linux-graphical-payload> \
  --input <windows-graphical-payload> \
  --output <new-interval-report.json>
```

Every raw trace is rehashed against its original receipt. The independent
callback/native/body/terrain/command witnesses are rechecked, and the causal
sidecar must bind the same trace, source and capture clocks. The full original
frozen source/runtime/GPU/Water gates remain the responsibility of the separately
retained complete replays; this diagnostic reader does not replace them.

The complete local interval report is 6,538,805 bytes, SHA-256
`99abdf57f390d329bdecb51adf70475a8ab67fdd4056c2a503ec650ce9ec1422`.
The compact committed report preserves exact input identities, all 32 arms,
first-144 partitions, unioned overlaps, tail inventories and illustrative longest
intervals. It records both reader source hashes. Four focused adversarial test
methods pass: nested/duplicate/adjacent unions, clipped partition conservation,
missing/reversed boundary retention, and invalid clock domains.
Specialist A independently reviewed the interval source and its joins to the
actual observer boundaries and found no blocking issue.

The original archives are Linux artifact `14943496499`, SHA-256
`afd69e365ee244fbc5d31dada33c3f3a0d85e30d6cc88cceb453db94880e3361`, and Windows
artifact `14945083776`, SHA-256
`2420a9f5fe066bafc7be60892cb07217cceb6ccb9810739af1eadf689cf26688`.
All raw outputs remain available under their original source and run identities.
