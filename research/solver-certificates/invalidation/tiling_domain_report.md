# B2-REGION-009 — finite tile-cover admissibility (10 November 2026)

**Disposition:** conditional mathematical GO for the finite-grid tile-cover law; **Draft/HOLD** for exact-module execution, independent review and any native CyberSand application. Research only. Not a production fix, speed claim, physics law, or World/worker qualification.

## Pre-edit identity and preregistered falsifier

Accepted `main` confirmed by GitHub branch read as `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`. B2's pre-edit Draft #556 head was `44207ba6c28674ac586f33f4a378b4b0c4511d05`; `sparse_fence.py` blob `1606f377ae734f621bda9975546132019638ec71`. Falsifier registered before edits in [#556 comment 6759827736](https://github.com/techrote/cybersand/pull/556#issuecomment-6759827736). Neither `#470` collider dirty packets, `#471` neighbour cursor, accepted `#522` PressureFlow fastpaths, nor current World/LCB/ballistic/lockstep code is changed.

The old `Sparse.__init__` calculated the integer tile column/row counts without validating caller-provided `tile_size`. For a positive 4-by-4 material grid and `tile_size=-10`:

```
cols=(4-10-1)//-10=0
rows=(4-10-1)//-10=0
roster=() ; certified=set() ; active=set()
```

With `Sand(0,0)`, `Empty(0,1)`, Rock elsewhere and even phase at tick 0, the true synchronous reference rule swaps the Sand and Empty positions. The historical zero-roster research cache instead evaluated no cells, advanced the tick, and could return `COMMITTED` after complete empty 1/4 logical-shard packet barriers. Material states **diverge on the first tick**: cached `[SAND,EMPTY]` versus reference `[EMPTY,SAND]` at indices 0 and 4. This is a silent failure of the model's complete-cover prerequisite, *not* evidence of a native engine fault.

A zero-size input raised before construction (not silent), while negative values could silently create no tiles. `True` is an integer subtype in Python and `2.0` can accidentally participate in arithmetic: neither should count as an authenticated integer partition parameter.

## Exact finite-cover lemma

**Grammar:** positive finite integers `W,H` and built-in positive integer `T`. The material snapshot must satisfy the separately checked finite source-domain and immutable body-footprint contracts. Define `C=ceil(W/T)`, `R=ceil(H/T)` and tile `(qx,qy)` as the half-open rectangle
`[qx*T,min((qx+1)*T,W)) × [qy*T,min((qy+1)*T,H))`.

**Claim (all positive W,H,T, not merely the enumerated samples):** these `C*R` rectangles are pairwise disjoint, each nonempty and their union is precisely all `W*H` cell sites.

**Proof:** Euclidean division supplies the unique `qx=x//T` and `qy=y//T` for each `0<=x<W, 0<=y<H`. Positivity guarantees `0<=qx<C` and `0<=qy<R`. The cell belongs to its indexed rectangle. If another rectangle contained that cell, both quotient coordinates would have to agree by uniqueness of division, hence it would be the same rectangle. All tiles are nonempty because each valid quotient starts below the respective positive dimension. This is standard integer arithmetic, not a novel algorithm for native solver sleeping.

**Consequence:** an empty active set is allowed to imply a completely proved fixed-point domain *only when* construction also establishes this exhaustive cover, all tile stability predicates are valid and every read/side-effect dependency remains witnessed. The cover alone says nothing about dynamic gas ancestry, pressure nonlocality, actor contact impulses, 1/4 **native** workers or production MAT-AUTH.

## Intervention and deterministic controls

The new guard rejects `type(tile_size) is not int` or `tile_size<=0` **before source copying and roster/certificate construction**. It does not arbitrarily cap legitimate positive tile sizes; e.g. `T>max(W,H)` gives one tile. No online tick-stage proof, per-cell hash, hot-path guard or changes to physical material/cell laws.

New `test_tiling_domain.py` (five methods) retains the historical unsafe formula as an explicitly labelled **negative control** and tests invalid canonical types, disjoint-exhaustive rosters, a complete shard fence against full-step oracle for T=1/2/3/4/7/100 and 1/4 logical shards, and additional witnessed edit/global pressure/UNKNOWN tapes.

An **independent CPython 3.11** bounded arithmetic oracle was actually executed separately (not the published Python module): it checked the exact quotient/roster cover for `W,H=1..17, T=1..31` (**8,959/8,959 checks**) and reproduced `T=-10,-5,-4` giving zero roster sites rather than 16. The independent one-step Sand fixture explicitly diverged at cell 0 and 4. The mathematical claim holds for the infinite positive-integer family by the proof, not by extrapolating the 8,959 tests.

**Evidence status:** The exact published `sparse_fence.py` and new `test_tiling_domain.py` are GitHub-persisted and source-pinnable, but the complete exact-module `unittest` suite has **not** been executed in this run. Independent review must run it from the published head and add an adversarial 1/4-shard cross-seam case. The independent arithmetic oracle is a reduced reconstruction, not native, Godot, physical-hash or exact-parent execution.

## Performance, unresolved constraints, handoff

- Guard complexity: **O(1)** integer type/domain admission check. Roster construction/proofs remain the existing **O(WH)** model setup costs; there is **zero added hot-tick work**.
- Recomputed skip ratio, false-positive invalidations, p50/p95, RSS/allocations: **not measured this cycle**. No new speed benefit is claimed. Earlier **3.089× abstract-work high-churn regression** remains material negative evidence and is not overridden by a constructor correction.
- The actual native source already contains #470 dirty collider packets, #471 neighbour read cursor and #522 pressure fastpaths; `cached_dormant` only skips a specific Water motion stage, not blanket chunk work. Native World authority/worker fencing, global gas changes, 5×5 body contacts, delayed producer/actor writes, saved physical hash and rollback/source ancestry remain outside this bounded model.
- **B4 request:** exact-head Python suite and a deliberately invalid tile-cover negative control before any performance consumer. Existing B4 #554 native A/B/B/A apparatus must be used if an admitted opt-in native implementation is ever proposed; no native time claim here.
- **B5 request:** treat tile-cover validity as an explicit precondition of any region-certificate interface. Reject an absent/unknown cover and unverifiable authoritative-source custody; do not move research certificates into World or accept them as generic whole-region sleep authority.

**Recommendation:** Mathematical GO for positive-integer partition coverage; integration HOLD until an independent exact-head run and source/authority review. Continue treating unknown dynamic dependencies as recompute or a blocked owner barrier, never speculative reuse. Preserve default laws, native owner, worker fence, Rapier main-thread ownership, MAT-AUTH, physical hash, saved state and provenance.
