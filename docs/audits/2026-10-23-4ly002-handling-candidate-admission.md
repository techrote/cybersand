---
title: 4LY-002 four-profile handling and ordinary-game selection candidate
status: Current
document-kind: audit
scope: Issue 206 source candidate, prospective real-Rapier measurements and exact-final-head acceptance blockers
canonical-for: []
last-reviewed: 2026-10-23
related-documents: [../systems/physical-free-flight.md, ../reference/configuration-reference.md, ../reference/interfaces-and-message-contracts.md, ../operations/local-build-and-validation.md, ../operations/github-development-and-release.md]
---

# 4LY-002 four-profile handling and ordinary-game selection candidate

## Implementation authority and source

Scope: [Cybersand #206](https://github.com/techrote/cybersand/issues/206)
depends on accepted 4LY-001 [PR #209](https://github.com/techrote/cybersand/pull/209).
The assessed and implementation base is `main`
`61ce0f73b05b4fb276f5851a884ca399eeb4782c`. A recoverable focused
branch is `feat/4ly-002-profiles-selection` (the opening PR records the
exact final source head when the gate runs). The existing physics/controller
implementation is reused unchanged: Godot 4.7, Rapier 0.35.2, native material
coupling, 60 Hz, action profile `4ly_velocity_v1`, and the retained version-2
physical-wire envelope. No alternative/shortcut policy-actuation code or
scene-specific physics was introduced. No Water/pressure, native solver,
cell carrier, or scientific fixture implementation was touched.

The canonical current physical contract is
[4LY free-flight](../systems/physical-free-flight.md);
[configuration](../reference/configuration-reference.md#physical-free-flight-values)
owns exact candidates and
[interfaces](../reference/interfaces-and-message-contracts.md#physical-free-flight-actions)
owns action, capability/receipt and lease identity.

## Source changes present on this candidate branch

1. **Four distinct complete physical profiles.** Trainer retains the 4LY-001
   default, Hauler uses large/high-inertia, lower desired speed/acceleration and
   longer force response; Drifter has slower translational braking/low passive
   linear drag but upright stabilization; Dart is compact with higher desired
   speed, faster drive/brake and quick response. See exact tables in
   configuration. All use a single validated rectangular Rapier collider,
   zero joints/mounts and explicit empty default equipment, with the same
   `CyberPhysicalFlightController`.
2. **Additive F5 host selection.** The family `set4LY` is appended after the
   original eight sets. The original 46 `RIG_IDS` retain their indices and SetP
   remains unchanged. Ordinary sandbox/exploratory hosts can select any of the
   four via human, neutral demo or policy. Applying and resetting replaces the
   actor and restores map spawn; equipment selection is disabled in the panel
   and independently denied by the host for this family.
3. **Observable handling and presentation.** The F5 button names the selected
   profile, authority and actual flight mode; its tooltip shows lease/fallback
   and profile hash. The source-driven physical rectangle uses its actual bridge
   transform with small visual hints of the applied physical force and requested
   desired velocity. They never drive collision or locomotion.
4. **Static policy capability data.** The `flight.capabilities` descriptor
   includes a deep-copied `capabilities` subset of physical mass, footprint,
   inertia, speed, force/gravity headroom, accel/brake, response/slew, drag and
   attitude authority. Neither a route, evaluator label nor a target enters the
   stabilizer; the already-published dynamic controller and action receipts
   remain separate.

The profile `calibration` field is deliberately
`candidate_4ly002`, not a declaration of tested family calibration.

## Prospective physical measurement gate

The source-controlled
[`4ly002_handling_thresholds.json`](../../godot/tests/fixtures/4ly002_handling_thresholds.json)
was created on this branch **before executing** the newly authored
[`test_physical_flight_handling.gd`](../../godot/tests/test_physical_flight_handling.gd).
It sets numerical comparison and per-profile thresholds. The fixture attempts:

- Identical unsupported 240-step neutral hover, 120-step horizontal velocity
  request, 180-step neutral brake and 180-step reversal.
- Identical 90-step ascent, 120-step descent and 240-step upright recovery
  after the same angular impulse (scaled by the body's declared inertia).
- Independent identical physical **+20 cells/s** initial horizontal impulse,
  followed by 240 neutral steps to measure braking time and distance without
  confusing requested top speed with brake response.
- Independent +20 cells/s impulse followed by explicit host power-off and
  60 passive steps, to distinguish physically persistent drift from secretly
  powered assistance.
- 480-step approach to the same physical static wall with contact count,
  observed blocked velocity and penetration checks.
- Actual applied force/torque magnitudes versus each profile's budget and
  published applied impulse integral. Every profile/fixture records its profile
  hash; run logs identify the source and platform separately.

A family pass requires the registered individual physical criteria **and**
Hauler speed at step 60 <= 85% of Trainer, Dart >= 120%, and Drifter common-speed
braking distance >= 125% of Trainer. The suite prints machine-readable
`4LY_002_HANDLING_METRICS` on completion; do not infer measurements from
authored constants alone.

The
[`test_physical_flight_selection.gd`](../../godot/tests/test_physical_flight_selection.gd)
independently opens the ordinary desktop scene to exercise F5 selection,
reset/epoch fencing, policy/demo choice, empty loadouts, companions, exploratory
map retention and return to sampled mode.

## Execution/admission ledger

| Gate | Evidence at this checkpoint | Disposition |
|---|---|---|
| Profile/schema, published capability copying | Source and Godot regression coverage added; measured run not yet recorded | PENDING actual host |
| Four measured manoeuvre sets against prospectively registered thresholds | Deterministic actual-Rapier fixture committed before first execution | PENDING execution and retained logs |
| Four ordinary F5 selectable profiles and reset/producer/empty equipment lifecycle | Dedicated scene/owner regression committed | PENDING execution |
| Retained 4LY-001 physical plant and session plus physical actor/equipment/host regressions | Existing regression suite remains discoverable | PENDING reexecution at exact final head |
| Docs, repository/provenance, frozen and supplementary retrieval | Canonical updates and retrieval question changes on candidate branch | PENDING hosted validation |
| GitHub-hosted Linux+Windows Godot/GDExtension and Native applicable checks | Existing workflows unchanged | PENDING exact-final-head checks |
| Subjective owner handling feedback / measured graphics captures | No such evidence collected | NOT CLAIMED |
| Trainer learning or family policy | Explicitly outside #206 and dependent on #207/#74/#75 | NOT CLAIMED |

Source files and authored fixture traces are **not** empirical metrics. This
audit intentionally records the absence of measured output, of locally
qualified runtimes and of owner-feel acceptance. An issue or PR may only be
closed as completed after evidence replaces the pending states above.
Do not substitute a green workflow at an old source SHA for the final branch
head. Negative/outlier measured runs remain in their own records; any tuning
change creates a different profile hash and requires rerunning the prospective
gate.

## Reproduction and remaining acceptance work

With the **source-matched** pinned Godot, Godot native extension and Rapier
runtime prepared per the
[build guide](../operations/local-build-and-validation.md):

```sh
godot --headless --path godot --script res://tests/test_physical_flight_profile.gd
godot --headless --path godot --script res://tests/test_physical_flight_session.gd
godot --headless --path godot --script res://tests/test_physical_flight_physics.gd
godot --headless --path godot --script res://tests/test_physical_flight_handling.gd
godot --headless --path godot --script res://tests/test_physical_flight_selection.gd
python3 tools/ci/check_docs.py
python3 tools/ci/check_repository.py --require-materialized
python3 tools/ci/check_m11_consistency.py
python3 tools/ci/check_ci_provider_policy.py
python3 tools/docs/retrieval_eval.py --output /tmp/4ly002-frozen-retrieval.json
python3 tools/docs/retrieval_eval.py --queries docs/reference/retrieval-challenges.json \
  --output /tmp/4ly002-supplementary-retrieval.json
git diff --check
```

CI remains GitHub-hosted with draft PRs suppressing expensive validation;
ready-for-review must trigger all applicable exact-final-head native,
GDExtension/Linux and actual Windows Godot suites plus documentation/provenance
checks. The prospective gate should be run and measured in the resulting
source-bound evidence artifact. All four profiles must then be frozen by their
**actual** hashes before #207 imports them; the host qualification of #207
and the later learned-policy gate do not inherit acceptance from source
presence.

**Explicit limitations:** unsupported UI outside ordinary sandbox/exploratory
hosts, unmeasured manual human feel and target desktop graphics, unmeasured
browser/Web, no trained teacher or navigation success, no new material solver
qualification or generalized rigid-body/granular acceptance. Parent #132
and the Jolt/morphology programme remain independently open.
