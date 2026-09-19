---
title: Issue 12 Stage 3 exit review, 2026-09-19
status: Current
document-kind: evidence
scope: Parent-owned admission review for read-only World settled-region discovery; no stationary acceleration or ownership transfer
canonical-for: []
last-reviewed: 2026-09-19
related-documents: [../../operations/soliding-stage3-freeze.md, ../../operations/soliding-programme.md, ../../operations/soliding-measurement.md, ../../systems/settled-region-discovery.md, stage3-cost-results.md, producer-hook-review.md]
---

# Issue 12 Stage 3 exit review

## Decision and exact boundary

**Parent decision: the integrated candidate passes the frozen Stage-3 technical
exit gate.** The admitted implementation/evidence lineage is PR #43 head
`90903355f5880e8f141ee6caea34840ad8b4990c` merged as `1bb2d9d`, PR #46 merged
as `5001f7f`, and the integration commits `64413f7` through `c35c8d1` on
`codex/issue-12-stage3-integration`. The last measured runtime source is
`2919106d9a8b3b91bab442fbb0e34bdee1b35afc`; `933ad5a` adds the retained cost
record and an exact-under-occupancy regression, and `c35c8d1` adds direct Water
transfer endpoint evidence without changing runtime source.

This decision admits only opt-in, read-only observation. It does not admit a
scheduler skip, stationary proxy, compact/frozen representation, cohesion,
material ownership transfer, Rapier body, fracture behavior or performance win.
Repository integration remains subject to the exact pull-request head passing its
required checks. Stage 4 must start from the merged exact candidate, preserve
Current ordinary sleep as a real measured arm and preregister alternatives before
choosing any threshold.

The requested independent stronger verifier was started only after an explicit
`gpt-6-astra` selection, but the worker could not observe or attest that exact
runtime model identity. It stopped before reading files or performing review.
No conclusion from it is used here. Earlier Luna drafts were rejected and retained
for audit at `64413f7`; no Luna code or conclusion was admitted by test success.
This review, source reconciliation, evidence interpretation and admission decision
were performed by the supervising parent.

## Frozen checklist disposition

