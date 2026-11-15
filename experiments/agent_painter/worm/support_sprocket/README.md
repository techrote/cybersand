# WORM-001 SPROCKET support — deterministic local decisions, v0

**Scope:** experimental, source-faithful **Python W0** support only, not learned policy, native Godot execution, complete-Art v2 output or useful-model freeze. Authority: [WORM #612](https://github.com/techrote/cybersand/issues/612) and [owner pivot](https://github.com/techrote/cybersand/issues/568#issuecomment-6891678794). Keep this and SPROCKET primary #576 Draft/HOLD; do not merge. Historical SMOL #573 untouched.

The support worker imports, never forks or edits the shepherd-owned W0 implementation at ../common/worm.py, contract cybersand.worm.observation-action/0-experimental. Exact action tokens: STRAIGHT, LEFT, RIGHT, BRANCH, RETRACE, STOP. Each input contains W0 fields x, y, heading (E/S/W/N=0/1/2/3), local_5x5 (@ current, # wall, + visited, . fresh), legal, last_actions, family and tick. The host alone determines legal moves, native permission/focus, Stop/Undo/history and materials.

## Execute (stdlib Python, no model weights)

From repository root:

    python3 -m unittest discover -s experiments/agent_painter/worm/support_sprocket -p 'test_curriculum.py' -v
    python3 experiments/agent_painter/worm/support_sprocket/curriculum.py --output /tmp/worm-sprocket-support

Outputs: synthetic dataset/train.jsonl and dataset/development.jsonl with canonical hashes and versioned manifest; **24 actual 384×384 PNGs and 24 full exact W0 replay JSON receipts** at two gallery world seeds × three families × four policies. Policies are W0 random, wall, fidget, plus SPROCKET-support synthetic teacher. The four policies share world seed, 96×96 grid, obstacles and maximum 128-step budget. Teacher is selected from actual W0 legal observations after each replay prefix, never by a duplicated local physics simulator. This costs O(steps squared) but is capped at 128 steps. Gallery manifest exposes all seeds, metrics, hashes and first-pass choices; poor outputs are retained.

## Dataset / split custody

- TRAIN world seeds: 101, 107, 113, 127, 131, 137. DEVELOPMENT: 1009, 1013, 1019. GALLERY: 2111, 2129. A world seed is the independent obstacle-structure group; many steps, policies and family variants are correlated views.
- Real W0 random/wall/fidget observations sampled every third tick receive deterministic rule-derived, legal local targets. Four extra clearly constructed rare-action fixtures per family cover junction BRANCH, blocked RETRACE, terminal STOP and deadline STOP, tagged constructed-not-native and TRAIN-only.
- Exact-observation SHA-256 dedupe removes repeated input states including collisions across splits; DEVELOPMENT world-seed set remains disjoint. Neither property proves semantic generalization.
- Each JSONL row contains input (compact serialized observation prompt ending ACTION=), target (one bare uppercase legal action), observation, group, world_seed, source, observation_sha256 and version. The SPROCKET primary may apply its verified pinned model-specific chat/EOS framing in a separately sourced WORM recipe.
- The corpus is synthetic WORM action-selection data, **not original native-admitted Art v2 TRAIN**, not frozen DEV60 and not sealed FINAL. Never use it to overwrite legacy checkpoints.

## Limitations / handoff

The teacher is intentionally simple: Greebles favours frequent turns, Pipework longer straight tracks, Architecture rhythmic orthogonal segments. It can BRANCH, RETRACE and STOP, but cannot plan entire buildings, guarantee loops, predict playability or establish art quality. W0 output is a source-faithful PNG grid raster, not actual native Godot material cells. Train a SPROCKET WORM model only under the primary's explicit unique training lease; this support lane never runs an optimizer.

The primary should compare genuine model first-pass choices and rollouts against all paired same-seed baselines, tracking illegal decisions, EOS, blank/uninteresting traces, branches, retraces, revisits, coverage and visual interest. No hidden action repairs or cherry-picked only-success images. Publish exact source commit, TRAIN/DEVELOPMENT hashes, action counts and gallery receipt hashes in issue #612, cross-link #568, and request independent visual review before any useful-version claim.
