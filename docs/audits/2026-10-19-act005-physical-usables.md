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

Pending focused implementation tests, ACT-004 regressions, applicable native and
sanitizer execution, independent review, and exact-head GitHub-hosted merge gates.
Windows cross-build/inspection will be recorded separately from interactive
Windows execution. No owner feel acceptance or browser qualification is implied.
