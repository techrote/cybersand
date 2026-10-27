---
title: Issue 12 Stage 3B current-main and Noita structural-detachment reassessment
status: Current
document-kind: audit
scope: 2026-10-27 source/issue inspection and owner-intent reconciliation, not executable soliding or runtime/performance qualification
canonical-for: [issue12-20261027-stage3b-reassessment]
last-reviewed: 2026-10-27
related-documents: [../operations/soliding-structural-detachment-programme.md, ../operations/soliding-programme.md, ../operations/soliding-stage3b-production-plan.md, ../systems/settled-region-discovery.md, ../architecture/soliding-lifecycle.md]
---

# Issue #12 Stage 3B source reassessment — 2026-10-27

## Evidence boundary and frozen source

**Inspection-only:** GitHub `main` commit
[`c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59`](https://github.com/techrote/cybersand/commit/c9ebe39c6cab086b7f7207ee3d80a6de2cb21f59),
tree `9575c8d6ff966f1e954eadd8e452be34c0a33069`,
plus the cited issue and contract text. No local clean worktree/LFS check,
new Windows/Linux binary, Godot render, native test, benchmark or
performance run was executed for this review. The original September
tests retain **their** pinned source/platform qualifications.

## Source-backed status matrix

| Question | Current source/record | Finding |
|---|---|---|
| Is discovery real? | `native/include/cybersand/settled_world_discovery.hpp`, `native/src/settled_world_discovery.cpp`, `native/src/world.cpp` | **Current:** real mutation/activity/coverage witnesses, bounded journal and opt-in observer |
| Is connected-region observation real? | `native/include/cybersand/settled_regions.hpp`, `native/tests/test_settled_regions.cpp` | **Current:** exact-tuple components, graph/dependency and bounded reconstruction, not a movable material aggregate |
| Does ordinary gameplay run it? | `WorldConfig` in `native/include/cybersand/world.hpp`: `settled_discovery_enabled=false`, `settled_region_connectivity_enabled=false`, both service budgets 0 | **No** by default; observations do not authorize simulation skip or Rapier creation |
| Is it unlimited world-scale? | `kMaximumIntegratedRegionTiles=4096`, <=32×32 subtile observations, bounded capacity/refusal | **No**; full 4096×1024-cell representation corresponds to up to 2048² area if fully tiled, not unlimited residency |
| Does it own source pixels or body handoff? | `World::advance_settled_regions` forwards to observer; `SettledRegionSnapshot` has area/bounds/digests, not exact transfer payload | **No**; cells retain authority |
| Is the lifecycle implemented in World? | `native/include/cybersand/soliding_lifecycle.hpp` says “executable Stage 2 contract model only” | **No**; tests validate isolated invariants |
| Is a Rapier contact bridge present? | `godot/native_extension/cyber_native_cell_world.cpp`, `godot/scripts/rapier_physics_bridge.gd`, [coupling contract](../architecture/rigid-body-and-cellular-coupling.md) | **Yes** for independent bodies, masks and derived static terrain, **not** native tree promotion |
| Is an async desktop host already available? | `godot/scripts/simulation_worker.gd`, [threading contract](../architecture/simulation-tick-and-threading.md), [PLAY #263](https://github.com/techrote/cybersand/issues/263) | **Yes**, reuse rather than inventing another World clock |
| Was near-rest reversal demonstrated? | Historical [PR #23](https://github.com/techrote/cybersand/pull/23), [Phase 0 reuse audit](2026-09-19-issue-12-phase0-reuse.md) | **Historical isolated one-slot rectangle proof**, not current runtime tree |
| Is Stage 3B performance accepted? | [#70](https://github.com/techrote/cybersand/issues/70) open | **No** source-matched complete Stage-3B final campaign established |

The exact current `RegionComponentKey` is material + state_a + state_b
+ temperature. These values are vital for payload accounting but not
an adequate universal mechanical bond policy. Do not infer that
neighbouring bark/wood/hot-wood pixels must be disconnected physical
objects or that identical quiet Sand pixels are cohesive.

## Historical performance is negative evidence, not a new measurement

The frozen [Stage-3A integrated cost record](issue-12-2026-09-19/stage3-cost-results.md)
measured a 2048² sparse-edit case on Ryzen 5 2600X:
ordinary control complete p95 **0.0754 ms** versus Stage-3A
discovery complete p95 **39.3214 ms**, with approximately **36.2 ms**
region-service p95 and approximately 67 MB added memory in the
old connectivity layout. That is an earlier **cost model**, not
current Stage-3B timing or an accepted speedup. #58–#65 subsequently
added safety, capacity sizing, sparse witnesses, indexing and bounded
reconstruction. Their own source-matched results must be preserved;
the complete updated Stage-3B workload/cost campaign remains open.

## What is outdated, and what remains reusable?

The parent [#12](https://github.com/techrote/cybersand/issues/12)
historical top checkpoint still says #62 is next, although
#56–#65 and #69 are completed in the current
[Stage-3B production plan](../operations/soliding-stage3b-production-plan.md).
Remaining issues [#66](https://github.com/techrote/cybersand/issues/66),
[#67](https://github.com/techrote/cybersand/issues/67),
[#68](https://github.com/techrote/cybersand/issues/68) and
[#70](https://github.com/techrote/cybersand/issues/70) remain **open**;
their original dependencies govern **Track B** global discovery/cost
qualification. The September Stage-4–Stage-7 serial ladder is not
evidence that completing global discovery is technologically necessary
before a **bounded local tree detachment** proof.

Intervening October work changes relevant authority surfaces:
[MAT-001 persistent reactions](2026-10-18-mat001-material-reaction-progress.md),
the new [construction-solid catalogue](../systems/building-material-catalogue.md),
[pressure cache/dormancy](../architecture/pressure-optimization.md) as a
separate optimization *comparison*, [PLAY #263](https://github.com/techrote/cybersand/issues/263)
existing async host, and future [GEN-006 #194](https://github.com/techrote/cybersand/issues/194)
residency/eviction/persistence. This is a **reason to rebase/review
consumer assumptions**, not proof that #58–#65 code is defective.

Retain the existing source-owned revision and ABA fences, bounded
work, explicit unknown/refusal, complete-only publication, exact
membership and failure semantics. Do not add global digest/graph
complexity before showing which consumer needs it.

## Noita: source-supported insight and limits

Petri Purho's [GDC 2019 Noita talk](https://www.gdcvault.com/play/1025695/Exploring-the-Tech-and-Design/)
([video](https://www.youtube.com/watch?v=prXuyMCgbTc),
[tree segment ~08:26](https://www.youtube.com/watch?v=prXuyMCgbTc&t=506s))
shows coherent tree rotation; the prior frame review found first
clear rotation around **08:26.333** and a video **reset**, not a
re-anchoring proof, around **08:55.667**. The talk's rigid body
and integration passages are approximately **05:42–07:18** and
**07:18–09:19**.

The [April 2019 Noita developer interview](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation/)
explicitly describes selectively carving eligible terrain/collapsing
material into falling rigid bodies, as well as per-pixel rigid-body
membership and shape recalculation/split. It supports using **selective
event-driven extraction** as a candidate architecture. Neither the
tree footage nor interview establishes exact CyberSand collision
switchover, transfer capacity/rollback, conservation, automatic
body-to-native restoration or a reusable Rapier API implementation.

**2026-10-27 owner clarification:** the actual priority is solid
support-loss/toppling/rolling. Earlier Water-sheet soliding was an
investigatory tangent and is not a Track-A prerequisite.

## Disposition and gaps to investigate

**Approved owner direction:** split [#12](https://github.com/techrote/cybersand/issues/12)
into Track A event-driven **real native-cell** structural detachment
(first gameplay milestone [#281](https://github.com/techrote/cybersand/issues/281))
and Track B separately qualified Stage-3B/4 acceleration.
The [canonical Track-A contract](../operations/soliding-structural-detachment-programme.md)
defines the source/payload/collision gate, finite tree test,
failure matrix and stages. The historical #66–#70/#69 route is
preserved and not silently changed; #68's typed local result is useful
only when its actual source dependency/contract is reconciled.

**Blocking design questions before code:** identify one owner and an
atomic static-collider-retire/dynamic-collider-activate fence;
verify how to reserve inactive Rapier shape/body creation safely;
prove source/anchor closure at chunk or unknown boundaries; choose
a conservative material-cohesion/attachment policy; implement an
explicit keep-static refusal for overlarge/unknown structures;
pin active aggregates against GEN-006 eviction; determine whether
any unfinished Stage-3B component is actually necessary.
No proposed hook is claimed to exist until inspected and tested.

**Change-scope matrix:** #12/current owner intent, focused Track-A
charter, Stage-3B plan navigation, lifecycle and macro-fracture
cross-references, roadmap/handover, RAG routes; **no modifications** to
native sources, tests, liquids, default backend, PR #23 evidence or
#69's frozen experiment schema. This audit's status “Current” means
the dated source *inspection* is real, not that the planned mechanism
is currently executable.
