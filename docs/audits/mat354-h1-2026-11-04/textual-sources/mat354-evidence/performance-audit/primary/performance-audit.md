# MAT354 H1 primary performance audit

**Execution and finite work are verified; performance disposition remains pending.** No primary sample is discarded and no acceptance threshold is introduced.

The frozen successor is `9d218bb179e72e9fa68b755d82680dbd739fb85e`, tree `d025ee050b8c782873161443428f804dd1622cfb`. The accepted baseline is `751edc0b495dc85484ad5509a7c95f863651c76b`. Source inventories, compiled dependencies, compiler/binary hashes, the completed correctness receipt, and all 672 raw-output facts authenticate.

## Coverage and measurement

The same host/compiler/binaries executed 14 workloads at configured workers1/4, five alternating AB/BA pairs each: 280 primary runs and 286,720 timed ticks. The 56 diagnostic replays contribute 57,344 separate trace ticks; their timings are never pooled. The observed host is AMD EPYC 9V74 80-Core Processor / Linux-6.18.57-x86_64-with-glibc2.39, with 9 reported logical CPUs.

Each measured World begins fresh after a separate32-tick throwaway warmup. Each row times World::tick only; first-conversion elapsed time also includes observation overhead. POSIX process CPU includes workers, with1000ns nominal resolution. Medians/p95 below are medians of the five per-run values; mean includes all5120 primary ticks per source/workload/worker setting.

## Absolute and relative primary costs

Wall and CPU values are microseconds per tick. Ratios compare successor to baseline. Every individual run, paired difference, p99, maximum and variance is retained in the JSON.

| Workload | Workers | Wall mean old→new µs | Wall ratio | Wall median old→new µs | Wall p95 old→new µs | CPU mean old→new µs |
|---|---:|---:|---:|---:|---:|---:|
| empty | 1 | 1.841→3.036 | 1.650× | 1.131→1.001 | 1.172→1.973 | 2.020→3.307 |
| inert | 1 | 1.017→1.073 | 1.055× | 0.331→0.300 | 0.361→0.461 | 1.235→1.290 |
| cold1 | 1 | 0.185→14.984 | 81.077× | 0.101→15.633 | 0.130→24.256 | 0.380→15.231 |
| cold16 | 1 | 4.203→329.811 | 78.465× | 0.601→350.889 | 1.052→623.971 | 4.379→330.123 |
| cold64 | 1 | 13.669→1508.869 | 110.383× | 2.244→1664.763 | 4.187→2674.128 | 13.902→1509.321 |
| hot180 | 1 | 0.937→0.768 | 0.820× | 0.101→0.100 | 0.140→0.120 | 1.120→0.924 |
| mixed | 1 | 13.120→187.981 | 14.327× | 1.142→177.663 | 44.387→364.319 | 13.330→188.599 |
| ice_pair | 1 | 8.752→8.124 | 0.928× | 0.341→0.301 | 31.247→34.381 | 8.950→8.421 |
| compact_pair | 1 | 1.988→1.525 | 0.767× | 0.331→0.300 | 0.541→0.501 | 2.182→1.700 |
| water_fm | 1 | 0.486→0.510 | 1.050× | 0.101→0.100 | 0.130→0.190 | 0.678→0.731 |
| water_cy | 1 | 24.207→19.962 | 0.825× | 16.054→15.453 | 29.815→31.878 | 24.462→20.148 |
| water_pf | 1 | 155.934→165.084 | 1.059× | 123.040→171.939 | 235.185→239.230 | 156.253→165.586 |
| water_in | 1 | 0.233→0.219 | 0.940× | 0.110→0.100 | 0.150→0.120 | 0.461→0.392 |
| paste | 1 | 0.228→0.172 | 0.756× | 0.100→0.100 | 0.120→0.120 | 0.392→0.356 |
| empty | 4 | 2.753→3.090 | 1.123× | 1.132→1.002 | 1.172→1.563 | 2.924→3.292 |
| inert | 4 | 2.010→1.173 | 0.583× | 0.331→0.300 | 0.621→0.471 | 1.838→1.590 |
| cold1 | 4 | 0.669→42.722 | 63.905× | 0.110→42.424 | 0.161→75.924 | 0.617→46.788 |
| cold16 | 4 | 3.657→251.433 | 68.762× | 0.600→306.954 | 1.122→439.212 | 5.181→452.783 |
| cold64 | 4 | 9.741→819.444 | 84.125× | 2.243→980.634 | 2.294→1476.427 | 16.130→1560.715 |
| hot180 | 4 | 1.184→1.095 | 0.925× | 0.101→0.100 | 0.120→0.130 | 1.413→1.328 |
| mixed | 4 | 15.321→153.329 | 10.008× | 2.143→187.152 | 67.281→293.453 | 20.849→245.834 |
| ice_pair | 4 | 18.822→19.612 | 1.042× | 0.621→0.560 | 75.985→70.085 | 21.776→22.156 |
| compact_pair | 4 | 1.949→1.793 | 0.920× | 0.331→0.300 | 0.380→0.331 | 2.740→2.635 |
| water_fm | 4 | 0.974→1.449 | 1.488× | 0.110→0.101 | 0.190→0.171 | 1.245→1.747 |
| water_cy | 4 | 62.821→60.811 | 0.968× | 43.486→42.489 | 97.587→97.767 | 67.378→63.091 |
| water_pf | 4 | 165.128→151.452 | 0.917× | 108.448→103.751 | 281.204→273.361 | 163.145→148.573 |
| water_in | 4 | 0.599→0.665 | 1.109× | 0.110→0.100 | 0.151→0.150 | 0.735→0.968 |
| paste | 4 | 0.754→1.159 | 1.538× | 0.110→0.100 | 0.130→0.170 | 1.035→1.266 |

