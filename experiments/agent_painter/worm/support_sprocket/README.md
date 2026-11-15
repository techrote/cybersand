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


## V1: six-action anti-collapse probes and replayed RIGHT-only stress

To generate independent, **support-only** v1 sidecars (without altering the v0 data):
\`python3 experiments/agent_painter/worm/support_sprocket/probes_v1.py --output /tmp/sprocket-v1\`

The first genuinely trained SPROCKET WORM policies learned legal EOS framing but collapsed overwhelmingly to STRAIGHT (W1) and then RIGHT (W2 static probes); the primary also measured literal model-prompt overlap across its source TRAIN/EVAL worlds. V1 therefore supplies **54 constructed TRAIN local-motif action examples** (3 variants × 6 labels × 3 themes), **36 constructed DEVELOPMENT probes** (2 different variants × 6 × 3), and a **54-row TRAIN-only family/action-balanced candidate sampling view** (3 per pair, preferring up to two genuine W0-observed TRAIN rows). The validator fails closed on literal input overlap across **all original support v0 and new v1** TRAIN/DEV rows, and on conflicting labels for identical prompts. All masks/targets are legal according to the imported W0 contract.

These LOCAL counterfactuals are *not* executed world states, independent structures, native Art admissions, or actual learned decisions. Their coordinates/variants do not prove semantic novelty; they are diagnostic failure probes. Never optimize against DEVELOPMENT; the primary owns all eventual model-training leases/recipe revisions. The unchanged original v0 corpus remains separate.

Six additional genuine **W0 source-faithful, model-free** 384×384 PNGs and paired JSON receipts replay a deliberately constant RIGHT raw controller on the same two gallery world seeds × three themes. Raw policy choices and host substitutions are recorded separately. This does **not** purport to reproduce the trained W2 model, whose own original online evaluation is authoritative. The support Actions workflow runs all tests and retains versioned JSONL/PNG/source SHA-256 evidence.

## S1 independent frozen-score counterfactual (15 November 2026)

Original S1: [hosted #43726271494, artifact #14168225018](https://github.com/techrote/cybersand/actions/runs/43726271494/artifacts/14168225018). Script `audit_s1_crn.py` pins its immutable original ZIP SHA-256 and exact shepherd W0 source SHA-256 from commit `4bb9d6e1d0d0d78183f87d1e3c29648edafacf61`. It verifies all 69 CRCs, 68 internal SHA-256 checks and 12 original W0 pixel-exact S1 PNGs.

    python3 experiments/agent_painter/worm/support_sprocket/audit_s1_crn.py \
        /path/to/original-S1.zip --trusted-w0 /path/to/immutable-w0.py --output /tmp/s1-crn

With ZERO optimizer, checkpoint edits or model downloads, the audit compares **real first-step trained six-token logits** on genuinely identical host observations except family, or with identical prompt/logits across temperatures. This isolates first-step score sensitivity from the host RNG confound. Two obstacle seeds are two independent worlds, not six.

It then executes **24 new bounded W0 host replays** (three families × two worlds × four counterfactual policies; ≤24 decisions each). The four variants apply the frozen original T1 per-tick six-logit tape at T1/T3, its time-mean prior at T3, or legal-action-uniform logits at T3. The host draws the same deterministic SHA-256 uniform for a given world seed and tick across family, temperature and ablations; six original-pixel contact sheets include the genuine first-party S1 T1/T3 gallery plus the four new control PNGs.

**Scientific restriction:** after the first trajectory divergence the original logit tape is *off-policy*: those logits were not computed for the new observation. This experiment diagnoses host sampling and prior effects, NOT fresh live learned model-in-the-loop responses or model-conditioned closed-loop steering. It is W0 Python, not native Godot Art.

Use `s1-crn-audit-report.json` for exact source custody, per-policy action histograms, STOP/survival denominators, bbox/radius and first-step logit/softmax total-variation measurements. Early STOP reduces executed actions below the 24-step allocation; do not compare raw coverage without those denominators. Send only substantive results to #612, cross-link #568; do not modify the shepherd-owned dashboard body. Keep PR Draft/HOLD.
