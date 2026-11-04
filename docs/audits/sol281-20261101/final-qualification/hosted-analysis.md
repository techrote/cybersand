# SOL281 hosted before/after analysis

Source `8e86ffd4eb2eb769178808a1012701076e3a4d19`; tree `b1f965508b24f9b10658907fff26cf1165e2d520`.

Hosted run: 41331369142, attempt 1. Original host results are retained below; analysis is not an independent qualification gate.

## Execution inventory

| Platform | Cohort | Original status | Cases | Numbered assertions | Ordinary controls | Errors |
| --- | --- | --- | --- | --- | --- | --- |
| Linux | contact-w1 | passed | 9 | 417 | 0 |  |
| Linux | contact-w4 | passed | 9 | 417 | 0 |  |
| Linux | core | passed | 11 | 502 | 4 |  |
| Windows | contact-w1 | passed | 9 | 417 | 0 |  |
| Windows | contact-w4 | passed | 9 | 417 | 0 |  |
| Windows | core | passed | 11 | 502 | 4 |  |

Only complete baseline/candidate pairs from passed hosts appear in the comparison tables. B = ordinary current-main ejection; C = bounded conservative chain displacement. Missing or failed hosts have no inferred physics values.

## Exact quantities and measured body motion

All paired cells show B / C. Translation is in simulation cells; rotation is in radians. Neither quantity is penetration.

| Platform | Workers | Environment | Sand B / C | Water mass B / C | Max translation B / C | Max abs rotation B / C |
| --- | --- | --- | --- | --- | --- | --- |
| Linux | 1 | packed_sand | 1176→1176 / 1176→1176 | 0→0 / 0→0 | 33.1884 / 40.0910 | 0.9260 / 0.6675 |
| Linux | 1 | embedded_sand | 2016→2016 / 2016→2016 | 0→0 / 0→0 | 44.9323 / 33.5724 | 1.0173 / 1.0280 |
| Linux | 1 | mixed | 658→658 / 658→658 | 132090→132090 / 132090→132090 | 42.6518 / 40.4195 | 1.2791 / 0.6641 |
| Linux | 4 | packed_sand | 1176→1176 / 1176→1176 | 0→0 / 0→0 | 53.4215 / 33.0105 | 1.5750 / 0.9538 |
| Linux | 4 | embedded_sand | 2016→2016 / 2016→2016 | 0→0 / 0→0 | 32.9818 / 32.3961 | 1.0264 / 0.4475 |
| Linux | 4 | mixed | 658→658 / 658→658 | 132090→132090 / 132090→132090 | 40.1122 / 40.3350 | 0.6765 / 0.6709 |
| Windows | 1 | packed_sand | 1176→1176 / 1176→1176 | 0→0 / 0→0 | 47.1494 / 40.1013 | 1.2051 / 0.6676 |
| Windows | 1 | embedded_sand | 2016→2016 / 2016→2016 | 0→0 / 0→0 | 45.6118 / 52.7712 | 1.1492 / 1.6552 |
| Windows | 1 | mixed | 658→658 / 658→658 | 132090→132090 / 132090→132090 | 40.1040 / 40.3474 | 0.6765 / 0.6695 |
| Windows | 4 | packed_sand | 1176→1176 / 1176→1176 | 0→0 / 0→0 | 32.3775 / 40.1277 | 0.9472 / 0.6623 |
| Windows | 4 | embedded_sand | 2016→2016 / 2016→2016 | 0→0 / 0→0 | 39.9390 / 45.1200 | 0.9457 / 1.0593 |
| Windows | 4 | mixed | 658→658 / 658→658 | 132090→132090 / 132090→132090 | 32.9406 / 48.5910 | 0.9873 / 1.1420 |

## Native displacement and sampled contact totals

Native attempts, accepts and parcels are strict-mechanism counters. Coupling counts are from accepted main-thread feedback and have a different denominator. Baseline zeros in strict counters do not mean that baseline ejection did no work.

