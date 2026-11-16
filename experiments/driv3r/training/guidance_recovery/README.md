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


## 16 November 2026 — harder recovery curriculum and actual CPU fine-tuning

**New modules:** \`hard_recovery.py\`, \`test_hard_recovery.py\`. They use the existing 25-feature policy head and the original unmodified synthetic \`World.apply\` permission authority. Training/evaluation is entirely external to CyberSand; this is **not native painting, native material Undo, model d1 inference, or model-side permission authority**.

**Motivation:** The initial short-detour six-decision recovery metric was saturated at 112/112 without host cues. The new adversarial scaffold instead has a misleading Manhattan-direction dead-end of depth 2–4, protected/forbidden non-corridor cells, a counterintuitive side branch that initially travels *away* from the apparent goal, and host-issued optional recovery advice. Returning to the junction by ordinary LIFT is no longer equivalent to **cleanly unwinding the actual history stack** with BACKTRACK. The evaluator separately measures return to junction, clean stack restoration, escape branch entry, illegal host writes, false-cue response and retained original held-out turn personality.

**Genuine optimizer work:** Fine-tuning initialized from the earlier immutable local baseline checkpoint SHA-256 \`484d039cf6db118410f5da4e4e5984e25c235fbb08c732bb7a882a1d6080da67\`; new 2,036 hard-state supervised samples mixed with original procedural-stochastic teacher examples into 14,089 examples; 1,036 further AdamW steps over 14 epochs. Loss 1.15941 → 0.82323. The resulting 24,084-byte safetensors checkpoint SHA-256 is \`3c3163428b796561fc5f56fd50d0be0a76c6f17ce0d8d3b1871205de0c568b33\`.

**Held-out evaluation:** 576 complete trap episodes per controller, matched across seeds, personality, scalar strengths {0, 0.35, 1}, and host-cue flag; 96 per arm/flag. Depth-4 traps and orientations 2/3 are **not present in the trap fine-tuning generator**. Nevertheless the topology uses the *same underlying corridor template*; this is deliberately **not claimed to be cross-topology generalization**. Stochastic action draws use a paired initial RNG seed, but diverged trajectories are not same-state counterfactuals.

| Model / scalar arm | Clean no-cue unwind | Clean cue-on unwind | Escape branch no cue | Escape branch cue-on |
|---|---:|---:|---:|---:|
| Baseline / 0.00 | 0/96 | 0/96 | 4/96 | 1/96 |
| Fine-tuned / 0.00 | 76/96 | 64/96 | 90/96 | 94/96 |
| Fine-tuned / 0.35 | 78/96 | 64/96 | 92/96 | 93/96 |
| Fine-tuned / 1.00 | 79/96 | 63/96 | 93/96 | 94/96 |

**Important negative:** The new head learns substantial cursor-stack recovery and branch escape, but **host cues decrease clean unwind success**: at zero guidance from 76/96 to 64/96, and at maximum guidance from 79/96 to 63/96. On genuinely held-out depth-4 traps at 0.00 scalar, clean unwind drops from 18/32 uncued to 6/32 cued. This is not established cue-following competence; more work is required on calibrated correction and longer-horizon recovery. False-cue counterexamples yielded 0/80 greedy BACKTRACK choices on open productive states, both before and after tuning, in each scalar/cue arm; this is a narrow negative-control check rather than general robustness. The original held-out student personality gap was 0.0975 baseline versus 0.0870 fine-tuned at zero guidance, and 0.0515 versus 0.0597 at strong guidance (8 seeds; small cohort). It is not proof of persistent personality.

**Reproduce (using the exact baseline checkpoint from the prior local bundle):**

\`\`\`bash
python -m unittest discover -s experiments/driv3r/training/guidance_recovery -p 'test_*.py' -v
python experiments/driv3r/training/guidance_recovery/hard_recovery.py \
  --checkpoint /path/to/guidance_recovery_head.safetensors --out /tmp/driv3r-guidance-hard \
  --train-instances 240 --eval-seeds 16 --epochs 14
\`\`\`

- Exact committed blobs locally tested: \`experiment.py\` Git SHA-1 \`cf67d48228f6512e8a6262b357c2fcc3bd04d9dd\`; \`test_experiment.py\` \`b777f437c7cf16e38cc5d54b6e3ab9134584d9ce\`; \`hard_recovery.py\` \`946279b4a0f47ec2cb48b38ccbf77bfdc9884d07\`; \`test_hard_recovery.py\` \`b3801ea0223dd229c4a177864534a1d2e2ab4213\`.
- **21/21** discovered offline tests pass. Two complete exact-source optimizer/evaluation runs generated byte-identical checkpoint and trajectory files, with equal numerical metrics.
- Synthetic trap dataset SHA-256 \`b03947da5d600b6186396377061d51d9153dbd2c25aa3ec3dc665b9e7f5c7050\`; source \`hard_recovery.py\` SHA-256 \`96c80ee1c17e49f251807316d8ca2926951ce0a52f6f815a2b743a26b81e95e8\`; full record hashes are in generated \`hard_metrics.json\`.
- Output \`hard_metrics.json\`, \`hard_trajectories.json\` and binary remain **off Git history**. They have not been delivered as an immutable GitHub Actions artifact; that requires a separately owned workflow/handoff rather than editing shared workflow files from this lane.
- Synthetic BACKTRACK only repositions a cursor and changes its history. **No painted material is ever undone**. Legality remains host-recomputed; candidate scalar scores never alter forbidden materials.