## Finite work, deadlines and retirement

All12 observations for each workload/source (five runs at each worker setting plus both diagnostic replays) have identical recorded job/visit/block/deadline/source-state trajectories. All ten control workloads preserve these complete recorded trajectories and final physical/tuple identity across sources. Every primary/diagnostic tick has zero chunk/temperature allocations and unchanged resident_cell_bytes.

| Workload | Jobs old→new | Visited cells old→new | Successor final MoltenGlass/Glass | Last successor job | Deadline changes old→new | Tail jobs |
|---|---:|---:|---:|---:|---:|---:|
| empty | 0→0 | 0→0 | 0/0 | 0 | 0→0 | 0 |
| inert | 24→24 | 0→0 | 0/0 | 3 | 0→0 | 0 |
| cold1 | 3→723 | 3→720 | 0/1 | 723 | 0→360 | 0 |
| cold16 | 103→16945 | 77→11497 | 0/16 | 723 | 0→5756 | 0 |
| cold64 | 396→68856 | 296→45984 | 0/64 | 723 | 0→23012 | 0 |
| hot180 | 3→3 | 432→432 | 144/0 | 3 | 0→0 | 0 |
| mixed | 436→8680 | 740→6452 | 16/8 | 723 | 111→2987 | 0 |
| ice_pair | 340→340 | 646→646 | 0/0 | 513 | 106→106 | 0 |
| compact_pair | 55→55 | 74→74 | 0/0 | 6 | 14→14 | 0 |
| water_fm | 12→12 | 30→30 | 0/0 | 12 | 0→0 | 0 |
| water_cy | 1024→1024 | 1024→1024 | 0/0 | 1024 | 0→0 | 256 |
| water_pf | 144→144 | 430→430 | 0/0 | 144 | 0→0 | 0 |
| water_in | 3→3 | 3→3 | 0/0 | 3 | 0→0 | 0 |
| paste | 3→3 | 3→3 | 0/0 | 3 | 0→0 | 0 |

Cold1/16/64 and mixed finish added work bytick723. All have zero tail jobs/visited cells/active blocks; all observed cooling deadline changes end bytick720. Hot180 keeps144 MoltenGlass cells, executes only the original3 jobs/432 visits, and sleeps. Water CY's256 tail jobs are unchanged historical behavior. PressureFlow has zero tail jobs but retains its existing nonzero tick cost; zero scheduled jobs must not be equated with zero whole-tick CPU.

Cold1 diagnostic execution records180 due-lane entries and540 ordinary off-lane entries, then one Glass conversion. Multicell diagnostics record actual aggregate entries/conversions but do not individually identify every cell's due/off-lane visit. Deadline-change observations are not counts of all coalesced requests.

## Variance and unresolved performance observations

