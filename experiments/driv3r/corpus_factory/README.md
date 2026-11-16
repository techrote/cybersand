# CyberSand GAME Corpus Factory — standalone research, v1

**Authority:** owner-approved Game Corpus Factory lane in `experiments/driv3r/corpus_factory/**`. **Draft/HOLD.** No modifications to `native/**`, `godot/**`, Workbench, production policies, source assets or maps. No native runtime evidence or checkpoint claims.

## What is actually implemented

- Reproducible 96×96 **external/synthetic** local material grids, obstacles, immutable protected cells, reachable spatial goals, corridors, deceptive choices, dead ends, motif steering and long histories.
- Three matched motif/family trajectories per world, with W0-shaped `x/y/heading/local_5x5/legal/last_actions/family/tick` observations and **additional** `local_material_5x5`, `local_protected_5x5` and goal channels. Legal choices: STRAIGHT, LEFT, RIGHT, BRANCH, RETRACE, STOP. The host, never a proposed policy, controls legality and application.
- Synthetic *heuristic teacher* actions, host receipts, legal-but-less-preferred and explicitly illegal hard negatives; this is **not** a trained policy, an optimal-route certification, or authentic native PAINT execution.
- TRAIN/DEV/heldout partitioned **by underlying scenario+world seed, not decision**. Three motif families on each world stay in the same split. Near-identical world rejection, local observation-input dedup, cross-split collision exclusion and post-export integrity auditor.
- Human-inspectable original PNGs, immutable SHA-256 inventories and machine-readable JSONL shards with source, split, family, difficulty and evidence class.
- Optional **read-only** importer for original WORM W0 Action ZIPs. Preserves original JSON and PNG digests; imported observations remain **evaluation-reference-only** and **never become training targets**. Neither a model trace nor a Python W0 run is silently reclassified as native.

**Pinned donor contract**: [W0 `worm.py`](https://github.com/techrote/cybersand/blob/research/612-worm-common/experiments/agent_painter/worm/common/worm.py), Git blob `8979b6f0296e81051194bacc907992d38e006605`. This corpus extends W0's *external research* observation and protection semantics; its material/protected features are **not supported by vanilla W0**, so it is not byte-for-byte W0 replay.

## Reproduce (Python 3.11+ standard library only)

```sh
python3 -m unittest discover -s experiments/driv3r/corpus_factory -p 'test_corpus.py' -v
python3 experiments/driv3r/corpus_factory/corpus.py --output /tmp/cs-game-corpus-v1 --worlds-per-scenario 50 --budget 160 --png-limit 12
python3 experiments/driv3r/corpus_factory/corpus.py --output /tmp/cs-game-corpus-v1 --audit-only

python3 experiments/driv3r/corpus_factory/ingest_w0.py /path/to/original_sprocket_F3_actions_artifact.zip --output /tmp/cs-game-corpus-references
```

The source `corpus.py` is deterministic with fixed scenario templates, local PRNG namespaces and JSON serialization. Do **not** feed DEV, heldout, or `w0-reference.jsonl` into a model optimizer. Trainers should consume only `train.decisions.jsonl`; test loaders should keep a separately bounded DEV pass and untouched heldout FINAL.

`manifest.json` records exact generator version, reference blob pin, parameters, hashes, counts and discard statistics. `*.worlds.jsonl` provides per-world obstacle/protection/seed/provenance and material-grid digest. `*.episodes.jsonl` carries complete host-applied trails; `*.decisions.jsonl` carries supervised observation/choice/receipt pairs with hard negatives. Source-derived references belong only in the separate ingestion manifest. The generator does not download models or start optimizers; no paid compute.

## Evidence, limitations, and handoff

Initial local dry run: 10 world groups per scenario, 60 groups / 180 family episodes / 24,855 retained decision inputs, 6 raster PNGs; integrity audit PASS; six focused unit tests PASS. This is **synthetic-only**, and does not prove any model capability. Independent GitHub Actions qualification and a larger hosted artifact remain to be completed; generated binary corpora are not committed to Git history.

For WORM model workers (#575 LFM, #576 Sprocket), a practical next step is to consume a finite TRAIN slice in existing primary-owned optimizer lanes, evaluate on DEV by independent world group, preserve heldout unchanged, and publish *equal-seed, equal-budget* visual comparisons and checkpoint pins. For DRIV3R #570, supply untuned inference examples and family-sensitive motif tests, not competing optimizer dispatchers. No safety admission, production model promotion, native bridge change, merge or Ready transition is implied.

### Known limitations

- Protected material is immutable and non-traversable **only in this synthetic extension**; it is not a claim about current native material interaction.
- The teacher uses goal-distance and texture heuristics, not a globally optimal traversal planner. Legal lower-scoring alternatives are **heuristic hard negatives**, not authoritative incorrect actions.
- World material layouts are deterministic analytical fixtures; physical sand, water and Rapier simulation are **not** run.
- W0 references are preserved separately and designated evaluation-only to prevent self-training on model evaluation traces.


## Safe TRAIN-only handoff to model owners

`train.decisions.jsonl` is **not itself a safe prompt corpus**: each row contains teacher labels, whole-world/source identifiers, candidate scores and action receipts. Never interpolate an entire source row into the model input.

Use the separate positive-allowlist exporter. It verifies the full original manifest and corpus audit, checks exact synthetic TRAIN lineage and each pre-action observation fingerprint, then emits only observable host inputs in the user message and the one synthetic teacher token in the assistant message. A distinct, analysis-only sidecar preserves record/group/SHA provenance. **No DEV, heldout or W0-imported evaluation reference is loaded into the exporter.**

```sh
python3 -m unittest discover -s experiments/driv3r/corpus_factory -p 'test_*.py' -v
python3 experiments/driv3r/corpus_factory/export_train.py \
  --corpus /tmp/cs-game-corpus-v1 \
  --output /tmp/cs-game-corpus-v1-train-800   --per-action-cap 800 --per-world-cap 80 --sampler-seed 0
```

The output `train.messages.jsonl` is an action-token chat-message TRAIN slice; `train.provenance.jsonl` and `export-manifest.json` are verification/analysis, not prompts. The selected samples are deterministically hash-ranked and capped per target action and source world, reducing the original STRAIGHT-heavy label skew without falsifying the source distribution. The receipt pins the source manifest SHA-256 and output hashes. Export refuses to write inside the source tree or overwrite an existing export. Models must record their own exact root, adapter and training-job hashes; this exporter launches **zero** optimizers. This is a synthetic curriculum handoff, **not** admission to native gameplay or qualification of an intelligent policy.

New exporter tests check deterministic bytes, true TRAIN-only group provenance, target metadata exclusion, tamper-resistant per-observation fingerprints and rejection of model-derived rows even if someone rehashes the corpus manifest. Hosted qualification of the new exporter has **not** yet been established.
