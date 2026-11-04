## Native performance qualification — measured, owner disposition pending

The primary source-qualified comparison used accepted main `751edc0b495dc85484ad5509a7c95f863651c76b` (tree `b0d42a256285e6049a6d3bdd1613d7ecd89f43c6`) and frozen F2 `9d218bb179e72e9fa68b755d82680dbd739fb85e` (tree `d025ee050b8c782873161443428f804dd1622cfb`). World SHA-256 values are `b7a129f44eccc7c33dbd2f0d84802ab096140dcaa9b5b3a83d45dd3bf85fbad1` and `df0bb080084972c49ca400b7bfc6504f7ec27fa474112bc2bd56abe5d3d21539`. Later public source-anchor metadata reconciliation is separate and does not rewrite these execution identities.

Measurements ran on AMD EPYC9V74 / Linux6.18.57 / x86_64,9 reported logical CPUs, GCC13.3.0, identical `-O3 -DNDEBUG` source-qualified build flags. Primary protocol:14 workloads × workers1/4 ×5 AB/BA pairs =280 processes/286,720 timed ticks;56 separate diagnostic replays supply57,344 work-trace ticks. Each measured World is fresh, after32 warmup ticks on a separate World, then1024 retained ticks. No other owned local work ran during timing; host-wide isolation is not established.

The tables report µs per tick. Wall mean includes every tick across all five runs. Median/p95 are medians of the five corresponding per-run statistics. σ is population SD across the five run means, not across an assumed independent5120-tick sample. CPU mean is process CPU including worker time, at1µs nominal resolution; CPU/wall are distinct observations. Full p99/max, raw values, all individual runs/pairs and variance are retained in the audit packet.

### Configured workers1

| Workload | Wall mean B→H1 | Δ µs (%) | Median B→H1 | p95 B→H1 | Run-mean σ B→H1 | CPU mean B→H1 (Δ%) |
|---|---:|---:|---:|---:|---:|---:|
| empty | 1.841→3.036 | +1.196 (+64.96%) | 1.131→1.001 | 1.172→1.973 | 0.325→1.190 | 2.020→3.307 (+63.77%) |
| inert | 1.017→1.073 | +0.056 (+5.49%) | 0.331→0.300 | 0.361→0.461 | 0.161→0.202 | 1.235→1.290 (+4.48%) |
| cold1 | 0.185→14.984 | +14.799 (+8007.72%) | 0.101→15.633 | 0.130→24.256 | 0.017→1.227 | 0.380→15.231 (+3907.30%) |
| cold16 | 4.203→329.811 | +325.608 (+7746.51%) | 0.601→350.889 | 1.052→623.971 | 1.963→34.667 | 4.379→330.123 (+7439.60%) |
| cold64 | 13.669→1508.869 | +1495.200 (+10938.33%) | 2.244→1664.763 | 4.187→2674.128 | 3.693→199.487 | 13.902→1509.321 (+10757.20%) |
| hot180 | 0.937→0.768 | -0.169 (-18.03%) | 0.101→0.100 | 0.140→0.120 | 0.272→0.092 | 1.120→0.924 (-17.49%) |
| mixed | 13.120→187.981 | +174.860 (+1332.73%) | 1.142→177.663 | 44.387→364.319 | 2.672→20.367 | 13.330→188.599 (+1314.84%) |
| ice_pair | 8.752→8.124 | -0.628 (-7.18%) | 0.341→0.301 | 31.247→34.381 | 0.935→0.448 | 8.950→8.421 (-5.92%) |
| compact_pair | 1.988→1.525 | -0.463 (-23.30%) | 0.331→0.300 | 0.541→0.501 | 0.427→0.204 | 2.182→1.700 (-22.10%) |
| water_fm | 0.486→0.510 | +0.024 (+4.97%) | 0.101→0.100 | 0.130→0.190 | 0.152→0.123 | 0.678→0.731 (+7.75%) |
| water_cy | 24.207→19.962 | -4.245 (-17.54%) | 16.054→15.453 | 29.815→31.878 | 3.415→1.674 | 24.462→20.148 (-17.64%) |
| water_pf | 155.934→165.084 | +9.150 (+5.87%) | 123.040→171.939 | 235.185→239.230 | 18.263→8.411 | 156.253→165.586 (+5.97%) |
| water_in | 0.233→0.219 | -0.014 (-6.05%) | 0.110→0.100 | 0.150→0.120 | 0.084→0.034 | 0.461→0.392 (-14.96%) |
| paste | 0.228→0.172 | -0.056 (-24.43%) | 0.100→0.100 | 0.120→0.120 | 0.082→0.003 | 0.392→0.356 (-9.22%) |

### Configured workers4

