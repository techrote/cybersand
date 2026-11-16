# DRIV3R Population Lab — P0 neural policy ecology

**Target:** eventually supply small, weird, useful host-authorised CyberSand game/painting controllers. **External research only.** Do not edit game code, native physics, scenes, Workbench, materials, maps, assets, or production providers.

## P0 executable population

A separate 22×22 synthetic world offers a finite legal action catalog: cardinal single-cell paint into empty/unprotected cells, logical brush-up RETRACE along a known parent tree, and STOP. Synthetic obstacles, a protected rectangle, a narrow wall, and a mid-episode goal change exercise game-facing control.

Six training niches: navigator, branch artist, recoverer, texture worm, material cautious, chaotic brush. These are **20-feature / 24-hidden-neuron neural MLP policies**, NOT pretrained language models. They receive real Adam gradient updates on niche utility targets from sequential on-policy/teacher-augmented game episodes. This cheap, falsifiable proxy infrastructure precedes actual SLM adapter/student training.

Default: 6 niches × 3 initial policies + 1 mutated/retrained child each = 24 candidates, 36 training seeds, 8 selection-only seeds, and 12 untouched final holdouts. PBT chooses using selection worlds only. Weights, optimizer-step counts, rejected candidates, parent lineage, split-hash manifests and final comparisons are retained in original experimental outputs.

## Run

Requires Python 3.11+ and NumPy 2.3.x.

    python -m unittest discover -s experiments/driv3r/training/population -p 'test_*.py' -v
    python experiments/driv3r/training/population/population_lab.py --output /tmp/population-619 --seed 619

Output directory must not exist. Original synthetic research artifacts are produced under results.json, models/*.json (real trained weights), gallery/*.svg and gallery/*-trajectory.json. Each run is seed-replayable. Generated weights are intended for immutable GitHub Actions artifacts, not Git history.

## Controls and interpretation

- Uniform legal random: STOP is sampled, so this is a deliberately weak control.
- Nonstop random: uniform among legal nonterminal choices, STOP only if stuck; **critical fairer random control**.
- Persistent: deterministic heading-first non-neural controller.
- Synthetic oracle: greedy scorer using the same handcrafted reward proxy; a privileged local control, NOT a game quality metric.
- Host prefilters illegal actions, so 100% menu legality does **not** establish learned safety.
- Niche rewards are synthetic handcrafted proxies, not human judgements or demonstrated gameplay improvement.
- Descriptor diversity uses painted coverage, retrace fraction, turns, branching-junction frequency, net displacement. Do not infer aesthetic quality from a scalar alone.
- No native Workbench PAINT, real model-language inference, source-faithful Godot material readbacks, or production integration occurs in this experiment.

## Next concrete waves

1. Held-out observation-sensitive versus frozen-action-prior counterfactuals; delayed obstacles, misleading goals, dead-end recovery.
2. Novelty-search survivor archives and true population diversity, compared against reward-only PBT; carefully evaluated adapter/weight mixing.
3. Train real sub-1B language-model adapters on the legal-candidate-choice contract using this population as one of several teachers. Measure genuine model inference and generalisation; do not rename MLP results as SLM results.
4. Extend materials/observations using **READ-ONLY** real CyberSand schemas. Any new game-side interface must be proposed as a handoff, not implemented here.

Draft/HOLD only. No merge, game edits, paid API/GPU spending or production provider modifications.


## P1 — actual retraining, novelty archive, and observation ablations

Run the P0 command first, then run:

    python experiments/driv3r/training/population/population_p1.py --p0-output /tmp/population-619 --output /tmp/population-620 --seed 620 --offspring 4 --train-episodes 18 --selection-episodes 8 --holdout-episodes 12

P1 reloads all six exact P0 champion neural checkpoints, builds four new offspring per niche (mutation + retraining, substantial parameter perturbation, and cross-niche weight mixing + retraining), and **executes actual Adam optimizer updates**. It retains all 30 evaluated policy weights and their lineage, selection metrics and model digests, not just six champions. Mixing identical-shape MLP weights is an exploratory control; it does not establish that arbitrary transformer checkpoints/adapters can be merged.

Selection and held-out seeds are newly derived and disjoint from P1 training seeds. Each candidate is evaluated on **selection-only** worlds, with a 14-dimensional movement/topology/spatial descriptor. k-nearest-neighbour novelty and discretized behaviour bins form a conservative archive. Two survivors per niche are compared on fresh held-out worlds: reward-only selection, and 55% within-niche reward + 45% novelty selection. A larger descriptor distance does not imply higher human artistic preference. Any diminished reward is reported, not concealed. This is an *archive over candidate evaluations*, not a claim of population-wide evolutionary convergence.

An observation-dependence ablation replays each selected policy with its initial action-score prior held fixed while preserving the current host-legal action menu. Reports include choice divergence on **identical encountered states**, probability total variation, the post-goal-switch divergence and a separate frozen-prior rollout reward. It asks whether changing observations influence the policy's actions; it does **not** prove the model learnt goal reasoning, and the static prior maps previously unseen actions to the initial mean score.

The original held-out trajectories and SVGs for BOTH selection policies, original per-candidate weight JSON, seed-hash manifest and failed/weak candidates are retained inside the same immutable Actions evidence bundle. The P0 baselines (nonstop random, persistent and privileged synthetic oracle) are rerun on new P1 holdouts. Nothing here uses native Workbench, performs real-game training, imports Godot code or changes game content.

P2 priority: train a true sub-1B SLM/adapter as a student on legal-choice trajectories; compare frozen-input/teacher-distilled samples with train/selection/heldout controls. Keep P1 MLP evidence separate from claims about actual language-model capabilities.
