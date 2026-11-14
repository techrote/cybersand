# DRIV3R D-2: procedural discovery (independent, offline)

This lane is a **synthetic-only preparation** for CyberSand [#570](https://github.com/techrote/cybersand/issues/570#issuecomment-6877408001). It must not write native World cells, emulate a native receipt, run a resident model, request paid resources, or claim production results. All changes are confined to \`experiments/driv3r/stage_d/procedural/**\`. [D-COMMON-001 #594](https://github.com/techrote/cybersand/pull/594) is a **candidate**, not an owner-accepted freeze (last checked: candidate commit \`8fa90de6be209ed0b7bd125039e6ec8b332fb1a6\`, schema SHA-256 \`ebe2fa211148602c614cba0f0a40f285cba797784b70efa035832d833877f80d\`).

## Research families

| Family | Original geometry | Routine algorithm | Recovery hypothesis | Material effect |
| --- | --- | --- | --- | --- |
| Weathering Worm | Frozen, filled Minkowski/n-flake polygon; **do not chase the newly eroded edge** | Original-perimeter-biased connected walker; branch-frontier selection | Brush-up backtrack or relocation to retained original-rock frontier | Persistent **erase** |
| Branching Growth | H-tree / branching skeleton and authorized volume | Raster-tree traversal from a fixed root with branch-frontier bookkeeping | Retraction to cursor-history ancestor versus logical branch relocation | Persistent **add**, compare contained vs bounded overshoot |
| Guided Coverage | Full Hilbert, closed Moore, and serpentine curves (not Stage B's \`HILBERT_MOTIF\`) | Incremental curve cursor, explicit visited center/footprint and next-segment inspection | Low/high scalar hysteresis, seek a *future unvisited four-step segment*, pause or record trap | Persistent **add** |

**Reversal semantics are not interchangeable.** \`BACKTRACK_CURSOR\` follows a previously traversed cursor chain with brush lifted; \`RELOCATE_TO_BRANCH\` is a discontinuous controller relocation with brush lifted (not a physical stroke or proof of transport). Neither changes native material. \`UNDO_MATERIAL_EDIT\` is **unavailable in the offline simulator**: only a future integration owner may issue a host-authorized native-history operation with source-fenced receipt, full original material hash/readback and bounds/partial-prefix safety.

## Records and custody

Keep an immutable, versioned **recipe** (generator, seed, World dimensions, permitted effect, curve/walker, guidance, thresholds, brush, recovery, budget), the original generated geometry and scalar guidance, candidate IDs and full offered catalogs, selected actions, exact visited/swept footprints, trajectory, failures and terminal reason. Save original before/midpoint/after **synthetic material-raster PNGs**, never call them framebuffer screenshots. Source and input digests, artifact SHA-256/byte lengths and a replay verifier must travel with every episode. Every absent native/model identity is explicitly \`null\` and \`native_replay_verified=false\`. Do not promote this exploratory corpus as native painter examples or training labels.

Metrics should be based on **actual executed synthetic changes**, not estimated tool plans: before/after material delta, connected traversal, branch coverage, retraces, original-boundary offset, retained negative space, trapped recoveries, viable reentries, uninterrupted steps per intervention, and total failures. Compare identical initial geometry, guidance, seed, budget and legal host candidate set; after first consequential divergence each arm is independently re-observed. Save failed/ugly trajectories rather than filtering them.

## Local preparation

Run the standalone Python module with stdlib only: \`python3 experiments/driv3r/stage_d/procedural/lab.py --out /tmp/driv3r-d2\`; test with \`python3 -m unittest discover -s experiments/driv3r/stage_d/procedural -p 'test_*.py' -v\`. This is a small **development** cohort, not held-out confirmation. Generated images/results belong in temporary artifact storage, not committed to Git history.

**Workflow preparation only:** \`ci/experiment-matrix.yml.disabled\` is a deliberately inert template under this lane. A future integration owner may, after *explicit budget, source and dispatch authorization*, review and migrate it into \`.github/workflows/\`; this lane does not create a runnable workflow or dispatch anything.

## Future integration/approval gates

1. Explicit M1 owner acceptance of exact D-COMMON source commit + schema hash, then source-qualified compatibility adaptation by the shared integration owner. Offline recipes are independent until then.
2. Host-owned World permissions, swept cells, Stop/timeout/cancellation, observation fence, readback, undo receipt and independent native replay qualification. No fake \`native\` field is permitted.
3. Opt-in 2/4/8-runner throughput measurement before considering a paired 4 steering × 3 seeds × 2 recovery = **24 episodes** model/native cohort. Two-tier screening on 8–12 identical saved observations, with raw distributions, option orders/paraphrases, latency, explicit information ablations and structurally distinct held-out confirmation.
4. Separate authorization for every native/model/GPU/API/training dispatch. Draft/HOLD, no merge, Ready or production-default changes.
