# Independent review of the coordinated CI wave

## Final hosted disposition

**APPROVE MERGE** of final Ready candidate
`0da970283d076ae4660a9d93efd0e5180d313247`, tree
`209c5521024d0c4d5cfa96b9a4aa5eee4a37cf88`, against accepted main
`be87b18b30506ccead610c7035ae1ffa8e65a347`. The source remains frozen, Ready
and mergeable at independent refresh. Its complete tree is byte-identical to
the locally reviewed `e85b1f73d5649158bc628834d169917d5d60ff16` below; only
merge commit metadata differs. Refreshed owner comments contain no newer
prohibition of this explicitly authorized tooling integration.

Attempt 1 qualification was independently recovered from current API job
inventories and both original reducer logs:

- [Native 45706972873](https://github.com/techrote/cybersand/actions/runs/45706972873): all nine jobs and steps succeed, including all six native families and reducer.
- [GDE 45706973071](https://github.com/techrote/cybersand/actions/runs/45706973071): 55 successful jobs, only the explicitly scoped physical-actor-stress job skipped. Both platform builds, all 23 Windows and 24 Linux shards, graphical smoke and both coverage reducers succeed. Windows independently verifies 317 cases and 340 original logs; Linux verifies 340 cases. The once-per-platform watchdog controls execute in shard zero; their deliberate nonzero-shard step skips do not omit any regression case.
- [Palette 45706972995](https://github.com/techrote/cybersand/actions/runs/45706972995): all eight jobs and all their steps succeed.
- [Documentation 45706973052](https://github.com/techrote/cybersand/actions/runs/45706973052): consistency and every step succeed.
- [Source advisory 45706972977](https://github.com/techrote/cybersand/actions/runs/45706972977): succeeds.

The previous Draft cohort's cancelled and skipped observations remain separate
and are not used as qualification. Final job identities and source bindings
are retained in `ci-wave-final-independent-approval.json`. Preserve ancestry
when merging. This approval grants no runtime publication or product feature
acceptance.

## Preserved initial local admission

**APPROVE Ready qualification** of source `e85b1f73d5649158bc628834d169917d5d60ff16`, tree `209c5521024d0c4d5cfa96b9a4aa5eee4a37cf88`. This review does not approve merging until every required resulting-source hosted gate passes.

The candidate preserves #771 original `911a3448e8e331cb097f1654bf861e20d77f57ca`, accepted main `be87b18b30506ccead610c7035ae1ffa8e65a347`, and exact #778 donor `585520e7e62b67ce8c4c86605b08e1f8cc920bba` through two ordinary ancestry-preserving merges. The 34-file delta is CI, tooling and documentation. Native, production Godot and third-party source/pins/runtimes are byte-identical to accepted main. The already accepted Palette concurrency line is absent from the remaining delta; no GDExtension fanout or RAM-first experiment is adopted.

## Source and negative-control review

The reviewer inspected the complete #778 acquisition/planner/reducer change and both #771 helper implementations. Godot acquisition changes only the route to the same locked bytes. The stale 24-shard test assumption is replaced by source-derived bounds and a 400-case/25-shard witness, while the original 16-case cap, expected cost, full watchdogs, hosted matrix ceiling and eight concurrent jobs per platform remain unchanged. Both coverage reducers reject missing or failed planning before invoking malformed commands. Actual coverage and original-log verification are retained.

Campaign coordination remains GET-only and distinguishes original run/attempt/source, reported success, missing/partial/non-atomic snapshots and owner qualification. It cannot dispatch or cancel any run. The publication helper requires an external contract pin, the exact same captured bytes that are parsed, original report/log joins, canonical local LFS objects, exact branch/index leases and a publication-only child. Its output explicitly denies publication authority, remote-LFS proof and semantic qualification. No active programme publisher has been migrated by this candidate.

## Independent executed checks

| Check | Actual result |
| --- | --- |
| Source-derived Godot planner | 12 methods PASS |
| Campaign coordination, `python3 -O` | 28 methods PASS |
| Publication custody, `python3 -O` | 39 methods PASS in 17.878 seconds |
| Direct Bash reducer predicates | 12 controls PASS: valid 1/25 counts admitted; empty/zero/negative/leading-zero/spaced/non-numeric counts and failed/skipped/cancelled/missing plans refused |

Optimized-Python execution confirms the helpers' decisive refusals survive removal of Python assertions. Separate source inspection verified no native/product dependency input changed. B owns additional full local policy/provenance tests; this record independently complements those results without substituting for hosted Native/GDExtension/Palette and documentation gates.

## Remaining gate

Run one complete applicable Ready cohort for this source, preserve all original failures, and review the actual complete job inventory, source/attempt bindings and required coverage reducers before merge. This combined tooling wave avoids two redundant heavyweight campaigns while retaining each donor identity and rollback path. Physical owner acceptance remains separate for product programmes.
