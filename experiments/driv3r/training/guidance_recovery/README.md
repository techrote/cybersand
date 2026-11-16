# DRIV3R guidance/recovery trainer — isolated game-policy head

**16 November 2026 — initial real CPU optimiser result, DRAFT/HOLD.**
This experimental training lane is owned exclusively under
`experiments/driv3r/training/guidance_recovery/**`. It **does not modify CyberSand**
or the D-1B soft-field owner branch. See [#570](https://github.com/techrote/cybersand/issues/570),
the [owner roadmap](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001),
the owner-accepted M1 contract (source `8fa90de6be209ed0b7bd125039e6ec8b332fb1a6`;
schema SHA-256 `ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d`)
and separate [D-1B PR #596](https://github.com/techrote/cybersand/pull/596).

## Executable scope

`experiment.py` trains a **small, nonlanguage, 25-feature / 64×64 MLP action-scoring head**
by genuine AdamW gradient descent (soft-distribution imitation of a seeded, imperfect,
stochastic procedural teacher). It is **not** LiquidAI d1-2B, a LoRA adapter, a
resident inference worm, a native Workbench controller or a real permission source.
No API, GPU, paid computation or game runtime is accessed.

The external 15×15 game-like sandbox supplies a ten-action catalog: four one-cell
INK, four pen-up LIFT, BACKTRACK_CURSOR and STOP. Terrain families include
obstacles, forbidden `SOLID_ROCK` / `FORBIDDEN_GLASS` cells, mutable AIR/INK,
visited strokes, branch history, personality-dependent turn preference, a changed
goal at decision 16, and two induced *host-legal, material-preserving* detours at
decisions 8–9. A three-decision host-issued correction cue is independently toggled.
The scalar preference field is quantised to unsigned 16-bit and contains a
deliberate misleading local maximum. Three matched strengths are 0, 0.35, 1.0.
Hints and recovery cues never change candidate legality or material permissions;
the host rechecks every action, including forged long/diagonal moves. BACKTRACK
moves the cursor only; **there is no native or synthetic material rollback**.

TRAIN topology families: `bars`, `islands`, `clumps`. Sealed-by-construction
**unseen-family** evaluation: `switchback` and `forks`, with disjoint seeds.
Each held-out source has both personality signs, all three guidance strengths,
and cue/no-cue copies. Counterparts share geometry, seed, legal action menu and
initial material; after decisions diverge, each runs its own state. The same-state
first-choice measure is reported separately from later episode outcomes.
The learned policy samples from its score distribution; greedy, procedural teacher
and random-host-legal controllers are retained as controls.

## Exact local execution and limitations

Python 3.11+ with `torch==2.10.0+cpu`, `numpy==2.3.5` and
`safetensors==0.7.0` was used. From repository root:

```bash
python -m unittest discover -s experiments/driv3r/training/guidance_recovery -p 'test_*.py' -v
python experiments/driv3r/training/guidance_recovery/experiment.py --episodes 360 --eval-seeds 28 --epochs 10 --out /tmp/driv3r-guidance
```

**12/12 focused local tests passed**, including an actual discovered bug:
the original sandbox executor erroneously admitted diagonal/long movement
when a caller forged an action. It was repaired *before* the final training run.
Tests and `experiment.py` are byte-matched to their published Git blob objects.

The completed **10-epoch / 1,340-step AdamW** run used **25,719 actual
teacher-state training samples** from 1,080 procedural episodes. Training
cross-entropy declined from `1.31313` to `1.07994`. The held-out evaluation
contains **2,688 synthetic episodes**: 2 families × 28 seeds × 2 personalities
× 3 strengths × 2 cue states × 4 policies, at most 24 decisions each.
All metrics are **synthetic host observations**, never authenticated native receipts.

| Held-out policy / guidance / cue | Mean unique INK cells | Mean final goal distance | Six-decision recovery | Mean BACKTRACK (decisions 10–13) | Turn-personality gap |
|---|---:|---:|---:|---:|---:|
| Student / 0 / no cue | 19.25 | 7.741 | 112/112 | 0.018 | 0.1043 |
| Student / 0 / cue | 19.13 | 7.795 | 112/112 | 0.232 | 0.0952 |
| Student / 0.35 / cue | 19.03 | 7.643 | 112/112 | 0.232 | 0.0683 |
| Student / 1.0 / cue | 18.92 | 6.964 | 112/112 | 0.196 | 0.0275 |
| Random legal / 0 / cue | 6.68 | 13.357 | 77/112 | 0.625 | −0.0006 |
| Procedural teacher / 0 / cue | 17.12 | 7.964 | 112/112 | 0.348 | 0.1271 |

Matched same-state first choices changed for the stochastic student on
**5/112** weak-vs-none and **8/112** strong-vs-none pairs. The full
trajectories diverge thereafter; end-state differences cannot be represented as
same-state causal evidence. The cue increases BACKTRACK selection markedly, but
recovery to the *pre-detour Manhattan distance* is trivial for this student
(112/112 with or without cues). Therefore the recovery metric is **saturated**
and is not evidence of robust trapped-worm intelligence. More interesting,
the strong guidance arm slightly improves distance but **erodes the
signed-turn personality difference** in this limited cohort. That is a
negative tradeoff to preserve, not an occasion to tune away the failures.

### Exact source/data/checkpoint provenance

- Published source (`experiment.py`) SHA-256: `7e6157bd5e10187ce181136b3badd18ce6f4e755eb28b0a140ce0ca26362274d`.
- Dataset provenance index digest: `2748e393d44830100315068f85b54cd3695a51a342e10fb9a98dd541a9f0638f`.
- Raw float32 feature-buffer SHA-256: `f21f6e898b9b5f8548e7a9dd50168b0f9c38272e67e5308658952b133546f630`.
- Teacher distribution SHA-256: `eed8e7c143309931333a01f005b1981c4370a1e8ff68787c5a5c61f3ccdb6cf8`.
- Full episode-record digest: `a895430c5fd06e5020a4202ed8a14a41e971f4859924b25241193de237501cd1`.
- Sampled full-trajectory gallery digest: `c61dcbb0b404aebce05254be8e602f2f4072420cac0998920268f3fd94750c8f`.
- Genuine resulting `safetensors` head (24,108 bytes) SHA-256:
  `484d039cf6db118410f5da4e4e5984e25c235fbb08c732bb7a882a1d6080da67`.
- Fixed training RNG seed 73, data seed 20261116; local measured runtime 13.12 seconds on CPU.

The standalone local checkpoint, complete 2,688 per-episode records and
trajectory gallery were **not uploaded to immutable GitHub Actions artifacts**
in this iteration. Their hashes are documented, and the scripts regenerate
them outside Git; **no model binary is committed to Git**. Until a separately
qualified lane-scoped hosted artifact job exists, a GitHub reviewer can reproduce
the run but cannot claim archived original-checkpoint custody or hosted
exact-source PASS. No external trained weights or d1 inference are claimed.

**Next substantive work:** add more demanding cue-dependent recovery cases
(with deceptive recovery cues and genuinely trapped branches), quantify
turn-style preservation against stronger preference fields, and publish
checkpoints/traces as immutable source-qualified Actions artifacts without
touching game/shared workflow ownership. All PRs remain Draft/HOLD; no merge
or production-default changes.
