# SOL364 hosted contact cost review

Run `41815817333`; source `9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d`; tree `b5baf8b23ff947c2d7b70e69745c10f18fbe9ebe`.

**Registered matrix: PASS; 24/24 observed groups pass; 24/24 groups and 72/72 cases available.**

The fixed criterion is 2 ms per complete consumed observation, with all owner and main response attempts retained in the numerator. Each group uses its largest unrounded repeat mean.

## Group results

All numbers below are elapsed work in ms per complete observation. SD is the sample standard deviation of the three repeat means.

| Platform | Workers | Fixture | Arm | r0 | r1 | r2 | SD | Worst repeat accounting (owner + response)/N | Gate |
|---|---:|---|---|---:|---:|---:|---:|---|---|
| Linux | 1 | embedded_sand | baseline | 0.781310000 | 0.416686275 | 0.542637195 | 0.185193054 | r0: (234.393 + 0.000)/300 | PASS |
| Linux | 1 | embedded_sand | candidate | 1.236303226 | 1.282837079 | 1.439424242 | 0.106413570 | r2: (74.296 + 400.714)/330 | PASS |
| Linux | 1 | mixed | baseline | 0.276258567 | 0.595807692 | 0.257970909 | 0.189991129 | r1: (154.910 + 0.000)/260 | PASS |
| Linux | 1 | mixed | candidate | 1.228020761 | 1.170283912 | 1.259963100 | 0.045453664 | r2: (78.317 + 263.133)/271 | PASS |
| Linux | 1 | packed_sand | baseline | 0.274064789 | 0.940604000 | 0.778581498 | 0.347625977 | r1: (235.151 + 0.000)/250 | PASS |
| Linux | 1 | packed_sand | candidate | 1.400974265 | 1.503230435 | 0.990503571 | 0.271364254 | r1: (92.507 + 253.236)/230 | PASS |
| Linux | 4 | embedded_sand | baseline | 0.412784314 | 0.407808333 | 0.854046358 | 0.256211282 | r2: (257.922 + 0.000)/302 | PASS |
| Linux | 4 | embedded_sand | candidate | 1.245543417 | 1.359354930 | 1.336416961 | 0.060190270 | r1: (77.149 + 405.422)/355 | PASS |
| Linux | 4 | mixed | baseline | 0.390047319 | 0.445113971 | 0.291127329 | 0.078027117 | r1: (121.071 + 0.000)/272 | PASS |
| Linux | 4 | mixed | candidate | 0.876788136 | 0.994575221 | 1.002997199 | 0.070561386 | r2: (61.961 + 296.109)/357 | PASS |
| Linux | 4 | packed_sand | baseline | 0.280957020 | 0.739668942 | 0.279836620 | 0.265161475 | r1: (216.723 + 0.000)/293 | PASS |
| Linux | 4 | packed_sand | candidate | 1.192245847 | 1.233593640 | 1.065470588 | 0.087604192 | r1: (81.617 + 267.490)/283 | PASS |
| Windows | 1 | embedded_sand | baseline | 0.363825000 | 0.381608451 | 0.922380282 | 0.317472946 | r2: (261.956 + 0.000)/284 | PASS |
| Windows | 1 | embedded_sand | candidate | 1.148578767 | 0.988644886 | 1.004273743 | 0.088173170 | r0: (66.543 + 268.842)/292 | PASS |
| Windows | 1 | mixed | baseline | 0.308932862 | 0.200937677 | 0.454666667 | 0.127331393 | r2: (120.032 + 0.000)/264 | PASS |
| Windows | 1 | mixed | candidate | 0.893227545 | 0.916898230 | 0.836280556 | 0.041437645 | r1: (63.554 + 143.665)/226 | PASS |
| Windows | 1 | packed_sand | baseline | 0.770222672 | 0.621686901 | 0.226369697 | 0.281103369 | r0: (190.245 + 0.000)/247 | PASS |
| Windows | 1 | packed_sand | candidate | 0.852056180 | 0.991940141 | 0.779282540 | 0.108079277 | r1: (54.440 + 227.271)/284 | PASS |
| Windows | 4 | embedded_sand | baseline | 0.404414566 | 0.375596639 | 1.035042308 | 0.372690759 | r2: (269.111 + 0.000)/260 | PASS |
| Windows | 4 | embedded_sand | candidate | 1.358657303 | 1.149468843 | 1.644949833 | 0.248738362 | r2: (58.555 + 433.285)/299 | PASS |
| Windows | 4 | mixed | baseline | 0.209047486 | 0.221589888 | 0.235823188 | 0.013396747 | r2: (81.359 + 0.000)/345 | PASS |
| Windows | 4 | mixed | candidate | 1.077994382 | 1.047913649 | 1.017308123 | 0.030343508 | r0: (47.375 + 336.391)/356 | PASS |
| Windows | 4 | packed_sand | baseline | 0.315185976 | 0.443489796 | 0.248835196 | 0.098956817 | r1: (152.117 + 0.000)/343 | PASS |
| Windows | 4 | packed_sand | candidate | 1.011080357 | 1.077382022 | 1.095750000 | 0.044538825 | r2: (51.269 + 338.818)/356 | PASS |

