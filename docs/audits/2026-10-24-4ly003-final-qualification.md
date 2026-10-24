---
title: 4LY-003 source-bound final teacher score and integration disposition
status: Current
document-kind: audit
scope: Prospective frozen-teacher physical qualification, one-use final suite provenance, retained failures and exact-head PR integration; not a learned-policy admission
last-reviewed: 2026-10-24
related-documents: [2026-10-23-4ly003-checkpoint.md, ../systems/physical-flight-lab.md, ../operations/physical-actor-programme.md, ../operations/local-build-and-validation.md]
---

# 4LY-003 — final teacher score and integration, 2026-10-24

**Implementation:** [PR #229](https://github.com/techrote/cybersand/pull/229), [issue #207](https://github.com/techrote/cybersand/issues/207), upstream 4LY-002 PR #223 merge `1f9336388f11be39abaae340a781a5eef52115d4`. This document updates the status of the earlier [implementation checkpoint](2026-10-23-4ly003-checkpoint.md) without editing its historical measurements or superseding the independent learner experiment.

## Immutable plant and source-bound physical evidence

The four upstream profile digests remain as registered in the original checkpoint; normalized controller SHA-256 is `fb86190c68c6a87e7d2ef7e845b1fb97305f188723a326f67f07caa6971cc8ae`. Scripted teacher source SHA-256 was frozen as `0fb571cfd314a53fc86b3517fb5a8258a77d7215fcbcb43fc7f53519e7e29761`. No 4LY-002 profile, controller, native material or Rapier physics implementation was tuned for this score.

[One-use, frozen-teacher GitHub-hosted final qualification #40038449339](https://github.com/techrote/cybersand/actions/runs/40038449339) passed using Godot 4.7 stable, pinned real native/Rapier runtimes and an AMD EPYC 7763 runner. The physical evidence identifies GitHub Actions synthetic merge checkout `2bc2b6cfa9ad62512266df5804c5662b5ba8bd04`, not merely a branch name. Its run-local suite has SHA-256 `4bd18d728581f64fa770c4dc29f765eff956f61999b96d03d8e378d54efc3401`, 56 unique scenario/seed fixtures and four registered seeds (419, 421, 431, 433). The final runner retained **224 complete episodes, 149,534 actual physical ticks and 263,821,956 bytes of traces**. Separate Python readback examined **224/224 complete traces**, per-episode hashes, source/teacher/profile/controller identity, physical receipts and native tick continuity: **PASS, zero readback errors, zero physics faults and zero invalid authority actions**.

The score must preserve both failures and successes:

| Scored family | Trainer | Hauler | Drifter | Dart |
|---|---:|---:|---:|---:|
| Free-space navigation | 12/12 | 12/12 | 12/12 | 12/12 |
| Reversal | 4/4 | 4/4 | 4/4 | 4/4 |
| Arrival and 36-tick dwell | 4/4 | 4/4 | 4/4 | 4/4 |
| Obstacles | 16/16 | **13/16** | 16/16 | 16/16 |
| Disturbance/contact recovery | 4/4 | 4/4 | 4/4 | 4/4 |

In total, **157/160** navigation/recovery family episodes received qualification credit; all **three failures** were retained in Hauler obstacle runs, not replaced or dropped. The four profiles each had **12 negative-control trials with zero navigation credit** (48/48 controls), plus four unsupported-hover trials each without navigation credit (16/16). Recovery qualification specifically required a bounded accepted disturbance and a post-disturbance physical contact witness before low-speed arrival; merely avoiding the wall did not count. Registered thresholds (free-space 80%, reversal 75%, arrival 80%, obstacles/recovery 60% per profile/family), minimum counts and zero critical faults were all met **on the tested host and frozen teacher**.

Earlier failed corner/slalom/recovery DEVELOPMENT episodes and earlier failing score attempts remain historical evidence; final positive results do not erase them. A single one-host Linux qualification does not demonstrate multi-host determinism, target-PC human feel, actual real-time learned inference or neural skill.

## Final-suite custody and precise scope of admission

The originally published public `final` geometry and later exposed v2 layouts were invalidated by split amendment v3 and were not reused for these measurements. The one-use CI job generated a different SHA-committed, run-ID-bound 56-case suite at execution time after the teacher source hash was frozen, performed its geometry/identity preflight, ran the native/Rapier scorer and independently verified the retained outputs. Its generation code was nevertheless visible in the transient PR workflow, and its `reviewer` admission field was supplied by that automation. **A separate human review or independently held external custodian has not been recorded.** Treat this as a strong source-bound scripted-teacher final-score result, **not** proof of externally administered blind-custody governance, and do not repurpose those final fixtures as untouched learner finals.

The transient GitHub Actions final-qualification job was removed from the permanent workflow after its evidence was retained. The explicit final runner in `godot/qualification/4ly003_teacher_qualification.gd` continues to fail closed if the external suite/admission/source/teacher identities are missing or mismatched. Wildcard regression jobs continue to access development fixtures only. This preserves score integrity and avoids running the one-use final again during normal CI.

## Post-qualification integration and exclusions

The later main-branch merges added LCB documentation, fixtures and tests, but no changes to the frozen flight profiles/controller/teacher, native material physics or 4LY episode/observation schema. The integration retains source-qualified final evidence at its **original tested checkout**; a newer source SHA is **not** retrospectively substituted in that evidence. The reconciled [GDExtension/Godot #40041851953](https://github.com/techrote/cybersand/actions/runs/40041851953), [Native #40041852010](https://github.com/techrote/cybersand/actions/runs/40041852010) and [Documentation/provenance #40041851921](https://github.com/techrote/cybersand/actions/runs/40041851921) all passed at pre-cleanup PR head `84b9322a1590488fc1a293a4047df4c0f38924c6`. If this cleanup/documentation update creates a new head, its own applicable CI must pass before merge.

The final teacher score may support a **scoped flight-lab implementation checkpoint**. It does **not** itself admit `techrote/neural-cyber-automata#74` training, allocate hardware, qualify realtime throughput for inference/transport, close broader #132, or assert complete #207 external custody or human approval. Any independent final-custody signoff and companion learner preregistration remain separate approvals.
