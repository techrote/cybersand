---
title: ACT-005 / USABLE-002 physical equipment integration and acceptance
status: Current
document-kind: audit
scope: Issue 182 implementation checkpoints, source and runtime identities, focused regression results and exact-head hosted acceptance
canonical-for: []
last-reviewed: 2026-10-19
related-documents: [../systems/physical-actor-rigs.md, ../systems/actor-usables.md, ../systems/thunderbowl-control-reference.md, ../operations/github-development-and-release.md]
---

# ACT-005 / USABLE-002 physical equipment integration

## Authority and work in progress

The owner requested completion of [issue #182](https://github.com/techrote/cybersand/issues/182)
and recoverable progress in the repository at least every thirty minutes during
active work. Work began on 2026-10-19 at 00:31 UTC on
`codex/issue-182-physical-usables`.

The source baseline is USABLE-001 PR #180 head
`64b2e264f3778a8d74e47b264bd6885f42a26a36`, which already contains the ACT-004
mainline merge `f2e34cf9b6fbaa5d9dedf9aa2cbc721a87472497`. It preserves all 32
U01-U32 catalogue entries alongside the 41 articulated actor mechanisms. Its
sampled equipment path remains a compatibility reference; physical integration
is the implementation owned by this issue.

## Implementation boundaries

Rapier bodies, mount ownership, aiming and recoil remain main-thread owned.
The simulation worker exclusively owns native material edits, sparse projectile
progression and processor recipes. Copied physical frames, requests and result
receipts bind those owners. Controllers share the physical actor's issued
observation and bounded lease admission; no producer writes bodies or native
cells directly.

Every actor has a defined demonstrative loadout. Release and pickup retain the
same physical body and stable coupling slot. Pending action cancellation and
already committed autonomous effects have separate lifetimes; reset retires
both with the world/session identity.

## Checkpoints

### 2026-10-19 00:37 UTC — reconciled baseline and ownership

- Read live issue, main, PR #180 and ACT-004 source and acceptance contracts.
- Created an isolated branch from the reconciled source; required LFS runtimes
  materialized without modifying dependency pins.
- Independent review identified weak sampled command freshness, sampled AABB
  origins, logical-only processors and asynchronous stale-receipt handling as
  the principal integration risks.
- Began parallel physical-owner and cellular-owner implementation, plus authored
  loadouts, scripted control, course integration and regression preparation.
- Implementation and hosted acceptance are in progress; this checkpoint does
  not claim that the issue is complete or validated.

## Validation record

### 2026-10-19 00:44 UTC — first published checkpoint

Published commit `5e5ee12c0fe3314cdc1c1421d80be41cd8a83837` on the issue branch
and opened draft [PR #183](https://github.com/techrote/cybersand/pull/183).
This checkpoint contains all 41 explicit loadouts, the shared script producer
integration and this authority record. The 32 usable IDs all appear in the
authored default loadout coverage.

### 2026-10-19 01:13 UTC — physical/worker and course integration checkpoint

Implemented the real held equipment body, local release/reattach, independent
mount aiming, incarnation-checked requests and receipts, native per-part source
occlusion, actual deployed processor ownership, all 32 equipment selections in
the desktop and a separate eight-section usable course. The copied worker frame
and matching body states are admitted atomically. Cancellation retires pending
work, while committed payloads remain autonomous until reset or expiry.

Source review and the first integrated runs exposed and corrected overlapping
source-mask attribution, aim-limit branch oscillation, late cancellation,
processor read-budget atomicity and early payload activation incorrectly gated
by launch resources. Ground, flight, and heavy delivery examples have exercised
the real runtime. Digger targeting is still being tuned against protected floor
geometry; this checkpoint is not the acceptance head.

The course processor test has exercised physical drop, free fall, settling and
fixing; blocked output without intake consumption; an authored Stone-to-Sand
cycle; and approach/pickup of the same body. A first Linux OpenGL/llvmpipe render
confirmed the production course and all 32 picker entries. Overlay clipping,
labels and equipment power presentation remain under review.

### Local validation to date

The pinned runtime is Godot `4.7.stable.official.5b4e0cb0f` on Linux with the
retained native GDExtension and Rapier. All 37 native source-sensitive input
hashes match the retained runtime provenance; this change currently modifies no
native source or dependency pin. Tests use writable isolated XDG directories and
the actual native/Rapier extensions, with 90-second focused-test timeouts.

| Scope | Result at this checkpoint |
|---|---|
| Frozen baseline native core | 71 tests passed |
| Frozen baseline ASan/UBSan | 71 tests passed; 64 MiB stack, leak detection disabled |
| Frozen baseline TSan | 71 tests passed; 64 MiB stack |
| Existing U01–U32 / session / desktop integration | 196 / 28 / 29 assertions passed |
| New physical native runtime / worker admission | 243 / 35 assertions passed |
| New physical equipment / lifecycle | 229 / 36 assertions passed before final aim additions |
| Existing physical session / desktop integration | 113 / 354 assertions passed |
| Raw ACT-004 articulation | 41 rigs × 1,200 ticks passed; raw actuation 86 assertions passed |
| New copied-observation equipment scripts | 3,993 assertions passed before final targeting additions |
| New real desktop physical equipment integration | 28 assertions passed |
| Documentation / M11 / materialized runtime identity | Passed; final exact-head rerun pending |
| Retrieval | Frozen 32/32 hit@5; all 70 prior challenges retained, three new challenges hit@5 |

Baseline command logs and local screenshots are temporary validation evidence;
the source audit, regression code and repository commits are the recoverable
record. Final integrated tests, visual corrections, independent review and
exact-head hosted merge gates are pending. Windows cross-build/inspection will
be recorded separately from interactive Windows execution. No owner feel
acceptance or browser qualification is implied.
