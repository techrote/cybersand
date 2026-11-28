# Linux recovery performance: source519

Source `51903088118d2a04f2dc79dd6fff7c25b226970c`, tree `a3f3e166f474d8c2a0d882cc9f7bb2adf21d8919`; run45517975210 attempt1, job138882242425. Aggregate **FAILED**: headless42/42, graphical30/31. Physical Windows/NVIDIA acceptance remains **HOLD**.

Rates count renderer submissions and native semantic ticks independently. Intervals are p50/p95/maximum milliseconds. Costs are milliseconds in the timed window unless explicitly marked bounded age.

| Workload | Submissions/s | Native ticks/s | Actual Rapier calls | Callback intervals | Render intervals | Bounded delivery age | Worker snapshots calls/ms | Main admission/packet/Rapier; pump ms |
| --- | ---: | ---: | ---: | --- | --- | --- | --- | --- |
| disabled_intact_paused [case FAILED] | 7.019 | 0.165 | 0 | 139.102/155.014/187.132 | 139.149/155.086/187.026 | unavailable | 0/0.000 | unavailable; unavailable |
| disabled_intact_playing [case FAILED] | 6.734 | 6.651 | 81 | 143.306/181.775/193.452 | 143.400/180.423/191.581 | unavailable | 0/0.000 | unavailable; unavailable |
| intact_paused | 6.274 | 0.000 | 0 | 152.716/191.415/194.461 | 152.838/191.772/196.733 | unavailable | 0/0.000 | unavailable; 2.448 |
| intact_playing | 6.800 | 3.317 | 161 | 145.366/179.726/193.732 | 145.884/179.119/194.156 | unavailable | 240/58.573 | unavailable; 363.647 |
| detached_paused | 7.022 | 0.000 | 0 | 138.670/165.594/190.385 | 138.599/165.614/190.375 | unavailable | 0/0.000 | unavailable; 2.55 |
| detached_playing | 6.812 | 2.160 | 108 | 144.172/170.185/196.623 | 144.159/170.527/197.342 | unavailable | 162/102.033 | unavailable; 467.102 |
| tower_overview | 6.697 | 2.245 | 721 | 145.272/186.661/198.592 | 145.630/186.012/199.627 | 7.897/15.624/16.862 | 1080/680.094 | 37.207/52.686/93.077; 3116.662 |
| viaduct_overview | 6.649 | 2.262 | 721 | 145.828/188.191/201.557 | 146.198/188.193/202.305 | 6.977/15.714/17.210 | 1080/693.352 | 31.384/62.387/112.512; 3075.567 |
| timber_overview | 6.649 | 2.204 | 721 | 146.198/187.740/199.149 | 146.600/188.177/199.957 | 7.910/15.780/17.737 | 1080/776.547 | 31.386/48.792/86.358; 3099.953 |
| mixed_overview | 6.728 | 2.226 | 721 | 143.841/186.354/198.804 | 144.151/186.372/199.424 | 6.138/15.972/16.792 | 1080/767.224 | 32.405/51.303/95.116; 3101.015 |
| stress_overview | 6.798 | 1.723 | 721 | 141.336/187.720/196.007 | 141.592/187.500/196.196 | 6.094/16.093/17.000 | 1080/1242.394 | 38.269/84.356/111.936; 4494.959 |
| tower_light_recording_off | 6.808 | 2.308 | 721 | 142.947/184.363/198.098 | 143.286/184.400/198.986 | unavailable | 1080/663.729 | 38.191/51.514/84.851; 3085.227 |
| tower_light_recording_on | 6.801 | 2.267 | 721 | 142.504/185.192/197.598 | 142.877/185.443/198.308 | 5.490/16.248/17.051 | 1080/671.038 | 34.459/52.463/89.962; 3102.731 |

## Interpretation boundaries

- The failed disabled paused control is not a zero-progression witness. Its two late native ticks are retained.
- Disabled/enabled ordinary controls have the same authored recipe and view, but only enabled fixtures attach per-callback coherence observation.
- Disabled actual Rapier calls are1/60second steps; attached calls are1/240second segments.
- Light recording on/off share sampling and fixture work; single-pair differences do not establish causal speedup.
- Stage samples are recent bounded recording samples starting before the timed window, including setup/cut.
- Receipt delivery age is native publication to Main observation, not material-to-monitor or input-to-monitor latency.
- Main pump, worker, native occupancy/relocation and stage upload costs overlap/nest; do not sum as wall time.
- Detached paused is not a running naturally sleeping-body control; that separate local scope is retained in natural-rest-local.
- Still captures do not establish dynamic playfeel.

- Unavailable: Physical NVIDIA hardware acceptance.
- Unavailable: Physical monitor scanout/FPS.
- Unavailable: Input-to-monitor response.
- Unavailable: Causal display frame identity from latency probe.
- Unavailable: Per-allocation counts/cost.

The machine-readable readout retains full-window counters, callback/draw coherence observation counts, all26headless/graphical profile summaries, every profile/report/log hash, runtime identities, native-stage counters and both rendered diagnostic-toggle receipts.
