# DRIV3R-WORM-001 — first two real native worms

**Qualified original execution:** `313b836b3c9ce2c60e4659e3763df140f84347a6`, [Actions run 43678354515](https://github.com/techrote/cybersand/actions/runs/43678354515), 15 November 2026. **Preserve source and original artifact identities.** The later comparator fix is a separate source revision and does not rewrite the evidence or turn the original failed aggregation into a success.

## What actually happened

One pinned, resident **LiquidAI/d1-2B Q8 System One** model independently controlled each worm, selecting only host-offered legal one-cell material-58 moves or brush-up recovery. Both used the same source-built Godot Workbench World, initial stored material, seed 570, 96×96 focus and independent native PAINT receipts. No A* objective, goal distance, training, external paid model API or user-facing production change.

| Observed fact | Free worm | Soft-scent worm |
| --- | --- | --- |
| Original model decisions | **36** | **36** |
| Actual newly painted native cells | **33** | **36** |
| Material-preserving brush-up recoveries | **3** | **0** |
| End state | Budget exhausted | Budget exhausted |
| Recorded single model PID | 7321 | 7308 |
| Independent original full-World native replay | **PASS** | **PASS** |
| Native / model child cleanup | **PASS** | **PASS** |
| Measured episode seconds (excluding setup) | 953.943 | 997.354 |
| Final full-World SHA-256 | `58a917031122d0229dd2f885eb3afe54d857e981809541e249c124b0fc1a5070` | `54d25a7478a5874525bcb385786b7b0972ade56410a590687655c2261f447d91` |

Both arms started from **exactly the same original 512×512 native World** SHA-256 `18749c1e87f4ecd96cb441a1f2a64a53d2cbb5dd079a5f6485e9974e80c9e418` and identical original host legal-catalog SHA-256 `552c446e89cd3538b5b78de6b79c41228aad48480efcb690cbc9a068727091cd`.

The first **four** original choices were identical (N, W, S, E). On zero-based decision **4** (the fifth choice), free chose `BACKTRACK` while the scent-guided worm chose `MOVE_S`, creating the first source-matched, consequential native cursor/material divergence. Subsequent Worlds are different; never pretend their later legal catalogs remain identical.

**Real original artifacts:**
- [Free worm artifact 14147579972](https://github.com/techrote/cybersand/actions/runs/43678354515/artifacts/14147579972), ZIP SHA-256 `33083b5642c9ae6af04d7530147818453dd4513b9cf4e6f9576e4ef79e0d9aac`.
- [Soft worm artifact 14147233975](https://github.com/techrote/cybersand/actions/runs/43678354515/artifacts/14147233975), ZIP SHA-256 `82d64e708e5706d4532900c60c52eaee7de04105d64888aaf436270136e7eca1`.
- Both contain the original `execution/model/turn-*.json` records, source-verified `execution/receipts/*.json`, `execution/native-replay.json`, full original World readbacks, `execution/execution/summary.json` and the material-derived `execution/gallery/{native-material.png,worm-closeup.png,worm-motion.gif}`. The gallery is **not** a framebuffer screenshot.

## Independent evidence audit and corrected comparison

The first native execution **succeeded in both arms**, but its aggregator erroneously searched for `execution/summary.json` instead of the original ZIP extraction path `execution/execution/summary.json` and reported both arms missing. That failed aggregation is part of the historical record, not erased.

A later isolated **no-model/no-native** [reconciliation job 43691749089](https://github.com/techrote/cybersand/actions/runs/43691749089) passed on the original artifact IDs and exact pinned original source. Its original-only comparator checks source SHA, matched starting native World and legal catalog, original model-turn count, true native replay and full M1 schema custody before declaring `NATIVE_WORM_PAIR_SOURCE_VERIFIED`. The repaired comparator has a regression test mirroring GitHub Actions' actual archive nesting and rejects partial/forged artifacts.

Independent local audit of the **original ZIP bytes**, not a regenerated synthetic trail, additionally verified:
- Both artifact ZIP SHA-256 digests against the published GitHub Actions digests.
- **33/33** free and **36/36** soft original native paint receipts: each reported one real changed cell, verified readback and reconstructed material.
- **36/36** original d1 Q8 answers per arm have status `ok`, with a single resident PID in each episode.
- The actual final full-World `i32le` file is **1,048,576 bytes**, matches its published blob SHA and the final summary SHA in both episodes. It contains precisely 33 / 36 material-58 cells; unchanged surrounding material is retained.
- Independent native replay files confirm 33 / 36 actual material actions replayed and matching final full-World hashes.

## Artistic observations, not optimisation claims

- **Free worm:** loops and backtracks around X 9–13 / Y 21–29, making a compact irregular squiggle with three brush-up recoveries.
- **Soft-guided worm:** follows a compact repeated zigzag around X 11–13 / Y 23–36, then curves back up; no recovery. The resulting stroke looks patterned, not objectively better or worse.
- Sampling the **same original soft scent field** along each run's actual newly painted cells gives a mean u16 preference of approximately **20,380** free versus **25,442** soft. These are retrospective descriptive numbers from two different trajectories, *not* causal proof that d1 understands or reliably follows the scent.
- Both arms continue painting until the **36-turn budget**, not a demonstrated voluntary artistic STOP. One seed and the original `wall-v1` crop cannot establish a population effect, generalised worm character, visual quality superiority, or control robustness.

**Next appropriate iteration:** keep it an entertaining small decision brain. Try a few different original starting positions/seeds and bounded pen-lift/short-turn options to increase line variation. Evaluate actual motion/ink GIFs and subjective line character, not A* efficiency or connected-component optimisation. Any new heavyweight native/model episode should have its own bounded source/request/evidence record. No merge, Ready, training or production changes are implied.
