---
title: B4-005 independently challenged B3 signed-IN seed alias custody
status: Experimental / HOLD; source-critical model falsifier, not native acceptance
document-kind: research-evidence
scope: B4 independent exact-source-gated adversary for B3-RESEARCH-4
last-reviewed: 2026-11-10
---

# B4-005 — mutable seed alias crosses signed-IN policy after admission

## Identity and pre-registration

- Accepted CyberSand main at inspection: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`.
- Independent B4 Draft PR #554 parent: `23742c8c293c5ea7f9c05fd9fa5cb6a12f445eaf`.
- B3 Draft #555 inspected head: `aedb37ab671888a2c9914ad01d8c33c330cbc3f1`, `handoff_contract.py` Git blob `523810bee1d9b219a421557181ecae108d222ef2`.
- Earlier B3 initial-state policy hole fixed in B3-RESEARCH-4, not reasserted. Its new `inertial_seed_admissible` accepts both a tuple and a **list** for `velocity_q256`.
- [B4 pre-registered experiment](https://github.com/techrote/cybersand/pull/554#issuecomment-6756632194) before this implementation.
- Source-critical contract documents read on main: AGENTS.md, docs/operations/cybersand-codex-development-handover.md, docs/reference/status-and-roadmap.md, docs/architecture/pressure-optimization.md and docs/architecture/pressure-flow-v1.md. #470/#471/#522 are accepted historical performance controls, not claimed successors here. #406 ballistic Water remains a separate experimental source family; #474 lockstep is opt-in.

## Defensible falsifier

The conditional B3 seed policy is checked at `World.start` and in explicit `assert_invariants`, but **the admitted seed data are not recursively owned**. The frozen `Record` dataclass is shallow. A caller can provide a mutable two-integer velocity list, which satisfies `Record.valid()` and `inertial_seed_admissible`. `World.start` installs that same Record into its dictionary rather than copying the list.

For `signed_inertial_world_enabled=False`, the following is therefore a source-visible violating trace (research model only):

```python
v = [0, 0]
w = World.start(3, [Record("water", Owner.INERTIAL, 256,
                            velocity_q256=v)],
                signed_inertial_world_enabled=False)
v[1] = -8              # caller-owned list; NO World transition
# w.records["water"].velocity_q256[1] is now -8;
# w.epoch and Record.revision have not changed.
```

Calling `w.assert_invariants()` *afterwards* detects the unsupported seed. But that does not prevent the already-installed invalid state or invalidate an external source witness. More strongly, the model's `prepare` invoked **after** this mutation sees the negative value as its current source signature; a fresh IN→BALLISTIC transaction can use it, and the successor BAL-LISTIC owner passes `trial.assert_invariants`. The Water quantity theorem remains valid. An intent prepared *before* mutation is correctly refused by the existing `SOURCE_DRIFT` check. This is a **policy/provenance custody gap**, not a mass-conservation counterexample and not evidence of a native CyberSand defect.

The exact checker asserts these distinct controls: immutable tuple resists mutation; unsigned list source drifts after validation with epoch/revision unchanged; later explicit invariant catches it; fresh post-drift handoff can be admitted; pre-drift intent refuses; signed-policy list mutation remains policy-valid.

## Reproducible apparatus and observation

- [Source-pinned B4 checker](b3_seed_alias_adversary.py): refuses `SOURCE_MISMATCH` unless the supplied external B3 module has Git blob `523810bee1d9b219a421557181ecae108d222ef2` and model tag `B3-RESEARCH-4`.
- Author-local CPython command: `python3 -m py_compile b3_seed_alias_adversary.py && python3 b3_seed_alias_adversary.py --shadow`: **PASS, 4/4 independent predicate/alias controls** (unsigned/signed × tuple/list). Its executed local file was Git-blob hashed and compared to the published file, which must match before quoting an exact blob.
- The independent checker `--module /path/to/B3/handoff_contract.py` is **authored but not executed** in this environment, because B3 checkout/native binaries are not locally available. The source-critical trace follows directly from the inspected exact GitHub source but is not a claim of completed exact-module dynamic qualification. Reviewer should execute that mode on B3 exact head, not copy B3 into the B4 repository subtree.
- Python source byte-level identity matters: a B3 amendment requires changing the expected blob and re-auditing each claim; never silently run against a different producer.
- Resource bounds: four shadow controls; one current seed and one list element mutation per control; exact mode contains a fixed number of single-record cases. Neither is native profiling or a parameter sweep. `--shadow` is explicitly **not** the full B3 model oracle.

## Proposed minimal correction and independent challenge

For admitted `Record` state, canonicalize nested velocities to owned immutable tuples **before** installing in `World.records`, or reject mutable inputs with typed refusal. Require the same rule for any opt-in restore/admitted update; validate every authoritative state transition under an explicit trusted producer. Add an adversarial record list mutation after start and after prepare, with a full mutable-source negative control, without assuming Python frozen dataclasses provide deep immutability. If a direct dataclass writer remains allowed, the theorem must explicitly assume exclusive ownership and no unversioned external aliases rather than claim unconditional seed immutability. Source-bound native policy/range, fences, Rapier and CYPS remain unproved.

**Disposition:** Source-critical **HOLD** on B3 model seed custody and on production use. This is a new research abstraction counterexample; B3's previously corrected unsigned negative initial literal remains refused, and existing B2 immutable worker packet fix is distinct. No new solver operation, material law, source identity, benchmarked performance improvement or physical-hash parity is established.

## Performance admission and negative controls

No new native executable or qualified A/B/B/A matched-host run is available in this run. Therefore median/p95 tick, memory/allocations, actual worker participation, pressure/gas and dynamic contact parity are **UNAVAILABLE**, not inferred from a Python model. Retain [B4 original real #470 source-matched stage reduction](README.md) without whole-tick causal attribution, the zero-packet `my-canvas` counterexample and stress tail sign flips. Retain B2's **3.089× high-churn abstract work regression** and require a physical-hash/exact-state oracle and active/quiet/multichunk worker evidence before any performance GO. No paid/native campaigns, protected-source changes, merge, default switch or hot-path checker.

B4 requests independent B3 and B5 model replay, source-typed seed/restore custody and a fresh B4 exact-head check. B2 region certificates must treat any unversioned mutable source or untrusted generation/epoch as `UNKNOWN=>RECOMPUTE`; incomplete worker ownership remains `BLOCKED`.
