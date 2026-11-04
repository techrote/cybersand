---
title: LCB-002 #201 P1 reviewed compatibility transition for world_pressure.inc
status: Current
document-kind: evidence
scope: Reviewed per-file MAT-AUTH compatibility transition admitting #201 P1's behaviour-preserving edit to native/src/world_pressure.inc; the lock, baseline, digests and every other protected consumer are unchanged
canonical-for: []
last-reviewed: 2026-11-04
related-documents: [2026-11-04-mat-auth-reviewed-transitions.md, 2026-11-04-lcb201-p1-wake-summaries.md, ../operations/material-catalogue-shadow.md, ../architecture/pressure-optimization.md]
---

# #201 P1 transition for `world_pressure.inc` — 4 November 2026

## Transition

The first entry in `REVIEWED_TRANSITIONS`, under the
[owner-approved mechanism](2026-11-04-mat-auth-reviewed-transitions.md):

| Field | Value |
|---|---|
| Path | `native/src/world_pressure.inc` (role: policy admission, physical hash and CYPS restoration) |
| From (baseline lock entry) | `c8cb11512e935d05e099d8f155c1659473a7f61aa301e2e4900e55bdcfe4024b` |
| To (LF bytes at the source commit) | `d766e808e88287f3f9ef1b833d790106e56eb512654a350716c8573beb30a874` |
| Source commit | `e5416b81bebf7ce79ac9894f7f9edf88f63b58da` (P1 wake summaries and P1b) |
| Issue / PR | #201 / #382 |

The source commit descends from baseline `0fd4af5987e77db4da3e37c757cf2c0917ae9e15`.
It is the last commit on #382 that changes this file, so #382's head holds the
same bytes. #382 must merge with a merge commit so the commit stays reachable.

## Why the protected role is unchanged

The [transition review on #382](https://github.com/techrote/cybersand/pull/382#issuecomment-6641279608)
compared the file at #382 head `12e4043e9aff41a9ecba21e79c00e3a1aefa0c49`
against the baseline. A separate read-only reviewer confirmed its claims:

- Only `prepare_pressure_tick` and `compute_pressure_heads` change. The P1 diff
  against main (whose bytes equal the baseline) has 59 insertions and 6
  deletions; every hunk lies in those two functions.
- `physical_state_hash` and its implementation, `liquid_comparison_hash`,
  `save_physical_state`, `restore_physical_state`, the codec helpers,
  `pack_transport`, `update_water_pressure`, `resolve_gas_topology` and
  `reset_pressure_cell` are byte-identical. The hash and codec encode their
  fields individually and read none of P1's wake state.
- No policy read or refusal sits in a changed hunk.
- P1b's same-chunk indexing gives the same chunk and index as `World::address`
  plus `find_chunk`, including negative coordinates, so material, gas and head
  reads are unchanged.
- The other 26 locked files are byte-identical, and the catalogue
  (`82b5ab9a…fdbad3`) and capability (`33c608f8…6e237`) digests are unchanged.

Hosted Native C++ validation run 41899419313 at `12e4043e` passed on all six
families, including `LCB-001 pressure physical hash and exact persistence`.

The reviewer's caveat stands: wake elision is exact only if every writer of
head, gas, flow, overfill or material clears the wake bits. That is P1's own
correctness, covered by `test_pressure_wake_summaries` and the cached-versus-
reference parity tests ([P1 evidence](2026-11-04-lcb201-p1-wake-summaries.md)),
not part of the lock's role.

## Admission check

`python tools/material_catalogue/compatibility.py --check` on #382's branch
reports `PASS` with this single entry in `reviewed_transitions`. The exact-head
hosted Documentation/provenance result is recorded on #382.
