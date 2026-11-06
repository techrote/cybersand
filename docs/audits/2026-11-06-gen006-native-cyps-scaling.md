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


## Follow-on: actual native render-dirty versus durable intent/ACK boundary

**New experimental question, separately qualified in the same native executable:** can
display-oriented \`take_dirty_chunks()\`, physical equality and an in-flight
whole-World CYPS byte copy establish durable user-edit intent, save failure
recovery or a generation-fenced ACK? The source says **no**; the new native
negative/control runs show the concrete reason.

Each of 1- and 4-configured-worker cohorts installs eight real signed native
chunks, executes two genuine native ticks, and reports observed participation
rather than inferring four. The test then: (1) records an external same-value
Wall edit intent while \`World::set_cell_state\` returns unchanged and render
dirty remains zero; (2) performs a Wall-to-Empty tombstone and consumes its
render dirty rectangle without durable persistence; (3) shows original native
baseline-only regeneration would resurrect Wall, while strict resident install
correctly refuses replacement; (4) stages a real complete CYPS snapshot,
then mutates Water to quantity/state 17; (5) models an earlier save ACK and
shows why it needs owner mutation-generation fencing; (6) verifies full native
same-source CYPS restoration of the latest Empty/Water state.

\`DurableIntentControl\` is an **isolated in-test owner-control model**:
it increments on explicit edit intent (including same-value), permits ACK
only for the current generation, and retains pending intent after a simulated
persistence failure. No production API, new native journal, filesystem
publication, OS process crash, actual eviction/reload, recipe migration,
source identity or accepted persistence semantics are introduced.

### Reproduce and qualify

The existing branch-only \`gen006-native-cyps-scaling.yml\` compiles the same
unchanged World and the augmented fixture with GCC 13 in \`-O0\` and \`-O2\`
profiles. In addition to the previous six scaling rows per profile, each
profile must emit and independently validate **two**
\`GEN006_NATIVE_DIRTY_ACK_JSON\` rows (1/4 configured workers), each with
\`owner_intent_generation=owner_ack_generation=3\`, true tombstone restoration,
and restored Water quantity 17. Both raw logs and JSON lines are retained
even if an earlier build or test fails.

**Status on writing:** UNQUALIFIED until exact-head hosted artifacts and
normal Documentation/provenance evidence are inspected. Existing #459
scaling evidence is from the preceding immutable head; do not carry that
pass forward as evidence for this follow-on.

### Distinct production gate

\`DirtyChunk\` and \`take_dirty_chunks\` are documented display notifications,
not durable edit provenance or a save ACK channel. The real World has no
public durable owner mutation-generation/intent/tombstone transaction.
Before selective saving, the owner must admit a separate bounded mutation
receipt and publication/ACK handshake that survives render consumption,
same-value edits, edits-to-Empty and older asynchronous save completions.
The current negative cases **do not demonstrate an existing production
persistence bug**, because there is no production sparse persistence writer.
No protected source, production codec or manual acceptance changed.


### Preserved first follow-on run: workflow parser negative

At first follow-on head \`311e316aadbb62e314c4b5286040c5dfe07b77e7\`
(tree \`b56a020db9869936a473b22bad5e4dbc3bc39220\`), the
[Ubuntu native run #42180054964](https://github.com/techrote/cybersand/actions/runs/42180054964)
**failed the legacy workflow grep**, which counted eight
\`"result":"PASS"\` rows after the two new diagnostic records were
added, instead of the six pre-existing scaling records. The actual
native fixture completed **248 assertions with zero native failures**
in this \`-O0\` run; the source-locked raw failure and artifact are
retained. This is NOT a passing workflow qualification; \`-O2\` was
not attempted on the failed run.

The follow-on correction scopes the six-row count to exact
\`gen006_native_cyps_scaling\` records, while separately validating
the two new \`gen006_native_dirty_ack\` records with JSON field
checks. No native fixture, assertions, production World or defaults
are changed by this parser correction. Require a new complete
exact-head hosted run before claiming acceptance.
