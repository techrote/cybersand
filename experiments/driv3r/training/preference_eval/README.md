# DRIV3R Gameplay Behaviour & Preference Lab — P0 image-derived proxy pilot (16 Nov 2026)

**DRAFT/HOLD research only.** Model-side evaluation under `experiments/driv3r/training/preference_eval/**`. No game/runtime/Workbench edits, no provider changes, no merged outputs, no DRIV3R #570 model-forward jobs. No owner/human ratings have been collected.

## What was actually used

32 **original**, visually inspected, 96×96-equivalent W0 material-drawing PNGs (extracted by reading source 384×384 nearest-neighbour PNG bytes, each source pixel copied 4×4): eight 128-turn genuine learned-model-scored synthetic Python W0 drawings plus 24 matched same-world model-free random/wall/fidget controllers. Sources:

- **LFM W13** — [Actions #43771476464](https://github.com/techrote/cybersand/actions/runs/43771476464), [artifact alpha #14185385444](https://github.com/techrote/cybersand/actions/runs/43771476464/artifacts/14185385444) and [beta #14185425004](https://github.com/techrote/cybersand/actions/runs/43771476464/artifacts/14185425004), original code `245290cab2352381dbd1eaf16374c577138b4ade`. The published original alpha outer ZIP SHA is `0e69b23c100a00b438d4e2d9d07fa4550e276368e0ad4635e38a6c858f79b95e`. Beta outer ZIP SHA is `36fa8876f249b0263d19dc40bea17731e8a4776da9cc82400189a876980380ff`. The source loader selects the correct immutable archive SHA for alpha seeds 6111/6127 versus beta seeds 6143/6167; the CSV stores image SHA-256 per individual controller.
- **Sprocket F3** — [Actions #43769025429](https://github.com/techrote/cybersand/actions/runs/43769025429), [artifact #14183924474](https://github.com/techrote/cybersand/actions/runs/43769025429/artifacts/14183924474), original code `e56e0aac49b310cc1e00aafe3ffeddb90eca6e38`, original outer ZIP SHA `5eb64e5f7d5335809f631aa11caf9edbfcf1a67f546601d5d14e795cc61f7af6`.
- The **actual original learned image SHA-256** is held per image in `source_features.csv`; all eight independently re-hashed PNGs matched the prior curated published learned image hashes. The 24 control PNG hashes were independently computed from their archived embedded original bytes. Entire earlier producer archives were verified by the separate ethology curation; this P0 did **not** freshly redownload these archived producer ZIPs and does not claim new source/runner authentication.
- Seeds and original learned run lease identities (synthetic completed episodes):
  - W13: 6111 `lfm-w13-43771476464-alpha-0-6111`; 6127 `lfm-w13-43771476464-alpha-1-6127`; 6143 `lfm-w13-43771476464-beta-0-6143`; 6167 `lfm-w13-43771476464-beta-1-6167`.
  - F3: 8111 `43769025429-e56e0aac49b310cc1e00aafe3ffeddb90eca6e38-0-f3-0-8111`; 8123 `43769025429-e56e0aac49b310cc1e00aafe3ffeddb90eca6e38-0-f3-1-8123`; 8147 `43769025429-e56e0aac49b310cc1e00aafe3ffeddb90eca6e38-1-f3-2-8147`; 8161 `43769025429-e56e0aac49b310cc1e00aafe3ffeddb90eca6e38-1-f3-3-8161`.
- Reference context: [DRIV3R #570](https://github.com/techrote/cybersand/issues/570), native Q8 contract [#611](https://github.com/techrote/cybersand/pull/611), learned WORM [#612](https://github.com/techrote/cybersand/issues/612). **No native 36-turn examples used for training.** Those are visual out-of-distribution examples, not directly comparable W0 reward targets.

## What was trained and why it is NOT yet human preference learning

Each PNG was downsampled to its **original 96×96 4×4-block centres**. Pixel colours (background `(14,19,29)`, obstacle `(78,81,96)`) were excluded. Ten numeric geometry features were derived from the resulting painted cells: material count, horizontal/vertical span, 4-neighbour edges, junctions, cycles (E−V+components), endpoints, obstacle adjacency, diagonal adjacency and western-half occupancy. The `components` column remains an audit feature. Image colours are presentation pixels, **not verified native material readbacks**.

48 within-world controller pairs were made for each of **two explicit, conflicting algorithmic weak-supervision axes**:
- `spatial_extent`: saturated occupied-cell count plus two-dimensional bounding-box extent.
- `local_weave`: 4-neighbour cycle density, junction density and compact filled footprint. Importantly, loops/revisits are **not blanket defects**.

The 96 labels **are not owner votes, aesthetic ratings or genuinely learned quality signals**. They are programmatically computed *proxy targets*; two separate standard-library Adam-trained logistic heads approximate them. The four-fold test holds out entire source worlds, not individual pair rows. Neither axis is promoted as the single definition of a good worm.

| Local CPU pilot (one run, exact CSV) | Extent proxy | Weave proxy |
|---|---:|---:|
| Training pairs | 48 | 48 |
| Held-out matched-world agreement | 45/48 = **93.75%** | 46/48 = **95.83%** |
| Held-out mean Brier | 0.0574 | 0.0255 |
| Full-fit agreement | 47/48 | 48/48 |
| Cells-only trivial comparator | 37/48 | 30/48 |
| x-span-only comparator | 34/48 | 15/48 |

**Important original behaviour finding:** the two proxy rules disagree on **27/48** matched controller pairs. The learned worms outrank matched controls in **0/24** pairs for extent, but **12/24** for local weave. The wall controller usually dominates local density. This does **not** establish owner preference, nor is W0 128-turn host-STOP-constrained inference equivalent to native Godot 128 turns. Future genuine blind human comparisons may prefer any of these constructions.

## Reproduction / boundaries

```bash
python3 -m unittest discover -s experiments/driv3r/training/preference_eval -p 'test_*.py' -v
python3 experiments/driv3r/training/preference_eval/rank.py --output-dir /tmp/driv3r-pref-P0
```

Pure Python 3 standard library, no network, no model downloads, deterministic 450-epoch Adam per head, four-heldout-world tests, SHA-fenced input, per-pair records, local JSON heads and metrics. **No checkpoints committed to Git.** The first CPU outputs were produced locally and are not independently GitHub Actions-qualified or immutable Actions artifacts; promotion is blocked until the approved code is run in an isolated Actions workflow with its output archives retained.

**Confounds / follow-up:** only eight worlds; all W0 controls inherit their producers' world/host interventions; W13 STOP censored; the observed images alone cannot reveal real action-level intent, dynamic recovery, obstacle legality, original checkpoint bytes or feedback sensitivity. Next independent experiment should reuse immutable original turn-level World/action receipts to construct *matched first-divergence recovery pairs* with STOP available, then collect blinded owner/human comparisons separately from proxy scores. Do not drive reward optimisation of d1 from these crude proxy heads. No new issue, no automatic dispatch, no merge.
