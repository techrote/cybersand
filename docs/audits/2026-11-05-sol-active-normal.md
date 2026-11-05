---
title: Bounded active-normal relaxation comparison
status: Current
document-kind: evidence
scope: Registered copied-value normal refinement, unchanged controls, no live SOL or default admission
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [2026-11-05-sol-chamber-yielding.md, 2026-11-05-sol-response-cost.md, ../architecture/rigid-body-and-cellular-coupling.md]
---

# Bounded active-normal relaxation — 5 November 2026

Root alone owns `codex/sol-normal-active-20261105`, based on Draft416
`3e0bf637c9f2cdb660bd55cf8bc33d2da779e4f9`. Other branches remain unchanged.
The [38case registration](../../native/tests/fixtures/sol_active_normal_001.json)
precedes candidate generation/execution. The old25case profile, production
header, native84 inventory and historical failures remain unchanged.

The current four-pass approximation dilutes normal arrest over all sample
weights. This experiment changes normal relaxation over approaching or loaded
contacts, retaining capacity shares, pass count, tangent/Coulomb rules and final
energy rejection. All-active batches reuse original weights; an empty active
set cannot divide by0. Loaded separating contacts can unwind.

For positive mass/inertia, unit normals and fixed capacities, the normal batch
is a convex combination of mass-metric contact projections in exact arithmetic.
This does not prove tangent passivity: a shrinking normal impulse can shrink the
friction cone and unwind tangent impulse, increasing intermediate computational
energy. All eight batches and final rejection are recorded. Iterations are not
eight physical applications or stored Sand elasticity.

Three arms use the unchanged header, a mechanically traced control and an
active-normal candidate. Trace control must exactly reproduce baseline outputs.
Thirteen added cases cover unwind, activation, friction, opposing/corner contact,
COM translation/reflection, unequal counts, clamped quadrature and fixed caps.

No World/Rapier authority exists in this value phase. Success would permit only
a separately registered opt-in live comparison and fresh native qualification.
In the existing live path the passive state includes the accepted event wrench;
legacy is combined afterward. That order and material/arrival policy must stay
unchanged. Original eligibility/Active-hold admission, CPU/archive failures and
365's restoration block remain binding. Keep publication Draft/dependent on416.

## Executed values and independent checks

Registration `e7b7f997` precedes implementation/execution
`5bca61599758be25eb847bce092a36bd72ef9b14`. Nine binaries compile and run:
three arms on Linux GCC13 optimized, strict ASan/UBSan and actual Windows
MSVC19.38 optimized. All21commands exit0 with clean logs. Each binary runs
38cases with three workspace replays and38maximum-node priming solves:
152calls each,1,368overall. The342case observations include18expected
null/overflow refusals, separately classified from accepted zero responses.

[Execution/compiler/input/binary receipts](sol-active-normal-20261105/execution.json),
[complete comparison](sol-active-normal-20261105/comparison.json) and
[custody manifest](sol-active-normal-20261105/manifest.json) preserve identities,
commands, process elapsed times, flags and hashes. Generated headers/binaries/logs
remain ignored. The generator authenticates the original header/driver, and
input bytes are bound to the prospective commit.

For each arm, parsed observations match across all three compiled variants;
original raw-byte hashes remain distinct. The unchanged header reproduces the
25original observations exactly; trace control reproduces all38physical/result/
final-workspace observations before candidate claims are evaluated.

| Uncapped incoming COM case | Baseline remaining speed | Candidate remaining speed |
| --- | ---: | ---: |
| Approaching fraction1/2, support or separating remainder | 0.0625 | 0 |
| Approaching fraction1/4, support or separating remainder | 0.31640625 | 0 |
| Approaching fraction1/8, support or separating remainder | 0.586181640625 | 0 |
| Mass520, approaching fraction1/4 | 0.31640625 | 0 |
| Unequal1/2/4sample counts | 0.5397750937109538 | 0 |
| Rotated unit normal, approaching fraction1/4 | approximately0.31640625 | 0 |

All nine named targets stop within1e-12 with no normal cap hit or rejection.
This improves normal arrest in synthetic values; it does not prove material
yielding, live Sand interaction or original SOL clearance.