| Platform | Workers | Environment | Attempts B / C | Accepts B / C | Parcels B / C | C multi-parcel | Sampled contacts B / C | Sampled displaced B / C | Sampled unresolved B / C |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Linux | 1 | packed_sand | 0 / 10555 | 0 / 81 | 0 / 195 | True | 65035 / 26826 | 235 / 81 | 29123 / 10412 |
| Linux | 1 | embedded_sand | 0 / 112438 | 0 / 44 | 0 / 81 | True | 98988 / 112662 | 732 / 29 | 37022 / 65654 |
| Linux | 1 | mixed | 0 / 11133 | 0 / 84 | 0 / 209 | True | 51169 / 27340 | 347 / 75 | 24435 / 10628 |
| Linux | 4 | packed_sand | 0 / 64360 | 0 / 14 | 0 / 27 | True | 39326 / 68127 | 356 / 5 | 18561 / 37837 |
| Linux | 4 | embedded_sand | 0 / 35346 | 0 / 87 | 0 / 181 | True | 105913 / 83019 | 358 / 87 | 55258 / 35102 |
| Linux | 4 | mixed | 0 / 10869 | 0 / 83 | 0 / 206 | True | 26091 / 27461 | 296 / 83 | 5953 / 10764 |
| Windows | 1 | packed_sand | 0 / 10552 | 0 / 81 | 0 / 195 | True | 30073 / 26624 | 302 / 81 | 9354 / 10365 |
| Windows | 1 | embedded_sand | 0 / 86818 | 0 / 113 | 0 / 262 | True | 91111 / 102451 | 652 / 108 | 33223 / 60012 |
| Windows | 1 | mixed | 0 / 10905 | 0 / 83 | 0 / 195 | True | 26312 / 26965 | 295 / 83 | 6000 / 10638 |
| Windows | 4 | packed_sand | 0 / 10704 | 0 / 82 | 0 / 171 | True | 66238 / 26560 | 133 / 77 | 29894 / 10192 |
| Windows | 4 | embedded_sand | 0 / 57374 | 0 / 94 | 0 / 213 | True | 95041 / 104392 | 347 / 77 | 47041 / 53705 |
| Windows | 4 | mixed | 0 / 23491 | 0 / 75 | 0 / 175 | True | 63801 / 38891 | 196 / 66 | 30463 / 19522 |

## Candidate final refusal classifications

Target-mask is the recorded `ForeignOccupancy` category and includes own/swept masks. The full JSON retains every category, including zeros, intermediate blocker counts and native transaction outcomes.

| Platform | Workers | Environment | Capacity | Target-mask | Geometry | No vacancy | Unsupported | Other nonzero refusals |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Linux | 1 | packed_sand | 0 | 5522 | 4877 | 56 | 19 | none |
| Linux | 1 | embedded_sand | 99821 | 9511 | 3032 | 8 | 22 | none |
| Linux | 1 | mixed | 0 | 5818 | 5173 | 36 | 22 | none |
| Linux | 4 | packed_sand | 53967 | 8042 | 2309 | 8 | 20 | none |
| Linux | 4 | embedded_sand | 15973 | 11127 | 8096 | 45 | 18 | none |
| Linux | 4 | mixed | 0 | 5675 | 5036 | 55 | 20 | none |
| Windows | 1 | packed_sand | 0 | 5517 | 4879 | 55 | 20 | none |
| Windows | 1 | embedded_sand | 72895 | 10105 | 3666 | 16 | 23 | none |
| Windows | 1 | mixed | 2 | 5690 | 5058 | 52 | 20 | none |
| Windows | 4 | packed_sand | 0 | 5594 | 4945 | 63 | 20 | none |
| Windows | 4 | embedded_sand | 38089 | 13240 | 5892 | 27 | 32 | none |
| Windows | 4 | mixed | 10945 | 8026 | 4397 | 26 | 22 | none |

## Observed timing

All paired cells show B / C. Means and maxima are milliseconds. Full totals and denominators are retained in JSON. These are sampled observations, not a claim of causal performance improvement.

