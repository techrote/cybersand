---
title: PUBPRES final03 Linux physical timing tables
status: Historical
document-kind: audit
scope: Every retained Linux03 timing arm with independent real-step reduction and explicit capture windows
canonical-for: []
last-reviewed: 2026-11-24
related-documents: [../final03-linux-decision.md]
---

# Final03 Linux physical timing tables

Every row is recomputed from independently witnessed completed Rapier steps. Fixed-step comparisons use capture start through the 144th completion. The three sustained ordinary captures use the complete recorded window. Quantiles use within-run linear interpolation; runs are never pooled. Threshold counts describe exposure, not an owner-approved acceptance threshold. Exact unrounded values, whole-capture alternatives, input witnesses, and all identities are in `final03-linux-independent-physical.json`.

Source comparisons use D = frozen c90 and C = c2. Calibration uses C in every arm, with presentation probe OFF/ON/ON/OFF; its D-like comparison labels are statistical roles, not a different application source. Deadline arms use the same C source/runtime and 0/30/60/60/30/0 Hz.

## confirmation-freemass_2048_follow

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| freemass_2048_follow/0-D-slots2 | 144 steps / 14.561 s | 9.8894 | 100.664 | 104.557 | 106.767 | 107.590 | 93 / 0 / 0 |
| freemass_2048_follow/1-C-slots2 | 144 steps / 14.461 s | 9.9577 | 99.806 | 103.466 | 105.408 | 107.370 | 68 / 0 / 0 |
| freemass_2048_follow/2-C-slots2 | 144 steps / 14.434 s | 9.9765 | 99.863 | 103.505 | 104.904 | 106.552 | 61 / 0 / 0 |
| freemass_2048_follow/3-D-slots2 | 144 steps / 14.576 s | 9.8790 | 101.051 | 103.973 | 106.215 | 106.573 | 99 / 0 / 0 |

## confirmation-pressure_512_follow

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| pressure_512_follow/0-D-slots2 | 144 steps / 13.148 s | 10.9523 | 91.307 | 94.111 | 95.075 | 95.132 | 0 / 0 / 0 |
| pressure_512_follow/1-C-slots2 | 144 steps / 13.102 s | 10.9906 | 90.709 | 93.294 | 94.864 | 95.151 | 0 / 0 / 0 |
| pressure_512_follow/2-C-slots2 | 144 steps / 13.220 s | 10.8928 | 91.685 | 94.497 | 96.927 | 98.068 | 0 / 0 / 0 |
| pressure_512_follow/3-D-slots2 | 144 steps / 13.273 s | 10.8490 | 92.217 | 95.024 | 98.041 | 98.991 | 0 / 0 / 0 |

## confirmation-wave_1024_follow_4

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| wave_1024_follow_4/0-D-slots2 | 144 steps / 13.093 s | 10.9981 | 90.285 | 95.505 | 97.206 | 98.461 | 0 / 0 / 0 |
| wave_1024_follow_4/1-C-slots2 | 144 steps / 12.831 s | 11.2230 | 88.964 | 91.812 | 92.947 | 94.377 | 0 / 0 / 0 |
| wave_1024_follow_4/2-C-slots2 | 144 steps / 12.903 s | 11.1602 | 89.452 | 92.440 | 93.613 | 94.710 | 0 / 0 / 0 |
| wave_1024_follow_4/3-D-slots2 | 144 steps / 13.290 s | 10.8353 | 91.658 | 96.864 | 98.439 | 99.139 | 0 / 0 / 0 |

## confirmation-wave_landscape_follow

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| wave_landscape_follow/0-D-slots2 | 144 steps / 13.983 s | 10.2985 | 94.697 | 108.413 | 110.010 | 111.321 | 30 / 0 / 0 |
| wave_landscape_follow/1-C-slots2 | 144 steps / 13.291 s | 10.8342 | 91.813 | 96.356 | 98.066 | 99.040 | 0 / 0 / 0 |
| wave_landscape_follow/2-C-slots2 | 144 steps / 13.241 s | 10.8755 | 91.354 | 96.582 | 98.493 | 101.250 | 1 / 0 / 0 |
| wave_landscape_follow/3-D-slots2 | 144 steps / 13.979 s | 10.3014 | 95.202 | 107.629 | 109.935 | 111.145 | 30 / 0 / 0 |

