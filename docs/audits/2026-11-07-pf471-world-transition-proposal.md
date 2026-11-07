---
title: PF471 neighbour cursor — unadmitted MAT-AUTH world.cpp transition proposal
status: Current
document-kind: audit
scope: Independently accepted and code-pinned MAT-AUTH transition for PR #471; frozen compatibility lock unchanged
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-06-fast-neighbour-cursor-draft.md, 2026-11-04-mat-auth-reviewed-transitions.md, ../operations/material-catalogue-shadow.md]
---

# PF471 reviewed transition for `native/src/world.cpp`

**Status: ADMITTED BY REVIEWED_TRANSITIONS; RUNTIME PUBLICATION STILL SEPARATE.**
Independent read-only MAT-AUTH review [#485](https://github.com/techrote/cybersand/issues/485)
returned **ACCEPT** on 7 November 2026. The frozen compatibility lock remains
unchanged; this record authorizes only the exact protected bytes below.

| Field | Proposal |
|---|---|
| Repository / PR | `techrote/cybersand` / [#471](https://github.com/techrote/cybersand/pull/471) |
| Review issue | [#485](https://github.com/techrote/cybersand/issues/485) |
| Parent source | #406 / `4a80af2a891332176a3912a235582d77d076a185` |
| Protected path / role | `native/src/world.cpp`; legacy movement, chemistry, thermal and scheduling authority |
| Previously admitted LF SHA-256 | `5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d` |
| Candidate LF SHA-256 | `bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868` |
| Exact source commit introducing candidate bytes | `b51f01536db6408458442c532d75256d33422fba` |
| Candidate blob identity | Git blob `dcacf99d62c472becd929617f4a7034f889aaeb9`; unchanged through qualification descendants |
| Frozen lock/baseline | **Unchanged** |
| Admission | **ACCEPTED — #485; code-pinned REVIEWED_TRANSITIONS entry** |

## Protected-source delta

The implementation commit changes only two production files relative to the
pinned #406 parent: `native/include/cybersand/world.hpp` (4 insertions,
2 deletions) and protected `native/src/world.cpp` (87 insertions, 35 deletions).

The protected change:

- introduces stack-local/read-only `KernelReadCursor`;
- rechecks `transient_obstacle_at` before every fast read, preserving
  `World::get` visible-mask authority;
- uses the already resolved source chunk only when signed deltas fit the bounded
  local neighbourhood and resulting local coordinates remain in the chunk;
- falls back to `stored_material` at chunk boundaries, missing chunks and any
  out-of-range read;
- replaces visible material reads in `update_rule_kernel` and the pending
  reaction wake scan, without caching material values across mutations;
- does not edit movement/write primitives, material catalogue or pair tables,
  PressureFlow/IN sidecars, physical hashes, CYPS codecs, scheduler topology,
  activity ownership or job-effect reduction.

Compile-time `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR` independently compares every
executed fast same-chunk load with `World::get` and terminates on disagreement.

These observations were independently reviewed in #485 and accepted as execution-only.

## Actual qualification attached to the proposal

[Actions 42313096990](https://github.com/techrote/cybersand/actions/runs/42313096990)
on GitHub-hosted Ubuntu 24.04 / GCC 13.3:

- ordinary native suite: **188/188 PASS**;
- native suite with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR`: **188/188 PASS**;
- strict ASan/UBSan: **188/188 PASS**;
- strict TSan: **188/188 PASS**, no race report;
- signed-coordinate, transient-mask, chunk seam/corner and missing-residency
  adversary: exact parent/candidate result at 1 and 6 configured workers;
- 6-worker adversary observed four actual participants;
- repeated exact-parent/candidate stress A/B/B/A: every state hash, physical
  hash, visited/moved count and scheduled-core count matches.

Six-worker timing cycles:

| Cycle | Parent mean | Candidate mean | Ratio | Improvement |
|---:|---:|---:|---:|---:|
| 1 | 37.290 ms | 36.382 ms | 0.97566 | 2.43% |
| 2 | 37.751 ms | 36.973 ms | 0.97940 | 2.06% |
| 3 | 37.738 ms | 37.017 ms | 0.98089 | 1.91% |

Median six-worker ratio is **0.97940**. The performance claim is deliberately
narrow: a modest native material-kernel improvement on the stress-derived
fixture, not a Godot/Rapier FPS result.

A source-line `perf` attempt in
[42315420376](https://github.com/techrote/cybersand/actions/runs/42315420376)
was refused by the GitHub-hosted kernel with `perf_event_paranoid=4`.
No privileged runner or policy weakening was used.

## Independent review questions

The reviewer should independently verify:

1. same-chunk local-index arithmetic including signed/extreme coordinates cannot
   redirect a read or overflow;
2. transient masks have identical precedence to `World::get`;
3. material mutations earlier in a kernel remain visible because values are not
   cached;
4. cross-chunk and nonresident positions retain exact Empty/material semantics;
5. the pending-reaction wake scan observes identical material state;
6. worker ownership/lifetime is valid for the source chunk pointer throughout a
   phased job;
7. the change does not alter the protected path's material identity, policy,
   physical-hash, persistence or scheduling authority.

The independent review is complete and the code-pinned transition entry now
admits exactly this path/hash/source-commit/record/issue/PR tuple. The current-main
reconciliation preserves `b51f0153...` in two-parent ancestry. Exact resulting-head
Native/Godot/provenance qualification remains mandatory before merge.

**This admission does not publish or authorize stale retained runtime artifacts.**
