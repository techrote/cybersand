---
title: B3-RESEARCH-6 construction-bound applied-policy pin
status: Experimental / Draft HOLD; exact-module and native verification pending
document-kind: research-evidence
scope: B3 model only; no CyberSand runtime/physics acceptance
last-reviewed: 2026-11-10
---

# B3-RESEARCH-6 — source-typed applied-policy custody (bounded model result)

## Source baseline and preregistration

Accepted main: `d4b18e7f06839b35c8f6a66195206da0f33c5fa3`, inspected 2026-11-10. Input Draft #555 head: `e33f9ce81ef4f21570b6941c206a9a4fae25a673`, model Git blob `facfa6ff8a1d67448a17faf5dfe0c7393ea04d13`, tests `e494a301b344c6cfc3f6839b1c50d69f92f8f972`. [Preregistration, before edits](https://github.com/techrote/cybersand/pull/555#issuecomment-6758323684). Source-critical independent [B5 falsifier](https://github.com/techrote/cybersand/pull/555#issuecomment-6756801337).

Read current AGENTS.md, development handover, roadmap, PressureFlow and inertial architecture, merged #470/#471/#522, #361/#362, accepted #474 and current workbench #542/#531 context. Current default Water stays FreeMass; signed native IN is opt-in, subject to native source policy and q16 constraints; B3's q256 velocity is an abstract model and **cannot be substituted for native q16**. Rapier is main-thread-owned, World native cells authoritative; actual physical hash, persistence, worker fence and contacts are not represented by an independently authenticated B3 producer.

## Falsifier and result

Before this patch, an unsigned World could prepare an FM→IN `vy=-8` token with `allow_signed_inertial=True`, receive `UNSIGNED_UPWARD`, then have `w.signed_inertial_world_enabled=True` directly assigned with **no epoch/generation/source revision advance**; the identical token would become admissible. This violates the advertised construction-bound model-policy premise, not the mass conservation theorem or CyberSand's native implementation.

Correction (B3-RESEARCH-6): ordinary Python assignment to that field after World construction raises `AttributeError` before mutation. `prepare` additionally copies the World policy Boolean into `Intent.applied_signed_policy`; the accepted token fingerprint includes it. Every *fresh* commit checks this pin after epoch/generation/fence checks and before any trial record construction, returning a typed `POLICY_DRIFT` with unchanged state if the destination World exposes a different policy. Fresh tokens prepared in genuinely signed Worlds still admit the model's signed negative-vy IN option; unsigned Worlds continue to refuse it. A replay of a previously accepted token returns only `HISTORICAL_ACK_ONLY`, never a fresh authority receipt.

**Scoped soundness / non-escalation lemma.** For any finite initial record set and integer model velocities admitted by `World.start`, and any sequence of allowed `prepare`, `commit`, `elapse`, ordinary attribute-assignment attempts and history-only retries: the originally constructed World policy cannot change by those operations. A new *commit* requires its intent's policy pin to equal the destination's present policy. Proof: the constructor sets the scalar exactly once; guarded `__setattr__` rejects further ordinary assignments; other admitted operations do not write the policy; a candidate World in `commit` inherits the same value; the new equality check precedes mutation. This induction holds for arbitrary transfer counts and admissible integers, not just sampled test cases. It is a **model-source property**, not independent native provenance or a new mathematical theorem about fluids.

## Independent bounded checker and negative evidence

Executed with local CPython 3 in the working container:

`python3 applied_policy_custody_oracle.py`
`python3 -m py_compile applied_policy_custody_oracle.py`

Standalone source-independent shadow output:
- 3/3 old unsigned→signed upgrade exposures reproduced (`vy=-32,-8,-1`, caller flag true).
- 14/14 ordinary setter attempts rejected; 14/14 cross-World old-token mismatches refused.
- 3/3 genuinely signed negative-vy positive controls and 8/8 unsigned nonnegative-vy controls admitted.
- **3/3 retained hostile internal rewrite counterexamples**: direct `World.__dict__` rewriting plus newly forged preparation can still appear admitted. The model is not tamper-proof.

The **executed standalone checker is not the exact published `handoff_contract.py`**, its 32 authored tests or any native/Godot runtime. Source-independent matrix is 7 integer vertical velocities × 2 caller permissions, not an infinite-family test. Historical evidence of old vulnerabilities is retained; no rewriting of prior reports.

The updated `test_handoff_contract.py` adds four exact-model regression methods for the ordinary setter, reconstructed same-generation/same-epoch World, replay fingerprint and hostile internal bypass. The previous artificial restart case now uses `dataclasses.replace(World,...)` rather than directly changing a construction-only field. **All 32 authored methods await independent exact-head execution.** Source/CI advisory and any native approval must be separately established.

## Limits, cost, consumer decision

- **Negative/unsupported:** a caller with `__dict__`, `object.__setattr__`, direct `World(...)`/dataclass reconstruction, forged native policy receipts or hostile source storage can bypass model custody; an unauthorized *new* preparation can still be accepted. A World generated with changed policy but an illegally reused generation can hide ABA to other consumers. No native applied-policy identity, monotone source mutation counter, restore/rollback authentication, physical hash, packet provenance, Rapier contact custody, signed-native-velocity range, q256→q16 translation, pressure topology or body impulse law is established.
- **Incremental model overhead:** one Boolean stored in each intent and one O(1) comparison on each fresh commit, plus one value in token fingerprints; existing Python model still performs O(N) Water scans, dictionary copy and whole-record validation. Normal World creation adds only a constant-time setter branch. This is *not* measured native runtime cost and is not an opt-in production implementation.
- **B2:** treat any World incarnation/policy mutation without trusted epoch/source stamps as `UNKNOWN=>RECOMPUTE`, not a reusable dormant certificate.
- **B4:** execute the exact-head 32-test module and test source-policy spoof via raw internal reassignment, copies, stale receipts, 1/4 actual worker participation and physical-hash parity if ever separately authorized; do not imply hosted benchmark now.
- **B5:** no production consumer admission until a **trusted, native-issued immutable applied-policy/World incarnation witness** is paired with current fence/epoch/source digest and Rapier sample; type every mismatch as unverified, not physics.

**Disposition:** GO only for independent model-level review of the new conditional policy pin; HOLD for the complete exact-module suite, authentic contact policy, production physics, and any performance claim. Draft #555 remains unmerged; default material law, MAT-AUTH, native World, Rapier/worker ownership, persistence and all prior physical evidence are unchanged.
