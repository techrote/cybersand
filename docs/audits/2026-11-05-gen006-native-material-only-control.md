---
title: GEN-006 actual native material-only rehydration negative control
status: Planned
document-kind: audit
scope: Isolated native baseline-versus-continuation discriminator for GEN-006; no streaming or codec admission
last-reviewed: 2026-11-05
related-documents: [../systems/world-storage-and-interest-region.md, ../reference/level-saves-and-replay.md, ../architecture/data-ownership-and-lifetimes.md]
---

# GEN-006 native material-only rehydration control — 5 November 2026

**Disposition: experimental evidence only. No merge or production adoption requested.**

Tracks [GEN-006 #194](https://github.com/techrote/cybersand/issues/194).
Accepted main at inspection: ba9cbc89029be88b812af59b19e5c59829bbcd90.
Only an independent native test, isolated diagnostic workflow and this audit are
changed; no native World implementation, serialized format, Godot runtime,
material catalogue, or production default is modified.

This experiment differs from [#415](https://github.com/techrote/cybersand/pull/415)'s
synthetic save/ACK and filesystem interruption apparatus and
[#230](https://github.com/techrote/cybersand/pull/230)'s proposed semantic
codec. GEN-003/004/005/007 (#190–193) are closed; MAT-003PREPASS #204,
MAT-AUTH #352–354 and the historical MoltenGlass cross-source import gate
[#398](https://github.com/techrote/cybersand/issues/398) remain open.
These independent experiments do not admit production stream persistence.

## Actual native discrimination

The native test (native/tests/test_gen006_material_only_rehydration.cpp) builds
against actual existing native World source and installs eight generated chunks
at signed chunk coordinates -1, 1, 3, 5, 7, 9, 11 and 13 (all y=0, chunk side
128), with small Water/Sand chambers in distinct scheduling cores. Identical
source fixtures are tested with configured native worker counts 1 and 4.

After three real native ticks, a partial-Water quantity (state_a=17) and
temperature=417 are written at world cell (-98,30), a Wall becomes explicit
Empty at (-102,26), and a real native explosion is queued for the following
tick. A full-World CYPS checkpoint is restored into a new World; ten subsequent
native ticks of uninterrupted versus restored control are compared for
physical-state hash, completed clock, Water state and quantity ledger.

The **material-only negative control** reads each current material identity
from the native chunk, installs those IDs into another actual new native World,
then checks the result. The new chunk has identical current material identities,
including Water and Empty, but has **different partial Water quantity,
authoritative temperature and physical state hash**. Strict fresh installation
refuses a second install onto an already resident chunk. Erasure remains
visible Empty in the copy, but the fact that it was an intentional removal of
old baseline Wall is no longer recoverable from material IDs alone.
A material-ID overlay cannot satisfy the GEN-006 continuation/reconciliation
contract.

This is NOT actual chunk eviction, despite using a newly constructed native
World. The positive CYPS restore is **whole-World**, not a selectable chunk
streaming format, and does not authorize migration of old saves.

## Reproducible hosted execution and retained negative evidence

- [Run 42000752962](https://github.com/techrote/cybersand/actions/runs/42000752962),
  source 78af9004f988de299143bc5aac1eb0495df3c90e, Ubuntu 24.04,
  g++-13, single negative-coordinate chunk: **PASS, 140 assertions**.
  Four configured workers produced **one observed worker**; four-worker
  participation was therefore NOT qualified by this first run.
- [Run 42001006985](https://github.com/techrote/cybersand/actions/runs/42001006985),
  source ca3b2c761335fa79940ca122475da74bb2e47261,
  eight chunks with 64 candidate-core slots: **FAIL**, native
  active scheduling-core capacity exhausted at assertion index 10.
  This is a real bounded-capacity negative. Candidate expanded-core entries
  count before deduplication; do not turn the error into a silent retry.
- [Run 42001167272](https://github.com/techrote/cybersand/actions/runs/42001167272),
  source 0bc5c430c4148c981f2ef4008411cb4ad3041e89:
  **PASS, 156 assertions** with eight chunks, bounded 512 candidate-core
  slots, 64 candidate-chunk slots and 16 resident chunks. Compiler:
  g++-13 (Ubuntu 13.3.0-6ubuntu2~24.04.1), C++20 -O0 -g1 -pthread.

| Real native observation | Configured 1 | Configured 4 |
|---|---:|---:|
| Max participating workers (live and restored) | 1 | **4** |
| Whole-World CYPS checkpoint size (bytes) | 827,265 | 827,265 |
| Tick-exact continuation checks | 10 | 10 |
| Assertions | 78 | 78 |
| Result | PASS | PASS |

All build, native execution, provider-policy and upload stages passed
in the corrected run. [Raw artifact 13403155168](https://github.com/techrote/cybersand/actions/runs/42001167272/artifacts/13403155168).
The 1 and 4 configured scenarios are each qualified against their OWN
same-config uninterrupted controls; this is not a separately proven
cross-worker-global-trajectory parity result. Windows and Godot are untested.

### Reproduction on the exact checkout

    mkdir -p build/gen006-native-probe
    g++-13 -std=c++20 -O0 -g1 -pthread -Wall -Wextra -Wpedantic -I native/include native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp native/tests/test_gen006_material_only_rehydration.cpp -o build/gen006-native-probe/probe
    timeout 240s build/gen006-native-probe/probe

The branch-scoped workflow is
.github/workflows/gen006-native-material-only-probe.yml. It uses GitHub-hosted
ubuntu-24.04 and retains raw source/tree, compiler, build and result logs.
The normal Native/GDExtension/Windows suite is not substituted by this scope.

## Limitations and next gate

No demand, live player/camera, selective eviction, actual filesystem durability,
crash recovery, cross-boundary transfer atomicity, native actor/usable state,
recipe rebase, mutation-provenance journal or historical import transition has
been implemented or qualified. Same-source CYPS behavior cannot settle the
pre-H1 MoltenGlass #398 compatibility contract.

**Next:** review and admit the smallest supportable owner-bound native chunk
snapshot and lease/edge-work/pin contract. Only then attempt actual opt-in
selective native eviction/reload against fixed-tick uninterrupted controls,
preserving unsupported event/actor/old-source refusal. Keep the present
diagnostic branch experimental; do not merge or close #194.
