---
title: B3-RESEARCH-8 — same-incarnation rollback resurrects a consumed handoff token
status: Experimental / Draft HOLD; shadow oracle executed, exact-parent mode pending
document-kind: research-evidence
scope: B3-only representation-transition lineage and external-custody hypothesis
last-reviewed: 2026-11-10
---

# B3-RESEARCH-8 — rollback continuation custody

## Exact baseline and falsifier

Accepted CyberSand main `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`; B3 Draft #555 before experiment `0cac753b6108bfc8770a67f8cd8f5317b68f95ed`; existing model Git blob `e8176a1a2a63fdd3edc1b097cf47647a20ff34bf`. Root AGENTS.md blob `d12d9d07101b7f7bc734835cf4b4b7849fca16d8`. Preregistered before editing: [B3 #555 comment 6759896562](https://github.com/techrote/cybersand/pull/555#issuecomment-6759896562).

The actual accepted main has #470 incremental collider packet, #471 neighbour cursor, #522 PressureFlow optimisations, opt-in #406 ballistic Water and #474 lockstep. B3 #555, B2 #556 and B4 #554 remain isolated Draft research. Main's material-selected per-World liquid family is not a dynamic per-cell handoff. Inertial negative-vy is a distinct opt-in law, and contact is not by itself a signed impulse receipt.

**Preregistered failure:** prepare full Water FreeMass→Ballistic intent at epoch 0, commit once, then restore the *pre-commit* epoch/source and empty accepted-token table **under the same trusted World incarnation ID**. An incarnation-only check admits the old token again. This differs from B3-7 cross-World transport: no new incarnation is required; the rollback invalidates the historical idempotency ledger. The B3 model can simulate this with a new `World.start` call that reuses generation and policy; this is a hypothetical restoration, NOT an assertion that the native save/restore path does so.

## Conditional law (elementary state-machine reasoning; infinite family)

Let a trusted owner issue `(incarnation, continuation)` for each executable World continuation. A prepared intent permanently binds that pair. On **every** rollback/fork/reconstruction that discards a prior accepted-token history or rewinds the authority epoch, the owner issues a strictly greater, non-reusable continuation value *before* any mutation is admitted. The executor compares both pair members in an exclusive, trusted admission barrier and refuses UNKNOWN or mismatch.

For arbitrary natural continuation `s`, any positive integer quantity `q`, any finite number of unrelated records, and any finite pre-rollback handoff sequence, an intent with `s` cannot commit after the owner advances to `s'>s`: strict inequality contradicts the required equality. This proves **non-resurrection of pre-rollback intents**, conditional on truthful monotone custody. It does NOT establish that Python dataclass fields, caller-supplied IDs or the current native World implement trustworthy custody. Neither identical physical hashes nor a fixed incarnation ID distinguish two history-divergent continuations.

**Necessary counterexamples:** preserve the incarnation ID but rewind epoch and erase accepted tokens; the consumed token commits again. Likewise, recycle the continuation value or permit malicious direct alteration of the source-of-truth stamp; simple equality then admits again. An authenticated continuation that preserves previous accepted-token history might allow historical ACKs, but acceptance of a restored full external-effects log is **not proved**. Conservative policy: always advance continuation on restore and force fresh intents, pending native design.

## Deterministic experiment and exact-mode contract

```sh
python3 research/solver-certificates/handoff/restore_lineage_probe.py --selftest
python3 research/solver-certificates/handoff/restore_lineage_probe.py --exact
```

Local CPython 3.13 sandbox source test: **160 same-incarnation token resurrections**, **160 serial-refusal/no-mutation controls**, **160 fresh-intent successes**, **four unknown/foreign/old-stamp refusals**, and **one ballistic-to-IN two-stage sequence**; deliberate recycled-stamp bypass separately reproduced. Syntax compilation PASS. These are finite samples of the conditional theorem, not its proof. Only the independent standard-library shadow model ran. The `--exact` path verifies the historical B3 `handoff_contract.py` Git blob before exercising the actual parent `World.start/prepare/commit`; **not executed at publication**, no claim of exact-parent acceptance. The current parent is untouched.

This checker has O(1) comparisons and token lookup per bounded transfer, plus an O(1) monotone serial advance at owner-controlled restoration. The existing research B3 model's O(N) whole-World scans and copy are unchanged. Unknown cost: true native allocation, persistence, worker-fence, Rapier and checkpoint synchronization. This is not a native benchmark, speedup, physics law, physical-hash parity test or native 1/4-worker execution.

## Consumer boundary and review handoff

Recommended opt-in consumer contract: `UNVERIFIED_CONTINUATION` must refuse before changing any cell, parcel or Rapier authority; historical retries remain observations, never new force/spawn permits; an authoritative native owner must bind issued lineage, worker generation, current applied solver policy, selected source/parcel, actual contact producer and transaction history at a single fenced boundary. A crash-recovered continuation and external side effects need explicit all-or-nothing custody; this research model supplies none.

B4: run `--exact` on matching B3 head, independently challenge the no-mutation result, restore/rollback/ABA and 1/4-worker source fences. B2: invalidate all derived region/pressure/contact certificates on continuation rollover. B5: challenge whether a native trusted monotonic restore witness is feasible and its boundary cost before proposing any opt-in consumer. No protected World/solver/worker/Rapier/UI sources, MAT-AUTH, saves, physical hash, units or defaults changed.

**Disposition:** GO for the conditional namespace theorem and a reproducible *negative* result against ID-only admission. HOLD for exact-published-parent runtime replay, trusted identity/counter allocation and native rollback proof. Next single seam: trusted continuation witness with crash-atomic revocation/transaction-history lineage.