| Workload | Wall mean B→H1 | Δ µs (%) | Median B→H1 | p95 B→H1 | Run-mean σ B→H1 | CPU mean B→H1 (Δ%) |
|---|---:|---:|---:|---:|---:|---:|
| empty | 2.753→3.090 | +0.337 (+12.26%) | 1.132→1.002 | 1.172→1.563 | 0.950→0.597 | 2.924→3.292 (+12.60%) |
| inert | 2.010→1.173 | -0.837 (-41.66%) | 0.331→0.300 | 0.621→0.471 | 1.604→0.241 | 1.838→1.590 (-13.51%) |
| cold1 | 0.669→42.722 | +42.053 (+6290.50%) | 0.110→42.424 | 0.161→75.924 | 0.585→4.322 | 0.617→46.788 (+7480.76%) |
| cold16 | 3.657→251.433 | +247.777 (+6776.25%) | 0.600→306.954 | 1.122→439.212 | 1.262→12.834 | 5.181→452.783 (+8639.53%) |
| cold64 | 9.741→819.444 | +809.703 (+8312.47%) | 2.243→980.634 | 2.294→1476.427 | 1.082→48.351 | 16.130→1560.715 (+9575.93%) |
| hot180 | 1.184→1.095 | -0.089 (-7.54%) | 0.101→0.100 | 0.120→0.130 | 0.546→0.092 | 1.413→1.328 (-5.99%) |
| mixed | 15.321→153.329 | +138.008 (+900.78%) | 2.143→187.152 | 67.281→293.453 | 1.290→11.237 | 20.849→245.834 (+1079.14%) |
| ice_pair | 18.822→19.612 | +0.790 (+4.20%) | 0.621→0.560 | 75.985→70.085 | 1.944→5.138 | 21.776→22.156 (+1.75%) |
| compact_pair | 1.949→1.793 | -0.156 (-8.02%) | 0.331→0.300 | 0.380→0.331 | 0.249→0.223 | 2.740→2.635 (-3.81%) |
| water_fm | 0.974→1.449 | +0.475 (+48.77%) | 0.110→0.101 | 0.190→0.171 | 0.271→0.478 | 1.245→1.747 (+40.40%) |
| water_cy | 62.821→60.811 | -2.009 (-3.20%) | 43.486→42.489 | 97.587→97.767 | 7.667→8.712 | 67.378→63.091 (-6.36%) |
| water_pf | 165.128→151.452 | -13.675 (-8.28%) | 108.448→103.751 | 281.204→273.361 | 5.228→9.536 | 163.145→148.573 (-8.93%) |
| water_in | 0.599→0.665 | +0.066 (+10.94%) | 0.110→0.100 | 0.151→0.150 | 0.225→0.486 | 0.735→0.968 (+31.80%) |
| paste | 0.754→1.159 | +0.406 (+53.83%) | 0.110→0.100 | 0.130→0.170 | 0.630→0.956 | 1.035→1.266 (+22.33%) |

### Work, retirement and memory bounds

Historical cold sources stop after only a few visits; the successor performs the finite cooling work and converts them. The large cold timing ratios therefore include restored work absent from the defective baseline. They do not establish acceptability by themselves.

| Workload | Jobs B→H1 | Visited cells B→H1 | H1 last job | H1 tail jobs | H1 deadline changes | H1 final Molten/Glass | Actual claimants at4 B→H1 |
|---|---:|---:|---:|---:|---:|---:|---:|
| empty | 0→0 | 0→0 | 0 | 0 | 0 | 0/0 | 0→0 |
| inert | 24→24 | 0→0 | 3 | 0 | 0 | 0/0 | 4→4 |
| cold1 | 3→723 | 3→720 | 723 | 0 | 360 | 0/1 | 1→1 |
| cold16 | 103→16945 | 77→11497 | 723 | 0 | 5756 | 0/16 | 4→4 |
| cold64 | 396→68856 | 296→45984 | 723 | 0 | 23012 | 0/64 | 4→4 |
| hot180 | 3→3 | 432→432 | 3 | 0 | 0 | 144/0 | 1→1 |
| mixed | 436→8680 | 740→6452 | 723 | 0 | 2987 | 16/8 | 4→4 |
| ice_pair | 340→340 | 646→646 | 513 | 0 | 106 | 0/0 | 4→4 |
| compact_pair | 55→55 | 74→74 | 6 | 0 | 14 | 0/0 | 4→4 |
| water_fm | 12→12 | 30→30 | 12 | 0 | 0 | 0/0 | 1→1 |
| water_cy | 1024→1024 | 1024→1024 | 1024 | 256 | 0 | 0/0 | 1→1 |
| water_pf | 144→144 | 430→430 | 144 | 0 | 0 | 0/0 | 1→1 |
| water_in | 3→3 | 3→3 | 3 | 0 | 0 | 0/0 | 1→1 |
| paste | 3→3 | 3→3 | 3 | 0 | 0 | 0/0 | 1→1 |

