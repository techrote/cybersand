---
title: Incremental hard-surface collider packet optimisation
status: Current
document-kind: evidence
scope: Draft PR #470 source-qualified implementation, exactness plan and runtime-qualification hold for independent 64x64 hard-surface invalidation; no merge or runtime publication
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-pf-ballistic-tick-cost.md, ../architecture/simulation-tick-and-threading.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/material-catalogue-shadow.md]
---

# Incremental hard-surface collider packet optimisation — 6 November 2026

## Disposition

**IMPLEMENTED ON DRAFT PR #470; SOURCE/CI QUALIFICATION IN PROGRESS; RUNTIME PERFORMANCE
QUALIFICATION NOT YET ESTABLISHED. DO NOT MERGE.**

This is a bounded child of PR #406. The task began from the then-current
`claude/water-ballistic-hybrid` head
`4a80af2a891332176a3912a235582d77d076a185`, not a historical audit pin.
The dedicated branch is `gpt/hard-surface-dirty-tiles-20261106`.
The last source commit before compatibility metadata is
`51d462537480324a4c11b3bf92f1ecb1882d8685`.

No native simulation law, material hard-surface classification, liquid algorithm,
render packet layout or runtime binary is intentionally changed or published by
this work. The implementation cannot make a performance acceptance claim until
the exact source is rebuilt and timed on an identified runtime.

## Cost and ownership map

The pre-change collider adapter already cached each complete 64x64 tile's rectangle
list, but every hard-surface revision first called
`World::copy_hard_surface_bits({0,0,extent.x,extent.y}, ...)`. That read every
cell in the finite canvas before comparing each 64-bit row word to the preceding
mask. On the stress-canvas this is the remaining full-canvas mask scan identified
by the parent audit.

The three publication stages have distinct ownership:

| Stage | Authoritative reads | Writes / ownership | This PR |
|---|---|---|---|
| Collider hard-surface packet | World material cells through hard-mask projection; hard revision | Adapter-owned mask cache, per-64x64 rectangle cache and complete packed collider packet | Replaces full-canvas discovery scan with World-owned collider invalidation plus copies of only potentially changed 64x64 masks |
| Native render exchange | Render-owned World dirty chunks and RG8 projection | RenderSnapshotExchange pending payload/serial and render dirty acknowledgement | **Unchanged ownership.** Collider never calls or consumes `take_dirty_chunks()` |
| Worker publication | Retained render exchange, retained collider packet and copied simulation/actor values | Fresh immutable `CyberSimulationSnapshot`, then one mutex-protected published pointer | Payload and admission are unchanged; diagnostic stage timings are added only |

The collider stream is intentionally independent of render backpressure and render
ACK. Delaying or consuming a render packet cannot clear collider invalidation, and
consuming collider invalidation cannot clear a render dirty rectangle.

## Implementation

`World` now owns a separate hard-surface invalidation stream. A default 128x128
storage chunk contains four 64x64 collider tiles. Each resident chunk holds fixed
tile bits; there is no per-edit allocation. Direct writes set the bit only when
`MaterialRules::is_hard_surface(before) != is_hard_surface(after)`.

Parallel jobs record the same fixed tile bits in their private `JobEffects`.
The coordinator merges them only after the normal phase barrier. Hard-surface
revision advancement retains the existing semantics. Because invalidation bits
are monotonic until consumed, multiple edits that return a tile to its original
mask still leave the tile potentially changed; the adapter copies that tile and
then observes that its final bytes are unchanged.

Destructive reset and unsupported/non-64-aligned storage geometry use an explicit
full-refresh marker. A failed World refuses invalidation consumption. The adapter
also fails closed to one full refresh if a hard revision advanced but a prior
consumer attempt could have consumed invalidation before its cache commit.

On normal revisions the adapter:

1. consumes the independent invalidated 64x64 tile coordinates;
2. copies only those tile masks with `copy_hard_surface_bits`;
3. compares the actual 64 row words with its retained mask;
4. rebuilds rectangle geometry only for tiles whose final mask words differ; and
5. assembles the same complete packed packet from cached tile rectangle lists.

