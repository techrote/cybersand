# B2-REGION-005 — bounded witness-epoch closure and atomic exhaustion refusal

**Research-only / Draft / HOLD for independent exact-head module execution.** 10 November 2026. No native worker changes, performance claims, production authority changes, or solver-policy switches.

## Source identity and preregistered falsifier

- Accepted CyberSand main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Starting B2 Draft PR #556 head: `f0585227f9f0bfc3900038429c52fc971ed71a7e`; pre-change `sparse_fence.py` Git blob `70898abcc6e1466d2aa325fad11442057a493e21`.
- Preregistration: [PR #556 comment #6756281258](https://github.com/techrote/cybersand/pull/556#issuecomment-6756281258).
- Corrected `sparse_fence.py` Git blob `cd512a8c5cce13aff756389ef4eb1d0575a6026e`; new `test_epoch_domain.py` blob `7b5f599562689165fdb306e23efee744b6baebaf`. Reconfirm these and current head before review.

**Exact defect in prior research contract.** `Packet.make` and `Fence.accept` admit only nonnegative signed-64-bit owner ticks and generations. At tick `M=2^63-1`, however, a complete valid barrier was permitted to advance, and `Sparse.step` increments tick to `M+1`. No next packet can describe that tick under the published grammar. Similarly, `Fence.restore` previously incremented generation at `M` to `M+1` before clearing the previously admitted packets, leaving an unrepresentable generation. These are bounded-protocol closure violations in the **Python research model**, not observed native defects. Python's arbitrary-precision integers mask overflow but not the lost admission contract.

The mandatory falsifier is: a complete 1- or 4-logical-shard barrier at tick `M`, and a restore at generation `M`, must both **REFUSE before changing state or accepted receipts**, while `M-1` still succeeds; an incomplete barrier remains `BLOCKED`. A restore whose claimed state tick is negative, oversized or boolean must refuse before retirement of current ownership.

## Correction and closure law

The owner barrier now preflights the **successor** tick, not only the current tick, after checking completeness but before digest rechecks or any mutation. Restore preflights the next generation and the supplied `State.tick` before changing receipt tables or state. Fence construction rejects out-of-domain initial owner tick. All checks are fixed-size scalar predicates; no per-cell proof added.

**Conditional closure statement.** Let `D={0,...,M}`. Consider any finite trace of trusted owner operations beginning with `(tick,generation) in D²` and an admitted snapshot. A complete `advance` may commit only if `tick<M`; a `restore` may change generation only if `generation<M` and the restored tick belongs to `D`. A blocked/incomplete stage does not mutate state. By induction over accepted operations, every successful resulting pair remains in `D²`; operations that would leave `D²` refuse without altering the pair, packet table or accepted witness table. This is elementary bounded-counter reasoning, **not** a new analytic theorem, and presupposes no illicit direct mutation of trusted owner internals.

This law is deliberately about **protocol representability**, not whole-tick physics, pressure dependency closure or general sleeping. It does not prove the native World uses a signed-64-bit counter or has this defect. If the real protocol needs unbounded operation, versioned wider epochs and rollover policy would require separate design/acceptance; silent wraparound is unsafe.

## Deterministic experiment and evidence qualification

New standalone `test_epoch_domain.py` covers:

1. Tick `M` with incomplete barrier => `BLOCKED`; complete 1/4-shard barrier => atomic `REFUSE`, unchanged `State`, packets and witness map.
2. Tick `M-1` => one pressure-changing commit matching full-step exact `State` (including steam conversion), then next complete barrier refuses.
3. Generation `M` => restore refuses with identical state and accepted packet/witness tables; generation `M-1` => one valid restore, next restore refuses.
4. Invalid initial/restored tick (`-1`, `M+1`, `2^100`, `True`) => typed refusal, unchanged owner state on restore.

**Executed in this environment:** isolated independent Python 3 shadow of the two integer successor predicates, 8 boundary rows across 1/4 logical-shard cases, all matched expected accept/refuse states. The pre-fix reconstructed counter example advanced tick and generation to `M+1`, then failed its own packet-admission domain. **Not executed here:** the exact published `sparse_fence.py` and the new repository test module together; the test is committed for independent replay. Do not label the authored tests PASS until actual exact-head module execution.

On a checkout of the exact PR head:

```sh
python3 -m unittest discover -s research/solver-certificates/invalidation -p 'test_*.py' -v
python3 research/solver-certificates/invalidation/sparse_fence.py
```

The extra guards are O(1) per complete barrier and O(1) per restore; no timing/allocation measurement was made. Prior B2-REGION-003 reported 0% skip and **3.089×** abstract work under global/high churn; retained unchanged. Source-matched native 1/4 worker participation, pressure/gas parity, physical hash and ABBA latency remain **unavailable**. The B4 historical #470 collider-packet gain is independent and cannot qualify this candidate.

## Independent review requests and decision

- **B4:** run the exact published module/tests at the pinned head and independently inject edge epoch values, including complete/incomplete barriers, rollback and hostile restored snapshots. Retain high-churn counterexample; no speed claim.
- **B5:** assess whether a typed `BLOCKED` / `UNKNOWN=>RECOMPUTE` / `REFUSE` owner boundary should require successor-domain admission and rollback-generation uniqueness for a *specific already-skippable stage*. Do not integrate generic runtime cache code.
- **B3:** this is related to, but does **not** solve, the separate A→B→A source mutation witness problem. An immutable payload snapshot cannot observe transient producer history without a trusted monotonic mutation authority.

**Disposition:** GO for simple arithmetic closure claim and negative original-implementation falsifier; HOLD for independent source execution, any native migration, physics or performance admission. Existing MAT-AUTH guards, Water defaults, worker fences, Rapier ownership, physical hashes, save-state and source provenance remain untouched.
