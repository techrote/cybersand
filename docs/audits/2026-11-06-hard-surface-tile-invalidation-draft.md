---
title: Incremental hard-surface collider tile invalidation — draft qualification
status: Current
document-kind: evidence
scope: 6 November 2026 source-pinned unqualified Draft PR for PR #406 native 64x64 hard-surface occupancy invalidation; no merge, no binary publication
canonical-for: []
last-reviewed: 2026-11-06
related-documents: [2026-11-06-pf-ballistic-tick-cost.md, ../architecture/chunk-tile-and-buffer-model.md, ../architecture/data-ownership-and-lifetimes.md, ../architecture/rendering-and-gameplay-bridges.md, ../architecture/simulation-tick-and-threading.md, ../operations/current-and-historical-validation.md]
---

# Hard-surface dirty tile optimization — bounded unqualified record

## Source and execution status

- Source parent: PR #406 `claude/water-ballistic-hybrid`, exact base `4a80af2a891332176a3912a235582d77d076a185`.
- Proposed implementation and tests: Git commit `79cdf5d94172f2c26ba19017a32414e0c7352aa5`, built atop that exact base. The subsequent documentation-only commit does not alter those sources. Use the Draft PR's live head for all final source-sensitive qualification.
- Native library / Godot extension built from this implementation: **none**. Source and runtime identity **not established**; no checksum can bridge an unbuilt runtime.
- Execution: **NOT RUN** for native tests, native sanitizers, C++ compilation, Godot regressions, byte-equivalence runtime cases, and fresh before/after timings. This is a source-only implementation checkpoint, not admission evidence.
- No production or original PR branch changes, no binary publication, no merge. Stop at the independent-review and source-matched runtime gate.

## Motivation and historical baseline (not paired with this candidate)

