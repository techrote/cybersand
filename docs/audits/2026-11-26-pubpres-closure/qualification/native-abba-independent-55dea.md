# Independent actual-task completion decision

**NOT_SELECTED / DEFAULT OFF. Retain the existing all-worker completion path.**

Specialist C independently reduced all eight raw captures from the registered
0/1/1/0 comparison. All captures pass the unchanged independent physical reducer;
the treatment executed real tasks and retained equal-step physical trajectories.
Neither workload meets the original necessary performance criteria. This is an
adverse selection result, not an application crash, an unexercised selector, or a
native correctness failure.

## Exact experiment

Application and driver: `55dea232aaeee8cda32fd85fd5b3cfd628848469`.
Linux native: `a908b78028bd7e0ebe173b3f75a9ac143f863e20be66589b224cac3bbfd205b4`.
Stock Safe engine: `f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The local GCC 14.2.0 toolchain drift was explicit. This experiment does not replace
fresh pinned Linux or Windows platform qualification. Every arm used the same
application, native binary, engine, scene and observer bytes on the same host.
It does not establish performance of the subsequently integrated application.

The original criterion requires both candidate rates to exceed both controls,
without worse maximum/p99 gaps or material/selected-pose age than the worse
control. The older generic reducer's stricter p95/p99 direction remains separately
reported; it has not been substituted for this registration. Selection already
fails on the original primary rate criterion for both workloads.

## Physical progression

Values below use the original first 144 completed physical steps, measured from
the recorded capture start. Intervals contain the 143 consecutive completion
gaps. These are actual native/Rapier completions, not rendered FPS.

| Workload | Arm | Real steps/s | Gap p50 ms | Gap p95 ms | Gap p99 ms | Max gap ms | Gaps >100 ms |
|---|---|---:|---:|---:|---:|---:|---:|
| Wave512 | Control 0 | 22.550 | 42.132 | 58.420 | 67.349 | 124.179 | 1 |
| Wave512 | Actual tasks 1 | 22.157 | 42.704 | 56.342 | 101.865 | 130.434 | 2 |
| Wave512 | Actual tasks 2 | 21.677 | 42.005 | 57.082 | 147.725 | 178.086 | 3 |
| Wave512 | Control 3 | 22.629 | 41.219 | 55.179 | 129.126 | 145.544 | 3 |
| Wave2048 | Control 0 | 8.603 | 128.527 | 174.587 | 185.731 | 226.099 | 91 |
| Wave2048 | Actual tasks 1 | 8.910 | 123.678 | 174.279 | 181.335 | 188.689 | 90 |
| Wave2048 | Actual tasks 2 | 8.852 | 123.101 | 173.659 | 206.579 | 225.852 | 88 |
| Wave2048 | Control 3 | 8.877 | 123.527 | 178.287 | 230.545 | 243.299 | 92 |

Both small-world candidates are slower than both controls. The second large-world
candidate is slower than the better control; both-candidate improvement is not
established. Large-world physical gaps above 100 ms remain frequent. None of
these first-144 windows contains a gap above 250, 500 or 1,000 ms. The machine
report also preserves whole-capture intervals; it does not replace those values
with first-window averages.

## Material and actor freshness

These ages independently join actual Main pre-draw submissions to witnessed
material upload provenance and completed physical steps. They do not measure GPU
completion, compositor delivery, physical display scanout, or input-to-visible
latency.

| Workload | Arm | Material p99 / max ms | Selected pose p99 / max ms |
|---|---|---:|---:|
| Wave512 | Control 0 | 76.955 / 115.595 | 9.520 / 9.994 |
| Wave512 | Actual tasks 1 | 67.972 / 136.134 | 15.903 / 22.934 |
| Wave512 | Actual tasks 2 | 163.271 / 202.540 | 21.218 / 30.369 |
| Wave512 | Control 3 | 126.439 / 162.268 | 13.529 / 23.292 |
| Wave2048 | Control 0 | 173.198 / 185.383 | 135.242 / 141.523 |
| Wave2048 | Actual tasks 1 | 185.229 / 190.470 | 133.656 / 141.206 |
| Wave2048 | Actual tasks 2 | 203.071 / 265.312 | 147.897 / 178.160 |
| Wave2048 | Control 3 | 179.479 / 262.113 | 149.079 / 191.828 |

The second small-world candidate exceeds the worse control in both physical
gap tails and material/pose tails. Large-world material tails also exceed the
worse control. The apparent modest throughput gain in one large-world arm does
not establish better ordinary interaction.

Three control arms each have one transient withheld body submission; candidate
captures contain none. Initial visible poses and material that precede the
capture's trace are explicitly counted as unjoined. No zero-omission or full
display-visibility claim is inferred from this one-body fixture. Original
submitted geometry and ownership checks remain mandatory.

## Treatment, parity and resources

Every candidate reports `actual_tasks` before and after capture, with positive
actual completed dispatch and task counts. Controls report `all_workers`.
Each large-world arm records 1,450 completed dispatches and 142,029 actual tasks.
Small-world whole captures record 1,530–1,614 dispatches and 9,596–10,136 tasks;
their total step counts differ because the original capture duration also has a
minimum elapsed-time requirement. Comparing these totals alone would be invalid.
All four arms within each workload have identical first-144 body trajectories
and admitted movement sequences. All eight process IDs agree with actual
application sampling; bounded presentation captures report no dropped or invalid
rows.

Sampled peak process RSS is approximately 1,175–1,183 MiB for Wave512 and
1,387–1,407 MiB for Wave2048. Process-lifetime mean CPU is approximately 3.18–3.25
and 4.29–4.40 core equivalents respectively. These observations include setup and
the software renderer, and are not capture-aligned CPU measurements. End samples
remain below sampled peaks, but these short sessions cannot establish sustained
retention, leak freedom or bounded GPU resource memory. They do not justify a
resource-based promotion.

## Reproduction and retained evidence

`native-abba-independent-55dea.json` contains all 16 independently reconstructed
physical/freshness windows, actual task counts, hashes, resource observations,
original necessary criteria and separate stricter direction results.
`native-abba-physical-reduction-55dea.json.gz` preserves the complete independently
generated physical reduction without changing its original bytes.

Run the unchanged `tools/pubpres_final/independent_reduction.py` on the retained
original campaign, then run this directory's `review_native_abba.py` with
`--campaign`, `--physical-reduction` and `--output`. The second reader imports no
shared quantile, selection or presentation-age helper. It independently joins
raw clocks, verifies receipt/trace hashes and rejects disagreement with published
aggregates. The original complete physical and submitted-geometry readers remain
the broader correctness authorities.

The earlier process-sampler admission failure remains a distinct retained
apparatus failure. It has not been relabelled as this successor's performance
result. No further unchanged actual-task campaign is warranted: keep the
candidate available for research with its default disabled, and continue product
qualification using the existing all-worker path.