With available0.5, the approaching node keeps capacity1/16 and support7/16.
Both arms retain speed15/16: unused support capacity is not transferred.
Loaded unwind gives baseline `(vx,omega)=(-13/16,-19/16)` and candidate `(-1,-1)`,
with normal loading1/2→1/4→0. COM translation/reflection and bin-order controls
pass. Candidate translation speed magnitude increases in five such cases while
rotation, total kinetic energy and maximum approach residual improve; this is
not a claim of uniformly less body motion. A separating contact also becomes
active on the next normal batch, showing active-set recomputation.

Independent read-only recomputation authenticates all9binary/log hashes and
14,319input bins/14,310final nodes. For1,632fully snapshotted computational
batches, clamps and velocity/omega deltas match; above32contacts the snapshots
are explicitly partial. Full-body batch states and complete final nodes remain
available. No positive normal-batch energy increase occurs. Unchanged friction
still permits tangent computational-energy increases: maximum0.0390625, with
0.01705078125/0.0188009765625 in the shrinking-cone case. Its candidate and
baseline outputs match. These are iterations, not separately applied work.

All registered benefit/analytic/normal-energy screens pass on all three builds,
with no new rejection, worsened maximum approaching-contact residual or final
energy increase in these38inputs. The existing final energy gate is unchanged.
A post-execution auditor strengthening binds zero applied/raw wrench on early
refusal; all retained refusals were already zero. No input, threshold or
algorithm is revised after outcomes.

`python tools/experiments/test_sol_active_normal.py` audits committed values,
baseline parity and full merit decisions without a compiler/World. It refuses
seven corrupted records, including redistributed capacity, wrong active mask,
relaxation, max-node counts and nonzero refusal wrench. Equal parsed values are
used only to adapt file resolution; original raw-byte receipts remain intact.
External independent adversarial acceptance remains pending.

## Decisions and next live gate

| Separate decision | Source-bound result |
| --- | --- |
| LA-SELECTIVE intended primary direction | CONDITIONAL, unchanged owner direction |
| Registered copied-value benefit/safety | PASS in38cases on three compiled variants |
| Real World/Rapier physical benefit | UNAVAILABLE; no live candidate executed in this phase |
| Original SOL physical clearance | NO-GO historical result retained; original authority absent |
| Material/source/Active-hold integration | NO-GO; no cross-SOL composition or restoration |
| General performance / original SOL CPU gate | UNAVAILABLE here; retain416's scoped cost evidence |

The next step is an opt-in normal-policy route through existing workbench
coupling, retaining the original policy/default and post-event passive-state
ordering. It requires a new prospective live registration, control parity,
fresh source-qualified Linux/Windows native binaries and affected tests before
any physical claim. Protected World/pressure semantics, material transitions
and frozen guards stay unchanged. Value PASS grants no integration admission.

Reproduce at the pinned execution source with
`python tools/experiments/sol_active_normal.py build/<fresh-name>` and
`python tools/experiments/sol_active_normal_compare.py build/<fresh-name>`.
Source guards reject changed inputs/header and directories refuse overwrite.

At `954167cd`, [validation](sol-active-normal-20261105/validation.json) passes
documentation, historical M11, repository/runtime provenance, original material
guard, new/old portable value audits, six geometry adversaries and whitespace.
Frozen retrieval remains19/32rank1 and32/32rank5; chamber2/3rank1 and3/3rank5;
passive1/1, cost2/2 and the separate active-normal question1/1rank1. Manual
fact review preserves synthetic/live, capacity and energy limits. No original
guard, source digest, policy/query/persistence oracle or runtime pin is relaxed.

**Source archive FAIL:** [artifact receipts](sol-active-normal-20261105/source-artifacts.json)
at `954167cd` record178,351,626bytes, SHA-256
`383ae5e3b35a449727f3862b7269d695918971bb1769427dd666081726260f1c`,
above unchanged134,217,728bytes. The dependent patch is2,254,314bytes, SHA-256
`3868a3f85534f36e751553f1405481c20a58bfd6a44afa8ad11c1f0bff12974d`.
These ignored local artifacts are handover files, not a release. Later metadata
commits remain outside that source snapshot. Historical84/84clearance failures,
64/84depth failures,36/36async overlaps,1452/1452refusals, CPU/archive/MAT failures
and365's block remain unchanged. Separate independent adversarial review must
precede any owner promotion or integration decision; keep this PR Draft.