## material-deadlines

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| wave_512_follow/0-deadline0 | 144 steps / 11.517 s | 12.5034 | 80.320 | 83.029 | 84.300 | 84.957 | 0 / 0 / 0 |
| wave_512_follow/1-deadline30 | 144 steps / 11.645 s | 12.3660 | 80.710 | 83.074 | 84.759 | 85.880 | 0 / 0 / 0 |
| wave_512_follow/2-deadline60 | 144 steps / 11.725 s | 12.2811 | 81.210 | 84.313 | 85.506 | 87.701 | 0 / 0 / 0 |
| wave_512_follow/3-deadline60 | 144 steps / 11.753 s | 12.2517 | 81.226 | 84.388 | 86.962 | 87.735 | 0 / 0 / 0 |
| wave_512_follow/4-deadline30 | 144 steps / 11.717 s | 12.2897 | 82.727 | 85.432 | 86.523 | 89.733 | 0 / 0 / 0 |
| wave_512_follow/5-deadline0 | 144 steps / 11.832 s | 12.1699 | 82.285 | 85.767 | 86.447 | 88.081 | 0 / 0 / 0 |
| wave_gameplay_2048_follow/0-deadline0 | 144 steps / 21.600 s | 6.6666 | 147.432 | 231.323 | 235.253 | 240.391 | 137 / 0 / 0 |
| wave_gameplay_2048_follow/1-deadline30 | 144 steps / 21.741 s | 6.6236 | 148.546 | 232.570 | 236.212 | 237.647 | 142 / 0 / 0 |
| wave_gameplay_2048_follow/2-deadline60 | 144 steps / 21.875 s | 6.5827 | 149.872 | 233.888 | 238.008 | 241.099 | 139 / 0 / 0 |
| wave_gameplay_2048_follow/3-deadline60 | 144 steps / 21.099 s | 6.8251 | 146.557 | 231.313 | 236.071 | 237.107 | 136 / 0 / 0 |
| wave_gameplay_2048_follow/4-deadline30 | 144 steps / 21.687 s | 6.6399 | 147.678 | 228.488 | 231.250 | 233.941 | 115 / 0 / 0 |
| wave_gameplay_2048_follow/5-deadline0 | 144 steps / 20.994 s | 6.8591 | 147.453 | 230.166 | 234.834 | 236.075 | 134 / 0 / 0 |

## mixed-eight-actor

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| mixed_wave_1024_follow | 650 steps / 60.002 s | 10.8329 | 92.010 | 96.146 | 98.148 | 99.575 | 0 / 0 / 0 |
| mixed_wave_512_follow | 704 steps / 60.067 s | 11.7203 | 85.097 | 88.264 | 90.437 | 103.846 | 1 / 0 / 0 |

## observer-calibration

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| wave_512_follow/0-C-slots2 | 144 steps / 11.840 s | 12.1619 | 82.728 | 85.555 | 86.773 | 87.490 | 0 / 0 / 0 |
| wave_512_follow/1-C-slots2 | 144 steps / 11.882 s | 12.1189 | 82.470 | 85.147 | 86.545 | 86.845 | 0 / 0 / 0 |
| wave_512_follow/2-C-slots2 | 144 steps / 11.503 s | 12.5181 | 80.245 | 82.358 | 83.308 | 83.760 | 0 / 0 / 0 |
| wave_512_follow/3-C-slots2 | 144 steps / 11.562 s | 12.4546 | 80.082 | 82.429 | 82.978 | 83.275 | 0 / 0 / 0 |
| wave_gameplay_2048_follow/0-C-slots2 | 144 steps / 21.312 s | 6.7569 | 144.047 | 226.933 | 232.431 | 253.353 | 110 / 1 / 0 |
| wave_gameplay_2048_follow/1-C-slots2 | 144 steps / 19.975 s | 7.2091 | 142.730 | 220.462 | 225.354 | 227.271 | 105 / 0 / 0 |
| wave_gameplay_2048_follow/2-C-slots2 | 144 steps / 19.848 s | 7.2550 | 141.705 | 220.190 | 224.561 | 226.349 | 98 / 0 / 0 |
| wave_gameplay_2048_follow/3-C-slots2 | 144 steps / 20.724 s | 6.9485 | 143.080 | 224.581 | 228.145 | 229.706 | 102 / 0 / 0 |

## source-abba

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| wave_512_follow/0-D-slots2 | 144 steps / 11.846 s | 12.1559 | 82.504 | 85.216 | 86.891 | 87.932 | 0 / 0 / 0 |
| wave_512_follow/1-C-slots2 | 144 steps / 11.870 s | 12.1310 | 82.197 | 84.992 | 86.654 | 87.449 | 0 / 0 / 0 |
| wave_512_follow/2-C-slots2 | 144 steps / 11.880 s | 12.1214 | 82.285 | 85.634 | 86.701 | 87.775 | 0 / 0 / 0 |
| wave_512_follow/3-D-slots2 | 144 steps / 11.797 s | 12.2069 | 82.812 | 85.754 | 87.200 | 87.682 | 0 / 0 / 0 |
| wave_gameplay_2048_follow/0-D-slots2 | 144 steps / 28.266 s | 5.0944 | 249.128 | 255.871 | 259.104 | 262.643 | 141 / 63 / 0 |
| wave_gameplay_2048_follow/1-C-slots2 | 144 steps / 22.094 s | 6.5175 | 148.848 | 231.488 | 234.453 | 239.174 | 140 / 0 / 0 |
| wave_gameplay_2048_follow/2-C-slots2 | 144 steps / 23.121 s | 6.2280 | 151.461 | 236.563 | 239.904 | 240.182 | 143 / 0 / 0 |
| wave_gameplay_2048_follow/3-D-slots2 | 144 steps / 28.860 s | 4.9897 | 253.547 | 261.712 | 264.707 | 266.160 | 143 / 86 / 0 |

## sustained-slots2

| Case / arm | Window | Steps/s | p50 ms | p95 ms | p99 ms | Max ms | Gaps >100 / >250 / >500 ms |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| wave_gameplay_2048_follow/0-C-slots2 | 495 steps / 60.027 s | 8.2462 | 106.782 | 230.313 | 235.544 | 241.561 | 494 / 0 / 0 |
