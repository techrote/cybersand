# WORKBENCH-HOST-CLAIMS-001 — native landscape qualification

Date: 20 November 2026. Repository: `techrote/cybersand`.
Integration: existing Draft/HOLD [PR #680](https://github.com/techrote/cybersand/pull/680).
Original implementation head: `a283cb4a08e94e39540e1b617054ac0eb37afb59`.
Accepted parent: `de109d0131641d6adc8d25bb9ced7ca3d4991105`.

## Disposition and exact-source receipts

The existing bounded implementation is retained. Source investigation and an
independent review found no production correction necessary. This finisher adds
meaningful source/native regression coverage, real authored-map qualification,
an independently checked evidence reducer and a portable Windows evaluation lane.
Native code, material laws, constructor limits and runtime publication manifests
are unchanged. Keep Draft/HOLD; no merge, Ready transition or auto-merge.

This initial checkpoint records local source-delta qualification below. The
workflow and local runner write the exact committed source and tree, complete
execution-input hashes, unchanged native build source, loaded binary hashes,
Godot identity, commands, exit statuses and raw-report hashes in
`qualification.json`. Final committed-head Linux/Windows results and the
independent final disposition must be attached to the PR; do not interpret an
earlier runtime publication or a skipped Draft gate as this host's qualification.

## Source authority and the bounded repair

`CyberMicroScenarioHost.install` first calls `Contract.validate`. Every rectangle
is checked, the full normalized definition is retained and its canonical SHA-256
is computed. The complete ordered five-word rectangle array still enters native
`prepare_liquid_world`, whose geometry/material/extent/capacity checks remain
independent. Native preparation precedes the observation projection.

Only Workbench claims with more than 32,768 **words** omit the redundant
`definition.rectangles` value. The record names the omitted field, encoding,
exact integer-word and rectangle counts, complete-definition SHA-256, reason and
explicit `unverified_host_claim_projection` status. Non-Workbench observations
and below-boundary Workbench observations keep their existing strict behavior.
Native and host full-match eligibility remain false. A digest in an unverified
claim is not substituted for validation, native execution or acknowledgement.

The physical continuation still binds its entire frozen original command. Only
successful native/owner commit publishes the staged host identity. Invalid input,
observation refusal and a vetoed final commit preserve the installed World and
host cursor. Setup-v2 and generated-start reconstruction keep their formats and
full source geometry; Save start does not serialize evolved simulation state.

## Runtime identity

Both retained native manifests contain exactly 95 native source/header inputs;
all match this branch. They describe their original build from
`e8c3aa6afd6ea2d53e1dab82cbb5b2c2e474b156`, published by the accepted Wave
Waterwall lane. Historical host-script observations are not relabeled as current
host execution. The new runner checks the current host separately.

| Runtime | Bytes | SHA-256 |
|---|---:|---|
| Linux CyberSand | 4,734,408 | `3b373d944fcbe6c7db42a39617c800917603fe8abe8ad21e2ba422945c54cfe7` |
| Windows CyberSand | 5,271,040 | `926e164a11274fe02f3aa2ff41527dae102803a30685a5d7480ad0aa9840d165` |
| Linux Rapier | 117,275,416 | `566e68ae53bfb2eb7018c8e7d0dd3727121bf696462039b780a33d6b8369c66a` |
| Windows Rapier | 9,987,072 | `b54e54bd1a03ae9094b788bf869212b5405b4a04793792d5a7cd81632cb10dd7` |

Pinned engine: `4.7.stable.official.5b4e0cb0f`. Linux executable SHA-256:
`f85bbc6b15e22416c7d797cd60b63286dd67b9cb13498847056c18520ae55a75`.
The actual Linux adapter reports and executes the existing 32,768-rectangle
budget. These results do not upgrade an old installed 4,096-record DLL.

## Boundary and adversarial tests

`test_workbench_host_claim_capacity.gd` now uses complete valid schema-2
definitions and real canonical digests rather than fabricated minimal values.
The pinned Linux run passes **95 assertions**. It checks 6,553, 6,554, 9,167,
13,839 and 32,768 accepted source rectangles; 32,769 refusal; malformed geometry
in the omitted tail; record arity and forged count metadata; invalid source
digests; order/material-sensitive full identity; original definition/native-input
immutability; unchanged fill/extent limits; and non-Workbench controls.

`test_workbench_host_claim_native.gd` passes **110 assertions** with a report
requested. All five accepted counts install through the real host and native
constructor at 2048×1024. Each complete LE16 stored-material plane equals its
independent expected plane. An independently encoded prepared-setup-v1 digest
binds the full canonical source claim and actual native payload. Falling Sand
moves during four actual native ticks in every case.

Direct native negatives include 32,769 rectangles, incomplete records, invalid
geometry/material/digest length, unsupported dimensions/response and ordinary
4,097-record construction. Ordinary 4,096 remains accepted. Refusals retain the
old physical hash, generation, revision, tick, receipt and host record. A valid
large candidate reaches a real commit guard and is vetoed; the token is discarded
and cannot subsequently commit. The old World advances again after every case.

## Dynamically discovered authored maps

The discovery snapshot found 53 open `sandmapsreference` PRs, including 45
original wide Draft/HOLD PRs containing 46 current authored 2048×1024 maps.
Twenty current maps exceeded 6,553 rectangles. One retained earlier Setup was
inspected separately and excluded from the current count. Independent replay
found exact source/coalesced counts, no overlaps and no malformed bounds in all
47 inspected Setup files. Graftloom was the highest-count current source.
The committed manifest preserves the full discovery roster and exact file/grid
identities; it is evidence of this snapshot, not a permanently frozen creator
roster or admission restriction on future maps.

| Map | Rectangles | Map PR | Exact authored HEAD |
|---|---:|---|---|
| Graftloom Slipway R6 | 13,839 | [#22](https://github.com/techrote/sandmapsreference/pull/22) | `b0d1e5216aabb9b5e009e599ffbffcec6fd8a657` |
| Nacre Spindle Court | 9,084 | [#38](https://github.com/techrote/sandmapsreference/pull/38) | `46e047d46dc067f79da8907e5e91b224c9e8cc17` |
| Graven Keel | 6,572 | [#45](https://github.com/techrote/sandmapsreference/pull/45) | `7ce39e6eb6d701b515bd4f6b1ccea551bf467a2f` |
| Kestrel Counterweight Works | 6,455 | [#53](https://github.com/techrote/sandmapsreference/pull/53) | `fc27754defff1f8501b256543d658a83f992da62` |
| The Long Pour | 4,092 | [#25](https://github.com/techrote/sandmapsreference/pull/25) | `9d38064137c1c3be1073d204967e658e8e2235a6` |

No live selected source had exactly 9,167 rectangles; that exact count remains
covered by both synthetic regressions. All external authored bytes remain
unchanged. Their source PRs, branches and state were not modified.

## Ordinary Workbench execution

`qualify_workbench_landscape.gd` loads the normal Main/Shared Workbench and its
threaded native owner. Only deterministic keyboard input is supplied through the
existing leased actor-control interface; the World, native preparation, physics
space, body, actor controller, brush and save APIs are real.

All five local source-delta install and reopen processes completed successfully.
Each install compares every one of the 2,097,152 cells with an independent stamp
replay, first through read-only native stored-material LE16 capture and then
through the material publication. `material_capture_finish(token,false)` releases
the read-only slot without Flatten, history adoption or World replacement.

Each process verifies the full installed source digest, exact projection counts
and committed native extent/body/receipt. Midge moves with nonzero applied
control force while both native and Rapier clocks advance at least 60 ticks.
Malformed geometry and a real invalid native-policy replacement are then refused
while preserving the old World generation, physical epoch, accepted Setup and
actual actor owner; play advances at least another 20 ticks afterward.

The install process restores the authored start, paints a small hard-wall disc,
erases its centre, checks all native stored cells again, and uses ordinary Save
start. The application closes. A fresh Godot process uses ordinary Load start,
verifies every original rectangle plus both edits, checks the exact saved grid
and starts actual Midge/native/Rapier play again. Distinct process IDs and
unchanged saved-file SHA-256 bind the pair.

The Python reducer independently reconstructs both source and saved geometry;
its integer-circle replay is separate from the GDScript test and constructor.
It rejects a missing/incomplete report, wrong source/capacity/count, different
native LE16 plane, absent gameplay progression, altered save or source/runtime
changes during execution. Long Pour's Water/Lava may evolve while playing;
full-grid equality is required before dynamics and after fresh authored-start
reconstruction, not against evolved live cells.

## Preserved development failures and independent gaps

The first exact-source pure run passed 21 assertions with native LFS pointers
still unmaterialized; it was only a pure source test. The pinned native tests
above ran after actual libraries were materialized and verified.

Two early new-harness attempts stopped on test-side representation mistakes:
JSON floats versus canonical Setup integers, then tagged observation integers
versus raw integers. Both were corrected without changing production code.
The first five-map Python process loaded an older reducer and wrongly compared
the edited reopened grid with the unedited source. Its ten native processes
passed; the campaign correctly remained failed. The repaired reducer separately
replayed each saved file and passed those raw records. Fresh committed-source
campaigns are required for final qualification; the old failure is not rewritten.

Map-art and specialist static reviews remain independent: Graven's README had
stale R2 counts despite correct R3 Setup bytes; Nacre and Kestrel retained their
separate technical/PNG review work. These are not host-admission failures.
The admission scheduler's latest inspected run was complete and its prompt
treated the CyberSand engine as read-only, so it was not a competing branch writer.

Physical Windows/NVIDIA display feel, manual collision/play acceptance and any
unrun broad Draft-gated CI remain explicit owner/final acceptance boundaries.
The portable package's ordinary launcher and extracted-project execution are
separate from a claim of human playtest acceptance.
