---
title: 4LY-001 shared physical free-flight conformance
status: Current
document-kind: audit
scope: Issue 205 implementation, actual Rapier conformance, lifecycle negatives, source/runtime identity and final hosted gate handoff
canonical-for: []
last-reviewed: 2026-10-22
related-documents: [../systems/physical-free-flight.md, ../reference/interfaces-and-message-contracts.md, ../reference/configuration-reference.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# 4LY-001 shared physical free-flight conformance

## Authority, source and recoverable checkpoint

The owner requested completion of [issue #205](https://github.com/techrote/cybersand/issues/205).
The assessed live main was `da5112c066416346d6fe3984d4161cd162611e50`,
including the Water exit-acknowledgement repair from PR #199. The issue chain,
companion training contract, canonical actor/coupling contracts, dependency pins,
LFS state and overlapping work were inspected before implementation.

The implementation checkpoint is
`d7e66d8a94c1641c4ff03f484ed3d0c8af7be574`, tree
`00d962153ba3956544701e7d5a7ddd56332077f8`, on
`feat/4ly-001-physical-flight`. It is recoverable through
[PR #209](https://github.com/techrote/cybersand/pull/209), initially opened as a
draft. The remote Git tree was checked against the locally staged tree before
publication. This audit and its machine-readable evidence follow that source
checkpoint without changing its actuator implementation.

The [curated conformance record](4ly001-2026-10-22/conformance.json) retains
source/runtime hashes, exact commands, per-case outcomes and timeouts, local log
digests, measured physics and validation scope. Raw logs, generated imports,
toolchains and binaries are not added by this change. Existing historical M11
records and dependency hashes remain unchanged.

## Implemented behavior and isolation

The [canonical contract](../systems/physical-free-flight.md) owns the new lane.
One validated profile schema and one local controller serve the four reserved
IDs `4ly_trainer`, `4ly_hauler`, `4ly_drifter` and `4ly_dart`. Each has one real
rectangular chassis, explicit mass/inertia and absent equipment. Trainer carries
initial conformance tuning; the other three use identical numerical defaults
and declare their uncalibrated status. The ordinary roster remains 46 actors.

The policy interpretation admits only two finite desired-velocity components.
At 60 Hz the controller uses that request and own velocity/attitude, bounds
acceleration/braking, includes gravity compensation in the same total thrust
budget, applies response/slew limits, and bounds upright torque. Its signature
has no goal, position, terrain, route, reward or World object. The actuator
owns one force/torque channel for one manual Rapier step; it does not assign
velocity or transform. Native coupling and material behavior are unchanged.

Neutral remains an authorized request to brake and approximately hover.
Cancellation, deadline expiry and power cutoff clear assistance and response
state without erasing momentum. Existing run, actor, epoch, sequence, issued
observation, producer, control-generation and lease fences remain effective.
The session additionally binds prepared/consumed snapshots to the bridge's
actual physical-step counter. Cancellation before consumption removes pending
force; cancellation after consumption retains the original producer, generation,
sequence, action and actuator receipt. New submissions cannot rewrite that
history. Unexpected physical steps cause a sticky suspension until replacement;
duplicate preparation or completion without a physical step is refused.

## Actual physical results

These are bounded, headless Linux conformance observations from the actual
retained Godot/Rapier/native runtime. They are not four-profile handling
qualification, broad material qualification or owner feel acceptance.

| Fixture | Measured result |
|---|---|
| Unsupported neutral | 600 steps / 10 seconds, zero grounded steps; initial spool drop 2.08194 cells |
| Settled hover | Zero measured displacement during the final five seconds; final speed approximately 0.00000337 cells/s |
| Upward request | 61.0432 cells of ascent over two seconds |
| Downward request | 81.7864 cells of descent over three seconds |
| Horizontal request then neutral | 47.4066 cells/s before braking; 12.5398 cells of stopping travel |
| Attitude disturbance | Peak angle 0.9530 rad, torque never above 300; final angle/angular velocity approximately zero |
| Propulsion explicitly disabled | 77.0880 cells fallen in one second; applied force and torque zero |
| Underpowered fixture, maximum force 150 | 120/120 saturated steps, 72.1547 cells fallen; bounded thrust cannot conceal insufficient lift |
| Native hard-wall fixture | 162 contact steps out of 240, desired horizontal speed 48 but final actual horizontal speed approximately zero |

A separate zero-gravity, zero-drag fixture applies external linear/angular
impulses and compares the next actual velocity change with the bounded force
and torque integrals. Preparing assistance does not immediately change velocity.
The fixture also cancels a prepared force before physics and verifies that it
does not act. This accounts for the authored actuator contribution only; no
unavailable decomposition of passive drag, gravity or contact forces is claimed.

## Validation and retained failures

The pinned runtime is Godot `4.7.stable.official.5b4e0cb0f` with Rapier `0.35.2`.
The Godot archive SHA-256 is
`0b1a6c54c2c619c12e169fe9241edda4b81080b519451cec2984bf0d2c6cb73c`.
The Linux native runtime SHA-256 is
`28f99172da4256acc34bcd932b113dacabe52bdb459fd0ee4883f741e41bd8e5`;
the Linux Rapier SHA-256 is
`147ab5673b9687ccb7a3b12fec07ea55cc674ad8a75f529d1085bf7d61fbd831`.
Source-sensitive retained native provenance matches; no native input or runtime
pin was changed. Materialization/identity checks cover 18 required payloads,
which is separate from executing those platforms.

| Local gate | Outcome |
|---|---|
| Pure profile/controller | 845 assertions, zero failures |
| Actual session/lifecycle | 273 assertions, zero failures |
| Actual physical plant | 9,892 assertions, zero failures |
| Focused new and retained actor/equipment/player suites | 39/39 cases passed, no skipped cases, script errors or timeouts |
| Documentation before this audit | 104 documents, 206 claims, 2,316 local links, 202 anchors; no errors/warnings |
| Materialized repository/provenance | Passed, 18 payloads |
| Historical M11 | Passed, 18 records and 28 source hashes at the audited historical revision |
| CI provider policy and whitespace | Passed; existing GitHub-hosted policy retained |
| Frozen retrieval | 32/32 hit@5, 21 rank-one, MRR@5 0.7953 |
| Supplementary retrieval | 114/114 hit@5, 92 rank-one, MRR@5 0.8863 |

The 39-case sweep ran during final integration; the last backend-gravity
admission guard landed during that sweep. All three new flight fixtures were
then rerun successfully at the exact published implementation checkpoint.
The JSON records both scopes rather than retroactively describing all local
execution as an immutable-head run. The final hosted gates separately bind the
complete PR head.

Focused cases use `tools/ci/run_godot_regressions.py::run_case`, with a
180-second timeout per fixture and isolated writable `XDG_DATA_HOME`,
`XDG_CONFIG_HOME` and `XDG_CACHE_HOME`. The direct reproduction shape is:

```sh
timeout 180s "$FLIGHT_GODOT" --headless --path godot \
  --script res://tests/test_physical_flight_profile.gd
timeout 180s "$FLIGHT_GODOT" --headless --path godot \
  --script res://tests/test_physical_flight_session.gd
timeout 180s "$FLIGHT_GODOT" --headless --path godot \
  --script res://tests/test_physical_flight_physics.gd
python3 tools/ci/check_docs.py
python3 tools/ci/check_repository.py --require-materialized
python3 tools/ci/check_m11_consistency.py
python3 tools/ci/check_ci_provider_policy.py
python3 tools/docs/retrieval_eval.py --output /tmp/4ly-frozen-retrieval.json
python3 tools/docs/retrieval_eval.py \
  --queries docs/reference/retrieval-challenges.json \
  --output /tmp/4ly-challenges-retrieval.json
git diff --check
```

The 36 retained cases cover physical actors, equipment, sampled actor references,
player controllers, selection, launch arguments and capacity. Exact case names,
commands, script hashes and outcomes are in the JSON. New tests are discovered
by the existing hosted Godot runner without workflow changes.

Validation found and corrected material defects:

- The first sustained-thrust implementation used pre-step impulses. Reported
  velocity approached zero while position drifted upward by approximately
  0.974 cells/s. The force-channel correction removed this drift, and the
  strengthened hover oracle now compares actual position travel with velocity.
- A six-failure session regression exposed sub-unit project-gravity scaling,
  paused-view authority, duplicate preparation/completion, false completion
  without physics and lost post-step cancellation history. The expanded
  273-assertion fixture passes all of these cases. Additional finite-double
  gravity overflow/underflow values are refused before body allocation.
- Fault cancellation initially left cached assistance diagnostics; the current
  observation overlays cleared controller/action state while retaining the last
  finite physical sample and labelled historical step.
- Early launches without isolated writable runtime directories failed before
  fixture execution. Correctly configured reruns passed; those launch failures
  are not counted as behavioral passes.
- Documentation initially lacked five pinned companion-workspace references.
  They were materialized from their exact retained checkpoint; frozen expected
  hashes were not relaxed. An initial retrieval edit displaced C09 from top five;
  clarifying native-contact and propulsion budget ownership restored coverage.

All frozen 32 and prior 110 supplementary question objects are preserved. The
prior 110 retain baseline aggregate retrieval scores, and the four new 4LY
questions rank 1, 2, 1 and 1. Returned contexts and expected facts were reviewed
against source. This is lexical development evidence, not unseen answer-quality
or navigation-policy evidence.

## Final hosted gate and platform boundary

At this evidence checkpoint, the PR is draft and hosted acceptance is still
pending. Before merge it must move to ready for review and retain exact-final-head
Documentation/provenance, Native and applicable GDExtension/Godot outcomes on
[PR #209](https://github.com/techrote/cybersand/pull/209). A skipped draft run is
not behavioral evidence. That PR's final immutable head and run links are the
hosted completion receipt; a documentation-only acceptance note does not replace
those checks.

The scoped Issue49 Water apparatus paths are untouched. Local validation did
not execute Windows, macOS, mobile or browser builds, inspect rendered pixels,
or establish interactive feel. Any hosted Windows cross-build or execution must
be described at the actual job's scope. No new dependency, runner provider,
training job, CUDA claim or paid service is introduced.

## Follow-up inputs

[4LY-002 / #206](https://github.com/techrote/cybersand/issues/206) receives the
strict profile schema, shared chassis, copied capability/hash descriptor,
60 Hz and cell-unit definitions, stable IDs and bounded conformance fixtures.
It owns numerical differentiation, final calibration and ordinary-game choices.
[4LY-003 / #207](https://github.com/techrote/cybersand/issues/207) receives the
same source-observation/lease contract, requested/admitted/prepared/completed
publication fields, explicit passive fallback and host-order diagnostics. It
owns the flight lab, actual-host episode interface and qualified teacher using
4LY-002's frozen profiles.

The neutral scripted producer is only a conformance source. Learned navigation
and Trainer-first/family qualification stay in companion issues #74/#75.
Representation parent [#132](https://github.com/techrote/cybersand/issues/132)
remains open. Implementation, empirical handling, policy success and owner
acceptance remain separate statuses.
