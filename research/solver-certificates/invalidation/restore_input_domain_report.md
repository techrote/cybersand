# B2-REGION-008 — canonical source admission before certificate recomputation

**10 Nov 2026 · Research Draft / HOLD.** [B2 PR #556](https://github.com/techrote/cybersand/pull/556); baseline accepted main `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`. Pre-edit Draft `fc948496d44bdb8a51732c7dec7f10c37eb1c977`; source blob `d73f9eafdc86dd584ab131566be7c6745669f632`. [Falsifier preregistration](https://github.com/techrote/cybersand/pull/556#issuecomment-6759070927). Work confined to `research/solver-certificates/invalidation/**`.

## Falsifier and outcome

The earlier B2 body-mask correction proved ownership of the body footprint, but `State.copy()` still copied an arbitrary flat `cells` list and arbitrary `pressure`. `Sparse.restore` assigned that state **before** recomputing certificates. A foreign `cells[0]` object whose equality check raises during `rule` could therefore interrupt the reset **after publication**. With a prior complete 1- or 4-logical-shard packet barrier, the fence retained the *old* generation and accepted receipts despite changed engine state and partially cleared active/certified sets. Non-enum scalar cells (`None`, `True`, `8`) were also admitted, outside the claimed finite physical source grammar. This is an input-admission counterexample **within the Python research model**, not evidence of native CyberSand failure.

**Correction:** `State.copy` now checks exact positive integer source geometry, an exact built-in list of length width×height, exact `int` materials in `0..7`, exact `int` pressure in `{0,1}`, plus the existing owned body-footprint checks, **before** returning a source to `Sparse.__init__`, `Sparse.restore` or `Fence.restore`. No custom equality/iteration on individual hostile cell objects is invoked; invalid snapshots refuse as typed `ValueError`. The direct engine restore and owner-fenced restore both preflight before publishing. The correction is intentionally a **boundary scan**, not a per-cell hot-tick certificate engine.

### Conditional atomic-admission law

For every positive finite pair of grid dimensions W,H and any canonical physical input cell vector `c ∈ {0,…,7}^{WH}`, pressure `p∈{0,1}` and owned bounded body mask B, the admission predicate terminates after at most WH cell-type/range checks and produces a separate list and immutable B. No caller mutation to the original list or body set changes the admitted values. For every source outside this exact admitted grammar (or with a foreign cell leaf), the predicate raises before `Sparse.restore` can replace state, alter the certificate roster or `Fence.restore` can change its generation/retained packet receipts. The proof is by strict type/length guards and bounded left-to-right iteration; **it assumes trusted owner methods and no concurrent/direct mutation of engine fields**, and says nothing about the native World or general solver correctness. Existing fixed-point induction applies only after admitted-source and complete input-witness premises.

The result is a standard finite-alphabet input-contract/transactional preflight pattern, not a novel mathematical theorem.

## Bounded executed independent experiment

Local CPython 3.13 standalone *reconstruction* `b2_region008_shadow.py` (not execution of the exact published 27-kB module) used a 4×4 all-Rock state, a foreign `__eq__` object, and retained receipts for 1/4 deterministic logical shard counts.

| Variant | 1 shard | 4 shards |
|---|---|---|
| Old assignment-before-proof reconstruction | Partial state publication; exception after 1 hostile comparison | Same |
| New preflight reconstruction | Atomic REFUSE; zero hostile comparisons | Same |
| Noncanonical input-domain refusals (five cell/pressure categories plus Boolean pressure) | 6/6 | 6/6 |
| Canonical independent owned-source restoration | PASS | PASS |

This **does not establish exact-module suite success**: the new [five-method regression suite](test_restore_input_domain.py) was authored against `sparse_fence.py` and must be executed independently on its exact Git blob. It covers the reconstructed historical failure, retained 1/4 receipts, hostile equality, seven invalid cell-list cases, six malformed pressure cases, direct/fenced atomic refusal, and full-oracle replay after canonical restore. Tests are deterministic, standard library only. The test source itself is not a measured native fixture.

At the authored test revision: `sparse_fence.py` blob `1606f377ae734f621bda9975546132019638ec71`; `test_restore_input_domain.py` blob `357eadf89c2db6a7869a1a9ef4a076394fc173a6`. Independent execution should verify these against the PR head before claiming a pass.

```sh
python3 -m unittest discover -s research/solver-certificates/invalidation -p 'test_*.py' -v
python3 research/solver-certificates/invalidation/sparse_fence.py
```

## Cost, negative results and no-go boundaries

- **Tracking/admission cost:** strict flat-vector scan `O(WH)` on `State.copy` at construction/restore, including the currently defensive double-copy at `Fence.restore`; additional per-tick/per-cell rule overhead is **zero**. O(WH) boundary cost is not free and may be costly on large native worlds; no wall-clock measurement was made.
- **Skip ratio and invalidation false positives:** not measured anew by this input-validation experiment; its effect is input admission, not scheduling/skip selection. Previously reported B2 model profiles, including **3.089× high-churn abstract cost**, remain retained unchanged.
- **Complete foreign effects:** exact native producer inventory, gas/pressure long-range wake, Rapier actor motion/contact, world generation, source authority, worker fence, rollback/persistence, physical hashes and actual 1/4 worker participation are all **unqualified**. An untrusted snapshot or unobserved dependency means UNKNOWN→RECOMPUTE; missing worker inputs mean BLOCKED.
- **Residual admitted bypass:** a hostile caller with direct write access to `engine.state` can still alter state outside the owner fence. The model does not authenticate native physical authority or cryptographically lock source bytes. Do not present this guard as protection against that attacker.
- **Production applicability:** no production or protected files changed; no paid/native benchmarking, no default law switch and no whole-tick/FPS speed claim. Research GO for bounded source-domain review; **HOLD** for production consumption/integration.

**Requested independent qualification:** B4 should execute the exact source/test blobs and challenge atomic restoration with already-accepted 1/4 logical barriers; B5 should check that finite source domain + body ownership is properly expressed as a *trusted-owner precondition*, not a native-proof/physics-performance conclusion. Recheck main/PR heads at review time.
