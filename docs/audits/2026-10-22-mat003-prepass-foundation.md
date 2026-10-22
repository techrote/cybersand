---
title: MAT-003PREPASS first experimental checkpoint
status: Current
document-kind: evidence
scope: Initial source audit, isolated carrier correctness, local evidence and proposed GEN-006 handoff; issue 204 remains incomplete
canonical-for: []
last-reviewed: 2026-10-22
related-documents: [../operations/mat-003prepass-registration.md, ../research/mat-003prepass-state-inventory.md, ../research/mat-003prepass-epoch-consumers.md, ../research/mat-003prepass-gen006-handoff.md, ../reference/validation-evidence.md]
---

# MAT-003PREPASS first experimental checkpoint

## Outcome and acceptance boundary

**Implemented and locally verified: isolated S0 storage foundations.** All 17
registered arms pass optimized normal and AddressSanitizer+UndefinedBehaviorSanitizer
checks, with leak detection enabled in the successful run. Each configuration
executes 49,775,273 live assertions. Exact semantic records are compared across
representations, and real sixteen-bit **experimental primitive** counters run
through two natural rollovers. Production World storage and physics are unchanged.

This is a useful start on [#204](https://github.com/techrote/cybersand/issues/204),
not issue completion. No full-engine candidate, real-World epoch16 rollover,
performance ranking, Windows/Wasm qualification, live continuation codec or
production winner is claimed. The registered mandatory widths/representations
exist and have storage observations; their required World/performance comparisons
remain outstanding. #14/G-final and unrelated Water/soliding gates stay open.

## Recoverable source and registration

| Identity | Value |
|---|---|
| Planning and execution baseline | `da5112c066416346d6fe3984d4161cd162611e50` |
| Baseline tree | `167c9a04ed45fe84d30846865e8a77d78cdfd6ec` |
| Work branch | `codex/mat-003prepass-foundation` |
| Initial local registration, before carrier implementation | `101b72738cfa392aeaea141764baebba36a50cc4` |
| Published equivalent registration tree | commit `f6e16afed03b3df1e5c5f8de61fd1f5af187a285`, tree `b006ecb1077d3d6749cdd2e790d403068dcad05c` |
| Formal collection source identity | local registration amendment `34861647184a973ee659ad5f7b77643eee297720` plus exact nine-input SHA-256 ledger and source snapshots in `local-run-002.json` |
| Host | Linux x86_64; detailed kernel/Python/compiler identities in the run receipt |
| Compiler / linker | GCC 13.3.0 / GNU binutils 2.42, matching the Linux pin |
| Production binary treatment | Existing LFS pointers/provenance preserved; no extension build or runtime execution claimed |

The remote tree matches the issue's planning intake. The isolated checkout was
clean before changes; existing workspaces and their binaries were not modified.
Network Git was unavailable, so existing local Git objects were copied and the
latest GitHub commit object reconstructed and verified against its exact SHA.
The resulting tree and commit are the live pinned baseline, not an approximate
source export. GitHub connector publication has different commit metadata from
local registrations. Their exact raw Git commit objects are retained in
[registration identities](mat003-prepass-2026-10-22/local-registration-commits.json).

The version-2 [registration](../../tools/experiments/mat003_prepass/registration.json)
clarifies two independent 4,096-operation streams and freezes production-control
header hashes before formal normal/sanitized collection. This narrow correctness
amendment follows developer review; the initial registration remains preserved.
Neither version admits candidate performance timing.

## What was built

The isolated [carrier header](../../tools/experiments/mat003_prepass/carriers.hpp)
and [native fixture](../../tools/experiments/mat003_prepass/test_carriers.cpp) cover:

- The unchanged production `PrecisionStorage` source control and matched word64
  epoch8/16, plus logical64/physical16 padded controls.
- Packed72/80 with explicit 9/10-byte storage, naturally aligned word/tail72/80,
  and bounded chunk-owned split base8+tail1/2, all at epoch8/16.
- Full state_a16, raw high material storage bits, high tail bits, reserved-bit
  isolation, initialized logical storage, signed conversions and copy/assignment.
- Identical zero-extra streams across all widths; full neutral payload streams
  within each width; exact plain-field comparisons at every operation.
- Move/swap, synthetic split/merge/reaction reset, capacity refusal without
  source mutation, sidecar reclaim, and absent/unread/accessed clustered/dispersed
  occupancy. These are synthetic ownership operations, not material rules.
- Typed epoch counters/accessors, natural and forced primitive boundaries, and
  preservation of unrelated fields when clearing epochs.

The [collector](../../tools/experiments/mat003_prepass/run.py) copies immutable
inputs before compilation, records actual compiler commands/outcomes and hashes,
rejects production-control drift from the registered Git baseline, and refuses
existing output directories. The separate
[readback](../../tools/experiments/mat003_prepass/verify.py) checks artifact hashes,
binary identity, registered compile flags, complete arm coverage, layout/memory
framing, observed primitive clears, exact serialized records and independent FNV
reductions. Result JSON must equal retained process stdout. Scope flags explicitly
refuse World/timing qualification. Hashes establish identity, not authenticity.

Fourteen [evidence rejection tests](../../tools/experiments/mat003_prepass/test_evidence.py)
cover missing/duplicate arms, malformed records, truncated state_a framing,
incorrect rollovers, padding masquerading as packed storage, missing split costs,
hash tampering, path escape and skipped/failed results. Their fabricated unit-test
fixtures are never presented as observed experiment evidence.

## Observed physical costs and exact records

**Observed on this Linux x86_64 ABI:**

| Representation | Size / array stride | Alignment | Separate cost |
|---|---:|---:|---|
| Direct source / word64 | 8 bytes | 8 | None in this fixture |
| Packed72 | 9 bytes | 1 | None |
| Packed80 | 10 bytes | 1 | None |
| Natural72 or 80 | 16 bytes | 8 | Tail at byte 8; padding is not capacity |
| Logical64 padded | 16 bytes | 8 | No extra semantic capacity |
| Split72 | Base 8 bytes | 8 | Tail 1 byte/cell, separately allocated |
| Split80 | Base 8 bytes | 8 | Tail 2 bytes/cell, separately allocated |

The split fixture has four chunks of 16 cells and 72 bytes of descriptor/counter
overhead. This is fixture metadata, not measured production chunk overhead.
Full preparation allocates 64/128 tail bytes; occupancy controls separately report
allocated versus nonzero tail use. The fixture has no per-cell index/free list.
Allocator overhead, process peak RSS, real World optional fields/activity/scratch
and snapshots remain unmeasured. Do not treat the legacy aggregate resident-byte
counter as an extra component.

**Arithmetic only**, applying measured strides to fixed cell counts:

| Resident cell count | 8-byte array | 9-byte array | 10-byte array | 16-byte array |
|---|---:|---:|---:|---:|
| 512² | 2 MiB | 2.25 MiB | 2.5 MiB | 4 MiB |
| 1024² | 8 MiB | 9 MiB | 10 MiB | 16 MiB |
| 2048² | 32 MiB | 36 MiB | 40 MiB | 64 MiB |

These are cell-array calculations, not measured workloads or whole-process memory.
Split base+fully allocated tails have the same ideal 8+1/2 arithmetic plus their
separate ownership/allocation costs. No cache, bandwidth or speed conclusion is
drawn from size or test runtime.

The common zero-extra stream retains 320 exact bytes for 64 cells and matches
all 17 arms. Full-payload streams retain 320/384/448 bytes at 64/72/80 logical bits
and match all representations/epochs within each width. The semantic schema is
explicit little-endian material16, state_a16, state_b8, plus zero/one/two extra
bytes. Epoch, reserved bits and ABI padding are excluded from this semantic
stream but tested independently. Nonzero Empty state is included.

| Stream | Supplementary FNV1a64 |
|---|---|
| Common zero-extra and C64 full record | `e9c2ee918d5f2460` |
| C72 full neutral payload | `bc012997a879f318` |
| C80 full neutral payload | `60162d15a97ad63e` |

The [normal results](mat003-prepass-2026-10-22/normal.json) and
[sanitized results](mat003-prepass-2026-10-22/sanitized.json) preserve the exact
hex records and per-arm costs/counters. Digests are a convenience; actual byte
equality and the independent plain-field oracle are the correctness checks.

## Natural primitive rollover and its limits

Every arm runs 131,080 uninterrupted primitive ticks from zero:

| Counter | Clear count | First clear | Last clear |
|---|---:|---:|---:|
| Actual uint8_t | 514 | 256 | 131,071 |
| Actual uint16_t | 2 | 65,536 | 131,071 |

The E16 loop observes both expected clears and subsequent ticks; forced boundaries
are separate checks. This is not a mocked eight-bit limit called sixteen bits.
It is also **not a production World**: support predicates, global-tick RNG,
sleep/interest, real event queues, Water mass and worker scheduling are absent.
The issue's real-World natural rollover gate remains open. The
[consumer audit](../research/mat-003prepass-epoch-consumers.md) names every native
stamp access and the required later fixtures, including support and reaction wakes.

## Retained failures and review corrections

No failed or superseded run is relabeled as a pass. The
[attempt ledger](mat003-prepass-2026-10-22/attempts.json) preserves identities and
limitations for developer attempts 01–03 and formal runs 001/002.

Independent review found two defects in the initial apparatus: split swap could
modify a source before a destination allocation completed, and a refused
synthetic merge still changed epoch/reserved fields. Both were fixed before
formal collection. Whole-record oversize-tail writes were also made consistently
refusing across representations. Earlier successful assertions therefore do not
qualify the final code. Attempt 02 lacks immutable source snapshots and is retained
only as a developer diagnostic.

Formal run 001 passed normal checks, but LeakSanitizer exited 1 because the process
sandbox prevented `/proc` thread inspection. Its [failed receipt](mat003-prepass-2026-10-22/local-run-001-failed.json)
and exact diagnostic remain retained. No sanitizer pass is claimed for it.
Formal run 002 used the same source/registered flags outside that process sandbox;
normal and ASan/UBSan both exited 0 with empty stderr, and leak detection stayed
enabled. Its [complete receipt](mat003-prepass-2026-10-22/local-run-002.json)
binds the actual source snapshots, commands, binaries, host and outputs.

The initial documentation/provenance check found six missing companion-workspace
reference paths. The five actual referenced files were restored read-only from
the same pinned companion commit used by CI, `6a58311982941b75f46e22109a0829e5acb83c7e`.
No fixture expectations or historical records were changed to hide that intake
failure. The final validation ledger below records the subsequent outcomes.

## Findings for material and persistence work

The [state inventory](../research/mat-003prepass-state-inventory.md) documents
the full current kernel families and outside-carrier state. Three findings are
especially consequential:

- Current a storage/accessors are 16-bit while legacy adapters and CYSD1 use a
  byte. `content_hash` also omits nonzero Empty state at ambient temperature;
  neither that hash nor the old #16 byte-a comparator is a sufficient oracle.
- Epochs affect granular support/bearing, transport and pending reaction wake
  behavior as well as same-tick update suppression. An epoch-only clear must not
  masquerade as a material mutation or discovery incarnation change.
- The separately saved pressure prototype uses spare bits 40–55. Its exact
  inspected mapping is linked from the inventory; epoch16 at 48–63 overlaps the
  prototype's overfill and part of trapped-air state. Keeping 40 material/state
  bits, 16 prototype payload bits and epoch16 requires 72 logical bits or a
  separately specified sidecar/repacking change. This is a compatibility budget,
  not admission of that solver or a selected layout.

The [GEN-006 handoff](../research/mat-003prepass-gen006-handoff.md) proposes
versioned semantic records independent of in-memory ABI, distinct catalogue/state/
solver/recipe/baseline identities, explicit same-value edits and Empty tombstones,
complete fixture/clock/pending-work ownership, and pin/refuse behavior for
unsupported authoritative state. Epoch rebase is an unproved candidate; no
continuation acceptance follows from the storage harness.

## Validation and next bounded step

The [compact validation ledger](mat003-prepass-2026-10-22/validation.json)
retains actual command outcomes, source identities, retrieval comparisons and
limits. The broad unchanged native executable compiled successfully, but its
unfiltered run reached the 120-second limit after 19 passed cases and no reported
failures. That run is **incomplete**, not a full native-suite pass. Five subsequent
30-second bounded filters passed: optional temperature movement, serialized
payload relocation, failed-tick stop/reset, interest-region resume boundaries,
and building CYSD1 constructor/snapshot round trip. Their separate receipts
retain the same native binary hash and unchanged test-source identity.

| Gate | Checkpoint disposition |
|---|---|
| Seventeen storage arms, optimized normal | Passed, 49,775,273 checks |
| Same arms, ASan/UBSan with leak detection | Passed in formal run 002; run 001 failure preserved |
| Evidence rejection unit tests | Passed, 14 tests |
| Dedicated GitHub-hosted provider checker/tests | Passed locally; 6 provider-policy tests |
| Independent evidence readback | Passed against retained formal run 002; exact records, file and binary hashes checked |
| Unchanged native World regressions | Compiled; full run timed out after 19 passes; five focused filters passed |
| Documentation/provenance and M11 | Passed locally; runtime identities checked as LFS pointers, not executed |
| Frozen retrieval | 32/32 canonical hits in top five; rank changes disclosed in the ledger |
| Supplementary retrieval | Prior 110 questions preserved; four new prepass questions reported separately |
| Hosted S0 workflow | Publication/check receipt remains separately source-qualified |
| Real-World candidates, conservation, epoch16 lifecycle | Not implemented/qualified |
| Performance, assembly/PMU, Windows/Wasm, continuation | Not executed/qualified |

The next implementation slice should introduce only an isolated World carrier
adapter and exact semantic recorder. Preserve the unchanged current binary and
matched E8 abstraction control, widen all consumers together, and first establish
ordinary 2,048-tick equivalence plus real-World 131,080-tick E16 rollover. Include
support/bearing, signed seams, event-prewritten destinations, Water transfers,
sleep/interest re-entry, reset and failed-world quarantine. Only after correctness
admit the staged seven-pair timing campaign. Leave secondary 24/32-bit arms and
production migration explicitly deferred until their own evidence is justified.

Canonical storage, materials, saves, ownership, programme, roadmap, build guide,
handover and retrieval routes link this checkpoint with experimental/Planned
status. No production source, runtime/provenance manifest, dependency pin, frozen
retrieval question, historical evidence or physics default is changed.