The epoch wraps occur at256,511,766,1021 from an initial epoch0. The source and normalized compiled epoch-clearing instruction prefix are unchanged; address/layout differs. The audit splits these predetermined ticks only for explanation and retains them in every primary mean.

Empty workers1: mean 1.840658→3.036268µs. Wrap samples average 113.456→266.353µs; their contribution to the all-tick delta is +0.597254µs. Non-wrap contribution is +0.598356µs. Every empty tick has zero jobs/visits/deadline changes.

Empty workers4: mean 2.752735→3.090159µs. Wrap samples average 232.988→333.825µs; their contribution to the all-tick delta is +0.393896µs. Non-wrap contribution is -0.056472µs. Every empty tick has zero jobs/visits/deadline changes.

The largest one-worker successor empty tick is repeat1/tick725:1733.753µs wall and1736µs process CPU, with zero jobs. Tick737 adds955.796µs wall/957µs CPU. CPU follows these spikes, so ordinary descheduling alone does not explain them. Empty means and Water PressureFlow variance require disposition; improved medians do not erase the mean increases.

## Observed worker scaling

These are cohort ratios, not separately paired worker-count experiments. Values below are successor observations; actual claimant counts and CPU ratios prevent interpreting a configured four-worker setting as four-way useful parallelism.

| Workload | Wall speedup 1÷4 | CPU cost 4÷1 | Actual claimants at4 |
|---|---:|---:|---:|
| empty | 0.983× | 0.995× | 0 |
| inert | 0.915× | 1.232× | 4 |
| cold1 | 0.351× | 3.072× | 1 |
| cold16 | 1.312× | 1.372× | 4 |
| cold64 | 1.841× | 1.034× | 4 |
| hot180 | 0.702× | 1.438× | 1 |
| mixed | 1.226× | 1.303× | 4 |
| ice_pair | 0.414× | 2.631× | 4 |
| compact_pair | 0.851× | 1.550× | 4 |
| water_fm | 0.352× | 2.391× | 1 |
| water_cy | 0.328× | 3.131× | 1 |
| water_pf | 1.090× | 0.897× | 1 |
| water_in | 0.330× | 2.470× | 1 |
| paste | 0.149× | 3.559× | 1 |

Cold64 benefits from four actual claimants; cold1 has one and pays substantially higher four-worker coordination cost. Existing one-claimant Water CY has the same direction of scaling loss. These measurements are preserved as performance risks, without changing unrelated scheduler policy.

## Limits and disposition

- All 1024 primary ticks and all five pairs remain in primary metrics; epoch/non-epoch strata and largest ticks are explanation only.
- Within-run ticks are correlated. Five run-level observations are retained; no artificial independent-5120-sample confidence claim.
- Process CPU resolution is 1000ns; includes worker CPU and surrounding wall-clock calls. Quantized zero/submicrosecond observations remain unchanged.
- TickStats covers chunk/temperature allocations only. resident_cell_bytes omits hash nodes, scheduler buffers, total heap/RSS. Complete heap/RSS evidence is unavailable.
- Benchmark quantity evidence is cold MoltenGlass+Glass conservation and exact final tuple/control identity. Full Water ledgers are in the separate source-qualified correctness packet.
- Only singleton diagnostic material entries identify per-cell execution. Multicell per-source thermal/off-lane visits and every coalesced deadline request are not directly observable.
- No stale-wake creation/retirement event counter exists in this apparatus. Recorded deadline changes and last jobs bound observed activity, without counting every request.
- All workload/source repeats and worker settings preserve complete recorded work/state traces plus final physical/tuple identity. Benchmark rows do not carry full per-tick physical hashes.
- Configured four workers can yield one actual claimant; small cold1 and Water fixtures are not distributed scaling proofs.
- The worker1 and worker4 cohorts run in fixed separate windows, not interleaved cross-worker pairs; host variance can affect scaling estimates.
- No other owned task ran during the primary cohort according to root orchestration; no host-wide isolation/frequency/affinity or representative-target-hardware guarantee is established by receipts.
- Empty-world mean and epoch-reset CPU increases remain unresolved performance observations. Unchanged source/normalized instructions do not prove a benign cause.
- No numerical H1 budget exists. This audit does not grant performance acceptance, compatibility adoption, final independent GO, or merge permission.