The rows below preserve the order and meaning of the authoritative
[Stage-3 freeze](../../operations/soliding-stage3-freeze.md#stage-3-exit-checklist).
`PASS` means the claimed property has source plus focused evidence. A safe refusal
is identified where the contract permits unusable/unknown coverage instead of a
false complete result.

| # | Result | Frozen item and concrete evidence |
|---:|---|---|
| 1 | PASS | **PR #43 foundation/reconciliation.** Its exact final head and required checks were independently inspected before merge; the merge landed at `1bb2d9d`. PR #23 remains a separate Phase-0 control. PR #46's architecture/freeze packet was reconciled and merged at `5001f7f`; no historical evidence hashes were rewritten. |
| 2 | PASS | **Complete World producer matrix.** The centralized owner-side hooks in [`world.cpp`](../../../native/src/world.cpp) cover direct tuple/temperature writes, both movement endpoints, Water transfer, reaction/state-progress writes, post-barrier `JobEffects`, activity/deadline metadata, masks, pending events, inclusion, chunk/reservation registration, live policy fences, clear/move and failure. [`producer-hook-review.md`](producer-hook-review.md) remains the source-to-hook matrix. Unrepresentable tile registration sets capacity-blocked and globally quarantines connected-region consumption instead of pretending coverage is complete. |
| 3 | PASS | **Workers never mutate shared discovery.** Worker kernels record bounded `JobEffects`; only serialized `merge_job_effects` calls `dirty_discovery_rect` after each deterministic barrier. Discovery service and publication run through the World owner. Source review found no coordinator/journal mutation from worker helpers. |
| 4 | PASS | **Direct ABA/render independence.** `direct_aba_exact_tuple_and_render_independence` performs state-only, hot-Empty and material change/restore, consumes render dirty state between mutations, requires two independent revision advances and accepts only a complete fresh exact scan. |
| 5 | PASS | **Worker writes/barriers/workers1/4.** `disabled_neutrality_and_worker_parity` drives moving Water/Sand/heat under workers 1 and 4 and compares authoritative hashes, canonical tile registration, revisions, classifications and signals. `integrated_region_worker_parity` also compares normalized region keys, geometry, areas, counts and both deterministic digests. |
| 6 | PASS | **No-write activity/deadlines.** `no_write_activity_deadline_and_epoch_wrap` reaches a deterministic keep-active/no-content-change lane and a sleeping Mercury exchange deadline; both remain uninspectable. |
| 7 | PASS | **Mask ABA/locality.** `movement_mask_event_and_far_locality` checks add, clear and empty reconfiguration revisions while an unrelated far tile retains its revision. `occupancy_preserves_exact_underlying_tuple` proves blocking/removal does not replace the cell-owned tuple. |
| 8 | PASS | **Pending events before execution.** The same test accepts a deferred explosion, observes the affected tile as pending and invalid before the tick, then permits the signal to clear only after owner-side drain. Overflow/endpoint mapping failure calls the discovery failure path rather than changing event acceptance semantics. |
| 9 | PASS | **Inclusion/exclusion/re-entry.** `inclusion_reset_move_and_failure_quarantine` proves requested exclusion immediately fences the old result, requested re-entry cannot reuse prior quiet age and applied re-entry requires a fresh complete scan. |
| 10 | PASS | **Chunk/reservation/capacity isolation.** `canonical_geometry_registration_and_capacity` reserves two authoritative chunks into one observer slot, retains both chunks, exposes no stale tile and sets `TileCapacity` with zero regions. `integrated_new_tile_registration_retires_facing_region` covers later resident coverage. |
| 11 | PASS | **Clear/move/replacement/failure.** `inclusion_reset_move_and_failure_quarantine` proves move transfers one incarnation, moved-from World has no observer, clear creates a new incarnation, and a capacity failure after partial World work immediately halts journal and region consumption. |
| 12 | PASS | **Epoch wrap is not mutation.** After 260 ticks, the exact tile revision in `no_write_activity_deadline_and_epoch_wrap` is unchanged across epoch-byte maintenance. The cost harness reports ordinary and epoch-clear ticks separately. |
| 13 | PASS | **Canonical/custom bounded subtiles.** `canonical_geometry_registration_and_capacity` proves 64x64 activity coverage becomes four 32x32 tiles. `custom_geometry_signed_endpoints_and_policy_fence` covers 10/6/8 geometry, partial negative edges and both signed endpoints. Oversize/invalid bounds and tile-capacity refusal are covered by [`test_settled_discovery.cpp`](../../../native/tests/test_settled_discovery.cpp). |
| 14 | PASS | **Exact stored tuple beneath occupancy.** `occupancy_preserves_exact_underlying_tuple` records Wall `{state_a=17,state_b=3,temperature=222}`, blocks it with occupancy, clears the mask and requires the identical tuple after a fresh scan. Sampling uses stored material/state/temperature plus a separate occupancy bit, never masked public accessors. |
| 15 | PASS | **Local holes/seams/keys/no truncation.** `single_tile_holes_and_exact_keys`, `exact_key_seams_and_local_shapes` and `bounded_capacity_never_publishes_a_prefix` in [`test_settled_regions.cpp`](../../../native/tests/test_settled_regions.cpp) cover canonical holes, exact material/state/temperature keys, non-filled shapes and component/frontier refusal without prefix publication. Noncanonical Empty is explicitly refused in the integrated World test. |
| 16 | PASS | **Cross-tile face connectivity and coordinates.** `cross_tile_seams_and_unknown_boundary`, `negative_seams_diagonals_and_partial_work`, `multi_tile_ring_and_many_tile_solid` and the integrated two-tile World fixture cover activity/chunk faces, negative coordinates, rings/holes and multi-tile solids. |
| 17 | PASS | **Diagonal versus face neck.** `negative_seams_diagonals_and_partial_work` keeps diagonal-only cells separate; face ports join only exact keys. These are observation components only: there is no support, strength or cohesion inference in the API. |
| 18 | PASS | **Old-region and facing-neighbor invalidation.** `bridge_and_split_retire_old_handles`, `unknown_registration_retires_faces_without_consuming_payload`, `unknown_middle_component_capacity_and_new_match`, and both integrated split/new-tile tests prove immediate old-handle retirement even when a changed/unknown neighbor may create a new bridge. |
| 19 | PASS | **Bounded resumable complete-only traversal.** Work-budget tests prove start/read/finalize accounting, partial-work invisibility and revision restart. Region tests exercise partial frontier progress, mutation during canonical seed seek, remote progress under churn and zero quiescent work. Publication requires every dependency revision still to match. |
| 20 | PASS | **Identity/generation/split/merge/capacity/determinism.** Split/merge tests reject old handles, publish new generations and preserve exact area. Insertion-order tests and workers1/4 normalized digests prove canonical results. Region/component/frontier/slot capacities return explicit refusal and never mutate source cells. |
| 21 | PASS | **Unknown/blocked/capacity boundaries.** `unknown_middle_component_capacity_and_new_match`, integrated mask/noncanonical-Empty tests and producer tile saturation all prevent false globally complete regions. Refusal remains visible as `UnknownBoundary`, `NoncanonicalEmpty`, `ComponentCapacity`, `FrontierCapacity`, `RegionCapacity`, `TileCapacity` or `SourceFailure`. |
| 22 | PASS | **Disabled neutrality/counters.** `disabled_neutrality_and_worker_parity` compares enabled/disabled World visited cells, moved cells and content hash for 24 ticks. The 276-process campaign also requires identical authoritative hashes across Current/producer/journal/connectivity cohorts. |
| 23 | PASS | **Workers1/4 deterministic state and discovery.** Focused World tests compare tile witnesses and normalized region digests; all measured workers1/4 cohorts match authoritative content hashes. Region digest intentionally excludes world incarnation while handles retain it. |
| 24 | PASS with platform limit | **Sanitizers/failure paths.** All four Stage-3 focused suites passed under ASan/UBSan with the pinned Clang toolchain, including the final occupancy and Water endpoint regressions. Failure-after-partial-work, source throw, producer failure, revision exhaustion, capacity refusal and mutation-during-traversal paths pass. TSan is not feasible for the pinned `x86_64-w64-windows-gnu` target: Clang 23.1.0 reports `unsupported option '-fsanitize=thread'`; this is retained as an explicit platform gap, not relabeled as a pass. Workers1/4 parity and deterministic barrier ownership provide the available concurrency evidence. |
| 25 | PASS | **Whole-system cost.** [`stage3-cost-results.md`](stage3-cost-results.md) retains 276/276 preregistered sequential processes with separate Current, producer, journal/feed and connectivity timing, peak RSS, setup, ordinary/epoch-clear and complete-service p95. Current discovery fields are JSON `null`, never fabricated zero. |
| 26 | PASS | **Large-world/churn/fanout/wake amplification.** The same evidence covers 512/1024/2048 quiet worlds, 2048 sparse edit, bridge, churn, mask, event, exclusion/re-entry, granular controls and a translated negative ring. It retains the 39.3 ms 2048 sparse-edit complete p95, 1,351,685 connectivity work units, publication/invalidation counts, refusals, fixed storage and setup costs. Whole-region rediscovery is accepted as bounded Stage-3 cost, not local scaling or a win. |
| 27 | PASS | **No Stage-4/Rapier claim.** Public Stage-3 interfaces expose immutable observations and metrics only. Cells remain authoritative; no scheduler skip, body creation, ownership transfer, cohesion or fracture code is introduced. The measured result explicitly rejects a zero-cost or speedup interpretation. |
| 28 | PASS subject to exact-head CI | **Docs/evidence/retrieval/identity synchronization.** The canonical discovery page links the corrected cost record; the programme, roadmap, handover and documentation index link this exit review and identify Stage 4 as next only after exact-head CI/merge. Raw local outputs remain uncommitted under the dated validation directory with compiler/executable/plan/result hashes. Companion-aware documentation, M11 integrity, repository policy and retrieval checks are required again on the final PR head. |

## Validation retained for the candidate

- Focused ordinary tests: lifecycle, journal/local discovery, region connectivity
  and integrated World producer/connectivity all pass.
- Focused ASan/UBSan: all four suites pass; the final integrated suite includes
  direct ABA, occupancy exact tuple and direct Water-transfer endpoint witnesses.
- Full native suite: 61/61 passed after producer/connectivity integration and again
  after bounded lookup/scalability corrections; it is rerun on the final PR head.
- Registered measurement runner tests: 4/4 pass. Corrected smoke: 7/7. Corrected
  preregistered campaign: 276/276, no retry, drop, malformed record or cohort mismatch.
- Documentation and repository integrity checks are recorded on the final PR head;
  historical runtime-attestation drift for changed `world.hpp`/`world.cpp` remains
  the expected four-item source-change report and does not rewrite retained binaries.

## Negative and ambiguous evidence retained

- The first 276-process campaign at `40db9f9` undercounted complete candidate cost;
  it remains archived and is superseded, not deleted.
- Connectivity reserves 67,703,136 compiled bytes and the producer/journal reports
  3,058,080 bytes. This is a material small-world penalty.
- A 2048 sparse edit triggers bounded whole-region rediscovery and is not local-cost
  scaling. Stage 4 must measure alternatives rather than hide this result.
- All paired complete-p95 comparisons cross the programme's relative review trigger;
  tiny Current denominators are presented with absolute costs rather than a claimed win.
- TSan is unavailable for this Windows LLVM-MinGW target. No unsupported run or
  workers1/4 parity test is presented as equivalent to TSan.
- No independently model-attested stronger subagent review was available. Parent
  admission does not manufacture one; exact-head automated checks and source review
  remain mandatory before merge.

## Next dependency-ready work

After this exact Stage-3 candidate is green and merged, open an isolated Stage-4
stationary-acceleration bake-off. Preregister and compare at least Current ordinary
sleep, summary/skip metadata, a derived stationary proxy and any justified compact/
frozen or boundary-band representation. Measure producer, journal/feed, rebuild,
memory and actual saved simulation work together. Derive break-even behavior from
area, boundary activity, quiet duration and churn; do not choose thresholds by
intuition. Rapier aggregates, macro-dynamics and fracture remain later first-class
goals, not the next implementation step.
