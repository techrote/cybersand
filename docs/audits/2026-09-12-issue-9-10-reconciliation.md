---
title: Issue #9 and #10 source/evidence reconciliation
status: Current
document-kind: evidence
scope: Current-source prerequisite acceptance for issues #11 and #12
canonical-for: []
last-reviewed: 2026-09-12
related-documents: [2026-09-09-physics-characterisation.md, 2026-09-09-issue-10-granular-policy.md, ../systems/granular-interaction-policy.md, ../operations/physics-characterisation.md]
---

# Issue #9 and #10 source/evidence reconciliation

## Decision and identity

- **#9: implementation/evidence complete enough but documentation stale
  (category B).** Deterministic fixtures, bounded diagnostics and a recoverable
  dated baseline are present. Measurements for later-changed mechanisms are
  historical, not current acceptance.
- **#10: confirmed complete (category A).** Current source has a coherent
  material-aware sampled-player support policy and a distinct deterministic
  powder/liquid exchange policy. Current native regressions and later
  source-matched desktop/Web evidence cover the downstream claims.

GitHub closure was not treated as runtime acceptance. No issue state or physics
source was changed.

The inspected repository is `https://github.com/techrote/cybersand.git`. This
worktree began clean at `fc4d15d9c0d673e78f9baa4acf7500f28282196a` on
`codex/issue-9-10-reconciliation`. It contains #9 commit `10e8153`, #10
support commit `1fba848`, #10 exchange commit `372bfb3`, and later #13 and
Water-leveling work. Subsequent first-parent changes through this revision are
documentation or agent configuration.

The #9 report binds Windows/Godot/Web evidence to source/artifact manifests and
records 2,496 runs over 8,047,080 ticks. The #10 report binds 52 native tests,
21 Godot runners, 1,070 native matrix runs, 257 player runs, desktop checks and
both Web profiles to its manifests.

Two requested inputs were unavailable: `docs/operations/agent-orchestration.md`
is neither tracked nor present under `C:/kybersand`; live private issue bodies
could not be read because GitHub CLI authentication was absent and browser control
failed to initialize. The current source ledger's prior live readback confirms
#9/#10 closure on 2026-09-10. The task's acceptance statements, current contracts
and dated issue audits supplied the substantive criteria. This limits live
metadata verification, not the source/runtime findings.

## #9 reconciliation

1. **Fixtures:** present. The native bench, Godot runner and `tools/physics`
   tooling cover P1/P2 powder/liquid and packed-powder cases, P3 player cases,
   P4 depth/creep/contact cases and P5/P6 scheduling, excavation, re-entry and
   controls. Worlds are fresh with explicit seeds and tick bounds.
2. **Telemetry:** present and bounded. Fixed per-job/global buffers report overflow
   and separate Empty moves, density swaps, reactions/conversions, Water transfer,
   rejected moves, body displacement and contacts.
3. **Identity:** the 2026-09-09 report, manifests, source snapshots/patch and
   `10e8153` commit bind source, artifacts, platform, workers and fixtures.
4. **Mechanisms:** clearly separated: density exchange versus Empty movement and
   chemistry; hard terrain versus player powder support; granular packing versus
   body feedback; exact global accounting versus crop loss from barrier ejection.
5. **Staleness:** old powder/powder reorder, single-material player support and
   Mercury rates were superseded by #10; Water front/erosion traces by the later
   Water checkpoint. Barrel sinking, masked-source and thin-barrier ejection remain
   defect baselines, not acceptance. The current masked-source regression passes;
   separate #11 reconciliation commit `5ebc025` reproduced ordinary-Sand floor
   contact.
6. **Material gaps:** none capable of invalidating #10/#11/#12 decisions.
   Multi-barrel loading, general shapes/torque and actual bearing belong to #11;
   #10 later supplied the shared moving-barrel case.

The old #9 audit's “remains open” sentence is administratively stale and remains
untouched as immutable dated history.

## #10 reconciliation

1. **Shared policy:** `World::granular_support_at` is the shared material,
   packing and stability query. Downward support uses an 8/9 local threshold;
   side/up resistance additionally requires centered 9/9 enclosure.
2. **Player path:** `CyberNativeCellWorld::character_box_collides` calls that
   query; the fallback uses the same versioned parameters.
3. **Excavation:** support is queried from current cells, not cached. Native and
   Godot cases remove support cells and observe descent.
4. **Exchange separation:** `MaterialRules::can_density_exchange` explicitly
   excludes powder/powder pairs. Empty falling precedes the exchange gate, so
   void fall and avalanche remain functional. Powder/liquid eligibility is separate.
5. **Mercury slowdown:** the default 30-tick rate is enforced in
   `World::exchange_permitted` after pair eligibility and before the swap; it is
   not merely lateral viscosity.
6. **Sleep/wake:** delayed interactions do not stall. Each activity block retains
   its earliest `next_interaction_tick`; due included blocks wake, and 10/30/60
   cadence tests pass with one and four workers.
7. **Excluded regions:** deadlines remain while excluded. Re-entry wakes once and
   selects the next cadence boundary without replaying elapsed exchanges; the
   tick-2-to-200 exclusion test passes.
8. **Current evidence:** the focused current native suite passes 55/55, including
   support/excavation, ordered powder pairs and void fall, Mercury layer
   orders/lanes/sleep/re-entry/worker parity, exact accounting, F01/F02 and the
   masked-source baseline. The later Water checkpoint ran unchanged #10 controls
   through native, Godot and both Web profiles; later changes through the inspected
   revision do not alter these runtime paths.
9. **#11 blocker:** none missing from #10. #10 supplies capability/local packing,
   but intentionally not persistent body bearing, masked feedback or barrier-aware
   ejection.