Across both worker configurations and all repeats, cold1/16/64 and mixed stop added work bytick723; cooling deadline observations cease changing bytick720. All have zero jobs, visits and active blocks throughout tail769–1024. Hot180 retains144 MoltenGlass cells and only the original3 jobs/432 visits. The ten control workloads have exact old/new final physical/tuple identity and complete recorded work/state trajectories. All12 runs per workload/source (five at each worker setting plus both diagnostic replays) have the same work/state trace.

Every measured tick records zero chunk/temperature allocations and constant resident_cell_bytes:131,328 bytes for singleton/small fixtures;2,101,248 for cold16;8,404,992 for cold64;4,202,496 for mixed and the32-chunk empty world. These counters omit general heap/hash/scheduler storage and RSS; they are not a complete memory-growth qualification. Cold1 diagnostics record180 due-lane and540 ordinary off-lane entries, then one conversion. Multicell thermal/off-lane visits are aggregate-only; deadline changes do not count every coalesced request or stale-wake event.

Water CY's256 tail jobs are unchanged existing behavior. PressureFlow has zero tail scheduled jobs while preserving substantial existing whole-tick CPU cost. No zero-CPU-idle claim follows from zero jobs.

### Conversion latency and observed worker cost

The sampled cold source at(11,8) converts at tick720. Elapsed values include between-tick observation/clock overhead; cumulative timed-tick cost is separately retained in receipts.

| Workload | Mean elapsed to sampled Glass,1 worker ms | Mean elapsed,4 workers ms | Four-worker wall speedup | Four/one CPU cost |
|---|---:|---:|---:|---:|
| cold1 | 15.814 | 44.428 | 0.351× | 3.072× |
| cold16 | 338.730 | 257.980 | 1.312× | 1.372× |
| cold64 | 1544.417 | 838.827 | 1.841× | 1.034× |
| mixed | 193.104 | 156.868 | 1.226× | 1.303× |

The inherited Phase A apparatus uses parallel_job_threshold=1; production WorldConfig defaults to8. Thus configured4 with one cold source dispatches the existing pool for one useful claimant and is about2.85× slower in wall time than configured1. This identifies a coordination path but does not attribute every measured delta to it; threshold8 performance was not measured. Cold16/64 and mixed show four real claimants. The worker1 and worker4 cohorts occupy separate windows, so scaling ratios also inherit host variance.

### Preserved outliers and the preregistered empty-only supplement

Primary empty one-worker wall mean is1.840658→3.036268µs (+64.96%) despite median1.131→1.001µs. Fixed epoch resets at256/511/766/1021 contribute +0.597254µs to that +1.195611µs all-tick delta; non-epoch samples contribute +0.598356µs. Successor repeat1/ticks725,737 cost1733.753/955.796µs wall and1736/957µs process CPU with zero jobs. The CPU evidence prevents dismissing them as ordinary descheduling alone.

One separately frozen empty-only supplement used the same binaries,32-chunk geometry,32 warmup/1024 measured ticks,20 AB/BA pairs at each worker count:80 processes/81,920 ticks. Plan SHA `de2b592d03d9bf0198ed59d48d16bbbc7df581779482bd5954414233e740cf3d`; driver SHA `0b986b9370f11ada9726c53c9b4a826e3ef8a2d79b85dc21207d7b0470bcfc64`. All samples, every pair and fixed epoch/non-epoch strata remain retained; no primary result was replaced.

| Workers | All-tick wall mean B→H1 µs | Wall Δ | All-tick CPU mean B→H1 µs | CPU Δ | Wrap CPU B→H1 µs | Wrap positive pairs |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 2.131575→2.269931 | +6.49% | 2.424121→2.444629 | +0.85% | 142.125000→253.675000 | 18/20 |
| 4 | 2.110948→2.075274 | -1.69% | 2.327002→2.301074 | -1.11% | 158.075000→206.487500 | 17/20 |

The primary whole-tick idle increase is not reproduced at the same magnitude. The epoch-wrap CPU increase persists (+78.49% at1worker, +30.63% at4), while non-wrap means improve. The source and normalized compiled epoch-clearing prefix are unchanged, which narrows investigation but does not explain or waive the measured cost. This remains an unresolved performance observation requiring disposition.

Water PressureFlow one-worker primary means rise +5.87% wall/+5.97% CPU, with four of five paired increases; four-worker means fall−8.28% wall/−8.93% CPU. Individual paired/run distributions remain available. The empty-only supplement does not resolve this variance-sensitive observation.

**Performance disposition: pending; no adoption GO.** The repository provides no numerical H1 adoption threshold. Finite work, deterministic controls and bounded recorded allocation/resident behavior are demonstrated, but those facts do not replace an explicit owner performance disposition, representative-target qualification, compatibility resolution and independent final review. No outlier removal, new numerical threshold, scheduler-policy change, runtime adoption or merge is implied.
