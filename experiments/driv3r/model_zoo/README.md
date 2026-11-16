# MZ-001 — Pythia-70M game-policy onboarding (Draft/HOLD)

**Scope:** model research only. No CyberSand game code or content edits. Game application is a *future* downstream target; current runs use separate synthetic 13×13 worlds and host-legal action menus, not real Godot or Workbench PAINT.

## Purpose
Onboard a new architecture family: [EleutherAI/pythia-70m-deduped](https://huggingface.co/EleutherAI/pythia-70m-deduped), GPT-NeoX six-layer ~70M, Apache-2.0, exact model revision `e93a9faa9c77e5d09219f6c868bfc7a1bd65593c`. This is a genuinely pretrained model, not an initialized stub. RWKV-4 169M (recurrent) is a follow-on candidate, not yet qualified.

## Method
1. Deterministic host creates source-fenced 13×13 synthetic worlds containing walls, rocks, protected cells, painted history, obstacles and three motifs.
2. Host offers legal STRAIGHT/LEFT/RIGHT/RETRACE/BRANCH/STOP actions as six single-token candidate IDs (A–F). **It is the host, not the model, that restricts execution.** Record raw unmasked preference illegality separately.
3. Generate TRAIN episodes using seeds 1000–1047, held-out teacher episodes using seeds 9000–9011; fail on identical prompt leakage.
4. Load immutable Pythia model and train real LoRA rank-4 QKV adapters with optimizer gradients against host-produced legal action targets, 256 class-weighted CPU steps. Retain smoothed initial and final loss, per-action held-out recalls, p50/p95 forward time and context lengths. This is *bounded proof-of-learnability*, not claims of a usable artist.
5. Compare stock and adapted action preferences on held-out teacher examples and separately roll out both models on six identical seed-matched worlds. Preserve their actual rendered synthetic PNGs, action sequences and hashes. No invented native receipts.
6. Preserve real adapter checkpoint in Actions artifacts; never check model binaries into git. Source commit is stamped in JSON. CPU runner only; no paid API/GPU.

**Scientific caution:** actions are synthetic teacher-generated; no actual CyberSand pixels, native material readbacks, independent human judgements, or game-world reward. An increase in synthetic action imitation is not proof of native game-policy quality. Small fixed horizons and stock/adapted comparison make this a cheap screening stage. Do not promote on training loss alone.

Run locally (requires pinned Python dependencies and network access to the public model):
```bash
python experiments/driv3r/model_zoo/zoo_pythia.py --self-test
python experiments/driv3r/model_zoo/zoo_pythia.py --output model-zoo-out --steps 256 --batch 6
```

**Hard boundary:** never change `godot/**`, `native/**`, Workbench, game assets, maps, materials, rendering, gameplay or default production providers. Any downstream game-side change requires separate owner-controlled handoff. Research branch and PR remain Draft/HOLD; no merge.

## Historical first wave (unweighted 48 steps)
Exact source `f4c399338cdcdb324f995d33310b448b2ee79d1a`, [successful run 43788084986](https://github.com/techrote/cybersand/actions/runs/43788084986), artifact 14190837843: held-out unmasked teacher imitation stock 167/276 (60.51%), adapted 169/276 (61.23%). Original seed-matched six-world synthetic rollouts: mean painted stock 13.17 versus adapted 20.17. The adapted model largely avoided premature STOPs, which is a behavioural observation, not proof of improved planning. All executed actions host-legal. Later class-balanced results are separate experiments, not retroactively attributed to this wave.
