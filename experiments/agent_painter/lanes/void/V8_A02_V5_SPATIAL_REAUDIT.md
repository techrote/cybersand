# VOID A02 v5 — prospective original-native spatial proximity re-audit

**Status: source added, hosted evidence pending.** Read-only follow-up to the independently qualified [v4 native/public spatial comparison](V4_A02_PEER_PUBLIC_SPATIAL_REVIEW.md) and [v5 native material review](V5_A02_NATIVE_INDEPENDENT_REVIEW.md).

## Why this check is needed

The original v4 A02 spatial review used the **524-cell** native mask before floor-anchored support revisions. The nominated A02 **v5** added 138 cells, bringing its native occupancy to **662**. The original same-coordinate v4 IoU numbers do **not** automatically establish v5's spatial proximity to held-out DEVELOPMENT. A separate lane's reviewer also showed that graph-degree/signature novelty can conceal a near-alias in actual image space. This check makes that change observable without altering A02's teaching prompt, geometry, training status or any source artifact.

## Pinned immutable inputs and what is computed

The workflow independently downloads original GitHub-hosted v4 [run #43592303518](https://github.com/techrote/cybersand/actions/runs/43592303518) artifact 14113396057, v5 [run #43601866007](https://github.com/techrote/cybersand/actions/runs/43601866007) artifact 14116463694 and original source633 [run #43506373969](https://github.com/techrote/cybersand/actions/runs/43506373969) artifact 14076703326. It verifies all whole ZIP SHA-256 values; all native ZIP CRCs; the original source633 corpus manifest and TRAIN/DEVELOPMENT split hashes; the v5 source/native gates, raw 96×96 little-endian material mask and original two identical host-seed views. For source633, **only explicitly selected TRAIN and DEVELOPMENT Architecture rows and material arrays** are decompressed. It never walks or opens FINAL targets, images or receipts.

For each of the four visible original Architecture structural groups (two TRAIN, two DEVELOPMENT), it compares **v4 and v5** on (i) same-coordinate occupied-cell intersection-over-union and (ii) fraction of A02 material cells lying within a Chebyshev radius of 3 native pixels of a neighbour's occupied cells. These are conservative *spatial descriptors*, not independent topological, playability or visual-quality gates. Near-3 fractions can be elevated merely because solid walls are nearby, and both metrics depend on the original coordinate alignment. They are neither translation-invariant nor semantic duplicates.

The script refuses missing original source/model evidence, unexpected new material IDs, differing v5 native seeds, a change other than the exact 138-cell superset revision, malformed structural grouping or an unknown/FINAL split. It emits **no model inference, generated paintings, optimizer steps, native reruns or shared TRAIN admissions**.

## Decision boundary

The prospective output is **review evidence for the shepherd and independent reviewer**, not permission to make A02 a TRAIN group. Compare *both* numerical descriptors with the original native images, especially DEVELOPMENT's stacked-room/shaft motif. If similarity is concerning, request explicit independent review of the visual structure; do not alter the original DEVELOPMENT or retrofit an approval. Keep A02 v5 nomination **REVIEW_ONLY/HOLD**, PR #574 Draft/HOLD and its model candidate unfrozen.

Run the source-only workflow `agent-painter-void-v5-spatial.yml` and record exact-head run, original artifact identities and metrics in issue #568 **only after a real completed hosted run**. Do not claim a PASS from the existence of this document or workflow.
