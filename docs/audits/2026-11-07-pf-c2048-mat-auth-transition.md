---
title: C2048 PressureFlow opt-in protected-source transition review
status: Current
document-kind: evidence
scope: Reviewed opt-in versioned C2048 per-World capacity transition for MAT-AUTH protected native sources; immutable C1024 identity and historic test contracts preserved
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [../operations/material-catalogue-shadow.md, 2026-11-07-pf-c2048-explicit-capacity.md, ../architecture/pressure-flow-v1.md]
---

# PF-C2048 MAT-AUTH protected-source transition — 7 November 2026

**Scope:** Owner-directed completion of [Draft PR #491](https://github.com/techrote/cybersand/pull/491), using the separate independently accepted [research PR #475](https://github.com/techrote/cybersand/pull/475#pullrequestreview-5808937803). This record admits two *non-retained-identity-input* source owners under the already owner-approved **reviewed per-file transition** mechanism. The immutable historical lock, baseline, material catalogue, policy hashes, capability digests, published golden vectors and C1024 default remain unchanged. This source admission is **not an instruction to merge** without complete exact-head platform gates.

Source code provenance: `a14cbfe70633e4c761c5259e39fd7f2799120884` is the merge commit retaining the full accepted #470 hard-surface packet source as an ancestor of this C2048 implementation. The two target blobs are the exact LF-normalized source bytes at that commit, verified by independent SHA-256 calculation. The continuation code and protected source are not changed by the later transition-record commit. This is an append-only chain from current accepted main.

| Protected source path | From admitted LF SHA-256 | New reviewed LF SHA-256 | Source commit |
|---|---|---|---|
| `native/src/world.cpp` | `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb` | `7dcce6273aeb9726e8d4babce829440e61b5550344ad1504c46bb8ddcdb1eefb` | `a14cbfe70633e4c761c5259e39fd7f2799120884` |
| `native/src/world_pressure.inc` | `26051b0d10ab10d65db822c993742e0a0bf13711f3bd56158e95d77735737aca` | `71723fa32bbd29aafe93f1a8dd233cece1eec7ed295da81c1e021f635085c17a` | `a14cbfe70633e4c761c5259e39fd7f2799120884` |

**Why these edits are bounded:** `world.cpp` introduces explicit per-World validation for an opt-in gas-enabled PressureFlow capacity of 2048, carrying the selected ceiling to the existing pre-reserved gas table and derived cache. Invalid capacity requests and C2048 on FreeMass or gas-disabled PressureFlow refuse at construction. The ordinary C1024 and default FreeMass branch is unchanged, retaining the same executable material and physics behavior. The changed range does not replace hard-surface packet scheduling, material rules, host lifecycle or worker execution introduced on accepted main #470.

`world_pressure.inc` changes gas-compartment creation/split, initial and restore count checks to use the applied, admitted finite per-World ceiling. It changes the *owner-preparation-only* gas coverage scratch from a 1024-element array to a source-compartment-sized vector and rejects retained transfers that would exceed destination capacity. The 16,384 volume/atmosphere threshold, 65,535 region bound, 8,192 overlap bound, 1,024 chunk-node bound, gas equations, monotonic IDs, history capacity, split/vent/ledger semantics remain intact. All failures still quarantine a failed World.

The new **C2048-only CYPS5 / physical hash5** constructor identity is deliberately a new version and saves the requested 2048 ceiling under a versioned extension flag; it cannot be silently loaded as CYPS2/3/4 or requested by a C1024 receiver. The C1024 path emits the exact original hash versions 2/3/4, CYPS2/3/4 and native receipt bytes. The typed receipt includes an append-only C2048 domain, leaving original policy wire and catalogue identities unchanged. This is a new versioned opt-in capacity contract, not a silent revision of the existing retained family parameter law.

**Source and execution checks observed before recording this transition:** The original source-bound native GCC13 qualification [run #42321092018](https://github.com/techrote/cybersand/actions/runs/42321092018) passed **83 focused capacity assertions**, all **188 historical native tests** including over 14 million head comparisons, and focused AddressSanitizer/UndefinedBehaviorSanitizer. Later [run #42322866948](https://github.com/techrote/cybersand/actions/runs/42322866948) passed on the workbench/native host branch, and the [actual Linux prepared-host run #42322866999](https://github.com/techrote/cybersand/actions/runs/42322866999) passed source-matched GDExtension build/execution. Those are historical individual heads. This source commit includes merged accepted main #470; **new resulting-head Linux/Windows/Godot/source-provenance gates must be checked independently**, including new authored stress workloads; a pending or failed run must not be represented as passing.

**Review limitations:** This mechanism authenticates exact audited source bytes and Git ancestry; it cannot by itself prove the new C2048 law is production-worthy, platform-tested, or compatible with every Saved World. Production adoption remains separately guarded by final candidate exact-head Native, full GDExtension/Godot platform tests, original source/fixture hashes, independent science/identity/code review, receipt and save/version compatibility decisions and explicit owner acceptance. The original C1024 and LCBH-019 failures are retained as historical negative fixtures; add successor results without rewriting them. Merge via a **merge commit**, never squash or rebase, so `source_commit` remains reachable from `main`.

No synthetic self-generated baseline lock has been installed. The protected `REVIEWED_TRANSITIONS` table is extended for exactly these two source owners, with all prior entries retained.