Out-of-view halo invalidation is not copied into a finite adapter packet. Cold
startup, reset and explicit recovery still use the existing full-mask path.

## Exactness coverage

The native and Godot fixtures added/expanded for this change are designed to
compare actual bytes/words, never hashes as a substitute for packet identity.

Native `test_world.cpp` covers:

- initial full refresh and repeated empty consumption;
- 64-cell and 128-cell boundary crossings with exact invalidated tile coordinates;
- collider/render dirty ownership in both consumption orders;
- hard-surface ABA mutation with identical final `uint64_t` mask words;
- Wood/Fire, Glass/Lava and Metal/Acid hard/non-hard transitions;
- fractional Water as a non-hard change;
- generated-chunk installation, destructive reset and conservative geometry fallback;
- failed-tick quarantine and recovery; and
- one-worker versus four-worker invalidation vectors, full hard-mask words,
  hard revision and native state over reactive ticks.

`godot/tests/test_hard_surface_incremental_packet.gd` compares every incremental
complete `PackedInt32Array` packet with
`diagnostic_full_hard_surface_chunk_rectangles()`, which is rebuilt from the
complete display projection. It adds focused seam, ABA, reaction, fractional
Water, reset, repeated-query, render-exchange independence and worker-parity
checks while retaining the seeded 90-step reactive stress oracle.

The render-independence arm compares actual render patch metadata and RG8 cell
bytes, plus serial/status/full-refresh/channels, between a control World and a
World whose collider packet has been consumed. Existing render handoff regression
tests remain responsible for delayed ACK/backpressure sequencing.

## Instrumentation and reproducible profiling

`CyberSimulationSnapshot` retains its existing `snapshot_copy_time_ms` and adds
diagnostic-only observations:

- `render_exchange_time_ms`;
- `hard_surface_packet_time_ms`; and
- `snapshot_publication_time_ms`.

These fields are not render/collider payload fields and are not used by admission
or simulation decisions.

The non-gating profiler
`godot/scripts/hard_surface_packet_profile.gd` installs the repository's built-in
`my-canvas` (512x512), `bench-canvas` (1024x512) and `stress-canvas`
(2048x1024), warms each for 30 ticks and observes 180 ticks. It emits JSON with
mean/p50/p95/max timing, source SHA, OS/CPU/Godot identity and the loaded native
binary SHA-256.

Run from an exact source checkout after rebuilding the native extension:

```text
CYBERSAND_SOURCE_SHA=$(git rev-parse HEAD) godot --headless --path godot \
  --script res://scripts/hard_surface_packet_profile.gd -- --workbench
```

On Windows PowerShell set `CYBERSAND_SOURCE_SHA` to
`(git rev-parse HEAD)` before invoking the same Godot script.

The parent audit's existing canvas timings remain historical/reference evidence
only. They are not re-labelled as a PR #470 baseline. A valid before/after
comparison must rebuild both the exact parent source and the exact candidate with
the same runtime/configuration and retain the emitted records.

## Parallel full-mask fallback

Parallel full-mask copying was considered as the fallback alternative. It is not
retained in this candidate. The incremental path removes the need to read
unchanged cell masks, whereas parallel copying still performs work proportional
to the complete canvas and introduces another execution policy for the same
read-only projection.

The task requires a demonstrated measured benefit before retaining the parallel
fallback. No exact-source target-runtime comparison has yet been executed for this
PR, so there is deliberately **no** claim that a particular thread count or
parallel-copy strategy wins. If runtime profiling later shows a pathological
high-dirty case, that experiment should remain a separately measured change.

## MAT-AUTH protected-source transition

`native/src/world.cpp` is a protected non-identity consumer. The immutable
compatibility lock and `BASELINE` are not changed. PR #470 appends exactly one
reviewed-per-file transition to the existing chain:

| Field | Value |
|---|---|
| Path | `native/src/world.cpp` |
| From LF SHA-256 | `5a9de5e09a8665392677902ab501696aafefb5bbd2d2800e3dc1059b87a6f17d` |
| To LF SHA-256 | `d743ca60406fc8f220206e005b37996f1d182005b1b86e0ed6591f050608fe1c` |
| Source commit | `51d462537480324a4c11b3bf92f1ecb1882d8685` |
| Issue / PR | #362 / #470 |

