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
| MAT compatibility after PR #470 transition | PASS — Documentation/provenance run 42291943955 accepted the chained `world.cpp` transition on exact head `312761f6afa65f2eea9751293c7d8c9985272565` |
| Documentation structure | PASS — run 42291943955 completed current documentation validation before the runtime-provenance gate |
| Published-runtime provenance | EXPECTED HOLD — run 42291943955 correctly reported both tracked Linux/Windows native binaries require rebuild for the changed native inputs; binaries/provenance were not updated because this task forbids runtime publication without explicit approval |
| Native source-scope advisory | PASS — run 42291943801 |
| Native C++ tests | **NOT ESTABLISHED** — run 42291943861 remained pending with no jobs created at the stop boundary |
| ASan/UBSan | **NOT ESTABLISHED** — same queued Native qualification had not executed |
| GDExtension/Godot regression | **NOT ESTABLISHED** — run 42291944100 remained pending with no jobs created at the stop boundary |
| Delayed render ACK/backpressure execution | **NOT ESTABLISHED** — the full Godot suite discovers the existing handoff regression, but the exact-head suite had not executed |
| Exact-head three-canvas before/after performance | **NOT ESTABLISHED** |
| Linux/Windows target-runtime qualification | **NOT ESTABLISHED** |
| Runtime binary publication | NOT PERFORMED |

The first hosted Documentation/provenance refusal reported expected admitted
`world.cpp` target `5a9de5e0...` and candidate `d743ca60...`. That is retained
as useful negative evidence: the guard failed closed until this explicit chained
transition was added. On the later exact-head run 42291943955 the material shadow
compatibility step passed. That run then stopped at the separate published-runtime
provenance gate because the checked-in Linux and Windows native binaries predate
the source change. No binary or provenance refresh was committed.

At the stop boundary, Native C++ run 42291943861 and GDExtension/Godot run
42291944100 were both still in GitHub Actions `pending` state with no jobs
created. They therefore provide no compiler, sanitizer, native-test or Godot-test
evidence for this candidate. Their mere presence in the queue is not qualification.

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

**STOP RECORDED.** Hosted Native C++/sanitizer and GDExtension/Godot qualification
could not be established before the bounded session ended: exact-head runs
42291943861 and 42291944100 remained pending without jobs. Exact parent/candidate
three-canvas target-runtime measurements were also unavailable. The PR therefore
returns to Draft with those gates unqualified.

The runtime-provenance failure in run 42291943955 is intentionally not repaired by
committing rebuilt binaries: this task explicitly forbids runtime binary
publication without owner approval. A source implementation and source-level byte
oracle must not be converted into a runtime exactness or performance claim by
inference.

## Continuation: exact-head Native evidence and transactional repair — 2026-11-06

The previous STOP ledger is historical and must not be rewritten as though
its pending jobs had executed at that time. Subsequently, at the unchanged
candidate head `97c19098fd2c238a75815836d4982668999f3f92`:

