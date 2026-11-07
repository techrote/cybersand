---
title: GEN-006 experimental save/ACK and eviction-fence fault preflight
status: Planned
document-kind: evidence
scope: Test-only single-chunk owner/disk publication sequence with real POSIX temporary filesystem operations; no native World streaming or serializer admission
canonical-for: []
last-reviewed: 2026-11-05
related-documents: [../systems/world-storage-and-interest-region.md, ../reference/level-saves-and-replay.md, ../architecture/data-ownership-and-lifetimes.md, ../operations/github-development-and-release.md]
---

# GEN-006 — independent save/ACK/eviction fault preflight

## Exact source and authority

**Source inspection:** accepted main commit [ba9cbc89029be88b812af59b19e5c59829bbcd90](https://github.com/techrote/cybersand/commit/ba9cbc89029be88b812af59b19e5c59829bbcd90), 5 November 2026. Primary route: [GEN-006 #194](https://github.com/techrote/cybersand/issues/194). All GEN-003/004/005/007 prerequisite issues are closed, but GEN-006's native runtime residency, eviction and durable sparse persistence are **not** Current capabilities. The existing World::install_generated_chunk admits only wholly absent chunks; set_simulation_region is a pause/interest policy, not eviction. CYSD1 omits continuation state. CYPS2/CYPS3 supplies a distinct native liquid-comparison **whole-World** tick-boundary physical-state continuation API, not per-chunk streaming or a durable mutation-intent journal. World::take_dirty_chunks is not a durability-acknowledged mutation-generation API. These distinctions are grounded in native/include/cybersand/world.hpp, the world-storage and level-save contracts, and must not be masked by successful experiments.

**Adjacent unmerged design:** [MAT-003PREPASS D #230](https://github.com/techrote/cybersand/pull/230) proposes the semantic field/schema/receipt and mutation-intent contract. Its CSG6X1 codec has 17 **nonproduction** checks, including mutation CAS and stale-generation fencing, but does not execute real disk publication, ACK or eviction. #230 is not an adopted production schema or native runtime. Material authority #353-A's shadow metadata is integrated; later #353-B consumer migration is still separate. #354 / [#398](https://github.com/techrote/cybersand/issues/398) explicitly demonstrate unresolved sleeping MoltenGlass historical-import continuation. This experiment neither selects a cell carrier nor resolves that migration.

## New bounded executable output

Run from repository root:

    python3 tools/experiments/gen006_save_ack_fault_fixture.py

This **independent, synthetic Python harness** uses a temporary Linux/POSIX directory and real write, flush, fsync, os.replace and directory fsync calls. It separates an immutable single-chunk snapshot from a durable manifest pointer and an owner-side acknowledgment. Snapshot payloads are explicitly small (8 KiB); modeled owner leases are limited to two. It tests:

- Modeled save→ACK→eviction with deliberate destruction of the only live synthetic payload→new-incarnation reload of an opaque record containing signed chunk (-1,0), Water amount/coherence, a thermal sample, due-tick sample, same-value edit and explicit Empty intent. The bytes roundtrip, but there is **no native physical continuation claim**.
- New edit after capture, edit interleaved at the pre-publication owner barrier, late old result after newer durable generation, generation-collision and retired session/incarnation: stale results cannot publish or mark live state clean.
- Injected failure after blob temp-file sync, after blob publication and after manifest temp-file sync: the earlier committed manifest remains the recovery root, dirty owner cannot evict. Failure **after** the manifest replacement models a lost ACK: on-disk checkpoint can reload, but the live owner refuses eviction without acknowledgment.
- Corrupt blob, incompatible recipe, failed-tick owner, non-drained snapshot lease, pending boundary and actor pin, over-capacity snapshot, invalid signed coordinate: explicit refusal.

**Exact executed code**: repository test file blob 2f1d7a3f3e653ccd12b275e2101d4be4db157ae2 (verified against the locally executed file's Git blob hash); local SHA-256 5bd6cd1ccf797d4a19203fa103fa2d7341d4666a53c2d928d1401283db209db3. Execution: Python 3.13.5, Linux x86_64 6.18.57, 5 November 2026: **14/14 unittest cases PASS**, approximately 0.06 s, including real temporary-file publication and injected exceptions. Python bytecode compilation also passed. These are local fixture checks only; hosted CI and actual native/Godot/Windows execution **not run**.

## Precise disposition and blocking interfaces

**EXPERIMENTAL — NOT ADMISSIBLE AS A WORLD SAVE/STREAMING IMPLEMENTATION.** This code is deliberately isolated under tools/experiments/, adds no production APIs or runtime defaults, does not alter material or GEN data, and does not claim native World ownership, worker participation, 1/4-worker equivalence, actor/Rapier restoration, Water conservation, real shader/desktop behavior or fixed-tick continuation.

The model intentionally assumes one exclusive writer and one chunk and calls a test-only callback at the would-be owner barrier; it does **not** implement concurrent process-safe file CAS, multi-chunk/plane atomic bundles, transactional boundary transfer, a native snapshot capture, sidecar schema migration, feature registration, optional solver-state reconstruction, real worker draining, clock/epoch rebasing, reclaiming orphan blobs, disk quota/retention, rollback from a corrupted pointed-to checkpoint, or Windows filesystem sync guarantees. Its read validator covers only the narrow synthetic manifest/payload; it is **not** suitable for untrusted storage. These are explicit incomplete requirements, not presumed future equivalences.

**Next bounded gate:** owner-admit (or revise) the minimum supported GEN-006 native continuation domain and immutable snapshot/write-set fencing, including the CYPS2/3 versus per-chunk extraction choice and #398 historical-save refusal. Then add an independent **native read-only test** that exercises one safe completed-tick snapshot/restore against an uninterrupted fixed-tick World control, with actual actor/boundary pins and matching material/policy identities. Keep mutable world.cpp and MAT/SOL/LCB/PLAY source untouched until its write-set owner and schema gate are resolved. Do not merge this draft experimental branch as proof of GEN-006.
