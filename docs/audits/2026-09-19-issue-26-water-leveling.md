---
title: Issue #26 Water head/leveling characterization and bounded-candidate disposition
status: Current
document-kind: evidence
scope: Source-matched automated characterization of deep/extended Water leveling, two rejected bounded no-state candidates, and successor architecture handoff
canonical-for: [issue-26-water-leveling-evidence]
last-reviewed: 2026-09-19
related-documents: [2026-09-19-issue-26-registration.md, issue-26-2026-09-19/baseline-reference.json, ../systems/water-design.md, ../operations/architecture-programme.md, ../reference/status-and-roadmap.md]
---

# Issue #26 Water head/leveling — 2026-09-19

## Post-merge review qualification

The independent [post-merge review](2026-09-19-issue-26-post-merge-review.md)
preserves this audit as historical evidence for the exact #26 experiment, but
qualifies several apparatus-v1 interpretations.

The two local candidate rejections remain valid because they fail independent
registered bulk/head benefit gates. Do not use apparatus v1 as the acceptance
oracle for #45.

Review corrections:

- settling/equilibrium v1 excludes dry columns, can encode an unreached threshold
  as numeric zero, and latches a sustained pass without later revocation;
- the historical fixture called `unequal-head-u-tube` is actually a
  three-compartment unequal-head communicating geometry, not a clean two-limb
  U-tube;
- whole-run p95 pools active/startup and sleeping ticks; the horizon arm genuinely
  does more useless work but the dramatic p95 ratio is not an active-tick ratio;
- hill/terrace/contact values are sampled proxies and do not by themselves
  establish the declared lifetime/rendered acceptance dimensions;
- the evidence runner requires overwrite/failure-retention hardening;
- final PR #41 validation cross-built Windows and performed actual runtime/ABI
  regression on Linux; it did not execute fresh Windows Godot runtime validation.