- [Native workflow 42295743251](https://github.com/techrote/cybersand/actions/runs/42295743251)
  completed successfully, including 190 C++ tests in native-normal,
  ASan/UBSan and TSan. This includes the two new hard-surface invalidation
  cases. Runtime logs, not merely the green workflow summary, establish execution.
- [GDExtension workflow 42295743187](https://github.com/techrote/cybersand/actions/runs/42295743187)
  built the Linux and Windows extensions successfully. Its Windows regression
  shards executed zero actual cases: the retained Windows DLL source manifest
  correctly rejected the modified `cyber_native_cell_world.cpp`. Some
  Linux shards passed with ephemeral exact-source builds; the full Linux
  suite did not complete. Neither is an all-OS qualification.
- [Docs 42298402388](https://github.com/techrote/cybersand/actions/runs/42298402388)
  passed after the earlier Ready attempt's intentionally failed retained
  runtime source-provenance gate. Palette-shader qualification also rejected
  a mismatched retained native runtime.
- A successful cross-build, source-valid C++ tests and an authored
  Godot byte-oracle are not equivalent to running the Godot oracle on
  the rebuilt candidate.

The independent review identified a two-part exception-safety hazard:

1. `World::take_hard_surface_invalidation()` previously cleared per-chunk
   tile bits while adding entries to a growing `std::vector`.
   Allocation failure partway through the loop could leave earlier chunks'
   flags lost and later chunks' flags pending. Collection now retains **all**
   flags until growth, sorting and deduplication succeed, then retires
   them in a nonthrowing pass.
2. `CyberNativeCellWorld::get_hard_surface_chunk_rectangles()` previously
   mutated its mask cache after consuming invalidation but had no persistent
   failed-publication marker. An exception followed by a separate new hard
   change could let the next query trust a partial cache. The adapter now
   marks cache invalid before any consumption or mutation, sets it valid only
   after committing the complete packet, and binds validity to the actual
   `World*` incarnation. Interrupted queries force full mask recovery.

Protected-source transition (explicit MAT-AUTH chain, not a rewrite of
the original #470 transition):

| Path | LF SHA-256 before | LF SHA-256 after | Source commit |
|---|---|---|---|
| `native/src/world.cpp` | `d743ca60406fc8f220206e005b37996f1d182005b1b86e0ed6591f050608fe1c` | `8bf0cb0058b139c32c030f5bbbc7e7e4555814c601598e1d6c7abecf7397d7fb` | `9ad76b21854b3e44fc9444f8293d3c36c619746b` |

This commit also changes the adapter's `.cpp` and `.hpp` transaction
guard; neither changes render packet fields or simulation law. The
transition is registered against issue #362 and Draft PR #470, pending
fresh hosted compatibility and runtime qualification. No pass claims
carry over to the repaired source head.

The ordinary Windows retained-DLL gate requires a committed LFS
pointer and matching published manifest and therefore intentionally
rejects new source. A separate ephemeral candidate workflow can test
a rebuilt, source-matched Windows DLL in its CI workspace without
replacing the retained runtime or relaxing its release gate. Such
candidate execution is **not** the canonical retained-runtime result.

The full three-canvas same-host before/after profiling remains required.
Parallel full-mask copying remains rejected absent comparable measurements.
Do not merge, publish replacement runtime binaries or claim acceptance.

## Owner-authorised finishing phase: reconciled lockstep and native-runtime publication

The owner explicitly authorised completing and integrating PR #470, including
the source-matched retained Linux/Windows runtimes. The branch has now
merged the accepted `main` lockstep change by an **ancestry-preserving
merge commit** (do not squash or rebase away the two reviewed MAT-AUTH
source-transition ancestors). The merged GDScript worker retains both
lockstep fencing and independently instrumented hard-packet/render/publication
stage timings; `native/src/world.cpp` and both native adapter files are
unchanged from the previously independently accepted implementation.

The dedicated `hs-pkt470-runtime-publication.yml` publisher is an
**explicit, source-bound, branch-leased** four-path publishing workflow,
using the existing audited shared publication engine. Its request records
sequence 1 and does not release or push to `main`. Before the publisher can
commit new runtime objects, it requires a fresh native hard-surface exactness
group, pinned source-matched builds for Linux and Windows, actual target-OS
Godot import and hard-packet byte oracle, both lockstep self-checks, render
ACK/backpressure, workbench/worker tests, original raw-log receipts, shared
native/build input SHA-256 ledgers and a four-path LFS pointer+manifest index
check. The only branch write is a fast-forward to the unchanged built source
tip protected by a `--force-with-lease` exact-SHA precondition.

**This checkpoint describes the publication admission request, not an
executed pass.** Confirm the final publisher run, source SHA and runtime
manifest hashes before accepting the resulting publication commit and
running the last Ready Native/GDExtension/Docs gates. Production merge remains
conditional on those checks, not on prior-source greens.

## Executed source-matched runtime publication — 2026-11-07

**PASS on publisher run [42320008406](https://github.com/techrote/cybersand/actions/runs/42320008406)**; source commit
`fa2a371e66c6e53c25f969ab260b5cfe69d94cd6` includes mainline
COUPLING-LOCKSTEP-001 and the previously reviewed HS-PKT C++/adapter bits.

- Native focused hard-mask/oracle/worker-parity cases: **PASS**.
- Linux GDExtension source-matched build and actual pinned Godot 4.7 import,
  complete packet byte oracle, lockstep semantics and actual 90-tick Rapier
  lockstep self-check, render patch handoff, worker interest ownership and
  full workbench canvas cases: **PASS**.
- Windows GDExtension source-matched cross-build, followed by actual Windows
  Godot 4.7 execution of the same scoped cases: **PASS**.
- Publisher single-parent append `fa1c5b72a35b28f75c91203004ac171e4d325a95`
  changed **only** the following paths:
  `godot/addons/cybersand_native/bin/libcybersand_native.linux.x86_64.so`,
  `godot/addons/cybersand_native/bin/cybersand_native.windows.x86_64.dll`,
  `godot/addons/cybersand_native/runtime-provenance.linux.json`,
  `godot/addons/cybersand_native/runtime-provenance.json`.
- Linux ELF SHA-256 `1409f2799da6335892a414ba2e87770549081602e5fb8528cdb2905af1ac30ea`,
  size 4,511,824 bytes.
- Windows PE SHA-256 `d27139de8070cbaf04d741564966593e31a4d46abd35d2714bcc50b5c6400c9c`,
  size 5,064,192 bytes.
- Both source manifests use schema 1, status
  `validated-development-runtime`, exactly 87 hashed native inputs and
  source-built provenance for the same immutable publish request head.
- No direct `main` branch write and no squash/rebase of the reviewed MAT-AUTH
  ancestry. The publisher's request and temporary workflow/helper/test
  scripts are retired by a separate descendant cleanup commit.

**The publication is complete, not an implied Ready-PR qualification.**
The final cleanup source head still requires current-source Docs, Native,
GDExtension/Windows/Linux and any scoped required CI results before merge.
