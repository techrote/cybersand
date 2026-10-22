---
title: MAT-003PREPASS carrier experiment registration
status: Planned
document-kind: guide
scope: Staged experimental material-state and 64/72/80-bit carrier research; S0 storage and S1 native World correctness, with performance and production migration separately held
canonical-for: [mat003-prepass-registration, mat003-carrier-experiment-matrix]
last-reviewed: 2026-10-22
related-documents: [../research/mat-003prepass-state-inventory.md, ../research/mat-003prepass-epoch-consumers.md, ../research/mat-003prepass-gen006-handoff.md, architecture-programme.md, cell-layout-experiment.md]
---

# MAT-003PREPASS carrier experiment registration

## Scope and source identity

**Planned experimental programme; S0 storage and registered S1 native Linux
World correctness checkpoints passed.**
Issue [#204](https://github.com/techrote/cybersand/issues/204) supplies evidence
before GEN-006 freezes continuation contracts. It does not migrate production
storage, select G-final, implement pressure/momentum or change Water conservation.
Both planning and execution intake are `da5112c066416346d6fe3984d4161cd162611e50`,
tree `167c9a04ed45fe84d30846865e8a77d78cdfd6ec`. The checkout was clean before
registration. The [machine registration](../../tools/experiments/mat003_prepass/registration.json)
was committed locally as `101b72738cfa392aeaea141764baebba36a50cc4` before
carrier code; published commit `f6e16afed03b3df1e5c5f8de61fd1f5af187a285`
preserves that exact registration tree. Version 2, locally committed as
`34861647184a973ee659ad5f7b77643eee297720` before formal collection,
clarifies the two independent operation streams and pins control-header hashes.
The dated checkpoint preserves both raw local commit objects and publication
identities; local and published commit metadata are distinct.

The first checkpoint was S0: storage capability, physical accounting, source
inventory and a proposed persistence handoff. Its
[dated report](../audits/2026-10-22-mat003-prepass-foundation.md) owns those historical
observations and failures. The later [S1 report](../audits/2026-10-22-mat003-world-correctness.md)
records the passed native Linux World fixtures, exact semantic/conservation gates
and natural E16 rollover. Broader consumer/platform coverage and the paired
performance campaign remain incomplete; this registration is not an acceptance report.

The sequencing constraint is GEN-007 qualified baseline → MAT-003PREPASS →
GEN-006 → full MAT-003. GEN-006 architecture work can proceed while the evidence
grows, but its durable state schema must consume the handoff. Historical #16/#17
controls and #14's open G-final retain their original dispositions.

## Exact primary field mapping

**Current control and registered experiments:** every arm retains material16,
state_a16 and state_b8 storage capacities. `Material : uint8_t` and byte-sized
adapters remain current constraints; a raw material16 test establishes storage
capacity, not a 65,536-material runtime catalogue.

| Field | E8 arms | E16 arms |
|---|---|---|
| Raw material | bits 0–15 | bits 0–15 |
| state_a | bits 16–31 | bits 16–31 |
| Raw state_b | bits 32–39 | bits 32–39 |
| Reserved base bits | bits 40–55 | bits 40–47 |
| Epoch | bits 56–63 | bits 48–63 |
| Neutral extra capacity, C72 | bits 64–71 | bits 64–71 |
| Neutral extra capacity, C80 | bits 64–79 | bits 64–79 |

E8 uses an actual `uint8_t` counter/accessor and E16 an actual `uint16_t`
counter/accessor in the experimental primitive. The production World remains
unchanged at epoch8. Neutral extra bits have no material, velocity or solver
meaning. Base reserved bits are isolated and preserved by unrelated setters.
Packed byte storage uses an explicitly little-endian logical mapping, independent
of typed alignment. Aligned word/tail storage is a host representation, not a
serialized C++ object.

## Registered physical arms

There are 17 S0 arm identifiers in the JSON registration:

| Logical capacity | Representations | Epoch widths | Number |
|---|---|---|---:|
| 64 | Direct, unchanged `PrecisionStorage` control | 8 | 1 |
| 64 | Abstraction-matched word; 16-byte physical padded control | 8 and 16 | 4 |
| 72 | Packed9; naturally aligned word+u8; split base8+u8 | 8 and 16 | 6 |
| 80 | Packed10; naturally aligned word+u16; split base8+u16 | 8 and 16 | 6 |

Measure actual size, alignment, member offset and array stride. A natural
word+tail struct may consume 16 bytes; padding is not semantic capacity.
Split buffers are separately owned, bounded chunk arrays, not contiguous 9/10.
The 64-bit padded control has no extra logical payload. Its explicit padding
must not enter semantic comparisons. The unchanged production header and its
default mass8/delay8 policy remain the source control.

At fixed cell count, packed9/10 array arithmetic is +12.5%/+25% relative to 8;
16-byte stride is +100%. These are neither process-RSS measurements nor speed
predictions. Report split base/tail allocations, actual capacity, descriptor and
bounded index costs separately. Unobservable allocator overhead and process
memory are gaps. Do not add `resident_cell_bytes()` to its own components.

**Deferred secondary arms:** C64-E24, C72-E32 and C80-E32. They require explicit
admission, exact mappings and forced-boundary lifecycle review. Epoch24 fits
40 material/state bits plus 24; epoch32 needs at least 72 logical bits. No E32
candidate can be described as an unchanged 64-bit carrier.

## S0 fixtures and stop rules

The checked-in JSON freezes representative field/tail boundaries, seed 204,
two independent streams of 4,096 deterministic operations each, 2,048 ordinary
primitive ticks and 131,080 natural primitive ticks. One stream has zero extra
payload and compares all 17 arms; the other exercises full width-masked neutral
payload and compares representations within each width. Full `state_a` values
include 255/256 and 32767/32768/65535.
Raw high material bits and tail high bits are checked independently of valid
runtime catalogue IDs. Zero/initial bytes, unrelated fields and nonzero reserved
patterns must survive declared operations.

Synthetic neutral payload tests cover copy, move, swap, split/merge, reaction
reset, reclaim and refusal without source mutation. Split occupancy includes
clustered/dispersed usage and absent/allocated-unread/accessed tails. Comparisons
use the same registered operation stream; a C64 arm cannot represent a nonzero
extra tail and is inapplicable to that payload contrast. Within each logical
width, representation-independent records include full material16/state_a16,
state_b8 and extra capacity. Compare records against an independent plain-field
model; a digest is supplementary, not a lossless comparator.

The natural E16 primitive must clear at 65,536 and 131,071 and run beyond both;
E8 first clears at 256, then every 255 ticks. Forced counter seeding must be
identified separately. This is **synthetic storage/epoch evidence**, not the
issue's real-World 131,080-tick gate. S0 did not qualify support predicates,
RNG/global cadence, interest/re-entry, event ordering, partial Water transfer or
failed-world quarantine. S1 below adds bounded native fixtures for those consumers;
the report preserves its Godot, discovery and continuation gaps.

S0 permits one test process at a time, two correctness configurations (optimized
normal and AddressSanitizer+UndefinedBehaviorSanitizer), 180 seconds per compile,
120 seconds per execution and 1,200 seconds total collection budget. Compiler,
flags, source hashes, binary hash and host identity must be retained by the
runner. This is not a speed test. Nonzero exit, timeout, sanitizer diagnostics,
malformed/missing arms or mismatched semantics fail the run. Retain every
attempt; a correction uses a new evidence directory and new source hashes.

## Reproduction and evidence readback

From the repository root, use the isolated runner; it does not add anything to
the production default build or published runtime input set:

```text
python3 tools/experiments/mat003_prepass/run.py --output build/mat003-prepass/run-001
python3 tools/experiments/mat003_prepass/verify.py build/mat003-prepass/run-001
```

Output directories are append-only per invocation: an existing directory is
refused. The collector records command outcomes even after a failed compile or
test. The separate readback checks hashes, complete arm coverage, primitive
rollovers and same-width digests. Windows and Web/Wasm remain unexecuted unless
an actual platform run is independently retained. GCC 13.3/binutils 2.42 match
the Linux pin at intake; Godot 4.7, godot-cpp and Rapier pins are not changed.
Retained runtime LFS pointers identify the production control; they are not
claimed as freshly executed binaries.

## Later World and performance admission

**Not admitted by S0; separately registered in S1 below:** implement an isolated World carrier
switch only after the [consumer audit](../research/mat-003prepass-epoch-consumers.md).
Keep the original World binary and rebuild an abstraction-matched E8 control.
Classify every hash/snapshot, support predicate and diagnostic. Validate full
semantic records including nonzero Empty states, independent Water/species
ledgers and identical event/work schedules before any candidate timing.

The next stage must freeze actual fixture/source/binary hashes, platform,
compiler, flags, geometry/residency, seeds/translations, worker dispatch,
run order and budgets. It must cover quiet/sleeping, small-active-region,
active-liquid/granular and current-catalogue reactive fixtures at 512²/1024²/2048²,
with 1/4 workers. A configured worker count alone is not actual dispatch evidence.
Stage the matrix and retain every mandatory arm's observed result or explicit
correctness rejection. Do not silently omit packed or split arms.

For each admitted primary contrast use seven independent interleaved AB/BA
process pairs, 120-tick warmup and separately retained startup. First compare
capacity at E8, then E8/E16 within each representation, then combined choices.
Observer-off primary timing and separate observer overhead are required. No
overlapping builds or benchmarks. A 2,048-tick E16 run without a wrap cannot
establish wide-epoch maintenance cost: observe real clears separately and label
period-based amortization as projection. Wider epochs reduce frequency; they
do not inherently remove the residual full-resident clear hitch.

Future timing must report ordinary p50/p95/p99/max, clear counts/cells/bytes and
neighboring excess, actual scanned/visited work, allocation/refusal and memory.
Keep fixed-cell and fixed-memory analyses separate. Zero visits must not cause
division by zero. Seven paired process ratios are not pooled tick replicates.
Historical 15% paired-p95 and 1 ms extra-clear screens trigger review, not automatic
acceptance. Optimized assembly, cache/page crossings and available counters
need their own evidence; elapsed time alone establishes no cache causality.

## Checkpoint completion versus issue acceptance

S0 can establish useful, source-bound storage capability and identify schema
hazards. It cannot close #204 or authorize production migration. S1 now qualifies
its registered native Linux semantic/conservation and actual sixteen-bit rollover
fixtures. Broader consumer/platform coverage, complete process memory accounting
and registered paired costs remain outstanding.
The [GEN-006 handoff](../research/mat-003prepass-gen006-handoff.md) is a proposal
to keep durable semantics independent of ABI; no real streaming/eviction/reload
or replay acceptance is inferred. Retain the baseline unless later evidence
supports a separately scoped migration.


## S1 continuation admission — 2026-10-22

**Registered correctness continuation of PR #208:** the owner's instruction to
continue this handoff admits an isolated native World adapter and fixtures under
the [S1 machine registration](../../tools/experiments/mat003_prepass/world_registration.json).
The continuation intake is `de767c6419ac23273232c5fa9699432af62116a4`;
production control source still matches the original `da5112c` baseline.
S0 artifacts and its registration remain unchanged.

All seventeen existing mappings remain in scope. The source-control World/header
are byte-identical; candidate copies replace the carrier alias and both counter
type/increment together. Split candidates use eagerly prepared chunk-owned tails
with explicit move/swap/reset handling and separate allocation accounting.
Correctness-only candidate observers record actual pool dispatch and background
worker execution; the unchanged control has no such instrumentation. The matched
E8 arm must bridge its exact semantic results. No observer cost or speed ranking
is established by these checks.

The registered fixtures include 2,048 ordinary ticks for serial1/phased1/phased4,
131,080 uninterrupted natural ticks with one phased worker and 256 resident cells
in one 16-by-16 chunk, forced overflow at 512²/1024²/2048² resident cells, and
lifecycle/refusal checks. Four-worker ordinary execution and large forced clears
do not establish four-worker natural E16 rollover. Exact records retain
material16, a16, b8 and temperature16, including valid nonzero Empty state. Raw
high-a16 probes are separately labelled because current public APIs constrain
non-Water a to a byte and default Water mass to 255. Numeric epoch/padding are
excluded from semantic equality but independently verified; each cell's
current-stamp predicate remains in the semantic record. Compare identical backend,
coordinates, work and inputs; do not assert that serial and phased trajectories
or translated RNG scenes must match.

S1 permits sequential optimized and ASan/UBSan configurations, at most 64 compiler
processes and 34 complete fixture processes, 240 seconds per compile, 360 seconds
per fixture and 7,200 seconds per formal collection. Exact implemented fixture,
source and binary identities are frozen before formal collection. Retain developer
failures separately; any corrected source receives a new immutable run directory.
A budget stop remains incomplete. Performance, other platforms, Godot adapter
execution, continuation and production migration remain deferred.

The [S1 implementation checkpoint](../audits/2026-10-22-mat003-world-correctness.md)
records the apparatus freeze, retained developer corrections and the disposition
of the formal collection. Its exact source ledger is the implementation amendment
before full collection; a selected-arm smoke pass is not all-arm acceptance.

## S2 performance feasibility proposal — not admitted

**Planned proposal; no timing admission or frozen execution contract.**
S1 correctness has passed; candidate timing remains withheld until a new
registration freezes sources, fixtures, binaries, flags, horizons, pair order,
budgets and stop rules.

A suggested source-only feasibility probe would cover 24 contexts:
512²/1024²/2048² × quiet/sleeping, small-active-region, active-liquid/granular and
current-catalogue reactive fixtures × phased workers 1/4. Suggested bounds are
20 minutes total and 120 seconds per process, with a short fixed horizon.
These limits are suggestions for a new registration, not a finalized execution
contract or completion estimate. A budget stop would remain incomplete.

**Proposed S2A:** first compare eight E8 contrasts at an active-liquid/granular 512²/four-worker
anchor: source versus word, word versus padded, and word versus each of the six
C72/C80 packed/aligned/split arms. Then run eight within-representation E8/E16
contrasts at a quiet 2048²/one-worker anchor. Seven independent interleaved AB/BA
process pairs require fourteen processes per contrast: **224 primary processes**
before correctness rejections. This covers all seventeen arms, with conclusions
limited to those anchors. Source versus matched word E8 measures abstraction
overhead within that context.

**Proposed S2B:** compare C64-word E8/E16 across the full 24-context grid. Reusing
the identical registered quiet anchor leaves 23 contrasts, or **322 additional
primary processes**. Wider-representation scaling and optional S2C combined-choice
comparisons need their own declared scope; this proposal does not require a full
Cartesian product or select a winner.

Timing builds would compile out candidate observers and omit per-tick semantic
capture. Separate observed twins would establish semantic/work equivalence,
actual background-worker execution and observer overhead. Native `TickStats`
does not count scanned cells or epoch clears: observed counters or a validated
exact derivation are needed; scheduled-core area alone is not generally enough.
Retain 120-tick warmup and startup separately. Active fixtures must maintain their
declared workload after warmup, with deterministic inputs, explicit material
source/sink ledgers and separately reported input costs.

S1 natural-rollover correctness and separately labelled forced-clear timing
answer different questions. Observe actual clear latency, cells, defined byte
counts and neighboring excess; period-based amortization is a projection and
does not remove the residual clear hitch. Report ordinary p50/p95/p99/max,
scanned/visited work, allocation/refusal and all seven process-level paired
ratios. Individual ticks are not independent replicates; zero visits must not
produce division by zero.

Memory accounting would distinguish cell and tail capacity, vector descriptors,
temperature/activity/scheduler storage and process peak RSS. Existing
`resident_cell_bytes()` omits split tails and is not whole-process memory.
Keep fixed-cell and fixed-memory analyses separate. Current split tails are
eagerly allocated: unread metadata does not establish absent optional-storage
cost, and accessed/clustered/dispersed payload claims need declared workloads.


## S2F source-only preflight registration — 2026-10-22

**Preregistered for untimed apparatus/scene qualification only; not an S2A
timing admission.** A separate continuation branch from S1 evidence head
7b71fbb9e1b4286197fb948da3d34f3c3bd5f879 contains the
[S2F decision and bounded preflight](mat-003-s2f-feasibility.md) and its
[machine registration](../../tools/experiments/mat003_perf/s2f_registration.json).
Registration commit 89b2b22635f53e0caee045bdc9fbfd3803f5b051 precedes
all S2F apparatus changes. The six source-C64-E8 untimed developer fixtures
are a subset of the proposed 24-context feasibility grid. No interleaved
AB/BA timing comparison, representation winner, restored-World persistence
or new pressure/momentum implementation is authorized. The S0/S1 checkpoint
and 17-arm evidence remain unchanged and separately source-qualified.

**Observed S2F developer preflight (2026-10-22):** Six source-C64-E8 untimed specimens, eight evidence-contract tests and a 57-file independent raw-artifact readback passed on GitHub-hosted Linux; see the [dated evidence](../audits/2026-10-22-mat003-s2f-preflight.md). Earlier failed attempts remain retained; this pass does not qualify the other 18 source contexts, a wider-carrier comparison or seven-pair S2A/S2B timing. The source-control binary and fixture were frozen separately from S1.
