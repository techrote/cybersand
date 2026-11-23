# PUBPRES #757 — Original Windows Wave512 Full / Target ABBA verdict

*Date: 2026-11-23. Application commit: `c90dbc46e1f57f28e06b1f4205b83467335ff657`.*

* Original hosted Windows [Actions run 45100037351](https://github.com/techrote/cybersand/actions/runs/45100037351) — **collection completed successfully; no performance acceptance**.
* [Original artifact 14784644587](https://github.com/techrote/cybersand/actions/runs/45100037351/artifacts/14784644587); outer ZIP SHA-256 `19e020f97860f55bb268ce7341f5b25b3f0a6b7e51f6b16925c695e6efb6dddd`, CRC check passes.
* Run employed stock Godot 4.7 Windows Safe/ANGLE, original independently source-matched native C DLL and separately source-bound Rapier. Evidence-only workflow commit `bd2c448bde84c0357cb8bebf4d159e9cd9d217a7` is **not** application source.
* Four C-only sequential arms: Full, Target-retirement blit, Target-retirement blit, Full; first 144 actual Rapier completions each, 143 intervals each; same-source physical body outputs and admitted-command trajectories checked.

| Metric | Full 0 | Target 1 | Target 2 | Full 3 |
| --- | ---: | ---: | ---: | ---: |
| Actual Rapier steps/s | 12.65 | 10.17 | 10.89 | 12.70 |
| Physical gap p95, ms | 235.7 | 425.1 | 240.6 | 239.0 |
| Physical gap p99, ms | 238.8 | 693.4 | 667.9 | 242.9 |
| Physical gap max, ms | 239.4 | 707.0 | 670.8 | 244.8 |
| Gaps above 250 ms | 0 | 9 | 7 | 0 |
| Gaps above 500 ms | 0 | 6 | 5 | 0 |
| Backend submit p95, ms | 226.39 | 0.70 | 0.65 | 227.85 |
| Material submission p95, ms | 227.11 | 1.61 | 1.65 | 228.34 |
| Upload return to next draw p95, ms | 6.0 | 630.6 | 544.0 | 5.9 |
| Frame p95, ms | 425.5 | 625.7 | 673.1 | 439.0 |
| Native tick p95, ms | 4.98 | 4.56 | 4.51 | 4.11 |

**Decision: NOT_ESTABLISHED / REPAIR / HOLD.** Target lost actual real-physics throughput (10.17/10.89 vs Full 12.65/12.70), caused multiple 500+ms physical stalls where Full had zero, and worsened worst physical gaps (671–707ms vs 239–245ms). Thus do not select Target or switch defaults merely because its CPU submission p95 is under 1ms.

### Causal scope and non-claims

The `ImageTexture.update` Full backend call takes 226–228ms at p95. Under Target, the analogous backend submission takes about 0.65–0.70ms, but upload-return-to-next-draw-callback p95 rises from ~6ms to **544–631ms**. Target shifts (and in these cases increases) whole-frame blocking downstream. These are CPU-render-loop timestamp intervals, not direct measurements of GPU completion, scanout, or driver internals. Wave native tick p95 stays under 5ms.

Each arm source and receipt SHA-256 was checked, first-144 actual `rapier_step` counters matched 144 unique genuine `physics_callback` origins, and the original raw event streams matched their declared analysis SHA-256 values. No fictitious callback credit, negative experiment deletion, or pooling of unlike hosts is permitted. `analysis.gpu_history.current_matches_cpu=true` in all arms, but **previous history was not separately first-read verified by this experiment**; see separate exact-C 180-revision Windows Main transition oracle 45083102476 for that independent correctness scope.

### Engineering disposition

The experiment closes the specific proposed Wave512 Full→Target selector optimization as **negative**. Retain the Full conservative path. The next source engineering work must attack backend scheduling/publication costs without moving a stall from Main submission into draw delivery. Preserve true Rapier and World progression, bounded acknowledgement, dual-plane history correctness and owner NVIDIA acceptance gates. No source fix or new runtime is evidenced by this experiment.

### Reproduction

```bash
python tools/pubpres_completion/reduce_wave512_original.py pubpres757-exact-c-wave512-full-target-abba-45100037351.zip --case wave_512_follow --output wave512-analysis.json
```

The attached original GitHub Actions ZIP must be downloaded separately; do not insert that large binary into the repository. The reducer verifies archive CRC, source and case identity, receipt/trace hashes, actual completed steps and callback origins, material mode, GPU current parity and registered direction gates. Its emitted per-arm JSON includes the original trace SHA-256 and quantitative timing breakdown.