# CI-OPT-003 first normal-target result — PERFORMANCE HOLD pending sanitizer

Exact candidate `506dfc8c343c5d24fe26e89a9542cf985c52853e`; accepted baseline `846fe0533b3170e7b01f690518da49fc40cc24d1`; immutable proof `371b9aef07e75cf99e20417884402a22a9ad58da`.

[Proof run 44959131042](https://github.com/techrote/cybersand/actions/runs/44959131042), attempt 1, normal job 137013797991. Artifact 14729210780 ZIP SHA256 `ae9e84dba2ededf27a863e28278649f45c0a8999360a9fc7cd85d75e6e2f2185` independently matches GitHub metadata.

The final strict offline reader was independently inspected and its 18 positive/adverse tests rerun successfully in 7.430s. Reviewed reader SHA256 `ee58321a5cfab2b27edd7f1ac6383a85e8244cd7496c784facc1690127295eb8`. This reader, plus separate independent raw-record interval accounting, both admit the original downloaded evidence. The original proof comparison.json is not authoritative because its summary/index coupling was incomplete.

| Measured same-worker quantity | Baseline | Candidate |
| --- | ---: | ---: |
| Complete cold normal target | 235.386537s | 228.906391s |
| Compiler interval union | 103.982179s | 106.675753s |
| Actual test interval union | 131.023898s | 130.953013s |
| Compiler/test overlap | 0s | 9.101613s |
| Generator heavy-object overlap | 0s | 16.853843s |
| Compiler user CPU | 193.356386s | 194.597991s |
| Largest compiler child RSS | 932304KiB | 932804KiB |
| Compiler/link invocations | 28 | 28 |
| Executed original test binaries | 16 | 16 |

Observed saving: **6.480146 seconds (2.752981%)**. This normal-only result is insufficient to establish a meaningful routine-CI acceleration. It neither fails safety nor demonstrates the targeted critical-path saving; wait for the already-declared sanitizer pair, without seeking additional favorable normal samples.

The hoped-for heavy compiler overlap happened, but normal compile union actually grew by2.694s; the overall small saving came chiefly from beginning the unchanged showcase loop about6.412s earlier, overlapping the remaining compile. Actual test duration stayed effectively constant. The two world_generation.cpp objects took only about17–18s apiece on this worker. Seven showcase tests dominate normal execution at121.322s combined, spread across all seven (approximately9.68/25.96/26.27/7.93/19.45/14.56/17.47s), with max-child test RSS about90MiB. Bounded independent showcase concurrency is the strongest newly evidenced next hypothesis.

Host: Intel Xeon6975P-C, four logical CPUs/two cores with two threads each,16.46GB reported memory, image ubuntu24 `20261116.133.1`, GCC13.3.0, GNU Make4.3. Both arms ran sequentially on the same worker with absent initial build directories, identical compiler/test arguments, unchanged production/fixture source and complete successful watchdog receipts. OS caches may be warmer in the second arm; no compiler/result cache was used. This is one pair, not a population estimate. RSS figures are per-child maxima, not concurrent aggregate memory.

Machine-readable results: `normal-pair-strict.json`, `normal-pair-independent.json`. Raw archive and extracted evidence remain untouched.