| Platform | Workers | Environment | Snapshots B / C | Worker mean B / C | Worker max B / C | Native mean B / C | Native max B / C |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Linux | 1 | packed_sand | 293 / 350 | 1.1272 / 0.6566 | 2.5320 / 0.9890 | 0.3856 / 0.3659 | 0.7676 / 0.6679 |
| Linux | 1 | embedded_sand | 307 / 247 | 1.2258 / 0.9272 | 2.2490 / 1.4150 | 0.5301 / 0.5487 | 0.8623 / 0.9969 |
| Linux | 1 | mixed | 278 / 347 | 1.8570 / 1.6637 | 2.3920 / 2.1070 | 1.2028 / 1.3490 | 1.7548 / 1.7988 |
| Linux | 4 | packed_sand | 334 / 237 | 0.6264 / 0.4188 | 1.4460 / 0.8330 | 0.2055 / 0.2180 | 0.7381 / 0.3643 |
| Linux | 4 | embedded_sand | 298 / 344 | 0.9959 / 0.5300 | 2.6800 / 1.4730 | 0.3404 / 0.3081 | 0.8886 / 0.8873 |
| Linux | 4 | mixed | 342 / 359 | 1.1737 / 1.1022 | 1.5170 / 2.2310 | 0.9407 / 0.8866 | 1.2761 / 1.7280 |
| Windows | 1 | packed_sand | 284 / 345 | 0.5020 / 0.3772 | 1.7230 / 0.7230 | 0.2153 / 0.1763 | 0.6319 / 0.5182 |
| Windows | 1 | embedded_sand | 288 / 326 | 0.8514 / 0.5999 | 1.4690 / 1.1680 | 0.3384 / 0.2839 | 0.5077 / 0.8440 |
| Windows | 1 | mixed | 356 / 350 | 0.6567 / 0.7114 | 1.2060 / 1.8460 | 0.4363 / 0.4509 | 0.8226 / 0.9119 |
| Windows | 4 | packed_sand | 234 / 348 | 0.7175 / 0.4362 | 1.7830 / 1.1170 | 0.2103 / 0.1909 | 1.0109 / 0.8890 |
| Windows | 4 | embedded_sand | 261 / 336 | 0.8443 / 0.5334 | 1.6940 / 1.3080 | 0.2431 / 0.2499 | 0.4584 / 0.9176 |
| Windows | 4 | mixed | 314 / 321 | 0.9284 / 0.6012 | 1.8660 / 1.2990 | 0.3803 / 0.3618 | 1.1430 / 1.0684 |

| Platform | Workers | Environment | Sync segments B / C | Sync mean B / C | Sync max B / C | Rapier steps B / C | Rapier mean B / C | Rapier max B / C | Terrain total B / C | Terrain revisions B / C |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Linux | 1 | packed_sand | 720 / 720 | 0.0355 / 0.0429 | 0.1150 / 0.1190 | 360 / 360 | 0.1162 / 0.1156 | 0.3890 / 0.2620 | 1.4730 / 1.5300 | 2 / 2 |
| Linux | 1 | embedded_sand | 720 / 720 | 0.0404 / 0.0320 | 0.1230 / 0.1270 | 360 / 360 | 0.1266 / 0.1088 | 0.2110 / 0.2190 | 1.6150 / 1.6870 | 2 / 2 |
| Linux | 1 | mixed | 720 / 720 | 0.0370 / 0.0476 | 0.1400 / 0.1270 | 360 / 360 | 0.1253 / 0.1242 | 0.2860 / 0.2410 | 1.6340 / 1.4790 | 2 / 2 |
| Linux | 4 | packed_sand | 720 / 720 | 0.0335 / 0.0264 | 0.1800 / 0.1570 | 360 / 360 | 0.1116 / 0.0953 | 0.3320 / 0.4560 | 1.2230 / 1.2160 | 2 / 2 |
| Linux | 4 | embedded_sand | 720 / 720 | 0.0342 / 0.0368 | 0.1790 / 0.1760 | 360 / 360 | 0.1114 / 0.1184 | 0.5200 / 0.8060 | 1.2550 / 1.3110 | 2 / 2 |
| Linux | 4 | mixed | 720 / 720 | 0.0413 / 0.0407 | 0.1130 / 0.2390 | 360 / 360 | 0.1171 / 0.1186 | 0.2460 / 0.5820 | 1.2180 / 1.2810 | 2 / 2 |
| Windows | 1 | packed_sand | 720 / 720 | 0.0475 / 0.0429 | 0.2360 / 0.1410 | 360 / 360 | 0.1588 / 0.1210 | 1.0610 / 1.6980 | 1.8800 / 2.0710 | 2 / 2 |
| Windows | 1 | embedded_sand | 720 / 720 | 0.0706 / 0.0774 | 0.2980 / 0.5650 | 360 / 360 | 0.2886 / 0.2677 | 6.9220 / 7.2630 | 2.1200 / 2.1280 | 2 / 2 |
| Windows | 1 | mixed | 720 / 720 | 0.0450 / 0.0714 | 0.4420 / 0.1890 | 360 / 360 | 0.1172 / 0.2235 | 0.5900 / 3.2630 | 1.9700 / 2.0530 | 2 / 2 |
| Windows | 4 | packed_sand | 720 / 720 | 0.0439 / 0.0544 | 0.1500 / 0.1630 | 360 / 360 | 0.1575 / 0.1517 | 0.5360 / 0.5210 | 2.1050 / 2.0020 | 2 / 2 |
| Windows | 4 | embedded_sand | 720 / 720 | 0.0480 / 0.0566 | 0.2030 / 0.1450 | 360 / 360 | 0.1656 / 0.1687 | 0.5030 / 0.5080 | 2.0430 / 2.1040 | 2 / 2 |
| Windows | 4 | mixed | 720 / 720 | 0.0499 / 0.0518 | 0.1470 / 0.1950 | 360 / 360 | 0.1623 / 0.1563 | 0.5110 / 0.5230 | 2.0450 / 2.0780 | 2 / 2 |

