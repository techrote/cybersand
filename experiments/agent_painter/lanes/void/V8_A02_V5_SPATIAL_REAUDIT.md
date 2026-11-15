# VOID A02 v5 — prospective original-native spatial proximity re-audit

**Status: exact-source GitHub-hosted read-only audit PASS (15 November 2026), global split admission HOLD.** Read-only follow-up to the independently qualified [v4 native/public spatial comparison](V4_A02_PEER_PUBLIC_SPATIAL_REVIEW.md) and [v5 native material review](V5_A02_NATIVE_INDEPENDENT_REVIEW.md).

## Why this check is needed

The original v4 A02 spatial review used the **524-cell** native mask before floor-anchored support revisions. The nominated A02 **v5** added 138 cells, bringing its native occupancy to **662**. The original same-coordinate v4 IoU numbers do **not** automatically establish v5's spatial proximity to held-out DEVELOPMENT. A separate lane's reviewer also showed that graph-degree/signature novelty can conceal a near-alias in actual image space. This check makes that change observable without altering A02's teaching prompt, geometry, training status or any source artifact.

## Pinned immutable inputs and what is computed

The workflow independently downloads original GitHub-hosted v4 [run #43592303518](https://github.com/techrote/cybersand/actions/runs/43592303518) artifact 14113396057, v5 [run #43601866007](https://github.com/techrote/cybersand/actions/runs/43601866007) artifact 14116463694 and original source633 [run #43506373969](https://github.com/techrote/cybersand/actions/runs/43506373969) artifact 14076703326. It verifies all whole ZIP SHA-256 values; all native ZIP CRCs; the original source633 corpus manifest and TRAIN/DEVELOPMENT split hashes; the v5 source/native gates, raw 96×96 little-endian material mask and original two identical host-seed views. For source633, **only explicitly selected TRAIN and DEVELOPMENT Architecture rows and material arrays** are decompressed. It never walks or opens FINAL targets, images or receipts.

For each of the four visible original Architecture structural groups (two TRAIN, two DEVELOPMENT), it compares **v4 and v5** on (i) same-coordinate occupied-cell intersection-over-union and (ii) fraction of A02 material cells lying within a Chebyshev radius of 3 native pixels of a neighbour's occupied cells. These are conservative *spatial descriptors*, not independent topological, playability or visual-quality gates. Near-3 fractions can be elevated merely because solid walls are nearby, and both metrics depend on the original coordinate alignment. They are neither translation-invariant nor semantic duplicates.

The script refuses missing original source/model evidence, unexpected new material IDs, differing v5 native seeds, a change other than the exact 138-cell superset revision, malformed structural grouping or an unknown/FINAL split. It emits **no model inference, generated paintings, optimizer steps, native reruns or shared TRAIN admissions**.

## Decision boundary

The prospective output is **review evidence for the shepherd and independent reviewer**, not permission to make A02 a TRAIN group. Compare *both* numerical descriptors with the original native images, especially DEVELOPMENT's stacked-room/shaft motif. If similarity is concerning, request explicit independent review of the visual structure; do not alter the original DEVELOPMENT or retrofit an approval. Keep A02 v5 nomination **REVIEW_ONLY/HOLD**, PR #574 Draft/HOLD and its model candidate unfrozen.

Run the source-only workflow `agent-painter-void-v5-spatial.yml` and record exact-head run, original artifact identities and metrics in issue #568 **only after a real completed hosted run**. Do not claim a PASS from the existence of this document or workflow.

## Executed V8 qualification — 15 November 2026

- **First attempt:** [run #43659680294](https://github.com/techrote/cybersand/actions/runs/43659680294) at `385f7e9dac6390ecedc18deb3f355bdc12590171` **FAILED** before original artifact download: 9/10 tests passed. One synthetic assertion incorrectly expected v5's 138-cell occupancy superset to *always increase* intersection-over-union. A superset can instead lower IoU when the peer overlaps only existing v4 cells. Do not erase this failed receipt.
- **Narrow repair:** `072f5f638e39e64d842e181c85dab4c0df218650` changes only `test_a02_v5_spatial_comparison.py`; it tests **both non-monotonic cases**, retains the exact 138-added/no-removal proof and does not change the evaluator, compiler, original data or native receipt contracts.
- **Real hosted execution:** [run #43664110047](https://github.com/techrote/cybersand/actions/runs/43664110047), [job #132659593521](https://github.com/techrote/cybersand/actions/runs/43664110047/job/132659593521) **COMPLETED SUCCESS**; `python -m py_compile`, provider/scheduling policy, **10/10 adversarial regressions**, three original public ZIP downloads and original-identity/visible-split comparison succeeded. Original v4/v5 masks are **524/662** material cells, exactly **+138/-0**; two v5 host seeds form **one composition**. No FINAL targets opened.
- **Output artifact:** [#14141596158](https://github.com/techrote/cybersand/actions/runs/43664110047/artifacts/14141596158), GitHub-published and independently redownloaded ZIP SHA-256 `f3954338f0fc17e4121a3160cdb809a7513133252ac707b76246e56fffaa6ad5`, **1/1 CRC PASS**, original `result.json` SHA-256 `e8034b88e44b493af7845b55b16ebf563448ceb2916b6f585c69c5afa5611a5a`. No new optimizer steps, native executions, model-generated paintings or shared TRAIN admission.

| Visible original Architecture group | v4 IoU | v5 IoU | v4 near-3 | v5 near-3 |
| --- | ---: | ---: | ---: | ---: |
| TRAIN paired-doorway rooms | 0.014184 | 0.019078 | 0.225191 | 0.208459 |
| TRAIN stair/landing hall | 0.049751 | 0.084323 | 0.467557 | 0.480363 |
| DEVELOPMENT stacked rooms/shaft | 0.010324 | 0.016173 | 0.450382 | 0.407855 |
| DEVELOPMENT bridge/towers | 0.054645 | 0.076136 | 0.599237 | **0.679758** |

**Original-PNG inspection:** I independently redownloaded original A02 v4/v5 and source633 native PNGs (whole-archive hashes matched the pinned values above), and visually inspected A02 alongside the four visible TRAIN/DEVELOPMENT Architecture compositions, without opening FINAL. A02 v5 is a tall open-topped shaft containing two floor-anchored narrow interior supports, unlike the held-out bridge's wider three-pier, elevated bridge composition; however, both contain vertical support strokes, and the held-out bridge's increased **67.98%** near-3 is a material caution requiring independent structural/split review. A02's support side slots remain **non-traversable**; centre geometric clearance is not a gravity/jump/climb playability claim. The two seed images are not independent architectures.

**Disposition:** SOURCE/ORIGINAL EVIDENCE PASS; **GLOBAL TRAIN ADMISSION HOLD**. The shepherd and independent reviewer own the global cross-lane allocation. The spatial descriptors and this worker's visual inspection do not themselves grant TRAIN admission. Maintain sole VOID Draft PR #574; do not train on A02 or unfreeze FINAL.
