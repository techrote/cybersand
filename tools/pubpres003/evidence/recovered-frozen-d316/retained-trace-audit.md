# PUBPRES-003 independent audit of retained PUBPRES-001 traces

This is a fresh reduction of immutable old captures, not a new software execution or successor qualification.

Validated arms: **32**. Refused records: **0**. Every admitted arm passes the unchanged v3 evidence validator and an independent numerical cross-check.

## Paired startup progression

Rates are the mean of two run-level first-10-second rates. Gap quantiles remain per-run; they are not averaged or pooled.

| Platform | Workload | Intervention | OFF steps/s | ON steps/s | OFF p95 gaps (ms) | ON p95 gaps (ms) |
|---|---|---|---:|---:|---|---|
| Linux | wave_2048_follow | wave_column_probe | 8.60 | 8.55 | 147.2, 148.7 | 147.7, 149.5 |
| Linux | wave_2048_follow | same_frame_continuation | 8.80 | 8.80 | 147.7, 142.8 | 146.3, 145.2 |
| Linux | wave_512_follow | same_frame_continuation | 16.25 | 16.10 | 64.9, 65.2 | 65.4, 65.4 |
| Linux | wave_gameplay_2048_follow | same_frame_continuation | 3.85 | 3.85 | 266.6, 268.9 | 266.6, 271.7 |
| Windows | wave_2048_follow | wave_column_probe | 4.25 | 4.45 | 475.6, 728.1 | 465.5, 319.3 |
| Windows | wave_2048_follow | same_frame_continuation | 4.60 | 5.15 | 321.0, 317.1 | 327.9, 319.5 |
| Windows | wave_512_follow | same_frame_continuation | 14.45 | 16.35 | 163.4, 167.3 | 164.4, 161.3 |
| Windows | wave_gameplay_2048_follow | same_frame_continuation | 2.85 | 2.70 | 676.0, 450.0 | 481.5, 456.8 |

## Individual continuation arms

The table retains each first-10-second observation. Full-capture and equal-144-step windows, source/runtime identities, original hashes and refusal counts are in the adjacent JSON.

| Platform / workload | Arm | Steps/s | Physical p95 / p99 / max (ms) | Native tick p50 / p95 (ms) | First handoff wait p50 / p95 (ms) |
|---|---|---:|---|---|---|
| Linux / wave_2048_follow | 0 OFF | 8.70 | 147.7 / 150.5 / 151.1 | 23.2 / 114.1 | 70.6 / 75.5 |
| Linux / wave_2048_follow | 1 ON | 8.80 | 146.3 / 147.1 / 147.9 | 23.5 / 114.6 | 70.1 / 74.9 |
| Linux / wave_2048_follow | 2 ON | 8.80 | 145.2 / 147.8 / 148.0 | 23.3 / 106.0 | 70.3 / 75.2 |
| Linux / wave_2048_follow | 3 OFF | 8.90 | 142.8 / 144.8 / 145.6 | 22.4 / 105.2 | 70.4 / 74.6 |
| Linux / wave_512_follow | 0 OFF | 16.40 | 64.9 / 66.2 / 66.6 | 2.6 / 3.9 | 56.2 / 59.9 |
| Linux / wave_512_follow | 1 ON | 16.00 | 65.4 / 68.9 / 70.0 | 2.6 / 3.9 | 57.0 / 60.5 |
| Linux / wave_512_follow | 2 ON | 16.20 | 65.4 / 68.3 / 69.0 | 2.5 / 3.7 | 56.9 / 60.9 |
| Linux / wave_512_follow | 3 OFF | 16.10 | 65.2 / 68.1 / 79.3 | 2.7 / 4.1 | 56.6 / 60.0 |
| Linux / wave_gameplay_2048_follow | 0 OFF | 3.90 | 266.6 / 271.2 / 273.4 | 176.4 / 192.8 | 68.8 / 77.0 |
| Linux / wave_gameplay_2048_follow | 1 ON | 3.90 | 266.6 / 271.6 / 274.2 | 182.8 / 195.2 | 69.9 / 78.9 |
| Linux / wave_gameplay_2048_follow | 2 ON | 3.80 | 271.7 / 273.6 / 274.1 | 184.9 / 199.6 | 67.8 / 78.3 |
| Linux / wave_gameplay_2048_follow | 3 OFF | 3.80 | 268.9 / 272.6 / 273.7 | 185.3 / 198.3 | 66.9 / 72.8 |
| Windows / wave_2048_follow | 0 OFF | 4.30 | 321.0 / 766.0 / 796.2 | 64.3 / 190.3 | 143.9 / 247.3 |
| Windows / wave_2048_follow | 1 ON | 5.00 | 327.9 / 558.8 / 598.3 | 66.7 / 199.1 | 77.0 / 234.6 |
| Windows / wave_2048_follow | 2 ON | 5.30 | 319.5 / 535.0 / 580.0 | 64.4 / 204.2 | 64.8 / 262.1 |
| Windows / wave_2048_follow | 3 OFF | 4.90 | 317.1 / 576.4 / 601.3 | 61.5 / 165.2 | 105.9 / 238.0 |
| Windows / wave_512_follow | 0 OFF | 15.10 | 163.4 / 447.1 / 449.3 | 1.9 / 2.9 | 2.5 / 166.0 |
| Windows / wave_512_follow | 1 ON | 15.90 | 164.4 / 449.1 / 452.2 | 2.1 / 5.2 | 2.4 / 173.5 |
| Windows / wave_512_follow | 2 ON | 16.80 | 161.3 / 358.1 / 459.0 | 2.0 / 4.6 | 3.7 / 156.9 |
| Windows / wave_512_follow | 3 OFF | 13.80 | 167.3 / 470.0 / 472.0 | 2.0 / 4.3 | 3.0 / 174.5 |
| Windows / wave_gameplay_2048_follow | 0 OFF | 2.70 | 676.0 / 773.9 / 781.8 | 176.6 / 283.4 | 96.7 / 480.1 |
| Windows / wave_gameplay_2048_follow | 1 ON | 2.70 | 481.5 / 693.1 / 760.5 | 179.4 / 334.4 | 39.2 / 282.7 |
| Windows / wave_gameplay_2048_follow | 2 ON | 2.70 | 456.8 / 702.5 / 783.5 | 168.0 / 293.2 | 120.2 / 269.3 |
| Windows / wave_gameplay_2048_follow | 3 OFF | 3.00 | 450.0 / 658.3 / 738.7 | 200.9 / 302.7 | 69.1 / 261.2 |

## Interpretation limits

Historical Wave uses one round without spill or ballistic transport. Current gameplay uses two rounds with the registered spill/parcels/ballistic mechanics. These are different workloads.

First healthy handoff joins native World, tick, body sample and terrain revision. Repeated status publication cannot reset packet age. The v3 worker events do not expose every session/epoch or actual Main mailbox-observation/install boundary, so these captures cannot distinguish delayed observation from every form of later admission delay.

Main frame gaps and frame_post_draw callbacks are CPU event-loop observations. They do not establish GPU completion, scanout or physical NVIDIA performance. Windows captures used the recorded hosted ANGLE adapter.

Original failed/incomplete records are retained and listed below; none is promoted to a successful generation.

