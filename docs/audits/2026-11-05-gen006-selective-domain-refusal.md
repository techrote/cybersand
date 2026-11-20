---
title: GEN-006 native selective-domain refusal and owner-state inventory
status: Planned
document-kind: audit
scope: Experimental native authority inventory and compiled refusal controls; no selective checkpoint admission
last-reviewed: 2026-11-05
related-documents: [../systems/world-storage-and-interest-region.md, ../reference/level-saves-and-replay.md, ../architecture/data-ownership-and-lifetimes.md]
---

# GEN-006 #194 — native selective continuation-domain refusal (2026-11-05)

**EXPERIMENTAL ONLY. Keep Draft; no merge, production codec adoption or source mutation.** Accepted main at inspection: ba9cbc89029be88b812af59b19e5c59829bbcd90. Source blobs: native/src/world.cpp = aed1bb10e480493397f5c5eac8ba2336f495b9f9; native/src/world_pressure.inc = cc332c338decaac6b0d4a0deaa2dfb6a77012a52. The only changes are a standalone native test, branch-scoped hosted workflow and this audit.

## Primary decision: selective continuation is not admitted

Current CYPS2/3 is **whole-World**. Source native/src/world_pressure.inc lines 1994–2149 writes all resident chunks and World-global quantity, pressure gas/compartment history/flow and inertial ledgers; lines 2152–2460 validates and constructs a **new World**. No currently exposed per-chunk checkpoint or active-World erase/restore transaction is available in the inspected native/include/cybersand/world.hpp. Current World::install_generated_chunk accepts only a fresh absent chunk and material IDs. Camera-interest exclusion pauses selected simulation work but does not evict chunk storage.

| Authority / owner | Exact source | Minimum selective rule |
|---|---|---|
| Material ID, state A/B, update epoch | world.cpp:293–330; world_pressure.inc:2082–2087 | Save exact real state and preserve separate mutation-intent Empty tombstone |
| Thermal state, activity blocks and deadlines | world.cpp:296–318; world_pressure.inc:2076–2089 | Clock/epoch rebase with no elapsed-time catch-up and boundary wakes |
| Water and quantity closure | world_pressure.inc:2090–2101 | Keep fractional mass, overfill and global quantity ledger consistent |
| Gas/topology/compartment history | world_pressure.inc:2102–2140,2350–2448 | **Refuse** selective pressure chunks until an atomic cross-chunk/global transaction exists |
| Inertial sidecars and ledger | world.cpp:260–264,316; world_pressure.inc:2097–2099,2141–2145 | Require separately admitted global ledger update and sidecar restore |
| Queued explosions | world_pressure.inc:2052–2058,2241–2253 | A radius can cross chunk seams; reject incompatible partial eviction |
| GCR-SEL preceding-tick granular arrival | world.cpp:317–318,2493–2519; world.hpp:284–293 | Not encoded by CYPS; **pin/refuse** while enabled unless explicitly supported |
| Actor transient mask/usable/leases | world.cpp:2173–2263; world.hpp actor API | Mask is host-owned, not material; actor/usable region pin or separate approved rebind |
| Settled discovery | world_pressure.inc:1994–2000 | Explicitly refused by current CYPS export |
| Recipe, session, mutation generations and intent | #194; design-only #230 | Not inferred from material/physical hash; require admitted owner receipt/journal |

## Executable native negative controls

The source-only test native/tests/test_gen006_selective_domain_refusal.cpp uses actual unchanged World, compiled in the branch-scoped workflow. For both 1- and 4-*configured*-worker cohorts:

1. Construct a signed negative chunk, activate real per-chunk GCR-SEL witness allocation before tick, finish a native tick, save and restore CYPS. The source and restored Worlds have matching ordinary material/tick/physical hash. The restored World has **zero witness storage** and cannot enable it post-tick. Equality of physical hash is thus insufficient for that optional actor coupling domain. The fixture does **not** assert nonzero arrival impulse events.
2. Construct a real transient occupancy mask over authoritative Empty, save and restore. The actor mask is omitted (stored Empty preserved), with the original/full physical-state hash detecting the loss.
3. Corrupt the digest, require native refusal, and verify the original World remains unaltered. Advance both source/restored Worlds one additional tick for a separate ordinary cellular continuation check.

This tests **scope and refusal**, not genuine per-chunk eviction/reload, Rapier actor restoration, gas/Inertial continuation, four actual workers, cross-source H1 import, Windows, or Godot.

### Exact-source runner

The branch-specific workflow .github/workflows/gen006-native-domain-refusal.yml uses Ubuntu 24.04 and GCC 13 with actual production native World sources. It records exact checkout commit, tree, compiler, CI-provider policy, build output and unmodified fixture stdout/stderr, including negative/failure attempts.

~~~sh
g++-13 -std=c++20 -O0 -g1 -pthread -Wall -Wextra -Wpedantic -I native/include \
  native/src/world.cpp native/src/material_rules.cpp \
  native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp \
  native/tests/test_gen006_selective_domain_refusal.cpp -o /tmp/gen006-domain-refusal
/tmp/gen006-domain-refusal
~~~

**A hosted PASS is not claimed until the actual exact-head run completes.** Draft Native/Godot skips are not passes. Failed/queued/cancelled attempts must retain their original status and output.

## Dependencies, ownership and next gate

This slice is independent of [#415](https://github.com/techrote/cybersand/pull/415) (synthetic durable save/ACK fault injection), [#422](https://github.com/techrote/cybersand/pull/422) (real native whole-World continuation and material-ID loss), and [#426](https://github.com/techrote/cybersand/pull/426) (native demand/session and threaded stale-result fencing). No files or active owners from those drafts were changed. [#230](https://github.com/techrote/cybersand/pull/230) remains an unadmitted proposed schema. Historical sleeping MoltenGlass cross-source import [#398](https://github.com/techrote/cybersand/issues/398) remains separately blocked. Closed GEN-003/004/005/007 (#190–193) are prerequisites, not production streaming acceptance; #204 and MAT-AUTH #352–354 retain distinct gates.

**Proposed, not accepted, narrow domain:** a separate exclusive owner could first attempt a no-pressure/no-inertial/no-actor/no-discovery/no-granular-arrival bounded cellular chunk, but must prove whole boundary-activity/queued-event/quantity dependencies absent or atomic; enforce healthy completed-tick boundary, snapshot leases, dirty-state durable ACK, incarnation/session/recipe generations, exact signed coordinate identity and failure-no-mutation. Then run genuine native eviction/reload and fixed-tick uninterrupted comparison with observed workers. Refuse unsupported or uncertain cases, never discard or regenerate live mutated authority.

**Next gate:** independent admission of the minimum source/ownership/halo/pin rules **before** a single authorized production writer touches protected World or persistence files. Preserve failure evidence. Record progress and stop.
