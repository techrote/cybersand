---
title: 4LY-002 measured four-profile handling and ordinary-game admission reconciliation
status: Current
document-kind: audit
scope: Exact-source real-Rapier Linux and Windows handling, hosted regression gates, measured profile identities, prior failed Windows attempt and human-feel limitations
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../systems/physical-free-flight.md, ../reference/configuration-reference.md, ../reference/interfaces-and-message-contracts.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md, 2026-10-23-4ly002-handling-candidate-admission.md]
---

# 4LY-002 measured four-profile handling and ordinary-game admission reconciliation

## Evidence identities, current scope and immutable record

This is the measured successor to the earlier
[implementation-candidate ledger](2026-10-23-4ly002-handling-candidate-admission.md),
which preserves the original pre-execution PENDING statuses as historical
facts rather than overwriting them. Source: [PR #223](https://github.com/techrote/cybersand/pull/223),
implementation/head `f7721a1bfc47d8965bc422911b71066d0cb65e6c`,
tested merge checkout `6c717a3e259a383597ff5cc36fc712d320cd6f42`.
This comparison includes the merged 4LY-001 shared physical plant. The
as-measured normalized controller source digest is
`fb86190c68c6a87e7d2ef7e845b1fb97305f188723a326f67f07caa6971cc8ae`.

All measurements below are *actual Godot 4.7 + Rapier 0.35.2* 60 Hz
single-rectangular-body executions on GitHub-hosted Linux and Windows,
not estimates from configuration constants. The exact prospectively
registered numerical gates were committed first in
[`4ly002_handling_thresholds.json`](../../godot/tests/fixtures/4ly002_handling_thresholds.json).
The retained, source-bound, machine-readable
[measured manoeuvre manifest](4ly002-2026-10-23/measured-handling.json)
contains every available per-profile physical measurement for **both**
platforms, the raw registration, profile/controller hashes, run/job/artifact
identities and the earlier negative Windows attempt. The platforms share
identical profile hashes and nearly identical metrics; tiny low-order
floating-point differences up to about `6e-8` absolute are explicitly
preserved, not rounded into a claim of bit-exact host equivalence.

The resolved parameters, units and rationale are in the
[configuration reference](../reference/configuration-reference.md#physical-free-flight-values).
They are authored as different real physical plants, one identical
controller/topology and one versioned two-output velocity action, with
empty equipment. None of the controller's goals/world/evaluation inputs
have changed. The literal code value `calibration = "candidate_4ly002"`
is part of the four measured profile hashes and must **not** be flipped
silently to `measured_4ly002`: doing so changes the identity of what the
test actually ran. Any later retuning or status change requires a
separately versioned comparison and source-bound verification.

## Physical results against prospectively registered criteria

| Required measurable handling distinction | Prospective acceptance | Linux result | Windows result |
|---|---:|---:|---:|
| Hauler normalized 60-step speed / Trainer | no more than 0.85 | 0.475933 | 0.475933 |
| Dart normalized 60-step speed / Trainer | at least 1.20 | 1.766361 | 1.766361 |
| Drifter common-speed neutral stop travel / Trainer | at least 1.25 | 1.846532 | 1.846532 |
| Physical single-rectangle unsupported hover | at least 240 support-free ticks each | 240/240 each | 240/240 each |
| 4LY handling fixture | zero failed assertions | 602 passed, 0 failed | 602 passed, 0 failed |

The same deterministic command sequence drove every candidate:
240 neutral ticks, 120 right, 180 neutral braking, 120 right,
180 left/reverse, 90 up, 120 down and 240 attitude recovery ticks.
The separate equal-speed braking control first applied a real
`20 cells/s` external horizontal impulse, then neutral command;
passive coasting used the same impulse followed by explicit power-off.
A real hard static wall supplied contact/penetration checks.
The published output records onset, speed at steps 60/120, brake time,
distance and overshoot, neutral hover displacement, reverse crossing
and final velocity, ascent/descent, angular recovery, actuator
saturation, passive coasting and collision/contact behavior.

| Profile | Measured 60-step speed (cells/s) | Neutral stop distance (cells) | Equal-20-cell/s stop travel (cells) | Neutral 240-step initial spool displacement (cells) |
|---|---:|---:|---:|---:|
| Trainer | 46.9843 | 12.5400 | 4.7361 | 2.0819 |
| Hauler | 22.3614 | 15.3970 | 11.5564 | 15.7556 |
| Drifter | 44.4089 | 32.3038 | 8.7453 | 6.4165 |
| Dart | 82.9912 | 13.8759 | 2.4655 | 0.5691 |

The Hauler's initial powered-hover spool-up falls approximately 15.76
cells before settling, considerably more than Trainer. This **passed the
registered unsupported-flight/settled-speed gate**, but is a legitimate
owner-feel concern and not silently called a perfect hover. The Drifter
is stable and upright while taking appreciably longer to stop. None
of the profiles require surface support during the 240-step hover test;
the recorded resource mode is continuous authored power without a
simulated fuel timer.

The original 4LY-001 actual contact/underpowered gravity fixtures and
the real-owner/lifecycle cases are still exercised alongside the new tests.
Their conformance cannot substitute for the four-profile comparisons,
and the dedicated #207 lab/scenario qualification remains a separate gate.

## Exact-source hosted gate results and retained negative result

| Gate | Source-bound evidence | Outcome |
|---|---|---|
| Linux four-shard Godot regression and gate | [GDExtension #39888785668](https://github.com/techrote/cybersand/actions/runs/39888785668), including [shard-3 raw logs](https://github.com/techrote/cybersand/actions/runs/39888785668/artifacts/12474324774) | PASS |
| Actual Windows Godot regression, run attempt 2 | Same [GDExtension #39888785668](https://github.com/techrote/cybersand/actions/runs/39888785668), 121 / 121 applicable cases; [retained Windows artifact](https://github.com/techrote/cybersand/actions/runs/39888785668/artifacts/12474809378) | PASS |
| Linux GDExtension build + Windows cross-build | GDExtension #39888785668 | PASS |
| Native C++ validation | [Native #39888785669](https://github.com/techrote/cybersand/actions/runs/39888785669) | PASS |
| Documentation/provenance, historical M11 and frozen + supplementary retrieval | [Documentation #39888785680](https://github.com/techrote/cybersand/actions/runs/39888785680) | PASS |

An earlier Windows attempt on the **same tested source** was negative:
120 / 121 applicable cases passed, with an unrelated retained
`test_player_vehicle_controls.gd` timeout after 180 seconds. The
case had passed at an earlier source. GitHub's targeted Windows rerun
(attempt 2) completed all 121/121 cases; both executions and the failed
run remain provenance, not retroactive claims that attempt 1 succeeded.

These complete exact-head checks apply to the executable source
`f7721a1...`. The later source-tree additions of this evidence record
and optional gameplay capture fixture are *not* retrospectively covered
by these runs. Their applicable hosted checks must pass against the
final revised PR head before merge. If an additional binary/source
change occurs, repeat this qualification and do not reassign old
measurement provenance.

## Profile hash handoff and learning boundary

| Stable profile ID | Measured resolved SHA-256 |
|---|---|
| `4ly_trainer` | `f1f9286a27b929c96caca5aaf2be70cbd82e0fd933f29968c1aaaa43ac8f1704` |
| `4ly_hauler` | `e9979ed9e437d2fcdf5c4c52fb4385e788d4ccd6f40c7494308c60c26c11e10d` |
| `4ly_drifter` | `c195dd35677dcbdb76c85c798d0c1fbc103dcc40182932be7d70c755b1dbac24` |
| `4ly_dart` | `a48a58c388fb0826f5b5b29005a7469d2cd081dd2c0ed3bfe6c028d88cd04084` |

These are frozen **physical measurement identities** on the tested plant,
not a prospective admission to train. #207 may consume the numerical
envelope as a source-bound reference when qualifying its actual flight lab,
episode producer and teacher, **provided** it verifies the final merged
host/profiles against these hashes. The companion 4LY-004/005 learning
campaigns retain their separate gating; this record does not authorize
four simultaneous training runs.

## Descriptive rendering and owner-feel limits

The additive
[`test_physical_flight_gameplay_render.gd`](../../godot/tests/test_physical_flight_gameplay_render.gd)
requests future source-matched GL framebuffer captures of each profile
inside the ordinary main sandbox, commanded through the actual version-2
policy/lease/physical-owner path. It is a **new pending fixture** at this
audit checkpoint; its captures are not claimed until the corresponding
hosted render job and retained screenshots are verified. Ordinary
source-level selection already covers the real sandbox and existing
exploratory Play hosts and preserves the native-worker/reset fences,
46 legacy IDs, SetP and protected Benchmark/scientific fixtures.

No owner has provided a subjective handling sign-off. Graphical clips
are useful descriptive evidence only and cannot supply human feel
approval. New Web execution, target-PC input/render behavior, broader
native material coupling and learned policy performance are unmeasured.
The issue should remain open for those explicit owner/host limitations
unless the owner separately grants a narrower acceptance. Do not mark
subjective feel, Web qualification or policy training as passing merely
because CI is green.
