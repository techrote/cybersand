---
title: ACT-IK-001 development admission and physical acceptance ledger — 2026-10-23
status: Current
document-kind: audit
scope: Source-only implementation checkpoint for Cybersand #210; unexecuted actual-host, independently reviewed exact NCA wire, and physical tracking acceptance gates
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../systems/physical-joint-targets.md, ../operations/local-build-and-validation.md, ../reference/validation-evidence.md]
---

# ACT-IK-001 development admission, 2026-10-23

## Assessed upstream scope

- **Issue:** [Cybersand #210](https://github.com/techrote/cybersand/issues/210),
  standalone companion of [NCA #55](https://github.com/techrote/neural-cyber-automata/issues/55).
- **Accepted host prerequisite:** merged 4LY-001 [Cybersand PR #209](https://github.com/techrote/cybersand/pull/209),
  including explicit no-equipment single-chassis preparation, session
  lifecycle fencing and genuine manual-step Rapier receipts.
- **Implementation branch base:** Cybersand
  `61ce0f73b05b4fb276f5851a884ca399eeb4782c`. The new
  `feat/act-ik-001-joint-owner` source is a prospective change against that base;
  the final head, merged commit and published host build are *not* qualified.
- **Frozen external descriptor basis:** Cybersand
  `f2e34cf9b6fbaa5d9dedf9aa2cbc721a87472497`, NCA
  `runner-right-sole@1` descriptor SHA-256
  `76fd5e0a481e628f30fe2fb55d62eb5cc66014be07c13a5b7720d30e792d2c65`;
  semantic SHA-256
  `6cb15832e240f82f4bcd582d2c26015ef986e44f335da683abaf9746e31503c4`.
- **NCA integration boundary:** #55's software client, strict wire records,
  independent review and final protocol hash remain subject to its separate
  accepted PR. No Cybersand code is allowed to assert that NCA's current
  main branch implements and accepts this host packet format until that
  evidence exists.

## Development write-set

The new [pilot contract](../systems/physical-joint-targets.md) and
[`physical_joint_target.gd`](../../godot/scripts/physical_joint_target.gd)
enforce fixed geometry, exact ordered right-chain references, typed packets,
nonfinite rejection, absolute/delta bounds, the 12-tick original-observation
age and the earliest-exclusive expiry.

`physical_usable_equipment.gd` now admits the distinct five-part Runner
without a sixth equipment chassis or fictitious mount; the previously accepted
single-chassis 4LY empty-equipment rule remains a different path.

`physical_actor_session.gd` implements explicit pilot installation,
capability disclosure conditioned on owner-supplied source/runtime identity,
trusted grant issuance, original root/joint observation cache, command
admission, generation-aware revocation and a copied per-tick motor/motion
receipt sequence. No existing `physical_wire_action/v2` actor is converted to
joint-target semantics; a legacy wire request for the IK pilot is refused.

`physical_actor_rig.gd` implements a separate right-leg motor loop with
authored mechanical play, speed/slew/effort/force clamps and the retained
ground/air neutral gyro, on the actual Rapier pins. The passive left limb's
motors are disarmed, but body constraints and velocities remain.

Two new Godot scripts provide pure protocol regression and actual
GDExtension/Rapier lifecycle/receipt tests. They are part of the default
`run_godot_regressions.py` discovery glob; no simulation stub, fake contact
oracle or geometry-only pass is accepted for physical evidence.

## Gate ledger (truth at initial review checkpoint)

| Required gate | Recorded disposition |
|---|---|
| Source-level pilot and narrowly scoped protocol | **Submitted in branch; independent review pending** |
| Immutable NCA descriptor and explicit five-part host geometry | Source guard added; host conformance test **not yet executed** |
| Historical Runner and 4LY regression preservation | Scope-preserving implementation; full regressions **not yet executed** |
| Synthetic strict schema and malicious input fixtures | Tests authored; pass count **unknown pending executed CI** |
| Actual fixed-step Rapier pilot, motor and contact readback | Test authored; pass count **unknown pending executed CI** |
| Independent NCA #55 wire/adapter review with exact accepted hash | **Not admitted**; #55 still open |
| Authenticated host source/build hash at actual execution | **Not admitted**; tests use clearly labelled dummy identity |
| Actual lost-reply, cancellation, stale and rapid replacement acceptance | Source defenses exist; full external-adapter conformance **not yet executed** |
| Actual obstruction/realistic contact tracking and NCA physical thresholds | **Unmeasured**; not implied by successful schema or motor test |
| Hosted full build and final-head zero-skip Godot suite | **Pending** |
| Independent source-bound review of final PR head | **Pending** |
| Integration, merged source and issue closure | **Not accepted** until every required gate is met |

**No** learned weights, CUDA execution, new training budget, model selection,
end-effector accuracy score, torque sensor or empirical contact-force
decomposition are created or qualified by this branch. Any passing fixture
must be tied to its exact source SHA, actual Godot and Rapier binary identities,
test command, zero-skip result and raw logs before changing its ledger row.

## Next independent review and executable acceptance

1. Reconcile the final Cybersand head and its packet fields against the
   **accepted** NCA #55 adapter, including the distinction between the
   canonical NCA observation hash and the host's opaque observation binding,
   source grants, single-use dispatch and tracking-state continuity.
2. Verify every right-joint command, passive left motor, gravity/gyro/play,
   contact and non-zero momentum on the true Rapier loop at Godot 4.7 with
   the frozen Rapier2D runtime. Include malformed/NaN/unknown fields,
   duplicate and delayed transport, producer/goal/epoch switches, timeout,
   concurrent actors and failure during an active physics step.
3. Run source-bound exact-head CI with the ordinary Runner, equipment and
   4LY suites, strict docs and retrieval checks. Retain job/run identities
   and exact build/runtime hashes; investigate skips or quarantines.
4. Obtain an **independent** NCA/host admission review at the final executable
   commit; verify actual physical tracking evidence against the prospective
   NCA acceptance declaration in its own independently authorized test scope.
5. Only then may PR merge, NCA #55 physical admission and
   [issue #210](https://github.com/techrote/cybersand/issues/210) closure
   become eligible. Failed or unavailable checks remain explicit blockers.
