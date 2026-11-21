# B2-REGION-002 — source-locked O(N) scan-floor falsifier (9 Nov 2026)

**Disposition: HOLD on any *total-cost* extrapolation from B2-REGION-001.** This is a bounded structural accounting experiment, not a new native benchmark, a refutation of the fixed-point theorem, or a claim about CyberSand runtime speed. No production sources or physics were edited.

## Pre-registered falsifier and source identity

Question: does the B2-REGION-001 Python reference actually eliminate full-grid work on a fully certified quiescent grid, or does its accounting exclude mandatory full-grid traversals? A falsifying witness is **any unconditional full-grid copy or difference scan in every cached tick**, even when all tiles are certified and zero rule calls execute. If all of these traversals are absent, the proposed scan-floor counterexample fails.

Exact accepted CyberSand main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
Source of the *reviewed model*: Draft #556 head `fe3c5312c60bc751d38ab5c00a34ac096027a56b` before this evidence-only increment. Git blob identities:

- `model.py`: `30606f77cf353bf552383f224a80afe880da92a5`
- `evidence.json`: `6333dc07c07dcec15db12ab3f077e3a188727b06`

The fixed dataset is a **24 × 16** grid (384 cells), 4 × 4 tiles, 64 ticks; both 1- and 4-*logical*-shard outputs are retained. It is not a physical multiworker profile. Script: `python3 research/solver-certificates/invalidation/scan_floor.py`. The script refuses to reuse totals for changed blobs, checks source syntax structure, checks historical per-profile arithmetic and has a mutation-negative selftest (`--selftest`). It is not a runtime profiler.

## Exact static-source result

On every call to `Cached.step`, irrespective of certification, the published source executes:

1. `old = s.copy()`: `State.copy` copies the **entire 384-cell list** into a pre-step snapshot.
2. `output = old.cells.copy()`: a **second entire 384-cell list** is copied before any certified-tile test.
3. `changed = {i for i, (a,b) in enumerate(zip(old.cells, output)) if a != b}`: a **384-position difference comparison** after the region loop, even when no cells changed.

The full reference `full_step` also copies the pre-step state, so **the first traversal is shared with the reference**. The second copy and final comparison are incremental-path operations omitted from the published `abstract_work_units` metric. Output materialisation exists in both algorithms, so traversals are **not equal-time units** and should not be turned into a wall-clock ratio.

| Profile | Full rule calls | Incremental rule calls | Published abstract work units | Unconditional cached list-copy positions (two copies) | Cached difference comparisons |
|---|---:|---:|---:|---:|---:|
| Quiet | 24,576 | 0 | 1,536 | 49,152 | 24,576 |
| Mixed | 24,576 | 7,584 | 16,941 | 49,152 | 24,576 |
| Dense | 24,576 | 7,712 | 17,208 | 49,152 | 24,576 |
| UNKNOWN every tick | 24,576 | 24,576 | 41,174 | 49,152 | 24,576 |

These counts are invariant across the two logical partition orders. There are **73,728 unavoidable cached full-grid cell-position traversals** across each 64-tick profile, before counting rule evaluation, certification, halo walks, tile membership, event processing, list allocations or the offline diagnostic. Of these, 49,152 positions belong to the output-copy and changed-cell comparison not included in existing abstract work. This is a **count of operations, not CPU cycles, cache-line bytes, allocations or a CyberSand tick measurement**.

**Negative finding:** the quiet case proves 100% avoidance of `step_cell` calls, but **does not eliminate O(N) reference-model tick work**. Its historical `0.063×` equal-weight `abstract_work_units` ratio is correct *for exactly the three terms defined there*, and is **not a total-work or throughput ratio**. That limitation was already noted generally in #556; this experiment provides the specific source-backed floor.

## Verification boundary / independent review

The exact blobs and all seven structural signatures were independently read from GitHub and checked against the source on 9 Nov 2026, with the eight original evidence records arithmetically reduced. The new Python script's isolated structural/mutation selftest passed locally. **A complete checkout execution of `scan_floor.py` against the GitHub blobs, actual Python memory allocations, and a source-matched native full-tick A/B/B/A are not established**. The script is a reproducible independent follow-up, not a completed hosted gate.

**B4 challenge:** independently execute the script on this exact head; inspect whether any model traversal was missed, and reject any real-world workload-speed claim without actual native 1/4-worker, total-tick, memory/allocation and physical hash/gas/quantity evidence. Existing #470/#471/#522 stages remain accepted controls and are not replaced.

**B5 design seam:** if considering an opt-in consumer, target an **already skippable specific stage with event-driven bounded invalidation**, avoiding full-world copy/diff/proof scans when quiescent; preserve the established #201 Water-motion-only certificate contract and global pressure/actor fallback. Existing #533 gas-component candidate owns its separate research question. No generic region skip or default switch is authorised.

The bounded fixed-point theorem retains its conditional validity in its pure synchronous toy grammar. This new negative result qualifies **cost accounting only**, not proof soundness or physical semantics. Draft/HOLD; independent review requested.