[#49](https://github.com/techrote/cybersand/issues/49) owns the correction. New
metrics or fixture geometry require new version identities and fresh Current-Water
controls; do not rewrite the result tables below.

## Disposition

Issue #26 completes through its declared **Outcome B**:

- the deep/extended Water defect is reproduced and quantitatively bounded;
- the source-matched control is preserved;
- both admitted small/local no-history candidate families were tested independently
  against thresholds frozen before candidate code;
- both candidates are rejected;
- no combined candidate is run because neither isolated arm justifies it;
- no production Water semantics, mass precision, Cell layout, directional history
  or presentation policy changes are accepted;
- the next architecture question is tracked by **#45, Water architecture experiment:
  transmit head through saturated connected bodies**.

The important result is structural: Current Water can redistribute mass between
adjacent cells when there is destination capacity, but has no mechanism for a high
column to transmit useful head through a saturated connected passage and lift the
lower side. Increasing local request strength or looking one additional cell
horizontally does not solve that missing capability.

#18 compact directional history remains held. Its horizontal/diagonal H references
remain confounded by the known bulk-head defect, so this result does not admit #18.

## Source and apparatus

#26 started from current main after the #27/MS-000 merge:

- source base: `de332eaf8f4e70b25b097bed0c2e2a7b2aac0173`;
- branch: `codex/issue-26-water-leveling-2026-09-19`;
- draft integration PR: #41.

The preregistration is
[`2026-09-19-issue-26-registration.md`](2026-09-19-issue-26-registration.md).
The retained native apparatus is:

- `native/bench/water_issue26.cpp`;
- `tools/physics/water_issue26.py`.

It covers nine scenario families over translations -65/0/63, normal/mirrored
orientation and 1/4 workers. Candidate runs use the same geometry and schedule as
their paired control. The harness asserts exact sampled closed-Water accounting,
exact expected worker parity and zero post-setup owned allocations.

PR #33 supplied the prior H handoff, including the key correction that historical
`u-vessel` is uniformly filled and is not differential-head evidence. #26 therefore
adds a true unequal-head U-tube/communicating-column fixture instead of reusing that
scenario incorrectly.

## Frozen baseline

Workflow run `35412803078`, artifact `10574760981`.

Artifact ZIP SHA-256:
`0466c6057b45dcdeb28e87a81682307fc2d8e23fc5932b747ab1dea2343a77c7`.

The baseline ran 108 cases. All passed:

- exact sampled Water quantity;
- exact authoritative 1/4-worker parity;
- zero post-setup owned allocations.

Key median results:

| Fixture / metric | Current control |
|---|---:|
| shallow outlet receive mass @300 | 21,104 |
| medium outlet receive mass @300 | 27,223 |
| deep outlet receive mass @300 | 27,223 |
| communicating-pools final level difference | 16.000 cells |
| unequal-head U-tube final level difference | 24.000 cells |
| constriction receive mass @300 | 15,454.5 |
| calm-settling sustained half-life | 480 ticks |
| calm-settling sustained <=1-cell spread | 2,670 ticks |
| fast-dump final surface spread | 3.392 cells |
| ledge-sheet receive mass @300 | 9,453.5 |

Two results are especially diagnostic.

First, medium and deep outlet controls produce the same early discharge. Extra
column depth above the locally active outlet cells supplies no additional drive.

Second, the communicating-pools and true U-tube fixtures make a small initial
rearrangement and then become effectively quiescent while retaining approximately
16- and 24-cell surface-height differences through the full 4,800-tick horizon.
This is authoritative simulation state, not a rendering explanation.

The frozen numerical survival gates and exact hashes are retained in
[`baseline-reference.json`](issue-26-2026-09-19/baseline-reference.json).

## Candidate 1 — head-scaled local drive

Candidate commit:
`c84e36817d4514b8b08b9c9a34d87ff8a3bfee92`.

This experiment remained behind a default-off diagnostic selector. It augmented the
adjacent request using a radius-2 local column proxy: current cell plus up to two
Water cells above each endpoint. Writes remained adjacent.

Workflow run `35413179226`, artifact `10575226046`,
artifact SHA-256
`46e331d714f8ebe88d6cee48b845463575eeb4ac0e8ac02c8a54f51cf1576511`.

The candidate-bearing source reran the baseline first; its authoritative samples
and deterministic work counters matched the frozen control exactly. The head arm
then ran another 108 cases with conservation, worker parity and allocation checks
passing.

Measured candidate medians:

| Metric | Control | Head arm | Frozen gate | Result |
|---|---:|---:|---:|---|
| calm sustained half-life | 480 | 360 | <=360 | pass |
| calm sustained <=1-cell | 2,670 | 2,400 | <=1,980 | **fail** |
| deep receive @300 | 27,223 | 29,334 | >=34,029 | **fail** |
| deep / medium @300 ratio | 1.00 | 1.00 | >=1.10 | **fail** |
| communicating level difference | 16.000 | 16.000 | <=12.000 | **fail** |
| U-tube level difference | 24.000 | 24.000 | <=18.000 | **fail** |
| constriction receive @300 | 15,454.5 | 16,352 | >=19,319 | **fail** |
| ledge receive @300 | 9,453.5 | 9,940.5 | 6,617–14,180 | pass |
| fast-dump final spread | 3.392 | 2.4215 | <=3.731 | pass |

Several active-fixture p95 timings also exceeded the preregistered 1.15 review
ratio. Because the mandatory calm gate failed and none of the four additional
primary benefit gates passed, this arm is **rejected**. The exact result is retained
in
[`head-scaled-result.json`](issue-26-2026-09-19/head-scaled-result.json).

## Candidate 2 — bounded radius-2 leveling horizon

The second arm was preregistered after candidate 1 was rejected and before its own
implementation. It asks only whether one extra same-row cell of spatial context is
the missing ingredient.

Candidate commit:
`56702574547c826a78c208502a2ad7371d501fc9`.

The candidate probes x±2 only when both the adjacent target and lookahead are
Empty/Water. It may strengthen the **adjacent** request; it does not jump barriers,
write at radius 2, move upward, add state, recurse, scan columns or create a pressure
field.

Workflow run `35413559622`, artifact `10575795070`,
artifact SHA-256
`d3b55e2318c85b875adbe4a68d4b879356e1730872f68080a3786ab147e9809c`.

Again the candidate-bearing source first reproduced the frozen baseline exactly in
authoritative samples and deterministic work. The horizon arm's 108 cases passed
conservation, expected worker parity and zero post-setup allocation.

Measured candidate medians:

| Metric | Control | Horizon arm | Frozen gate | Result |
|---|---:|---:|---:|---|
| calm sustained half-life | 480 | 480 | <=360 | **fail** |
| calm sustained <=1-cell | 2,670 | 2,220 | <=1,980 | **fail** |
| deep receive @300 | 27,223 | 28,978 | >=34,029 | **fail** |
| deep / medium @300 ratio | 1.00 | 1.00 | >=1.10 | **fail** |
| communicating level difference | 16.000 | 16.000 | <=12.000 | **fail** |
| U-tube level difference | 24.000 | 24.000 | <=18.000 | **fail** |
| constriction receive @300 | 15,454.5 | 17,178 | >=19,319 | **fail** |
| ledge receive @300 | 9,453.5 | 10,150.5 | 6,617–14,180 | pass |
| fast-dump final spread | 3.392 | 2.566 | <=3.731 | pass |

It also increases surface-classification turnover: calm-settling median turnover
rises from 10 to 22.5 sampled transitions, and fast-dump from 15 to 25.5. More
importantly, communicating-pools stays active at enormous cost while retaining the
same 16-cell level difference: its paired p95 rises from about 1.15 microseconds in
the sleeping control to about 689 microseconds. Keeping bad Water awake is not
progress.

This arm is therefore **rejected**. Exact evidence is retained in
[`bounded-horizon-result.json`](issue-26-2026-09-19/bounded-horizon-result.json).

## Why there is no combined arm

The experiment contract allowed a combined head+horizon candidate only if both
isolated candidates justified it. Neither did. Combining two rejected mechanisms
would be post-hoc tuning and would invalidate the registered decision rule.

No combined arm was implemented or run.

## Mechanism conclusion

The clean communicating fixtures explain why both candidates fail.

Current pairwise Water movement requires usable capacity at a nearby destination.
In a deep connected body, the lower passage can be completely full. The higher
column cannot communicate its additional head merely by asking for a larger
same-row transfer: there is nowhere local for that mass to go. A short horizontal
lookahead has the same limitation. Useful equalization ultimately requires a
bounded way for head/pressure information to propagate through saturated Water and
create/lift capacity on the lower-head side.

That mechanism is qualitatively different from #18 directional momentum/history.
The next work item is therefore #45, not #18.

#45 must perform an architecture/admission phase before code. Candidate families may
include a derived immutable active-region/column-head summary, a bounded scalar
pressure/head carrier, staged fixed-capacity pressure propagation, or another
bounded source-backed mechanism. It may not silently become a global/unbounded
pressure solver.

## Current source after #26

**No rejected candidate semantics are retained as Current Water behavior.**

The merge candidate restores the native Water kernel and experiment configuration
to the source-matched control. The reusable #26 characterization harness and dated
evidence remain. Current Water therefore still uses:

- exact 8-bit control mass semantics in production;
- gravity/diagonals before lateral work;
- adjacent three-quarter positive-imbalance requests;
- one-unit tolerance;
- current coherent-emission and adhesion behavior;
- no generic persistent cellular direction, pressure or velocity field.

No owner visual H regression was required to reject these arms: neither reached the
pre-H automated survival gate. A later #45 survivor will require its own focused
human review before it becomes the baseline used to reassess #18.

## Programme consequence

- #26: complete by documented Outcome B once this evidence/cleanup lands.
- #45: next Water bulk-head architecture experiment.
- #18: remains open/held; do not interpret current directional references as a
  clean stored-motion target yet.
- #20: remains downstream of #18/G-M and G-B.
- #14/G-final: remains open.
- #28/#29: remain independent/provisional; Water-dependent scenarios or interaction
  evidence are revalidated only if a later accepted Water change affects them.

A sound negative result is successful experiment completion. #26 did not find a
small local fix, but it substantially narrows the engineering problem.
