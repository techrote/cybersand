# WORM-001 LFM support: local action decisions v1

Authority: [WORM-001 #612](https://github.com/techrote/cybersand/issues/612) and [owner 15-Nov pivot](https://github.com/techrote/cybersand/issues/568#issuecomment-6891678794). **Draft/HOLD; no model optimizer, native application, production provider or historical #574 edits.**

This is a runnable, deliberately small **W0 local-action supervision** dataset, paired legal baselines, and a seed/obstacle-matched **96×96 non-native PNG gallery**. It imports the shepherd-owned W0 host at `../common/worm.py` (initial qualified source `4bb9d6e1d0d0d78183f87d1e3c29648edafacf61`). The host—not this curriculum—owns obstacles, bounds, legal actions, raw-invalid fallback, Stop and rendering. Re-qualify if W0 changes. This code never accesses the old whole-scene TRAIN/DEVELOPMENT/FINAL.

## Action/observation contract

Same experimental W0 `cybersand.worm.observation-action/0-experimental`: `STRAIGHT LEFT RIGHT BRANCH RETRACE STOP`; heading 0 east/1 south/2 west/3 north; 5×5 local `#` obstacle/out-of-bounds, `+` previously occupied, `.` fresh, `@` current; `legal`, `last_actions`, `tick` and `family`. Teacher is a deterministic, *untrained* heuristic: seek fresh cells, sometimes branch at junctions, family-specific zigzag/straight preferences, retrace at blocked/revisited local fronts. Teacher labels are always legal; this is not a claim that all its trajectories are visually good. Some real decisions may be off-policy states drawn from W0 `wall`/`fidget` demonstrations.

- `train.jsonl`: 12 distinct obstacle-world seeds 1101–1112, three families, two non-model source policies, first 32 observed decisions or until Stop.
- `development.jsonl`: separate obstacle seeds 2101–2106 with identical procedure; **never** optimize on these labels. Multiple trajectories or themes sharing a seed remain within the same split and are **not independent design structures**.
- `world_group`, exact decision IDs, plain `prompt`, and `target_action` are present. The prompt is **plain UTF-8 text**, *not* an LFM chat template or proof of token fit. LFM primary alone wraps it using pinned official `Lfm2VlProcessor`, chooses EOS7 and owns the versioned WORM LoRA recipe.
- The generator rejects duplicate example identities, cross-split obstacle groups, illegal labels or unknown action strings. No private held-out complete-scene Art targets/images are used.

## Reproduce now

```sh
python3 -m unittest discover -s experiments/agent_painter/worm/support_lfm -p 'test_curriculum.py' -v
python3 experiments/agent_painter/worm/support_lfm/curriculum.py --output /tmp/worm-lfm-v1 --steps 240
```

Python 3.11+ standard library only; import resolves the current shared W0 baseline in the stacked branch. `manifest.json` contains full train/DEVELOPMENT source seed lists, counts, and canonical JSONL hashes. `gallery/summary.json` inventories each actual PNG and exact-trace JSON with SHA-256 and per-run metrics. `--steps` bounds gallery decisions to 1–512; training observations are capped independently at 32. GitHub-hosted workflow runs these commands and uploads the actual archives (no LFM model download, no GPU, no native Workbench claims).

## Fair paired evaluation

`save_gallery()` emits random-legal W0, deterministic wall W0 and a closed-loop heuristic oracle on the **same held-out seed, obstacle map, theme, grid and decision budget**. The oracle uses `rollout()`: each next observation arrives via the W0 authoritative callback after host legality checks, never teacher-forced. It also draws `TELEPORT` raw-invalid and constant-`LEFT` failure controllers, with original decisions and host refusals in adjacent JSON traces. These are **illustrative non-model failures**, not LFM first passes.

`statistics()` includes decision count, invalid raw count/rate, host unique coverage of obstacle-free cells, novelty per decision, W0 revisit contacts, branches, retraces, blocked-local decisions, recovery by retrace, longest repeated-action streak and applied-action entropy. Retraces are tracked separately rather than silently counted as new trail visits. No metric alone establishes aesthetic value; assess original PNGs alongside the numbers.

To compare an **actual model** without falsifying its output, LFM primary imports:

```python
from curriculum import evaluate_policy, statistics, worm
pairs = evaluate_policy("lfm-raw-stepNN", choose, seeds=(2101,2102), steps=48)
# choose(observation: dict) -> str, unmodified first-pass raw text
# Each (record, metadata) holds W0 events/raw_choice, host applied action, obstacles.
```

`choose` must invoke the genuine pinned model with the current observation. It MUST NOT see a DEVELOPMENT `target_action`, use answer repair, teacher fallback, hidden retries or altered host legality. W0 invokes the genuine policy once per decision and caps these evaluations at 512 actions; real-time native integration is a later separate W4 gate. If model outputs `"LEFT\n"`, it is **invalid** as a raw W0 action and remains invalid in the receipt.

The workflow does **not** report model-vs-baseline because no model endpoint/explicit optimiser lease has been provided. Current output is support-source evidence only. LFM primary can consume exact corpus hash, prompt-v1 format, held-out action interface and W0 PNG schema before launching its own CPU model training. The owner-authoritative Art2 complete-scene FINAL remains sealed.
