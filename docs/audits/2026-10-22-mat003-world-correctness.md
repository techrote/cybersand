---
title: MAT-003PREPASS isolated native World correctness checkpoint
status: Current
document-kind: evidence
scope: S1 isolated native World apparatus and source-qualified correctness evidence; no performance, platform or production-layout acceptance
canonical-for: []
last-reviewed: 2026-10-22
related-documents: [../operations/mat-003prepass-registration.md, ../research/mat-003prepass-epoch-consumers.md, ../research/mat-003prepass-gen006-handoff.md, ../reference/validation-evidence.md, 2026-10-22-mat003-prepass-foundation.md]
---

# MAT-003PREPASS isolated native World correctness checkpoint

## Disposition

**Implemented S1 apparatus; formal all-arm collection pending.** This continuation
of [#204](https://github.com/techrote/cybersand/issues/204) and draft
[PR #208](https://github.com/techrote/cybersand/pull/208) adds the actual native
World to the earlier S0 carrier checks. The final selected C80-E16-split developer
diagnostic passes normal and ASan/UBSan with leak detection. It does not substitute
for the registered seventeen-arm, two-configuration collection.

Production remains the original 64-bit carrier and eight-bit epoch. The candidate
World copies are isolated experiment inputs; no production native source, public
adapter, dependency pin, runtime library or save format changes. No performance
winner, other-platform qualification or continuation codec is accepted. Issue
#204, #14/G-final and the unrelated Water/soliding gates remain open.

## Recoverable registration and source

| Identity | Value |
|---|---|
| Continuation intake | `de767c6419ac23273232c5fa9699432af62116a4` |
| Intake tree | `ae9ad6701ea1920242ca9d2bd98dbbd22a33c569` |
| Unchanged production baseline | `da5112c066416346d6fe3984d4161cd162611e50` |
| Published S1 registration | `fa6802d5e64f41b967ccce46d9005d5fca3194ab` |
| Registration tree | `b017cf56cd80fa600376f6b600f0fad04ddf4ebf` |
| Local initial S1 registration | `2614d6a`; full object in the identity ledger |
| Local dependency-completeness amendment | `0c876a154c8d315191737d5eda57737074134eb8` |
| Work branch | `codex/mat-003prepass-foundation` |

The [registration identity ledger](mat003-world-2026-10-22/registration-identities.json)
preserves the local raw commit objects and the published equivalent tree. Version
2 of the [S1 registration](../../tools/experiments/mat003_prepass/world_registration.json)
adds private native headers to the frozen dependency ledger before collection.
The [implementation freeze](mat003-world-2026-10-22/apparatus-freeze.json) records
all apparatus input hashes and the developer corrections. The collector takes a
complete immutable source snapshot before any compile; later working-tree edits
cannot change a running attempt. Source hashes, rather than coincident local and
remote commit metadata, bind the executable input.

The source-control arm uses byte-identical original World header/source and
`PrecisionStorage`. All native dependencies are checked against the registered
Git baseline. Candidate overlays record literal patches and before/after hashes:
six declared substitutions for ordinary candidates, fifteen for split candidates,
and zero for the source control. Independent readback reconstructs these patches.

## What S1 exercises

All seventeen S0 mappings are retained: the unchanged source E8 control; matched
word64 and padded64 at E8/E16; packed, aligned and split 72/80 at E8/E16. An E16
candidate changes the actual World counter, increment cast and carrier accessor
to sixteen bits together. A wide carrier with an eight-bit World counter would
fail this contract.

The fixture contains four complementary groups:

- **Ordinary:** 2,048 ticks each for serial/one worker, phased/one worker and
  phased/four workers, with production 128-cell storage chunks, 64-cell cores and
  32-cell activity blocks. The closed Water/Sand scene crosses the signed zero
  storage/core seam. A separate two-cell Brine/BareIron chamber exercises actual
  conversion to RustedSteel. Scheduled events test prewritten Fire suppression.
- **Natural rollover:** 131,080 uninterrupted ticks from a fresh zero counter in
  one 16-by-16 chunk. Water wake/movement, an excluded granular specimen, region
  re-entry and events straddle both sixteen-bit boundaries. Attempted/completed
  clocks are recorded every tick. A nonzero excluded sentinel must be cleared at
  each observed maximum-to-one counter transition.
- **Forced resident clear:** 512², 1024² and 2048² resident cells, with only the
  epoch seeded to maximum-minus-one. Every cell is inspected after the actual
  clear. Raw state, reserved bits, neutral tails and nonambient temperatures must
  survive. Global tick remains explicit; these are not natural rollover runs.
- **Lifecycle and refusal:** movement/swap, partial/full Water transfer, Empty
  destination initialization, changed/no-op writes, generated chunk admission,
  clear/replacement, the general cross-chunk scan path, failed-rollover quarantine
  and clear recovery. A separately labelled direct transport-consumer probe
  configures pickup, observes current-stamp rejection and stale-stamp acceptance,
  and requires one `GrainTransport` event with Water conservation.

Candidate observers count actual dispatch and background-worker tasks. The
unchanged source control has no injected observer; its exact matched-E8 bridge
is kept separate from worker-execution evidence. Configured worker count and
`phase_jobs` alone are not proof that pool workers ran.

### Exact comparison and ledgers

Four binary streams retain the initial state and every subsequent tick through
lossless byte-range deltas. Independent decoding reconstructs full snapshots;
literal byte equality is required across representations and configurations for
the same backend/input schedule. Serial and phased schedules are not required to
produce the same trajectory.

Records include material16, full state_a16, state_b8, signed temperature16 and the
current-epoch predicate for every resident cell. They also include activity and
quiet/deadline state, selected/applied interest regions, ordered pending events,
completed/attempted clocks, TickStats, support queries and conversion diagnostics.
Water mass and all 132 catalogue species are independently reduced from the
decoded cells. Epoch numbers, reserved bits and ABI padding do not masquerade as
semantic state; their separate preservation/type checks remain required.

Valid nonzero Empty state is retained. Raw high-a16 inert sentinels are labelled
as storage probes because the current public non-Water API accepts byte-sized a
and default Water mass is at most 255. Ordinary/natural trajectories use zero
neutral extra payload. Nonzero tails are helper/forced-storage evidence, not
qualification of a new material payload or parallel continuation format.

### Physical ownership and accounting

Split candidates retain an eight-byte base array plus an eagerly allocated,
bounded, chunk-owned one- or two-byte tail array. Complete movement/swap transfers
tails; replacement/reset clears them; partial Water changes preserve the tails of
both endpoints. No per-cell pointer, hidden tick-time lazy tail admission or solver
interpretation is introduced. This implementation does not test absent optional
tails or sparse occupancy savings.

The fixture reports actual cell sizes/capacities, temperature arrays, activity
arrays, tail capacities, chunk descriptors, partial scratch and `sizeof(World)`.
Its legacy aggregate is separately labelled and must not be added to its own
components. Allocator overhead and peak RSS remain unmeasured; the report is not
a whole-process memory accounting claim.

## Developer evidence and retained failures

The [developer ledger](mat003-world-2026-10-22/developer-attempts.json) retains
actual source hashes, commands, exit states and diagnostic outputs. Earlier runs
are neither overwritten nor relabelled as final evidence.

| Attempt | Observed outcome | Disposition |
|---|---|---|
| world-dev-001 | Three normal source/word-E16/split-E16 arms passed | Superseded apparatus; preceded stronger epoch, transport and reactive witnesses |
| world-dev-002 | Sanitized split-E16 failed | Reaction chamber assertion failed; LeakSanitizer also could not inspect sandbox `/proc` threads |
| world-dev-003 | Final split-E16 normal and sanitized both passed; 459,299,274 assertions each | Selected-arm diagnostic only; leak detection retained, empty execution stderr |

Dev002's chamber allowed Brine to move away from the asserted position. The final
two-cell interior fixes the fixture. Its independent LeakSanitizer environment
failure is preserved; dev003 executes outside that incompatible process sandbox
without disabling leak checks.

Independent developer readback decoded 2,049 frames for each ordinary stream and
131,081 natural frames. Water remained 8,925 units in the ordinary scene and 255
in natural; Sand count remained four. The four sanitized streams are literally
equal to their normal counterparts. The retained
[normal readback](mat003-world-2026-10-22/world-dev-003-normal-readback.json) and
[corrected sanitized readback](mat003-world-2026-10-22/world-dev-003-sanitized-readback-corrected.json)
record the results. An initial diagnostic wrapper reloaded integer-keyed summary
data through JSON, causing false conversion-vacuity errors; that failed wrapper
report is preserved and explained by the corrected receipt. The formal verifier
uses the in-memory keys and is unaffected.

Thirty-five focused overlay/evidence tests pass locally, covering exact patch
contracts, source drift, record decoding, missing/duplicate arms, malformed
deltas, ledger vacuity, rollover/type witnesses, capacity framing and tampering.
Six CI-provider policy tests and the active provider check also pass. These tests
validate apparatus behavior; their fabricated negative fixtures are not observed
World experiment results.

## Formal collection and readback contract

Formal acceptance requires all seventeen arms in both normal and sanitized
configurations: forty compiler processes (including six shared-source object
compiles) and thirty-four complete fixture processes, sequentially. The registered
limits are 240 seconds per compile, 360 seconds per fixture and 7,200 seconds
including collection/readback. A failure or budget stop leaves an incomplete
attempt with original receipts.

The dedicated GitHub-hosted job uses Ubuntu 24.04, the GCC 13/binutils 2.42 pin,
retained exact flags, `detect_leaks=1:halt_on_error=1` and UBSan halt/stacktrace.
The job stores immutable inputs, overlays, original/candidate binaries, all
traces, stdout/stderr, hashes and independent readback in an artifact. Artifact
retention is thirty days; compact checked-in receipts do not replace raw traces.
No primary timing is admitted by S1, and elapsed values enforce budgets only.

Evidence-only synchronization commits do not repeat the long World collection
when apparatus, native inputs, toolchain pin and workflow are unchanged. The job
states this explicitly; prior evidence remains qualified to its tested inputs.
Ready-for-review and manual events always collect again. This draft checkpoint
does not supply merge authorization or a full release-platform gate.

## Remaining work

After formal S1 acceptance, the next bounded step is separately registered S2
performance feasibility and paired measurements. Timing builds must remove
observer atomics and per-tick semantic capture; their observed twins must first
qualify the new scenarios. Every primary contrast requires the registered seven
interleaved AB/BA process pairs. A settled scene cannot stand in for maintained
active work, and 2,048 E16 ticks without a clear cannot measure maintenance cost.

The [consumer audit](../research/mat-003prepass-epoch-consumers.md) retains broader
discovery, Godot support/bearing and continuation gates. Windows/Wasm, secondary
E24/E32, pressure-prototype integration, real streaming/eviction/reload and any
production layout selection remain outside S1. The
[GEN-006 handoff](../research/mat-003prepass-gen006-handoff.md) remains a proposed
semantic contract, including unresolved epoch-rebase behavior.
