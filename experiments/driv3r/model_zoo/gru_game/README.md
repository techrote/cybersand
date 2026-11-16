# MZ-007 — GRU-19M from-scratch game-policy baseline

**RESEARCH ONLY — Draft/HOLD.** No changes are permitted to CyberSand game code, Godot, native, Workbench, simulation, materials, maps, production provider settings or game assets.

## Why this experiment

MZ-001–006 show that frozen pretrained language representations generally underperform a cheap structured-feature model on the same synthetic game-action teacher. MZ-006 verified that limited pretrained encoder training can help, but did not close the gap. Before onboarding another expensive language backbone, test whether **a fully trainable recurrent network shaped specifically for game observations** can generalize from *sequences* of material/obstacle/goal states. This is a new from-scratch game model, not a pretrained language model. It belongs to the 20M model zoo as an approximately 18.7M-parameter recurrent candidate.

## Experiment and fair controls

- Eight-layer, 640-unit GRU with a seven-action classifier; ~18.7M parameters genuinely trained (no frozen pretrained representation).
- Input is four successive 114-feature game observations. Prior goals are masked to zero to avoid leaking counterfactual target goals. The current target, local painted/blocked/protected cells, facing, turn and legal actions remain visible. Past observations are only taken from earlier steps in the same synthetic world.
- 120 TRAIN world seeds, eight DEV and eight held-out TEST world seeds, 10 turns per world, four-way directional counterfactual goals when legal.
- 600 optimizer updates for the recurrent model **and** the 114-feature structured policy, with the exact same mini-batch indices and 64-example batch size. The parameter count differs drastically: matched exposure, not matched FLOPs.
- Constant-majority baseline, **history-ablated recurrent model**, goal-swap paired accuracy and switch rate, macro-F1, raw illegal proposals, legal host masking, real evolving trajectories against structured/random/teacher.
- CPU forward p50/p95, optimizer-step p50 and peak RSS, full independently reloadable training checkpoint and original 4x4 painted-world gallery.

The inherited deterministic synthetic 11×11 research world comes exclusively from `experiments/driv3r/model_zoo/mamba130/**`; it is **not the actual CyberSand world**, and claims about native Workbench performance are prohibited.

## Qualification and promotion

The dedicated workflow `.github/workflows/driv3r-model-zoo-gru-game.yml` installs pinned CPU torch and Pillow, verifies world and model tests, performs actual GRU optimizer updates, checks source SHA and trained checkpoint SHA-256, and uploads original weights/metrics/traces/gallery as a short-lived Actions artifact.

Do **not** promote the model solely on teacher-label accuracy. Compare against the structured policy and history-ablated controller. A recurrent model whose history does not help, or which always emits the same action, is a valid negative. Retain weird but legal generated geometry as evidence. No merges, Ready changes, production registration, paid training services or gameplay implementation changes without owner acceptance.
