---
title: PF471 neighbour cursor — reviewed linear MAT-AUTH transition after HS-PKT
status: Current
document-kind: audit
scope: Independently accepted final world.cpp transition for PR #471 after merged PR #470; frozen compatibility lock unchanged
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-06-fast-neighbour-cursor-draft.md, 2026-11-06-hard-surface-packet-incremental.md, 2026-11-04-mat-auth-reviewed-transitions.md, ../operations/material-catalogue-shadow.md]
---

# PF471 reviewed linear transition after HS-PKT

## Disposition

**ACCEPTED AND CODE-PINNED.**

PR #470 landed first on main at merge commit
`3d953ed1c1f5bd0bcf582359d47863689b9e2310`. PR #471's neighbour-read cursor
was then three-way merged on top in
`484b48f67ba4db68b1b4c73cd63f1a187594523d`.

Independent combined review [#492](https://github.com/techrote/cybersand/issues/492)
returned **ACCEPT**. The frozen catalogue compatibility lock is unchanged.

## Final protected transition

| Field | Value |
|---|---|
| Protected path | `native/src/world.cpp` |
| Protected role | legacy movement, chemistry, thermal and scheduling authority |
| From accepted LF SHA-256 | `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb` |
| To combined LF SHA-256 | `e23935738a1424b6e0009ae935e6f79fdc0d56c4162766061acb0ae2ec3de6ee` |
| Source commit carrying exact combined bytes | `484b48f67ba4db68b1b4c73cd63f1a187594523d` |
| Review issue | #492 |
| PR | #471 |
| Frozen lock | unchanged |

The earlier branch-only #471 proposal
`5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d`
→
`bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868`
at `b51f01536db6408458442c532d75256d33422fba` was independently accepted in
#485, but it is **not** part of the final main-line transition ledger because
#470 landed first. Its review remains historical evidence for the isolated
cursor implementation.

## Composition proof

The merge used shared #406 source
`4a80af2a891332176a3912a235582d77d076a185`, accepted #470 main, and #471's
source commit `b51f01536db6408458442c532d75256d33422fba`.

A line-level three-way comparison found **zero overlapping base hunks** between
#470 and #471 in both:

- `native/src/world.cpp`;
- `native/include/cybersand/world.hpp`.

The final main→combined production diff is exactly the neighbour-cursor delta:

- `native/src/world.cpp`: 87 insertions, 35 deletions;
- `native/include/cybersand/world.hpp`: 4 insertions, 2 deletions.

No #470 hard-surface hunk is replaced by the cursor application.

## Protected-role review

The combined review confirms:

1. `KernelReadCursor::visible` keeps transient-body masks authoritative before
   any material read.
2. Signed-coordinate gap arithmetic is overflow-safe and only admits bounded
   same-chunk reads; all other reads fall back to `stored_material`.
3. Material values are loaded live on each cursor call, so mutations are not
   hidden by caching.
4. Heap-owned chunk lifetime and phased worker ownership remain valid.
5. Pending reaction wake, chemistry predicates, movement/write paths, epochs and
   scheduler geometry retain their existing semantics.
6. #470 hard-surface mutation detection, tile invalidation, revision advancement,
   job-effect merge and transactional invalidation retirement are untouched.
7. Material identity, policy admission, physical hashes and CYPS persistence are
   unchanged.

## Qualification evidence

The isolated #471 campaign
[42313096990](https://github.com/techrote/cybersand/actions/runs/42313096990)
completed:

- ordinary native suite: **188/188 PASS**;
- full native suite with `CYBERSAND_VERIFY_LOCAL_NEIGHBOUR`: **188/188 PASS**;
- strict ASan/UBSan: **188/188 PASS**;
- strict TSan: **188/188 PASS**;
- signed/mask/chunk-seam/missing-residency adversary: exact at 1/6 workers;
- three same-host A/B/B/A stress cycles: exact hashes/work counts and a
  six-worker median candidate/parent ratio of **0.97940**.

The prior integrated source on lockstep main also passed the complete Native
workflow and all 21 source-matched Linux Godot shards before #470 landed.
The final combined source must still pass its own resulting-head gates and
receive new source-matched retained runtimes before merge.

## Admission boundary

`tools/material_catalogue/compatibility.py` admits exactly the final transition
above. No lock refresh is permitted. Runtime publication/provenance is a separate
gate and cannot be satisfied by either #470's or the earlier #471-only binaries.
