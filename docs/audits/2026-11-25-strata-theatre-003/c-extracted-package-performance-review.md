# C independent performance review of the extracted owner package

**All nine initial scene admissions pass the unchanged 45-second target in this
extracted-package cohort. Every enabled optical profile misses the registered
90% progression-rate criterion. PERFORMANCE HOLD remains.**

This is an independent re-computation of existing evidence, with no runtime
rerun. It concerns the actual Windows owner package extracted and exercised by
the package job. It is a separate population from the earlier Linux/Windows
source-checkout campaigns and from the external A1 shader experiment.

## Exact source and evidence

| Item | Identity |
| --- | --- |
| Application | `fd0830abcfadd9ae19162e5677943bb131223e59` |
| Application tree | `fd4dc12d6bfd3e13d6b4d26eede8a1171ca1b499` |
| Run / package job | [45721790366](https://github.com/techrote/cybersand/actions/runs/45721790366) / `139629241289` |
| Original package evidence | [15080936111](https://github.com/techrote/cybersand/actions/runs/45721790366/artifacts/15080936111), 464,793,280 bytes |
| Evidence ZIP SHA256 | `c01cbd055e762af0ca96e47a3e8c4f4cd4ecf47070d48d5eab361ead76938513` |
| Extracted campaign SHA256 | `de2e9d0da81d98933649a5774f152b6591bc3de01154cd20afbb0d490da0b8b1` |
| Original progression report | `extracted/optics-readability-challenge/progression/result.json` |
| Progression report SHA256 | `7de2d920e400cd950048cd5ed591b101974534bb2af031f0bd4487170745b101` |
| Owner evaluator artifact | [15080761776](https://github.com/techrote/cybersand/actions/runs/45721790366/artifacts/15080761776) |
| Inner owner ZIP SHA256 | `f76a5b718c89c5906f8c6f51fdf9ece5f9bbd7c51601352b226c429b8a2daa07` |

The original campaign is completed and passed its functional evidence reader.
C verified that the progression report's bytes match both the campaign ledger
and case digest, and that its parsed contents equal the retained case record.
The actual runtime is official Godot 4.7 with the source-matched native/Rapier
libraries. Their exact identities are retained in the companion
[machine-readable review](c-extracted-package-performance-review.json).
The host reports Windows Server 2022, four logical CPUs, and **ANGLE / Microsoft
Basic Render Driver**. No physical NVIDIA observation is implied.

## Method and unchanged criteria

The cohort contains three windows per profile, ordered forward/reverse/forward,
with 90 display callbacks per window. Each window starts from a freshly admitted
native challenge scene and the same initial Play material hash and actor pose.
Quality is **Balanced** except the explicitly expensive **Diorama High** case.

C recomputed native and Rapier rates as the actual before/after tick difference
divided by the retained elapsed microseconds. Every window has 89 native ticks
and 90 actual completed Rapier steps. C checked every completed-step sequence,
reconstructed all 89 consecutive completion gaps in each window, and verified
the entire reported interval population and nearest-rank distributions. There
are **1,350 actual completed steps and 1,335 physical intervals** across all
15 windows. Physical interval tails come from those completed Rapier steps;
they are not callback/FPS estimates or reconstructed native completion times.

The reported comparison uses the median of three per-window rates and the
median of three per-window percentiles. No outliers or stalls are removed.
The original registration requires both median rates to reach **90% of
Classic**, with median physical p95 no higher than
`max(1.20 × Classic p95, Classic p95 + 10 ms)`. Here Classic p95 is 211.980 ms,
so the unchanged p95 limit is **254.376 ms**. The original registration calls
for inspection of p99/max/stalls; it does **not** define a separate p99 pass gate.

## Actual progression results

| Profile / quality | Native ticks/s | Rapier steps/s | Rate versus Classic, both | Median p95 | p95 criterion |
| --- | ---: | ---: | ---: | ---: | --- |
| Classic / Balanced | 5.000483 | 5.056668 | 100% | 211.980 ms | Reference |
| Architectural / Balanced | 3.913319 | 3.957289 | **78.258824%** | 255.069 ms | Miss by 0.693 ms |
| Cinematic Deep Focus / Balanced | 4.029828 | 4.075107 | **80.588768%** | 247.462 ms | Meets |
| Gameplay Clarity / Balanced | 3.784423 | 3.826944 | **75.681142%** | 267.350 ms | Miss |
| Diorama / High | 3.675052 | 3.716345 | **73.493942%** | 272.173 ms | Miss |

All four enabled profiles miss the registered rate threshold. Deep Focus's
p95 result does not compensate for its rate miss. Architectural's small p95
miss should not be treated as a stable broad performance difference; its
material rate miss remains the clearer finding in this sample.

| Profile | Median per-window p99 | Worst interval across all three windows | Intervals ≥500 ms, out of 267 |
| --- | ---: | ---: | ---: |
| Classic | 534.030 ms | 555.002 ms | 2 |
| Architectural | 694.535 ms | 729.063 ms | 3 |
| Cinematic Deep Focus | 695.528 ms | 707.975 ms | 3 |
| Gameplay Clarity | 746.425 ms | 790.220 ms | 3 |
| Diorama | 762.816 ms | 774.090 ms | 2 |

With only 89 intervals per window, nearest-rank p99 equals that window's
maximum. The table's p99 is the median of three such values, not a pooled or
long-session 99th percentile. No interval reached one second in this cohort.
The observed native rate range divided by its median was 9.63% for Classic,
2.87% for Architectural, 1.25% for Deep Focus, 6.90% for Clarity and 1.47% for
Diorama. These short hosted windows retain meaningful load uncertainty; the
numeric misses support HOLD rather than a general causal or hardware claim.

Owner identities remain stable within every timed window. Native material
capture and decorative-upload deltas are zero throughout. Play remains
unprocessed, and shader materials remain bounded at zero for fresh Classic
and three for enabled profiles. Those isolation facts do not erase the
observed cost of the enabled rendering paths.

## Initial scene admissions: a distinct positive cohort

| Scene | Initial admission | 45-second target |
| --- | ---: | --- |
| Orbital Terminal | 28.475 s | Meets |
| Neon Rain Arcology | 34.429 s | Meets |
| Industrial Underworks | 30.728 s | Meets |
| Abyss Foundry | 28.959 s | Meets |
| Vertical Transfer Spine | 28.102 s | Meets |
| Sunward Freight Megastructure | 28.747 s | Meets |
| Xeno Resonance Grotto | 27.608 s | Meets |
| Lunar Terminator Observatory | 27.495 s | Meets |
| Optics Readability Challenge | 31.056 s | Meets |

C independently checked each original install-phase report's source, exact
digest, unchanged 45,000-ms target and recorded elapsed value. These are the
nine initial scene admissions in the extracted-package job. The separate
progression process's initial admission was 33.794 s; neither value should be
substituted for the cold CMD process lifetime.

All nine admissions meet the target in this later population. The earlier
source-checkout campaign misses, the original Strata 002 Windows misses, and
other retained admission failures remain valid for their own executions.
This is **not evidence of a particular startup optimisation or its cause**:
job conditions and observation populations differ. The target has not moved.

## Disposition

The actual shipped package has a useful positive initial-admission result and
a continuing enabled-optics progression limitation. Preserve both findings.
No shader, threshold, preset, observer, geometry or source changed for this
analysis; A1 remains a separate deferred experiment. Draft/HOLD, the enabled
optical PERFORMANCE HOLD, and owner artistic/physical Windows 11/NVIDIA
acceptance remain appropriate.
