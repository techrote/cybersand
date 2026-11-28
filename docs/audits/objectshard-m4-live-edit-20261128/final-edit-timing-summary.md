# Actual editing stage timings

Application source: `ba6d8de45bd4d38717d92bdece7153bff115c0f0`. Campaign: `46125028803`.

Each latency pair below is **median / maximum**, in milliseconds. The per-action CSV and JSON receipts retain every measured stage and each material/rebuild count.

| Lane | Complete actions / censored | Input → admission (ms) | Admission → publication (ms) | Fixture total (s) |
| --- | ---: | ---: | ---: | ---: |
| Linux source, headless | 12 / 0 | 0.360 / 69.724 | 10.105 / 122.482 | 14.788 |
| Linux source, rendered | 12 / 0 | 4.382 / 28.259 | 154.113 / 670.298 | 45.697 |
| Windows source, headless | 12 / 0 | 30.997 / 74.218 | 11.711 / 60.920 | 17.290 |
| Windows source, rendered | 12 / 0 | 23.313 / 130.634 | 120.490 / 341.874 | 160.155 |
| Windows producer package, rendered | 12 / 0 | 39.432 / 129.452 | 95.728 / 246.707 | 126.065 |
| Windows fresh independent package, rendered | 11 / 1 | 20.777 / 165.283 | 118.035 / 1274.907 | 164.671 |

## Snapshot counts

Native Applied and Main publication are separate observations. A pending publication has no invented completion time.

| Lane | Pointer attempts | Admitted | Native Applied | Presented | Requested / removed cells |
| --- | ---: | ---: | ---: | ---: | ---: |
| Linux source, headless | 14 | 12 | 12 | 12 | 418 / 418 |
| Linux source, rendered | 14 | 12 | 12 | 12 | 418 / 418 |
| Windows source, headless | 14 | 12 | 12 | 12 | 418 / 418 |
| Windows source, rendered | 14 | 12 | 12 | 12 | 418 / 418 |
| Windows producer package, rendered | 14 | 12 | 12 | 12 | 418 / 418 |
| Windows fresh independent package, rendered | 14 | 12 | 12 | 11 | 418 / 418 |

The fresh independent package snapshot contains 11 complete actions and one native Applied action awaiting publication. The latter is the final pause/resume cancellation probe; the fixture then replaces the scene. Its publication latency is right-censored, and the original strict extractor refusal is retained separately. No later presentation is inferred.

## Native and delivery stages

Every value is median / maximum in milliseconds; the spans overlap.

| Lane | Worker queue | Native owner service | Native target | Native mutation | Native connectivity + geometry | Main receipt delivery |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Linux source, headless | 0.357 / 4.965 | 0.227 / 5.603 | 0.003 / 0.012 | 0.001 / 0.020 | 0.060 / 0.086 | 9.360 / 17.761 |
| Linux source, rendered | 0.366 / 4.424 | 0.223 / 3.085 | 0.005 / 0.017 | 0.001 / 0.023 | 0.060 / 0.081 | 151.465 / 242.498 |
| Windows source, headless | 1.145 / 4.459 | 0.172 / 3.188 | 0.003 / 0.012 | 0.001 / 0.017 | 0.035 / 0.044 | 10.758 / 15.507 |
| Windows source, rendered | 1.429 / 6.746 | 0.322 / 4.729 | 0.006 / 0.029 | 0.001 / 0.040 | 0.055 / 0.104 | 110.102 / 253.312 |
| Windows producer package, rendered | 1.020 / 9.309 | 0.300 / 7.529 | 0.003 / 0.019 | 0.001 / 0.026 | 0.079 / 0.084 | 87.791 / 225.414 |
| Windows fresh independent package, rendered | 0.710 / 6.043 | 0.286 / 5.515 | 0.004 / 0.018 | 0.001 / 0.022 | 0.054 / 0.084 | 107.903 / 246.579 |

## One actual geometry-install witness per lane

Each selected action removed six material cells, performed one native reconstruction and installed 44 shapes. The join binds World, native owner, session, body generation, geometry revision and physics step.

| Lane | Native connectivity + geometry (µs) | Main Rapier install (µs) |
| --- | ---: | ---: |
| Linux source, headless | 216.790 | 348 |
| Linux source, rendered | 180.559 | 373 |
| Windows source, headless | 116.200 | 305 |
| Windows source, rendered | 265.100 | 524 |
| Windows producer package, rendered | 217.500 | 641 |
| Windows fresh independent package, rendered | 212.700 | 689 |

## Interpretation

- Each run records 12 admissions in the eight-owned-body stress fixture. Latency summaries use only complete admitted/Applied/presented triples; explicitly censored snapshot actions are counted separately. This is a small qualification sample, not a production latency distribution.
- Whole-fixture duration includes scene setup, settling and waits before pointer events; it is not edit latency.
- Input-to-admission uses the captured gesture timestamp. Admission-to-publication ends at Main acknowledged installed/coherent publication, not physical monitor presentation.
- Worker queue, native owner service, native core phase counters and Main delivery are nested or overlapping spans; do not add them. Native target/mutation/combined-geometry counters exclude facade normalization, projection, marshalling, fingerprints and some post-debit work.
- Combined native geometry includes connectivity and shape reconstruction. Rapier installation is independently witnessed on Main in one creative-construction action per lane, not a distribution.
- Continued strokes are throttled to about 30 admissions per second; fresh presses and Slice commits bypass that interval. All routes allow one outstanding transaction.
- Hosted software-rendered Windows/Linux execution is not a benchmark of the owner Ryzen 5 5600X or TITAN RTX. Owned and awake cohorts remain separate.
