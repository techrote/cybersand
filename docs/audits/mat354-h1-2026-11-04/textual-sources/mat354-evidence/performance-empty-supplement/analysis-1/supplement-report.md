# Empty-world performance supplement

**All80 preregistered processes executed; performance acceptance remains pending.** The successor's higher epoch-wrap cost persists. The primary cohort remains unchanged, and this empty-only supplement does not dispose Water PressureFlow observations.

The root acknowledged plan SHA `de2b592d03d9bf0198ed59d48d16bbbc7df581779482bd5954414233e740cf3d` and driver SHA `0b986b9370f11ada9726c53c9b4a826e3ef8a2d79b85dc21207d7b0470bcfc64` before launch. Exact original F2 binaries ran20 alternating AB/BA pairs at each of configured workers1/4. Each fresh32-chunk empty World runs1024 ticks after32 warmup ticks on a separate throwaway World. There were no other owned local process tasks during timing; this does not guarantee host-wide isolation. Affinity was observed as0–8 and was not modified.

## Whole-tick measurements

Values are µs. Means retain every sample. Medians/p95/p99 are medians of the20 individual run statistics. CPU is process CPU with1µs nominal resolution.

| Workers | Clock | Baseline mean | H1 mean | Δ µs | Δ % | Median B→H1 | p95 B→H1 | p99 B→H1 | Positive paired means |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | wall | 2.131575 | 2.269931 | +0.138357 | +6.49% | 1.132→1.001 | 1.252→1.042 | 3.170→2.238 | 13/20 |
| 1 | cpu | 2.424121 | 2.444629 | +0.020508 | +0.85% | 1.000→1.000 | 2.000→2.000 | 4.500→3.000 | 13/20 |
| 4 | wall | 2.110948 | 2.075274 | -0.035674 | -1.69% | 1.132→1.001 | 1.162→1.141 | 4.086→2.829 | 14/20 |
| 4 | cpu | 2.327002 | 2.301074 | -0.025928 | -1.11% | 1.000→1.000 | 2.000→2.000 | 5.000→4.500 | 14/20 |

## Fixed epoch and non-epoch strata

The fixed epoch-wrap ticks are256,511,766,1021, derived from the fresh World's byte epoch0 and reset-to1 behavior. These ticks remain in all whole-tick statistics. Their separate reduction is explanatory; no outlier is dropped.

| Workers | Stratum | Clock | Mean B→H1 µs | Relative change | Positive pairs |
|---:|---|---|---:|---:|---:|
| 1 | epoch_wrap | wall | 141.617→253.176 | +78.77% | 18/20 |
| 1 | epoch_wrap | cpu | 142.125→253.675 | +78.49% | 18/20 |
| 1 | non_epoch_wrap | wall | 1.585→1.286 | -18.84% | 2/20 |
| 1 | non_epoch_wrap | cpu | 1.876→1.459 | -22.22% | 4/20 |
| 4 | epoch_wrap | wall | 157.721→205.923 | +30.56% | 17/20 |
| 4 | epoch_wrap | cpu | 158.075→206.488 | +30.63% | 17/20 |
| 4 | non_epoch_wrap | wall | 1.501→1.276 | -14.98% | 6/20 |
| 4 | non_epoch_wrap | cpu | 1.716→1.500 | -12.58% | 6/20 |

Epoch CPU rises78.49% in the one-worker cohort and30.63% in the four-worker cohort, while non-epoch cost improves. Whole-tick means are sensitive to these opposite contributions and run-level outliers; improved whole-tick medians do not resolve the persistent wrap increase. The unchanged normalized epoch-clearing instruction prefix does not identify its cause. No causal claim that host interference or source code explains all variation is established.

## Integrity, scope and disposition

The independent arithmetic reduction authenticates160 raw output facts and all81,920 contiguous tick rows, recomputes every per-run window quantile and every paired ratio, and confirms exact original binary hashes. All samples have zero jobs, visits, active blocks, observed claimants, deadline changes and counted allocations; resident_cell_bytes remains4,202,496. Final empty physical/tuple identity matches the primary cohort. Complete heap/RSS, hardware counters, frequency and host-wide scheduling are not measured.

No numerical H1 acceptance threshold exists. An owner performance disposition and independent final review remain required. The primary results, primary failed evidence and Water PressureFlow timing observations are retained without reclassification.
