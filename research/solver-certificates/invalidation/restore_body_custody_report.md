# B2-REGION-007 — restored body-footprint ownership, exact model boundary

**10 November 2026 · Draft / HOLD (research only).** Accepted CyberSand main
`d4b18e7f06839b35c8f6a66195206da0f33c5fa3` (merged #542).
Pre-edit B2 Draft PR [#556](https://github.com/techrote/cybersand/pull/556)
head `a7103e7ff74caf4d557a55cefa3b8e3244f6e04b`;
`sparse_fence.py` Git blob `247974c57ac4e45ac5dc087e387a6920c76bf6d7`.
[Predeclared exact fixture](https://github.com/techrote/cybersand/pull/556#issuecomment-6758150240).
This cycle answers the independent [B5 restored-state challenge](https://github.com/techrote/cybersand/pull/556#issuecomment-6757733992).
All changes are confined to `research/solver-certificates/invalidation/**`.
No native World, solver, Rapier, worker, MAT-AUTH, Godot, saved state,
physical hash, material/default or proof-gate changes.

## Precise unsoundness and conservative admission correction

The previous `State.copy()` copied the flat cell list but retained the
original `body` object. Python's `frozenset[int]` annotation is not a runtime
type guard. `Sparse.__init__` and `Sparse.restore` call `copy`, so a caller
could supply `body=set({0})` and mutate that set *after* a proof was admitted,
without a witnessed `body` event. The previous geometry-only restore guard
did not protect against this same-shape input substitution.

On a **4×4** source with **Sand at index 0**, **Empty at index 4**, every other
cell Rock, and a transient body obstacle initially at index 0, both phases
certify the top-left tile stationary. An external `mask.clear()` then removes
the obstacle but supplies no owner event. In the unowned model, a complete
empty 1/4-logical-shard barrier skips that tile while a full synchronous tick
moves Sand to index 4: an exact first-tick disagreement, not a native defect.

`State.copy()` now admits only concrete built-in `set`/`frozenset` body
containers with exact integer cell indices in `[0,width*height)`, then
constructs an owned immutable `frozenset` in its returned State. An opaque
iterable, wrong type, boolean index, negative index or off-grid index is a
typed `ValueError` refusal; no custom iterator is invoked. This applies at
initial construction and direct restore, not only to `Fence.restore`.
The owner fence performs the copy/validation and engine restore **before**
incrementing generation or retiring previously accepted worker receipts.
There is no new per-cell or per-tick body checker. All ordinary body changes
must still travel through witnessed owner packets.

### Conditional closure lemma (infinite family)

Fix any finite positive grid dimensions `W,H`, a pure deterministic
synchronous radius-one two-phase rule, a bounded physical index set
`B ⊆ {0,…,WH−1}`, complete trusted producer barriers, no direct mutation of
engine-owned State and the existing read-footprint/side-effect premises.
For any externally held admissible concrete set `B`, after `State.copy`
the stored obstacle mask is the immutable value `frozenset(B)`. Mutating
the caller's original set cannot alter that value. All future admitted
body changes are owner events and produce the symmetric-difference touched
indices, which revoke any fixed-point proof reading those sites before
re-evaluation. By the original two-phase fixed-point induction, cached cells
remain identical to full synchronous recomputation under these assumptions.
The result covers infinitely many finite grid dimensions and bounded
sets, **not** arbitrary untrusted Python object graphs, concurrent copies,
direct engine-state mutation or native CyberSand runtime dependencies.

The body subset itself is a **global source assumption** for an exact
certificate receipt; a cell's body membership participates in the read
footprint. Mere equality of flat cell buffers, snapshot geometry, physical
hashes or per-cell values is insufficient provenance under unversioned
mutability (including A→B→A). The engine's monotone authoritative event
witness and real physics-side effect inventory remain unproved.

## Independent bounded reproduction — not the exact published module

A local independent CPython 3.13 reduced semantic oracle was executed with
the same 4×4 fixture, two-phase pair rule, full reference, fixed-point tile
partition, and 1/4 sequential logical shard loops. Results:

| Mode | Logical shards | Evaluated cells on tick | Cached index 4 | Full index 4 | Exact parity |
|---|---:|---:|---:|---:|---|
| Historical shared-mask path | 1 | 0 | Empty=0 | Sand=1 | **FAIL** |
| Owned-immutable mask path | 1 | 0 | Empty=0 | Empty=0 | PASS |
| Historical shared-mask path | 4 | 0 | Empty=0 | Sand=1 | **FAIL** |
| Owned-immutable mask path | 4 | 0 | Empty=0 | Empty=0 | PASS |

Four additional reduced controls refused `body=[0]`, `{16}`, `{-1}`,
`{True}` as expected. **8/8 scoped independent reduced controls completed**.
This does not mean the entire repository module/test suite was executed;
the new `test_restore_body_custody.py` contains five authored exact-module
test methods, including historical bypass, fixed restore, fixed constructor,
atomic refusal with already-admitted packets and witnessed body motion.
The complete Draft-head command is:

```sh
python3 -m unittest discover -s research/solver-certificates/invalidation -p 'test_*.py' -v
python3 research/solver-certificates/invalidation/sparse_fence.py
```

Exact published-module execution **NOT RUN** here: remote GitHub connector
provides bytes, but this run's local Python environment cannot retrieve the
whole Git tree for executing the repository source. The reduced oracle is
explicitly separately implemented; do not label it source-exact replay.
Git blob identities and current CI status must be rechecked at review.

## Cost, negative results and protected-runtime limits

| Item | Bounded cost / status |
|---|---|
| Input body validation/freeze | `O(|B|)` iterations on construction/copy/restore |
| Existing full flat-cell copy | `O(WH)`; fence restore currently makes an additional defensive copy |
| Additional hot cell/tick work | **0 added** |
| Incremental oracle rule calls for this certified 16-cell one-tick fixture | 0 versus 16 full calls, but no speed claim; both historical and fixed versions skip |
| Revocations/false positives on empty-input one-tick fixture | 0/0; not representative of busy workloads |
| Historical high-churn model regression | **3.089×** abstract work, retained unchanged |
| Native tick, actual workers, physical hash, allocation, gas ledger, contact | Not measured; **HOLD** |

The sole demonstrated benefit is **correctness of input ownership for the
declared toy theorem**. No causal native tick reduction, general solver skip,
pressure/gas dependency closure, Rapier contact safety, rollback persistence or
default-physics effect has been demonstrated. A complete worker barrier remains
a prerequisite; missing shard means **BLOCKED**, known complete unknown-range
effect means **recompute** and production failure/quarantine keeps its existing
authority.

### Independent review requests

**B4 (#554):** execute the exact new Draft-head B2 suite, including the
deliberate old-path mismatch and 1/4-shard complete packets; challenge
restore-time atomic refusal and object/protocol ownership. No native campaign.

**B5 (radiCADSAC #472):** qualify whether mutable restored body custody is
closed under the trusted-owner premise. Keep unauthenticated applied solver
policy, native body-contact effects and pressure long-range dependencies
outside any general certificate composition or speed claim.

**Disposition:** GO for bounded independent research-model verification;
**HOLD** for integration, complete source-level test qualification and any
production/current-physics or performance claim.