The [PR #406 6 November tick-cost record](2026-11-06-pf-ballistic-tick-cost.md#incremental-collider-packet) documents an earlier optimization that caches 64x64 rectangle groups but still scans the entire authoritative occupancy mask on each hard-surface revision. At its earlier source/toolchain provenance:

| Earlier profile | Packet before existing cache | Packet after existing cache | Limit |
|---|---:|---:|---|
| stress-canvas 2048x1024, gas off | 6.4–6.7 ms | 1.8–2.0 ms | Remaining whole-mask copy over ~2 Mi cells |
| bench-canvas 1024x512 | 1.3–1.5 ms | 0.35–0.39 ms | Earlier hardware/runtime only |
| my-canvas 512x512 | Not established in that packet table | Not established | Must measure fresh |

These numbers are historical, not a measured candidate baseline or a claim of savings from this commit. Stress-canvas with gas on is documented to fail the gas compartment capacity; record that separate outcome rather than silently converting it to a performance sample.

## Source design and lifetime review premises

1. Each resident native storage chunk preallocates a persistent grid of 64x64 occupancy revision stamps (four stamps for ordinary 128x128 storage chunks). Direct occupancy flips stamp their local tile; workers record hard-only per-chunk bounds in fixed job effects and stamp only at the phase barrier. Conservatively marked tiles are permitted; missed changes are not.
2. The new `World::copy_hard_surface_changed_tiles(region, since_revision, destination)` is a non-destructive, exclusive-owner, 64-aligned read. It ORs stamps into 64x64 **world-aligned** collider flags. It accommodates negative coordinates and native non-128 chunk sizes by mapping intersections. `World::clear` forces complete recovery for pre-clear revisions. A replacement/restored World is a different identity and requires a cold adapter cache.
3. Godot's adapter owns its cached 64bit occupancy words and per-tile rectangle vectors. A valid warm cache copies only native-flagged 64x64 masks, compares their **actual words**, rebuilds changed rectangles by the unmodified run/sort contract, and always emits the same complete packed packet layout. A cold/invalid/replaced cache copies every tile. A thrown partial rebuild invalidates the cache for subsequent recovery.
4. Existing render dirty bounds, `take_dirty_chunks`, native render leases, `take_render_snapshot`, worker publication, render serial/ACK/backpressure and physical step order are not changed. The new flags do not consume or acknowledge render dirtiness. The adapter's new diagnostic counters are read-only and do not change packet fields.
5. No parallel full-mask fallback was retained. It requires **paired measurements and race proof** before its complexity could be justified; tile tracking is intended to avoid most mask work entirely.
6. This source design is **unreviewed and unqualified**. Static inspection alone cannot establish byte identity, concurrency safety, build correctness or a performance gain.

## Reproduction and identity

Capture all baseline and candidate runs separately, with exact commit, clean tree, native source-input provenance, runtime SHA-256, Godot version, OS, CPU/thread count, compiler, build flags, seed, canvas identity, physics/Water/gas/ballistic/spray configuration, frame/window settings and raw timings. Never use the retained #406 published DLL as a runtime for this modified source.

```sh
git rev-parse HEAD
git status --short
git diff --check
c++ --version
godot --version
timeout 120 make test
timeout 300 make sanitize
timeout 300 make thread-sanitize
python3 tools/ci/check_docs.py
python3 tools/ci/check_m11_consistency.py
python3 tools/ci/check_repository.py
```

On a host with a **rebuilt, source-matched** GDExtension and imported Godot 4.7 project, run the native extension smoke and byte oracle:

```sh
godot --headless --path godot --editor --quit
godot --headless --path godot --script res://tests/test_hard_surface_incremental_packet.gd
godot --headless --path godot --script res://tests/test_render_patch_handoff_regression.gd
godot --headless --path godot --script res://tests/test_render_world_generation.gd
godot --headless --path godot --script res://tests/test_simulation_worker_interest_ownership.gd
godot --headless --path godot --script res://tests/test_tick_failure_regression.gd
godot --headless --path godot --script res://tests/test_workbench_canvas.gd -- --workbench
```

Adapter-only paired benchmark (the runtime SHA **must match the rebuilt source**, and the same seed/ticks/device must be used for both control/candidate). Supply valid local library paths, separate receipts and actual source SHA:

```sh
godot --headless --path godot --script res://tests/bench_hard_surface_packet.gd -- \
  --ticks=120 --seed=406 --source-head="$(git rev-parse HEAD)" \
  --runtime-path=/path/to/source-matched-libcybersand_native.linux.x86_64.so \
  --runtime-sha256=ACTUAL_64_CHARACTER_SHA256 \
  --output=/path/to/hard-surface-packet-receipt.json
```

This adapter-only script measures actual packed packet generation, full-projection oracle and native render exchange separately, including byte comparison at every tick. It **does not measure worker publication, Rapier collider installation, display upload or real workbench presets**. Those require the existing real workbench and main-thread campaigns, with before/after instrumented stages at identical configurations for `my-canvas`, `bench-canvas`, `stress-canvas`, and the worker render copy/publication path (`godot/tests/bench_render_copy_publication.gd`). Record median, p95, full-mask tiles copied, bytes, source/run identity, and the actual physics frame/tick rate; alternate control/candidate order to expose drift.

## New source tests and missing runtime gates

- `native/tests/test_world.cpp`: hard tile flags across signed 64/128 seams, soft-only changes, direct reversal whose mask bytes are equal, non-destructive repeated calls after `take_dirty_chunks`, generated chunk installation, clear/chunk retirement, failed-world refusal/recovery, single vs four-worker real mask words, fractional Water, Wood/Fire, Glass/Lava and Metal/Acid fixtures.
- `godot/tests/test_hard_surface_incremental_packet.gd`: complete packed integer-array equality with independent full projection over 90 reactive ticks, repeated query/no needless copy, interleaved render snapshot extraction, and reset cold-cache proof. These are **test definitions only**, not pass claims.
- Retained owner/worker tests: render-patch ACK, serials, pending full-refresh recovery, backpressure and generation; failed tick/quarantine; workbench real-body physics, scenery and native coupling. New tests do not replace those existing checks.
- Additional required qualification: ASan/UBSan/TSan (include 1/4/6 workers), Windows and Linux rebuilt Godot with complete ABI provenance, actual native packet byte comparison across profile variants, delayed render acknowledgement/failed publication, source-hash gating, and full rendered workbench stage measurements. Check no sanitizer/runner exclusions.
- Do not classify negative or absent results as green. Draft CI suppresses expensive native/Godot jobs; a Draft state cannot provide merge qualification.

## Independent-review checklist (all pending)

- [ ] Check every native material mutation/reaction, transport/swap and deferred event writes a matching hard-only stamp; prove no false negatives for changes reversed during one tick.
- [ ] Check chunk size variants, signed coordinates, 64/128 seams, generated chunks, resets, restore/replace lifetimes and revision wrap/recovery.
- [ ] Check fixed per-job bounds, overflow/refusal, all phase merges, visibility barriers, no tick allocations/locks, and TSan worker parity.
- [ ] Compare native old/new full mask bytes for each tick, not merely hashes or final physical-state values.
- [ ] Compare **every complete packed collider packet element** to independent projection after each edit/tick, not only rectangle counts.
- [ ] Confirm render `Published`, `NoChanges`, `Backpressure`, `CapacityExceeded`, bytes, serial progression, leases, delayed ACK, failed tick handling and full-refresh behaviour against the source control.
- [ ] Confirm packet and collider cache lifetime under reset, world change, same revision reused by a different World, and interrupted allocations.
- [ ] Verify exact changed-files scope, source-to-runtime manifests, shader/native dependencies, and no native physics/liquid/material or render packet layout delta.
- [ ] Execute native tests and both sanitizers, Godot Linux/Windows, relevant existing render/worker/Rapier/workbench regressions; retain raw logs.
- [ ] Collect paired median/p95/canvas/worker measurements for control vs candidate with stable hardware/CPU load; show changed tile counts and identify performance regressions.
- [ ] Independently assess parallel whole-mask fallback; retain only if a measured gain justifies risk (not included here).
- [ ] Run repository/docs checks, retrieval evaluation, exact-head CI and independent review; leave Draft and **do not merge or publish runtime binaries** before owner approval.

**Disposition: STOP / UNQUALIFIED DRAFT.** The implementation is isolated for review, but source-matched native builds, actual mask/packet equality, cross-platform Godot/worker behaviour and paired performance measurements have not been established. Any new head requires fresh qualification.
