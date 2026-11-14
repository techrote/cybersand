---
title: GEN-006 actual native CYPS cross-process Windows continuation gate
document-kind: audit
status: Experimental
scope: Source-guarded Windows native whole-World restart, crash-before-publication and corruption controls; selective eviction remains unimplemented
last-reviewed: 2026-11-06
related-documents: [../systems/world-storage-and-interest-region.md, ../reference/level-saves-and-replay.md, 2026-11-06-gen006-native-cyps-scaling.md]
---

# GEN-006 #194 — independently compiled Windows native restart experiment

**EXPERIMENTAL / production HOLD / DO NOT MERGE.** This follow-up targets the
unqualified Windows platform left by the earlier real-Linux native checkpoint
restart on Draft #459. The branch-only workflow
`.github/workflows/gen006-native-restart-windows.yml` compiles the unchanged
actual native World and existing C++ restart executable with hosted Windows
Server 2022 / LLVM-Clang using the installed MSVC toolchain environment.

## Exact scope and controls

- Same test source/driver as the qualified Linux experiment; do not create
  another serializer or replace the accepted World implementation.
- Runtime cohorts: one- and four-**configured** native workers, eight signed
  resident chunks, real fixed ticks and Water 17/19 tuples.
- Separate producer and reader **OS processes** publish/restore actual CYPS
  bytes through a bounded experimental file envelope. Each cohort checks three
  post-restart ticks against the producer's uninterrupted hash.
- The producer exits with status 17 before replacement-root publication; the
  prior checkpoint must remain readable. Truncated and same-length corrupted
  records must refuse, distinguishing envelope/length refusal from actual
  native CYPS decoder refusal.
- Explicitly capture source commit/tree, native World CPP/HPP Git blobs,
  compiler/runtime, original logs and machine-readable witness. A successful
  workflow is a Windows *whole-World* continuation result only; there is no
  actual selective eviction, material journal, durable ACK coordinator,
  power-loss proof, actor sidecar or cross-source #398 migration.

Run the workflow on exact branch head and inspect
`build/gen006-native-windows/native-restart-witness.json` plus raw artifact.
The workflow must check `world.cpp` blob
`aed1bb10e480493397f5c5eac8ba2336f495b9f9` and `world.hpp` blob
`bb2f6e33dd1ad8e4a2b2aec7b34ccfb8229b6cb3`.

Reproduce on a Windows x64 Developer Command Prompt at the checked-out commit:

```cmd
clang++ -std=c++20 -O2 -DNDEBUG -I native/include native/src/world.cpp native/src/material_rules.cpp native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp native/tests/test_gen006_native_restart.cpp -o native-restart-probe.exe
python tools/experiments/gen006_native_restart.py --native native-restart-probe.exe --out build/gen006-native-windows
```

This is a qualification-only apparatus; no production source or other owner
branch is modified. The source checks and API readiness gates remain strict.
**Next blocked admission:** owner-approved selective bundle/owner pin contract
and native eviction/reload with bounded fixed-tick continuation. A pass here
would not satisfy GEN-006 #194.
