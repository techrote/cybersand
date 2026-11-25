# B2-REGION-006 — restore geometry is a source-bound invalidation input

**10 November 2026. Status: research-only Draft / HOLD for exact-head and native qualification.**
Repository `techrote/cybersand`; accepted main `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
Pre-edit B2 Draft head `571c9626d435bd4d68fa472b770968e28f836042`;
pre-edit `sparse_fence.py` Git blob `cd512a8c5cce13aff756389ef4eb1d0575a6026e`.
Preregistered on [PR #556](https://github.com/techrote/cybersand/pull/556#issuecomment-6757400390).
Only `research/solver-certificates/invalidation/**` changed; no production source, MAT-AUTH, native World, worker, Rapier, pressure law or defaults.

## Falsifier: identical flat count, different physical topology

`Sparse.__init__` constructs `roster` and `cols` exactly once using the constructor width/height.
Before correction, `Sparse.restore` replaced the `State` but only recomputed certificate membership;
`Fence.restore` only checked type/tick and could retire pending receipts before this unchecked handoff.
This allows a *same-number-of-cells but different-grid-topology* restored state to reuse an obsolete tile-to-cell mapping.

Deterministic 16-cell counterexample, tick 0, `tile_size=2`, one or four **logical** shards:

1. Construct engine from all-Rock **4×4**. Its tile 2 roster is flat indices `(8,9,12,13)`.
2. Restore a **8×2** State of equal flat length, all Rock except Water at index 0. A two-phase proof finds every tile stable: index 8 is Rock, so Water at index 0 is blocked.
3. The complete owner barrier accepts a canonical `("set",0,1,EMPTY)` event; this edits flat index 8, immediately unblocking the downward pair. The new `tile(8)` computation returns tile **0**, but the immutable roster still owns index 8 under tile **2**.
4. Halo invalidation awakens tile 0, not tile 2. The active stage updates Water's old index 0 to Empty, but does not evaluate the newly empty destination index 8. It leaves that cell Empty.
5. A synchronous full recomputation on the restored 8×2 geometry instead moves Water into index **8**. The exact states differ at **one** cell after **one** tick. The correct value is `Water=2`; the unsafe cached value is `Empty=0`.

This is an internal research-model correctness counterexample with *complete* logical packet participation and a perfectly ordinary local `set` event. It needs no cryptographic forgery, unknown influence, hot-path side effect or native pressure assumptions. The external restoration changes the authoritative grid identity; it is **not** an alleged bug in actual CyberSand save/restore.

An independent minimal Python reconstruction of the published cell rule, tile map, two-phase check, sparse wake and original unguarded restore produced exactly the index-8 discrepancy. Its fresh-engine 8×2 control agreed with the full oracle. **The exact published full Python module and the newly authored repository test suite have not been executed in this run.**

## Correction and scoped closure lemma

`Sparse.same_geometry(snapshot)` now checks exact State type, exact positive shape identity through equal constructor-bound width/height, a concrete owned-list-shaped cell container and the total flat length. `Sparse.restore` refuses incompatible snapshots *before* swapping state or certificates. `Fence.restore` performs the identical preflight before incrementing the generation or clearing accepted packets and checks. The test `test_restore_geometry.py` includes the deliberate old-path bypass as a preserved negative control, 1/4-shard atomic refusal, malformed-length refusal, and 1/4-shard same-shape restored continuation against `full_step`.

**Conditional closure law (finite grids of arbitrary positive integral shape).** Fix a pure synchronous radius-1 operator, its two-phase proof, one construction-time `roster`, and a trusted owner who changes the state only through witnessed commits or admitted same-geometry restorations. If each restore preserves width, height and correctly shaped flat storage, every roster index and computed tile identifier continues to denote the same physical cell and tile. The existing bounded-read invalidation induction therefore remains applicable after rebuilding proofs on restoration. A shape-changing restore invalidates this coordinate identity and must be rejected or create a **new** engine with new indexing; flat cell count equality alone is insufficient. This is conventional dependence-graph identity reasoning, not a new theorem of general fluid or pressure physics.

The guard adds only fixed-count scalar comparisons at an **owner restore boundary**, plus no new per-cell tick checks, no allocation, no new physics kernel and no independent proof engine. Its actual elapsed-time cost was **not measured**. It cannot authenticate mutable state fields, source permissions or real worker payload provenance; a trusted World owner and source-revision binding remain prerequisites.

## Verification and unchanged negative evidence

| Item | Evidence / outcome |
|---|---|
| Restored 4×4 → 8×2 old-code minimal reproduction | Diverges at flat index 8 on first tick; 1/4 logical-shard loop has the same structural fault |
| Fresh 8×2 engine / full oracle control | Exact equality in the independent local reconstruction |
| New Python source guard | Authored in B2-owned `sparse_fence.py`; exact hosted module tests **not run here** |
| Regression tests | Four authored methods, including the unguarded old-path falsifier; **not yet executed on exact Git tree** |
| Skip ratio, false-positive invalidations, total cost | No new measurement; do not reuse old abstract figures as runtime acceleration |
| Existing B2 high-churn adverse result | **3.089× abstract-work regression** retained, not disproven |
| Native physical hashes and worker 1/4 actual participation | **Unavailable; not run** |
| Global gas, contact, chemistry and side-effect closure | **Unproven**; UNKNOWN ⇒ RECOMPUTE after a complete authoritative fence, incomplete ⇒ BLOCKED |

**B4 review request:** replay `test_restore_geometry.py` at the exact new head, verify the deliberate negative control really diverges, and check the four-worker receipt-retention path. Existing B4 [performance research](https://github.com/techrote/cybersand/pull/554) should remain the sole owner of real native profiling. This is not a speedup claim.

**B5 review request:** treat shape/tile-grid topology, source/epoch identity and restore generation as typed certificate assumptions. Reject or replace certificate stores on World reconfiguration; verify applied policy, worker fences and gas/contact dependencies independently before considering a selective opt-in consumer. No production integration or global sleep admission is requested.

**Disposition:** GO to independent falsifier/guard replay; HOLD for any native applicability, general skip or performance claim. Preserve all prior signed and negative evidence and leave PR #556 Draft.
