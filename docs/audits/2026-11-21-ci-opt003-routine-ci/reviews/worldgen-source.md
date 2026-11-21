# CI-OPT-003 worldgen compiler-order independent review

Date: 2026-11-21 UTC. Reviewer: independent `review_worldgen` agent; did not author candidate code or tests.

## Disposition

**SOURCE / CONTRACT GO; PERFORMANCE AND HOSTED QUALIFICATION PENDING.** No confirmed P1/P2/P3 defect in the reviewed production Makefile change. This is approval to continue qualification, not a merge recommendation without measured value and final-source hosted results.

Reviewed accepted base: `846fe0533b3170e7b01f690518da49fc40cc24d1`.
Reviewed uncommitted candidate branch: `ci/ci-opt-003-native-acceleration-20261121`.

Exact reviewed source fingerprints:

| Input | SHA-256 |
| --- | --- |
| Makefile | `f1373f3df2f3259803b9213d37863ed59e97900affe8ece72241c36ae7874222` |
| tools/ci/test_worldgen_build_inventory.py | `26d28698d2bde976d832e116b59a0072e152d8b5f9f70cb60f4a8b20d7bc4c93` |
| Two-file diff against base | `30aaad8b734af313586afe758ca67a4cda5ad33979241eeb7776180905f62b99` |

## Independent inspection

The only executable change is in Makefile lines 255–327: move each generation object directory creation into its corresponding object recipe, and make both plain/threaded world_generation objects the first prerequisites of each worldgen aggregate. This uses existing `make -j2`; it introduces no additional compiler slot, job, cache, instrumentation change, or test-result reuse.

The directory mkdir commands are still fail-closed recipe commands. `mkdir -p` is safe when two object recipes create the same directory concurrently. Every generation object retains its exact source, all shared headers, and Makefile as rebuild dependencies. Threaded/plain and normal/sanitized namespaces remain separate. No other Makefile rule references the removed directory targets. Existing partial-compiler-output handling is unchanged.

The independent expected-command checker was unchanged. I ran it on both the accepted-base worktree and the candidate, then compared full argument vectors as multisets and complete executable order. Both modes preserve exactly 28 compiler/link commands, 12 generation objects, 16 binaries, and 16 ordered tests. All sanitizer flags, `-pthread` distinctions, warnings, optimisation flags and source paths are byte-for-byte equivalent at the argument level. Reports: `worldgen-inventory-comparison.json`.

The complete native source, fixtures, Godot tree, workflows, family wrapper, command/budget inventory, verifier and watchdog policy are unchanged. Consequently all six required families, twenty outer commands, run/source/attempt binding, timeouts, failure artifacts and final Native aggregation still apply. No new path can turn a skipped, cancelled, partial or failed family into accepted evidence.

## Reproduced checks

- `python3 tools/ci/test_worldgen_build_inventory.py`: **15 tests PASS**, including actual GNU Make cold-graph rendezvous, both compiler flag families, all compiler and test arguments, compile failure before execution, test failure with exact-prefix stop, and all inherited adverse inventory controls.
- `python3 tools/ci/test_native_watchdogs.py`: **21 tests PASS**.
- `python3 tools/ci/test_native_shards.py`: **45 tests PASS**.
- Independent actual GNU Make warm-graph exercise: each mode compiles 28 outputs on its cold invocation, compiles zero outputs on the immediately repeated invocation, and executes all 16 tests again in unchanged order. Report: `worldgen-warm-graph.json`.

These are **81 passing focused tests plus independent inventory and warm-graph checks**. The compiler double establishes scheduling and failure behavior only. It does not establish native test outcomes or elapsed performance.

## Profiling evidence caveat

The initial scratch `profile_make.py` was inspected separately from the candidate. Its raw `passed` field alone was insufficient as an acceptance reducer: it did not require the expected number and identity of compiler/test receipts, and its source check ignored untracked inputs. I informed the integration owner before hosted evidence collection. The owner is adding complete compiler/test inventory matching, rejection of partial receipts, and full clean-worktree validation. The eventual proof must be independently rechecked after these additions. This concern does not affect canonical Native qualification, which retains its existing verifier.

Nested compiler/shell timing records overlap. Sum only the appropriate child records for CPU accounting, and use intervals or the complete make duration for wall time; summing every shell and compiler record would double-count compilation. Per-child maximum RSS is not concurrent aggregate RSS.

## Remaining gates

1. Bind this review to the final committed source by confirming the above source fingerprints, or re-review any changed executable delta.
2. Complete actual source-matched Native, Linux/Windows GDExtension and applicable scoped qualification; local GNU Make 4.4.1 graph checks are not hosted GCC13 native execution.
3. Verify clean same-worker control/candidate proof inventories and all actual exits; report compiler versus test time and memory without treating the source-order hypothesis as a speed result.
4. Independently judge practical performance/resource value. No percentage, repeatability or whole-routine saving is established by this review.

The historical runtime manifests must remain unchanged. Makefile is in their retained build-history ledger, not their current native source input set; this test-only build-order change provides no reason to republish a runtime or rewrite provenance.
