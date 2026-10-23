---
title: MAT-003PREPASS D state and persistence execution handoff
status: Planned
document-kind: runbook
scope: Source-qualified inventory and GEN-006 acceptance prerequisites, experimental codec evidence limits and pending owner decisions
canonical-for: [mat003prepass-gen006-state-handoff, gen006-persistence-admission-prerequisites]
last-reviewed: 2026-10-23
related-documents: [../architecture/gen006-semantic-state-and-persistence.md, ../architecture/data-ownership-and-lifetimes.md, ../systems/world-storage-and-interest-region.md, ../systems/procedural-semantic-planes.md, ../reference/level-saves-and-replay.md, ../reference/retrieval-index.md, architecture-programme.md, documentation-maintenance.md]
keywords: [MAT-003PREPASS, GEN-006, state inventory, experimental codec, persistence acceptance, baseline, migration]
---

# MAT-003PREPASS D — GEN-006 state/persistence handoff

**Scope:** [#204](https://github.com/techrote/cybersand/issues/204) design-only workstream D, consumed by [GEN-006 #194](https://github.com/techrote/cybersand/issues/194). The [proposed canonical state contract](../architecture/gen006-semantic-state-and-persistence.md) owns field/identity/lifecycle semantics. This document owns evidence limits, contract gaps, source map, fixture commands, acceptance gates and deferral. **No GEN-006 code, production storage migration or carrier decision is authorized or claimed by this handoff.** Work is isolated on `docs/mat003prepass-gen006-state-contract-20261023`; PR #221 remains untouched.

## Inspected source identity and authority

- **Current `main` at inspection (2026-10-23):** `1f9336388f11be39abaae340a781a5eef52115d4`. This is a GitHub-sourced branch/commit inspection, **not** a local checked-out or compiled Windows/Linux binary. No local uncommitted user tree was inspected or modified.
- **Primary source:** [PrecisionStorage](../../native/include/cybersand/precision_storage.hpp), [material descriptors](../../native/include/cybersand/material.hpp), [World owner and configuration](../../native/include/cybersand/world.hpp), [World/Chunk/ticks/writes](../../native/src/world.cpp), [generation schema/identity](../../native/include/cybersand/world_generation.hpp), [four-plane fixture/link definitions](../../native/include/cybersand/generation_planes.hpp).
- **Current canonical boundaries:** [chunk model](../architecture/chunk-tile-and-buffer-model.md), [activity/deadlines](../systems/activity-dirty-regions-and-waking.md), [ownership](../architecture/data-ownership-and-lifetimes.md), [storage/interest](../systems/world-storage-and-interest-region.md), [material kernels](../systems/materials-and-rule-kernels.md), [generation](../systems/procedural-world-generation.md), [semantic planes](../systems/procedural-semantic-planes.md), [CYSD1 omissions](../reference/level-saves-and-replay.md), [determinism](../architecture/determinism-and-boundary-transfers.md), [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md), [ADR-010](../decisions/ADR-010-failed-tick-quarantine.md).
- **Evidence boundary:** #16/#17 source-led experiments and #204's source-qualified L/S2 controls are architecture inputs. [PR #211](https://github.com/techrote/cybersand/pull/211) and [PR #221](https://github.com/techrote/cybersand/pull/221) are separate experimental branches; their review and campaign claims do **not** select a production carrier or validate GEN-006 continuation. The latest PR #221 readiness/containment state is independent of this branch. Related MAT-002 [#179](https://github.com/techrote/cybersand/issues/179) and LCB [#213](https://github.com/techrote/cybersand/issues/213) do not imply a new pressure/state codec.
- **Important source trap:** `native/src/world.cpp` still has a stale comment describing a four-byte cell, whereas compiled `PrecisionStorage` asserts size/align 8/8; source-qualified bit widths are material16, state_a16, state_b8, epoch8, 16 unassigned. This handoff records the contradiction; no production comment/edit is included.

## Design decision and capability classification

| Concern | Current source fact | Proposed GEN-006 rule | Admitted by D? |
|---|---|---|---|
| Native cell | 8B carrier, narrow runtime `Material` enum; `World::set_cell_state` non-Water state_a max255 | Canonical validated logical state, not raw bits | Proposal only |
| Water | FreeMass quantity in state_a, coherence in state_b, policy-dependent bounds; partial transfer writes two cells | Serialize exact typed quantity/coherence, atomic source+dest journal | Proposal only |
| Other materials | State-specific burn/growth/strength/cure/heading/payload, whole-cell CellularYield and pair conversions | Material-state schema registry, embedded-ID checks, default/reaction migration | Proposal only |
| Optional temperature | Ambient default, chunk-owned separate int16 array | Persist non-default values; absent schema-optional field defaults from frozen policy | Proposal only |
| Scheduling | 8-bit epoch, activity/quiet state, earliest absolute `next_interaction_tick`, pending explosions | Stable checkpoint clock, recent-touch discriminator, block state and ordered deferred work; epoch rebase | Proposal only |
| Recipe and feature | GEN-001–005 deterministic generation, stable hierarchy/plane/fixture identities | Retain old baseline reconstruction; fixture retirement/source progress; bundle dependency receipts | Proposal only |
| Mutations | World marks render dirtiness; no dedicated serialization generation/journal | Durable monotonic generation + idempotent operation journal, explicit same-value intent/Empty tombstone | Proposal only |
| World streaming | Sparse chunks, strict fresh install, interest pause; no general eviction API | Immutable snapshot, atomic save, capacity/pin/refusal, restoration of coherent bundle | **Not implemented** |
| Actors/physics | Rapier and usable lifecycle are separately authoritative | Pin regions until independently versioned serializer exists | **Unsupported for eviction** |
| Render/settled diagnostics | Snapshot leases/dither and read-only discovery separate from cell authority | Reconstruct/retire under checked incarnation; do not confuse with canonical state | Proposal only |

**Outstanding schema-specific field audit before runtime:** material-by-material valid state ranges and initializers (including state-carried `Cloner` and `Rocket` IDs), all solver/profile flags and optional tool states, event ownership across plane/world seams, hard-surface revision consumers, tick/excluded scheduling predicates, serialized actor/usable dependency footprints and sidecar migration. The existing `content_hash` excludes edit intent and most scheduler state; `state_hash` covers more but still cannot be used as a complete durable representation/compatibility proof. Future MAT-003 momentum/pressure and multi-liquid modes are *requirements to register*, not checked-in state.

## Proposed exactness levels and restore policy

GEN-006 must explicitly name its **supported domain**; proposed minimum is a complete **healthy native cellular** checkpoint with World policy and pending bounded events. Do not claim full Godot/Rapier replay. Distinguish these tests:

1. **Semantic reconstruction:** all admitted material/state_a/state_b/temperature bytes and recipe+baseline identity match after save/import. No scheduling claim.
2. **Safe functional reentry:** absolute tick, block wake/deadlines, region pause and fresh physical epoch rebasing pass; new chunks cannot accidentally update twice or grant sampled support to just-written grains.
3. **Fixed-input/fixed-tick native continuation:** same initial checkpoint, event/order/policy and selected ticks yields semantic state, pending work, conservation and supported support predicates equal to an uninterrupted control. Explicitly state what external actor/time domains were pinned.
4. **Durable/crash consistency:** only acknowledged generations may be evicted; interrupted writes/saves and duplicate retries preserve the last validated published checkpoint. This is separate from level re-export equivalence and `content_hash` comparison.

Per [ADR-004](../decisions/ADR-004-interest-region-and-reconfiguration.md), reentry is **paused** while off-interest/off-resident, without wall-time catch-up. Mid-tick export is refused. No handler may silently discard queued work crossing a chunk boundary; pin all affected owner bundles or durably journal the whole transfer and its exactly-once replay receipt.

## Experimental reference fixture: bounded, not runtime integration

Source: [`tools/experiments/mat003_gen006_codec_fixture.py`](../../tools/experiments/mat003_gen006_codec_fixture.py). Invoke from root:

```sh
python3 tools/experiments/mat003_gen006_codec_fixture.py
```

It uses Python standard library only, a tiny `CSG6X1` **experimental** magic, fixed-size little-endian header, SHA-256 over canonical bounded JSON payload, unique sorted cell indexes, synthetic *allowlisted* identities and an explicit 8×8 maximum. It is not CYSD1 or an approved durable format; fixture-side material and Water domains are intentionally narrower than all possible experimental precision policies. Checks include:

| Fixture family | Expected invariant/refusal |
|---|---|
| Negative chunk/plane, Water 127 mass / coherence12, touched flag, block deadline, nonambient temperature, pending seam transfer | Canonical roundtrip equality; no raw bitmask/epoch coupling |
| Explicit equal-to-baseline edit and Empty tombstone | Provenance and edit-intent retained independently of current cell value |
| Absent optional temperature sidecar | Explicit ambient default; no fabricated allocation |
| Truncated header, malformed length, trailing bytes, wrong digest | Refusal before interpretation |
| Schema major mismatch, catalogue/solver identity mismatch | Explicit incompatibility, never material-ID reinterpretation |
| Reserved/unknown material, truncated cell state, invalid Water 0/coherence13 | Fail closed; no saturation/truncation |
| Duplicate cell/intention, malformed sidecar value/length, over-quota chunk | Refusal without partial writes |
| Unknown required extension | Incompatibility; no silent omission |
| Mutation CAS, identical operation replay and conflicting duplicate ID | Commit once, idempotent identical retry, refuse conflict or stale generation |
| Async receipt with wrong session/chunk/plane/incarnation/generation/recipe/baseline/job ID | Refuse late result even if cancellation occurred |

**Explicit noncoverage:** actual World allocation, eviction/reload, multithreaded race, I/O crash durability, full catalogue-state validator, full event schema, field sidecar migration, separate Rapier/usable state, thermal evolution, native tick continuation or benchmark. These require *new* implementation/source-linked fixtures in GEN-006. Tests must never be cited as proof that the runtime can save or evict modified native chunks.

## GEN-006 acceptance prerequisites (ordered)

- [ ] **Registry freeze:** version and content-hash a catalogue with 0–131/invalid10 and embedded material references, per-material state schema including units/initialization and all effective solver/config/recipe identities. Decide stable content-addressed baseline retention and schema-major migration/refusal table.
- [ ] **Authoritative coverage:** audited native World, layer/fixture/link/usable/actor boundary matrix with an explicit supported domain; fields not persisted must be deterministically reconstructed with independent witnesses, otherwise pin/refuse.
- [ ] **Durable generation and semantics:** independent monotonic mutation generation, same-value edit intent, explicit Empty tombstones, journal provenance/op IDs, atomic cross-chunk departures/arrivals, feature retirement/source consumption. Retain old recipe and/or old immutable baseline content.
- [ ] **Owner transaction and fencing:** owner-mediated snapshot with drained phase work, fixed bounded memory/backpressure, optional-sidecar ownership and preflight, strict fresh installer preserved, checked restore path separate, and session/incarnation/recipe/generation/job fencing at commit.
- [ ] **Quiescent clock + support:** persist completed global clock, absolute due deadlines, interest/applied coverage, activity/quiet and recent-write predicate; rebase physical epochs without granting false support or running twice. Failed World and mid-tick snapshots must refuse.
- [ ] **Crash and compatibility:** versioned checksummed envelopes, strict length/coordinate/material/state quotas, atomic publication, journal replay/deduplication and recovery to last valid commit. Negative fixtures cover old save completion, unknown IDs, incompatible solver, missing old baseline, missing/oversized sidecar and torn checkpoint.
- [ ] **Native qualification:** uninterrupted vs restored fixed-tick controls; signed multi-chunk seams; Water mass/source+destination conservation and event count; thermal/cure/combustion state; Mercury/pair/Ice deadlines; pause/reentry/wrap; deleted feature/source no resurrection; same-value/overlap recipe preview + recheck and idempotent retry.
- [ ] **Actual host/lifecycle:** camera/player demand over signed coordinates and beyond finite 1024², hard resident/job/cache/save budgets with visible refusal, evict/reload/process restart and interruption fault matrix. Document explicit actor/usable pins and unsupported scope. Compare varied worker counts/admission orders only for deterministic *baseline*, not automatic live physics lockstep.
- [ ] **Canonical docs/RAG and CI:** update storage/owner/level-save/recipe/depth/feature interfaces, configuration budgets, roadmap, test guides, retrieval corpus/index/questions. Run `tools/ci/check_docs.py`, `check_repository.py`, `check_m11_consistency.py`, lexical retrieval evaluation, applicable native and Godot tests on exact supported platforms; source/artifact seals and negative outcomes retained.

## Decide now / safely defer

| Decide **before** GEN-006 runtime implementation | Safely defer with explicit guard |
|---|---|
| Stable semantic schema and per-material catalogue/solver/state identities | Which C64/C72/C80/C128 carrier, epoch width or optional SoA layout wins performance |
| Durably recorded mutation intent, generation CAS and content/old-baseline retention | Packed9 vs memcpy9 vs aligned16 vs split sidecar, and future C128 use |
| Epoch recent-touch and block-deadline support-equivalence policy | How to optimize epoch rollover and optional field density |
| Supported atomic chunk/layer/fixture/pending-boundary transaction + pinned unsupported domain | Future pressure/momentum solvers, unified liquids, wide material IDs, generic velocity |
| Crash/refusal contract, quota defaults, explicit pin/backpressure and migration registry | Compression, storage backend, file naming, snapshot delta representation (subject to boundedness) |
| Current GEN-007/GEN-005 recipe+feature identity and old-baseline availability | Full actor/Rapier solver/contact persistence and strict whole-game replay |

**Ready for GEN-006 architecture design once the owner accepts the semantic/refusal policy; not ready for streaming implementation or runtime acceptance without the checkboxes above.** Follow [GEN-006 #194](https://github.com/techrote/cybersand/issues/194), not this prepass fixture, as the execution owner. G-final and production carrier selection remain open.
