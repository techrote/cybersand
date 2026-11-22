# SWARM-006 — late accepted-main observation after sealing

**Disposition: deliver the unchanged, qualified `428f8420` evaluator under Draft/HOLD. Incorporation of the latest accepted main remains explicitly pending.** A read-only independent review of the newly accepted CI increment found no change to the evaluator's native, scientific, Godot, package or scoped qualification inputs. No immediate software repair or new execution campaign is required by this increment. This finding does not qualify a build of the newer main or close the later SWARM-004/005 reconciliation gate.

This is a separate addendum recorded at **2026-11-22 00:50:52 UTC**. The sealed qualification report and complete evidence archive retain their earlier observation of accepted main `30e1cddd`. They have not been edited to imply that they included the later observation below.

## Source chronology and preserved delivery

Accepted main advanced through [CI-only PR #723](https://github.com/techrote/cybersand/pull/723) at **2026-11-22 00:37:43 UTC**. The independent reviewer checked the actual Git objects against GitHub's commit and comparison metadata, then inspected the complete [accepted `30e1cddd` → `662df51c` delta](https://github.com/techrote/cybersand/compare/30e1cddd3d678456df10f52f7a2fb2210a9daaad...662df51cd8409a52332fa7ef15d06d8ab8945aed).

| Role | Exact identity |
| --- | --- |
| Qualified SWARM-006 software | `428f842034a1f80d593bcc6bb32af2dd99cd0105` |
| Qualified software tree | `cb1f4fdaf7b9cb487e850f1702a4f9085d0cb300` |
| Qualified accepted-main foundation | `846fe0533b3170e7b01f690518da49fc40cc24d1` |
| Accepted main observed in the sealed report | `30e1cddd3d678456df10f52f7a2fb2210a9daaad` — CI-only #722 |
| Latest accepted main observed by this addendum | `662df51cd8409a52332fa7ef15d06d8ab8945aed` — CI-only #723 |
| Latest accepted-main tree | `39b658c5de9c5e541312b5190bd5d8ba797c6bed` |
| #723 merge parents | `30e1cddd3d678456df10f52f7a2fb2210a9daaad`; `19023b4016facfda2b13b9a1503742e4a9fe1982` |
| Qualified Windows execution | [Run `44959721570`](https://github.com/techrote/cybersand/actions/runs/44959721570) |

The final sealed report SHA-256 remains `441f8674fd6de9c99a45a9789136926a4ad0e7af9210ca446d1d4a33b575b0c7`. The complete evidence archive, `CyberSand-SWARM006-Finisher-428f842034a1-Evidence.zip`, remains **500,131,811 bytes**, SHA-256 **`ec2fca91e6ecf08873c39e9c153bcda25a83c1d2fe6bba570c5a0e7a2fa43067`**. The owner evaluator ZIP remains **93,736,036 bytes**, SHA-256 **`2462275ad0093097b3c80b6bfe6fb543780b2b53cf3ee2ec56829c4341c7f015`**. This review rehashed those files and confirmed that the repository HEAD, tree, branch, index, refs, clean status and protected prior evidence were unchanged before and after the inspection.

## Exact accepted increment and merge preflight

The new increment changes **13 paths**, with **561 insertions and 67 deletions**:

| Path | Accepted change |
| --- | --- |
| `.github/workflows/native.yml` | Retains raw per-showcase logs in the ordinary Native artifact. |
| `Makefile` | Runs seven required normal/sanitized showcase targets through the existing Make jobserver; retains raw output before grouped replay. |
| `tools/ci/check_worldgen_build_inventory.py` | Checks the seven-showcase union and nine ordered principal tests, build prerequisites, original flags and execution-log contract. |
| `tools/ci/native_execution_policy.py` | Adds `--output-sync=target` to the two existing worldgen commands. |
| `tools/ci/run_native_family.sh` | Applies the same output grouping in the actual ordinary Native runner. |
| `tools/ci/verify_native_shards.py` | Requires all fourteen normal/sanitized raw showcase logs and explicit source/run/attempt/binary identity. |
| `tools/ci/test_native_shards.py` | Adds missing/stale/extra/header-only log and failure-retention controls. |
| `tools/ci/test_native_watchdogs.py` | Checks that grouping applies only to the two bounded worldgen commands. |
| `tools/ci/test_worldgen_build_inventory.py` | Adds graph, concurrency, warm-run, failure, timeout, cancellation and raw-output controls using test doubles. |
| `docs/operations/ci-execution-and-performance.md` | Documents the bounded scheduling and retained-output contract. |
| `docs/operations/local-build-and-validation.md` | Updates the current worldgen execution description and distinguishes historical bounds. |
| `docs/reference/retrieval-index.md` | Adds the CI contract retrieval route. |
| `docs/reference/status-and-roadmap.md` | Adds the CI-OPT-003 showcase scheduling status. |

The source change keeps seven showcases required before nine principal test recipes, shares the existing two-job budget, and retains the original test/sanitizer commands inside their existing watchdogs. This review inspected the accepted source; it does **not** independently repeat or certify #723's performance or concurrency experiments.

The full-index patch `accepted-30e1cddd-to-662df51c.patch` has SHA-256 `f60e59fbd12e9ecb2b1667c669ab25e306376373ca7a88f0f41903d1e348071d`. The accompanying `accepted-main-review.json` maps every changed path to its exact mode, Git blob, SHA-256 and byte length at qualified428, accepted846, previous30e, latest662 and the unresolved merge projection. GitHub's per-file statistics match the local Git diff exactly.

A cumulative accepted-only merge projection from qualified428 to latest662 contains **17 changed paths**, accounting for both CI-only increments #722 and #723. It reports exactly one text conflict: **`docs/reference/status-and-roadmap.md`**, where additive CI and successor programme sections share an insertion location. The other sixteen paths merge without text conflicts. The eventual resolution must preserve both sets of programme statements. The unresolved diagnostic tree is `12defa27b6beb6309b3584d874522f03bc4592fb`; it is not an implementation commit. Its patch and conflict output are retained. All temporary Git object writes were confined to the new review directory and removed afterward; no repository source, object store, index or ref was modified by this review.

## Effect on existing qualification

Exact Git modes and blobs are unchanged between qualified428 and the cumulative accepted-only projection for each scoped inventory:

| Inventory | Unchanged paths |
| --- | ---: |
| Qualified reciprocal CLI inputs | 132 |
| Qualified GDExtension adapter inputs | 106 |
| Qualified Windows preservation inputs | 1,121 |
| Entire native subtree | 262 |
| Entire Godot subtree | 957 |
| SWARM-006 qualification and package tools | 24 |
| Actual native scientific build inventory | 100 |
| Seven frozen registration files, native runner and replay orchestrator | 9 |
| Scoped workflow, packaging helper, candidate identity helper and attributes | 4 |

The 52 native definition inputs remain exact, producing `72779688b897e4707d89ac1f6e692046abbc806bd27b4c129bd77fcd995093a0`. The reciprocal and legacy experiment Makefiles are unchanged. The scoped SWARM-006 workflow does not invoke the changed worldgen aggregate; its relevant root-Make target, `workbench-authoring-patch-test`, retains the exact recipe, compiled-binary prerequisite rule and `CXX`, `COMMON_FLAGS`, `DEBUG_FLAGS` and `CORE_SOURCES` assignments.

The scientific evidence keeps its actual execution identities: **1,920 candidate executions at `ca63445888d818ed868f71869abb37ae4d00975e` plus 480 retained references**, with the independently reviewed byte-equivalence mapping to428. There were **zero corpus executions relabelled as428**, and none is relabelled as662. The mapping receipt remains SHA-256 `a1033d4876f2fd71c42c031c0eafcadb1f0f66d222972f8ff8c3de584c7d1041`. No registration, raw result, comparison policy or negative outcome was changed.

These unchanged inputs preserve the interpretation of the existing source-matched428 native, Workbench, Windows, package and terminal custody evidence. They do not make that evidence an execution of662 or any future combined source. Exact commit/tree admission still applies when a new source is built or packaged. No additional native, Godot, graphical or broad CI execution was performed for this addendum.

## Pending integration and owner decision

A fresh [PR #715 metadata check](https://github.com/techrote/cybersand/pull/715) still reports **Draft, open and unmerged**, with head `919134a39d31461947c410c233d59d1965c48414` and no merge commit. Neither the qualified428 evaluator nor this source-impact review adopts that unaccepted candidate. The previously retained SWARM-004/005 donor and conflict contract remains unchanged; the latest CI increment adds no native or Workbench reconciliation requirement to it.

**Latest-main incorporation is deliberately pending the reconciliation with the eventual actual accepted SWARM-004/005 foundation.** This is a chosen sequencing decision, not a claim that the CI-only commits cannot be incorporated separately. At that later step, revalidate then-current main and the real accepted merge; incorporate both accepted CI increments; resolve the additive roadmap conflict; preserve the accepted CI command/log gates and SWARM-006 authority, recovery, source and transaction boundaries; and renew the resulting-source builds, manifests and applicable qualification. Existing exact-source receipts must remain historical rather than be relabelled.

The user can evaluate the unchanged428 owner package now using its existing acceptance guide. Physical NVIDIA/original-owner-world acceptance remains outside the hosted evidence. **PR #716 stays Draft/HOLD: no Ready promotion, merge, auto-merge, production-default change or closure of the pending accepted-main/004/005 source objective follows from this addendum.**
