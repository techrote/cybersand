---
title: Combined hard-surface packet and fast neighbour-cursor integration
status: Current
document-kind: evidence
scope: Exact mechanical composition of independently reviewed PRs #470 and #471 on main with source-locked MAT-AUTH successor; runtime release separately gated
canonical-for: []
last-reviewed: 2026-11-07
related-documents: [2026-11-06-hard-surface-packet-incremental.md, 2026-11-06-fast-neighbour-cursor-draft.md, 2026-11-07-pf471-world-transition-proposal.md, ../architecture/simulation-tick-and-threading.md]
---

# HS-PKT + neighbour-cursor combined integration — 7 November 2026

**Disposition: combined source candidate, not a retained-runtime release.**

## Source and merge identities

| Source | Identity |
|---|---|
| Current main at branch preparation | `4c2c97323d862afdd3ec6730017127cc8e4ec05c` |
| HS-PKT reviewed parent | `9155dec83fa8cca79d309ba7dccb8fc773b5cb7c` (PR #470) |
| Cursor reviewed parent | `aab74cd8ff2dad3a34243f5d477c29532750550c` (PR #471) |
| Two-parent source composition commit | `7966ca05e8f430cda99bb57555cde8e89aa3f8af` |
| Combined `native/src/world.cpp` LF SHA-256 | `e23935738a1424b6e0009ae935e6f79fdc0d56c4162766061acb0ae2ec3de6ee` |
| Combined source PR | [#489](https://github.com/techrote/cybersand/pull/489) |

The merge commit preserves both implementation histories. The source code was
reconciled using the exact #471 PR cursor hunks, applied to the accepted #470
native implementation, with no rejected or ambiguous hunks. On the untouched
current-main native files, the same hunks reproduce #471's bytes exactly.
Both source-parent LF hashes were recalculated before composition and matched
their reviewed targets:

- #470 last admitted `world.cpp`: `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb`
- #471 source-review accepted `world.cpp`: `bbd9741311bc67905934048633846b8d011efd760033edd0ff9e88be5b262868`

No change was made to the frozen material compatibility lock, material IDs,
physical state serialization, solver policy/defaults, or Rapier authority.
The separate PR-specific runtime-publication workflows were not copied into
the combined source tree: a release, if admitted, must use **one** exact-source
binary custody chain, not two branch-scoped publishers.

## Combined protected-source change and review boundary

The protected native change is the **mechanical union** of two independently
reviewed execution-only optimisations, with no overlapping source hunks:

1. HS-PKT `World` direct/job-effect hard-tile invalidation. It does not
   consume render dirtiness; tile collection is transactional before ACK.
   The Godot adapter reuses unchanged 64×64 rectangle lists and recovers a
   cold/full mask after an interrupted packet commit.
2. `KernelReadCursor` replaces repeated in-chunk visible material lookups in
   rule kernels and pending-reaction wake inspection. It tests transient
   body masks first, reloads current cell bytes on every access, and falls
   back to ordinary stored-material lookup outside its existing source chunk.

No changed line of the cursor patch overwrote a HS-PKT change; `world.hpp`
changes were likewise a nonoverlapping mechanical composition. Both of their
source commits remain ancestors of `7966ca05e8f430cda99bb57555cde8e89aa3f8af`, including the independent
MAT-AUTH evidence recorded for #470 and the #485 review of #471.

### Code-pinned reviewed transition

The existing code-pinned `native/src/world.cpp` chain ends with #470's
second protected source transition:

`d743ca60406fc8f220206e005b37996f1d182005b1b86e0ed6591f050608fe1c`
→ `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb`
at `9ad76b21854b3e44fc9444f8293d3c36c619746b`.

The combined successor admits the mechanical union:

- `path`: `native/src/world.cpp`
- `from_lf_sha256`: `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb`
- `to_lf_sha256`: `e23935738a1424b6e0009ae935e6f79fdc0d56c4162766061acb0ae2ec3de6ee`
- `source_commit`: `7966ca05e8f430cda99bb57555cde8e89aa3f8af`
- `record`: `docs/audits/2026-11-07-hs-pkt-neighbour-integration.md`
- `issue`: #485
- `pr`: #489

The previous #471 individual review target is **not** inserted as a conflicting
second transition from `5a9de5e0…`. Its accepted source is an ancestor of this
merge and its unchanged implementation is included in the combined source.

## Qualification and publication

The predecessor PR #470's 190-test Native normal/ASan/UBSan/TSan and
source-matched Linux/ephemeral Windows Godot collider byte oracle passed. The
predecessor PR #471's normal/oracle/ASan/UBSan/TSan 188-test suites passed,
as did its signed-boundary/mask adversary and stress A/B/B/A with ~2% native
six-worker improvement. **These individual receipts are not a substitute for
execution of the resulting combined source.**

The combined PR requires exact-head MAT-AUTH, all Native families, full Linux
Godot, source-matched Windows candidate (or approved retained Windows runtime)
and relevant lockstep plus hard-surface/cursor regressions. The source-sensitive
retained runtime checks remain fail-closed until the new extension is rebuilt,
attested and published under canonical provenance. No LFS runtime pointer or
historical provenance hash is fabricated here, and no binary is published by
this transition.
