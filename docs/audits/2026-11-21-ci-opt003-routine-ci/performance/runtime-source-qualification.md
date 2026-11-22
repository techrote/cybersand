# PR723 final-source hosted qualification

Candidate HEAD `19023b4016facfda2b13b9a1503742e4a9fe1982`, tested merge checkout `5c56bce96881291c57cea6575e1f4d5fb89485cc`, exact tree `39b658c5de9c5e541312b5190bd5d8ba797c6bed`. The merge checkout/tree was independently checked against local immutable Git objects. This report records real hosted execution. Controlled performance admission has separately passed both the frozen source-aware reader and independently reviewed complete-showcase supplement; its measurements and limits are in `worldgen-runtime-final-performance-verdict.md`.

## Complete Ready cohort

All 78 executed jobs passed across six applicable workflows, with conditional skips recorded separately. Event at 2026-11-21 23:42:31 UTC to final required job at 2026-11-22 00:12:40 UTC was **30m09s**. Summed unweighted hosted runner consumption was **285.416667 minutes**. The superseded same-HEAD 23:42:20 cohort was retained as separate evidence and excluded; cancelled/skipped runs were not qualification.

| Workflow | Exact run | Event to last job | Initial wait to first executed job | Runner-minutes | Executed jobs |
| --- | --- | ---: | ---: | ---: | ---: |
| Native | 44963101962 | 30m09s | 7m26s | 72.333333 | 9 |
| GDExtension Linux/Windows | 44963102007 | 25m04s | 4m06s | 173.683333 | 55 |
| Documentation/provenance | 44963101934 | 7m31s | 7s | 7.400000 | 1 |
| Wave | 44963101963 | 6m37s | 3s | 13.916667 | 4 |
| Palette | 44963101949 | 7m25s | 4s | 17.683333 | 8 |
| Source advisory | 44963101939 | 32s | 8s | 0.400000 | 1 |

The job count is two higher than PR722 because two cheap Ready scope policy jobs executed here rather than taking their conditional skip. The scientific inventory is unchanged. Native's 7m26 wait was observed while an earlier superseded PR723 run's worldgen job remained active. The existing job-level `always()` condition is a plausible explanation in light of GitHub's cancellation semantics, but the exact cancellation-request event log was unavailable; that root cause is an inference, not a separately confirmed defect. This wait remains included in developer turnaround and must not be presented as runtime of the new scheduling implementation. First completed Native family was at 10m02 from the event, or 2m36 after Native's first worker began. The first functional result across the whole cohort was Wave normal at 1m26; this earlier feedback belongs to the independent unchanged Wave workflow.

Machine source: `runtime-cohort-summary.json` and original `runtime-cohort/jobs-*.json`. Full links follow the form `https://github.com/techrote/cybersand/actions/runs/<run>`; no prior or superseded commit's successful result was substituted.

The new bounded-graph and failure controls also add real work before the family matrix. The Native policy job took 44s here, including a 30s provider/evidence/failure-control step, versus 27s and 11s in PR722's separate hosted cohort. The observed whole-job increase is 17s (control step19s); different hosts prevent treating it as an exact causal overhead estimate. This cost is included in the full-cohort result above and is outside the controlled worldgen-family pair. The paired family percentage must not be reported as a full-routine percentage or as if this additional validation were free.

## Original worldgen evidence

Original artifact `14731551841`, ZIP SHA256 `9b9f5b54d3f35beeb568027a9c7f3fc7b23bb9a430938aba19120c662d030be8`, retained all three complete command receipts, all 14 raw showcase logs, and 324 scientific output entries. Family receipt elapsed time was **1241.791111 seconds** on Intel Xeon 6975P-C, four logical CPUs, Ubuntu image `20261116.133.1`.

| Original command | Seconds | Child user/system CPU | CPU utilization | Maximum child RSS |
| --- | ---: | ---: | ---: | ---: |
| Physics characterization / all original CLI assertions | 96.122198 | Not instrumented at this layer | Not claimed | Not claimed |
| Normal worldgen | 183.201612 | 334.37 / 8.13s | 187% | 933,012 KiB |
| ASan/UBSan worldgen | 960.309874 | 1682.59 / 19.35s | 177% | 1,695,232 KiB |

Both GNU time records show zero swap. Maximum child RSS is not the sum of memory used by simultaneous children. Raw showcase logs preserve every case's output and source/run/attempt identity but do not instrument per-case elapsed time; no invented case timings are reported. `runtime-hosted-worldgen-summary.json` records exact hashes and metadata.

Final Native reducer artifact `14730789639`, ZIP SHA256 `c9b548b06f5f14339464e3bae661136a0cf8602175313740520ed6fadbf14e68`, reports no errors, all six exact families received successfully, 192 required core cases, source/run/attempt binding, and the exact tested tree above. The source-bound original reducer remains the Native required-check authority.

## Interpretation and next bottleneck

This single complete Ready cohort demonstrates final-source execution and preserves the user-facing event latency. It is not a controlled whole-CI speedup estimate. Hosted worker variation and the two measured queue delays differ from PR722. The independent full-worldgen pair is still the causal performance experiment.

GDExtension remains the next major candidate after Native: its unqueued workflow window was 20m58. Current pinned godot-cpp builds took 334.074637s on Linux (AMD EPYC 9V74) and 330.085261s for Windows cross-compilation (AMD EPYC 7763), with extension builds 83.714098s and 71.038168s. These unchanged build paths vary substantially across hosted CPUs. Windows shard16 was the last functional shard, taking437s total (404s harness,23s checkout); real regression execution, not artifact restore, dominated it.

The original build telemetry artifacts were independently downloaded: Linux `14730767104` ZIP SHA256 `76ff4f1a52bf902acf18c6c60b26c51ca41666d743e298b5209e40ae999b46a3`; Windows `14730751161` SHA256 `9f97540aeb7272eca96b367601e44d0152bcf0bb6e3cb8b1e2d5bd7b174726e7`. They bind the same source/run/attempt/tree. Their direct-shell CPU/RSS observations do not establish compiler descendant memory headroom.

The lowest-risk next hypothesis remains increasing only pinned godot-cpp's bounded SCons job count from2 to4 after verifying descendant CPU/memory behavior. It precedes introducing persistent dependency-cache trust machinery. Existing shard balance and repeated history transfer remain secondary hypotheses; no additional hosted campaign was started for them.

For repeated developer updates, verify PR supersession cancellation behavior. The measured 7m26 wait and simultaneous older Native family are observations; an `always()` cancellation interaction is a source-supported hypothesis requiring the cancellation request/transition evidence before correction. Any future change must preserve artifact retention and fail-closed cancelled/partial evidence. It is outside this frozen candidate and its performance claim.
