---
title: GEN-006 actual native whole-World CYPS snapshot scaling discriminator
document-kind: audit
status: Experimental
scope: Test-only Linux native owner-tick-boundary snapshot cost; not a selective serializer
last-reviewed: 2026-11-06
related-documents: [../systems/world-storage-and-interest-region.md, ../reference/level-saves-and-replay.md, ../architecture/data-ownership-and-lifetimes.md]
---

# GEN-006 #194 — whole-World CYPS scope and snapshot latency

**EXPERIMENTAL / DRAFT / DO NOT MERGE.** Accepted intake main:
\`06522e300dcf91efbab0ac8f4f4370af72cf2029\`, tree
\`40fa1b41bc1d7c809101bcf95125ac56019f424b\`.
Do not claim platform results until inspecting the final-head Actions evidence.

## Distinct question

Does the **actual native** \`World::save_physical_state()\` produce data
proportional to all resident chunks, and how much exclusive-owner time does
a full checkpoint consume even when a single distant stored cell changes?
This is a cost discriminator only, not a proposed chunk checkpoint or
codec migration. It is separate from #422's state-loss/continuation proof,
#435's optional witness/actor refusal, #442/#448's bundle atomicity experiments,
#426's session fencing and #458's synthetic filesystem coordination.

## Executable protocol

Run the branch-scoped workflow
\`.github/workflows/gen006-native-cyps-scaling.yml\` on GitHub Ubuntu 24.04.
It compiles **current unchanged** \`native/src/world.cpp\` and required native
implementation files with GCC 13 C++20. The test executes six cohorts:
1/4 **configured** workers × 1/8/32 signed sparse chunks, 128×128 each.
Each chunk has four active native scheduling cores and material Wall/Water/Sand.
Two actual native ticks precede the checkpoint. The maximum **observed**
worker participation is reported separately from configuration.

Each cohort captures five \`steady_clock\` wall-time saves (after warmup),
checkpoint byte size, resident cell bytes, one-cell-edit checkpoint size,
exact native restoration hash and material readback. Unchanged consecutive
save bytes must be canonical and all cohorts must be nonempty. A distant
one-cell Wall mutation must change the serialized checkpoint and survive
a genuine \`World::restore_physical_state\` roundtrip. The byte footprint is
a whole-World cohort observation, not evidence of a per-chunk API.
The source-guarded CI artifact retains raw samples, compiler, SHA, tree and
original failures; workload and timings are not end-user-gaming benchmarks.

Local reproduction with GCC 13 and repository root:

\`\`\`sh
g++-13 -std=c++20 -O0 -g1 -pthread -Wall -Wextra -Wpedantic -I native/include \
  native/src/world.cpp native/src/material_rules.cpp \
  native/src/scheduler_geometry.cpp native/src/settled_world_discovery.cpp \
  native/tests/test_gen006_cyps_scaling.cpp -o /tmp/gen006-cyps-probe
/tmp/gen006-cyps-probe
\`\`\`

**Owner boundary:** Native \`World\` is single external owner; the diagnostic
does not concurrently save against ticks or borrow mutable storage. It does
not alter production algorithms, material authority, cell/carrier ABI,
Godot/Rapier, worker scheduler, codec, defaults, current save bytes, or
existing PR branches. It does not cover Windows, power-cut durability,
cross-process publication/leases, actor/usable state, real selective eviction,
fixed-tick continuation after *selective* reload, or full production review.

## Admission meaning / next step

If the actual hosted data show the expected full-World scaling, retain it as
negative evidence against using CYPS whole-World copy/restore as the production
per-chunk persistence or admission mechanism. Demand a minimum selective
owner-domain/pin/refusal contract before any native writer starts an eviction
implementation. Explicitly refuse optional state that #435 showed does not
survive whole-World restore, and defer historical #398 cross-source import.
No production permission is inferred from a green diagnostic.


## Profile control

This second candidate revision runs the same unchanged World and test source
twice: the initial \`-O0\` debugging profile and an explicitly optimized \`-O2
-DNDEBUG\` profile. Each has independently validated JSON rows and retains raw
timings. Do not compare absolute wall times across uncalibrated machines or
infer a user GPU or Windows throughput result. Treat the profile as provenance,
not a production setting change.