10. **#12 blocker:** none missing from #10 for candidate eligibility or player
    semantics. Support-dependent stationary-proxy/one-barrel integration remains
    blocked by #11; player sampling is not a barrel bearing contract.

## Dependency acceptance matrix

| Dependency | Current status | Evidence | Downstream effect |
|---|---|---|---|
| #9 fixture/telemetry baseline | satisfied | P1-P6 tooling, bounded diagnostics, `10e8153` manifests; current diagnostics pass | Safe to reuse fixtures/event meanings; numerical outputs retain dated scope |
| #9 barrel characterization | satisfied but evidence stale | Historical P4 report; current masked-source test and separate #11 rerun corroborate the defect | Safe as a defect baseline, never as proof of support |
| #10 shared support policy | satisfied | `granular_support_at`, ADR-011, native/Godot acceptance | Safe for capability/local packing, not body bearing |
| #10 player support | satisfied | Adapter call path; all-powder, side/down and recovery tests | Safe for sampled-player scope only |
| #10 powder exchange | satisfied | Explicit exclusion plus ordered-pair and void tests | Safe; avalanche/Empty movement remain separate |
| #10 liquid/powder permeability | satisfied | Pair gate, both orders/initiators, Mercury controls, exact accounting | Safe at version-1 defaults |
| #10 excavation/support loss | satisfied | Current-cell query and excavation tests | Safe for player loss; body/proxy invalidation stays #11/#12 |
| #10 sleep/region behavior | satisfied | Deadline implementation, parity and re-entry test | Safe for delayed exchange without catch-up |

## Downstream authority

**#11 may rely on** #9 fixture geometry, bounded telemetry and separation of
contact, displacement, exchange and accounting; and #10 material capability/local
packing. #9 barrel results are only a historical defect baseline. Neither issue
proves persistent barrel support, correct masked-source feedback or barrier-safe
ejection.

**#12 may rely on** #9 deterministic fixtures/diagnostics and #10 powder-pair,
permeability, player-support, excavation and delayed-wake semantics. Candidate
design is unblocked by #9/#10. Stationary-proxy or one-island/one-barrel proof
depending on granular bearing is blocked by #11, not a #9/#10 deficiency.

## Focused current validation

Windows NT 10.0.26200 AMD64, Clang 23.1 (`ea7d852`):

```text
C:/kybersand/.local/llvm-mingw-20260826-ucrt-x86_64/bin/mingw32-make.exe test CXX=.../x86_64-w64-mingw32-g++.exe CC=.../x86_64-w64-mingw32-gcc.exe
```

Compilation succeeded. Make's immediate launch returned `0xC0000135` because
the fresh worktree lacked compiler runtime DLLs. After copying only generated,
ignored `libc++.dll` and `libunwind.dll` beside the executable,
`build/tests.exe` passed **55/55**. Its SHA-256 is
`6E49DDCE2FDD465C4E00C0A3F72903F09935FC0A0618CF208D6AB18BCE67000E`.

Source hashes before documentation edits:

- `native/src/world.cpp`: `F67EFB22B66AE4EEAD33FE3175B64985C80F31FF73E6D98DF048CA50DAE318C5`
- `native/src/material_rules.cpp`: `1C786BC843E7563511AF261DC7551CFD11D8832EB8054697045C73FE3E4C6D6E`
- `native/tests/test_world.cpp`: `B93D91DC2F209AE4F93DAF2BD1D12D0D77C0B2ACFD452CFE01403049BD4F5AD6`
- `native/include/cybersand/interaction_policy.hpp`: `D959A2EF74AFEE0F9C2F794EF5EE5362F1D8CFE6FC86A733ACF2A17FEC54D5FF`

This was one focused native suite, not a new Godot, Web, Linux or sanitizer
campaign. Other platform claims reuse only later source-matched records where the
relevant code is unchanged.

Documentation/repository checks were also bounded:

- `check_m11_consistency.py` passed all 18 records and 28 source hashes.
- Retrieval evaluation indexed 58 documents/421 chunks and hit a canonical route
  for all 32 questions at k (22 at rank 1; MRR 0.8229).
- In this requested `worktrees/<name>` layout, `check_docs.py` scanned the
  changed corpus without link/metadata errors but failed six frozen expected-fact
  paths because they resolve to `C:/kybersand/worktrees` rather than the companion
  workspace. The untouched `C:/kybersand/source` layout passes that check.
- `check_repository.py` retains the same 14 Windows/Linux extension rebuild
  requirements on the untouched source checkout. They predate and are unaffected
  by this documentation-only change.

## Closure and narrow follow-up

- **#9:** leave closed but annotate current limitations. The measurement/fixture
  objective is fulfilled; superseded behavior must not be treated as current.
- **#10:** leave closed. Its shared support/exchange policy is present and
  adequately evidenced for downstream use.

The remaining substantive package belongs to **#11**:

- **Defect:** no persistent powder bearing for the ordinary 8x14 mass-1 barrel;
  masked cells attribute contact through the Wall proxy; endpoint-only ejection
  can cross a one-cell hard barrier.
- **Required behavior/regression:** bound embed/creep without a hard floor,
  preserve support until excavation then release, attribute feedback to the stored
  source, and prohibit cross-barrier ejection while conserving cells. Retain the
  Sand support/excavation, masked-source and thin-barrier fixtures.
- **Dependencies:** #9 diagnostics/fixtures, #10 capability, ADR-007/009, F01/F02.
- **Non-goals:** #12 ownership transfer/soliding, general shapes/torque,
  multi-body retuning or a broad ballistics campaign.
- **Decision unlocked:** #12 support-dependent stationary-proxy and one-barrel
  integration can move from design assumption to runtime proof.
