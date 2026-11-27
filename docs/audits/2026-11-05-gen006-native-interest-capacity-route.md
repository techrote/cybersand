---
title: GEN-006 actual native interest-route resident-budget refusal experiment
status: Planned
document-kind: audit
scope: Experimental real-native Generator and World synthetic interest-route qualification, no production streaming implementation
last-reviewed: 2026-11-05
related-documents: [../systems/world-storage-and-interest-region.md, ../architecture/data-ownership-and-lifetimes.md, ../reference/level-saves-and-replay.md]
---

# GEN-006 #194 — synthetic camera-interest saturation, real native World

**Experimental only; retain Draft #426, no merge or Ready transition.** Baseline accepted main on 2026-11-05: commit `ba9cbc89029be88b812af59b19e5c59829bbcd90`, tree `3af18f50e6094776263119623b64a1b2f4ca0ab2`. Source-intake branch #426 at `d7f33dabe41533fa9840b9070c94c68eccdbf546` (tree `23d2f69a8d3d25a46fb52996755d95c57b06106a`). Exact committed experiment SHA/tree and host runtime must be read from hosted workflow artifacts, not inferred from this design document. #426 remains a single GEN-owned experimental branch with no production changes.

## Distinct question and predeclared test

The earlier #426 session-fence test proves that stale generator results can be refused by an external owner after a World reset; #442 proves a separate cross-chunk semantic partial-commit boundary; #422 exercises whole-World CYPS continuation; #435 inventories selective-state and actor pin loss; #415 models disk ACK and snapshot-lease faults. None measures a multi-position **native demand route that saturates the resident World budget**. This addition targets a missing streaming prerequisite without creating another GEN experiment PR.

Use the real compiled `cybersand::generation::Generator`, `World::install_generated_chunk` and phased World. The test-only driver supplies interest rectangles for five requested chunks: `(-9,0),(-1,0),(0,0),(9,0),(10,0)`; world x origin `-1152,-128,0,1152,1280` crosses the signed origin and both sides of a 1024-wide finite adapter. The immutable recipe produces static Wall across the finite route to keep the continuation control stable. One native World has `maximum_chunk_count=3`; neither the user interface nor a real camera calls this harness.

1. First three genuinely generated receipts must validate and install into absent native chunks. The next two should refuse with `CapacityFull`, leaving resident counts and physical-state hash unchanged.
2. Moving the external synthetic interest request does **not** itself evict any chunk. A native `Glass` replacement edit in the far-west resident must persist; replaying its old generated payload must refuse as `AlreadyResident`, not silently regenerate.
3. Construct a separate reference World with only the first three successfully admitted payloads and identical mutation. Run three native ticks with synthetic interest at the unresident far-east request, the far-west resident and the origin. Compare completed tick, complete physical-state hash and quantity ledger after each tick.
4. Repeat for configured worker counts 1 and 4; report **actual observed** pool participation and do not infer concurrency from configuration. Admit no new mutation, solver or save format.
5. Report synchronous maximum generated-proposal occupancy (one), generator charged logical operations, native resident budget and admission refusals. This is not a measured complete memory peak, real camera path latency or asynchronous queue bound.

**Expected limitation, not a production defect:** A valid next area is refused indefinitely once the three-resident native budget is exhausted, because there is no approved selective eviction + dirty-state ACK/restore owner transaction. It must not be reclassified as silently successful streaming. A host cannot solve this by raising a budget without bounds or regenerating mutated residents.

## Execution and provenance

Branch-only `.github/workflows/gen006-native-demand-fence.yml` compiles unchanged accepted native World/generator sources with GCC 13 on Ubuntu 24.04, links `native/tests/test_gen006_interest_budget.cpp`, then records original stdout/stderr, compiler, commit/tree, CI provider and build logs as a retained artifact even on failure. Execute:

```sh
build/gen006-demand-fence/interest_budget
```

The suite is intentionally a genuine native *Linux* test; no Windows, Godot, player/actor, pressure/inertial sidecar, real eviction/reload, process restart, persistent mutation log or four-worker participation is asserted without a corresponding observed result. Any failed first attempt stays failed. Full Native, GDExtension/Godot and materialized provenance remain independent admission gates and may be skipped under Draft.

## Ownership and next decision

Only this test, branch-only workflow and audit are touched. Other GEN-006 PRs #415/#422/#435/#442, pending MAT-003PREPASS design #230, issue #398's unsupported historical CYPS import, SOL, PLAY, MAT and Water owner files remain untouched. GEN-003/004/005/007 (#190–193) are closed; #204, #194 and material authority #352–354 are not complete GEN-006 runtime admission.

**Next highest-value gate:** design and admit the smallest exclusive-owner **dirty-save ACK / pin-aware eviction / exact-session restore** contract, with an explicit opt-out for unsupported sidecars and actor pins. Then implement one real native two-region round trip under a budget of three; require a retained mutation and continued native tick comparison. Do not select a codec or schema from #230 by implication; do not merge diagnostic #426 or close #194. Record progress and stop.

## Retained first-run failure and narrow correction

The original hosted [run 42062629979](https://github.com/techrote/cybersand/actions/runs/42062629979), source `921705bf6a48876ad91dfa875b8932d79e8aa809` (tree `61b1256f5cd4cab2a5bcbcdf0b8cca3fc97d40b1`), **FAILED in compilation**, not simulation. The test supplied a bare braced initializer to `set_simulation_region(std::optional<RectI64>)`, which GCC 13.3 correctly rejected at line 78. Original failing job log and [artifact 13432483256](https://github.com/techrote/cybersand/actions/runs/42062629979/artifacts/13432483256) remain intact. This subsequent fixture-only edit constructs `RectI64` explicitly and mirrors the last interest selection in the control World to avoid a false hash comparison; the production World/generator source, scenario, assertions and existing two tests are unchanged. Only a later exact-head hosted run may establish successful execution.