The source commit is an ancestor of the metadata commit and retains the exact
candidate `world.cpp` bytes. The changed hunks add collider invalidation
bookkeeping around existing mutations and merge barriers; they do not edit
`MaterialRules::is_hard_surface`, material descriptors, pair reaction tables,
liquid policy identities, quantity codecs or retained material oracle inputs.

As required by the transition contract, any eventual integration that keeps this
entry must preserve `51d46253...` in ancestry with a merge commit. **PR #470 is
not authorized for merge by this record.**

## Qualification ledger

| Gate | Result at this record |
|---|---|
| Starting source provenance | PASS — PR #406 head observed as `4a80af2a891332176a3912a235582d77d076a185` before branch creation |
| Dedicated branch / no existing-branch write | PASS |
| Exact packet oracle coverage in source | IMPLEMENTED |
| Native hard invalidation ownership/parity coverage in source | IMPLEMENTED |
| Render payload/serial/status byte comparison in source | IMPLEMENTED |
| Reproducible three-canvas profiler | IMPLEMENTED |
| First Documentation/provenance run | EXPECTED REFUSAL — run 42291478159 rejected unadmitted `world.cpp` bytes; this directly motivated the chained transition above |
| MAT compatibility after PR #470 transition | PENDING fresh hosted run |
| Native C++ tests | PENDING fresh hosted run |
| ASan/UBSan | PENDING fresh hosted run |
| GDExtension/Godot regression | PENDING fresh hosted run |
| Exact-head three-canvas before/after performance | **NOT ESTABLISHED** |
| Windows target-runtime qualification | **NOT ESTABLISHED** |
| Runtime binary publication | NOT PERFORMED |

The first hosted Documentation/provenance refusal reported expected admitted
`world.cpp` target `5a9de5e0...` and candidate `d743ca60...`. That is retained
as useful negative evidence: the guard failed closed until this explicit chained
transition was added.

## Independent-review checklist

An independent reviewer should treat this checklist as **unchecked** until they
inspect the exact PR head and its executed evidence:

- [ ] Confirm PR #470 still targets `claude/water-ballistic-hybrid` and no
      implementation commit was written to PR #406 or `main`.
- [ ] Diff `world.cpp` and verify every hard invalidation write corresponds to
      a pre-existing hard-surface revision transition or reset boundary.
- [ ] Verify job-local tile evidence cannot race shared chunk metadata and is
      merged only after the existing phase barrier.
- [ ] Verify collider consumption never calls/acknowledges `take_dirty_chunks()`.
- [ ] Confirm cold/reset/error recovery cannot leave a stale adapter mask.
- [ ] Run native direct, generated-chunk, ABA, failed-tick and 1-vs-4-worker tests.
- [ ] Compare actual full hard-mask words and actual complete packed packet words;
      do not substitute content/physical hashes for those comparisons.
- [ ] Run existing render delayed-ACK/backpressure regressions and confirm serial,
      status, bytes and acknowledgement behavior are unchanged.
- [ ] Run ASan/UBSan and applicable Linux/Windows Godot regressions at the exact head.
- [ ] Run the three-canvas profiler on exact parent and candidate binaries under
      the same runtime/configuration; retain raw JSON and native binary hashes.
- [ ] Measure any parallel full-mask-copy experiment independently before considering
      it for retention.
- [ ] Re-run MAT compatibility and confirm the lock/digests/identity inputs remain
      unchanged and only the explicit chained `world.cpp` transition is new.
- [ ] Keep the PR Draft/unmerged until runtime-performance and owner acceptance
      requirements are explicitly satisfied.

## Stop boundary

If hosted source/sanitizer/Godot qualification cannot be established, or if the
exact target runtime needed for comparable parent/candidate canvas measurements is
unavailable, this work stops at the Draft PR with the unqualified items named
above. A source implementation and passing byte oracle must not be converted into
a runtime performance claim by inference.
