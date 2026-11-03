---
title: SOL281 dense contact recovery registration
status: Planned
document-kind: evidence
scope: Preregistered opt-in unilateral Sand contact experiment and source reconciliation; no gameplay acceptance
canonical-for: []
last-reviewed: 2026-11-03
related-documents: [../systems/solid-detachment.md, 2026-11-01-sol281-current-main.md]
---

# SOL281 dense contact recovery registration

## Source and integration strategy

Verified before implementation on 3 November 2026: accepted main is
`89020b9eb6d540383a5bb64b58dcd29a87592c32`; active draft #347 is
`5af50b3c5a5f11614099a82090ad431646db4cba`. Their common ancestor is
`a8f08a67fea3c58f6df7473cbae1831334fcc04e`. Main adds the accepted #332 PLAY
recovery. A three-tree preview identifies three additive documentation conflicts
and no execution-source conflict. Merge this exact main into #347 using an
ordinary merge commit, retain both introductions in those three documents and
preserve every existing execution/evidence ancestor. This registration precedes
that ancestry change and all candidate tuning. Historical qualification remains
bound to its original source; it does not qualify the reconciled executable.

Frozen #283 remains `254235ec4c3d58782bba44b478caca86bf57c856`, draft/open,
unchanged. #282 and #343 remain draft/unmerged. No merge or promotion is authorized.

## Concrete deficiency and selected experiment

The aggregate has native mass 520, yet its host caps the sum of the six proxy
impulse magnitudes at 3 per consumed sample. At the fixture's gravity scale
0.094, nominal acceleration 980 and 60 Hz, the corresponding gravity impulse
is approximately 798.37 per step. This dimensional comparison explains why the
existing response is weak; it is not a measured causal gameplay result. Native
bearing also has its own capacity limit. Simply raising the host cap is not the
registered experiment.

Implement one **opt-in aggregate-only, inelastic unilateral normal response**
to unresolved ambient Sand. The exclusive native worker selects exact occupied
unit-square / transformed-rectangle contacts. Main-thread Rapier applies an
effective-mass impulse only to approaching motion at an actual contact point,
with a current-pose check and kinetic-energy nonincrease preflight. No positional
correction, new friction, Water response, ejection radius expansion or material
transfer is added by this mechanism. Retain the prior conservative-displacement
host as the baseline. The six rectangles, their holes, native ownership and
ordinary 11-input/9-result coupling remain intact. The experiment is independent
of Y1, which is not imported or promoted.

## Proposed gates fixed before tuning

These are **proposed mechanism gates**, not previously approved gameplay limits.
Do not change them after observing candidate outcomes.

| Gate | Registered criterion and rationale |
|---|---|
| Conservation/ownership | Exact existing payload and quantity gates, zero duplicate or stale application; any loss or corruption is NO-GO. |
| Geometry | Analytic rotated square/OBB intersection area and SAT separation depth within 1e-8 in double tests; exact touching is distinct from positive area; holes and sibling internal faces preserved. |
| Single-contact response | Identical frozen current pose/velocity/mass/inertia/contact inputs; approaching normal speed reduced to within 1e-4 cells/s, separating input unchanged. This tests a unilateral inelastic constraint, not calibrated friction. |
| Energy | Each calculated impulse must satisfy kinetic-energy change <= 1e-8 * max(1, initial energy), followed by actual Rapier readback within 1e-4 relative tolerance. No restitution or correction energy is authorized. |
| Determinism/fencing | Identical frozen inputs yield identical ordered contacts/response within host precision; malformed, incomplete, duplicate, old, wrong-token/generation/tick and excessive-pose-drift samples apply no impulse. |
| Physical improvement | Registered controlled packed-plane and off-centre contact steps must reduce added overlap area by at least 25% against the unchanged baseline, with no greater initial penetration. Record depth/area separately. Failure remains NO-GO for that fixture. |
| Bounded cost | At most 8192 cell/proxy geometry probes and 256 manifold contacts per publication; explicit refusal on capacity or unknown residency. Report actual counts and milliseconds per complete observation/application. Target observed mean added owner/contact work <= 2 ms on the disclosed host; this is provisional CPU feasibility, not GPU acceptance. |
| Live trial | Repeated packed/embedded/mixed actual asynchronous sessions with workers 1/4; report ranges, exact denominators and real geometry metrics. No causal speedup or calibrated energy claim from unmatched trajectories. |

Unresolved initial embedding, sustained clearance, resistance calibration,
latency under missed publications, multi-contact rotational stability and human
feel remain separate gates. A passing single-contact response does not satisfy
them or #281. Do not advance restoration until the physical gates justify it.

## Measurement contract

Enumerate native cells against each exact rotated rectangle, including fringe
squares whose centres are outside. SAT minimum separation depth and clipped
intersection polygon area are different metrics. Sum area across the disjoint
proxies; deduplicate cells for overlap-cell observations. Record pre/post phase,
native tick, source revision, body sample, epoch and token. Native publication
samples are not simulation steps: report overlap-cell-samples and area-samples
for asynchronous observations, never relabel them cell-ticks. A deliberately
synchronized fixture may report per-step values with its explicit step count.

Record response impulse, torque, current linear/angular velocities and kinetic
energy before/after application; gravity, ordinary coupling, hard collision,
damping and scheduler effects remain separate. Record native geometry time,
probes, contact count, main application time, worker/native and Rapier timing.
No headless GPU/interactive performance claim is permitted.

## Qualification and stop boundary

Use existing targeted SOL281 CI and source/runtime provenance. Add focused
geometry/response regressions to the existing cohorts; preserve all negative
fixtures. Require independent review and actual Linux/Windows execution, with
MSVC coverage identified separately from LLVM-MinGW cross-builds. Keep failures
and blockers. Publish code and a gate-by-gate handover on #347; keep it draft.
Do not merge #347/#282/#283 or close #281/#12.
