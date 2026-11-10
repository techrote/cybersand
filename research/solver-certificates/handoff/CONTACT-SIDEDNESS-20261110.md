---
title: B3-RESEARCH-9 — a contact tuple is not a sided impact certificate
status: Experimental / Draft HOLD; independent oracle executed, exact parent mode pending
document-kind: research-evidence
scope: Research-only B3 representation handoff contact-evidence boundary
last-reviewed: 2026-11-10
---

# B3-RESEARCH-9 — contact provenance and sidedness

## Pinned source and preregistration

Accepted CyberSand main: \`d4b18e7f06839b35c8f6a66195206da0f33c5fa3\`; B3 Draft PR #555 pre-experiment: \`2622a1204748d3630affa7f08e8ebb51dbb8fbe8\`. Parent B3 \`handoff_contract.py\` Git blob: \`e8176a1a2a63fdd3edc1b097cf47647a20ff34bf\`. Pre-registered before source change: [#555 comment 6760864206](https://github.com/techrote/cybersand/pull/555#issuecomment-6760864206).

Source reconciliation: [#406 ballistic Water](https://github.com/techrote/cybersand/pull/406), [#470 incremental hard-surface collider packets](https://github.com/techrote/cybersand/pull/470), [#471 neighbour cursor](https://github.com/techrote/cybersand/pull/471), [#522 PressureFlow gas optimisation](https://github.com/techrote/cybersand/pull/522), and [#474 opt-in lockstep](https://github.com/techrote/cybersand/pull/474) are **merged** on accepted main. The current standalone B2/B3/B4 PRs #556/#555/#554 remain Draft. #361 equipment/authoring PR #553 and active PressureFlow optimisation candidates #532/#533 are Draft, not accepted sources. The historical [ballistic reference](../../../docs/architecture/ballistic-water-v1.md) still says “not on main”; PR state and actual accepted source supersede that stale sentence, not the experimental/default-off limitation.

The exact B3 model's \`World.record_contact\` accepts a free-form \`kind\`; it appends \`kind\` to \`contact_observations\` but records only \`(epoch, body_id, sample, source_id)\` in \`contact_samples\`. \`commit\` checks membership of that **four-tuple**, never the kind, signed contact normal, relative motion, or independently verified impulse. \`audit_tag\` affects only a receipt's \`UNVERIFIED_INPUT_DECLARED\` label. No assertion about native contact sensor defects follows.

The actual accepted-main native path is separate: \`godot/native_extension/cyber_native_cell_world.cpp::reconcile_overlap\` derives an outward direction from overlap/sweep and can launch spray through \`try_water_spray\`; \`godot/scripts/rapier_physics_bridge.gd::apply_cellular_results\` applies main-thread positional corrections and central impulses. Neither can be equated with an independently authenticated, complete *signed-contact* certificate in this research model. Do not add a contact requirement to authored jets, face release, or ordinary ballistic mechanisms.

## One falsifier

For the same genuine contact **key** \`(13,7,42,"water")\`, consider (a) a closing impact, (b) a separating contact, (c) telemetry-only observation, and (d) an unknown-kind observation. The B3 tuple-membership predicate admits every category when the key is present. Thus **\`CONTACT_PRESENT\` is not sufficient for \`SIGNED_IMPACT_VERIFIED\`**, even though all admitted transfers still conserve the abstract Water quantity and preserve single-owner records.

The independent \`contact_sidedness_probe.py --selftest\` enumerates the 4 axial normals, velocities \`v_x,v_y\` in integers [-8,8], and four event categories. Its proposed *strictly narrower* signed-impact oracle requires (1) exact producer-owned epoch/body/sample/source association; (2) authenticated owner ledger **as an assumption**, not a user-supplied flag; (3) event kind \`impact\`; (4) a nonzero exact unit axial normal; (5) relative normal velocity \`n·v < 0\`. It returns \`UNVERIFIED\` for any unknown/missing/synthetic/nonclosing case. The constraint is for a **future impact-certified receipt**, not a law for all valid physical spray.

| Independent pure-Python result | Count |
|---|---:|
| Same-key presence admissions | 4,624 |
| Explicit closing-impact qualifications | 544 |
| Typed UNVERIFIED cases | 4,080 |
| Of those: non-impact kind | 3,468 |
| Of those: nominal impact but tangent/separating | 612 |
| Wrong-identity/strict-type refusals | 6 |
| Producer/invalid-normal/side/kind refusals | 7 |

Actual local command: \`python3 contact_sidedness_probe.py --selftest\` under CPython 3.13, **PASS**. \`python3 -m py_compile contact_sidedness_probe.py\`, **PASS**. The executed and uploaded Python source matches Git blob \`7600f97991833ebff1839b23a0ddc172d0ada05e\` byte-for-byte. The checker also provides \`--exact\`, which verifies the full historical B3 parent blob *before importing it* and expects four distinct kinds to commit and an absent sample to refuse. **That exact-parent mode has NOT been executed** in this run; do not cite its expected outcomes as executed observations. Full B3 module tests and real native/Rapier/1-/4-worker tests also were not run.

## Conditional closure law and precise boundaries

For any finite contact ledger and any integer-valued relative-velocity vector (an infinite parameter family), provided (a) the exclusive owner genuinely authenticates the ledger and cannot be impersonated, (b) each typed event's complete key and signed normal/velocity values are faithful to the physical producer and mutation epoch, and (c) \`SIGNED_IMPACT_VERIFIED\` is returned *only* by the listed guard, then every accepted signed-impact receipt has a matching issued \`impact\` event and negative signed normal relative velocity. Proof: the guard checks exact key, producer, kind and a strictly negative dot product before emitting that type. Mutation of any required field, or unknown producer custody, cannot be promoted by this guard. This is an elementary admission invariant, not a novel physics theorem; finite enumeration is a check, not the proof.

The normal grammar is axial integer unit vectors. Real rotating Rapier shapes produce general continuous normals, contact manifold ambiguity, touching/tangency, moving boundaries, and multiple simultaneous samples; the lemma makes **no** claim about those cases. Nor does it show that a closing contact warrants any specific ballistic impulse, upward speed, energy transfer, volume displacement, or solver selection. Source-supplied string \`producer="rapier-main"\` is not authentication. A future consumer must obtain a trusted worker-to-main witness or return \`UNVERIFIED\`. For non-impact launch causes, use a separate typed source/equipment/face-release permit rather than claiming a nonexistent Rapier impact.

The model-level guard is constant operations per **bounded handoff**, not per-cell or per-tick physics work. A real native implementation would additionally pay for producing signed contact data, preserving sample/owner lineage, synchronizing worker fence and main-thread ownership, and versioning persistence and physical hash; these are *unmeasured*. No speed claim or proof of native conservation is admitted.

## Integration handoffs

- **B4:** run \`python3 research/solver-certificates/handoff/contact_sidedness_probe.py --selftest --exact\` at the exact published B3 head, compare with pinned parent, then examine whether any real source-matched #406/#474 collision sample exposes a signed normal/relative velocity under an authoritative producer without an extra hot-path pass.
- **B2:** invalidate a typed impact witness on body movement, sample/epoch change, rollback, World continuation renewal, source material edits and global contact state uncertainty; *present* sample alone is not a wake/safe-reuse certificate.
- **B5:** keep \`CONTACT_PRESENT\`, \`SIGNED_IMPACT_VERIFIED\`, \`UNVERIFIED\` distinct in any proposed opt-in research consumer. Independently challenge the ledger's trust premise and the crash-window external Rapier effect custody problem. Do not integrate into production physics without an independently reviewed contract.

**Disposition:** GO for the conditional typed-evidence law; NO-GO for claiming that the current model's tuple-only witness proves physical impact; HOLD for exact-parent execution, authentic native producer, general contact geometry, external-effect recovery and real cost. No B3 parent or production source edited; no default, MAT-AUTH, native World, Rapier, worker fence, physical hash, persistence, units or material law changed.
