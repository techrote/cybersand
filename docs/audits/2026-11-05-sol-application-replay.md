---
title: Recorded SOL-like application replay
status: Current
document-kind: evidence
scope: Registered complete-window analysis apparatus for retained mixed-body recordings; no new physical trial or application policy
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-05-sol-active-normal-live.md, 2026-11-05-sol-authority-offline.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Recorded application replay — 5 November 2026

Root alone continues Draft429 with
[SOL-APPLICATION-REPLAY-001](../../native/tests/fixtures/sol_application_replay_001.json),
committed at04151117 before the full-window analyzer. The question follows a
declared post-result exploratory inspection of the mixed-body regression. It is
registered analysis of retained executions, not prospective new physical trials.
No application variant, correction, solver coefficient, native source or runtime
is changed. No live World/RID replay is performed.

The registered input is both complete180step/three-owner Windows worker1/repeat0
shared-body reports at119ac3a5, raw hashesaf498bfd… andce640d7b…, common initial
payloadbafc82a9…. Every1080body application is retained, including zero response.
Existing all-owner and scalar-native audits authenticate policy, identities,
actual application, energy and unchanged1e-5readback tolerance. Per-node inputs
are not exported; equal body states do not prove equal contact-node inputs.

The analyzer separates live KE, correction-clipped KE, recorded-wrench work after
that clip, observed post-application KE and Rapier-step KE. Explicit/controller,
preapplication, between-observation and correction-potential terms remain
separate. Native predicted final KE is compared with observed actual application
without labeling their gap as new energy creation. Full-window sums and first
divergences accompany endpoint contact phase.

Two algebraic alternatives retain pre-clip velocity or substitute recorded native
torque for transported action torque. They are not applied trajectories, valid
recovery predictions or promotion candidates. The latter deliberately mixes
recorded reference frames for diagnosis. Original gains, caps, cadence, material
map, input schedule and application policy remain fixed.

## Executed full-window replay

Atbd5d6617, both actual Windows and WSL Linux Python hosts pass three focused
stage tests and reconstruct all1,080records. [Summary](sol-application-replay-20261105/summary.json),
[complete records](sol-application-replay-20261105/records.json),
[execution](sol-application-replay-20261105/execution.json) and
[custody](sol-application-replay-20261105/custody.json) retain separate analysis,
physical execution and runtime identities. Curation executes at0daaeff4.
These are the same Windows physical recordings analyzed twice; there are no
new Linux physics trials or additional physical denominator. This three-authored-
body case is not an original520member SOL aggregate.

| Body | First native-wrench difference | Exported passive body state equal | First higher Active post-step KE |
| --- | --- | --- | --- |
| Barrel1 |30 |true |95 |
| Kestrel2 |32 |true |120 |
| Scooper3 |2 |true |16 |

At each first difference, event/legacy wrench and correction are zero; the
candidate initially removes more kinetic energy. The normal-policy change also
changes subsequent friction/torque response. Equal exported body states are not
proof of equal per-node positions, weights or active masks. These observations
locate the first response difference, not unique trajectory causation.

Every native passive and actual combined application KE change is nonpositive
in these two recordings. Yet364body-steps have positive recorded-wrench work
after clipping. The observed accounting is:

`actual response work = clip work + wrench work after clip + rounding residual`

| Full-window body KE term | Original | Active |
| --- | ---: | ---: |
| Clip-only work |−126.47880057400023 |−115.33385838222955 |
| Recorded wrench work after clip |+34.97377732889009 |+36.08047013177485 |
| Summed actual rounding residual |−0.000004042797760678 |+0.000002910610157855 |
| Actual combined application work |−91.50502728790791 |−79.25338533984454 |
| Explicit API work |+33.1207183183941 |+33.1202472032821 |
| Rapier-step work |+59.53543559962727 |+52.16088529070991 |
| Final total body KE |1.1511266301134102 |6.027747154147473 |

Kinetic balances close per owner to about4.45e-15. This is arithmetic closure
of observed body-state differences, not full grain/body conservation. Separate
correction-induced potential changes are+137.4994467117341/+132.59576122524135;
they must not be added as another KE contribution. Nonpositive KE changes here
do not establish mechanical-energy passivity, and do not overwrite positive
application body-steps measured in other authored cases.

For Active barrel step169, clipping removes approximately1.14514KE and the
recorded wrench adds approximately1.14179after that clip. Combined actual
application still removes KE. Retaining pre-clip velocity with the same recorded
action gives approximately.00005418KE, while actual application ends near
1.14489. This is an algebraic witness to the prediction/application interaction,
not an applied alternative or a recommendation to disable correction.

The endpoint also samples different contact phases. At179 the Active barrel has
zero nodes/zero application work, then Rapier adds3.883149866951964KE. Original
has four nodes, application removes.0257204523675571, then Rapier adds
1.0613893554485743. The barrel accounts for over99.7% of the final KE increase.
Active removes less KE through response over the whole window, while its Rapier
steps add less in total. Neither the endpoint nor the ledger uniquely attributes
the regression to clipping, normal relaxation, friction or node disappearance.

## Review, portability and limits

Internal read-only review verifies all1,080unique records and the stage ledger.
It identifies a latent action-array ordering assumption; all360actual packets
here are ordered1,2,3, so original results are correct. Before reuse,
[amendment002](../../native/tests/fixtures/sol_application_replay_apparatus_002.json)
indexes states by owner ID and enforces zero event/legacy scope for comparing
native passive prediction with total observed application. At81fb112a,
[six tests per host and both complete replays](sol-application-replay-20261105/hardening-002.json)
pass; each host's records exactly match its retained001hash. No evidence or
physical input is rewritten.

Summaries are byte-identical across Python hosts. The records differ only at
Original step13/body3 in two audited native KE fields:1.8281549696291747e-5
versus1.8281549696291744e-5, a3.3881317890172014e-21difference.
[Complete cross-analysis differences](sol-application-replay-20261105/cross-analysis.json)
preserve both hashes. The curator reconstructs the entire Linux derivative
from the Windows derivative plus those differences and requires exact bytes.
Linux raw output remains local; no byte-identical record claim is made.

The native-prediction gap is interpretable here because event and legacy terms
are zero. Between-observation KE change is zero, which does not prove every
unobserved state change absent. Native-torque substitution remains a mixed-frame
algebraic diagnostic. Per-node/batch tracing, full energy conservation, original
SOL authority/clearance and general promotion remain unavailable.

**Decision: CONDITIONAL diagnostic evidence.** The mixed-body regression remains;
no live application variant is selected. Prior rejected passive variants and
physical/SOL failures remain historical controls. A later bounded live node/batch
trace or physics candidate needs separate registration, fresh affected runtime
qualification and independent adversarial review. Keep Draft; stop before integration.
