---
title: MAT-003 capture phase and support-relevant touch handoff
status: Planned
document-kind: design
scope: Source-qualified Current touch counterexample and proposed refinement of carrier-neutral continuation capture; no schema adoption or restore implementation
canonical-for: [mat003-capture-phase-handoff]
last-reviewed: 2026-10-24
related-documents: [mat-003prepass-gen006-handoff.md, mat-003prepass-epoch-consumers.md, ../operations/mat003-overnight-campaign.md, ../reference/level-saves-and-replay.md]
---

# Capture phase and support-relevant touch handoff

## Current behavior: content and completed tick are insufficient

**Source inspected at main `1002b920`:**
[`World::granular_support_at`](https://github.com/techrote/cybersand/blob/1002b9201006b572180a12cbc4c3b21fc234e8fa/native/src/world.cpp#L1327)
uses the current cell-epoch equality predicate for support, with a separate
tick-zero exception. A genuine
[`write_cell`](https://github.com/techrote/cybersand/blob/1002b9201006b572180a12cbc4c3b21fc234e8fa/native/src/world.cpp#L1475)
stamps the current World epoch even when invoked through the public
[`set_cell_state`](https://github.com/techrote/cybersand/blob/1002b9201006b572180a12cbc4c3b21fc234e8fa/native/src/world.cpp#L1693)
between native ticks. A same-value request returns without stamping.

Therefore “touched in the most recently completed native tick” is too narrow if
the capture boundary permits already-applied owner edits after that tick. The
needed discriminator is the **actual current-epoch touch predicate at capture**,
including external writes. It cannot be reconstructed solely from current cell
content, completed tick or a logical-content hash.

**Observed Windows author validation, not independent acceptance:** the
[registered native probe](../../tools/experiments/mat003_touch/registration-v3.json)
ran the real Current C64-E8 World in serial/one-worker, phased/one-worker and
configured phased/four-worker cases, both normal and ASan+UBSan. All six cases
passed **3,630 assertions**, nine edit checkpoints and nine following-tick
recoveries per case. Each case ran 513 native ticks; checkpoints span 255/256
and 510/511 around the ordinary E8 rollover boundaries.

| Same owner boundary, no intervening native tick | Cell content | Sampled support |
|---|---|---|
| Stable Sand before edit | Original | True |
| Same-value `set_cell_state` | Original; full state hash unchanged | True |
| Genuine state edit | Changed | False |
| Restore original cell state | Original content hash restored | **False** |
| Complete following native tick | Original | True |

The concrete fixture and all 54 checkpoint observations are retained in the
[summary](../audits/mat003-overnight-2026-10-24/touch-summary.json). This is a
counterexample to a content/clock-only restore rule, not a native restore test.
Configured four-worker execution is not a claim that four distinct workers
participated; this probe adds no dispatch observer. The earlier Windows archive
has its own worker witnesses and independent-readback requirements.

## Proposed refinement before GEN-006 implementation

Consume this alongside the existing
[carrier-neutral handoff](mat-003prepass-gen006-handoff.md) and the separately
proposed [#230 schema/lifecycle handoff](https://github.com/techrote/cybersand/pull/230).
It does not adopt a durable codec, physical epoch width or carrier.

Before defining a snapshot's semantic state, choose and version the owner
capture phase. Either capture immediately after the completed native tick and
before later owner writes, retaining those writes as ordered pending work, or
capture after applying them and preserve their effects on the current-epoch
predicate plus mutation/order receipts. Do not silently mix these phases.

For the admitted domain, persist or prove reconstruction of the actual
`cell_epoch == current_world_epoch` discriminator at capture, the absolute
successful clock, activity/deadline state, interest/exclusion policy and pending
ordered work. Keep physical epoch labels separate from durable mutation
generation, residency incarnation and job/save identity. Tick-zero handling and
post-capture first-update/support behavior require explicit native fixtures.

Required continuation negatives include a post-tick state edit, a content-roundtrip
edit, a true same-value no-op, an applied boundary event, capture before/after
owner input, rollover, excluded/re-entered activity, and a stale save/job receipt.
Compare uninterrupted versus restored support and fixed-tick evolution; equality
of content hashes alone cannot satisfy that gate. No such restore is implemented
or qualified here.

## Existing fixture review and follow-ups

The unmodified #230 experimental Python codec at `0d6d713` passed its 17 tests
locally. Two additional bounded probes expose **fixture hardening follow-ups**:

- `admitted_result({}, {})` and matching partial dictionaries return true because
  missing keys compare as `None == None`. Require complete, typed identity sets
  before equality, then a separate one-use owner transaction for actual commit.
- A record with `version=True` roundtrips because boolean true compares equal to
  integer one. Require an exact integer schema version before compatibility checks.

These are nonproduction model limitations, not shipped stale-job or persistence
defects. The codec remains a proposal/fixture; it must not be used as evidence of
runtime admission, native continuation or complete validation. Original #230
source and tests are unchanged; the new probes and source seal are retained in
this campaign's handoff-review evidence.

## Contract model: separate physical labels from the capture predicate

The [registered model](../../tools/experiments/mat003_touch/epoch-model-registration.json)
exhaustively exercises three abstract cells, two-/three-bit source and destination
counters, every source stamp in `[0,current]`, every nonzero rebased destination
epoch and all length-three traces of counter tick, changed write, no-op, committed
move and committed swap. Mapping current stamps to the new current epoch and all
other stamps to zero preserves logical contents, absolute clock, equality and the
tick-zero support exception throughout that bounded domain.

Local result: **13,960 initial projections, 1,745,000 terminal traces and
2,177,760 positive comparisons pass**. Three deliberately broken models are
refused: dropping current touch, stamping a true same-value no-op, and clearing
only active cells while retaining an excluded old stamp across wrap.
Reproducer: `python -B tools/experiments/mat003_touch/epoch_model.py`.

**Contract-model evidence only:** this is not native restore, an E8/E16 rollover
qualification or proof of complete continuation. Its argument requires that the
relevant consumers use equality, future-stamp labels cannot appear, the full
resident clear contract remains, and all other authoritative state is preserved.
Raw epoch-inclusive hashes may differ and require separately versioned semantic
comparison. A lazy/local-clear alternative cannot inherit this argument without
establishing its own stale-label and exclusion/re-entry proof.

## Execution and preserved failure

The probe's first v2 build was refused by Clang warnings-as-errors for the known
unused `this` capture at `world.cpp:2730`; no binary or case ran. Registration v3
then permitted exactly one unused-capture removal in a separate compiled copy,
with no diagnostic suppression. The raw source snapshot and production source
remain byte-unchanged. All compiled native files are checked against the original
snapshot, with precisely that one literal difference allowed in World.

The successful source froze at `d6c0166ff416e7fa061919f37d18f12e841122e9`.
Windows LLVM-MinGW 20260826 / Clang23.1.0, explicit LLD, Python3.12.10 and retained
psutil7.0.0 were used. Build/case timeouts are 180/60 seconds with concurrency
one, fail-fast sanitizer options and a 2 GiB Windows job bound. Leak detection is
disabled. Wall/RSS receipts are operational guards, not timings.

Both failed v2 and successful v3 raw source, compiled copies, binaries, streams,
commands and inventories are retained outside Git at
`C:/Users/_/mat003-overnight-20261024/touch-v2-v3-evidence.zip`, **2,424,047 bytes**,
SHA-256 `9bbbaff902d946b3f361e80022f266e10137b7b57d59209366fe6de371dfac5a`.
The [collector](../../tools/experiments/mat003_touch/run.py) reproduces v3 into
a new output root with the sealed compiler; registration v1 is an unexecuted
proposal and v2 remains a retained failed build, never overwritten by v3.

The separate [Windows archive reader](../../tools/experiments/mat003_touch/verify.py)
checks the complete source inventory against that Git revision, exact generated
copy, two binaries, eight ordered commands/receipts and all 54 native checkpoint
observations. Six resealed negative archives refuse omitted cases/checkpoints,
changed flags/native source, false restored support and false no-op behavior.
These are read-only checks; no native case is re-executed:

```text
python -B tools/experiments/mat003_touch/verify.py <touch-v3> --source-commit d6c0166ff416e7fa061919f37d18f12e841122e9 --registration-sha256 <touch-summary-registration-sha256> --compiler-sha256 <touch-summary-compiler-sha256>
python -B tools/experiments/mat003_touch/test_verify.py <touch-v3>
```