- **worker:** observed_worker_step_ms_total / timed_snapshots; consumed healthy same-epoch snapshots only, not all native ticks.
- **native:** observed_native_tick_ms_total / timed_snapshots; consumed healthy same-epoch snapshots only, not all native ticks.
- **sync:** main_sync_ms_total / main_sync_segments; separate response-consumption and state-publication segments, not whole frames.
- **rapier:** rapier_step_ms_total / timed_rapier_steps; actual bridge.step calls.
- **terrain:** terrain_refresh_ms is total installation/drain time; terrain_refreshes counts admitted revisions/install events, not timed calls; no per-call mean is derived.

## Runtime and source references

| Platform | Cohort | Native SHA-256 | CPU | Source unchanged | Checkout bytes unchanged |
| --- | --- | --- | --- | --- | --- |
| Linux | contact-w1 | d556a9d615840761f5c0a4a6a14c39fa62e154c95a11ae16014cdca09bfb7a63 | AMD EPYC 7763 64-Core Processor | True | True |
| Linux | contact-w4 | d556a9d615840761f5c0a4a6a14c39fa62e154c95a11ae16014cdca09bfb7a63 | AMD EPYC 9V45 96-Core Processor | True | True |
| Linux | core | d556a9d615840761f5c0a4a6a14c39fa62e154c95a11ae16014cdca09bfb7a63 | AMD EPYC 9V74 80-Core Processor | True | True |
| Windows | contact-w1 | c223da56fb43a04e60869c593e0d4fa97c963eb815c3466e4abdff68ae31902f | AMD64 Family 25 Model 1 Stepping 1, AuthenticAMD | True | True |
| Windows | contact-w4 | c223da56fb43a04e60869c593e0d4fa97c963eb815c3466e4abdff68ae31902f | Intel64 Family 6 Model 106 Stepping 6, GenuineIntel | True | True |
| Windows | core | c223da56fb43a04e60869c593e0d4fa97c963eb815c3466e4abdff68ae31902f | AMD64 Family 25 Model 1 Stepping 1, AuthenticAMD | True | True |

Original artifact paths, report hashes, result hashes, engine/Rapier identity and raw counter values are retained in the adjacent analysis JSON.

## Measurement limits

- Actual solid-versus-cell penetration depth and overlap area: NOT MEASURED. max_translation is the maximum distance of the body transform origin from its initial pose; max_rotation is the maximum absolute rotation. Neither is penetration.
- Mechanical energy/contact work, contact-quality thresholds, allocation counts, GPU/render time and interactive frame pacing: NOT MEASURED by these headless reports.
- Native displacement attempts/outcomes are cumulative strict-mechanism invocations. Coupling contacts/displaced/unresolved are totals from feedback accepted by the main-thread consumer; their denominators differ. They cannot be combined into a failure rate.
- Baseline strict-mechanism counters are zero because that mechanism is disabled; ordinary current-main ejection still runs and may displace cells.
- ForeignOccupancy is a target-mask refusal, including the aggregate's own/swept mask; it does not count only other bodies. Outcome categories reflect the final priority-ordered guard decision. NoVacancy is not a replacement empty-route census.
- moved_cells > accepted > 0 proves at least one actual multi-parcel transaction. It does not establish deep-bed yielding quality or a useful penetration bound.
- Exact live Sand quantity and Water mass are reported. The 14-check populated test also asserts exact aggregate payload and sole ownership; these JSON files do not retain every surrounding parcel's state/temperature history.
- The deterministic recipe is executed with real asynchronous worker/main scheduling. Different trajectories, feedback counts, CPU models and sampling prevent causal speedup/resistance claims from this single before/after comparison.