## All-attempt work and receipt totals

| Platform | Workers | Owner attempts (complete/refused) | Complete consumed | Main attempts (accept/refuse) | Owner ms | Response ms | Planner ms | Ready latency mean/max ms | Accepted publication latency mean/max ms |
|---|---:|---|---:|---|---:|---:|---:|---|---|
| Linux | 1 | 6640 (6496/144) | 5328 | 2595 (2499/96) | 2077.860 | 2693.419 | 2587.987 | 4.768029/16.854 | 5.355878/18.318 |
| Linux | 4 | 6637 (6493/144) | 5682 | 2632 (2520/112) | 1964.101 | 2524.122 | 2418.673 | 7.318739/17.055 | 7.456684/18.983 |
| Windows | 1 | 6648 (6495/153) | 5666 | 2722 (2644/78) | 1760.275 | 2186.108 | 2067.461 | 7.046815/17.526 | 8.339016/19.085 |
| Windows | 4 | 6650 (6499/151) | 6174 | 2951 (2908/43) | 1612.955 | 3113.682 | 2978.129 | 7.891923/17.874 | 9.386081/19.990 |

## Preserved failures

- Historical Windows w4 embedded baseline r0: 480.685 ms owner + 0.000 ms response, 369 owner attempts / 224 complete consumed = **2.145915178571 ms, FAIL**.
- Local Linux w1 embedded candidate r2: 116.446 ms owner + 408.867 ms response, 369 owner attempts and 245 response attempts / 261 complete consumed = **2.012693486590 ms, FAIL**.

## Accounting and interpretation

Native geometry and payload-freezing timings are nested inside native-call work. Only native-call + envelope + the five disjoint response stages form the inclusive numerator. Unconsumed/setup owner attempts remain included, but their count is not a claim that every one was overwritten.

The registered owner interval covers native observation/value construction and metadata envelope/freezing. Cumulative metrics bookkeeping follows the ready timestamp; shared publication lies outside that historical interval. This is not a whole simulation/snapshot CPU budget, and mutex CPU is not measured separately.

Owner ready-to-receipt latency and accepted publication-to-response latency use distinct endpoints and denominators. These are elapsed monotonic intervals, not OS thread CPU measurements. Whole-process resource receipts, where present, are a separate process-wide quantity.

The JSON annex retains all trial numerators, denominators, attempts, refusals, stage totals, latency means/maxima and observed motion/depth. Historical asynchronous before/after ranges are descriptive; no matched-trajectory or continuous-overlap claim is made.

## Evidence files

- `cost-review.json`: group gates, variance and source/runtime custody.
- `case-accounting-annex.json`: all available cases, with a required final inventory of 72.
- `preserved-cost-failures.json`: both earlier failed receipts and all original 24 group summaries.
- `before-after-groups.json`: old/new per-group repeat ranges, maxima, SD and observation denominators.
- `github-contact-artifacts.json`: independently retrieved GitHub artifact IDs, ZIP digests, byte sizes and source/run identity.
- `review_cost.py`: independent reproducible calculation; does not import the repository analyzer.

## Reproduction and portable identities

Canonical published raw evidence belongs under `docs/audits/sol281-20261103/hosted/9edc4f8f7d8cd8fc65119d176c9e1981ab6ea77d/`; each cohort receipt in `cost-review.json` records its portable repository path, artifact name, source commit/tree and exact hashes.

Retrieve the named build/host artifacts from the run and retain the original build DLL/ELF. Extract build artifacts into `build-linux/` and `build-windows/`; host artifacts into `cohorts/<platform>/contact-w<workers>/` preserving their ZIP structure. Then run:

```sh
python3 review_cost.py --repo /path/to/cybersand --base /path/to/extracted-artifacts
```

The review requires the actual hosted binaries and hashes them. The earlier local development ELF is not an accepted substitute. Source and GitHub state remain unchanged.
